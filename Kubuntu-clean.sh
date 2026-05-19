main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}¿Qué deseas hacer?${NC}\n"
        echo "  1) 🗑️  Eliminar aplicaciones preinstaladas"
        echo "  2) ⚙️  Configurar sistema (Rolling Release)"
        echo "  3) 🚀  Optimizaciones de rendimiento (GPU, Kernel)"
        echo "  4) 🎨  Instalar Alacritty y temas"
        echo "  5) 📦  Instalar software opcional"
        echo "  6) 🔧  Aplicar TODOS los cambios"
        echo "  7) ↩️  Revertir a Kubuntu original"
        echo "  8) ☢️  ELIMINACIÓN NUCLEAR DE SNAP (sin rastro)"
        echo "  9) ❌  Salir"
        echo ""
        read -p "Opción (1-9): " option
        
        case $option in
            1) select_apps_to_remove ;;
            2) configure_system ;;
            3) optimize_performance ;;
            4) install_custom_software ;;
            5) select_optional_software ;;
            6) apply_all_changes ;;
            7) revert_changes ;;
            8) nuclear_snap_removal ;;
            9) 
                log_success "¡Hasta luego!"
                exit 0
                ;;
            *) 
                log_error "Opción inválida"
                pause
                ;;
        esac
        
        if [[ "$option" != "6" && "$option" != "7" && "$option" != "8" && "$option" != "9" ]]; then
            pause
        fi
    done
}
