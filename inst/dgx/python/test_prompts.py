#!/usr/bin/env python3
"""Sanity test per prompts.render_user_message_stage2 (RED ALERT F4 opzione C).

Verifica che il renderer v3:
- NON includa member_sample_ids nel prompt (serve all'espansione locale, non al
  modello),
- mantenga geo_accession, n_replicates, condition_id, sample_facts,
- renderizzi correttamente i record chunkati (riga "chunk: X/Y").

Esecuzione:  cd inst/dgx/python && python3 test_prompts.py
"""
import json
from prompts import render_user_message_stage2


def _v3_record(chunked=False):
    rec = {
        "record_id": "GSE1#1of3" if chunked else "GSE1",
        "series_id": "GSE1",
        "study_summary": "",
        "samples": [
            {
                "geo_accession": "GSM1",
                "sample_facts": {"series_id": "GSE1", "perturbations": []},
                "n_replicates": 5,
                "member_sample_ids": ["GSM1", "GSM2", "GSM3", "GSM4", "GSM5"],
                "condition_id": "cond_0001",
            }
        ],
    }
    if chunked:
        rec["chunk_metadata"] = {
            "part": 1, "total_parts": 3, "original_record_key": "GSE1",
            "broadcast_condition_ids": ["cond_0001"],
        }
    return rec


def test_strip_member_sample_ids():
    out = render_user_message_stage2(_v3_record())
    assert "member_sample_ids" not in out, "member_sample_ids non deve essere nel prompt"
    assert "GSM3" not in out and "GSM5" not in out, "i GSM membri non devono comparire"
    assert "n_replicates" in out, "n_replicates deve restare"
    assert '"geo_accession":"GSM1"' in out, "geo_accession (rappresentante) deve restare"
    assert "condition_id" in out, "condition_id deve restare"
    assert "perturbations" in out, "sample_facts deve restare"


def test_chunk_line():
    out = render_user_message_stage2(_v3_record(chunked=True))
    assert "chunk: 1/3" in out, "riga chunk: X/Y attesa per record chunkato"
    assert "member_sample_ids" not in out


if __name__ == "__main__":
    test_strip_member_sample_ids()
    test_chunk_line()
    print("OK -- 2/2 sanity render_user_message_stage2 v3")
