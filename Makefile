.DEFAULT_GOAL := help


.PHONY: help
help: ## Generates a help README
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


# prompt_example> make install profile="ubuntu"
.PHONY: install
install: ## Run dotbot install script, e.g. make install profile="ubuntu-coder"
	./install-profile $(profile)

.PHONY: profiles
profiles: ## List available profiles
	 @ls -1 ./meta/profiles
