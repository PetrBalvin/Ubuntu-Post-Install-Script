#!/bin/bash
#==============================================================================
# Název:      Ubuntu Post-Install Script
# Verze:      1.0-beta
# Autor:      Petr Bálvin <petrbalvin@yandex.com>
# Licence:    MIT License (více informací v souboru LICENSE)
#==============================================================================
# Popis:      Profesionální konfigurační skript pro Ubuntu s následujícími funkcemi:
#             - Povolení standardních a třetích repozitářů (LibreOffice, OBS, Mesa)
#             - Kompletní aktualizace systému a čištění balíčků
#             - Integrace Ubuntu Pro (ESM, Livepatch) pro LTS verze
#             - Optimalizace pro AMD hardware (GPU+CPU):
#                • Instalace ovladačů (amdgpu, Vulkan)
#                • Konfigurace thermald a jádra (amd_pstate, C-states)
#                • Podpora VA-API a video kodeků
#             - Instalace multimediálních kodeků a produktivity nástrojů
#             - Konfigurace GNOME (rozšíření, oblíbené aplikace, MIME typy)
#             - Nastavení přihlašovací obrazovky (HiDPI škálování)
#             - Automatická konfigurace přístupu k médiím pro Snap balíčky
#==============================================================================
# Kompatibilita:
#   - Ubuntu 22.04+ (testováno na 22.04/23.10/24.04/24.10)
#   - Hardware s AMD procesorem a grafickou kartou (Ryzen/APU/ Radeon RX/Vega)
#   - Vyžaduje aktivní internetové připojení a práva sudo
#==============================================================================
# Poznámky:
#   - Pro plnou funkcionalitu spusťte na čisté instalaci Ubuntu
#   - Skript vytváří logy v adresáři postinstall-script-logs/
#   - Konfigurace GPU vyžaduje podporu amdgpu v jádře (min. 5.15+)
#==============================================================================

# =====================
# Konfigurace logování
# =====================
LOG_DIR="postinstall-script-logs"
LOG_FILE="$LOG_DIR/postscript-$(date +%F_%H-%M-%S).log"
mkdir -p "$LOG_DIR" || { echo "Nelze vytvořit adresář pro logy"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
    echo "[OK] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

exec > >(tee -a "$LOG_FILE") 2>&1

# =====================
# Kontrola předpokladů
# =====================
log_info "Kontrola oprávnění"
if [ "$EUID" -eq 0 ]; then
  log_error "Nespouštějte skript jako root"
  exit 1
fi
log_success "Oprávnění OK"

log_info "Kontrola licence"
if [ ! -f LICENSE ]; then
    log_error "Soubor LICENSE chybí!"
    exit 1
fi
log_success "Licence nalezena"

# =====================
# Úvodní informace
# =====================
echo -e "${YELLOW}### Licence (MIT) ###${NC}"
cat LICENSE
echo -e "${YELLOW}####################${NC}"

echo -e "${YELLOW}### Ubuntu Post-Install Script v1.0-beta ###${NC}"
echo "Tento skript provede:"
echo "1. Povolení standardních repozitářů"
echo "2. Přidání repozitářů třetích stran"
echo "3. Kompletní aktualizaci systému"
echo "4. Konfiguraci Ubuntu Pro (pokud je systém LTS)"
echo "5. Instalaci APT aplikací a kodeků"
echo "6. Optimalizaci pro AMD GPU"
echo "7. Instalaci Snap balíčků"
echo "8. Čištění systému"
echo "9. Kopírování systémových souborů"
echo "10. Konfiguraci GNOME"

read -p "Chcete pokračovat? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Instalace přerušena uživatelem"
    exit 1
fi
log_success "Uživatel potvrdil pokračování"

# =====================
# Kontrola LTS verze
# =====================
log_info "Kontrola LTS verze"
IS_LTS=false
CONFIGURE_UBUNTU_PRO=false

if grep -q "LTS" /etc/os-release; then
    IS_LTS=true
    log_info "Systém je LTS"
    
    read -p "Chcete nakonfigurovat Ubuntu Pro? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CONFIGURE_UBUNTU_PRO=true
        log_success "Konfigurace Ubuntu Pro povolena"
    else
        log_info "Konfigurace Ubuntu Pro přeskočena uživatelem"
    fi
else
    log_info "Systém není LTS - konfigurace Ubuntu Pro nebude provedena"
fi

# =====================
# Správa repozitářů
# =====================
log_info "Povolení standardních repozitářů"
for repo in universe multiverse restricted; do
    log_info "Povoluji $repo"
    if sudo add-apt-repository "$repo" -y; then
        log_success "$repo úspěšně povolen"
    else
        log_error "Chyba při povolení $repo"
    fi
done

log_info "Přidání repozitářů třetích stran"
add_repo_if_not_exists() {
    local repo_name="$1"
    if ! grep -q "^deb .*$repo_name" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        log_info "Přidávání repozitáře: $repo_name"
        if sudo add-apt-repository -y "$repo_name"; then
            log_success "Repozitář $repo_name přidán"
        else
            log_error "Chyba při přidání repozitáře $repo_name"
        fi
    else
        log_info "Repozitář $repo_name již existuje"
    fi
}

THIRD_PARTY_REPOS=(
    "ppa:libreoffice/ppa"
    "ppa:mozillacorp/mozillavpn"
    "ppa:obsproject/obs-studio"
    "ppa:kisak/kisak-mesa"
)

for repo in "${THIRD_PARTY_REPOS[@]}"; do
    add_repo_if_not_exists "$repo"
done

log_info "Přidání repozitáře MKVToolNix"
MKV_REPO_FILE="/etc/apt/sources.list.d/mkvtoolnix.list"
if [ ! -f "$MKV_REPO_FILE" ]; then
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/mkvtoolnix.gpg] https://mkvtoolnix.download/ubuntu/ $(lsb_release -cs) main" | sudo tee "$MKV_REPO_FILE" > /dev/null
    log_success "Repozitář MKVToolNix přidán"
else
    log_info "Repozitář MKVToolNix již existuje"
fi

log_info "Import GPG klíče pro MKVToolNix"
sudo mkdir -p /etc/apt/trusted.gpg.d
if [ ! -f /etc/apt/trusted.gpg.d/mkvtoolnix.gpg ]; then
    if wget -q -O - https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/mkvtoolnix.gpg > /dev/null; then
        log_success "GPG klíč pro MKVToolNix importován"
    else
        log_error "Chyba při importu GPG klíče"
    fi
else
    log_info "GPG klíč pro MKVToolNix již existuje"
fi

# =====================
# Aktualizace systému
# =====================
log_info "Spouštím aktualizaci systému"
if sudo apt update; then
    log_success "Aktualizace seznamu balíčků úspěšná"
    if sudo apt upgrade -y --allow-downgrades; then
        log_success "Systém úspěšně aktualizován"
    else
        log_error "Chyba při aktualizaci systému"
    fi
else
    log_error "Chyba při aktualizaci seznamu balíčků"
fi

# =====================
# Konfigurace Ubuntu Pro
# =====================
if $IS_LTS && $CONFIGURE_UBUNTU_PRO; then
    log_info "Konfigurace Ubuntu Pro"
    if sudo apt install -y ubuntu-advantage-tools; then
        log_success "Nástroje Ubuntu Pro nainstalovány"
        
        read -p "Zadejte váš token pro Ubuntu Pro: " UBUNTU_PRO_TOKEN
        if [ -n "$UBUNTU_PRO_TOKEN" ]; then
            if sudo pro attach "$UBUNTU_PRO_TOKEN"; then
                log_success "Připojení k Ubuntu Pro úspěšné"
                for service in esm-apps esm-infra livepatch; do
                    if sudo pro enable "$service" --assume-yes; then
                        log_success "Služba $service povolena"
                    else
                        log_error "Chyba při povolení služby $service"
                    fi
                done
            else
                log_error "Chyba při připojování k Ubuntu Pro"
            fi
        else
            log_info "Token nezadán - konfigurace přeskočena"
        fi
    else
        log_error "Chyba při instalaci nástrojů Ubuntu Pro"
    fi
else
    log_info "Konfigurace Ubuntu Pro přeskočena"
fi

# =====================
# Optimalizace AMD GPU
# =====================
log_info "Instalace AMD balíčků"
AMD_PACKAGES=(
    "libdrm-amdgpu1"
    "mesa-utils"
    "mesa-vdpau-drivers"
    "mesa-va-drivers"
    "mesa-vulkan-drivers"
    "ocl-icd-opencl-dev"
    "vainfo"
    "vdpauinfo"
    "radeontop"
    "clinfo"
    "vulkan-tools"
    "xserver-xorg-video-amdgpu"
    "thermald"
    "libgl1-mesa-dev"
    "libvulkan-dev"
)

AMD_PACKAGES=($(printf "%s\n" "${AMD_PACKAGES[@]}" | sort))
if sudo apt install -y "${AMD_PACKAGES[@]}"; then
    log_success "AMD balíčky nainstalovány"
else
    log_error "Chyba při instalaci AMD balíčků"
fi

log_info "Konfigurace služby thermald"
if sudo systemctl enable thermald --now; then
    log_success "thermald úspěšně aktivováno"
else
    log_error "Chyba při konfiguraci thermald"
fi

log_info "Optimalizace parametrů jádra"
sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="amd_pstate=active amdgpu.dc=1 amdgpu.audio=1 processor.max_cstate=5 idle=nomwait pcie_aspm=force"/' /etc/default/grub
if sudo update-grub; then
    log_success "Konfigurace GRUB aktualizována"
else
    log_error "Chyba při aktualizaci GRUB"
fi

log_info "Kontrola AMDGPU ovladače"
if lsmod | grep -q "amdgpu"; then
    log_success "AMDGPU ovladač aktivní"
else
    log_error "AMDGPU ovladač není aktivní"
fi

log_info "Kontrola VA-API"
if vainfo > /dev/null 2>&1; then
    log_success "VA-API funkční"
else
    log_error "VA-API není funkční"
fi

log_info "Kontrola Vulkan API"
if vulkaninfo --summary > /dev/null 2>&1; then
    log_success "Vulkan API funkční"
else
    log_error "Vulkan API není funkční"
fi

# =====================
# Instalace balíčků
# =====================
log_info "Instalace nástrojů pro souborové systémy"
FILESYSTEM_PACKAGES=(
    "btrfs-progs"
    "e2fsprogs"
    "exfat-fuse"
    "exfatprogs"
    "f2fs-tools"
    "zfsutils-linux"
)

if sudo apt install -y "${FILESYSTEM_PACKAGES[@]}"; then
    log_success "Souborové systémy nainstalovány"
else
    log_error "Chyba při instalaci souborových systémů"
fi

log_info "Instalace APT aplikací"
APT_PACKAGES=(
    "audacity"
    "fastfetch"
    "gnome-shell-extension-manager"
    "handbrake"
    "libreoffice"
    "libreoffice-l10n-cs"
    "mediainfo"
    "mkvtoolnix"
    "mkvtoolnix-gui"
    "mozillavpn"
    "obs-studio"
)

if sudo apt install -y "${APT_PACKAGES[@]}"; then
    log_success "APT aplikace nainstalovány"
else
    log_error "Chyba při instalaci APT aplikací"
fi

log_info "Instalace kodeků"
CODEC_PACKAGES=(
    "ffmpeg"
    "ffmpegthumbnailer"
    "gstreamer1.0-plugins-base"
    "gstreamer1.0-plugins-good"
    "gstreamer1.0-plugins-bad"
    "gstreamer1.0-plugins-ugly"
    "libaom-dev"
    "libavif-dev"
    "libflac-dev"
    "libopus-dev"
    "libvorbis-dev"
    "libvpx-dev"
    "libwebp-dev"
)

if sudo apt install -y "${CODEC_PACKAGES[@]}"; then
    log_success "Kodeky nainstalovány"
else
    log_error "Chyba při instalaci kodeků"
fi

log_info "Instalace Snap balíčků"
SNAP_PACKAGES=(
    "celluloid"
    "discord"
    "firefox"
    "gimp"
    "loupe"
    "musicpod"
    "remmina"
    "spotify"
    "steam"
    "tagger"
    "telegram-desktop"
    "thunderbird"
    "transmission"
)

for package in "${SNAP_PACKAGES[@]}"; do
    log_info "Instalace Snap: $package"
    if sudo snap install "$package"; then
        log_success "Snap $package nainstalován"
    else
        log_error "Chyba při instalaci Snap $package"
    fi
done

log_info "Konfigurace přístupu k externím médiím"
for package in "${SNAP_PACKAGES[@]}"; do
    # Zkontrolujeme, zda Snap má podporu pro removable-media
    if snap connections "$package" | grep -q "removable-media"; then
        log_info "Konfigurace přístupu pro: $package"
        if sudo snap connect "$package:removable-media"; then
            log_success "Přístup pro $package povolen"
        else
            log_error "Chyba při konfiguraci přístupu pro $package"
        fi
    else
        log_info "Snap $package nepodporuje removable-media - přeskočeno"
    fi
done

# =====================
# Čištění systému
# =====================
log_info "Čištění systému"
if sudo apt autoremove -y && sudo apt autoclean -y && sudo snap refresh; then
    log_success "Systém úspěšně vyčištěn"
else
    log_error "Chyba při čištění systému"
fi

# =====================
# Kopírování systémových souborů
# =====================
log_info "Kopírování systémových souborů"
ASSETS_DIR="assets"
REQUIRED_DIRS=("backgrounds" "gnome-background-properties")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$ASSETS_DIR/$dir" ]; then
        log_error "Chybí adresář: $ASSETS_DIR/$dir"
        exit 1
    fi
done

for dir in "${REQUIRED_DIRS[@]}"; do
    log_info "Přepisuji /usr/share/$dir"
    if sudo rm -rf "/usr/share/$dir" && \
       sudo cp -r "$ASSETS_DIR/$dir" "/usr/share/" && \
       sudo chmod -R 755 "/usr/share/$dir" && \
       sudo chown -R root:root "/usr/share/$dir"; then
        log_success "Adresář $dir úspěšně přepsán"
    else
        log_error "Chyba při zpracování $dir"
    fi
done

# =====================
# Konfigurace GNOME
# =====================
log_info "Konfigurace GNOME nastavení"
GNOME_CONFIGS=(
    "set org.gnome.system.location enabled true"
    "set org.gnome.mutter center-new-windows true"
    "set org.gnome.TextEditor restore-session false"
    "set org.gnome.TextEditor spellcheck false"
    "set org.gnome.TextEditor show-line-numbers true"
    "set org.gnome.TextEditor highlight-current-line true"
    "set org.gnome.nautilus.compression default-compression-format '7z'"
    "set org.gnome.nautilus.preferences show-directory-item-counts 'always'"
    "set org.gnome.nautilus.preferences show-image-thumbnails 'always'"
    "set org.gnome.nautilus.preferences show-create-link true"
    "set org.gnome.nautilus.preferences show-delete-permanently true"
    "set org.gnome.desktop.calendar show-weekdate true"
    "set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/Oracular_Oriole.webp'"
    "set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/Oracular_Oriole.webp'"
    "set org.gnome.desktop.interface scaling-factor 1"
    "set org.gnome.desktop.interface text-scaling-factor 1"
    "set org.gnome.desktop.privacy old-files-age 2"
    "set org.gnome.desktop.privacy remove-old-temp-files true"
    "set org.gnome.desktop.privacy remove-old-trash-files true"
    "set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'"
    "set org.gnome.shell.extensions.dash-to-dock multi-monitor true"
    "set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'"
    "set org.gnome.shell.extensions.dash-to-dock extend-height false"
    "set org.gnome.shell.extensions.dash-to-dock intellihide true"
    "set org.gnome.shell.extensions.dash-to-dock dock-fixed false"
    "set org.gnome.shell.extensions.ding start-corner 'top-left'"
)

for config in "${GNOME_CONFIGS[@]}"; do
    log_info "Nastavuji: $config"
    if gsettings $config; then
        log_success "Nastavení $config úspěšné"
    else
        log_error "Chyba při nastavení $config"
    fi
done

log_info "Nastavení oblíbených aplikací"
FAVORITE_APPS="[
    'firefox_firefox.desktop',
    'thunderbird_thunderbird.desktop',
    'musicpod_musicpod.desktop',
    'org.gnome.Nautilus.desktop',
    'libreoffice-writer.desktop',
    'libreoffice-calc.desktop',
    'libreoffice-impress.desktop',
    'snap-store_snap-store.desktop',
    'telegram-desktop_telegram-desktop.desktop',
    'org.bunkus.mkvtoolnix-gui.desktop'
]"

if gsettings set org.gnome.shell favorite-apps "$FAVORITE_APPS"; then
    log_success "Oblíbené aplikace nastaveny"
else
    log_error "Chyba při nastavení oblíbených aplikací"
fi

log_info "Aktualizace MIME databáze"
if sudo update-mime-database /usr/share/mime && sudo update-desktop-database; then
    log_success "MIME databáze aktualizována"
else
    log_error "Chyba při aktualizaci MIME databáze"
fi

# =====================
# Konfigurace GDM
# =====================
log_info "Konfigurace škálování přihlašovací obrazovky"
if sudo mkdir -p /usr/share/glib-2.0/schemas/ && \
   echo -e "[org.gnome.settings-daemon.plugins.xsettings]\nscale=2" | \
   sudo tee /usr/share/glib-2.0/schemas/93_hidpi.gschema.override > /dev/null && \
   sudo glib-compile-schemas /usr/share/glib-2.0/schemas/; then
    log_success "Konfigurace GDM škálování úspěšná"
else
    log_error "Chyba při konfiguraci GDM škálování"
fi

# =====================
# Finální kontrola
# =====================
echo -e "\n${YELLOW}=== Dokončení instalace ===${NC}"

# Najdeme všechny chyby v logu
ERRORS=$(grep "\[ERROR\]" "$LOG_FILE")

if [ -n "$ERRORS" ]; then
    echo -e "${RED}Instalace dokončena s chybami!${NC}"
    echo "Chyby:"
    echo "--------------------------------------------------"
    echo "$ERRORS" | sed 's/\[ERROR\]/\x1b[31m&\x1b[0m/'  # Zvýrazní [ERROR] červeně
    echo "--------------------------------------------------"
    echo "Podrobnosti v logu: $(realpath "$LOG_FILE")"
    exit_status=1
else
    echo -e "${GREEN}Instalace úspěšně dokončena!${NC}"
    echo "Log uložen: $(realpath "$LOG_FILE")"
    exit_status=0
fi

read -p "Chcete opustit terminál? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exit $exit_status
fi
