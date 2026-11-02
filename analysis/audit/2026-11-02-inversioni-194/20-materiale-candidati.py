#!/usr/bin/env python3
# analysis/audit/2026-11-02-inversioni-194/20-materiale-candidati.py
#
# Per ogni studio candidato scrive, in candidati/, che cosa dicono i metadati grezzi
# dei due bracci di ogni suo confronto nel gruppo: etichetta dello Stadio 2, e per
# ciascun braccio i titoli e i valori distinti di sorgente e caratteristiche, senza
# campioni ripetuti. E' il materiale per classificare a mano (classi in 00-previsioni.md).
#
# Uso: python3 analysis/audit/2026-11-02-inversioni-194/20-materiale-candidati.py
import csv, os, re, collections, sys
csv.field_size_limit(sys.maxsize)
A = 'analysis/audit/2026-11-02-inversioni-194'
C = 'analysis/audit/2026-08-20-rilettura-194/campioni-per-meta-analisi.csv'
os.makedirs(f'{A}/candidati', exist_ok=True)
cand = {}
for r in csv.DictReader(open(f'{A}/inversioni-per-studio.csv')):
    if r['candidato'] == 'TRUE': cand[(r['cluster_id'], r['study_id'])] = ('studio', r)
for r in csv.DictReader(open(f'{A}/inversioni-per-braccio.csv')):
    if r['candidato'] == 'TRUE': cand.setdefault((r['cluster_id'], r['study_id']), ('braccio', r))
righe = collections.defaultdict(list)
for r in csv.DictReader(open(C)):
    if (r['cluster_id'], r['studio']) in cand:
        righe[(r['cluster_id'], r['studio'])].append(r)
def ripulisci(t): return re.sub(r'\s+', ' ', t or '').strip()
def blocco(rr):
    out = []
    titoli = [ripulisci(x['h5_titolo']) for x in rr]
    out.append(f"    titoli ({len(rr)}): " + ' | '.join(titoli[:6]) + (' | ...' if len(titoli) > 6 else ''))
    for campo in ('h5_sorgente', 'h5_caratteristiche'):
        c = collections.Counter(ripulisci(x[campo])[:230] for x in rr)
        for v, n in c.most_common(5): out.append(f"    {n:3d}x {campo[3:]}: {v}")
        if len(c) > 5: out.append(f"    ... altri {len(c)-5} valori distinti di {campo[3:]}")
    return out
mancanti = 0
for (cid, sid), (livello, r) in sorted(cand.items(), key=lambda kv: float(kv[1][1]['rho_tutti'] or 0)):
    rr = righe.get((cid, sid), [])
    if not rr: mancanti += 1
    L = [f"{r['nome']} | {cid} | {sid} | candidato a livello {livello} | controllo {r['controllo']}",
         f"rho_tutti={float(r['rho_tutti']):.2f} rho_top={float(r['rho_top']):.2f}" + (f" k={r['k']} altri_negativi={r['n_altri_negativi']}/{r['n_altri']}" if livello == 'studio' else f" braccio={r['braccio']} n={r['n_treated']}/{r['n_control']}"), '']
    conf = collections.defaultdict(lambda: collections.defaultdict(list))
    for x in rr: conf[x['confronto']][x['braccio']].append(x)
    for c, b in conf.items():
        L.append(f"CONFRONTO {c}")
        for br in ('TRATTATO', 'CONTROLLO'):
            if br in b:
                L.append(f"  {br}: «{ripulisci(b[br][0]['etichetta_braccio'])}»")
                L += blocco(b[br])
        L.append('')
    nome = re.sub(r'[^A-Za-z0-9._-]+', '_', r['nome'])[:30]
    open(f"{A}/candidati/{float(r['rho_tutti']):+.2f}_{sid}_{nome}.txt", 'w').write('\n'.join(L))
print(f"candidati: {len(cand)} | senza materiale: {mancanti}")
