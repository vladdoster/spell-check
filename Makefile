IMAGE ?= speller
TAG ?= latest
IMAGE_REF = $(IMAGE):$(TAG)

.DEFAULT_GOAL := help
.PHONY: help build run clean

help: ## Show available targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -t $(IMAGE_REF) .

ifneq ($(filter run,$(MAKECMDGOALS)),)
ifndef REPOSITORY
$(error REPOSITORY is required, e.g. make run REPOSITORY=user/repo)
endif
ifndef GH_TOKEN
$(error GH_TOKEN must be set in the environment)
endif
endif

REPOSITORY :=

run: build ## Run the image (requires GH_TOKEN env and REPOSITORY=user/repo; optional IGNORE, SKIP)
	docker run --rm -e GH_TOKEN $(IMAGE_REF) $(REPOSITORY) '$(IGNORE)' '$(SKIP)'

clean: ## Remove the Docker image
	-docker rmi $(IMAGE_REF)
