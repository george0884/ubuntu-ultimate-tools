#!/bin/bash

# ============================================================
# Script: Kubuntu Lite Ultimate
# Descripción: Transforma Kubuntu en un sistema minimalista
#              con optimizaciones de rendimiento extremo
# Versión: 7.0 - MENÚS UNIFORMES Y ESTÉTICA CUIDADA
# Autor: Old The One Deluxe (@george0884)
# Licencia: GNU GPL v3 o posterior (ver archivo LICENSE)
# SPDX-License-Identifier: GPL-3.0-or-later
# ============================================================

# ============================================================
# CONFIGURACIÓN INICIAL
# ============================================================

LOG_FILE="$HOME/kubuntu-lite.log"

# Estado guardado entre ejecuciones (lo usa "Revertir")
STATE_DIR="$HOME/.local/share/kubuntu-lite"
REMOVED_LIST="$STATE_DIR/paquetes-eliminados.txt"
INSTALLED_LIST="$STATE_DIR/paquetes-instalados.txt"
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

# Modo automático (perfiles): sin pausas ni preguntas; las confirmaciones responden "no"
AUTO_MODE=false
ASSUME_YES=false

clear() {
    $AUTO_MODE || command clear
}

pause() {
    $AUTO_MODE && return 0
    echo -e "\n${YELLOW}─────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}📌 Presiona Enter para continuar...${NC}"
    read -r
}

confirm() {
    local prompt="$1"
    local response
    if $AUTO_MODE; then
        echo -e "$prompt ${YELLOW}→ no (modo automático)${NC}"
        return 1
    fi
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

# Como 'run', pero mostrando la salida en pantalla (para operaciones largas)
run_visible() {
    local desc="$1"
    shift
    echo "[$(date '+%H:%M:%S')] \$ $*" >> "$LOG_FILE"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}
    if [ "$rc" -ne 0 ]; then
        log_error "$desc (código $rc). Detalles en: $LOG_FILE"
    fi
    return "$rc"
}

# Las salidas que el script interpreta se piden en inglés: con el sistema en español,
# apt-cache escribe "Candidato:" o "Depende:" en lugar de "Candidate:" o "Depends:",
# y free escribe "Mem.:" en lugar de "Mem:".
apt-cache() { LC_ALL=C command apt-cache "$@"; }
free() { LC_ALL=C command free "$@"; }

# Sin preguntas: ante un archivo de configuración modificado se conserva el del usuario
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
APT_LISTS_FRESH=false

# 'apt update' solo una vez por sesión (o si el sistema lo hizo hace menos de 30 min).
# Tras añadir o quitar un repositorio hay que llamarlo con "force".
apt_update() {
    if [ "$1" != "force" ]; then
        $APT_LISTS_FRESH && return 0
        if [ -n "$(find /var/lib/apt/periodic/update-success-stamp -mmin -30 2>/dev/null)" ]; then
            APT_LISTS_FRESH=true
            return 0
        fi
    fi
    run "Falló 'apt update'" sudo apt-get update || return 1
    APT_LISTS_FRESH=true
}
apt_install() { run "No se pudo instalar: $*" sudo env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_OPTS[@]}" "$@"; }
apt_purge() { run "No se pudo eliminar: $*" sudo env DEBIAN_FRONTEND=noninteractive apt-get purge "${APT_OPTS[@]}" "$@"; }

# Instala y anota en INSTALLED_LIST los paquetes que NO estaban instalados antes,
# para poder quitarlos después desde "Deshacer optimizaciones" (opción 18).
# Acepta nombres de paquete y rutas a archivos .deb.
apt_install_recorded() {
    local new=() arg name
    for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        name=$arg
        [[ "$arg" == *.deb ]] && name=$(dpkg-deb -f "$arg" Package 2>/dev/null)
        [ -n "$name" ] || continue
        installed_pkgs "$name" | grep -qx -- "$name" || new+=("$name")
    done
    apt_install "$@" || return 1
    if [ ${#new[@]} -gt 0 ]; then
        mkdir -p "$STATE_DIR"
        printf '%s\n' "${new[@]}" >> "$INSTALLED_LIST"
        sort -u -o "$INSTALLED_LIST" "$INSTALLED_LIST"
    fi
}

# Quita paquetes del registro de instalados
forget_installed() {
    [ -f "$INSTALLED_LIST" ] || return 0
    local p
    for p in "$@"; do
        sed -i "/^${p//./\\.}\$/d" "$INSTALLED_LIST"
    done
}

# Lista los paquetes instalados que coinciden con los patrones dados
installed_pkgs() {
    dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' "$@" 2>/dev/null | awk '$1 ~ /^.i/ {print $2}'
}

# Elimina paquetes y anota todo lo que apt quita (también dependencias) para poder revertir
purge_and_record() {
    local removed
    removed=$(LC_ALL=C apt-get -s purge "$@" 2>/dev/null | awk '/^(Purg|Remv) / {print $2}')
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

# Colores de alto contraste para whiptail: los de fábrica (azul y gris claro) se leen
# mal con muchos temas de Konsole. Se respeta NEWT_COLORS si el usuario ya lo definió.
WHIPTAIL_COLORS='
root=white,black
border=cyan,black
window=white,black
shadow=black,black
title=brightcyan,black
textbox=white,black
listbox=white,black
actlistbox=black,cyan
sellistbox=white,black
actsellistbox=black,cyan
checkbox=white,black
actcheckbox=black,cyan
button=white,blue
actbutton=black,cyan
compactbutton=white,black
helpline=white,black
roottext=white,black
'

# Lista con casillas: barra espaciadora para marcar, Enter para aceptar.
# Entradas "paquete|descripción"; deja lo elegido en CHOSEN. Devuelve 1 si se cancela.
# Si no hay whiptail (o no es una terminal interactiva) se elige escribiendo números.
checklist_select() {
    local title="$1" text="$2"
    shift 2
    local entries=("$@") args=() entry name desc i=0 input num
    CHOSEN=()

    if command -v whiptail &> /dev/null && [ -t 0 ] && [ -t 1 ]; then
        for entry in "${entries[@]}"; do
            name=${entry%%|*}
            desc=${entry#*|}
            # Sin el emoji inicial: whiptail calcula mal su ancho y descuadra la lista
            [[ "$desc" == *" "* ]] && [[ "${desc%% *}" != *[[:alnum:]]* ]] && desc=${desc#* }
            args+=("$name" "$desc" OFF)
        done
        local h w lh max_h out
        # Alto justo para la lista (sin hueco vacío), limitado al tamaño de la terminal
        max_h=$(( $(tput lines 2>/dev/null || echo 24) - 2 ))
        [ "$max_h" -lt 15 ] && max_h=15
        lh=${#entries[@]}
        [ "$lh" -gt $((max_h - 10)) ] && lh=$((max_h - 10))
        h=$((lh + 10))
        w=$(( $(tput cols 2>/dev/null || echo 80) - 4 ))
        [ "$w" -gt 90 ] && w=90
        out=$(NEWT_COLORS="${NEWT_COLORS:-$WHIPTAIL_COLORS}" \
            whiptail --title "$title" --ok-button "Aceptar" --cancel-button "Cancelar" \
            --checklist "$text\n\nEspacio: marcar/desmarcar · Flechas: moverse · Enter: aceptar" \
            "$h" "$w" "$lh" "${args[@]}" 3>&1 1>&2 2>&3) || return 1
        read -r -a CHOSEN <<< "$(tr -d '"' <<< "$out")"
        return 0
    fi

    echo -e "${CYAN}$text${NC}\n"
    for entry in "${entries[@]}"; do
        i=$((i + 1))
        printf "  ${CYAN}[%2s]${NC} %-22s - %s\n" "$i" "${entry%%|*}" "${entry#*|}"
    done
    echo ""
    read -r -p "🔢 Números separados por espacio: " input
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#entries[@]} ]; then
            CHOSEN+=("${entries[$((num - 1))]%%|*}")
        fi
    done
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

    local apps=(
        "akregator|📰 Lector RSS y feeds"
        "cantata|🎵 Cliente de música MPD"
        "dragonplayer|🎬 Reproductor de video"
        "juk|🎵 Reproductor de audio"
        "k3b|💿 Grabador de CDs y DVDs"
        "kaddressbook|📇 Agenda de contactos"
        "kalarm|⏰ Alarmas y recordatorios"
        "kate|📝 Editor de texto avanzado"
        "kmag|🔍 Lupa de pantalla"
        "kmail|📧 Cliente de correo electrónico"
        "kmahjongg|🀄 Juego de Mahjongg"
        "kmines|💣 Juego de buscaminas"
        "knotes|📋 Notas adhesivas"
        "konsole|💻 Terminal"
        "kontact|📅 Suite PIM completa"
        "konversation|💬 Cliente IRC"
        "korganizer|📆 Calendario"
        "kpat|🃏 Juego de cartas solitario"
        "krdc|🖥️ Cliente de escritorio remoto"
        "kruler|📏 Regla en pantalla"
        "ksudoku|🔢 Juego de Sudoku"
        "ktorrent|📥 Cliente Torrent"
        "libreoffice-core|📄 Suite ofimática"
        "skanlite|🖨️ Escáner"
        "kmouth|🗣️ Sintetizador de voz"
        "kcharselect|🔣 Mapa de caracteres"
        "kdf|💾 Visor de uso de disco"
        "kfind|🔎 Buscador de archivos"
        "kgpg|🔐 Gestión de claves GPG"
        "kamoso|📷 Cámara web"
        "kdeconnect|📱 Sincronización con móvil"
        "kdenlive|🎬 Editor de video"
        "khelpcenter|❓ Centro de ayuda"
        "kio-extras|🔌 Protocolos extra KIO"
        "kmix|🔊 Control de volumen"
        "kolourpaint|🎨 Pintura simple"
        "kompare|📊 Comparador de archivos"
        "kremotecontrol|🎮 Control remoto"
        "kscreen|🖥️ Configuración de pantallas"
        "ksystemlog|📋 Visor de logs del sistema"
        "kteatime|🍵 Temporizador para té"
        "ktimer|⏱️ Temporizador"
        "kwalletmanager|👛 Gestión de contraseñas"
        "okular|📖 Visor de PDF/DjVu"
        "spectacle|📸 Capturas de pantalla"
        "gwenview|🖼️ Visor de imágenes"
        "mpv|🎬 Reproductor multimedia ligero"
        "remmina|🖥️ Cliente de escritorio remoto"
        "plasma-discover|🛒 Tienda de aplicaciones"
        "plasma-welcome|👋 Guía de bienvenida"
        "kubuntu-docs|📚 Documentación de Kubuntu"
        "kubuntu-web-shortcuts|🌐 Accesos web de Kubuntu"
        "qml-module-org-kde-kirigami2|🎨 Componentes Kirigami"
        "qml-module-qtquick-controls2|🎛️ Controles QtQuick"
    )

    # Solo se ofrecen las que están instaladas
    local installed=() entries=() app
    mapfile -t installed < <(installed_pkgs "${apps[@]%%|*}")
    for app in "${apps[@]}"; do
        printf '%s\n' "${installed[@]}" | grep -qx -- "${app%%|*}" && entries+=("$app")
    done
    if [ ${#entries[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ Ninguna de estas aplicaciones está instalada${NC}"
        pause
        return 0
    fi

    SELECTED_APPS=()
    if checklist_select "Eliminar aplicaciones" "Marca las aplicaciones que quieres ELIMINAR (${#entries[@]} instaladas)" "${entries[@]}"; then
        SELECTED_APPS=("${CHOSEN[@]}")
    fi
    clear

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

remove_kubuntu_meta() {
    if ! installed_pkgs kubuntu-desktop | grep -qx kubuntu-desktop; then
        echo -e "  ${YELLOW}ℹ kubuntu-desktop ya no está instalado${NC}"
        return 0
    fi
    # Sin el meta-paquete, sus apps quedan "huérfanas" y 'apt autoremove' (opción 6)
    # las borraría. Se marcan como instaladas manualmente para conservarlas.
    local kd_pkgs
    # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
    mapfile -t kd_pkgs < <(installed_pkgs $(kubuntu_desktop_pkgs))
    [ ${#kd_pkgs[@]} -gt 0 ] && run "No se pudieron proteger las apps de Kubuntu" sudo apt-mark manual "${kd_pkgs[@]}"
    purge_and_record kubuntu-desktop && log_success "Se eliminó kubuntu-desktop (las apps se conservan)"
}

enable_backports() {
    if grep -rqs 'kubuntu-ppa/backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
        echo -e "  ${GREEN}✓ KDE Rolling Release (backports) ya está activo${NC}"
        return 0
    fi
    run "No se pudo agregar ppa:kubuntu-ppa/backports" sudo add-apt-repository -y ppa:kubuntu-ppa/backports \
        && apt_update force && log_success "Se cambió a KDE Rolling Release (actualiza el sistema para aplicarlo)"
}

# man-db reindexa los manuales tras cada instalación: es lo más lento de apt/dpkg
disable_mandb() {
    echo "man-db man-db/auto-update boolean false" | sudo debconf-set-selections
    sudo rm -f /var/lib/man-db/auto-update
    log_success "Indexación de manuales desactivada (apt será más rápido)"
}

enable_mandb() {
    echo "man-db man-db/auto-update boolean true" | sudo debconf-set-selections
    sudo touch /var/lib/man-db/auto-update
    log_success "Indexación de manuales activada"
}

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
        remove_kubuntu_meta
    else
        echo -e "${YELLOW}ℹ Se mantiene kubuntu-desktop${NC}"
    fi

    echo ""
    echo -e "${GREEN}2. Cambio a KDE Rolling Release${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Cambia los repositorios a versión Rolling Release"
    echo -e "   ${GREEN}✓ Beneficio:${NC} Te dará las últimas versiones de KDE Plasma"
    echo ""
    if confirm "${GREEN}¿Cambiar a KDE Rolling Release? (recomendado)${NC}"; then
        enable_backports
    else
        echo -e "${YELLOW}ℹ Se mantienen repositorios estándar${NC}"
    fi

    echo ""
    echo -e "${GREEN}3. Indexación de manuales (man-db)${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Tras cada instalación se reindexan los manuales de terminal"
    echo -e "   ${GREEN}✓ Si la desactivas:${NC} Instalar y desinstalar es bastante más rápido"
    echo ""
    if [ ! -e /var/lib/man-db/auto-update ]; then
        echo -e "${GREEN}✓ Ya está desactivada${NC}"
        if confirm "${GREEN}¿Volver a activarla?${NC}"; then
            enable_mandb
        fi
    elif confirm "${GREEN}¿Desactivar la indexación de manuales? (recomendado)${NC}"; then
        disable_mandb
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
        install_recommended_drivers || return 1
    else
        echo -e "${PURPLE}🔧 Activando modo persistente del driver...${NC}"
        run "No se pudo activar el modo persistente" sudo nvidia-smi -pm 1
    fi

    if confirm "${PURPLE}¿Instalar CUDA Toolkit? (varios GB, solo para desarrollo/IA)${NC}"; then
        echo -e "${PURPLE}📦 Instalando CUDA Toolkit...${NC}"
        apt_install_recorded nvidia-cuda-toolkit && log_success "CUDA Toolkit instalado"
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
    apt_install_recorded corectrl

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

# Elige el kernel que GRUB arranca por defecto: "0" (el más reciente) o una versión.
# Con GRUB_DEFAULT=saved basta 'grub-set-default': no hace falta regenerar grub.cfg
# (update-grub tarda bastante, sobre todo con os-prober). La instalación y
# eliminación de kernels ya regenera grub.cfg por su cuenta.
# Identificador (o, si no lo tiene, el título) de una línea menuentry/submenu de grub.cfg
grub_line_id() {
    local id
    id=$(grep -oP "\\\$menuentry_id_option '\K[^']+" <<< "$1")
    [ -z "$id" ] && id=$(grep -oP "^\s*(menuentry|submenu) ['\"]\K[^'\"]+" <<< "$1")
    echo "$id"
}

# Ruta para grub-set-default de la entrada del kernel indicado: "submenú>entrada" o
# solo "entrada" si no está en un submenú (GRUB_DISABLE_SUBMENU, grub-customizer...)
grub_entry_path() {
    local target="$1" cfg="$2" found=() sub_id entry_id
    mapfile -t found < <(sudo awk -v t="$target" '
        /^submenu / { s = $0; next }
        /^}/ { s = ""; next }
        /menuentry / && index($0, t) && tolower($0) !~ /recovery|recuperaci/ { print s; print $0; exit }
    ' "$cfg")
    [ ${#found[@]} -eq 2 ] || return 1
    entry_id=$(grub_line_id "${found[1]}")
    [ -n "$entry_id" ] || return 1
    if [ -n "${found[0]}" ]; then
        sub_id=$(grub_line_id "${found[0]}")
        [ -n "$sub_id" ] || return 1
        echo "${sub_id}>${entry_id}"
    else
        echo "$entry_id"
    fi
}

# Pasa GRUB a GRUB_DEFAULT=saved (una sola vez). Devuelve 2 si tuvo que regenerar grub.cfg.
ensure_grub_saved() {
    grep -Eq '^GRUB_DEFAULT="?saved"?$' /etc/default/grub && return 0
    set_grub_default saved
    run "Falló update-grub" sudo update-grub || return 1
    return 2
}

grub_select() {
    local target="$1" cfg="/boot/grub/grub.cfg" regenerated=false _ rc
    ensure_grub_saved
    rc=$?
    [ "$rc" -eq 1 ] && return 1
    [ "$rc" -eq 2 ] && regenerated=true

    if [ "$target" = "0" ]; then
        run "No se pudo fijar el kernel por defecto" sudo grub-set-default 0
        return
    fi

    local path=""
    for _ in 1 2; do
        path=$(grub_entry_path "$target" "$cfg") && break
        $regenerated && break
        run "Falló update-grub" sudo update-grub || return 1
        regenerated=true
    done

    if [ -n "$path" ]; then
        run "No se pudo fijar el kernel por defecto" sudo grub-set-default "$path" \
            && log_success "GRUB arrancará por defecto: $target"
    else
        log_warning "No se encontró $target en GRUB; se arrancará el kernel más reciente"
        run "No se pudo fijar el kernel por defecto" sudo grub-set-default 0
    fi
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

    grub_select "$version"

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
    apt_update force || return 1

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
    apt_update force || return 1

    if ! apt-cache policy "$package" 2>/dev/null | grep -q 'Candidate: [0-9]'; then
        log_error "XanMod no tiene el paquete $package para esta versión de Ubuntu ($codename)"
        remove_kernel_family xanmod
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
    run "Falló la limpieza de kernels antiguos" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge

    echo -e "${BLUE}[5/5] Configurando GRUB...${NC}"
    rm -f "$GRUB_TEMP_PIN_FILE"
    if [ "$kind" = "specific" ]; then
        grub_select "$version" || return 1
        echo -e "${YELLOW}ℹ Las actualizaciones pueden instalar kernels nuevos, pero GRUB seguirá arrancando $version${NC}"
    elif $KERNEL_PENDING_CLEANUP; then
        # El kernel anterior sigue instalado hasta reiniciar: fijar el elegido mientras tanto
        grub_select "$version" || return 1
        mkdir -p "$STATE_DIR"
        touch "$GRUB_TEMP_PIN_FILE"
    else
        grub_select 0 || return 1
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
        grub_select 0
        rm -f "$GRUB_TEMP_PIN_FILE"
    fi
    log_success "Kernels anteriores eliminados"
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

enable_trim() {
    run "No se pudo habilitar fstrim.timer" sudo systemctl enable --now fstrim.timer \
        && log_success "TRIM automático semanal habilitado"
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
        enable_trim
    fi

    echo -e "${GREEN}✓ Ajustes avanzados aplicados${NC}"
}

# ============================================================
# OPCIÓN 5: OPTIMIZACIÓN DE MEMORIA RAM (COLOR: AMARILLO)
# ============================================================

apply_ram_tweaks() {
    echo -e "${YELLOW}🔧 Configurando swappiness y presión de caché...${NC}"
    set_sysctl vm.swappiness 10
    set_sysctl vm.vfs_cache_pressure 50
    log_success "Memoria optimizada (swappiness=10, vfs_cache_pressure=50)"
}

enable_zram() {
    echo -e "${YELLOW}📦 Configurando ZRAM...${NC}"
    apt_update
    apt_install_recorded zram-tools || return 1
    printf 'ALGO=zstd\nPERCENT=50\n' | sudo tee /etc/default/zramswap > /dev/null
    run "No se pudo reiniciar zramswap" sudo systemctl restart zramswap.service \
        && log_success "ZRAM configurado (50% de RAM como compresión)"
}

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

    apply_ram_tweaks

    if confirm "${YELLOW}¿Activar compresión ZRAM? (mejora rendimiento con poca RAM)${NC}"; then
        enable_zram
    fi

    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN DE RAM COMPLETADA!${NC}"
    pause
}

# ============================================================
# OPCIÓN 6: ACTUALIZACIÓN DEL SISTEMA (COLOR: VERDE)
# ============================================================

do_system_update() {
    echo -e "${GREEN}[1/4] Actualizando lista de paquetes...${NC}"
    run_visible "Falló 'apt update'" sudo apt-get update || return 1
    APT_LISTS_FRESH=true

    echo -e "${GREEN}[2/4] Actualizando paquetes del sistema...${NC}"
    run_visible "Falló la actualización" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" full-upgrade || return 1

    echo -e "${GREEN}[3/4] Eliminando paquetes huérfanos...${NC}"
    run "Falló autoremove" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge

    echo -e "${GREEN}[4/4] Limpiando caché de paquetes...${NC}"
    run "Falló autoclean" sudo apt-get autoclean -y
    log_success "Sistema actualizado"
}

system_update() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔄 ACTUALIZAR SISTEMA                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${GREEN}📋 Se ejecutará:${NC}"
    echo -e "  • sudo apt update"
    echo -e "  • sudo apt full-upgrade -y"
    echo -e "  • sudo apt autoremove -y"
    echo -e "  • sudo apt autoclean -y"
    echo ""

    if ! confirm "${GREEN}¿Actualizar el sistema?${NC}"; then
        return 0
    fi

    do_system_update
    echo ""
    echo -e "${GREEN}✓ ¡SISTEMA ACTUALIZADO COMPLETAMENTE!${NC}"
    pause
}

# ============================================================
# OPCIÓN 7: INSTALAR ALACRITTY Y TEMAS (COLOR: CIAN)
# ============================================================

# ------------------------------------------------------------
# Tema Tokyo Night (incluido en el script: no depende de descargas)
# ------------------------------------------------------------

# Un grupo de colores de KDE: $1 nombre, $2 fondo, $3 fondo alterno, $4 texto
tokyo_color_group() {
    cat << EOF
[Colors:$1]
BackgroundAlternate=$3
BackgroundNormal=$2
DecorationFocus=122,162,247
DecorationHover=125,207,255
ForegroundActive=255,158,100
ForegroundInactive=86,95,137
ForegroundLink=122,162,247
ForegroundNegative=247,118,142
ForegroundNeutral=224,175,104
ForegroundNormal=$4
ForegroundPositive=158,206,106
ForegroundVisited=187,154,247

EOF
}

write_tokyo_night_colors() {
    local file="$HOME/.local/share/color-schemes/TokyoNight.colors"
    mkdir -p "$(dirname "$file")"
    {
        tokyo_color_group View "26,27,38" "31,35,53" "192,202,245"
        tokyo_color_group Window "22,22,30" "26,27,38" "192,202,245"
        tokyo_color_group Button "41,46,66" "31,35,53" "192,202,245"
        tokyo_color_group Selection "61,89,161" "41,46,66" "192,202,245"
        tokyo_color_group Tooltip "22,22,30" "26,27,38" "192,202,245"
        tokyo_color_group Complementary "22,22,30" "26,27,38" "192,202,245"
        tokyo_color_group Header "22,22,30" "26,27,38" "192,202,245"
        cat << 'EOF'
[General]
ColorScheme=TokyoNight
Name=Tokyo Night
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=22,22,30
activeBlend=192,202,245
activeForeground=192,202,245
inactiveBackground=22,22,30
inactiveBlend=86,95,137
inactiveForeground=86,95,137
EOF
    } > "$file"
}

write_tokyo_night_konsole() {
    local dir="$HOME/.local/share/konsole"
    mkdir -p "$dir"
    # Colores 0-7 normales y su versión intensa (negro, rojo, verde, amarillo, azul, magenta, cian, blanco)
    local normal=("21,22,30" "247,118,142" "158,206,106" "224,175,104" "122,162,247" "187,154,247" "125,207,255" "169,177,214")
    local bright=("65,72,104" "247,118,142" "158,206,106" "224,175,104" "122,162,247" "187,154,247" "125,207,255" "192,202,245")
    local i
    {
        printf '[Background]\nColor=26,27,38\n\n[BackgroundIntense]\nColor=26,27,38\n\n'
        printf '[Foreground]\nColor=192,202,245\n\n[ForegroundIntense]\nColor=192,202,245\n\n'
        for i in 0 1 2 3 4 5 6 7; do
            printf '[Color%s]\nColor=%s\n\n[Color%sIntense]\nColor=%s\n\n' "$i" "${normal[$i]}" "$i" "${bright[$i]}"
        done
        printf '[General]\nDescription=Tokyo Night\nOpacity=1\n'
    } > "$dir/TokyoNight.colorscheme"

    printf '[Appearance]\nColorScheme=TokyoNight\n\n[General]\nName=Tokyo Night\nParent=FALLBACK/\n' \
        > "$dir/TokyoNight.profile"
}

install_tokyo_night_theme() {
    echo -e "${CYAN}🎨 Aplicando tema Tokyo Night...${NC}"
    write_tokyo_night_colors
    write_tokyo_night_konsole

    if command -v plasma-apply-colorscheme &> /dev/null; then
        run "No se pudo aplicar el esquema de colores (¿estás en una sesión de Plasma?)" \
            plasma-apply-colorscheme TokyoNight \
            && log_success "Colores Tokyo Night aplicados a Plasma"
    else
        log_warning "Aplica los colores a mano: Preferencias del sistema → Colores → Tokyo Night"
    fi

    # Konsole: perfil Tokyo Night como predeterminado (si ya usas otro, se pregunta)
    local kwrite current
    kwrite=$(command -v kwriteconfig6 || command -v kwriteconfig5)
    current=$(sed -n 's/^DefaultProfile=//p' "$HOME/.config/konsolerc" 2>/dev/null)
    if [ -n "$kwrite" ] && { [ -z "$current" ] || [ "$current" = "TokyoNight.profile" ] \
        || confirm "${CYAN}Konsole usa el perfil '$current'. ¿Cambiarlo por Tokyo Night?${NC}"; }; then
        "$kwrite" --file konsolerc --group "Desktop Entry" --key DefaultProfile TokyoNight.profile \
            && log_success "Konsole usará Tokyo Night en las ventanas nuevas"
    else
        echo -e "${CYAN}ℹ En Konsole: Configuración → Gestionar perfiles → Tokyo Night${NC}"
    fi
    echo -e "${CYAN}ℹ Para volver a los colores originales: Preferencias del sistema → Colores → Breeze${NC}"
}

install_custom_software() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🖥️ ALACRITTY Y TEMA TOKYO NIGHT               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${CYAN}✨ Alacritty es una terminal moderna que usa la GPU para renderizar${NC}\n"

    if confirm "${CYAN}¿Instalar Alacritty (terminal con aceleración GPU)?${NC}"; then
        echo -e "${CYAN}📦 Instalando Alacritty...${NC}"
        apt_update
        if ! apt_install_recorded alacritty; then
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

    if confirm "${CYAN}¿Aplicar tema Tokyo Night a Plasma y Konsole?${NC}"; then
        install_tokyo_night_theme
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
        "filezilla|📁 Cliente FTP/SFTP"
        "code|📝 Visual Studio Code"
        "virtualbox|🖥️ VirtualBox"
        "google-chrome-stable|🌐 Google Chrome"
        "telegram-desktop|📱 Telegram"
        "python3|🐍 Python 3"
        "python3-pip|📦 PIP"
        "python3-venv|📦 Entornos virtuales"
        "git|📚 Git"
        "curl|🌐 CURL"
        "wget|⬇️ Wget"
        "htop|📊 HTOP"
        "fastfetch|🖥️ Fastfetch"
        "timeshift|⏰ Timeshift"
        "gparted|💾 GParted"
        "vim|⌨️ Vim"
        "discord|🎮 Discord"
        "spotify|🎵 Spotify"
        "obs-studio|🎥 OBS Studio"
        "emojier|😊 Selector de emojis"
        "qrca|📱 Generador de códigos QR"
    )

    # Se marca lo que ya está instalado para no reinstalarlo por error
    local installed=() entries=() app pkg
    mapfile -t installed < <(installed_pkgs "${software[@]%%|*}" spotify-client kdeplasma-addons)
    for app in "${software[@]}"; do
        pkg=${app%%|*}
        case $pkg in
            spotify) pkg=spotify-client ;;
            emojier) pkg=kdeplasma-addons ;;
        esac
        if printf '%s\n' "${installed[@]}" | grep -qx -- "$pkg"; then
            entries+=("${app} (ya instalado)")
        else
            entries+=("$app")
        fi
    done

    SELECTED_OPTIONAL=()
    if checklist_select "Software opcional" "Marca los programas que quieres INSTALAR" "${entries[@]}"; then
        SELECTED_OPTIONAL=("${CHOSEN[@]}")
    fi
    clear

    if [ ${#SELECTED_OPTIONAL[@]} -gt 0 ]; then
        echo -e "${BLUE}📋 Se instalarán:${NC}"
        printf "  ${BLUE}•${NC} %s\n" "${SELECTED_OPTIONAL[@]}"
        echo ""
    else
        echo -e "${YELLOW}ℹ No seleccionaste ningún programa${NC}"
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

# Elimina todas las apps en una sola operación de apt (mucho más rápido que una a una:
# dpkg ejecuta sus tareas posteriores una sola vez). Si falla, reintenta de a una.
remove_apps_with_progress() {
    local installed=() app

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    mapfile -t installed < <(installed_pkgs "$@")
    for app in "$@"; do
        printf '%s\n' "${installed[@]}" | grep -qx -- "$app" || echo -e "  ${YELLOW}⚠ No instalado: $app${NC}"
    done

    if [ ${#installed[@]} -gt 0 ]; then
        echo -e "${CYAN}🗑 Eliminando ${#installed[@]} aplicaciones en una sola operación...${NC}"
        if purge_and_record "${installed[@]}"; then
            for app in "${installed[@]}"; do
                echo -e "  ${GREEN}✓ Eliminado: $app${NC}"
            done
        else
            log_warning "Reintentando una por una..."
            for app in "${installed[@]}"; do
                if purge_and_record "$app" > /dev/null; then
                    echo -e "  ${GREEN}✓ Eliminado: $app${NC}"
                else
                    echo -e "  ${RED}✗ No se pudo eliminar: $app${NC}"
                fi
            done
        fi
    fi

    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    $AUTO_MODE || echo -e "${CYAN}ℹ Para quitar los íconos del escritorio o del panel usa la opción 14${NC}"
    echo ""
}

setup_spotify_repo() {
    [ -f /etc/apt/sources.list.d/spotify.list ] && return 0
    run "No se pudo descargar la clave de Spotify" \
        bash -c "set -o pipefail; wget -qO- https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg" \
        || return 1
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
}

# Instala todo en una sola operación de apt. Los .deb externos (VSCode, Chrome,
# Discord) se descargan en paralelo mientras se actualiza la lista de paquetes.
install_optional_with_progress() {
    local repo=() deb_names=() deb_urls=() pids=() debs=() failed=() app i
    local repo_changed=false tmp
    tmp=$(mktemp -d)
    chmod 755 "$tmp"

    echo -e "${BLUE}📦 Instalando software...${NC}"
    command -v wget &> /dev/null || { apt_update; apt_install wget; }

    for app in "$@"; do
        case $app in
            "code") deb_names+=(code); deb_urls+=("https://go.microsoft.com/fwlink/?LinkID=760868") ;;
            "fastfetch")
                # No está en los repositorios de Ubuntu 24.04 y anteriores: .deb oficial del proyecto
                if [ -n "$(available_pkgs fastfetch)" ]; then
                    repo+=(fastfetch)
                else
                    local ff_arch
                    ff_arch=$(dpkg --print-architecture)
                    [ "$ff_arch" = "arm64" ] && ff_arch=aarch64
                    deb_names+=(fastfetch)
                    deb_urls+=("https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$ff_arch.deb")
                fi ;;
            "google-chrome-stable") deb_names+=(google-chrome-stable); deb_urls+=("https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb") ;;
            "discord") deb_names+=(discord); deb_urls+=("https://discord.com/api/download?platform=linux&format=deb") ;;
            "spotify")
                if setup_spotify_repo; then
                    repo+=(spotify-client)
                    repo_changed=true
                else
                    failed+=(spotify)
                fi ;;
            "emojier") repo+=(kdeplasma-addons) ;;
            *) repo+=("$app") ;;
        esac
    done

    for i in "${!deb_urls[@]}"; do
        echo -e "${BLUE}  ⬇ Descargando ${deb_names[$i]}...${NC}"
        wget -qO "$tmp/${deb_names[$i]}.deb" "${deb_urls[$i]}" >> "$LOG_FILE" 2>&1 &
        pids+=($!)
    done

    if $repo_changed; then
        apt_update force
    else
        apt_update
    fi

    # Paquetes que no existen en tus repositorios: se avisan sin romper el resto
    if [ ${#repo[@]} -gt 0 ]; then
        local available=() missing
        mapfile -t available < <(available_pkgs "${repo[@]}" | sort -u)
        for app in "${repo[@]}"; do
            if ! printf '%s\n' "${available[@]}" | grep -qx -- "$app"; then
                log_error "No disponible en tus repositorios: $app"
                failed+=("$app")
            fi
        done
        repo=("${available[@]}")
    fi

    for i in "${!pids[@]}"; do
        if wait "${pids[$i]}" && [ -s "$tmp/${deb_names[$i]}.deb" ]; then
            chmod 644 "$tmp/${deb_names[$i]}.deb"
            debs+=("$tmp/${deb_names[$i]}.deb")
        else
            log_error "No se pudo descargar ${deb_names[$i]}"
            failed+=("${deb_names[$i]}")
        fi
    done

    local all=("${repo[@]}" "${debs[@]}")
    if [ ${#all[@]} -gt 0 ]; then
        echo -e "${BLUE}📦 Instalando ${#all[@]} paquetes en una sola operación...${NC}"
        if apt_install_recorded "${all[@]}"; then
            for app in "${all[@]}"; do
                echo -e "  ${GREEN}✓ Instalado: $(basename "$app" .deb)${NC}"
            done
        else
            log_warning "Reintentando uno por uno..."
            for app in "${all[@]}"; do
                if apt_install_recorded "$app" > /dev/null; then
                    echo -e "  ${GREEN}✓ Instalado: $(basename "$app" .deb)${NC}"
                else
                    failed+=("$(basename "$app" .deb)")
                fi
            done
        fi
    fi
    rm -rf "$tmp"

    if [ ${#failed[@]} -gt 0 ]; then
        log_error "No se pudieron instalar: ${failed[*]}"
        return 1
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
    echo -e "  • Volver a los valores de fábrica los ajustes del script (RAM, DNS, ZRAM, energía...)"
    echo ""

    if ! confirm "${RED}⚠ ¿Revertir a Kubuntu original?${NC}"; then
        return 0
    fi

    echo -e "${RED}[1/5] Eliminando Rolling Release...${NC}"
    if grep -rqs 'kubuntu-ppa/backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
        run "No se pudo quitar el PPA backports" sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports
        apt_update force
        downgrade_orphaned_ppa_pkgs
    else
        echo -e "  ${GREEN}✓ El PPA backports no está activo${NC}"
        apt_update
    fi

    echo -e "${RED}[2/5] Desbloqueando Snap...${NC}"
    # La eliminación nuclear (opción 10) bloquea snapd; hay que desbloquearlo antes
    sudo apt-mark unhold snapd >> "$LOG_FILE" 2>&1
    sudo rm -f /etc/apt/preferences.d/nosnap.pref

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

    echo -e "${RED}[5/5] Restaurando ajustes y limpiando configuraciones...${NC}"
    restore_all_tweaks
    rm -rf ~/.config/alacritty

    echo ""
    echo -e "${GREEN}✓ Sistema revertido${NC}"
    echo -e "${YELLOW}⚠ Reinicia para completar${NC}"
    pause
}

# ============================================================
# OPCIÓN 10: ELIMINACIÓN NUCLEAR DE SNAP (COLOR: ROJO)
# ============================================================

# Copia los perfiles de Firefox/Thunderbird del snap a la ubicación de la versión .deb
migrate_snap_profiles() {
    local pair app dir
    for pair in firefox:.mozilla thunderbird:.thunderbird; do
        app=${pair%%:*}
        dir=${pair#*:}
        if [ -d "$HOME/snap/$app/common/$dir" ] && [ ! -e "$HOME/$dir" ]; then
            cp -a "$HOME/snap/$app/common/$dir" "$HOME/$dir" \
                && log_success "Perfil de $app copiado a ~/$dir (marcadores y contraseñas)"
        fi
    done
}

do_snap_removal() {
    echo -e "${RED}☢️ Iniciando eliminación nuclear de Snap...${NC}\n"

    # Al borrar el snap se pierden marcadores y contraseñas: se copian antes a la ruta normal
    migrate_snap_profiles

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
    run "Falló autoremove" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge

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

}

# Firefox .deb desde el repositorio oficial de Mozilla (el de Ubuntu instala el snap)
install_firefox_deb() {
    local status
    status=$(dpkg-query -W -f='${db:Status-Abbrev}|${Version}' firefox 2>/dev/null)
    # El paquete de Ubuntu es un "puente" al snap (versión 1:1snap1-...)
    if [[ "$status" == ?i* ]] && [[ "$status" != *snap* ]]; then
        echo -e "  ${GREEN}✓ Firefox .deb ya está instalado${NC}"
        return 0
    fi
    sudo install -d -m 0755 /etc/apt/keyrings
    run "No se pudo descargar la clave de Mozilla" \
        sudo wget -qO /etc/apt/keyrings/packages.mozilla.org.asc https://packages.mozilla.org/apt/repo-signing-key.gpg || return 1
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    # Prioridad alta para que no se use el paquete de Ubuntu que instala el snap
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
    apt_update force || return 1
    apt_install --allow-downgrades firefox && log_success "Firefox .deb instalado"
}

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

    do_snap_removal

    if confirm "${BLUE}¿Instalar Firefox en versión .deb (repositorio oficial de Mozilla)?${NC}"; then
        install_firefox_deb
    fi
    echo ""
    echo -e "${GREEN}✓ ¡ELIMINACIÓN NUCLEAR DE SNAP COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Snap ha sido borrado y bloqueado (la opción 11 permite reinstalarlo)${NC}"
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

        is_live_session && echo -e "${GREEN}💿 Sesión Live USB detectada: usa la opción 4${NC}"
        echo -e "\n${PURPLE}📋 Con el sistema arrancado:${NC}\n"
        echo -e "  ${PURPLE}1)${NC} 📊 DIAGNÓSTICO - Ver discos y particiones"
        echo -e "  ${PURPLE}2)${NC} 🔧 REPARACIÓN NORMAL - Reinstalar GRUB"
        echo -e "  ${PURPLE}3)${NC} 💿 INSTALAR GRUB EN DISCO - Disco específico"
        echo -e "\n${PURPLE}📋 Cuando el sistema NO arranca:${NC}\n"
        echo -e "  ${PURPLE}4)${NC} 🚑 REPARAR DESDE LIVE USB - Automático (chroot)"
        echo -e "  ${PURPLE}5)${NC} 📖 GUÍA 'grub>' - Arrancar a mano desde el prompt de GRUB"
        echo -e "  ${PURPLE}6)${NC} 📖 GUÍA 'grub rescue>' - Recuperar el menú de GRUB"
        echo -e "  ${PURPLE}7)${NC} 📖 GUÍA LIVE USB - Reparación manual con comandos"
        echo -e "\n${PURPLE}📋 Menú de arranque y EFI:${NC}\n"
        echo -e "  ${PURPLE} 8)${NC} 🗂️ SISTEMA POR DEFECTO - Qué arranca solo y cuánto espera el menú"
        echo -e "  ${PURPLE} 9)${NC} 🪟 OTROS SISTEMAS - Detectar Windows y otras distros (os-prober)"
        echo -e "  ${PURPLE}10)${NC} 🔢 ORDEN DE ARRANQUE UEFI - Qué arranca primero / solo la próxima vez"
        echo -e "  ${PURPLE}11)${NC} 🩺 PARTICIÓN EFI - Verificar, reparar y ver espacio libre"
        echo -e "  ${PURPLE}12)${NC} 🧰 HERRAMIENTAS - Grub Customizer, Boot-Repair, rEFInd"
        echo -e "  ${PURPLE}13)${NC} ⬅️ Volver al menú principal"
        echo ""
        read -r -p "📌 Opcion (1-13): " grub_option

        case $grub_option in
            1) grub_diagnostic ;;
            2) grub_normal_repair ;;
            3) grub_reinstall_to_disk ;;
            4) grub_live_repair ;;
            5) grub_prompt_guide ;;
            6) grub_rescue_guide ;;
            7) grub_live_guide ;;
            8) grub_default_entry_menu; pause ;;
            9) grub_os_prober_toggle; pause ;;
            10) uefi_boot_order_menu; pause ;;
            11) esp_check_repair; pause ;;
            12) boot_tools_menu ;;
            13) return 0 ;;
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

grub_guide_header() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    printf "║                    %-46s║\n" "$1"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

grub_prompt_guide() {
    grub_guide_header "📖 ARRANQUE MANUAL DESDE 'grub>'"
    cat << 'EOF'
Si al encender aparece "grub>" (GRUB cargó, pero no encuentra su menú),
puedes arrancar Kubuntu a mano. La tecla TAB autocompleta nombres y rutas.

PASO 1: ENCONTRAR LA PARTICIÓN DE KUBUNTU
    ls
  Verás algo como: (hd0) (hd0,gpt1) (hd0,gpt2) ...  (o msdos1, msdos2 en discos MBR)
  Prueba cada una hasta ver las carpetas del sistema (boot/, etc/, home/...):
    ls (hd0,gpt2)/

PASO 2: CARGAR MÓDULOS Y ARRANCAR
  (cambia hd0,gpt2 y /dev/sda2 por los tuyos)
    set root=(hd0,gpt2)
    insmod part_gpt          (en discos MBR: insmod part_msdos)
    insmod ext2              (sirve también para ext4)
    insmod linux
    linux /boot/vmlinuz root=/dev/sda2 ro
    initrd /boot/initrd.img
    boot

  • /boot/vmlinuz e /boot/initrd.img apuntan siempre al kernel más nuevo,
    así no hace falta escribir la versión (vmlinuz-6.8.0-xx...).
  • root= usa el nombre de Linux, no el de GRUB:
      (hd0,gpt2) suele ser /dev/sda2 en discos SATA y /dev/nvme0n1p2 en NVMe.
    Si te equivocas, verás "(initramfs)": reinicia y prueba con otro nombre.
  • Si /boot está en su propia partición, en PASO 2 usa esa partición y
    quita "/boot" de las rutas: linux /vmlinuz ... e initrd /initrd.img

PASO 3: YA DENTRO DEL SISTEMA (reparar de forma permanente)
  Ejecuta este script → opción 12 → 2 (REPARACIÓN NORMAL), o a mano:
    sudo grub-install /dev/sda        (en UEFI basta: sudo grub-install)
    sudo update-grub
  (update-grub es lo mismo que "grub-mkconfig -o /boot/grub/grub.cfg")
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_rescue_guide() {
    grub_guide_header "🛡️ GUÍA PARA 'grub rescue>'"
    cat << 'EOF'
"grub rescue>" significa que GRUB no encuentra ni sus módulos: aquí no existen
los comandos "linux" ni "initrd", solo ls, set e insmod.

PASO 1: IDENTIFICAR LAS PARTICIONES
    ls
  Verás algo como: (hd0) (hd0,gpt1) (hd0,gpt2) (hd0,gpt3)

PASO 2: ENCONTRAR LA PARTICIÓN DE LINUX
  Prueba cada partición con:
    ls (hd0,gpt2)/boot/grub
  La que muestre archivos (como grub.cfg o la carpeta x86_64-efi / i386-pc)
  es la correcta.

PASO 3: CARGAR GRUB NORMALMENTE
  Con la partición encontrada (ej: hd0,gpt2):
    set prefix=(hd0,gpt2)/boot/grub
    set root=(hd0,gpt2)
    insmod normal
    normal

  Aparecerá el menú de GRUB (o el prompt "grub>": sigue la guía 5).

PASO 4: UNA VEZ EN EL SISTEMA
  Ejecuta este script → opción 12 → 2 (REPARACIÓN NORMAL).

SI "insmod normal" FALLA
  Los archivos de GRUB están dañados: arranca desde un USB de Kubuntu
  y usa la opción 4 (reparación automática desde Live USB).
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_live_guide() {
    grub_guide_header "📖 REPARACIÓN MANUAL DESDE LIVE USB"
    cat << 'EOF'
Arranca desde un USB de Kubuntu ("Probar Kubuntu") y abre Konsole.
La opción 4 de este menú hace todo esto automáticamente.

1. IDENTIFICAR LA PARTICIÓN DEL SISTEMA (y la EFI, si el equipo es UEFI)
    sudo fdisk -l            (o: lsblk -f)
  • Sistema: la partición ext4/btrfs grande (ej: /dev/sda2)
  • EFI: la partición FAT32 de ~100-1000 MB "EFI System" (ej: /dev/sda1)
  • ¿UEFI o BIOS? Si existe /sys/firmware/efi, es UEFI.

2. MONTAR EL SISTEMA
    sudo mount /dev/sda2 /mnt
    sudo mount /dev/sda1 /mnt/boot/efi            (solo UEFI)
  • btrfs: sudo mount -o subvol=@ /dev/sda2 /mnt
  • Cifrado (LUKS): sudo cryptsetup open /dev/sda3 cripta
                    sudo vgchange -ay   y monta el volumen que aparezca
  • /boot separado: sudo mount /dev/sdaX /mnt/boot (antes que /boot/efi)

3. PREPARAR EL ENTORNO PARA EL CHROOT
    for d in dev dev/pts proc sys run; do sudo mount --bind /$d /mnt/$d; done
    sudo mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars   (solo UEFI)

4. ENTRAR AL SISTEMA DAÑADO
    sudo chroot /mnt

5. REINSTALAR GRUB (dentro del chroot)
  UEFI:
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
  BIOS (al DISCO, no a la partición: /dev/sda, no /dev/sda2):
    grub-install --target=i386-pc /dev/sda
  Después, en ambos casos:
    update-grub
  (update-grub = grub-mkconfig -o /boot/grub/grub.cfg; no hace falta ejecutar los dos)

  Si grub-install falla por archivos que faltan, reinstala GRUB (necesita internet):
    apt install --reinstall grub-efi-amd64-signed shim-signed     (UEFI)
    apt install --reinstall grub-pc                               (BIOS)

6. SALIR, DESMONTAR Y REINICIAR
    exit
    sudo umount -R /mnt      (desmonta todo lo de /mnt de una vez)
    reboot
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

# ------------------------------------------------------------
# Reparación automática desde Live USB
# ------------------------------------------------------------

RESCUE_MNT="/mnt/kubuntu-rescate"

is_live_session() {
    grep -qw 'boot=casper' /proc/cmdline 2>/dev/null || [ -d /cdrom/casper ] \
        || [ "$(findmnt -no FSTYPE / 2>/dev/null)" = "overlay" ]
}

# Particiones con sistema de archivos de Linux: "dispositivo|tamaño|tipo|etiqueta"
linux_partitions() {
    local dev fs
    while read -r dev; do
        fs=$(lsblk -dno FSTYPE "$dev" 2>/dev/null)
        case $fs in ext4|ext3|btrfs|xfs) ;; *) continue ;; esac
        echo "$dev|$(lsblk -dno SIZE "$dev" | tr -d ' ')|$fs|$(lsblk -dno LABEL "$dev")"
    done < <(lsblk -lnpo NAME,TYPE | awk '$2 == "part" || $2 == "lvm" || $2 == "crypt" {print $1}')
}

unlock_encrypted_partitions() {
    local dev
    for dev in $(lsblk -lnpo NAME,FSTYPE | awk '$2 == "crypto_LUKS" {print $1}'); do
        lsblk -lnpo TYPE "$dev" | grep -q crypt && continue
        if confirm "${PURPLE}🔐 $dev está cifrada. ¿Desbloquearla?${NC}"; then
            sudo cryptsetup open "$dev" "rescate_$(basename "$dev")" \
                || log_error "No se pudo desbloquear $dev"
        fi
    done
    command -v vgchange &> /dev/null && sudo vgchange -ay >> "$LOG_FILE" 2>&1
}

rescue_umount() {
    findmnt "$RESCUE_MNT" > /dev/null 2>&1 || return 0
    sudo umount -R "$RESCUE_MNT" 2>> "$LOG_FILE" || sudo umount -lR "$RESCUE_MNT" 2>> "$LOG_FILE"
}

rescue_grub_install() {
    local uefi="$1" disk="$2"
    if $uefi; then
        run_visible "Falló grub-install" sudo chroot "$RESCUE_MNT" \
            grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
    else
        run_visible "Falló grub-install" sudo chroot "$RESCUE_MNT" grub-install --target=i386-pc --recheck "$disk"
    fi
}

grub_live_repair() {
    grub_guide_header "🚑 REPARAR GRUB DESDE LIVE USB"

    if ! is_live_session; then
        log_warning "Esto no parece una sesión Live USB"
        echo -e "${YELLOW}  Esta opción es para cuando Kubuntu no arranca: inicia desde un USB de Kubuntu,${NC}"
        echo -e "${YELLOW}  elige 'Probar Kubuntu', abre Konsole y ejecuta este script.${NC}"
        echo -e "${YELLOW}  Si el sistema arranca, usa la opción 2 (REPARACIÓN NORMAL).${NC}\n"
        if ! confirm "${PURPLE}¿Continuar de todos modos?${NC}"; then
            return 0
        fi
    fi

    local uefi=false
    [ -d /sys/firmware/efi ] && uefi=true
    if $uefi; then
        echo -e "${PURPLE}🖥️ Modo de arranque: UEFI${NC}"
    else
        echo -e "${PURPLE}🖥️ Modo de arranque: BIOS (Legacy)${NC}"
    fi
    echo -e "${YELLOW}ℹ El USB debe haber arrancado en el mismo modo que el sistema instalado${NC}\n"

    unlock_encrypted_partitions

    local parts=() part i=0 choice root_dev root_fs disk
    mapfile -t parts < <(linux_partitions)
    if [ ${#parts[@]} -eq 0 ]; then
        log_error "No se encontraron particiones de Linux"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
        read -r
        return 1
    fi
    echo -e "${PURPLE}💾 Particiones de Linux encontradas:${NC}\n"
    for part in "${parts[@]}"; do
        i=$((i + 1))
        IFS='|' read -r root_dev disk root_fs choice <<< "$part"
        printf "  ${PURPLE}[%s]${NC} %-22s %8s  %-6s %s\n" "$i" "$root_dev" "$disk" "$root_fs" "$choice"
    done
    echo ""
    read -r -p "📌 ¿Cuál es la partición del sistema (la raíz /)? " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#parts[@]} ]; then
        log_error "Opción inválida"
        sleep 1
        return 1
    fi
    IFS='|' read -r root_dev _ root_fs _ <<< "${parts[$((choice - 1))]}"
    # Disco físico que contiene la partición (atravesando LVM/LUKS)
    disk="/dev/$(lsblk -rnso NAME,TYPE "$root_dev" | awk '$2 == "disk" {print $1; exit}')"

    echo -e "\n${PURPLE}[1/5] Montando $root_dev...${NC}"
    rescue_umount
    sudo mkdir -p "$RESCUE_MNT"
    if [ "$root_fs" = "btrfs" ]; then
        # Kubuntu instala la raíz en el subvolumen @
        sudo mount -o subvol=@ "$root_dev" "$RESCUE_MNT" 2>> "$LOG_FILE" \
            || run "No se pudo montar $root_dev" sudo mount "$root_dev" "$RESCUE_MNT" || return 1
    else
        run "No se pudo montar $root_dev" sudo mount "$root_dev" "$RESCUE_MNT" || return 1
    fi
    if [ ! -f "$RESCUE_MNT/etc/fstab" ] || [ ! -d "$RESCUE_MNT/boot" ]; then
        log_error "$root_dev no contiene un sistema instalado (no tiene /etc/fstab ni /boot)"
        rescue_umount
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
        read -r
        return 1
    fi

    echo -e "${PURPLE}[2/5] Montando /boot y la partición EFI...${NC}"
    local mp spec esp
    # Particiones separadas según el fstab del sistema instalado (primero /boot)
    for mp in /boot /boot/efi; do
        spec=$(awk -v m="$mp" '$1 !~ /^#/ && $2 == m {print $1; exit}' "$RESCUE_MNT/etc/fstab")
        if [ -n "$spec" ]; then
            sudo mkdir -p "$RESCUE_MNT$mp"
            run "No se pudo montar $mp ($spec)" sudo mount "$spec" "$RESCUE_MNT$mp" || { rescue_umount; return 1; }
            log_success "$mp montado ($spec)"
        fi
    done
    if $uefi && ! findmnt "$RESCUE_MNT/boot/efi" > /dev/null 2>&1; then
        esp=$(lsblk -lnpo NAME,PARTTYPE | awk 'tolower($2) == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" || $2 == "0xef" {print $1; exit}')
        if [ -z "$esp" ]; then
            log_error "No se encontró la partición EFI (FAT32, tipo 'EFI System')"
            rescue_umount
            return 1
        fi
        sudo mkdir -p "$RESCUE_MNT/boot/efi"
        run "No se pudo montar la partición EFI $esp" sudo mount "$esp" "$RESCUE_MNT/boot/efi" || { rescue_umount; return 1; }
        log_success "Partición EFI montada ($esp)"
    fi

    echo -e "${PURPLE}[3/5] Preparando el entorno chroot...${NC}"
    local d
    for d in dev dev/pts proc sys run; do
        run "No se pudo montar /$d" sudo mount --bind "/$d" "$RESCUE_MNT/$d" || { rescue_umount; return 1; }
    done
    $uefi && sudo mount -t efivarfs efivarfs "$RESCUE_MNT/sys/firmware/efi/efivars" 2>> "$LOG_FILE"

    if ! $uefi; then
        echo -e "\n${PURPLE}💿 Discos:${NC}"
        lsblk -dpno NAME,SIZE,MODEL | grep -v loop | sed 's/^/  /'
        read -r -p "📌 Disco donde instalar GRUB [Enter = $disk]: " d
        [ -n "$d" ] && disk="$d"
        if [ ! -b "$disk" ]; then
            log_error "El disco $disk no existe"
            rescue_umount
            return 1
        fi
    fi

    echo -e "\n${PURPLE}📋 Resumen:${NC}"
    echo -e "  • Sistema: $root_dev ($root_fs)"
    $uefi && echo -e "  • Modo: UEFI (partición EFI en /boot/efi)" || echo -e "  • Modo: BIOS, GRUB en $disk"
    if ! confirm "${PURPLE}¿Reinstalar GRUB ahora?${NC}"; then
        rescue_umount
        return 0
    fi

    echo -e "${PURPLE}[4/5] Reinstalando GRUB...${NC}"
    local ok=0
    if ! rescue_grub_install "$uefi" "$disk"; then
        ok=1
        local grub_pkgs="grub-pc"
        $uefi && grub_pkgs="grub-efi-amd64 grub-efi-amd64-signed shim-signed"
        if confirm "${PURPLE}¿Reinstalar los paquetes de GRUB del sistema y reintentar? (necesita internet)${NC}"; then
            # shellcheck disable=SC2086  # lista de paquetes
            run_visible "No se pudieron reinstalar los paquetes de GRUB" sudo chroot "$RESCUE_MNT" \
                env DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y $grub_pkgs \
                && rescue_grub_install "$uefi" "$disk" && ok=0
        fi
    fi

    if [ $ok -eq 0 ]; then
        run_visible "Falló update-grub" sudo chroot "$RESCUE_MNT" update-grub
        ok=$?
    fi

    echo -e "${PURPLE}[5/5] Desmontando...${NC}"
    rescue_umount

    echo ""
    if [ $ok -eq 0 ]; then
        log_success "GRUB reparado. Quita el USB y reinicia"
        if confirm "${PURPLE}¿Reiniciar ahora?${NC}"; then
            sudo reboot
        fi
    else
        log_error "La reparación no terminó. Revisa: $LOG_FILE"
    fi
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

# ------------------------------------------------------------
# Menú de arranque y EFI
# ------------------------------------------------------------

# Cambia (o agrega) una variable de /etc/default/grub
set_grub_var() {
    local key="$1" value="$2"
    if grep -q "^${key}=" /etc/default/grub; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" /etc/default/grub
    else
        echo "${key}=${value}" | sudo tee -a /etc/default/grub > /dev/null
    fi
}

# Entradas del menú de GRUB: "ruta para grub-set-default|título visible"
grub_menu_entries() {
    local cfg="/boot/grub/grub.cfg" sub_line entry_line sub_title entry_title sub_id entry_id
    # Separador \037: con un tabulador, read se come el campo vacío de las entradas sin submenú
    while IFS=$'\037' read -r sub_line entry_line; do
        entry_id=$(grub_line_id "$entry_line")
        entry_title=$(grep -oP "^\s*menuentry ['\"]\K[^'\"]+" <<< "$entry_line")
        if [ -n "$sub_line" ]; then
            sub_id=$(grub_line_id "$sub_line")
            sub_title=$(grep -oP "^\s*submenu ['\"]\K[^'\"]+" <<< "$sub_line")
            echo "${sub_id}>${entry_id}|${sub_title} › ${entry_title}"
        else
            echo "${entry_id}|${entry_title}"
        fi
    done < <(sudo awk '
        /^submenu / { s = $0; next }
        /^}/ { s = ""; next }
        /menuentry / && tolower($0) !~ /recovery|recuperaci/ { print s "\037" $0 }
    ' "$cfg")
}

grub_default_entry_menu() {
    grub_guide_header "🗂️ SISTEMA POR DEFECTO Y TIEMPO DEL MENÚ"
    local entries=() entry i=0 choice timeout
    mapfile -t entries < <(grub_menu_entries)
    if [ ${#entries[@]} -eq 0 ]; then
        log_error "No se pudo leer el menú de GRUB (/boot/grub/grub.cfg)"
        return 1
    fi

    echo -e "${PURPLE}📋 Entradas del menú de arranque:${NC}\n"
    for entry in "${entries[@]}"; do
        i=$((i + 1))
        printf "  ${PURPLE}[%2s]${NC} %s\n" "$i" "${entry#*|}"
    done
    echo ""
    read -r -p "📌 ¿Cuál arranca por defecto? (Enter = no cambiar): " choice
    if [ -n "$choice" ]; then
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#entries[@]} ]; then
            log_error "Opción inválida"
            return 1
        fi
        entry=${entries[$((choice - 1))]}
        ensure_grub_saved
        [ $? -eq 1 ] && return 1
        run "No se pudo cambiar el sistema por defecto" sudo grub-set-default "${entry%%|*}" \
            && log_success "Por defecto: ${entry#*|}"
    fi

    timeout=$(sed -n 's/^GRUB_TIMEOUT=//p' /etc/default/grub | tr -d '"')
    echo ""
    read -r -p "⏱ Segundos que espera el menú (actual: ${timeout:-?}; 0 = no mostrarlo; Enter = no cambiar): " choice
    if [ -n "$choice" ]; then
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            log_error "Escribe un número de segundos"
            return 1
        fi
        set_grub_var GRUB_TIMEOUT "$choice"
        if [ "$choice" -eq 0 ]; then
            set_grub_var GRUB_TIMEOUT_STYLE hidden
        else
            set_grub_var GRUB_TIMEOUT_STYLE menu
        fi
        run_visible "Falló update-grub" sudo update-grub \
            && log_success "El menú de GRUB espera $choice segundos"
    fi
}

grub_os_prober_toggle() {
    grub_guide_header "🪟 DETECTAR OTROS SISTEMAS"
    if grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then
        echo -e "${GREEN}✓ La detección de otros sistemas ya está activada${NC}\n"
        if confirm "${PURPLE}¿Desactivarla? (los otros sistemas desaparecerán del menú)${NC}"; then
            set_grub_var GRUB_DISABLE_OS_PROBER true
            run_visible "Falló update-grub" sudo update-grub && log_success "Detección de otros sistemas desactivada"
        fi
        return 0
    fi

    echo -e "${PURPLE}Desde GRUB 2.06, Ubuntu no busca otros sistemas (Windows, otras distros) por seguridad.${NC}"
    echo -e "${PURPLE}Al activarlo, aparecerán en el menú de arranque.${NC}\n"
    confirm "${PURPLE}¿Activar la detección de otros sistemas?${NC}" || return 0
    command -v os-prober &> /dev/null || { apt_update; apt_install os-prober || return 1; }
    set_grub_var GRUB_DISABLE_OS_PROBER false
    echo -e "${PURPLE}🔍 Buscando otros sistemas...${NC}"
    local found
    found=$(sudo os-prober 2>> "$LOG_FILE")
    if [ -n "$found" ]; then
        echo -e "${GREEN}Encontrados:${NC}"
        cut -d: -f2 <<< "$found" | sed 's/^/  • /'
    else
        log_warning "No se encontró otro sistema (si está en otro disco, conéctalo y vuelve a intentarlo)"
    fi
    run_visible "Falló update-grub" sudo update-grub && log_success "Detección activada"
    echo -e "${YELLOW}ℹ Si el menú no aparece al encender, usa la opción 8 para darle unos segundos${NC}"
}

uefi_boot_order_menu() {
    grub_guide_header "🔢 ORDEN DE ARRANQUE UEFI"
    if [ ! -d /sys/firmware/efi ]; then
        log_warning "Este equipo arranca en modo BIOS (Legacy): el orden se cambia en la BIOS"
        return 0
    fi
    command -v efibootmgr &> /dev/null || { apt_update; apt_install efibootmgr || return 1; }

    local out entries=() order current entry i=0 choice action num
    out=$(LC_ALL=C efibootmgr 2>> "$LOG_FILE")
    order=$(sed -n 's/^BootOrder: //p' <<< "$out")
    current=$(sed -n 's/^BootCurrent: //p' <<< "$out")
    mapfile -t entries < <(sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} \{1,\}\([^\t]*\).*/\1|\2/p' <<< "$out")
    if [ ${#entries[@]} -eq 0 ]; then
        log_error "No se pudieron leer las entradas UEFI"
        return 1
    fi

    echo -e "${PURPLE}📋 Entradas de arranque (orden actual: $order):${NC}\n"
    for entry in "${entries[@]}"; do
        i=$((i + 1))
        num=${entry%%|*}
        printf "  ${PURPLE}[%2s]${NC} %s %s" "$i" "$num" "${entry#*|}"
        [ "$num" = "$current" ] && printf " ${GREEN}(arrancado ahora)${NC}"
        [ "$num" = "${order%%,*}" ] && printf " ${CYAN}(primero)${NC}"
        echo ""
    done
    echo ""
    read -r -p "📌 Entrada: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#entries[@]} ]; then
        echo -e "${YELLOW}ℹ No se cambió nada${NC}"
        return 0
    fi
    entry=${entries[$((choice - 1))]}
    num=${entry%%|*}

    echo -e "\n  ${PURPLE}1)${NC} Ponerla primera (siempre)"
    echo -e "  ${PURPLE}2)${NC} Arrancarla solo la próxima vez (p. ej. entrar a Windows una vez)"
    read -r -p "📌 Opción: " action
    case $action in
        1)
            local new_order
            new_order=$(tr ',' '\n' <<< "$order" | grep -vix "$num" | paste -sd, -)
            new_order="$num${new_order:+,$new_order}"
            run "No se pudo cambiar el orden" sudo efibootmgr -o "$new_order" \
                && log_success "Primero: ${entry#*|} (orden: $new_order)"
            ;;
        2)
            run "No se pudo programar el próximo arranque" sudo efibootmgr -n "$num" \
                && log_success "El próximo arranque será: ${entry#*|}"
            confirm "${PURPLE}¿Reiniciar ahora?${NC}" && sudo reboot
            ;;
        *) echo -e "${YELLOW}ℹ No se cambió nada${NC}" ;;
    esac
}

esp_check_repair() {
    grub_guide_header "🩺 PARTICIÓN EFI"
    local dev
    dev=$(findmnt -no SOURCE /boot/efi 2>/dev/null)
    if [ -z "$dev" ]; then
        log_warning "No hay partición EFI montada en /boot/efi (¿el equipo arranca en modo BIOS?)"
        return 0
    fi
    echo -e "${PURPLE}💾 Partición EFI: $dev${NC}"
    df -h /boot/efi | sed 's/^/  /'
    echo -e "\n${PURPLE}📁 Sistemas registrados en ella:${NC}"
    sudo ls /boot/efi/EFI 2>/dev/null | sed 's/^/  • /'
    echo -e "\n${YELLOW}ℹ Windows con 'inicio rápido' o un apagado brusco pueden dañarla y dejar GRUB sin arrancar${NC}\n"
    confirm "${PURPLE}¿Verificar y reparar la partición EFI? (se desmonta unos segundos)${NC}" || return 0

    command -v fsck.vfat &> /dev/null || { apt_update; apt_install dosfstools || return 1; }
    run "No se pudo desmontar /boot/efi (¿la está usando otro programa?)" sudo umount /boot/efi || return 1
    sudo fsck.vfat -a "$dev" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}
    run "No se pudo volver a montar /boot/efi" sudo mount /boot/efi || return 1
    # fsck: 0 = sin errores, 1 = errores corregidos, más = quedaron errores
    case $rc in
        0) log_success "Partición EFI sin errores" ;;
        1) log_success "Partición EFI reparada" ;;
        *) log_error "Quedaron errores en la partición EFI (código $rc). Prueba Boot-Repair (opción 12 → 2)" ;;
    esac
}

# ------------------------------------------------------------
# Herramientas gráficas de arranque
# ------------------------------------------------------------

# Instala un paquete desde los repositorios o, si no está, desde su PPA
install_from_repo_or_ppa() {
    local pkg="$1" ppa="$2"
    apt_update
    if [ -z "$(available_pkgs "$pkg")" ]; then
        echo -e "${PURPLE}📦 Agregando el repositorio $ppa...${NC}"
        run "No se pudo agregar $ppa" sudo add-apt-repository -y "$ppa" || return 1
        apt_update force
        if [ -z "$(available_pkgs "$pkg")" ]; then
            log_error "$pkg no está disponible para esta versión de Ubuntu"
            run "No se pudo quitar $ppa" sudo add-apt-repository --remove -y "$ppa"
            return 1
        fi
    fi
    apt_install_recorded "$pkg"
}

launch_gui() {
    echo -e "${PURPLE}🚀 Abriendo $1...${NC}"
    setsid "$1" >> "$LOG_FILE" 2>&1 < /dev/null &
}

install_grub_customizer() {
    echo -e "${YELLOW}ℹ Grub Customizer reemplaza los scripts de /etc/grub.d por los suyos.${NC}"
    echo -e "${YELLOW}  Para deshacerlo: en Grub Customizer → Archivo → Revertir a la configuración original.${NC}\n"
    command -v grub-customizer &> /dev/null || install_from_repo_or_ppa grub-customizer ppa:danielrichter2007/grub-customizer || return 1
    launch_gui grub-customizer
}

install_boot_repair() {
    echo -e "${YELLOW}ℹ Boot-Repair repara el arranque (GRUB y EFI) con un clic; sus opciones avanzadas${NC}"
    echo -e "${YELLOW}  permiten elegir el sistema por defecto y la partición EFI. También funciona desde Live USB.${NC}\n"
    command -v boot-repair &> /dev/null || install_from_repo_or_ppa boot-repair ppa:yannubuntu/boot-repair || return 1
    launch_gui boot-repair
}

install_refind() {
    if [ ! -d /sys/firmware/efi ]; then
        log_error "rEFInd solo funciona en equipos UEFI (este arranca en modo BIOS)"
        return 1
    fi
    echo -e "${YELLOW}ℹ rEFInd es otro gestor de arranque: muestra todos los sistemas con íconos y queda primero.${NC}"
    echo -e "${YELLOW}  GRUB sigue instalado: se puede volver con la opción 10 o quitando rEFInd desde aquí.${NC}"
    if secure_boot_enabled; then
        log_warning "Secure Boot está activado: rEFInd puede no arrancar (la UEFI saltará a la siguiente entrada)"
    fi
    echo ""
    confirm "${PURPLE}¿Instalar rEFInd?${NC}" || return 0
    # Instalarlo en la partición EFI sin preguntar
    echo "refind refind/install_to_esp boolean true" | sudo debconf-set-selections
    apt_update
    apt_install_recorded refind && log_success "rEFInd instalado: se verá al reiniciar"
}

remove_refind() {
    if ! installed_pkgs refind | grep -qx refind; then
        echo -e "  ${GREEN}✓ rEFInd no está instalado${NC}"
        return 0
    fi
    confirm "${PURPLE}¿Quitar rEFInd y volver a arrancar con GRUB?${NC}" || return 0
    apt_purge refind && forget_installed refind
    # Su entrada UEFI y sus archivos en la partición EFI no se borran con el paquete
    local num
    for num in $(LC_ALL=C efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} rEFInd.*/\1/p'); do
        run "No se pudo quitar la entrada UEFI de rEFInd" sudo efibootmgr -b "$num" -B
    done
    sudo rm -rf /boot/efi/EFI/refind
    run_visible "No se pudo reinstalar GRUB" sudo grub-install && log_success "rEFInd quitado: arranca GRUB"
}

boot_tools_menu() {
    while true; do
        grub_guide_header "🧰 HERRAMIENTAS DE ARRANQUE"
        echo -e "  ${PURPLE}1)${NC} Grub Customizer - Editar el menú: ordenar, renombrar, ocultar, fondo"
        echo -e "  ${PURPLE}2)${NC} Boot-Repair - Reparación automática de GRUB y EFI"
        echo -e "  ${PURPLE}3)${NC} rEFInd - Gestor de arranque gráfico con todos los sistemas (UEFI)"
        echo -e "  ${PURPLE}4)${NC} Quitar rEFInd y volver a GRUB"
        echo -e "  ${PURPLE}5)${NC} ⬅️ Volver"
        echo -e "\n${YELLOW}ℹ Grub Customizer y Boot-Repair se pueden desinstalar desde la opción 18 del menú principal${NC}\n"
        read -r -p "📌 Opción (1-5): " tool_option
        case $tool_option in
            1) install_grub_customizer ;;
            2) install_boot_repair ;;
            3) install_refind ;;
            4) remove_refind ;;
            5) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
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
# OPCIÓN 15: RED, DNS Y DRIVERS (COLOR: AZUL)
# ============================================================

RESOLVED_DNS_CONF="/etc/systemd/resolved.conf.d/99-kubuntu-lite-dns.conf"
NM_WIFI_CONF="/etc/NetworkManager/conf.d/99-kubuntu-lite-wifi.conf"

# nombre|servidores (IPv4 e IPv6, con el nombre para DNS cifrado)|descripción
DNS_PROVIDERS=(
    "cloudflare|1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com|Cloudflare: el más rápido en casi todo el mundo, privado"
    "cloudflare-seguro|1.1.1.2#security.cloudflare-dns.com 1.0.0.2#security.cloudflare-dns.com 2606:4700:4700::1112#security.cloudflare-dns.com 2606:4700:4700::1002#security.cloudflare-dns.com|Cloudflare + bloqueo de malware"
    "google|8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google|Google Public DNS: muy estable"
    "quad9|9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net|Quad9: bloquea dominios maliciosos, sin registros"
    "adguard|94.140.14.14#dns.adguard-dns.com 94.140.15.15#dns.adguard-dns.com 2a10:50c0::ad1:ff#dns.adguard-dns.com 2a10:50c0::ad2:ff#dns.adguard-dns.com|AdGuard: bloquea anuncios y rastreadores"
)

dns_provider_field() {
    local name="$1" field="$2" entry
    for entry in "${DNS_PROVIDERS[@]}"; do
        if [ "${entry%%|*}" = "$name" ]; then
            cut -d'|' -f"$field" <<< "$entry"
            return 0
        fi
    done
    return 1
}

current_dns() {
    if [ -f "$RESOLVED_DNS_CONF" ]; then
        sed -n 's/^# Proveedor: //p' "$RESOLVED_DNS_CONF"
    else
        echo "automático (el del router)"
    fi
}

# Aplica el DNS globalmente con systemd-resolved (usado por Kubuntu) y DNS cifrado
# cuando el servidor lo permite. Si después no resuelve nombres, se deshace solo.
set_dns() {
    local name="$1" servers
    servers=$(dns_provider_field "$name" 2) || { log_error "Proveedor DNS desconocido: $name"; return 1; }
    if ! systemctl is-active --quiet systemd-resolved; then
        log_error "systemd-resolved no está activo; no se puede cambiar el DNS de forma segura"
        return 1
    fi

    sudo install -d -m 0755 /etc/systemd/resolved.conf.d
    # Domains=~. hace que se use este DNS para todo, en lugar del que da el router
    printf '# Proveedor: %s\n[Resolve]\nDNS=%s\nDomains=~.\nDNSOverTLS=opportunistic\n' "$name" "$servers" \
        | sudo tee "$RESOLVED_DNS_CONF" > /dev/null
    run "No se pudo reiniciar systemd-resolved" sudo systemctl restart systemd-resolved || return 1

    sleep 1
    if getent hosts ubuntu.com > /dev/null; then
        log_success "DNS cambiado a $name (cifrado si el servidor lo permite)"
    else
        log_error "Con $name no se resuelven nombres: se vuelve al DNS automático"
        reset_dns
        return 1
    fi
}

reset_dns() {
    sudo rm -f "$RESOLVED_DNS_CONF"
    run "No se pudo reiniciar systemd-resolved" sudo systemctl restart systemd-resolved \
        && log_success "DNS automático restaurado"
}

# Mide la latencia a cada proveedor (ping al primer servidor IPv4) y deja el
# nombre del más rápido en FASTEST_DNS
measure_dns() {
    local entry name ip avg best=999999
    FASTEST_DNS=""
    echo -e "${BLUE}⏱ Midiendo latencia de cada DNS...${NC}"
    for entry in "${DNS_PROVIDERS[@]}"; do
        name=${entry%%|*}
        ip=$(cut -d'|' -f2 <<< "$entry" | cut -d' ' -f1 | cut -d'#' -f1)
        avg=$(LC_ALL=C ping -c 3 -W 1 -q "$ip" 2>/dev/null | awk -F'/' '/^rtt|^round-trip/ {print $5}')
        if [ -n "$avg" ]; then
            printf "  %-18s %8s ms\n" "$name" "$avg"
            if awk -v a="$avg" -v b="$best" 'BEGIN {exit !(a < b)}'; then
                best=$avg
                FASTEST_DNS=$name
            fi
        else
            printf "  %-18s %8s\n" "$name" "sin respuesta"
        fi
    done
    [ -n "$FASTEST_DNS" ]
}

set_fastest_dns() {
    if ! measure_dns; then
        log_error "Ningún DNS respondió (¿hay conexión a internet?)"
        return 1
    fi
    echo -e "${GREEN}🏆 Más rápido: $FASTEST_DNS${NC}"
    set_dns "$FASTEST_DNS"
}

# BBR: algoritmo de congestión TCP de Google. Mejora la velocidad y la latencia
# sobre todo en Wi-Fi y conexiones con pérdidas.
# Versión de BBR que ofrece el kernel: bbr (Ubuntu, XanMod), bbr3 (Liquorix) o bbr2
bbr_algorithm() {
    local algo
    for algo in bbr bbr3 bbr2; do
        if grep -qw "$algo" /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
            echo "$algo"
            return 0
        fi
    done
    return 1
}

enable_bbr() {
    local kernel algo
    kernel=$(uname -r)
    # Algunos kernels (XanMod, Liquorix...) traen BBR incluido: no hay módulo que cargar
    if ! algo=$(bbr_algorithm); then
        if ! sudo modprobe tcp_bbr >> "$LOG_FILE" 2>&1 || ! algo=$(bbr_algorithm); then
            if [ ! -d "/lib/modules/$kernel/kernel" ]; then
                log_error "Faltan los módulos del kernel en uso ($kernel): reinicia y vuelve a intentarlo"
            else
                log_error "El kernel $kernel no incluye BBR (disponibles: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null))"
            fi
            return 1
        fi
    fi
    # Si BBR es un módulo, se carga en cada arranque
    if [ "$algo" = "bbr" ] && modinfo tcp_bbr &> /dev/null; then
        echo tcp_bbr | sudo tee /etc/modules-load.d/kubuntu-lite-bbr.conf > /dev/null
    fi
    set_sysctl net.core.default_qdisc fq
    set_sysctl net.ipv4.tcp_congestion_control "$algo"
    log_success "TCP BBR activado ($algo)"
}

disable_bbr() {
    sudo rm -f /etc/modules-load.d/kubuntu-lite-bbr.conf
    sudo sed -i '/^net\.core\.default_qdisc/d; /^net\.ipv4\.tcp_congestion_control/d' "$SYSCTL_FILE" 2>/dev/null
    # Valores por defecto de Ubuntu
    run "No se pudo restaurar TCP" sudo sysctl -w net.ipv4.tcp_congestion_control=cubic net.core.default_qdisc=fq_codel \
        && log_success "TCP vuelve a la configuración por defecto (cubic)"
}

# El ahorro de energía del Wi-Fi causa picos de latencia y microcortes
disable_wifi_powersave() {
    printf '[connection]\nwifi.powersave = 2\n' | sudo tee "$NM_WIFI_CONF" > /dev/null
    run "No se pudo recargar NetworkManager" sudo systemctl reload NetworkManager \
        && log_success "Ahorro de energía del Wi-Fi desactivado (se aplica al reconectar)"
}

enable_wifi_powersave() {
    sudo rm -f "$NM_WIFI_CONF"
    run "No se pudo recargar NetworkManager" sudo systemctl reload NetworkManager \
        && log_success "Ahorro de energía del Wi-Fi restaurado"
}

# Drivers privados recomendados por Ubuntu (NVIDIA, Wi-Fi Broadcom, etc.)
install_recommended_drivers() {
    echo -e "${BLUE}🔍 Buscando drivers recomendados para tu hardware...${NC}"
    apt_update
    apt_install ubuntu-drivers-common || return 1
    local list
    list=$(ubuntu-drivers list 2>/dev/null)
    if [ -z "$list" ]; then
        log_success "Tu hardware no necesita drivers adicionales"
        return 0
    fi
    echo -e "${BLUE}📋 Drivers disponibles:${NC}"
    sed 's/^/  • /' <<< "$list"
    run_visible "No se pudieron instalar los drivers" sudo ubuntu-drivers install \
        && log_success "Drivers recomendados instalados (requiere reinicio)"
}

# Firmware de BIOS/UEFI, SSD, docks, etc. desde LVFS
update_firmware() {
    apt_update
    command -v fwupdmgr &> /dev/null || apt_install fwupd || return 1
    run "No se pudo consultar el servicio de firmware" fwupdmgr refresh --force
    echo -e "${BLUE}📋 Actualizaciones de firmware disponibles:${NC}"
    if ! fwupdmgr get-updates 2>&1 | tee -a "$LOG_FILE"; then
        echo -e "${GREEN}✓ No hay actualizaciones de firmware${NC}"
        return 0
    fi
    if confirm "${BLUE}¿Instalar las actualizaciones de firmware? (no apagues el equipo durante el proceso)${NC}"; then
        run_visible "Falló la actualización de firmware" sudo fwupdmgr update -y --no-reboot-check \
            && log_success "Firmware actualizado (puede requerir reinicio)"
    fi
}

network_menu() {
    while true; do
        clear
        echo -e "${BLUE}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🌐 RED, DNS Y DRIVERS                         ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "${BLUE}🌐 DNS actual: ${BOLD}$(current_dns)${NC}"
        echo -e "${BLUE}📶 TCP: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)${NC}"
        echo -e "${YELLOW}ℹ Un DNS rápido acelera el inicio de cada página; no aumenta los Mbps contratados${NC}\n"
        echo -e "  ${BLUE}1)${NC} Elegir DNS (Cloudflare, Google, Quad9, AdGuard)"
        echo -e "  ${BLUE}2)${NC} Medir qué DNS es más rápido desde tu conexión y usarlo"
        echo -e "  ${BLUE}3)${NC} Restaurar DNS automático (el del router)"
        echo -e "  ${BLUE}4)${NC} Activar/desactivar TCP BBR (mejor velocidad en Wi-Fi y conexiones inestables)"
        echo -e "  ${BLUE}5)${NC} Activar/desactivar ahorro de energía del Wi-Fi (menos latencia y cortes)"
        echo -e "  ${BLUE}6)${NC} Drivers: detectar e instalar los recomendados (GPU, Wi-Fi...)"
        echo -e "  ${BLUE}7)${NC} Actualizar firmware (BIOS, SSD...)"
        echo -e "  ${BLUE}8)${NC} Volver"
        echo ""
        read -r -p "📌 Opción (1-8): " net_option

        case $net_option in
            1)
                local i=0 entry choice
                echo ""
                for entry in "${DNS_PROVIDERS[@]}"; do
                    i=$((i + 1))
                    echo -e "  ${BLUE}${i})${NC} $(cut -d'|' -f3 <<< "$entry")"
                done
                echo -e "\n${YELLOW}⚠ Si usas una VPN de trabajo con nombres internos, puede que necesites el DNS automático${NC}"
                read -r -p "📌 Proveedor: " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#DNS_PROVIDERS[@]} ]; then
                    entry=${DNS_PROVIDERS[$((choice - 1))]}
                    set_dns "${entry%%|*}"
                else
                    log_error "Opción inválida"
                fi
                ;;
            2) set_fastest_dns ;;
            3) reset_dns ;;
            4)
                if [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" == bbr* ]]; then
                    confirm "${BLUE}BBR ya está activo. ¿Desactivarlo?${NC}" && disable_bbr
                else
                    enable_bbr
                fi
                ;;
            5)
                if [ -f "$NM_WIFI_CONF" ]; then
                    confirm "${BLUE}El ahorro del Wi-Fi ya está desactivado. ¿Restaurarlo?${NC}" && enable_wifi_powersave
                else
                    disable_wifi_powersave
                fi
                ;;
            6) install_recommended_drivers ;;
            7) update_firmware ;;
            8) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 16: ENERGÍA Y RENDIMIENTO (COLOR: AMARILLO)
# ============================================================

is_laptop() {
    ls /sys/class/power_supply/BAT* &> /dev/null
}

current_power_profile() {
    if command -v tlp &> /dev/null && systemctl is-enabled --quiet tlp 2>/dev/null; then
        echo "TLP"
    elif command -v powerprofilesctl &> /dev/null; then
        powerprofilesctl get 2>/dev/null
    else
        echo "desconocido"
    fi
}

# Perfiles de power-profiles-daemon: performance | balanced | power-saver
power_profiles_available() {
    powerprofilesctl list 2>/dev/null | grep -oE '^[ *]*[a-z-]+:' | tr -d ' *:' | tr '\n' ' '
}

# Perfil de rendimiento para juegos. Si el equipo no lo ofrece (depende de la CPU y la
# BIOS) no es un error: GameMode ya pone la CPU al máximo mientras hay un juego abierto.
set_gaming_power() {
    if command -v powerprofilesctl &> /dev/null && powerprofilesctl list 2>/dev/null | grep -q 'performance:'; then
        set_power_profile performance
        return
    fi
    log_warning "Tu equipo no ofrece el perfil de energía 'rendimiento' (depende de la CPU y la BIOS)"
    echo -e "  ${YELLOW}ℹ No hace falta: GameMode pone la CPU al máximo automáticamente mientras juegas${NC}"
}

set_power_profile() {
    local profile="$1"
    if ! command -v powerprofilesctl &> /dev/null; then
        log_error "power-profiles-daemon no está instalado (¿usas TLP?)"
        return 1
    fi
    if ! powerprofilesctl list 2>/dev/null | grep -q "$profile:"; then
        log_error "Tu equipo no admite el perfil '$profile' (disponibles: $(power_profiles_available))"
        return 1
    fi
    run "No se pudo cambiar el perfil de energía" powerprofilesctl set "$profile" \
        && log_success "Perfil de energía: $profile"
}

install_tlp() {
    echo -e "${YELLOW}ℹ TLP reemplaza a power-profiles-daemon: el selector de perfiles de Plasma desaparecerá${NC}"
    apt_update
    apt_install_recorded tlp tlp-rdw || return 1
    run "No se pudo activar TLP" sudo systemctl enable --now tlp \
        && log_success "TLP activado (para volver: sudo apt install power-profiles-daemon)"
}

# Portátil: TLP. Escritorio: perfil de ahorro de power-profiles-daemon
enable_power_saving() {
    if is_laptop; then
        install_tlp
    else
        set_power_profile power-saver
    fi
}

baloo_cmd() {
    command -v balooctl6 || command -v balooctl
}

# Baloo indexa todos los archivos para la búsqueda: consume CPU, disco y batería
disable_baloo() {
    local cmd
    cmd=$(baloo_cmd) || { echo -e "  ${YELLOW}ℹ Baloo no está instalado${NC}"; return 0; }
    run "No se pudo desactivar Baloo" "$cmd" disable && log_success "Indexador de archivos Baloo desactivado"
}

enable_baloo() {
    local cmd
    cmd=$(baloo_cmd) || { log_error "Baloo no está instalado"; return 1; }
    run "No se pudo activar Baloo" "$cmd" enable && log_success "Indexador de archivos Baloo activado"
}

install_gaming_tools() {
    apt_update
    # GameMode: el juego pide máximo rendimiento al sistema. MangoHud: FPS y temperaturas en pantalla
    apt_install_recorded gamemode mangohud || return 1
    # Valor que usan SteamOS y Fedora: evita cierres en juegos modernos (Proton)
    set_sysctl vm.max_map_count 1048576
    log_success "GameMode y MangoHud instalados (en Steam: gamemoderun mangohud %command%)"
}

power_menu() {
    while true; do
        clear
        echo -e "${YELLOW}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🔋 ENERGÍA Y RENDIMIENTO                      ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "${YELLOW}⚡ Perfil actual: ${BOLD}$(current_power_profile)${NC}"
        is_laptop && echo -e "${YELLOW}💻 Portátil detectado${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} Rendimiento máximo"
        echo -e "  ${YELLOW}2)${NC} Equilibrado"
        echo -e "  ${YELLOW}3)${NC} Ahorro de energía"
        echo -e "  ${YELLOW}4)${NC} TLP: ahorro avanzado de batería para portátiles"
        echo -e "  ${YELLOW}5)${NC} Activar/desactivar indexador de archivos Baloo"
        echo -e "  ${YELLOW}6)${NC} Herramientas de juego (GameMode y MangoHud)"
        echo -e "  ${YELLOW}7)${NC} Volver"
        echo ""
        read -r -p "📌 Opción (1-7): " power_option

        case $power_option in
            1) set_power_profile performance ;;
            2) set_power_profile balanced ;;
            3) set_power_profile power-saver ;;
            4) confirm "${YELLOW}¿Instalar TLP?${NC}" && install_tlp ;;
            5)
                local cmd
                if cmd=$(baloo_cmd) && "$cmd" status 2>/dev/null | grep -qi 'disabled\|desactivad'; then
                    enable_baloo
                else
                    disable_baloo
                fi
                ;;
            6) install_gaming_tools ;;
            7) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 17: PERFILES AUTOMÁTICOS (COLOR: PÚRPURA)
# ============================================================

PROFILES=(
    "productividad|Oficina y uso diario: herramientas, RAM, DNS rápido, sin juegos"
    "gaming|Juegos: drivers, kernel Liquorix, GameMode, máximo rendimiento, red de baja latencia"
    "ahorro|Ahorro de energía: TLP en portátiles, sin indexador, ZRAM"
    "desarrollo|Programación: git, compiladores, Python, VSCode, ajustes para IDEs"
    "minimalista|Estilo KDE Neon: sin kubuntu-desktop, sin Snap, Firefox .deb, Plasma más nuevo"
)

# Pasos de cada perfil: "Descripción|función [argumentos]"
profile_steps() {
    case $1 in
        productividad) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Quitar juegos preinstalados|remove_apps_with_progress kmahjongg kmines kpat ksudoku
Instalar herramientas (git, htop, fastfetch, timeshift, vim...)|install_optional_with_progress git curl wget htop fastfetch timeshift vim
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar ZRAM|enable_zram
Activar TRIM semanal para SSD|enable_trim
Usar el DNS más rápido (medido)|set_fastest_dns
Activar TCP BBR|enable_bbr
EOF
        ;;
        gaming) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Instalar drivers recomendados (GPU, Wi-Fi...)|install_recommended_drivers
Kernel Liquorix (se omite si Secure Boot está activo)|install_liquorix_kernel
Instalar GameMode y MangoHud|install_gaming_tools
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar ZRAM|enable_zram
Perfil de energía: rendimiento máximo (o GameMode al jugar)|set_gaming_power
Desactivar indexador Baloo|disable_baloo
Wi-Fi sin ahorro de energía (menos latencia)|disable_wifi_powersave
Activar TCP BBR|enable_bbr
Usar el DNS más rápido (medido)|set_fastest_dns
EOF
        ;;
        ahorro) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Ahorro de energía (TLP en portátil, perfil de ahorro en PC)|enable_power_saving
Desactivar indexador Baloo|disable_baloo
Activar ZRAM (menos escrituras en disco)|enable_zram
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar TRIM semanal para SSD|enable_trim
EOF
        ;;
        desarrollo) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Instalar herramientas (git, build-essential, Python, VSCode...)|install_optional_with_progress git curl wget vim htop build-essential python3-pip python3-venv code
Más archivos vigilados para IDEs (inotify)|set_sysctl fs.inotify.max_user_watches 524288
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar ZRAM|enable_zram
Activar TRIM semanal para SSD|enable_trim
Activar TCP BBR|enable_bbr
Usar el DNS más rápido (medido)|set_fastest_dns
EOF
        ;;
        minimalista) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Quitar meta-paquete kubuntu-desktop (las apps se conservan)|remove_kubuntu_meta
Quitar apps preinstaladas (juegos, suite PIM, IRC, torrent...)|remove_apps_with_progress kmahjongg kmines kpat ksudoku kmail kontact korganizer kaddressbook kalarm knotes akregator konversation ktorrent k3b dragonplayer juk kmouth kteatime ktimer plasma-welcome kubuntu-docs kubuntu-web-shortcuts
Eliminar Snap por completo (se conservan los perfiles de Firefox)|do_snap_removal
Instalar Firefox .deb de Mozilla|install_firefox_deb
Activar KDE Rolling Release (backports)|enable_backports
Actualizar a la versión más nueva de Plasma|do_system_update
Desactivar indexador Baloo|disable_baloo
Activar ZRAM|enable_zram
EOF
        ;;
    esac
}

list_profiles() {
    local entry
    echo -e "${PURPLE}📋 Perfiles disponibles:${NC}\n"
    for entry in "${PROFILES[@]}"; do
        printf "  ${PURPLE}%-14s${NC} %s\n" "${entry%%|*}" "${entry#*|}"
    done
}

run_profile() {
    local name="$1" steps=() line desc cmd i=0 ok=0 results=() start
    mapfile -t steps < <(profile_steps "$name")
    if [ ${#steps[@]} -eq 0 ]; then
        log_error "Perfil desconocido: $name"
        list_profiles
        return 1
    fi

    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    printf "║                    🚀 PERFIL: %-35s║\n" "${name^^}"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${PURPLE}📋 Se aplicará lo siguiente:${NC}\n"
    for line in "${steps[@]}"; do
        i=$((i + 1))
        echo -e "  ${PURPLE}$(printf '%2s' "$i").${NC} ${line%%|*}"
    done
    echo ""

    if ! $ASSUME_YES; then
        local response
        echo -e -n "${PURPLE}¿Aplicar el perfil $name? Puede tardar varios minutos (s/n): ${NC}"
        read -r response
        [[ "$response" =~ ^([sSyY]|[sS][iI]|[sS]í|[sS]Í)$ ]] || return 0
    fi

    # Durante el perfil no hay preguntas: las confirmaciones internas responden "no"
    local was_auto=$AUTO_MODE
    AUTO_MODE=true
    start=$(date +%s)
    i=0
    for line in "${steps[@]}"; do
        i=$((i + 1))
        desc=${line%%|*}
        read -r -a cmd <<< "${line#*|}"
        log_title "[$i/${#steps[@]}] $desc"
        if "${cmd[@]}"; then
            results+=("${GREEN}✓${NC} $desc")
            ok=$((ok + 1))
        else
            results+=("${RED}✗${NC} $desc")
        fi
    done
    AUTO_MODE=$was_auto

    echo ""
    echo -e "${PURPLE}${BOLD}📊 Resumen del perfil $name ($(( ($(date +%s) - start) / 60 )) min):${NC}\n"
    printf '  %b\n' "${results[@]}"
    echo ""
    if [ "$ok" -eq ${#steps[@]} ]; then
        log_success "Perfil $name aplicado por completo"
    else
        log_warning "$ok de ${#steps[@]} pasos completados. Detalles en: $LOG_FILE"
    fi
    echo -e "${YELLOW}⚠ Reinicia para aplicar todos los cambios${NC}"
    [ "$ok" -eq ${#steps[@]} ]
}

profiles_menu() {
    local i entry choice
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 PERFILES AUTOMÁTICOS                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${PURPLE}Aplican varias optimizaciones de una vez, sin preguntas intermedias.${NC}\n"
    i=0
    for entry in "${PROFILES[@]}"; do
        i=$((i + 1))
        printf "  ${PURPLE}%s)${NC} %-14s %s\n" "$i" "${entry%%|*}" "${entry#*|}"
    done
    echo -e "  ${PURPLE}$((i + 1)))${NC} Volver"
    echo -e "\n${YELLOW}💡 También desde terminal: ./Kubuntu-clean.sh --perfil gaming${NC}\n"
    read -r -p "📌 Opción: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#PROFILES[@]} ]; then
        entry=${PROFILES[$((choice - 1))]}
        run_profile "${entry%%|*}"
        pause
    fi
}

# ============================================================
# OPCIÓN 18: DESHACER OPTIMIZACIONES (COLOR: ROJO)
# ============================================================

# Programas que el script puede instalar. Sirve para ofrecer también los que se
# instalaron antes de que existiera el registro. No incluye paquetes del sistema
# que Ubuntu ya trae (python3, curl, wget): quitarlos podría romper otras cosas.
SCRIPT_PROGRAMS=(filezilla code virtualbox google-chrome-stable telegram-desktop python3-pip
    python3-venv git htop fastfetch timeshift gparted vim discord spotify-client obs-studio
    qrca build-essential alacritty gamemode mangohud tlp tlp-rdw zram-tools corectrl
    nvidia-cuda-toolkit grub-customizer boot-repair refind)

remove_installed_programs() {
    local logged=() known=() entries=() p desc
    # shellcheck disable=SC2046  # lista de paquetes: se separa a propósito
    [ -f "$INSTALLED_LIST" ] && mapfile -t logged < <(installed_pkgs $(cat "$INSTALLED_LIST"))
    mapfile -t known < <(installed_pkgs "${SCRIPT_PROGRAMS[@]}")

    for p in "${logged[@]}"; do
        desc=$(dpkg-query -W -f='${binary:Summary}' "$p" 2>/dev/null)
        entries+=("$p|${desc:-instalado por el script}")
    done
    for p in "${known[@]}"; do
        printf '%s\n' "${logged[@]}" | grep -qx -- "$p" && continue
        entries+=("$p|(sin registro: puede que ya lo tuvieras) $(dpkg-query -W -f='${binary:Summary}' "$p" 2>/dev/null)")
    done

    if [ ${#entries[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No hay programas instalados por el script${NC}"
        return 0
    fi
    if ! checklist_select "Quitar programas" "Marca los programas que quieres DESINSTALAR" "${entries[@]}" \
        || [ ${#CHOSEN[@]} -eq 0 ]; then
        clear
        echo -e "${YELLOW}ℹ No seleccionaste ningún programa${NC}"
        return 0
    fi
    clear

    # Lo que apt quitaría de verdad: puede arrastrar otros paquetes que dependen de estos
    local extra=()
    mapfile -t extra < <(LC_ALL=C apt-get -s purge "${CHOSEN[@]}" 2>/dev/null \
        | awk '/^(Purg|Remv) / {print $2}' | grep -vxF -f <(printf '%s\n' "${CHOSEN[@]}"))
    echo -e "${RED}📋 Se desinstalarán:${NC}"
    printf "  ${RED}•${NC} %s\n" "${CHOSEN[@]}"
    if [ ${#extra[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}⚠ También se quitarán porque dependen de ellos:${NC}"
        printf "  ${YELLOW}•${NC} %s\n" "${extra[@]}"
    fi
    echo ""
    if ! confirm "${RED}¿Desinstalar?${NC}"; then
        echo -e "${YELLOW}ℹ Cancelado: no se desinstaló nada${NC}"
        return 0
    fi

    apt_purge "${CHOSEN[@]}" || return 1
    forget_installed "${CHOSEN[@]}" "${extra[@]}"
    log_success "Desinstalado: ${CHOSEN[*]}"
    run "Falló la limpieza de dependencias" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge

    # Sin TLP, el selector de energía de Plasma necesita power-profiles-daemon
    if printf '%s\n' "${CHOSEN[@]}" | grep -qx tlp; then
        apt_update
        apt_install power-profiles-daemon \
            && run "No se pudo activar power-profiles-daemon" sudo systemctl enable --now power-profiles-daemon \
            && log_success "Vuelve el selector de energía de Plasma"
    fi
}

# Valor de fábrica de los ajustes que cambia el script (los demás vuelven al reiniciar)
sysctl_default() {
    case $1 in
        vm.swappiness) echo 60 ;;
        vm.vfs_cache_pressure) echo 100 ;;
        net.ipv4.tcp_congestion_control) echo cubic ;;
        net.core.default_qdisc) echo fq_codel ;;
        *) return 1 ;;
    esac
}

restore_sysctl_defaults() {
    if [ ! -s "$SYSCTL_FILE" ]; then
        echo -e "  ${GREEN}✓ No hay ajustes del sistema cambiados por el script${NC}"
        return 0
    fi
    local key value def
    echo -e "${YELLOW}📋 Ajustes que vuelven a su valor original:${NC}"
    while read -r key _ value; do
        [ -n "$key" ] || continue
        if def=$(sysctl_default "$key"); then
            sudo sysctl -w "$key=$def" >> "$LOG_FILE" 2>&1
            echo -e "  • $key: $value → $def"
        else
            echo -e "  • $key: $value → valor de fábrica (al reiniciar)"
        fi
    done < "$SYSCTL_FILE"
    sudo rm -f "$SYSCTL_FILE" /etc/modules-load.d/kubuntu-lite-bbr.conf
    # Vuelve a aplicar los valores que definen Ubuntu y los demás paquetes
    run "No se pudieron recargar los ajustes del sistema" sudo sysctl --system \
        && log_success "Ajustes del sistema restaurados"
}

disable_zram() {
    if ! installed_pkgs zram-tools | grep -qx zram-tools; then
        echo -e "  ${GREEN}✓ ZRAM no está instalado${NC}"
        return 0
    fi
    run "No se pudo detener ZRAM" sudo systemctl disable --now zramswap.service \
        && log_success "ZRAM desactivado"
    if confirm "${YELLOW}¿Desinstalar también zram-tools?${NC}"; then
        apt_purge zram-tools && forget_installed zram-tools
    fi
}

remove_tlp() {
    if ! installed_pkgs tlp | grep -qx tlp; then
        echo -e "  ${GREEN}✓ TLP no está instalado${NC}"
        return 0
    fi
    local pkgs=()
    mapfile -t pkgs < <(installed_pkgs tlp tlp-rdw)
    apt_purge "${pkgs[@]}" || return 1
    forget_installed tlp tlp-rdw
    apt_update
    apt_install power-profiles-daemon \
        && run "No se pudo activar power-profiles-daemon" sudo systemctl enable --now power-profiles-daemon \
        && log_success "TLP quitado: vuelve el selector de energía de Plasma"
}

# Muestra qué ajustes del script están activos. Devuelve 1 si no hay ninguno.
show_tweaks_status() {
    local changed=0 cmd
    changed_line() { echo -e "  ${YELLOW}⚙ $1${NC}"; changed=$((changed + 1)); }
    factory_line() { echo -e "  ${GREEN}✓ $1${NC}"; }

    echo -e "${YELLOW}📋 Estado actual de los ajustes:${NC}\n"
    if [ -s "$SYSCTL_FILE" ]; then
        changed_line "Ajustes del sistema cambiados:"
        sed 's/^/      /' "$SYSCTL_FILE"
    else
        factory_line "Ajustes del sistema (RAM, inotify, BBR): de fábrica"
    fi
    if [ -f "$RESOLVED_DNS_CONF" ]; then changed_line "DNS: $(current_dns)"; else factory_line "DNS: automático (el del router)"; fi
    if [ -f "$NM_WIFI_CONF" ]; then changed_line "Wi-Fi: ahorro de energía desactivado"; else factory_line "Wi-Fi: de fábrica"; fi
    if installed_pkgs zram-tools | grep -qx zram-tools; then changed_line "ZRAM: instalado"; else factory_line "ZRAM: no instalado"; fi
    if installed_pkgs tlp | grep -qx tlp; then
        changed_line "Energía: TLP instalado"
    elif command -v powerprofilesctl &> /dev/null && [ "$(powerprofilesctl get 2>/dev/null)" != "balanced" ]; then
        changed_line "Energía: perfil $(powerprofilesctl get 2>/dev/null)"
    else
        factory_line "Energía: equilibrado"
    fi
    if cmd=$(baloo_cmd) && "$cmd" status 2>/dev/null | grep -qi 'disabled\|desactivad'; then
        changed_line "Baloo (indexador de archivos): desactivado"
    else
        factory_line "Baloo: activo"
    fi
    if [ -e /var/lib/man-db/auto-update ]; then factory_line "Indexación de manuales: activa"; else changed_line "Indexación de manuales: desactivada"; fi
    echo ""
    [ "$changed" -gt 0 ]
}

# Todo lo que el script cambia en la configuración, sin desinstalar programas
restore_all_tweaks() {
    echo -e "${YELLOW}🔧 Ajustes del sistema (RAM, inotify, BBR...)${NC}"
    restore_sysctl_defaults
    echo -e "${YELLOW}🌐 DNS y Wi-Fi${NC}"
    if [ -f "$RESOLVED_DNS_CONF" ]; then reset_dns; else echo -e "  ${GREEN}✓ El DNS ya es el automático${NC}"; fi
    if [ -f "$NM_WIFI_CONF" ]; then enable_wifi_powersave; else echo -e "  ${GREEN}✓ El ahorro del Wi-Fi ya está como de fábrica${NC}"; fi
    echo -e "${YELLOW}💾 ZRAM${NC}"
    disable_zram
    echo -e "${YELLOW}🔋 Energía${NC}"
    if installed_pkgs tlp | grep -qx tlp; then
        confirm "${YELLOW}¿Quitar TLP y volver al selector de energía de Plasma?${NC}" && remove_tlp
    elif command -v powerprofilesctl &> /dev/null; then
        set_power_profile balanced
    fi
    echo -e "${YELLOW}🔎 Indexadores${NC}"
    local cmd
    if cmd=$(baloo_cmd) && "$cmd" status 2>/dev/null | grep -qi 'disabled\|desactivad'; then
        enable_baloo
    else
        echo -e "  ${GREEN}✓ Baloo ya está activo${NC}"
    fi
    if [ -e /var/lib/man-db/auto-update ]; then
        echo -e "  ${GREEN}✓ La indexación de manuales ya está activa${NC}"
    else
        enable_mandb
    fi
}

undo_menu() {
    while true; do
        clear
        echo -e "${RED}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    ↩️ DESHACER OPTIMIZACIONES                     ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "  ${RED}1)${NC} 📦 Ver y quitar PROGRAMAS instalados por el script"
        echo -e "  ${RED}2)${NC} 🔧 Restaurar ajustes del sistema (RAM, inotify, BBR...) a sus valores de fábrica"
        echo -e "  ${RED}3)${NC} 💾 Desactivar ZRAM"
        echo -e "  ${RED}4)${NC} 🔋 Quitar TLP y volver al selector de energía de Plasma"
        echo -e "  ${RED}5)${NC} 📋 Ver qué AJUSTES están cambiados y restaurarlos todos (no toca programas)"
        echo -e "  ${RED}6)${NC} ⬅️ Volver"
        echo -e "\n${YELLOW}ℹ Otros cambios se deshacen en su menú: kernel (4), Kubuntu original (9),${NC}"
        echo -e "${YELLOW}  Snap (11), accesos directos (14), DNS/BBR/Wi-Fi (15), energía y Baloo (16)${NC}\n"
        read -r -p "📌 Opción (1-6): " undo_option

        case $undo_option in
            1) remove_installed_programs ;;
            2) restore_sysctl_defaults ;;
            3) disable_zram ;;
            4) remove_tlp ;;
            5)
                if ! show_tweaks_status; then
                    echo -e "${GREEN}✓ No hay ajustes cambiados: todo está como de fábrica${NC}"
                elif confirm "${RED}¿Restaurar a fábrica los ajustes marcados con ⚙?${NC}"; then
                    restore_all_tweaks
                else
                    echo -e "${YELLOW}ℹ Cancelado: no se cambió nada${NC}"
                fi
                ;;
            6) return 0 ;;
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
        echo -e "  ${CYAN}15)${NC} 🌐 Red, DNS y drivers"
        echo -e "  ${CYAN}16)${NC} 🔋 Energía y rendimiento"
        echo -e "  ${CYAN}17)${NC} 🚀 PERFILES AUTOMÁTICOS (gaming, productividad...)"
        echo -e "  ${CYAN}18)${NC} ↩️  Deshacer optimizaciones / quitar programas"
        echo -e "  ${CYAN}19)${NC} ❌ Salir"
        echo ""
        read -r -p "🔢 Opcion (1-19): " option

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
            15) network_menu ;;
            16) power_menu ;;
            17) profiles_menu ;;
            18) undo_menu ;;
            19)
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

usage() {
    cat << EOF
Uso: $0 [opciones]

  (sin opciones)          Menú interactivo
  -p, --perfil NOMBRE     Aplica un perfil automáticamente
  -y, --si                No pedir confirmación antes de aplicar el perfil
  -l, --perfiles          Lista los perfiles disponibles
  -h, --ayuda             Muestra esta ayuda

Ejemplos:
  $0 --perfil gaming
  $0 --perfil productividad --si
EOF
}

PROFILE=""
while [ $# -gt 0 ]; do
    case $1 in
        -p|--perfil)
            PROFILE="$2"
            if [ -z "$PROFILE" ]; then
                echo -e "${RED}❌ Falta el nombre del perfil${NC}"
                list_profiles
                exit 1
            fi
            shift ;;
        -y|--si) ASSUME_YES=true ;;
        -l|--perfiles) list_profiles; exit 0 ;;
        -h|--ayuda) usage; exit 0 ;;
        *) echo -e "${RED}❌ Opción desconocida: $1${NC}\n"; usage; exit 1 ;;
    esac
    shift
done

if [ -n "$PROFILE" ] && [ -z "$(profile_steps "$PROFILE")" ]; then
    echo -e "${RED}❌ Perfil desconocido: $PROFILE${NC}\n"
    list_profiles
    exit 1
fi

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

if [ -n "$PROFILE" ]; then
    run_profile "$PROFILE"
    exit $?
fi

main_menu
