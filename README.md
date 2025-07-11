# Servidor OpenVPN Seguro con DNS Dinámico

Este proyecto configura un servidor OpenVPN seguro usando Docker, con actualizaciones automáticas de DNS dinámico a través de No-IP. Está diseñado para ser fácil de configurar mientras mantiene prácticas de seguridad robustas.

## Características

- **Servidor OpenVPN**: Servidor VPN seguro con cifrado fuerte
- **Integración DNS Dinámico**: Actualizaciones automáticas de tu dirección IP con No-IP
- **Enfoque en Seguridad**: Usa estándares de cifrado modernos y deshabilita características vulnerables
- **Configuración Fácil**: Script de inicialización simple maneja todo el proceso de configuración
- **Basado en Docker**: Se ejecuta en contenedores para despliegue y gestión fácil

## Requisitos Previos

- Un servidor Linux con Docker y Docker Compose instalados
- Una cuenta No-IP (gratuita o de pago) con un dominio configurado
- Puerto 1194/UDP abierto en tu router/firewall y redirigido a tu servidor

## Características de Seguridad

Esta configuración de OpenVPN incluye las siguientes mejoras de seguridad:

- Cifrado AES-256-GCM (más fuerte y rápido que los modos CBC)
- SHA512 para autenticación
- Suite de cifrado TLS moderna (TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384)
- Diffie-Hellman de Curva Elíptica para intercambio de claves
- Compresión deshabilitada para prevenir ataques VORACLE
- Protección contra filtración DNS
- Servidores DNS de Cloudflare (1.1.1.1 y 1.0.0.1)

## Variables de Entorno

Toda la configuración se realiza a través de variables de entorno en el archivo `.env`:

### Configuración OpenVPN
- `OVPN_DOMAIN`: Tu dominio No-IP (ej., tudominio.ddns.net)
- `OVPN_PORT`: Puerto para OpenVPN (predeterminado: 1194)
- `OVPN_PROTOCOL`: Protocolo para OpenVPN (udp o tcp, predeterminado: udp)
- `OVPN_CIPHER`: Cifrado de encriptación (predeterminado: AES-256-GCM)
- `OVPN_TLS_CIPHER`: Suite de cifrado TLS (predeterminado: TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384)
- `OVPN_AUTH`: Algoritmo de autenticación (predeterminado: SHA512)
- `OVPN_COMP_LZO`: Si habilitar compresión LZO (predeterminado: false)
- `OVPN_ENABLE_COMPRESSION`: Si habilitar compresión (predeterminado: false)
- `OVPN_DH`: Parámetros Diffie-Hellman (predeterminado: none para ECDH)

### Configuración No-IP
- `NOIP_DOMAIN`: Tu dominio No-IP (usualmente el mismo que OVPN_DOMAIN)
- `NOIP_USERNAME`: Tu nombre de usuario No-IP
- `NOIP_PASSWORD`: Tu contraseña No-IP

### Configuración Actualizador DDNS
- `DDNS_UPDATE_PERIOD`: Cada cuánto verificar cambios de IP (predeterminado: 5m)
- `DDNS_COOLDOWN_PERIOD`: Período de espera entre actualizaciones (predeterminado: 5m)
- `DDNS_IP_FETCHERS`: Obtenedores de IP a usar (predeterminado: all)
- `DDNS_IP_PROVIDERS`: Proveedores de IP a usar (predeterminado: all)
- `DDNS_PORT`: Puerto para la interfaz web del actualizador DDNS (predeterminado: 8000)

## Inicio Rápido

1. Clona este repositorio:

2. Copia el archivo de entorno de ejemplo y edítalo con tu configuración:
   ```
   cp .env.example .env
   nano .env  # o usa tu editor de texto preferido
   ```

3. Ejecuta el script de configuración:
   ```
   chmod +x setup-vpn.sh
   ./setup-vpn.sh
   ```

4. Sigue las instrucciones para configurar el servidor VPN.

5. Una vez completado, tendrás un archivo `.ovpn` que puedes usar con cualquier cliente OpenVPN.

## Configuración Manual

Si prefieres configurar los servicios manualmente:

1. Copia el archivo de entorno de ejemplo y edítalo con tu configuración:
   ```
   cp .env.example .env
   nano .env  # o usa tu editor de texto preferido
   ```

2. Genera el archivo de configuración DDNS desde la plantilla:
   ```
   envsubst < ddns-config/config.json.template > ddns-config/config.json
   ```

3. Inicializa la configuración de OpenVPN:
   ```
   source .env
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
   ```

4. Inicializa el PKI:
   ```
   docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
   ```

5. Inicia los servicios:
   ```
   docker compose up -d
   ```

6. Genera un certificado de cliente:
   ```
   docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full NOMBRE_CLIENTE nopass
   docker run -v $PWD/openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient NOMBRE_CLIENTE > NOMBRE_CLIENTE.ovpn
   ```

## Configuración del Cliente

1. Transfiere el archivo `.ovpn` a tu dispositivo de forma segura (ej., usando SCP o un método de transferencia de archivos seguro).

2. Instala un cliente OpenVPN:
   - **Windows**: [OpenVPN GUI](https://openvpn.net/community-downloads/)
   - **macOS**: [Tunnelblick](https://tunnelblick.net/) o [Viscosity](https://www.sparklabs.com/viscosity/)
   - **Linux**: `sudo apt install openvpn` o equivalente para tu distribución
   - **iOS**: [OpenVPN Connect](https://apps.apple.com/us/app/openvpn-connect/id590379981)
   - **Android**: [OpenVPN for Android](https://play.google.com/store/apps/details?id=de.blinkt.openvpn)

3. Importa el archivo `.ovpn` en tu cliente y conéctate.

## Solución de Problemas

### Problemas de Conexión

- Verifica que el puerto 1194/UDP esté abierto y redirigido a tu servidor
- Revisa los logs de OpenVPN: `docker compose logs openvpn`
- Asegúrate de que tu dominio No-IP esté apuntando correctamente a tu IP actual

### Problemas del Actualizador DDNS

- Revisa los logs del actualizador DDNS: `docker compose logs ddns-updater`
- Verifica tus credenciales No-IP en el archivo .env
- Asegúrate de que el archivo config.json se generó correctamente: `cat ddns-config/config.json`
- Visita la interfaz web del actualizador DDNS en http://ip-de-tu-servidor:8000 para el estado (o el puerto que configuraste en DDNS_PORT)

## Agregar Más Clientes

Para agregar más certificados de cliente:

```bash
docker run -v $PWD/openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full NOMBRE_NUEVO_CLIENTE nopass
docker run -v $PWD/openvpn-data:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient NOMBRE_NUEVO_CLIENTE > NOMBRE_NUEVO_CLIENTE.ovpn
```