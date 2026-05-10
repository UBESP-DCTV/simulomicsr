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

    from vllm import LLM, SamplingParams

    gen = bundle["generation"]
    schema = bundle["schema"]
    stage = bundle["manifest"]["stage"]
    system_prompt = bundle["prompt"]

    print(f"[worker {worker_id}] caricamento vLLM su GPU {gpu_index}...", flush=True)
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
    if "max_num_seqs" in gen and gen["max_num_seqs"] is not None:
        llm_kwargs["max_num_seqs"] = int(gen["max_num_seqs"])
        print(f"[worker {worker_id}] max_num_seqs={llm_kwargs['max_num_seqs']}", flush=True)
    llm = LLM(**llm_kwargs)

    # Param opzionali (presenti solo se override del default yaml).
    extra_kwargs: dict[str, Any] = {}
    if "repetition_penalty" in gen and gen["repetition_penalty"] is not None:
        extra_kwargs["repetition_penalty"] = float(gen["repetition_penalty"])
    if "top_p" in gen and gen["top_p"] is not None:
        extra_kwargs["top_p"] = float(gen["top_p"])
    if "min_p" in gen and gen["min_p"] is not None:
        extra_kwargs["min_p"] = float(gen["min_p"])

    # Structured outputs vLLM 0.20+: backend "auto" (xgrammar -> outlines
    # fallback). Output parser-grade per construction. Emergency escape:
    # gen["disable_guided_decoding"]=true cade su free-gen + json.loads
    # best-effort (utile per debug, no path operativo).
    use_guided = not gen.get("disable_guided_decoding", False)
    if not use_guided:
        print(f"[worker {worker_id}] guided decoding DISABILITATO (debug only)", flush=True)
    structured_params = None
    if use_guided:
        from vllm.sampling_params import StructuredOutputsParams
        structured_params = StructuredOutputsParams(json=schema)

    default_max_tokens = int(gen["max_tokens"])

    def _make_sampling(max_tok: int) -> SamplingParams:
        """Build SamplingParams per request. max_tok puo' essere per-record
        (tier-based via dgx_p4_build_bundle(tiered_max_tokens=TRUE), ADR-0011)
        o il default globale gen[max_tokens]."""
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

    # Micro-batch llm.chat: divide il workload in chunks per write incrementale
    # a predictions.jsonl (visibility progress + crash safety). Per stage1
    # record corti, batch grande (None = all-in-one). Per stage2, default 50.
    MICROBATCH = int(gen.get("microbatch", 0)) or (None if stage == "stage1" else 50)
    print(f"[worker {worker_id}] generazione su {len(conversations)} record "
          f"(microbatch={MICROBATCH or 'all'})...", flush=True)
    t0 = time.time()

    def _write_batch(rids, outs):
        # Con vLLM 0.20+ e structured_outputs backend (xgrammar->outlines
        # fallback automatico) l'output e' parser-grade per construction.
        # Pre-ADR-0010 c'erano _strip_md_fences + _try_parse(missing-value
        # regex) come heuristic recovery contro free-gen Mistral-3.2;
        # rimossi in Phase 5 cleanup (ADR-0010 Outcome 2026-05-10).
        with predictions_path.open("a", encoding="utf-8") as fh:
            for rid, out in zip(rids, outs):
                raw = out.outputs[0].text if out.outputs else ""
                try:
                    parsed = json.loads(raw)
                    valid = True
                except json.JSONDecodeError:
                    parsed = None
                    valid = False
                row = {
                    "record_id": rid,
                    "raw_output": raw,
                    "parsed_json": parsed,
                    "valid_schema": valid,
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
