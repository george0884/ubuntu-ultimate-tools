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

# Colores base (uniformes por menú)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
WHITE='\033[1;37m'

# Variables de estado
SELECTED_APPS=()
SELECTED_OPTIONAL=()
REMOVE_METAPACKAGE=false
USE_ROLLING=false
REMOVE_SNAPS=false

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
    read
}

confirm() {
    local prompt="$1"
    local response
    echo -e -n "$prompt (s/n): "
    read response
    [[ "$response" =~ ^[sS]$ ]]
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

    read -p "🔢 Números a eliminar: " input

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
        sudo apt remove --purge -y kubuntu-desktop > /dev/null 2>&1
        sudo apt install -y plasma-desktop > /dev/null 2>&1
        echo -e "${GREEN}✓ Se eliminó kubuntu-desktop${NC}"
    else
        echo -e "${YELLOW}ℹ Se mantiene kubuntu-desktop${NC}"
    fi

    echo ""
    echo -e "${GREEN}2. Cambio a KDE Rolling Release${NC}"
    echo -e "   ${GREEN}📝 Descripción:${NC} Cambia los repositorios a versión Rolling Release"
    echo -e "   ${GREEN}✓ Beneficio:${NC} Te dará las últimas versiones de KDE Plasma"
    echo ""
    if confirm "${GREEN}¿Cambiar a KDE Rolling Release? (recomendado)${NC}"; then
        sudo add-apt-repository -y ppa:kubuntu-ppa/backports > /dev/null 2>&1
        sudo apt update > /dev/null 2>&1
        echo -e "${GREEN}✓ Se cambió a KDE Rolling Release${NC}"
    else
        echo -e "${YELLOW}ℹ Se mantienen repositorios estándar${NC}"
    fi

    pause
}

# ============================================================
# OPCIÓN 3: OPTIMIZACIÓN DE GPU (COLOR: MAGENTA)
# ============================================================

optimize_gpu_menu() {
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
    read -p "📌 Opción (1-5): " gpu_option

    case $gpu_option in
        1) optimize_nvidia ;;
        2) optimize_amd ;;
        3) optimize_intel ;;
        4) auto_detect_gpu ;;
        5) return 0 ;;
        *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; optimize_gpu_menu ;;
    esac
    pause
}

optimize_nvidia() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🟢 OPTIMIZACIÓN NVIDIA                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}⚠ Driver NVIDIA no detectado. Instalando...${NC}"
        sudo apt update > /dev/null 2>&1
        sudo apt install -y nvidia-driver-550 > /dev/null 2>&1
        echo -e "${GREEN}✓ Driver NVIDIA instalado (requiere reinicio)${NC}"
    fi

    echo -e "${PURPLE}🔧 Activando modo de rendimiento persistente...${NC}"
    sudo nvidia-smi -pm 1 > /dev/null 2>&1

    echo -e "${PURPLE}🔧 Configurando perfil de memoria máximo...${NC}"
    sudo nvidia-smi -ac 5001,1590 > /dev/null 2>&1

    echo -e "${PURPLE}🔧 Activando soporte para CUDA y OpenCL...${NC}"
    sudo apt install -y nvidia-cuda-toolkit nvidia-opencl-icd > /dev/null 2>&1

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
    sudo apt update > /dev/null 2>&1
    sudo apt install -y mesa-utils mesa-vulkan-drivers libgl1-mesa-dri > /dev/null 2>&1

    echo -e "${PURPLE}🔧 Activando overclocking y control de fans...${NC}"
    echo 'options amdgpu ppfeaturemask=0xffffffff' | sudo tee /etc/modprobe.d/amd_ppfeaturemask.conf > /dev/null

    echo -e "${PURPLE}🔧 Instalando CoreCtrl para control gráfico...${NC}"
    sudo apt install -y corectrl > /dev/null 2>&1

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
    sudo apt update > /dev/null 2>&1
    sudo apt install -y intel-media-va-driver intel-gpu-tools va-driver-all vainfo > /dev/null 2>&1

    echo -e "${PURPLE}🔧 Activando GuC/HuC para códecs...${NC}"
    echo 'options i915 enable_guc=3' | sudo tee /etc/modprobe.d/i915_guc.conf > /dev/null

    echo ""
    echo -e "${GREEN}✓ ¡OPTIMIZACIÓN INTEL COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Reinicia el sistema para aplicar todos los cambios${NC}"
}

auto_detect_gpu() {
    echo -e "${PURPLE}🔄 Detectando GPU...${NC}"
    if lspci | grep -i nvidia > /dev/null; then
        echo -e "${GREEN}🟢 GPU NVIDIA detectada${NC}"
        optimize_nvidia
    elif lspci | grep -i amd > /dev/null; then
        echo -e "${GREEN}🔴 GPU AMD detectada${NC}"
        optimize_amd
    elif lspci | grep -i intel > /dev/null; then
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
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚡ OPTIMIZACIÓN DEL KERNEL                     ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${BLUE}📋 Opciones de optimización del kernel:${NC}\n"
    echo -e "  ${BLUE}1)${NC} Kernel Liquorix (máximo rendimiento, gaming)"
    echo -e "  ${BLUE}2)${NC} Kernel Zen (rendimiento balanceado, desktop)"
    echo -e "  ${BLUE}3)${NC} Kernel oficial Ubuntu LTS + optimizaciones (recomendado)"
    echo -e "  ${BLUE}4)${NC} Kernel oficial + Livepatch (Ubuntu Pro)"
    echo -e "  ${BLUE}5)${NC} Ajustes avanzados de kernel"
    echo -e "  ${BLUE}6)${NC} Volver"
    echo ""
    read -p "📌 Opción (1-6): " kernel_option

    case $kernel_option in
        1) install_liquorix_kernel ;;
        2) install_zen_kernel ;;
        3) optimize_standard_kernel ;;
        4) install_standard_livepatch_kernel ;;
        5) advanced_kernel_tweaks ;;
        6) return 0 ;;
        *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1; optimize_kernel_menu ;;
    esac
    pause
}

install_liquorix_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚡ KERNEL LIQUORIX                             ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${BLUE}📦 Agregando repositorio Liquorix...${NC}"
    sudo add-apt-repository -y ppa:damentz/liquorix > /dev/null 2>&1
    sudo apt update > /dev/null 2>&1

    echo -e "${BLUE}📦 Instalando kernel Liquorix...${NC}"
    sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 > /dev/null 2>&1
    sudo update-grub > /dev/null 2>&1

    echo -e "${GREEN}✓ Kernel Liquorix instalado${NC}"
    echo -e "${YELLOW}⚠ Reinicia para usar el nuevo kernel${NC}"
}

install_zen_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🐧 KERNEL ZEN                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${BLUE}📦 Instalando kernel Zen...${NC}"
    sudo apt install -y linux-zen linux-headers-zen > /dev/null 2>&1
    sudo update-grub > /dev/null 2>&1

    echo -e "${GREEN}✓ Kernel Zen instalado${NC}"
    echo -e "${YELLOW}⚠ Reinicia para usar el nuevo kernel${NC}"
}

optimize_standard_kernel() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚙️ KERNEL OFICIAL UBUNTU LTS                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${BLUE}📦 Instalando kernel oficial de Ubuntu LTS...${NC}"

    # Instalar kernel genérico oficial
    echo -e "${BLUE}[1/6] Instalando kernel generic...${NC}"
    sudo apt update > /dev/null 2>&1
    sudo apt install -y linux-image-generic linux-headers-generic linux-modules-extra-generic > /dev/null 2>&1

    # Eliminar kernels no oficiales (Liquorix)
    echo -e "${BLUE}[2/6] Eliminando kernels Liquorix si existen...${NC}"
    if dpkg -l | grep -q "linux-image-liquorix"; then
        sudo apt remove -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 2>/dev/null
        echo -e "  ${GREEN}✓ Kernels Liquorix eliminados${NC}"
    else
        echo -e "  ${YELLOW}ℹ No se encontraron kernels Liquorix${NC}"
    fi

    # Eliminar kernels Zen
    echo -e "${BLUE}[3/6] Eliminando kernels Zen si existen...${NC}"
    if dpkg -l | grep -q "linux-image-zen"; then
        sudo apt remove -y linux-image-zen linux-headers-zen 2>/dev/null
        echo -e "  ${GREEN}✓ Kernels Zen eliminados${NC}"
    else
        echo -e "  ${YELLOW}ℹ No se encontraron kernels Zen${NC}"
    fi

    # Limpiar kernels antiguos
    echo -e "${BLUE}[4/6] Limpiando kernels antiguos...${NC}"
    sudo apt autoremove --purge -y > /dev/null 2>&1

    # Actualizar GRUB
    echo -e "${BLUE}[5/6] Actualizando GRUB...${NC}"
    sudo update-grub > /dev/null 2>&1

    # Aplicar optimizaciones
    echo -e "${BLUE}[6/6] Aplicando optimizaciones de rendimiento...${NC}"
    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null

    sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null

    echo ""
    echo -e "${GREEN}✓ Kernel oficial Ubuntu LTS instalado correctamente${NC}"
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

    echo -e "${BLUE}📦 Instalando kernel oficial con soporte Livepatch...${NC}"

    # Instalar kernel genérico
    echo -e "${BLUE}[1/5] Instalando kernel generic...${NC}"
    sudo apt update > /dev/null 2>&1
    sudo apt install -y linux-image-generic linux-headers-generic > /dev/null 2>&1

    # Instalar Ubuntu Pro tools
    echo -e "${BLUE}[2/5] Instalando Ubuntu Pro client...${NC}"
    sudo apt install -y ubuntu-advantage-tools > /dev/null 2>&1

    # Actualizar GRUB
    echo -e "${BLUE}[3/5] Actualizando GRUB...${NC}"
    sudo update-grub > /dev/null 2>&1

    # Aplicar optimizaciones
    echo -e "${BLUE}[4/5] Aplicando optimizaciones...${NC}"
    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null

    # Configurar Livepatch
    echo -e "${BLUE}[5/5] Configurando Livepatch...${NC}"
    if command -v pro &> /dev/null; then
        echo -e "${GREEN}✓ Ubuntu Pro client instalado${NC}"
        echo -e "${YELLOW}📋 Para habilitar Livepatch, necesitas un token de Ubuntu Pro${NC}"
        echo -e "${BLUE}🔑 Obtén tu token gratuito en: https://ubuntu.com/pro/dashboard${NC}"
        if confirm "¿Tienes un token para habilitar Livepatch ahora?"; then
            read -p "Ingresa tu token: " pro_token
            if [ -n "$pro_token" ]; then
                sudo pro attach "$pro_token" > /dev/null 2>&1
                sudo pro enable livepatch > /dev/null 2>&1
                echo -e "${GREEN}✓ Livepatch habilitado correctamente${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Livepatch no habilitado. Puedes configurarlo después con: sudo pro attach [token]${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ Kernel oficial con Livepatch configurado${NC}"
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

    if confirm "${BLUE}¿Deshabilitar mitigaciones de espectre/meltdown? (+15% rendimiento, riesgo alto)${NC}"; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 mitigations=off"/' /etc/default/grub
        sudo update-grub > /dev/null 2>&1
        echo -e "${GREEN}✓ Mitigaciones deshabilitadas (requiere reinicio)${NC}"
    fi

    if confirm "${BLUE}¿Habilitar TRIM automático para SSD?${NC}"; then
        sudo systemctl enable fstrim.timer > /dev/null 2>&1
        sudo systemctl start fstrim.timer > /dev/null 2>&1
        echo -e "${GREEN}✓ TRIM automático habilitado${NC}"
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

    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
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
    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null

    echo -e "${YELLOW}🔧 Configurando presión de caché...${NC}"
    sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null

    if confirm "${YELLOW}¿Activar compresión ZRAM? (mejora rendimiento con poca RAM)${NC}"; then
        echo -e "${YELLOW}📦 Instalando ZRAM...${NC}"
        sudo apt install -y zram-tools > /dev/null 2>&1
        echo 'PERCENT=50' | sudo tee /etc/default/zram-tools > /dev/null
        sudo service zram-tools restart > /dev/null 2>&1
        echo -e "${GREEN}✓ ZRAM configurado (50% de RAM como compresión)${NC}"
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
        echo -e "${GREEN}✓ Alacritty instalado (usando GPU para renderizado)${NC}"
    fi

    if confirm "${CYAN}¿Instalar tema Tokyo Night?${NC}"; then
        echo -e "${CYAN}🎨 Instalando tema...${NC}"
        sudo apt install -y kpackagetool6 git > /dev/null 2>&1

        cd /tmp
        git clone https://github.com/fausto-kouches/tokyo-night-kde 2>/dev/null
        if [ -d "tokyo-night-kde" ]; then
            cd tokyo-night-kde
            kpackagetool6 -t Plasma/LookAndFeel -i ./ 2>/dev/null
            lookandfeeltool -a org.kde.tokyonight.desktop 2>/dev/null
            echo -e "${GREEN}✓ Tema Tokyo Night instalado y aplicado${NC}"
        fi
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
    read -p "🔢 Números a instalar: " input

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
            sudo apt remove --purge -y "$app" > /dev/null 2>&1
            echo -e "  ${GREEN}✓ Eliminado: $app${NC}"

            if [[ "$app" == "kubuntu-web-shortcuts" ]]; then
                rm -f "$HOME/Escritorio/kubuntu-website.desktop" 2>/dev/null
                rm -f "$HOME/Desktop/kubuntu-website.desktop" 2>/dev/null
                echo -e "  ${GREEN}✓ Ícono de Kubuntu Website eliminado${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ No instalado: $app${NC}"
        fi
    done

    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

install_optional_with_progress() {
    local apps=("$@")

    echo -e "${BLUE}📦 Instalando software opcional...${NC}"
    sudo apt update > /dev/null 2>&1

    for app in "${apps[@]}"; do
        case $app in
            "filezilla") sudo apt install -y filezilla > /dev/null 2>&1 ;;
            "code") sudo apt install -y code > /dev/null 2>&1 ;;
            "virtualbox") sudo apt install -y virtualbox > /dev/null 2>&1 ;;
            "google-chrome-stable")
                wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
                sudo dpkg -i /tmp/chrome.deb > /dev/null 2>&1
                sudo apt install -f -y > /dev/null 2>&1
                rm /tmp/chrome.deb ;;
            "telegram-desktop") sudo apt install -y telegram-desktop > /dev/null 2>&1 ;;
            "python3") sudo apt install -y python3 > /dev/null 2>&1 ;;
            "python3-pip") sudo apt install -y python3-pip > /dev/null 2>&1 ;;
            "python3-venv") sudo apt install -y python3-venv > /dev/null 2>&1 ;;
            "git") sudo apt install -y git > /dev/null 2>&1 ;;
            "curl") sudo apt install -y curl > /dev/null 2>&1 ;;
            "wget") sudo apt install -y wget > /dev/null 2>&1 ;;
            "htop") sudo apt install -y htop > /dev/null 2>&1 ;;
            "fastfetch") sudo apt install -y fastfetch > /dev/null 2>&1 ;;
            "timeshift") sudo apt install -y timeshift > /dev/null 2>&1 ;;
            "gparted") sudo apt install -y gparted > /dev/null 2>&1 ;;
            "vim") sudo apt install -y vim > /dev/null 2>&1 ;;
            "discord")
                wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
                sudo dpkg -i /tmp/discord.deb > /dev/null 2>&1
                sudo apt install -f -y > /dev/null 2>&1
                rm /tmp/discord.deb ;;
            "spotify")
                curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
                echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
                sudo apt update > /dev/null 2>&1
                sudo apt install -y spotify-client > /dev/null 2>&1 ;;
            "obs-studio") sudo apt install -y obs-studio > /dev/null 2>&1 ;;
            "emojier") sudo apt install -y plasma5-addons > /dev/null 2>&1 ;;
            "qrca") sudo apt install -y qrca > /dev/null 2>&1 ;;
        esac
        echo -e "  ${GREEN}✓ Instalado: $app${NC}"
    done
}

# ============================================================
# OPCIÓN 9: REVERTIR CAMBIOS (COLOR: ROJO)
# ============================================================

revert_changes() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    ↩️ REVERTIR A KUBUNTU                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${RED}📋 Esto reinstalará:${NC}"
    echo -e "  • kubuntu-desktop"
    echo -e "  • Snap"
    echo -e "  • Eliminará repositorios Rolling Release"
    echo ""

    if ! confirm "${RED}⚠ ¿Revertir a Kubuntu original?${NC}"; then
        return 0
    fi

    echo -e "${RED}📦 Reinstalando kubuntu-desktop...${NC}"
    sudo apt install --reinstall -y kubuntu-desktop > /dev/null 2>&1

    echo -e "${RED}🗑 Eliminando Rolling Release...${NC}"
    sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports > /dev/null 2>&1

    echo -e "${RED}📦 Reinstalando Snap...${NC}"
    sudo apt install -y snapd > /dev/null 2>&1

    echo -e "${RED}🧹 Limpiando configuraciones...${NC}"
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

    echo -e "${RED}[1/11] Deteniendo servicios snap...${NC}"
    sudo systemctl stop snapd.service 2>/dev/null
    sudo systemctl disable snapd.service 2>/dev/null

    echo -e "${RED}[2/11] Matando procesos snap...${NC}"
    sudo pkill -f snapd 2>/dev/null
    sudo killall snapd 2>/dev/null

    echo -e "${RED}[3/11] Eliminando paquetes snap...${NC}"
    for snap in $(snap list 2>/dev/null | awk 'NR>1 {print $1}'); do
        sudo snap remove --purge "$snap" 2>/dev/null
    done

    echo -e "${RED}[4/11] Eliminando snaps del sistema...${NC}"
    sudo snap remove --purge core22 2>/dev/null
    sudo snap remove --purge core20 2>/dev/null
    sudo snap remove --purge core 2>/dev/null

    echo -e "${RED}[5/11] Desmontando directorios loop...${NC}"
    for mnt in $(mount | grep -E 'snap|/snap/' | awk '{print $3}'); do
        sudo umount "$mnt" 2>/dev/null
    done

    echo -e "${RED}[6/11] Eliminando paquetes snapd...${NC}"
    sudo apt remove --purge -y snapd gnome-software-plugin-snap snapd-xdg-open > /dev/null 2>&1
    sudo apt autoremove --purge -y > /dev/null 2>&1

    echo -e "${RED}[7/11] Bloqueando reinstalación...${NC}"
    sudo apt-mark hold snapd 2>/dev/null
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
    sudo rm -f /usr/bin/snap /usr/bin/snapctl /usr/lib/snapd 2>/dev/null

    echo -e "${RED}[11/11] Limpieza final...${NC}"
    sudo apt autoremove --purge -y > /dev/null 2>&1
    sudo apt autoclean -y > /dev/null 2>&1

    echo ""
    echo -e "${GREEN}✓ ¡ELIMINACIÓN NUCLEAR DE SNAP COMPLETADA!${NC}"
    echo -e "${YELLOW}⚠ Snap ha sido borrado SIN POSIBILIDAD DE REINSTALACIÓN${NC}"
    echo -e "${BLUE}📦 Para Firefox: sudo apt install firefox${NC}"
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
    sudo apt update > /dev/null 2>&1
    sudo apt install -y snapd > /dev/null 2>&1

    echo -e "${GREEN}[3/5] Instalando Ubuntu Pro client...${NC}"
    sudo apt install -y ubuntu-advantage-tools > /dev/null 2>&1

    echo -e "${GREEN}[4/5] Creando directorios necesarios...${NC}"
    sudo mkdir -p /snap /var/snap /var/lib/snapd

    echo -e "${GREEN}[5/5] Iniciando servicios...${NC}"
    sudo systemctl enable snapd.service > /dev/null 2>&1
    sudo systemctl start snapd.service > /dev/null 2>&1

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
        read -p "📌 Opcion (1-5): " grub_option

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
    read
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
        local boot_disk=$(lsblk -d -o NAME | grep -E "sd|hd|nvme" | head -1)
        echo -e "${PURPLE}🔄 Reparando GRUB en modo BIOS (disco: /dev/$boot_disk)...${NC}"
        sudo grub-install --target=i386-pc "/dev/$boot_disk"
    fi

    echo -e "${PURPLE}🔄 Regenerando configuración...${NC}"
    sudo update-grub

    echo -e "${GREEN}✓ GRUB reparado correctamente${NC}"
    echo -e "\n${YELLOW}📌 Presiona Enter para volver...${NC}"
    read
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
    read -p "📌 Ingresa el disco (ej: /dev/sda): " target_disk

    if [ ! -b "$target_disk" ]; then
        echo -e "${RED}❌ Error: El disco $target_disk no existe${NC}"
        read
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
    read
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
    read
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
    read -p "📌 Opción (1-3): " power_option

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
# MENÚ PRINCIPAL (COLOR: CIAN)
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}📌 ¿Qué deseas hacer?${NC}\n"
        echo -e "  ${CYAN} 1)${NC} 🗑️  Eliminar aplicaciones preinstaladas"
        echo -e "  ${CYAN} 2)${NC} ⚙️  Configurar sistema (Rolling Release)"
        echo -e "  ${CYAN} 3)${NC} 🎮 Optimizar GPU (NVIDIA/AMD/Intel)"
        echo -e "  ${CYAN} 4)${NC} ⚡ Optimizar Kernel (Liquorix/Zen/Estándar)"
        echo -e "  ${CYAN} 5)${NC} 💾 Optimizar Memoria RAM (automático)"
        echo -e "  ${CYAN} 6)${NC} 🔄 ACTUALIZAR SISTEMA (update/upgrade/clean)"
        echo -e "  ${CYAN} 7)${NC} 🖥️  Instalar Alacritty (terminal GPU) y temas"
        echo -e "  ${CYAN} 8)${NC} 📦 Instalar software opcional"
        echo -e "  ${CYAN} 9)${NC} ↩️  Revertir a Kubuntu original"
        echo -e "  ${CYAN}10)${NC} ☢️  ELIMINACION NUCLEAR DE SNAP"
        echo -e "  ${CYAN}11)${NC} 🔄 REINSTALAR SNAP"
        echo -e "  ${CYAN}12)${NC} 🔧 REPARAR GRUB (BIOS/EFI/Rescue)"
        echo -e "  ${CYAN}13)${NC} 🔌 Apagar / Reiniciar sistema"
        echo -e "  ${CYAN}14)${NC} ❌ Salir"
        echo ""
        read -p "🔢 Opcion (1-14): " option

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
            14)
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

main_menu
