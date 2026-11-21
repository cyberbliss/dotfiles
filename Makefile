.DEFAULT_GOAL := help

CHEZMOI ?= $(shell command -v chezmoi 2>/dev/null || echo $$HOME/.local/bin/chezmoi)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: prereqs
prereqs: ## Install OpenCode + put it on PATH (run this first)
	./scripts/prereqs.sh

.PHONY: bootstrap
bootstrap: ## Bootstrap a fresh machine (toolchain + clone), then hand off to an agent
	./scripts/bootstrap.sh

.PHONY: apply
apply: ## Apply the chezmoi source to $HOME (config + baseline packages)
	$(CHEZMOI) apply

.PHONY: doctor
doctor: ## Verify a machine: make doctor machine=chromebook
	./scripts/doctor.sh $(machine)

.PHONY: zsh
zsh: ## Walk through this machine's zsh target type + modules
	./scripts/zsh-configure.sh

.PHONY: extras
extras: ## List the optional installable stacks
	./scripts/install-extras.sh --list

.PHONY: render-matrix
render-matrix: ## Prove per-machine template rendering (no second box needed)
	./scripts/render-matrix.sh
