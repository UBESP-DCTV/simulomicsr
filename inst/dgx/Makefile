# Makefile per build e deploy del container P4.
# Pattern: docker build locale -> push DockerHub -> singularity pull sul cluster.
# Allineato a 2026.scRNA_DGX/Makefile.

DOCKER_USER ?= lucavd
IMAGE_NAME  ?= simulomicsr-vllm
TAG         ?= latest
FULL_IMAGE  := $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)

LOGIN_HOST  ?= logindgx.hpc.ict.unipd.it
LOGIN_USER  ?= u0044
RUNTIME_DIR ?= /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/runtime

.PHONY: build push pull-cluster predownload-model deploy

# Build locale
build:
	docker build -t $(FULL_IMAGE) .

# Push a DockerHub (richiede `docker login` una volta)
push: build
	docker push $(FULL_IMAGE)

# Pull come SIF sul login node DGX (richiede SSH key valida)
pull-cluster:
	ssh $(LOGIN_USER)@$(LOGIN_HOST) \
		"mkdir -p $(RUNTIME_DIR) && \
		 cd $(RUNTIME_DIR) && \
		 module load singularity/4.2.0 && \
		 singularity pull --force current.sif docker://$(FULL_IMAGE) && \
		 ls -lh current.sif"

# Pre-download del modello UNA VOLTA (uso HF_TOKEN dal login)
# Richiede current.sif gia' presente (eseguire `make pull-cluster` prima).
predownload-model:
	ssh $(LOGIN_USER)@$(LOGIN_HOST) \
		". ~/.simulomicsr-dgx.env && \
		 module load singularity/4.2.0 && \
		 mkdir -p /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/models/HF_HOME && \
		 singularity exec \
		   --bind /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/models/HF_HOME:/work/models/HF_HOME \
		   $(RUNTIME_DIR)/current.sif \
		   huggingface-cli download mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
		   --token \$$HF_TOKEN"

# Pipeline completa
deploy: push pull-cluster
	@echo "Container deployed. Esegui 'make predownload-model' per popolare HF cache."
