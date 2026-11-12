#!/usr/bin/env python3
# S12r4 - quanti errori di lettura sono presenti in ogni forma (non solo quelli nuovi).
# Legge 27-stati.csv (lo stato di ogni etichetta in ogni corsa) e la colonna `costa`
# di 26-errori-nelle-basi.csv. I 4 errori di S12r3 (tipo «predicato») non stanno in
# quel file e si contano come «costa si» (finding S12r3: gruppi sbagliati o confronti persi).
# Uso: python3 29-errori-presenti.py <cartella dell'audit>   -> 29-errori-presenti-per-forma.csv
import csv, sys, collections
D = sys.argv[1].rstrip("/") + "/"
costa = {r["errore"]: r["costa"] for r in csv.DictReader(open(D + "26-errori-nelle-basi.csv", encoding="utf-8"))}
st = list(csv.DictReader(open(D + "27-stati.csv", encoding="utf-8")))
senza = sorted({r["errore"] for r in st if r["errore"] not in costa})
pred = sorted({r["errore"] for r in st if r["tipo"] == "predicato"})
assert all(e in pred for e in senza), f"etichette senza `costa` che non sono predicati: {senza}"
for e in senza: costa[e] = "si"
corse = list(dict.fromkeys(r["corsa"] for r in st))
righe = []
for k in corse:
    rk = [r for r in st if r["corsa"] == k]
    pres = [r for r in rk if r["stato"] == "presente"]
    cst = [r for r in pres if costa[r["errore"]] == "si"]
    nv = {r["studio"] for r in rk if r["stato"] == "non valutabile"}
    righe.append([k, len(pres), len({r["studio"] for r in pres}), len(cst), len({r["studio"] for r in cst}), len(nv)])
w = csv.writer(open(D + "29-errori-presenti-per-forma.csv", "w", newline="", encoding="utf-8"), quoting=csv.QUOTE_ALL)
w.writerow(["corsa", "errori_presenti", "studi_con_errore", "errori_che_costano", "studi_con_errore_che_costa", "studi_non_valutabili"]); w.writerows(righe)
print(f"etichette {len(costa)}, corse {len(corse)}, righe di stato {len(st)}; senza `costa` nel file delle basi (predicati, contati «si»): {senza}")
for r in righe: print(*r, sep="\t")
