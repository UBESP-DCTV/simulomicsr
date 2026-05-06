# CUDA 12.1+ richiesto da vLLM 0.6.x.
# Driver DGX UniPD HPC (poddgx02) compatibile CUDA 12 (verificato dal
# progetto 2026.scRNA_DGX che gira su nvcr.io/nvidia/rapidsai/base con
# CUDA 12.x sullo stesso nodo).
FROM vllm/vllm-openai:v0.6.4

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
