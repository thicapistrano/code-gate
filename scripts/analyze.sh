#!/usr/bin/env bash
set -euo pipefail

# Load .env from project root (one level above scripts/)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source "${ROOT_DIR}/.env"
  set +o allexport
fi

SONARQUBE_URL="${SONARQUBE_URL:-http://localhost:9020}"
SONARQUBE_TOKEN="${SONARQUBE_TOKEN:-}"
PROJECT_KEY=""
PROJECT_NAME=""
PROJECT_PATH=""
EXTRA_ARGS=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo -e "Usage: $0 -p <project_path> [options]"
  echo ""
  echo -e "Options:"
  echo -e "  -p  Path to the project to analyze ${RED}(required)${NC}"
  echo -e "  -k  SonarQube project key      (default: directory name, lowercase)"
  echo -e "  -n  SonarQube project name     (default: directory name)"
  echo -e "  -t  SonarQube token            (or set SONARQUBE_TOKEN env var / .env)"
  echo -e "  -s  SonarQube URL              (default: http://localhost:9020)"
  echo -e "  -h  Show this help"
  echo ""
  echo -e "Examples:"
  echo -e "  $0 -p ~/my-project"
  echo -e "  $0 -p ~/my-project -k my-key -n 'My Project'"
  exit 1
}

while getopts "p:k:n:t:s:h" opt; do
  case "$opt" in
    p) PROJECT_PATH="$OPTARG" ;;
    k) PROJECT_KEY="$OPTARG" ;;
    n) PROJECT_NAME="$OPTARG" ;;
    t) SONARQUBE_TOKEN="$OPTARG" ;;
    s) SONARQUBE_URL="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
if [ -z "$PROJECT_PATH" ]; then
  echo -e "${RED}Error: -p <project_path> is required.${NC}"
  usage
fi

PROJECT_PATH="$(realpath "$PROJECT_PATH")"

if [ ! -d "$PROJECT_PATH" ]; then
  echo -e "${RED}Error: '$PROJECT_PATH' is not a directory.${NC}"
  exit 1
fi

DIR_NAME="$(basename "$PROJECT_PATH")"
# Sanitize key: lowercase, replace spaces with underscores, keep alphanumeric/._-
PROJECT_KEY="${PROJECT_KEY:-$DIR_NAME}"
PROJECT_KEY="$(echo "$PROJECT_KEY" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_.-')"
PROJECT_NAME="${PROJECT_NAME:-$DIR_NAME}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SonarQube Local Code Analyzer${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "  Project Path : ${YELLOW}${PROJECT_PATH}${NC}"
echo -e "  Project Key  : ${YELLOW}${PROJECT_KEY}${NC}"
echo -e "  Project Name : ${YELLOW}${PROJECT_NAME}${NC}"
echo -e "  SonarQube    : ${YELLOW}${SONARQUBE_URL}${NC}"
echo ""

# ── Check SonarQube ──────────────────────────────────────────────────────────
echo -e "Checking SonarQube status..."
if ! curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
  echo -e "${RED}SonarQube is not running or not ready.${NC}"
  echo -e "Start it with: ${YELLOW}make start${NC}"
  echo -e "Run setup:     ${YELLOW}make setup${NC}"
  exit 1
fi
echo -e "${GREEN}SonarQube is up and running.${NC}\n"

# ── Build scanner args ───────────────────────────────────────────────────────
SCANNER_PROPS=(
  "-Dsonar.projectKey=${PROJECT_KEY}"
  "-Dsonar.projectName=${PROJECT_NAME}"
  "-Dsonar.sources=."
  "-Dsonar.host.url=${SONARQUBE_URL}"
  "-Dsonar.exclusions=**/node_modules/**,**/.git/**,**/dist/**,**/build/**,**/target/**,**/__pycache__/**,**/*.min.js,**/vendor/**,**/.next/**,**/coverage/**"
)

# Respect existing sonar-project.properties in the target project
if [ -f "${PROJECT_PATH}/sonar-project.properties" ]; then
  echo -e "${YELLOW}Found sonar-project.properties in project root — it will override defaults.${NC}\n"
fi

if [ -n "$SONARQUBE_TOKEN" ]; then
  SCANNER_PROPS+=("-Dsonar.token=${SONARQUBE_TOKEN}")
else
  echo -e "${YELLOW}Warning: no token set — falling back to admin/admin.${NC}"
  echo -e "Run ${CYAN}make setup${NC} to generate a proper token.\n"
  SCANNER_PROPS+=("-Dsonar.login=admin" "-Dsonar.password=admin")
fi

# ── Run scanner ──────────────────────────────────────────────────────────────
echo -e "Running SonarScanner...\n"

docker run --rm \
  --network host \
  -v "${PROJECT_PATH}:/usr/src" \
  -w /usr/src \
  sonarsource/sonar-scanner-cli:latest \
  "${SCANNER_PROPS[@]}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Analysis Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "View results: ${YELLOW}${SONARQUBE_URL}/dashboard?id=${PROJECT_KEY}${NC}"
