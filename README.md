
---

```markdown
<div align="center">
  
# 🚀 Kubuntu Transformer

### Transforma tu Kubuntu en un sistema minimalista estilo KDE Neon

[![Licencia](https://img.shields.io/badge/Licencia-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![KDE Plasma](https://img.shields.io/badge/KDE%20Plasma-6.0+-1D99F3?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)

</div>

---

## 📖 Descripción

**Kubuntu Transformer** es un script interactivo que te permite convertir tu instalación de Kubuntu en un sistema minimalista similar a **KDE Neon**. Con una interfaz de menús fácil de usar, puedes:

- 🗑️ **Eliminar** aplicaciones preinstaladas de Kubuntu
- ⚙️ **Configurar** el sistema al estilo Neon (backports, sin Snap)
- 🎨 **Instalar** terminal Alacritty y temas modernos (Tokyo Night)
- 📦 **Agregar** software opcional popular (VSCode, Chrome, Discord, etc.)
- ↩️ **Revertir** todos los cambios a la configuración original

> ⚠️ **Nota**: Este script está diseñado para **Kubuntu 22.04 LTS o superior**.

---

## ✨ Características

| Categoría | Funcionalidades |
|-----------|----------------|
| **Limpieza** | Eliminación selectiva de +25 apps preinstaladas (juegos, PIM, utilidades) |
| **Snap** | Eliminación completa del sistema Snap (estilo Neon puro) |
| **Backports** | Activación de repositorios para Plasma actualizado |
| **Terminal** | Instalación y configuración de Alacritty con tema Tokyo Night |
| **Temas** | Instalación de themes visuales modernos para KDE Plasma |
| **Software** | 19 programas opcionales listos para instalar con un clic |
| **Revertir** | Restauración completa al estado original de Kubuntu |

---

## 📋 Requisitos

- **Kubuntu** 22.04 LTS o superior
- Conexión a internet
- Usuario con privilegios `sudo`
- Terminal con soporte para menús `whiptail` (se instala automáticamente)

---

## 🔧 Instalación

### 1. Descargar el script

```bash
git clone https://github.com/tu-usuario/kubuntu-transformer.git
cd kubuntu-transformer
```

O directamente:

```bash
wget https://raw.githubusercontent.com/tu-usuario/kubuntu-transformer/main/transform.sh
```

2. Dar permisos de ejecución

```bash
chmod +x transform.sh
```

3. Ejecutar

```bash
./transform.sh
```

💡 No es necesario ejecutarlo como root. El script solicitará sudo cuando sea necesario.

---

🎮 Menú Principal

```
╔════════════════════════════════════════════════════════════╗
║     TRANSFORMADOR DE KUBUNTU A KDE NEON (o personal)       ║
╚════════════════════════════════════════════════════════════╝

1) 🗑️  Seleccionar apps para eliminar (incluye SNAP)
2) ⚙️  Configurar estilo del sistema (Neon/Kubuntu)
3) 🎨  Instalar terminal y temas (Alacritty + Tokyo Night)
4) 📦  Instalar software opcional
5) 🚀  Aplicar todos los cambios seleccionados
6) ↩️  Revertir cambios (volver a Kubuntu original)
7) ❌  Salir
```

---

📦 Software Opcional Disponible

Programa Descripción Tipo
FileZilla Cliente FTP/SFTP 🖥️ GUI
VS Code Editor de código 🖥️ GUI
VirtualBox Máquinas virtuales 🖥️ GUI
Google Chrome Navegador web 🖥️ GUI
Telegram Mensajería 🖥️ GUI
Discord Chat de voz/texto 🖥️ GUI
Spotify Música streaming 🖥️ GUI
OBS Studio Grabación/streaming 🖥️ GUI
Python 3 Lenguaje de programación ⌨️ CLI
PIP Gestor paquetes Python ⌨️ CLI
Git Control de versiones ⌨️ CLI
Fastfetch Info del sistema ⌨️ CLI
Timeshift Backups del sistema 🖥️ GUI
GParted Editor de particiones 🖥️ GUI
HTOP Monitor de sistema ⌨️ CLI
Vim Editor de texto ⌨️ CLI
Curl / Wget Transferencias ⌨️ CLI

---

🗑️ Aplicaciones que puedes eliminar

El script permite eliminar selectivamente:

Juegos: KMahjongg, KMines, KPat, KSudoku, KBreakout, KNetwalk
Multimedia: Dragon Player, Juk, K3b, KTorrent
PIM/Suite: KMail, Kontact, KOrganizer, KAddressBook, KAlarm
Utilidades: KWrite, Kate, KRuler, KMag, KCharSelect, KDF, KFind, KGpg
Internet: Akregator, Konversation, KRDC
Oficina: LibreOffice (completo)
Snap: Sistema completo de Snap (Firefox, Store, etc.)

---

🔄 Flujo de trabajo recomendado

```mermaid
graph LR
    A[Ejecutar script] --> B[Opción 1: Seleccionar apps a eliminar]
    B --> C[Opción 2: Configurar estilo Neon]
    C --> D[Opción 4: Elegir software opcional]
    D --> E[Opción 5: Aplicar cambios]
    E --> F[¡Sistema transformado!]
```

---

🛡️ Seguridad

· ✅ No destructivo: Todos los cambios son reversibles
· ✅ Confirmaciones: Cada acción crítica requiere confirmación
· ✅ Backports opcional: No se modifica el sistema si no deseas
· ✅ Revertir completo: Opción para volver a Kubuntu 100% original

---

📸 Capturas

Menú de selección de software opcional

```
┌─────────────────────┤ Instalar Software Adicional ├─────────────────────┐
│                                                                         │
│    Usa ESPACIO para seleccionar los programas que QUIERES INSTALAR:     │
│                                                                         │
│    (*) filezilla      Cliente FTP/SFTP                                  │
│    ( ) code           Visual Studio Code (editor)                       │
│    (*) virtualbox     VirtualBox (máquinas virtuales)                   │
│    ( ) google-chrome  Google Chrome (navegador)                         │
│    (*) fastfetch      Fastfetch (info del sistema)                      │
│                                                                         │
│    <OK>                              <Cancelar>                         │
└─────────────────────────────────────────────────────────────────────────┘
```

Terminal Alacritty con tema Tokyo Night

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  user@kubuntu:~$ fastfetch                                        │  │
│  │                                                                   │  │
│  │       .:///:-.                    user@kubuntu                    │  │
│  │     .:////////:-.                 OS: Kubuntu 24.04               │  │
│  │    -////////////////:.            Kernel: 6.8.0-xx               │  │
│  │   `:////////////////:.            Shell: bash 5.2.15              │  │
│  │    :+///////////////+`            DE: KDE Plasma 6.0.4            │  │
│  │   `-/+++++++++++++/.              Theme: Tokyo Night              │  │
│  │    `.-://///:-.`                  Terminal: Alacritty             │  │
│  │                                                                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

❓ Preguntas Frecuentes

¿Puedo usar esto en Ubuntu normal con KDE instalado manualmente?

No está recomendado. El script está diseñado específicamente para Kubuntu de fábrica.

¿Qué pasa si elimino Snap?

Firefox y la tienda Snap se eliminarán. Puedes reinstalar Firefox desde APT: sudo apt install firefox

¿Cómo vuelvo atrás?

Usa la Opción 6 del menú principal. Reinstalará kubuntu-desktop y restaurará Snap.

¿Necesito reinstalar después de ejecutar el script?

No es necesario, pero se recomienda reiniciar para aplicar todos los cambios correctamente.

---

🤝 Contribuciones

Las contribuciones son bienvenidas. Puedes:

1. Reportar errores en Issues
2. Sugerir nuevos programas para incluir en la lista opcional
3. Mejorar la documentación

---

📄 Licencia

Este proyecto está bajo la licencia MIT. Ver archivo LICENSE para más detalles.

---

<div align="center">

👤 Autor

Tu Nombre – @tu-usuario

</div>

---

<div align="center">

⭐ ¿Te fue útil este script? ¡Dale una estrella en GitHub!

</div>
```

---

📝 Instrucciones para personalizar el README

Antes de usar el README, cambia estos datos:

Campo Búscalo en el README Cámbialo por
tu-usuario https://github.com/tu-usuario/... Tu nombre de usuario de GitHub
Tu Nombre **Tu Nombre** Tu nombre real o alias
@tu-usuario @tu-usuario Tu usuario de GitHub

📁 Estructura de archivos recomendada

```
kubuntu-transformer/
├── transform.sh          # El script principal
├── README.md             # Este archivo
└── LICENSE               # Archivo MIT (opcional)
```
