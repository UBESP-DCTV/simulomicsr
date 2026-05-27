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
        [molecule_hint: <hint>]    # opzionale, ADR-0019 D5 + RED_ALERT D1b
        sample_string:
        <string>

    `molecule_hint` proviene dal campo JSONL `molecule_ch1` introdotto in
    FASE C4 (commit 6963198). Valori GEO controlled-vocabulary:
    "total RNA", "polyA RNA", "nuclear RNA", "cytoplasmic RNA", ...
    Se assente / null / vuoto la riga NON viene emessa (parita' con la
    versione R).
    """
    geo = str(record["geo_accession"])
    sid = str(record["series_id"])
    sstr = str(record["string"])
    organism_hint = record.get("organism_hint")
    molecule_hint = record.get("molecule_ch1")

    lines = [
        f"geo_accession: {geo}",
        f"series_id: {sid}",
    ]
    if organism_hint:
        lines.append(f"organism_hint: {organism_hint}")
    # `if molecule_hint` filtra None / "" / valori falsy: stesso semantica del
    # guard R `!is.null(x) && !is.na(x) && nzchar(x)` (NA serializzato JSON
    # diventa null Python, gestito da `if`).
    if molecule_hint:
        lines.append(f"molecule_hint: {molecule_hint}")
    lines.append("sample_string:")
    lines.append(sstr)
    return "\n".join(lines)


def render_user_message_stage2(record: dict[str, Any]) -> str:
    """Costruisce lo user message per Stadio 2 (study-level).

    Layout (alpha P4 2026-05-07, support chunking):
        series_id: <sid>             # GSE canonico — record["series_id"] o record_id
        [chunk: X/Y]                 # opzionale: presente solo se input splittato
        [study_total_samples: N]     # opzionale: presente con chunk
        study_summary: <summary>
        samples:
        <compact JSON dei sample_facts dei sample del chunk>

    record["record_id"] e' la chiave unica per chunk (es. "GSE12345#1of3");
    record["series_id"] (se presente) e' il GSE canonico mostrato al modello
    e atteso nell'output. Per back-compat, se "series_id" manca si usa
    record_id.

    JSON compact (no indent) per ridurre i token consumati: i sample_facts
    pretty-printed gonfiavano del ~30% un input gia' al limite di 32K ctx.
    """
    sid = str(record.get("series_id") or record["record_id"])
    summary = str(record.get("study_summary", ""))
    samples = record.get("samples", [])

    samples_json = json.dumps(samples, sort_keys=False, separators=(",", ":"))

    lines = [f"series_id: {sid}"]
    chunk_meta = record.get("chunk_metadata")
    if chunk_meta:
        part = chunk_meta.get("part")
        total_parts = chunk_meta.get("total_parts")
        total_samples = chunk_meta.get("study_total_samples")
        if part is not None and total_parts is not None:
            lines.append(f"chunk: {part}/{total_parts}")
        if total_samples is not None:
            lines.append(f"study_total_samples: {total_samples}")
    lines.append(f"study_summary: {summary}")
    lines.append("samples:")
    lines.append(samples_json)
    return "\n".join(lines)


def build_messages(system_prompt: str, user_message: str) -> list[dict[str, str]]:
    """Restituisce la struttura messages standard OpenAI/vLLM."""
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]
