#!/bin/bash
CONFIG_PATH=/data/options.json

export CONNECTION_TYPE=$(jq --raw-output '.connection_type' $CONFIG_PATH)
export MESHTASTIC_NODE_IP=$(jq --raw-output '.MESHTASTIC_NODE_IP' $CONFIG_PATH)
export MESHTASTIC_TCP_PORT=$(jq --raw-output '.MESHTASTIC_TCP_PORT' $CONFIG_PATH)
export MESHTASTIC_SERIAL_PORT=$(jq --raw-output '.MESHTASTIC_SERIAL_PORT' $CONFIG_PATH)
export SESSION_SECRET=$(jq --raw-output '.SESSION_SECRET' $CONFIG_PATH)
export DISABLE_ANONYMOUS=$(jq --raw-output '.DISABLE_ANONYMOUS' $CONFIG_PATH)

export DATABASE_PATH="/data/meshmonitor.db"
export PORT=3001
export TRUST_PROXY=true
export ALLOWED_ORIGINS="*"
export COOKIE_SECURE=false

if [ "$CONNECTION_TYPE" = "serial" ]; then
  echo "Using Serial connection: ${MESHTASTIC_SERIAL_PORT}"
  export MESHTASTIC_CONNECTION_TYPE=serial
  export MESHTASTIC_SERIAL_PATH="${MESHTASTIC_SERIAL_PORT}"
else
  echo "Using TCP connection: ${MESHTASTIC_NODE_IP}:${MESHTASTIC_TCP_PORT}"
  export MESHTASTIC_CONNECTION_TYPE=tcp
fi

if [ -n "$SUPERVISOR_TOKEN" ]; then
  RAW_URL=$(curl -s -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/addons/self/info | jq --raw-output '.data.ingress_url')
  export BASE_URL="${RAW_URL%/}"
  echo "Configuring MeshMonitor BASE_URL to: $BASE_URL"
fi

# HA_LOGIN: password-less login for Home Assistant users via ingress.
# MeshMonitor trusts a header that only our nginx sets; its name is random
# per start so nothing else on the add-on network can guess and forge it.
NGINX_CONF=/etc/nginx/http.d/default.conf
HA_LOGIN=$(jq --raw-output '.HA_LOGIN // false' $CONFIG_PATH)
if [ "$HA_LOGIN" = "true" ]; then
  HA_HDR="x-ha-login-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  export PROXY_AUTH_ENABLED=true
  export PROXY_AUTH_AUTO_PROVISION=true
  export PROXY_AUTH_HEADER_EMAIL="$HA_HDR"
  export PROXY_AUTH_ADMIN_EMAILS=$(jq --raw-output '.HA_ADMINS // ""' $CONFIG_PATH \
    | tr 'A-Z' 'a-z' | tr -d ' ' | tr ',' '\n' | sed '/^$/d; s/.*/ha-&@homeassistant/' | paste -sd, -)
  sed -i "s/__HA_LOGIN_HEADER__/${HA_HDR}/" "$NGINX_CONF"
  echo "HA login enabled (admins: $(echo "$PROXY_AUTH_ADMIN_EMAILS" | tr ',' ' ' | wc -w))"
else
  sed -i '/__HA_LOGIN_HEADER__/d' "$NGINX_CONF"
fi

mkdir -p /run/nginx
nginx

echo "Starting MeshMonitor..."
exec node /app/dist/server/server.js
