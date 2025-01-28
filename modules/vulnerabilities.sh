#!/usr/bin/env bash
###############################################################################
# ARGOS - Vulnerabilities
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
 __      __                    
 \ \    / /  
  \ \  / /  
   \ \/ / 
    \__/ 
      V U L N E R A B I L I T I E S
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter domain (e.g. example.com): ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/vulns_${TARGET}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Checking vulnerabilities on: $TARGET${RESET}"

# mailspoof
if command -v mailspoof >/dev/null; then
  echo -e "${CYAN}[*] mailspoof (SPF/DMARC) ...${RESET}"
  mailspoof -d "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/mailspoof.txt"
fi

# subjack
if command -v subjack >/dev/null; then
  echo -e "${CYAN}[*] subjack (subdomain takeover) ...${RESET}"
  echo "$TARGET" | subjack -ssl -v 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/subjack.txt"
fi

# dalfox/gau/gf for XSS
if command -v dalfox >/dev/null && command -v gau >/dev/null && command -v gf >/dev/null; then
  echo -ne "${CYAN}[?] Blind XSS Collab URL (enter if you have one): ${RESET}"
  read -r BLINDXSS
  echo -e "${CYAN}[*] XSS check with dalfox ...${RESET}"
  gau "$TARGET" 2>&1 | gf xss | sed 's/=.*/=/' | sed 's/URL: //' \
    | dalfox pipe -o "$LOOT_DIR/xss.txt" $( [ -n "$BLINDXSS" ] && echo "--blind $BLINDXSS" ) \
      2>&1 | stdbuf -oL tr '\r' '\n'
fi

# sqlmap
if command -v sqlmap >/dev/null && command -v gf >/dev/null && command -v gau >/dev/null; then
  echo -e "${CYAN}[*] SQLi check with sqlmap ...${RESET}"
  gau "$TARGET" 2>&1 | gf sqli > "$LOOT_DIR/sqli_params.txt"
  sqlmap -m "$LOOT_DIR/sqli_params.txt" --batch --random-agent --level=1 \
    2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/sqli.txt"
fi

# nuclei
if command -v nuclei >/dev/null; then
  echo -ne "${CYAN}[?] Nuclei severity filter? [low,medium,high,critical]: ${RESET}"
  read -r SEV
  SEV=${SEV:-low,medium,high,critical}
  echo -e "${CYAN}[*] Nuclei scanning ($SEV) ...${RESET}"
  nuclei -u "$TARGET" -severity "$SEV" -o "$LOOT_DIR/nuclei.txt" \
    2>&1 | stdbuf -oL tr '\r' '\n'
fi

echo -e "${GREEN}[VULNS] Done. Loot -> $LOOT_DIR${RESET}"
exit 0
