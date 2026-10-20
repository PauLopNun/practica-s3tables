#!/bin/bash
# Practica S3 Tables con los mismos comandos que en AWS (awslocal -> LocalStack).
# En AWS real basta con cambiar `awslocal` por `aws`.
set -e
cd "$(dirname "$0")"

if [ ! -s .localstack.env ]; then
  echo "ERROR: falta el fichero .localstack.env con tu token (mira el README, paso 3)." >&2
  exit 1
fi
if ! awslocal s3tables list-table-buckets >/dev/null 2>&1; then
  echo "ERROR: LocalStack S3 Tables no responde. Arrancalo con:" >&2
  echo "  docker compose --profile s3tables up -d --wait s3tables" >&2
  echo "y revisa la licencia con: docker logs lab-s3tables | grep -i licen" >&2
  exit 1
fi

ARN=arn:aws:s3tables:us-east-1:000000000000:bucket/mi-table-bucket
echo "== 1. Crear table bucket y namespace"
# "|| true": si ya existen de una ejecucion anterior, se reutilizan
awslocal s3tables create-table-bucket --name mi-table-bucket || true
awslocal s3tables create-namespace --table-bucket-arn "$ARN" --namespace ventas || true
awslocal s3tables list-namespaces --table-bucket-arn "$ARN"

echo "== 2. Crear tabla, insertar datos y consultar (PyIceberg)"
uv run python practica_s3tables.py

echo "== 3. Ver la tabla con la API de S3 Tables"
awslocal s3tables list-tables --table-bucket-arn "$ARN" --query 'tables[].{nombre:name,arn:tableARN}'
awslocal s3tables get-table --table-bucket-arn "$ARN" --namespace ventas --name pedidos \
  --query '{tabla:name,formato:format,metadata:metadataLocation}'
