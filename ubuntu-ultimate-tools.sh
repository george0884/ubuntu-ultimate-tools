#!/bin/bash

# ============================================================
# Script: Ubuntu Ultimate Tools
# Descripción: Transforma cualquier sabor de Ubuntu en un sistema minimalista
#              con optimizaciones de rendimiento extremo
# Versión: 7.0 - MENÚS UNIFORMES Y ESTÉTICA CUIDADA
# Autor: Old The One Deluxe (@george0884)
# Licencia: GNU GPL v3 o posterior (ver archivo LICENSE)
# SPDX-License-Identifier: GPL-3.0-or-later
# ============================================================

# ============================================================
# CONFIGURACIÓN INICIAL
# ============================================================

LOG_FILE="$HOME/ubuntu-ultimate-tools.log"
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")

# Estado guardado entre ejecuciones (lo usa "Revertir")
STATE_DIR="$HOME/.local/share/ubuntu-ultimate-tools"
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
    echo "║                    UBUNTU ULTIMATE TOOLS                         ║"
    echo "║              Transformación y Optimización Extrema               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${GREEN}🐧 Detectado: ${FLAVOR_NAME} $(os_release_value VERSION_ID) · ${DESKTOP_NAME}${NC}"
    echo -e "${YELLOW}📁 Log activo: $LOG_FILE${NC}\n"
}

# Modo automático (perfiles): sin pausas ni preguntas; las confirmaciones responden "no"
AUTO_MODE=false
ASSUME_YES=false
ACTIVE_PROFILE=""

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
    if [ "${FORCE_YES:-false}" = true ]; then
        echo -e "$prompt ${YELLOW}→ sí (ya confirmado)${NC}"
        return 0
    fi
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
# para poder quitarlos después desde "Deshacer optimizaciones" (opción 17).
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

# Dependencias y recomendaciones del meta-paquete del sabor (las apps originales)
flavor_meta_pkgs() {
    [ -n "$FLAVOR_META" ] || return 0
    apt-cache depends "$FLAVOR_META" 2>/dev/null \
        | awk '$1 ~ /^\|?(Depends|Recommends):$/ && $2 !~ /^</ {print $2}' | sort -u
}

SYSCTL_FILE="/etc/sysctl.d/99-ubuntu-ultimate-tools.conf"
BBR_MODULES_FILE="/etc/modules-load.d/ubuntu-ultimate-tools-bbr.conf"

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
# Entradas "paquete|descripción" o "paquete|descripción|ON" (casilla ya marcada);
# deja lo elegido en CHOSEN. Devuelve 1 si se cancela.
# Con CHECKLIST_NOTAGS=true no se muestra la columna de nombres internos.
# Si no hay whiptail (o no es una terminal interactiva) se elige escribiendo números.
checklist_select() {
    local title="$1" text="$2"
    shift 2
    local entries=("$@") args=() entry name desc status i=0 input num
    CHOSEN=()

    if command -v whiptail &> /dev/null && [ -t 0 ] && [ -t 1 ]; then
        for entry in "${entries[@]}"; do
            status=OFF
            [[ "$entry" == *"|ON" ]] && { status=ON; entry=${entry%|ON}; }
            name=${entry%%|*}
            desc=${entry#*|}
            # Sin el emoji inicial: whiptail calcula mal su ancho y descuadra la lista
            [[ "$desc" == *" "* ]] && [[ "${desc%% *}" != *[[:alnum:]]* ]] && desc=${desc#* }
            args+=("$name" "$desc" "$status")
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
            ${CHECKLIST_NOTAGS:+--notags} \
            --checklist "$text\n\nEspacio: marcar/desmarcar · Flechas: moverse · Enter: aceptar" \
            "$h" "$w" "$lh" "${args[@]}" 3>&1 1>&2 2>&3) || return 1
        read -r -a CHOSEN <<< "$(tr -d '"' <<< "$out")"
        return 0
    fi

    echo -e "${CYAN}$text${NC}\n"
    for entry in "${entries[@]}"; do
        i=$((i + 1))
        status=" "
        [[ "$entry" == *"|ON" ]] && { status="x"; entry=${entry%|ON}; }
        if [ -n "$CHECKLIST_NOTAGS" ]; then
            printf "  ${CYAN}[%2s]${NC} [%s] %s\n" "$i" "$status" "${entry#*|}"
        else
            printf "  ${CYAN}[%2s]${NC} [%s] %-22s - %s\n" "$i" "$status" "${entry%%|*}" "${entry#*|}"
        fi
    done
    echo -e "\n${CYAN}([x] = marcado ahora; escribe todos los que quieras dejar marcados; Enter = cancelar)${NC}"
    read -r -p "🔢 Números separados por espacio: " input
    # Sin respuesta no se cambia nada (no significa "desmarcar todo")
    [ -n "${input// /}" ] || return 1
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#entries[@]} ]; then
            CHOSEN+=("${entries[$((num - 1))]%%|*}")
        fi
    done
}

# ============================================================
# SABOR DE UBUNTU Y ESCRITORIO
# ============================================================

FLAVOR=""          # kubuntu, ubuntu, xubuntu, lubuntu, mate, budgie, cinnamon, unity, studio, edubuntu, kylin, server
FLAVOR_NAME=""     # Nombre para mostrar (Kubuntu, Xubuntu...)
FLAVOR_META=""     # Meta-paquete del sabor (kubuntu-desktop...)
DESKTOP=""         # kde, gnome, xfce, lxqt, mate, budgie, cinnamon, unity, ukui, none
DESKTOP_NAME=""    # Nombre del escritorio para mostrar

# sabor|nombre|meta-paquete|escritorio|nombre del escritorio|paquete que lo identifica si ya no está el meta-paquete
# El orden importa: Ubuntu Studio y Edubuntu instalan también otros meta-paquetes.
FLAVORS=(
    "studio|Ubuntu Studio|ubuntustudio-desktop|kde|KDE Plasma|ubuntustudio-default-settings"
    "edubuntu|Edubuntu|edubuntu-desktop|gnome|GNOME|edubuntu-default-settings"
    "kubuntu|Kubuntu|kubuntu-desktop|kde|KDE Plasma|plasma-workspace"
    "xubuntu|Xubuntu|xubuntu-desktop|xfce|Xfce|xfce4-session"
    "lubuntu|Lubuntu|lubuntu-desktop|lxqt|LXQt|lxqt-session"
    "mate|Ubuntu MATE|ubuntu-mate-desktop|mate|MATE|mate-session-manager"
    "budgie|Ubuntu Budgie|ubuntu-budgie-desktop|budgie|Budgie|budgie-desktop"
    "cinnamon|Ubuntu Cinnamon|ubuntucinnamon-desktop|cinnamon|Cinnamon|cinnamon"
    "unity|Ubuntu Unity|ubuntu-unity-desktop|unity|Unity|unity"
    "kylin|Ubuntu Kylin|ubuntukylin-desktop|ukui|UKUI|ukui-session-manager"
    "ubuntu|Ubuntu|ubuntu-desktop|gnome|GNOME|gnome-shell"
    "ubuntu|Ubuntu|ubuntu-desktop-minimal|gnome|GNOME|gnome-shell"
)

# Detecta el sabor por su meta-paquete o, si se quitó (opción 3), por su escritorio
detect_flavor() {
    local entry meta marker found=""
    for entry in "${FLAVORS[@]}"; do
        IFS='|' read -r _ _ meta _ _ marker <<< "$entry"
        if installed_pkgs "$meta" | grep -qx -- "$meta"; then found=$entry; break; fi
    done
    # Si se quitó con la opción 3, queda anotado: así un Ubuntu mínimo no se confunde con el completo
    if [ -z "$found" ] && [ -s "$REMOVED_LIST" ]; then
        for entry in "${FLAVORS[@]}"; do
            IFS='|' read -r _ _ meta _ _ _ <<< "$entry"
            if grep -qx -- "$meta" "$REMOVED_LIST"; then found=$entry; break; fi
        done
    fi
    if [ -z "$found" ]; then
        for entry in "${FLAVORS[@]}"; do
            IFS='|' read -r _ _ _ _ _ marker <<< "$entry"
            if installed_pkgs "$marker" | grep -qx -- "$marker"; then found=$entry; break; fi
        done
    fi
    if [ -n "$found" ]; then
        IFS='|' read -r FLAVOR FLAVOR_NAME FLAVOR_META DESKTOP DESKTOP_NAME _ <<< "$found"
    else
        FLAVOR=server FLAVOR_NAME="Ubuntu Server" FLAVOR_META="" DESKTOP=none DESKTOP_NAME="sin escritorio"
    fi
}

has_desktop() { [ "$FLAVOR" != server ]; }

# Aviso para las opciones que dependen de un escritorio concreto
desktop_only() {
    local needed="$1" what="$2"
    [[ " $needed " == *" $DESKTOP "* ]] && return 0
    log_warning "$what no está disponible en $FLAVOR_NAME ($DESKTOP_NAME)"
    return 1
}

# ------------------------------------------------------------
# Apps que se pueden eliminar. Salen de los meta-paquetes de cada sabor,
# SIN las piezas del escritorio (gestor de archivos, configuración, panel,
# sesión, ventanas, red, sonido, energía, notificaciones, portales...).
# Solo se muestran las que están instaladas.
# ------------------------------------------------------------

# Comunes a varios sabores
APPS_COMMON=(
    "libreoffice-core|📄 LibreOffice completo (quita todas sus apps)"
    "libreoffice-writer|📝 LibreOffice Writer (textos)"
    "libreoffice-calc|📊 LibreOffice Calc (hojas de cálculo)"
    "libreoffice-impress|📽️ LibreOffice Impress (presentaciones)"
    "libreoffice-draw|✏️ LibreOffice Draw (dibujo)"
    "libreoffice-math|➗ LibreOffice Math (fórmulas)"
    "thunderbird|📧 Thunderbird (correo)"
    "evolution|📧 Evolution (correo y calendario)"
    "geary|📧 Geary (correo)"
    "transmission-gtk|📥 Transmission (torrent)"
    "transmission-qt|📥 Transmission (torrent)"
    "ktorrent|📥 KTorrent (torrent)"
    "rhythmbox|🎵 Rhythmbox (música)"
    "lollypop|🎵 Lollypop (música)"
    "gnome-music|🎵 Música de GNOME"
    "elisa|🎵 Elisa (música)"
    "juk|🎵 JuK (música)"
    "cantata|🎵 Cantata (música MPD)"
    "goodvibes|📻 Goodvibes (radio por internet)"
    "gpodder|🎙️ gPodder (podcasts)"
    "totem|🎬 Vídeos de GNOME (Totem)"
    "showtime|🎬 Showtime (vídeos)"
    "celluloid|🎬 Celluloid (vídeos)"
    "parole|🎬 Parole (vídeos)"
    "vlc|🎬 VLC (multimedia)"
    "haruna|🎬 Haruna (vídeos)"
    "dragonplayer|🎬 Dragon Player (vídeos)"
    "mpv|🎬 mpv (multimedia ligero)"
    "shotwell|🖼️ Shotwell (fotos)"
    "gthumb|🖼️ gThumb (imágenes)"
    "gimp|🎨 GIMP (editor de imágenes)"
    "drawing|🎨 Drawing (dibujo simple)"
    "kolourpaint|🎨 KolourPaint (dibujo simple)"
    "cheese|📷 Cheese (cámara web)"
    "gnome-snapshot|📷 Cámara de GNOME"
    "guvcview|📷 guvcview (cámara web)"
    "webcamoid|📷 Webcamoid (cámara web)"
    "kamoso|📷 Kamoso (cámara web)"
    "remmina|🖥️ Remmina (escritorio remoto)"
    "krdc|🖥️ KRDC (escritorio remoto)"
    "vino|🖥️ Vino (compartir el escritorio por VNC)"
    "simple-scan|🖨️ Escáner de documentos"
    "skanlite|🖨️ Skanlite (escáner)"
    "skanpage|🖨️ Skanpage (escáner multipágina)"
    "deja-dup|💾 Déjà Dup (copias de seguridad)"
    "baobab|💾 Analizador de uso del disco"
    "gnome-disk-utility|💾 Discos (formatear y crear imágenes)"
    "partitionmanager|💾 Gestor de particiones de KDE"
    "gdebi|📦 GDebi (instalar paquetes .deb)"
    "synaptic|📦 Synaptic (gestor de paquetes)"
    "usb-creator-gtk|💿 Crear un USB de arranque"
    "usb-creator-kde|💿 Crear un USB de arranque"
    "k3b|💿 K3b (grabar CD/DVD)"
    "xfburn|💿 Xfburn (grabar CD/DVD)"
    "hexchat|💬 HexChat (IRC)"
    "quassel|💬 Quassel (IRC)"
    "konversation|💬 Konversation (IRC)"
    "neochat|💬 NeoChat (chat Matrix)"
    "onboard|⌨️ Onboard (teclado en pantalla)"
    "magnus|🔍 Magnus (lupa de pantalla)"
    "kmag|🔍 KMag (lupa de pantalla)"
    "gucharmap|🔣 Mapa de caracteres"
    "gnome-characters|🔣 Caracteres de GNOME"
    "kcharselect|🔣 Mapa de caracteres de KDE"
    "gnome-font-viewer|🔤 Visor de tipografías"
    "font-manager|🔤 Gestor de tipografías"
    "gnome-calendar|📆 Calendario de GNOME"
    "gnome-clocks|⏰ Relojes de GNOME"
    "gnome-weather|🌤️ Tiempo de GNOME"
    "gnome-maps|🗺️ Mapas de GNOME"
    "gnome-contacts|📇 Contactos de GNOME"
    "gnome-dictionary|📖 Diccionario de GNOME"
    "endeavour|✅ Endeavour (tareas)"
    "gnome-logs|📋 Registros del sistema (GNOME)"
    "ksystemlog|📋 Registros del sistema (KDE)"
    "yelp|❓ Ayuda de GNOME"
    "khelpcenter|❓ Centro de ayuda de KDE"
    "apport-gtk|🐞 Reporte de errores de Ubuntu"
    "apport-kde|🐞 Reporte de errores de Ubuntu"
    "seahorse|🔐 Contraseñas y claves (Seahorse)"
    "htop|📊 htop (monitor en la terminal)"
    "stacer|📊 Stacer (optimizador y monitor)"
    "git-cola|🧰 git-cola (interfaz gráfica de Git)"
    "xterm|💻 XTerm (terminal básica adicional)"
    "tilda|💻 Tilda (terminal desplegable)"
    "catfish|🔎 Catfish (buscador de archivos)"
    "kfind|🔎 KFind (buscador de archivos)"
    "gigolo|🌐 Gigolo (carpetas remotas)"
    "mugshot|👤 Mugshot (datos del usuario)"
    "xfce4-dict|📖 Diccionario de Xfce"
    "convertall|📐 ConvertAll (conversor de unidades)"
    "aisleriot|🃏 Solitarios (AisleRiot)"
    "gnome-mines|💣 Buscaminas de GNOME"
    "gnome-sudoku|🔢 Sudoku de GNOME"
    "gnome-mahjongg|🀄 Mahjongg de GNOME"
    "gnome-2048|🎲 2048 de GNOME"
    "gnome-chess|♟️ Ajedrez de GNOME"
    "sgt-launcher|🧩 Rompecabezas de Simon Tatham"
    "2048-qt|🎲 2048"
    "kmahjongg|🀄 Mahjongg de KDE"
    "kmines|💣 Buscaminas de KDE"
    "kpat|🃏 Solitarios de KDE"
    "ksudoku|🔢 Sudoku de KDE"
)

# Por escritorio
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_KDE=(
    "akregator|📰 Akregator (lector RSS)"
    "kaddressbook|📇 KAddressBook (contactos)"
    "kalarm|⏰ KAlarm (alarmas y recordatorios)"
    "kate|📝 Kate (editor de texto avanzado)"
    "kwrite|📝 KWrite (editor de texto)"
    "kmail|📧 KMail (correo)"
    "knotes|📋 KNotes (notas adhesivas)"
    "kontact|📅 Kontact (suite de correo, agenda y contactos)"
    "korganizer|📆 KOrganizer (calendario)"
    "kmouth|🗣️ KMouth (sintetizador de voz)"
    "kdf|💾 KDiskFree (uso de disco)"
    "kgpg|🔐 KGpg (claves GPG)"
    "kdeconnect|📱 KDE Connect (sincronizar con el móvil)"
    "kdenlive|🎬 Kdenlive (editor de vídeo)"
    "kompare|📊 Kompare (comparar archivos)"
    "kremotecontrol|🎮 Control remoto"
    "kruler|📏 KRuler (regla en pantalla)"
    "kteatime|🍵 KTeaTime (temporizador para el té)"
    "ktimer|⏱️ KTimer (temporizador)"
    "kwalletmanager|👛 Gestor de la cartera de contraseñas (la cartera sigue funcionando)"
    "kcalc|🧮 KCalc (calculadora)"
    "ark|🗜️ Ark (archivos comprimidos)"
    "okular|📖 Okular (visor de PDF)"
    "gwenview|🖼️ Gwenview (visor de imágenes)"
    "kde-spectacle|📸 Spectacle (capturas de pantalla)"
    "spectacle|📸 Spectacle (capturas de pantalla)"
    "plasma-systemmonitor|📊 Monitor del sistema"
    "kinfocenter|ℹ️ Centro de información"
    "qapt-deb-installer|📦 Instalador de paquetes .deb"
    "plasma-discover|🛒 Discover (tienda de aplicaciones)"
    "plasma-welcome|👋 Bienvenida de Plasma"
    "kubuntu-docs|📚 Documentación de Kubuntu"
    "kubuntu-web-shortcuts|🌐 Accesos web de Kubuntu"
    "kio-extras|⚠️ Protocolos KIO extra (miniaturas, móvil y red en Dolphin)"
    "kscreen|⚠️ Configuración de pantallas (sin ella no podrás cambiar la resolución)"
    "konsole|⚠️ Konsole (terminal: quítala solo si usas otra, como Alacritty)"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_GNOME=(
    "eog|🖼️ Visor de imágenes (Eye of GNOME)"
    "loupe|🖼️ Visor de imágenes (Loupe)"
    "evince|📖 Visor de documentos PDF"
    "papers|📖 Visor de documentos (Papers)"
    "gnome-text-editor|📝 Editor de texto"
    "gnome-calculator|🧮 Calculadora"
    "gnome-system-monitor|📊 Monitor del sistema"
    "file-roller|🗜️ Archivos comprimidos"
    "gnome-power-manager|🔋 Estadísticas de energía"
    "gnome-bluetooth-sendto|📶 Enviar archivos por Bluetooth"
    "gnome-shell-extension-manager|🧩 Gestor de extensiones"
    "gnome-browser-connector|🧩 Extensiones de GNOME desde el navegador"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_XFCE=(
    "mousepad|📝 Mousepad (editor de texto)"
    "ristretto|🖼️ Ristretto (visor de imágenes)"
    "atril|📖 Atril (visor de PDF)"
    "engrampa|🗜️ Engrampa (archivos comprimidos)"
    "mate-calc|🧮 Calculadora"
    "xfce4-screenshooter|📸 Capturas de pantalla"
    "xfce4-taskmanager|📊 Administrador de tareas"
    "menulibre|🗂️ Editor del menú"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_LXQT=(
    "featherpad|📝 FeatherPad (editor de texto)"
    "kcalc|🧮 KCalc (calculadora)"
    "okular|📖 Okular (visor de PDF)"
    "noblenote|📋 NobleNote (notas)"
    "qps|📊 Qps (monitor de procesos)"
    "qtpass|🔐 QtPass (contraseñas)"
    "screengrab|📸 ScreenGrab (capturas de pantalla)"
    "qlipper|📋 Qlipper (historial del portapapeles)"
    "redshift-qt|🌙 Redshift (luz nocturna)"
    "lxqt-archiver|🗜️ Archivos comprimidos"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_MATE=(
    "atril|📖 Atril (visor de PDF)"
    "eom|🖼️ Eye of MATE (visor de imágenes)"
    "pluma|📝 Pluma (editor de texto)"
    "mate-calc|🧮 Calculadora"
    "engrampa|🗜️ Engrampa (archivos comprimidos)"
    "mate-system-monitor|📊 Monitor del sistema"
    "mate-utils|🧰 Utilidades de MATE (capturas, diccionario, búsqueda)"
    "mate-user-guide|❓ Guía de MATE"
    "ubuntu-mate-guide|❓ Guía de Ubuntu MATE"
    "gufw|🛡️ Gufw (cortafuegos gráfico)"
    "redshift-gtk|🌙 Redshift (luz nocturna)"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_BUDGIE=(
    "gedit|📝 Gedit (editor de texto)"
    "atril|📖 Atril (visor de PDF)"
    "mate-calc|🧮 Calculadora"
    "mate-system-monitor|📊 Monitor del sistema"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_CINNAMON=(
    "gedit|📝 Gedit (editor de texto)"
    "evince|📖 Visor de documentos PDF"
    "file-roller|🗜️ Archivos comprimidos"
    "gnome-calculator|🧮 Calculadora"
    "gnome-system-monitor|📊 Monitor del sistema"
    "gnome-screenshot|📸 Capturas de pantalla"
    "gnome-software|🛒 Centro de software"
    "gnome-power-manager|🔋 Estadísticas de energía"
)
# shellcheck disable=SC2034  # se usa por referencia en flavor_app_list
APPS_UNITY=(
    "pluma|📝 Pluma (editor de texto)"
    "eom|🖼️ Eye of MATE (visor de imágenes)"
    "atril|📖 Atril (visor de PDF)"
    "file-roller|🗜️ Archivos comprimidos"
    "mate-calc|🧮 Calculadora"
    "mate-system-monitor|📊 Monitor del sistema"
    "gnome-screenshot|📸 Capturas de pantalla"
    "activity-log-manager|🕵️ Registro de actividad (privacidad)"
)

# Apps del sabor actual + comunes, sin repetir paquetes
flavor_app_list() {
    local -n desk_list
    case $DESKTOP in
        kde) desk_list=APPS_KDE ;;
        gnome) desk_list=APPS_GNOME ;;
        xfce) desk_list=APPS_XFCE ;;
        lxqt) desk_list=APPS_LXQT ;;
        mate) desk_list=APPS_MATE ;;
        budgie) desk_list=APPS_BUDGIE ;;
        cinnamon) desk_list=APPS_CINNAMON ;;
        unity) desk_list=APPS_UNITY ;;
        *) printf '%s\n' "${APPS_COMMON[@]}"; return 0 ;;
    esac
    printf '%s\n' "${desk_list[@]}" "${APPS_COMMON[@]}" | awk -F'|' '!seen[$1]++'
}

# Juegos (perfil productividad) y extras que sobran en un sistema mínimo (perfil minimalista).
# Solo se quitan los que estén instalados.
GAME_PKGS=(aisleriot gnome-mines gnome-sudoku gnome-mahjongg gnome-2048 gnome-chess sgt-launcher
    2048-qt kmahjongg kmines kpat ksudoku)
MINIMAL_PKGS=("${GAME_PKGS[@]}" kmail kontact korganizer kaddressbook kalarm knotes akregator
    konversation hexchat quassel neochat ktorrent transmission-gtk transmission-qt k3b xfburn
    dragonplayer juk kmouth kteatime ktimer mugshot plasma-welcome kubuntu-docs kubuntu-web-shortcuts
    mate-user-guide ubuntu-mate-guide goodvibes gpodder)

remove_games() { remove_apps_with_progress "${GAME_PKGS[@]}"; }
remove_minimal_extras() { remove_apps_with_progress "${MINIMAL_PKGS[@]}"; }

# Piezas sin las que el escritorio o el sistema dejan de funcionar: si quitar una app
# las arrastraría por dependencias, esa app no se quita
CORE_PKGS=(plasma-desktop plasma-workspace kwin-x11 kwin-wayland systemsettings dolphin sddm
    gnome-shell gnome-session mutter nautilus gnome-control-center gdm3
    xfce4-session xfce4-panel xfwm4 xfdesktop4 thunar lightdm
    lxqt-session lxqt-panel openbox pcmanfm-qt
    mate-session-manager mate-panel marco caja
    budgie-desktop nemo cinnamon cinnamon-session unity unity-session ukui-session-manager
    network-manager pipewire wireplumber pulseaudio xorg xserver-xorg-core xwayland
    sudo systemd policykit-1 polkitd ubuntu-minimal ubuntu-standard grub-common linux-generic)

# ============================================================
# OPCIÓN 2: ELIMINAR APLICACIONES (COLOR: CIAN)
# ============================================================

select_apps_to_remove() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🗑️ ELIMINAR APLICACIONES                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${CYAN}🖥️ Apps de ${FLAVOR_NAME} (${DESKTOP_NAME}) y comunes a todos los Ubuntu${NC}\n"
    local apps=()
    mapfile -t apps < <(flavor_app_list)

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
# OPCIÓN 3: CONFIGURAR SISTEMA (COLOR: VERDE)
# ============================================================

remove_flavor_meta() {
    if [ -z "$FLAVOR_META" ] || ! installed_pkgs "$FLAVOR_META" | grep -qx -- "$FLAVOR_META"; then
        echo -e "  ${YELLOW}ℹ El meta-paquete de ${FLAVOR_NAME} ya no está instalado${NC}"
        return 0
    fi
    # Sin el meta-paquete, sus apps quedan "huérfanas" y 'apt autoremove' (opción 1)
    # las borraría. Se marcan como instaladas manualmente para conservarlas.
    local kd_pkgs
    # shellcheck disable=SC2046  # listas de paquetes: se separan a propósito
    mapfile -t kd_pkgs < <(installed_pkgs $(flavor_meta_pkgs))
    [ ${#kd_pkgs[@]} -gt 0 ] && run "No se pudieron proteger las apps de ${FLAVOR_NAME}" sudo apt-mark manual "${kd_pkgs[@]}"
    purge_and_record "$FLAVOR_META" && log_success "Se eliminó $FLAVOR_META (las apps se conservan)"
}

enable_backports() {
    # El PPA de backports es de Kubuntu: en los demás sabores no existe
    if [ "$FLAVOR" != kubuntu ]; then
        log_warning "KDE Rolling Release es solo para Kubuntu (este sistema es ${FLAVOR_NAME})"
        return 0
    fi
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

    if [ -z "$FLAVOR_META" ]; then
        echo -e "\n${YELLOW}ℹ ${FLAVOR_NAME}: no hay meta-paquete de escritorio${NC}"
    else
    echo -e "\n${GREEN}1. Meta-paquete ${FLAVOR_META}${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Es el paquete que agrupa todas las apps de ${FLAVOR_NAME}"
    echo -e "   ${GREEN}✓ Si lo eliminas:${NC} Podrás desinstalar apps sin que se reinstalen"
    echo ""
    if confirm "${GREEN}¿Eliminar ${FLAVOR_META}? (recomendado)${NC}"; then
        remove_flavor_meta
    else
        echo -e "${YELLOW}ℹ Se mantiene ${FLAVOR_META}${NC}"
    fi
    fi

    if [ "$FLAVOR" = kubuntu ]; then
    echo ""
    echo -e "${GREEN}2. Cambio a KDE Rolling Release (solo para Kubuntu)${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Cambia los repositorios a versión Rolling Release"
    echo -e "   ${GREEN}✓ Beneficio:${NC} Te dará las últimas versiones de KDE Plasma"
    echo ""
    if confirm "${GREEN}¿Cambiar a KDE Rolling Release? (recomendado)${NC}"; then
        enable_backports
    else
        echo -e "${YELLOW}ℹ Se mantienen repositorios estándar${NC}"
    fi
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
# OPCIÓN 4: OPTIMIZACIÓN DE GPU (COLOR: MAGENTA)
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
        echo -e "\n  ${PURPLE}0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-4): " gpu_option

        case $gpu_option in
            1) optimize_nvidia ;;
            2) optimize_amd ;;
            3) optimize_intel ;;
            4) auto_detect_gpu ;;
            0) return 0 ;;
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
# OPCIÓN 5: OPTIMIZACIÓN DE KERNEL (COLOR: AZUL)
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
        echo -e "\n  ${BLUE}0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-5): " kernel_option

        case $kernel_option in
            1) install_liquorix_kernel ;;
            2) install_xanmod_kernel ;;
            3) optimize_standard_kernel ;;
            4) install_standard_livepatch_kernel ;;
            5) advanced_kernel_tweaks ;;
            0) return 0 ;;
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
GRUB_DEFAULT_BACKUP="/etc/default/grub.ubuntu-ultimate-tools.orig"

# Antes del primer cambio guarda /etc/default/grub para poder volver al original
backup_grub_config() {
    [ -f "$GRUB_DEFAULT_BACKUP" ] || sudo cp -p /etc/default/grub "$GRUB_DEFAULT_BACKUP"
}

set_grub_default() {
    local value="$1"
    backup_grub_config
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
    echo -e "\n  ${BLUE}0)${NC} 🔙 Volver"
    echo ""
    read -r -p "📌 Opción: " option

    OFFICIAL_VERSION=""
    case $option in
        0) return 1 ;;
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
# OPCIÓN 6: OPTIMIZACIÓN DE MEMORIA RAM (COLOR: AMARILLO)
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
# OPCIÓN 1: ACTUALIZACIÓN DEL SISTEMA (COLOR: VERDE)
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

THEME_BACKUP="$STATE_DIR/tema-anterior.txt"

# Anota un ajuste del tema tal como estaba antes del primer cambio (para "Revertir")
save_theme_value() {
    local key="$1" value="$2"
    mkdir -p "$STATE_DIR"
    grep -qs "^$key=" "$THEME_BACKUP" || echo "$key=$value" >> "$THEME_BACKUP"
}

theme_value() { sed -n "s/^$1=//p" "$THEME_BACKUP" 2>/dev/null | head -n1; }

kde_color_scheme() { sed -n '/^\[General\]/,/^\[/ s/^ColorScheme=//p' "$HOME/.config/kdeglobals" 2>/dev/null | head -n1; }

install_tokyo_night_theme() {
    echo -e "${CYAN}🎨 Aplicando tema Tokyo Night...${NC}"
    local before
    before=$(kde_color_scheme)
    [ "$before" != TokyoNight ] && save_theme_value kde-colores "${before:-BreezeLight}"
    save_theme_value konsole-perfil "$(sed -n 's/^DefaultProfile=//p' "$HOME/.config/konsolerc" 2>/dev/null)"
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
    echo -e "${CYAN}ℹ Para volver a los colores originales: opción 9 (Revertir) o Preferencias del sistema → Colores${NC}"
}

# Modo oscuro de GNOME: estilo oscuro y, con el tema Yaru de Ubuntu, su variante oscura
gnome_dark_mode() {
    local theme
    save_theme_value gnome-estilo "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)"
    save_theme_value gnome-tema "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)"
    run "No se pudo activar el modo oscuro" gsettings set org.gnome.desktop.interface color-scheme prefer-dark || return 1
    theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    if [[ "$theme" == Yaru* && "$theme" != *-dark ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "${theme}-dark"
    fi
    log_success "Modo oscuro de GNOME activado"
}

install_custom_software() {
    if ! has_desktop; then
        log_warning "Alacritty y los temas necesitan un escritorio (este sistema no tiene)"
        pause
        return 0
    fi
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

    case $DESKTOP in
        kde)
            if confirm "${CYAN}¿Aplicar tema Tokyo Night a Plasma y Konsole?${NC}"; then
                install_tokyo_night_theme
            fi ;;
        gnome)
            if confirm "${CYAN}¿Activar el modo oscuro de GNOME?${NC}"; then
                gnome_dark_mode
            fi ;;
        *)
            echo -e "${CYAN}ℹ El tema del escritorio solo se aplica en KDE Plasma (Tokyo Night) y GNOME (modo oscuro).${NC}"
            echo -e "${CYAN}  Alacritty ya usa los colores Tokyo Night.${NC}" ;;
    esac

    pause
}

# ------------------------------------------------------------
# Desarrollo: compilar APK (SDK de Android), Android Studio y Flatpak
# ------------------------------------------------------------

ANDROID_SDK="$HOME/Android/Sdk"            # La misma carpeta que usa Android Studio
ANDROID_ENV="$HOME/.config/ubuntu-ultimate-tools/android-sdk.sh"
ANDROID_ENV_MARK="# Ubuntu Ultimate Tools: Android SDK"
ANDROID_STUDIO_DIR="/opt/android-studio"
ANDROID_STUDIO_STATE="$STATE_DIR/android-studio.txt"   # "google" o "snap"
ANDROID_STUDIO_DESKTOP="$HOME/.local/share/applications/android-studio.desktop"
FLATPAK_SDK_LIST="$STATE_DIR/flatpak-sdk.txt"

android_tools_installed() { [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; }
android_studio_installed() {
    [ -x "$ANDROID_STUDIO_DIR/bin/studio" ] || [ -x "$ANDROID_STUDIO_DIR/bin/studio.sh" ] \
        || snap list android-studio &> /dev/null
}

# Avisa si no hay espacio suficiente (en GB) en la carpeta dada
enough_space() {
    local dir="$1" need="$2" free
    free=$(df -BG --output=avail "$dir" 2>/dev/null | tail -1 | tr -dc '0-9')
    [ -z "$free" ] || [ "$free" -ge "$need" ] && return 0
    log_error "Hace falta unos $need GB libres en $dir y hay $free GB"
    return 1
}

# Comprueba el SHA de un archivo (sha1 o sha256 según el largo)
check_sum() {
    local file="$1" sum="$2" got
    case ${#sum} in
        40) got=$(sha1sum < "$file" | cut -d' ' -f1) ;;
        64) got=$(sha256sum < "$file" | cut -d' ' -f1) ;;
        *) return 1 ;;
    esac
    [ "$got" = "$sum" ]
}

# JDK que usa Gradle: el 21 si existe en tu Ubuntu, si no el 17
install_jdk() {
    local jdk
    jdk=$(available_pkgs openjdk-21-jdk-headless openjdk-17-jdk-headless | head -n1)
    if [ -z "$jdk" ]; then
        log_error "No hay JDK 17 ni 21 en tus repositorios"
        return 1
    fi
    apt_install_recorded "$jdk" || return 1
    JAVA_HOME_DIR=$(dirname "$(dirname "$(dpkg -L "$jdk" 2>/dev/null | grep -m1 '/bin/javac$')")")
    [ -x "$JAVA_HOME_DIR/bin/javac" ] || { log_error "No se encontró el JDK instalado"; return 1; }
}

# Variables para la terminal: ANDROID_HOME, JAVA_HOME y las herramientas en el PATH
write_android_env() {
    mkdir -p "$(dirname "$ANDROID_ENV")"
    cat > "$ANDROID_ENV" << ENV
# Creado por Ubuntu Ultimate Tools: herramientas para compilar APK
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export JAVA_HOME="\${JAVA_HOME:-$JAVA_HOME_DIR}"
_uut_bt=\$(ls -d "\$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -n1)
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\${_uut_bt:+\$_uut_bt:}\$PATH"
unset _uut_bt
ENV
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$rc" ] || continue
        grep -qF "$ANDROID_ENV_MARK" "$rc" && continue
        echo "[ -f \"$ANDROID_ENV\" ] && . \"$ANDROID_ENV\"  $ANDROID_ENV_MARK" >> "$rc"
    done
}

# Paquetes de Google para la última versión estable de Android
android_sdk_packages() {
    local list platform build
    list=$("$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK" --list 2>/dev/null)
    platform=$(grep -oE '^ *platforms;android-[0-9]+ ' <<< "$list" | tr -d ' ' | sort -t- -k2 -n | tail -n1)
    build=$(grep -oE '^ *build-tools;[0-9.]+ ' <<< "$list" | tr -d ' ' | sort -V | tail -n1)
    echo platform-tools $platform $build
}

install_android_tools() {
    echo -e "${BLUE}🤖 Herramientas para compilar APK (sin Android Studio)${NC}"
    echo -e "${CYAN}  Java (JDK) + SDK de Android de Google + adb. Unos 3 GB en $ANDROID_SDK${NC}"
    enough_space "$HOME" 4 || return 1
    apt_update
    install_jdk || return 1
    # Reglas para que Linux reconozca el celular por USB (adb sin sudo) y unzip para el SDK
    apt_install_recorded android-sdk-platform-tools-common unzip || return 1
    getent group plugdev > /dev/null && ! id -nG | grep -qw plugdev \
        && run "No se pudo dar permiso al USB" sudo usermod -aG plugdev "$USER"

    if ! android_tools_installed; then
        local xml url sum tmp
        echo -e "${BLUE}⬇ Buscando la última versión de las herramientas de Google...${NC}"
        # La misma lista que usa sdkmanager: dice el archivo y su suma de comprobación
        xml=$(wget -qO- https://dl.google.com/android/repository/repository2-3.xml 2>> "$LOG_FILE")
        read -r sum url < <(awk '
            /<remotePackage path="cmdline-tools;latest">/ { on = 1 }
            on && /<checksum/ { c = $0; gsub(/.*">|<\/checksum>.*/, "", c) }
            on && /<url>/ { u = $0; gsub(/.*<url>|<\/url>.*/, "", u); if (u ~ /linux/) { print c, u; exit } }
            on && /<\/remotePackage>/ { on = 0 }' <<< "$xml")
        if [[ ! "$url" =~ ^commandlinetools-linux-[0-9]+_latest\.zip$ ]]; then
            log_error "No se pudo consultar la versión de las herramientas de Google (¿sin internet?)"
            return 1
        fi
        tmp=$(mktemp -d)
        echo -e "${BLUE}⬇ Descargando $url...${NC}"
        if ! wget -q --show-progress -O "$tmp/tools.zip" "https://dl.google.com/android/repository/$url" \
            || ! check_sum "$tmp/tools.zip" "$sum"; then
            log_error "La descarga de las herramientas de Google falló o llegó dañada"
            rm -rf "$tmp"
            return 1
        fi
        mkdir -p "$ANDROID_SDK/cmdline-tools"
        rm -rf "$ANDROID_SDK/cmdline-tools/latest"
        if ! unzip -q "$tmp/tools.zip" -d "$tmp" || ! mv "$tmp/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"; then
            log_error "No se pudieron descomprimir las herramientas de Google"
            rm -rf "$tmp"
            return 1
        fi
        rm -rf "$tmp"
    fi

    export JAVA_HOME="$JAVA_HOME_DIR"
    local sdkm="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" pkgs
    echo -e "${BLUE}📜 Aceptando las licencias del SDK de Android...${NC}"
    yes 2>/dev/null | "$sdkm" --sdk_root="$ANDROID_SDK" --licenses >> "$LOG_FILE" 2>&1
    read -r -a pkgs <<< "$(android_sdk_packages)"
    if [ ${#pkgs[@]} -lt 3 ]; then
        log_error "No se pudo leer la lista de paquetes del SDK (detalles en $LOG_FILE)"
        return 1
    fi
    echo -e "${BLUE}⬇ Instalando ${pkgs[*]}...${NC}"
    run_visible "No se pudo instalar el SDK de Android" "$sdkm" --sdk_root="$ANDROID_SDK" "${pkgs[@]}" || return 1
    # Si ya estaba instalado, se actualiza todo lo que tenga versión nueva (también el NDK)
    echo -e "${BLUE}🔄 Actualizando los paquetes del SDK que ya tenías...${NC}"
    run "No se pudo actualizar el SDK" "$sdkm" --sdk_root="$ANDROID_SDK" --update
    write_android_env
    mkdir -p "$STATE_DIR"
    log_success "Listo para compilar APK (Android ${pkgs[1]#platforms;android-}, ${pkgs[2]})"
    cat << 'GUIA'

  📖 CÓMO COMPILAR UN APK (abre una terminal NUEVA para que tome las variables)
     cd carpeta-de-tu-proyecto
     ./gradlew assembleDebug        → app/build/outputs/apk/debug/app-debug.apk
     ./gradlew assembleRelease      → APK para publicar (hay que firmarlo)

  🧩 PROYECTOS CON VARIANTES (por ejemplo, Telegram y sus derivados):
     ./gradlew tasks                → lista todo lo que se puede compilar
     ./gradlew :modulo:tasks        → solo las de un módulo (busca assemble...)
     El APK queda en <módulo>/build/outputs/apk/<variante>/

  ⚙️ NDK Y CMAKE (proyectos con código C/C++): no hace falta instalarlos a mano.
     Como las licencias ya están aceptadas, Gradle baja solo la versión exacta
     que pide el proyecto (ndkVersion) la primera vez que compilas.

  🔄 ACTUALIZAR: vuelve a usar esta opción (actualiza el SDK). Tu proyecto:
     git pull  y compila de nuevo.

  🔑 FIRMAR (para compartir o publicar): crea tu clave UNA vez y guárdala bien;
     si la pierdes no podrás actualizar tu app:
     keytool -genkey -v -keystore mi-clave.jks -alias mi-app -keyalg RSA -validity 10000
     apksigner sign --ks mi-clave.jks app-release-unsigned.apk

  📱 PROBAR EN TU CELULAR: activa "Depuración USB" (Ajustes → Opciones de
     desarrollador), conéctalo y: adb install app-debug.apk
     (cierra sesión y vuelve a entrar la primera vez para el permiso del USB)
GUIA
}

# El emulador de Android necesita la virtualización del procesador (KVM)
check_kvm() {
    echo -e "${BLUE}🖥️ Emulador de Android: comprobando la virtualización (KVM)...${NC}"
    if ! grep -Eqw 'vmx|svm' /proc/cpuinfo; then
        log_warning "Tu procesador no tiene virtualización: el emulador no funcionará. Prueba en tu celular por USB."
        return 0
    fi
    if [ ! -e /dev/kvm ]; then
        log_warning "La virtualización está APAGADA en la BIOS: el emulador será muy lento o no abrirá"
        echo -e "${YELLOW}  Actívala al encender (Supr, F2 o F10): busca 'Intel VT-x', 'Virtualization Technology'${NC}"
        echo -e "${YELLOW}  o en AMD 'SVM Mode', ponla en Enabled, guarda y reinicia.${NC}"
        return 0
    fi
    if getent group kvm > /dev/null && ! id -nG | grep -qw kvm; then
        run "No se pudo dar permiso para KVM" sudo usermod -aG kvm "$USER" \
            && log_success "Permiso para el emulador listo (cierra sesión y vuelve a entrar)"
    else
        log_success "La virtualización está activa: el emulador irá rápido"
    fi
}

# Android Studio oficial de Google: la página de descargas tiene el enlace y su SHA-256
install_android_studio_google() {
    local html url file sum tmp old=""
    enough_space "$HOME" 2 && enough_space /opt 4 || return 1
    command -v wget &> /dev/null || { apt_update; apt_install wget; }
    echo -e "${BLUE}⬇ Buscando la última versión estable en developer.android.com...${NC}"
    html=$(wget -qO- https://developer.android.com/studio 2>> "$LOG_FILE" | tr -d '\n')
    url=$(grep -oE 'https://redirector\.gvt1\.com/edgedl/android/studio/ide-zips/[0-9.]+/android-studio-[0-9.]+-linux\.tar\.gz' <<< "$html" | head -n1)
    if [ -z "$url" ]; then
        log_error "No se encontró la descarga de Android Studio (¿sin internet o cambió la página de Google?)"
        return 1
    fi
    file=${url##*/}
    sum=$(grep -oE "${file//./\\.}.{0,800}" <<< "$html" | grep -oE '\b[0-9a-f]{64}\b' | head -n1)
    tmp=$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}" 2>/dev/null || mktemp -d)
    echo -e "${BLUE}⬇ Descargando $file (más de 1 GB)...${NC}"
    if ! wget -q --show-progress -O "$tmp/$file" "$url"; then
        log_error "No se pudo descargar Android Studio"
        rm -rf "$tmp"
        return 1
    fi
    if [ -n "$sum" ]; then
        if ! check_sum "$tmp/$file" "$sum"; then
            log_error "La descarga de Android Studio llegó dañada (la suma de comprobación no coincide)"
            rm -rf "$tmp"
            return 1
        fi
        log_success "Descarga verificada (SHA-256)"
    else
        log_warning "Google no publicó la suma de comprobación en su página: no se pudo verificar la descarga"
        confirm "${YELLOW}¿Instalarla igual? (viene de la descarga oficial de Google por HTTPS)${NC}" \
            || { rm -rf "$tmp"; return 1; }
    fi
    # Si había una versión anterior, se aparta hasta que la nueva quede instalada
    if [ -d "$ANDROID_STUDIO_DIR" ]; then
        old="$ANDROID_STUDIO_DIR.anterior"
        sudo rm -rf "$old"
        sudo mv "$ANDROID_STUDIO_DIR" "$old"
    fi
    if ! sudo tar -xzf "$tmp/$file" -C /opt >> "$LOG_FILE" 2>&1 || [ ! -d "$ANDROID_STUDIO_DIR/bin" ]; then
        log_error "No se pudo descomprimir Android Studio"
        sudo rm -rf "$ANDROID_STUDIO_DIR"
        [ -n "$old" ] && sudo mv "$old" "$ANDROID_STUDIO_DIR"
        rm -rf "$tmp"
        return 1
    fi
    [ -n "$old" ] && sudo rm -rf "$old"
    rm -rf "$tmp"

    local exe=studio icon=studio.svg
    [ -x "$ANDROID_STUDIO_DIR/bin/studio" ] || exe=studio.sh
    [ -f "$ANDROID_STUDIO_DIR/bin/$icon" ] || icon=studio.png
    mkdir -p "$(dirname "$ANDROID_STUDIO_DESKTOP")"
    cat > "$ANDROID_STUDIO_DESKTOP" << DESKTOP
[Desktop Entry]
Type=Application
Name=Android Studio
Comment=Crear apps para Android
Exec="$ANDROID_STUDIO_DIR/bin/$exe" %f
Icon=$ANDROID_STUDIO_DIR/bin/$icon
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
DESKTOP
    mkdir -p "$STATE_DIR"
    echo google > "$ANDROID_STUDIO_STATE"
    file=${file#android-studio-}
    log_success "Android Studio ${file%-linux.tar.gz} instalado en $ANDROID_STUDIO_DIR (está en el menú de aplicaciones)"
}

install_android_studio_snap() {
    if ! command -v snap &> /dev/null || [ -f /etc/apt/preferences.d/nosnap.pref ]; then
        log_error "Snap no está instalado en este sistema (opción 11 para reinstalarlo, o usa la versión de Google)"
        return 1
    fi
    echo -e "${BLUE}⬇ Instalando el snap de Android Studio (más de 1 GB)...${NC}"
    run_visible "No se pudo instalar el snap de Android Studio" sudo snap install android-studio --classic || return 1
    mkdir -p "$STATE_DIR"
    echo snap > "$ANDROID_STUDIO_STATE"
    log_success "Android Studio instalado (snap: se actualiza solo)"
}

install_android_studio() {
    if ! has_desktop; then
        log_warning "Android Studio necesita un escritorio (este sistema no tiene)"
        return 1
    fi
    if [ "$(dpkg --print-architecture)" != amd64 ]; then
        log_warning "Android Studio para Linux solo existe para PC de 64 bits (amd64)"
        return 1
    fi
    echo -e "\n${BLUE}🤖 ANDROID STUDIO - para programar apps de Android (con emulador)${NC}"
    echo -e "${CYAN}  Ocupa unos 3 GB, más el SDK y los emuladores que bajes (unos 10 GB en total).${NC}"
    echo -e "${CYAN}  La primera vez que lo abras, un asistente baja el SDK a $ANDROID_SDK${NC}"
    echo -e "${CYAN}  (si ya instalaste las herramientas para compilar APK, las usa).${NC}\n"
    echo -e "  ${BLUE}1)${NC} Versión oficial de Google (recomendado): en $ANDROID_STUDIO_DIR, se actualiza"
    echo -e "     desde el propio Android Studio (Ayuda → Buscar actualizaciones)"
    echo -e "  ${BLUE}2)${NC} Snap: se actualiza solo con el sistema (lo empaqueta la comunidad, no Google)"
    echo -e "  ${BLUE}0)${NC} 🔙 No instalar"
    local choice
    read -r -p "📌 Opción (0-2): " choice
    case $choice in
        1) install_android_studio_google || return 1 ;;
        2) install_android_studio_snap || return 1 ;;
        *) echo -e "${YELLOW}ℹ No se instaló Android Studio${NC}"; return 0 ;;
    esac
    check_kvm
}

# Quita Android Studio y/o el SDK (las claves de firma de ~/.android nunca se tocan)
remove_android() {
    local found=false
    if android_studio_installed; then
        found=true
        if confirm "${RED}¿Quitar Android Studio?${NC}"; then
            if snap list android-studio &> /dev/null; then
                run "No se pudo quitar el snap" sudo snap remove android-studio
            fi
            sudo rm -rf "$ANDROID_STUDIO_DIR"
            rm -f "$ANDROID_STUDIO_DESKTOP" "$ANDROID_STUDIO_STATE"
            log_success "Android Studio quitado (su configuración queda en ~/.config/Google por si lo reinstalas)"
        fi
    fi
    if [ -d "$ANDROID_SDK" ]; then
        found=true
        echo -e "${YELLOW}ℹ El SDK de Android ocupa $(du -sh "$ANDROID_SDK" 2>/dev/null | cut -f1) en $ANDROID_SDK (incluye los emuladores)${NC}"
        if confirm "${RED}¿Borrar el SDK de Android? (tus proyectos y tus claves de firma en ~/.android no se tocan)${NC}"; then
            [ "${NUCLEAR_ALL:-false}" = true ] || { [ -d "$HOME/.android" ] && make_backup android-claves "$HOME/.android"; }
            rm -rf "$ANDROID_SDK" "$ANDROID_ENV"
            sed -i "/$ANDROID_ENV_MARK\$/d" "$HOME/.bashrc" "$HOME/.profile" 2>/dev/null
            log_success "SDK de Android borrado"
            echo -e "${CYAN}ℹ El JDK y las reglas USB son paquetes: se quitan en 'Ver y quitar PROGRAMAS' (1)${NC}"
        fi
    fi
    $found || echo -e "${YELLOW}ℹ No hay Android Studio ni SDK de Android instalados${NC}"
}

install_flatpak() {
    if ! has_desktop; then
        log_warning "Flatpak es para apps de escritorio (este sistema no tiene)"
        return 1
    fi
    apt_update
    local pkgs=(flatpak)
    # Para ver e instalar Flatpaks desde la tienda del escritorio
    case $DESKTOP in
        kde) installed_pkgs plasma-discover | grep -qx plasma-discover && pkgs+=(plasma-discover-backend-flatpak) ;;
        *) installed_pkgs gnome-software | grep -qx gnome-software && pkgs+=(gnome-software-plugin-flatpak) ;;
    esac
    apt_install_recorded "${pkgs[@]}" || return 1
    run "No se pudo agregar Flathub" sudo flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
    log_success "Flatpak y Flathub listos (cierra sesión y vuelve a entrar para ver las apps en el menú)"
    [ ${#pkgs[@]} -gt 1 ] && log_info "También puedes instalar Flatpaks desde la tienda de aplicaciones de tu escritorio"
    return 0
}

# Última versión de un SDK de Flathub (las versiones con letras o "-" se ignoran)
flatpak_latest_branch() {
    flatpak remote-ls --system flathub --runtime --columns=application,branch 2>/dev/null \
        | awk -v app="$1" '$1 == app {print $2}' | grep -E '^[0-9]+(\.[0-9]+)?$' | sort -V | tail -n1
}

install_flatpak_builder() {
    command -v flatpak &> /dev/null && flatpak remotes 2>/dev/null | grep -qw flathub || install_flatpak || return 1
    apt_install_recorded flatpak-builder || return 1
    log_success "flatpak-builder instalado"

    if $AUTO_MODE; then return 0; fi
    echo -e "\n${BLUE}📦 ¿Para qué tipo de app vas a compilar? Cada SDK pesa entre 1 y 3 GB.${NC}"
    echo -e "${CYAN}  Usa el que diga el manifiesto de tu app (runtime: / sdk:). Puedes elegir varios: 1 2${NC}"
    echo -e "  ${BLUE}1)${NC} KDE / Qt         (org.kde.Sdk)"
    echo -e "  ${BLUE}2)${NC} GNOME / GTK      (org.gnome.Sdk)"
    echo -e "  ${BLUE}3)${NC} Básico           (org.freedesktop.Sdk: apps en C, C++, Rust, Python, juegos...)"
    echo -e "  ${BLUE}0)${NC} Ninguno por ahora"
    local choice c app branch refs=()
    read -r -p "📌 Opción: " choice
    for c in $choice; do
        case $c in
            1) app=org.kde ;;
            2) app=org.gnome ;;
            3) app=org.freedesktop ;;
            *) continue ;;
        esac
        branch=$(flatpak_latest_branch "$app.Sdk")
        if [ -z "$branch" ]; then
            log_error "No se pudo consultar la versión de $app.Sdk en Flathub"
            continue
        fi
        refs+=("$app.Sdk//$branch" "$app.Platform//$branch")
    done
    if [ ${#refs[@]} -gt 0 ]; then
        echo -e "${BLUE}⬇ Instalando ${refs[*]}...${NC}"
        if run_visible "No se pudieron instalar los SDK de Flatpak" \
            sudo flatpak install -y --noninteractive --system flathub "${refs[@]}"; then
            mkdir -p "$STATE_DIR"
            printf '%s\n' "${refs[@]}" >> "$FLATPAK_SDK_LIST"
            sort -u -o "$FLATPAK_SDK_LIST" "$FLATPAK_SDK_LIST"
            log_success "SDK instalados: ${refs[*]}"
        fi
    fi
    cat << 'GUIA'

  📖 CÓMO COMPILAR UN FLATPAK (en la carpeta donde está el manifiesto .yml)
     Probarlo en tu PC:
       flatpak-builder --user --install --force-clean compilacion com.ejemplo.App.yml
       flatpak run com.ejemplo.App
     Crear un archivo .flatpak para compartir (se instala con doble clic):
       flatpak-builder --repo=repo --force-clean compilacion com.ejemplo.App.yml
       flatpak build-bundle repo mi-app.flatpak com.ejemplo.App
GUIA
}

remove_flatpak_sdks() {
    local refs=()
    [ -f "$FLATPAK_SDK_LIST" ] && mapfile -t refs < "$FLATPAK_SDK_LIST"
    if [ ${#refs[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No hay SDK de Flatpak instalados por el script${NC}"
        return 0
    fi
    printf "  ${RED}•${NC} %s\n" "${refs[@]}"
    confirm "${RED}¿Quitar estos SDK de Flatpak?${NC}" || return 0
    run "No se pudieron quitar los SDK" sudo flatpak uninstall -y --noninteractive --system "${refs[@]}"
    sudo flatpak uninstall -y --noninteractive --system --unused >> "$LOG_FILE" 2>&1
    rm -f "$FLATPAK_SDK_LIST"
    log_success "SDK de Flatpak quitados (Flatpak y flatpak-builder se quitan en 'Ver y quitar PROGRAMAS')"
}

# ------------------------------------------------------------
# Respaldos: antes de borrar algo que no se puede recuperar
# ------------------------------------------------------------

BACKUP_DIR="$HOME/respaldos-ubuntu-ultimate-tools"

# Guarda carpetas en un .tar.gz con fecha (también las de root). Uso: make_backup nombre ruta...
make_backup() {
    local name="$1" file paths=() p
    shift
    for p in "$@"; do sudo test -e "$p" && paths+=("${p#/}"); done
    [ ${#paths[@]} -gt 0 ] || return 0
    mkdir -p "$BACKUP_DIR"
    file="$BACKUP_DIR/$name-$(date +%Y%m%d-%H%M%S)"
    # Nunca se pisa un respaldo anterior
    [ -e "$file.tar.gz" ] && file="$file-$$-$RANDOM"
    file="$file.tar.gz"
    echo -e "${BLUE}💾 Guardando respaldo de: $*${NC}"
    if sudo tar -czf "$file" -C / "${paths[@]}" 2>> "$LOG_FILE"; then
        sudo chown "$(id -u):$(id -g)" "$file"
        log_success "Respaldo guardado: $file ($(du -h "$file" | cut -f1))"
        LAST_BACKUP="$file"
        return 0
    fi
    sudo rm -f "$file"
    log_error "No se pudo guardar el respaldo de $name"
    return 1
}

# ------------------------------------------------------------
# Docker: compilar con el Dockerfile de un proyecto (SDK, NDK... ya listos adentro)
# ------------------------------------------------------------

DOCKER_PKGS=(docker.io docker-buildx docker-compose-v2)

docker_installed() { command -v docker &> /dev/null; }

install_docker() {
    echo -e "${BLUE}🐳 DOCKER - compilar con el Dockerfile de un proyecto${NC}"
    echo -e "${CYAN}  Un Dockerfile es una receta: Docker arma un \"contenedor\" con todo lo que el proyecto${NC}"
    echo -e "${CYAN}  necesita (SDK, NDK, versiones exactas...) sin instalarlo en tu sistema.${NC}"
    echo -e "${CYAN}  Sirve también en un VPS sin escritorio.${NC}\n"

    # Otras instalaciones de Docker chocan con la de Ubuntu
    if [ -n "$(installed_pkgs docker-ce)" ]; then
        log_info "Ya tienes Docker de docker.com (docker-ce): no se instala el de Ubuntu"
    elif snap list docker &> /dev/null; then
        log_error "Tienes Docker en snap: chocaría con el de Ubuntu. Quítalo antes con: sudo snap remove docker"
        return 1
    else
        # Si había configuración de un Docker anterior, se respalda antes de tocar nada
        sudo test -d /etc/docker && make_backup docker-config /etc/docker
        apt_update
        local pkgs=()
        mapfile -t pkgs < <(available_pkgs "${DOCKER_PKGS[@]}")
        if ! printf '%s\n' "${pkgs[@]}" | grep -qx docker.io; then
            log_error "Tu Ubuntu no tiene el paquete docker.io"
            return 1
        fi
        apt_install_recorded "${pkgs[@]}" || return 1
    fi
    run "No se pudo iniciar Docker" sudo systemctl enable --now docker.service docker.socket || return 1
    log_success "Docker instalado y en marcha"

    # Usar docker sin sudo: cómodo, pero ese grupo equivale a ser administrador
    if ! id -nG | grep -qw docker; then
        echo -e "\n${YELLOW}ℹ Para usar docker sin escribir sudo, tu usuario entra al grupo 'docker'.${NC}"
        echo -e "${YELLOW}  Ojo: quien está en ese grupo tiene poder de administrador en la PC. En tu PC o${NC}"
        echo -e "${YELLOW}  en tu VPS personal está bien; en un servidor compartido, mejor usar sudo docker.${NC}"
        if confirm "${BLUE}¿Usar docker sin sudo?${NC}"; then
            run "No se pudo agregar al grupo docker" sudo usermod -aG docker "$USER" \
                && log_success "Listo (cierra sesión y vuelve a entrar, o en un VPS sal y vuelve a conectarte)"
        fi
    fi
    cat << 'GUIA'

  📖 COMPILAR UN PROYECTO QUE TRAE DOCKERFILE (por ejemplo, una app de Android)
     cd carpeta-del-proyecto
     docker build -t mi-compilador .                    → arma el contenedor (la 1.ª vez tarda)
     docker run --rm -v "$PWD":/home/source mi-compilador → compila (la ruta /home/source
                                                           la indica el README del proyecto)
     El APK queda en la carpeta del proyecto, como si lo hubieras compilado sin Docker.

  🔄 ACTUALIZAR: git pull y vuelve a ejecutar los 2 comandos.
  🧹 LIBERAR ESPACIO: docker system df  (ver)  ·  docker system prune  (borrar lo que sobra)
GUIA
}

# Tamaño ocupado por Docker (imágenes, contenedores, volúmenes)
docker_usage() {
    sudo docker system df 2>/dev/null | sed 's/^/   /'
    sudo du -sh /var/lib/docker 2>/dev/null | awk '{print "   Total en disco: " $1}'
}

# Quitar Docker. Normal: los programas (imágenes y volúmenes se conservan).
# Nuclear: además todos los datos, la configuración y el grupo, con respaldo antes.
remove_docker() {
    if ! docker_installed && ! sudo test -d /var/lib/docker; then
        echo -e "${YELLOW}ℹ Docker no está instalado${NC}"
        return 0
    fi
    echo -e "${RED}🐳 Quitar Docker${NC}\n"
    docker_usage
    echo ""
    echo -e "  ${RED}1)${NC} Quitar los programas y CONSERVAR imágenes, contenedores y volúmenes"
    echo -e "     (si lo reinstalas, todo vuelve a estar)"
    echo -e "  ${RED}2)${NC} ☢️  ELIMINACIÓN NUCLEAR: programas + TODOS los datos + configuración + grupo"
    echo -e "     (antes se guarda un respaldo de la configuración y, si quieres, de tus volúmenes)"
    echo -e "  ${RED}0)${NC} 🔙 Volver sin cambiar nada"
    local choice
    read -r -p "📌 Opción (0-2): " choice
    case $choice in
        1) docker_remove_programs ;;
        2) docker_nuclear ;;
        *) echo -e "${YELLOW}ℹ No se cambió nada${NC}" ;;
    esac
}

docker_remove_programs() {
    local pkgs=()
    mapfile -t pkgs < <(installed_pkgs "${DOCKER_PKGS[@]}" docker-ce docker-ce-cli containerd.io)
    [ ${#pkgs[@]} -gt 0 ] || { echo -e "${YELLOW}ℹ No hay paquetes de Docker instalados${NC}"; return 0; }
    confirm "${RED}¿Quitar ${pkgs[*]}? (los datos en /var/lib/docker se conservan)${NC}" || return 0
    sudo systemctl stop docker.service docker.socket >> "$LOG_FILE" 2>&1
    run "No se pudo quitar Docker" sudo env DEBIAN_FRONTEND=noninteractive apt-get remove "${APT_OPTS[@]}" "${pkgs[@]}" || return 1
    forget_installed "${pkgs[@]}"
    log_success "Docker quitado (tus imágenes y volúmenes siguen en /var/lib/docker)"
}

docker_nuclear() {
    echo -e "\n${RED}${BOLD}⚠️  ELIMINACIÓN NUCLEAR DE DOCKER${NC}"
    echo -e "${RED}  Se borran para siempre: todos los contenedores, imágenes, volúmenes y redes,${NC}"
    echo -e "${RED}  /var/lib/docker, /var/lib/containerd, /etc/docker, ~/.docker y el grupo 'docker'.${NC}\n"
    if [ "${NUCLEAR_ALL:-false}" != true ]; then
        confirm "${RED}¿Seguro que quieres borrar Docker y TODOS sus datos?${NC}" || return 0
        confirm "${RED}ÚLTIMA ADVERTENCIA: ¿confirmar la eliminación total?${NC}" || return 0
    fi

    # Respaldos: la configuración siempre (es chica); los volúmenes (tus datos), si quieres
    make_backup docker-config /etc/docker "$HOME/.docker"
    if sudo test -d /var/lib/docker/volumes && [ -n "$(sudo ls -A /var/lib/docker/volumes 2>/dev/null | grep -vx metadata.db)" ]; then
        echo -e "${YELLOW}ℹ Tus volúmenes (datos de los contenedores) ocupan $(sudo du -sh /var/lib/docker/volumes | cut -f1)${NC}"
        if confirm "${BLUE}¿Guardar un respaldo de los volúmenes antes de borrarlos?${NC}"; then
            enough_space "$HOME" "$(( $(sudo du -s --block-size=1G /var/lib/docker/volumes | cut -f1) + 1 ))" \
                && make_backup docker-volumes /var/lib/docker/volumes
        fi
    fi

    echo -e "${RED}[1/4] Deteniendo y borrando contenedores...${NC}"
    if docker_installed; then
        sudo docker ps -aq 2>/dev/null | xargs -r sudo docker rm -f >> "$LOG_FILE" 2>&1
    fi
    sudo systemctl stop docker.service docker.socket containerd.service >> "$LOG_FILE" 2>&1

    echo -e "${RED}[2/4] Quitando los programas...${NC}"
    local pkgs=()
    mapfile -t pkgs < <(installed_pkgs "${DOCKER_PKGS[@]}" docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin containerd runc)
    if [ ${#pkgs[@]} -gt 0 ]; then
        apt_purge "${pkgs[@]}"
        forget_installed "${pkgs[@]}"
        run "Falló la limpieza de dependencias" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge
    fi

    echo -e "${RED}[3/4] Borrando datos y configuración...${NC}"
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker.sock "$HOME/.docker"

    echo -e "${RED}[4/4] Quitando el grupo docker...${NC}"
    getent group docker > /dev/null && sudo groupdel docker >> "$LOG_FILE" 2>&1

    log_success "Docker eliminado por completo"
    [ -d "$BACKUP_DIR" ] && echo -e "${CYAN}💾 Respaldos en: $BACKUP_DIR${NC}"
}

# Todo lo de desarrollo que instala el script, de una vez
dev_nuclear() {
    echo -e "${RED}${BOLD}☢️  ELIMINACIÓN NUCLEAR DE LAS HERRAMIENTAS DE DESARROLLO${NC}\n"
    echo -e "${RED}📋 Se borra:${NC}"
    android_studio_installed && echo -e "  • Android Studio"
    [ -d "$ANDROID_SDK" ] && echo -e "  • SDK de Android ($(du -sh "$ANDROID_SDK" 2>/dev/null | cut -f1), con emuladores y NDK)"
    [ -s "$FLATPAK_SDK_LIST" ] && echo -e "  • SDK de Flatpak: $(paste -sd' ' "$FLATPAK_SDK_LIST")"
    { docker_installed || sudo test -d /var/lib/docker; } && echo -e "  • Docker con TODAS sus imágenes, contenedores y volúmenes"
    echo -e "  • Java (JDK), reglas USB de Android y flatpak-builder"
    echo -e "\n${GREEN}✓ No se tocan: tus proyectos, tus claves de firma (~/.android) ni tus apps Flatpak.${NC}"
    echo -e "${GREEN}  Antes se guardan respaldos en $BACKUP_DIR${NC}\n"
    confirm "${RED}¿Borrar todo lo anterior?${NC}" || return 0
    confirm "${RED}ÚLTIMA ADVERTENCIA: ¿confirmar la eliminación total?${NC}" || return 0

    # Las claves de firma no se borran, pero un respaldo extra nunca sobra
    [ -d "$HOME/.android" ] && make_backup android-claves "$HOME/.android"

    local was_force=${FORCE_YES:-false}
    if android_studio_installed || [ -d "$ANDROID_SDK" ]; then
        FORCE_YES=true NUCLEAR_ALL=true remove_android
    fi
    [ -s "$FLATPAK_SDK_LIST" ] && FORCE_YES=true remove_flatpak_sdks
    if docker_installed || sudo test -d /var/lib/docker; then
        NUCLEAR_ALL=true docker_nuclear
    fi
    FORCE_YES=$was_force

    local pkgs=()
    mapfile -t pkgs < <(installed_pkgs openjdk-21-jdk-headless openjdk-17-jdk-headless \
        android-sdk-platform-tools-common flatpak-builder)
    if [ ${#pkgs[@]} -gt 0 ]; then
        apt_purge "${pkgs[@]}" && forget_installed "${pkgs[@]}"
        run "Falló la limpieza de dependencias" sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" autoremove --purge
    fi
    echo ""
    log_success "Herramientas de desarrollo eliminadas"
    [ -d "$BACKUP_DIR" ] && echo -e "${CYAN}💾 Respaldos en: $BACKUP_DIR${NC}"
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
        "steam|🎮 Steam (con Proton para juegos de Windows)"
        "proton-ge|🍷 Proton-GE (Proton de la comunidad, más compatible)"
        "spotify|🎵 Spotify"
        "obs-studio|🎥 OBS Studio"
        "emojier|😊 Selector de emojis"
        "qrca|📱 Generador de códigos QR"
        "android-tools|🤖 Compilar APK: Java + SDK Android + adb (~3 GB)"
        "android-studio|🤖 Android Studio con emulador (Google o Snap, ~10 GB)"
        "flatpak|📦 Flatpak + Flathub: instalar apps Flatpak"
        "flatpak-builder|🛠️ Compilar Flatpaks: flatpak-builder + el SDK que elijas"
        "docker|🐳 Docker + Compose: compilar con el Dockerfile de un proyecto"
    )

    # Se marca lo que ya está instalado para no reinstalarlo por error
    local installed=() entries=() app pkg
    mapfile -t installed < <(installed_pkgs "${software[@]%%|*}" spotify-client kdeplasma-addons)
    steam_installed && installed+=(steam)
    [ -n "$(ls -d "$(steam_dir)"/compatibilitytools.d/GE-Proton* 2>/dev/null)" ] && installed+=(proton-ge)
    android_tools_installed && installed+=(android-tools)
    android_studio_installed && installed+=(android-studio)
    docker_installed && installed+=(docker)
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
# Seguro: qué piezas esenciales (CORE_PKGS) arrastraría quitar estos paquetes
core_pkgs_removed_by() {
    LC_ALL=C apt-get -s purge "$@" 2>/dev/null | awk '/^(Purg|Remv) / {print $2}' \
        | grep -xF -f <(printf '%s\n' "${CORE_PKGS[@]}")
}

remove_apps_with_progress() {
    local installed=() safe=() app core extra=()

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    mapfile -t installed < <(installed_pkgs "$@")
    if ! $AUTO_MODE; then
        for app in "$@"; do
            printf '%s\n' "${installed[@]}" | grep -qx -- "$app" || echo -e "  ${YELLOW}⚠ No instalado: $app${NC}"
        done
    fi

    # Ninguna app se quita si arrastra el escritorio, la sesión, la red, el sonido...
    for app in "${installed[@]}"; do
        core=$(core_pkgs_removed_by "$app" | tr '\n' ' ')
        if [ -n "$core" ]; then
            echo -e "  ${RED}🛡 No se quita $app: arrastraría piezas esenciales del sistema (${core% })${NC}"
        else
            safe+=("$app")
        fi
    done
    installed=("${safe[@]}")

    # Lo que apt quitaría además por dependencias
    if [ ${#installed[@]} -gt 0 ]; then
        mapfile -t extra < <(LC_ALL=C apt-get -s purge "${installed[@]}" 2>/dev/null \
            | awk '/^(Purg|Remv) / {print $2}' | grep -vxF -f <(printf '%s\n' "${installed[@]}"))
        if [ ${#extra[@]} -gt 0 ]; then
            echo -e "${YELLOW}⚠ También se quitarán porque dependen de ellas:${NC}"
            printf "  ${YELLOW}•${NC} %s\n" "${extra[@]}"
            if ! $AUTO_MODE && ! confirm "${CYAN}¿Continuar igualmente?${NC}"; then
                echo -e "${YELLOW}ℹ Cancelado: no se eliminó nada${NC}"
                return 0
            fi
        fi
    fi

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
    $AUTO_MODE || echo -e "${CYAN}ℹ Para quitar los íconos del escritorio o del panel usa la opción 13${NC}"
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
    local repo_changed=false tmp want_steam=false want_ge=false want_extra=()
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
            # Necesitan pasos propios (32 bits, verificación): se instalan al final
            "steam") want_steam=true ;;
            "proton-ge") want_ge=true ;;
            # Descargas grandes con pasos propios: van al final, en este orden
            "android-tools"|"android-studio"|"flatpak"|"flatpak-builder"|"docker") want_extra+=("$app") ;;
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

    if $want_steam; then install_steam || failed+=(steam); fi
    if $want_ge; then install_proton_ge || failed+=(proton-ge); fi
    for app in android-tools android-studio flatpak flatpak-builder docker; do
        [[ " ${want_extra[*]} " == *" $app "* ]] || continue
        # flatpak-builder ya instala Flatpak si hace falta
        [ "$app" = flatpak ] && [[ " ${want_extra[*]} " == *" flatpak-builder "* ]] && continue
        echo ""
        "install_${app//-/_}" || failed+=("$app")
    done

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
        echo -e "  ${GREEN}✓ Todos los paquetes de ${FLAVOR_NAME} ya están instalados${NC}"
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

# Vuelve el tema del escritorio al de antes de la opción 7 (Tokyo Night o modo oscuro)
restore_theme() {
    local kwrite value
    kwrite=$(command -v kwriteconfig6 || command -v kwriteconfig5)
    case $DESKTOP in
        kde)
            if [ "$(kde_color_scheme)" = TokyoNight ]; then
                value=$(theme_value kde-colores)
                run "No se pudieron restaurar los colores de Plasma" plasma-apply-colorscheme "${value:-BreezeLight}" \
                    && log_success "Colores de Plasma restaurados (${value:-BreezeLight})"
            else
                echo -e "  ${GREEN}✓ Plasma no usa Tokyo Night${NC}"
            fi
            if [ -n "$kwrite" ] && grep -qs '^DefaultProfile=TokyoNight.profile' "$HOME/.config/konsolerc"; then
                value=$(theme_value konsole-perfil)
                if [ -n "$value" ]; then
                    "$kwrite" --file konsolerc --group "Desktop Entry" --key DefaultProfile "$value"
                else
                    "$kwrite" --file konsolerc --group "Desktop Entry" --key DefaultProfile --delete
                fi
                log_success "Konsole vuelve a su perfil anterior"
            fi
            rm -f "$HOME/.local/share/color-schemes/TokyoNight.colors" \
                "$HOME/.local/share/konsole/TokyoNight.colorscheme" "$HOME/.local/share/konsole/TokyoNight.profile"
            ;;
        gnome)
            if grep -qs '^gnome-' "$THEME_BACKUP"; then
                for value in color-scheme:gnome-estilo gtk-theme:gnome-tema; do
                    if [ -n "$(theme_value "${value#*:}")" ]; then
                        gsettings set org.gnome.desktop.interface "${value%%:*}" "$(theme_value "${value#*:}")"
                    fi
                done
                log_success "Tema de GNOME restaurado"
            else
                echo -e "  ${GREEN}✓ El script no cambió el tema de GNOME${NC}"
            fi
            ;;
        *) echo -e "  ${GREEN}✓ El script no cambia el tema de ${DESKTOP_NAME}${NC}" ;;
    esac
    rm -f "$THEME_BACKUP"
}

# Quita el repositorio de Mozilla (Firefox .deb) y vuelve al Firefox de Ubuntu
restore_ubuntu_firefox() {
    sudo rm -f /etc/apt/sources.list.d/mozilla.list /etc/apt/preferences.d/mozilla \
        /etc/apt/keyrings/packages.mozilla.org.asc
    apt_update force
    # El paquete de Ubuntu instala el snap; los marcadores de ~/.mozilla se importan al abrirlo
    if installed_pkgs firefox | grep -qx firefox; then
        apt_install --allow-downgrades firefox && log_success "Firefox de Ubuntu reinstalado"
    fi
}

revert_changes() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                ↩️ REVERTIR A DISTRIBUCIÓN ORIGINAL               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}🐧 Distribución detectada: ${FLAVOR_NAME} (${DESKTOP_NAME})${NC}"

    local removed_count=0 backports=false mozilla=false keep_firefox=false
    [ -f "$REMOVED_LIST" ] && removed_count=$(wc -l < "$REMOVED_LIST")
    grep -rqs 'kubuntu-ppa/backports' /etc/apt/sources.list /etc/apt/sources.list.d/ && backports=true
    [ -f /etc/apt/sources.list.d/mozilla.list ] && mozilla=true

    echo -e "\n${RED}📋 Esto hará:${NC}"
    $backports && echo -e "  • Quitar KDE Rolling Release (PPA backports) y volver Plasma a la versión oficial"
    echo -e "  • Desbloquear y reinstalar Snap y las apps snap que se quitaron"
    $mozilla && echo -e "  • Volver al Firefox de Ubuntu (se pregunta antes)"
    if [ -n "$FLAVOR_META" ]; then
        echo -e "  • Reinstalar ${FLAVOR_META} y todas las apps de ${FLAVOR_NAME}"
    fi
    [ "$removed_count" -gt 0 ] && echo -e "  • Reinstalar los $removed_count paquetes eliminados con este script"
    if has_desktop; then
        echo -e "  • Restaurar los accesos directos del escritorio y del panel"
        echo -e "  • Restaurar el tema del escritorio (si el script lo cambió)"
    fi
    echo -e "  • Volver a los valores de fábrica los ajustes del script (RAM, DNS, ZRAM, energía...)"
    echo -e "\n${YELLOW}ℹ No cambia el kernel (opción 5) ni el arranque (opción 12). Los programas que instaló${NC}"
    echo -e "${YELLOW}  el script se quitan desde la opción 17.${NC}"
    echo ""

    if ! confirm "${RED}⚠ ¿Revertir a la distribución original (${FLAVOR_NAME})?${NC}"; then
        return 0
    fi
    if $mozilla && ! confirm "${YELLOW}¿Volver al Firefox de Ubuntu (snap)? Si dices que no, sigues con el de Mozilla (.deb)${NC}"; then
        keep_firefox=true
    fi

    echo -e "${RED}[1/6] Repositorios...${NC}"
    if $backports; then
        run "No se pudo quitar el PPA backports" sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports
        apt_update force
        downgrade_orphaned_ppa_pkgs
    else
        echo -e "  ${GREEN}✓ KDE Rolling Release no está activo${NC}"
        apt_update
    fi

    echo -e "${RED}[2/6] Desbloqueando Snap...${NC}"
    # La eliminación nuclear (opción 10) bloquea snapd; hay que desbloquearlo antes
    sudo apt-mark unhold snapd >> "$LOG_FILE" 2>&1
    sudo rm -f /etc/apt/preferences.d/nosnap.pref
    if $mozilla && ! $keep_firefox; then
        restore_ubuntu_firefox
    fi

    echo -e "${RED}[3/6] Reinstalando paquetes de ${FLAVOR_NAME}...${NC}"
    local pkgs=()
    if [ -n "$FLAVOR_META" ]; then
        mapfile -t pkgs < <(flavor_meta_pkgs)
        pkgs+=("$FLAVOR_META")
    fi
    pkgs+=(snapd)
    [ -f "$REMOVED_LIST" ] && mapfile -t -O "${#pkgs[@]}" pkgs < "$REMOVED_LIST"
    # Con el Firefox de Mozilla, no se reinstala el de Ubuntu (que lo cambiaría por el snap)
    if $keep_firefox; then
        mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -vx firefox)
    fi
    if install_missing_pkgs "${pkgs[@]}"; then
        rm -f "$REMOVED_LIST"
    fi
    run "No se pudo iniciar snapd" sudo systemctl enable --now snapd.socket

    echo -e "${RED}[4/6] Reinstalando apps snap...${NC}"
    if $keep_firefox; then restore_removed_snaps firefox; else restore_removed_snaps; fi

    echo -e "${RED}[5/6] Restaurando escritorio...${NC}"
    if has_desktop; then
        restore_desktop_shortcuts
        restore_panel_launchers
        restore_theme
    else
        echo -e "  ${GREEN}✓ Sin escritorio: no hay accesos ni tema que restaurar${NC}"
    fi

    echo -e "${RED}[6/6] Restaurando ajustes y limpiando configuraciones...${NC}"
    restore_all_tweaks
    rm -rf ~/.config/alacritty
    rm -f "$HOME/.config/environment.d/90-mangohud.conf"

    echo ""
    echo -e "${GREEN}✓ ${FLAVOR_NAME} revertido a su estado original${NC}"
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

REMOVED_SNAPS="$STATE_DIR/snaps-eliminados.txt"

# Anota las apps snap instaladas ("nombre" o "nombre classic") para poder reinstalarlas
record_removed_snaps() {
    local list
    # Solo apps: los runtimes (temas, bibliotecas de GNOME/KDE, mesa...) llegan solos con ellas
    list=$(snap list 2>/dev/null | awk 'NR>1 && $NF !~ /base|core|snapd/ && $1 !~ /^(gtk-common-themes|gtk2-common-themes|gnome-[0-9]|kf[56]-|mesa-|bare$)/ {
        print $1 ($NF ~ /classic/ ? " classic" : "")}')
    [ -n "$list" ] || return 0
    mkdir -p "$STATE_DIR"
    echo "$list" >> "$REMOVED_SNAPS"
    sort -u -o "$REMOVED_SNAPS" "$REMOVED_SNAPS"
}

# Reinstala las apps snap que quitó la eliminación nuclear (opción 10 o perfil minimalista).
# Los argumentos son snaps que no se reinstalan (p. ej. firefox si se queda el de Mozilla).
restore_removed_snaps() {
    local name mode failed=() wanted=() skip=" $* "
    if [ -s "$REMOVED_SNAPS" ]; then
        mapfile -t wanted < "$REMOVED_SNAPS"
    elif [[ "$FLAVOR" == ubuntu || "$FLAVOR" == edubuntu ]]; then
        # Versiones anteriores del script no las anotaban: las que trae Ubuntu de fábrica
        wanted=(snap-store firmware-updater snapd-desktop-integration)
    fi
    if [ ${#wanted[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓ No hay apps snap que reinstalar${NC}"
        return 0
    fi
    command -v snap &> /dev/null || { log_warning "Snap no está instalado: no se reinstalan sus apps"; return 1; }
    sudo snap wait system seed.loaded >> "$LOG_FILE" 2>&1
    for name in "${wanted[@]}"; do
        read -r name mode <<< "$name"
        [[ "$skip" == *" $name "* ]] && continue
        if snap list "$name" &> /dev/null; then
            echo -e "  ${GREEN}✓ $name ya está instalado${NC}"
        elif sudo snap install "$name" ${mode:+--classic} >> "$LOG_FILE" 2>&1; then
            echo -e "  ${GREEN}✓ Reinstalado: $name${NC}"
        else
            failed+=("$name")
        fi
    done
    if [ ${#failed[@]} -gt 0 ]; then
        log_error "No se pudieron reinstalar los snaps: ${failed[*]}"
        return 1
    fi
    rm -f "$REMOVED_SNAPS"
}

do_snap_removal() {
    echo -e "${RED}☢️ Iniciando eliminación nuclear de Snap...${NC}\n"

    # Al borrar el snap se pierden marcadores y contraseñas: se copian antes a la ruta normal
    migrate_snap_profiles

    # Los snaps se eliminan mientras snapd sigue activo: sin el demonio 'snap remove' no funciona
    echo -e "${RED}[1/11] Eliminando paquetes snap de aplicaciones...${NC}"
    record_removed_snaps
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
    if [ -s "$REMOVED_SNAPS" ] && confirm "${GREEN}¿Reinstalar también las apps snap que se quitaron ($(wc -l < "$REMOVED_SNAPS"))?${NC}"; then
        restore_removed_snaps
    fi

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
        echo "║                    🔧 ARRANQUE: GRUB Y EFI                       ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        is_live_session && echo -e "${GREEN}💿 Sesión Live USB detectada: usa la opción 10${NC}"
        echo -e "${PURPLE}🔍 Diagnóstico:${NC}"
        echo -e "  ${PURPLE} 1)${NC} 📊 DIAGNÓSTICO - Estado del arranque (y guardar un informe)"
        echo -e "\n${PURPLE}🔧 Reparar (con el sistema arrancado):${NC}"
        echo -e "  ${PURPLE} 2)${NC} 🔧 REPARACIÓN RÁPIDA - Reinstalar GRUB y regenerar el menú"
        echo -e "  ${PURPLE} 3)${NC} 🧰 REPARACIÓN COMPLETA - EFI + paquetes de GRUB + reinstalación + orden UEFI"
        echo -e "  ${PURPLE} 4)${NC} 💿 INSTALAR GRUB EN OTRO DISCO - Solo modo BIOS"
        echo -e "  ${PURPLE} 5)${NC} 🩺 PARTICIÓN EFI - Verificar, reparar y ver espacio libre"
        echo -e "\n${PURPLE}🎨 Configurar el menú de arranque:${NC}"
        echo -e "  ${PURPLE} 6)${NC} 📂 SISTEMA POR DEFECTO - Qué arranca solo y cuánto espera el menú"
        echo -e "  ${PURPLE} 7)${NC} 🪟 OTROS SISTEMAS - Detectar Windows y otras distros"
        echo -e "  ${PURPLE} 8)${NC} 🔢 ORDEN DE ARRANQUE UEFI - Qué arranca primero / solo la próxima vez"
        echo -e "  ${PURPLE} 9)${NC} 🎨 PERSONALIZAR MENÚ - Ocultar entradas, orden, colores, fondo, parámetros"
        echo -e "\n${PURPLE}🚑 Cuando el sistema NO arranca:${NC}"
        echo -e "  ${PURPLE}10)${NC} 🚑 REPARAR DESDE LIVE USB - Automático (chroot)"
        echo -e "  ${PURPLE}11)${NC} 📖 GUÍA 'grub>' - Arrancar a mano desde el prompt de GRUB"
        echo -e "  ${PURPLE}12)${NC} 📖 GUÍA 'grub rescue>' - Recuperar el menú de GRUB"
        echo -e "  ${PURPLE}13)${NC} 📖 GUÍA LIVE USB - Reparación manual con comandos"
        echo -e "\n${PURPLE}🛟 Prepárate ANTES de que falle (con el sistema funcionando):${NC}"
        echo -e "  ${PURPLE}14)${NC} 🪪 TARJETA DE RESCATE - Los comandos exactos de TU PC para 'grub>' y"
        echo -e "        'grub rescue>', para fotografiar y copiar al pendrive junto con el script"
        echo -e "  ${PURPLE}15)${NC} 🛟 ARRANQUE DE RESPALDO UEFI - Que la PC arranque aunque la BIOS"
        echo -e "        pierda la entrada de Ubuntu (actualización de BIOS, reseteo...)"
        echo -e "\n  ${PURPLE} 0)${NC} 🔙 Volver al menú principal"
        echo ""
        read -r -p "📌 Opción (0-15): " grub_option

        case $grub_option in
            1) grub_diagnostic ;;
            2) grub_normal_repair ;;
            3) grub_full_repair; pause ;;
            4) grub_reinstall_to_disk ;;
            5) esp_check_repair; pause ;;
            6) grub_default_entry_menu; pause ;;
            7) grub_os_prober_toggle; pause ;;
            8) uefi_boot_order_menu; pause ;;
            9) grub_customize_menu ;;
            10) grub_live_repair ;;
            11) grub_prompt_guide ;;
            12) grub_rescue_guide ;;
            13) grub_live_guide ;;
            14) rescue_card_menu ;;
            15) uefi_fallback_menu ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# Informe del arranque en texto plano (se muestra y se guarda para compartirlo)
boot_report() {
    echo "== Fecha: $(date '+%Y-%m-%d %H:%M')"
    echo "== Sistema: $(os_release_value PRETTY_NAME) · kernel en uso $(uname -r)"
    echo ""
    echo "== MODO DE ARRANQUE"
    if [ -d /sys/firmware/efi ]; then
        echo "  UEFI · Secure Boot: $(secure_boot_enabled && echo activado || echo desactivado)"
    else
        echo "  BIOS (Legacy)"
    fi
    echo ""
    echo "== DISCOS Y PARTICIONES"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null | grep -v loop | sed 's/^/  /'
    echo ""
    echo "== ESPACIO EN /boot"
    df -h /boot 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "== KERNELS INSTALADOS"
    installed_pkgs 'linux-image-[0-9]*' | sed 's/^linux-image-/  /' | sort -V
    echo ""
    echo "== GRUB"
    if command -v grub-install &> /dev/null; then
        echo "  $(grub-install --version 2>/dev/null | head -1)"
    else
        echo "  ✗ GRUB NO está instalado"
    fi
    grep -E '^GRUB_(DEFAULT|TIMEOUT|TIMEOUT_STYLE|SAVEDEFAULT|DISABLE_OS_PROBER|DISABLE_RECOVERY|CMDLINE_LINUX_DEFAULT|GFXMODE|BACKGROUND)=' \
        /etc/default/grub 2>/dev/null | sed 's/^/  /'
    echo "  Entrada guardada: $(grub-editenv /boot/grub/grubenv list 2>/dev/null | sed -n 's/^saved_entry=//p')"
    [ -d /etc/grub.d/proxifiedScripts ] && echo "  ⚠ Configuración modificada por Grub Customizer"
    echo ""
    echo "== MENÚ DE ARRANQUE"
    grub_menu_entries | cut -d'|' -f2 | sed 's/^/  • /'
    if [ -d /sys/firmware/efi ]; then
        echo ""
        echo "== ENTRADAS UEFI"
        LC_ALL=C efibootmgr 2>/dev/null | sed 's/\t.*//; s/^/  /'
        echo ""
        echo "== PARTICIÓN EFI"
        if findmnt /boot/efi > /dev/null 2>&1; then
            df -h /boot/efi | sed 's/^/  /'
            echo "  Carpetas: $(sudo ls /boot/efi/EFI 2>/dev/null | tr '\n' ' ')"
        else
            echo "  ✗ No hay partición EFI montada en /boot/efi"
        fi
    fi
}

grub_diagnostic() {
    grub_guide_header "📊 DIAGNÓSTICO DEL ARRANQUE"
    local report="$HOME/diagnostico-arranque.txt"
    boot_report | tee "$report"
    echo -e "\n${GREEN}💾 Informe guardado en: $report${NC}"
    echo -e "${YELLOW}   (sirve para pedir ayuda: compártelo si algo no arranca)${NC}"
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_normal_repair() {
    grub_guide_header "🔧 REPARACIÓN RÁPIDA DE GRUB"
    echo -e "${PURPLE}Reinstala GRUB y regenera el menú. Si no alcanza, usa la REPARACIÓN COMPLETA (3).${NC}\n"
    if ! confirm "${PURPLE}¿Reparar GRUB ahora?${NC}"; then
        return 0
    fi

    local ok=true
    if [ -d /sys/firmware/efi ]; then
        echo -e "${PURPLE}🔄 Reparando GRUB en modo UEFI...${NC}"
        if ! findmnt /boot/efi > /dev/null 2>&1; then
            log_error "La partición EFI no está montada en /boot/efi (revisa la opción 5)"
            ok=false
        else
            run_visible "Falló grub-install" sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi \
                --bootloader-id=ubuntu --recheck || ok=false
        fi
    else
        local root_dev boot_disk
        root_dev=$(findmnt -no SOURCE /)
        # Sube por la jerarquía (LVM/LUKS/partición) hasta el disco físico
        boot_disk=$(lsblk -rnso NAME,TYPE "$root_dev" 2>/dev/null | awk '$2 == "disk" {print $1; exit}')
        if [ -z "$boot_disk" ]; then
            log_error "No se pudo detectar el disco del sistema; usa la opción 4"
            ok=false
        else
            echo -e "${PURPLE}🔄 Reparando GRUB en modo BIOS (disco: /dev/$boot_disk)...${NC}"
            run_visible "Falló grub-install" sudo grub-install --target=i386-pc --recheck "/dev/$boot_disk" || ok=false
        fi
    fi

    echo -e "${PURPLE}🔄 Regenerando configuración...${NC}"
    run_visible "Falló update-grub" sudo update-grub || ok=false

    if $ok; then
        log_success "GRUB reparado correctamente"
    else
        log_error "La reparación tuvo errores: prueba la REPARACIÓN COMPLETA (opción 3)"
    fi
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_reinstall_to_disk() {
    grub_guide_header "💿 INSTALAR GRUB EN OTRO DISCO"
    if [ -d /sys/firmware/efi ]; then
        echo -e "${YELLOW}ℹ Este equipo arranca en modo UEFI: GRUB no se instala en un disco sino en la${NC}"
        echo -e "${YELLOW}  partición EFI. Usa la REPARACIÓN RÁPIDA (2) o la COMPLETA (3).${NC}"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
        read -r
        return 0
    fi

    echo -e "${PURPLE}[*] Discos disponibles:${NC}"
    lsblk -dpno NAME,SIZE,MODEL 2>/dev/null | grep -v "loop" | sed 's/^/  /'
    echo ""
    read -r -p "📌 Disco (ej: /dev/sda; el DISCO, no una partición como /dev/sda1): " target_disk

    if [ ! -b "$target_disk" ] || [ "$(lsblk -dno TYPE "$target_disk" 2>/dev/null)" != "disk" ]; then
        log_error "$target_disk no es un disco"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
        read -r
        return 1
    fi

    echo -e "\n${RED}⚠ Esto instalará GRUB en $target_disk${NC}"
    if ! confirm "${PURPLE}¿Confirmar?${NC}"; then
        return 0
    fi

    if run_visible "Falló grub-install" sudo grub-install --target=i386-pc --recheck "$target_disk" \
        && run_visible "Falló update-grub" sudo update-grub; then
        log_success "GRUB instalado en $target_disk"
    fi
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

# Comandos calculados para esta PC (si el script corre en el sistema instalado)
guide_my_commands() {
    is_live_session && return 1
    rescue_card_collect 2>/dev/null && $rc_ok && ! $rc_crypt || return 1
    echo -e "${GREEN}${BOLD}⭐ TUS COMANDOS (calculados para esta PC)${NC}"
    case $1 in
        prompt)
            echo -e "${GREEN}  Escribe estas líneas en 'grub>' y aparece el menú de siempre:${NC}"
            $rc_lvm && echo -e "${CYAN}    insmod lvm${NC}"
            echo -e "${CYAN}    search --no-floppy --fs-uuid --set=root $rc_uuid"
            echo -e "    configfile $rc_grubpath/grub.cfg${NC}"
            echo -e "${GREEN}  O, para arrancar directo sin menú:${NC}"
            echo -e "${CYAN}    search --no-floppy --fs-uuid --set=root $rc_uuid"
            echo -e "    linux $rc_kernel $rc_root ro"
            echo -e "    initrd $rc_initrd"
            echo -e "    boot${NC}"
            ;;
        rescue)
            echo -e "${GREEN}  Escribe estas 4 líneas en 'grub rescue>':${NC}"
            echo -e "${CYAN}    set prefix=($rc_drive)$rc_grubpath"
            echo -e "    set root=($rc_drive)"
            echo -e "    insmod normal"
            echo -e "    normal${NC}"
            $rc_approx && echo -e "${YELLOW}  (el número de disco es calculado: si falla, prueba hd0, hd1, hd2...)${NC}"
            ;;
    esac
    echo -e "${YELLOW}  📷 Sácales una foto, o guarda la tarjeta completa con la opción 14 (también al pendrive).${NC}"
    echo -e "${YELLOW}  Si ya estás frente a 'grub>' en otra PC o no tienes la foto, sigue la guía de abajo.${NC}\n"
}

grub_prompt_guide() {
    grub_guide_header "📖 ARRANQUE MANUAL DESDE 'grub>'"
    echo -e "Si al encender aparece ${BOLD}grub>${NC}, GRUB funciona pero no encuentra su menú."
    echo -e "Desde ahí se puede arrancar escribiendo unos comandos. ${BOLD}TAB${NC} autocompleta.\n"
    guide_my_commands prompt
    cat << 'EOF'
CAMINO RÁPIDO: QUE GRUB BUSQUE SOLO DÓNDE ESTÁ UBUNTU
  Escribe estas 2 líneas. La primera busca la partición que tiene el menú:
    search --no-floppy --file --set=root /boot/grub/grub.cfg
    configfile /boot/grub/grub.cfg
  • Si aparece el menú de siempre: elige tu sistema y ve al PASO FINAL.
  • Si dice "no such device": puede que /boot esté en su propia partición
    o que uses btrfs. Prueba cambiando /boot/grub/grub.cfg (en las 2 líneas) por:
        /grub/grub.cfg              (/boot en partición aparte)
        /@/boot/grub/grub.cfg       (btrfs)
  • Si tienes DOS Linux instalados, puede encontrar el otro primero:
    usa el CAMINO MANUAL.

CAMINO MANUAL: BUSCAR LA PARTICIÓN A MANO
  1. Lista los discos y particiones:
        ls
     Verás algo como: (hd0) (hd0,gpt1) (hd0,gpt2) ...  (o msdos1, msdos2)
  2. Mira cada una hasta encontrar la de Ubuntu (muestra boot/, etc/, home/...):
        ls (hd0,gpt2)/
     Con "ls (hd0,gpt2)" (sin la barra) GRUB dice el tipo (ext*) y el tamaño.
  3. Arranca con ella (cambia hd0,gpt2 por la tuya):
        set root=(hd0,gpt2)
        linux /boot/vmlinuz root=/dev/sda2 ro
        initrd /boot/initrd.img
        boot
     • /boot/vmlinuz e /boot/initrd.img siempre apuntan al kernel más nuevo.
     • root= usa el nombre de LINUX, no el de GRUB: (hd0,gpt2) suele ser
       /dev/sda2 (SATA) o /dev/nvme0n1p2 (NVMe). Si te equivocas, verás
       "(initramfs)": reinicia y prueba con el otro nombre.
     • Con /boot en partición aparte: usa esa partición y quita "/boot":
       linux /vmlinuz ...  e  initrd /initrd.img

PASO FINAL: YA DENTRO DEL SISTEMA (repararlo de forma permanente)
  Ejecuta este script → opción 12 → 2 (REPARACIÓN RÁPIDA) o → 3 (COMPLETA).
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_rescue_guide() {
    grub_guide_header "🛡️ GUÍA PARA 'grub rescue>'"
    echo -e "${BOLD}grub rescue>${NC} significa que GRUB arrancó pero no encuentra ni sus propios"
    echo -e "archivos. Es un modo muy limitado: solo existen ${BOLD}ls${NC}, ${BOLD}set${NC} e ${BOLD}insmod${NC}"
    echo -e "(no puede buscar solo). Hay que decirle dónde está su carpeta.\n"
    guide_my_commands rescue
    cat << 'EOF'
PASO 1: VER LAS PARTICIONES
    ls
  Verás algo como: (hd0) (hd0,gpt1) (hd0,gpt2) (hd0,gpt3)

PASO 2: ENCONTRAR LA QUE TIENE GRUB
  Prueba cada una hasta que una muestre archivos (grub.cfg, fonts, x86_64-efi...):
    ls (hd0,gpt2)/boot/grub
  • "unknown filesystem": esa no es (suele ser la EFI o la de Windows), sigue.
  • /boot en partición aparte:  ls (hd0,gpt3)/grub
  • btrfs:                       ls (hd0,gpt2)/@/boot/grub

PASO 3: CARGAR GRUB (cambia hd0,gpt2 y la ruta por las que encontraste)
    set prefix=(hd0,gpt2)/boot/grub
    set root=(hd0,gpt2)
    insmod normal
    normal
  Aparece el menú de siempre (o "grub>": entonces sigue la guía 11).

PASO 4: YA DENTRO DEL SISTEMA
  Ejecuta este script → opción 12 → 2 (REPARACIÓN RÁPIDA) o → 3 (COMPLETA).

SI "insmod normal" FALLA
  Los archivos de GRUB están dañados: arranca desde un USB de Ubuntu (de tu sabor)
  y usa la opción 10 (reparación automática desde Live USB).
EOF
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

grub_live_guide() {
    grub_guide_header "📖 REPARACIÓN MANUAL DESDE LIVE USB"
    cat << 'EOF'
Arranca desde un USB de Ubuntu de tu sabor ("Probar Ubuntu") y abre una terminal.
La opción 10 de este menú hace todo esto automáticamente.

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

RESCUE_MNT="/mnt/rescate-ubuntu"

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
        echo -e "${YELLOW}  Esta opción es para cuando Ubuntu no arranca: inicia desde un USB de Ubuntu,${NC}"
        echo -e "${YELLOW}  elige 'Probar Ubuntu', abre una terminal y ejecuta este script.${NC}"
        echo -e "${YELLOW}  Si el sistema arranca, usa la opción 2 (RÁPIDA) o 3 (COMPLETA).${NC}\n"
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
        # Ubuntu instala la raíz en el subvolumen @
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
    local key="$1" value="$2" escaped
    backup_grub_config
    # Escapa los caracteres especiales del reemplazo de sed (\ & |)
    escaped=${value//\\/\\\\}
    escaped=${escaped//&/\\&}
    escaped=${escaped//|/\\|}
    if grep -q "^${key}=" /etc/default/grub; then
        sudo sed -i "s|^${key}=.*|${key}=${escaped}|" /etc/default/grub
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
    ' "$cfg" 2>/dev/null)
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

GRUB_OTHERS_FIRST="/etc/grub.d/09_ubuntu_ultimate_tools_otros_primero"

others_visible() {
    grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub || [ -f "$GRUB_OTHERS_FIRST" ]
}

grub_os_prober_toggle() {
    grub_guide_header "🪟 DETECTAR OTROS SISTEMAS"
    if others_visible; then
        echo -e "${GREEN}✓ La detección de otros sistemas ya está activada${NC}\n"
        if confirm "${PURPLE}¿Desactivarla? (los otros sistemas desaparecerán del menú)${NC}"; then
            sudo rm -f "$GRUB_OTHERS_FIRST"
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
    echo -e "${YELLOW}ℹ Si el menú no aparece al encender, usa la opción 6 para darle unos segundos${NC}"
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
    echo -e "  ${PURPLE}0)${NC} 🔙 Volver sin cambiar nada"
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

    esp_fsck "$dev"
}

# Desmonta la partición EFI, la verifica con fsck.vfat y la vuelve a montar
esp_fsck() {
    local dev="$1"
    command -v fsck.vfat &> /dev/null || { apt_update; apt_install dosfstools || return 1; }
    run "No se pudo desmontar /boot/efi (¿la está usando otro programa?)" sudo umount /boot/efi || return 1
    sudo fsck.vfat -a "$dev" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}
    run "No se pudo volver a montar /boot/efi" sudo mount /boot/efi || return 1
    # fsck: 0 = sin errores, 1 = errores corregidos, más = quedaron errores
    case $rc in
        0) log_success "Partición EFI sin errores" ;;
        1) log_success "Partición EFI reparada" ;;
        *) log_error "Quedaron errores en la partición EFI (código $rc)"; return 1 ;;
    esac
}

# ------------------------------------------------------------
# Personalizar el menú de GRUB (sin programas externos)
# ------------------------------------------------------------

GRUB_LOOK_FILE="/etc/grub.d/42_ubuntu_ultimate_tools_apariencia"

# Regenera grub.cfg. Si falla, muestra el error en pantalla: grub-mkconfig solo
# reemplaza el menú cuando termina bien, así que el anterior sigue intacto.
regen_grub() {
    # La primera versión de este script buscaba os-prober solo en su sitio y hacía
    # fallar update-grub si Grub Customizer lo había movido: se reemplaza por la nueva
    if [ -f "$GRUB_OTHERS_FIRST" ] && grep -q '^exec sh /etc/grub.d/30_os-prober$' "$GRUB_OTHERS_FIRST"; then
        write_others_first_script
    fi
    # El filtro de entradas ocultas se reescribe siempre con la versión actual del script
    # (la primera dejaba bloques "if" vacíos y update-grub fallaba)
    [ -f "$GRUB_FILTER_AWK" ] && write_grub_filter
    echo -e "${PURPLE}🔄 Regenerando el menú de GRUB...${NC}"
    local out rc
    out=$(sudo update-grub 2>&1)
    rc=$?
    echo "[$(date '+%H:%M:%S')] \$ update-grub" >> "$LOG_FILE"
    echo "$out" >> "$LOG_FILE"
    if [ $rc -eq 0 ]; then
        rescue_card_refresh
        return 0
    fi

    log_error "Falló update-grub (código $rc). El menú de arranque anterior sigue intacto."
    echo -e "${YELLOW}Últimas líneas del error:${NC}"
    tail -8 <<< "$out" | sed 's/^/   /'
    if [ -d /etc/grub.d/proxifiedScripts ]; then
        echo -e "${YELLOW}⚠ Grub Customizer cambió los scripts de /etc/grub.d: suele ser la causa de este error.${NC}"
        echo -e "${YELLOW}  Deshazlo en: opción 12 → 9 (Personalizar menú) → 7${NC}"
    fi
    return $rc
}

# Scripts de /etc/grub.d cuyo nombre contiene el texto dado, con cualquier número
# delante: Grub Customizer los renumera (37_uefi-firmware) o los cambia por *_proxy
grub_scripts() {
    local f
    for f in /etc/grub.d/[0-9][0-9]_*"$1"*; do
        [ -f "$f" ] && echo "$f"
    done
}

# Oculto = existe y ninguno de sus scripts es ejecutable
grub_scripts_hidden() {
    local f found=false
    while IFS= read -r f; do
        found=true
        [ -x "$f" ] && return 1
    done < <(grub_scripts "$1")
    $found
}

grub_scripts_chmod() {
    local mode="$1" f
    while IFS= read -r f; do
        sudo chmod "$mode" "$f"
    done < <(grub_scripts "$2")
}

# --- Ocultar entradas sueltas -------------------------------------------------
# Cada script de GRUB con entradas ocultas se desactiva (sin permiso de ejecución) y
# en su lugar corre "<script>_ubuntu_ultimate_tools", que lo ejecuta y filtra su salida con
# grub-filtro.awk según la lista de títulos ocultos.
UUT_ETC="/etc/ubuntu-ultimate-tools"
GRUB_HIDDEN_LIST="$UUT_ETC/grub-ocultas"
GRUB_FILTER_AWK="$UUT_ETC/grub-filtro.awk"

write_grub_filter() {
    sudo install -d -m 0755 "$UUT_ETC"
    sudo tee "$GRUB_FILTER_AWK" > /dev/null << 'EOF'
# Ubuntu Ultimate Tools: quita del menú de GRUB las entradas cuyo título está en la lista
# (líneas "script|título"). Una entrada ocupa desde su línea "menuentry" hasta la
# llave que la cierra. En su lugar queda "true" (no hace nada): si la entrada
# estaba sola dentro de un "if ... then ... fi", un bloque vacío es un error de
# sintaxis y update-grub falla.
BEGIN {
    while ((getline line < list) > 0) {
        sub(/^[^|]*\|/, "", line)
        if (line != "") hide[line] = 1
    }
    close(list)
}
skip > 0 { skip += gsub(/\{/, "{") - gsub(/\}/, "}"); next }
/^[ \t]*menuentry / {
    t = $0
    sub(/^[ \t]*menuentry[ \t]+['"]/, "", t)
    sub(/['"].*/, "", t)
    if (t in hide) {
        match($0, /^[ \t]*/)
        print substr($0, 1, RLENGTH) "true"
        skip = gsub(/\{/, "{") - gsub(/\}/, "}")
        if (skip < 0) skip = 0
        next
    }
}
{ print }
EOF
}

# Envoltorio que reemplaza a un script de GRUB y filtra sus entradas
write_grub_filter_wrapper() {
    local orig="$1"
    sudo tee "${orig}_ubuntu_ultimate_tools" > /dev/null << EOF
#!/bin/sh
# Ubuntu Ultimate Tools: genera las entradas de ${orig##*/} sin las ocultas (ver $GRUB_HIDDEN_LIST)
ORIG='$orig'
[ -f "\$ORIG" ] || exit 0
# Si una actualización volvió a activar el original, este filtro se aparta (sin duplicados)
[ -x "\$ORIG" ] && exit 0
sh "\$ORIG" | awk -v list='$GRUB_HIDDEN_LIST' -f '$GRUB_FILTER_AWK'
EOF
    sudo chmod +x "${orig}_ubuntu_ultimate_tools"
    sudo chmod -x "$orig"
}

remove_grub_filter_wrapper() {
    local orig="$1"
    sudo rm -f "${orig}_ubuntu_ultimate_tools"
    [ -f "$orig" ] && sudo chmod +x "$orig"
}

# Entradas del grub.cfg actual: "script|ruta visible|título"
grub_cfg_entries() {
    sudo awk -v q="'" '
        /^### BEGIN / { src = $3; next }
        /^submenu / { s = $0; sub("^submenu[ \t]+[" q "\"]", "", s); sub("[" q "\"].*", "", s); next }
        /^}/ { s = ""; next }
        /^[ \t]*menuentry / {
            t = $0; sub("^[ \t]*menuentry[ \t]+[" q "\"]", "", t); sub("[" q "\"].*", "", t)
            print src "|" (s != "" ? s " › " t : t) "|" t
        }
    ' /boot/grub/grub.cfg 2>/dev/null
}

grub_hide_entries() {
    # Con Grub Customizer activo sus *_proxy duplican las entradas y aplican sus
    # propias reglas: hay que deshacerlo antes de filtrar
    if [ -d /etc/grub.d/proxifiedScripts ]; then
        echo -e "${YELLOW}⚠ Grub Customizer está activo: genera cada entrada dos veces y aplica sus propias${NC}"
        echo -e "${YELLOW}  reglas, así que primero hay que deshacer sus cambios (se guarda una copia).${NC}\n"
        undo_grub_customizer || return 1
        [ -d /etc/grub.d/proxifiedScripts ] && return 0
        echo ""
    fi
    local entries=() tags=() line src shown title i=0 hidden=()
    on() { if "$@"; then echo "|ON"; fi; }
    [ -f "$GRUB_HIDDEN_LIST" ] && mapfile -t hidden < "$GRUB_HIDDEN_LIST"

    # Grupos completos
    entries+=("recuperacion|[Grupo] Todos los modos de recuperación$(on grep -q '^GRUB_DISABLE_RECOVERY=true' /etc/default/grub)")
    tags+=("recuperacion|")
    if grub_scripts_hidden memtest86+; then
        entries+=("memtest|[Grupo] Toda la prueba de memoria (memtest86+)|ON"); tags+=("memtest|")
    fi
    if grub_scripts_hidden uefi-firmware; then
        entries+=("uefi|[Grupo] Configuración de la UEFI|ON"); tags+=("uefi|")
    fi

    # Cada entrada del menú actual (las de recuperación van en su grupo)
    while IFS='|' read -r src shown title; do
        [[ "$src" == *ubuntu_ultimate_tools_otros_primero* || "$src" == *_ubuntu_ultimate_tools ]] && src=${src%_ubuntu_ultimate_tools}
        [[ "${title,,}" == *recovery* || "${title,,}" == *recuperaci* ]] && continue
        i=$((i + 1))
        entries+=("e$i|$shown")
        tags+=("e$i|$src|$title")
    done < <(grub_cfg_entries)
    # Y las que ya están ocultas (no salen en el menú actual)
    for line in "${hidden[@]}"; do
        [ -n "$line" ] || continue
        i=$((i + 1))
        entries+=("e$i|${line#*|} (oculta)|ON")
        tags+=("e$i|$line")
    done

    CHECKLIST_NOTAGS=true checklist_select "Ocultar entradas" \
        "Marca TODAS las entradas que quieres OCULTAR del menú (las ya ocultas aparecen marcadas)" \
        "${entries[@]}" || return 0
    clear
    local chosen=" ${CHOSEN[*]} " tag new_hidden=() scripts=() script title_only kubuntu_left=0 kubuntu_total=0

    if [[ "$chosen" == *" recuperacion "* ]]; then set_grub_var GRUB_DISABLE_RECOVERY true; else set_grub_var GRUB_DISABLE_RECOVERY false; fi
    [[ "$chosen" != *" memtest "* ]] && grub_scripts_hidden memtest86+ && grub_scripts_chmod +x memtest86+
    [[ "$chosen" != *" uefi "* ]] && grub_scripts_hidden uefi-firmware && grub_scripts_chmod +x uefi-firmware

    for tag in "${tags[@]}"; do
        [[ "$tag" == e* ]] || continue
        IFS='|' read -r _ script title_only <<< "$tag"
        if [[ "$script" == */10_linux ]]; then
            kubuntu_total=$((kubuntu_total + 1))
            [[ "$chosen" == *" ${tag%%|*} "* ]] || kubuntu_left=$((kubuntu_left + 1))
        fi
        [[ "$chosen" == *" ${tag%%|*} "* ]] && new_hidden+=("$script|$title_only")
    done
    if [ "$kubuntu_total" -gt 0 ] && [ "$kubuntu_left" -eq 0 ]; then
        log_error "No puedes ocultar todas las entradas de ${FLAVOR_NAME}: no podrías arrancarlo. No se cambió nada."
        return 1
    fi

    local previous=""
    [ -f "$GRUB_HIDDEN_LIST" ] && previous=$(cat "$GRUB_HIDDEN_LIST")
    write_grub_filter
    printf '%s\n' "${new_hidden[@]}" | sed '/^$/d' | sort -u | sudo tee "$GRUB_HIDDEN_LIST" > /dev/null
    # Filtro solo en los scripts que tienen algo oculto
    mapfile -t scripts < <(printf '%s\n' "${new_hidden[@]}" | cut -d'|' -f1 | sed '/^$/d' | sort -u)
    local wrapper orig
    for wrapper in /etc/grub.d/*_ubuntu_ultimate_tools; do
        [ -f "$wrapper" ] || continue
        orig=${wrapper%_ubuntu_ultimate_tools}
        printf '%s\n' "${scripts[@]}" | grep -qxF "$orig" || remove_grub_filter_wrapper "$orig"
    done
    for script in "${scripts[@]}"; do
        [[ "$script" == *ubuntu_ultimate_tools_otros_primero ]] && continue
        [ -f "$script" ] && write_grub_filter_wrapper "$script"
    done
    # "Otros sistemas primero" llama a os-prober por su cuenta: también usa el filtro
    [ -f "$GRUB_OTHERS_FIRST" ] && write_others_first_script

    if regen_grub; then
        log_success "Menú actualizado: ${#new_hidden[@]} entradas ocultas"
        return 0
    fi
    # Seguro: si el menú nuevo no se pudo generar, se vuelve a la lista anterior
    log_warning "Se deshace este último cambio para que el menú siga funcionando"
    printf '%s\n' "$previous" | sed '/^$/d' | sudo tee "$GRUB_HIDDEN_LIST" > /dev/null
    regen_grub && log_success "Menú de arranque como estaba antes de este cambio"
    return 1
}

write_others_first_script() {
    sudo tee "$GRUB_OTHERS_FIRST" > /dev/null << 'EOF'
#!/bin/sh
# Ubuntu Ultimate Tools: muestra los otros sistemas (Windows, otras distros) antes que Ubuntu.
# El script de os-prober puede estar en su sitio o movido por Grub Customizer; si no
# está, no hace nada (nunca debe hacer fallar update-grub).
GRUB_DISABLE_OS_PROBER=false
export GRUB_DISABLE_OS_PROBER
for script in /etc/grub.d/30_os-prober /etc/grub.d/proxifiedScripts/os-prober; do
    if [ -f "$script" ]; then
        if [ -f /etc/ubuntu-ultimate-tools/grub-filtro.awk ]; then
            sh "$script" | awk -v list=/etc/ubuntu-ultimate-tools/grub-ocultas -f /etc/ubuntu-ultimate-tools/grub-filtro.awk
        else
            sh "$script"
        fi
        exit 0
    fi
done
exit 0
EOF
    sudo chmod +x "$GRUB_OTHERS_FIRST"
}

# Otros sistemas antes que Ubuntu: un script que corre antes que 10_linux llama a
# 30_os-prober, y el original queda desactivado con GRUB_DISABLE_OS_PROBER=true.
grub_others_first_toggle() {
    if [ -f "$GRUB_OTHERS_FIRST" ]; then
        confirm "${PURPLE}Los otros sistemas ya aparecen primero. ¿Volver a mostrar ${FLAVOR_NAME} primero?${NC}" || return 0
        sudo rm -f "$GRUB_OTHERS_FIRST"
        set_grub_var GRUB_DISABLE_OS_PROBER false
        regen_grub && log_success "${FLAVOR_NAME} vuelve a estar primero en el menú"
        return
    fi
    confirm "${PURPLE}¿Mostrar Windows y los otros sistemas ANTES que ${FLAVOR_NAME} en el menú?${NC}" || return 0
    command -v os-prober &> /dev/null || { apt_update; apt_install os-prober || return 1; }
    write_others_first_script
    set_grub_var GRUB_DISABLE_OS_PROBER true
    # Que el orden no cambie lo que arranca solo: Ubuntu sigue siendo el predeterminado
    ensure_grub_saved
    [ $? -eq 1 ] && return 1
    regen_grub || return 1
    local saved kubuntu
    saved=$(sudo grub-editenv list 2>/dev/null | sed -n 's/^saved_entry=//p')
    if [ -z "$saved" ] || [ "$saved" = "0" ]; then
        kubuntu=$(grub_menu_entries | grep -m1 '^gnulinux-simple-' | cut -d'|' -f1)
        [ -n "$kubuntu" ] && sudo grub-set-default "$kubuntu"
    fi
    log_success "Los otros sistemas aparecen primero (${FLAVOR_NAME} sigue arrancando por defecto; cámbialo con la opción 6)"
}

grub_remember_last_toggle() {
    if grep -q '^GRUB_SAVEDEFAULT=true' /etc/default/grub; then
        confirm "${PURPLE}GRUB recuerda el último sistema elegido. ¿Desactivarlo?${NC}" || return 0
        set_grub_var GRUB_SAVEDEFAULT false
        regen_grub && log_success "GRUB arrancará siempre la entrada por defecto (opción 6)"
        return
    fi
    confirm "${PURPLE}¿Que GRUB arranque solo el último sistema que elegiste en el menú?${NC}" || return 0
    ensure_grub_saved
    [ $? -eq 1 ] && return 1
    set_grub_var GRUB_SAVEDEFAULT true
    regen_grub && log_success "GRUB recordará el último sistema elegido"
}

# Colores del menú (nombres de color de GRUB: texto/fondo; "black" deja ver el fondo)
grub_set_colors() {
    local color_text="$1" color_selected="$2"
    sudo tee "$GRUB_LOOK_FILE" > /dev/null << EOF
#!/bin/sh
# Ubuntu Ultimate Tools: colores del menú de GRUB
cat << 'COLORES'
set color_normal=light-gray/black
set menu_color_normal=$color_text
set menu_color_highlight=$color_selected
COLORES
EOF
    sudo chmod +x "$GRUB_LOOK_FILE"
}

grub_appearance_menu() {
    local option file ext
    echo -e "  ${PURPLE}1)${NC} Colores Tokyo Night (azul y lila)"
    echo -e "  ${PURPLE}2)${NC} Colores alto contraste (blanco y negro)"
    echo -e "  ${PURPLE}3)${NC} Colores verde terminal"
    echo -e "  ${PURPLE}4)${NC} Colores originales de Ubuntu"
    echo -e "  ${PURPLE}5)${NC} Imagen de fondo (PNG o JPG)"
    echo -e "  ${PURPLE}6)${NC} Quitar la imagen de fondo"
    echo -e "  ${PURPLE}7)${NC} Resolución del menú"
    echo -e "\n  ${PURPLE}0)${NC} 🔙 Volver"
    echo ""
    read -r -p "📌 Opción: " option
    case $option in
        1) grub_set_colors light-blue/black black/light-magenta ;;
        2) grub_set_colors white/black black/white ;;
        3) grub_set_colors light-green/black black/light-green ;;
        4) sudo rm -f "$GRUB_LOOK_FILE" ;;
        5)
            read -r -p "🖼 Ruta de la imagen (puedes arrastrarla desde Dolphin): " file
            file=${file//\'/}
            file=${file/#\~/$HOME}
            ext=$(tr '[:upper:]' '[:lower:]' <<< "${file##*.}")
            if [ ! -f "$file" ] || [[ ! "$ext" =~ ^(png|jpg|jpeg|tga)$ ]]; then
                log_error "No es una imagen PNG, JPG o TGA: $file"
                return 1
            fi
            # Dentro de /boot/grub, donde GRUB la puede leer al arrancar
            sudo rm -f /boot/grub/ubuntu-ultimate-tools-fondo.*
            sudo cp "$file" "/boot/grub/ubuntu-ultimate-tools-fondo.$ext"
            set_grub_var GRUB_BACKGROUND "\"/boot/grub/ubuntu-ultimate-tools-fondo.$ext\""
            ;;
        6)
            backup_grub_config
            sudo sed -i '/^GRUB_BACKGROUND=/d' /etc/default/grub
            sudo rm -f /boot/grub/ubuntu-ultimate-tools-fondo.*
            ;;
        7)
            echo -e "  1) Automática  2) 1920x1080  3) 1366x768  4) 1280x1024  5) 1024x768  0) Volver"
            read -r -p "📌 Resolución: " option
            case $option in
                1) set_grub_var GRUB_GFXMODE auto ;;
                2) set_grub_var GRUB_GFXMODE 1920x1080 ;;
                3) set_grub_var GRUB_GFXMODE 1366x768 ;;
                4) set_grub_var GRUB_GFXMODE 1280x1024 ;;
                5) set_grub_var GRUB_GFXMODE 1024x768 ;;
                *) echo -e "${YELLOW}ℹ No se cambió nada${NC}"; return 0 ;;
            esac
            ;;
        *) echo -e "${YELLOW}ℹ No se cambió nada${NC}"; return 0 ;;
    esac
    regen_grub && log_success "Apariencia del menú actualizada (se ve al reiniciar)"
    if grep -q '^GRUB_TIMEOUT_STYLE=hidden' /etc/default/grub; then
        echo -e "${YELLOW}ℹ El menú está oculto al arrancar: dale unos segundos con la opción 6 para verlo${NC}"
    fi
}

# Parámetros con los que arranca el kernel (GRUB_CMDLINE_LINUX_DEFAULT)
grub_kernel_params_menu() {
    local current option params word
    current=$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT=//p' /etc/default/grub | tr -d '"')
    echo -e "${PURPLE}⚙ Parámetros actuales:${NC} ${current:-(ninguno)}\n"
    echo -e "  ${PURPLE}1)${NC} Ver los mensajes al arrancar (quita 'quiet splash': útil si algo falla)"
    echo -e "  ${PURPLE}2)${NC} Arranque silencioso con logo (pone 'quiet splash', lo normal en Ubuntu)"
    echo -e "  ${PURPLE}3)${NC} Escribirlos a mano"
    echo -e "\n  ${PURPLE}0)${NC} 🔙 Volver"
    echo ""
    read -r -p "📌 Opción: " option
    case $option in
        1|2)
            params=""
            for word in $current; do
                [[ "$word" == "quiet" || "$word" == "splash" ]] || params+="$word "
            done
            [ "$option" = 2 ] && params="quiet splash $params"
            ;;
        3)
            read -r -e -i "$current" -p "✏ Parámetros: " params
            ;;
        *) echo -e "${YELLOW}ℹ No se cambió nada${NC}"; return 0 ;;
    esac
    params=$(xargs <<< "$params")
    set_grub_var GRUB_CMDLINE_LINUX_DEFAULT "\"$params\""
    regen_grub && log_success "Parámetros del kernel: ${params:-(ninguno)} (se aplican al reiniciar)"
}

# Deshace los cambios de Grub Customizer en /etc/grub.d sin usar el programa:
# cada script original de un paquete vuelve a su nombre (desde su copia renumerada,
# desde proxifiedScripts o reinstalando el paquete) y se quita todo lo demás.
# Antes se guarda una copia completa de /etc/grub.d.
undo_grub_customizer() {
    if [ ! -d /etc/grub.d/proxifiedScripts ]; then
        echo -e "${GREEN}✓ Grub Customizer no modificó /etc/grub.d${NC}"
        return 0
    fi
    echo -e "${PURPLE}Grub Customizer cambió los scripts de GRUB: los renumeró, los movió a${NC}"
    echo -e "${PURPLE}proxifiedScripts y puso los suyos (*_proxy). Esto los deja como los instala Ubuntu.${NC}\n"
    confirm "${PURPLE}¿Deshacer los cambios de Grub Customizer?${NC}" || return 0

    local backup
    backup="/etc/grub.d.antes-de-deshacer-grub-customizer-$(date +%Y%m%d-%H%M%S)"
    run "No se pudo hacer la copia de seguridad" sudo cp -a /etc/grub.d "$backup" || return 1
    log_success "Copia de seguridad: $backup"

    # Scripts que instalan los paquetes (grub-common, memtest86+, fwupd...)
    local owned=() pkgs=() path name candidate missing_pkgs=()
    mapfile -t owned < <(dpkg-query -S '/etc/grub.d/*' 2>/dev/null | grep -v '^diversion' \
        | awk -F': ' '$2 ~ "^/etc/grub.d/[^/]+$" {print $2}' | sort -u)
    # Seguro: sin la lista de los originales no se toca nada (se borraría todo)
    if ! printf '%s\n' "${owned[@]}" | grep -q '/00_header$' \
        || ! printf '%s\n' "${owned[@]}" | grep -q '/10_linux$'; then
        log_error "No se pudo saber qué scripts instala Ubuntu: no se cambió nada"
        return 1
    fi
    for path in "${owned[@]}"; do
        [ -f "$path" ] && continue
        name=${path##*/}
        name=${name#[0-9][0-9]_}
        candidate=""
        for candidate in /etc/grub.d/[0-9][0-9]_"$name" /etc/grub.d/proxifiedScripts/"$name"; do
            # Nunca otro original con el mismo nombre (40_custom y 41_custom son distintos)
            [ -f "$candidate" ] && ! printf '%s\n' "${owned[@]}" | grep -qxF "$candidate" && break
            candidate=""
        done
        if [ -n "$candidate" ]; then
            sudo mv "$candidate" "$path"
            sudo chmod +x "$path"
            echo -e "  ${GREEN}✓ ${path##*/} vuelve a su lugar${NC}"
        else
            mapfile -t pkgs < <(dpkg-query -S "$path" 2>/dev/null | cut -d: -f1 | tr ',' '\n' | xargs -n1)
            missing_pkgs+=("${pkgs[@]}")
        fi
    done

    # Todo lo que no es de un paquete ni de este script: proxies, copias, bin/, backup/...
    local entry keep
    for entry in /etc/grub.d/* /etc/grub.d/.script_sources.txt; do
        [ -e "$entry" ] || continue
        keep=false
        printf '%s\n' "${owned[@]}" | grep -qxF "$entry" && keep=true
        [[ "${entry##*/}" == *ubuntu_ultimate_tools* || "${entry##*/}" == README ]] && keep=true
        $keep || sudo rm -rf "$entry"
    done

    # Los que no tenían copia se recuperan del paquete (dpkg repone los archivos que faltan)
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        mapfile -t missing_pkgs < <(printf '%s\n' "${missing_pkgs[@]}" | sort -u)
        echo -e "${PURPLE}📦 Recuperando del paquete: ${missing_pkgs[*]}${NC}"
        apt_update
        run "No se pudieron recuperar los scripts originales" sudo env DEBIAN_FRONTEND=noninteractive \
            apt-get install --reinstall -y -o Dpkg::Options::=--force-confmiss "${missing_pkgs[@]}"
    fi

    if regen_grub; then
        log_success "Cambios de Grub Customizer deshechos"
    else
        log_error "update-grub sigue fallando: la copia de /etc/grub.d está en $backup"
        return 1
    fi
    if installed_pkgs grub-customizer | grep -qx grub-customizer \
        && confirm "${PURPLE}¿Desinstalar Grub Customizer para que no vuelva a cambiar el menú?${NC}"; then
        apt_purge grub-customizer && forget_installed grub-customizer
    fi
}

grub_restore_original() {
    if [ ! -f "$GRUB_DEFAULT_BACKUP" ] && [ ! -f "$GRUB_LOOK_FILE" ] && [ ! -f "$GRUB_OTHERS_FIRST" ] \
        && [ ! -f "$GRUB_HIDDEN_LIST" ]; then
        echo -e "${GREEN}✓ El menú de GRUB no tiene cambios del script${NC}"
        return 0
    fi
    confirm "${PURPLE}¿Volver el menú de GRUB a como estaba antes de usar el script?${NC}" || return 0
    if [ -f "$GRUB_DEFAULT_BACKUP" ]; then
        sudo cp -p "$GRUB_DEFAULT_BACKUP" /etc/default/grub && sudo rm -f "$GRUB_DEFAULT_BACKUP"
    fi
    sudo rm -f "$GRUB_LOOK_FILE" "$GRUB_OTHERS_FIRST" /boot/grub/ubuntu-ultimate-tools-fondo.*
    local wrapper
    for wrapper in /etc/grub.d/*_ubuntu_ultimate_tools; do
        [ -f "$wrapper" ] && remove_grub_filter_wrapper "${wrapper%_ubuntu_ultimate_tools}"
    done
    sudo rm -f "$GRUB_HIDDEN_LIST" "$GRUB_FILTER_AWK"
    grub_scripts_chmod +x memtest86+
    grub_scripts_chmod +x uefi-firmware
    regen_grub && run "No se pudo fijar el kernel por defecto" sudo grub-set-default 0 \
        && log_success "Menú de GRUB restaurado"
}

grub_customize_menu() {
    local entry
    while true; do
        grub_guide_header "🎨 PERSONALIZAR MENÚ DE GRUB"
        echo -e "${PURPLE}📋 Así se ve ahora el menú:${NC}"
        while IFS= read -r entry; do
            echo "   • ${entry#*|}"
        done < <(grub_menu_entries)
        if [ -d /etc/grub.d/proxifiedScripts ]; then
            echo -e "\n${YELLOW}⚠ Grub Customizer modificó este menú: usa la opción 7 para deshacerlo.${NC}"
        fi
        echo ""
        echo -e "  ${PURPLE}1)${NC} Ocultar o mostrar entradas: marca cada una (kernels, Windows, memtest...)"
        echo -e "  ${PURPLE}2)${NC} Orden: otros sistemas (Windows...) antes o después de ${FLAVOR_NAME}"
        echo -e "  ${PURPLE}3)${NC} Recordar el último sistema elegido"
        echo -e "  ${PURPLE}4)${NC} Apariencia: colores, imagen de fondo y resolución"
        echo -e "  ${PURPLE}5)${NC} Parámetros de arranque del kernel"
        echo -e "  ${PURPLE}6)${NC} Restaurar el menú original (deshace los cambios de este script)"
        echo -e "  ${PURPLE}7)${NC} Deshacer los cambios de Grub Customizer"
        echo -e "\n  ${PURPLE}0)${NC} 🔙 Volver"
        echo -e "\n${YELLOW}ℹ Qué arranca por defecto y cuánto espera el menú: opción 6 del menú de GRUB${NC}\n"
        read -r -p "📌 Opción (0-7): " custom_option
        case $custom_option in
            1) grub_hide_entries ;;
            2) grub_others_first_toggle ;;
            3) grub_remember_last_toggle ;;
            4) grub_appearance_menu ;;
            5) grub_kernel_params_menu ;;
            6) grub_restore_original ;;
            7) undo_grub_customizer ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ------------------------------------------------------------
# Reparación completa (sin programas externos)
# ------------------------------------------------------------

# Quita rEFInd (versiones anteriores del script podían instalarlo) y vuelve a GRUB
remove_refind() {
    apt_purge refind && forget_installed refind
    # Su entrada UEFI y sus archivos en la partición EFI no se borran con el paquete
    local num
    for num in $(LC_ALL=C efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} \{1,\}rEFInd.*/\1/p'); do
        run "No se pudo quitar la entrada UEFI de rEFInd" sudo efibootmgr -b "$num" -B
    done
    sudo rm -rf /boot/efi/EFI/refind
    log_success "rEFInd quitado"
}

# Pone primera la entrada UEFI de Ubuntu (todos los sabores usan "ubuntu")
uefi_ubuntu_first() {
    local out order num new_order
    out=$(LC_ALL=C efibootmgr 2>/dev/null)
    order=$(sed -n 's/^BootOrder: //p' <<< "$out")
    num=$(sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} \{1,\}[Uu]buntu.*/\1/p' <<< "$out" | head -1)
    [ -n "$num" ] || return 0
    [ "${order%%,*}" = "$num" ] && return 0
    new_order=$(tr ',' '\n' <<< "$order" | grep -vix "$num" | paste -sd, -)
    run "No se pudo cambiar el orden de arranque" sudo efibootmgr -o "$num${new_order:+,$new_order}"
}

grub_full_repair() {
    grub_guide_header "🛠️ REPARACIÓN COMPLETA DEL ARRANQUE"
    local uefi=false disk step=0 total=4 failed=()
    [ -d /sys/firmware/efi ] && { uefi=true; total=7; }

    echo -e "${PURPLE}📋 Se hará, en orden:${NC}"
    $uefi && echo -e "  • Verificar y reparar la partición EFI"
    echo -e "  • Reinstalar los paquetes de GRUB$($uefi && echo " (y shim para Secure Boot)")"
    echo -e "  • Reinstalar GRUB en $($uefi && echo "la partición EFI" || echo "el disco del sistema")"
    echo -e "  • Regenerar el menú de arranque"
    $uefi && echo -e "  • Poner ${FLAVOR_NAME} primero en el orden de arranque UEFI"
    $uefi && echo -e "  • Arranque de respaldo UEFI (se pregunta; si ya está, se actualiza)"
    echo -e "  • Comprobar el resultado y actualizar la tarjeta de rescate"
    echo -e "\n${YELLOW}ℹ Para un sistema que NO arranca, usa la opción 10 desde un Live USB${NC}\n"
    confirm "${PURPLE}¿Empezar la reparación completa?${NC}" || return 0

    if installed_pkgs refind | grep -qx refind \
        && confirm "${PURPLE}rEFInd está instalado y puede tapar a GRUB. ¿Quitarlo?${NC}"; then
        remove_refind
    fi

    if $uefi; then
        step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Partición EFI...${NC}"
        if findmnt /boot/efi > /dev/null 2>&1; then
            esp_fsck "$(findmnt -no SOURCE /boot/efi)" || failed+=("partición EFI")
        else
            log_error "No hay partición EFI montada en /boot/efi"
            failed+=("partición EFI")
        fi
    fi

    step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Reinstalando los paquetes de GRUB...${NC}"
    local pkgs=(grub-pc)
    $uefi && pkgs=(grub-efi-amd64 grub-efi-amd64-signed shim-signed)
    apt_update
    run_visible "No se pudieron reinstalar los paquetes de GRUB" \
        sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" install --reinstall "${pkgs[@]}" \
        || failed+=("paquetes de GRUB")

    step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Reinstalando GRUB...${NC}"
    if $uefi; then
        run_visible "Falló grub-install" sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi \
            --bootloader-id=ubuntu --recheck || failed+=("grub-install")
    else
        disk=$(lsblk -rnso NAME,TYPE "$(findmnt -no SOURCE /)" 2>/dev/null | awk '$2 == "disk" {print $1; exit}')
        if [ -n "$disk" ]; then
            run_visible "Falló grub-install" sudo grub-install --target=i386-pc --recheck "/dev/$disk" || failed+=("grub-install")
        else
            log_error "No se pudo detectar el disco del sistema (usa la opción 4)"
            failed+=("grub-install")
        fi
    fi

    step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Regenerando el menú...${NC}"
    run_visible "Falló update-grub" sudo update-grub || failed+=("update-grub")

    if $uefi; then
        step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Orden de arranque UEFI...${NC}"
        uefi_ubuntu_first || failed+=("orden UEFI")
        step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Arranque de respaldo UEFI...${NC}"
        if [ "$(uefi_fallback_state)" = nuestro ]; then
            install_uefi_fallback || failed+=("arranque de respaldo")
        elif [ "$(uefi_fallback_state)" = vacio ]; then
            echo -e "${CYAN}ℹ Si la BIOS pierde la entrada de Ubuntu (al actualizarla o resetearla), la PC no arranca.${NC}"
            echo -e "${CYAN}  El arranque de respaldo lo evita: arranca igual y Ubuntu vuelve a crear su entrada.${NC}"
            if confirm "${PURPLE}¿Instalar el arranque de respaldo? (recomendado)${NC}"; then
                install_uefi_fallback || failed+=("arranque de respaldo")
            fi
        else
            echo -e "${CYAN}ℹ La ruta de respaldo la usa otro sistema: no se toca (opción 15 para más detalles)${NC}"
        fi
    fi

    step=$((step + 1)); echo -e "\n${PURPLE}[$step/$total] Comprobando...${NC}"
    local entry_count
    entry_count=$(grub_menu_entries | wc -l)
    if [ -s /boot/grub/grub.cfg ] && [ "$entry_count" -gt 0 ]; then
        log_success "El menú de GRUB tiene $entry_count entradas"
    else
        log_error "El menú de GRUB quedó vacío"
        failed+=("comprobación")
    fi
    if $uefi && ! LC_ALL=C efibootmgr 2>/dev/null | grep -qi 'ubuntu'; then
        log_error "No hay entrada UEFI de Ubuntu"
        failed+=("entrada UEFI")
    fi
    if [ -f "$RESCUE_CARD" ]; then
        rescue_card_refresh && log_success "Tarjeta de rescate actualizada ($RESCUE_CARD)"
    else
        echo -e "${CYAN}💡 Consejo: genera tu tarjeta de rescate (opción 14) para estar preparado si falla otra vez${NC}"
    fi

    echo ""
    if [ ${#failed[@]} -eq 0 ]; then
        log_success "Reparación completa terminada sin errores"
    else
        log_error "Pasos con problemas: ${failed[*]}. Detalles en: $LOG_FILE"
    fi
}

# ------------------------------------------------------------
# Prepararse antes de que falle: tarjeta de rescate y arranque de respaldo
# ------------------------------------------------------------

RESCUE_CARD="$HOME/tarjeta-rescate-arranque.txt"
RESCUE_CARD_ESP="/boot/efi/tarjeta-rescate-arranque.txt"

# Datos del arranque de ESTA PC, como los ve GRUB. Deja variables rc_* listas para la tarjeta.
rescue_card_collect() {
    local grubdir=/boot/grub mnt fsroot rel dev part disk pnum pttype idx name
    rc_ok=false rc_approx=false rc_crypt=false rc_lvm=false
    [ -d "$grubdir" ] || return 1
    dev=$(findmnt -no SOURCE -T "$grubdir" 2>/dev/null | sed 's/\[.*//')
    [ -b "$dev" ] || return 1
    mnt=$(findmnt -no TARGET -T "$grubdir")
    fsroot=$(findmnt -no FSROOT -T "$grubdir")
    rel=${grubdir#"${mnt%/}"}
    # Ruta de /boot/grub DENTRO de su partición (con /boot aparte es /grub; con btrfs @ es /@/boot/grub)
    rc_grubpath="${fsroot%/}$rel"
    rc_bootpath="${rc_grubpath%/grub}"
    rc_uuid=$(lsblk -no UUID "$dev" 2>/dev/null | head -n1)
    rc_fstype=$(lsblk -no FSTYPE "$dev" 2>/dev/null | head -n1)
    rc_size=$(lsblk -no SIZE "$dev" 2>/dev/null | head -n1 | tr -d ' ')
    rc_dev=$dev

    local abstraction
    abstraction=$(sudo grub-probe --target=abstraction "$grubdir" 2>/dev/null)
    [[ "$abstraction" == *crypt* || "$abstraction" == *luks* ]] && rc_crypt=true
    [[ "$abstraction" == *lvm* ]] && rc_lvm=true
    if lsblk -no TYPE "$dev" 2>/dev/null | grep -qx crypt; then rc_crypt=true; fi

    # Nombre de la partición para GRUB, p. ej. (hd0,gpt2)
    name=$(sudo grub-probe --target=drive "$grubdir" 2>/dev/null)
    if [[ "$name" =~ ^\((hd[0-9]+,(gpt|msdos)[0-9]+|lvm/[^\)]+)\)$ ]]; then
        rc_drive=${name:1:-1}
    else
        # grub-probe no lo sabe: se calcula (el número de disco puede variar)
        part=$(basename "$(readlink -f "$dev")")
        disk=$(lsblk -no PKNAME "/dev/$part" 2>/dev/null | head -n1)
        pnum=$(cat "/sys/class/block/$part/partition" 2>/dev/null)
        pttype=$(lsblk -dno PTTYPE "/dev/$disk" 2>/dev/null)
        [ "$pttype" = dos ] && pttype=msdos
        [ -n "$disk" ] && [ -n "$pnum" ] && [ -n "$pttype" ] || return 1
        idx=$(lsblk -dno NAME,TYPE,RM 2>/dev/null | awk '$2 == "disk" && $3 == 0 {print $1}' | grep -nx "$disk" | cut -d: -f1)
        rc_drive="hd$(( ${idx:-1} - 1 )),$pttype$pnum"
        rc_approx=true
    fi

    # Parámetros del kernel con los que arrancó este sistema (root= y, si hay, rootflags=)
    rc_root=$(tr ' ' '\n' < /proc/cmdline | grep -E '^(root|rootflags)=' | paste -sd' ')
    rc_kernel="$rc_bootpath/vmlinuz"
    rc_initrd="$rc_bootpath/initrd.img"
    [ -e /boot/vmlinuz ] || rc_kernel="$rc_bootpath/vmlinuz-$(uname -r)"
    [ -e /boot/initrd.img ] || rc_initrd="$rc_bootpath/initrd.img-$(uname -r)"
    [ -n "$rc_uuid" ] && [ -n "$rc_root" ] && rc_ok=true
}

# La tarjeta en texto plano (para guardar, imprimir o fotografiar)
rescue_card_text() {
    local mode=BIOS
    [ -d /sys/firmware/efi ] && mode=UEFI
    echo "================================================================"
    echo " TARJETA DE RESCATE DEL ARRANQUE - $(os_release_value PRETTY_NAME)"
    echo " Generada el $(date '+%d/%m/%Y') con Ubuntu Ultimate Tools"
    echo "================================================================"
    echo ""
    echo " Partición de arranque: $rc_dev ($rc_fstype, $rc_size) - modo $mode"
    $rc_crypt || echo " GRUB la llama: ($rc_drive)$($rc_approx && echo "  (calculado: si falla, prueba hd0, hd1, hd2...)")"
    echo " Su UUID (identificador único): $rc_uuid"
    echo ""
    if $rc_crypt; then
        echo " ATENCIÓN: /boot está en un disco cifrado. Desde 'grub>' o"
        echo " 'grub rescue>' no se puede arrancar a mano: usa un Live USB y"
        echo " este script, opción 12 -> 10 (reparación automática)."
        echo ""
    else
        echo "----------------------------------------------------------------"
        echo " A) SI AL ENCENDER VES  grub>"
        echo "----------------------------------------------------------------"
        echo " Escribe estas 2 líneas (Enter después de cada una):"
        echo ""
        $rc_lvm && echo "    insmod lvm"
        echo "    search --no-floppy --fs-uuid --set=root $rc_uuid"
        echo "    configfile $rc_grubpath/grub.cfg"
        echo ""
        echo " Aparece el menú de siempre: elige tu sistema."
        echo " Si dice 'no such device' o no aparece el menú, arranca directo:"
        echo ""
        echo "    search --no-floppy --fs-uuid --set=root $rc_uuid"
        echo "    linux $rc_kernel $rc_root ro"
        echo "    initrd $rc_initrd"
        echo "    boot"
        echo ""
        echo "----------------------------------------------------------------"
        echo " B) SI VES  grub rescue>"
        echo "----------------------------------------------------------------"
        echo " Escribe estas 4 líneas:"
        echo ""
        echo "    set prefix=($rc_drive)$rc_grubpath"
        echo "    set root=($rc_drive)"
        echo "    insmod normal"
        echo "    normal"
        echo ""
        echo " Si dice 'no such partition' o 'unknown filesystem', el número"
        echo " cambió (por ejemplo, porque hay un USB conectado). Escribe:"
        echo "    ls"
        echo " y prueba con cada partición hasta que una muestre archivos:"
        echo "    ls (hd0,${rc_drive#*,})$rc_grubpath"
        echo "    ls (hd1,${rc_drive#*,})$rc_grubpath      ...y así"
        echo " Usa esa en las 4 líneas de arriba."
        echo ""
    fi
    echo "----------------------------------------------------------------"
    echo " C) CUANDO VUELVAS A ENTRAR AL SISTEMA"
    echo "----------------------------------------------------------------"
    echo " Arréglalo de forma permanente: este script, opción 12 -> 2"
    echo " (reparación rápida) o 12 -> 3 (reparación completa)."
    echo ""
    echo "----------------------------------------------------------------"
    echo " D) SI NADA DE ESTO FUNCIONA"
    echo "----------------------------------------------------------------"
    echo " Arranca con un USB de instalación de Ubuntu ('Probar Ubuntu'),"
    echo " abre este script desde el pendrive y usa la opción 12 -> 10."
    echo "    bash /media/\$USER/<pendrive>/ubuntu-ultimate-tools.sh"
    echo "================================================================"
}

# Guarda la tarjeta en la carpeta personal y en la partición EFI (sin preguntas)
rescue_card_write() {
    rescue_card_collect && $rc_ok || return 1
    rescue_card_text > "$RESCUE_CARD" || return 1
    # En la partición EFI se puede leer desde un Live USB o desde Windows
    if findmnt /boot/efi > /dev/null 2>&1; then
        sudo cp "$RESCUE_CARD" "$RESCUE_CARD_ESP" 2>> "$LOG_FILE"
    fi
    return 0
}

# Pendrives montados: "carpeta|tamaño libre"
mounted_usb_drives() {
    findmnt -rno TARGET,SOURCE 2>/dev/null | awk '$1 ~ "^(/media/|/run/media/)" {print $1}' | while read -r dir; do
        dir=$(printf '%b' "$dir")   # findmnt escapa los espacios como \x20
        echo "$dir|$(df -h --output=avail "$dir" 2>/dev/null | tail -1 | tr -d ' ') libres"
    done
}

# Copia la tarjeta y el script a un pendrive (para usarlos desde un Live USB)
rescue_copy_to_usb() {
    local drives=() i=0 d choice dir
    mapfile -t drives < <(mounted_usb_drives)
    if [ ${#drives[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No hay ningún pendrive conectado. Conéctalo, ábrelo en el gestor de archivos${NC}"
        echo -e "${YELLOW}  (así queda montado) y vuelve a esta opción.${NC}"
        return 0
    fi
    echo -e "${PURPLE}💾 Pendrives conectados:${NC}"
    for d in "${drives[@]}"; do
        i=$((i + 1))
        echo -e "  ${PURPLE}$i)${NC} ${d%%|*} (${d#*|})"
    done
    echo -e "  ${PURPLE}0)${NC} 🔙 No copiar"
    read -r -p "📌 ¿En cuál copiar? " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#drives[@]} ]; then
        echo -e "${YELLOW}ℹ No se copió nada${NC}"
        return 0
    fi
    dir=${drives[$((choice - 1))]%%|*}
    if cp "$RESCUE_CARD" "$dir/" 2>> "$LOG_FILE" && cp "$SCRIPT_PATH" "$dir/ubuntu-ultimate-tools.sh" 2>> "$LOG_FILE"; then
        sync
        log_success "Copiados en $dir: el script y la tarjeta de rescate"
        echo -e "${CYAN}ℹ Desde el Live USB: bash /media/\$USER/$(basename "$dir")/ubuntu-ultimate-tools.sh → 12 → 10${NC}"
    else
        log_error "No se pudo copiar al pendrive (¿está lleno o protegido contra escritura?)"
    fi
}

rescue_card_menu() {
    grub_guide_header "🪪 TARJETA DE RESCATE DE ESTA PC"
    if is_live_session; then
        log_warning "Esto es un Live USB: la tarjeta se genera desde tu sistema instalado, cuando arranca bien"
        echo -e "${YELLOW}  Si tu sistema no arranca, usa la opción 10.${NC}"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"; read -r
        return 0
    fi
    cat << 'EXPL'
Cuando GRUB se rompe, en lugar del menú aparece "grub>" o "grub rescue>" y hay
que escribir comandos con el nombre exacto de TU disco. Ahí no se puede abrir
este script ni buscar en internet desde la PC.

Esta tarjeta trae esos comandos ya calculados para esta PC. Guárdala ahora,
mientras todo funciona:
  📷 sácale una FOTO con el celular (es lo más seguro: la tienes siempre),
  💾 y cópiala al pendrive junto con este script (opción de abajo).
Se guarda también en tu carpeta personal y en la partición EFI, y se actualiza
sola cada vez que el script cambia GRUB.
EXPL
    echo ""
    if ! rescue_card_write; then
        log_error "No se pudieron leer los datos del arranque (¿falta /boot/grub?). Usa el diagnóstico (opción 1)"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"; read -r
        return 1
    fi
    echo -e "${YELLOW}📌 Presiona Enter para ver la tarjeta...${NC}"; read -r
    clear
    # Los comandos para escribir, resaltados (líneas con sangría)
    sed -E "s/^(    .*)$/$(printf '\033[1;36m')\1$(printf '\033[0m')/" "$RESCUE_CARD"
    echo ""
    echo -e "${GREEN}💾 Guardada en: $RESCUE_CARD${NC}"
    findmnt /boot/efi > /dev/null 2>&1 && echo -e "${GREEN}💾 Copia en la partición EFI: $RESCUE_CARD_ESP${NC}"
    echo ""
    if confirm "${PURPLE}¿Copiar la tarjeta y este script a un pendrive?${NC}"; then
        rescue_copy_to_usb
    fi
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

# Actualiza la tarjeta si ya existe (después de cambiar GRUB o el kernel)
rescue_card_refresh() {
    [ -f "$RESCUE_CARD" ] || return 0
    is_live_session && return 0
    rescue_card_write 2>/dev/null || true
}

# ------------------------------------------------------------
# Arranque de respaldo UEFI: \EFI\BOOT\BOOTX64.EFI es la ruta que el firmware
# prueba cuando no tiene (o perdió) la entrada de Ubuntu. Con el "fallback" de
# shim (fbx64.efi), además vuelve a crear la entrada de Ubuntu solo.
# ------------------------------------------------------------

UEFI_FALLBACK_MARK="$UUT_ETC/arranque-respaldo"
UEFI_FALLBACK_HOOK="/etc/apt/apt.conf.d/99ubuntu-ultimate-tools-arranque-respaldo"
UEFI_FALLBACK_TOOL="/usr/local/sbin/ubuntu-ultimate-tools-arranque-respaldo"
UEFI_FALLBACK_BACKUP="$UUT_ETC/efi-boot-anterior"

# El programa que copia los archivos: lo usa el script y lo llama apt después de
# cada actualización, para que la copia nunca quede vieja.
write_uefi_fallback_tool() {
    sudo install -d -m 755 "$UUT_ETC" /usr/local/sbin
    sudo tee "$UEFI_FALLBACK_TOOL" > /dev/null << 'TOOL'
#!/bin/sh
# Ubuntu Ultimate Tools: mantiene el arranque de respaldo UEFI (\EFI\BOOT) igual
# al de Ubuntu (\EFI\ubuntu). Solo toca \EFI\BOOT si lo puso el script.
MARK=/etc/ubuntu-ultimate-tools/arranque-respaldo
ESP=/boot/efi
[ -d /sys/firmware/efi ] && [ -f "$MARK" ] && mountpoint -q "$ESP" || exit 0
SRC=$(find "$ESP/EFI" -maxdepth 1 -iname ubuntu | head -n1)
DST=$(find "$ESP/EFI" -maxdepth 1 -iname boot | head -n1)
[ -n "$SRC" ] || exit 0
[ -n "$DST" ] || { DST="$ESP/EFI/BOOT"; mkdir -p "$DST"; }
CUR=$(find "$DST" -maxdepth 1 -iname bootx64.efi | head -n1)
# Si otro sistema reemplazó el archivo, no se toca
if [ -n "$CUR" ] && [ "$(sha256sum < "$CUR" | cut -d' ' -f1)" != "$(cat "$MARK")" ]; then
    [ "${1:-}" = "--forzar" ] || exit 0
fi
if [ -f "$SRC/shimx64.efi" ]; then
    cp "$SRC/shimx64.efi" "$DST/BOOTX64.EFI" || exit 0
    for f in grubx64.efi mmx64.efi; do [ -f "$SRC/$f" ] && cp "$SRC/$f" "$DST/$f"; done
    # fbx64.efi vuelve a crear la entrada de Ubuntu en el firmware si se borró
    for f in /usr/lib/shim/fbx64.efi.signed /usr/lib/shim/fbx64.efi; do
        [ -f "$f" ] && { cp "$f" "$DST/fbx64.efi"; break; }
    done
elif [ -f "$SRC/grubx64.efi" ]; then
    cp "$SRC/grubx64.efi" "$DST/BOOTX64.EFI" || exit 0
else
    exit 0
fi
[ -f "$SRC/grub.cfg" ] && cp "$SRC/grub.cfg" "$DST/grub.cfg"
sha256sum < "$DST/BOOTX64.EFI" | cut -d' ' -f1 > "$MARK"
exit 0
TOOL
    sudo chmod 755 "$UEFI_FALLBACK_TOOL"
    echo "DPkg::Post-Invoke { \"$UEFI_FALLBACK_TOOL || true\"; };" | sudo tee "$UEFI_FALLBACK_HOOK" > /dev/null
}

# Estado de \EFI\BOOT\BOOTX64.EFI: vacio | nuestro | windows | otro
uefi_fallback_state() {
    local cur
    cur=$(sudo find /boot/efi/EFI -maxdepth 2 -ipath '*/boot/bootx64.efi' 2>/dev/null | head -n1)
    if [ -z "$cur" ]; then
        echo vacio
    elif [ -f "$UEFI_FALLBACK_MARK" ] && [ "$(sudo sha256sum < "$cur" | cut -d' ' -f1)" = "$(cat "$UEFI_FALLBACK_MARK")" ]; then
        echo nuestro
    elif sudo grep -qa 'Microsoft Corporation' "$cur" && ! sudo grep -qa -i 'shim' "$cur"; then
        echo windows
    else
        echo otro
    fi
}

install_uefi_fallback() {
    local state
    state=$(uefi_fallback_state)
    case $state in
        nuestro)
            write_uefi_fallback_tool
            sudo "$UEFI_FALLBACK_TOOL" --forzar
            log_success "El arranque de respaldo ya estaba puesto: se actualizó"
            return 0 ;;
        windows)
            log_warning "La ruta de respaldo la usa Windows: no se toca (Windows dejaría de arrancar por esa vía)"
            echo -e "${YELLOW}  Si algún día la PC va directo a Windows sin mostrar GRUB: entra al menú de arranque${NC}"
            echo -e "${YELLOW}  del BIOS (F12, F11, F8 o Esc al encender, según la marca), elige ubuntu y luego${NC}"
            echo -e "${YELLOW}  usa este script → 12 → 8 para ponerlo primero.${NC}"
            return 0 ;;
        otro)
            echo -e "${YELLOW}⚠ La ruta de respaldo ya tiene el arranque de otro sistema (otra distro o un programa).${NC}"
            confirm "${PURPLE}¿Reemplazarlo por el de ${FLAVOR_NAME}? (se guarda una copia para volver atrás)${NC}" || return 0
            sudo rm -rf "$UEFI_FALLBACK_BACKUP"
            sudo cp -r "$(sudo find /boot/efi/EFI -maxdepth 1 -iname boot | head -n1)" "$UEFI_FALLBACK_BACKUP" \
                || { log_error "No se pudo guardar la copia: no se cambió nada"; return 1; } ;;
    esac
    write_uefi_fallback_tool
    echo "nuevo" | sudo tee "$UEFI_FALLBACK_MARK" > /dev/null
    sudo "$UEFI_FALLBACK_TOOL" --forzar
    if [ "$(uefi_fallback_state)" = nuestro ]; then
        log_success "Arranque de respaldo instalado en la ruta de respaldo EFI/BOOT (se actualiza solo con cada actualización de GRUB)"
    else
        log_error "No se pudo instalar el arranque de respaldo (¿falta la carpeta EFI/ubuntu? Prueba la reparación completa)"
        sudo rm -f "$UEFI_FALLBACK_MARK" "$UEFI_FALLBACK_HOOK"
        return 1
    fi
}

remove_uefi_fallback() {
    local dir state
    state=$(uefi_fallback_state)
    if [ "$state" != nuestro ]; then
        echo -e "${GREEN}✓ El arranque de respaldo no lo puso este script: no se toca${NC}"
        sudo rm -f "$UEFI_FALLBACK_MARK" "$UEFI_FALLBACK_HOOK" "$UEFI_FALLBACK_TOOL"
        return 0
    fi
    confirm "${PURPLE}¿Quitar el arranque de respaldo?${NC}" || return 0
    dir=$(sudo find /boot/efi/EFI -maxdepth 1 -iname boot | head -n1)
    # Solo los archivos que copia el script; si había otros, se quedan
    sudo find "$dir" -maxdepth 1 -type f \( -iname bootx64.efi -o -iname grubx64.efi -o -iname mmx64.efi \
        -o -iname fbx64.efi -o -iname grub.cfg \) -delete
    if [ -d "$UEFI_FALLBACK_BACKUP" ]; then
        sudo cp -r "$UEFI_FALLBACK_BACKUP/." "$dir/" && sudo rm -rf "$UEFI_FALLBACK_BACKUP" \
            && log_success "Se restauró el arranque de respaldo que había antes"
    fi
    sudo rmdir "$dir" 2>/dev/null
    sudo rm -f "$UEFI_FALLBACK_MARK" "$UEFI_FALLBACK_HOOK" "$UEFI_FALLBACK_TOOL"
    log_success "Arranque de respaldo quitado"
}

uefi_fallback_menu() {
    grub_guide_header "🛟 ARRANQUE DE RESPALDO UEFI"
    if [ ! -d /sys/firmware/efi ]; then
        log_warning "Este equipo arranca en modo BIOS (Legacy): esto es solo para UEFI"
        echo -e "${YELLOW}  En BIOS, GRUB vive en el propio disco y no depende de entradas del firmware.${NC}"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"; read -r
        return 0
    fi
    if ! findmnt /boot/efi > /dev/null 2>&1; then
        log_error "La partición EFI no está montada en /boot/efi (revisa la opción 5)"
        echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"; read -r
        return 1
    fi
    cat << 'EXPL'
El firmware (la BIOS UEFI) guarda una lista de sistemas para arrancar. A veces
esa lista se borra: al actualizar la BIOS, al quitar la pila, al cambiar el disco
de PC o por un reseteo. Entonces la PC dice "no hay sistema" o va directo a
Windows, aunque Ubuntu y GRUB estén perfectos.

El arranque de respaldo es una copia del arranque de Ubuntu en la "ruta de
emergencia" (\EFI\BOOT\BOOTX64.EFI), la que el firmware prueba cuando no
encuentra nada en su lista. Si la entrada se borra:
  1. La PC arranca igual por esa ruta.
  2. Ubuntu vuelve a crear su entrada solo, sin que hagas nada.

  • Funciona con Secure Boot (usa los mismos archivos firmados de Ubuntu).
  • Se actualiza solo cada vez que se actualiza GRUB.
  • Si esa ruta la usa Windows, no se toca.
EXPL
    local state
    state=$(uefi_fallback_state)
    echo ""
    case $state in
        nuestro) echo -e "${GREEN}✓ Estado: INSTALADO (lo puso este script)${NC}" ;;
        vacio) echo -e "${YELLOW}○ Estado: no hay arranque de respaldo${NC}" ;;
        windows) echo -e "${CYAN}ℹ Estado: la ruta de respaldo es de Windows${NC}" ;;
        *) echo -e "${YELLOW}ℹ Estado: la ruta de respaldo tiene el arranque de otro sistema${NC}" ;;
    esac
    echo ""
    echo -e "  ${PURPLE}1)${NC} $([ "$state" = nuestro ] && echo "Actualizarlo ahora" || echo "Instalarlo")"
    echo -e "  ${PURPLE}2)${NC} Quitarlo (vuelve a como estaba)"
    echo -e "  ${PURPLE}0)${NC} 🔙 Volver"
    local choice
    read -r -p "📌 Opción (0-2): " choice
    case $choice in
        1) install_uefi_fallback ;;
        2) remove_uefi_fallback ;;
        *) return 0 ;;
    esac
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read -r
}

# ============================================================
# OPCIÓN 19: APAGAR O REINICIAR (COLOR: AMARILLO)
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
    echo -e "\n  ${YELLOW}0)${NC} 🔙 Volver"
    echo ""
    read -r -p "📌 Opción (0-2): " power_option

    case $power_option in
        1)
            echo -e "\n${RED}🔴 Apagando el sistema...${NC}"
            sudo shutdown -h now
            ;;
        2)
            echo -e "\n${GREEN}🟢 Reiniciando el sistema...${NC}"
            sudo reboot
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida${NC}"
            sleep 1
            ;;
    esac
}

# ============================================================
# OPCIÓN 13: QUITAR ACCESOS DIRECTOS (COLOR: CIAN)
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

GNOME_FAVORITES_BACKUP="$SHORTCUTS_BACKUP/gnome-favoritas"

# Apps fijadas en el dock de GNOME (Ubuntu): se guardan antes de vaciarlo
remove_gnome_favorites() {
    local current
    current=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null)
    if [ -z "$current" ] || [ "$current" = "@as []" ] || [ "$current" = "[]" ]; then
        echo -e "${YELLOW}ℹ No hay apps fijadas en el dock${NC}"
        return 0
    fi
    echo -e "${CYAN}📌 Apps fijadas en el dock:${NC}"
    tr -d "[]'" <<< "$current" | tr ',' '\n' | sed 's/^ *//; s/\.desktop$//; s/^/  • /'
    echo ""
    confirm "${CYAN}¿Quitar todas las apps fijadas del dock?${NC}" || return 0
    mkdir -p "$SHORTCUTS_BACKUP"
    [ -f "$GNOME_FAVORITES_BACKUP" ] || echo "$current" > "$GNOME_FAVORITES_BACKUP"
    run "No se pudo cambiar el dock" gsettings set org.gnome.shell favorite-apps "[]" \
        && log_success "Apps fijadas quitadas del dock"
}

restore_gnome_favorites() {
    if [ ! -f "$GNOME_FAVORITES_BACKUP" ]; then
        echo -e "  ${YELLOW}ℹ No hay copia del dock guardada${NC}"
        return 0
    fi
    run "No se pudo restaurar el dock" gsettings set org.gnome.shell favorite-apps "$(cat "$GNOME_FAVORITES_BACKUP")" \
        && rm -f "$GNOME_FAVORITES_BACKUP" && log_success "Dock restaurado"
}

remove_panel_launchers() {
    case $DESKTOP in
        gnome) remove_gnome_favorites; return ;;
        kde) ;;
        *) log_warning "Quitar las apps fijadas del panel solo está disponible en KDE Plasma y GNOME"; return 0 ;;
    esac
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
    [ -f "$GNOME_FAVORITES_BACKUP" ] && restore_gnome_favorites
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
    if ! has_desktop; then
        log_warning "Los accesos directos necesitan un escritorio (este sistema no tiene)"
        pause
        return 0
    fi
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🧹 QUITAR ACCESOS DIRECTOS                    ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"

        echo -e "\n${CYAN}📋 Opciones:${NC}\n"
        echo -e "  ${CYAN}1)${NC} Íconos del escritorio"
        echo -e "  ${CYAN}2)${NC} Aplicaciones fijadas en el panel o el dock"
        echo -e "  ${CYAN}3)${NC} Restaurar los accesos quitados"
        echo -e "\n  ${CYAN}0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-3): " shortcut_option

        case $shortcut_option in
            1) remove_desktop_shortcuts ;;
            2) remove_panel_launchers ;;
            3) restore_desktop_shortcuts; restore_panel_launchers ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 14: RED, DNS Y DRIVERS (COLOR: AZUL)
# ============================================================

RESOLVED_DNS_CONF="/etc/systemd/resolved.conf.d/99-ubuntu-ultimate-tools-dns.conf"
NM_WIFI_CONF="/etc/NetworkManager/conf.d/99-ubuntu-ultimate-tools-wifi.conf"

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

# Aplica el DNS globalmente con systemd-resolved (usado por Ubuntu) y DNS cifrado
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
        echo tcp_bbr | sudo tee "$BBR_MODULES_FILE" > /dev/null
    fi
    set_sysctl net.core.default_qdisc fq
    set_sysctl net.ipv4.tcp_congestion_control "$algo"
    log_success "TCP BBR activado ($algo)"
}

disable_bbr() {
    sudo rm -f "$BBR_MODULES_FILE"
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
        echo -e "\n  ${BLUE}0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-7): " net_option

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
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 15: ENERGÍA Y RENDIMIENTO (COLOR: AMARILLO)
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
        if installed_pkgs tlp | grep -qx tlp; then
            log_error "Usas TLP: los perfiles de energía los maneja TLP (quítalo en la opción 17 para usar estos)"
            return 1
        fi
        # Xubuntu, Lubuntu y otros no lo traen: es el servicio estándar de perfiles de energía
        echo -e "${YELLOW}📦 Instalando power-profiles-daemon (perfiles de energía)...${NC}"
        apt_update
        apt_install_recorded power-profiles-daemon || return 1
        run "No se pudo iniciar power-profiles-daemon" sudo systemctl enable --now power-profiles-daemon || return 1
    fi
    if ! powerprofilesctl list 2>/dev/null | grep -q "$profile:"; then
        log_error "Tu equipo no admite el perfil '$profile' (disponibles: $(power_profiles_available))"
        return 1
    fi
    run "No se pudo cambiar el perfil de energía" powerprofilesctl set "$profile" \
        && log_success "Perfil de energía: $profile"
}

install_tlp() {
    echo -e "${YELLOW}ℹ TLP reemplaza a power-profiles-daemon: el selector de perfiles del escritorio desaparecerá${NC}"
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

# Servicio del indexador de GNOME (LocalSearch en versiones nuevas, Tracker en las anteriores)
gnome_indexer_unit() {
    local unit
    for unit in localsearch-3.service tracker-miner-fs-3.service; do
        if systemctl --user cat "$unit" &> /dev/null; then
            echo "$unit"
            return 0
        fi
    done
    return 1
}

indexer_disabled() {
    local cmd unit
    if cmd=$(baloo_cmd); then
        "$cmd" status 2>/dev/null | grep -qi 'disabled\|desactivad'
    elif unit=$(gnome_indexer_unit); then
        [ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" = masked ]
    else
        return 1
    fi
}

# El indexador recorre todos los archivos para la búsqueda: consume CPU, disco y batería
disable_indexer() {
    local unit
    if baloo_cmd > /dev/null; then
        disable_baloo
    elif unit=$(gnome_indexer_unit); then
        run "No se pudo desactivar el indexador" systemctl --user mask --now "$unit" \
            && log_success "Indexador de archivos desactivado (${unit%%-*})"
    else
        echo -e "  ${YELLOW}ℹ No hay indexador de archivos activo en ${DESKTOP_NAME}${NC}"
    fi
}

enable_indexer() {
    local unit
    if baloo_cmd > /dev/null; then
        enable_baloo
    elif unit=$(gnome_indexer_unit); then
        run "No se pudo activar el indexador" systemctl --user unmask "$unit" \
            && systemctl --user start "$unit" 2>> "$LOG_FILE"
        log_success "Indexador de archivos activado (${unit%%-*})"
    else
        echo -e "  ${YELLOW}ℹ No hay indexador de archivos en ${DESKTOP_NAME}${NC}"
    fi
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
    configure_mangohud
    log_success "GameMode y MangoHud instalados (en Steam: gamemoderun mangohud %command%)"
}

MANGOHUD_CONF="$HOME/.config/MangoHud/MangoHud.conf"
MANGOHUD_ENV="$HOME/.config/environment.d/90-mangohud.conf"

# Deja MangoHud mostrando y grabando los FPS (SysMonitorPro lee esos registros).
# Sin configuración, MangoHud no graba nada y solo actúa en juegos lanzados con 'mangohud'.
configure_mangohud() {
    mkdir -p "$(dirname "$MANGOHUD_CONF")" "$HOME/mangohud-logs"
    if [ ! -f "$MANGOHUD_CONF" ]; then
        cat > "$MANGOHUD_CONF" << EOF
# Creado por Ubuntu Ultimate Tools
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
toggle_hud=Shift_R+F12
toggle_logging=Shift_L+F2
output_folder=$HOME/mangohud-logs
autostart_log=1
EOF
        log_success "MangoHud configurado: $MANGOHUD_CONF"
    else
        # Configuración propia: solo se añade lo necesario para grabar los FPS
        local key value added=false
        cp "$MANGOHUD_CONF" "$MANGOHUD_CONF.bak"
        for key in output_folder autostart_log toggle_logging; do
            grep -q "^${key}=" "$MANGOHUD_CONF" && continue
            case $key in
                output_folder) value="$HOME/mangohud-logs" ;;
                autostart_log) value=1 ;;
                toggle_logging) value="Shift_L+F2" ;;
            esac
            echo "${key}=${value}" >> "$MANGOHUD_CONF"
            added=true
        done
        if $added; then
            log_success "MangoHud: registro de FPS activado (copia en $MANGOHUD_CONF.bak)"
        else
            rm -f "$MANGOHUD_CONF.bak"
        fi
    fi

    # Global: todos los juegos Vulkan y Proton/DXVK usan MangoHud sin tocar Steam.
    # En el perfil 'gaming' se activa directamente; en el menú se pregunta.
    if [ -f "$MANGOHUD_ENV" ]; then
        log_info "MangoHud ya está activo en todos los juegos Vulkan/Proton"
    elif [ "$ACTIVE_PROFILE" = "gaming" ] || confirm "${YELLOW}¿Activar MangoHud en todos los juegos Vulkan/Proton (sin configurar cada juego)?${NC}"; then
        mkdir -p "$(dirname "$MANGOHUD_ENV")"
        echo "MANGOHUD=1" > "$MANGOHUD_ENV"
        log_success "MangoHud activo en todos los juegos Vulkan/Proton (tras cerrar sesión y volver a entrar)"
    fi
    log_info "Juegos OpenGL o nativos sin Vulkan: abrirlos con 'mangohud juego' o en Steam 'mangohud %command%'"
    log_info "Shift derecho + F12 oculta el panel en el juego · Shift izquierdo + F2 pausa/reanuda la grabación"
}

# ------------------------------------------------------------
# Steam y Proton
# ------------------------------------------------------------

# Instalador oficial de Valve (si no se descarga, se usa el de Ubuntu)
STEAM_DEB_URLS=(
    "https://cdn.fastly.steamstatic.com/client/installer/steam.deb"
    "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb"
)
PROTON_GE_LIST="$STATE_DIR/proton-ge.txt"

steam_installed() {
    [ -n "$(installed_pkgs steam-launcher steam-installer steam)" ] \
        || flatpak info com.valvesoftware.Steam &> /dev/null
}

# Carpeta de datos de Steam (existe aunque todavía no se haya abierto)
steam_dir() {
    if [ -z "$(installed_pkgs steam-launcher steam-installer steam)" ] \
        && [ -d "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" ]; then
        echo "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
    elif [ -d "$HOME/.steam/root" ]; then
        readlink -f "$HOME/.steam/root"
    else
        echo "$HOME/.local/share/Steam"
    fi
}

steam_supported() {
    if ! has_desktop; then
        log_warning "Steam necesita un escritorio (este sistema no tiene)"
        return 1
    fi
    if [ "$(dpkg --print-architecture)" != amd64 ]; then
        log_warning "Steam solo existe para PC de 64 bits (amd64)"
        return 1
    fi
}

# Librerías gráficas de 32 bits: la mayoría de los juegos de Windows (Proton) las necesitan
steam_i386_libs() {
    local libs=() nv
    if [ -n "$(available_pkgs steam-libs-amd64)" ]; then
        libs+=(steam-libs-amd64:amd64 steam-libs-i386:i386)
    else
        libs+=(libgl1:i386 libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386)
    fi
    # Con el driver de NVIDIA hace falta también su parte de 32 bits
    nv=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libnvidia-gl-*' 2>/dev/null \
        | awk '$1 ~ /^.i/ && $2 ~ /^libnvidia-gl-[0-9]+(-server)?$/ {print $2; exit}')
    [ -n "$nv" ] && libs+=("$nv:i386")
    apt_install_recorded "${libs[@]}"
}

install_steam() {
    steam_supported || return 1
    if steam_installed; then
        echo -e "  ${GREEN}✓ Steam ya está instalado${NC}"
        enable_steam_play
        return 0
    fi

    echo -e "${BLUE}🎮 Instalando Steam...${NC}"
    # Steam y los juegos de Windows usan librerías de 32 bits
    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        run "No se pudo activar la arquitectura de 32 bits" sudo dpkg --add-architecture i386 || return 1
        log_success "Arquitectura de 32 bits (i386) activada"
    fi
    command -v wget &> /dev/null || { apt_update; apt_install wget; }

    local tmp url deb=""
    tmp=$(mktemp -d)
    chmod 755 "$tmp"
    for url in "${STEAM_DEB_URLS[@]}"; do
        if wget -qO "$tmp/steam.deb" "$url" >> "$LOG_FILE" 2>&1 \
            && [ "$(dpkg-deb -f "$tmp/steam.deb" Package 2>/dev/null)" = steam-launcher ]; then
            chmod 644 "$tmp/steam.deb"
            deb="$tmp/steam.deb"
            break
        fi
    done

    apt_update force
    if [ -n "$deb" ]; then
        apt_install_recorded "$deb" || { rm -rf "$tmp"; return 1; }
        # El instalador agrega el repositorio de Valve: de ahí salen sus librerías
        apt_update force
    elif [ -n "$(available_pkgs steam-installer)" ]; then
        log_warning "No se pudo descargar el instalador de Valve: se usa el paquete de Ubuntu"
        apt_install_recorded steam-installer || { rm -rf "$tmp"; return 1; }
    else
        log_error "No se pudo descargar Steam y tu Ubuntu no tiene el paquete (activa el repositorio multiverse)"
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"
    steam_i386_libs || log_warning "Faltan librerías de 32 bits: Steam las pedirá al abrirlo"
    log_success "Steam instalado (Proton viene incluido)"
    enable_steam_play
}

# Activa Proton para todos los juegos (Steam → Configuración → Compatibilidad).
# El ajuste vive en config.vdf, que Steam crea la primera vez que se abre.
enable_steam_play() {
    local cfg tmp
    cfg="$(steam_dir)/config/config.vdf"
    if [ ! -f "$cfg" ]; then
        log_info "Abre Steam una vez e inicia sesión. Proton ya está activo para los juegos verificados;"
        log_info "para todos: Steam → Configuración → Compatibilidad → 'Activar Steam Play para todos los demás títulos'"
        log_info "(o, con Steam cerrado, usa la opción 15 → 6 y se activa solo)"
        return 0
    fi
    if pgrep -x steam &> /dev/null; then
        log_warning "Steam está abierto: ciérralo y usa la opción 15 → 6 para activar Proton en todos los juegos"
        return 0
    fi
    tmp=$(mktemp)
    if steam_play_vdf < "$cfg" > "$tmp"; then
        cp "$cfg" "$cfg.bak"
        mv "$tmp" "$cfg"
        log_success "Proton activado para todos los juegos (Proton Experimental; copia en config.vdf.bak)"
    else
        rm -f "$tmp"
        log_info "Steam ya tiene elegida una versión de Proton para todos los juegos: no se cambia"
    fi
}

# Agrega a config.vdf la versión de Proton para "todos los demás títulos" (la entrada "0").
# Falla (sin salida útil) si ya hay una elegida o si el archivo no tiene la forma esperada.
steam_play_vdf() {
    awk '
        function path(   s, i) { s = ""; for (i = 1; i <= d; i++) s = s "/" tolower(st[i]); return s }
        function tabs(n,   s) { s = ""; while (n-- > 0) s = s "\t"; return s }
        function entry(t) {
            print t "\"0\""; print t "{"
            print t "\t\"name\"\t\t\"proton_experimental\""
            print t "\t\"config\"\t\t\"\""
            print t "\t\"priority\"\t\t\"75\""
            print t "}"
        }
        { lines[NR] = $0 }
        END {
            base = "/installconfigstore/software/valve/steam"
            # Primera pasada: ¿ya existe la entrada "0"? ¿existe CompatToolMapping?
            d = 0
            for (n = 1; n <= NR; n++) {
                l = lines[n]
                if (l ~ /^[ \t]*"[^"]*"[ \t]*$/) { k = l; gsub(/^[ \t]*"|"[ \t]*$/, "", k); pend = k }
                else if (l ~ /^[ \t]*\{[ \t]*$/) { st[++d] = pend; p = path()
                    if (p == base "/compattoolmapping") mapping = 1
                    if (p == base "/compattoolmapping/0") exit 1 }
                else if (l ~ /^[ \t]*\}[ \t]*$/) d--
            }
            if (d != 0) exit 1
            # Segunda pasada: copia el archivo e inserta lo que falta
            for (n = 1; n <= NR; n++) {
                l = lines[n]; print l
                if (l ~ /^[ \t]*"[^"]*"[ \t]*$/) { k = l; gsub(/^[ \t]*"|"[ \t]*$/, "", k); pend = k }
                else if (l ~ /^[ \t]*\{[ \t]*$/) { st[++d] = pend; p = path(); t = tabs(d)
                    if (!done && mapping && p == base "/compattoolmapping") { entry(t); done = 1 }
                    if (!done && !mapping && p == base) {
                        print t "\"CompatToolMapping\""; print t "{"; entry(t "\t"); print t "}"; done = 1 } }
                else if (l ~ /^[ \t]*\}[ \t]*$/) d--
            }
            exit !done
        }'
}

# Proton-GE: versión de la comunidad con arreglos para juegos y vídeos que el oficial aún no tiene
install_proton_ge() {
    steam_supported || return 1
    command -v wget &> /dev/null || { apt_update; apt_install wget; }
    local tag dir tmp
    tag=$(wget -qO- https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest 2>> "$LOG_FILE" \
        | grep -m1 '"tag_name"' | cut -d'"' -f4)
    if [[ ! "$tag" =~ ^GE-Proton[0-9A-Za-z.-]+$ ]]; then
        log_error "No se pudo consultar la última versión de Proton-GE (¿sin internet?)"
        return 1
    fi
    dir="$(steam_dir)/compatibilitytools.d"
    if [ -d "$dir/$tag" ]; then
        echo -e "  ${GREEN}✓ $tag ya está instalado (es la última versión)${NC}"
        return 0
    fi

    echo -e "${BLUE}⬇ Descargando $tag (unos 500 MB)...${NC}"
    mkdir -p "$dir" "${XDG_CACHE_HOME:-$HOME/.cache}"
    tmp=$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}")
    local base="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$tag/$tag"
    if ! wget -q --show-progress -O "$tmp/$tag.tar.gz" "$base.tar.gz" \
        || ! wget -qO "$tmp/$tag.sha512sum" "$base.sha512sum"; then
        log_error "No se pudo descargar $tag"
        rm -rf "$tmp"
        return 1
    fi
    # Se comprueba que el archivo llegó entero y es el publicado
    if ! (cd "$tmp" && sha512sum -c --status "$tag.sha512sum"); then
        log_error "La descarga de $tag está dañada (la suma de comprobación no coincide)"
        rm -rf "$tmp"
        return 1
    fi
    if ! tar -xzf "$tmp/$tag.tar.gz" -C "$dir" >> "$LOG_FILE" 2>&1 || [ ! -d "$dir/$tag" ]; then
        log_error "No se pudo descomprimir $tag"
        rm -rf "$tmp" "${dir:?}/$tag"
        return 1
    fi
    rm -rf "$tmp"
    mkdir -p "$STATE_DIR"
    echo "$dir/$tag" >> "$PROTON_GE_LIST"
    log_success "$tag instalado"
    log_info "Para usarlo en un juego: Propiedades → Compatibilidad → $tag (reinicia Steam si estaba abierto)"
}

# Quita las versiones de Proton-GE que instaló el script
remove_proton_ge() {
    local dirs=() d
    [ -f "$PROTON_GE_LIST" ] && mapfile -t dirs < <(sort -u "$PROTON_GE_LIST")
    mapfile -t dirs < <(for d in "${dirs[@]}"; do [ -d "$d" ] && [[ "$(basename "$d")" == GE-Proton* ]] && echo "$d"; done)
    if [ ${#dirs[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ No hay versiones de Proton-GE instaladas por el script${NC}"
        rm -f "$PROTON_GE_LIST"
        return 0
    fi
    printf "  ${RED}•${NC} %s\n" "${dirs[@]##*/}"
    confirm "${RED}¿Quitar estas versiones de Proton-GE? Los juegos que las usen vuelven al Proton oficial${NC}" || return 0
    rm -rf "${dirs[@]}"
    rm -f "$PROTON_GE_LIST"
    log_success "Proton-GE quitado"
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
        echo -e "  ${YELLOW}5)${NC} Activar/desactivar el indexador de archivos (Baloo / Tracker)"
        echo -e "  ${YELLOW}6)${NC} Herramientas de juego (GameMode, MangoHud, Steam y Proton)"
        echo -e "\n  ${YELLOW}0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-6): " power_option

        case $power_option in
            1) set_power_profile performance ;;
            2) set_power_profile balanced ;;
            3) set_power_profile power-saver ;;
            4) confirm "${YELLOW}¿Instalar TLP?${NC}" && install_tlp ;;
            5)
                local cmd
                if indexer_disabled; then
                    enable_indexer
                else
                    disable_indexer
                fi
                ;;
            6)
                install_gaming_tools
                if steam_installed; then
                    enable_steam_play
                elif has_desktop && confirm "${YELLOW}¿Instalar Steam (incluye Proton para juegos de Windows)?${NC}"; then
                    install_steam
                fi
                if has_desktop && confirm "${YELLOW}¿Instalar Proton-GE (versión de la comunidad, más compatible)?${NC}"; then
                    install_proton_ge
                fi
                ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 16: PERFILES AUTOMÁTICOS (COLOR: PÚRPURA)
# ============================================================

PROFILES=(
    "productividad|Oficina y uso diario: herramientas, RAM, DNS rápido, sin juegos"
    "gaming|Juegos: Steam + Proton, drivers, kernel Liquorix, GameMode, red de baja latencia"
    "ahorro|Ahorro de energía: TLP en portátiles, sin indexador, ZRAM"
    "desarrollo|Programación: git, compiladores, Python, VSCode, SDK de Android para APK"
    "minimalista|Mínimo: sin meta-paquete ni apps extra, sin Snap, Firefox .deb (y Plasma más nuevo en Kubuntu)"
)

# Pasos de cada perfil: "Descripción|función [argumentos]"
profile_steps() {
    case $1 in
        productividad) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Quitar juegos preinstalados|remove_games
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
Instalar Steam y activar Proton para todos los juegos|install_steam
Instalar Proton-GE (más compatible con algunos juegos)|install_proton_ge
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar ZRAM|enable_zram
Perfil de energía: rendimiento máximo (o GameMode al jugar)|set_gaming_power
Desactivar el indexador de archivos|disable_indexer
Wi-Fi sin ahorro de energía (menos latencia)|disable_wifi_powersave
Activar TCP BBR|enable_bbr
Usar el DNS más rápido (medido)|set_fastest_dns
EOF
        ;;
        ahorro) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Ahorro de energía (TLP en portátil, perfil de ahorro en PC)|enable_power_saving
Desactivar el indexador de archivos|disable_indexer
Activar ZRAM (menos escrituras en disco)|enable_zram
Optimizar RAM (swappiness y caché)|apply_ram_tweaks
Activar TRIM semanal para SSD|enable_trim
EOF
        ;;
        desarrollo) cat << 'EOF'
Desactivar indexación de manuales (apt más rápido)|disable_mandb
Actualizar el sistema|do_system_update
Instalar herramientas (git, build-essential, Python, VSCode...)|install_optional_with_progress git curl wget vim htop build-essential python3-pip python3-venv code
Herramientas para compilar APK (Java, SDK de Android, adb)|install_android_tools
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
Quitar el meta-paquete del sabor (las apps se conservan)|remove_flavor_meta
Quitar apps preinstaladas (juegos, correo y agenda, IRC, torrent...)|remove_minimal_extras
Eliminar Snap por completo (se conservan los perfiles de Firefox)|do_snap_removal
Instalar Firefox .deb de Mozilla|install_firefox_deb
Activar KDE Rolling Release (solo para Kubuntu)|enable_backports
Actualizar con los paquetes más nuevos|do_system_update
Desactivar el indexador de archivos|disable_indexer
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
    ACTIVE_PROFILE="$name"
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
    ACTIVE_PROFILE=""

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
    echo -e "\n  ${PURPLE}0)${NC} 🔙 Volver"
    echo -e "\n${YELLOW}💡 También desde terminal: ./ubuntu-ultimate-tools.sh --perfil gaming${NC}\n"
    read -r -p "📌 Opción: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#PROFILES[@]} ]; then
        entry=${PROFILES[$((choice - 1))]}
        run_profile "${entry%%|*}"
        pause
    fi
}

# ============================================================
# OPCIÓN 17: DESHACER OPTIMIZACIONES (COLOR: ROJO)
# ============================================================

# Programas que el script puede instalar. Sirve para ofrecer también los que se
# instalaron antes de que existiera el registro. No incluye paquetes del sistema
# que Ubuntu ya trae (python3, curl, wget): quitarlos podría romper otras cosas.
SCRIPT_PROGRAMS=(filezilla code virtualbox google-chrome-stable telegram-desktop python3-pip
    python3-venv git htop fastfetch timeshift gparted vim discord spotify-client obs-studio
    qrca build-essential alacritty gamemode mangohud steam-launcher steam-installer flatpak flatpak-builder
    openjdk-21-jdk-headless openjdk-17-jdk-headless android-sdk-platform-tools-common docker.io docker-buildx docker-compose-v2 tlp tlp-rdw zram-tools corectrl
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

    # Sin TLP, el selector de energía del escritorio necesita power-profiles-daemon
    if printf '%s\n' "${CHOSEN[@]}" | grep -qx tlp; then
        apt_update
        apt_install power-profiles-daemon \
            && run "No se pudo activar power-profiles-daemon" sudo systemctl enable --now power-profiles-daemon \
            && log_success "Vuelve el selector de energía del escritorio"
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
    sudo rm -f "$SYSCTL_FILE" "$BBR_MODULES_FILE"
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
        && log_success "TLP quitado: vuelve el selector de energía del escritorio"
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
    if indexer_disabled; then
        changed_line "Indexador de archivos: desactivado"
    else
        factory_line "Indexador de archivos: activo (o no hay)"
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
        confirm "${YELLOW}¿Quitar TLP y volver al selector de energía del escritorio?${NC}" && remove_tlp
    elif command -v powerprofilesctl &> /dev/null; then
        set_power_profile balanced
    fi
    echo -e "${YELLOW}🔎 Indexadores${NC}"
    local cmd
    if indexer_disabled; then
        enable_indexer
    else
        echo -e "  ${GREEN}✓ El indexador de archivos ya está activo (o no hay)${NC}"
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
        echo -e "  ${RED}4)${NC} 🔋 Quitar TLP y volver al selector de energía del escritorio"
        echo -e "  ${RED}5)${NC} 📋 Ver qué AJUSTES están cambiados y restaurarlos todos (no toca programas)"
        echo -e "  ${RED}6)${NC} 🍷 Quitar Proton-GE"
        echo -e "  ${RED}7)${NC} 🤖 Quitar Android Studio y/o el SDK de Android"
        echo -e "  ${RED}8)${NC} 📦 Quitar los SDK de Flatpak (KDE, GNOME, Freedesktop)"
        echo -e "  ${RED}9)${NC} 🐳 Quitar Docker (conservando tus datos, o eliminación nuclear)"
        echo -e "  ${RED}10)${NC} ☢️  ELIMINACIÓN NUCLEAR de todo lo de desarrollo (Android, Flatpak SDK, Docker)"
        echo -e "      con respaldos antes de borrar"
        echo -e "\n  ${RED}0)${NC} 🔙 Volver"
        echo -e "\n${YELLOW}ℹ Otros cambios se deshacen en su menú: kernel (5), distribución original (9),${NC}"
        echo -e "${YELLOW}  Snap (11), accesos directos (13), DNS/BBR/Wi-Fi (14), energía e indexador (15)${NC}\n"
        read -r -p "📌 Opción (0-10): " undo_option

        case $undo_option in
            1) remove_installed_programs ;;
            2) restore_sysctl_defaults ;;
            3) disable_zram ;;
            4) remove_tlp ;;
            6) remove_proton_ge ;;
            7) remove_android ;;
            8) remove_flatpak_sdks ;;
            9) remove_docker ;;
            10) dev_nuclear ;;
            5)
                if ! show_tweaks_status; then
                    echo -e "${GREEN}✓ No hay ajustes cambiados: todo está como de fábrica${NC}"
                elif confirm "${RED}¿Restaurar a fábrica los ajustes marcados con ⚙?${NC}"; then
                    restore_all_tweaks
                else
                    echo -e "${YELLOW}ℹ Cancelado: no se cambió nada${NC}"
                fi
                ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# OPCIÓN 18: INFORMACIÓN DEL SISTEMA Y HARDWARE (COLOR: CIAN)
# ============================================================

# Cada sección imprime texto sin colores: así sirve para la pantalla, para buscar
# y para guardar el informe. Con INFO_QUIET=true no pregunta ni descarga nada.
INFO_QUIET=false

info_title() {
    echo ""
    echo "▶ $1"
}

# Temperatura de la CPU desde el kernel (no necesita programas extra)
cpu_temperature() {
    local dir name temp
    for dir in /sys/class/hwmon/hwmon*; do
        name=$(cat "$dir/name" 2>/dev/null)
        case $name in
            k10temp|coretemp|zenpower|cpu_thermal|acpitz)
                temp=$(cat "$dir/temp1_input" 2>/dev/null) || continue
                echo "$((temp / 1000))°C"
                return 0 ;;
        esac
    done
    return 1
}

info_summary() {
    local temp
    info_title "RESUMEN"
    echo "  Sistema:    $(os_release_value PRETTY_NAME) · ${FLAVOR_NAME} (${DESKTOP_NAME}, sesión ${XDG_SESSION_TYPE:-sin escritorio})"
    echo "  Kernel:     $(uname -r)"
    echo "  Encendido:  $(LC_ALL=C uptime -p | sed -e 's/^up //' -e 's/weeks/semanas/; s/week/semana/' \
        -e 's/days/días/; s/day/día/; s/hours/horas/; s/hour/hora/; s/minutes/minutos/; s/minute/minuto/')"
    echo "  CPU:        $(LC_ALL=C lscpu | sed -n 's/^Model name: *//p' | head -1) ($(nproc) hilos)"
    LC_ALL=C lspci 2>/dev/null | grep -Ei 'vga|3d controller|display controller' | sed 's/^[^ ]* [^:]*: /  GPU:        /'
    free -h | awk '/^Mem:/ {print "  RAM:        " $3 " en uso de " $2} /^Swap:/ {print "  Swap/ZRAM:  " $3 " en uso de " $2}'
    df -h / | awk 'NR == 2 {print "  Disco (/):  " $3 " en uso de " $2 " (" $5 ")"}'
    temp=$(cpu_temperature) && echo "  Temp. CPU:  $temp"
}

# Ejecuta fastfetch: el instalado o uno temporal que se borra al terminar
info_fastfetch() {
    if command -v fastfetch &> /dev/null; then
        fastfetch
        return
    fi
    $INFO_QUIET && return 0
    echo -e "${CYAN}ℹ fastfetch no está instalado. Se puede ver sin instalar: se descarga (~1,5 MB) a una${NC}"
    echo -e "${CYAN}  carpeta temporal desde su página oficial y se borra al terminar.${NC}"
    confirm "${CYAN}¿Verlo sin instalar?${NC}" || return 0
    local tmp arch
    arch=$(dpkg --print-architecture)
    [ "$arch" = arm64 ] && arch=aarch64
    tmp=$(mktemp -d)
    if run "No se pudo descargar fastfetch" wget -qO "$tmp/ff.tar.gz" \
        "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$arch.tar.gz" \
        && tar -xzf "$tmp/ff.tar.gz" -C "$tmp"; then
        local ffbin=("$tmp"/fastfetch-linux-*/usr/bin/fastfetch)
        "${ffbin[0]}"
    fi
    rm -rf "$tmp"
}

# Ejecuta inxi: el instalado o el paquete oficial de Ubuntu, usado sin instalar
info_inxi() {
    local flags="$1" tmp
    if command -v inxi &> /dev/null; then
        # shellcheck disable=SC2086  # varias opciones
        inxi $flags
        return
    fi
    $INFO_QUIET && return 0
    echo -e "${CYAN}ℹ inxi no está instalado. Se puede ver sin instalar: se descarga el paquete oficial de${NC}"
    echo -e "${CYAN}  Ubuntu (~350 KB) a una carpeta temporal y se borra al terminar.${NC}"
    confirm "${CYAN}¿Verlo sin instalar?${NC}" || return 0
    tmp=$(mktemp -d)
    apt_update
    if (cd "$tmp" && run "No se pudo descargar inxi" apt-get download inxi) \
        && dpkg-deb -x "$tmp"/inxi_*.deb "$tmp/x"; then
        # shellcheck disable=SC2086  # varias opciones
        perl "$tmp/x/usr/bin/inxi" $flags
    fi
    rm -rf "$tmp"
}

info_cpu_ram() {
    info_title "CPU"
    LC_ALL=C lscpu | grep -E '^(Model name|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|CPU max MHz|CPU min MHz|L3 cache|Virtualization):' \
        | sed -e 's/^Model name:/Modelo:/' -e 's/^CPU(s):/Hilos:/' -e 's/^Thread(s) per core:/Hilos por núcleo:/' \
              -e 's/^Core(s) per socket:/Núcleos:/' -e 's/^CPU max MHz:/Frecuencia máxima (MHz):/' \
              -e 's/^CPU min MHz:/Frecuencia mínima (MHz):/' -e 's/^L3 cache:/Caché L3:/' -e 's/^Virtualization:/Virtualización:/' \
              -e 's/  */ /g; s/^/  /'
    info_title "MEMORIA RAM"
    free -h | awk '/^Mem:/ {print "  Total " $2 " · en uso " $3 " · disponible " $7}'
    if command -v dmidecode &> /dev/null; then
        # Un bloque "Memory Device" por ranura de la placa
        LC_ALL=C sudo dmidecode -t memory 2>/dev/null | awk -F': ' '
            /^Memory Device/ { if (slot != "") out(); size = type = speed = maker = slot = ""; next }
            /^\tSize:/ { size = $2 }
            /^\tType:/ { type = $2 }
            /^\tConfigured Memory Speed:/ { speed = $2 }
            /^\tSpeed:/ { if (speed == "" || speed == "Unknown") speed = $2 }
            /^\tManufacturer:/ { maker = $2 }
            /^\tLocator:/ { slot = $2 }
            function out() {
                if (size ~ /No Module|^$/) printf "  Ranura %-12s vacía\n", slot
                else printf "  Ranura %-12s %s %s a %s (%s)\n", slot, size, type, speed, maker
            }
            END { if (slot != "") out() }'
    fi
}

info_gpu() {
    info_title "TARJETA GRÁFICA"
    LC_ALL=C lspci -k 2>/dev/null | awk '
        /^[^\t]/ { show = ($0 ~ /VGA|3D controller|Display controller/) }
        show && /^[^\t]/ { sub(/^[^ ]+ [^:]+: /, ""); print "  " $0 }
        show && /Kernel driver in use/ { sub(/.*: /, ""); print "    Driver en uso: " $0 }'
    if LC_ALL=C lspci -k 2>/dev/null | grep -A3 -i nvidia | grep -q 'driver in use: nouveau'; then
        echo "  ⚠ La NVIDIA usa el driver libre 'nouveau': para juegos instala el de NVIDIA (opción 14 → 6)"
    fi
}

info_disks() {
    local disk
    info_title "DISCOS Y PARTICIONES"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null | grep -v -E 'loop|zram' | sed 's/^/  /'
    info_title "ESPACIO"
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | sed 's/^/  /'
    info_title "SALUD DE LOS DISCOS (SMART)"
    if ! command -v smartctl &> /dev/null; then
        if $INFO_QUIET; then
            echo "  (smartmontools no está instalado)"
            return 0
        fi
        echo -e "${CYAN}ℹ Para leer la salud de los discos hace falta smartmontools (se puede quitar en la opción 17)${NC}"
        confirm "${CYAN}¿Instalarlo?${NC}" || return 0
        apt_update
        apt_install_recorded smartmontools || return 1
    fi
    for disk in $(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" && $1 !~ /zram/ {print $1}'); do
        echo "  $disk"
        LC_ALL=C sudo smartctl -H -A "$disk" 2>/dev/null | grep -E \
            'overall-health|Percentage Used|Power On Hours|Power_On_Hours|^Temperature:|Temperature_Celsius|Media and Data Integrity|Reallocated_Sector|Wear_Leveling|Percent_Lifetime|Unsafe Shutdowns|Available Spare:' \
            | sed -e 's/SMART overall-health self-assessment test result:/Estado general:/' -e 's/  */ /g; s/^/    /'
    done
}

info_temps() {
    local dir name file label value found=false
    info_title "TEMPERATURAS Y VENTILADORES"
    for dir in /sys/class/hwmon/hwmon*; do
        name=$(cat "$dir/name" 2>/dev/null) || continue
        for file in "$dir"/temp*_input "$dir"/fan*_input; do
            [ -f "$file" ] || continue
            value=$(cat "$file" 2>/dev/null) || continue
            label=$(cat "${file%_input}_label" 2>/dev/null || basename "${file%_input}")
            if [[ "$file" == *temp* ]]; then
                printf "  %-14s %-12s %3s°C\n" "$name" "$label" "$((value / 1000))"
            else
                printf "  %-14s %-12s %s RPM\n" "$name" "$label" "$value"
            fi
            found=true
        done
    done
    $found || echo "  No hay sensores disponibles"
}

info_network() {
    local iface speed
    info_title "RED"
    ip -br addr 2>/dev/null | grep -v '^lo ' | sed 's/^/  /'
    echo "  Salida a internet por: $(ip route show default 2>/dev/null | awk '{print $5; exit}')"
    for iface in /sys/class/net/*; do
        speed=$(cat "$iface/speed" 2>/dev/null) || continue
        [ "${speed:-0}" -gt 0 ] 2>/dev/null && echo "  Velocidad del enlace de ${iface##*/}: $speed Mb/s"
    done
    if command -v nmcli &> /dev/null; then
        LC_ALL=C nmcli -t -f ACTIVE,SSID,SIGNAL,RATE,SECURITY dev wifi 2>/dev/null | awk -F: '$1 == "yes" {
            print "  Wi-Fi conectado: " $2 " · señal " $3 "% · " $4 " · " $5 }'
    fi
    echo "  DNS: $(current_dns) · TCP: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
}

info_battery() {
    local bat full design health found=false
    info_title "BATERÍA"
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue
        found=true
        full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
        design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
        echo "  ${bat##*/}: $(cat "$bat/manufacturer" 2>/dev/null) $(cat "$bat/model_name" 2>/dev/null)"
        echo "    Carga: $(cat "$bat/capacity" 2>/dev/null)% · estado: $(cat "$bat/status" 2>/dev/null)"
        if [ -n "$full" ] && [ -n "$design" ] && [ "$design" -gt 0 ]; then
            health=$((full * 100 / design))
            echo "    Salud: ${health}% de la capacidad original"
        fi
        [ -f "$bat/cycle_count" ] && echo "    Ciclos de carga: $(cat "$bat/cycle_count")"
    done
    $found || echo "  No hay batería (equipo de escritorio)"
}

info_usb() {
    info_title "USB Y PERIFÉRICOS"
    if command -v lsusb &> /dev/null; then
        lsusb | sed 's/^Bus [0-9]* Device [0-9]*: ID [0-9a-f:]* /  /' | grep -vi 'root hub'
    else
        echo "  (usbutils no está instalado)"
    fi
}

info_diagnostics() {
    info_title "SERVICIOS QUE FALLARON"
    { LC_ALL=C systemctl --failed --no-legend --plain 2>/dev/null; LC_ALL=C systemctl --user --failed --no-legend --plain 2>/dev/null; } \
        | sed 's/^/  /' | grep . || echo "  Ninguno"
    info_title "ERRORES DEL ÚLTIMO ARRANQUE (los 15 más recientes)"
    LC_ALL=C sudo journalctl -b -p err --no-pager -q 2>/dev/null | tail -15 | cut -c1-160 | sed 's/^/  /' | grep . || echo "  Ninguno"
    info_title "TIEMPO DE ARRANQUE"
    LC_ALL=C systemd-analyze 2>/dev/null | head -1 | sed 's/^/  /'
    echo "  Lo que más tarda:"
    LC_ALL=C systemd-analyze blame 2>/dev/null | head -8 | sed 's/^ */    /'
    info_title "PROCESOS QUE MÁS CONSUMEN"
    echo "  Por CPU:"
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6 | sed 's/^/    /'
    echo "  Por memoria:"
    ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -6 | sed 's/^/    /'
}

info_script_changes() {
    local custom count
    info_title "CAMBIOS HECHOS POR ESTE SCRIPT"
    echo "  Kernel en uso: $(uname -r)"
    custom=$(installed_pkgs 'linux-image-[0-9]*' | grep -E 'liquorix|xanmod' | sed 's/^linux-image-//' | tr '\n' ' ')
    [ -n "$custom" ] && echo "  Kernels de terceros instalados: $custom"
    [ -n "$FLAVOR_META" ] && ! installed_pkgs "$FLAVOR_META" | grep -qx -- "$FLAVOR_META" \
        && echo "  Meta-paquete $FLAVOR_META: quitado"
    [ -f /etc/default/grub ] && echo "  GRUB: $(grep -E '^GRUB_(DEFAULT|TIMEOUT)=' /etc/default/grub | tr '\n' ' ')"
    if [ -s "$GRUB_HIDDEN_LIST" ]; then
        echo "  Entradas ocultas en GRUB: $(wc -l < "$GRUB_HIDDEN_LIST")"
    fi
    [ -f "$GRUB_OTHERS_FIRST" ] && echo "  GRUB: otros sistemas antes que ${FLAVOR_NAME}"
    [ -f "$GRUB_LOOK_FILE" ] && echo "  GRUB: colores personalizados"
    if [ -f "$REMOVED_LIST" ]; then
        count=$(wc -l < "$REMOVED_LIST")
        echo "  Paquetes eliminados: $count"
    fi
    if [ -f "$INSTALLED_LIST" ]; then
        echo "  Programas instalados: $(tr '\n' ' ' < "$INSTALLED_LIST")"
    fi
    show_tweaks_status | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^$' | grep -v 'Estado actual' | sed 's/^ */  /'
    return 0
}

# Informe completo en texto, sin preguntas ni descargas
info_full_report() {
    local was=$INFO_QUIET
    INFO_QUIET=true
    echo "Informe de Ubuntu Ultimate Tools · $(date '+%Y-%m-%d %H:%M')"
    info_summary
    info_cpu_ram
    info_gpu
    info_disks
    info_temps
    info_network
    info_battery
    info_usb
    info_diagnostics
    info_script_changes
    if command -v inxi &> /dev/null; then
        info_title "INXI"
        inxi -Fxxz -c 0 2>/dev/null | sed 's/^/  /'
    fi
    INFO_QUIET=$was
}

# Quita datos personales antes de compartir: números de serie, MAC, IP, UUID,
# nombre de usuario, nombre del equipo y red Wi-Fi
privacy_filter() {
    local host
    host=$(hostname)
    sed -E \
        -e 's/(Serial( Number)?|serial)( *[:=] *).*/\1\3(oculto)/' \
        -e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/XX:XX:XX:XX:XX:XX/g' \
        -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]+)?\b/x.x.x.x/g' \
        -e 's/\b([0-9a-fA-F]{0,4}:){3,7}[0-9a-fA-F]{1,4}(\/[0-9]+)?\b/x:x:x:x/g' \
        -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/uuid-oculto/g' \
        -e 's/(Wi-Fi conectado: )[^·]*/\1(oculta) /' \
        -e "s/\\b${USER}\\b/usuario/g" \
        -e "s/\\b${host}\\b/equipo/g"
}

info_search() {
    local report term
    report=$(mktemp)
    echo -e "${CYAN}⏳ Reuniendo toda la información...${NC}"
    info_full_report > "$report" 2>/dev/null
    while true; do
        echo ""
        read -r -p "🔎 Palabra a buscar (por ejemplo nvidia, temp, wifi, error; Enter = volver): " term
        [ -n "$term" ] || break
        local matches
        # Solo en el contenido, no en los títulos de las secciones
        matches=$(awk -v t="$term" 'BEGIN {t = tolower(t)}
            /^▶ / {sec = substr($0, 5); next}
            index(tolower($0), t) {print "[" sec "]\t" $0}' "$report")
        if [ -z "$matches" ]; then
            echo -e "${YELLOW}  No aparece \"$term\"${NC}"
            continue
        fi
        echo -e "${GREEN}  $(wc -l <<< "$matches") resultados:${NC}"
        local sec line
        while IFS=$'\t' read -r sec line; do
            printf "  ${CYAN}%s${NC} %s\n" "$sec" "$(GREP_COLORS='mt=01;33' grep --color=always -i -F -- "$term" <<< "${line# }")"
        done <<< "$matches"
    done
    rm -f "$report"
}

info_save_report() {
    local file
    file="$HOME/informe-sistema-$(date +%Y%m%d-%H%M).txt"
    echo -e "${CYAN}⏳ Reuniendo toda la información...${NC}"
    info_full_report 2>/dev/null | privacy_filter > "$file"
    log_success "Informe guardado en: $file"
    echo -e "${CYAN}ℹ Se ocultaron números de serie, MAC, IP, UUID, usuario, nombre del equipo y red Wi-Fi.${NC}"
    echo -e "${CYAN}  Revísalo antes de compartirlo.${NC}"
}

# Prueba rápida: velocidad del disco del usuario y de internet
info_benchmark() {
    local file free out
    info_title "VELOCIDAD DEL DISCO (carpeta personal)"
    free=$(df -Pm "$HOME" | awk 'NR == 2 {print $4}')
    if [ "${free:-0}" -lt 2048 ]; then
        echo "  No hay espacio libre suficiente para la prueba (hace falta 2 GB)"
    else
        file="$HOME/.prueba-velocidad-uut"
        out=$(LC_ALL=C dd if=/dev/zero of="$file" bs=1M count=1024 oflag=direct conv=fdatasync 2>&1 | tail -1)
        echo "  Escritura: ${out##*, }"
        out=$(LC_ALL=C dd if="$file" of=/dev/null bs=1M iflag=direct 2>&1 | tail -1)
        echo "  Lectura:   ${out##*, }"
        rm -f "$file"
    fi

    info_title "INTERNET"
    local avg start end bytes=50000000
    avg=$(LC_ALL=C ping -c 4 -q 1.1.1.1 2>/dev/null | awk -F'/' '/^rtt/ {print $5}')
    echo "  Latencia (ping a 1.1.1.1): ${avg:+$avg ms}${avg:-sin respuesta}"
    start=$(date +%s.%N)
    if wget -qO /dev/null "https://speed.cloudflare.com/__down?bytes=$bytes" 2>> "$LOG_FILE"; then
        end=$(date +%s.%N)
        awk -v b="$bytes" -v t="$(awk -v a="$start" -v z="$end" 'BEGIN {print z - a}')" \
            'BEGIN {printf "  Descarga: %.0f Mb/s (50 MB desde Cloudflare)\n", b * 8 / t / 1000000}'
    else
        echo "  Descarga: no se pudo medir (¿hay conexión a internet?)"
    fi
    echo "  (Valores aproximados: repítela si el equipo estaba ocupado)"
}

sysinfo_menu() {
    local option level
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    🖥️ INFORMACIÓN DEL SISTEMA                     ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e "${CYAN}👀 Vistas rápidas:${NC}"
        echo -e "  ${CYAN} 1)${NC} Resumen rápido (sin internet ni instalar nada)"
        echo -e "  ${CYAN} 2)${NC} Fastfetch (el instalado o uno temporal)"
        echo -e "  ${CYAN} 3)${NC} inxi: informe completo (el instalado o uno temporal)"
        echo -e "\n${CYAN}🔩 Hardware en detalle:${NC}"
        echo -e "  ${CYAN} 4)${NC} CPU y memoria RAM (cada módulo y ranuras libres)"
        echo -e "  ${CYAN} 5)${NC} Tarjeta gráfica y driver en uso"
        echo -e "  ${CYAN} 6)${NC} Discos, espacio y salud (SMART)"
        echo -e "  ${CYAN} 7)${NC} Temperaturas y ventiladores"
        echo -e "  ${CYAN} 8)${NC} Red: IP, Wi-Fi, velocidad del enlace y DNS"
        echo -e "  ${CYAN} 9)${NC} Batería: salud y ciclos"
        echo -e "  ${CYAN}10)${NC} USB y periféricos"
        echo -e "\n${CYAN}🩺 Estado del sistema:${NC}"
        echo -e "  ${CYAN}11)${NC} Diagnóstico: servicios fallidos, errores, arranque y procesos"
        echo -e "  ${CYAN}12)${NC} Qué cambió este script"
        echo -e "\n${CYAN}🧰 Herramientas:${NC}"
        echo -e "  ${CYAN}13)${NC} 🔎 Buscar en toda la información"
        echo -e "  ${CYAN}14)${NC} 💾 Guardar informe completo para compartir (sin datos personales)"
        echo -e "  ${CYAN}15)${NC} ⏱️ Prueba de rendimiento (disco e internet)"
        echo -e "\n  ${CYAN} 0)${NC} 🔙 Volver"
        echo ""
        read -r -p "📌 Opción (0-15): " option
        case $option in
            1) info_summary ;;
            2) info_fastfetch ;;
            3)
                read -r -p "  Nivel: 1) normal  2) muy detallado [1]: " level
                if [ "$level" = 2 ]; then info_inxi "-Fxxx"; else info_inxi "-F"; fi ;;
            4) info_cpu_ram ;;
            5) info_gpu ;;
            6) info_disks ;;
            7) info_temps ;;
            8) info_network ;;
            9) info_battery ;;
            10) info_usb ;;
            11) info_diagnostics ;;
            12) info_script_changes ;;
            13) info_search ;;
            14) info_save_report ;;
            15) info_benchmark ;;
            0) return 0 ;;
            *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; continue ;;
        esac
        pause
    done
}

# ============================================================
# MIGRACIÓN DESDE "KUBUNTU LITE"
# ============================================================

# Las versiones anteriores se llamaban "Kubuntu Lite" y guardaban su configuración con
# ese nombre. La primera vez se renombra todo (sin cambiar su contenido) para que el
# script siga reconociendo lo que ya se configuró. Si no hay nada viejo, no hace nada.
migrate_from_kubuntu_lite() {
    local old new pair f ext orig moved=false grub_changed=false
    local pairs=(
        "/etc/kubuntu-lite|$UUT_ETC"
        "/etc/sysctl.d/99-kubuntu-lite.conf|$SYSCTL_FILE"
        "/etc/modules-load.d/kubuntu-lite-bbr.conf|$BBR_MODULES_FILE"
        "/etc/NetworkManager/conf.d/99-kubuntu-lite-wifi.conf|$NM_WIFI_CONF"
        "/etc/systemd/resolved.conf.d/99-kubuntu-lite-dns.conf|$RESOLVED_DNS_CONF"
        "/etc/default/grub.kubuntu-lite.orig|$GRUB_DEFAULT_BACKUP"
        "/etc/grub.d/09_kubuntu_lite_otros_primero|$GRUB_OTHERS_FIRST"
        "/etc/grub.d/42_kubuntu_lite_apariencia|$GRUB_LOOK_FILE"
    )

    # Archivos del usuario
    rm -f "$HOME/kubuntu-lite.log"
    if [ -d "$HOME/.local/share/kubuntu-lite" ] && [ ! -e "$STATE_DIR" ]; then
        mkdir -p "$(dirname "$STATE_DIR")"
        mv "$HOME/.local/share/kubuntu-lite" "$STATE_DIR" && moved=true
    fi

    # Archivos del sistema
    for pair in "${pairs[@]}"; do
        old=${pair%%|*}
        new=${pair#*|}
        if [ -e "$old" ] && [ ! -e "$new" ]; then
            sudo mv "$old" "$new" && moved=true
            [[ "$new" == /etc/grub.d/* || "$new" == "$GRUB_DEFAULT_BACKUP" ]] && grub_changed=true
        fi
    done

    # Fondo de GRUB: archivo y ruta en /etc/default/grub
    for f in /boot/grub/kubuntu-lite-fondo.*; do
        [ -f "$f" ] || continue
        ext=${f##*.}
        sudo mv "$f" "/boot/grub/ubuntu-ultimate-tools-fondo.$ext"
        sudo sed -i '/^GRUB_BACKGROUND=/s|kubuntu-lite-fondo\.|ubuntu-ultimate-tools-fondo.|' /etc/default/grub
        moved=true
        grub_changed=true
    done

    # Filtros de entradas ocultas: llevan las rutas dentro, se escriben de nuevo
    for f in /etc/grub.d/*_kubuntu_lite; do
        [ -f "$f" ] || continue
        orig=${f%_kubuntu_lite}
        sudo rm -f "$f"
        [ -f "$orig" ] && write_grub_filter_wrapper "$orig"
        moved=true
        grub_changed=true
    done

    $moved || return 0
    # Los que llevan rutas dentro se reescriben con las nuevas
    [ -f "$GRUB_FILTER_AWK" ] && write_grub_filter
    [ -f "$GRUB_OTHERS_FIRST" ] && write_others_first_script
    log_success "Configuración de \"Kubuntu Lite\" pasada a \"Ubuntu Ultimate Tools\""
    if $grub_changed; then
        regen_grub || log_warning "Revisa el menú de GRUB en la opción 12"
    fi
}

# ============================================================
# MENÚ PRINCIPAL (COLOR: CIAN)
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}📌 ¿Qué deseas hacer?${NC}\n"
        echo -e "  ${CYAN} 1)${NC} 🔄 ACTUALIZAR SISTEMA (update/upgrade/clean)"
        echo -e "  ${CYAN} 2)${NC} 🗑️  Eliminar aplicaciones preinstaladas"
        if [ "$FLAVOR" = kubuntu ]; then
            echo -e "  ${CYAN} 3)${NC} ⚙️  Configurar sistema (meta-paquete, manuales, Rolling Release solo Kubuntu)"
        else
            echo -e "  ${CYAN} 3)${NC} ⚙️  Configurar sistema (meta-paquete y manuales)"
        fi
        echo -e "  ${CYAN} 4)${NC} 🎮 Optimizar GPU (NVIDIA/AMD/Intel)"
        echo -e "  ${CYAN} 5)${NC} ⚡ Optimizar Kernel (Liquorix/XanMod/Estándar)"
        echo -e "  ${CYAN} 6)${NC} 💾 Optimizar Memoria RAM (automático)"
        echo -e "  ${CYAN} 7)${NC} 🖥️  Instalar Alacritty (terminal GPU) y temas"
        echo -e "  ${CYAN} 8)${NC} 📦 Instalar software opcional"
        echo -e "  ${CYAN} 9)${NC} ↩️  Revertir a distribución original"
        echo -e "  ${CYAN}10)${NC} ☢️  ELIMINACION NUCLEAR DE SNAP"
        echo -e "  ${CYAN}11)${NC} 🔄 REINSTALAR SNAP"
        echo -e "  ${CYAN}12)${NC} 🔧 ARRANQUE: reparar y personalizar GRUB/EFI"
        echo -e "  ${CYAN}13)${NC} 🧹 Quitar accesos directos (escritorio y panel)"
        echo -e "  ${CYAN}14)${NC} 🌐 Red, DNS y drivers"
        echo -e "  ${CYAN}15)${NC} 🔋 Energía y rendimiento"
        echo -e "  ${CYAN}16)${NC} 🚀 PERFILES AUTOMÁTICOS (gaming, productividad...)"
        echo -e "  ${CYAN}17)${NC} ↩️  Deshacer optimizaciones / quitar programas"
        echo -e "  ${CYAN}18)${NC} 🖥️  Información del sistema y hardware"
        echo -e "  ${CYAN}19)${NC} 🔌 Apagar / Reiniciar sistema"
        echo -e "\n  ${CYAN} 0)${NC} ❌ Salir"
        echo ""
        read -r -p "🔢 Opción (0-19): " option

        case $option in
            1) system_update ;;
            2) select_apps_to_remove ;;
            3) configure_system ;;
            4) optimize_gpu_menu ;;
            5) optimize_kernel_menu ;;
            6) optimize_ram_menu ;;
            7) install_custom_software ;;
            8) select_optional_software ;;
            9) revert_changes ;;
            10) nuclear_snap_removal ;;
            11) reinstall_snap ;;
            12) grub_repair_menu ;;
            13) remove_shortcuts_menu ;;
            14) network_menu ;;
            15) power_menu ;;
            16) profiles_menu ;;
            17) undo_menu ;;
            18) sysinfo_menu ;;
            19) shutdown_menu ;;
            0)
                echo -e "\n${GREEN}✅ ¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción inválida${NC}"
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

echo "=== Ubuntu Ultimate Tools - $(date) ===" > "$LOG_FILE"

# Pide la contraseña una sola vez y la mantiene activa mientras corre el script
echo -e "${YELLOW}🔑 Se necesitan permisos de administrador${NC}"
if ! sudo -v; then
    echo -e "${RED}❌ No se pudo obtener sudo${NC}"
    exit 1
fi
while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done 2>/dev/null &

migrate_from_kubuntu_lite
detect_flavor
cleanup_pending_kernels

if [ -n "$PROFILE" ]; then
    run_profile "$PROFILE"
    exit $?
fi

main_menu
