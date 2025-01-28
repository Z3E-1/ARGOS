#!/usr/bin/env bash
###############################################################################
# ARGOS - Massive Recon
###############################################################################

source "$(dirname "$0")/../utils.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
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
      M A S S I V E  R E C O N
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter domain (e.g. example.com) for repeated scans: ${RESET}"
  read -r TARGET
  validate_domain "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

echo -e "${RED}[!] MASSIVE RECON will repeatedly run subfinder + httpx + nuclei. Press Ctrl+C to stop.${RESET}"
echo -ne "${CYAN}[?] Interval in seconds? [default=300]: ${RESET}"
read -r INTERVAL
INTERVAL=${INTERVAL:-300}

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/massive_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting MASSIVE recon on $TARGET every $INTERVAL seconds. Press Ctrl+C to stop.${RESET}"

# Dependency Checks
declare -A dependencies=(
  ["subfinder"]="subfinder"
  ["httpx"]="httpx"
  ["nuclei"]="nuclei"
)

for tool in "${!dependencies[@]}"; do
  if ! command -v "${dependencies[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
    exit 1
  fi
done

# Trap Ctrl+C to exit gracefully
trap "echo -e '\n${YELLOW}[!] Massive Recon interrupted by user.${RESET}'; exit 0" SIGINT

while true; do
  CURRENT_TS=$(date +%Y%m%d_%H%M%S)
  CURRENT_LOOT_DIR="$LOOT_DIR/round_${CURRENT_TS}"
  mkdir -p "$CURRENT_LOOT_DIR"

  echo -e "${GREEN}[+] Starting round at $(date)${RESET}"

  SUBF="$CURRENT_LOOT_DIR/subfinder_${CURRENT_TS}.txt"
  LIVEF="$CURRENT_LOOT_DIR/alive_${CURRENT_TS}.txt"
  NUC="$CURRENT_LOOT_DIR/nuclei_${CURRENT_TS}.txt"

  # subfinder
  echo -e "${CYAN}[*] Running subfinder for $TARGET ...${RESET}"
  run_command "subfinder -d \"$TARGET\" -silent | tee \"$SUBF\""

  # httpx
  if [ -s "$SUBF" ]; then
    echo -e "${CYAN}[*] Checking alive subdomains with httpx ...${RESET}"
    run_command "httpx -l \"$SUBF\" -silent | tee \"$LIVEF\""
  else
    echo -e "${YELLOW}[!] No subdomains found by subfinder. Skipping httpx scan.${RESET}"
  fi

  # nuclei
  if [ -s "$LIVEF" ]; then
    echo -e "${CYAN}[*] Running nuclei scan ...${RESET}"
    echo -ne "${CYAN}[?] Nuclei severity filter? [low,medium,high,critical]: ${RESET}"
    read -r SEV
    SEV=${SEV:-low,medium,high,critical}
    run_command "nuclei -l \"$LIVEF\" -severity \"$SEV\" -o \"$NUC\""
  else
    echo -e "${YELLOW}[!] No alive subdomains to scan with nuclei.${RESET}"
  fi

  echo -e "${GREEN}[+] Round completed at $(date). Next round in $INTERVAL seconds...${RESET}"
  sleep "$INTERVAL"
done
