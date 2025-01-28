#!/usr/bin/env bash
###############################################################################
# ARGOS - Active Scanning
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
    ___          
   /   | 
  / /| | 
 / ___ |
/_/  |_/ 
      A C T I V E
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target IP/CIDR (e.g., 192.168.1.0/24): ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No target provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/active"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting ACTIVE scan on: $TARGET${RESET}"

echo -ne "${CYAN}[?] Nmap scan intensity T(1-5) [default=4]: ${RESET}"
read -r NMAP_T
NMAP_T=${NMAP_T:-4}

NMAP_OUT="$LOOT_DIR/nmap_$(echo "$TARGET" | sed 's|/|_|g')_${TS}"
if command -v nmap >/dev/null; then
  echo -e "${CYAN}[*] Nmap scanning (T${NMAP_T})...${RESET}"
  nmap -sV -sC -O -Pn -p- -T"$NMAP_T" "$TARGET" -oA "$NMAP_OUT" \
    2>&1 | stdbuf -oL tr '\r' '\n'
fi

MASSCAN_OUT="$LOOT_DIR/masscan_$(echo "$TARGET" | sed 's|/|_|g')_${TS}.txt"
echo -ne "${CYAN}[?] Run Masscan? (y/N): ${RESET}"
read -r RUN_MS
if [[ "$RUN_MS" =~ ^[Yy]$ ]]; then
  echo -ne "${CYAN}[?] Masscan rate (default=10000): ${RESET}"
  read -r MSRATE
  MSRATE=${MSRATE:-10000}
  if command -v masscan >/dev/null; then
    echo -e "${CYAN}[*] Masscan scanning all ports at rate=$MSRATE ...${RESET}"
    sudo masscan "$TARGET" -p1-65535 --rate="$MSRATE" -oL "$MASSCAN_OUT" \
      2>&1 | stdbuf -oL tr '\r' '\n'
    # parse open ports -> nmap
    if [ -f "$MASSCAN_OUT" ]; then
      PORTS=$(grep -oP '(?<=open tcp ).*' "$MASSCAN_OUT" | tr '\n' ',' | sed 's/,$//')
      if [ -n "$PORTS" ]; then
        SPEC_OUT="$LOOT_DIR/nmap_specific_$(echo "$TARGET" | sed 's|/|_|g')_${TS}"
        echo -e "${CYAN}[*] Nmap scanning open ports: $PORTS${RESET}"
        nmap -sV -sC -O -Pn -p"$PORTS" "$TARGET" -oA "$SPEC_OUT" \
          2>&1 | stdbuf -oL tr '\r' '\n'
      fi
    fi
  else
    echo -e "${RED}[!] masscan not found.${RESET}"
  fi
fi

echo -e "${GREEN}[ACTIVE] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
