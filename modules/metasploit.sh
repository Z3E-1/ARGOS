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
  echo -e "${RED}[!] msfconsole not found. Skipping Metasploit module.${RESET}"
  exit 1
fi
if ! command -v xmlstarlet >/dev/null; then
  echo -e "${RED}[!] xmlstarlet not found. Skipping parse logic.${RESET}"
  exit 1
fi

WORKSPACE="autopwn_ws"
TMPDIR="$LOOT_DIR/tmp"
mkdir -p "$TMPDIR"
IPLIST="$TMPDIR/iplist.txt"

echo -e "${GREEN}[+] Starting Metasploit autopwn...${RESET}"

# Metasploit veritabanını başlat
sudo systemctl start postgresql
sudo msfdb init
sudo msfdb start

# Create or switch workspace, import if forced
RCFILE="$TMPDIR/msf_import.rc"
{
  echo "workspace -a $WORKSPACE"
  echo "workspace $WORKSPACE"
  if [ "$FORCE_DBIMPORT" = "1" ]; then
    [ -n "$NMAP_XML" ] && echo "db_import $NMAP_XML"
    [ -n "$NMAP_GNMAP" ] && echo "db_import $NMAP_GNMAP"
  fi
  echo "services -u"
  echo "vulns"
  echo "exit"
} > "$RCFILE"

msfconsole -q -r "$RCFILE" </dev/null >/dev/null 2>&1
rm -f "$RCFILE"

# Parse open ports
if [ -n "$NMAP_XML" ] && [ -f "$NMAP_XML" ]; then
  xmlstarlet sel -t -m '//host' -m 'ports/port[state/@state="open"]' \
    -v 'concat(address[@addrtype="ipv4"]/@addr,"|",@portid,"|",service/@name,"|",service/@product,"|",service/@version)' -n "$NMAP_XML" \
    2>&1 | stdbuf -oL tr '\r' '\n' > "$IPLIST"
elif [ -n "$NMAP_GNMAP" ] && [ -f "$NMAP_GNMAP" ]; then
  grep "^Host: " "$NMAP_GNMAP" | awk '{print $2}' > "$IPLIST"
fi

[ ! -s "$IPLIST" ] && echo -e "${RED}[!] No valid services from scan output.${RESET}" && exit 1

while IFS='|' read -r ip port sname sprod sver; do
  [ -z "$ip" ] && continue
  echo -e "${CYAN}[*] Trying $sname modules on $ip:$port ...${RESET}"
  msfconsole -q -x "
    use auxiliary/scanner/${sname}/${sname}_version
    set RHOSTS $ip
    set RPORT $port
    set LHOST $LHOST
    set LPORT $LPORT
    run
    exit
  " </dev/null 2>&1 | stdbuf -oL tr '\r' '\n'
done < "$IPLIST"

echo -e "${GREEN}[Metasploit] Done. Results in $LOOT_DIR/output.${RESET}"
exit 0