#!/bin/bash

# ============================================================
# Script: Kubuntu Lite Ultimate
# Descripción: Transforma Kubuntu en un sistema minimalista
#              con optimizaciones de rendimiento extremo
# Versión: 7.0 - MENÚS UNIFORMES Y ESTÉTICA CUIDADA
# ============================================================

# ============================================================
# CONFIGURACIÓN INICIAL
# ============================================================

LOG_FILE="$HOME/kubuntu-lite.log"

# Estado guardado entre ejecuciones (lo usa "Revertir")
STATE_DIR="$HOME/.local/share/kubuntu-lite"
REMOVED_LIST="$STATE_DIR/paquetes-eliminados.txt"
SHORTCUTS_BACKUP="$STATE_DIR/accesos-directos"

# Colores base (uniformes por menú)
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

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    KUBUNTU LITE ULTIMATE                         ║"
    echo "║              Transformación y Optimización Extrema               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}📁 Log activo: $LOG_FILE${NC}\n"
}

pause() {
    echo -e "\n${YELLOW}─────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}📌 Presiona Enter para continuar...${NC}"
    read -r
}

confirm() {
    local prompt="$1"
    local response
    echo -e -n "$prompt (s/n): "
    read -r response
    [[ "$response" =~ ^([sSyY]|[sS][iI]|[sS]í|[sS]Í)$ ]]
}

# ============================================================
# FUNCIONES DE EJECUCIÓN SEGURA
# ============================================================

# Ejecuta un comando guardando su salida en el log.
# Si falla, muestra el error en pantalla en lugar de ocultarlo.
run() {
    local desc="$1"
    shift
    echo "[$(date '+%H:%M:%S')] \$ $*" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1
    local rc=$?
    if [ $rc -ne 0 ]; then
        log_error "$desc (código $rc). Detalles en: $LOG_FILE"
    fi
    return $rc
}

apt_update() { run "Falló 'apt update'" sudo apt-get update; }
apt_install() { run "No se pudo instalar: $*" sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
apt_purge() { run "No se pudo eliminar: $*" sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@"; }

# Lista los paquetes instalados que coinciden con los patrones dados
installed_pkgs() {
    dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' "$@" 2>/dev/null | awk '$1 ~ /^.i/ {print $2}'
}

# Elimina paquetes y anota todo lo que apt quita (también dependencias) para poder revertir
purge_and_record() {
    local removed
    removed=$(apt-get -s purge "$@" 2>/dev/null | awk '/^(Purg|Remv) / {print $2}')
    apt_purge "$@" || return 1
    if [ -n "$removed" ]; then
        mkdir -p "$STATE_DIR"
        echo "$removed" >> "$REMOVED_LIST"
        sort -u -o "$REMOVED_LIST" "$REMOVED_LIST"
    fi
}

# Dependencias y recomendaciones de kubuntu-desktop (las apps originales de Kubuntu)
kubuntu_desktop_pkgs() {
    apt-cache depends kubuntu-desktop 2>/dev/null \
        | awk '$1 ~ /^\|?(Depends|Recommends):$/ && $2 !~ /^</ {print $2}' | sort -u
}

SYSCTL_FILE="/etc/sysctl.d/99-kubuntu-lite.conf"

# Aplica un parámetro sysctl y lo deja persistente sin duplicar líneas
set_sysctl() {
    local key="$1" value="$2"
    run "No se pudo aplicar $key=$value" sudo sysctl -w "$key=$value"
    # Versiones anteriores añadían líneas repetidas en /etc/sysctl.conf
    sudo sed -i "/^${key//./\\.}=/d" /etc/sysctl.conf 2>/dev/null
    sudo touch "$SYSCTL_FILE"
    if grep -q "^${key//./\\.} *=" "$SYSCTL_FILE"; then
        sudo sed -i "s|^${key//./\\.} *=.*|$key = $value|" "$SYSCTL_FILE"
    else
        echo "$key = $value" | sudo tee -a "$SYSCTL_FILE" > /dev/null
    fi
}

# ============================================================
# OPCIÓN 1: ELIMINAR APLICACIONES (COLOR: CIAN)
# ============================================================

select_apps_to_remove() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🗑️ ELIMINAR APLICACIONES                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${CYAN}📋 Lista de aplicaciones que puedes eliminar:${NC}\n"

    local apps=(
        "1|akregator|📰 Lector RSS y feeds"
        "2|cantata|🎵 Cliente de música MPD"
        "3|dragonplayer|🎬 Reproductor de video"
        "4|juk|🎵 Reproductor de audio"
        "5|k3b|💿 Grabador de CDs y DVDs"
        "6|kaddressbook|📇 Agenda de contactos"
        "7|kalarm|⏰ Alarmas y recordatorios"
        "8|kate|📝 Editor de texto avanzado"
        "9|kmag|🔍 Lupa de pantalla"
        "10|kmail|📧 Cliente de correo electrónico"
        "11|kmahjongg|🀄 Juego de Mahjongg"
        "12|kmines|💣 Juego de buscaminas"
        "13|knotes|📋 Notas adhesivas"
        "14|konsole|💻 Terminal"
        "15|kontact|📅 Suite PIM completa"
        "16|konversation|💬 Cliente IRC"
        "17|korganizer|📆 Calendario"
        "18|kpat|🃏 Juego de cartas solitario"
        "19|krdc|🖥️ Cliente de escritorio remoto"
        "20|kruler|📏 Regla en pantalla"
        "21|ksudoku|🔢 Juego de Sudoku"
        "22|ktorrent|📥 Cliente Torrent"
        "23|libreoffice-core|📄 Suite ofimática"
        "24|skanlite|🖨️ Escáner"
        "25|kmouth|🗣️ Sintetizador de voz"
        "26|kcharselect|🔣 Mapa de caracteres"
        "27|kdf|💾 Visor de uso de disco"
        "28|kfind|🔎 Buscador de archivos"
        "29|kgpg|🔐 Gestión de claves GPG"
        "30|kamoso|📷 Cámara web"
        "31|kdeconnect|📱 Sincronización con móvil"
        "32|kdenlive|🎬 Editor de video"
        "33|khelpcenter|❓ Centro de ayuda"
        "34|kio-extras|🔌 Protocolos extra KIO"
        "35|kmix|🔊 Control de volumen"
        "36|kolourpaint|🎨 Pintura simple"
        "37|kompare|📊 Comparador de archivos"
        "38|kremotecontrol|🎮 Control remoto"
        "39|kscreen|🖥️ Configuración de pantallas"
        "40|ksystemlog|📋 Visor de logs del sistema"
        "41|kteatime|🍵 Temporizador para té"
        "42|ktimer|⏱️ Temporizador"
        "43|kwalletmanager|👛 Gestión de contraseñas"
        "44|okular|📖 Visor de PDF/DjVu"
        "45|spectacle|📸 Capturas de pantalla"
        "46|gwenview|🖼️ Visor de imágenes"
        "47|mpv|🎬 Reproductor multimedia ligero"
        "48|remmina|🖥️ Cliente de escritorio remoto"
        "49|plasma-discover|🛒 Tienda de aplicaciones"
        "50|plasma-welcome|👋 Guía de bienvenida"
        "51|kubuntu-docs|📚 Documentación de Kubuntu"
        "52|kubuntu-web-shortcuts|🌐 Accesos web de Kubuntu"
        "53|qml-module-org-kde-kirigami2|🎨 Componentes Kirigami"
        "54|qml-module-qtquick-controls2|🎛️ Controles QtQuick"
    )

    for app in "${apps[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${CYAN}[%2s]${NC} %-22s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${CYAN}📝 Instrucciones: Escribe los números separados por espacio${NC}"
    echo -e "${CYAN}Ejemplo: 3 5 11 23 46 47 48${NC}\n"

    read -r -p "🔢 Números a eliminar: " input

    SELECTED_APPS=()
    if [ -n "$input" ]; then
        for num in $input; do
            for app in "${apps[@]}"; do
                app_num=$(echo "$app" | cut -d'|' -f1)
                app_name=$(echo "$app" | cut -d'|' -f2)
                if [ "$app_num" = "$num" ]; then
                    SELECTED_APPS+=("$app_name")
                    echo -e "  ${GREEN}✓ Marcado para eliminar: $app_name${NC}"
                fi
            done
        done
    fi

    if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
        echo ""
        echo -e "${CYAN}📋 Se eliminarán las siguientes aplicaciones:${NC}"
        for app in "${SELECTED_APPS[@]}"; do
            echo -e "  ${CYAN}•${NC} $app"
        done
        echo ""

        if confirm "${CYAN}⚠️ ¿Confirmar eliminación de estas ${#SELECTED_APPS[@]} aplicaciones?${NC}"; then
            remove_apps_with_progress "${SELECTED_APPS[@]}"
            echo -e "${GREEN}✓ Eliminación completada${NC}"
        else
            echo -e "${YELLOW}ℹ Eliminación cancelada${NC}"
            SELECTED_APPS=()
        fi
    else
        echo -e "${YELLOW}ℹ No seleccionaste ninguna aplicación${NC}"
    fi

    pause
}

# ============================================================
# OPCIÓN 2: CONFIGURAR SISTEMA (COLOR: VERDE)
# ============================================================

configure_system() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚙️ CONFIGURAR SISTEMA                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${GREEN}1. Meta-paquete kubuntu-desktop${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Es el paquete que agrupa todas las apps de Kubuntu"
    echo -e "   ${GREEN}✓ Si lo eliminas:${NC} Podrás desinstalar apps sin que se reinstalen"
    echo ""
    if confirm "${GREEN}¿Eliminar kubuntu-desktop? (recomendado)${NC}"; then
        # Sin el meta-paquete, sus apps quedan "huérfanas" y 'apt autoremove' (opción 6)
        # las borraría. Se marcan como instaladas manualmente para conservarlas.
        local kd_pkgs
        # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
        mapfile -t kd_pkgs < <(installed_pkgs $(kubuntu_desktop_pkgs))
        [ ${#kd_pkgs[@]} -gt 0 ] && run "No se pudieron proteger las apps de Kubuntu" sudo apt-mark manual "${kd_pkgs[@]}"
        purge_and_record kubuntu-desktop && log_success "Se eliminó kubuntu-desktop (las apps se conservan)"
    else
        echo -e "${YELLOW}ℹ Se mantiene kubuntu-desktop${NC}"
    fi

    echo ""
    echo -e "${GREEN}2. Cambio a KDE Rolling Release${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Cambia los repositorios a versión Rolling Release"
    echo -e "   ${GREEN}✓ Beneficio:${NC} Te dará las últimas versiones de KDE Plasma"
    echo ""
    if confirm "${GREEN}¿Cambiar a KDE Rolling Release? (recomendado)${NC}"; then
        run "No se pudo agregar ppa:kubuntu-ppa/backports" sudo add-apt-repository -y ppa:kubuntu-ppa/backports \
            && apt_update && log_success "Se cambió a KDE Rolling Release (ejecuta la opción 6 para actualizar)"
    else
        echo -e "${YELLOW}ℹ Se mantienen repositorios estándar${NC}"
    fi

    pause
}

# ============================================================
# OPCIÓN 3: OPTIMIZACIÓN DE GPU (COLOR: MAGENTA)
# ============================================================

optimize_gpu_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🎮 OPTIMIZACIÓN DE GPU                        ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "\n${PURPLE}🎮 Selecciona tu tarjeta gráfica:${NC}\n"
        echo -e "  ${PURPLE}1)${NC} NVIDIA - Optimización completa"
        echo -e "  ${PURPLE}2)${NC} AMD   - Optimización completa"
        echo -e "  ${PURPLE}3)${NC} Intel - Optimización completa"
        echo -e "  ${PURPLE}4)${NC} Detectar automáticamente y optimizar"
        echo -e "  ${PURPLE}5)${NC} Volver"
        echo ""
        read -r -p "📌 Opción (1-5): " gpu_option

        case $gpu_option in
            1) optimize_nvidia ;;
            2) optimize_amd ;;
            3) optimize_intel ;;
            4) auto_detect_gpu ;;
            5) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
        return 0
    done
}

optimize_nvidia() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🟢 OPTIMIZACIÓN NVIDIA                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}⚠ Driver NVIDIA no detectado. Instalando el recomendado para tu GPU...${NC}"
        apt_update
        apt_install ubuntu-drivers-common || return 1
        run "No se pudo instalar el driver NVIDIA" sudo ubuntu-drivers install || return 1
        log_success "Driver NVIDIA instalado (requiere reinicio)"
    else
        echo -e "${PURPLE}🔧 Activando modo persistente del driver...${NC}"
        run "No se pudo activar el modo persistente" sudo nvidia-smi -pm 1
    fi

    if confirm "${PURPLE}¿Instalar CUDA Toolkit? (varios GB, solo para desarrollo/IA)${NC}"; then
        echo -e "${PURPLE}📦 Instalando CUDA Toolkit...${NC}"
        apt_install nvidia-cuda-toolkit && log_success "CUDA Toolkit instalado"
    fi

    echo ""
    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN NVIDIA COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Reinicia el sistema para aplicar todos los cambios${NC}"
}

optimize_amd() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔴 OPTIMIZACIÓN AMD                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${PURPLE}🔧 Actualizando drivers AMD...${NC}"
    apt_update
    apt_install mesa-utils mesa-vulkan-drivers libgl1-mesa-dri || return 1

    echo -e "${PURPLE}🔧 Activando overclocking y control de fans...${NC}"
    echo 'options amdgpu ppfeaturemask=0xffffffff' | sudo tee /etc/modprobe.d/amd_ppfeaturemask.conf > /dev/null
    run "No se pudo regenerar initramfs" sudo update-initramfs -u

    echo -e "${PURPLE}🔧 Instalando CoreCtrl para control gráfico...${NC}"
    apt_install corectrl

    echo ""
    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN AMD COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Reinicia el sistema para aplicar todos los cambios${NC}"
}

optimize_intel() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔵 OPTIMIZACIÓN INTEL                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${PURPLE}🔧 Actualizando driver Intel...${NC}"
    apt_update
    apt_install intel-media-va-driver intel-gpu-tools va-driver-all vainfo || return 1

    echo -e "${PURPLE}🔧 Activando GuC/HuC para códecs...${NC}"
    echo 'options i915 enable_guc=3' | sudo tee /etc/modprobe.d/i915_guc.conf > /dev/null
    run "No se pudo regenerar initramfs" sudo update-initramfs -u

    echo ""
    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN INTEL COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Reinicia el sistema para aplicar todos los cambios${NC}"
}

auto_detect_gpu() {
    echo -e "${PURPLE}🔄 Detectando GPU...${NC}"
    # Solo dispositivos de vídeo: evita confundir la CPU/chipset AMD o Intel con la GPU
    local gpus
    gpus=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display controller')
    if grep -qi nvidia <<< "$gpus"; then
        echo -e "${GREEN}🟢 GPU NVIDIA detectada${NC}"
        optimize_nvidia
    elif grep -Eqi 'amd|ati|radeon' <<< "$gpus"; then
        echo -e "${GREEN}🔴 GPU AMD detectada${NC}"
        optimize_amd
    elif grep -qi intel <<< "$gpus"; then
        echo -e "${GREEN}🔵 GPU Intel detectada${NC}"
        optimize_intel
    else
        echo -e "${YELLOW}⚠ No se detectó ninguna GPU compatible${NC}"
    fi
}

# ============================================================
# OPCIÓN 4: OPTIMIZACIÓN DE KERNEL (COLOR: AZUL)
# ============================================================

optimize_kernel_menu() {
    while true; do
        clear
        echo -e "${BLUE}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    ⚡ OPTIMIZACIÓN DEL KERNEL                     ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "${BLUE}🐧 Kernel en uso: ${BOLD}$(uname -r)${NC}"
        echo -e "\n${BLUE}📋 Opciones de optimización del kernel:${NC}\n"
        echo -e "  ${BLUE}1)${NC} Kernel Liquorix (basado en Zen, máximo rendimiento, gaming)"
        echo -e "  ${BLUE}2)${NC} Kernel XanMod (rendimiento balanceado, desktop)"
        echo -e "  ${BLUE}3)${NC} Kernel oficial Ubuntu: LTS, HWE o versión específica (recomendado)"
        echo -e "  ${BLUE}4)${NC} Kernel oficial + Livepatch (Ubuntu Pro)"
        echo -e "  ${BLUE}5)${NC} Ajustes avanzados de kernel"
        echo -e "  ${BLUE}6)${NC} Volver"
        echo ""
        read -r -p "📌 Opción (1-6): " kernel_option

        case $kernel_option in
            1) install_liquorix_kernel ;;
            2) install_xanmod_kernel ;;
            3) optimize_standard_kernel ;;
            4) install_standard_livepatch_kernel ;;
            5) advanced_kernel_tweaks ;;
            6) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
        return 0
    done
}

# ------------------------------------------------------------
# Utilidades para cambiar de kernel
# ------------------------------------------------------------

# Kernels de terceros que gestiona el script
CUSTOM_KERNELS=("liquorix" "xanmod")
KERNEL_CLEANUP_FILE="$STATE_DIR/kernels-pendientes.txt"
GRUB_TEMP_PIN_FILE="$STATE_DIR/grub-fijado-temporal"
KERNEL_PENDING_CLEANUP=false
XANMOD_KEYRING="/etc/apt/keyrings/xanmod-archive-keyring.gpg"
XANMOD_LIST="/etc/apt/sources.list.d/xanmod-release.list"

# Versiones de kernel instaladas que contienen el texto dado (de menor a mayor)
kernel_versions() {
    installed_pkgs 'linux-image-[0-9]*' | sed 's/^linux-image-//' | grep -- "$1" | sort -V
}

secure_boot_enabled() {
    command -v mokutil &> /dev/null && mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"
}

# Comprobaciones antes de instalar un kernel de terceros
check_custom_kernel_requirements() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        log_error "Este kernel solo está disponible para arquitectura amd64"
        return 1
    fi

    if secure_boot_enabled; then
        log_error "Secure Boot está activado"
        echo -e "${YELLOW}  Liquorix y XanMod no están firmados: con Secure Boot el equipo NO arrancará con ellos.${NC}"
        echo -e "${YELLOW}  Desactiva Secure Boot en la BIOS/UEFI o usa el kernel oficial (opción 3).${NC}"
        return 1
    fi

    if [ -z "$(kernel_versions generic)" ]; then
        log_warning "No hay un kernel oficial (generic) instalado como respaldo"
        if ! confirm "${BLUE}¿Continuar de todos modos?${NC}"; then
            return 1
        fi
    fi

    local boot_free
    boot_free=$(df --output=avail -m /boot 2>/dev/null | tail -1 | tr -d ' ')
    if [ -n "$boot_free" ] && [ "$boot_free" -lt 300 ]; then
        log_warning "Poco espacio libre en /boot (${boot_free} MB); la instalación podría fallar"
    fi
    return 0
}

# Elimina paquetes de kernel, salvo los del kernel en uso: esos se apuntan
# en KERNEL_CLEANUP_FILE y se borran en la próxima ejecución, tras reiniciar.
purge_kernel_pkgs() {
    local running pkgs=() pending=() p
    running=$(uname -r)
    for p in "$@"; do
        if [[ "$p" == *"$running"* ]]; then
            pending+=("$p")
        else
            pkgs+=("$p")
        fi
    done

    if [ ${#pending[@]} -gt 0 ]; then
        mkdir -p "$STATE_DIR"
        printf '%s\n' "${pending[@]}" >> "$KERNEL_CLEANUP_FILE"
        sort -u -o "$KERNEL_CLEANUP_FILE" "$KERNEL_CLEANUP_FILE"
        KERNEL_PENDING_CLEANUP=true
        log_warning "El kernel en uso ($running) se eliminará al reiniciar y volver a abrir el script"
    fi
    [ ${#pkgs[@]} -eq 0 ] && return 0
    apt_purge "${pkgs[@]}"
}

# Elimina por completo un kernel de terceros (imágenes, headers y su repositorio)
remove_kernel_family() {
    local family="$1" pkgs
    mapfile -t pkgs < <(installed_pkgs "linux-*${family}*")

    if [ ${#pkgs[@]} -gt 0 ]; then
        purge_kernel_pkgs "${pkgs[@]}" || return 1
        log_success "Kernel ${family} eliminado"
    fi

    case $family in
        liquorix)
            if ls /etc/apt/sources.list.d/*damentz*liquorix* &> /dev/null; then
                run "No se pudo quitar el PPA de Liquorix" sudo add-apt-repository --remove -y ppa:damentz/liquorix
            fi
            ;;
        xanmod)
            sudo rm -f "$XANMOD_LIST" "$XANMOD_KEYRING"
            ;;
    esac
    return 0
}

# Cambia GRUB_DEFAULT en /etc/default/grub
set_grub_default() {
    local value="$1"
    if grep -q '^GRUB_DEFAULT=' /etc/default/grub; then
        sudo sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=\"$value\"|" /etc/default/grub
    else
        echo "GRUB_DEFAULT=\"$value\"" | sudo tee -a /etc/default/grub > /dev/null
    fi
}

# Hace que GRUB arranque por defecto la versión de kernel indicada.
# Usa los IDs de grub.cfg, que no dependen del idioma del sistema.
boot_kernel_by_default() {
    local version="$1" cfg="/boot/grub/grub.cfg" submenu entry
    run "Falló update-grub" sudo update-grub || return 1

    submenu=$(sudo grep -oP "^submenu .*\\\$menuentry_id_option '\Kgnulinux-advanced-[^']+" "$cfg" | head -1)
    entry=$(sudo grep -oP "menuentry .*\\\$menuentry_id_option '\Kgnulinux-\Q${version}\E-advanced-[^']+" "$cfg" | head -1)

    if [ -n "$submenu" ] && [ -n "$entry" ]; then
        set_grub_default "${submenu}>${entry}"
        log_success "GRUB arrancará por defecto: $version"
    else
        log_warning "No se encontró $version en GRUB; se arrancará el kernel más reciente"
        set_grub_default 0
    fi
    run "Falló update-grub" sudo update-grub
}

# Nivel de microarquitectura x86-64 soportado por la CPU (para XanMod)
x86_64_level() {
    local out
    out=$(/lib64/ld-linux-x86-64.so.2 --help 2>/dev/null)
    if grep -q 'x86-64-v3 (supported' <<< "$out"; then
        echo 3
    elif grep -q 'x86-64-v2 (supported' <<< "$out"; then
        echo 2
    fi
}

finish_custom_kernel() {
    local family="$1" label="$2" version
    version=$(kernel_versions "$family" | tail -1)
    if [ -z "$version" ] || [ ! -e "/boot/vmlinuz-$version" ]; then
        log_error "El kernel $label no quedó instalado en /boot"
        return 1
    fi

    boot_kernel_by_default "$version"

    echo ""
    log_success "Kernel $label instalado: $version"
    echo -e "${YELLOW}⚠ Reinicia para usar el nuevo kernel${NC}"
    echo -e "${BLUE}📋 Si no arranca, elige el kernel 'generic' en 'Opciones avanzadas' de GRUB${NC}"
    echo -e "${BLUE}   (mantén Shift o pulsa Esc al encender) y vuelve con la opción 3.${NC}"
}

# ------------------------------------------------------------
# Instalación de kernels
# ------------------------------------------------------------

install_liquorix_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚡ KERNEL LIQUORIX                             ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    check_custom_kernel_requirements || return 1

    echo -e "${BLUE}[1/4] Agregando repositorio Liquorix...${NC}"
    run "No se pudo agregar el PPA de Liquorix" sudo add-apt-repository -y ppa:damentz/liquorix || return 1
    apt_update || return 1

    echo -e "${BLUE}[2/4] Instalando kernel Liquorix (puede tardar varios minutos)...${NC}"
    apt_install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || return 1

    echo -e "${BLUE}[3/4] Eliminando XanMod si existe...${NC}"
    remove_kernel_family xanmod

    echo -e "${BLUE}[4/4] Configurando GRUB...${NC}"
    finish_custom_kernel liquorix "Liquorix"
}

install_xanmod_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🐧 KERNEL XANMOD                              ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${YELLOW}ℹ El kernel Zen no existe para Ubuntu; XanMod es la alternativa equivalente${NC}\n"

    check_custom_kernel_requirements || return 1

    local level codename package tmp_key
    level=$(x86_64_level)
    if [ -z "$level" ]; then
        log_error "Tu CPU no soporta x86-64-v2, requerido por XanMod"
        return 1
    fi
    package="linux-xanmod-x64v${level}"
    # shellcheck disable=SC1091
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo -e "${BLUE}📋 CPU compatible con x86-64-v${level} → paquete ${package}${NC}\n"

    echo -e "${BLUE}[1/5] Agregando repositorio XanMod...${NC}"
    command -v wget &> /dev/null || apt_install wget || return 1
    tmp_key=$(mktemp)
    if ! run "No se pudo descargar la clave de XanMod" wget -qO "$tmp_key" https://dl.xanmod.org/archive.key; then
        rm -f "$tmp_key"
        return 1
    fi
    sudo install -d -m 0755 /etc/apt/keyrings
    run "Clave de XanMod inválida" sudo gpg --dearmor --yes -o "$XANMOD_KEYRING" "$tmp_key"
    rm -f "$tmp_key"
    echo "deb [signed-by=$XANMOD_KEYRING] http://deb.xanmod.org $codename main" | sudo tee "$XANMOD_LIST" > /dev/null
    apt_update || return 1

    if ! apt-cache policy "$package" 2>/dev/null | grep -q 'Candidate: [0-9]'; then
        log_error "XanMod no tiene el paquete $package para esta versión de Ubuntu ($codename)"
        remove_kernel_family xanmod
        apt_update
        return 1
    fi

    echo -e "${BLUE}[2/5] Instalando kernel XanMod (puede tardar varios minutos)...${NC}"
    apt_install "$package" || return 1

    echo -e "${BLUE}[3/5] Eliminando Liquorix si existe...${NC}"
    remove_kernel_family liquorix

    echo -e "${BLUE}[4/5] Eliminando kernel Zen antiguo si existe...${NC}"
    local zen_pkgs
    mapfile -t zen_pkgs < <(installed_pkgs 'linux-*zen*')
    [ ${#zen_pkgs[@]} -gt 0 ] && apt_purge "${zen_pkgs[@]}"

    echo -e "${BLUE}[5/5] Configurando GRUB...${NC}"
    finish_custom_kernel xanmod "XanMod"
}

# Paquetes de la lista que tienen versión disponible en los repositorios
available_pkgs() {
    apt-cache policy "$@" 2>/dev/null | awk '/^[^ ]/ {p = $1; sub(/:$/, "", p)} /^  Candidate:/ && $2 != "(none)" {print p}'
}

# Versión del kernel a la que apunta un metapaquete instalado (p. ej. linux-image-generic)
meta_kernel_version() {
    dpkg-query -W -f='${Depends}' "$1" 2>/dev/null | grep -oE 'linux-image-(unsigned-)?[0-9][^ ,]*' | head -1 \
        | sed -E 's/^linux-image-(unsigned-)?//'
}

os_release_value() {
    # shellcheck disable=SC1091
    (. /etc/os-release && eval "echo \"\$$1\"")
}

# Borra todos los paquetes de una versión concreta del kernel oficial
purge_official_kernel_version() {
    local base="${1%-generic}" pkgs
    mapfile -t pkgs < <(installed_pkgs "linux-*-${base}" "linux-*-${base}-*")
    [ ${#pkgs[@]} -gt 0 ] && purge_kernel_pkgs "${pkgs[@]}"
}

# Muestra los kernels oficiales disponibles y deja la elección en OFFICIAL_VERSION
choose_specific_kernel_version() {
    local versions v i=0 mark choice running
    running=$(uname -r)
    mapfile -t versions < <(apt-cache pkgnames linux-image- 2>/dev/null \
        | grep -E '^linux-image-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$' \
        | sed 's/^linux-image-//' | sort -V | tail -15)
    if [ ${#versions[@]} -eq 0 ]; then
        log_error "No se encontraron versiones del kernel oficial en los repositorios"
        return 1
    fi

    echo -e "\n${BLUE}📋 Versiones disponibles (las 15 más recientes):${NC}\n"
    for v in "${versions[@]}"; do
        i=$((i + 1))
        mark=""
        [ -e "/boot/vmlinuz-$v" ] && mark=" ${GREEN}(instalado)${NC}"
        [ "$v" = "$running" ] && mark=" ${GREEN}(en uso)${NC}"
        echo -e "  ${BLUE}[$(printf '%2s' "$i")]${NC} $v$mark"
    done
    echo ""
    read -r -p "📌 Número de versión: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#versions[@]} ]; then
        log_error "Opción inválida"
        return 1
    fi
    OFFICIAL_VERSION="${versions[$((choice - 1))]}"
}

# Pregunta qué kernel oficial usar; deja el resultado en OFFICIAL_KIND (ga|hwe|specific)
choose_official_kernel() {
    local allow_specific="$1" release hwe_available=false option
    release=$(os_release_value VERSION_ID)
    [ -n "$(available_pkgs "linux-generic-hwe-$release")" ] && hwe_available=true

    echo -e "${BLUE}📋 ¿Qué kernel oficial quieres usar?${NC}\n"
    echo -e "  ${BLUE}1)${NC} LTS / GA (linux-generic): el kernel con el que salió Ubuntu $release, máxima estabilidad"
    if $hwe_available; then
        echo -e "  ${BLUE}2)${NC} HWE (linux-generic-hwe-$release): más reciente, mejor soporte para hardware nuevo"
    else
        echo -e "  ${BLUE}2)${NC} HWE ${YELLOW}(no disponible: solo existe en versiones LTS)${NC}"
    fi
    $allow_specific && echo -e "  ${BLUE}3)${NC} Versión específica (elegir de la lista)"
    echo ""
    read -r -p "📌 Opción: " option

    OFFICIAL_VERSION=""
    case $option in
        1) OFFICIAL_KIND="ga" ;;
        2)
            if ! $hwe_available; then
                log_error "El kernel HWE no está disponible en esta versión"
                return 1
            fi
            OFFICIAL_KIND="hwe" ;;
        3)
            $allow_specific || { log_error "Opción inválida"; return 1; }
            OFFICIAL_KIND="specific"
            choose_specific_kernel_version || return 1 ;;
        *) log_error "Opción inválida"; return 1 ;;
    esac
}

# Instala el kernel oficial elegido y elimina los de terceros. Devuelve 1 si falla.
switch_to_official_kernel() {
    local kind="$1" version="$2" release pkgs=() family v
    release=$(os_release_value VERSION_ID)
    KERNEL_PENDING_CLEANUP=false

    echo -e "\n${BLUE}[1/5] Instalando kernel oficial...${NC}"
    apt_update || return 1
    case $kind in
        ga) pkgs=(linux-generic) ;;
        hwe) pkgs=("linux-generic-hwe-$release") ;;
        specific)
            mapfile -t pkgs < <(available_pkgs "linux-image-$version" "linux-headers-$version" "linux-modules-extra-$version")
            if [ ${#pkgs[@]} -eq 0 ]; then
                log_error "La versión $version no está disponible"
                return 1
            fi ;;
    esac
    apt_install "${pkgs[@]}" || return 1

    case $kind in
        ga) version=$(meta_kernel_version linux-image-generic) ;;
        hwe) version=$(meta_kernel_version "linux-image-generic-hwe-$release") ;;
    esac
    if [ -z "$version" ] || [ ! -e "/boot/vmlinuz-$version" ]; then
        log_error "No se encontró el kernel oficial en /boot; no se eliminarán los demás kernels"
        return 1
    fi
    log_success "Kernel oficial disponible: $version"

    echo -e "${BLUE}[2/5] Eliminando kernels de terceros (Liquorix/XanMod)...${NC}"
    for family in "${CUSTOM_KERNELS[@]}"; do
        remove_kernel_family "$family" || return 1
    done

    echo -e "${BLUE}[3/5] Quitando la otra línea de kernel oficial (LTS/HWE)...${NC}"
    local metas=()
    case $kind in
        ga) mapfile -t metas < <(installed_pkgs 'linux-*generic-hwe-*') ;;
        hwe) mapfile -t metas < <(installed_pkgs linux-generic linux-image-generic linux-headers-generic) ;;
    esac
    [ ${#metas[@]} -gt 0 ] && apt_purge "${metas[@]}"
    if [ "$kind" != "specific" ]; then
        # Versiones de otra serie (p. ej. 6.14 de HWE si se eligió la 6.8 LTS)
        for v in $(kernel_versions generic); do
            [ "${v%%-*}" != "${version%%-*}" ] && purge_official_kernel_version "$v"
        done
    fi

    echo -e "${BLUE}[4/5] Limpiando kernels antiguos...${NC}"
    if confirm "${BLUE}¿Dejar SOLO el kernel $version y borrar las demás versiones oficiales?${NC}"; then
        for v in $(kernel_versions generic); do
            [ "$v" != "$version" ] && purge_official_kernel_version "$v"
        done
    fi
    run "Falló la limpieza de kernels antiguos" sudo env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
    apt_update

    echo -e "${BLUE}[5/5] Actualizando GRUB...${NC}"
    rm -f "$GRUB_TEMP_PIN_FILE"
    if [ "$kind" = "specific" ]; then
        boot_kernel_by_default "$version" || return 1
        echo -e "${YELLOW}ℹ Las actualizaciones pueden instalar kernels nuevos, pero GRUB seguirá arrancando $version${NC}"
    elif $KERNEL_PENDING_CLEANUP; then
        # El kernel anterior sigue instalado hasta reiniciar: fijar el elegido mientras tanto
        boot_kernel_by_default "$version" || return 1
        mkdir -p "$STATE_DIR"
        touch "$GRUB_TEMP_PIN_FILE"
    else
        set_grub_default 0
        run "Falló update-grub" sudo update-grub || return 1
    fi
    return 0
}

# Al iniciar el script: borra los kernels que no se pudieron quitar porque estaban en uso
cleanup_pending_kernels() {
    [ -s "$KERNEL_CLEANUP_FILE" ] || return 0
    local running pkgs
    running=$(uname -r)
    # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
    mapfile -t pkgs < <(installed_pkgs $(cat "$KERNEL_CLEANUP_FILE") | grep -vF -- "$running")
    if grep -qF -- "$running" "$KERNEL_CLEANUP_FILE"; then
        log_warning "Sigues usando un kernel marcado para eliminar ($running): reinicia y elige el nuevo"
        return 0
    fi
    if [ ${#pkgs[@]} -gt 0 ]; then
        echo -e "${YELLOW}🧹 Kernels anteriores pendientes de eliminar:${NC}"
        printf '  • %s\n' "${pkgs[@]}"
        confirm "${YELLOW}¿Eliminarlos ahora?${NC}" || return 0
        apt_purge "${pkgs[@]}" || return 1
    fi
    rm -f "$KERNEL_CLEANUP_FILE"
    if [ -f "$GRUB_TEMP_PIN_FILE" ]; then
        set_grub_default 0
        rm -f "$GRUB_TEMP_PIN_FILE"
    fi
    run "Falló update-grub" sudo update-grub && log_success "Kernels anteriores eliminados"
}

optimize_standard_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚙️ KERNEL OFICIAL UBUNTU                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    choose_official_kernel true || return 1
    switch_to_official_kernel "$OFFICIAL_KIND" "$OFFICIAL_VERSION" || return 1

    echo -e "${BLUE}🔧 Aplicando optimizaciones de rendimiento...${NC}"
    set_sysctl vm.swappiness 10
    set_sysctl vm.vfs_cache_pressure 50

    echo ""
    log_success "Kernel oficial de Ubuntu configurado"
    echo -e "${YELLOW}⚠ Reinicia el sistema para usar el nuevo kernel${NC}"
    echo -e "${BLUE}📋 Para verificar: uname -r${NC}"
}

install_standard_livepatch_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🛡️ KERNEL CON LIVEPATCH                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    if ! grep -q 'LTS' /etc/os-release; then
        log_warning "Livepatch solo funciona en versiones LTS de Ubuntu"
    fi
    if ! command -v snap &> /dev/null; then
        log_warning "Livepatch necesita Snap; reinstálalo con la opción 11 del menú principal"
    fi

    # Livepatch solo da soporte a los kernels oficiales LTS (GA) y HWE
    choose_official_kernel false || return 1
    switch_to_official_kernel "$OFFICIAL_KIND" || return 1

    echo -e "${BLUE}🔧 Instalando Ubuntu Pro client...${NC}"
    local pro_pkg="ubuntu-pro-client"
    apt-cache show "$pro_pkg" &> /dev/null || pro_pkg="ubuntu-advantage-tools"
    apt_install "$pro_pkg" || return 1

    set_sysctl vm.swappiness 10

    if command -v pro &> /dev/null; then
        echo -e "${YELLOW}📋 Para habilitar Livepatch, necesitas un token de Ubuntu Pro${NC}"
        echo -e "${BLUE}🔑 Obtén tu token gratuito en: https://ubuntu.com/pro/dashboard${NC}"
        if confirm "¿Tienes un token para habilitar Livepatch ahora?"; then
            local pro_token
            read -r -p "Ingresa tu token: " pro_token
            if [ -n "$pro_token" ]; then
                if run "No se pudo vincular Ubuntu Pro" sudo pro attach "$pro_token"; then
                    # 'pro attach' suele activar Livepatch por sí solo
                    if pro status 2>/dev/null | grep -Eq '^livepatch +yes +enabled' || \
                       run "No se pudo habilitar Livepatch" sudo pro enable livepatch; then
                        log_success "Livepatch habilitado correctamente"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Livepatch no habilitado. Configúralo después con: sudo pro attach [token]${NC}"
        fi
    fi

    echo ""
    log_success "Kernel oficial configurado"
    echo -e "${YELLOW}⚠ Reinicia el sistema para usar el nuevo kernel${NC}"
}

advanced_kernel_tweaks() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔧 AJUSTES AVANZADOS                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${YELLOW}⚠ ADVERTENCIA: Estos ajustes pueden afectar la seguridad${NC}\n"

    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=.*mitigations=off' /etc/default/grub; then
        echo -e "${YELLOW}ℹ Las mitigaciones de Spectre/Meltdown ya están deshabilitadas${NC}"
        if confirm "${BLUE}¿Volver a habilitarlas? (recomendado por seguridad)${NC}"; then
            sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/ *mitigations=off//' /etc/default/grub
            run "Falló update-grub" sudo update-grub && log_success "Mitigaciones habilitadas (requiere reinicio)"
        fi
    elif confirm "${BLUE}¿Deshabilitar mitigaciones de Spectre/Meltdown? (+rendimiento, riesgo alto)${NC}"; then
        sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 mitigations=off"/' /etc/default/grub
        run "Falló update-grub" sudo update-grub && log_success "Mitigaciones deshabilitadas (requiere reinicio)"
    fi

    if confirm "${BLUE}¿Habilitar TRIM automático para SSD?${NC}"; then
        run "No se pudo habilitar fstrim.timer" sudo systemctl enable --now fstrim.timer \
            && log_success "TRIM automático habilitado"
    fi

    echo -e "${GREEN}✓ Ajustes avanzados aplicados${NC}"
}

# ============================================================
# OPCIÓN 5: OPTIMIZACIÓN DE MEMORIA RAM (COLOR: AMARILLO)
# ============================================================

optimize_ram_menu() {
    clear
    echo -e "${YELLOW}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    💾 OPTIMIZACIÓN DE RAM                        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local total_ram
    total_ram=$(free -m | awk '/^Mem:/{printf "%.1f", $2/1024}')
    echo -e "\n${YELLOW}📊 RAM detectada: ${total_ram}GB${NC}"

    echo -e "\n${YELLOW}📋 Se aplicarán las siguientes optimizaciones:${NC}"
    echo -e "  • Configuración de swappiness óptima"
    echo -e "  • Gestión de caché mejorada"
    echo -e "  • Compresión ZRAM activa"
    echo ""

    if ! confirm "${YELLOW}¿Aplicar optimización completa de RAM?${NC}"; then
        return 0
    fi

    echo -e "${YELLOW}🔧 Configurando swappiness óptimo...${NC}"
    set_sysctl vm.swappiness 10

    echo -e "${YELLOW}🔧 Configurando presión de caché...${NC}"
    set_sysctl vm.vfs_cache_pressure 50

    if confirm "${YELLOW}¿Activar compresión ZRAM? (mejora rendimiento con poca RAM)${NC}"; then
        echo -e "${YELLOW}📦 Instalando ZRAM...${NC}"
        if apt_install zram-tools; then
            printf 'ALGO=zstd\nPERCENT=50\n' | sudo tee /etc/default/zramswap > /dev/null
            run "No se pudo reiniciar zramswap" sudo systemctl restart zramswap.service \
                && log_success "ZRAM configurado (50% de RAM como compresión)"
        fi
    fi

    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN DE RAM COMPLETADA!${NC}"
    pause
}

# ============================================================
# OPCIÓN 6: ACTUALIZACIÓN DEL SISTEMA (COLOR: VERDE)
# ============================================================

system_update() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔄 ACTUALIZAR SISTEMA                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${GREEN}📋 Se ejecutará:${NC}"
    echo -e "  • sudo apt update"
    echo -e "  • sudo apt upgrade -y"
    echo -e "  • sudo apt autoremove -y"
    echo -e "  • sudo apt autoclean -y"
    echo ""

    if ! confirm "${GREEN}¿Actualizar el sistema?${NC}"; then
        return 0
    fi

    echo ""
    echo -e "${GREEN}[1/4] Actualizando lista de paquetes...${NC}"
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"
    sudo apt update
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}✓ Lista de paquetes actualizada${NC}"

    echo ""
    echo -e "${GREEN}[2/4] Actualizando paquetes del sistema...${NC}"
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"
    sudo apt upgrade -y
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}✓ Paquetes actualizados${NC}"

    echo ""
    echo -e "${GREEN}[3/4] Eliminando paquetes huérfanos...${NC}"
    sudo apt autoremove -y
    echo -e "${GREEN}✓ Paquetes huérfanos eliminados${NC}"

    echo ""
    echo -e "${GREEN}[4/4] Limpiando caché de paquetes...${NC}"
    sudo apt autoclean -y
    echo -e "${GREEN}✓ Caché limpiado${NC}"

    echo ""
    echo -e "${GREEN}✓ ¡SISTEMA ACTUALIZADO COMPLETAMENTE!${NC}"
    pause
}

# ============================================================
# OPCIÓN 7: INSTALAR ALACRITTY Y TEMAS (COLOR: CIAN)
# ============================================================

install_custom_software() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🖥️ INSTALAR ALACRITTY                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${CYAN}✨ Alacritty es una terminal moderna que usa la GPU para renderizar${NC}\n"

    if confirm "${CYAN}¿Instalar Alacritty (terminal con aceleración GPU)?${NC}"; then
        echo -e "${CYAN}📦 Instalando Alacritty...${NC}"
        apt_update
        if ! apt_install alacritty; then
            pause
            return 1
        fi

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
        echo -e "${GREEN}✓ Alacritty instalado (usando GPU para renderizado)${NC}"
    fi

    if confirm "${CYAN}¿Instalar tema Tokyo Night?${NC}"; then
        echo -e "${CYAN}🎨 Instalando tema...${NC}"
        apt_install kpackagetool6 git

        local theme_dir
        theme_dir=$(mktemp -d)
        if run "No se pudo descargar el tema Tokyo Night" \
               git clone --depth 1 https://github.com/fausto-kouches/tokyo-night-kde "$theme_dir/tokyo-night-kde"; then
            if run "No se pudo instalar el tema" kpackagetool6 -t Plasma/LookAndFeel -i "$theme_dir/tokyo-night-kde" \
               || run "No se pudo actualizar el tema" kpackagetool6 -t Plasma/LookAndFeel -u "$theme_dir/tokyo-night-kde"; then
                run "No se pudo aplicar el tema" lookandfeeltool -a org.kde.tokyonight.desktop \
                    && log_success "Tema Tokyo Night instalado y aplicado"
            fi
        fi
        rm -rf "$theme_dir"
    fi

    pause
}

# ============================================================
# OPCIÓN 8: SOFTWARE OPCIONAL (COLOR: AZUL)
# ============================================================

select_optional_software() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    📦 SOFTWARE OPCIONAL                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local software=(
        "1|filezilla|📁 Cliente FTP/SFTP"
        "2|code|📝 Visual Studio Code"
        "3|virtualbox|🖥️ VirtualBox"
        "4|google-chrome-stable|🌐 Google Chrome"
        "5|telegram-desktop|📱 Telegram"
        "6|python3|🐍 Python 3"
        "7|python3-pip|📦 PIP"
        "8|python3-venv|📦 Entornos virtuales"
        "9|git|📚 Git"
        "10|curl|🌐 CURL"
        "11|wget|⬇️ Wget"
        "12|htop|📊 HTOP"
        "13|fastfetch|🖥️ Fastfetch"
        "14|timeshift|⏰ Timeshift"
        "15|gparted|💾 GParted"
        "16|vim|⌨️ Vim"
        "17|discord|🎮 Discord"
        "18|spotify|🎵 Spotify"
        "19|obs-studio|🎥 OBS Studio"
        "20|emojier|😊 Selector de emojis"
        "21|qrca|📱 Generador de códigos QR"
    )

    for app in "${software[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${BLUE}[%2s]${NC} %-20s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${BLUE}📝 Escribe los números separados por espacio${NC}"
    echo -e "${BLUE}Ejemplo: 2 4 13 20 21${NC}\n"
    read -r -p "🔢 Números a instalar: " input

    SELECTED_OPTIONAL=()
    if [ -n "$input" ]; then
        for num in $input; do
            for app in "${software[@]}"; do
                app_num=$(echo "$app" | cut -d'|' -f1)
                app_name=$(echo "$app" | cut -d'|' -f2)
                if [ "$app_num" = "$num" ]; then
                    SELECTED_OPTIONAL+=("$app_name")
                    echo -e "  ${GREEN}✓ Marcado: $app_name${NC}"
                fi
            done
        done
    fi

    if [ ${#SELECTED_OPTIONAL[@]} -gt 0 ]; then
        echo ""
        if confirm "${BLUE}¿Instalar los ${#SELECTED_OPTIONAL[@]} programas seleccionados?${NC}"; then
            install_optional_with_progress "${SELECTED_OPTIONAL[@]}"
        fi
    fi

    pause
}

# ============================================================
# FUNCIONES DE EJECUCIÓN
# ============================================================

remove_apps_with_progress() {
    local apps=("$@")
    local total=${#apps[@]}
    local current=0

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"

    for app in "${apps[@]}"; do
        current=$((current + 1))
        echo -e "${CYAN}[${current}/${total}]${NC} Eliminando: ${app}"

        if dpkg -l "$app" 2>/dev/null | grep -q "^ii"; then
            if ! purge_and_record "$app"; then
                continue
            fi
            echo -e "  ${GREEN}✓ Eliminado: $app${NC}"
        else
            echo -e "  ${YELLOW}⚠ No instalado: $app${NC}"
        fi
    done

    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}ℹ Para quitar los íconos del escritorio o del panel usa la opción 14${NC}"
    echo ""
}

# Descarga un .deb y lo instala resolviendo dependencias
install_deb_from_url() {
    local url="$1" deb
    deb=$(mktemp --suffix=.deb)
    run "No se pudo descargar $url" wget -qO "$deb" "$url" \
        && chmod 644 "$deb" && apt_install "$deb"
    local rc=$?
    rm -f "$deb"
    return $rc
}

install_optional_with_progress() {
    local apps=("$@")
    local failed=()

    echo -e "${BLUE}📦 Instalando software opcional...${NC}"
    apt_update

    for app in "${apps[@]}"; do
        echo -e "${BLUE}  → $app${NC}"
        case $app in
            "code") install_deb_from_url "https://go.microsoft.com/fwlink/?LinkID=760868" ;;
            "google-chrome-stable") install_deb_from_url "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" ;;
            "discord") install_deb_from_url "https://discord.com/api/download?platform=linux&format=deb" ;;
            "spotify")
                run "No se pudo descargar la clave de Spotify" \
                    bash -c "set -o pipefail; wget -qO- https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg" \
                    && echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null \
                    && apt_update && apt_install spotify-client ;;
            "emojier") apt_install kdeplasma-addons ;;
            *) apt_install "$app" ;;
        esac
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Instalado: $app${NC}"
        else
            failed+=("$app")
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        log_error "No se pudieron instalar: ${failed[*]}"
    fi
}

# ============================================================
# OPCIÓN 9: REVERTIR CAMBIOS (COLOR: ROJO)
# ============================================================

# Vuelve a las versiones de los repositorios oficiales los paquetes que vinieron
# de un PPA ya eliminado (quitar el PPA no baja las versiones por sí solo)
downgrade_orphaned_ppa_pkgs() {
    local targets=() line pkg inst cand
    # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
    while read -r line; do
        read -r pkg inst cand <<< "$line"
        dpkg --compare-versions "$inst" gt "$cand" && targets+=("$pkg=$cand")
    done < <(apt-cache policy $(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' | awk '$1 ~ /^.i/ {print $2}') 2>/dev/null \
        | awk '/^[^ ]/ {p = $1; sub(/:$/, "", p)}
               /^  Installed:/ {i = $2}
               /^  Candidate:/ && $2 != "(none)" && $2 != i {print p, i, $2}')

    if [ ${#targets[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓ No hay paquetes que bajar de versión${NC}"
        return 0
    fi
    echo -e "  ${RED}↓ Bajando ${#targets[@]} paquetes a la versión oficial (puede tardar)...${NC}"
    apt_install --allow-downgrades "${targets[@]}" && log_success "Paquetes de backports revertidos"
}

# Instala los paquetes que falten; si el lote falla, los intenta uno a uno
install_missing_pkgs() {
    local available=() missing=() failed=() p
    # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
    mapfile -t available < <(available_pkgs $(printf '%s\n' "$@" | sort -u) | sort -u)
    [ ${#available[@]} -gt 0 ] && mapfile -t missing < <(comm -23 \
        <(printf '%s\n' "${available[@]}") <(installed_pkgs "${available[@]}" | sort -u))

    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓ Todos los paquetes de Kubuntu ya están instalados${NC}"
        return 0
    fi
    echo -e "  ${RED}📦 Instalando ${#missing[@]} paquetes: ${missing[*]}${NC}"
    if apt_install "${missing[@]}"; then
        log_success "Paquetes reinstalados"
        return 0
    fi

    log_warning "Reintentando los paquetes uno a uno..."
    for p in "${missing[@]}"; do
        apt_install "$p" > /dev/null || failed+=("$p")
    done
    if [ ${#failed[@]} -gt 0 ]; then
        log_error "No se pudieron reinstalar: ${failed[*]}"
        return 1
    fi
    log_success "Paquetes reinstalados"
}

revert_changes() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ↩️ REVERTIR A KUBUNTU                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local removed_count=0
    [ -f "$REMOVED_LIST" ] && removed_count=$(wc -l < "$REMOVED_LIST")

    echo -e "\n${RED}📋 Esto hará:${NC}"
    echo -e "  • Quitar el PPA backports (Rolling Release) y volver Plasma a la versión oficial"
    echo -e "  • Desbloquear y reinstalar Snap"
    echo -e "  • Reinstalar kubuntu-desktop y todas sus aplicaciones"
    echo -e "  • Reinstalar los $removed_count paquetes eliminados con este script"
    echo -e "  • Restaurar los accesos directos del escritorio y del panel"
    echo ""

    if ! confirm "${RED}⚠ ¿Revertir a Kubuntu original?${NC}"; then
        return 0
    fi

    echo -e "${RED}[1/5] Eliminando Rolling Release...${NC}"
    if grep -rqs 'kubuntu-ppa/backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
        run "No se pudo quitar el PPA backports" sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports
        apt_update
        downgrade_orphaned_ppa_pkgs
    else
        echo -e "  ${GREEN}✓ El PPA backports no está activo${NC}"
        apt_update
    fi

    echo -e "${RED}[2/5] Desbloqueando Snap...${NC}"
    # La eliminación nuclear (opción 10) bloquea snapd; hay que desbloquearlo antes
    sudo apt-mark unhold snapd >> "$LOG_FILE" 2>&1
    sudo rm -f /etc/apt/preferences.d/nosnap.pref
    apt_update

    echo -e "${RED}[3/5] Reinstalando kubuntu-desktop y paquetes eliminados...${NC}"
    local pkgs=()
    mapfile -t pkgs < <(kubuntu_desktop_pkgs)
    pkgs+=(kubuntu-desktop snapd)
    [ -f "$REMOVED_LIST" ] && mapfile -t -O "${#pkgs[@]}" pkgs < "$REMOVED_LIST"
    if install_missing_pkgs "${pkgs[@]}"; then
        rm -f "$REMOVED_LIST"
    fi
    run "No se pudo iniciar snapd" sudo systemctl enable --now snapd.socket

    echo -e "${RED}[4/5] Restaurando accesos directos...${NC}"
    restore_desktop_shortcuts
    restore_panel_launchers

    echo -e "${RED}[5/5] Limpiando configuraciones...${NC}"
    rm -rf ~/.config/alacritty

    echo ""
    echo -e "${GREEN}✓ Sistema revertido${NC}"
    echo -e "${YELLOW}⚠ Reinicia para completar${NC}"
    pause
}

# ============================================================
# OPCIÓN 10: ELIMINACIÓN NUCLEAR DE SNAP (COLOR: ROJO)
# ============================================================

nuclear_snap_removal() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ☢️ ELIMINACIÓN NUCLEAR DE SNAP                ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${RED}${BOLD}⚠️ ⚠️ ⚠️  ADVERTENCIA  ⚠️ ⚠️ ⚠️${NC}"
    echo -e "${RED}Esta acción es IRREVERSIBLE y eliminará COMPLETAMENTE Snap${NC}\n"
    echo -e "${RED}📋 Lo que se eliminará:${NC}"
    echo -e "  • Todos los paquetes snap instalados"
    echo -e "  • El servicio snapd y su demonio"
    echo -e "  • Todos los directorios de Snap"
    echo -e "  • Configuraciones y cachés"
    echo ""

    if ! confirm "${RED}¿Estás ABSOLUTAMENTE seguro de eliminar Snap para siempre?${NC}"; then
        echo -e "${YELLOW}❌ Eliminación nuclear cancelada${NC}"
        pause
        return 1
    fi

    if ! confirm "${RED}ÚLTIMA ADVERTENCIA: ¿Confirmar eliminación TOTAL de Snap?${NC}"; then
        echo -e "${YELLOW}❌ Eliminación nuclear cancelada${NC}"
        pause
        return 1
    fi

    echo -e "${RED}☢️ Iniciando eliminación nuclear de Snap...${NC}\n"

    # Los snaps se eliminan mientras snapd sigue activo: sin el demonio 'snap remove' no funciona
    echo -e "${RED}[1/11] Eliminando paquetes snap de aplicaciones...${NC}"
    local snap_name
    for snap_name in $(snap list 2>/dev/null | awk 'NR>1 && $NF !~ /base|core|snapd/ {print $1}'); do
        run "No se pudo eliminar el snap $snap_name" sudo snap remove --purge "$snap_name"
    done

    echo -e "${RED}[2/11] Eliminando snaps del sistema (bases y runtimes)...${NC}"
    # Se repite porque unas bases dependen de otras (p. ej. gtk-common-themes → core)
    local _
    for _ in 1 2 3; do
        for snap_name in $(snap list 2>/dev/null | awk 'NR>1 && $1 != "snapd" {print $1}'); do
            sudo snap remove --purge "$snap_name" >> "$LOG_FILE" 2>&1
        done
    done
    sudo snap remove --purge snapd >> "$LOG_FILE" 2>&1

    echo -e "${RED}[3/11] Deteniendo servicios snap...${NC}"
    sudo systemctl stop snapd.socket snapd.service >> "$LOG_FILE" 2>&1
    sudo systemctl disable snapd.socket snapd.service >> "$LOG_FILE" 2>&1

    echo -e "${RED}[4/11] Terminando procesos snap...${NC}"
    sudo pkill -x snapd 2>/dev/null

    echo -e "${RED}[5/11] Desmontando directorios loop...${NC}"
    for mnt in $(mount | grep -E 'snap|/snap/' | awk '{print $3}'); do
        sudo umount "$mnt" 2>/dev/null
    done

    echo -e "${RED}[6/11] Eliminando paquetes snapd...${NC}"
    local snap_pkgs
    mapfile -t snap_pkgs < <(installed_pkgs snapd gnome-software-plugin-snap snapd-xdg-open plasma-discover-backend-snap)
    [ ${#snap_pkgs[@]} -gt 0 ] && purge_and_record "${snap_pkgs[@]}"
    run "Falló autoremove" sudo env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y

    echo -e "${RED}[7/11] Bloqueando reinstalación...${NC}"
    echo 'Package: snapd
Pin: release *
Pin-Priority: -1' | sudo tee /etc/apt/preferences.d/nosnap.pref > /dev/null

    echo -e "${RED}[8/11] Eliminando directorios de Snap...${NC}"
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null
    sudo rm -rf /etc/systemd/system/snapd.* 2>/dev/null

    echo -e "${RED}[9/11] Eliminando configuraciones de usuario...${NC}"
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            sudo rm -rf "$user_home/snap" "$user_home/.cache/snap" "$user_home/.config/snap" 2>/dev/null
        fi
    done
    sudo rm -rf ~/snap 2>/dev/null

    echo -e "${RED}[10/11] Eliminando binarios residuales...${NC}"
    sudo rm -rf /usr/bin/snap /usr/bin/snapctl /usr/lib/snapd 2>/dev/null

    echo -e "${RED}[11/11] Limpieza final...${NC}"
    run "Falló autoclean" sudo apt-get autoclean -y

    echo ""
    echo -e "${GREEN}✓ ¡ELIMINACIÓN NUCLEAR DE SNAP COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Snap ha sido borrado y bloqueado (la opción 11 permite reinstalarlo)${NC}"
    echo -e "${BLUE}📦 Para Firefox en .deb: sudo add-apt-repository ppa:mozillateam/ppa${NC}"
    echo -e "${BLUE}   ('apt install firefox' de Ubuntu solo instala el snap y fallará)${NC}"
    pause
}

# ============================================================
# OPCIÓN 11: REINSTALAR SNAP (COLOR: VERDE)
# ============================================================

reinstall_snap() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔄 REINSTALAR SNAP                            ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${YELLOW}⚠ Esta opción reinstalará Snap en el sistema${NC}\n"
    echo -e "${GREEN}📋 Lo que se reinstalará:${NC}"
    echo -e "  • snapd (servicio de Snap)"
    echo -e "  • ubuntu-advantage-tools (Ubuntu Pro)"
    echo -e "  • Directorios necesarios"
    echo ""

    if ! confirm "¿Reinstalar Snap?"; then
        return 0
    fi

    echo -e "${GREEN}🔄 Reinstalando Snap...${NC}\n"

    echo -e "${GREEN}[1/5] Eliminando bloqueos previos...${NC}"
    sudo apt-mark unhold snapd 2>/dev/null
    sudo rm -f /etc/apt/preferences.d/nosnap.pref 2>/dev/null

    echo -e "${GREEN}[2/5] Instalando snapd...${NC}"
    apt_update
    if ! apt_install snapd; then
        pause
        return 1
    fi

    echo -e "${GREEN}[3/5] Instalando Ubuntu Pro client...${NC}"
    apt_install ubuntu-advantage-tools

    echo -e "${GREEN}[4/5] Creando directorios necesarios...${NC}"
    sudo mkdir -p /snap /var/snap /var/lib/snapd

    echo -e "${GREEN}[5/5] Iniciando servicios...${NC}"
    run "No se pudo iniciar snapd" sudo systemctl enable --now snapd.socket snapd.service

    echo ""
    echo -e "${GREEN}✓ Snap reinstalado correctamente${NC}"
    echo -e "${BLUE}📦 Para instalar Firefox Snap: sudo snap install firefox${NC}"
    echo -e "${BLUE}🔑 Para Ubuntu Pro: sudo pro attach [token] (gratuito en ubuntu.com/pro/dashboard)${NC}"
    pause
}

# ============================================================
# OPCIÓN 12: REPARAR GRUB (COLOR: MAGENTA)
# ============================================================

grub_repair_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🔧 REPARACIÓN DE GRUB                         ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "\n${PURPLE}📋 Opciones disponibles:${NC}\n"
        echo -e "  ${PURPLE}1)${NC} 📊 DIAGNÓSTICO - Ver discos y particiones"
        echo -e "  ${PURPLE}2)${NC} 🔧 REPARACIÓN NORMAL - Reinstalar GRUB"
        echo -e "  ${PURPLE}3)${NC} 💿 INSTALAR GRUB EN DISCO - Disco específico"
        echo -e "  ${PURPLE}4)${NC} 🛡️ GUÍA PARA RESCUE - Solucionar 'grub rescue>'"
        echo -e "  ${PURPLE}5)${NC} ⬅️ Volver al menú principal"
        echo ""
        read -r -p "📌 Opcion (1-5): " grub_option

        case $grub_option in
            1) grub_diagnostic ;;
            2) grub_normal_repair ;;
            3) grub_reinstall_to_disk ;;
            4) grub_rescue_guide ;;
            5) return 0 ;;
            *) echo -e "${RED}❌ Opcion invalida${NC}"; sleep 1 ;;
        esac
    done
}

grub_diagnostic() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    📊 DIAGNOSTICO DEL SISTEMA                    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${PURPLE}[*] MODO DE ARRANQUE:${NC}"
    if [ -d /sys/firmware/efi ]; then
        echo -e "  ${GREEN}✓ UEFI (EFI) detectado${NC}"
    else
        echo -e "  ${GREEN}✓ BIOS (Legacy) detectado${NC}"
    fi

    echo -e "\n${PURPLE}[*] DISCOS DETECTADOS:${NC}"
    lsblk -d -o NAME,SIZE,MODEL 2>/dev/null | grep -v "loop" | head -10 | sed 's/^/  /'

    echo -e "\n${PURPLE}[*] PARTICIONES:${NC}"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v "loop" | sed 's/^/  /'

    echo -e "\n${PURPLE}[*] GRUB INSTALADO:${NC}"
    if command -v grub-install &> /dev/null; then
        echo -e "  ${GREEN}✓ $(grub-install --version | head -1)${NC}"
    else
        echo -e "  ${RED}✗ GRUB NO esta instalado${NC}"
    fi

    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_normal_repair() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔧 REPARACIÓN NORMAL DE GRUB                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    if ! confirm "${PURPLE}¿Reparar GRUB ahora?${NC}"; then
        return 0
    fi

    if [ -d /sys/firmware/efi ]; then
        echo -e "${PURPLE}🔄 Reparando GRUB en modo UEFI...${NC}"
        sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
    else
        local root_dev boot_disk
        root_dev=$(findmnt -no SOURCE /)
        # Sube por la jerarquía (LVM/LUKS/partición) hasta el disco físico
        boot_disk=$(lsblk -rnso NAME,TYPE "$root_dev" 2>/dev/null | awk '$2 == "disk" {print $1; exit}')
        if [ -z "$boot_disk" ]; then
            log_error "No se pudo detectar el disco del sistema; usa la opción 3"
            read -r
            return 1
        fi
        echo -e "${PURPLE}🔄 Reparando GRUB en modo BIOS (disco: /dev/$boot_disk)...${NC}"
        sudo grub-install --target=i386-pc "/dev/$boot_disk"
    fi

    echo -e "${PURPLE}🔄 Regenerando configuración...${NC}"
    sudo update-grub

    echo -e "${GREEN}✓ GRUB reparado correctamente${NC}"
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_reinstall_to_disk() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    💿 INSTALAR GRUB EN DISCO                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${PURPLE}[*] Discos disponibles:${NC}"
    lsblk -d -o NAME,SIZE,MODEL 2>/dev/null | grep -v "loop" | sed 's/^/  /'

    echo ""
    read -r -p "📌 Ingresa el disco (ej: /dev/sda): " target_disk

    if [ ! -b "$target_disk" ]; then
        echo -e "${RED}❌ Error: El disco $target_disk no existe${NC}"
        read -r
        return 1
    fi

    echo -e "\n${RED}⚠ Esto instalara GRUB en $target_disk${NC}"
    if ! confirm "${PURPLE}¿Confirmar?${NC}"; then
        return 0
    fi

    if [ -d /sys/firmware/efi ]; then
        echo -e "${PURPLE}🔄 Instalando GRUB en modo UEFI...${NC}"
        sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck "$target_disk"
    else
        echo -e "${PURPLE}🔄 Instalando GRUB en modo BIOS...${NC}"
        sudo grub-install --target=i386-pc "$target_disk"
    fi

    sudo update-grub
    echo -e "${GREEN}✓ GRUB instalado en $target_disk${NC}"
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_rescue_guide() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🛡️ GUÍA PARA GRUB RESCUE                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    cat << 'EOF'

══════════════════════════════════════════════════════════════════
🛡️ GUIA PARA SOLUCIONAR "grub rescue>"

Si al iniciar ves el mensaje "grub rescue>", sigue estos pasos:

PASO 1: IDENTIFICAR LAS PARTICIONES
  En el prompt "grub rescue>" escribe:
    ls

  Veras algo como: (hd0) (hd0,gpt1) (hd0,gpt2) (hd0,gpt3)

PASO 2: ENCONTRAR LA PARTICION DE LINUX
  Prueba cada particion con:
    ls (hd0,gpt2)/boot/grub

  La que muestre archivos (como normal.mod) es la correcta.

PASO 3: CARGAR GRUB NORMALMENTE
  Una vez identificada la particion (ej: hd0,gpt2), escribe:
    set prefix=(hd0,gpt2)/boot/grub
    insmod normal
    normal

PASO 4: UNA VEZ EN EL SISTEMA
  1. Bootea normalmente
  2. Ejecuta este script nuevamente
  3. Usa la opcion de reparación normal de GRUB

══════════════════════════════════════════════════════════════════
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

# ============================================================
# OPCIÓN 13: APAGAR O REINICIAR (COLOR: AMARILLO)
# ============================================================

shutdown_menu() {
    clear
    echo -e "${YELLOW}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔌 APAGAR / REINICIAR SISTEMA                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${YELLOW}📋 Opciones:${NC}\n"
    echo -e "  ${YELLOW}1)${NC} Apagar sistema ahora"
    echo -e "  ${YELLOW}2)${NC} Reiniciar sistema ahora"
    echo -e "  ${YELLOW}3)${NC} Cancelar"
    echo ""
    read -r -p "📌 Opción (1-3): " power_option

    case $power_option in
        1)
            echo -e "\n${RED}🔴 Apagando el sistema...${NC}"
            sudo shutdown -h now
            ;;
        2)
            echo -e "\n${GREEN}🟢 Reiniciando el sistema...${NC}"
            sudo reboot
            ;;
        3)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida${NC}"
            sleep 1
            ;;
    esac
}

# ============================================================
# OPCIÓN 14: QUITAR ACCESOS DIRECTOS (COLOR: CIAN)
# ============================================================

PLASMA_APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

# Carpeta del escritorio (en español suele ser ~/Escritorio, no ~/Desktop)
desktop_dir() {
    local dir
    dir=$(xdg-user-dir DESKTOP 2>/dev/null)
    if [ -z "$dir" ] || [ "$dir" = "$HOME" ] || [ ! -d "$dir" ]; then
        for dir in "$HOME/Escritorio" "$HOME/Desktop" ""; do
            [ -d "$dir" ] && break
        done
    fi
    echo "$dir"
}

# Plasma guarda su configuración al cerrarse: hay que pararlo antes de editarla
stop_plasmashell() {
    pgrep -x plasmashell > /dev/null || return 0
    kquitapp6 plasmashell >> "$LOG_FILE" 2>&1 || kquitapp5 plasmashell >> "$LOG_FILE" 2>&1
    local i
    for i in $(seq 20); do
        pgrep -x plasmashell > /dev/null || return 0
        sleep 0.5
    done
    pkill -x plasmashell
    sleep 1
}

start_plasmashell() {
    pgrep -x plasmashell > /dev/null && return 0
    if command -v kstart &> /dev/null; then
        kstart plasmashell >> "$LOG_FILE" 2>&1
    elif command -v kstart5 &> /dev/null; then
        kstart5 plasmashell >> "$LOG_FILE" 2>&1
    else
        setsid plasmashell >> "$LOG_FILE" 2>&1 < /dev/null &
    fi
}

# IDs "contenedor applet" de los gestores de tareas del panel
taskmanager_applets() {
    [ -f "$PLASMA_APPLETSRC" ] || return 0
    awk '
        /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ { g = $0; next }
        /^\[/ { g = "" }
        g != "" && /^plugin=org\.kde\.plasma\.(icontasks|taskmanager)$/ { gsub(/[^0-9]+/, " ", g); print g }
    ' "$PLASMA_APPLETSRC"
}

remove_desktop_shortcuts() {
    local dir items=() item i=0 input selected=() kind
    dir=$(desktop_dir)
    if [ -z "$dir" ]; then
        log_warning "No se encontró la carpeta del escritorio"
        return 1
    fi

    mapfile -t items < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' -printf '%f\n' | sort)
    if [ ${#items[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No hay accesos en $dir${NC}"
        echo -e "${YELLOW}  Si aún ves íconos, son widgets: clic derecho sobre ellos → Eliminar${NC}"
        return 0
    fi

    echo -e "${CYAN}📁 Contenido de $dir:${NC}\n"
    for item in "${items[@]}"; do
        i=$((i + 1))
        kind="archivo"
        [[ "$item" == *.desktop ]] && kind="acceso directo"
        [ -L "$dir/$item" ] && kind="enlace"
        [ -d "$dir/$item" ] && kind="carpeta"
        printf "  ${CYAN}[%2s]${NC} %-40s ${YELLOW}(%s)${NC}\n" "$i" "$item" "$kind"
    done
    echo -e "\n${CYAN}📝 Números separados por espacio, 't' = todos los accesos directos (.desktop y enlaces)${NC}"
    read -r -p "🔢 Quitar: " input

    if [ "$input" = "t" ] || [ "$input" = "T" ]; then
        for item in "${items[@]}"; do
            [[ "$item" == *.desktop ]] || [ -L "$dir/$item" ] && selected+=("$item")
        done
    else
        for i in $input; do
            [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le ${#items[@]} ] && selected+=("${items[$((i - 1))]}")
        done
    fi
    if [ ${#selected[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No seleccionaste nada${NC}"
        return 0
    fi

    # Se mueven a una copia de seguridad en lugar de borrarlos, para poder restaurarlos
    mkdir -p "$SHORTCUTS_BACKUP/escritorio"
    for item in "${selected[@]}"; do
        if run "No se pudo quitar $item" mv --backup=numbered "$dir/$item" "$SHORTCUTS_BACKUP/escritorio/"; then
            echo -e "  ${GREEN}✓ Quitado: $item${NC}"
        fi
    done
    echo -e "${CYAN}ℹ Guardados en $SHORTCUTS_BACKUP/escritorio (se restauran con 'Revertir')${NC}"
}

remove_panel_launchers() {
    local applets launchers kwrite
    mapfile -t applets < <(taskmanager_applets)
    if [ ${#applets[@]} -eq 0 ]; then
        log_warning "No se encontró la barra de tareas de Plasma en $PLASMA_APPLETSRC"
        return 1
    fi
    kwrite=$(command -v kwriteconfig6 || command -v kwriteconfig5)
    if [ -z "$kwrite" ]; then
        log_error "No se encontró kwriteconfig6/kwriteconfig5"
        return 1
    fi

    launchers=$(grep '^launchers=' "$PLASMA_APPLETSRC" | cut -d= -f2- | tr ',' '\n' | sed '/^$/d')
    echo -e "${CYAN}📌 Aplicaciones fijadas en el panel:${NC}"
    if [ -n "$launchers" ]; then
        sed 's/^/  • /' <<< "$launchers"
    else
        echo -e "  • (las predeterminadas de Plasma: Discover, Dolphin, navegador...)"
    fi
    echo ""
    confirm "${CYAN}¿Quitar todas las aplicaciones fijadas del panel?${NC}" || return 0

    mkdir -p "$SHORTCUTS_BACKUP"
    [ -f "$SHORTCUTS_BACKUP/panel-appletsrc" ] || cp "$PLASMA_APPLETSRC" "$SHORTCUTS_BACKUP/panel-appletsrc"

    echo -e "${CYAN}🔄 Reiniciando el escritorio (la pantalla parpadeará)...${NC}"
    stop_plasmashell
    local entry ids
    for entry in "${applets[@]}"; do
        read -r -a ids <<< "$entry"
        # Si la clave no existe, Plasma usa sus lanzadores por defecto: se escribe vacía
        "$kwrite" --file "$PLASMA_APPLETSRC" --group Containments --group "${ids[0]}" --group Applets \
            --group "${ids[1]}" --group Configuration --group General --key launchers ""
    done
    start_plasmashell
    log_success "Aplicaciones fijadas quitadas del panel"
}

restore_desktop_shortcuts() {
    local dir src="$SHORTCUTS_BACKUP/escritorio"
    dir=$(desktop_dir)
    [ -n "$dir" ] || dir="$HOME/Desktop"
    if [ -d "$src" ] && [ -n "$(ls -A "$src")" ]; then
        mkdir -p "$dir"
        run "No se pudieron restaurar los íconos del escritorio" mv -n "$src"/* "$dir/" \
            && log_success "Íconos del escritorio restaurados"
        rmdir "$src" 2>/dev/null
    else
        echo -e "  ${YELLOW}ℹ No hay íconos del escritorio guardados${NC}"
    fi
}

restore_panel_launchers() {
    local backup="$SHORTCUTS_BACKUP/panel-appletsrc"
    if [ ! -f "$backup" ]; then
        echo -e "  ${YELLOW}ℹ No hay copia del panel guardada${NC}"
        return 0
    fi
    stop_plasmashell
    if cp "$backup" "$PLASMA_APPLETSRC"; then
        rm -f "$backup"
        log_success "Panel restaurado"
    fi
    start_plasmashell
}

remove_shortcuts_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🧹 QUITAR ACCESOS DIRECTOS                    ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "\n${CYAN}📋 Opciones:${NC}\n"
        echo -e "  ${CYAN}1)${NC} Íconos del escritorio"
        echo -e "  ${CYAN}2)${NC} Aplicaciones fijadas en el panel (barra de tareas)"
        echo -e "  ${CYAN}3)${NC} Restaurar los accesos quitados"
        echo -e "  ${CYAN}4)${NC} Volver"
        echo ""
        read -r -p "📌 Opción (1-4): " shortcut_option

        case $shortcut_option in
            1) remove_desktop_shortcuts ;;
            2) remove_panel_launchers ;;
            3) restore_desktop_shortcuts; restore_panel_launchers ;;
            4) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# MENÚ PRINCIPAL (COLOR: CIAN)
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}📌 ¿Qué deseas hacer?${NC}\n"
        echo -e "  ${CYAN} 1)${NC} 🗑️  Eliminar aplicaciones preinstaladas"
        echo -e "  ${CYAN} 2)${NC} ⚙️  Configurar sistema (Rolling Release)"
        echo -e "  ${CYAN} 3)${NC} 🎮 Optimizar GPU (NVIDIA/AMD/Intel)"
        echo -e "  ${CYAN} 4)${NC} ⚡ Optimizar Kernel (Liquorix/XanMod/Estándar)"
        echo -e "  ${CYAN} 5)${NC} 💾 Optimizar Memoria RAM (automático)"
        echo -e "  ${CYAN} 6)${NC} 🔄 ACTUALIZAR SISTEMA (update/upgrade/clean)"
        echo -e "  ${CYAN} 7)${NC} 🖥️  Instalar Alacritty (terminal GPU) y temas"
        echo -e "  ${CYAN} 8)${NC} 📦 Instalar software opcional"
        echo -e "  ${CYAN} 9)${NC} ↩️  Revertir a Kubuntu original"
        echo -e "  ${CYAN}10)${NC} ☢️  ELIMINACION NUCLEAR DE SNAP"
        echo -e "  ${CYAN}11)${NC} 🔄 REINSTALAR SNAP"
        echo -e "  ${CYAN}12)${NC} 🔧 REPARAR GRUB (BIOS/EFI/Rescue)"
        echo -e "  ${CYAN}13)${NC} 🔌 Apagar / Reiniciar sistema"
        echo -e "  ${CYAN}14)${NC} 🧹 Quitar accesos directos (escritorio y panel)"
        echo -e "  ${CYAN}15)${NC} ❌ Salir"
        echo ""
        read -r -p "🔢 Opcion (1-15): " option

        case $option in
            1) select_apps_to_remove ;;
            2) configure_system ;;
            3) optimize_gpu_menu ;;
            4) optimize_kernel_menu ;;
            5) optimize_ram_menu ;;
            6) system_update ;;
            7) install_custom_software ;;
            8) select_optional_software ;;
            9) revert_changes ;;
            10) nuclear_snap_removal ;;
            11) reinstall_snap ;;
            12) grub_repair_menu ;;
            13) shutdown_menu ;;
            14) remove_shortcuts_menu ;;
            15)
                echo -e "\n${GREEN}✅ ¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opcion invalida${NC}"
                sleep 1
                ;;
        esac
    done
}

# ============================================================
# INICIO
# ============================================================

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ No ejecutes este script como root (no uses sudo)${NC}"
    exit 1
fi

echo "=== Kubuntu Lite Ultimate - $(date) ===" > "$LOG_FILE"

# Pide la contraseña una sola vez y la mantiene activa mientras corre el script
echo -e "${YELLOW}🔑 Se necesitan permisos de administrador${NC}"
if ! sudo -v; then
    echo -e "${RED}❌ No se pudo obtener sudo${NC}"
    exit 1
fi
while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done 2>/dev/null &

cleanup_pending_kernels

main_menu
