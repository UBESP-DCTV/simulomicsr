#!/usr/bin/env python3
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/20-studi.py
# Il disegno degli studi dei 1.903 confronti: tutti i gruppi dello Stadio 2 (master A3) con etichetta, ruolo e
# campioni. Serve alla scheda di lettura (gli altri gruppi dello studio) e al censimento a tempo zero.
# Attenzione: sample_ids puo' essere una stringa sola invece di una lista (scalari-come-array).
# Uso: python3 analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/20-studi.py
import csv, json, hashlib
D = 'analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/'
S2 = 'analysis/p4-output/A3-stage2-master-innestato.jsonl'
conf = list(csv.DictReader(open('analysis/audit/2026-11-07-S10b-metadati-campioni/20-confronti.csv')))
studi = {c['study'] for c in conf}
h = hashlib.sha256(); righe = []; trovati = set()
with open(S2, 'rb') as f:
    for b in f:
        h.update(b)
        j = json.loads(b)
        s = j.get('series_id')
        if s not in studi: continue
        trovati.add(s)
        for g in j.get('replicate_groups') or []:
            ids = g.get('sample_ids')
            if isinstance(ids, str): ids = [ids]
            righe.append(dict(study=s, group_id=g.get('group_id'), label=g.get('label_human') or '',
                              ruolo=g.get('primary_role') or '', n=len(ids or []), gsm=','.join(ids or []),
                              disegno=j.get('design_summary') or ''))
w = csv.DictWriter(open(D + '20-gruppi.csv', 'w'), fieldnames=list(righe[0].keys())); w.writeheader(); w.writerows(righe)
print('SHA-256 master Stadio 2:', h.hexdigest())
print('studi dei 1.903:', len(studi), '| trovati nel master:', len(trovati), '| gruppi:', len(righe),
      '| campioni:', len({x for r in righe for x in r['gsm'].split(',') if x}))
