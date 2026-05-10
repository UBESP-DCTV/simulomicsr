#!/usr/bin/env python3
"""Smoke vLLM: carica Mistral-Small-3.2-24B su 1 GPU e genera 1 prompt.

Mistral-Small-3.2 e' multimodale (Mistral3Config) e richiede:
  - tokenizer_mode="mistral" (usa Tekken/mistral_common, NON HF AutoTokenizer)
  - config_format="mistral" / load_format="mistral"
  - llm.chat() (non llm.generate() con apply_chat_template, perche' il
    MistralTokenizer non implementa quel metodo).
"""
from __future__ import annotations

import json
import sys
import time

MODEL_ID = "mistralai/Mistral-Small-3.2-24B-Instruct-2506"


def main() -> int:
    print(f"[smoke] modello: {MODEL_ID}", flush=True)
    import torch
    print(f"[smoke] torch: {torch.__version__} | cuda: {torch.cuda.is_available()}", flush=True)
    if not torch.cuda.is_available():
        print("[smoke] FAIL: CUDA non disponibile", flush=True)
        return 2
    print(f"[smoke] device: {torch.cuda.get_device_name(0)}", flush=True)

    from vllm import LLM, SamplingParams
    print("[smoke] vllm import OK", flush=True)

    print("[smoke] caricamento modello (puo' richiedere 1-3 min)...", flush=True)
    t0 = time.time()
    llm = LLM(
        model=MODEL_ID,
        tokenizer_mode="mistral",
        config_format="mistral",
        load_format="mistral",
        dtype="bfloat16",
        gpu_memory_utilization=0.90,
        tensor_parallel_size=1,
        max_model_len=4096,
    )
    print(f"[smoke] modello caricato in {time.time() - t0:.1f}s", flush=True)

    schema = {
        "type": "object",
        "properties": {
            "ack": {"type": "string"},
            "n":   {"type": "integer"},
        },
        "required": ["ack", "n"],
        "additionalProperties": False,
    }

    # Structured outputs: vLLM 0.20+ usa StructuredOutputsParams
    # (GuidedDecodingParams rimosso in v0.12.0). Backend selection auto.
    from vllm.sampling_params import StructuredOutputsParams
    sampling = SamplingParams(
        max_tokens=64,
        temperature=0.0,
        structured_outputs=StructuredOutputsParams(json=schema),
    )

    messages = [
        {"role": "system", "content": "Rispondi sempre solo in JSON valido conforme allo schema."},
        {"role": "user",   "content": "Restituisci JSON con ack='ok' e n=42."},
    ]

    print("[smoke] generazione 1 prompt...", flush=True)
    t0 = time.time()
    out = llm.chat(messages=messages, sampling_params=sampling)
    elapsed = time.time() - t0
    raw = out[0].outputs[0].text if out and out[0].outputs else ""
    print(f"[smoke] output raw: {raw!r}", flush=True)
    print(f"[smoke] tempo generazione: {elapsed:.2f}s", flush=True)

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[smoke] FAIL: output non e' JSON valido ({e})", flush=True)
        return 3

    print(f"[smoke] OK: parsed={parsed}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
