#!/usr/bin/env python3
"""06-forma-voci-v0.py - S12r2, diagnosi PRIMA della correzione: la forma delle voci di `assignment` nel v0.

Per ogni fattore scritto dal lettore v0 (corsa 1, 47 studi di sviluppo): quante colonne di fonte ha e che forma
hanno le voci. Lo schema v0 chiede `values[]` posizionale, lungo quanto `source_columns`, senza vincolo di
lunghezza. Legge solo materiale gia' visto in S12r. Nessuna corsa nuova, nessuno studio di giudizio.

Uso: python3 analysis/audit/2026-11-10-S12r2-prova-ripetuta/06-forma-voci-v0.py > .../06-out.txt
"""
import json, collections
A0 = 'analysis/audit/2026-11-09-lettore-studio/'
viste = {}
for l in open(A0 + '60-viste-v0.jsonl', encoding='utf-8'):
    r = json.loads(l); viste[r['record_id']] = r
usc = {}
for l in open('analysis/p4-output/S12r-lettore-v0/corsa1.jsonl', encoding='utf-8'):
    r = json.loads(l); usc[r['record_id']] = json.loads(r['raw'])
assert len(viste) == 47 and set(viste) == set(usc)

def col(v, c):
    g = v['campioni']
    if c == 'gsm': return g
    if c in v['tabella']: return [v['tabella'][c][x] for x in g]
    if c in v['costanti']: return [v['costanti'][c]] * len(g)
    return None

GIUSTA = 'giusta'
STESSA = 'piu valori della stessa colonna -> un livello'
ALTRI = 'piu valori, non tutti nella colonna'
n_fonti = collections.Counter(); forma = collections.Counter()
studi_forma = collections.defaultdict(set); dettaglio = []; studi_non_giusti = set()
for g in sorted(viste):
    v, u = viste[g], usc[g]
    for f in u['factors']:
        k = len(f['source_columns']); n_fonti[k] += 1
        valori = set(col(v, f['source_columns'][0]) or []) if k == 1 else set()
        conta = collections.Counter()
        for a in f['assignment']:
            if len(a['values']) == k: conta[GIUSTA] += 1
            elif k == 1 and all(x in valori for x in a['values']): conta[STESSA] += 1
            else: conta[ALTRI] += 1
        non_giuste = [c for c in conta if c != GIUSTA]
        if not non_giuste:
            forma[(k, 'tutte giuste')] += 1
        else:
            for c in non_giuste:
                forma[(k, c)] += 1; studi_forma[(k, c)].add(g)
            studi_non_giusti.add(g)
            dettaglio.append((g, f['name'], f['type'], k, dict(conta)))

print('fattori per numero di colonne di fonte:', dict(sorted(n_fonti.items())))
print('\nfattori per (colonne di fonte, forma delle voci):')
for (k, c) in sorted(forma):
    ns = len(studi_forma[(k, c)]) if c != 'tutte giuste' else '-'
    print(f'  {k} colonne | {c:55s} | {forma[(k, c)]:3d} fattori | {ns} studi')
print('\ndettaglio dei fattori con voci non giuste:')
for d in dettaglio: print('  ', *d)
print('\nstudi con almeno un fattore con voci non giuste:', len(studi_non_giusti))
