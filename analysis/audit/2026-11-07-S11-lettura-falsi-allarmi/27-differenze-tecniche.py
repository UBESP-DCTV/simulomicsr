#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/27-differenze-tecniche.py
# Censimento delle differenze tecniche fra i bracci, sui 1.903 confronti (decisione del PI, 2026-11-07).
# Un campo differisce se i due bracci hanno valori non vuoti senza nessun valore in comune. Campi: strumento,
# selezione, fonte e strategia della libreria, molecola, piattaforma. Marcatori nel testo (titolo, sorgente,
# caratteristiche; il protocollo di estrazione si confronta come campo): 4sU, paired/single-end, total RNA, polyA, nuclear/cytoplasmic.
# Un marcatore conta se sta in tutti i campioni di un braccio e in nessuno dell'altro. Sono candidati: si leggono.
# Uso: python3 -I analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/27-differenze-tecniche.py
import csv, gzip, re
from collections import Counter
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
conf = list(csv.DictReader(open('analysis/audit/2026-11-07-S10b-metadati-campioni/20-confronti.csv')))
T = {r['gsm']: r for r in csv.DictReader(gzip.open(D + '26-campi-tecnici.csv.gz', 'rt'))}
G = {r['gsm']: r for r in csv.DictReader(gzip.open(D + '21-metadati-geo.csv.gz', 'rt'))}
CAMPI = ['instrument_model', 'library_selection', 'library_source', 'library_strategy', 'molecule_ch1', 'platform_id', 'extract_protocol_ch1']
MARC = {'4sU': re.compile(r'4[ -]?su\b|4[ -]?thiouridine|metabolic(ally)? label', re.I),
        'paired-end': re.compile(r'paired[ -]?end|library type: paired', re.I),
        'single-end': re.compile(r'single[ -]?end|library type: single', re.I),
        'total RNA': re.compile(r'total ?rna ?seq|totalrnaseq|ribo-?zero|rrna deplet', re.I),
        'polyA': re.compile(r'poly ?\(?a\)?[ +-]?(selected|selection|enriched|rna|mrna)|oligo ?\(?dt', re.I)}
def val(g, c):
    r = T.get(g); v = (r or {}).get(c) or ''
    return v.strip().lower()
def testo(g):
    a = G.get(g, {}); b = T.get(g, {})
    # il protocollo di estrazione e' di solito uguale in tutto lo studio: si confronta come campo, non come testo
    return ' | '.join([a.get('title') or '', a.get('source') or '', a.get('characteristics') or ''])
out = []
for c in conf:
    gt = c['gsm_t'].split(','); gc = c['gsm_c'].split(',')
    diff = []
    for k in CAMPI:
        vt = {val(g, k) for g in gt} - {''}; vc = {val(g, k) for g in gc} - {''}
        if vt and vc and not (vt & vc): diff.append(f'{k}: {sorted(vt)} vs {sorted(vc)}')
    for k, rx in MARC.items():
        at = [bool(rx.search(testo(g))) for g in gt]; ac = [bool(rx.search(testo(g))) for g in gc]
        if (all(at) and not any(ac)) or (all(ac) and not any(at)): diff.append(f'marcatore {k}: trattato {sum(at)}/{len(at)}, controllo {sum(ac)}/{len(ac)}')
        elif any(at) != any(ac) or (any(at) and not all(at)) or (any(ac) and not all(ac)):
            if any(at) or any(ac): diff.append(f'marcatore {k} misto: trattato {sum(at)}/{len(at)}, controllo {sum(ac)}/{len(ac)}')
    if diff:
        out.append(dict(record_id=c['record_id'], cluster_id=c['cluster_id'], study=c['study'], trattato=c['tl'], controllo=c['cl'], differenze=' || '.join(diff)))
w = csv.DictWriter(open(D + '27-candidati-tecnici.csv', 'w'), fieldnames=['record_id', 'cluster_id', 'study', 'trattato', 'controllo', 'differenze'])
w.writeheader(); w.writerows(out)
print('candidati:', len(out), '| studi:', len({o['study'] for o in out}), '| meta-analisi:', len({o['cluster_id'] for o in out}))
print('per tipo:', Counter(d.split(':')[0] for o in out for d in o['differenze'].split(' || ')).most_common())
for s in ('GSE105951', 'GSE132782'):
    print('controllo', s, [o['record_id'][-40:] for o in out if o['study'] == s])
