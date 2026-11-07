#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/22-tempo-zero.py
# Censimento dei confronti con un controllo a tempo zero, sui 1.903 confronti, con tre fonti (00-previsioni.md):
#   s1  = Stadio 1: tutti i controlli con un tempo sono a 0 o is_zero_timepoint, e un trattato ha un tempo > 0;
#   eti = etichetta del controllo con un tempo zero, etichetta del trattato senza;
#   geo = metadati GEO (titolo + sorgente + caratteristiche) di TUTTI i controlli con un tempo zero, di nessun trattato.
# Sono candidati: la decisione 1 del PI si applica dopo la lettura.
# Uso: python3 analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/22-tempo-zero.py
import csv, gzip, json, re
from collections import Counter
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
B = 'analysis/audit/2026-11-07-S10b-metadati-campioni/'
conf = list(csv.DictReader(open(B + '20-confronti.csv')))
es = {x['record_id']: x for x in csv.DictReader(open(B + '40-esiti.csv'))}
F = {}
for l in gzip.open(B + '20-fatti.jsonl.gz', 'rt'):
    j = json.loads(l); F[j['record_id']] = j['parsed_json']
G = {r['gsm']: r for r in csv.DictReader(gzip.open(D + '21-metadati-geo.csv.gz', 'rt'))}

ZERO = re.compile(r'(time[ _-]?zero|\b0 ?(h|hr|hrs|hour|hours|min|mins|minute|minutes|d|day|days)\b'
                  r'|\b(day|d)[ _-]?0\b(?![.,]?\d)|\b(t|time|timepoint|time point|time_point)[ :=_-]*0\b(?![.,]\d)'
                  r'|baseline|pre-?treat|pre-?stim|before (treatment|stimulation))', re.I)

def ore(g):
    h = []; z = False
    for p in (F[g].get('perturbations') or []):
        d = p.get('duration') or {}
        v = d.get('value_hours')
        if isinstance(v, list): v = v[0] if v else None
        if v is not None: h.append(float(v))
        if d.get('is_zero_timepoint'): z = True
    return h, z

def testo(g):
    r = G.get(g)
    return '' if r is None else ' | '.join([r['title'] or '', r['source'] or '', r['characteristics'] or ''])

out = []
for c in conf:
    gt = c['gsm_t'].split(','); gc = c['gsm_c'].split(',')
    th = [ore(g) for g in gt]; ch = [ore(g) for g in gc]
    info = [x for x in ch if x[0] or x[1]]
    s1 = len(info) > 0 and all(x[1] or (x[0] and max(x[0]) == 0) for x in info) and any(x[0] and max(x[0]) > 0 for x in th)
    eti = bool(ZERO.search(c['cl'])) and not ZERO.search(c['tl'])
    geo = all(ZERO.search(testo(g)) for g in gc) and not any(ZERO.search(testo(g)) for g in gt)
    if s1 or eti or geo:
        e = es[c['record_id']]
        out.append(dict(cluster_id=c['cluster_id'], study=c['study'], record_id=c['record_id'], trattato=c['tl'],
                        controllo=c['cl'], insieme=e['insieme'], famiglia=e['famiglia'], PROPOSTA=e['PROPOSTA'],
                        s1=int(s1), eti=int(eti), geo=int(geo),
                        geo_controllo=testo(gc[0])[:300], geo_trattato=testo(gt[0])[:300]))
w = csv.DictWriter(open(D + '22-candidati-tempo-zero.csv', 'w'), fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print('candidati:', len(out), '| studi:', len({o['study'] for o in out}), '| meta-analisi:', len({o['cluster_id'] for o in out}))
print('per fonte (s1, eti, geo):', sorted(Counter((o['s1'], o['eti'], o['geo']) for o in out).items()))
print('per insieme:', dict(Counter(o['insieme'] for o in out)))
print('segnalati dalla combinazione:', sum(o['PROPOSTA'] == '1' for o in out))
print('solo geo, senza Stadio 1:', sum(o['geo'] and not o['s1'] for o in out))
for s, n in (('GSE126409', 11), ('GSE221804', 10)):
    print(f'controllo {s}: {sum(o["study"] == s for o in out)} su {n}')
