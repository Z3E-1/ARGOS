#!/usr/bin/env bash
###############################################################################
# ARGOS - Wildcard Scanning
###############################################################################

source "$(dirname "$0")/../lib/argos_lib.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
 __        ___     
 \ \      / / 
  \ \ /\ / /  
   \ V  V /   
    \_/\_/    
          W I L D C A R D
EOF

WILDCARD="$1"
if [ -z "$WILDCARD" ]; then
  echo -ne "${CYAN}Enter base domain for wildcard (e.g. example.com): ${RESET}"
  read -r WILDCARD
  validate_domain "$WILDCARD"
fi
[ -z "$WILDCARD" ] && { echo -e "${RED}[!] No wildcard domain provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/wildcard_${WILDCARD//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Wildcard scanning for: *.$WILDCARD${RESET}"

SUBFILE="$LOOT_DIR/subdomains.txt"
LIVEFILE="$LOOT_DIR/alive.txt"

# Dependency Checks
declare -A dependencies=(
  ["subfinder"]="subfinder"
  ["amass"]="amass"
  ["httpx"]="httpx"
)

for tool in "${!dependencies[@]}"; do
  if ! command -v "${dependencies[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
    exit 1
  fi
done

# subfinder
echo -ne "${CYAN}[?] subfinder concurrency [default=10]: ${RESET}"
read -r SBTH
SBTH=${SBTH:-10}
echo -e "${CYAN}[*] Running subfinder ...${RESET}"
run_command "subfinder -d \"$WILDCARD\" -t \"$SBTH\" 2>&1 | stdbuf -oL tr '\r' '\n' | tee \"$SUBFILE\""

# amass
echo -e "${CYAN}[*] Running amass (passive) ...${RESET}"
run_command "amass enum -passive -d \"$WILDCARD\" 2>&1 | stdbuf -oL tr '\r' '\n' >> \"$SUBFILE\""
run_command "sort -u \"$SUBFILE\" -o \"$SUBFILE\""

# httpx
echo -e "${CYAN}[*] Checking alive subdomains with httpx ...${RESET}"
run_command "httpx -l \"$SUBFILE\" 2>&1 | stdbuf -oL tr '\r' '\n' | tee \"$LIVEFILE\""

echo -e "${GREEN}[WILDCARD] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
