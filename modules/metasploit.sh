#!/usr/bin/env bash
###############################################################################
# ARGOS - Metasploit Automation
###############################################################################

NMAP_XML=""
NMAP_GNMAP=""
LHOST="127.0.0.1"
LPORT="4444"
LOOT_DIR="./loot"
FORCE_DBIMPORT="0"

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${CYAN}=== METASPLOIT AUTOMATION ===${RESET}"

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
      shift ;;
  esac
done

if [ -z "$NMAP_XML" ] && [ -z "$NMAP_GNMAP" ]; then
  echo -e "${RED}Usage: $0 --xml <nmap.xml> [--lhost IP --lport PORT --force-dbimport]${RESET}"
  exit 1
fi

mkdir -p "$LOOT_DIR/output"

if ! command -v msfconsole >/dev/null; then
  echo -e "${RED}[!] msfconsole not found. Please install Metasploit.${RESET}"
  exit 1
fi

if ! command -v xmlstarlet >/dev/null; then
  echo -e "${RED}[!] xmlstarlet not found. Please install xmlstarlet.${RESET}"
  exit 1
fi

sudo systemctl start postgresql
sudo msfdb init
sudo msfdb start

WORKSPACE="autopwn_ws"
TMPDIR="$LOOT_DIR/tmp"
mkdir -p "$TMPDIR"
IPLIST="$TMPDIR/iplist.txt"

RCFILE="$TMPDIR/msf_import.rc"
{
  echo "workspace -a $WORKSPACE"
  echo "workspace $WORKSPACE"
  [ -n "$NMAP_XML" ] && echo "db_import $NMAP_XML"
  [ -n "$NMAP_GNMAP" ] && echo "db_import $NMAP_GNMAP"
  echo "services -u"
  echo "vulns"
  echo "exit"
} > "$RCFILE"

msfconsole -q -r "$RCFILE"

echo -e "${GREEN}[Metasploit] Done. Results in $LOOT_DIR/output.${RESET}"
exit 0
