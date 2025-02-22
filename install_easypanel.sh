#!/bin/bash
################################################################################
#  Script de instalación/rehabilitación de Easypanel para Contabo              #
#  (c) 2025 - Francisco Rozas Mira - MIT License                               #
#                                                                              #
#  Realiza los pasos:                                                          #
#   1) Verifica si Docker/Easypanel están instalados y pregunta si borrarlos   #
#   2) Desinstala Docker/Easypanel (si el usuario lo desea)                    #
#   3) Instala todo en orden estricto:                                         #
#       - apt update && apt upgrade -y                                         #
#       - curl -sSL https://get.docker.com | sh                                #
#       - docker run ... easypanel/easypanel setup                             #
#       - apt install net-tools                                                #
#       - netstat -tuln | grep -E "80|443"                                     #
#       - systemctl stop apache2 && disable apache2                            #
#       - ufw allow ssh, 80, 443, enable                                       #
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

  Instalador / reinstalador de Docker + Easypanel (Contabo)
  (c) 2025 - Francisco Rozas Mira | MIT License
EOF

echo
echo_info "Este script va a:"
echo "1) Comprobar si Docker/Easypanel ya están instalados."
echo "2) Si están instalados, te preguntará si deseas borrarlos (para dejar limpio)."
echo "3) Luego instalará en orden estricto: apt update & upgrade, Docker, Easypanel, net-tools, etc."
echo
echo "Pulsa [ENTER] para continuar o CTRL+C para cancelar."
read -r

# ──────────────────────────────────────────────────────────────────────────────
#         DETECCIÓN PREVIA DE DOCKER Y EASY PANEL (y contenedor)
# ──────────────────────────────────────────────────────────────────────────────
INSTALADO_DOCKER="no"
INSTALADO_EASYPANEL="no"

# - Comprobar si Docker está instalado
if command -v docker &>/dev/null; then
  INSTALADO_DOCKER="si"
fi

# - Comprobar si hay un contenedor 'easypanel' (corriendo o detenido)
EASY_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -w easypanel 2>/dev/null)
if [ -n "$EASY_CONTAINER" ]; then
  INSTALADO_EASYPANEL="si"
fi

# - Comprobar si existe la carpeta /etc/easypanel
if [ -d "/etc/easypanel" ]; then
  INSTALADO_EASYPANEL="si"
fi

# ──────────────────────────────────────────────────────────────────────────────
#   SI ESTÁN INSTALADOS, PREGUNTAR AL USUARIO SI DESEA DESINSTALAR
# ──────────────────────────────────────────────────────────────────────────────
HACER_LIMPIEZA="no"

if [ "$INSTALADO_DOCKER" = "si" ] || [ "$INSTALADO_EASYPANEL" = "si" ]; then
  echo_warn "Se detecta que Docker/Easypanel ya están presentes en el servidor."
  echo "¿Deseas DESINSTALAR Docker/Easypanel para reinstalar todo limpio?"
  read -p "(s/n): " RESP
  RESP=$(echo "$RESP" | tr '[:upper:]' '[:lower:]')
  if [[ "$RESP" == "s" || "$RESP" == "si" ]]; then
    HACER_LIMPIEZA="si"
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
#                      LIMPIEZA (si el usuario aceptó)
# ──────────────────────────────────────────────────────────────────────────────
if [ "$HACER_LIMPIEZA" = "si" ]; then
  echo_info "Eliminando contenedor 'easypanel' (si existe)..."
  docker stop easypanel 2>/dev/null
  docker rm easypanel 2>/dev/null

  echo_info "Borrando carpeta /etc/easypanel..."
  rm -rf /etc/easypanel

  echo_info "Desinstalando Docker y purgando paquetes relacionados..."
  # Esto desinstala Docker CE, Docker.io, containerd, etc. Ajusta según tu distro
  apt remove -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt purge -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt autoremove -y

  # Docker datos
  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd

  echo_ok "Limpieza completa de Docker y Easypanel finalizada."
fi

# ──────────────────────────────────────────────────────────────────────────────
#        1) ACTUALIZACIÓN: apt update && apt upgrade -y
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "1) Actualizando el sistema operativo..."
apt update && apt upgrade -y
echo_ok "Sistema actualizado."

# ──────────────────────────────────────────────────────────────────────────────
#        2) INSTALA DOCKER (curl -sSL https://get.docker.com | sh)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "2) Instalando Docker..."
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."

# ──────────────────────────────────────────────────────────────────────────────
#        3) INSTALA EASY PANEL
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "3) Instalando Easypanel..."
docker run --rm -it \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup
echo_ok "Easypanel instalado y configurado."

# ──────────────────────────────────────────────────────────────────────────────
#        4) AÑADIR NET-TOOLS
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "4) Instalando net-tools (para netstat)..."
apt install -y net-tools
echo_ok "net-tools instalado."

# ──────────────────────────────────────────────────────────────────────────────
#        5) ASEGURAR PUERTOS 80 Y 443 DISPONIBLES
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "5) Verificando puertos 80 y 443 con netstat..."
netstat -tuln | grep -E "80|443" || echo_info "No se encontraron procesos en 80/443."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#        6) DETIENE SERVICIO QUE USE 80/443 (ej: Apache)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "6) Deteniendo apache2 si está en ejecución..."
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
echo_ok "Apache detenido y deshabilitado (si existía)."

# ──────────────────────────────────────────────────────────────────────────────
#        7) CONFIGURAR EL FIREWALL (UFW allow ssh, 80, 443, enable)
# ──────────────────────────────────────────────────────────────────────────────
clear
echo_info "7) Configurando firewall UFW (permitir SSH, 80 y 443)..."
apt install -y ufw 2>/dev/null
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable
echo_ok "Firewall UFW activo, puertos 22/80/443 abiertos."

# ──────────────────────────────────────────────────────────────────────────────
#        8) MENSAJE FINAL
# ──────────────────────────────────────────────────────────────────────────────
clear
echo -e "${VERDE}==============================================================${RESET}"
echo -e "      INSTALACIÓN DE EASY PANEL COMPLETADA EXITOSAMENTE"
echo -e "${VERDE}==============================================================${RESET}"
echo
echo -e " - Docker instalado (o reinstalado) con éxito."
echo -e " - Easypanel configurado: carpeta /etc/easypanel y contenedor 'easypanel'."
echo -e " - net-tools instalado, puertos 80/443 revisados."
echo -e " - Apache detenido y firewall UFW activo (SSH, 80, 443)."
echo
echo -e "${AMARILLO}Para acceder a Easypanel, abre tu navegador en:${RESET}"
echo -e "   ${CYAN}https://<IP-del-servidor>${RESET} (o tu dominio, si lo configuraste)."
echo
echo_ok "¡Disfruta de tu servidor, Winner!"
echo
exit 0
