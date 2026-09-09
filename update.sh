#!/bin/bash

#=========================================================
#        YAKU-MULTI-SCRIPT - UPDATER
#        Actualizador independiente sin sistema de licencias
#=========================================================

set -o pipefail

#=========================================================
# VARIABLES
#=========================================================

BASE="/etc/yaku-multi-script"
LEGACY_BASE="/etc/kevintech"
TMP="/tmp/yaku_multi_script_update"

# Migración segura desde instalaciones anteriores.
if [[ -e "$LEGACY_BASE" && ! -L "$LEGACY_BASE" && ! -e "$BASE" ]]; then
    info() { echo "[INFO] $*"; }
    info "Migrando instalación histórica a $BASE..."
    mv "$LEGACY_BASE" "$BASE" || { echo "❌ No se pudo migrar $LEGACY_BASE"; exit 1; }
elif [[ -e "$LEGACY_BASE" && ! -L "$LEGACY_BASE" && -e "$BASE" ]]; then
    echo "❌ Existen ambos directorios: $BASE y $LEGACY_BASE"
    echo "   Revisa la instalación manualmente antes de continuar."
    exit 1
fi

if [[ -d "$BASE" ]]; then
    ln -sfn "$BASE" "$LEGACY_BASE"
fi

REPO="https://github.com/YakuFw/Yaku-Multi-Script.git"

VERSION_FILE="$BASE/version.txt"


#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
BOLD="\e[1m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

GOLD="\e[38;5;220m"
SKY="\e[38;5;117m"
PURPLE="\e[38;5;141m"
LIME="\e[38;5;154m"

#=========================================================
# ARGUMENTOS TELEGRAM
#=========================================================

TELEGRAM_MODE="false"
for arg in "$@"; do
    [[ "$arg" == "--telegram" ]] && TELEGRAM_MODE="true"
done


#=========================================================
# VARIABLES DEL SERVIDOR
#=========================================================

CLIENT_IP=""
OS_NAME=""
HOSTNAME_SERVER=""
DATE_NOW=""

VERSION_ACTUAL="No disponible"
NUEVA_VERSION="No disponible"

#=========================================================
# FUNCIONES
#=========================================================

titulo() {

    clear 2>/dev/null || true

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}              KEVIN TECH UPDATER${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}                 MULTI SCRIPT PREMIUM${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

ok() {
    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
}

error() {
    echo -e " ${RED}✘${RESET} ${WHITE}$1${RESET}"
}

warning() {
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

#=========================================================
# ERROR
#=========================================================

error_exit() {

    echo
    error "$1"
    echo

    rm -rf "$TMP"

    exit 1
}

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo -e "${RED}❌ Este actualizador necesita ejecutarse como root.${RESET}"
    echo

    if command -v sudo >/dev/null 2>&1; then

        exec sudo bash "$0" "$@"

    else

        exit 1

    fi

fi

#=========================================================
# COMPROBAR INSTALACIÓN
#=========================================================

if [[ ! -d "$BASE" ]]; then

    error "No existe el directorio $BASE."

    echo
    echo -e "${YELLOW}⚠ El sistema KevinTech no parece estar instalado.${RESET}"
    echo

    exit 1

fi

#=========================================================
# DEPENDENCIAS
#=========================================================

MISSING=""

command -v curl >/dev/null 2>&1 || MISSING+=" curl"
command -v jq >/dev/null 2>&1 || MISSING+=" jq"
command -v git >/dev/null 2>&1 || MISSING+=" git"

if [[ -n "$MISSING" ]]; then

    echo -e "${CYAN}◆ Instalando dependencias:${RESET}${WHITE}$MISSING${RESET}"
    echo

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y >/dev/null 2>&1 || \
        error_exit "No se pudieron actualizar los repositorios."

    apt-get install -y \
        curl \
        jq \
        git \
        ca-certificates \
        >/dev/null 2>&1 || \
        error_exit "No se pudieron instalar las dependencias."

fi

#=========================================================
# INICIO
#=========================================================

titulo

echo -e "${GOLD}${BOLD}◆ ACTUALIZACIÓN DEL SISTEMA${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Preparando actualización..."

echo -e " ${GRAY}➜${RESET} Repositorio: ${SKY}$REPO${RESET}"
echo -e " ${GRAY}➜${RESET} Destino:     ${SKY}$BASE${RESET}"

echo

#=========================================================
# VERSIÓN INSTALADA
#=========================================================

if [[ -f "$VERSION_FILE" ]]; then

    VERSION_ACTUAL="$(
        head -n1 "$VERSION_FILE" |
        tr -d '\r'
    )"

fi

[[ -z "$VERSION_ACTUAL" ]] && \
    VERSION_ACTUAL="No disponible"

echo -e "${BLUE}${BOLD}◆ INFORMACIÓN DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${YELLOW}Versión instalada:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"

echo

info "No se requiere Key ni activación externa. La actualización continuará directamente."
echo

#=========================================================
# INFORMACIÓN SERVIDOR
#=========================================================

info "Recopilando información del servidor..."

CLIENT_IP="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 10 \
        -4 \
        https://api.ipify.org \
        2>/dev/null
)"

if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP="Desconocida"
fi

OS_NAME="$(
    grep '^PRETTY_NAME=' /etc/os-release |
    cut -d'"' -f2
)"

[[ -z "$OS_NAME" ]] && \
    OS_NAME="Desconocido"

HOSTNAME_SERVER="$(hostname)"

DATE_NOW="$(
    date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

echo

echo -e "${CYAN}${BOLD}◆ INFORMACIÓN DEL SERVIDOR${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${GRAY}IP:${RESET}        ${WHITE}$CLIENT_IP${RESET}"
echo -e " ${GRAY}Hostname:${RESET}  ${WHITE}$HOSTNAME_SERVER${RESET}"
echo -e " ${GRAY}Sistema:${RESET}   ${WHITE}$OS_NAME${RESET}"
echo -e " ${GRAY}Fecha:${RESET}     ${WHITE}$DATE_NOW${RESET}"

echo

#=========================================================
# TEMPORAL
#=========================================================

info "Preparando archivos temporales..."

rm -rf "$TMP"

mkdir -p "$TMP" || \
    error_exit "No se pudo crear el directorio temporal."

echo

#=========================================================
# DESCARGAR ACTUALIZACIÓN
#=========================================================

echo -e "${MAGENTA}${BOLD}◆ DESCARGANDO ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${CYAN}⬇${RESET} ${WHITE}Conectando con GitHub...${RESET}"
echo

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP"; then

    echo

    error "No se pudo descargar la actualización."

    echo
    echo -e " ${YELLOW}⚠${RESET} Comprueba:"
    echo -e "   ${GRAY}•${RESET} Conexión a Internet"
    echo -e "   ${GRAY}•${RESET} Acceso a GitHub"
    echo -e "   ${GRAY}•${RESET} Disponibilidad del repositorio"
    echo

    rm -rf "$TMP"

    exit 1

fi

echo

ok "Actualización descargada correctamente."

#=========================================================
# NUEVA VERSIÓN
#=========================================================

if [[ -f "$TMP/version.txt" ]]; then

    NUEVA_VERSION="$(
        head -n1 "$TMP/version.txt" |
        tr -d '\r'
    )"

fi

[[ -z "$NUEVA_VERSION" ]] && \
    NUEVA_VERSION="No disponible"

echo

echo -e "${PURPLE}${BOLD}◆ CONTROL DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${YELLOW}Versión actual:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"
echo -e " ${GREEN}Nueva versión:${RESET}  ${LIME}${NUEVA_VERSION}${RESET}"

echo

#=========================================================
# BACKUP
#=========================================================

echo -e "${BLUE}${BOLD}◆ COPIA DE SEGURIDAD${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

BACKUP_DIR="${BASE}/backup"

mkdir -p "$BACKUP_DIR" || \
    error_exit "No se pudo crear el directorio de backup."

BACKUP_FILE="$BACKUP_DIR/backup_$(date '+%Y%m%d_%H%M%S').tar.gz"

info "Creando copia de seguridad..."

if tar \
    -czf "$BACKUP_FILE" \
    -C "$BASE" \
    --exclude="./backup" \
    . >/dev/null 2>&1; then

    ok "Backup creado."

    echo -e " ${GRAY}➜${RESET} $BACKUP_FILE"

else

    warning "No se pudo crear el backup completo."
    echo -e "${YELLOW}La actualización continuará.${RESET}"

fi

echo

#=========================================================
# INSTALAR
#=========================================================

echo -e "${BLUE}${BOLD}◆ INSTALANDO ARCHIVOS${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Copiando archivos..."

if ! cp -a "$TMP"/. "$BASE"/; then

    echo

    error "No se pudieron copiar los archivos."

    echo
    rm -rf "$TMP"

    exit 1

fi

ok "Archivos actualizados correctamente."

# Eliminar metadatos de licencia heredados de versiones anteriores.
rm -f "$BASE/license.conf"

# Mantener alias histórico para instalaciones y scripts externos antiguos.
ln -sfn "$BASE" "$LEGACY_BASE" 2>/dev/null || true

#=========================================================
# VERSIÓN
#=========================================================

if [[ -f "$TMP/version.txt" ]]; then

    cp -f \
        "$TMP/version.txt" \
        "$VERSION_FILE"

    ok "Versión instalada: ${NUEVA_VERSION}"

else

    warning "No se encontró version.txt."

fi

#=========================================================
# PERMISOS
#=========================================================

echo

info "Aplicando permisos..."

chmod -R 755 "$BASE" >/dev/null 2>&1 || true

ok "Permisos actualizados."

info "Actualización aplicada localmente. No se requiere activación externa."
echo

#=========================================================
# LIMPIEZA
#=========================================================

echo

info "Limpiando archivos temporales..."

rm -rf "$TMP"

ok "Limpieza completada."

#=========================================================
# FINAL
#=========================================================

echo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}          ✅ ACTUALIZACIÓN COMPLETADA${RESET}              ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET} ${GRAY}                 Yaku-Multi-Script${RESET}           ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e " ${CYAN}◆${RESET} ${WHITE}Versión anterior:${RESET} ${GRAY}${VERSION_ACTUAL}${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Versión instalada:${RESET} ${GREEN}${NUEVA_VERSION}${RESET}"

echo

echo -e "${CYAN}🚀${RESET} ${WHITE}Regresando al panel...${RESET}"

sleep 2

#=========================================================
# REGRESAR AL MENÚ
#=========================================================

if [[ "$TELEGRAM_MODE" == "true" ]]; then
    exit 0
fi

if [[ -f "$BASE/menu.sh" ]]; then

    exec bash "$BASE/menu.sh"

else

    echo
    warning "No se encontró menu.sh."
    echo
    echo -e "${CYAN}Escribe:${RESET} menu"
    echo

fi

exit 0
