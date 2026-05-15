# aegis-stateless — Makefile
#
# Wraps terraform invocations with a project-local PATH (so tools resolve from
# ./bin/, never the host's /usr/local) and a shared -var-file pointing at the
# single source of truth for the multi-region topology (regions.auto.tfvars).
#
# Per "Host isolation discipline": every dev tool lives in ./bin/. Reviewer can
# clone + `make dev-setup all` without conflicting with their toolchain.

ROOT   := $(CURDIR)
BIN    := $(ROOT)/bin
TFVARS := $(ROOT)/regions.auto.tfvars

PATH := $(BIN):$(PATH)
export PATH

# Neutral default for committed reference. Bin's local shell exports
# AWS_PROFILE=hivemind to override; reviewer sets their own value.
AWS_PROFILE ?= aegis
export AWS_PROFILE

TF_BOOTSTRAP := terraform/envs/bootstrap
TF_PLATFORM  := terraform/envs/platform
TF_REGIONAL  := terraform/envs/regional

.PHONY: help dev-setup fmt validate lint sec \
        bootstrap platform regional all \
        destroy-regional destroy-platform \
        clean-bin

help:
	@echo "Targets:"
	@echo "  dev-setup        Install pinned tflint/tfsec/kubeconform/hadolint into ./bin/"
	@echo "  fmt              terraform fmt -recursive terraform/"
	@echo "  validate         terraform validate in each env (no backend init)"
	@echo "  lint             tflint --recursive --chdir=terraform/"
	@echo "  sec              tfsec terraform/"
	@echo "  bootstrap        Apply terraform/envs/bootstrap (one-time; creates remote backend)"
	@echo "  platform         Apply terraform/envs/platform (slow lifecycle; survives DR drill)"
	@echo "  regional         Apply terraform/envs/regional (fast lifecycle; DR drill target)"
	@echo "  all              bootstrap + platform + regional in order"
	@echo "  destroy-regional DR drill — tear down workload; platform survives"
	@echo "  destroy-platform Full teardown — Route 53 + ECR + budgets + Grafana resources"
	@echo "  clean-bin        Remove ./bin/ (project-local tools)"

dev-setup:
	./scripts/install-tools.sh $(BIN)

fmt:
	terraform fmt -recursive terraform/

validate:
	@if [ -d $(TF_BOOTSTRAP) ]; then \
	  cd $(TF_BOOTSTRAP) && terraform init -backend=false && terraform validate; \
	fi
	@if [ -d $(TF_PLATFORM)  ]; then \
	  cd $(TF_PLATFORM)  && terraform init -backend=false && terraform validate; \
	fi
	@if [ -d $(TF_REGIONAL)  ]; then \
	  cd $(TF_REGIONAL)  && terraform init -backend=false && terraform validate; \
	fi

lint:
	$(BIN)/tflint --recursive --chdir=terraform/

sec:
	$(BIN)/tfsec terraform/

bootstrap:
	cd $(TF_BOOTSTRAP) && terraform init && terraform apply

platform:
	cd $(TF_PLATFORM)  && terraform init \
	  && terraform apply -var-file=$(TFVARS)

regional:
	cd $(TF_REGIONAL)  && terraform init \
	  && terraform apply -var-file=$(TFVARS)

all: bootstrap platform regional

# DR drill: tear down the regional workload only. The platform env (Route 53
# zone, ECR repo, Grafana dashboards, SSM parameters) intentionally survives.
destroy-regional:
	cd $(TF_REGIONAL)  && terraform destroy -var-file=$(TFVARS)

# Full teardown (post-submission cleanup). Removes platform too.
destroy-platform:
	cd $(TF_PLATFORM)  && terraform destroy -var-file=$(TFVARS)

clean-bin:
	rm -rf $(BIN)
