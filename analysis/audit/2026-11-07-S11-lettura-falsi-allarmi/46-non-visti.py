#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/46-non-visti.py
# Gli errori del riferimento corretto che la combinazione non segnala, per famiglia e per fonte.
# Uso: python3 -I analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/46-non-visti.py
import csv
from collections import Counter
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
es = {x['record_id']: x for x in csv.DictReader(open('analysis/audit/2026-11-07-S10b-metadati-campioni/40-esiti.csv'))}
rif = list(csv.DictReader(open(D + '41-riferimento-dopo-S11.csv')))
fam_s10 = {x['record_id']: x['famiglia'] for x in csv.DictReader(open('analysis/audit/2026-11-07-S10-rilevatore/40-esiti.csv'))}
nv = [r for r in rif if es[r['record_id']]['PROPOSTA'] != '1']
out = [f'errori nel riferimento corretto: {len(rif)} | visti dalla combinazione: {len(rif) - len(nv)} | non visti: {len(nv)}']
out.append(f"non visti, dalla rilettura di agosto: {sum(r['sessione'].startswith('S10') for r in nv)} | dalla lettura S11: {sum(r['sessione'] == 'S11' for r in nv)}")
def fam(r):
    f = r['categoria'] if r['sessione'] == 'S11' else fam_s10.get(r['record_id'], r['categoria'])
    return 'tempo (zero o non appaiato)' if 'tempo' in f else f
out.append('non visti per famiglia:')
for k, v in Counter(fam(r) for r in nv).most_common(): out.append(f'  {v:3d}  {k}')
out.append('non visti S11 per famiglia: ' + str(Counter(r['categoria'] for r in nv if r['sessione'] == 'S11').most_common()))
open(D + '46-out.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
