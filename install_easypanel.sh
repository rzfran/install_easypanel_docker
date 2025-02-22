#!/bin/bash
################################################################################
#  Script de instalación de Docker + Easypanel (Contabo)                       #
#  (c) 2025 - Francisco Rozas Mira - MIT License                               #
#                                                                              #
#  Estructura original:                                                        #
#   1) apt update && apt upgrade -y                                            #
#   2) Instala Docker (curl -sSL https://get.docker.com | sh)                  #
#   3) Instala Easypanel (docker run --rm -it ... setup)                       #
#   4) apt install net-tools                                                   #
#   5) netstat -tuln | grep -E "80|443"                                        #
#   6) Detener apache                                                          #
#   7) Configurar UFW (puertos 22, 80, 443)                                    #
#   8) Mensaje final con la URL (IP)                                           #
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
#                        COLORES Y FUNCIONES AUXILIARES
# ──────────────────────────────────────────────────────────────────────────────
AMARILLO="\e[33m"
VERDE="\e[32m"
CYAN="\e[36m"
ROJO="\e[91m"
BLANCO="\e[97m"
RESET="\e[0m"

function echo_info()   { echo -e "${CYAN}[INFO]${RESET} $1"; }
function echo_ok()     { echo -e "${VERDE}[OK]${RESET} $1"; }
function echo_warn()   { echo -e "${AMARILLO}[WARN]${RESET} $1"; }
function echo_error()  { echo -e "${ROJO}[ERROR]${RESET} $1"; }

# ──────────────────────────────────────────────────────────────────────────────
#                       VERIFICACIÓN DE PERMISOS DE ROOT
# ──────────────────────────────────────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
  echo_error "Debes ejecutar este script como root (o usando sudo)."
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
#                             BANNER DE BIENVENIDA
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "EOF"
  __          __  _                            _____                      
  \ \        / / | |                          / ____|                     
   \ \  /\  / /__| | ___ ___  _ __ ___   ___ | (_____      ____ _ _ __ ___
    \ \/  \/ / _ \ |/ __/ _ \| '_ ` _ \ / _ \ \___ \ \ /\ / / _` | '__/ _ \
     \  /\  /  __/ | (_| (_) | | | | | |  __/ ____) \ V  V / (_| | | |  __/
      \/  \/ \___|_|\___\___/|_| |_| |_|\___||_____/ \_/\_/ \__,_|_|  \___|
     
         Instalador Docker + Easypanel | (c) 2025 Francisco Rozas Mira
                Basado en la estructura original para Contabo
EOF
echo
echo_info "¡Bienvenido! Este script instalará Docker + Easypanel con pasos originales."
echo_info "Si ya tienes Docker/Easypanel, podrás limpiar antes de volver a instalar."
echo "Pulsa [ENTER] para continuar o CTRL+C para cancelar."
read -r

# ──────────────────────────────────────────────────────────────────────────────
#                   DETECTA SI DOCKER/EASYPANEL YA ESTÁN INSTALADOS
# ──────────────────────────────────────────────────────────────────────────────
INSTALADO_DOCKER="no"
INSTALADO_EASYPANEL="no"

command -v docker &>/dev/null && INSTALADO_DOCKER="si"
[ -d "/etc/easypanel" ] && INSTALADO_EASYPANEL="si"
EASY_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -w easypanel 2>/dev/null)
[ -n "$EASY_CONTAINER" ] && INSTALADO_EASYPANEL="si"

# ──────────────────────────────────────────────────────────────────────────────
#              PREGUNTA SI QUIERE LIMPIAR INSTALACIONES ANTERIORES
# ──────────────────────────────────────────────────────────────────────────────
HACER_LIMPIEZA="no"
if [ "$INSTALADO_DOCKER" = "si" ] || [ "$INSTALADO_EASYPANEL" = "si" ]; then
  echo_warn "Se detecta instalación previa de Docker/Easypanel."
  echo -n "¿Deseas DESINSTALAR todo (borrar contenedores, etc.)? (s/n): "
  read -r RESP
  RESP=$(echo "$RESP" | tr '[:upper:]' '[:lower:]')
  if [[ "$RESP" == "s" || "$RESP" == "si" ]]; then
    HACER_LIMPIEZA="si"
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
#                    LIMPIEZA DE DOCKER/EASYPANEL (si procede)
# ──────────────────────────────────────────────────────────────────────────────
if [ "$HACER_LIMPIEZA" = "si" ]; then
  echo_info "Parando y eliminando contenedor 'easypanel' (si existe)..."
  docker stop easypanel 2>/dev/null
  docker rm easypanel 2>/dev/null

  echo_info "Borrando carpeta /etc/easypanel..."
  rm -rf /etc/easypanel

  echo_info "Desinstalando Docker y limpiando paquetes..."
  apt remove -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt purge -y docker-ce docker-ce-cli docker.io containerd runc 2>/dev/null
  apt autoremove -y
  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd

  echo_ok "Limpieza completa de Docker y Easypanel realizada."
  sleep 2
fi

# ──────────────────────────────────────────────────────────────────────────────
#              (1) ACTUALIZA SISTEMA (apt update && apt upgrade)
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP1"
█████╗ ████████╗ ██████╗ 
██╔══██╗╚══██╔══╝██╔═══██╗
███████║   ██║   ██║   ██║
██╔══██║   ██║   ██║   ██║
██║  ██║   ██║   ╚██████╔╝
╚═╝  ╚═╝   ╚═╝    ╚═════╝ 
STEP1
echo_info "1) Actualizando el sistema operativo..."
apt update && apt upgrade -y
echo_ok "Sistema actualizado."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#     (2) INSTALA DOCKER (curl -sSL https://get.docker.com | sh)
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP2"
██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
██╔══██╗██╔═══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
██████╔╝██║   ██║██║     ███████║█████╗  ██████╔╝
██╔══██╗██║   ██║██║     ██╔══██║██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚██████╗██║  ██║███████╗██║  ██║
╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
STEP2
echo_info "2) Instalando Docker..."
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#           (3) INSTALA EASY PANEL (docker run --rm -it setup)
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP3"
███████╗ █████╗ ███████╗██╗   ██╗██████╗  ███████╗███╗   ██╗███████╗
██╔════╝██╔══██╗██╔════╝██║   ██║██╔══██╗██╔════╝████╗  ██║██╔════╝
█████╗  ███████║█████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗
██╔══╝  ██╔══██║██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║
██║     ██║  ██║███████╗╚██████╔╝██║  ██║███████╗██║ ╚████║███████║
╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝
STEP3
echo_info "3) Instalando Easypanel (modo setup)."
docker run --rm -it \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup

echo_ok "Easypanel instalado y configurado."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#      (4) AÑADIR net-tools
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP4"
███╗   ██╗███████╗████████╗     ██████╗ ███████╗
████╗  ██║██╔════╝╚══██╔══╝     ██╔══██╗██╔════╝
██╔██╗ ██║█████╗     ██║        ██║  ██║█████╗  
██║╚██╗██║██╔══╝     ██║        ██║  ██║██╔══╝  
██║ ╚████║███████╗   ██║        ██████╔╝███████╗
╚═╝  ╚═══╝╚══════╝   ╚═╝        ╚═════╝ ╚══════╝
STEP4
echo_info "4) Instalando net-tools (para netstat)..."
apt install -y net-tools
echo_ok "net-tools instalado."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#      (5) Verificar puertos con netstat
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP5"
██╗   ██╗███████╗████████╗██╗   ██╗███████╗██████╗  ██████╗ 
██║   ██║██╔════╝╚══██╔══╝██║   ██║██╔════╝██╔══██╗██╔═══██╗
██║   ██║█████╗     ██║   ██║   ██║█████╗  ██████╔╝██║   ██║
╚██╗ ██╔╝██╔══╝     ██║   ██║   ██║██╔══╝  ██╔══██╗██║   ██║
 ╚████╔╝ ███████╗   ██║   ╚██████╔╝███████╗██║  ██║╚██████╔╝
  ╚═══╝  ╚══════╝   ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ 
STEP5
echo_info "5) Verificando puertos 80 y 443 con netstat..."
netstat -tuln | grep -E "80|443" || echo_info "No hay procesos en 80/443 (o solo Easypanel)."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#      (6) Detener apache si está presente
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP6"
 █████╗ ██████╗  ██████╗██╗  ██╗ █████╗  ██████╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██║ ██╔╝██╔══██╗██╔════╝██╔════╝
███████║██████╔╝██║   ██║█████╔╝ ███████║██║     █████╗  
██╔══██║██╔══██╗██║   ██║██╔═██╗ ██╔══██║██║     ██╔══╝  
██║  ██║██║  ██║╚██████╔╝██║  ██╗██║  ██║╚██████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
STEP6
echo_info "6) Deteniendo apache2 (si está activo) y deshabilitándolo..."
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
echo_ok "Apache detenido/deshabilitado (si existía)."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#      (7) CONFIGURAR UFW
# ──────────────────────────────────────────────────────────────────────────────
clear
cat << "STEP7"
██╗   ██╗███████╗
██║   ██║██╔════╝
██║   ██║█████╗  
██║   ██║██╔══╝  
╚██████╔╝███████╗
 ╚═════╝ ╚══════╝
STEP7
echo_info "7) Configurando firewall UFW (SSH, 80, 443)..."
apt install -y ufw >/dev/null 2>&1
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable
echo_ok "UFW activo. Puertos 22, 80, 443 abiertos."
sleep 2

# ──────────────────────────────────────────────────────────────────────────────
#                    (8) MENSAJE FINAL CON IP POR DEFECTO
# ──────────────────────────────────────────────────────────────────────────────
clear
PUBLIC_IP="$(curl -s ifconfig.me || echo 'TuServidorIP')"

cat << "FIN"
  ______ _           _           _       _____                      _ 
 |  ____(_)         | |         | |     / ____|                    | |
 | |__   _ _ __   __| | ___  ___| |_   | (_____      ____ _ _ __ ___| |
 |  __| | | '_ \ / _` |/ _ \/ __| __|   \___ \ \ /\ / / _` | '__/ _ \ |
 | |    | | | | | (_| |  __/\__ \ |_    ____) \ V  V / (_| | | |  __/ |
 | |    | | | | | (_| |  __/\__ \ |_   | (_____  R E D A C T E D 
FIN

echo -e "${VERDE}¡Instalación completada exitosamente!${RESET}"
echo
echo -e " - Docker instalado."
echo -e " - Easypanel configurado en modo setup."
echo -e " - net-tools instalado, puertos revisados."
echo -e " - Apache deshabilitado, UFW activo (22, 80, 443)."
echo
echo -e "${AMARILLO}Accede a Easypanel desde tu navegador en:${RESET}"
echo -e "  ${CYAN}https://${PUBLIC_IP}${RESET}"
echo
echo -e "Podrás luego configurar dominio personalizado y SSL si lo deseas."
echo
echo_ok "¡Gracias por usar este instalador! Atentamente, Francisco Rozas Mira (@franr.ia en instagram)."
echo
exit 0
