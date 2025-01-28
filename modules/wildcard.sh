#!/usr/bin/env bash
###############################################################################
# ARGOS - Wildcard Scanning
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
 __        ___     
 \ \      / / (_)
  \ \ /\ / /  | |
   \ V  V /   | |  
    \_/\_/    
          W I L D C A R D
EOF

WILDCARD="$1"
if [ -z "$WILDCARD" ]; then
  echo -ne "${CYAN}Enter base domain for wildcard (e.g. example.com): ${RESET}"
  read -r WILDCARD
fi
[ -z "$WILDCARD" ] && { echo -e "${RED}[!] No wildcard domain provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/wildcard_${WILDCARD}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Wildcard scanning for: *.$WILDCARD${RESET}"

SUBFILE="$LOOT_DIR/subdomains.txt"
LIVEFILE="$LOOT_DIR/alive.txt"

# subfinder
if command -v subfinder >/dev/null; then
  echo -ne "${CYAN}[?] subfinder concurrency [default=10]: ${RESET}"
  read -r SBTH
  SBTH=${SBTH:-10}
  echo -e "${CYAN}[*] subfinder ...${RESET}"
  subfinder -d "$WILDCARD" -t "$SBTH" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$SUBFILE"
fi

# amass
if command -v amass >/dev/null; then
  echo -e "${CYAN}[*] amass (passive) ...${RESET}"
  amass enum -passive -d "$WILDCARD" 2>&1 | stdbuf -oL tr '\r' '\n' >> "$SUBFILE"
  sort -u "$SUBFILE" -o "$SUBFILE"
fi

# httpx
if command -v httpx >/dev/null && [ -s "$SUBFILE" ]; then
  echo -e "${CYAN}[*] Checking alive with httpx ...${RESET}"
  httpx -l "$SUBFILE" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LIVEFILE"
fi

echo -e "${GREEN}[WILDCARD] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
