SONARQUBE_URL ?= http://localhost:9000

.DEFAULT_GOAL := help

.PHONY: help start stop restart setup analyze logs status open clean

help: ## Show available commands
	@echo ""
	@echo "  SonarQube Local Code Analyzer"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "  Examples:"
	@echo "    make analyze DIR=~/my-project"
	@echo "    make analyze DIR=~/my-project KEY=my-key NAME='My Project'"
	@echo ""

start: ## Start SonarQube and PostgreSQL
	docker-compose up -d
	@echo ""
	@echo "  SonarQube starting at $(SONARQUBE_URL)"
	@echo "  It may take 60-90 seconds to be fully ready."
	@echo "  Run 'make setup' once it is up."

stop: ## Stop all containers
	docker-compose down

restart: ## Restart the SonarQube container
	docker-compose restart sonarqube

setup: ## First-time setup: wait for readiness, change password, generate token
	@bash setup.sh

analyze: ## Analyze a project — required: DIR=/path/to/project  optional: KEY= NAME=
	@if [ -z "$(DIR)" ]; then \
		echo ""; \
		echo "  \033[31mError: DIR is required.\033[0m"; \
		echo "  Usage: make analyze DIR=/path/to/project"; \
		echo ""; \
		exit 1; \
	fi
	@bash analyze.sh -p "$(DIR)" \
		$(if $(KEY),-k "$(KEY)") \
		$(if $(NAME),-n "$(NAME)")

logs: ## Stream SonarQube logs
	docker-compose logs -f sonarqube

status: ## Print SonarQube system status
	@curl -sf "$(SONARQUBE_URL)/api/system/status" \
		| python3 -m json.tool 2>/dev/null \
		|| curl -sf "$(SONARQUBE_URL)/api/system/status" \
		|| echo "SonarQube is not reachable at $(SONARQUBE_URL)"

open: ## Open SonarQube dashboard in the default browser
	@xdg-open "$(SONARQUBE_URL)" 2>/dev/null \
		|| open "$(SONARQUBE_URL)" 2>/dev/null \
		|| echo "Open $(SONARQUBE_URL) in your browser"

clean: ## Remove all containers AND persistent volumes (data loss!)
	@echo ""
	@echo "  \033[31mWARNING: This deletes all SonarQube data and analysis history.\033[0m"
	@read -p "  Type 'yes' to confirm: " confirm && \
		[ "$$confirm" = "yes" ] && docker-compose down -v && echo "Done." || echo "Aborted."
