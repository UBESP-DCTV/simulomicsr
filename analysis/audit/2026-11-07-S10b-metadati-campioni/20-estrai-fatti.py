#!/usr/bin/env python3
"""20-estrai-fatti.py - S10b: i fatti dello Stadio 1 dei campioni dei 1.903 confronti.

Legge il master A3 dello Stadio 1 (quello scritto in run_metadata.json dello Stadio 3 del
deliverable) e tiene il parsed_json dei GSM elencati in 20-gsm.txt. Calcola lo SHA-256 del
master mentre lo legge, per confrontarlo con quello di run_metadata.json.

Uscite: 20-fatti.jsonl.gz (un GSM per riga: record_id, valid_schema, parsed_json),
        20-estrai-out.txt (conteggi e SHA-256).

Uso: python3 -I analysis/audit/2026-11-07-S10b-metadati-campioni/20-estrai-fatti.py
"""
import gzip
import hashlib
import json
import os

OUT = "analysis/audit/2026-11-07-S10b-metadati-campioni"
MASTER = "analysis/p4-output/A3-stage1-master-innestato.jsonl"
META = "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159/run_metadata.json"

gsm = set(open(os.path.join(OUT, "20-gsm.txt")).read().split())
sha_atteso = json.load(open(META))["input_files"]["stage1_master"]["sha256"]

h = hashlib.sha256()
trovati, doppi, righe = {}, 0, 0
with open(MASTER, "rb") as f:
    for line in f:
        h.update(line)
        righe += 1
        # filtro veloce sul testo prima del parse
        i = line.find(b'"record_id": "')
        rid = line[i + 14: line.find(b'"', i + 14)].decode()
        if rid not in gsm:
            continue
        r = json.loads(line)
        if rid in trovati:
            doppi += 1
        trovati[rid] = {"record_id": rid, "valid_schema": r.get("valid_schema"),
                        "parsed_json": r.get("parsed_json")}

sha = h.hexdigest()
with gzip.open(os.path.join(OUT, "20-fatti.jsonl.gz"), "wt", encoding="utf-8") as g:
    for rid in sorted(trovati):
        g.write(json.dumps(trovati[rid], ensure_ascii=False) + "\n")

validi = sum(1 for v in trovati.values() if v["parsed_json"] is not None)
schema_ok = sum(1 for v in trovati.values() if v["valid_schema"] is True)
with open(os.path.join(OUT, "20-estrai-out.txt"), "w") as o:
    for s in [f"master: {MASTER}",
              f"righe lette: {righe}",
              f"SHA-256 letto:  {sha}",
              f"SHA-256 atteso: {sha_atteso}",
              f"SHA-256 coincide: {sha == sha_atteso}",
              f"GSM richiesti: {len(gsm)}",
              f"GSM trovati: {len(trovati)}",
              f"GSM con parsed_json: {validi}",
              f"GSM con valid_schema TRUE: {schema_ok}",
              f"record doppi nel master fra i richiesti: {doppi}",
              f"GSM mancanti: {sorted(gsm - set(trovati))[:20]}"]:
        print(s)
        o.write(s + "\n")
