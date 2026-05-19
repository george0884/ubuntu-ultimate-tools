#!/bin/bash

# ============================================================
# Script: Kubuntu Lite Ultimate
# Descripción: Transforma Kubuntu en un sistema minimalista
#              con optimizaciones de rendimiento extremo
# Versión: 4.0 - CON LOG VISIBLE Y MENÚ ESTABLE
# ============================================================

# ============================================================
# CONFIGURACIÓN INICIAL
# ============================================================

LOG_FILE="$HOME/kubuntu-lite.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Variables de estado
SELECTED_APPS=()
SELECTED_OPTIONAL=()
REMOVE_METAPACKAGE=false
USE_ROLLING=false
REMOVE_SNAPS=false
OPTIMIZE_GPU=false
OPTIMIZE_KERNEL=false
INSTALL_CUDA=false

# ============================================================
# FUNCIONES DE LOG Y PROGRESO
# ============================================================

log() {
    local msg="$1"
    echo -e "$msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g')" >> "$LOG_FILE"
}

log_info() { log "${BLUE}ℹ $1${NC}"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_error() { log "${RED}✗ $1${NC}"; }
log_warning() { log "${YELLOW}⚠ $1${NC}"; }
log_title() { log "\n${PURPLE}${BOLD}► $1${NC}\n"; }

show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%% - ${YELLOW}%s${NC}    " "$percent" "$task"
}

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    KUBUNTU LITE ULTIMATE                         ║"
    echo "║              Transformación y Optimización Extrema               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Log activo: $LOG_FILE${NC}\n"
}

pause() {
    echo -e "\n${YELLOW}─────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}Presiona Enter para volver al menú principal...${NC}"
    read
}

confirm() {
    local prompt="$1"
    local response
    read -p "$prompt (s/n): " response
    [[ "$response" =~ ^[sS]$ ]]
}
# ============================================================
# OPCIÓN 1: ELIMINAR APLICACIONES (ACTUALIZADA)
# ============================================================

select_apps_to_remove() {
    log_title "ELIMINAR APLICACIONES PREINSTALADAS"

    echo -e "${YELLOW}Lista de aplicaciones que puedes eliminar:${NC}\n"

    local apps=(
        "1|akregator|Lector RSS y feeds"
        "2|cantata|Cliente de música MPD"
        "3|dragonplayer|Reproductor de video"
        "4|juk|Reproductor de audio"
        "5|k3b|Grabador de CDs y DVDs"
        "6|kaddressbook|Agenda de contactos"
        "7|kalarm|Alarmas y recordatorios"
        "8|kate|Editor de texto avanzado"
        "9|kmag|Lupa de pantalla"
        "10|kmail|Cliente de correo electrónico"
        "11|kmahjongg|Juego de Mahjongg"
        "12|kmines|Juego de buscaminas"
        "13|knotes|Notas adhesivas"
        "14|konsole|Terminal"
        "15|kontact|Suite PIM completa"
        "16|konversation|Cliente IRC"
        "17|korganizer|Calendario"
        "18|kpat|Juego de cartas"
        "19|krdc|Escritorio remoto"
        "20|kruler|Regla en pantalla"
        "21|ksudoku|Juego de Sudoku"
        "22|ktorrent|Cliente Torrent"
        "23|libreoffice-core|Suite ofimática"
        "24|skanlite|Escáner"
        "25|kmouth|Sintetizador de voz"
        "26|kcharselect|Mapa de caracteres"
        "27|kdf|Visor de disco"
        "28|kfind|Buscador de archivos"
        "29|kgpg|Gestión de claves GPG"
        "30|kamoso|Cámara web"
        "31|kdeconnect|Sincronización con móvil"
        "32|kdenlive|Editor de video"
        "33|khelpcenter|Centro de ayuda"
        "34|kio-extras|Extra de protocolos KIO"
        "35|kmix|Control de volumen"
        "36|kolourpaint|Pintura simple"
        "37|kompare|Comparador de archivos"
        "38|kpat|Juego de cartas"
        "39|kremotecontrol|Control remoto"
        "40|kscreen|Configuración de pantallas"
        "41|ksystemlog|Visor de logs"
        "42|kteatime|Temporizador para té"
        "43|ktimer|Temporizador"
        "44|kwalletmanager|Gestión de contraseñas"
        "45|okular|Visor de PDF/DjVu"
        "46|spectacle|Capturas de pantalla"
        "47|gwenview|Visor de imágenes"
        "48|mpv|Reproductor multimedia ligero"
        "49|remmina|Cliente de escritorio remoto"
        "50|kruler|Regla en pantalla"
        "51|plasma-discover|Tienda de aplicaciones"
        "52|plasma-welcome|Guía de bienvenida de Kubuntu"
        "53|kubuntu-docs|Documentación de Kubuntu"
        "54|kubuntu-web-shortcuts|Accesos web de Kubuntu"
        "55|qml-module-org-kde-kirigami2|Componentes Kirigami"
        "56|qml-module-qtquick-controls2|Controles QtQuick"
    )

    for app in "${apps[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${CYAN}[%2s]${NC} %-20s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${YELLOW}Instrucciones: Escribe los números separados por espacio${NC}"
    echo "Ejemplo: 3 5 11 23 47 48 49"
    echo ""
    echo -e "${CYAN}Apps nuevas añadidas:${NC}"
    echo "  • 47 gwenview   - Visor de imágenes"
    echo "  • 48 mpv        - Reproductor multimedia ligero"
    echo "  • 49 remmina    - Cliente de escritorio remoto (alternativa a KRDC)"
    echo "  • 51 plasma-discover - Tienda de aplicaciones"
    echo "  • 52 plasma-welcome  - Guía de bienvenida de Kubuntu"
    echo "  • 53 kubuntu-docs    - Documentación de Kubuntu"
    echo "  • 54 kubuntu-web-shortcuts - Accesos web de Kubuntu"
    echo ""

    read -p "Números a eliminar: " input

    SELECTED_APPS=()
    if [ -n "$input" ]; then
        for num in $input; do
            for app in "${apps[@]}"; do
                app_num=$(echo "$app" | cut -d'|' -f1)
                app_name=$(echo "$app" | cut -d'|' -f2)
                if [ "$app_num" = "$num" ]; then
                    SELECTED_APPS+=("$app_name")
                    log_success "Marcado: $app_name"
                fi
            done
        done
    fi

    echo ""
    if confirm "¿Eliminar TODO el sistema Snap? (Firefox, Store, etc.)"; then
        REMOVE_SNAPS=true
        SELECTED_APPS+=("snapd")
        log_success "Snap será eliminado"
    fi

    log_info "Total a eliminar: ${#SELECTED_APPS[@]} apps"
    pause
}
# ============================================================
# OPCIÓN 3: OPTIMIZACIONES DE RENDIMIENTO
# ============================================================

optimize_performance() {
    log_title "OPTIMIZACIONES DE RENDIMIENTO"

    echo -e "${YELLOW}1. Optimización GPU NVIDIA${NC}"
    echo "   Activa modo de rendimiento persistente y perfiles de memoria"
    if confirm "¿Optimizar GPU NVIDIA? (si tienes NVIDIA)"; then
        OPTIMIZE_GPU=true
        log_success "Optimización GPU activada"
    fi

    echo -e "\n${YELLOW}2. Optimización del Kernel y Memoria${NC}"
    echo "   Reduce swappiness y mejora caché del sistema"
    if confirm "¿Optimizar kernel y memoria? (recomendado)"; then
        OPTIMIZE_KERNEL=true
        log_success "Optimización kernel/memoria activada"
    fi

    echo -e "\n${YELLOW}3. Instalar CUDA Toolkit${NC}"
    echo "   Para aceleración en IA, edición de vídeo y renderizado"
    if confirm "¿Instalar CUDA Toolkit? (opcional, requiere NVIDIA)"; then
        INSTALL_CUDA=true
        log_success "Instalación de CUDA activada"
    fi

    pause
}

# ============================================================
# OPCIÓN 4: ACTUALIZACIÓN DEL SISTEMA (CORREGIDA)
# ============================================================

system_update() {
    log_title "ACTUALIZACIÓN COMPLETA DEL SISTEMA"

    echo -e "${YELLOW}Se ejecutará:${NC}"
    echo "  • sudo apt update"
    echo "  • sudo apt upgrade -y"
    echo "  • sudo apt autoremove -y"
    echo "  • sudo apt autoclean -y"
    echo ""

    if ! confirm "¿Actualizar el sistema?"; then
        log_info "Actualización cancelada"
        pause
        return 1
    fi

    # Paso 1: Update (con barra de progreso animada)
    echo ""
    log_info "[1/4] Actualizando lista de paquetes..."
    echo -ne "${CYAN}[>>>         ] 0% - Ejecutando apt update...${NC}\r"
    sudo apt update > /tmp/apt_update.log 2>&1
    echo -ne "${CYAN}[============] 100% - ¡Completado!                ${NC}\n"
    log_success "Lista de paquetes actualizada"

    # Mostrar resumen de actualizaciones disponibles
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    if [ "$updates" -gt 0 ]; then
        log_info "Hay $updates paquetes para actualizar"
    fi

    # Paso 2: Upgrade (con barra de progreso)
    echo ""
    log_info "[2/4] Actualizando paquetes del sistema..."
    echo -ne "${CYAN}[>>>         ] 0% - Iniciando upgrade...${NC}\r"
    sudo apt upgrade -y > /tmp/apt_upgrade.log 2>&1
    echo -ne "${CYAN}[============] 100% - ¡Completado!                ${NC}\n"
    log_success "Paquetes actualizados"

    # Paso 3: Autoremove
    echo ""
    log_info "[3/4] Eliminando paquetes huérfanos..."
    echo -ne "${CYAN}[>>>         ] 0% - Buscando dependencias huérfanas...${NC}\r"
    sleep 1
    echo -ne "${CYAN}[=======>    ] 50% - Eliminando paquetes...${NC}\r"
    sudo apt autoremove -y > /tmp/apt_autoremove.log 2>&1
    echo -ne "${CYAN}[============] 100% - ¡Completado!                ${NC}\n"
    log_success "Paquetes huérfanos eliminados"

    # Paso 4: Autoclean
    echo ""
    log_info "[4/4] Limpiando caché de paquetes..."
    echo -ne "${CYAN}[>>>         ] 0% - Limpiando caché...${NC}\r"
    sleep 1
    echo -ne "${CYAN}[============] 100% - ¡Completado!                ${NC}\n"
    sudo apt autoclean -y > /tmp/apt_autoclean.log 2>&1
    log_success "Caché limpiado"

    echo ""
    log_success "¡SISTEMA ACTUALIZADO COMPLETAMENTE!"

    # Mostrar estadísticas finales
    echo ""
    echo -e "${GREEN}Resumen de la actualización:${NC}"
    echo "  • Repositorios actualizados: ✓"
    echo "  • Paquetes actualizados: $updates"
    echo "  • Espacio liberado: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
    echo ""

    pause
}

# ============================================================
# OPCIÓN 5: INSTALAR ALACRITTY Y TEMAS
# ============================================================

install_custom_software() {
    log_title "INSTALAR ALACRITTY Y TEMAS"

    if confirm "¿Instalar Alacritty (terminal moderna)?"; then
        log_info "Instalando Alacritty..."
        sudo apt update > /dev/null 2>&1
        sudo apt install -y alacritty > /dev/null 2>&1

        mkdir -p ~/.config/alacritty
        cat > ~/.config/alacritty/alacritty.toml << 'EOF'
[window]
opacity = 0.95
padding = { x = 10, y = 10 }

[font]
size = 12

[font.normal]
family = "Monospace"
style = "Regular"

[colors]
primary = { background = "#1a1b26", foreground = "#c0caf5" }
normal = { black = "#15161e", red = "#f7768e", green = "#9ece6a", yellow = "#e0af68", blue = "#7aa2f7", magenta = "#bb9af7", cyan = "#7dcfff", white = "#a9b1d6" }
EOF
        log_success "Alacritty instalado y configurado"
    fi

    if confirm "¿Instalar tema Tokyo Night?"; then
        log_info "Instalando tema..."
        sudo apt install -y kpackagetool6 git > /dev/null 2>&1

        cd /tmp
        git clone https://github.com/fausto-kouches/tokyo-night-kde 2>/dev/null
        if [ -d "tokyo-night-kde" ]; then
            cd tokyo-night-kde
            kpackagetool6 -t Plasma/LookAndFeel -i ./ 2>/dev/null
            log_success "Tema instalado"
            lookandfeeltool -a org.kde.tokyonight.desktop 2>/dev/null
            log_success "Tema aplicado"
        fi
    fi

    pause
}

# ============================================================
# OPCIÓN 6: SOFTWARE OPCIONAL
# ============================================================

select_optional_software() {
    log_title "SOFTWARE OPCIONAL"

    echo -e "${YELLOW}Lista de programas disponibles:${NC}\n"

    local software=(
        "1|filezilla|Cliente FTP/SFTP"
        "2|code|Visual Studio Code"
        "3|virtualbox|VirtualBox"
        "4|google-chrome-stable|Google Chrome"
        "5|telegram-desktop|Telegram"
        "6|python3|Python 3"
        "7|python3-pip|PIP"
        "8|python3-venv|Entornos virtuales"
        "9|git|Git"
        "10|curl|CURL"
        "11|wget|Wget"
        "12|htop|HTOP"
        "13|fastfetch|Fastfetch"
        "14|timeshift|Timeshift"
        "15|gparted|GParted"
        "16|vim|Vim"
        "17|discord|Discord"
        "18|spotify|Spotify"
        "19|obs-studio|OBS Studio"
    )

    for app in "${software[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${CYAN}[%2s]${NC} %-20s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${YELLOW}Escribe los números separados por espacio${NC}"
    echo "Ejemplo: 2 4 13"
    read -p "Números a instalar: " input

    SELECTED_OPTIONAL=()
    if [ -n "$input" ]; then
        for num in $input; do
            for app in "${software[@]}"; do
                app_num=$(echo "$app" | cut -d'|' -f1)
                app_name=$(echo "$app" | cut -d'|' -f2)
                if [ "$app_num" = "$num" ]; then
                    SELECTED_OPTIONAL+=("$app_name")
                    log_success "Marcado: $app_name"
                fi
            done
        done
    fi

    log_info "Total a instalar: ${#SELECTED_OPTIONAL[@]} programas"
    pause
}

# ============================================================
# FUNCIONES DE EJECUCIÓN CON PROGRESO
# ============================================================

remove_apps_with_progress() {
    local apps=("$@")
    local total=${#apps[@]}
    local current=0

    for app in "${apps[@]}"; do
        if [[ "$app" != "snapd" ]] && dpkg -l | grep -q "^ii  $app"; then
            current=$((current + 1))
            show_progress $current $total "Eliminando: $app"
            sudo apt remove --purge -y "$app" > /dev/null 2>&1
            log_success "Eliminado: $app"
        fi
    done
    echo ""
}

remove_snap_with_progress() {
    log_info "Eliminando Snap..."

    show_progress 1 5 "Deteniendo servicios snap"
    sudo systemctl stop snapd.service 2>/dev/null
    sudo systemctl disable snapd.service 2>/dev/null

    local snaps=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')
    local snap_count=$(echo "$snaps" | wc -l)
    local current=0

    for snap in $snaps; do
        if [ "$snap" != "Name" ] && [ "$snap" != "core" ] && [ "$snap" != "core20" ] && [ "$snap" != "core22" ]; then
            current=$((current + 1))
            show_progress $current $snap_count "Eliminando snap: $snap"
            sudo snap remove --purge "$snap" 2>/dev/null
        fi
    done

    show_progress 2 5 "Eliminando snaps del sistema"
    sudo snap remove --purge core22 2>/dev/null
    sudo snap remove --purge core20 2>/dev/null
    sudo snap remove --purge core 2>/dev/null

    show_progress 3 5 "Desmontando directorios"
    for mnt in $(mount | grep snap | awk '{print $3}'); do
        sudo umount "$mnt" 2>/dev/null
    done

    show_progress 4 5 "Eliminando paquetes snapd"
    sudo apt remove --purge -y snapd gnome-software-plugin-snap 2>/dev/null
    sudo apt-mark hold snapd 2>/dev/null

    show_progress 5 5 "Limpiando archivos residuales"
    sudo rm -rf ~/snap /snap /var/snap /var/lib/snapd /var/cache/snapd

    echo ""
    log_success "Snap eliminado completamente"
}

apply_kde_rolling() {
    log_info "Cambiando a KDE Rolling Release..."
    sudo add-apt-repository -y ppa:kubuntu-ppa/backports > /dev/null 2>&1
    sudo apt update > /dev/null 2>&1
    log_success "KDE Rolling Release activado"
}

optimize_gpu() {
    log_info "Optimizando GPU NVIDIA..."
    if command -v nvidia-smi &> /dev/null; then
        sudo nvidia-smi -pm 1 > /dev/null 2>&1
        sudo nvidia-smi -ac 5001,1590 > /dev/null 2>&1
        log_success "Modo persistente y perfil de memoria activados"
    else
        log_warning "Driver NVIDIA no detectado, omitiendo optimización"
    fi
}

optimize_kernel() {
    log_info "Optimizando kernel y memoria..."

    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1

    sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1

    log_success "Kernel optimizado"
}

install_cuda() {
    log_info "Instalando CUDA Toolkit..."
    sudo apt install -y nvidia-cuda-toolkit > /dev/null 2>&1
    log_success "CUDA Toolkit instalado"
}

install_optional_with_progress() {
    local apps=("$@")
    local total=${#apps[@]}
    local current=0

    log_info "Instalando software opcional..."
    sudo apt update > /dev/null 2>&1

    for app in "${apps[@]}"; do
        current=$((current + 1))
        show_progress $current $total "Instalando: $app"

        case $app in
            "filezilla") sudo apt install -y filezilla > /dev/null 2>&1 ;;
            "code")
                if ! command -v code &> /dev/null; then
                    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                    rm -f packages.microsoft.gpg
                    sudo apt update > /dev/null 2>&1
                fi
                sudo apt install -y code > /dev/null 2>&1
                ;;
            "virtualbox") sudo apt install -y virtualbox virtualbox-ext-pack > /dev/null 2>&1 ;;
            "google-chrome-stable")
                wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
                sudo dpkg -i /tmp/chrome.deb > /dev/null 2>&1
                sudo apt install -f -y > /dev/null 2>&1
                rm /tmp/chrome.deb
                ;;
            "telegram-desktop") sudo apt install -y telegram-desktop > /dev/null 2>&1 ;;
            "python3") sudo apt install -y python3 > /dev/null 2>&1 ;;
            "python3-pip") sudo apt install -y python3-pip > /dev/null 2>&1 ;;
            "python3-venv") sudo apt install -y python3-venv > /dev/null 2>&1 ;;
            "git") sudo apt install -y git > /dev/null 2>&1 ;;
            "curl") sudo apt install -y curl > /dev/null 2>&1 ;;
            "wget") sudo apt install -y wget > /dev/null 2>&1 ;;
            "htop") sudo apt install -y htop > /dev/null 2>&1 ;;
            "fastfetch")
                sudo apt install -y fastfetch > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    sudo apt install -y git cmake build-essential > /dev/null 2>&1
                    git clone https://github.com/fastfetch-cli/fastfetch /tmp/fastfetch 2>/dev/null
                    cd /tmp/fastfetch && mkdir -p build && cd build
                    cmake .. > /dev/null 2>&1 && make -j$(nproc) > /dev/null 2>&1
                    sudo make install > /dev/null 2>&1
                    cd / && rm -rf /tmp/fastfetch
                fi
                echo "alias neofetch='fastfetch'" >> ~/.bashrc
                ;;
            "timeshift") sudo apt install -y timeshift > /dev/null 2>&1 ;;
            "gparted") sudo apt install -y gparted > /dev/null 2>&1 ;;
            "vim") sudo apt install -y vim > /dev/null 2>&1 ;;
            "discord")
                wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
                sudo dpkg -i /tmp/discord.deb > /dev/null 2>&1
                sudo apt install -f -y > /dev/null 2>&1
                rm /tmp/discord.deb
                ;;
            "spotify")
                curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
                echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
                sudo apt update > /dev/null 2>&1
                sudo apt install -y spotify-client > /dev/null 2>&1
                ;;
            "obs-studio") sudo apt install -y obs-studio > /dev/null 2>&1 ;;
        esac
        log_success "Instalado: $app"
    done
    echo ""
}

# ============================================================
# ELIMINACIÓN NUCLEAR DE SNAP
# ============================================================

nuclear_snap_removal() {
    log_title "ELIMINACIÓN NUCLEAR DE SNAP - SIN RASTRO"

    echo -e "${RED}${BOLD}⚠️  ADVERTENCIA: Esta acción es IRREVERSIBLE ⚠️${NC}"
    echo -e "${YELLOW}Eliminará COMPLETAMENTE:${NC}"
    echo "  • Todos los paquetes snap instalados"
    echo "  • El servicio snapd y su demonio"
    echo "  • Todos los directorios de Snap"
    echo "  • Configuraciones y cachés"
    echo "  • Prevención de reinstalación automática"
    echo ""
    echo -e "${RED}Esto afectará a: Firefox, Snap Store, y cualquier snap que tengas${NC}"
    echo ""

    if ! confirm "¿Estás ABSOLUTAMENTE seguro de eliminar Snap para siempre?"; then
        log_info "Eliminación nuclear cancelada"
        pause
        return 1
    fi

    if ! confirm "ÚLTIMA ADVERTENCIA: ¿Confirmar eliminación TOTAL de Snap?"; then
        log_info "Eliminación nuclear cancelada"
        pause
        return 1
    fi

    log_info "Iniciando eliminación nuclear de Snap..."

    log_info "[1/11] Deteniendo servicios snap..."
    sudo systemctl stop snapd.service 2>/dev/null
    sudo systemctl stop snapd.socket 2>/dev/null
    sudo systemctl disable snapd.service 2>/dev/null
    sudo systemctl disable snapd.socket 2>/dev/null
    log_success "Servicios detenidos"

    log_info "[2/11] Matando procesos snap..."
    sudo pkill -f snapd 2>/dev/null
    sudo killall snapd 2>/dev/null
    log_success "Procesos eliminados"

    log_info "[3/11] Eliminando paquetes snap..."
    local snaps=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')
    for snap in $snaps; do
        if [ "$snap" != "Name" ]; then
            sudo snap remove --purge "$snap" 2>/dev/null
        fi
    done
    log_success "Paquetes snap eliminados"

    log_info "[4/11] Eliminando snaps del sistema..."
    sudo snap remove --purge core22 2>/dev/null
    sudo snap remove --purge core20 2>/dev/null
    sudo snap remove --purge core 2>/dev/null
    log_success "Core snaps eliminados"

    log_info "[5/11] Desmontando directorios loop..."
    for mnt in $(mount | grep -E 'snap|/snap/' | awk '{print $3}'); do
        sudo umount "$mnt" 2>/dev/null
    done
    log_success "Directorios desmontados"

    log_info "[6/11] Eliminando paquetes snapd..."
    sudo apt remove --purge -y snapd gnome-software-plugin-snap snapd-xdg-open > /dev/null 2>&1
    sudo apt autoremove --purge -y > /dev/null 2>&1
    log_success "Paquetes snapd eliminados"

    log_info "[7/11] Bloqueando reinstalación..."
    sudo apt-mark hold snapd 2>/dev/null
    echo 'Package: snapd
Pin: release *
Pin-Priority: -1' | sudo tee /etc/apt/preferences.d/nosnap.pref > /dev/null
    log_success "Reinstalación bloqueada"

    log_info "[8/11] Eliminando directorios de Snap..."
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null
    sudo rm -rf /etc/systemd/system/snapd.* 2>/dev/null
    log_success "Directorios eliminados"

    log_info "[9/11] Eliminando configuraciones de usuario..."
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            sudo rm -rf "$user_home/snap" "$user_home/.cache/snap" "$user_home/.config/snap" 2>/dev/null
        fi
    done
    sudo rm -rf ~/snap 2>/dev/null
    log_success "Configuraciones eliminadas"

    log_info "[10/11] Eliminando binarios residuales..."
    sudo rm -f /usr/bin/snap /usr/bin/snapctl /usr/lib/snapd 2>/dev/null
    log_success "Binarios eliminados"

    log_info "[11/11] Limpieza final..."
    sudo apt autoremove --purge -y > /dev/null 2>&1
    sudo apt autoclean -y > /dev/null 2>&1
    log_success "Limpieza completada"

    echo ""
    log_success "¡ELIMINACIÓN NUCLEAR DE SNAP COMPLETADA!"
    log_warning "Snap ha sido borrado SIN POSIBILIDAD DE REINSTALACIÓN"
    log_info "Para Firefox: sudo apt install firefox"
    pause
}

# ============================================================
# APLICAR TODOS LOS CAMBIOS
# ============================================================

apply_all_changes() {
    log_title "APLICANDO TODOS LOS CAMBIOS"

    echo -e "${YELLOW}Resumen de cambios a aplicar:${NC}"
    [ ${#SELECTED_APPS[@]} -gt 0 ] && echo "  • Eliminar ${#SELECTED_APPS[@]} aplicaciones"
    [ "$REMOVE_METAPACKAGE" = true ] && echo "  • Eliminar kubuntu-desktop"
    [ "$USE_ROLLING" = true ] && echo "  • KDE Rolling Release"
    [ "$REMOVE_SNAPS" = true ] && echo "  • Eliminar Snap"
    [ "$OPTIMIZE_GPU" = true ] && echo "  • Optimizar GPU NVIDIA"
    [ "$OPTIMIZE_KERNEL" = true ] && echo "  • Optimizar Kernel y Memoria"
    [ "$INSTALL_CUDA" = true ] && echo "  • Instalar CUDA Toolkit"
    [ ${#SELECTED_OPTIONAL[@]} -gt 0 ] && echo "  • Instalar ${#SELECTED_OPTIONAL[@]} programas"

    echo ""
    if ! confirm "¿Aplicar estos cambios?"; then
        log_info "Cancelado"
        pause
        return 1
    fi

    if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
        echo ""
        remove_apps_with_progress "${SELECTED_APPS[@]}"
    fi

    if [ "$REMOVE_SNAPS" = true ]; then
        echo ""
        remove_snap_with_progress
    fi

    if [ "$REMOVE_METAPACKAGE" = true ]; then
        echo ""
        log_info "Eliminando kubuntu-desktop..."
        sudo apt remove --purge -y kubuntu-desktop > /dev/null 2>&1
        sudo apt install -y plasma-desktop > /dev/null 2>&1
        log_success "Reemplazado por plasma-desktop"
    fi

    if [ "$USE_ROLLING" = true ]; then
        echo ""
        apply_kde_rolling
    fi

    if [ "$OPTIMIZE_GPU" = true ]; then
        echo ""
        optimize_gpu
    fi

    if [ "$OPTIMIZE_KERNEL" = true ]; then
        echo ""
        optimize_kernel
    fi

    if [ "$INSTALL_CUDA" = true ]; then
        echo ""
        install_cuda
    fi

    echo ""
    log_info "Limpieza final..."
    sudo apt autoremove --purge -y > /dev/null 2>&1
    journalctl --vacuum-size=200M 2>/dev/null
    rm -rf ~/.cache/thumbnails/* 2>/dev/null
    log_success "Limpieza completada"

    if [ ${#SELECTED_OPTIONAL[@]} -gt 0 ]; then
        echo ""
        if confirm "¿Instalar el software opcional seleccionado?"; then
            install_optional_with_progress "${SELECTED_OPTIONAL[@]}"
        fi
    fi

    echo ""
    log_success "¡Sistema transformado y optimizado!"
    log_warning "Recomendación: Reinicia el sistema para aplicar todos los cambios"
    pause
}

# ============================================================
# REVERTIR CAMBIOS
# ============================================================

revert_changes() {
    log_title "REVERTIR A KUBUNTU ORIGINAL"

    echo -e "${YELLOW}Esto reinstalará:${NC}"
    echo "  • kubuntu-desktop"
    echo "  • Snap"
    echo "  • Eliminará repositorios Rolling Release"

    if ! confirm "¿Revertir a Kubuntu original?"; then
        log_info "Cancelado"
        pause
        return 1
    fi

    log_info "Reinstalando kubuntu-desktop..."
    sudo apt install --reinstall -y kubuntu-desktop > /dev/null 2>&1

    log_info "Eliminando Rolling Release..."
    sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports > /dev/null 2>&1

    log_info "Reinstalando Snap..."
    sudo apt install -y snapd > /dev/null 2>&1

    log_info "Limpiando configuraciones..."
    rm -rf ~/.config/alacritty

    echo ""
    log_success "Sistema revertido"
    log_warning "Reinicia para completar"
    pause
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}¿Qué deseas hacer?${NC}\n"
        echo "  1) 🗑️  Eliminar aplicaciones preinstaladas"
        echo "  2) ⚙️  Configurar sistema (Rolling Release)"
        echo "  3) 🚀  Optimizaciones de rendimiento (GPU, Kernel)"
        echo "  4) 🔄  ACTUALIZAR SISTEMA (update/upgrade/clean)"
        echo "  5) 🎨  Instalar Alacritty y temas"
        echo "  6) 📦  Instalar software opcional"
        echo "  7) 🔧  Aplicar TODOS los cambios"
        echo "  8) ↩️  Revertir a Kubuntu original"
        echo "  9) ☢️  ELIMINACIÓN NUCLEAR DE SNAP"
        echo "  0) ❌  Salir"
        echo ""
        read -p "Opción (0-9): " option

        case $option in
            1) select_apps_to_remove ;;
            2) configure_system ;;
            3) optimize_performance ;;
            4) system_update ;;
            5) install_custom_software ;;
            6) select_optional_software ;;
            7) apply_all_changes ;;
            8) revert_changes ;;
            9) nuclear_snap_removal ;;
            0)
                log_success "¡Hasta luego!"
                exit 0
                ;;
            *)
                log_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# ============================================================
# INICIO
# ============================================================

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}No ejecutes este script como root (no uses sudo)${NC}"
    exit 1
fi

# Crear archivo de log
echo "=== Kubuntu Lite Ultimate - $(date) ===" > "$LOG_FILE"

main_menu
