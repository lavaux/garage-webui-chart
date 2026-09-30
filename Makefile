CHART_NAME := garage-webui
VERSION    := $(shell grep '^version:' Chart.yaml | awk '{print $$2}')

# Versioning, tagging and publishing are done by semantic-release in
# .github/workflows/release.yml. These targets are for local checks only.

.PHONY: help lint template validate package clean
.DEFAULT_GOAL := help

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	  /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@printf "\nEnvironment:\n"
	@printf "  %-20s %s\n" "Chart version:" "$(VERSION)"
	@printf "  %-20s %s\n" "helm:" "$$(helm version --short 2>/dev/null | cut -d+ -f1 || echo 'not found')"

lint: ## Lint the chart
	helm lint .

template: ## Render templates to stdout with default values
	helm template $(CHART_NAME) .

validate: ## Validate the rendered templates with kubeconform
	helm template $(CHART_NAME) . | docker run --rm -i ghcr.io/yannh/kubeconform -strict -summary -

package: lint ## Lint then package the chart into a .tgz (local test only)
	helm package .

clean: ## Remove packaged .tgz files
	rm -f *.tgz
