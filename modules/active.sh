# active.sh
#!/usr/bin/env bash
###############################################################################
# ARGOS - Active Scanning
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
      A C T I V E
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target IP/CIDR (e.g., 192.168.1.0/24): ${RESET}"
  read -r TARGET
  validate_ipcidr "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No target provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/active_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting ACTIVE scan on: $TARGET${RESET}"

# Dependency Checks
declare -A dependencies=(
  ["nmap"]="nmap"
  ["masscan"]="masscan"
)

for tool in "${!dependencies[@]}"; do
  if ! command -v "${dependencies[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
    exit 1
  fi
done

echo -ne "${CYAN}[?] Nmap scan intensity T(1-5) [default=4]: ${RESET}"
read -r NMAP_T
NMAP_T=${NMAP_T:-4}

NMAP_OUT="$LOOT_DIR/nmap_${TARGET//\//_}_${TS}"
echo -e "${CYAN}[*] Running Nmap scan (T${NMAP_T})...${RESET}"
run_command "nmap -sV -sC -O -Pn -p- -T${NMAP_T} ${TARGET} -oA ${NMAP_OUT}"

echo -ne "${CYAN}[?] Run Masscan? (y/N): ${RESET}"
read -r RUN_MS
if [[ "$RUN_MS" =~ ^[Yy]$ ]]; then
  echo -ne "${CYAN}[?] Masscan rate (default=10000): ${RESET}"
  read -r MSRATE
  MSRATE=${MSRATE:-10000}
  
  MASSCAN_OUT="$LOOT_DIR/masscan_${TARGET//\//_}_${TS}.txt"
  echo -e "${CYAN}[*] Running Masscan at rate=${MSRATE}...${RESET}"
  run_command "sudo masscan ${TARGET} -p1-65535 --rate=${MSRATE} -oL ${MASSCAN_OUT}"
  
  # Parse open ports and run specific Nmap scan
  if [ -f "${MASSCAN_OUT}" ]; then
    PORTS=$(grep -Eo '^[0-9]+' "${MASSCAN_OUT}" | paste -sd, -)
    if [ -n "${PORTS}" ]; then
      SPEC_OUT="$LOOT_DIR/nmap_specific_${TARGET//\//_}_${TS}"
      echo -e "${CYAN}[*] Running Nmap scan on open ports: ${PORTS}...${RESET}"
      run_command "nmap -sV -sC -O -Pn -p${PORTS} ${TARGET} -oA ${SPEC_OUT}"
    else
      echo -e "${YELLOW}[!] No open ports found by Masscan.${RESET}"
    fi
  else
    echo -e "${RED}[!] Masscan output not found. Skipping specific Nmap scan.${RESET}"
  fi
fi

###############################################################################
# EKLEME BAŞLANGICI: Metasploit Entegrasyonu
###############################################################################

# Metasploit Automation
if command -v bash >/dev/null && [ -f "$(dirname "$0")/metasploit.sh" ]; then
  echo -e "${GREEN}[+] Starting Metasploit automation...${RESET}"
  
  # Determine which Nmap XML to use
  if [ -f "${NMAP_OUT}.xml" ]; then
    NMAP_XML="${NMAP_OUT}.xml"
  elif [ -f "${SPEC_OUT}.xml" ]; then
    NMAP_XML="${SPEC_OUT}.xml"
  else
    echo -e "${RED}[!] No Nmap XML output found. Skipping Metasploit automation.${RESET}"
    exit 1
  fi

  # Prompt for Metasploit parameters
  echo -ne "${CYAN}Enter LHOST for Metasploit (default=$(hostname -I | awk '{print $1}')): ${RESET}"
  read -r M_LHOST
  M_LHOST=${M_LHOST:-$(hostname -I | awk '{print $1}')}

  echo -ne "${CYAN}Enter LPORT for Metasploit (default=4444): ${RESET}"
  read -r M_LPORT
  M_LPORT=${M_LPORT:-4444}

  # Run Metasploit automation
  bash "$(dirname "$0")/metasploit.sh" --xml "${NMAP_XML}" --lhost "${M_LHOST}" --lport "${M_LPORT}" --loot "${LOOT_DIR}"

  echo -e "${GREEN}[+] Metasploit automation completed.${RESET}"
else
  echo -e "${RED}[!] metasploit.sh not found or bash not available. Skipping Metasploit automation.${RESET}"
fi

###############################################################################
# EKLEME SONU
###############################################################################

echo -e "${GREEN}[ACTIVE] Done. Loot -> ${LOOT_DIR}${RESET}"
exit 0
