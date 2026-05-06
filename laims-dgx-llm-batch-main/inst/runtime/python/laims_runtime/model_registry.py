"""Canonical managed runtime model registry."""

from __future__ import annotations


OFFICIAL_MODELS = {
    "20B": {
        "managed_id": "official-20b",
        "model_id": "openai/gpt-oss-20b",
        "label": "Official GPT-OSS 20B runtime",
    },
    "120B": {
        "managed_id": "official-120b",
        "model_id": "openai/gpt-oss-120b",
        "label": "Official GPT-OSS 120B runtime",
    },
}


ALIASES = {
    "20b": "20B",
    "120b": "120B",
    "openai/gpt-oss-20b": "20B",
    "openai/gpt-oss-120b": "120B",
}


def resolve_model_key(candidate: str | None) -> str:
    value = (candidate or "").strip()
    if not value:
        raise ValueError("model is required")

    if value in OFFICIAL_MODELS:
        return value

    alias = ALIASES.get(value.lower())
    if alias:
        return alias

    raise ValueError(f"unsupported managed runtime model: {value!r}")


def resolve_model_spec(candidate: str | None) -> dict:
    model_key = resolve_model_key(candidate)
    spec = dict(OFFICIAL_MODELS[model_key])
    spec["model"] = model_key
    return spec
