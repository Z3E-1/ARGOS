#!/usr/bin/env bash
###############################################################################
# ARGOS - OSINT
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
   ___   
  / _ \
 | | | |   
 | |_| |   
  \___/  
       O S I N T
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target (IP, domain, username, etc.): ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No target provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/osint_${TARGET}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting OSINT on: $TARGET${RESET}"

# ipinfo
if command -v curl >/dev/null; then
  echo -e "${CYAN}[*] Checking ipinfo.io ...${RESET}"
  curl -s "https://ipinfo.io/$TARGET/json" \
    2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/ipinfo.json"
fi

# Expand with haveibeenpwned, or other

echo -e "${GREEN}[OSINT] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
