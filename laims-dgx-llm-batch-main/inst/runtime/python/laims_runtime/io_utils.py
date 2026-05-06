"""Bundle and file helpers for the managed runtime."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Iterable


def ensure_dir(path: str | Path) -> Path:
    target = Path(path)
    target.mkdir(parents=True, exist_ok=True)
    return target


def read_json(path: str | Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def read_jsonl(path: str | Path) -> list[dict]:
    records = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def write_json_atomic(path: str | Path, payload: dict) -> None:
    destination = Path(path)
    ensure_dir(destination.parent)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", delete=False, dir=str(destination.parent)
    ) as handle:
        json.dump(payload, handle, indent=2, sort_keys=False)
        handle.write("\n")
        temp_name = handle.name
    os.replace(temp_name, destination)


def append_jsonl(path: str | Path, rows: Iterable[dict]) -> None:
    destination = Path(path)
    ensure_dir(destination.parent)
    with destination.open("a", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=False))
            handle.write("\n")
