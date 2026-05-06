#!/usr/bin/env python
"""Batch runner for the first managed runtime iteration."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

from laims_runtime.backend import load_backend
from laims_runtime.io_utils import append_jsonl, ensure_dir, read_json, read_jsonl, write_json_atomic
from laims_runtime.model_registry import resolve_model_spec


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run first-pass DGX batch inference.")
    parser.add_argument("--bundle", required=True, help="Path to the staged bundle directory.")
    parser.add_argument("--output", required=True, help="Path to the output directory.")
    parser.add_argument("--status-path", required=True, help="Path to the run-level status.json file.")
    parser.add_argument("--cache-dir", default=os.environ.get("HF_HOME", "/opt/laims/cache/huggingface"))
    return parser.parse_args()


def load_bundle(bundle_dir: Path) -> dict:
    manifest = read_json(bundle_dir / "manifest.json")
    run_meta = read_json(bundle_dir / "run_meta.json")
    generation = read_json(bundle_dir / "generation.json")
    schema = read_json(bundle_dir / "schema.json")
    prompt = (bundle_dir / "prompt.txt").read_text(encoding="utf-8")
    records = read_jsonl(bundle_dir / "records.jsonl")
    chunk_plan = read_jsonl(bundle_dir / "chunk_plan.jsonl")
    initial_status = read_json(bundle_dir / "status.json")

    records_by_id = {}
    for row in records:
        row_id = str(row.get(manifest["id_col"]) or row.get("id") or "")
        records_by_id[row_id] = row

    return {
        "manifest": manifest,
        "run_meta": run_meta,
        "generation": generation,
        "schema": schema,
        "prompt": prompt,
        "records": records,
        "records_by_id": records_by_id,
        "chunk_plan": chunk_plan,
        "initial_status": initial_status,
    }


def base_status(bundle: dict, backend_name: str) -> dict:
    manifest = bundle["manifest"]
    initial = bundle["initial_status"]
    return {
        "run_id": manifest["run_id"],
        "state": initial.get("state", "created"),
        "message": initial.get("message", "Bundle created locally"),
        "updated_at": now_utc(),
        "submitted_at": initial.get("submitted_at"),
        "started_at": None,
        "finished_at": None,
        "model": manifest.get("model"),
        "model_id": manifest.get("model_id"),
        "backend": backend_name,
        "records": {
            "total": int(manifest.get("record_count", 0)),
            "completed": 0,
            "failed": 0,
        },
        "chunks": {
            "total": int(manifest.get("chunk_count", 0)),
            "completed": 0,
            "running": 0,
        },
        "engine": {
            "contract_version": "0.1",
            "real": [
                "bundle file IO",
                "incremental status updates",
                "predictions/errors/summary writing",
                "official managed model IDs for 20B and 120B",
            ],
            "provisional": [
                "single-process chunk execution",
                "transformers-based model loading on one GPU",
                "best-effort JSON parsing instead of constrained decoding",
            ],
        },
    }


def write_status(path: Path, status: dict) -> None:
    status["updated_at"] = now_utc()
    write_json_atomic(path, status)


def try_parse_json(text: str):
    text = (text or "").strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            return None
    return None


def render_prompt(prompt_template: str, schema: dict, record_id: str, record_text: str) -> str:
    schema_json = json.dumps(schema, indent=2, sort_keys=True)
    return (
        f"{prompt_template.strip()}\n\n"
        "Return exactly one JSON object matching this schema.\n"
        f"{schema_json}\n\n"
        f"Record ID: {record_id}\n"
        "Record text:\n"
        f"{record_text}\n\n"
        "JSON:"
    )


def record_error_row(run_id: str, model_spec: dict, chunk_id: int, record_id: str, exc: Exception) -> dict:
    return {
        "run_id": run_id,
        "record_id": record_id,
        "chunk_id": chunk_id,
        "model": model_spec["model"],
        "model_id": model_spec["model_id"],
        "error_type": type(exc).__name__,
        "error_message": str(exc),
        "raised_at": now_utc(),
    }


def record_prediction_row(
    run_id: str,
    model_spec: dict,
    chunk_id: int,
    record_id: str,
    prompt: str,
    output_text: str,
    parsed_json,
    backend_result,
) -> dict:
    return {
        "run_id": run_id,
        "record_id": record_id,
        "chunk_id": chunk_id,
        "model": model_spec["model"],
        "model_id": model_spec["model_id"],
        "backend": backend_result.backend_name,
        "generated_at": now_utc(),
        "prompt_chars": len(prompt),
        "output_text": output_text,
        "parsed_json": parsed_json,
        "backend_details": backend_result.backend_details,
    }


def main() -> int:
    args = parse_args()
    bundle_dir = Path(args.bundle)
    output_dir = ensure_dir(args.output)
    status_path = Path(args.status_path)
    ensure_dir(status_path.parent)

    bundle = load_bundle(bundle_dir)
    model_spec = resolve_model_spec(bundle["manifest"].get("model") or bundle["run_meta"].get("model"))
    backend = load_backend(model_spec, cache_dir=args.cache_dir)

    status = base_status(bundle, backend.name)
    status["state"] = "starting"
    status["message"] = "Runtime started; preparing backend"
    status["started_at"] = now_utc()
    write_status(status_path, status)

    predictions_path = output_dir / "predictions.jsonl"
    errors_path = output_dir / "errors.jsonl"
    summary_path = output_dir / "run_summary.json"

    started = time.time()
    try:
        status["state"] = "loading_model"
        status["message"] = f"Loading backend {backend.name} for {model_spec['model']}"
        write_status(status_path, status)
        backend_info = backend.load()
        status["backend_info"] = backend_info
        status["state"] = "running"
        status["message"] = "Backend ready; processing chunks"
        write_status(status_path, status)
    except Exception as exc:
        status["state"] = "failed"
        status["message"] = f"Backend load failed: {exc}"
        status["finished_at"] = now_utc()
        status["failure"] = {
            "error_type": type(exc).__name__,
            "error_message": str(exc),
            "traceback": traceback.format_exc(),
        }
        write_status(status_path, status)
        write_json_atomic(
            summary_path,
            {
                "run_id": bundle["manifest"]["run_id"],
                "state": "failed",
                "model": model_spec["model"],
                "model_id": model_spec["model_id"],
                "backend": backend.name,
                "started_at": status["started_at"],
                "finished_at": status["finished_at"],
                "failure": status["failure"],
                "real": status["engine"]["real"],
                "provisional": status["engine"]["provisional"],
            },
        )
        return 1

    total_records = status["records"]["total"]
    total_chunks = status["chunks"]["total"]

    for chunk in bundle["chunk_plan"]:
        chunk_id = int(chunk["chunk_id"])
        status["chunks"]["running"] = 1
        status["message"] = f"Processing chunk {chunk_id}/{total_chunks}"
        status["current_chunk"] = {
            "chunk_id": chunk_id,
            "record_count": int(chunk.get("record_count", 0)),
            "record_ids": chunk.get("record_ids", []),
        }
        write_status(status_path, status)

        prediction_rows = []
        error_rows = []
        for record_id in chunk.get("record_ids", []):
            record = bundle["records_by_id"].get(str(record_id))
            if record is None:
                exc = KeyError(f"record_id {record_id!r} missing from records.jsonl")
                error_rows.append(record_error_row(bundle["manifest"]["run_id"], model_spec, chunk_id, str(record_id), exc))
                status["records"]["failed"] += 1
                continue

            prompt = render_prompt(
                bundle["prompt"],
                bundle["schema"],
                str(record_id),
                str(record.get(bundle["manifest"]["text_col"], "")),
            )
            normalized_record = {
                "record_id": str(record_id),
                "text": str(record.get(bundle["manifest"]["text_col"], "")),
                "raw_record": record,
            }
            try:
                backend_result = backend.generate(
                    prompt=prompt,
                    generation_config=bundle["generation"],
                    record=normalized_record,
                )
                parsed_json = try_parse_json(backend_result.text)
                prediction_rows.append(
                    record_prediction_row(
                        bundle["manifest"]["run_id"],
                        model_spec,
                        chunk_id,
                        str(record_id),
                        prompt,
                        backend_result.text,
                        parsed_json,
                        backend_result,
                    )
                )
                status["records"]["completed"] += 1
            except Exception as exc:
                error_rows.append(
                    record_error_row(bundle["manifest"]["run_id"], model_spec, chunk_id, str(record_id), exc)
                )
                status["records"]["failed"] += 1

        if prediction_rows:
            append_jsonl(predictions_path, prediction_rows)
        if error_rows:
            append_jsonl(errors_path, error_rows)

        status["chunks"]["running"] = 0
        status["chunks"]["completed"] += 1
        status["message"] = (
            f"Completed chunk {chunk_id}/{total_chunks}; "
            f"{status['records']['completed']} succeeded, {status['records']['failed']} failed"
        )
        write_status(status_path, status)

    status["finished_at"] = now_utc()
    duration_seconds = round(time.time() - started, 3)
    if status["records"]["failed"] > 0:
        status["state"] = "completed_with_errors"
        status["message"] = (
            f"Run finished with partial failures: "
            f"{status['records']['completed']} succeeded, {status['records']['failed']} failed"
        )
    else:
        status["state"] = "completed"
        status["message"] = f"Run finished successfully: {status['records']['completed']}/{total_records} records completed"
    write_status(status_path, status)

    write_json_atomic(
        summary_path,
        {
            "run_id": bundle["manifest"]["run_id"],
            "state": status["state"],
            "model": model_spec["model"],
            "model_id": model_spec["model_id"],
            "backend": backend.name,
            "started_at": status["started_at"],
            "finished_at": status["finished_at"],
            "duration_seconds": duration_seconds,
            "records": status["records"],
            "chunks": status["chunks"],
            "outputs": {
                "predictions_jsonl": str(predictions_path),
                "errors_jsonl": str(errors_path),
                "status_json": str(status_path),
            },
            "real": status["engine"]["real"],
            "provisional": status["engine"]["provisional"],
            "assumptions": [
                "first model load may download weights from Hugging Face",
                "official model access must already be granted to the executing environment",
                "single-process execution on one H100 80GB is the current contract",
            ],
        },
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
