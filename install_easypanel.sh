#!/bin/bash
###############################################################################
#  Script de instalación de Easypanel (Contabo) - Acciones 1 a 1              #
#  (c) 2025 - Francisco Rozas Mira - Licencia MIT                              #
###############################################################################

# Actualiza el sistema operativo
apt update && apt upgrade -y

# Instala Docker
curl -sSL https://get.docker.com | sh

# Instala Easypanel (modo setup)
docker run --rm -it \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup

# Añadir net-tools
apt install -y net-tools

# Asegúrate de que los puertos 80 y 443 estén disponibles
netstat -tuln | grep -E "80|443"

# Si están ocupados, detén el servicio que los usa (por ejemplo, Apache)
systemctl stop apache2
systemctl disable apache2

# Configura el firewall (opcional)
ufw allow ssh
ufw allow 80
ufw allow 443
ufw enable

# Mensaje final
echo ""
echo "======================================================="
echo "¡Instalación finalizada! Para acceder a Easypanel, abre"
echo "tu navegador y ve a: https://<tu-IP> (o tu dominio, si procede)."
echo "======================================================="
