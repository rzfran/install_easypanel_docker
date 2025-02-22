#!/bin/bash
################################################################################
#  Script de instalación de Easypanel para Contabo                             #
#  (c) 2025 - Francisco Rozas Mira - MIT License                               #
#                                                                              #
#  Orden de pasos (exáctamente como se indica):                                #
#    1) apt update && apt upgrade -y                                           #
#    2) Instala Docker                                                         #
#    3) Instala Easypanel (docker run)                                         #
#    4) apt install net-tools                                                  #
#    5) netstat -tuln | grep -E "80|443"                                       #
#    6) Detener apache2                                                        #
#    7) Configurar ufw (ssh, 80, 443)                                          #
#    8) Mensaje final de acceso                                               #
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
#                             COLORES Y FUNCIONES
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
    | |/ _` | '__/ _ \ | '__/ _ \/ _` |/ _ \ '__| | |  | | | | |/ _` |/ _ \ '_ \ 
    | | (_| | | |  __/ | | |  __/ (_| |  __/ |    | |__| | |_| | (_| |  __/ | | |
    |_|\__,_|_|  \___|_|_|  \___|\__,_|\___|_|     \___|_|\__,_|\__,_|\___|_| |_|
    
              Instalador de Easypanel (Contabo) por Francisco Rozas Mira
                                  (c) 2025 - MIT License
EOF

echo
echo_info "Este script seguirá exactamente estos pasos, en el orden indicado:"
echo " 1) apt update && apt upgrade -y"
echo " 2) Instalar Docker (curl -sSL https://get.docker.com | sh)"
echo " 3) Instalar Easypanel (docker run --rm -it...)"
echo " 4) apt install net-tools"
echo " 5) netstat -tuln | grep -E \"80|443\""
echo " 6) Detener el servicio que use 80/443 (ej: Apache)"
echo " 7) Configurar firewall (ufw allow ssh,80,443 y enable)"
echo " 8) Mensaje final"
echo
echo "Pulsa [ENTER] para continuar o CTRL+C para cancelar."
read -r

# ──────────────────────────────────────────────────────────────────────────────
# 1) ACTUALIZA EL SISTEMA
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
███████╗████████╗██████╗ 
██╔════╝╚══██╔══╝██╔══██╗
█████╗     ██║   ██████╔╝
██╔══╝     ██║   ██╔══██╗
███████╗   ██║   ██║  ██║
╚══════╝   ╚═╝   ╚═╝  ╚═╝
STEP
echo_info "1) Actualizando el sistema operativo..."
sleep 1
apt update && apt upgrade -y
echo_ok "Sistema actualizado."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 2) INSTALAR DOCKER
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
██╔══██╗██╔═══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
██████╔╝██║   ██║██║     ███████║█████╗  ██████╔╝
██╔══██╗██║   ██║██║     ██╔══██║██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚██████╗██║  ██║███████╗██║  ██║
╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
STEP
echo_info "2) Instalando Docker (curl -sSL https://get.docker.com | sh)..."
sleep 1
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 3) INSTALAR EASY PANEL
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
███████╗ █████╗ ███████╗██╗   ██╗██████╗  ███████╗███╗   ██╗███████╗
██╔════╝██╔══██╗██╔════╝██║   ██║██╔══██╗██╔════╝████╗  ██║██╔════╝
█████╗  ███████║█████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗
██╔══╝  ██╔══██║██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║
██║     ██║  ██║███████╗╚██████╔╝██║  ██║███████╗██║ ╚████║███████║
╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝
STEP
echo_info "3) Instalando Easypanel (docker run --rm -it...)"
sleep 1
docker run --rm -it \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup
echo_ok "Easypanel instalado y configurado."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 4) INSTALAR net-tools
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
███╗   ██╗███████╗████████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗
████╗  ██║██╔════╝╚══██╔══╝     ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
██╔██╗ ██║█████╗     ██║          ██║   ██║   ██║██║   ██║██║     ███████╗
██║╚██╗██║██╔══╝     ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║
██║ ╚████║███████╗   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║
╚═╝  ╚═══╝╚══════╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
STEP
echo_info "4) Instalando net-tools..."
sleep 1
apt install -y net-tools
echo_ok "net-tools instalado."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 5) VERIFICAR PUERTOS 80 Y 443
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
██████╗ ███████╗██████╗ ██╗██████╗ 
██╔══██╗██╔════╝██╔══██╗██║██╔══██╗
██████╔╝█████╗  ██║  ██║██║██║  ██║
██╔══██╗██╔══╝  ██║  ██║██║██║  ██║
██║  ██║███████╗██████╔╝██║██████╔╝
╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚═════╝ 
STEP
echo_info "5) Revisando si los puertos 80 y 443 están en uso..."
sleep 1
netstat -tuln | grep -E "80|443" || echo "No se encontraron procesos en 80/443."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
# 6) DETIENE SERVICIO QUE OCUPA 80/443 (ej: Apache)
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
██████╗ ███████╗████████╗██╗██████╗ ███████╗
██╔══██╗██╔════╝╚══██╔══╝██║██╔══██╗██╔════╝
██████╔╝█████╗     ██║   ██║██████╔╝█████╗  
██╔══██╗██╔══╝     ██║   ██║██╔═══╝ ██╔══╝  
██║  ██║███████╗   ██║   ██║██║     ███████╗
╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝╚═╝     ╚══════╝
STEP
echo_info "6) Deteniendo Apache2 (si está activo) y deshabilitándolo..."
sleep 1
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
echo_ok "Apache detenido/deshabilitado (si existía)."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 7) CONFIGURA FIREWALL (UFW)
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP"
██╗   ██╗███████╗
██║   ██║██╔════╝
██║   ██║█████╗  
██║   ██║██╔══╝  
╚██████╔╝███████╗
 ╚═════╝ ╚══════╝
STEP
echo_info "7) Configurando firewall UFW (permitir SSH, 80 y 443)..."
sleep 1
apt-get install -y ufw >/dev/null 2>&1
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable
echo_ok "Firewall activo con puertos 22(SSH), 80 y 443 abiertos."
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# 8) MENSAJE FINAL
# ──────────────────────────────────────────────────────────────────────────────
clear
echo -e "${VERDE}===========================================================${RESET}"
echo -e "   PROCESO DE INSTALACIÓN FINALIZADO CON ÉXITO"
echo -e "${VERDE}===========================================================${RESET}"
echo
echo -e "${BLANCO}- Docker está instalado correctamente.${RESET}"
echo -e "${BLANCO}- Easypanel se ha configurado en tu servidor.${RESET}"
echo -e "${BLANCO}- net-tools instalado y puertos 80 y 443 disponibles.${RESET}"
echo -e "${BLANCO}- Firewall UFW activo (SSH, 80, 443 abiertos).${RESET}"
echo
echo -e "${AMARILLO}Accede a Easypanel abriendo tu navegador en:${RESET}"
echo -e "  ${CYAN}https://<IP-de-tu-servidor>${RESET} (o el dominio que hayas configurado)"
echo
echo -e "${VERDE}[OK]${RESET} ¡Disfruta de Easypanel!"
echo
