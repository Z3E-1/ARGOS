#!/usr/bin/env bash
###############################################################################
# ARGOS - Enhanced Install Script v2.1 (Kali Linux Fix)
###############################################################################

cd "$(dirname "$0")" || exit 1

# Renk kodları
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Hata yönetimi
trap 'echo -e "${RED}[!] Hata oluştu: $BASH_COMMAND${RESET}"; exit 1' ERR

function banner_install() {
  clear
  cat << "EOF"

 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
   A R G O S   I N S T A L L E R   v2.1
EOF
}

run_command() {
  echo -e "${CYAN}[+] Çalıştırılıyor: ${YELLOW}$1${RESET}"
  if ! eval "$1"; then
    echo -e "${RED}[!] Hata: Komut başarısız oldu - $1${RESET}"
    return 1
  fi
}

# Başlangıç kontrolleri
banner_install

# Temel bağımlılıklar
echo -e "${CYAN}[+] Temel bağımlılıklar kontrol ediliyor...${RESET}"
command -v curl >/dev/null || run_command "sudo apt install -y curl"
command -v git >/dev/null || run_command "sudo apt install -y git"
command -v python3 >/dev/null || run_command "sudo apt install -y python3 python3-pip"
command -v pip3 >/dev/null || run_command "sudo apt install -y python3-pip"

# Sistem güncellemeleri
echo -e "${CYAN}[+] Sistem paketleri güncelleniyor...${RESET}"
run_command "sudo apt update -y && sudo apt upgrade -y"

# Go kurulumu
GO_VERSION="1.22.4"
if ! command -v go >/dev/null || [[ $(go version | awk '{print $3}') != "go${GO_VERSION}" ]]; then
  echo -e "${CYAN}[+] Go ${GO_VERSION} kuruluyor...${RESET}"
  run_command "sudo rm -rf /usr/local/go"
  run_command "curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -xz -C /usr/local"
  
  # PATH güncellemesi
  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
  for SHELLRC in ~/.bashrc ~/.zshrc ~/.profile; do
    if ! grep -q "/usr/local/go/bin" "$SHELLRC"; then
      echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin' | tee -a "$SHELLRC" >/dev/null
    fi
  done
  source ~/.bashrc
else
  echo -e "${GREEN}[✓] Go zaten güncel (v${GO_VERSION})${RESET}"
fi

# Ana araç listesi
declare -A tools=(
  ["nmap"]="sudo apt install -y nmap"
  ["dalfox"]="go install github.com/hahwul/dalfox/v2@latest"
  ["subfinder"]="go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  ["amass"]="go install github.com/owasp/amass/v3/...@latest"
  ["httpx"]="go install github.com/projectdiscovery/httpx/cmd/httpx@latest"
  ["nuclei"]="go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  ["katana"]="go install github.com/projectdiscovery/katana/cmd/katana@latest"
  ["gau"]="go install github.com/lc/gau/v2/cmd/gau@latest"
  ["gf"]="go install github.com/tomnomnom/gf@latest"
  ["metasploit"]="curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && chmod 755 msfinstall && ./msfinstall"
  ["rustscan"]="sudo dpkg -i $(curl -s https://api.github.com/repos/RustScan/RustScan/releases/latest | grep 'browser_download_url.*amd64.deb' | cut -d '"' -f 4)"
  ["wafw00f"]="python3 -m pip install --user --break-system-packages wafw00f"
  ["ffuf"]="go install github.com/ffuf/ffuf@latest"
  ["wpscan"]="sudo gem install wpscan"
  ["testssl.sh"]="git clone https://github.com/drwetter/testssl.sh.git ~/tools/testssl.sh"
  ["gospider"]="go install github.com/jaeles-project/gospider@latest"
  ["commix"]="git clone https://github.com/commixproject/commix.git ~/tools/commix"
  ["jq"]="sudo apt install -y jq"
)

# Araç kurulum fonksiyonu
install_tool() {
  local tool=$1
  local cmd=$2
  
  if ! command -v "$tool" >/dev/null; then
    echo -e "${CYAN}[+] $tool kuruluyor...${RESET}"
    if run_command "$cmd"; then
      echo -e "${GREEN}[✓] $tool başarıyla kuruldu${RESET}"
    else
      echo -e "${RED}[!] $tool kurulumu başarısız oldu${RESET}"
    fi
  else
    echo -e "${GREEN}[✓] $tool zaten kurulu${RESET}"
  fi
}

# Ana araçları kur
echo -e "\n${CYAN}### TEMEL ARAÇLAR KURULUYOR ###${RESET}"
for tool in "${!tools[@]}"; do
  install_tool "$tool" "${tools[$tool]}"
done

# Python bağımlılıkları (Kali Linux Fix)
echo -e "\n${CYAN}### PYTHON BAĞIMLILIKLARI KURULUYOR ###${RESET}"
run_command "python3 -m pip install --upgrade pip"
run_command "python3 -m pip install --user --break-system-packages jsbeautifier argparse requests"

# Node.js ve npm kurulumu
if ! command -v npm >/dev/null; then
  echo -e "${CYAN}[+] Node.js ve npm kuruluyor...${RESET}"
  run_command "sudo apt install -y nodejs npm"
fi

# Retire.js kurulumu
if ! command -v retire >/dev/null; then
  echo -e "${CYAN}[+] Retire.js kuruluyor...${RESET}"
  run_command "sudo npm install -g retire"
fi

# LinkFinder kurulum fix
if [ ! -d ~/tools/linkfinder ]; then
  run_command "git clone https://github.com/GerbenJavado/LinkFinder.git ~/tools/linkfinder"
  run_command "python3 -m pip install --user --break-system-packages -r ~/tools/linkfinder/requirements.txt"
fi

# Ek GitHub araçları
echo -e "\n${CYAN}### EK GÜVENLİK ARAÇLARI KURULUYOR ###${RESET}"
declare -A github_tools=(
  ["SecretFinder"]="https://github.com/m4ll0k/SecretFinder.git"
  ["GitDorker"]="https://github.com/obheda12/GitDorker.git"
  ["403bypasser"]="https://github.com/yunemse48/403bypasser.git"
)

mkdir -p ~/tools
for tool in "${!github_tools[@]}"; do
  if [ ! -d ~/tools/"$tool" ]; then
    run_command "git clone ${github_tools[$tool]} ~/tools/$tool"
    if [ -f ~/tools/"$tool"/requirements.txt ]; then
      run_command "python3 -m pip install --user --break-system-packages -r ~/tools/$tool/requirements.txt"
    fi
  else
    echo -e "${GREEN}[✓] $tool zaten kurulu${RESET}"
  fi
done

# Son kontroller
echo -e "\n${CYAN}### SON KONTROLLER ###${RESET}"
run_command "go install -v"
run_command "sudo updatedb"

# PATH güncellemesi
echo -e "\n${CYAN}[+] PATH güncelleniyor...${RESET}"
export PATH=$PATH:$HOME/.local/bin
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc

echo -e "\n${GREEN}[✓] Kurulum tamamlandı!${RESET}"
echo -e "${YELLOW}[!] Yeni terminal oturumu başlatmayı unutmayın!${RESET}"
echo -e "${CYAN}[*] Komutları çalıştırmak için: source ~/.bashrc${RESET}"
exit 0