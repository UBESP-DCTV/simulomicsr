#!/usr/bin/env python3
"""12-verifica-testi.py — verifica dei testi GEO congelati degli studi nuovi di ARCHS4 (cancello K2) e misura a1.

Legge i due manifesti dello scarico (11-manifesto-geo-{0,1}.tsv) e i due file dei falliti (11-falliti-{0,1}.tsv).
Non scarica niente. Controlla, per OGNI riga dei manifesti: il file esiste nella cartella dei testi, ha i byte
scritti e lo SHA-256 scritto. Controlla anche: nessun file nella cartella fuori dai manifesti; nessun file di uno
studio che non e' della classe `nuovo` (K5: nessuno studio di giudizio); nessun file doppio fra i due manifesti.
Uno studio ha i testi quando ha tutti e due i file (serie e campioni) nel manifesto.
Per ogni studio nuovo senza i testi scrive il motivo: l'ULTIMO motivo scritto nel file dei falliti, oppure
`non_ancora_scaricato` se lo scarico non lo ha ancora provato (lo script si puo' lanciare a scarico in corso).

Uso:  python3 -I analysis/audit/2026-11-16-archs4-intero/12-verifica-testi.py > .../12-out.txt
Uscite: 12-senza-testi.csv (gse, file_mancante, motivo, inizio_ultima_risposta), i conti su stdout.
Esce con codice 1 se un file non torna con il manifesto.
"""
import csv, glob, hashlib, os, sys, time

D = "analysis/audit/2026-11-16-archs4-intero"
CARTELLA = "analysis/input/geo-testi-archs4-2026-11-16"
csv.field_size_limit(10**9)


def tsv(pattern):
    righe = []
    for f in sorted(glob.glob(os.path.join(D, pattern))):
        with open(f, newline="", encoding="utf-8") as h:
            righe += list(csv.DictReader(h, delimiter="\t", quoting=csv.QUOTE_NONE))
    return righe


with open(os.path.join(D, "10-elenco.csv"), newline="") as h:
    elenco = list(csv.DictReader(h))
nuovi = {r["gse"] for r in elenco if r["classe"] == "nuovo"}
assert len(elenco) == 24393 and len(nuovi) == 21249

man = tsv("11-manifesto-geo-[0-9]*.tsv")
nomi = [r["file"] for r in man]
assert len(nomi) == len(set(nomi)), "file doppio fra i manifesti"
fuori = sorted({n.split(".")[0] for n in nomi} - nuovi)
assert not fuori, "file di studi non nuovi nel manifesto: %s" % fuori[:5]

male = []
for r in man:
    p = os.path.join(CARTELLA, r["file"])
    if not os.path.isfile(p):
        male.append((r["file"], "manca su disco")); continue
    with open(p, "rb") as h:
        b = h.read()
    if len(b) != int(r["byte"]) or hashlib.sha256(b).hexdigest() != r["sha256"]:
        male.append((r["file"], "byte o SHA-256 diversi dal manifesto"))
su_disco = set(os.listdir(CARTELLA))
orfani = sorted(su_disco - set(nomi))

per_studio = {}
for n in nomi:
    per_studio.setdefault(n.split(".")[0], set()).add(n.split(".", 1)[1])
ATTESI = {"serie.soft.txt", "campioni.soft.txt"}
con_testi = {g for g, s in per_studio.items() if s == ATTESI}

falliti = {}
for r in tsv("11-falliti-[0-9]*.tsv"):          # l'ultimo motivo vince (le righe sono in ordine di tempo per processo)
    g = r["file"].split(".")[0]
    if g not in falliti or r["quando_utc"] >= falliti[g]["quando_utc"]:
        falliti[g] = r
senza = sorted(nuovi - con_testi, key=lambda g: int(g[3:]))
with open(os.path.join(D, "12-senza-testi.csv"), "w", newline="", encoding="utf-8") as h:
    w = csv.writer(h); w.writerow(["gse", "file_mancante", "motivo", "inizio_ultima_risposta"])
    for g in senza:
        f = falliti.get(g)
        w.writerow([g, f["file"] if f else "", f["motivo"] if f else "non_ancora_scaricato",
                    (f["inizio_ultima_risposta"] or "")[:200] if f else ""])

print("12-verifica-testi.py", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
print("righe dei manifesti: %d; file che tornano con byte e SHA-256: %d; file che non tornano: %d" % (len(man), len(man) - len(male), len(male)))
print("file nella cartella fuori dai manifesti: %d %s" % (len(orfani), " ".join(orfani[:10])))
print("a1, studi nuovi con i due file dei testi: %d su %d (%.2f%%)" % (len(con_testi), len(nuovi), 100.0 * len(con_testi) / len(nuovi)))
motivi = {}
for g in senza:
    m = falliti[g]["motivo"] if g in falliti else "non_ancora_scaricato"
    m = "".join("N" if c.isdigit() else c for c in m)
    motivi[m] = motivi.get(m, 0) + 1
print("studi nuovi senza i testi: %d" % len(senza))
for m, n in sorted(motivi.items(), key=lambda x: -x[1]):
    print("  %6d  %s" % (n, m))
for f, m in male[:20]:
    print("NON TORNA: %s (%s)" % (f, m))
if male or orfani:
    print("CANCELLO K2: FALLITO"); sys.exit(1)
print("CANCELLO K2: passa sui file scritti fino a qui" if "non_ancora_scaricato" in motivi else "CANCELLO K2: passa")
