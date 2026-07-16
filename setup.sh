#!/usr/bin/env bash
set -euo pipefail

SONARQUBE_URL="${SONARQUBE_URL:-http://localhost:9000}"
ADMIN_USER="admin"
ADMIN_PASS_DEFAULT="admin"
ADMIN_PASS_NEW="${SONARQUBE_ADMIN_PASSWORD:-Admin@123}"
TOKEN_NAME="local-analyzer-$(date +%Y%m%d)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SonarQube First-Time Setup${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ── Wait for SonarQube ──────────────────────────────────────────────────────
echo -e "Waiting for SonarQube at ${YELLOW}${SONARQUBE_URL}${NC} ..."
RETRIES=0
until curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge 40 ]; then
    echo -e "\n${RED}Timeout: SonarQube did not become ready after ~2 minutes.${NC}"
    echo -e "Run ${YELLOW}make logs${NC} to check for errors."
    exit 1
  fi
  echo -n "."
  sleep 3
done
echo -e "\n${GREEN}SonarQube is ready!${NC}\n"

# ── Change default admin password ───────────────────────────────────────────
echo -e "Updating admin password..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${ADMIN_USER}:${ADMIN_PASS_DEFAULT}" \
  -X POST "${SONARQUBE_URL}/api/users/change_password" \
  -d "login=${ADMIN_USER}&password=${ADMIN_PASS_NEW}&previousPassword=${ADMIN_PASS_DEFAULT}" || true)

case "$HTTP_CODE" in
  204) echo -e "${GREEN}Password updated successfully.${NC}" ;;
  401) echo -e "${YELLOW}Password was already changed. Continuing...${NC}" ;;
  *)   echo -e "${YELLOW}Could not change password (HTTP ${HTTP_CODE}). Continuing...${NC}" ;;
esac

# ── Generate analysis token ─────────────────────────────────────────────────
echo -e "\nGenerating analysis token '${TOKEN_NAME}'..."
TOKEN_RESPONSE=$(curl -sf \
  -u "${ADMIN_USER}:${ADMIN_PASS_NEW}" \
  -X POST "${SONARQUBE_URL}/api/user_tokens/generate" \
  -d "name=${TOKEN_NAME}" 2>/dev/null || true)

if echo "${TOKEN_RESPONSE}" | grep -q '"token"'; then
  TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

  # Persist to .env (remove stale entries first)
  touch .env
  sed -i '/^SONARQUBE_TOKEN=/d' .env
  sed -i '/^SONARQUBE_ADMIN_PASSWORD=/d' .env
  sed -i '/^SONARQUBE_URL=/d' .env
  {
    echo "SONARQUBE_URL=${SONARQUBE_URL}"
    echo "SONARQUBE_TOKEN=${TOKEN}"
    echo "SONARQUBE_ADMIN_PASSWORD=${ADMIN_PASS_NEW}"
  } >> .env

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Setup Complete!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "Token saved to ${YELLOW}.env${NC}"
  echo -e "Admin password: ${YELLOW}${ADMIN_PASS_NEW}${NC}"
  echo -e "Dashboard: ${YELLOW}${SONARQUBE_URL}${NC}"
  echo ""
  echo -e "Run your first analysis:"
  echo -e "  ${CYAN}make analyze DIR=/path/to/your/project${NC}"
else
  echo -e "${RED}Could not generate token automatically.${NC}"
  echo -e "Please generate one manually:"
  echo -e "  1. Open ${SONARQUBE_URL}"
  echo -e "  2. Login as ${ADMIN_USER} / ${ADMIN_PASS_NEW}"
  echo -e "  3. My Account → Security → Generate Tokens"
  echo -e "  4. Export: ${YELLOW}export SONARQUBE_TOKEN=<your-token>${NC}"
  exit 1
fi
