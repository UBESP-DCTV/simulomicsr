#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
# Accordo fra la lettura umana (umano/RISPOSTE.csv) e il metodo: contro il run
# originale e contro il retest 2 (ambiente congelato), piu' il metodo contro se
# stesso SULLE STESSE righe, che e' il termine di paragone. Conta SOLO le righe
# compilate e lo dice. Il confronto primario e' la PARTE 1: stessa informazione
# del modello. La PARTE 2 misura altro: quanto l'etichetta nasconde.
# Uso: python3 analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
import csv, os, sys
sys.path.insert(0, 'analysis/audit/2026-08-21-S3-test-retest')
from lib_accordo import *
S = 'analysis/audit/2026-08-21-S3-test-retest'; R = 'analysis/audit/2026-08-20-rilettura-194'
PRECEDENTE = 0.362
ris = list(csv.DictReader(open(os.path.join(S, 'umano', 'RISPOSTE.csv'))))
orig = {r['cluster_id']: r for r in csv.DictReader(open(os.path.join(R, 'verdetti-194.csv')))}
ret = {r['cluster_id']: r for r in csv.DictReader(open(os.path.join(S, 'verdetti-retest2.csv')))}
def accusati(p):
    d = {}
    for r in csv.DictReader(open(p)): d.setdefault(r['cluster_id'], set()).add(r['study_id'])
    return d
dif_orig, dif_ret = accusati(os.path.join(R, 'difetti.csv')), accusati(os.path.join(S, 'difetti-retest2.csv'))

def norm(v): return v.strip().lower()
lette = [r for r in ris if norm(r['verdetto_parte1']) in CLASSI]
print(f"schede compilate: {len(lette)} su {len(ris)}")
print("  non compilate: " + (", ".join(r['file'] for r in ris if r not in lette) or "nessuna"))
if not lette: sys.exit("niente da contare: compila umano/RISPOSTE.csv")
if len(lette) < 10:
    print("  ATTENZIONE: con meno di 10 gruppi l'intervallo copre quasi tutto.")
BIN = lambda v: ['difettosa' if x == 'difettosa' else 'non' for x in v]

def misura(a, b, nome):
    n = len(a); k = sum(x == y for x, y in zip(a, b)); lo, hi = ic_esatto(k, n)
    kk = kappa(a, b); klo, khi = ic_bootstrap(a, b, kappa)
    ab, bb = BIN(a), BIN(b); kb = sum(x == y for x, y in zip(ab, bb)); blo, bhi = ic_esatto(kb, n)
    print(f"\n=== {nome}, su {n} gruppi ===")
    print(f"  tre classi : {k}/{n} = {100*k/n:.1f}%  [IC95 esatto {100*lo:.1f}, {100*hi:.1f}]   kappa {kk:.2f} [bootstrap {klo:.2f}, {khi:.2f}]")
    print(f"  binario    : {kb}/{n} = {100*kb/n:.1f}%  [IC95 esatto {100*blo:.1f}, {100*bhi:.1f}]   kappa {kappa(ab,bb):.2f}")
    print(f"  contro il precedente {100*PRECEDENTE:.1f}%: P(X>={k} | p={PRECEDENTE}) = {binom_coda_sup(k, n, PRECEDENTE):.2g}")

def verdetti_umano(colonna):
    return [norm(r[colonna]) if norm(r[colonna]) in CLASSI else norm(r['verdetto_parte1']) for r in lette]
def confronta(nome, ref, colonna):
    a = verdetti_umano(colonna); b = [ref[r['cluster_id']]['verdetto_finale'] for r in lette]
    misura(a, b, f"umano ({colonna}) contro {nome}")
    stampa_matrice(matrice(a, b), 'umano', nome)
    for r, x, y in zip(lette, a, b):
        if x != y: print(f"    disaccordo {r['file']:40s} umano={x:10s} {nome}={y}")

print("\n########## PRIMARIO: PARTE 1, stessa informazione del modello ##########")
confronta('originale', orig, 'verdetto_parte1')
confronta('retest2', ret, 'verdetto_parte1')
print("\n########## TERMINE DI PARAGONE: il metodo contro se stesso sulle stesse righe ##########")
a = [orig[r['cluster_id']]['verdetto_finale'] for r in lette]; b = [ret[r['cluster_id']]['verdetto_finale'] for r in lette]
misura(a, b, "originale contro retest2")
for r, x, y in zip(lette, a, b):
    if x != y: print(f"    disaccordo {r['file']:40s} originale={x:10s} retest2={y}")
print("\n########## PARTE 2: l'umano con le stringhe grezze, che il modello non aveva ##########")
camb = [r for r in lette if norm(r['verdetto_dopo_parte2']) in CLASSI and norm(r['verdetto_dopo_parte2']) != norm(r['verdetto_parte1'])]
print(f"verdetti cambiati dall'umano dopo la parte 2: {len(camb)} su {len(lette)}")
for r in camb: print(f"    {r['file']:40s} {norm(r['verdetto_parte1'])} -> {norm(r['verdetto_dopo_parte2'])}")
confronta('originale', orig, 'verdetto_dopo_parte2')
print("\n########## TOTALI E STUDI ACCUSATI (parte 1) ##########")
for nome, v in [('umano parte 1', verdetti_umano('verdetto_parte1')), ('umano dopo parte 2', verdetti_umano('verdetto_dopo_parte2')),
                ('originale', a), ('retest2', b)]:
    print(f"  {nome:20s} " + "  ".join(f"{c} {v.count(c)}" for c in CLASSI))
tu = to = tc = 0
for r in lette:
    u = {s.strip() for s in r['studi_difettosi_parte1'].split(';') if s.strip()}
    m, q = dif_orig.get(r['cluster_id'], set()), dif_ret.get(r['cluster_id'], set())
    tu += len(u); to += len(m); tc += len(u & m)
    if u or m or q: print(f"  {r['file']:36s} umano={sorted(u)} originale={sorted(m)} retest2={sorted(q)}")
print(f"  coppie gruppo-studio: umano {tu}, originale {to}, comuni {tc}")
