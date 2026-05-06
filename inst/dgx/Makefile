# Makefile per build e deploy del container P4.
# Allineato 1:1 al pattern di 2026.scRNA_DGX/Makefile (lucavd/sc-benchmark):
# - target laptop: build, push (docker)
# - target cluster (run dopo SSH): pull-singularity, predownload-model
# Niente SSH wrapping nel Makefile: pattern semplice, esegui il target dove
# ti serve, decidi tu dove SSH-are.

DOCKER_USER ?= lucavd
IMAGE_NAME  ?= simulomicsr-vllm
TAG         ?= latest
FULL_IMAGE  := $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)

# Path persistente sul cluster UniPD (allineato a scRNA_DGX: usa /mnt/home/<u>
# perche' compute node poddgx02 vede storage qui, NON in /home/<u>).
WORKDIR ?= /mnt/home/u0044/simulomicsr-dgx

.PHONY: build push pull-singularity predownload-model

# ===== LAPTOP =====

build:
	docker build -t $(FULL_IMAGE) .

push:
	docker push $(FULL_IMAGE)

# ===== CLUSTER (run dopo SSH al login node) =====
# Esempio:
#   ssh u0044@logindgx.hpc.ict.unipd.it
#   cd /mnt/home/u0044/simulomicsr-dgx/runtime/
#   module load singularity/4.2.0
#   make -f /path/al/repo/inst/dgx/Makefile pull-singularity

pull-singularity:
	singularity pull --force $(IMAGE_NAME).sif docker://$(FULL_IMAGE)
	singularity cache clean

predownload-model:
	. ~/.simulomicsr-dgx.env && \
	mkdir -p $(WORKDIR)/models/HF_HOME && \
	singularity exec \
	  --bind $(WORKDIR)/models/HF_HOME:/work/models/HF_HOME \
	  $(IMAGE_NAME).sif \
	  huggingface-cli download mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
	  --token $$HF_TOKEN
