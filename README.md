# 🚀 dump-script — Fresh Machine Setup

A self-contained script to set up a fresh **Pop!_OS / Ubuntu** machine exactly the way I like it.

## 📁 Structure

```
dump-script/
├── install.sh              ← Main setup script (run this)
├── report.css              ← Stylesheet for the HTML report
├── report.html             ← Generated after running install.sh
├── install.log             ← Plain text log
└── configs/
    ├── dotfiles/
    │   ├── .zshrc
    │   ├── .zprofile
    │   └── .gitconfig
    └── jetbrains/
        ├── clion/          ← CLion 2025.3 settings
        └── webstorm/       ← WebStorm 2025.3 settings
```

## 🖥️ What gets installed

| Category | Apps |
|---|---|
| **Browser** | Brave |
| **Media** | Spotify, Discord, VLC, GIMP |
| **Security** | Mullvad VPN |
| **Dev tools** | Docker CE (+ compose, buildx), VirtualBox 7.2, Git, cmake, build-essential, jq, fd-find |
| **Node** | NVM → Node v24 LTS + yarn, @nestjs/cli, expo-cli, @expo/ngrok, corepack |
| **Python** | Python 3, pip, venv |
| **Haskell** | GHC, Cabal |
| **SFML** | libsfml-dev (full) |
| **Flatpak** | Arduino IDE 2, Postman, pgAdmin 4 |
| **IDE** | VS Code, JetBrains Toolbox |
| **Shell** | ZSH + Oh-My-Zsh + dotfiles restored |
| **Git** | user config + colors + ssh key generated |

## 🚀 Usage

```bash
# Clone this repo on your fresh machine
git clone <your-repo-url> ~/dump-script
cd ~/dump-script

# Run the setup
bash install.sh
```

After it finishes, open `report.html` in your browser to see the full log.

## 📋 Post-install checklist

- [ ] Add the new SSH public key to **GitHub** and/or **GitLab**
- [ ] Log out and back in (docker/vboxusers group changes)
- [ ] Open **JetBrains Toolbox** from system tray and install CLion / WebStorm
- [ ] Log into Brave, Spotify, Discord, Mullvad

## 🔄 Updating configs

Run this from your current machine to refresh the backed-up configs:

```bash
cd ~/dump-script

# Refresh dotfiles
cp ~/.zshrc configs/dotfiles/.zshrc
cp ~/.zprofile configs/dotfiles/.zprofile
cp ~/.gitconfig configs/dotfiles/.gitconfig

# Refresh JetBrains configs
rsync -a --exclude="workspace/" --exclude="*.db" \
  ~/.config/JetBrains/CLion2025.3/ configs/jetbrains/clion/

rsync -a --exclude="workspace/" --exclude="*.db" \
  ~/.config/JetBrains/WebStorm2025.3/ configs/jetbrains/webstorm/

git add -A && git commit -m "chore: refresh configs $(date +%Y-%m-%d)"
```
