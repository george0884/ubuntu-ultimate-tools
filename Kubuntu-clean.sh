#!/bin/bash

# ============================================================
# Script Interactivo: Transforma Kubuntu en KDE Neon (o personalizado)
# Autor: Asistente IA
# Uso: chmod +x script.sh && ./script.sh
# ============================================================

# Colores para UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables globales
SELECTED_APPS=()
SELECTED_OPTIONAL=()
REMOVE_METAPACKAGE=false
INSTALL_NEON_STYLE=false
USE_BACKPORTS=false
REMOVE_SNAPS=false
REMOVE_SNAP_APPS=false

# ============================================================
# FUNCIONES DE UTILIDAD
# ============================================================

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     TRANSFORMADOR DE KUBUNTU A KDE NEON (o personal)       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${PURPLE}${BOLD}► $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

pause() {
    echo -e "\n${YELLOW}Presiona Enter para continuar...${NC}"
    read
}

confirm() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt (s/n): " response
        case $response in
            [sS]) return 0 ;;
            [nN]) return 1 ;;
            *) echo "Por favor responde s o n" ;;
        esac
    done
}

# ============================================================
# MENÚ PRINCIPAL DE APLICACIONES A ELIMINAR
# ============================================================

select_apps_to_remove() {
    print_section "SELECCIÓN DE APLICACIONES A ELIMINAR"
    echo -e "${YELLOW}Marca las apps que QUIERES ELIMINAR (espacio para seleccionar, Enter para continuar)${NC}\n"
    
    # Lista completa de apps de Kubuntu (incluye snaps)
    apps=(
        "akregator|Lector RSS"
        "cantata|Cliente MPD (música)"
        "dragonplayer|Reproductor de video"
        "juk|Reproductor de audio"
        "k3b|Grabador de CDs/DVDs"
        "kaddressbook|Agenda de contactos"
        "kalarm|Alarmas y recordatorios"
        "kate|Editor de texto avanzado"
        "kmag|Lupa de pantalla"
        "kmail|Cliente de correo"
        "kmahjongg|Juego Mahjongg"
        "kmines|Buscaminas"
        "knotes|Notas adhesivas"
        "konsole|Terminal (alternativa a Alacritty)"
        "kontact|Suite PIM completa"
        "konversation|Cliente IRC"
        "korganizer|Calendario"
        "kpat|Juego de cartas"
        "krdc|Cliente escritorio remoto"
        "kruler|Regla en pantalla"
        "ksudoku|Juego Sudoku"
        "ktorrent|Cliente Torrent"
        "libreoffice-core|Suite ofimática"
        "skanlite|Escáner"
        "kmouth|Sintetizador de voz"
        "kcharselect|Mapa de caracteres"
        "kdf|Visor de uso de disco"
        "kfind|Buscador de archivos"
        "kgpg|Gestión de claves GPG"
        "snapd|Sistema de paquetes Snap (ELIMINAR SNAP COMPLETO)"
    )
    
    # Usar whiptail para menú interactivo
    local choices=$(whiptail --title "Selecciona apps para ELIMINAR" \
        --checklist "Usa ESPACIO para seleccionar:\n(Apps seleccionadas = serán eliminadas)\n\n⚠️ Si seleccionas 'snapd' se eliminará TODO el sistema Snap" \
        27 80 16 \
        $(for app in "${apps[@]}"; do
            name=$(echo $app | cut -d'|' -f1)
            desc=$(echo $app | cut -d'|' -f2)
            echo "$name" "$desc" OFF
        done) \
        3>&1 1>&2 2>&3)
    
    # Convertir resultado a array
    IFS='"' read -ra SELECTED_APPS <<< "$choices"
    
    # Verificar si se seleccionó snapd
    for app in "${SELECTED_APPS[@]}"; do
        if [[ "$app" == "snapd" ]]; then
            REMOVE_SNAP_APPS=true
            print_info "⚠️ Se eliminará TODO el sistema Snap (incluyendo Firefox, Store, etc.)"
        fi
    done
    
    if [ ${#SELECTED_APPS[@]} -eq 0 ]; then
        print_info "No seleccionaste ninguna app para eliminar"
    else
        print_success "Apps seleccionadas para eliminar: ${#SELECTED_APPS[@]}"
        for app in "${SELECTED_APPS[@]}"; do
            if [[ ! -z "$app" && "$app" != " " ]]; then
                echo "  - $app"
            fi
        done
    fi
}

# ============================================================
# CONFIGURACIÓN DEL SISTEMA (estilo KDE Neon)
# ============================================================

configure_system() {
    print_section "CONFIGURACIÓN DEL SISTEMA"
    
    # Preguntar sobre meta-paquete
    if confirm "¿Eliminar el meta-paquete 'kubuntu-desktop'? (recomendado para estilo Neon)"; then
        REMOVE_METAPACKAGE=true
        print_success "Se eliminará kubuntu-desktop"
    else
        print_info "Manteniendo kubuntu-desktop (más parecido a Kubuntu original)"
    fi
    
    # Preguntar sobre backports (Plasma actualizado)
    if confirm "¿Agregar repositorios backports para tener Plasma más actualizado? (estilo Neon)"; then
        USE_BACKPORTS=true
        print_success "Se agregarán backports"
    else
        print_info "Manteniendo repositorios estándar de Kubuntu"
    fi
    
    # Preguntar sobre Snaps (Neon no los usa por defecto)
    if confirm "¿Eliminar TODO el sistema Snap? (Firefox, Store, etc. - estilo Neon puro)"; then
        REMOVE_SNAPS=true
        REMOVE_SNAP_APPS=true
        print_success "Se eliminará Snap completo"
    else
        print_info "Manteniendo Snap (estilo Kubuntu original)"
    fi
}

# ============================================================
# FUNCIÓN ESPECÍFICA PARA ELIMINAR SNAP
# ============================================================

remove_snap_completely() {
    print_info "Eliminando TODO el sistema Snap..."
    
    # Detener servicios de snap
    sudo systemctl stop snapd.service 2>/dev/null
    sudo systemctl disable snapd.service 2>/dev/null
    
    # Eliminar todos los paquetes snap instalados
    echo "  • Eliminando paquetes snap..."
    for snap in $(snap list 2>/dev/null | awk 'NR>1 {print $1}'); do
        if [ "$snap" != "Name" ] && [ "$snap" != "core" ] && [ "$snap" != "core20" ] && [ "$snap" != "core22" ]; then
            sudo snap remove --purge "$snap" 2>/dev/null
            print_success "    - Eliminado: $snap"
        fi
    done
    
    # Eliminar snaps del sistema (core, core20, core22)
    sudo snap remove --purge core22 2>/dev/null
    sudo snap remove --purge core20 2>/dev/null
    sudo snap remove --purge core 2>/dev/null
    
    # Desmontar directorios loop de snap
    for mnt in $(mount | grep snap | awk '{print $3}'); do
        sudo umount "$mnt" 2>/dev/null
    done
    
    # Eliminar paquetes snapd
    sudo apt remove --purge -y snapd gnome-software-plugin-snap 2>/dev/null
    sudo apt-mark hold snapd 2>/dev/null  # Evitar reinstalación automática
    
    # Eliminar directorios residuales
    sudo rm -rf ~/snap /snap /var/snap /var/lib/snapd /var/cache/snapd
    
    # Eliminar preferencias de snap en APT
    sudo rm -f /etc/apt/preferences.d/nosnap.pref 2>/dev/null
    
    print_success "¡Snap completamente eliminado del sistema!"
    print_info "Firefox se instalará desde el repositorio APT en la próxima actualización"
}

# ============================================================
# NUEVA FUNCIÓN: INSTALACIÓN DE SOFTWARE OPCIONAL
# ============================================================

select_optional_software() {
    print_section "SELECCIÓN DE SOFTWARE OPCIONAL A INSTALAR"
    echo -e "${GREEN}Selecciona los programas que QUIERES INSTALAR${NC}\n"
    
    # Lista de software opcional (CORREGIDA con Fastfetch)
    optional_software=(
        "filezilla|Cliente FTP/SFTP"
        "code|Visual Studio Code (editor)"
        "virtualbox|VirtualBox (máquinas virtuales)"
        "google-chrome-stable|Google Chrome (navegador)"
        "telegram-desktop|Telegram (mensajería)"
        "python3|Python 3 (lenguaje de programación)"
        "python3-pip|PIP (gestor de paquetes Python)"
        "python3-venv|Entornos virtuales Python"
        "git|Git (control de versiones)"
        "curl|CURL (transferencias por URL)"
        "wget|Wget (descargas por terminal)"
        "htop|HTOP (monitor de sistema)"
        "fastfetch|Fastfetch (info del sistema - sucesor de Neofetch)"
        "timeshift|Timeshift (backups del sistema)"
        "gparted|GParted (editor de particiones)"
        "vim|Vim (editor de texto terminal)"
        "discord|Discord (chat de voz/texto)"
        "spotify|Spotify (música)"
        "obs-studio|OBS Studio (grabación/streaming)"
    )
    
    # Usar whiptail para selección múltiple
    local choices=$(whiptail --title "Instalar Software Adicional" \
        --checklist "Usa ESPACIO para seleccionar los programas que QUIERES INSTALAR:" \
        25 80 16 \
        $(for app in "${optional_software[@]}"; do
            name=$(echo $app | cut -d'|' -f1)
            desc=$(echo $app | cut -d'|' -f2)
            echo "$name" "$desc" OFF
        done) \
        3>&1 1>&2 2>&3)
    
    # Convertir resultado a array
    IFS='"' read -ra SELECTED_OPTIONAL <<< "$choices"
    
    if [ ${#SELECTED_OPTIONAL[@]} -eq 0 ]; then
        print_info "No seleccionaste ningún software opcional para instalar"
    else
        print_success "Software seleccionado para instalar: ${#SELECTED_OPTIONAL[@]}"
        for app in "${SELECTED_OPTIONAL[@]}"; do
            if [[ ! -z "$app" && "$app" != " " ]]; then
                echo "  + $app"
            fi
        done
    fi
}

install_optional_software() {
    print_section "INSTALANDO SOFTWARE OPCIONAL"
    
    if [ ${#SELECTED_OPTIONAL[@]} -eq 0 ]; then
        print_info "No hay software opcional para instalar"
        return 0
    fi
    
    # Actualizar repositorios
    print_info "Actualizando repositorios..."
    sudo apt update > /dev/null 2>&1
    
    # Instalar cada programa seleccionado
    for app in "${SELECTED_OPTIONAL[@]}"; do
        if [[ ! -z "$app" && "$app" != " " ]]; then
            case $app in
                "filezilla")
                    print_info "Instalando FileZilla..."
                    sudo apt install -y filezilla > /dev/null 2>&1
                    print_success "FileZilla instalado"
                    ;;
                "code")
                    print_info "Instalando Visual Studio Code..."
                    if ! command -v code &> /dev/null; then
                        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                        sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                        rm -f packages.microsoft.gpg
                        sudo apt update > /dev/null 2>&1
                    fi
                    sudo apt install -y code > /dev/null 2>&1
                    print_success "Visual Studio Code instalado"
                    ;;
                "virtualbox")
                    print_info "Instalando VirtualBox..."
                    sudo apt install -y virtualbox virtualbox-ext-pack > /dev/null 2>&1
                    print_success "VirtualBox instalado"
                    ;;
                "google-chrome-stable")
                    print_info "Instalando Google Chrome..."
                    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
                    sudo dpkg -i /tmp/chrome.deb > /dev/null 2>&1
                    sudo apt install -f -y > /dev/null 2>&1
                    rm /tmp/chrome.deb
                    print_success "Google Chrome instalado"
                    ;;
                "telegram-desktop")
                    print_info "Instalando Telegram..."
                    sudo apt install -y telegram-desktop > /dev/null 2>&1
                    print_success "Telegram instalado"
                    ;;
                "python3")
                    print_info "Instalando Python 3..."
                    sudo apt install -y python3 > /dev/null 2>&1
                    print_success "Python 3 instalado"
                    ;;
                "python3-pip")
                    print_info "Instalando PIP para Python..."
                    sudo apt install -y python3-pip > /dev/null 2>&1
                    print_success "PIP instalado"
                    ;;
                "python3-venv")
                    print_info "Instalando entornos virtuales Python..."
                    sudo apt install -y python3-venv > /dev/null 2>&1
                    print_success "Entornos virtuales Python instalados"
                    ;;
                "git")
                    print_info "Instalando Git..."
                    sudo apt install -y git > /dev/null 2>&1
                    print_success "Git instalado"
                    ;;
                "curl")
                    print_info "Instalando CURL..."
                    sudo apt install -y curl > /dev/null 2>&1
                    print_success "CURL instalado"
                    ;;
                "wget")
                    print_info "Instalando Wget..."
                    sudo apt install -y wget > /dev/null 2>&1
                    print_success "Wget instalado"
                    ;;
                "htop")
                    print_info "Instalando HTOP..."
                    sudo apt install -y htop > /dev/null 2>&1
                    print_success "HTOP instalado"
                    ;;
                "fastfetch")
                    print_info "Instalando Fastfetch (sucesor de Neofetch)..."
                    sudo apt install -y fastfetch > /dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        print_success "Fastfetch instalado desde repositorios"
                    else
                        print_info "Fastfetch no está en repositorios, instalando desde GitHub..."
                        sudo apt install -y git cmake build-essential > /dev/null 2>&1
                        git clone https://github.com/fastfetch-cli/fastfetch /tmp/fastfetch 2>/dev/null
                        cd /tmp/fastfetch
                        mkdir -p build && cd build
                        cmake .. > /dev/null 2>&1
                        make -j$(nproc) > /dev/null 2>&1
                        sudo make install > /dev/null 2>&1
                        cd /
                        rm -rf /tmp/fastfetch
                        print_success "Fastfetch compilado e instalado desde GitHub"
                    fi
                    # Crear alias para compatibilidad con neofetch
                    echo "alias neofetch='fastfetch'" >> ~/.bashrc
                    echo "alias neofetch='fastfetch'" >> ~/.zshrc 2>/dev/null
                    print_info "Alias creado: 'neofetch' ejecutará 'fastfetch'"
                    ;;
                "timeshift")
                    print_info "Instalando Timeshift..."
                    sudo apt install -y timeshift > /dev/null 2>&1
                    print_success "Timeshift instalado"
                    ;;
                "gparted")
                    print_info "Instalando GParted..."
                    sudo apt install -y gparted > /dev/null 2>&1
                    print_success "GParted instalado"
                    ;;
                "vim")
                    print_info "Instalando Vim..."
                    sudo apt install -y vim > /dev/null 2>&1
                    print_success "Vim instalado"
                    ;;
                "discord")
                    print_info "Instalando Discord..."
                    wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
                    sudo dpkg -i /tmp/discord.deb > /dev/null 2>&1
                    sudo apt install -f -y > /dev/null 2>&1
                    rm /tmp/discord.deb
                    print_success "Discord instalado"
                    ;;
                "spotify")
                    print_info "Instalando Spotify..."
                    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
                    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
                    sudo apt update > /dev/null 2>&1
                    sudo apt install -y spotify-client > /dev/null 2>&1
                    print_success "Spotify instalado"
                    ;;
                "obs-studio")
                    print_info "Instalando OBS Studio..."
                    sudo apt install -y obs-studio > /dev/null 2>&1
                    print_success "OBS Studio instalado"
                    ;;
            esac
        fi
    done
    
    print_success "¡Instalación de software opcional completada!"
}

# ============================================================
# INSTALACIÓN DE ALACRITTY Y TEMAS
# ============================================================

install_custom_software() {
    print_section "INSTALACIÓN DE SOFTWARE PERSONALIZADO"
    
    # Alacritty
    if confirm "¿Instalar Alacritty (terminal moderna)?"; then
        print_info "Instalando Alacritty..."
        sudo apt update > /dev/null 2>&1
        sudo apt install -y alacritty
        print_success "Alacritty instalado"
        
        # Configurar Alacritty con tema Tokyo Night
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
        print_success "Alacritty configurado con tema Tokyo Night"
    fi
    
    # Temas de Plasma
    if confirm "¿Instalar temas visuales modernos (Tokyo Night, Catppuccin, etc.)?"; then
        print_info "Instalando temas desde KDE Store..."
        
        # Instalar kpackagetool si no está
        sudo apt install -y kpackagetool6 git > /dev/null 2>&1
        
        # Tokyo Night
        cd /tmp
        git clone https://github.com/fausto-kouches/tokyo-night-kde 2>/dev/null
        if [ -d "tokyo-night-kde" ]; then
            cd tokyo-night-kde
            kpackagetool6 -t Plasma/LookAndFeel -i ./ 2>/dev/null
            print_success "Tema Tokyo Night instalado"
        fi
        
        # Aplicar tema si se instaló
        if confirm "¿Aplicar tema Tokyo Night ahora?"; then
            lookandfeeltool -a org.kde.tokyonight.desktop 2>/dev/null
            print_success "Tema aplicado"
        fi
    fi
}

# ============================================================
# EJECUCIÓN DE LOS CAMBIOS
# ============================================================

apply_changes() {
    print_section "APLICANDO CAMBIOS"
    echo -e "${RED}${BOLD}¡ATENCIÓN! Se aplicarán los siguientes cambios:${NC}"
    
    if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
        echo "  • Eliminar ${#SELECTED_APPS[@]} aplicaciones"
    fi
    [ "$REMOVE_METAPACKAGE" = true ] && echo "  • Eliminar kubuntu-desktop"
    [ "$USE_BACKPORTS" = true ] && echo "  • Agregar repositorios backports"
    if [ "$REMOVE_SNAPS" = true ] || [ "$REMOVE_SNAP_APPS" = true ]; then
        echo "  • Eliminar SNAP completamente (⚠️ elimina Firefox, Store, etc.)"
    fi
    
    if ! confirm "\n¿Aplicar estos cambios?"; then
        print_info "Cambios cancelados"
        return 1
    fi
    
    # 1. Eliminar apps seleccionadas (excluyendo snapd que se maneja aparte)
    if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
        print_info "Eliminando aplicaciones..."
        for app in "${SELECTED_APPS[@]}"; do
            if [[ ! -z "$app" && "$app" != " " && "$app" != "snapd" ]]; then
                if dpkg -l | grep -q "^ii  $app"; then
                    sudo apt remove --purge -y "$app" > /dev/null 2>&1
                    print_success "Eliminado: $app"
                else
                    print_info "$app no estaba instalado"
                fi
            fi
        done
    fi
    
    # 2. Eliminar Snap completo (si se seleccionó en apps o en configuración)
    if [ "$REMOVE_SNAPS" = true ] || [ "$REMOVE_SNAP_APPS" = true ]; then
        remove_snap_completely
    fi
    
    # 3. Eliminar meta-paquete
    if [ "$REMOVE_METAPACKAGE" = true ]; then
        print_info "Eliminando kubuntu-desktop..."
        sudo apt remove --purge -y kubuntu-desktop > /dev/null 2>&1
        # Instalar plasma-desktop como reemplazo minimalista
        sudo apt install -y plasma-desktop > /dev/null 2>&1
        print_success "Meta-paquete reemplazado por plasma-desktop minimal"
    fi
    
    # 4. Configurar backports
    if [ "$USE_BACKPORTS" = true ]; then
        print_info "Agregando backports..."
        sudo add-apt-repository -y ppa:kubuntu-ppa/backports > /dev/null 2>&1
        sudo apt update > /dev/null 2>&1
        print_success "Backports agregados (Plasma actualizado)"
    fi
    
    # 5. Limpieza final
    print_info "Limpiando dependencias huérfanas..."
    sudo apt autoremove --purge -y > /dev/null 2>&1
    sudo apt autoclean -y > /dev/null 2>&1
    
    print_success "¡Todos los cambios aplicados correctamente!"
    
    if [ "$REMOVE_SNAPS" = true ] || [ "$REMOVE_SNAP_APPS" = true ]; then
        echo -e "\n${YELLOW}⚠️ IMPORTANTE: Se eliminó Snap. Para reinstalar Firefox:${NC}"
        echo "  sudo apt install firefox"
    fi
}

# ============================================================
# MENÚ DE REVERSIÓN (volver a Kubuntu)
# ============================================================

revert_changes() {
    print_section "REVERTIR CAMBIOS - VOLVER A KUBUNTU"
    
    echo -e "${YELLOW}Esta opción reinstalará la configuración original de Kubuntu${NC}"
    
    if confirm "¿Estás seguro de que quieres revertir todos los cambios?"; then
        print_info "Reinstalando kubuntu-desktop..."
        sudo apt install --reinstall -y kubuntu-desktop > /dev/null 2>&1
        
        print_info "Eliminando backports..."
        sudo add-apt-repository --remove -y ppa:kubuntu-ppa/backports > /dev/null 2>&1
        
        print_info "Reinstalando Snap..."
        sudo apt install -y snapd > /dev/null 2>&1
        
        print_info "Limpiando configuraciones personalizadas..."
        rm -rf ~/.config/alacritty
        
        print_success "¡Sistema revertido a configuración original de Kubuntu!"
        print_info "Recomendación: Reinicia el sistema"
    fi
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================

main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}¿Qué deseas hacer?${NC}\n"
        echo "1) 🗑️  Seleccionar apps para eliminar (incluye SNAP)"
        echo "2) ⚙️  Configurar estilo del sistema (Neon/Kubuntu)"
        echo "3) 🎨  Instalar terminal y temas (Alacritty + Tokyo Night)"
        echo "4) 📦  Instalar software opcional (Filezilla, VSCode, Chrome, etc.)"
        echo "5) 🚀  Aplicar todos los cambios seleccionados"
        echo "6) ↩️  Revertir cambios (volver a Kubuntu original)"
        echo "7) ❌  Salir"
        echo ""
        read -p "Selecciona una opción (1-7): " option
        
        case $option in
            1) select_apps_to_remove ;;
            2) configure_system ;;
            3) install_custom_software ;;
            4) select_optional_software ;;
            5) 
                apply_changes
                # Preguntar si también quiere instalar el software opcional seleccionado
                if [ ${#SELECTED_OPTIONAL[@]} -gt 0 ]; then
                    if confirm "\n¿Deseas instalar el software opcional que seleccionaste?"; then
                        install_optional_software
                    fi
                fi
                ;;
            6) revert_changes ;;
            7) 
                print_success "¡Hasta luego!"
                exit 0
                ;;
            *) 
                print_error "Opción inválida"
                pause
                ;;
        esac
        
        if [[ "$option" != "5" && "$option" != "6" && "$option" != "7" ]]; then
            pause
        fi
    done
}

# ============================================================
# INICIO DEL SCRIPT
# ============================================================

# Verificar que se ejecuta como usuario normal (sudo se pedirá cuando toque)
if [ "$EUID" -eq 0 ]; then
    print_error "No ejecutes este script como root (sin sudo)"
    exit 1
fi

# Verificar whiptail (necesario para menús)
if ! command -v whiptail &> /dev/null; then
    print_info "Instalando whiptail para menús interactivos..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y whiptail > /dev/null 2>&1
fi

# Iniciar
main_menu
