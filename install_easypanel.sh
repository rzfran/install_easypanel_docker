#!/bin/bash
################################################################################
#  Script de instalación/rehabilitación de Easypanel para Contabo              #
#  (c) 2025 - Francisco Rozas Mira - MIT License                               #
#                                                                              #
#  Proceso exacto con la opción adicional de dominio personalizado:            #
#    1) Verifica si Docker/Easypanel están instalados, pregunta si limpiar.    #
#    2) Si el usuario acepta, desinstala Docker/Easypanel por completo.        #
#    3) apt update && apt upgrade -y                                           #
#    4) Instala Docker (curl -sSL https://get.docker.com | sh)                 #
#    5) Pregunta si se desea configurar un dominio personalizado para Easypanel#
#    6) Instala Easypanel (docker run ... ) pasando la variable de dominio.    #
#    7) apt install net-tools                                                  #
#    8) netstat -tuln | grep -E "80|443"                                       #
#    9) systemctl stop apache2 && disable apache2                              #
#    10) ufw allow ssh, 80, 443, enable                                        #
#    11) Mensaje final con link (IP o dominio).                                #
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

 Instalación / reinstalación de Docker + Easypanel (Contabo)
 Con opción de dominio personalizado
 (c) 2025 - Francisco Rozas Mira | MIT License
EOF

echo
echo_info "Este script va a:"
echo " 1) Comprobar si Docker/Easypanel ya están instalados."
echo " 2) Preguntar si quieres borrarlos y reinstalar de cero (opcional)."
echo " 3) Instalar todo en estricto orden (apt update, Docker, Easypanel, net-tools, etc.)."
echo " 4) Preguntar si deseas un dominio personalizado para Easypanel."
echo " 5) Mostrar al final un link directo al panel (IP pública o dominio)."
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
  echo -n "¿Quieres DESINSTALAR Docker/Easypanel para tener instalación limpia? (s/n): "
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
#      1) apt update && apt upgrade -y
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "1) Actualizando el sistema operativo..."
apt update && apt upgrade -y
echo_ok "Sistema actualizado."

# ──────────────────────────────────────────────────────────────────────────────
#      2) Instala Docker
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "2) Instalando Docker (curl -sSL https://get.docker.com | sh)..."
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."

# ──────────────────────────────────────────────────────────────────────────────
#      2.1) Pregunta dominio personalizado
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "¿Deseas configurar un dominio personalizado para Easypanel? (s/n)"
read -r DOM_RESP
DOM_RESP=$(echo "$DOM_RESP" | tr '[:upper:]' '[:lower:]')
EASYPANEL_DOMAIN=""
if [[ "$DOM_RESP" == "s" || "$DOM_RESP" == "si" ]]; then
  echo_info "Introduce el dominio (ej: panel.midominio.com):"
  read -r EASYPANEL_DOMAIN
  if [ -z "$EASYPANEL_DOMAIN" ]; then
    echo_warn "No se introdujo dominio. Se usará IP por defecto."
    EASYPANEL_DOMAIN=""
  fi
else
  echo_info "Se usará la IP del servidor por defecto."
fi

# ──────────────────────────────────────────────────────────────────────────────
#      3) Instala Easypanel (docker run)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "3) Instalando Easypanel..."
if [ -n "$EASYPANEL_DOMAIN" ]; then
  docker run --rm -it \
    -v /etc/easypanel:/etc/easypanel \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -e EASYPANEL_DOMAIN="$EASYPANEL_DOMAIN" \
    easypanel/easypanel setup
else
  docker run --rm -it \
    -v /etc/easypanel:/etc/easypanel \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    easypanel/easypanel setup
fi
echo_ok "Easypanel instalado y configurado."

# ──────────────────────────────────────────────────────────────────────────────
#      4) apt install net-tools
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "4) Instalando net-tools..."
apt install -y net-tools
echo_ok "net-tools instalado."

# ──────────────────────────────────────────────────────────────────────────────
#      5) netstat -tuln | grep -E "80|443"
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "5) Comprobando puertos 80 y 443..."
netstat -tuln | grep -E "80|443" || echo_info "No se encontraron procesos en 80/443."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#      6) Detiene Apache (si existe)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "6) Deteniendo apache2 (si está activo) y deshabilitándolo..."
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
echo_ok "Apache detenido/deshabilitado (si existía)."

# ──────────────────────────────────────────────────────────────────────────────
#      7) Configurar firewall (ufw)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "7) Configurando firewall UFW (SSH, 80, 443)..."
apt install -y ufw 2>/dev/null
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable
echo_ok "Firewall activo. Puertos 22, 80, 443 abiertos."

# ──────────────────────────────────────────────────────────────────────────────
#      8) Mensaje final (con IP o dominio)
# ──────────────────────────────────────────────────────────────────────────────
clear

# Podemos obtener la IP pública de varias formas; una es:
PUBLIC_IP="$(curl -s ifconfig.me || echo 'tu_servidor_IP')"

echo -e "${VERDE}==============================================================${RESET}"
echo -e "      INSTALACIÓN DE EASY PANEL COMPLETADA EXITOSAMENTE"
echo -e "${VERDE}==============================================================${RESET}"
echo
echo -e " - Docker instalado (o reinstalado) con éxito."
echo -e " - Easypanel configurado en tu servidor."
echo -e " - net-tools instalado, puertos 80/443 revisados."
echo -e " - Firewall UFW activo (SSH, 80, 443)."
echo

if [ -n "$EASYPANEL_DOMAIN" ]; then
  echo -e "${AMARILLO}Accede a Easypanel con tu dominio personalizado:${RESET}"
  echo -e "   ${CYAN}https://$EASYPANEL_DOMAIN${RESET}"
  echo
else
  echo -e "${AMARILLO}Accede a Easypanel con la IP de tu servidor:${RESET}"
  echo -e "   ${CYAN}https://$PUBLIC_IP${RESET}"
  echo
fi

echo_ok "¡Disfruta de tu servidor, Winner!"
echo
exit 0
