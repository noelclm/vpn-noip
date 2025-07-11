#!/bin/bash
set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin Color

echo -e "${YELLOW}Script de Configuración del Servidor OpenVPN${NC}"
echo "Este script te ayudará a configurar un servidor OpenVPN seguro con soporte para DNS dinámico."

# Verificar si docker y docker compose están instalados
if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null; then
    echo "Docker y/o Docker Compose no están instalados. Por favor instálalos primero."
    exit 1
fi

# Verificar si el archivo .env existe
if [ ! -f .env ]; then
    echo -e "\n${YELLOW}No se encontró el archivo .env. Creando uno...${NC}"
    cp .env.example .env
    echo "Por favor edita el archivo .env con tu configuración y ejecuta este script nuevamente."
    exit 0
fi

# Cargar las variables de entorno
set -a
source .env
set +a

echo -e "\n${GREEN}Paso 1: Configurar No-IP DNS Dinámico${NC}"
echo "Usando el dominio de No-IP: $NOIP_DOMAIN"

# Generar el archivo de configuración DDNS desde la plantilla
echo "Generando configuración DDNS..."

# Escapar caracteres especiales en la contraseña para JSON
NOIP_PASSWORD_ESCAPED=$(echo "$NOIP_PASSWORD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
export NOIP_PASSWORD_ESCAPED

# Usar un enfoque modificado de envsubst
cat ddns-config/config.json.template | \
  sed "s/\${NOIP_PASSWORD}/$(echo "$NOIP_PASSWORD_ESCAPED" | sed 's/[[\.*^$()+?{|]/\\&/g')/g" | \
  envsubst > ddns-config/config.json

# Inicializar la configuración de OpenVPN
echo -e "\n${GREEN}Paso 2: Inicializar el Servidor OpenVPN${NC}"
echo "Esto generará las claves de cifrado y certificados para tu servidor VPN."

# Crear la configuración de OpenVPN con parámetros correctos
docker run -v $PWD/openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig \
    -u $OVPN_PROTOCOL://$OVPN_DOMAIN:$OVPN_PORT \
    -C $OVPN_CIPHER \
    -a $OVPN_AUTH \
    -T $OVPN_TLS_CIPHER \
    $([ "$OVPN_COMP_LZO" = "true" ] && echo "-z") \
    -p "redirect-gateway def1" \
    -p "dhcp-option DNS 1.1.1.1" \
    -p "dhcp-option DNS 1.0.0.1" \
    -p "block-outside-dns"

echo -e "\n${YELLOW}Ahora necesitas inicializar el PKI (Infraestructura de Clave Pública)${NC}"
echo "Se te pedirá que establezca una frase de contraseña para tu clave CA."
echo "Asegúrate de recordar esta frase de contraseña ya que será necesaria más adelante."
echo -e "Presiona Enter para continuar..."
read

# Inicializar PKI
docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki

echo -e "\n${GREEN}Paso 3: Iniciar los servicios VPN y DDNS${NC}"
echo "Iniciando los servicios con docker compose..."
docker compose up -d

echo -e "\n${GREEN}Paso 4: Generar un certificado de cliente${NC}"
read -p "Ingresa un nombre para el cliente (ej: laptop, telefono): " CLIENT_NAME

# Generar certificado de cliente
docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $CLIENT_NAME nopass

# Generar archivo de configuración del cliente
docker run -v $PWD/openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $CLIENT_NAME > $CLIENT_NAME.ovpn

echo -e "\n${GREEN}¡Éxito!${NC}"
echo "Tu servidor VPN ahora está funcionando con la siguiente configuración:"
echo "- Dominio: $OVPN_DOMAIN"
echo "- Puerto: $OVPN_PORT/$OVPN_PROTOCOL"
echo "- Cifrado: $OVPN_CIPHER con autenticación $OVPN_AUTH"
echo "- TLS: $OVPN_TLS_CIPHER"
echo "- Compresión: $OVPN_COMP_LZO"
echo ""
echo "Se ha creado un archivo de configuración del cliente: $CLIENT_NAME.ovpn"
echo "Puedes usar este archivo con clientes OpenVPN en tus dispositivos."
echo ""
echo "Para agregar más clientes, ejecuta:"
echo "docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full NOMBRE_CLIENTE nopass"
echo "docker run -v $PWD/openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient NOMBRE_CLIENTE > NOMBRE_CLIENTE.ovpn"
echo ""
echo "Para verificar el estado de tus servicios:"
echo "docker compose ps"
echo ""
echo "Para ver los logs:"
echo "docker compose logs -f"