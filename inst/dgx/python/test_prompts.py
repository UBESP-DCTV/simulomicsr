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
from prompts import (render_user_message_name_cleanup, render_user_message_stage2,
                     render_user_message_stage2b)


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


def test_name_cleanup_fields_present_no_top_theme():
    # Porta 1:1 di R/name-cleanup.R::.build_name_cleanup_messages() — vedi
    # Task 10 RED_ALERT F6 (pulizia-nomi Stadio 3, scope A).
    rec = {
        "record_id": "cluster_L2_abc123",
        "current_label": "STR:carnitine_exposed",
        "kind": "small_molecule",
        "member_metadata": "carnitine 10mM 24h treated | control untreated",
    }
    out = render_user_message_name_cleanup(rec)
    assert "current_label" not in out, "il nome del campo non deve comparire, solo il valore"
    assert "STR:carnitine_exposed" in out, "current_label deve comparire nel testo"
    assert "small_molecule" in out, "kind atteso deve comparire"
    assert "carnitine 10mM 24h treated" in out, "member_metadata deve comparire"
    assert "top_theme" not in out, "top_theme e' un oracolo indipendente, NON deve entrare nel prompt"


def test_stage2b_testo_identico():
    # Stadio 2b: il messaggio utente e' il testo congelato, byte per byte.
    testo = "# Comparison under review\nTreated arm label (from the pipeline): compound K17 1 \u00b5M\n\n[title] T1: a  b"
    out = render_user_message_stage2b({"record_id": "conf_1", "testo": testo})
    assert out == testo, "il testo dello Stadio 2b deve passare identico"
    for cattivo in ({"record_id": "conf_2"}, {"record_id": "conf_3", "testo": ""}):
        try:
            render_user_message_stage2b(cattivo)
        except (KeyError, ValueError):
            pass
        else:
            raise AssertionError("un record senza testo deve fermare il runner")


def test_count_prompt_tokens_lista_e_dizionario():
    # Il conteggio accetta la lista di token (MistralTokenizer di vLLM) e il
    # dizionario con input_ids (tokenizer HF che restituisce un BatchEncoding).
    from run_p4_vllm import count_prompt_tokens

    class TokLista:
        def apply_chat_template(self, messages, tools=None, **kw):
            assert kw.get("add_generation_prompt") is True
            return list(range(len(messages[-1]["content"])))

    class TokDict:
        def apply_chat_template(self, conversation, **kw):
            return {"input_ids": [1] * 7, "attention_mask": [1] * 7}

    conv = [{"role": "system", "content": "s"}, {"role": "user", "content": "abcde"}]
    assert count_prompt_tokens(TokLista(), conv) == 5
    assert count_prompt_tokens(TokDict(), conv) == 7


if __name__ == "__main__":
    test_strip_member_sample_ids()
    test_chunk_line()
    test_name_cleanup_fields_present_no_top_theme()
    test_stage2b_testo_identico()
    test_count_prompt_tokens_lista_e_dizionario()
    print("OK -- 5/5 sanity render_user_message_stage2/name_cleanup/stage2b, conteggio token")
