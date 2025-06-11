# sysadmin-tools

Este repositorio es una colección de scripts y utilidades para asistir en tareas de administración de sistemas, principalmente en entornos Linux (Debian/Ubuntu). Son herramientas utilizadas por el equipo de Infraestructura/DevOps de Adhoc.

---

## Descripción General

Incluye:

- Scripts para mantenimiento, backup y restauración de notebooks.
- Instaladores automatizados para software común (AnyDesk, RStudio).
- Utilidades para gestión de swap y configuraciones del sistema.
- Un servidor PXE dockerizado usando iVentoy para booteo de imágenes por red.

---

## Herramientas y Scripts

### 1. Mantenimiento de Notebooks (`mantenimiento_notebooks.sh`)

Script integral para mantenimiento y actualización de notebooks Ubuntu/Debian.

**Características principales:**

- Actualiza repositorios y paquetes del sistema.
- Instala paquetes esenciales (`unattended-upgrades`, `screenfetch`, `dmidecode`, `cowsay`).
- Limpia caché de APT.
- Verifica y crea token de inscripción de Chrome si falta.
- Corrige permisos de `/tmp`.
- Actualiza Rancher CLI si está instalado.
- (Opcional) Limpieza de imágenes Docker.
- Crea alias `mantenimiento` para el usuario.
- Muestra información y evidencia de ejecución.

**Uso:**

```bash
sudo bash ./mantenimiento_notebooks.sh
```

---

### 2. Backup y Restauración de Notebooks (`adhoc_notebooks.sh`)

Asistente unificado para backup y restauración de datos/configuraciones de usuario, con interfaz gráfica (Zenity) o CLI.

**Características:**

- Permite seleccionar carpetas/archivos comunes y personalizados para backup.
- Genera un archivo comprimido `.tar.gz` con los datos seleccionados.
- Restaura backups guiando al usuario en pasos manuales (VSCode, Docker, Odoo, etc).
- Ajusta permisos de `.ssh` tras restaurar.

**Uso:**

```bash
bash ./adhoc_notebooks.sh
```

(No ejecutar como root.)

---

### 3. Instalador y Verificador de AnyDesk (`check_anydesk.sh`)

Verifica si AnyDesk está instalado; si no, lo instala desde el repositorio oficial y muestra el ID.

**Uso:**

```bash
bash ./check_anydesk.sh
```

---

### 4. Instalador de R y RStudio (`install_rstudio.sh`)

Automatiza la instalación de R y RStudio Desktop en Debian/Ubuntu.

**Uso:**

```bash
sudo bash ./install_rstudio.sh
```

---

### 5. Gestión de Swap (`adhoc_swap.sh`)

Script para crear o redimensionar `/swapfile` según configuración deseada.

**Características:**

- Tamaño configurable (por defecto 16G).
- Permite reemplazo si el swap existente es menor.
- Permite coexistencia con otras swaps.
- Hace persistente la configuración en `/etc/fstab`.

**Uso:**

```bash
sudo bash ./adhoc_swap.sh
```

---

### 6. Servidor PXE (iVentoy)

En la carpeta `pxe/` hay un setup para correr un servidor PXE iVentoy vía Docker.

**Pasos básicos:**

1. Colocar ISOs en `pxe/config/iso/`.
2. Levantar el servicio:

   ```bash
   cd pxe/
   docker-compose up -d
   ```

3. Acceder a la interfaz web en [http://127.0.0.1:26000](http://127.0.0.1:26000).

Más detalles y troubleshooting en [`pxe/README.md`](pxe/README.md).

---
