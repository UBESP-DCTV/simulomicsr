#!/usr/bin/env python3
"""05-diagnosi-v0.py - S12r2, diagnosi PRIMA della correzione (handout S12r2, punto 3).

Dove nascono due errori del lettore v0: il fattore letto dal titolo con un livello per campione, e la base
scritta senza campioni. Legge solo materiale v0 dei 47 studi di sviluppo (vista e uscita della corsa 1), gia'
visto in S12r. Nessuna corsa nuova, nessuno studio di giudizio.

Uso: python3 analysis/audit/2026-11-10-S12r2-prova-ripetuta/05-diagnosi-v0.py > .../05-out.txt
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

print('== A. Il fattore con un livello per campione ==')
print('studio | n | ruolo di title | colonne con un valore per campione (ruolo) | fattori per campione (tipo; fonti; livelli)')
tab = collections.Counter(); righe = []
for g in sorted(viste):
    v, u = viste[g], usc[g]; n = len(v['campioni'])
    ruolo = {k['column']: k['role'] for k in u['columns']}
    uniche = [c for c in v['tabella'] if len(set(col(v, c))) == n and n > 1]
    fonti_tutte = [c for f in u['factors'] for c in f['source_columns']]
    per_camp = []
    for f in u['factors']:
        nl = len(f['levels'])
        # un livello per campione: i livelli scritti sono almeno quanti i campioni, oppure piu' di meta' con
        # ogni fonte unica per campione
        fonte_unica = any(c in uniche or c == 'gsm' for c in f['source_columns'])
        if n > 2 and (nl >= n or (fonte_unica and nl > n / 2)):
            per_camp.append((f['name'], f['type'], f['source_columns'], nl))
    t_ruolo = ruolo.get('title', '(assente)')
    t_fonte = 'title' in fonti_tutte
    # i fattori che usano title come fonte e NON sono per campione
    buoni_da_titolo = [f['name'] for f in u['factors'] if 'title' in f['source_columns']
                       and f['name'] not in [p[0] for p in per_camp]]
    tab[(t_ruolo, bool(per_camp))] += 1
    righe.append((g, n, t_ruolo, t_fonte, uniche, per_camp, buoni_da_titolo, ruolo))
    if per_camp:
        print(f"{g} | {n} | {t_ruolo} | {'; '.join(f'{c} ({ruolo.get(c)})' for c in uniche)} | "
              + ' || '.join(f"{a} ({b}; {','.join(c)}; {d})" for a, b, c, d in per_camp)
              + (f" | altri fattori dal titolo: {','.join(buoni_da_titolo)}" if buoni_da_titolo else ''))
print('\nruolo dato a `title` contro «lo studio ha un fattore per campione»:')
for k in sorted(tab): print(f'  title={k[0]:14s} fattore per campione={k[1]}: {tab[k]} studi')
n_pc = sum(1 for r in righe if r[5])
print(f'studi con almeno un fattore per campione: {n_pc} su 47')
print('\nnei', n_pc, 'studi: tipo e nome del fattore per campione')
print(collections.Counter((p[1], p[0]) for r in righe for p in r[5]).most_common())
print('\nnei', n_pc, 'studi: la colonna fonte del fattore per campione ha ruolo')
print(collections.Counter(r[7].get(c, 'costante/gsm') for r in righe for p in r[5] for c in p[2]).most_common())
print('\nil titolo e\' fonte di un fattore che NON e\' per campione (uso legittimo):',
      sum(1 for r in righe if r[6]), 'studi:', ', '.join(r[0] for r in righe if r[6]))
print('title ha ruolo `factor` ma nessun fattore lo usa come fonte:',
      sum(1 for r in righe if r[2] == 'factor' and not r[3]), 'studi')
print('title ha ruolo `factor`:', sum(1 for r in righe if r[2] == 'factor'), 'studi; `replicate`:',
      sum(1 for r in righe if r[2] == 'replicate'), '; `uninformative`:', sum(1 for r in righe if r[2] == 'uninformative'),
      '; `subject`:', sum(1 for r in righe if r[2] == 'subject'), '; title costante o assente:',
      sum(1 for r in righe if r[2] == '(assente)'))
# la domanda della diagnosi: dove title ha ruolo factor, c'era un'altra colonna con la stessa informazione?
print('\nstudi con title=`factor`: il fattore dal titolo ripete una partizione gia\' data da altre colonne?')
for g, n, t_ruolo, t_fonte, uniche, per_camp, buoni, ruolo in righe:
    if t_ruolo != 'factor': continue
    v, u = viste[g], usc[g]
    altre = [c for c in v['tabella'] if c != 'title' and 1 < len(set(col(v, c))) < n]
    print(f"  {g}: n={n}; altre colonne non costanti e non uniche: {len(altre)}; fattori con fonte title: "
          + ', '.join(f"{f['name']}({f['type']},{len(f['levels'])} livelli)" for f in u['factors'] if 'title' in f['source_columns']))

print('\n== B. La base scritta senza campioni ==')
print('studio | fattore (tipo) | base | la base e\' fra i livelli | voci col livello di base | voci di forma giusta col livello di base | di queste, con valori presenti nella tabella | causa')
cause = collections.Counter(); studi_causa = collections.defaultdict(set)
for g in sorted(viste):
    v, u = viste[g], usc[g]; gsm = v['campioni']
    for f in u['factors']:
        b = f['baseline_level']
        if not b: continue
        liv = [l['level'] for l in f['levels']]
        fonti = f['source_columns']
        cols = [col(v, c) for c in fonti]
        if any(c is None for c in cols): continue
        chiavi = set(zip(*cols)) if cols else set()
        voci_b = [a for a in f['assignment'] if a['level'] == b]
        giuste = [a for a in voci_b if len(a['values']) == len(fonti)]
        presenti = [a for a in giuste if tuple(a['values']) in chiavi]
        if b in liv and presenti: continue          # la base ha campioni
        if b not in liv: causa = 'base non fra i livelli'
        elif not voci_b: causa = 'nessuna voce assegna la base (base che lo studio non ha)'
        elif not giuste: causa = 'forma delle voci'
        else: causa = 'valori delle voci non presenti nella tabella'
        cause[causa] += 1; studi_causa[causa].add(g)
        print(f"{g} | {f['name']} ({f['type']}) | {b} | {b in liv} | {len(voci_b)} | {len(giuste)} | {len(presenti)} | {causa}")
        if causa.startswith('nessuna'):
            print(f"      evidenza scritta dal modello: «{f['baseline_evidence'][:160]}»; livelli: {liv[:8]}")
print('\nfattori per causa:', dict(cause))
print('studi per causa:', {k: len(s) for k, s in studi_causa.items()})
print('studi con almeno una base senza campioni:', len(set().union(*studi_causa.values())) if studi_causa else 0)
