#!/usr/bin/env python3
"""Scrive una riga di 26-letture-senza-unita.csv: nota_su.py <GSE> <firma12> "<etichette separate da ;>" "<descrizione>"."""
import sys, csv, os
F = "/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/26-letture-senza-unita.csv"
g, f, e, d = sys.argv[1:5]; assert len(f) == 12
R = list(csv.DictReader(open(F, encoding="utf-8"))) if os.path.exists(F) else []
R = [r for r in R if not (r["studio"] == g and r["firma"] == f)] + [dict(studio=g, firma=f, errore=e, descrizione=d)]
R.sort(key=lambda r: (r["studio"], r["firma"]))
w = csv.DictWriter(open(F, "w", encoding="utf-8", newline=""), ["studio", "firma", "errore", "descrizione"], quoting=csv.QUOTE_ALL); w.writeheader(); w.writerows(R)
print("righe", len(R))
