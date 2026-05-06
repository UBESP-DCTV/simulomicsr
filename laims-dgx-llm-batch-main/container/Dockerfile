# Placeholder Dockerfile for the inference runtime.
# Intended to be converted into a Singularity/Apptainer image for HPC use.

FROM python:3.11-slim

WORKDIR /app

# Minimal placeholder system setup.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Placeholder Python dependencies.
# In a real implementation, pin versions carefully and align with cluster CUDA.
RUN pip install --no-cache-dir \
    pyyaml \
    orjson

# Placeholder runtime files.
COPY . /app

CMD ["python", "-c", "print('Placeholder LLM batch runtime container')"]
