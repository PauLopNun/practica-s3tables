#!/bin/bash
# Instalador de la practica S3 Tables: comprueba requisitos, instala dependencias
# a nivel de usuario (sin sudo), descarga las imagenes y configura el token de LocalStack.
set -e
cd "$(dirname "$0")"

ok()   { echo "  [OK] $*"; }
fallo() { echo "  [ERROR] $*" >&2; exit 1; }
paso() { echo; echo "== $*"; }

paso "1/5 Comprobando requisitos"
docker info >/dev/null 2>&1 \
  || fallo "No puedes usar Docker sin sudo (tu usuario no esta en el grupo 'docker'). Avisa al profesor."
ok "Docker accesible sin sudo"

COMPOSE=$(docker compose version --short 2>/dev/null | sed 's/^v//') \
  || fallo "No esta instalado 'docker compose' (v2)."
[ "$(printf '%s\n2.24.0\n' "$COMPOSE" | sort -V | head -1)" = "2.24.0" ] \
  || fallo "Docker Compose $COMPOSE es demasiado antiguo (minimo 2.24.0)."
ok "Docker Compose $COMPOSE"

if getent hosts localhost.localstack.cloud | grep -q '127.0.0.1'; then
  ok "DNS de localhost.localstack.cloud"
else
  echo "  [AVISO] Tu red no resuelve localhost.localstack.cloud: la Parte 2 puede fallar."
fi

paso "2/5 Instalando uv y awslocal (en ~/.local/bin)"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
ok "$(uv --version)"
uv tool install -q awscli-local --with awscli
ok "awslocal instalado"

paso "3/5 Instalando librerias de Python (uv sync)"
uv sync -q
ok "$(uv run python --version) con las librerias de uv.lock"

paso "4/5 Descargando imagenes de Docker (la primera vez tarda unos minutos)"
docker compose --profile s3tables pull -q
ok "Imagenes descargadas"

paso "5/5 Token de LocalStack para la Parte 2 (S3 Tables)"
GUARDAR=1
if [ -s .localstack.env ]; then
  read -rp "  Ya tienes un token guardado. Cambiarlo? [s/N] " RESP
  [[ "$RESP" =~ ^[sS]$ ]] || GUARDAR=0
fi
if [ "$GUARDAR" = 1 ]; then
  echo "  Pega tu Auth Token de https://app.localstack.cloud (no se vera al escribir)."
  echo "  Pulsa Enter sin escribir nada para saltar este paso (solo podras hacer la Parte 1)."
  read -rsp "  Token: " TOKEN; echo
  # Limpia lo que se cuela al pegar: espacios, saltos de linea, comillas o el prefijo de la variable
  TOKEN=$(printf '%s' "$TOKEN" | tr -d "[:space:]\"'")
  TOKEN=${TOKEN#LOCALSTACK_AUTH_TOKEN=}
  if [ -z "$TOKEN" ]; then
    echo "  Saltado. Vuelve a ejecutar ./instalar.sh cuando tengas el token."
    echo; echo "Instalacion terminada (solo Parte 1)."
    exit 0
  fi
  [[ "$TOKEN" == ls-* ]] || fallo "El token debe empezar por 'ls-'."
  (umask 077; printf 'LOCALSTACK_AUTH_TOKEN=%s\n' "$TOKEN" > .localstack.env)
  ok "Token recibido: ${TOKEN:0:7}...${TOKEN: -4}"
  ok "Guardado en .localstack.env (no se sube a GitHub)"
fi

echo "  Comprobando la licencia..."
docker compose down >/dev/null 2>&1 || true
docker compose --profile s3tables up -d --wait s3tables >/dev/null 2>&1 || true
LICENCIA=$(docker logs lab-s3tables 2>&1 | grep -io 'license [^ ]*:[a-z]*' | tail -1)
if awslocal s3tables list-table-buckets >/dev/null 2>&1; then
  ok "Licencia activa (${LICENCIA##*:}) y S3 Tables disponible"
  docker compose --profile s3tables down >/dev/null 2>&1
else
  docker logs lab-s3tables 2>&1 | grep -iE 'licen|reason' | tail -3 >&2
  docker compose --profile s3tables down >/dev/null 2>&1
  fallo "S3 Tables no funciona con ese token. Revisa que tu plan sea Student y ejecuta ./instalar.sh otra vez."
fi

echo
echo "Instalacion terminada. Sigue el README desde el apartado 2."
echo "Si en esta terminal no encuentra 'uv' o 'awslocal', ejecuta:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
