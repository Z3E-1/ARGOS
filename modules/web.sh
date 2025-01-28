#!/usr/bin/env bash
###############################################################################
# ARGOS - Web & API Analysis
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"
 __        __   _     
 \ \      / /__| |__  
  \ \ /\ / / _ \ '_ \ 
   \ V  V /  __/ |_) |
    \_/\_/ \___|_.__/ 
   W E B  &  A P I
EOF

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target domain (e.g. example.com): ${RESET}"
  read -r TARGET
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/web_${TARGET}_${TS}"
mkdir -p "$LOOT_DIR"

echo -e "${GREEN}[+] Starting WEB & API analysis on: $TARGET${RESET}"

SUBF="$LOOT_DIR/subdomains.txt"
LIVEF="$LOOT_DIR/live.txt"

# subfinder
if command -v subfinder >/dev/null; then
  echo -ne "${CYAN}[?] subfinder concurrency? [default=10]: ${RESET}"
  read -r SUBT
  SUBT=${SUBT:-10}
  echo -e "${CYAN}[*] Running subfinder ...${RESET}"
  subfinder -d "$TARGET" -t "$SUBT" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$SUBF"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] subfinder failed. Check logs for details.${RESET}"
  fi
else
  echo -e "${RED}[!] subfinder not found. Skipping subdomain enumeration.${RESET}"
fi

# amass (passive)
if command -v amass >/dev/null; then
  echo -e "${CYAN}[*] Running amass (passive) ...${RESET}"
  amass enum -passive -d "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' >> "$SUBF"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] amass failed. Check logs for details.${RESET}"
  fi
else
  echo -e "${RED}[!] amass not found. Skipping passive enumeration.${RESET}"
fi

# Sort and deduplicate subdomains
if [ -f "$SUBF" ]; then
  sort -u "$SUBF" -o "$SUBF"
  echo -e "${GREEN}[+] Subdomains collected: $(wc -l < "$SUBF")${RESET}"
fi

# httpx (check alive subdomains)
if command -v httpx >/dev/null && [ -s "$SUBF" ]; then
  echo -e "${CYAN}[*] Checking alive subdomains with httpx ...${RESET}"
  httpx -l "$SUBF" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LIVEF"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] httpx failed. Check logs for details.${RESET}"
  else
    echo -e "${GREEN}[+] Alive subdomains: $(wc -l < "$LIVEF")${RESET}"
  fi
else
  echo -e "${RED}[!] httpx not found or no subdomains to check. Skipping alive check.${RESET}"
fi

# Zafiyet taramalarını başlat
echo -e "${CYAN}[*] Starting vulnerability scans...${RESET}"

# Nuclei taraması
if command -v nuclei >/dev/null; then
  echo -ne "${CYAN}[?] Nuclei severity filter? [low,medium,high,critical]: ${RESET}"
  read -r SEV
  SEV=${SEV:-low,medium,high,critical}
  echo -e "${CYAN}[*] Running Nuclei scan (severity: $SEV) ...${RESET}"
  nuclei -u "$TARGET" -severity "$SEV" -o "$LOOT_DIR/nuclei.txt" \
    2>&1 | stdbuf -oL tr '\r' '\n'
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Nuclei scan failed. Check logs for details.${RESET}"
  else
    echo -e "${GREEN}[+] Nuclei findings: $(wc -l < "$LOOT_DIR/nuclei.txt")${RESET}"
  fi
else
  echo -e "${RED}[!] nuclei not found. Skipping Nuclei scan.${RESET}"
fi

# Subdomain takeover taraması (subjack)
if command -v subjack >/dev/null; then
  echo -e "${CYAN}[*] Running subdomain takeover check with subjack ...${RESET}"
  echo "$TARGET" | subjack -ssl -v 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/subjack.txt"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] subjack failed. Check logs for details.${RESET}"
  else
    echo -e "${GREEN}[+] Subdomain takeovers: $(wc -l < "$LOOT_DIR/subjack.txt")${RESET}"
  fi
else
  echo -e "${RED}[!] subjack not found. Skipping subdomain takeover check.${RESET}"
fi

# SPF/DMARC taraması (mailspoof)
if command -v mailspoof >/dev/null; then
  echo -e "${CYAN}[*] Running SPF/DMARC check with mailspoof ...${RESET}"
  mailspoof -d "$TARGET" 2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/mailspoof.txt"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] mailspoof failed. Check logs for details.${RESET}"
  else
    echo -e "${GREEN}[+] SPF/DMARC issues: $(wc -l < "$LOOT_DIR/mailspoof.txt")${RESET}"
  fi
else
  echo -e "${RED}[!] mailspoof not found. Skipping SPF/DMARC check.${RESET}"
fi

# XSS taraması (dalfox)
if command -v dalfox >/dev/null && command -v gau >/dev/null && command -v gf >/dev/null; then
  echo -ne "${CYAN}[?] Blind XSS Collab URL (enter if you have one): ${RESET}"
  read -r BLINDXSS
  if [ -n "$BLINDXSS" ]; then
    echo -e "${CYAN}[*] Blind XSS Collab URL provided: $BLINDXSS${RESET}"
  else
    echo -e "${CYAN}[*] No Blind XSS Collab URL provided. Running standard XSS scan.${RESET}"
  fi
  echo -e "${CYAN}[*] Running XSS check with dalfox ...${RESET}"
  gau "$TARGET" 2>&1 | gf xss | sed 's/=.*/=/' | sed 's/URL: //' \
    | dalfox pipe -o "$LOOT_DIR/xss.txt" $( [ -n "$BLINDXSS" ] && echo "--blind $BLINDXSS" ) \
      2>&1 | stdbuf -oL tr '\r' '\n'
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] dalfox failed. Check logs for details.${RESET}"
  else
    echo -e "${GREEN}[+] XSS vulnerabilities: $(wc -l < "$LOOT_DIR/xss.txt")${RESET}"
  fi
else
  echo -e "${RED}[!] dalfox, gau, or gf not found. Skipping XSS scan.${RESET}"
fi

# SQLi taraması (sqlmap)
if command -v sqlmap >/dev/null && command -v gf >/dev/null && command -v gau >/dev/null; then
  echo -e "${CYAN}[*] Running SQLi check with sqlmap ...${RESET}"
  gau "$TARGET" 2>&1 | gf sqli > "$LOOT_DIR/sqli_params.txt"
  if [ -s "$LOOT_DIR/sqli_params.txt" ]; then
    sqlmap -m "$LOOT_DIR/sqli_params.txt" --batch --random-agent --level=1 \
      2>&1 | stdbuf -oL tr '\r' '\n' | tee "$LOOT_DIR/sqli.txt"
    if [ $? -ne 0 ]; then
      echo -e "${RED}[!] sqlmap failed. Check logs for details.${RESET}"
    else
      echo -e "${GREEN}[+] SQLi vulnerabilities: $(wc -l < "$LOOT_DIR/sqli.txt")${RESET}"
    fi
  else
    echo -e "${RED}[!] No SQLi parameters found. Skipping SQLi scan.${RESET}"
  fi
else
  echo -e "${RED}[!] sqlmap, gau, or gf not found. Skipping SQLi scan.${RESET}"
fi

# Sonuçların özeti
echo -e "${GREEN}[+] Web & API analysis completed.${RESET}"
echo -e "${CYAN}[*] Loot directory: $LOOT_DIR${RESET}"
echo -e "${CYAN}[*] Subdomains: $(wc -l < "$SUBF")${RESET}"
echo -e "${CYAN}[*] Alive subdomains: $(wc -l < "$LIVEF")${RESET}"
echo -e "${CYAN}[*] Nuclei findings: $(wc -l < "$LOOT_DIR/nuclei.txt")${RESET}"
echo -e "${CYAN}[*] Subdomain takeovers: $(wc -l < "$LOOT_DIR/subjack.txt")${RESET}"
echo -e "${CYAN}[*] SPF/DMARC issues: $(wc -l < "$LOOT_DIR/mailspoof.txt")${RESET}"
echo -e "${CYAN}[*] XSS vulnerabilities: $(wc -l < "$LOOT_DIR/xss.txt")${RESET}"
echo -e "${CYAN}[*] SQLi vulnerabilities: $(wc -l < "$LOOT_DIR/sqli.txt")${RESET}"

exit 0