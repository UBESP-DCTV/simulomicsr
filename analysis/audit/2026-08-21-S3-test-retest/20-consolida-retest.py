#!/usr/bin/env python3
# analysis/audit/2026-08-21-S3-test-retest/20-consolida-retest.py
# Dal JSON persistito del workflow di retest ai due CSV, con le stesse colonne del
# run originale (30-consolida.py di 2026-08-20-rilettura-194).
# Uso: python3 20-consolida-retest.py <wf_XXXX.json>
import json, sys, csv, os, collections
SRC = sys.argv[1]
S = 'analysis/audit/2026-08-21-S3-test-retest'
d = json.load(open(SRC, errors='ignore'))
gruppi = d['result']['gruppi']
meta = {k: d.get(k) for k in ('runId', 'timestamp', 'workflowName', 'agentCount', 'durationMs',
                              'defaultModel', 'totalTokens', 'status')}
json.dump({**meta, 'result': d['result'], 'logs': d.get('logs')},
          open(os.path.join(S, 'risultato-retest.json'), 'w'), ensure_ascii=False, indent=1)
print(f"run {meta['runId']} {meta['status']}: {len(gruppi)} gruppi, {meta['agentCount']} agenti, "
      f"{(meta['durationMs'] or 0)/60000:.1f} min, {meta['totalTokens']} token")
with open(os.path.join(S, 'verdetti-retest.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['cluster_id', 'verdetto_finale', 'n_studi_difettosi', 'etichetta_non_chiude',
                'rilievi_accettati', 'rilievi_respinti', 'motivo'])
    for g in gruppi:
        w.writerow([g['cluster_id'], g['verdetto_finale'], len(g.get('studi_difettosi', [])),
                    g.get('etichetta_non_chiude', False), g.get('rilievi_accettati', ''),
                    g.get('rilievi_respinti', ''), g['motivo']])
righe = [{'cluster_id': g['cluster_id'], 'study_id': s['study_id'], 'categoria': s['categoria'],
          'etichetta': s['etichetta_citata']} for g in gruppi for s in g.get('studi_difettosi', [])]
with open(os.path.join(S, 'difetti-retest.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['cluster_id', 'study_id', 'categoria', 'etichetta'])
    w.writeheader(); w.writerows(righe)
c = collections.Counter(g['verdetto_finale'] for g in gruppi)
print("verdetti:", dict(c), "| coppie gruppo-studio accusate:", len(righe),
      "| gruppi con >=1 difetto:", len({r['cluster_id'] for r in righe}),
      "| etichetta_non_chiude:", sum(1 for g in gruppi if g.get('etichetta_non_chiude')))
dup = [k for k, v in collections.Counter(g['cluster_id'] for g in gruppi).items() if v > 1]
if dup: print("ATTENZIONE cluster_id duplicati:", dup)
