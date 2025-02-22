#!/bin/bash
################################################################################
#  Script de instalación/rehabilitación de Docker + Easypanel (Contabo)         #
#  con opción de dominio personalizado y Let’s Encrypt                          #
#  (c) 2025 - Francisco Rozas Mira - MIT License                               #
#                                                                              #
#  Pasos en orden:                                                              #
#   1) Detecta si Docker/Easypanel están instalados, pregunta si borrarlos.     #
#   2) Limpia Docker/Easypanel si el usuario acepta (borrando contenedor, etc.).#
#   3) apt update && apt upgrade -y                                             #
#   4) Instala Docker                                                           #
#   5) Pregunta dominio (opcional) y si usar Let’s Encrypt (correo).           #
#   6) Inicia Easypanel con docker run -d (-p 80:80 -p 443:443) y variables env.#
#   7) Instala net-tools, netstat puertos 80/443, detiene apache, UFW.          #
#   8) Muestra link final (dominio o IP).                                       #
################################################################################

: '
MIT License (c) 2025

Copyright (c) 2025 Francisco Rozas Mira

Por la presente, se concede permiso, libre de cargos, a cualquier persona que obtenga
una copia de este software y de los archivos de documentación asociados (el "Software"),
para tratar el Software sin restricción, incluyendo, sin limitación, los derechos
para usar, copiar, modificar, fusionar, publicar, distribuir, sublicenciar,
y/o vender copias del Software, y para permitir a las personas a quienes se
proporcione el Software a hacer lo mismo, sujeto a las siguientes condiciones:

La nota de copyright anterior y esta nota de permiso deberán
incluirse en todas las copias o partes sustanciales del Software.

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO,
EXPRESA O IMPLÍCITA, INCLUYENDO PERO NO LIMITADO A GARANTÍAS
DE COMERCIALIZACIÓN, IDONEIDAD PARA UN PROPÓSITO PARTICULAR
Y NO INFRACCIÓN. EN NINGÚN CASO LOS AUTORES O TITULARES DEL COPYRIGHT
SERÁN RESPONSABLES DE NINGUNA RECLAMACIÓN, DAÑO U OTRA RESPONSABILIDAD,
YA SEA EN UNA ACCIÓN DE CONTRATO, AGRAVIO O CUALQUIER OTRA SITUACIÓN,
QUE SURJA DE O EN CONEXIÓN CON EL SOFTWARE O EL USO U OTRO TIPO
DE ACCIONES EN EL SOFTWARE.
'

# ──────────────────────────────────────────────────────────────────────────────
#                            COLORES Y FUNCIONES
# ──────────────────────────────────────────────────────────────────────────────
AMARILLO="\e[33m"
VERDE="\e[32m"
CYAN="\e[36m"
ROJO="\e[91m"
BLANCO="\e[97m"
RESET="\e[0m"

function echo_info()  { echo -e "${CYAN}[INFO]${RESET} $1"; }
function echo_ok()    { echo -e "${VERDE}[OK]${RESET} $1"; }
function echo_warn()  { echo -e "${AMARILLO}[WARN]${RESET} $1"; }
function echo_error() { echo -e "${ROJO}[ERROR]${RESET} $1"; }

# ──────────────────────────────────────────────────────────────────────────────
#                            VALIDACIÓN DE ROOT
# ──────────────────────────────────────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
  echo_error "Debes ejecutar este script como root (o usando sudo)."
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
#                          BANNER DE PRESENTACIÓN
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "EOF"
  _______             _              _              ___ _           _            
 |__   __|           (_)            | |            / __| |         | |           
    | | __ _ _ __ ___ _ _ __ ___  __| | ___ _ __  | |  | |_   _  __| | ___ _ __  
    | |/ _` | '__/ _ \/ __/ _ \  _  // _` | '_ ` _ \| |
    | | (_| | | |  __/ (_|  __/ | \ \ (_| | | | | | |_|
    |_|\__,_|_|  \___|\___\___|_|  \_\__,_|_| |_| |_(_)

 Instalación / Reinstalación de Docker + Easypanel (Contabo)
 con dominio personalizado y Let’s Encrypt opcional
 (c) 2025 - Francisco Rozas Mira | MIT License
EOF

echo
echo_info "Este script:"
echo " 1) Comprueba si Docker/Easypanel están instalados y pregunta si limpiarlos."
echo " 2) Instala (o reinstala) Docker, Easypanel, net-tools, etc., en estricto orden."
echo " 3) Te permite establecer un dominio personalizado (y Let’s Encrypt)."
echo " 4) Al final muestra el enlace de acceso (dominio o IP)."
echo
echo "Pulsa [ENTER] para continuar o CTRL+C para cancelar."
read -r

# ──────────────────────────────────────────────────────────────────────────────
#       DETECCIÓN PREVIA DE DOCKER Y EASY PANEL (y contenedor)
# ──────────────────────────────────────────────────────────────────────────────
INSTALADO_DOCKER="no"
INSTALADO_EASYPANEL="no"

if command -v docker &>/dev/null; then
  INSTALADO_DOCKER="si"
fi

EASY_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -w easypanel 2>/dev/null)
if [ -n "$EASY_CONTAINER" ]; then
  INSTALADO_EASYPANEL="si"
fi

if [ -d "/etc/easypanel" ]; then
  INSTALADO_EASYPANEL="si"
fi

# ──────────────────────────────────────────────────────────────────────────────
#    PREGUNTAR AL USUARIO SI DESEA BORRAR LAS INSTALACIONES EXISTENTES
# ──────────────────────────────────────────────────────────────────────────────
HACER_LIMPIEZA="no"
if [ "$INSTALADO_DOCKER" = "si" ] || [ "$INSTALADO_EASYPANEL" = "si" ]; then
  echo_warn "Se detecta Docker/Easypanel instalados en este servidor."
  echo -n "¿Quieres DESINSTALAR Docker/Easypanel para instalación limpia? (s/n): "
  read -r RESP
  RESP=$(echo "$RESP" | tr '[:upper:]' '[:lower:]')
  if [[ "$RESP" == "s" || "$RESP" == "si" ]]; then
    HACER_LIMPIEZA="si"
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
#                            LIMPIEZA (opcional)
# ──────────────────────────────────────────────────────────────────────────────
if [ "$HACER_LIMPIEZA" = "si" ]; then
  echo_info "Parando y eliminando contenedor 'easypanel' (si existe)..."
  docker stop easypanel 2>/dev/null
  docker rm easypanel 2>/dev/null

  echo_info "Borrando carpeta /etc/easypanel..."
  rm -rf /etc/easypanel

  echo_info "Desinstalando Docker y purgando paquetes..."
  apt remove -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt purge -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt autoremove -y

  echo_info "Eliminando directorios de datos de Docker..."
  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd

  echo_ok "Limpieza completa de Docker y Easypanel finalizada."
fi

# ──────────────────────────────────────────────────────────────────────────────
#    1) apt update && apt upgrade -y
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "1) Actualizando el sistema operativo (apt update && apt upgrade -y)..."
apt update && apt upgrade -y
echo_ok "Sistema actualizado."

# ──────────────────────────────────────────────────────────────────────────────
#    2) Instalar Docker
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "2) Instalando Docker (curl -sSL https://get.docker.com | sh)..."
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."

# ──────────────────────────────────────────────────────────────────────────────
#    2.1) Preguntar dominio personalizado y Let’s Encrypt
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "¿Deseas configurar un dominio personalizado para Easypanel? (s/n)"
read -r DOM_RESP
DOM_RESP=$(echo "$DOM_RESP" | tr '[:upper:]' '[:lower:]')
EASYPANEL_DOMAIN=""
EASYPANEL_LETSENCRYPT_EMAIL=""

if [[ "$DOM_RESP" == "s" || "$DOM_RESP" == "si" ]]; then
  echo_info "Introduce el dominio (ej: panel.midominio.com):"
  read -r EASYPANEL_DOMAIN
  if [ -n "$EASYPANEL_DOMAIN" ]; then
    echo_info "¿Deseas usar Let’s Encrypt para HTTPS válido en tu dominio? (s/n)"
    read -r LE_RESP
    LE_RESP=$(echo "$LE_RESP" | tr '[:upper:]' '[:lower:]')
    if [[ "$LE_RESP" == "s" || "$LE_RESP" == "si" ]]; then
      echo_info "Introduce tu correo electrónico para Let’s Encrypt:"
      read -r EASYPANEL_LETSENCRYPT_EMAIL
    else
      echo_warn "Se usará certificado auto-firmado con dominio $EASYPANEL_DOMAIN."
    fi
  else
    echo_warn "No se introdujo dominio. Se usará la IP del servidor."
    EASYPANEL_DOMAIN=""
  fi
else
  echo_info "Se usará la IP del servidor para acceder a Easypanel."
fi

# ──────────────────────────────────────────────────────────────────────────────
#    3) Instala Easypanel (docker run -d)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "3) Iniciando contenedor de Easypanel en modo detach (-d)..."

# Preparamos el comando base
DOCKER_CMD="docker run -d \
  -p 80:80 \
  -p 443:443 \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --name easypanel \
  easypanel/easypanel"

# Si hay dominio, le sumamos -e EASYPANEL_DOMAIN
if [ -n "$EASYPANEL_DOMAIN" ]; then
  DOCKER_CMD="$DOCKER_CMD -e EASYPANEL_DOMAIN=\"$EASYPANEL_DOMAIN\""
fi

# Si hay email, sumamos -e EASYPANEL_LETSENCRYPT_EMAIL
if [ -n "$EASYPANEL_LETSENCRYPT_EMAIL" ]; then
  DOCKER_CMD="$DOCKER_CMD -e EASYPANEL_LETSENCRYPT_EMAIL=\"$EASYPANEL_LETSENCRYPT_EMAIL\""
fi

# Ejecutamos
eval "$DOCKER_CMD"

echo_ok "Easypanel se está ejecutando en segundo plano (contenedor 'easypanel')."

# ──────────────────────────────────────────────────────────────────────────────
#    4) apt install net-tools
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "4) Instalando net-tools (para netstat)..."
apt install -y net-tools
echo_ok "net-tools instalado."

# ──────────────────────────────────────────────────────────────────────────────
#    5) netstat -tuln | grep -E "80|443"
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "5) Verificando puertos 80/443 con netstat..."
netstat -tuln | grep -E "80|443" || echo_info "No hay servicios en 80/443 (salvo Docker/Easypanel)."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#    6) Detiene Apache si está en uso
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "6) Deteniendo apache2 (si está activo) y deshabilitándolo..."
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
echo_ok "Apache detenido/deshabilitado (si existía)."

# ──────────────────────────────────────────────────────────────────────────────
#    7) Configura firewall (UFW)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "7) Configurando firewall UFW (permitir SSH, 80 y 443)..."
apt install -y ufw 2>/dev/null
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable
echo_ok "UFW activo, puertos 22 (SSH), 80 y 443 abiertos."

# ──────────────────────────────────────────────────────────────────────────────
#    8) Mensaje final: link directo (dominio o IP)
# ──────────────────────────────────────────────────────────────────────────────
clear

# Intentamos obtener la IP pública (puedes cambiar a "hostname -I | awk '{print $1}'")
PUBLIC_IP="$(curl -s ifconfig.me || echo 'X.X.X.X')"

echo -e "${VERDE}==============================================================${RESET}"
echo -e " INSTALACIÓN DE EASY PANEL COMPLETADA EXITOSAMENTE"
echo -e "${VERDE}==============================================================${RESET}"
echo
echo -e " - Docker instalado (o reinstalado) con éxito."
echo -e " - Easypanel en contenedor 'easypanel' (puertos 80/443)."
echo -e " - net-tools instalado, puertos verificados."
echo -e " - Firewall UFW activo (SSH, 80, 443)."
echo

if [ -n "$EASYPANEL_DOMAIN" ]; then
  echo -e "${AMARILLO}Accede a Easypanel con tu dominio:${RESET}"
  echo -e "   ${CYAN}https://$EASYPANEL_DOMAIN${RESET}"
  if [ -n "$EASYPANEL_LETSENCRYPT_EMAIL" ]; then
    echo "Easypanel intentará emitir un certificado Let’s Encrypt automáticamente."
  else
    echo "Usarás un certificado auto-firmado para HTTPS (advertencias en el navegador)."
  fi
else
  echo -e "${AMARILLO}Accede a Easypanel con la IP del servidor:${RESET}"
  echo -e "   ${CYAN}https://$PUBLIC_IP${RESET}"
  echo "Se usará un certificado auto-firmado (si no configuraste nada adicional)."
fi

echo
echo_ok "¡Disfruta de tu servidor, Winner"
echo
exit 
