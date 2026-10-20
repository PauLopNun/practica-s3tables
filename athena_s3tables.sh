#!/bin/bash
# Consulta SQL con Athena sobre las tablas de S3 Tables (catalogo s3tablescatalog/<table bucket>).
# Uso: ./athena_s3tables.sh ["SELECT ..."]   (sin argumento lanza una consulta de ejemplo)
# En AWS real: cambia `awslocal` por `aws` y usa un bucket de resultados tuyo.
set -e
cd "$(dirname "$0")"

SQL=${1:-"SELECT cliente, SUM(importe) AS total FROM pedidos GROUP BY cliente ORDER BY total DESC"}
CONTEXTO="Catalog=s3tablescatalog/mi-table-bucket,Database=ventas"

awslocal s3 mb s3://athena-resultados >/dev/null 2>&1 || true
echo "SQL: $SQL"
ID=$(awslocal athena start-query-execution --query-string "$SQL" \
  --query-execution-context "$CONTEXTO" \
  --result-configuration OutputLocation=s3://athena-resultados/ \
  --query QueryExecutionId --output text)

# La primera vez LocalStack descarga el motor de Athena: puede tardar ~5 minutos
echo -n "Ejecutando (la primera vez tarda unos minutos)"
for i in $(seq 1 200); do
  ESTADO=$(awslocal athena get-query-execution --query-execution-id "$ID" --query QueryExecution.Status.State --output text)
  case "$ESTADO" in SUCCEEDED|FAILED|CANCELLED) break ;; esac
  echo -n "."; sleep 3
done
echo " $ESTADO"

if [ "$ESTADO" != SUCCEEDED ]; then
  echo "La consulta ha fallado. Detalle en: docker logs lab-s3tables 2>&1 | grep -A5 'Athena error'" >&2
  exit 1
fi
awslocal athena get-query-results --query-execution-id "$ID" \
  --query 'ResultSet.Rows[*].Data[*].VarCharValue' --output text | column -t -s $'\t'
