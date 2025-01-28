#!/usr/bin/env bash
###############################################################################
# ARGOS - Massive Recon
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
   __  ___            _                  
  /  |/  /
 / /|_/ / 
/ /  / / 
/_/  /_/ 
      M A S S I V E  R E C O N
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter domain (e.g. example.com) for repeated scans: ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

echo -e "${RED}[!] MASSIVE RECON will repeatedly run subfinder + httpx + nuclei. Ctrl+C to stop.${RESET}"
echo -ne "${CYAN}[?] Interval in seconds? [default=300]: ${RESET}"
read -r INTERVAL
INTERVAL=${INTERVAL:-300}

LOOT_DIR="./loot/massive_${TARGET}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting MASSIVE recon on $TARGET every $INTERVAL s. Press Ctrl+C to stop.${RESET}"

while true; do
  TS=$(date +%Y%m%d_%H%M%S)
  SUBF="$LOOT_DIR/sub_${TS}.txt"
  LIVEF="$LOOT_DIR/alive_${TS}.txt"
  NUC="$LOOT_DIR/nuclei_${TS}.txt"

  if command -v subfinder >/dev/null; then
    echo -e "${CYAN}[*] subfinder ($TARGET) ...${RESET}"
    subfinder -d "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' > "$SUBF"
  fi

  if command -v httpx >/dev/null; then
    echo -e "${CYAN}[*] Checking alive with httpx ...${RESET}"
    httpx -l "$SUBF" 2>&1 | stdbuf -oL tr '\r' '\n' > "$LIVEF"
  fi

  if command -v nuclei >/dev/null; then
    echo -e "${CYAN}[*] Nuclei scanning ...${RESET}"
    nuclei -l "$LIVEF" -o "$NUC" \
      2>&1 | stdbuf -oL tr '\r' '\n'
  fi

  echo -e "${GREEN}[+] Round done at $(date). Next round in $INTERVAL sec...${RESET}"
  sleep "$INTERVAL"
done
