#!/usr/bin/env python3
"""S12r4, conto accanto dichiarato DOPO i numeri (rilievo R1 della revisione indipendente).

Il conto depositato (00-previsioni.md, §4) vede un errore nuovo solo nelle righe
peggiorate. Qui si contano, per ogni forma, le etichette di errore di lettura
«presente» nella forma e non «presente» nella base (nate) e quelle «presente»
nella base e «assente» nella forma (tolte), da 27-stati.csv. Non sostituisce
il conto depositato e non entra in nessun esito.

Uso: python3 33-nati-per-etichetta.py <cartella> > 33-out.txt
Scrive <cartella>/33-nati-per-etichetta.csv
"""
import csv, sys, collections, statistics

D = sys.argv[1]
rd = lambda f: list(csv.DictReader(open(f"{D}/{f}", encoding="utf-8")))
stati = rd("27-stati.csv")
pf = {r["corsa"]: r for r in rd("27-per-forma.csv")}
costa = {r["errore"]: r["costa"] for r in rd("26-errori-nelle-basi.csv")}
st = collections.defaultdict(dict)
for r in stati:
    st[r["corsa"]][r["errore"]] = r["stato"]
studio = {r["errore"]: r["studio"] for r in stati}
righe = []
for corsa, r in pf.items():
    base = r["base"]
    nate = sorted(e for e, s in st[corsa].items() if s == "presente" and st[base][e] != "presente")
    tolte = sorted(e for e, s in st[base].items() if s == "presente" and st[corsa][e] == "assente")
    righe.append(dict(
        corsa=corsa, base=base,
        etichette_tolte=len(tolte), etichette_nate=len(nate),
        etichette_nate_che_costano=sum(costa.get(e, "si") == "si" for e in nate),
        studi_con_etichetta_nata=len({studio[e] for e in nate}),
        studi_con_errore_nuovo_depositato=r["studi_con_errore_nuovo"],
        studi_con_errore_nuovo_stretto=r["studi_con_errore_nuovo_stretto"],
        nate="; ".join(nate), tolte="; ".join(tolte)))
with open(f"{D}/33-nati-per-etichetta.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(righe[0].keys()), quoting=csv.QUOTE_ALL)
    w.writeheader(); w.writerows(righe)
print("forma base | etichette tolte | etichette nate (che costano) | studi con un'etichetta nata | conto depositato (stretto)")
for x in righe:
    print(f"{x['corsa']:10s} {x['base']} | {x['etichette_tolte']} | {x['etichette_nate']} ({x['etichette_nate_che_costano']}) | "
          f"{x['studi_con_etichetta_nata']} | {x['studi_con_errore_nuovo_depositato']} ({x['studi_con_errore_nuovo_stretto']})")
un = ["RP", "RPa", "RPb", "RPc", "RPd", "RP5", "RC", "RC3", "RA1", "RA4", "RR", "F1", "F2"]
v = sorted(int(x["studi_con_etichetta_nata"]) for x in righe if x["corsa"] in un)
print("\nprevisione 11 col conto per etichetta (13 forme a un cambio da B0): valori", v, "mediana", statistics.median(v))
con = [x for x in righe if x["etichette_tolte"] > 0]
print("forme che tolgono almeno un'etichetta:", len(con), "su", len(righe),
      "; fra queste, con almeno un'etichetta nata:", sum(x["etichette_nate"] > 0 for x in con))
print("forme senza etichette tolte:", [(x["corsa"], x["etichette_nate"]) for x in righe if x["etichette_tolte"] == 0])
print("forme con meno etichette nate che tolte:", [(x["corsa"], x["etichette_tolte"], x["etichette_nate"]) for x in righe if x["etichette_nate"] < x["etichette_tolte"]])
