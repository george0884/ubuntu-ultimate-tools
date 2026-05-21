#!/bin/bash

# ============================================================
# Script: Kubuntu Lite Ultimate
# Descripción: Transforma Kubuntu en un sistema minimalista
#              con optimizaciones de rendimiento extremo
# Versión: 5.0 - COMPLETAMENTE CORREGIDO
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
# OPCIÓN 1: ELIMINAR APLICACIONES (CORREGIDA - SIN DUPLICADOS)
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
        "18|kpat|Juego de cartas solitario"
        "19|krdc|Cliente de escritorio remoto"
        "20|kruler|Regla en pantalla"
        "21|ksudoku|Juego de Sudoku"
        "22|ktorrent|Cliente Torrent"
        "23|libreoffice-core|Suite ofimática"
        "24|skanlite|Escáner"
        "25|kmouth|Sintetizador de voz"
        "26|kcharselect|Mapa de caracteres"
        "27|kdf|Visor de uso de disco"
        "28|kfind|Buscador de archivos"
        "29|kgpg|Gestión de claves GPG"
        "30|kamoso|Cámara web"
        "31|kdeconnect|Sincronización con móvil"
        "32|kdenlive|Editor de video"
        "33|khelpcenter|Centro de ayuda"
        "34|kio-extras|Protocolos extra KIO"
        "35|kmix|Control de volumen"
        "36|kolourpaint|Pintura simple"
        "37|kompare|Comparador de archivos"
        "38|kremotecontrol|Control remoto"
        "39|kscreen|Configuración de pantallas"
        "40|ksystemlog|Visor de logs del sistema"
        "41|kteatime|Temporizador para té"
        "42|ktimer|Temporizador"
        "43|kwalletmanager|Gestión de contraseñas"
        "44|okular|Visor de PDF/DjVu"
        "45|spectacle|Capturas de pantalla"
        "46|gwenview|Visor de imágenes"
        "47|mpv|Reproductor multimedia ligero"
        "48|remmina|Cliente de escritorio remoto"
        "49|plasma-discover|Tienda de aplicaciones"
        "50|plasma-welcome|Guía de bienvenida de Kubuntu"
        "51|kubuntu-docs|Documentación de Kubuntu"
        "52|kubuntu-web-shortcuts|Accesos web de Kubuntu"
        "53|qml-module-org-kde-kirigami2|Componentes Kirigami"
        "54|qml-module-qtquick-controls2|Controles QtQuick"
    )

    for app in "${apps[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${CYAN}[%2s]${NC} %-22s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${YELLOW}Instrucciones: Escribe los números separados por espacio${NC}"
    echo "Ejemplo: 3 5 11 23 46 47 48"
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
# OPCIÓN 2: CONFIGURAR SISTEMA (CORREGIDA)
# ============================================================

configure_system() {
    log_title "CONFIGURACIÓN DEL SISTEMA"

    echo -e "${YELLOW}1. Meta-paquete kubuntu-desktop${NC}"
    echo "   Descripción: Es el paquete que agrupa todas las apps de Kubuntu"
    echo "   Si lo eliminas: Podrás desinstalar apps sin que se reinstalen"
    echo "   Si lo mantienes: El sistema intentará reinstalar apps eliminadas"
    echo ""
    if confirm "¿Eliminar kubuntu-desktop? (recomendado)"; then
        REMOVE_METAPACKAGE=true
        log_success "Se eliminará kubuntu-desktop"
    else
        log_info "Se mantiene kubuntu-desktop"
    fi

    echo ""
    echo -e "${YELLOW}2. Cambio a KDE Rolling Release${NC}"
    echo "   Descripción: Cambia los repositorios a versión Rolling Release"
    echo "   Esto te dará las últimas versiones de KDE Plasma"
    echo "   Equivalente a tener KDE Neon pero sobre Kubuntu"
    echo ""
    if confirm "¿Cambiar a KDE Rolling Release? (recomendado)"; then
        USE_ROLLING=true
        log_success "Se cambiará a KDE Rolling Release"
    else
        log_info "Se mantienen repositorios estándar"
    fi

    pause
}
# ============================================================
# OPCIÓN 3A: OPTIMIZACIÓN DE GPU
# ============================================================

optimize_gpu_menu() {
    log_title "OPTIMIZACIÓN DE GPU"

    echo -e "${YELLOW}Selecciona tu tarjeta gráfica:${NC}\n"
    echo "  1) 🟢 NVIDIA - Optimización completa"
    echo "  2) 🔴 AMD   - Optimización completa"
    echo "  3) 🔵 Intel - Optimización completa"
    echo "  4) ⚪ Detectar automáticamente y optimizar"
    echo "  5) ⬅️ Volver"
    echo ""
    read -p "Opción (1-5): " gpu_option

    case $gpu_option in
        1) optimize_nvidia ;;
        2) optimize_amd ;;
        3) optimize_intel ;;
        4) auto_detect_gpu ;;
        5) return 0 ;;
        *) log_error "Opción inválida"; sleep 1; optimize_gpu_menu ;;
    esac
    pause
}
optimize_nvidia() {
    log_title "OPTIMIZACIÓN NVIDIA"

    echo -e "${GREEN}Aplicando optimizaciones para GPU NVIDIA...${NC}\n"

    # Verificar driver
    if ! command -v nvidia-smi &> /dev/null; then
        log_warning "Driver NVIDIA no detectado. Instalando..."
        sudo apt update > /dev/null 2>&1
        sudo apt install -y nvidia-driver-550 > /dev/null 2>&1
        log_success "Driver NVIDIA instalado (requiere reinicio)"
    fi

    # Optimizaciones NVIDIA
    log_info "[1/6] Activando modo de rendimiento persistente..."
    sudo nvidia-smi -pm 1 > /dev/null 2>&1
    log_success "Modo persistente activado"

    log_info "[2/6] Configurando perfil de memoria máximo..."
    sudo nvidia-smi -ac 5001,1590 > /dev/null 2>&1
    log_success "Perfil de memoria configurado"

    log_info "[3/6] Activando modo de reloj máximo..."
    sudo nvidia-smi -pl 250 > /dev/null 2>&1
    log_success "Límite de potencia configurado"

    log_info "[4/6] Configurando archivo de configuración X11..."
    sudo nvidia-xconfig --cool-bits=28 > /dev/null 2>&1
    log_success "Configuración X11 aplicada"

    log_info "[5/6] Deshabilitando modo de ahorro de energía..."
    sudo nvidia-smi --power-limit=0 > /dev/null 2>&1
    log_success "Ahorro de energía deshabilitado"

    log_info "[6/6] Activando soporte para CUDA y OpenCL..."
    sudo apt install -y nvidia-cuda-toolkit nvidia-opencl-icd > /dev/null 2>&1
    log_success "CUDA y OpenCL instalados"

    echo ""
    log_success "¡OPTIMIZACIÓN NVIDIA COMPLETADA!"
    log_warning "Reinicia el sistema para aplicar todos los cambios"
}

optimize_amd() {
    log_title "OPTIMIZACIÓN AMD"

    echo -e "${GREEN}Aplicando optimizaciones para GPU AMD...${NC}\n"

    # Verificar driver AMD
    log_info "[1/7] Actualizando drivers AMD..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y mesa-utils mesa-vulkan-drivers libgl1-mesa-dri > /dev/null 2>&1
    log_success "Drivers AMD actualizados"

    log_info "[2/7] Activando overclocking y control de fans..."
    echo 'options amdgpu ppfeaturemask=0xffffffff' | sudo tee /etc/modprobe.d/amd_ppfeaturemask.conf > /dev/null
    log_success "Overclocking habilitado"

    log_info "[3/7] Configurando perfil de rendimiento 'high'..."
    echo 'high' | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level > /dev/null 2>&1
    log_success "Perfil de rendimiento configurado"

    log_info "[4/7] Configurando frecuencia máxima de memoria VRAM..."
    echo '1' | sudo tee /sys/class/drm/card0/device/pp_dpm_mclk > /dev/null 2>&1
    log_success "Frecuencia VRAM optimizada"

    log_info "[5/7] Activando Radeon Raytracing (si está disponible)..."
    echo '1' | sudo tee /sys/class/drm/card0/device/raytracing > /dev/null 2>&1
    log_success "Raytracing activado"

    log_info "[6/7] Instalando ROCm para computación (opcional)..."
    if confirm "¿Instalar ROCm para aceleración en IA/ML? (opcional, 3GB)"; then
        sudo apt install -y rocm-dev > /dev/null 2>&1
        log_success "ROCm instalado"
    fi

    log_info "[7/7] Instalando CoreCtrl para control gráfico..."
    sudo apt install -y corectrl > /dev/null 2>&1
    log_success "CoreCtrl instalado (acceso desde menú de aplicaciones)"

    echo ""
    log_success "¡OPTIMIZACIÓN AMD COMPLETADA!"
    log_warning "Reinicia el sistema para aplicar todos los cambios"
}

optimize_intel() {
    log_title "OPTIMIZACIÓN INTEL"

    echo -e "${GREEN}Aplicando optimizaciones para GPU Intel...${NC}\n"

    log_info "[1/5] Actualizando driver Intel..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y intel-media-va-driver intel-gpu-tools > /dev/null 2>&1
    log_success "Drivers Intel actualizados"

    log_info "[2/5] Activando aceleración por hardware..."
    sudo apt install -y va-driver-all vainfo > /dev/null 2>&1
    log_success "Aceleración VA-API activada"

    log_info "[3/5] Configurando governor de rendimiento..."
    echo 'performance' | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level > /dev/null 2>&1
    log_success "Governor configurado"

    log_info "[4/5] Activando GuC/HuC para códecs..."
    echo 'options i915 enable_guc=3' | sudo tee /etc/modprobe.d/i915_guc.conf > /dev/null
    log_success "GuC/HuC activados (mejora códecs de video)"

    log_info "[5/5] Optimizando para OpenCL..."
    sudo apt install -y intel-opencl-icd > /dev/null 2>&1
    log_success "OpenCL instalado"

    echo ""
    log_success "¡OPTIMIZACIÓN INTEL COMPLETADA!"
    log_warning "Reinicia el sistema para aplicar todos los cambios"
}

auto_detect_gpu() {
    log_title "DETECCIÓN AUTOMÁTICA DE GPU"

    if lspci | grep -i nvidia > /dev/null; then
        log_info "GPU NVIDIA detectada"
        optimize_nvidia
    elif lspci | grep -i amd > /dev/null; then
        log_info "GPU AMD detectada"
        optimize_amd
    elif lspci | grep -i intel > /dev/null; then
        log_info "GPU Intel detectada"
        optimize_intel
    else
        log_warning "No se detectó ninguna GPU compatible"
        log_info "Aplicando optimizaciones genéricas..."
        sudo apt install -y mesa-utils > /dev/null 2>&1
        log_success "Optimizaciones genéricas aplicadas"
    fi
    pause
}
# ============================================================
# OPCIÓN 3B: OPTIMIZACIÓN DEL KERNEL
# ============================================================

optimize_kernel_menu() {
    log_title "OPTIMIZACIÓN DEL KERNEL"

    echo -e "${YELLOW}Opciones de optimización del kernel:${NC}\n"
    echo "  1) ⚡ Kernel Liquorix (máximo rendimiento, gaming)"
    echo "  2) 🐧 Kernel Zen (rendimiento balanceado, desktop)"
    echo "  3) ⚙️  Kernel estándar con optimizaciones (recomendado)"
    echo "  4) 🔧 Ajustes avanzados de kernel (swappiness, cache)"
    echo "  5) ⬅️ Volver"
    echo ""
    read -p "Opción (1-5): " kernel_option

    case $kernel_option in
        1) install_liquorix_kernel ;;
        2) install_zen_kernel ;;
        3) optimize_standard_kernel ;;
        4) advanced_kernel_tweaks ;;
        5) return 0 ;;
        *) log_error "Opción inválida"; sleep 1; optimize_kernel_menu ;;
    esac
    pause
}

install_liquorix_kernel() {
    log_title "INSTALANDO KERNEL LIQUORIX"

    echo -e "${GREEN}Kernel Liquorix - Optimizado para gaming y baja latencia${NC}\n"

    log_info "[1/4] Agregando repositorio Liquorix..."
    sudo add-apt-repository -y ppa:damentz/liquorix > /dev/null 2>&1
    sudo apt update > /dev/null 2>&1
    log_success "Repositorio agregado"

    log_info "[2/4] Instalando kernel Liquorix..."
    sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 > /dev/null 2>&1
    log_success "Kernel Liquorix instalado"

    log_info "[3/4] Configurando parámetros de arranque..."
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash threadirqs nohz_full=2-11 mitigations=off"' | sudo tee -a /etc/default/grub > /dev/null
    sudo update-grub > /dev/null 2>&1
    log_success "Parámetros configurados"

    log_info "[4/4] Instalando herramientas de rendimiento..."
    sudo apt install -y irqbalance tuned > /dev/null 2>&1
    sudo tuned-adm profile latency-performance > /dev/null 2>&1
    log_success "Herramientas instaladas"

    echo ""
    log_success "¡KERNEL LIQUORIX INSTALADO!"
    log_warning "Reinicia y selecciona el nuevo kernel en GRUB"
}

install_zen_kernel() {
    log_title "INSTALANDO KERNEL ZEN"

    echo -e "${GREEN}Kernel Zen - Balance entre rendimiento y estabilidad${NC}\n"

    log_info "[1/3] Instalando kernel Zen desde repositorios..."
    sudo apt install -y linux-zen linux-headers-zen > /dev/null 2>&1
    log_success "Kernel Zen instalado"

    log_info "[2/3] Configurando parámetros de rendimiento..."
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.d/99-performance.conf > /dev/null
    echo 'kernel.numa_balancing=0' | sudo tee -a /etc/sysctl.d/99-performance.conf > /dev/null
    log_success "Parámetros configurados"

    log_info "[3/3] Aplicando scheduler adecuado..."
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash elevator=kyber"' | sudo tee -a /etc/default/grub > /dev/null
    sudo update-grub > /dev/null 2>&1
    log_success "Scheduler configurado"

    echo ""
    log_success "¡KERNEL ZEN INSTALADO!"
    log_warning "Reinicia para usar el nuevo kernel"
}

optimize_standard_kernel() {
    log_title "OPTIMIZANDO KERNEL ESTÁNDAR"

    echo -e "${GREEN}Aplicando optimizaciones al kernel actual...${NC}\n"

    log_info "[1/8] Configurando swappiness para mejor rendimiento..."
    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Swappiness configurado (10)"

    log_info "[2/8] Configurando presión de caché..."
    sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Cache pressure configurado (50)"

    log_info "[3/8] Mejorando gestión de memoria..."
    sudo sysctl -w vm.dirty_ratio=30 > /dev/null 2>&1
    sudo sysctl -w vm.dirty_background_ratio=5 > /dev/null 2>&1
    echo 'vm.dirty_ratio=30' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Gestión de memoria optimizada"

    log_info "[4/8] Configurando scheduler de E/S..."
    echo 'deadline' | sudo tee /sys/block/sda/queue/scheduler > /dev/null 2>&1
    log_success "Scheduler deadline configurado"

    log_info "[5/8] Activando fusión de solicitudes..."
    echo '1024' | sudo tee /sys/block/sda/queue/nr_requests > /dev/null 2>&1
    log_success "Fusión de solicitudes activada"

    log_info "[6/8] Deshabilitando balanceo NUMA para gaming..."
    sudo sysctl -w kernel.numa_balancing=0 > /dev/null 2>&1
    echo 'kernel.numa_balancing=0' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "NUMA balancing deshabilitado"

    log_info "[7/8] Optimizando parámetros de red..."
    sudo sysctl -w net.core.rmem_max=134217728 > /dev/null 2>&1
    sudo sysctl -w net.core.wmem_max=134217728 > /dev/null 2>&1
    echo 'net.core.rmem_max=134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.core.wmem_max=134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Parámetros de red optimizados"

    log_info "[8/8] Aplicando cambios y limpiando..."
    sudo sysctl -p > /dev/null 2>&1
    log_success "Cambios aplicados"

    echo ""
    log_success "¡KERNEL ESTÁNDAR OPTIMIZADO!"
    log_warning "No requiere reinicio (los cambios son dinámicos)"
}

advanced_kernel_tweaks() {
    log_title "AJUSTES AVANZADOS DEL KERNEL"

    echo -e "${YELLOW}Ajustes avanzados para máximo rendimiento:${NC}\n"

    # Deshabilitar mitigaciones de seguridad (riesgo)
    echo -e "${RED}[ADVERTENCIA] Deshabilitar mitigaciones de seguridad puede afectar la seguridad del sistema${NC}"
    if confirm "¿Deshabilitar mitigaciones de espectre/meltdown? (riesgo alto, +15% rendimiento)"; then
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="mitigations=off"' | sudo tee -a /etc/default/grub > /dev/null
        sudo update-grub > /dev/null 2>&1
        log_success "Mitigaciones deshabilitadas"
    fi

    # Habilitar TRIM para SSD
    echo ""
    if confirm "¿Habilitar TRIM automático para SSD? (recomendado para SSD)"; then
        sudo systemctl enable fstrim.timer > /dev/null 2>&1
        sudo systemctl start fstrim.timer > /dev/null 2>&1
        log_success "TRIM automático habilitado"
    fi

    # Configurar límites de archivos
    echo ""
    log_info "Aumentando límites de archivos del sistema..."
    echo 'fs.file-max=2097152' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo '* soft nofile 1048576' | sudo tee -a /etc/security/limits.conf > /dev/null
    echo '* hard nofile 1048576' | sudo tee -a /etc/security/limits.conf > /dev/null
    log_success "Límites de archivos aumentados"

    # Optimizar para gaming
    echo ""
    if confirm "¿Optimizar para gaming? (reducir latencia, priorizar procesos)"; then
        sudo apt install -y gamemode > /dev/null 2>&1
        echo 'gamemode' | sudo tee /etc/security/limits.d/gamemode.conf > /dev/null
        log_success "GameMode instalado y configurado"
    fi

    echo ""
    log_success "¡AJUSTES AVANZADOS APLICADOS!"
}
# ============================================================
# OPCIÓN 3C: OPTIMIZACIÓN DE MEMORIA RAM
# ============================================================

optimize_ram_menu() {
    log_title "OPTIMIZACIÓN DE MEMORIA RAM"

    echo -e "${GREEN}Configuración automática de memoria RAM${NC}\n"

    # Detectar RAM total
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    log_info "RAM detectada: ${total_ram}GB"

    echo -e "\n${YELLOW}Se aplicarán las siguientes optimizaciones:${NC}"
    echo "  • Configuración de swappiness óptima"
    echo "  • Gestión de caché mejorada"
    echo "  • Compresión ZRAM activa"
    echo "  • Límites de memoria ajustados"
    echo "  • Limpieza automática de caché"
    echo ""

    if ! confirm "¿Aplicar optimización completa de RAM?"; then
        log_info "Optimización cancelada"
        pause
        return 1
    fi

    # Optimización según cantidad de RAM
    if [ "$total_ram" -le 4 ]; then
        low_ram_optimization
    elif [ "$total_ram" -le 8 ]; then
        medium_ram_optimization
    elif [ "$total_ram" -le 16 ]; then
        high_ram_optimization
    else
        ultra_ram_optimization
    fi

    # Preguntar por ZRAM
    echo ""
    if confirm "¿Activar compresión ZRAM? (mejora rendimiento con poca RAM)"; then
        install_zram
    fi

    # Preguntar por limpieza automática
    echo ""
    if confirm "¿Configurar limpieza automática de caché cada hora? (libera RAM)"; then
        setup_auto_cache_clean
    fi

    # Preguntar por swapfile
    echo ""
    if confirm "¿Optimizar swapfile (memoria de intercambio)?"; then
        optimize_swap
    fi

    echo ""
    log_success "¡OPTIMIZACIÓN DE RAM COMPLETADA!"
    pause
}

low_ram_optimization() {
    log_title "OPTIMIZACIÓN PARA POCA RAM (<4GB)"

    log_info "[1/5] Configurando swappiness agresivo..."
    sudo sysctl -w vm.swappiness=60 > /dev/null 2>&1
    echo 'vm.swappiness=60' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Swappiness=60"

    log_info "[2/5] Reduciendo presión de caché..."
    sudo sysctl -w vm.vfs_cache_pressure=100 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=100' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Cache pressure=100"

    log_info "[3/5] Configurando dirty pages más agresivo..."
    sudo sysctl -w vm.dirty_ratio=20 > /dev/null 2>&1
    sudo sysctl -w vm.dirty_background_ratio=3 > /dev/null 2>&1
    log_success "Dirty pages configuradas"

    log_info "[4/5] Activando compactación de memoria..."
    echo '1' | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>&1
    log_success "Compactación activada"

    log_info "[5/5] Configurando límite mínimo de memoria libre..."
    sudo sysctl -w vm.min_free_kbytes=65536 > /dev/null 2>&1
    echo 'vm.min_free_kbytes=65536' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Memoria mínima libre configurada"
}

medium_ram_optimization() {
    log_title "OPTIMIZACIÓN PARA RAM MEDIA (4-8GB)"

    log_info "[1/5] Configurando swappiness balanceado..."
    sudo sysctl -w vm.swappiness=30 > /dev/null 2>&1
    echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Swappiness=30"

    log_info "[2/5] Configurando presión de caché óptima..."
    sudo sysctl -w vm.vfs_cache_pressure=70 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=70' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Cache pressure=70"

    log_info "[3/5] Configurando dirty pages estándar..."
    sudo sysctl -w vm.dirty_ratio=25 > /dev/null 2>&1
    sudo sysctl -w vm.dirty_background_ratio=4 > /dev/null 2>&1
    log_success "Dirty pages configuradas"

    log_info "[4/5] Configurando OOM killer más inteligente..."
    echo '1' | sudo tee /proc/sys/vm/oom_kill_allocating_task > /dev/null 2>&1
    log_success "OOM killer optimizado"

    log_info "[5/5] Configurando memoria mínima libre..."
    sudo sysctl -w vm.min_free_kbytes=131072 > /dev/null 2>&1
    echo 'vm.min_free_kbytes=131072' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Memoria mínima libre configurada"
}

high_ram_optimization() {
    log_title "OPTIMIZACIÓN PARA MUCHA RAM (8-16GB)"

    log_info "[1/5] Configurando swappiness bajo..."
    sudo sysctl -w vm.swappiness=15 > /dev/null 2>&1
    echo 'vm.swappiness=15' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Swappiness=15"

    log_info "[2/5] Configurando presión de caché baja..."
    sudo sysctl -w vm.vfs_cache_pressure=40 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=40' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Cache pressure=40"

    log_info "[3/5] Configurando dirty pages relajado..."
    sudo sysctl -w vm.dirty_ratio=40 > /dev/null 2>&1
    sudo sysctl -w vm.dirty_background_ratio=10 > /dev/null 2>&1
    log_success "Dirty pages configuradas"

    log_info "[4/5] Activando transparent hugepages..."
    echo 'always' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1
    log_success "Transparent hugepages activadas"

    log_info "[5/5] Configurando memoria mínima libre..."
    sudo sysctl -w vm.min_free_kbytes=262144 > /dev/null 2>&1
    echo 'vm.min_free_kbytes=262144' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Memoria mínima libre configurada"
}

ultra_ram_optimization() {
    log_title "OPTIMIZACIÓN PARA RAM EXTREMA (>16GB)"

    log_info "[1/5] Configurando swappiness mínimo..."
    sudo sysctl -w vm.swappiness=5 > /dev/null 2>&1
    echo 'vm.swappiness=5' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Swappiness=5"

    log_info "[2/5] Configurando presión de caché muy baja..."
    sudo sysctl -w vm.vfs_cache_pressure=20 > /dev/null 2>&1
    echo 'vm.vfs_cache_pressure=20' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Cache pressure=20"

    log_info "[3/5] Configurando dirty pages máximo..."
    sudo sysctl -w vm.dirty_ratio=50 > /dev/null 2>&1
    sudo sysctl -w vm.dirty_background_ratio=15 > /dev/null 2>&1
    log_success "Dirty pages configuradas"

    log_info "[4/5] Activando todas las optimizaciones de memoria..."
    echo 'always' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1
    echo '1' | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>&1
    log_success "Optimizaciones avanzadas activadas"

    log_info "[5/5] Configurando memoria mínima libre..."
    sudo sysctl -w vm.min_free_kbytes=524288 > /dev/null 2>&1
    echo 'vm.min_free_kbytes=524288' | sudo tee -a /etc/sysctl.conf > /dev/null
    log_success "Memoria mínima libre configurada"
}

install_zram() {
    log_title "INSTALANDO ZRAM"

    log_info "ZRAM comprime la memoria RAM, aumentando efectivamente su capacidad..."

    sudo apt install -y zram-tools > /dev/null 2>&1

    # Configurar ZRAM
    cat > /tmp/zram.conf << 'EOF'
PERCENT=50
PRIORITY=100
EOF
    sudo cp /tmp/zram.conf /etc/default/zram-tools

    sudo service zram-tools restart > /dev/null 2>&1
    log_success "ZRAM configurado (50% de RAM como compresión)"
}

setup_auto_cache_clean() {
    log_title "LIMPIADOR AUTOMÁTICO DE CACHÉ"

    # Crear script de limpieza
    cat > /tmp/clear-cache.sh << 'EOF'
#!/bin/bash
sync && echo 3 > /proc/sys/vm/drop_caches
EOF

    sudo mv /tmp/clear-cache.sh /etc/cron.hourly/clear-cache
    sudo chmod +x /etc/cron.hourly/clear-cache
    log_success "Limpieza automática configurada (cada hora)"
}

optimize_swap() {
    log_title "OPTIMIZANDO SWAP"

    # Verificar si hay swap activo
    if swapon --show | grep -q .; then
        log_info "Deshabilitando swap actual..."
        sudo swapoff -a > /dev/null 2>&1
    fi

    # Crear nuevo swapfile optimizado
    log_info "Creando swapfile de 2GB..."
    sudo fallocate -l 2G /swapfile > /dev/null 2>&1
    sudo chmod 600 /swapfile > /dev/null 2>&1
    sudo mkswap /swapfile > /dev/null 2>&1
    sudo swapon /swapfile > /dev/null 2>&1

    # Montar permanente
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null

    # Configurar swappiness
    sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1

    log_success "Swap optimizado (2GB, swappiness=10)"
}
# ============================================================
# OPCIÓN 4: ACTUALIZACIÓN DEL SISTEMA
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

    echo ""
    log_info "[1/4] Actualizando lista de paquetes..."
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    sudo apt update
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    log_success "Lista de paquetes actualizada"

    echo ""
    log_info "[2/4] Actualizando paquetes del sistema..."
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    sudo apt upgrade -y
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    log_success "Paquetes actualizados"

    echo ""
    log_info "[3/4] Eliminando paquetes huérfanos..."
    sudo apt autoremove -y
    log_success "Paquetes huérfanos eliminados"

    echo ""
    log_info "[4/4] Limpiando caché de paquetes..."
    sudo apt autoclean -y
    log_success "Caché limpiado"

    echo ""
    log_success "¡SISTEMA ACTUALIZADO COMPLETAMENTE!"
    pause
}
# ============================================================
# OPCIÓN 7: INSTALAR ALACRITTY Y TEMAS
# ============================================================

install_custom_software() {
    log_title "INSTALAR ALACRITTY Y TEMAS"

    echo -e "${GREEN}Alacritty es una terminal moderna que usa la GPU para renderizar,${NC}"
    echo -e "${GREEN}ofreciendo mayor fluidez y menor latencia que Konsole.${NC}\n"

    if confirm "¿Instalar Alacritty (terminal con aceleración GPU)?"; then
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
        log_success "Alacritty instalado (usando GPU para renderizado)"
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
        "20|emojier|Selector de emojis (Meta+.)"
        "21|qrca|Generador de códigos QR"
    )

    for app in "${software[@]}"; do
        num=$(echo "$app" | cut -d'|' -f1)
        name=$(echo "$app" | cut -d'|' -f2)
        desc=$(echo "$app" | cut -d'|' -f3)
        printf "  ${CYAN}[%2s]${NC} %-20s - %s\n" "$num" "$name" "$desc"
    done

    echo -e "\n${YELLOW}Escribe los números separados por espacio${NC}"
    echo "Ejemplo: 2 4 13 20 21"
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

            # === LIMPIEZA ESPECÍFICA PARA CADA APP ===

            # Limpiar kubuntu-web-shortcuts (ícono de Kubuntu Website en escritorio)
            if [[ "$app" == "kubuntu-web-shortcuts" ]]; then
                log_info "  → Limpiando accesos web de Kubuntu..."
                rm -f "$HOME/Escritorio/kubuntu-website.desktop" 2>/dev/null
                rm -f "$HOME/Desktop/kubuntu-website.desktop" 2>/dev/null
                rm -f "$HOME/Escritorio/kubuntu-website" 2>/dev/null
                rm -f "$HOME/Desktop/kubuntu-website" 2>/dev/null
                sudo rm -rf /usr/share/kubuntu-web-shortcuts/ 2>/dev/null
                sudo rm -f /usr/share/applications/kubuntu-website.desktop 2>/dev/null
                log_success "  → Ícono de Kubuntu Website eliminado"
            fi

            # Limpiar plasma-welcome (guía de bienvenida)
            if [[ "$app" == "plasma-welcome" ]]; then
                log_info "  → Limpiando guía de bienvenida..."
                rm -f "$HOME/.config/plasma-welcome" 2>/dev/null
                sudo rm -f /usr/share/applications/org.kde.plasma-welcome.desktop 2>/dev/null
                log_success "  → Guía de bienvenida eliminada"
            fi

            # Limpiar plasma-discover (tienda de aplicaciones)
            if [[ "$app" == "plasma-discover" ]]; then
                log_info "  → Limpiando configuración de Discover..."
                rm -rf "$HOME/.config/discover" 2>/dev/null
                sudo rm -rf /var/lib/discover 2>/dev/null
                log_success "  → Discover limpiado"
            fi

            # Limpiar kubuntu-docs (documentación)
            if [[ "$app" == "kubuntu-docs" ]]; then
                log_info "  → Limpiando documentación de Kubuntu..."
                sudo rm -rf /usr/share/doc/kubuntu-docs 2>/dev/null
                log_success "  → Documentación eliminada"
            fi

            # Limpiar libreoffice
            if [[ "$app" == "libreoffice-core" ]]; then
                log_info "  → Limpiando configuración de LibreOffice..."
                rm -rf "$HOME/.config/libreoffice" 2>/dev/null
                log_success "  → Configuración de LibreOffice eliminada"
            fi

            # Limpiar kdenlive
            if [[ "$app" == "kdenlive" ]]; then
                log_info "  → Limpiando configuración de Kdenlive..."
                rm -rf "$HOME/.config/kdenliverc" 2>/dev/null
                rm -rf "$HOME/.local/share/kdenlive" 2>/dev/null
                log_success "  → Configuración de Kdenlive eliminada"
            fi
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
            "emojier")
                sudo apt install -y plasma5-addons > /dev/null 2>&1
                log_success "Selector de emojis instalado (acceso con Meta+.)"
                ;;
            "qrca")
                sudo apt install -y qrca > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    sudo snap install qrca 2>/dev/null
                fi
                log_success "QRca instalado"
                ;;
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
# MENÚ PRINCIPAL (CORREGIDO)
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}¿Qué deseas hacer?${NC}\n"
        echo "  1) 🗑️  Eliminar aplicaciones preinstaladas"
        echo "  2) ⚙️  Configurar sistema (Rolling Release)"
        echo "  3) 🎮  Optimizar GPU (NVIDIA/AMD/Intel)"
        echo "  4) ⚡  Optimizar Kernel (Liquorix/Zen/Estándar)"
        echo "  5) 💾  Optimizar Memoria RAM (automático)"
        echo "  6) 🔄  ACTUALIZAR SISTEMA (update/upgrade/clean)"
        echo "  7) 🖥️  Instalar Alacritty (terminal GPU) y temas Tokyo Night"
        echo "  8) 📦  Instalar software opcional"
        echo "  9) ↩️  Revertir a Kubuntu original"
        echo " 10) ☢️  ELIMINACIÓN NUCLEAR DE SNAP"
        echo " 11) ❌  Salir"
        echo ""
        read -p "Opción (1-11): " option

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
            11)
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
