#!/usr/bin/env python3
# 47-nome-del-modello.py — S9, dopo la seconda risposta del PI: che cosa scrive il
# modello (Stadio 1, perturbazioni del primo campione trattato) per i confronti dei
# gruppi con piu' nomi. Ingresso: 47-membri.csv (record_id, study, entity_off), scritto
# da 47-membri.R. Uscita: 47-out.txt.
# Uso: python3 -I analysis/audit/2026-11-07-S9-greche-e-corsie/47-nome-del-modello.py
import json, csv, collections, re
A = "analysis/audit/2026-11-07-S9-greche-e-corsie"
rows = list(csv.DictReader(open(f"{A}/47-membri.csv")))
studies = {r["study"] for r in rows}
need = {}
for ln in open("analysis/p4-output/A3-stage2-master-innestato.jsonl"):
    d = json.loads(ln)
    if d.get("series_id") not in studies: continue
    rg = {g["group_id"]: g for g in d.get("replicate_groups", [])}
    seen = collections.Counter()
    for c in d.get("comparisons", []):
        t, k = rg.get(c["treated_group"]), rg.get(c["control_group"])
        if not t or not k or not t.get("sample_ids") or not k.get("sample_ids"): continue
        seen[c["comparison_id"]] += 1
        need["%s__%s__%d" % (d["series_id"], c["comparison_id"], seen[c["comparison_id"]])] = t["sample_ids"][0]
gsm = collections.defaultdict(list)
for r in rows:
    if r["record_id"] in need: gsm[need[r["record_id"]]].append(r)
out = collections.defaultdict(collections.Counter); n_conf = collections.Counter()
for ln in open("analysis/p4-output/A3-stage1-master-innestato.jsonl"):
    m = re.match(r'\{"record_id"\s*:\s*"([^"]+)"', ln)
    if not m or m.group(1) not in gsm: continue
    d = json.loads(ln)
    def perturbazioni(o):
        if isinstance(o, str):
            try: o = json.loads(o)
            except Exception: return []
        if isinstance(o, dict):
            if isinstance(o.get("perturbations"), list): return o["perturbations"]
            for v in o.values():
                q = perturbazioni(v)
                if q: return q
        return []
    pert = []
    for p in perturbazioni(d):
        an = p.get("agent_normalized") or {}
        pert.append((p.get("agent_raw"), an.get("id"), an.get("preferred_name")))
    for r in gsm[m.group(1)]:
        n_conf[r["entity_off"]] += 1
        for p in pert:
            out[r["entity_off"]][f'{p[2]} [{p[1]}] <- {p[0]}'] += 1
L = ["nome scritto dal modello [ID scritto dal modello] <- agent_raw, per confronto del gruppo (primo campione trattato)"]
for e in sorted(out):
    L.append(f"== {e}: {n_conf[e]} confronti")
    for k, v in out[e].most_common(8): L.append(f"   {v:3d}  {k}")
open(f"{A}/47-out.txt", "w").write("\n".join(L) + "\n"); print("\n".join(L))
