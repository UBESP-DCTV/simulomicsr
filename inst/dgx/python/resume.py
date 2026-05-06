"""Resume idempotente: legge i record_id gia' presenti nei predictions
worker JSONL e filtra l'input prima di partire."""

from __future__ import annotations

import glob
import json
import os
from pathlib import Path
from typing import Iterable


def existing_record_ids(output_dir: str | os.PathLike) -> set[str]:
    """Scansiona predictions.worker_*.jsonl e predictions.jsonl, ritorna gli ID
    gia' completati con successo. Linee non parseabili vengono saltate."""
    out = Path(output_dir)
    done: set[str] = set()
    patterns = ["predictions.worker_*.jsonl", "predictions.jsonl"]
    for pat in patterns:
        for p in out.glob(pat):
            try:
                with p.open("r", encoding="utf-8") as fh:
                    for line in fh:
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            row = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        rid = row.get("record_id")
                        if rid is not None:
                            done.add(str(rid))
            except FileNotFoundError:
                continue
    return done


def filter_input_records(records: Iterable[dict], done_ids: set[str]) -> list[dict]:
    """Restituisce solo i record con record_id NON in done_ids."""
    return [r for r in records if str(r.get("record_id")) not in done_ids]


def shard_round_robin(records: list[dict], n_workers: int) -> list[list[dict]]:
    """Divide la lista in n_workers fette round-robin (load-balanced)."""
    shards: list[list[dict]] = [[] for _ in range(n_workers)]
    for i, r in enumerate(records):
        shards[i % n_workers].append(r)
    return shards
