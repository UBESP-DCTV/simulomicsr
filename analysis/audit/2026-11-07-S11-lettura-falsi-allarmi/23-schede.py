#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/23-schede.py
# Le schede di lettura: A = le 56 righe dell'elenco della S10b; B = i candidati a tempo zero fuori dall'elenco;
# C = i controlli depositati (00-previsioni.md). Ordine per studio, per leggere il disegno una volta.
# Uso: python3 analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/23-schede.py
import csv, gzip, json
from collections import defaultdict
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
B = 'analysis/audit/2026-11-07-S10b-metadati-campioni/'
R = 'analysis/audit/2026-08-20-rilettura-194/'
conf = {c['record_id']: c for c in csv.DictReader(open(B + '20-confronti.csv'))}
es = {x['record_id']: x for x in csv.DictReader(open(B + '40-esiti.csv'))}
fa = [x['record_id'] for x in csv.DictReader(open(B + '40-falsi-allarmi.csv'))]
tz = {x['record_id']: x for x in csv.DictReader(open(D + '22-candidati-tempo-zero.csv'))}
idx = {x['cluster_id']: x for x in csv.DictReader(open(R + 'INDICE-194.csv'))}
dif = defaultdict(list)
for x in csv.DictReader(open(R + 'difetti.csv')): dif[(x['cluster_id'], x['study_id'])].append(x)
G = {r['gsm']: r for r in csv.DictReader(gzip.open(D + '21-metadati-geo.csv.gz', 'rt'))}
grp = defaultdict(list)
for r in csv.DictReader(open(D + '20-gruppi.csv')): grp[r['study']].append(r)
F = {}
for l in gzip.open(B + '20-fatti.jsonl.gz', 'rt'):
    j = json.loads(l); F[j['record_id']] = j['parsed_json']

# controlli depositati: (studio, etichetta trattato, etichetta controllo)
CTRL = [('GSE139963', 'Hypoxia + TGF-β1', 'PBS (Vehicle Control)'), ('GSE97744', 'Circulating macrophage + IFN-γ and LPS', None),
        ('GSE210984', 'MSC iPSC-derived TGF-β 21 days', None), ('GSE139963', 'TGF-β1', 'PBS (Vehicle Control)'),
        ('GSE114686', 'Lapatinib 1 µM 24h', 'DMSO 0.001 µM 24h')]
ctrl = []
for s, t, c in CTRL:
    m = [r for r, x in conf.items() if x['study'] == s and x['tl'] == t and (c is None or x['cl'] == c)]
    assert len(m) >= 1, (s, t, c, len(m)); ctrl += m
sez = {}
for r in fa: sez[r] = 'A'
for r in tz:
    if r not in sez: sez[r] = 'B'
for r in ctrl: sez.setdefault(r, 'C')

def s1(g):
    p = F.get(g)
    if not p: return 'Stadio 1 assente'
    a = []
    for q in p.get('perturbations') or []:
        d = q.get('duration') or {}; v = d.get('value_hours')
        if isinstance(v, list): v = v[0] if v else None
        a.append(f"{q.get('agent_raw')}[{q.get('kind')}{',ctrl' if q.get('is_negative_control') else ''}"
                 f"{',h=' + str(v) if v is not None else ''}{',t0' if d.get('is_zero_timepoint') else ''}]")
    cc = p.get('cell_context') or {}
    return '; '.join(a) + f" | ctx={cc.get('context_kind')} pass={cc.get('passage_or_state')}"

def campioni(lista):
    righe = []
    for g in lista[:6]:
        r = G.get(g, {})
        righe.append(f"    {g} | T: {r.get('title', '')} | S: {r.get('source', '')} | C: {(r.get('characteristics') or '')[:260]}\n"
                     f"           S1: {s1(g)}")
    if len(lista) > 6: righe.append(f"    (+{len(lista) - 6} altri campioni)")
    return '\n'.join(righe)

ordine = sorted(sez, key=lambda r: (conf[r]['study'], conf[r]['cluster_id'], r))
out = []
for n, r in enumerate(ordine, 1):
    c = conf[r]; e = es[r]; i = idx.get(c['cluster_id'], {})
    det = ', '.join(f"{k}={e['det_' + k]}" for k in ('R1', 'R2a', 'R2b', 'R6') if e.get('det_' + k))
    reg = '+'.join(k for k in ('R1', 'R2a', 'R2b', 'R6') if e[k] == '1') + ('+V3pulita' if e['S10_pulita'] == '1' else '')
    t = tz.get(r)
    acc = dif.get((c['cluster_id'], c['study']), [])
    s = [f"=== [{n:03d}] sez.{sez[r]} | {c['study']} | {r}",
         f"meta-analisi: {i.get('nome')} ({c['entita']}, {i.get('verso')}, {i.get('controllo')}) {c['cluster_id']} | verdetto agosto: {i.get('verdetto')}",
         f"insieme S10: {e['insieme']} | famiglia: {e['famiglia']} | combinazione: {e['PROPOSTA']} [{reg}] | {det}",
         f"tempo zero: " + (f"s1={t['s1']} eti={t['eti']} geo={t['geo']}" if t else 'non candidato'),
         f"TRATTATO : {c['tl']}  (n={len(c['gsm_t'].split(','))})", campioni(c['gsm_t'].split(',')),
         f"CONTROLLO: {c['cl']}  (n={len(c['gsm_c'].split(','))})", campioni(c['gsm_c'].split(','))]
    for a in acc: s.append(f"  accusa di agosto (stesso gruppo e studio): {a['categoria']}: {a['etichetta'][:400]}")
    s.append('  gruppi dello studio (Stadio 2):')
    for g in grp[c['study']][:30]: s.append(f"    {g['group_id']} | {g['ruolo']} | n={g['n']} | {g['label']}")
    if len(grp[c['study']]) > 30: s.append(f"    (+{len(grp[c['study']]) - 30} altri gruppi)")
    out.append('\n'.join(s))
open(D + '23-schede.txt', 'w').write('\n\n'.join(out) + '\n')
from collections import Counter
print('schede:', len(ordine), dict(Counter(sez.values())), '| studi:', len({conf[r]['study'] for r in ordine}))
csv.writer(open(D + '23-ordine.csv', 'w')).writerows([['n', 'sezione', 'record_id']] + [[n, sez[r], r] for n, r in enumerate(ordine, 1)])
