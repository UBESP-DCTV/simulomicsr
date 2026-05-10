# vLLM v0.20.2 (release 2026-05-10): include PR #40946 fix per Issue #39734
# (scheduler v1 deadlock head-of-line) merged 2026-04-27 in v0.20.0 milestone.
# Vedi ADR-0010 per validation plan + gate hierarchical.
#
# Variante cu129 (CUDA 12.9) richiesta perche' :v0.20.2 plain e' compilata
# con CUDA 13.0/PyTorch 2.11 e richiede driver NVIDIA >= 545. Il DGX UniPD
# (poddgx02) ha driver 535.183.01 (supporta max CUDA 12.2 nativo). La
# variante cu129 include CUDA Forward Compatibility libs nel container,
# che permettono a un binario CUDA 12.9 di girare su driver 535 (verificato
# nelle vLLM docs + smoke job 20039 fallito a Step 3 con driver too old
# message conferma il blocker).
#
# API breaking change rispetto a 0.10.0: GuidedDecodingParams rimosso in
# v0.12.0 -> sostituito da StructuredOutputsParams. Il run_p4_vllm.py e'
# stato migrato (vedi commit di Phase 1 ADR-0010). Mistral-Small-3.2
# kwargs (tokenizer_mode/config_format/load_format = "mistral") invariati,
# verificato in examples/offline_inference/mistral-small.py @ v0.20.2.
FROM vllm/vllm-openai:v0.20.2-cu129-ubuntu2404

LABEL maintainer="simulomicsr" \
      model="mistralai/Mistral-Small-3.2-24B-Instruct-2506" \
      purpose="P4 batch classification stage1+stage2"

# Dipendenze extra rispetto al base vllm/vllm-openai
RUN pip install --no-cache-dir jsonschema orjson pyyaml

# Copia gli script Python custom in una location stabile
COPY python /opt/simulomicsr/runtime/python

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/simulomicsr/runtime/python \
    HF_HOME=/work/models/HF_HOME \
    TRANSFORMERS_CACHE=/work/models/HF_HOME

# vllm/vllm-openai default ENTRYPOINT lancia il server HTTP. Lo
# sovrascriviamo col nostro batch runner. NB: l'immagine espone python3,
# NON python — verificato sul cluster il 2026-05-06.
ENTRYPOINT ["python3", "/opt/simulomicsr/runtime/python/run_p4_vllm.py"]
