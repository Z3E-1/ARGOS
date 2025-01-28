#!/usr/bin/env bash
###############################################################################
# ARGOS - Generate a simple HTML report from ./loot
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

REPORT_NAME="argos_report_$(date +%Y%m%d_%H%M%S).html"
LOOT_DIR="./loot"

echo -e "${CYAN}[+] Generating HTML report from $LOOT_DIR ...${RESET}"

cat << EOF > "$REPORT_NAME"
<html><head><meta charset="UTF-8"/><title>ARGOS Pentest Report</title></head>
<body style="font-family:sans-serif;">
<h1>ARGOS Pentest Report</h1>
<p>Generated on $(date)</p>
EOF

# Directory tree
echo "<h2>Loot Directory Structure</h2><pre>" >> "$REPORT_NAME"
if command -v tree >/dev/null; then
  tree -a "$LOOT_DIR" >> "$REPORT_NAME" 2>/dev/null
else
  # fallback
  find "$LOOT_DIR" >> "$REPORT_NAME" 2>/dev/null
fi
echo "</pre>" >> "$REPORT_NAME"

# Example: parse .nmap files
echo "<h2>Nmap Results Found</h2>" >> "$REPORT_NAME"
NMAPS=$(find "$LOOT_DIR" -type f -name "*.nmap" 2>/dev/null)
if [ -n "$NMAPS" ]; then
  for f in $NMAPS; do
    echo "<h3>$f</h3><pre>" >> "$REPORT_NAME"
    cat "$f" >> "$REPORT_NAME"
    echo "</pre>" >> "$REPORT_NAME"
  done
else
  echo "<p>No .nmap files found.</p>" >> "$REPORT_NAME"
fi

# Nuclei results
echo "<h2>Vulnerability Scans</h2>" >> "$REPORT_NAME"
find "$LOOT_DIR" -type f \( -name "nuclei.txt" -o -name "xss.txt" -o -name "sqli.txt" \) | while read -r f; do
  echo "<h3>$(basename "$f")</h3><pre>" >> "$REPORT_NAME"
  cat "$f" >> "$REPORT_NAME"
  echo "</pre>" >> "$REPORT_NAME"
done

echo "<p>End of Argos report.</p></body></html>" >> "$REPORT_NAME"

echo -e "${GREEN}[+] Report saved as: $REPORT_NAME${RESET}"
exit 0
