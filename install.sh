#!/usr/bin/env bash
# =============================================================================
#  🚀 chuipagro — Fresh Machine Setup Script
#  Run: bash install.sh
#  Logs every step (success/failure) to report.html
# =============================================================================

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/report.html"
REPORT_CSS="$SCRIPT_DIR/report.css"
LOG_FILE="$SCRIPT_DIR/install.log"
STEP=0
PASS=0
FAIL=0
START_TIME=$(date +%s)

# ─── Colors ──────────────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

# ─── HTML report bootstrap ───────────────────────────────────────────────────
init_report() {
  cat > "$REPORT_FILE" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Install Report — chuipagro</title>
  <link rel="stylesheet" href="report.css" />
</head>
<body>
  <header>
    <div class="header-inner">
      <div class="logo">⚙️</div>
      <div>
        <h1>Fresh Machine Setup</h1>
        <p class="subtitle">chuipagro — <span id="hostname">HOSTNAME</span></p>
      </div>
      <div class="header-meta">
        <div class="badge" id="badge-pass">✅ <span id="count-pass">0</span> passed</div>
        <div class="badge" id="badge-fail">❌ <span id="count-fail">0</span> failed</div>
      </div>
    </div>
  </header>
  <main>
    <div class="timeline">
HTMLEOF

  # Replace HOSTNAME placeholder
  sed -i "s/HOSTNAME/$(hostname)/" "$REPORT_FILE"
}

# ─── Append a step result to the HTML report ─────────────────────────────────
report_step() {
  local status="$1"   # "pass" or "fail"
  local section="$2"
  local name="$3"
  local detail="$4"   # error message or empty
  local duration="$5"

  local icon class
  if [[ "$status" == "pass" ]]; then
    icon="✅"; class="pass"
  else
    icon="❌"; class="fail"
  fi

  cat >> "$REPORT_FILE" <<STEPEOF
      <div class="step $class">
        <div class="step-icon">$icon</div>
        <div class="step-body">
          <div class="step-header">
            <span class="step-section">$section</span>
            <span class="step-name">$name</span>
            <span class="step-duration">${duration}s</span>
          </div>
          $([ -n "$detail" ] && echo "<div class=\"step-error\"><code>$detail</code></div>" || echo "")
        </div>
      </div>
STEPEOF
}

report_section() {
  echo "      <div class=\"section-header\"><h2>$1</h2></div>" >> "$REPORT_FILE"
}

close_report() {
  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$(( end_time - START_TIME ))
  local mins=$(( elapsed / 60 ))
  local secs=$(( elapsed % 60 ))

  cat >> "$REPORT_FILE" <<CLOSEEOF
    </div>
  </main>
  <footer>
    <p>Completed in ${mins}m ${secs}s &nbsp;·&nbsp; $(date '+%Y-%m-%d %H:%M:%S') &nbsp;·&nbsp; $PASS passed &nbsp;·&nbsp; $FAIL failed</p>
  </footer>
  <script>
    document.getElementById('count-pass').textContent = '$PASS';
    document.getElementById('count-fail').textContent = '$FAIL';
  </script>
</body>
</html>
CLOSEEOF
}

# ─── Run a step safely (never aborts the script) ─────────────────────────────
run_step() {
  local section="$1"
  local name="$2"
  shift 2
  local cmd=("$@")

  STEP=$(( STEP + 1 ))
  local t_start t_end duration
  t_start=$(date +%s)

  printf "${C_CYAN}[%02d]${C_RESET} ${C_BOLD}%-50s${C_RESET}" "$STEP" "$name"

  local output exit_code
  output=$(bash -c "${cmd[*]}" 2>&1) && exit_code=0 || exit_code=$?

  t_end=$(date +%s)
  duration=$(( t_end - t_start ))

  # Log to file
  echo "[$( date '+%H:%M:%S')] [$exit_code] $name" >> "$LOG_FILE"
  [[ -n "$output" ]] && echo "$output" >> "$LOG_FILE"

  if [[ $exit_code -eq 0 ]]; then
    printf " ${C_GREEN}✅ done${C_RESET} (${duration}s)\n"
    PASS=$(( PASS + 1 ))
    report_step "pass" "$section" "$name" "" "$duration"
  else
    printf " ${C_RED}❌ FAILED (exit $exit_code)${C_RESET}\n"
    # Escape HTML special chars in output
    local safe_output
    safe_output=$(echo "$output" | tail -5 | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    FAIL=$(( FAIL + 1 ))
    report_step "fail" "$section" "$name" "exit $exit_code — $safe_output" "$duration"
  fi
}

# ─── Sudo check ──────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  echo "❌ Do NOT run as root. Run as your normal user (sudo will be called when needed)."
  exit 1
fi

echo -e "${C_BOLD}${C_CYAN}"
cat <<'BANNER'
  ____  _____ _____ _   _ ____
 / ___|| ____|_   _| | | |  _ \
 \___ \|  _|   | | | | | | |_) |
  ___) | |___  | | | |_| |  __/
 |____/|_____| |_|  \___/|_|
BANNER
echo -e "${C_RESET}"
echo -e "Starting setup for ${C_BOLD}$(whoami)@$(hostname)${C_RESET} on $(date)"
echo ""

# Keep sudo alive
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_LOOP_PID=$!
trap "kill $SUDO_LOOP_PID 2>/dev/null; close_report" EXIT

# Init report
echo "" > "$LOG_FILE"
init_report

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================
report_section "🔄 System Update"

run_step "System" "Update apt cache" \
  "sudo apt-get update -q"

run_step "System" "Full system upgrade" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q"

run_step "System" "Install core utilities" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    curl wget git jq fd-find build-essential cmake \
    ca-certificates gnupg apt-transport-https software-properties-common \
    rsync zip unzip lsb-release"

# =============================================================================
# 2. SHELL — ZSH + OH-MY-ZSH
# =============================================================================
report_section "🐚 Shell — ZSH & Oh-My-Zsh"

run_step "Shell" "Install ZSH" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q zsh"

run_step "Shell" "Set ZSH as default shell" \
  "sudo chsh -s \$(which zsh) \$(whoami)"

run_step "Shell" "Install Oh-My-Zsh" \
  'if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "Oh-My-Zsh already installed, skipping"
  fi'

run_step "Shell" "Restore .zshrc" \
  "cp '$SCRIPT_DIR/configs/dotfiles/.zshrc' \"\$HOME/.zshrc\""

run_step "Shell" "Restore .zprofile" \
  "[ -f '$SCRIPT_DIR/configs/dotfiles/.zprofile' ] && cp '$SCRIPT_DIR/configs/dotfiles/.zprofile' \"\$HOME/.zprofile\" || true"

# =============================================================================
# 3. GIT CONFIG
# =============================================================================
report_section "🔧 Git Configuration"

run_step "Git" "Set user name" \
  "git config --global user.name 'chuipagro'"

run_step "Git" "Set user email" \
  "git config --global user.email 'pablo.levy@epitech.eu'"

run_step "Git" "Set default branch to main" \
  "git config --global init.defaultBranch main"

run_step "Git" "Enable color UI" \
  "git config --global color.ui auto"

run_step "Git" "Color for git status" \
  "git config --global color.status auto"

run_step "Git" "Color for git branch" \
  "git config --global color.branch auto"

run_step "Git" "Color for git diff" \
  "git config --global color.diff auto"

run_step "Git" "Set color status entries" \
  "git config --global color.status.added 'green bold' && \
   git config --global color.status.changed 'yellow bold' && \
   git config --global color.status.untracked 'red bold'"

run_step "Git" "Set color branch entries" \
  "git config --global color.branch.current 'cyan bold' && \
   git config --global color.branch.remote 'magenta'"

run_step "Git" "Set pretty log alias" \
  "git config --global alias.lg \"log --oneline --graph --decorate --color --all\""

run_step "Git" "Generate SSH key (ed25519)" \
  'if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "pablo.levy@epitech.eu" -f "$HOME/.ssh/id_ed25519" -N ""
    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519"
    echo ""
    echo "📋 Your NEW public SSH key (add to GitHub/GitLab):"
    echo "---------------------------------------------------"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo "---------------------------------------------------"
  else
    echo "SSH key already exists, skipping"
  fi'

# =============================================================================
# 4. BROWSER — BRAVE
# =============================================================================
report_section "🌐 Browser — Brave"

run_step "Browser" "Add Brave GPG key" \
  'sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg'

run_step "Browser" "Add Brave repository" \
  'echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
    https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null && sudo apt-get update -q'

run_step "Browser" "Install Brave browser" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q brave-browser"

# =============================================================================
# 5. MEDIA — SPOTIFY, DISCORD, VLC, GIMP, STEAM
# =============================================================================
report_section "🎵 Media & Entertainment"

run_step "Media" "Add Spotify GPG key & repo" \
  'curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
'

run_step "Media" "Install Spotify" \
  "sudo apt-get update && sudo apt-get install spotify-client"
  
run_step "Media" "Install Discord" \
  'TMP_DEB="$(mktemp /tmp/discord.XXXXXX.deb)" && \
   curl -fsSL "https://discordapp.com/api/download?platform=linux&format=deb" -o "$TMP_DEB" && \
   sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$TMP_DEB" && \
   rm -f "$TMP_DEB"'

run_step "Media" "Install VLC" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q vlc"

run_step "Media" "Install GIMP" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q gimp"

# Steam needs 32-bit libs; pre-accept the license so the install doesn't block.
run_step "Media" "Install Steam" \
  'sudo dpkg --add-architecture i386 && sudo apt-get update -q && \
   echo "steam steam/question select I AGREE" | sudo debconf-set-selections && \
   echo "steam steam/license note \"\"" | sudo debconf-set-selections && \
   sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q steam-installer'

# =============================================================================
# 6. SECURITY — MULLVAD VPN
# =============================================================================
report_section "🔒 Security — Mullvad VPN"

run_step "Security" "Add Mullvad GPG key" \
  'sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
    https://repository.mullvad.net/deb/mullvad-keyring.asc'

run_step "Security" "Add Mullvad repository" \
  'echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=amd64] \
    https://repository.mullvad.net/deb/stable stable main" \
    | sudo tee /etc/apt/sources.list.d/mullvad.list > /dev/null && sudo apt-get update -q'

run_step "Security" "Install Mullvad VPN" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q mullvad-vpn"

# =============================================================================
# 7. DOCKER
# =============================================================================
report_section "🐳 Docker"

run_step "Docker" "Add Docker GPG key" \
  'sudo install -m 0755 -d /etc/apt/keyrings && \
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc && \
   sudo chmod a+r /etc/apt/keyrings/docker.asc'

run_step "Docker" "Add Docker repository" \
  'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt-get update -q'

run_step "Docker" "Install Docker CE + plugins" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin"

run_step "Docker" "Add user to docker group" \
  "sudo usermod -aG docker \$(whoami)"

run_step "Docker" "Enable Docker service" \
  "sudo systemctl enable --now docker"

# =============================================================================
# 8. VIRTUALBOX
# =============================================================================
report_section "📦 VirtualBox"

run_step "VirtualBox" "Add Oracle GPG key" \
  'wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg'

run_step "VirtualBox" "Add VirtualBox repository" \
  'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] \
    http://download.virtualbox.org/virtualbox/debian \
    $(lsb_release -cs) contrib" \
    | sudo tee /etc/apt/sources.list.d/virtualbox.list > /dev/null && sudo apt-get update -q'

run_step "VirtualBox" "Install VirtualBox 7.x" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q virtualbox-7.2"

run_step "VirtualBox" "Add user to vboxusers group" \
  "sudo usermod -aG vboxusers \$(whoami)"

# =============================================================================
# 9. LANGUAGES — NODE (NVM) + PYTHON + HASKELL + SDL2/SFML/CSFML
# =============================================================================
report_section "🔤 Languages & Runtimes"

# NVM + Node
run_step "Node" "Install NVM" \
  'if [ ! -d "$HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  else
    echo "NVM already installed"
  fi'

run_step "Node" "Install Node.js v24 (LTS)" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install 24 && nvm alias default 24'

# NPM global packages
run_step "npm" "Install @nestjs/cli globally" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm install -g @nestjs/cli'

run_step "npm" "Install @expo/ngrok globally" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm install -g @expo/ngrok'

run_step "npm" "Install expo-cli globally" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm install -g expo-cli'

run_step "npm" "Install yarn globally" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm install -g yarn'

run_step "npm" "Install corepack globally" \
  'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm install -g corepack'

# Python
run_step "Python" "Install Python 3 + pip + venv" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    python3 python3-pip python3-venv python3-dev"

# Haskell
run_step "Haskell" "Install GHC + Cabal" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q ghc cabal-install"

# Graphics libs — all from apt so versions match (SFML 2.6 ↔ CSFML 2.6)
run_step "Graphics" "Install SDL2 + extensions" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q pkg-config \
    libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-mixer-dev \
    libsdl2-gfx-dev libsdl2-net-dev"

run_step "Graphics" "Install SFML" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libsfml-dev"

run_step "Graphics" "Install CSFML" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libcsfml-dev"

# Compile + link a tiny program against each lib to prove the setup works.
run_step "Graphics" "Check SDL2 / SFML / CSFML build" \
  'T="$(mktemp -d)" && trap "rm -rf \"$T\"" EXIT
   printf "#include <SDL2/SDL.h>\nint main(void){SDL_version v;SDL_GetVersion(&v);return 0;}\n" > "$T/sdl.c"
   printf "#include <SFML/Graphics.hpp>\nint main(){sf::Texture t;return 0;}\n" > "$T/sfml.cpp"
   printf "#include <SFML/Graphics.h>\nint main(void){sfTexture_destroy(NULL);return 0;}\n" > "$T/csfml.c"
   gcc "$T/sdl.c" -o "$T/sdl" $(pkg-config --cflags --libs sdl2 SDL2_image SDL2_ttf SDL2_mixer) &&
   g++ "$T/sfml.cpp" -o "$T/sfml" -lsfml-graphics -lsfml-window -lsfml-system &&
   gcc "$T/csfml.c" -o "$T/csfml" -lcsfml-graphics -lcsfml-window -lcsfml-system &&
   echo "✅ SDL2 $(pkg-config --modversion sdl2), SFML $(pkg-config --modversion sfml-all), CSFML $(pkg-config --modversion csfml-all) OK"'


# =============================================================================
# 10. FLATPAK APPS
# =============================================================================
report_section "📦 Flatpak Apps"

run_step "Flatpak" "Install Flatpak" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q flatpak"

run_step "Flatpak" "Add Flathub remote" \
  "flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo"

run_step "Flatpak" "Install Arduino IDE 2, Postman, pgAdmin 4, Bottles" \
  "flatpak install -y --user --noninteractive flathub cc.arduino.IDE2 com.getpostman.Postman org.pgadmin.pgadmin4 com.usebottles.bottles"

# =============================================================================
# 11. VS CODE
# =============================================================================
report_section "💻 VS Code"

run_step "VSCode" "Add Microsoft GPG key" \
  'wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null'

# Same file + keyring the `code` package manages itself — a second entry with a
# different Signed-By makes apt refuse to read any source.
run_step "VSCode" "Add VS Code repository" \
  'sudo rm -f /etc/apt/sources.list.d/vscode.list
   printf "Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/microsoft.gpg\n" \
    | sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null && sudo apt-get update -q'

run_step "VSCode" "Install VS Code" \
  "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q code"

# =============================================================================
# 12. JETBRAINS IDEs
# =============================================================================
report_section "🧰 JetBrains IDEs"

# ── Helper: download + install one JetBrains IDE from official API ────────────
# Usage: _jb_install <API_CODE> <APP_NAME> <BIN_NAME>
#   API_CODE : product code used by JetBrains API (CL, WS, …)
#   APP_NAME : display name used for the .desktop entry (CLion, WebStorm, …)
#   BIN_NAME : binary name inside the extracted tarball (clion, webstorm, …)
_jb_install() {
  local code="$1" app="$2" bin="$3"
  local api="https://data.services.jetbrains.com/products/releases?code=${code}&latest=true&type=release"

  local url version
  url=$(curl -fsSL "$api" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['${code}'][0]['downloads']['linux']['link'])")
  version=$(curl -fsSL "$api" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['${code}'][0]['version'])")

  local tmp="/tmp/${bin}-latest.tar.gz"
  local dest="$HOME/.local/share/JetBrains/${app}"

  curl -fsSL "$url" -o "$tmp"
  mkdir -p "$dest"
  tar -xzf "$tmp" -C "$dest" --strip-components=1

  # Symlink binary to ~/.local/bin
  mkdir -p "$HOME/.local/bin"
  ln -sf "$dest/bin/${bin}" "$HOME/.local/bin/${bin}"

  # .desktop entry
  mkdir -p "$HOME/.local/share/applications"
  cat > "$HOME/.local/share/applications/${bin}.desktop" <<DESK
[Desktop Entry]
Version=1.0
Type=Application
Name=${app}
Exec=$dest/bin/${bin} %u
Icon=$dest/bin/${bin}.svg
Terminal=false
StartupWMClass=jetbrains-${bin}
Categories=Development;IDE;
DESK

  # Restore config — target the versioned dir JetBrains expects
  local cfg_dir="$HOME/.config/JetBrains/${app}${version%.*}"
  mkdir -p "$cfg_dir"
  rsync -a --exclude='.lock' \
    "$SCRIPT_DIR/configs/jetbrains/${bin}/" \
    "$cfg_dir/"

  echo "✅ ${app} ${version} installed → ${dest}"
  echo "   Config restored → ${cfg_dir}"
}

# Export so run_step's bash -c subshell can see the function and SCRIPT_DIR
export -f _jb_install
export SCRIPT_DIR

run_step "CLion" "Download, install & configure CLion" \
  '_jb_install CL CLion clion'

run_step "WebStorm" "Download, install & configure WebStorm" \
  '_jb_install WS WebStorm webstorm'

# ── JetBrains Toolbox (optional tray manager — non-blocking) ─────────────────
run_step "JetBrains" "Install JetBrains Toolbox (background)" \
  'TOOLBOX_URL=$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[\"TBA\"][0][\"downloads\"][\"linux\"][\"link\"])")
   curl -fsSL "$TOOLBOX_URL" -o /tmp/jetbrains-toolbox.tar.gz
   tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /tmp/
   TOOLBOX_BIN=$(find /tmp -name "jetbrains-toolbox" -type f | head -1)
   chmod +x "$TOOLBOX_BIN"
   mkdir -p "$HOME/.local/share/JetBrains/Toolbox/bin"
   cp "$TOOLBOX_BIN" "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
   ln -sf "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"
   nohup "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" >/dev/null 2>&1 &
   disown
   echo "✅ Toolbox installed and launched in background (check system tray)"'

# =============================================================================
# 13. GITHUB CLI
# =============================================================================
report_section "🐙 GitHub CLI"

run_step "GitHub CLI" "Add GitHub CLI GPG key & repo" \
  'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'

run_step "GitHub CLI" "Install gh" \
  "sudo apt-get update -q && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q gh"

run_step "GitHub CLI" "Authenticate with GitHub (browser)" \
  "gh auth login --git-protocol ssh --web"

run_step "GitHub CLI" "Clone github-repo-searcher" \
  'if [ -d "$HOME/github-repo-searcher" ]; then
     echo "ℹ️  $HOME/github-repo-searcher already exists — skipping clone."
   else
     gh repo clone chuipagro/github-repo-searcher "$HOME/github-repo-searcher"
   fi'

# ─── Pull Anthropic API key from a private GitHub Gist ───────────────────────
# Store your key in a private gist with a single file named ANTHROPIC_API_KEY
# Then set ANTHROPIC_GIST_ID=<your-gist-id> before running this script,
# or it will prompt you interactively.
# =============================================================================
# 14. AI TOOLS — ANTIGRAVITY + CLAUDE CODE
# =============================================================================
report_section "🤖 AI Tools"

run_step "AI Tools" "Fetch Anthropic API key from GitHub Gist" \
  'if [[ -z "${ANTHROPIC_GIST_ID:-}" ]]; then
     echo "ℹ️  No ANTHROPIC_GIST_ID set — skipping automatic key fetch."
     echo "   Set it with: export ANTHROPIC_GIST_ID=<your-gist-id>"
     exit 0
   fi
   KEY=$(gh gist view "$ANTHROPIC_GIST_ID" --raw 2>/dev/null | grep -v "^#" | tr -d "[:space:]")
   if [[ -z "$KEY" ]]; then
     echo "❌ Could not read key from gist $ANTHROPIC_GIST_ID" >&2; exit 1
   fi
   # Persist to shell configs
   for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
     grep -q "ANTHROPIC_API_KEY" "$RC" 2>/dev/null && \
       sed -i "s|^export ANTHROPIC_API_KEY=.*|export ANTHROPIC_API_KEY=\"$KEY\"|" "$RC" || \
       echo "export ANTHROPIC_API_KEY=\"$KEY\"" >> "$RC"
   done
   export ANTHROPIC_API_KEY="$KEY"
   echo "✅ ANTHROPIC_API_KEY written to ~/.bashrc and ~/.zshrc"'

run_step "Antigravity" "Add Antigravity APT repo" \
  'sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
     | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
   echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
     | sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null'

run_step "Antigravity" "Install Antigravity" \
  "sudo apt-get update -q && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q antigravity"

run_step "Claude Code" "Install Claude Code CLI" \
  "bash \"$SCRIPT_DIR/claude-install.sh\""

# =============================================================================
# DONE
# =============================================================================
close_report

echo ""
echo -e "${C_BOLD}${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_BOLD}  Setup complete!${C_RESET}"
echo -e "${C_GREEN}  ✅ $PASS steps passed${C_RESET}"
if [[ $FAIL -gt 0 ]]; then
  echo -e "${C_RED}  ❌ $FAIL steps failed${C_RESET}"
fi
echo -e "  📄 Report: file://$REPORT_FILE"
echo -e "  📋 Log:    $LOG_FILE"
echo -e "${C_BOLD}${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""
echo -e "${C_YELLOW}⚠️  Reminder:${C_RESET} Add your SSH public key to GitHub/GitLab!"
[[ -f "$HOME/.ssh/id_ed25519.pub" ]] && echo "" && cat "$HOME/.ssh/id_ed25519.pub"
echo ""
echo -e "${C_YELLOW}⚠️  Note:${C_RESET} Log out and back in for docker/vboxusers group changes to take effect."
