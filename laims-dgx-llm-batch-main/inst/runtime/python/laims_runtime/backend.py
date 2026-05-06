"""Inference backends for the first-pass managed runtime."""

from __future__ import annotations

import gc
import json
import os
from dataclasses import dataclass
from typing import Any


@dataclass
class GenerationResult:
    text: str
    backend_name: str
    backend_details: dict[str, Any]


class BaseBackend:
    name = "base"

    def __init__(self, model_spec: dict, cache_dir: str | None = None) -> None:
        self.model_spec = model_spec
        self.cache_dir = cache_dir

    def load(self) -> dict[str, Any]:
        raise NotImplementedError

    def generate(self, prompt: str, generation_config: dict, record: dict | None = None) -> GenerationResult:
        raise NotImplementedError


class MockBackend(BaseBackend):
    name = "mock"

    def __init__(self, model_spec: dict, cache_dir: str | None = None) -> None:
        super().__init__(model_spec, cache_dir=cache_dir)
        raw_failures = os.environ.get("LAIMS_RUNTIME_FAIL_RECORD_IDS", "")
        self.fail_record_ids = {
            value.strip() for value in raw_failures.split(",") if value.strip()
        }
        self.emit_json = os.environ.get("LAIMS_RUNTIME_MOCK_JSON", "0") == "1"

    def load(self) -> dict[str, Any]:
        return {
            "backend": self.name,
            "mode": "test-double",
            "note": "Mock backend for local contract tests and dry execution."
        }

    def generate(self, prompt: str, generation_config: dict, record: dict | None = None) -> GenerationResult:
        record = record or {}
        record_id = str(record.get("record_id") or record.get("id") or "")
        if record_id in self.fail_record_ids:
            raise RuntimeError(f"mock backend forced failure for record {record_id}")

        excerpt = str(record.get("text") or "")[:80]
        if self.emit_json:
            payload = {
                "record_id": record_id,
                "label": "mock",
                "confidence": 0.0,
                "excerpt": excerpt,
            }
            text = json.dumps(payload)
        else:
            text = f"MOCK_RESPONSE[{self.model_spec['model']}]: {excerpt}"

        return GenerationResult(
            text=text,
            backend_name=self.name,
            backend_details={"prompt_chars": len(prompt)},
        )


class TransformersBackend(BaseBackend):
    name = "transformers"

    def __init__(self, model_spec: dict, cache_dir: str | None = None) -> None:
        super().__init__(model_spec, cache_dir=cache_dir)
        self.model = None
        self.tokenizer = None
        self.torch = None
        self.device = "cpu"

    def load(self) -> dict[str, Any]:
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self.torch = torch
        model_kwargs = {
            "trust_remote_code": True,
            "low_cpu_mem_usage": True,
        }
        if self.cache_dir:
            model_kwargs["cache_dir"] = self.cache_dir

        if torch.cuda.is_available():
            self.device = "cuda"
            model_kwargs["dtype"] = torch.bfloat16
            model_kwargs["device_map"] = "auto"
        else:
            self.device = "cpu"
            model_kwargs["dtype"] = torch.float32

        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_spec["model_id"],
            trust_remote_code=True,
            cache_dir=self.cache_dir,
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_spec["model_id"],
            **model_kwargs,
        )

        return {
            "backend": self.name,
            "device": self.device,
            "dtype": str(model_kwargs["dtype"]),
            "note": (
                "First-pass local generation backend. Large-model fit/download "
                "is still cluster- and access-dependent."
            ),
        }

    def generate(self, prompt: str, generation_config: dict, record: dict | None = None) -> GenerationResult:
        if self.model is None or self.tokenizer is None or self.torch is None:
            raise RuntimeError("backend not loaded")

        encoded = self.tokenizer(prompt, return_tensors="pt")
        target_device = "cuda" if self.device == "cuda" else "cpu"
        encoded = {key: value.to(target_device) for key, value in encoded.items()}

        max_new_tokens = int(generation_config.get("max_tokens", 1024))
        temperature = float(generation_config.get("temperature", 0.0))
        top_p = float(generation_config.get("top_p", 1.0))
        do_sample = temperature > 0

        generate_kwargs = {
            "max_new_tokens": max_new_tokens,
            "do_sample": do_sample,
            "pad_token_id": self.tokenizer.eos_token_id,
        }
        if do_sample:
            generate_kwargs["temperature"] = temperature
            generate_kwargs["top_p"] = top_p

        with self.torch.inference_mode():
            output = self.model.generate(**encoded, **generate_kwargs)

        generated_tokens = output[0][encoded["input_ids"].shape[1]:]
        text = self.tokenizer.decode(generated_tokens, skip_special_tokens=True).strip()

        if self.device == "cuda":
            self.torch.cuda.empty_cache()
        gc.collect()

        return GenerationResult(
            text=text,
            backend_name=self.name,
            backend_details={"device": self.device},
        )


def load_backend(model_spec: dict, cache_dir: str | None = None) -> BaseBackend:
    backend_name = os.environ.get("LAIMS_RUNTIME_BACKEND", "transformers").strip().lower()
    if backend_name == "mock":
        return MockBackend(model_spec, cache_dir=cache_dir)
    if backend_name == "transformers":
        return TransformersBackend(model_spec, cache_dir=cache_dir)
    raise ValueError(f"unsupported runtime backend: {backend_name!r}")
