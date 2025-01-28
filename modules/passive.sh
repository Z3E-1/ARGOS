#!/usr/bin/env bash
###############################################################################
# ARGOS - Passive Recon
###############################################################################

source "$(dirname "$0")/../lib/argos_lib.sh"
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
      P A S S I V E
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter domain (e.g. example.com): ${RESET}"
  read -r TARGET
  validate_domain "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

echo -ne "${CYAN}[?] Perform a Full Passive scan? (theHarvester, GitDorker, etc.) y/N: ${RESET}"
read -r FULLPASS
FULLPASS=${FULLPASS:-n}

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/passive_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting PASSIVE recon on: $TARGET${RESET}"

# Dependency Checks
declare -A dependencies=(
  ["whois"]="whois"
  ["dig"]="dig"
  ["nslookup"]="nslookup"
  ["subfinder"]="subfinder"
  ["theHarvester"]="theHarvester"
  ["GitDorker"]="GitDorker.py"
)

for tool in "${!dependencies[@]}"; do
  case "$tool" in
    "theHarvester")
      if ! command -v theHarvester >/dev/null; then
        echo -e "${RED}[!] Dependency not found: theHarvester. Please install it first.${RESET}"
        exit 1
      fi
      ;;
    "GitDorker")
      if [ ! -x ~/tools/GitDorker/GitDorker.py ]; then
        echo -e "${RED}[!] Dependency not found or not executable: GitDorker.${RESET}"
        exit 1
      fi
      ;;
    *)
      if ! command -v "${dependencies[$tool]}" >/dev/null; then
        echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
        exit 1
      fi
      ;;
  esac
done

# WHOIS
echo -e "${CYAN}[*] WHOIS ...${RESET}"
run_command "whois \"$TARGET\" | tee \"$LOOT_DIR/whois.txt\""

# DIG ANY
echo -e "${CYAN}[*] DIG (ANY) ...${RESET}"
run_command "dig \"$TARGET\" ANY +noall +answer | tee \"$LOOT_DIR/dig.txt\""

# NSLOOKUP
echo -e "${CYAN}[*] NSLOOKUP ...${RESET}"
run_command "nslookup \"$TARGET\" | tee \"$LOOT_DIR/nslookup.txt\""

# Full Passive Scan
if [[ "$FULLPASS" =~ ^[Yy]$ ]]; then
  # Subfinder
  echo -ne "${CYAN}[?] Subfinder concurrency (default=10): ${RESET}"
  read -r SBTHREAD
  SBTHREAD=${SBTHREAD:-10}
  echo -e "${CYAN}[*] Running subfinder ...${RESET}"
  run_command "subfinder -d \"$TARGET\" -t \"$SBTHREAD\" 2>&1 | tee \"$LOOT_DIR/subfinder.txt\""

  # theHarvester
  if command -v theHarvester >/dev/null; then
    echo -e "${CYAN}[*] theHarvester ...${RESET}"
    run_command "theHarvester -d \"$TARGET\" -b all -l 500 2>&1 | tee \"$LOOT_DIR/theharvester.txt\""
  fi

  # GitDorker
  if [ -x ~/tools/GitDorker/GitDorker.py ]; then
    echo -ne "${CYAN}[?] GitHub Token (optional): ${RESET}"
    read -r GITHUB_TOK
    if [ -n "$GITHUB_TOK" ]; then
      echo -e "${CYAN}[*] GitDorker ...${RESET}"
      run_command "python3 ~/tools/GitDorker/GitDorker.py -t \"$GITHUB_TOK\" -q \"$TARGET\" | tee \"$LOOT_DIR/gitdorker.txt\""
    else
      echo -e "${YELLOW}[!] No GitHub Token provided. Skipping GitDorker.${RESET}"
    fi
  fi
fi

echo -e "${GREEN}[PASSIVE] Done. Results -> $LOOT_DIR${RESET}"
exit 0
