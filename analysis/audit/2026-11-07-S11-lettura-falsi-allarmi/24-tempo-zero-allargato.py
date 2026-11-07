#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/24-tempo-zero-allargato.py
# Aggiunta DOPO il deposito, dichiarata nel finding: la lettura ha mostrato che l'elenco di forme di 22-tempo-zero.py
# non vede il tempo zero attaccato ad altre lettere ("TGF0h", "_0HR_", "Day0"). Qui le forme senza confine di parola,
# su titolo, sorgente e caratteristiche GEO di tutti i controlli dei 1.903 confronti, fuori dai candidati gia' letti.
# Uso: python3 analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/24-tempo-zero-allargato.py
import csv, gzip, re
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
conf = list(csv.DictReader(open('analysis/audit/2026-11-07-S10b-metadati-campioni/20-confronti.csv')))
letti = {x['record_id'] for x in csv.DictReader(open(D + '23-ordine.csv'))}
G = {r['gsm']: r for r in csv.DictReader(gzip.open(D + '21-metadati-geo.csv.gz', 'rt'))}
Z = re.compile(r'(?<![0-9.])0 ?(h|hr|hrs|hour|hours|min|mins|d)(?![a-z])|(day|d|t|time|timepoint)[ :_=-]*0(?![0-9.,])|time ?zero|baseline|pre-?treat|untreated[ _-]?0', re.I)
def testo(g):
    r = G.get(g); return '' if r is None else ' | '.join([r['title'] or '', r['source'] or '', r['characteristics'] or ''])
out = []
for c in conf:
    if c['record_id'] in letti: continue
    gc = c['gsm_c'].split(','); gt = c['gsm_t'].split(',')
    if all(Z.search(testo(g)) for g in gc) and not any(Z.search(testo(g)) for g in gt):
        out.append(dict(record_id=c['record_id'], study=c['study'], trattato=c['tl'], controllo=c['cl'],
                        geo_c=testo(gc[0])[:250], geo_t=testo(gt[0])[:250]))
w = csv.DictWriter(open(D + '24-candidati-allargati.csv', 'w'), fieldnames=['record_id', 'study', 'trattato', 'controllo', 'geo_c', 'geo_t'])
w.writeheader(); w.writerows(out)
print('candidati nuovi:', len(out), '| studi:', len({o['study'] for o in out}))
for o in out: print(o['record_id'], '\n   T:', o['trattato'], '|', o['geo_t'][:160], '\n   C:', o['controllo'], '|', o['geo_c'][:160])
