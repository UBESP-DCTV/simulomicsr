#!/usr/bin/env python3
"""Dall'elenco degli studi umani di Gemma (10-gemma-umani.csv) agli studi da scaricare (11-da-scaricare.csv).
Uso: python3 -I 11-elenco-da-scaricare.py [USCITA]   (dalla radice del repository)
Entrano gli studi RNA-seq di Gemma che stanno nel nostro bacino (master S14 dello Stadio 2), non marcati
«troubled» e non single-cell. `parte`: sviluppo, giudizio_A, giudizio_B (la divisione del lettore dello
studio, 30-divisione.tsv) oppure gemma (tutti gli altri). Gli studi di giudizio restano chiusi: 12-scarica-disegni.py
non li scarica."""
import collections, csv, re, sys
A = "analysis/audit/2026-11-15-gemma-riferimento"
out_path = sys.argv[1] if len(sys.argv) > 1 else f"{A}/11-da-scaricare.csv"
g = list(csv.DictReader(open(f"{A}/10-gemma-umani.csv")))
bac = set()
for l in open("analysis/p4-output/S14-stage2-master.jsonl"):
    m = re.match(r'\{"series_id":"(GSE\d+)"', l)
    if m: bac.add(m.group(1))
div = {r["gse"]: r["parte"] for r in csv.DictReader(open("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv"), delimiter="\t")}
out = []
for r in g:
    m = re.match(r"(GSE\d+)", r["accession"] or r["shortName"] or "")
    if not m or m.group(1) not in bac or "RNA_SEQ" not in r["strat"] and r["tech"] != "GENELIST": continue
    if r["troubled"] == "True" or r["sc"] == "True": continue
    out.append(dict(id=r["id"], shortName=r["shortName"], gse=m.group(1), n=r["n"], parte=div.get(m.group(1), "gemma")))
w = csv.DictWriter(open(out_path, "w", newline=""), fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out), collections.Counter(r["parte"] for r in out))
