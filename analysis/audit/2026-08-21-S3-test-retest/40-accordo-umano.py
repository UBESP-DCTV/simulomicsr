#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
# Accordo fra la lettura umana (umano/RISPOSTE.csv) e il metodo: contro il run
# originale e contro il retest. Conta SOLO le righe compilate e lo dice.
# Uso: python3 analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
import csv, os, sys
sys.path.insert(0, 'analysis/audit/2026-08-21-S3-test-retest')
from lib_accordo import *
S = 'analysis/audit/2026-08-21-S3-test-retest'; R = 'analysis/audit/2026-08-20-rilettura-194'
ris = list(csv.DictReader(open(os.path.join(S, 'umano', 'RISPOSTE.csv'))))
orig = {r['cluster_id']: r for r in csv.DictReader(open(os.path.join(R, 'verdetti-194.csv')))}
p = os.path.join(S, 'verdetti-retest.csv')
ret = {r['cluster_id']: r for r in csv.DictReader(open(p))} if os.path.exists(p) else {}
dif_orig = {}
for r in csv.DictReader(open(os.path.join(R, 'difetti.csv'))):
    dif_orig.setdefault(r['cluster_id'], set()).add(r['study_id'])

def norm(v): return v.strip().lower()
lette = [r for r in ris if norm(r['verdetto_parte1']) in CLASSI]
print(f"schede compilate: {len(lette)} su {len(ris)}")
if not lette: sys.exit("niente da contare: compila umano/RISPOSTE.csv")
if len(lette) < 10:
    print("  ATTENZIONE: con meno di 10 gruppi l'intervallo copre quasi tutto (36% e 90% non si distinguono).")

def confronta(nome, ref, colonna):
    a = [norm(r[colonna]) if norm(r[colonna]) in CLASSI else norm(r['verdetto_parte1']) for r in lette]
    b = [ref[r['cluster_id']]['verdetto_finale'] for r in lette]
    n = len(a); k = kappa(a, b); lo, hi = ic_bootstrap(a, b, kappa)
    ab = ['difettosa' if x == 'difettosa' else 'non' for x in a]
    bb = ['difettosa' if x == 'difettosa' else 'non' for x in b]
    print(f"\n=== umano ({colonna}) contro {nome}, su {n} gruppi ===")
    print(f"  accordo grezzo a tre classi : {100*accordo(a,b):.1f}%   kappa {k:.2f}  [IC95 bootstrap {lo:.2f}, {hi:.2f}]")
    print(f"  accordo binario (difettosa) : {100*accordo(ab,bb):.1f}%   kappa {kappa(ab,bb):.2f}")
    stampa_matrice(matrice(a, b), 'umano', nome)
    for r, x, y in zip(lette, a, b):
        if x != y: print(f"    disaccordo {r['file']:40s} umano={x:10s} {nome}={y}")

confronta('originale', orig, 'verdetto_parte1')
if ret: confronta('retest', ret, 'verdetto_parte1')
if any(norm(r['verdetto_dopo_parte2']) in CLASSI for r in lette):
    n2 = sum(norm(r['verdetto_dopo_parte2']) in CLASSI for r in lette)
    print(f"\n--- dopo le stringhe grezze (PARTE 2): {n2} verdetti cambiati dall'umano ---")
    confronta('originale', orig, 'verdetto_dopo_parte2')
# gli studi accusati: l'umano ritrova quelli del modello?
print("\n=== studi accusati (PARTE 1) contro difetti.csv dell'originale ===")
for r in lette:
    u = {s.strip() for s in r['studi_difettosi_parte1'].split(';') if s.strip()}
    m = dif_orig.get(r['cluster_id'], set())
    if u or m: print(f"  {r['file']:40s} umano={sorted(u)} modello={sorted(m)}  comuni={len(u & m)}")
