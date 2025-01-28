#!/usr/bin/env bash
###############################################################################
# ARGOS - Passive Recon
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
  _ _ _
|       \
|   -    |
|  _ _ _/
|  |      
|__|
      P A S S I V E
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter domain (e.g. example.com): ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

echo -ne "${CYAN}[?] Perform a Full Passive scan? (theHarvester, GitDorker, etc.) y/N: ${RESET}"
read -r FULLPASS
FULLPASS=${FULLPASS:-n}

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/passive_${TARGET}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting PASSIVE recon on: $TARGET${RESET}"

# WHOIS
if command -v whois >/dev/null; then
  echo -e "${CYAN}[*] WHOIS ...${RESET}"
  whois "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/whois.txt"
fi

# DIG ANY
if command -v dig >/dev/null; then
  echo -e "${CYAN}[*] DIG (ANY) ...${RESET}"
  dig "$TARGET" ANY +noall +answer 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/dig.txt"
fi

# NSLOOKUP
if command -v nslookup >/dev/null; then
  echo -e "${CYAN}[*] NSLOOKUP ...${RESET}"
  nslookup "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/nslookup.txt"
fi

# Subfinder
if command -v subfinder >/dev/null && [[ "$FULLPASS" =~ ^[Yy]$ ]]; then
  echo -ne "${CYAN}[?] Subfinder concurrency (default=10): ${RESET}"
  read -r SBTHREAD
  SBTHREAD=${SBTHREAD:-10}
  echo -e "${CYAN}[*] Subfinder ...${RESET}"
  subfinder -d "$TARGET" -t "$SBTHREAD" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/subfinder.txt"
fi

# theHarvester
if [ -x ~/tools/theHarvester/theHarvester.py ] && [[ "$FULLPASS" =~ ^[Yy]$ ]]; then
  echo -e "${CYAN}[*] theHarvester ...${RESET}"
  python3 ~/tools/theHarvester/theHarvester.py -d "$TARGET" -b all -l 500 \
    2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/theharvester.txt"
fi

# GitDorker
if [ -x ~/tools/GitDorker/GitDorker.py ] && [[ "$FULLPASS" =~ ^[Yy]$ ]]; then
  echo -ne "${CYAN}[?] GitHub Token (optional): ${RESET}"
  read -r GITHUB_TOK
  if [ -n "$GITHUB_TOK" ]; then
    echo -e "${CYAN}[*] GitDorker ...${RESET}"
    python3 ~/tools/GitDorker/GitDorker.py -t "$GITHUB_TOK" -q "$TARGET" -o "$LOOT_DIR/gitdorker.txt" \
      2>&1 | stdbuf -oL tr '\r' '\n'
  fi
fi

echo -e "${GREEN}[PASSIVE] Done. Results -> $LOOT_DIR${RESET}"
exit 0
