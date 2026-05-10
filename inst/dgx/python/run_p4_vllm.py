#!/usr/bin/env python3
"""Entry point P4: 4 worker data-parallel vLLM offline batch su DGX.

Architettura:
  - Argomenti: --bundle (path al bundle dir), --output (path output dir), --workers N
  - Legge bundle: manifest.json, generation.json, schema.json, prompt.txt, input.jsonl
  - Resume: scansiona output dir per record_id gia' completati
  - Sharding round-robin su N worker
  - Ogni worker: multiprocessing.Process con CUDA_VISIBLE_DEVICES=<i>
    - carica vLLM LLM(model=..., tokenizer_mode="mistral",
      config_format="mistral", load_format="mistral", dtype=bfloat16, ...)
    - SamplingParams(max_tokens=..., temperature=0,
      structured_outputs=StructuredOutputsParams(json=schema))  # vLLM 0.20+
    - llm.chat(messages=[[sys, user] per record]) — Mistral-3.2 NON supporta
      apply_chat_template (Tekken tokenizer).
    - scrive predictions.worker_<i>.jsonl append-only
  - Main: aspetta tutti, fa concat predictions.worker_*.jsonl -> predictions.jsonl,
    scrive run_summary.json
"""

from __future__ import annotations

import argparse
import json
import multiprocessing as mp
import os
import re
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Local modules (PYTHONPATH set in container env)
from prompts import build_messages, render_user_message_stage1, render_user_message_stage2
from resume import existing_record_ids, filter_input_records, shard_round_robin


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="P4 vLLM batch runner")
    p.add_argument("--bundle", required=True, help="Path al bundle dir (montato in /work/bundle).")
    p.add_argument("--output", required=True, help="Path output dir (montato in /work/run).")
    p.add_argument("--workers", type=int, default=4, help="Numero worker data-parallel.")
    return p.parse_args()


def load_bundle(bundle_dir: Path) -> dict[str, Any]:
    return {
        "manifest":   json.loads((bundle_dir / "manifest.json").read_text()),
        "generation": json.loads((bundle_dir / "generation.json").read_text()),
        "schema":     json.loads((bundle_dir / "schema.json").read_text()),
        "prompt":     (bundle_dir / "prompt.txt").read_text(),
        "input_path": bundle_dir / "input.jsonl",
    }


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    out = []
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def write_status(status_path: Path, payload: dict) -> None:
    payload = dict(payload)
    payload["updated_at"] = now_utc_iso()
    tmp = status_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2))
    tmp.replace(status_path)


def render_user_for_stage(stage: str, record: dict) -> str:
    if stage == "stage1":
        return render_user_message_stage1(record)
    if stage == "stage2":
        return render_user_message_stage2(record)
    raise ValueError(f"stage non noto: {stage!r}")


def worker_main(worker_id: int, gpu_index: int, bundle: dict, records: list[dict],
                output_dir: Path, predictions_path: Path) -> None:
    """Funzione eseguita in subprocess. Carica vLLM su una sola GPU e
    genera in batch sui record assegnati."""
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_index)
    # Mitigazione xgrammar guided-decoding stall (Task 22 stage2 stall
    # 2026-05-08, job 19778). Il default torch._dynamo cache_size_limit=8 e'
    # troppo basso per le shape variants del kernel
    # apply_token_bitmask_inplace_kernel_indices_torch_compile di xgrammar:
    # quando viene saturato, il kernel compilato viene evitto e xgrammar
    # ricade su un Python loop (CPU 99%, GPU 0%). Bumpando i due limit a
    # 256/1024 il fast path resta attivo per molte piu' shape variants.
    # NB: env vars vanno settate PRIMA di import torch.
    os.environ.setdefault("TORCHDYNAMO_CACHE_SIZE_LIMIT", "256")
    os.environ.setdefault("TORCHDYNAMO_ACCUMULATED_CACHE_SIZE_LIMIT", "1024")
    import torch._dynamo
    torch._dynamo.config.cache_size_limit = 256
    torch._dynamo.config.accumulated_cache_size_limit = 1024

    # Import vLLM solo qui (per non caricarlo nel main process)
    from vllm import LLM, SamplingParams

    gen = bundle["generation"]
    schema = bundle["schema"]
    stage = bundle["manifest"]["stage"]
    system_prompt = bundle["prompt"]

    print(f"[worker {worker_id}] caricamento vLLM su GPU {gpu_index}...", flush=True)
    # Backend di structured outputs in vLLM 0.20.2: default "auto"
    # (xgrammar con fallback automatico a outlines/guidance per casi non
    # supportati). Storico Task 22 (vLLM 0.10.0): xgrammar saturava
    # torch._dynamo cache_size_limit su stage2 (jobs 19778, 19800 stallo
    # GPU 0% / CPU 99%) e disable_guided_decoding=true era l'unica via.
    # Con v0.20.2 il fallback su outlines puo' rendere strict-schema viable
    # — ADR-0010 Phase 2 config 2b verifichera' su mini500-cs25.
    # Costruzione args con flag opzionali (enforce_eager, max_num_seqs):
    # enforce_eager=True disabilita CUDA graph capture (piu' lento ma piu'
    # stabile su sequenze lunghe — Task 22 v5 mitigazione 2026-05-08, dopo
    # stall ricorrente di vLLM scheduler dopo ~25-30 min di gen healthy).
    llm_kwargs = dict(
        model=gen["model_id"],
        dtype=gen["dtype"],
        tokenizer_mode=gen.get("tokenizer_mode", "mistral"),
        config_format=gen.get("config_format", "mistral"),
        load_format=gen.get("load_format", "mistral"),
        gpu_memory_utilization=float(gen["gpu_memory_utilization"]),
        tensor_parallel_size=int(gen["tensor_parallel_size"]),
        max_model_len=int(gen.get("max_model_len", 4096)),
    )
    if bool(gen.get("enforce_eager", False)):
        llm_kwargs["enforce_eager"] = True
        print(f"[worker {worker_id}] enforce_eager=True (no CUDA graphs)", flush=True)
    if "max_num_seqs" in gen and gen["max_num_seqs"] is not None:
        llm_kwargs["max_num_seqs"] = int(gen["max_num_seqs"])
        print(f"[worker {worker_id}] max_num_seqs={llm_kwargs['max_num_seqs']}", flush=True)
    # Task 22 stage2 follow-up 2026-05-08 (next session triage): flag opzionali
    # per testare hypotheses sulla causa del deadlock vLLM scheduler dopo
    # ~325 record/worker con prompt 20K+ token.
    # H1: enable_prefix_caching (default v1=true) si corrompe su prompt
    #     eterogenei lunghi → spiega "resume immediate stall" pattern.
    # H2: enable_chunked_prefill gestisce prompt 20K+ in chunked prefill
    #     incrementale → riduce KV pressure picco.
    # Solo settati se PRESENTI nel gen dict (default vLLM altrimenti).
    if "enable_prefix_caching" in gen and gen["enable_prefix_caching"] is not None:
        llm_kwargs["enable_prefix_caching"] = bool(gen["enable_prefix_caching"])
        print(f"[worker {worker_id}] enable_prefix_caching={llm_kwargs['enable_prefix_caching']}", flush=True)
    if "enable_chunked_prefill" in gen and gen["enable_chunked_prefill"] is not None:
        llm_kwargs["enable_chunked_prefill"] = bool(gen["enable_chunked_prefill"])
        print(f"[worker {worker_id}] enable_chunked_prefill={llm_kwargs['enable_chunked_prefill']}", flush=True)
    # scheduler_reserve_full_isl=False: workaround per vLLM Issue #39734
    # (scheduler v1 deadlock head-of-line per request entro max_model_len ma
    # > KV capacity disponibile). Bug ancora presente in vLLM 0.19.x. Path C
    # (chunk_size=25) evita gia' la zona-bug; questo flag e' defense-in-depth.
    if "scheduler_reserve_full_isl" in gen and gen["scheduler_reserve_full_isl"] is not None:
        llm_kwargs["scheduler_reserve_full_isl"] = bool(gen["scheduler_reserve_full_isl"])
        print(f"[worker {worker_id}] scheduler_reserve_full_isl={llm_kwargs['scheduler_reserve_full_isl']}", flush=True)
    llm = LLM(**llm_kwargs)

    # Param opzionali (presenti solo se override del default yaml).
    extra_kwargs: dict[str, Any] = {}
    if "repetition_penalty" in gen and gen["repetition_penalty"] is not None:
        extra_kwargs["repetition_penalty"] = float(gen["repetition_penalty"])
    if "top_p" in gen and gen["top_p"] is not None:
        extra_kwargs["top_p"] = float(gen["top_p"])
    if "min_p" in gen and gen["min_p"] is not None:
        extra_kwargs["min_p"] = float(gen["min_p"])

    # Guided decoding: API vLLM v0.20+ usa StructuredOutputsParams (rimpiazza
    # GuidedDecodingParams rimosso in v0.12.0). Backend selection automatica
    # (xgrammar default con fallback a outlines/guidance) — ADR-0010 Phase 2
    # config 2b verifichera' se outlines strict-schema raggiunge 100% validity
    # su Mistral-3.2.
    # Se gen["disable_guided_decoding"]=true (status quo stage2 da Task 22
    # 2026-05-08 per evitare xgrammar torch._dynamo saturation in 0.10.0), la
    # generazione e' free-JSON e la validazione schema avviene post-hoc.
    use_guided = not gen.get("disable_guided_decoding", False)
    if not use_guided:
        print(f"[worker {worker_id}] guided decoding DISABILITATO (free JSON, validate post-hoc)", flush=True)
    structured_params = None
    if use_guided:
        from vllm.sampling_params import StructuredOutputsParams
        structured_params = StructuredOutputsParams(json=schema)

    default_max_tokens = int(gen["max_tokens"])

    def _make_sampling(max_tok: int) -> SamplingParams:
        """Build SamplingParams per request. max_tok puo' essere per-record
        (tier-based, vedi `tiered_max_tokens=TRUE` in dgx_p4_build_bundle()) o
        il default globale gen[max_tokens]."""
        kw = dict(extra_kwargs)
        kw["max_tokens"]  = int(max_tok)
        kw["temperature"] = float(gen["temperature"])
        if use_guided:
            kw["structured_outputs"] = structured_params
        return SamplingParams(**kw)

    # Mistral tokenizer non supporta apply_chat_template. Usiamo llm.chat()
    # che accetta una lista di liste di messages e formatta internamente.
    # Per tiered max_tokens, costruiamo per-record SamplingParams (vLLM accetta
    # sampling_params come lista parallela a messages).
    conversations: list = []
    record_ids: list = []
    samplings: list = []  # one per conversation
    n_per_record_max_tokens = 0
    for r in records:
        user_msg = render_user_for_stage(stage, r)
        conversations.append(build_messages(system_prompt, user_msg))
        record_ids.append(str(r["record_id"]))
        rec_mt = r.get("max_tokens")
        if rec_mt is not None:
            n_per_record_max_tokens += 1
            samplings.append(_make_sampling(int(rec_mt)))
        else:
            samplings.append(_make_sampling(default_max_tokens))
    if n_per_record_max_tokens > 0:
        unique_mts = sorted({s.max_tokens for s in samplings})
        print(f"[worker {worker_id}] per-record max_tokens: "
              f"{n_per_record_max_tokens}/{len(samplings)} record con override, "
              f"valori distinti={unique_mts}", flush=True)

    # Micro-batch llm.chat (Task 22 stage2 mitigazione 2026-05-08, job 19801
    # stallato dopo 20 min di gen healthy). Un singolo llm.chat con tutti i
    # 1663 record / 20K prefill ciascuno entra in stato indeterminato dopo
    # qualche minuto (workers in futex_wait, GPU 0%, CPU 0%). Processandoli
    # a chunks di MICROBATCH la KV cache si drena tra un chunk e l'altro,
    # vediamo progress incrementale, e se un record specifico triggera un
    # bug vLLM lo isoliamo. Per stage1 (record corti) usa batch grande.
    MICROBATCH = int(gen.get("microbatch", 0)) or (None if stage == "stage1" else 50)
    print(f"[worker {worker_id}] generazione su {len(conversations)} record "
          f"(microbatch={MICROBATCH or 'all'})...", flush=True)
    t0 = time.time()

    def _strip_md_fences(s: str) -> str:
        # Mistral-3.2 free-gen (disable_guided_decoding=true) spesso wrappa
        # l'output in ```json ... ``` markdown fences. Strip difensivo per
        # rendere `json.loads` permissivo. NB: mantenere il raw originale
        # in `raw_output` per debug/audit; solo `parsed_json` usa la versione
        # stripped.
        s = s.strip()
        if s.startswith("```json"):
            s = s[7:].lstrip()
        elif s.startswith("```"):
            s = s[3:].lstrip()
        if s.endswith("```"):
            s = s[:-3].rstrip()
        return s

    # Pattern recovery heuristic identificato 2026-05-10 nei 17 residual α
    # stage2: Mistral-3.2 occasionalmente droppa il token "value": dentro
    # array factor_levels, producendo `{"key": "X", "RAWVAL"}` invece di
    # `{"key": "X", "value": "RAWVAL"}`. Il regex sotto re-inserisce "value":
    # solo dove il pattern e' inequivocabile (key + scalar value secondo
    # campo, niente piu' chiavi o oggetti). Su 17 residual recover 3/17 senza
    # alcun rischio semantico.
    _RX_MISSING_VALUE = re.compile(
        r'(\{\s*"key"\s*:\s*"[^"]+"\s*,\s*)("[^"]+")(\s*\})'
    )

    def _try_parse(s: str):
        """Restituisce (parsed_dict_or_None, applied_patches_list)."""
        applied = []
        try:
            return json.loads(s), applied
        except json.JSONDecodeError:
            pass
        # Tentativo 1: missing-value patch
        s2 = _RX_MISSING_VALUE.sub(r'\1"value": \2\3', s)
        if s2 != s:
            try:
                return json.loads(s2), ["missing_value"]
            except json.JSONDecodeError:
                pass
        return None, applied

    def _write_batch(rids, outs):
        with predictions_path.open("a", encoding="utf-8") as fh:
            for rid, out in zip(rids, outs):
                raw = out.outputs[0].text if out.outputs else ""
                cleaned = _strip_md_fences(raw)
                parsed, patches = _try_parse(cleaned)
                valid = parsed is not None
                row = {
                    "record_id": rid,
                    "raw_output": raw,
                    "parsed_json": parsed,
                    "valid_schema": valid,
                    "applied_patches": patches,
                    "worker_id": worker_id,
                    "ts": now_utc_iso(),
                }
                fh.write(json.dumps(row) + "\n")
            fh.flush()

    if MICROBATCH is None:
        outputs = llm.chat(messages=conversations, sampling_params=samplings)
        _write_batch(record_ids, outputs)
    else:
        n_total = len(conversations)
        for i in range(0, n_total, MICROBATCH):
            j = min(i + MICROBATCH, n_total)
            t_b = time.time()
            outs = llm.chat(messages=conversations[i:j],
                            sampling_params=samplings[i:j])
            _write_batch(record_ids[i:j], outs)
            print(f"[worker {worker_id}] microbatch {i+1}-{j}/{n_total} "
                  f"in {time.time()-t_b:.1f}s (cum {time.time()-t0:.1f}s)",
                  flush=True)

    elapsed = time.time() - t0
    print(f"[worker {worker_id}] generazione completata in {elapsed:.1f}s "
          f"({len(record_ids)} record)", flush=True)


def main() -> int:
    args = parse_args()
    bundle_dir = Path(args.bundle)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    status_path = output_dir / "status.json"
    summary_path = output_dir / "run_summary.json"
    final_predictions = output_dir / "predictions.jsonl"

    bundle = load_bundle(bundle_dir)
    all_records = read_jsonl(bundle["input_path"])

    # Resume: rimuovi gia' fatti
    done = existing_record_ids(output_dir)
    todo = filter_input_records(all_records, done)
    print(f"[main] totale={len(all_records)} done={len(done)} todo={len(todo)}", flush=True)

    write_status(status_path, {
        "run_id": bundle["manifest"]["run_id"],
        "state":  "starting",
        "records_total":     len(all_records),
        "records_already_done": len(done),
        "records_todo": len(todo),
        "started_at": now_utc_iso(),
    })

    if not todo:
        # Niente da fare; concat e summary, exit
        _concat_and_summarize(output_dir, bundle, len(all_records), len(done), 0, 0)
        write_status(status_path, {**json.loads(status_path.read_text()),
                                   "state": "completed",
                                   "message": "Nothing to do (resume)"})
        return 0

    n_workers = max(1, int(args.workers))
    shards = shard_round_robin(todo, n_workers)

    # Lancia worker
    procs = []
    for i, shard in enumerate(shards):
        if not shard:
            continue
        worker_pred_path = output_dir / f"predictions.worker_{i}.jsonl"
        p = mp.Process(
            target=worker_main,
            args=(i, i, bundle, shard, output_dir, worker_pred_path),
        )
        p.start()
        procs.append((i, p))

    # Aspetta
    failed = []
    for (i, p) in procs:
        p.join()
        if p.exitcode != 0:
            failed.append(i)

    # Concat + summary
    completed, failed_count = _concat_and_summarize(
        output_dir, bundle, len(all_records), len(done), len(todo), len(failed)
    )

    final_state = "completed" if not failed else "completed_with_errors"
    write_status(status_path, {
        "run_id": bundle["manifest"]["run_id"],
        "state": final_state,
        "records_total": len(all_records),
        "records_completed": completed,
        "records_failed": failed_count,
        "workers_failed": failed,
        "finished_at": now_utc_iso(),
    })

    return 0 if not failed else 2


def _concat_and_summarize(output_dir: Path, bundle: dict,
                          total: int, already_done: int, todo: int,
                          n_workers_failed: int) -> tuple[int, int]:
    """Merge predictions.worker_*.jsonl -> predictions.jsonl (idempotente,
    sovrascrive). Returns (completed, failed)."""
    final = output_dir / "predictions.jsonl"
    seen_ids: set[str] = set()
    completed = 0
    failed = 0

    with final.open("w", encoding="utf-8") as fout:
        for wp in sorted(output_dir.glob("predictions.worker_*.jsonl")):
            with wp.open("r", encoding="utf-8") as fin:
                for line in fin:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    rid = row.get("record_id")
                    if rid in seen_ids:
                        continue
                    seen_ids.add(rid)
                    if row.get("valid_schema"):
                        completed += 1
                    else:
                        failed += 1
                    fout.write(json.dumps(row) + "\n")

    summary = {
        "run_id": bundle["manifest"]["run_id"],
        "model_id": bundle["generation"]["model_id"],
        "stage": bundle["manifest"]["stage"],
        "records_total": total,
        "records_already_done_resume": already_done,
        "records_todo_this_run": todo,
        "records_completed_total": completed,
        "records_failed_schema": failed,
        "workers_failed_count": n_workers_failed,
        "finished_at": now_utc_iso(),
    }
    (output_dir / "run_summary.json").write_text(json.dumps(summary, indent=2))
    return completed, failed


if __name__ == "__main__":
    sys.exit(main())
