# vLLM >= 0.8.x richiesto per Mistral-Small-3.2 (model_type "mistral3"
# introdotto in transformers 4.49 a inizio 2025; vLLM 0.6.4 di Nov 2024
# non lo conosce -> KeyError 'mistral3' al load).
# Verificato sul cluster il 2026-05-07 con job 19721: smoke fallisce a
# Step 5 con questo errore esatto su v0.6.4. Bumpato a v0.10.0 stable.
FROM vllm/vllm-openai:v0.10.0

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
