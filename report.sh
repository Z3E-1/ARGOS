#!/usr/bin/env bash
###############################################################################
# ARGOS - Generate a comprehensive HTML report from ./loot
###############################################################################

source "./../utils.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

REPORT_NAME="argos_report_$(date +%Y%m%d_%H%M%S).html"
LOOT_DIR="./loot"

echo -e "${CYAN}[+] Generating HTML report from $LOOT_DIR ...${RESET}"

cat << EOF > "$REPORT_NAME"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8"/>
    <title>ARGOS Pentest Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2, h3 { color: #2E8B57; }
        pre { background-color: #f4f4f4; padding: 10px; border: 1px solid #ddd; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        table, th, td { border: 1px solid #ddd; }
        th, td { padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background-color: #e7f3fe; padding: 10px; border-left: 6px solid #2196F3; }
    </style>
</head>
<body>
    <h1>ARGOS Pentest Report</h1>
    <p>Generated on $(date)</p>

    <h2>Loot Directory Structure</h2>
    <pre>
EOF

if command -v tree >/dev/null; then
    tree -a "$LOOT_DIR" >> "$REPORT_NAME" 2>/dev/null
else
    find "$LOOT_DIR" >> "$REPORT_NAME" 2>/dev/null
fi

echo "</pre>" >> "$REPORT_NAME"

# Function to include file contents
include_file() {
    local filepath="$1"
    local title="$2"
    if [ -f "$filepath" ]; then
        echo "<h3>$title: $(basename "$filepath")</h3><pre>" >> "$REPORT_NAME"
        cat "$filepath" >> "$REPORT_NAME"
        echo "</pre>" >> "$REPORT_NAME"
    else
        echo "<h3>$title:</h3><p>File not found.</p>" >> "$REPORT_NAME"
    fi
}

# Summary Section
echo "<h2>Summary of Findings</h2>" >> "$REPORT_NAME"
echo "<div class='summary'>" >> "$REPORT_NAME"

# Count files and vulnerabilities
TOTAL_SUBDOMAINS=$(find "$LOOT_DIR" -type f -name "subdomains.txt" | xargs wc -l | tail -n1 | awk '{print $1}')
TOTAL_LIVE=$(find "$LOOT_DIR" -type f -name "live.txt" | xargs wc -l | tail -n1 | awk '{print $1}')
TOTAL_NUCLEI=$(find "$LOOT_DIR" -type f -name "nuclei.txt" | xargs wc -l | tail -n1 | awk '{print $1}')
TOTAL_SUBJACK=$(find "$LOOT_DIR" -type f -name "subjack.txt" | grep -c "potentially vulnerable")
TOTAL_XSS=$(find "$LOOT_DIR" -type f -name "xss.txt" | xargs wc -l | tail -n1 | awk '{print $1}')
TOTAL_SQLI=$(find "$LOOT_DIR" -type f -name "sqli_output.log" | grep -c "interesting")

echo "<ul>
    <li>Total Subdomains: $TOTAL_SUBDOMAINS</li>
    <li>Total Alive Subdomains: $TOTAL_LIVE</li>
    <li>Nuclei Findings: $TOTAL_NUCLEI</li>
    <li>Subdomain Takeovers: $TOTAL_SUBJACK</li>
    <li>SPF/DMARC Issues: $TOTAL_MAILSPOOF</li>
    <li>XSS Vulnerabilities: $TOTAL_XSS</li>
    <li>SQLi Vulnerabilities: $TOTAL_SQLI</li>
</ul>" >> "$REPORT_NAME"

echo "</div>" >> "$REPORT_NAME"

# Detailed Findings
echo "<h2>Detailed Findings</h2>" >> "$REPORT_NAME"

# Nmap Results
echo "<h3>Nmap Results</h3>" >> "$REPORT_NAME"
NMAPS=$(find "$LOOT_DIR" -type f -name "*.nmap" 2>/dev/null)
if [ -n "$NMAPS" ]; then
    for f in $NMAPS; do
        echo "<h4>$(basename "$f")</h4><pre>" >> "$REPORT_NAME"
        cat "$f" >> "$REPORT_NAME"
        echo "</pre>" >> "$REPORT_NAME"
    done
else
    echo "<p>No .nmap files found.</p>" >> "$REPORT_NAME"
fi

# Metasploit Results
METASPLOIT_OUT="$LOOT_DIR/output"
if [ -d "$METASPLOIT_OUT" ]; then
    echo "<h3>Metasploit Results</h3><pre>" >> "$REPORT_NAME"
    find "$METASPLOIT_OUT" -type f | while read -r file; do
        echo "<h4>$(basename "$file")</h4><pre>" >> "$REPORT_NAME"
        cat "$file" >> "$REPORT_NAME"
        echo "</pre>" >> "$REPORT_NAME"
    done
    echo "</pre>" >> "$REPORT_NAME"
else
    echo "<h3>Metasploit Results</h3><p>No Metasploit output found.</p>" >> "$REPORT_NAME"
fi

# Vulnerability Scans
echo "<h3>Vulnerability Scans</h3>" >> "$REPORT_NAME"



# Include subjack
include_file "$LOOT_DIR/subjack.txt" "Subdomain Takeover Check (subjack)"

# Include nuclei
include_file "$LOOT_DIR/nuclei.txt" "Nuclei Scan Results"

# Include xss
include_file "$LOOT_DIR/xss.txt" "XSS Vulnerabilities (dalfox)"

# Include sqlmap
include_file "$LOOT_DIR/sqli.txt" "SQLi Vulnerabilities (sqlmap)"

echo "<h3>Additional Vulnerability Scans</h3>" >> "$REPORT_NAME"
ADDITIONAL_FILES=$(find "$LOOT_DIR" -type f \( -name "responder*.log" -o -name "bettercap*.log" \) 2>/dev/null)
if [ -n "$ADDITIONAL_FILES" ]; then
    for f in $ADDITIONAL_FILES; do
        echo "<h4>$(basename "$f")</h4><pre>" >> "$REPORT_NAME"
        cat "$f" >> "$REPORT_NAME"
        echo "</pre>" >> "$REPORT_NAME"
    done
else
    echo "<p>No additional vulnerability scan logs found.</p>" >> "$REPORT_NAME"
fi

# End of Report
echo "<p>End of ARGOS report.</p></body></html>" >> "$REPORT_NAME"

echo -e "${GREEN}[+] Report saved as: $REPORT_NAME${RESET}"
exit 0
