#!/usr/bin/env bash
###############################################################################
# ARGOS - OSINT
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
       O S I N T
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target (IP, domain, username, etc.): ${RESET}"
  read -r TARGET
  validate_input "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No target provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/osint_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting OSINT on: $TARGET${RESET}"

# Dependency Checks
declare -A dependencies=(
  ["curl"]="curl"
  ["subfinder"]="subfinder"
  ["amass"]="amass"
  ["theHarvester"]="python3 ~/tools/theHarvester/theHarvester.py"
  ["GitDorker"]="python3 ~/tools/GitDorker/GitDorker.py"
)

for tool in "${!dependencies[@]}"; do
  case "$tool" in
    "theHarvester")
      if [ ! -x ~/tools/theHarvester/theHarvester.py ]; then
        echo -e "${RED}[!] Dependency not found or not executable: theHarvester.${RESET}"
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
echo -ne "${CYAN}[?] Perform a Full Passive scan? (theHarvester, GitDorker, etc.) y/N: ${RESET}"
read -r FULLPASS
FULLPASS=${FULLPASS:-n}

if [[ "$FULLPASS" =~ ^[Yy]$ ]]; then
  # Subfinder
  echo -ne "${CYAN}[?] Subfinder concurrency (default=10): ${RESET}"
  read -r SBTHREAD
  SBTHREAD=${SBTHREAD:-10}
  echo -e "${CYAN}[*] Running subfinder ...${RESET}"
  run_command "subfinder -d \"$TARGET\" -t \"$SBTHREAD\" 2>&1 | stdbuf -oL tr '\r' '\n' | tee \"$LOOT_DIR/subfinder.txt\""

  # theHarvester
  if [ -x ~/tools/theHarvester/theHarvester.py ]; then
    echo -e "${CYAN}[*] theHarvester ...${RESET}"
    run_command "python3 ~/tools/theHarvester/theHarvester.py -d \"$TARGET\" -b all -l 500 2>&1 | stdbuf -oL tr '\r' '\n' | tee \"$LOOT_DIR/theharvester.txt\""
  fi

  # GitDorker
  if [ -x ~/tools/GitDorker/GitDorker.py ]; then
    echo -ne "${CYAN}[?] GitHub Token (optional): ${RESET}"
    read -r GITHUB_TOK
    if [ -n "$GITHUB_TOK" ]; then
      echo -e "${CYAN}[*] GitDorker ...${RESET}"
      run_command "python3 ~/tools/GitDorker/GitDorker.py -t \"$GITHUB_TOK\" -q \"$TARGET\" -o \"$LOOT_DIR/gitdorker.txt\" 2>&1 | stdbuf -oL tr '\r' '\n'"
    else
      echo -e "${YELLOW}[!] No GitHub Token provided. Skipping GitDorker.${RESET}"
    fi
  fi
fi

# Additional OSINT Tools
echo -e "${CYAN}[*] Running additional OSINT tools ...${RESET}"

# ipinfo.io
if command -v curl >/dev/null; then
  echo -e "${CYAN}[*] Checking ipinfo.io ...${RESET}"
  run_command "curl -s \"https://ipinfo.io/$TARGET/json\" | tee \"$LOOT_DIR/ipinfo.json\""
else
  echo -e "${YELLOW}[!] curl not found. Skipping ipinfo.io check.${RESET}"
fi

# Have I Been Pwned
echo -ne "${CYAN}[?] Check Have I Been Pwned breaches? (y/N): ${RESET}"
read -r HIBP
HIBP=${HIBP:-n}
if [[ "$HIBP" =~ ^[Yy]$ ]]; then
  echo -e "${CYAN}[*] Checking Have I Been Pwned ...${RESET}"
  echo -ne "${CYAN}Enter email for HIBP check: ${RESET}"
  read -r EMAIL
  if [ -n "$EMAIL" ]; then
    run_command "curl -s \"https://haveibeenpwned.com/api/v3/breachedaccount/$EMAIL\" -H \"hibp-api-key: YOUR_API_KEY\" | tee \"$LOOT_DIR/hibp_breaches.json\""
    echo -e "${YELLOW}[!] Ensure you have a valid HIBP API key and replace YOUR_API_KEY in the script.${RESET}"
  else
    echo -e "${YELLOW}[!] No email provided. Skipping HIBP check.${RESET}"
  fi
fi

echo -e "${GREEN}[OSINT] Done. Results -> $LOOT_DIR${RESET}"
exit 0
