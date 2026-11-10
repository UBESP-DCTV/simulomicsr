#!/usr/bin/env python3
"""08-campi-di-tempo.py — sonda di disegno, PRIMA delle previsioni: quali campi dei 47 studi di sviluppo portano
un tempo, in GEO (viste v0) e in Expression Atlas (SDRF condensato), e con quali valori. Serve a scrivere la
regola del tempo zero per costruzione. Legge solo metadati e riferimento: nessuna uscita di pipeline.
Uso: python3 analysis/audit/2026-11-10-S12r2-prova-ripetuta/08-campi-di-tempo.py > .../08-out.txt"""
import csv, json, re, collections
A = "analysis/audit/2026-11-09-lettore-studio"
LARGO = re.compile(r"time|day|hour|\bhr|week|month|duration|hpi|dpi|stage", re.I)
div = [r for r in csv.DictReader(open(f"{A}/30-divisione.tsv"), delimiter="\t") if r["parte"] == "sviluppo"]
assert len(div) == 47
acc = {r["gse"]: r["accession"] for r in div}
viste = {}
for riga in open(f"{A}/60-viste-v0.jsonl"):
    v = json.loads(riga); viste[v["record_id"]] = v
assert set(viste) == set(acc)
print("== GEO: colonne e costanti con nome di tempo (largo) ==")
for g in sorted(viste):
    v = viste[g]
    for col, val in v["tabella"].items():
        if LARGO.search(col):
            t = collections.Counter(val.values())
            print(g, "| colonna |", col, "|", "; ".join(f"{k!r}={n}" for k, n in sorted(t.items())[:12]), "| distinti", len(t))
    cost = v.get("costanti") or {}
    for col, val in (cost.items() if isinstance(cost, dict) else []):
        if LARGO.search(col):
            print(g, "| costante |", col, "|", repr(val)[:80])
print("\n== Atlas: campi (caratteristica o fattore) con nome di tempo (largo) ==")
for g in sorted(acc):
    t = collections.defaultdict(collections.Counter)
    for r in csv.reader(open(f"analysis/input/atlas-2026-11-09/{acc[g]}.condensed-sdrf.tsv"), delimiter="\t"):
        if len(r) >= 6 and LARGO.search(r[4]):
            t[(r[3], r[4])][r[5]] += 1
    for (ruolo, nome), c in sorted(t.items()):
        print(g, "|", ruolo, "|", nome, "|", "; ".join(f"{k!r}={n}" for k, n in sorted(c.items())[:12]), "| distinti", len(c))
