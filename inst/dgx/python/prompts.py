"""User-message rendering per stage1 / stage2 — port 1:1 dei template R."""
from __future__ import annotations

import json
from typing import Any


def render_user_message_stage1(record: dict[str, Any]) -> str:
    """Costruisce lo user message per Stadio 1 (sample-level).

    Layout identico a R/llm-stage1.R::build_prompt_stage1():
        geo_accession: <ga>
        series_id: <sid>
        [organism_hint: <hint>]    # opzionale, se presente nel record
        sample_string:
        <string>
    """
    geo = str(record["geo_accession"])
    sid = str(record["series_id"])
    sstr = str(record["string"])
    organism_hint = record.get("organism_hint")

    lines = [
        f"geo_accession: {geo}",
        f"series_id: {sid}",
    ]
    if organism_hint:
        lines.append(f"organism_hint: {organism_hint}")
    lines.append("sample_string:")
    lines.append(sstr)
    return "\n".join(lines)


def render_user_message_stage2(record: dict[str, Any]) -> str:
    """Costruisce lo user message per Stadio 2 (study-level).

    Layout identico a R/llm-stage2.R::build_prompt_stage2():
        series_id: <sid>
        study_summary: <summary>
        samples:
        <JSON dei sample_facts dei sample dello studio>
    """
    sid = str(record["record_id"])  # GSE id
    summary = str(record.get("study_summary", ""))
    samples = record.get("samples", [])

    samples_json = json.dumps(samples, indent=2, sort_keys=False)

    return (
        f"series_id: {sid}\n"
        f"study_summary: {summary}\n"
        "samples:\n"
        f"{samples_json}"
    )


def build_messages(system_prompt: str, user_message: str) -> list[dict[str, str]]:
    """Restituisce la struttura messages standard OpenAI/vLLM."""
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]
