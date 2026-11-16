#!/usr/bin/env python3
"""23-oltre-contesto.py — conto accanto, nato dopo i numeri: gli studi nuovi oltre il contesto secondo la stima.

Legge 21-per-studio-nuovo.csv (una riga per studio nuovo con la vista). Non legge uscite di modelli.
Dice quanti studi e quanti campioni non avranno una lettura nella corsa grande, secondo la stima dei token
(il conto vero lo fa il lavoratore con i token del modello).
Uso: python3 -I analysis/audit/2026-11-16-archs4-intero/23-oltre-contesto.py > .../23-out.txt
"""
import csv, statistics, time
D = "analysis/audit/2026-11-16-archs4-intero"
with open(D + "/21-per-studio-nuovo.csv", newline="") as h:
    r = list(csv.DictReader(h))
assert len(r) == 21244
ing = [x for x in r if x["esito"] == "nell_ingresso"]
oltre = [x for x in ing if x["oltre_contesto_stimato"] == "1"]
una = [x for x in r if x["esito"] == "nessuna_colonna_variabile"]
tot = sum(int(x["campioni"]) for x in r)
c = sorted(int(x["campioni"]) for x in oltre)
print("23-oltre-contesto.py", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
print("studi nuovi con la vista: %d; campioni: %d" % (len(r), tot))
print("studi nell'ingresso: %d; campioni: %d" % (len(ing), sum(int(x["campioni"]) for x in ing)))
print("studi oltre il contesto secondo la stima: %d (%.2f%% degli studi nell'ingresso)" % (len(oltre), 100.0 * len(oltre) / len(ing)))
print("  campioni: %d (%.1f%% dei campioni degli studi nuovi con la vista); minimo %d, mediana %s, massimo %d" % (sum(c), 100.0 * sum(c) / tot, c[0], statistics.median(c), c[-1]))
cu = [int(x["campioni"]) for x in una]
print("studi senza colonne non costanti: %d; campioni: %d; campioni per studio minimo %d massimo %d" % (len(una), sum(cu), min(cu), max(cu)))
