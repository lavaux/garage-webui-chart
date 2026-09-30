CHART_NAME   := garage-webui
VERSION      := $(shell grep '^version:' Chart.yaml | awk '{print $$2}')
PACKAGE      := $(CHART_NAME)-$(VERSION).tgz

FORGEJO_HOST := git.aquila-consortium.org
REPO_OWNER   := guilhem_lavaux
REPO_NAME    := helm-garage-webui
FORGEJO_API  := https://$(FORGEJO_HOST)/api/v1
TAG          := v$(VERSION)

.PHONY: help lint template package bump-patch bump-minor bump-major release clean
.DEFAULT_GOAL := help

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	  /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@printf "\nEnvironment:\n"
	@printf "  %-20s %s\n" "Chart version:" "$(VERSION)"
	@printf "  %-20s %s\n" "Forgejo host:" "$(FORGEJO_HOST)"
	@printf "  %-20s %s\n" "helm:" "$$(helm version --short 2>/dev/null | cut -d+ -f1 || echo 'not found')"
	@printf "  %-20s %s\n" "curl:" "$$(curl --version 2>/dev/null | awk 'NR==1{print $$2}' || echo 'not found')"
	@printf "  %-20s %s\n" "jq:" "$$(jq --version 2>/dev/null || echo 'not found')"
	@if test -n "$$FORGEJO_TOKEN"; then \
	  printf "  %-20s \033[32mset\033[0m\n" "FORGEJO_TOKEN:"; \
	else \
	  printf "  %-20s \033[31mNOT SET\033[0m\n" "FORGEJO_TOKEN:"; \
	fi

lint: ## Lint the chart
	helm lint .

template: ## Render templates to stdout with default values
	helm template $(CHART_NAME) .

package: lint ## Lint then package the chart into a .tgz
	helm package .

bump-patch: ## Increment patch version in Chart.yaml and commit
	awk '/^version:/{split($$2,a,"."); a[3]+=1; \
	  printf "version: %s.%s.%s\n",a[1],a[2],a[3]; next} {print}' \
	  Chart.yaml > Chart.yaml.tmp && mv Chart.yaml.tmp Chart.yaml
	git add Chart.yaml
	git commit -m "chore: bump chart to $$(grep '^version:' Chart.yaml | awk '{print $$2}')"

bump-minor: ## Increment minor version in Chart.yaml and commit
	awk '/^version:/{split($$2,a,"."); a[2]+=1; a[3]=0; \
	  printf "version: %s.%s.%s\n",a[1],a[2],a[3]; next} {print}' \
	  Chart.yaml > Chart.yaml.tmp && mv Chart.yaml.tmp Chart.yaml
	git add Chart.yaml
	git commit -m "chore: bump chart to $$(grep '^version:' Chart.yaml | awk '{print $$2}')"

bump-major: ## Increment major version in Chart.yaml and commit
	awk '/^version:/{split($$2,a,"."); a[1]+=1; a[2]=0; a[3]=0; \
	  printf "version: %s.%s.%s\n",a[1],a[2],a[3]; next} {print}' \
	  Chart.yaml > Chart.yaml.tmp && mv Chart.yaml.tmp Chart.yaml
	git add Chart.yaml
	git commit -m "chore: bump chart to $$(grep '^version:' Chart.yaml | awk '{print $$2}')"

release: package ## Package, tag, push, and upload as a Forgejo release asset (requires curl, jq, FORGEJO_TOKEN)
	@test -n "$$FORGEJO_TOKEN" || (echo "ERROR: FORGEJO_TOKEN is not set"; exit 1)
	@echo "Tagging $(TAG)..."
	git tag $(TAG)
	git push origin $(TAG)
	@RELEASE_ID=$$(curl -sf -X POST \
	  -H "Authorization: token $$FORGEJO_TOKEN" \
	  -H "Content-Type: application/json" \
	  "$(FORGEJO_API)/repos/$(REPO_OWNER)/$(REPO_NAME)/releases" \
	  -d '{"tag_name":"$(TAG)","name":"$(TAG)","body":"Helm chart $(CHART_NAME) $(VERSION)"}' \
	  | jq -r '.id') && \
	echo "Uploading $(PACKAGE) to release $$RELEASE_ID..." && \
	curl -sf -X POST \
	  -H "Authorization: token $$FORGEJO_TOKEN" \
	  -F "attachment=@$(PACKAGE)" \
	  "$(FORGEJO_API)/repos/$(REPO_OWNER)/$(REPO_NAME)/releases/$$RELEASE_ID/assets" && \
	echo "Release $(TAG) published."

clean: ## Remove packaged .tgz files
	rm -f *.tgz
