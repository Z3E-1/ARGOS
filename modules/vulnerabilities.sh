#!/usr/bin/env bash
###############################################################################
# ARGOS - Vulnerabilities
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
      V U L N E R A B I L I T I E S
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target domain (e.g. example.com): ${RESET}"
  read -r TARGET
  validate_domain "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/vulns_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Checking vulnerabilities on: $TARGET${RESET}"

# Dependency Checks
declare -A dependencies=(
  ["subjack"]="subjack"
  ["dalfox"]="dalfox"
  ["gau"]="gau"
  ["gf"]="gf"
  ["sqlmap"]="sqlmap"
  ["nuclei"]="nuclei"
)

for tool in "${!dependencies[@]}"; do
  if ! command -v "${dependencies[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
    exit 1
  fi
done



# subjack (subdomain takeover)
echo -e "${CYAN}[*] subjack (subdomain takeover) ...${RESET}"
run_command "echo \"$TARGET\" | subjack -ssl -v | tee \"$LOOT_DIR/subjack.txt\""

# dalfox/gau/gf for XSS
echo -ne "${CYAN}[?] Blind XSS Collab URL (enter if you have one): ${RESET}"
read -r BLINDXSS
if [ -n "$BLINDXSS" ]; then
  echo -e "${CYAN}[*] Blind XSS Collab URL provided: $BLINDXSS${RESET}"
else
  echo -e "${CYAN}[*] No Blind XSS Collab URL provided. Running standard XSS scan.${RESET}"
fi
echo -e "${CYAN}[*] XSS check with dalfox ...${RESET}"
if [ -n "$BLINDXSS" ]; then
  run_command "gau \"$TARGET\" | gf xss | dalfox pipe -o \"$LOOT_DIR/xss.txt\" --blind \"$BLINDXSS\""
else
  run_command "gau \"$TARGET\" | gf xss | dalfox pipe -o \"$LOOT_DIR/xss.txt\""
fi

# sqlmap
echo -e "${CYAN}[*] SQLi check with sqlmap ...${RESET}"
run_command "gau \"$TARGET\" | gf sqli > \"$LOOT_DIR/sqli_params.txt\""
if [ -s "$LOOT_DIR/sqli_params.txt" ]; then
  run_command "sqlmap -m \"$LOOT_DIR/sqli_params.txt\" --batch --random-agent --level=1 | tee \"$LOOT_DIR/sqli.txt\""
else
  echo -e "${YELLOW}[!] No SQLi parameters found. Skipping SQLi scan.${RESET}"
fi

# nuclei
echo -ne "${CYAN}[?] Nuclei severity filter? [low,medium,high,critical]: ${RESET}"
read -r SEV
SEV=${SEV:-low,medium,high,critical}
echo -e "${CYAN}[*] Nuclei scanning ($SEV) ...${RESET}"
run_command "nuclei -u \"$TARGET\" -severity \"$SEV\" -o \"$LOOT_DIR/nuclei.txt\""

echo -e "${GREEN}[VULNS] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
