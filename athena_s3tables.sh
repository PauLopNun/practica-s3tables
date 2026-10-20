#!/bin/bash
# Consultas SQL con Athena sobre las tablas de S3 Tables (catalogo s3tablescatalog/<table bucket>).
# Uso:
#   ./athena_s3tables.sh                 -> consola interactiva: escribes el SELECT y pulsas Enter
#   ./athena_s3tables.sh "SELECT ..."    -> ejecuta una sola consulta
# En AWS real: cambia `awslocal` por `aws` y usa un bucket de resultados tuyo.
cd "$(dirname "$0")"

CONTEXTO="Catalog=s3tablescatalog/mi-table-bucket,Database=ventas"

consulta() {
  local SQL=$1 ID ESTADO
  ID=$(awslocal athena start-query-execution --query-string "$SQL" \
    --query-execution-context "$CONTEXTO" \
    --result-configuration OutputLocation=s3://athena-resultados/ \
    --query QueryExecutionId --output text) || return 1

  # La primera vez LocalStack descarga el motor de Athena: puede tardar ~5 minutos
  echo -n "Ejecutando (la primera vez tarda unos minutos)"
  for i in $(seq 1 200); do
    ESTADO=$(awslocal athena get-query-execution --query-execution-id "$ID" --query QueryExecution.Status.State --output text)
    case "$ESTADO" in SUCCEEDED|FAILED|CANCELLED) break ;; esac
    echo -n "."; sleep 3
  done
  echo " $ESTADO"

  if [ "$ESTADO" != SUCCEEDED ]; then
    echo "La consulta ha fallado (revisa el SQL). Detalle: docker logs lab-s3tables 2>&1 | grep -A5 'Athena error'" >&2
    return 1
  fi
  awslocal athena get-query-results --query-execution-id "$ID" \
    --query 'ResultSet.Rows[*].Data[*].VarCharValue' --output text | column -t -s $'\t'
}

if ! awslocal s3tables list-table-buckets >/dev/null 2>&1; then
  echo "ERROR: LocalStack S3 Tables no responde. Arrancalo con:" >&2
  echo "  docker compose --profile s3tables up -d --wait s3tables" >&2
  exit 1
fi
awslocal s3 mb s3://athena-resultados >/dev/null 2>&1 || true

if [ -n "$1" ]; then
  echo "SQL: $1"
  consulta "$1"
  exit $?
fi

echo "Consola Athena - catalogo s3tablescatalog/mi-table-bucket, base de datos ventas"
echo "Tabla: pedidos (columnas: id, cliente, importe)"
echo "Escribe un SELECT y pulsa Enter. Flechas arriba/abajo = historial. 'salir' para terminar."
echo "Ejemplo: SELECT * FROM pedidos WHERE importe > 10"
HISTFILE=.athena_historial; history -r "$HISTFILE" 2>/dev/null
while true; do
  read -erp "athena> " SQL || { echo; break; }
  SQL=$(echo "$SQL" | sed 's/^[[:space:]]*//; s/[[:space:];]*$//')
  [ -z "$SQL" ] && continue
  case "${SQL,,}" in salir|exit|quit) break ;; esac
  history -s "$SQL"; history -w "$HISTFILE"
  consulta "$SQL"
  echo
done
