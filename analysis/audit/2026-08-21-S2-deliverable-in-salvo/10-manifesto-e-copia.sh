#!/usr/bin/env bash
# 10-manifesto-e-copia.sh — S2 dell'handout 2026-08-21: mettere in salvo il deliverable.
#
# Manifesto SHA-256 del deliverable A3 v16 (194 meta-analisi) e di CIO' CHE SERVE
# A RICOSTRUIRLO (Stadio 3, master Stadio 1/2, input, dizionari); copia su un
# supporto diverso; verifica della copia con lo stesso manifesto.
#
# Uso (bash, nessuna dipendenza oltre coreutils e rsync):
#   10-manifesto-e-copia.sh genera            scrive SHA256SUMS.txt accanto allo script
#   10-manifesto-e-copia.sh verifica          verifica le ORIGINI contro SHA256SUMS.txt
#   10-manifesto-e-copia.sh verifica <DEST>   verifica una COPIA (<DEST>/<prefisso>/...)
#   10-manifesto-e-copia.sh copia <DEST>      rsync di tutto in <DEST>, poi verifica <DEST>
#
# Il manifesto usa percorsi relativi a quattro PREFISSI virtuali (stage4-v16,
# p4-output, input, cache): lo stesso file verifica sia le origini, sparse su
# tre dischi/cartelle, sia la copia, dove i prefissi sono sottocartelle di <DEST>.
# Le origini si possono spostare con le variabili STAGE4_ROOT, SIMULOMICSR_REPO,
# SIMULOMICSR_CACHE.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=${SIMULOMICSR_REPO:-$(cd "$HERE/../../.." && pwd)}
MANIFESTO=${MANIFESTO:-$HERE/SHA256SUMS.txt}
README_DATI=$HERE/README-cartella-dati.md

declare -A ORIGINE=(
  [stage4-v16]="${STAGE4_ROOT:-/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16}"
  [p4-output]="$REPO/analysis/p4-output"
  [input]="$REPO/analysis/input"
  [cache]="${SIMULOMICSR_CACHE:-$HOME/.cache/R/simulomicsr}"
)
PREFISSI=(stage4-v16 p4-output input cache)

# Oggetti censiti, relativi al prefisso. Una directory => tutti i file sotto di essa.
OGGETTI=(
  # Stadio 4: le QUATTRO cartelle omonime, tutte (quale sia il deliverable lo dice README-cartella-dati.md)
  stage4-v16/20260819T185517Z-stage4-v16-3e31e59d
  stage4-v16/20260819T184204Z-stage4-v16-3e31e59d
  stage4-v16/20260815T193851Z-stage4-v16-3e31e59d
  stage4-v16/20260815T121010Z-stage4-v16-3e31e59d
  # Stadio 3: quello del deliverable (A3) e quello del riferimento (in due copie identiche)
  p4-output/20260818T110906Z-stage3-v16-7f986159
  p4-output/20260814T025911Z-stage3-v16-7f986159
  p4-output/20260815T231154Z-stage3-v16-7f986159
  # Master Stadio 1/2 innestati (ingresso dello Stadio 3 A3) e master vecchi (ingresso del riferimento)
  p4-output/A3-stage1-master-innestato.jsonl
  p4-output/A3-stage2-master-innestato.jsonl
  p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl
  p4-output/p4-fase-f4-stage2-master-v3.jsonl
  # Input dello Stadio 1 (dall'ETL) e sottoinsieme A3
  input/archs4-human-stage1-input-v2.jsonl
  input/A3-stage1-input.jsonl
  # Dizionari ontologici e cache usate dallo Stadio 3 (release registrate nel run_metadata dello Stadio 3)
  cache/chebi
  cache/chembl
  cache/mesh
  cache/taxonomy
  cache/immport
  cache/uniprot
  cache/hgnc_complete_set.tsv
  cache/hgnc-lookup.rds
  cache/mesh-lookup.rds
  cache/name-recovery-lookup
  cache/geo-series-resolver-cache.rds
  cache/archs4-metadata-551065e6.rds
  cache/archs4-metadata-f971be69.rds
)
# ESCLUSI di proposito:
#  - cache/stage4-counts (9,5 GB): cache delle conte, ricostruibile dall'H5; cambia a
#    ogni re-pool e renderebbe stale il manifesto.
#  - analysis/input/human_gene_v2.5.h5 (47,86 GB): pubblico, ri-scaricabile; il suo
#    SHA-256 sta in analysis/p4-output/p4-beta-archs4-source.json.

genera() {
  local tmp="$MANIFESTO.tmp" n=0
  : > "$tmp"
  for o in "${OGGETTI[@]}"; do
    local p=${o%%/*} rel=${o#*/} root
    root=${ORIGINE[$p]}
    if [ ! -e "$root/$rel" ]; then echo "MANCA: $root/$rel" >&2; rm -f "$tmp"; exit 2; fi
    ( cd "$root" && if [ -d "$rel" ]; then
        find "$rel" -type f | LC_ALL=C sort | xargs -d '\n' sha256sum
      else sha256sum "$rel"; fi ) | sed "s|^\([0-9a-f]\{64\}\)  |\1  $p/|" >> "$tmp"
  done
  mv "$tmp" "$MANIFESTO"
  n=$(wc -l < "$MANIFESTO")
  echo "scritto $MANIFESTO: $n file"
}

verifica() {
  local dest=${1:-} fallite=0 p root n
  [ -s "$MANIFESTO" ] || { echo "manifesto assente: $MANIFESTO" >&2; exit 2; }
  for p in "${PREFISSI[@]}"; do
    if [ -n "$dest" ]; then root="$dest/$p"; else root=${ORIGINE[$p]}; fi
    n=$(grep -c "^[0-9a-f]\{64\}  $p/" "$MANIFESTO" || true)
    [ "$n" -gt 0 ] || continue
    if [ ! -d "$root" ]; then echo "FAIL  $p: manca $root"; fallite=1; continue; fi
    if ( cd "$root" && grep "^[0-9a-f]\{64\}  $p/" "$MANIFESTO" | sed "s|  $p/|  |" \
           | sha256sum -c --quiet --strict ); then
      echo "OK    $p  ($n file)  in $root"
    else
      echo "FAIL  $p  in $root"; fallite=1
    fi
  done
  if [ "$fallite" -eq 0 ]; then echo "VERIFICA OK: tutti i file del manifesto coincidono${dest:+ in $dest}"; else echo "VERIFICA FALLITA" >&2; exit 1; fi
}

copia() {
  local dest=${1:?uso: copia <DEST>} p o rel dd od
  mkdir -p "$dest"
  dd=$(stat -c %d "$dest")
  for p in "${PREFISSI[@]}"; do
    od=$(stat -c %d "${ORIGINE[$p]}")
    if [ "$od" = "$dd" ]; then
      echo "ATTENZIONE: $dest sta sullo STESSO dispositivo di ${ORIGINE[$p]} -> non e' un supporto diverso" >&2
    fi
  done
  for o in "${OGGETTI[@]}"; do
    p=${o%%/*}; rel=${o#*/}
    mkdir -p "$dest/$p/$(dirname "$rel")"
    rsync -a "${ORIGINE[$p]}/$rel" "$dest/$p/$(dirname "$rel")/"
  done
  cp "$MANIFESTO" "$dest/SHA256SUMS.txt"
  [ -f "$README_DATI" ] && cp "$README_DATI" "$dest/README.md" && cp "$README_DATI" "$dest/stage4-v16/README.md"
  cp "${BASH_SOURCE[0]}" "$dest/10-manifesto-e-copia.sh"
  echo "copia finita in $dest ($(du -sh "$dest" | cut -f1)); verifico"
  verifica "$dest"
}

case "${1:-}" in
  genera)   genera ;;
  verifica) verifica "${2:-}" ;;
  copia)    copia "${2:-}" ;;
  *) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
