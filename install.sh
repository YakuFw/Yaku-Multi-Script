#!/bin/bash

#=========================================================
#        YAKU-MULTI-SCRIPT INSTALLER
#        LICENSE SYSTEM v4.0
#        PREMIUM SERVER EDITION
#
#        HTTPS / TLS SECURE EDITION
#=========================================================

set -o pipefail

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
VIOLET="\e[38;5;177m"
SKY="\e[38;5;117m"
LIME="\e[38;5;154m"
GOLD="\e[38;5;220m"
ORANGE="\e[38;5;214m"
AQUA="\e[38;5;159m"

#=========================================================
# VARIABLES PRINCIPALES
#=========================================================

BASE="/etc/yaku-multi-script"
LEGACY_BASE="/etc/kevintech"
TMP="/tmp/yaku_multi_script_install"

# Migración segura del directorio histórico.
# Se conserva /etc/kevintech como alias para compatibilidad.
if [[ -e "$LEGACY_BASE" && ! -L "$LEGACY_BASE" ]]; then
    if [[ -e "$BASE" ]]; then
        echo "❌ Existen ambos directorios: $BASE y $LEGACY_BASE"
        echo "   Revisa la instalación manualmente antes de continuar."
        exit 1
    fi
    mv "$LEGACY_BASE" "$BASE"
fi

if [[ -d "$BASE" && ! -e "$LEGACY_BASE" ]]; then
    ln -s "$BASE" "$LEGACY_BASE"
elif [[ -L "$LEGACY_BASE" && "$(readlink -f "$LEGACY_BASE")" != "$BASE" ]]; then
    rm -f "$LEGACY_BASE"
    ln -s "$BASE" "$LEGACY_BASE"
fi

# SOLO HTTPS
REPO="https://github.com/YakuFw/Yaku-Multi-Script.git"
INSTALL_PROTOCOLS="ON"

SERVER_DOMAIN=""
SERVER_IP=""
DOMAIN_IP=""
DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

CLIENT_IP=""
OS_NAME=""
HOSTNAME_VALUE=""
DATE_NOW=""

SSHD_CFG="/etc/ssh/sshd_config"

#=========================================================
# CONFIGURACIÓN DE CURL / TLS
#=========================================================

export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

CURL_COMMON=(
    --silent
    --show-error
    --location
    --fail
    --connect-timeout 7
    --max-time 20
    --retry 2
    --retry-delay 1
    --tlsv1.2
    --proto '=https'
)

#=========================================================
# LIMPIEZA
#=========================================================

cleanup() {
    rm -rf "$TMP"
}

trap cleanup EXIT

#=========================================================
# FUNCIONES VISUALES
#=========================================================

clear_screen() {
    clear 2>/dev/null || true
}

linea() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

linea_color() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

titulo() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}                 YAKU-MULTI-SCRIPT${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                 PREMIUM INSTALLER v4.0${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${SKY}              🚀  S E C U R E   E D I T I O N  🚀${RESET}"
    echo

}

seccion() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD} $1${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

ok() {
    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
}

warn() {
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

fail() {
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
}

loading() {

    local TEXT="$1"

    echo -ne " ${CYAN}${TEXT}${RESET} "

    for i in 1 2 3; do
        echo -ne "${PURPLE}●${RESET}"
        sleep 0.12
    done

    echo
}

pausa() {
    sleep "${1:-1}"
}

error_exit() {

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}❌ INSTALACIÓN DETENIDA${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
    echo

    cleanup

    exit 1
}

#=========================================================
# VALIDAR URL HTTPS
#=========================================================

validate_https_url() {

    local URL="$1"

    if [[ "$URL" != https://* ]]; then
        fail "URL insegura rechazada:"
        echo -e " ${RED}$URL${RESET}"
        return 1
    fi

    if [[ "$URL" =~ [[:space:]] ]]; then
        fail "La URL contiene espacios."
        return 1
    fi

    return 0
}

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}🔒 PERMISOS ROOT NECESARIOS${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${YELLOW}Ejecuta:${RESET}"
    echo
    echo -e "${CYAN}sudo -i${RESET}"
    echo

    exit 1
fi

#=========================================================
# SISTEMA OPERATIVO
#=========================================================

if [[ ! -f /etc/os-release ]]; then
    error_exit "No se pudo detectar el sistema operativo."
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    error_exit "Este instalador solamente es compatible con Ubuntu."
fi

#=========================================================
# VALIDAR TODAS LAS URL PRINCIPALES
#=========================================================

validate_https_url "$REPO" ||
    error_exit "El repositorio no utiliza HTTPS."

#=========================================================
# CABECERA
#=========================================================

titulo

echo -e "${GREEN}             ● SISTEMA COMPATIBLE DETECTADO ●${RESET}"
echo

echo -e "${WHITE}Sistema : ${SKY}${PRETTY_NAME}${RESET}"
echo -e "${WHITE}Usuario : ${GOLD}root${RESET}"
echo -e "${WHITE}Proyecto: ${MAGENTA}Yaku-Multi-Script${RESET}"
echo -e "${WHITE}Seguridad: ${GREEN}HTTPS / TLS 1.2+${RESET}"

echo
linea_color

#=========================================================
# PASO 0
# DEPENDENCIAS
#=========================================================

seccion "📦 PASO 0  •  PREPARANDO EL SISTEMA"

echo -e "${GRAY}Instalando las herramientas necesarias para Yaku-Multi-Script.${RESET}"
echo

export DEBIAN_FRONTEND=noninteractive

loading "Actualizando repositorios"

apt-get update -y >/dev/null 2>&1 ||
    error_exit "No se pudieron actualizar los repositorios."

ok "Repositorios actualizados."

loading "Instalando dependencias"

apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    dnsutils \
    sudo \
    openssl \
    unzip \
    zip \
    tar \
    nano \
    cron \
    net-tools \
    lsof \
    screen \
    bc \
    socat \
    openssh-server \
    ufw \
    fail2ban \
    >/dev/null 2>&1 ||
    error_exit "No se pudieron instalar las dependencias."

update-ca-certificates >/dev/null 2>&1 || true

ok "Dependencias instaladas."

#=========================================================
# COMPROBAR HTTPS / REPOSITORIO
#=========================================================

seccion "🔐 PASO 1  •  SEGURIDAD HTTPS"

info "Verificando acceso HTTPS al repositorio..."
if ! curl "${CURL_COMMON[@]}" -I "${REPO}" >/dev/null 2>&1; then
    error_exit "No se pudo establecer una conexión HTTPS segura con el repositorio."
fi
ok "TLS/HTTPS operativo."

info "Repositorio:"
echo -e " ${GREEN}🔒 ${REPO}${RESET}"

seccion "🚀 PASO 2  •  INICIO DE YAKU-MULTI-SCRIPT"

ok "Instalación sin sistema de licencias: no se requiere Key."

#=========================================================
# PASO 2
# DOMINIO
#=========================================================


seccion "🌐 PASO 2  •  CONFIGURACIÓN DE DOMINIO"

loading "Detectando IP pública"

SERVER_IP="$(curl "${CURL_COMMON[@]}" -4 https://api.ipify.org 2>/dev/null)" || true
[[ -z "$SERVER_IP" ]] && SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -z "$SERVER_IP" ]] && SERVER_IP="Desconocida"

read -r -p "$(echo -e "${CYAN}🌐 Dominio del VPS (ENTER = usar IP ${SERVER_IP}):${RESET} ")" SERVER_DOMAIN
SERVER_DOMAIN="$(printf '%s' "$SERVER_DOMAIN" | tr -d '[:space:]')"

if [[ -z "$SERVER_DOMAIN" ]]; then
    SERVER_DOMAIN="$SERVER_IP"
    DOMAIN_MODE="IP"
    ok "Sin dominio. Se utilizará la IP del VPS: $SERVER_IP"
elif [[ "$SERVER_DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] && [[ "$SERVER_DOMAIN" == *.* ]]; then
    DOMAIN_MODE="DOMAIN"
    ok "Dominio configurado: $SERVER_DOMAIN"
else
    warn "Dominio inválido. Se utilizará la IP del VPS: $SERVER_IP"
    SERVER_DOMAIN="$SERVER_IP"
    DOMAIN_MODE="IP"
fi

DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

loading "Comprobando DNS"

DOMAIN_IP=""
if [[ "${DOMAIN_MODE:-DOMAIN}" == "DOMAIN" ]]; then
    DOMAIN_IP="$(dig +short A "$SERVER_DOMAIN" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"
fi

if [[ -n "$DOMAIN_IP" &&
      "$DOMAIN_IP" == "$SERVER_IP" ]]; then

    DOMAIN_IP_MATCH="YES"

    ok "El dominio apunta correctamente al VPS."

else

    warn "El dominio todavía no apunta a este VPS."

    [[ -n "$DOMAIN_IP" ]] && {

        echo -e \
            " ${GRAY}IP encontrada:${RESET} ${YELLOW}$DOMAIN_IP${RESET}"

        echo -e \
            " ${GRAY}IP VPS:${RESET} ${CYAN}$SERVER_IP${RESET}"
    }

fi

NS="$(
    dig +short NS "$SERVER_DOMAIN" |
    tr '\n' ' '
)"

if echo "$NS" | grep -qi "cloudflare"; then

    DNS_PROVIDER="Cloudflare"

elif echo "$NS" | grep -Eqi "awsdns|route53"; then

    DNS_PROVIDER="AWS Route 53"

elif echo "$NS" | grep -Eqi "google"; then

    DNS_PROVIDER="Google Cloud DNS"

elif echo "$NS" | grep -qi "azure"; then

    DNS_PROVIDER="Azure DNS"

elif echo "$NS" | grep -qi "namecheap"; then

    DNS_PROVIDER="Namecheap"

elif echo "$NS" | grep -qi "godaddy"; then

    DNS_PROVIDER="GoDaddy"

elif echo "$NS" | grep -qi "porkbun"; then

    DNS_PROVIDER="Porkbun"

fi

echo
echo -e \
    " ${GRAY}Proveedor DNS:${RESET} ${SKY}$DNS_PROVIDER${RESET}"

#=========================================================
# PASO 5
# OPENSSH
#=========================================================

seccion "🔒 PASO 3  •  CONFIGURANDO SSH"

loading "Activando OpenSSH"

systemctl enable ssh >/dev/null 2>&1 ||
    error_exit "No se pudo habilitar OpenSSH."

systemctl restart ssh >/dev/null 2>&1 ||
    error_exit "No se pudo iniciar OpenSSH."

if systemctl is-active --quiet ssh; then

    ok "OpenSSH activo."

else

    error_exit "OpenSSH no está activo."

fi

#=========================================================
# SSH HARDENING
#=========================================================

info "Aplicando protección SSH..."

if [[ -f "$SSHD_CFG" ]]; then

    cp "$SSHD_CFG" \
        "${SSHD_CFG}.kevintech.backup"

    sed -i \
        -e '/^[[:space:]]*#\?[[:space:]]*MaxAuthTries[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveInterval[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveCountMax[[:space:]]/d' \
        "$SSHD_CFG"

    cat >> "$SSHD_CFG" <<'EOF'

#=========================================================
# KevinTech SSH configuration
#=========================================================

MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

EOF

fi

if sshd -t >/dev/null 2>&1; then

    systemctl restart ssh

    ok "Configuración SSH válida."

else

    fail "Error en la configuración SSH."

    if [[ -f "${SSHD_CFG}.kevintech.backup" ]]; then

        cp \
            "${SSHD_CFG}.kevintech.backup" \
            "$SSHD_CFG"

        systemctl restart ssh

        ok "Configuración SSH anterior restaurada."

    fi

fi

#=========================================================
# FAIL2BAN
#=========================================================

seccion "🛡️ PASO 4  •  PROTECCIÓN FAIL2BAN"

mkdir -p /etc/fail2ban

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
backend = systemd
EOF

systemctl enable fail2ban >/dev/null 2>&1 || true

systemctl restart fail2ban >/dev/null 2>&1 || true

if systemctl is-active --quiet fail2ban; then

    ok "Fail2Ban activo."

else

    warn "Fail2Ban no pudo iniciarse."

fi

#=========================================================
# FIREWALL
#=========================================================

seccion "🔥 PASO 5  •  CONFIGURANDO FIREWALL"

info "Restableciendo reglas UFW..."

ufw --force reset >/dev/null 2>&1 || true

ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1

# SSH
ufw allow 22/tcp >/dev/null 2>&1

# Web
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1

# DNS / SlowDNS
ufw allow 53/udp >/dev/null 2>&1

# OpenVPN TCP
ufw allow 1194/tcp >/dev/null 2>&1

# Activar
ufw --force enable >/dev/null 2>&1 ||
    warn "No se pudo activar UFW."

if ufw status | grep -q "Status: active"; then

    ok "Firewall activo."

else

    warn "UFW no está activo."

fi

#=========================================================
# PASO 8
# DESCARGAR YAKU-MULTI-SCRIPT
#=========================================================

seccion "📥 PASO 6  •  INSTALANDO YAKU-MULTI-SCRIPT"

rm -rf "$TMP"
mkdir -p "$TMP"

validate_https_url "$REPO" ||
    error_exit "Repositorio inseguro."

loading "Descargando repositorio mediante HTTPS"

git config --global protocol.version 2

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP" >/dev/null 2>&1; then

    error_exit "No se pudieron descargar los archivos mediante HTTPS."

fi

ok "Repositorio descargado mediante HTTPS."

#=========================================================
# COMPROBAR CONTENIDO
#=========================================================

if [[ ! -d "$TMP" ]]; then
    error_exit "El repositorio descargado está vacío."
fi

if [[ ! -f "$TMP/menu.sh" ]]; then
    warn "No se encontró menu.sh en el repositorio."
fi

#=========================================================
# INSTALAR ARCHIVOS
#=========================================================

mkdir -p "$BASE"

cp -a "$TMP"/. "$BASE"/ ||
    error_exit "No se pudieron copiar los archivos."

mkdir -p \
    "$BASE/protocolos" \
    "$BASE/usuarios" \
    "$BASE/sistema" \
    "$BASE/logs" \
    "$BASE/herramientas"

# Componentes del bot: se instalan desde install.sh y no requieren
# pasos manuales separados.
if [[ -d "$TMP/telegram" ]]; then
    mkdir -p "$BASE/telegram"
    cp -a "$TMP/telegram"/. "$BASE/telegram"/
    rm -f "$BASE/telegram/README.md" "$BASE/telegram/health.sh" "$BASE/telegram/service.sh" "$BASE/telegram/setup.sh" "$BASE/telegram/update.sh"
fi

#=========================================================
# PERMISOS CORRECTOS
#=========================================================

find "$BASE" \
    -type d \
    -exec chmod 755 {} \;

find "$BASE" \
    -type f \
    -name "*.sh" \
    -exec chmod 755 {} \;

ok "Archivos instalados."

#=========================================================
# CONFIGURACIÓN PRINCIPAL
#=========================================================

seccion "⚙️ PASO 7  •  CONFIGURACIÓN PRINCIPAL"

cat > "$BASE/config.conf" <<EOF
#=========================================================
# YAKU-MULTI-SCRIPT
# CONFIGURATION
#=========================================================

SERVER_DOMAIN="$SERVER_DOMAIN"
SERVER_IP="$SERVER_IP"
DOMAIN_MODE="${DOMAIN_MODE:-DOMAIN}"

DNS_PROVIDER="$DNS_PROVIDER"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"

SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

AUTO_START=OFF

#=========================================================
# SEGURIDAD
#=========================================================

HTTPS_ONLY="ON"
TLS_MIN_VERSION="1.2"

#=========================================================
# PROTOCOLOS
#=========================================================

OPENSSH=ON

DROPBEAR=OFF
SSL=OFF
BADVPN=OFF
UDP_CUSTOM=OFF
HYSTERIA=OFF
SLOWDNS=OFF
XRAY=OFF
V2RAY=OFF
OPENVPN=OFF

ZIPVPN=OFF
WEBSOCKET=OFF
TROJAN=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF

#=========================================================
# SISTEMA
#=========================================================

SYSTEMDNS=OFF
SQUID=OFF
WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF
EOF

chmod 600 "$BASE/config.conf"

# No se crea license.conf: Yaku-Multi-Script no utiliza licencias.

#=========================================================
# COMANDO MENU
#=========================================================

cat > /usr/local/bin/menu <<'EOF'
#!/bin/bash

BASE="/etc/yaku-multi-script"

if [[ -f "$BASE/menu.sh" ]]; then
    exec bash "$BASE/menu.sh" "$@"
fi

echo "❌ No se encontró $BASE/menu.sh"
exit 1
EOF

chmod 755 /usr/local/bin/menu

ok "Comando 'menu' instalado."

#=========================================================
# PASO 10
# ACCESO ROOT
#=========================================================

seccion "👑 PASO 8  •  ACCESO ROOT"

echo -e "${WHITE}¿Deseas establecer una contraseña para root?${RESET}"
echo
echo -e "${GREEN}Y${RESET} = Establecer contraseña"
echo -e "${RED}N${RESET} = Continuar sin habilitar root por contraseña"
echo

read -r -p \
    "$(echo -e "${GOLD}[Y/N]:${RESET} ")" \
    ROOT_ACCESS

ROOT_ACCESS="$(
    printf '%s' "$ROOT_ACCESS" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$ROOT_ACCESS" == "y" ]]; then

    echo
    passwd root

    if [[ $? -eq 0 ]]; then

        if [[ -f "$SSHD_CFG" ]]; then

            sed -i \
                -e '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' \
                -e '/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication[[:space:]]/d' \
                "$SSHD_CFG"

            cat >> "$SSHD_CFG" <<'EOF'

#=========================================================
# KevinTech root access
#=========================================================

PermitRootLogin yes
PasswordAuthentication yes

EOF

            if sshd -t >/dev/null 2>&1; then

                systemctl restart ssh

                ok "Acceso root habilitado."

            else

                fail "La configuración SSH no es válida."

            fi

        fi

    else

        fail "No se pudo cambiar la contraseña."

    fi

else

    info "Root por contraseña no fue habilitado."

fi

#=========================================================
# FUNCIÓN GENERAL DE MÓDULOS
#=========================================================

seccion "🚀 PASO 9  •  INSTALACIÓN DE PROTOCOLOS"

echo -e "${WHITE}Instalando los módulos disponibles.${RESET}"
echo

instalar_modulo() {

    local NOMBRE="$1"
    local ARCHIVO="$2"
    local VARIABLE="$3"

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}📦 $NOMBRE${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if [[ ! -f "$ARCHIVO" ]]; then

        warn "$NOMBRE no encontrado."

        echo -e \
            " ${GRAY}Archivo:${RESET} $ARCHIVO"

        return 2

    fi

    chmod 755 "$ARCHIVO"

    info "Ejecutando modo automático..."

    if bash "$ARCHIVO" --auto; then

        if [[ -n "$VARIABLE" ]] &&
           grep -q "^${VARIABLE}=ON" "$BASE/config.conf" 2>/dev/null; then

            ok "$NOMBRE instalado correctamente."

        else

            ok "$NOMBRE finalizó correctamente."

        fi

        return 0

    fi

    fail "$NOMBRE terminó con errores."

    return 1
}

#=========================================================
# OPENSSH
#=========================================================

echo
info "Verificando OpenSSH..."

if systemctl is-active --quiet ssh; then

    sed -i \
        's/^OPENSSH=.*/OPENSSH=ON/' \
        "$BASE/config.conf"

    ok "OpenSSH instalado correctamente."

else

    sed -i \
        's/^OPENSSH=.*/OPENSSH=OFF/' \
        "$BASE/config.conf"

    fail "OpenSSH no está activo."

fi

#=========================================================
# DROPBEAR
#=========================================================

instalar_modulo \
    "Dropbear" \
    "$BASE/protocolos/dropbear.sh" \
    "DROPBEAR"

#=========================================================
# SSL TUNNEL
#=========================================================

instalar_modulo \
    "SSL Tunnel" \
    "$BASE/protocolos/ssl.sh" \
    "SSL"

#=========================================================
# XRAY / V2RAY
#=========================================================

XRAY_SCRIPT=""

if [[ -f "$BASE/protocolos/xray.sh" ]]; then

    XRAY_SCRIPT="$BASE/protocolos/xray.sh"

elif [[ -f "$BASE/protocolos/v2ray.sh" ]]; then

    XRAY_SCRIPT="$BASE/protocolos/v2ray.sh"

fi

if [[ -n "$XRAY_SCRIPT" ]]; then

    instalar_modulo \
        "Xray / VMess" \
        "$XRAY_SCRIPT" \
        "XRAY"

else

    warn "No se encontró xray.sh ni v2ray.sh."

fi

#=========================================================
# UDP CUSTOM
#=========================================================

instalar_modulo \
    "UDP Custom" \
    "$BASE/protocolos/udpcustom.sh" \
    "UDP_CUSTOM"

#=========================================================
# BADVPN
#=========================================================

instalar_modulo \
    "BadVPN UDPGW" \
    "$BASE/protocolos/badvpn.sh" \
    "BADVPN"

#=========================================================
# ZIVPN
#=========================================================

instalar_modulo \
    "ZiVPN" \
    "$BASE/protocolos/zivpn.sh" \
    "ZIPVPN"

#=========================================================
# SLOWDNS
#=========================================================

instalar_modulo \
    "SlowDNS" \
    "$BASE/protocolos/slowdns.sh" \
    "SLOWDNS"

#=========================================================
# OPENVPN
#=========================================================

instalar_modulo \
    "OpenVPN" \
    "$BASE/protocolos/openvpn.sh" \
    "OPENVPN"

#=========================================================
# ESTADO DE PROTOCOLOS
#=========================================================

seccion "📊 ESTADO DE PROTOCOLOS"

show_protocol() {

    local NAME="$1"
    local VAR="$2"

    local VALUE

    VALUE="$(
        grep "^${VAR}=" "$BASE/config.conf" 2>/dev/null |
        cut -d '=' -f2 |
        tr -d '"'
    )"

    if [[ "$VALUE" == "ON" ]]; then

        echo -e \
            " ${GREEN}●${RESET} ${WHITE}${NAME}:${RESET} ${GREEN}ACTIVO${RESET}"

    else

        echo -e \
            " ${GRAY}○${RESET} ${WHITE}${NAME}:${RESET} ${GRAY}NO INSTALADO${RESET}"

    fi
}

show_protocol "OpenSSH" "OPENSSH"
show_protocol "Dropbear" "DROPBEAR"
show_protocol "SSL Tunnel" "SSL"
show_protocol "UDP Custom" "UDP_CUSTOM"
show_protocol "BadVPN" "BADVPN"
show_protocol "ZiVPN" "ZIPVPN"
show_protocol "SlowDNS" "SLOWDNS"
show_protocol "Xray" "XRAY"
show_protocol "OpenVPN" "OPENVPN"

#=========================================================
# BANNER SSH
#=========================================================

seccion "🎨 PASO 10  •  CONFIGURANDO BANNER"

cat > /etc/profile.d/kevintech-banner.sh <<'EOF'
#!/bin/bash

[[ $- != *i* ]] && return

BASE="/etc/yaku-multi-script"
CONFIG="$BASE/config.conf"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

SERVER="$(hostname)"
DOMAIN="-"

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG" 2>/dev/null
    DOMAIN="${SERVER_DOMAIN:--}"
fi

UPTIME="$(
    uptime -p 2>/dev/null |
    sed 's/up //'
)"

FECHA="$(date '+%d-%m-%Y')"
HORA="$(date '+%H:%M:%S')"

RAM="$(
    free -h 2>/dev/null |
    awk '/Mem:/ {print $3 "/" $2}'
)"

LOAD="$(
    uptime 2>/dev/null |
    awk -F'load average:' '{print $2}' |
    sed 's/^ //'
)"

echo

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${PINK}${BOLD}             🚀 YAKU-MULTI-SCRIPT 🚀${RESET}           ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET} ${PURPLE}                    SECURE SERVER${RESET}                   ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${CYAN}┌────────────────── SERVIDOR ──────────────────┐${RESET}"

echo -e " ${WHITE}🖥 Servidor :${RESET} ${SKY}$SERVER${RESET}"
echo -e " ${WHITE}🌐 Dominio  :${RESET} ${MAGENTA}$DOMAIN${RESET}"
echo -e " ${WHITE}🔐 HTTPS    :${RESET} ${GREEN}ACTIVO${RESET}"
echo -e " ${WHITE}⏱ Uptime   :${RESET} ${GREEN}${UPTIME:-Desconocido}${RESET}"
echo -e " ${WHITE}💾 RAM      :${RESET} ${GREEN}${RAM:-Desconocida}${RESET}"
echo -e " ${WHITE}⚡ Carga    :${RESET} ${YELLOW}${LOAD:-Desconocida}${RESET}"
echo -e " ${WHITE}📅 Fecha    :${RESET} ${YELLOW}$FECHA${RESET}"
echo -e " ${WHITE}🕐 Hora     :${RESET} ${CYAN}$HORA${RESET}"

echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"

echo

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                       ⭐ CRÉDITOS ⭐${RESET}                   ${PURPLE}║${RESET}"
echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Proyecto :${RESET} ${PINK}Yaku-Multi-Script${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Autor    :${RESET} ${WHITE}Kevin tech tutorials${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Infra    :${RESET} ${SKY}@Dan3651${RESET}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

if [[ "$EUID" -eq 0 ]]; then

    echo -e " ${GREEN}👑 Usuario:${RESET} ${WHITE}root${RESET}"
    echo -e " ${CYAN}👉 Panel:${RESET} ${WHITE}menu${RESET}"

else

    echo -e " ${YELLOW}👤 Usuario:${RESET} ${WHITE}$(whoami)${RESET}"

fi

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}          Yaku-Multi-Script • HTTPS Secure${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

EOF

chmod 755 /etc/profile.d/kevintech-banner.sh

ok "Banner configurado."

#=========================================================
# FINALIZACIÓN LOCAL
#=========================================================

seccion "🔐 PASO 11  •  FINALIZANDO INSTALACIÓN"

ok "Instalación local completada. No se requiere activación externa."

#=========================================================
# PERMISOS FINALES
#=========================================================

find "$BASE" \
    -type d \
    -exec chmod 755 {} \;

find "$BASE" \
    -type f \
    -name "*.sh" \
    -exec chmod 755 {} \;

chmod 600 "$BASE/config.conf"
#=========================================================
# LIMPIEZA
#=========================================================


cleanup

#=========================================================
# FINAL
#=========================================================

titulo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}             🎉 INSTALACIÓN COMPLETADA 🎉${RESET}             ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e \
    " ${GREEN}●${RESET} ${WHITE}Servidor:${RESET}    ${GREEN}LISTO${RESET}"

echo -e \
    " ${GREEN}●${RESET} ${WHITE}HTTPS/TLS:${RESET}   ${GREEN}ACTIVO${RESET}"

echo

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                 INFORMACIÓN DEL VPS${RESET}                   ${PURPLE}║${RESET}"
echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"

echo -e \
    "${PURPLE}║${RESET} ${GRAY}Dominio:${RESET} ${SKY}${SERVER_DOMAIN:-No configurado}${RESET}"

echo -e \
    "${PURPLE}║${RESET} ${GRAY}IP     :${RESET} ${CYAN}${SERVER_IP}${RESET}"

echo -e \
    "${PURPLE}║${RESET} ${GRAY}DNS    :${RESET} ${MAGENTA}${DNS_PROVIDER}${RESET}"

echo -e \
    "${PURPLE}║${RESET} ${GRAY}DNS OK :${RESET} ${GREEN}${DOMAIN_IP_MATCH}${RESET}"

echo -e \
    "${PURPLE}║${RESET} ${GRAY}TLS    :${RESET} ${GREEN}HTTPS / TLS 1.2+${RESET}"

echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                     ⭐ CRÉDITOS ⭐${RESET}                    ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

echo -e \
    "${CYAN}║${RESET} ${GRAY}Proyecto :${RESET} ${PINK}Yaku-Multi-Script${RESET}"

echo -e \
    "${CYAN}║${RESET} ${GRAY}Autor    :${RESET} ${WHITE}Kevin tech tutorials${RESET}"

echo -e \
    "${CYAN}║${RESET} ${GRAY}Infra    :${RESET} ${SKY}@Dan3651${RESET}"

echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${GOLD}🚀 Yaku-Multi-Script está listo.${RESET}"

echo
echo -e \
    "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel.${RESET}"

echo

read -r -p \
    "$(echo -e "${YELLOW}¿Reiniciar el servidor ahora? [Y/N]:${RESET} ")" \
    REBOOT_SERVER

REBOOT_SERVER="$(
    printf '%s' "$REBOOT_SERVER" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$REBOOT_SERVER" == "y" ]]; then

    echo
    echo -e "${YELLOW}🔄 Reiniciando en 5 segundos...${RESET}"

    for i in 5 4 3 2 1; do

        echo -ne \
            "\r${CYAN}Reinicio en ${WHITE}${i}${CYAN}...${RESET}"

        sleep 1

    done

    echo
    reboot

else

    echo
    echo -e "${GREEN}✅ Instalación finalizada sin reiniciar.${RESET}"
    echo
    echo -e \
        "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel."
    echo

fi

exit 0