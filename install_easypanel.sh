#!/bin/bash
################################################################################
#  Script para instalar y configurar Docker + Easypanel en un servidor Ubuntu  #
#  con la mejor solución para HTTPS, usando Let’s Encrypt si tienes dominio.    #
#                                                                              #
#  Autor: Francisco Rozas Mira (2025)  |  Instagram: @franr.ia                 #
#  Basado en la idea original de OrionDesign                                   #
#  Licencia: MIT                                                               #
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
BLANCO="\e[97m"
ROJO="\e[91m"
RESET="\e[0m"

function echo_info ()  { echo -e "${BLANCO}[INFO]${RESET} $1"; }
function echo_ok ()    { echo -e "${VERDE}[OK]${RESET} $1"; }
function echo_warn ()  { echo -e "${AMARILLO}[WARN]${RESET} $1"; }
function echo_error () { echo -e "${ROJO}[ERROR]${RESET} $1"; }

# ──────────────────────────────────────────────────────────────────────────────
#                              VALIDACIÓN DE ROOT
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
 _______                      _____                 _ 
|__   __|                    |  __ \               | |
   | | __ _ _ __ ___  ___ ___| |__) |__ _ _ __ ___ | |
   | |/ _` | '__/ _ \/ __/ _ \  _  // _` | '_ ` _ \| |
   | | (_| | | |  __/ (_|  __/ | \ \ (_| | | | | | |_|
   |_|\__,_|_|  \___|\___\___|_|  \_\__,_|_| |_| |_(_)

 Instalador Automatizado de Docker + Easypanel (HTTPS Let’s Encrypt)
 (c) 2025 - Francisco Rozas Mira   |  Instagram: @franr.ia
 Basado en la idea original de OrionDesign
 Licencia: MIT
EOF

echo
echo "Este script actualizará el sistema, instalará Docker, Easypanel,"
echo "net-tools y configurará un firewall. Además, si tienes un dominio"
echo "apuntando a esta IP, usará Let’s Encrypt automáticamente."
echo "Presiona CTRL+C para cancelar si no deseas continuar."
sleep 5

# ──────────────────────────────────────────────────────────────────────────────
# 1. ACTUALIZA EL SISTEMA (APT UPDATE & UPGRADE)
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Actualizando repositorios y paquetes del sistema..."
apt update && apt upgrade -y
echo_ok "Sistema actualizado."

# ──────────────────────────────────────────────────────────────────────────────
# 2. INSTALA DOCKER (get.docker.com)
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Instalando Docker..."
curl -sSL https://get.docker.com | sh
echo_ok "Docker instalado correctamente."

# ──────────────────────────────────────────────────────────────────────────────
# 3. PREGUNTA SI USAR LET’S ENCRYPT (DOMINIO)
# ──────────────────────────────────────────────────────────────────────────────
USE_LETSENCRYPT="n"
EASYPANEL_DOMAIN=""
EASYPANEL_EMAIL=""

echo_info "¿Quieres configurar Easypanel con Let’s Encrypt para HTTPS? (S/n)"
read -p "   " USE_LETSENCRYPT

if [[ "$USE_LETSENCRYPT" =~ ^[Ss]$ ]]; then
  echo_info "Introduce el nombre de dominio (ej: panel.midominio.com):"
  read EASYPANEL_DOMAIN
  if [ -z "$EASYPANEL_DOMAIN" ]; then
    echo_warn "No se ha introducido dominio. Se usará un certificado auto-firmado."
  else
    echo_info "Introduce un correo electrónico para Let’s Encrypt:"
    read EASYPANEL_EMAIL
    if [ -z "$EASYPANEL_EMAIL" ]; then
      echo_warn "No se especificó email. Let’s Encrypt puede requerirlo."
      EASYPANEL_EMAIL="admin@$EASYPANEL_DOMAIN"
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 4. INSTALA EASYPANEL (SETUP) CON LAS VARIABLES DE ENTORNO
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Instalando Easypanel (modo setup)..."

EXISTING=$(docker ps -q -f name=easypanel)
if [ "$EXISTING" ]; then
  echo_warn "Se encontró un contenedor Easypanel en ejecución. Deteniéndolo..."
  docker stop easypanel
  docker rm easypanel
fi

PORTS="-p 80:80 -p 443:443"

if [ -n "$EASYPANEL_DOMAIN" ]; then
   docker run --rm -it \
     $PORTS \
     -v /etc/easypanel:/etc/easypanel \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -e EASYPANEL_DOMAIN="$EASYPANEL_DOMAIN" \
     -e EASYPANEL_LETSENCRYPT_EMAIL="$EASYPANEL_EMAIL" \
     easypanel/easypanel setup
else
   docker run --rm -it \
     $PORTS \
     -v /etc/easypanel:/etc/easypanel \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     easypanel/easypanel setup
fi

echo_ok "Easypanel configurado."

# ──────────────────────────────────────────────────────────────────────────────
# 5. AÑADIR NET-TOOLS
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Instalando net-tools (para netstat, etc.)..."
apt install net-tools -y
echo_ok "net-tools instalado."

# ──────────────────────────────────────────────────────────────────────────────
# 6. VERIFICA PUERTOS 80/443 Y DETIENE APACHE (SI EXISTE)
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Verificando puertos 80 y 443..."
sleep 1
PORTS_IN_USE=$(netstat -tuln | grep -E "0.0.0.0:(80|443)|:::(80|443)")

if [ -n "$PORTS_IN_USE" ]; then
  echo_warn "Se encontraron servicios usando puertos 80/443:"
  echo "$PORTS_IN_USE"
  echo
  echo_warn "Intentando detener apache2 (si está en ejecución)..."
  systemctl stop apache2 2>/dev/null
  systemctl disable apache2 2>/dev/null
  echo_ok "Apache (si existía) se detuvo y deshabilitó."
else
  echo_ok "Los puertos 80 y 443 están libres."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. CONFIGURA FIREWALL (UFW) PARA PUERTOS 80/443/SSH
# ──────────────────────────────────────────────────────────────────────────────
echo_info "Configurando firewall UFW..."
which ufw &>/dev/null || apt install ufw -y

ufw allow ssh
ufw allow 80
ufw allow 443

if [[ "$(ufw status)" == *"Status: inactive"* ]]; then
  echo_info "Habilitando UFW..."
  ufw --force enable
  echo_ok "UFW habilitado."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. MENSAJE FINAL DE ACCESO
# ──────────────────────────────────────────────────────────────────────────────
clear
cat <<EOF

${VERDE}==========================================================
¡Instalación completada con éxito!
==========================================================${RESET}

- Docker está instalado y en ejecución.
- Easypanel se ha configurado.

EOF

if [ -n "$EASYPANEL_DOMAIN" ]; then
  echo "Se ha configurado Easypanel con dominio: ${AMARILLO}$EASYPANEL_DOMAIN${RESET}"
  echo "Si Let’s Encrypt ha validado tu dominio, el certificado SSL"
  echo "estará activo. De lo contrario, revisa logs y configuración DNS."
  echo -e "Accede via HTTPS: ${AMARILLO}https://$EASYPANEL_DOMAIN${RESET}\n"
else
  echo "No se configuró un dominio, se ha generado un certificado auto-firmado."
  echo "Podrás acceder a Easypanel en: https://<IP-del-servidor>"
  echo "El navegador mostrará una advertencia de certificado inseguro."
  echo
fi

echo "- net-tools instalado (para netstat, etc.)."
echo "- Firewall UFW activo, puertos 22 (SSH), 80 y 443 abiertos."
echo

echo_ok "¡Proceso finalizado! Disfruta de Easypanel."
exit 0
