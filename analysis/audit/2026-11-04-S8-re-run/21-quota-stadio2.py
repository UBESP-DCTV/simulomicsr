#!/usr/bin/env python3
# Quota dell'uscita dello Stadio 2 che appartiene agli studi di A3, nel master vecchio (senza flag).
# Serve a scalare il tempo misurato di A3 sul corpus intero: il tempo segue la lunghezza generata, non il numero di record.
import json
A3 = set(l.strip() for l in open("analysis/audit/2026-08-16-A3/A3-studi.txt") if l.strip())
tot = a3 = 0; n = na = 0
for l in open("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"):
    s = json.loads(l)["series_id"]
    n += 1; tot += len(l)
    if s in A3: na += 1; a3 += len(l)
print(f"master vecchio: {n} studi, {tot} caratteri; A3: {na} studi, {a3} caratteri; quota caratteri {a3/tot:.4f}; quota studi {na/n:.4f}")
