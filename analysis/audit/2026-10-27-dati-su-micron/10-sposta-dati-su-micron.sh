#!/usr/bin/env bash
# 10-sposta-dati-su-micron.sh — 2026-10-27: i dati pesanti di simulomicsr su /mnt/micron.
#
# Perché: la radice (/) era al 90% (90 GB liberi su 916) e il repo pesava 81 GB, quasi
# tutti dati gitignorati. Scelta dell'utente (opzione C): si spostano SOLO i dati;
# codice, git, worktree e sessioni Claude restano in /home/user/simulomicsr.
#
# Che cosa si sposta e con quale forma di link (la forma la decide git):
#   analysis/input          cartella intera -> link   (0 file tracciati)
#   analysis/p4-bundles     cartella intera -> link   (0 file tracciati)
#   analysis/p4-output      voce per voce   -> link   (17 file tracciati: la cartella resta vera;
#                                                      si sposta ogni voce che git non traccia)
#   ~/.cache/R/simulomicsr  cartella intera -> link   (fuori dal repo)
# Un link al posto di una cartella ignorata con «dir/» git lo mostra come «??»: per input
# e p4-bundles la riga di .gitignore perde la barra finale (provato su un repo a vuoto).
# Conseguenza: i run NUOVI scritti in analysis/p4-output/ finiscono ancora sulla radice.
#
# Fasi (ognuna rilanciabile; nessuna cancella dati):
#   copia      rsync -aHAX sorgente -> $DEST; elenco delle voci di p4-output per regola
#   manifesto  SHA-256 di ogni file letto dalla SORGENTE (in $DEST/SHA256SUMS-<area>.txt)
#   verifica   sha256sum -c sulla DESTINAZIONE + confronto di link e cartelle; scrive .verifica-ok
#              (prima: sync e ../2026-08-21-S2-deliverable-in-salvo/20-sfratta-page-cache.py $DEST sfratta)
#   scambia    sorgente -> $VECCHI (stesso disco, istantaneo) e link al suo posto; solo dopo .verifica-ok
#   ripristina il contrario di scambia
# La cancellazione di $VECCHI la fa l'utente, dopo il suo ok.
set -euo pipefail

REPO=/home/user/simulomicsr
DEST=/mnt/micron/simulomicsr-dati
VECCHI=/home/user/simulomicsr-dati-vecchi-2026-10-27
QUI=$(cd "$(dirname "$0")" && pwd)
VOCI="$QUI/p4-output-voci-spostate.txt"

# area intera: nome in $DEST -> sorgente
declare -A INTERE=(
  [input]="$REPO/analysis/input"
  [p4-bundles]="$REPO/analysis/p4-bundles"
  [cache-R-simulomicsr]="$HOME/.cache/R/simulomicsr"
)
P4OUT="$REPO/analysis/p4-output"

muori() { echo "ERRORE: $*" >&2; exit 1; }
gia_scambiato() { [[ -L "$REPO/analysis/input" ]]; }

copia() {
  gia_scambiato && muori "lo scambio è già fatto: la copia leggerebbe i link"
  [[ "$(stat -c %d "$REPO")" == "$(stat -c %d "$(dirname "$VECCHI")")" ]] ||
    muori "$VECCHI non è sullo stesso disco del repo: lo scambio non sarebbe istantaneo"
  mkdir -p "$DEST"
  for a in "${!INTERE[@]}"; do
    echo "[copia] $a"
    rsync -aHAX "${INTERE[$a]}/" "$DEST/$a/"
  done
  # Regola, non lista: ogni voce di p4-output che non è (né contiene) un file tracciato.
  # LC_ALL=C anche su comm: con la collazione di sistema rifiuta l'ordine di `sort` in C
  # e, con set -e, ferma il job (successo al primo lancio, 2026-10-27).
  LC_ALL=C comm -23 <(ls -A "$P4OUT" | LC_ALL=C sort) \
           <(git -C "$REPO" ls-files analysis/p4-output | cut -d/ -f3 | LC_ALL=C sort -u) > "$VOCI"
  echo "[copia] p4-output: $(wc -l < "$VOCI") voci su $(ls -A "$P4OUT" | wc -l)"
  rsync -aHAX -r --files-from="$VOCI" "$P4OUT/" "$DEST/p4-output/"
  cp "$VOCI" "$DEST/"
}

# file regolari di un'area, relativi alla sua radice, uno per riga NUL
file_area() {
  local a=$1 radice=$2
  if [[ $a == p4-output ]]; then
    (cd "$radice" && while IFS= read -r v; do find "./$v" -type f -print0; done < "$VOCI")
  else
    (cd "$radice" && find . -type f -print0)
  fi
}

manifesto() {
  gia_scambiato && muori "lo scambio è già fatto: il manifesto va letto dalla sorgente"
  for a in "${!INTERE[@]}" p4-output; do
    local src=${INTERE[$a]:-$P4OUT}
    echo "[manifesto] $a"
    file_area "$a" "$src" | (cd "$src" && xargs -0 -P 16 -n 64 sha256sum) |
      LC_ALL=C sort -k2 > "$DEST/SHA256SUMS-$a.txt"
    echo "  $(wc -l < "$DEST/SHA256SUMS-$a.txt") file"
  done
}

verifica() {
  local ko=0
  for a in "${!INTERE[@]}" p4-output; do
    local dst="$DEST/$a" src=${INTERE[$a]:-$P4OUT} man="$DEST/SHA256SUMS-$a.txt"
    [[ -s $man ]] || muori "manca $man"
    local dir; dir=$(mktemp -d)
    split -e -n l/16 "$man" "$dir/pezzo-"
    if (cd "$dst" && ls "$dir"/pezzo-* | xargs -P 16 -I{} sha256sum -c --quiet {}); then
      echo "[verifica] $a: $(wc -l < "$man") file OK"
    else
      echo "[verifica] $a: SHA-256 DIVERSI (righe sopra)"; ko=1
    fi
    rm -rf "$dir"
    local n_dst; n_dst=$(find "$dst" -type f | wc -l)
    [[ $n_dst -eq $(wc -l < "$man") ]] || { echo "[verifica] $a: $n_dst file in destinazione, manifesto $(wc -l < "$man")"; ko=1; }
    if ! gia_scambiato; then
      # link e cartelle: stessi nomi e stessi bersagli
      if [[ $a == p4-output ]]; then
        cmp -s <(cd "$src" && while IFS= read -r v; do find "./$v" \( -type l -printf '%p -> %l\n' \) -o \( -type d -printf '%p/\n' \); done < "$VOCI" | LC_ALL=C sort) \
               <(cd "$dst" && while IFS= read -r v; do find "./$v" \( -type l -printf '%p -> %l\n' \) -o \( -type d -printf '%p/\n' \); done < "$VOCI" | LC_ALL=C sort) ||
          { echo "[verifica] $a: link o cartelle diversi"; ko=1; }
      else
        cmp -s <(cd "$src" && find . \( -type l -printf '%p -> %l\n' \) -o \( -type d -printf '%p/\n' \) | LC_ALL=C sort) \
               <(cd "$dst" && find . \( -type l -printf '%p -> %l\n' \) -o \( -type d -printf '%p/\n' \) | LC_ALL=C sort) ||
          { echo "[verifica] $a: link o cartelle diversi"; ko=1; }
      fi
    fi
  done
  [[ $ko -eq 0 ]] || muori "verifica fallita: niente .verifica-ok"
  date -Is > "$DEST/.verifica-ok"
  echo "[verifica] tutto OK ($(cat "$DEST/.verifica-ok"))"
}

scambia() {
  [[ -f "$DEST/.verifica-ok" ]] || muori "manca $DEST/.verifica-ok: prima la verifica"
  gia_scambiato && muori "scambio già fatto"
  mkdir -p "$VECCHI/p4-output"
  for a in "${!INTERE[@]}"; do
    mv "${INTERE[$a]}" "$VECCHI/$a"
    ln -s "$DEST/$a" "${INTERE[$a]}"
  done
  while IFS= read -r v; do
    mv "$P4OUT/$v" "$VECCHI/p4-output/$v"
    ln -s "$DEST/p4-output/$v" "$P4OUT/$v"
  done < "$VOCI"
  sed -i 's#^analysis/input/$#analysis/input#; s#^analysis/p4-bundles/$#analysis/p4-bundles#' "$REPO/.gitignore"
  echo "[scambia] fatto; originali in $VECCHI"
}

ripristina() {
  gia_scambiato || muori "niente da ripristinare"
  for a in "${!INTERE[@]}"; do
    [[ -L "${INTERE[$a]}" && -d "$VECCHI/$a" ]] || muori "${INTERE[$a]}: stato inatteso"
    rm "${INTERE[$a]}"
    mv "$VECCHI/$a" "${INTERE[$a]}"
  done
  while IFS= read -r v; do
    [[ -L "$P4OUT/$v" && -e "$VECCHI/p4-output/$v" ]] || muori "$P4OUT/$v: stato inatteso"
    rm "$P4OUT/$v"
    mv "$VECCHI/p4-output/$v" "$P4OUT/$v"
  done < "$VOCI"
  sed -i 's#^analysis/input$#analysis/input/#; s#^analysis/p4-bundles$#analysis/p4-bundles/#' "$REPO/.gitignore"
  echo "[ripristina] fatto"
}

case "${1:-}" in
  copia|manifesto|verifica|scambia|ripristina) "$1" ;;
  *) echo "uso: $0 copia|manifesto|verifica|scambia|ripristina" >&2; exit 2 ;;
esac
