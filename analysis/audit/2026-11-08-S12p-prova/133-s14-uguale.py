#!/usr/bin/env python3
# S12p, quinta parte (D9, spiegazione): per i 993 studi dei 1.903 confronti, gruppi e confronti del master S14 dello
# Stadio 2 sono identici a quelli del master A3? Uso: python3 analysis/audit/2026-11-08-S12p-prova/133-s14-uguale.py > .../133-out.txt
import json, csv, re
studi = set(r["study_id"] for r in csv.DictReader(open("analysis/audit/2026-11-08-S12p-prova/130-diagnosi.csv")))
def leggi(p):
    d = {}
    for l in open(p):
        m = re.search(r'"series_id": ?"([^"]+)"', l)
        if m and m.group(1) in studi: d[m.group(1)] = json.loads(l)
    return d
a = leggi("analysis/p4-output/A3-stage2-master-innestato.jsonl"); b = leggi("analysis/p4-output/S14-stage2-master.jsonl")
k = lambda r, c: json.dumps(r.get(c), sort_keys=True)
same = [s for s in studi if s in a and s in b and k(a[s], "replicate_groups") == k(b[s], "replicate_groups") and k(a[s], "comparisons") == k(b[s], "comparisons")]
print(f"studi: {len(studi)}; in A3: {len(a)}; in S14: {len(b)}; gruppi e confronti identici: {len(same)}")
