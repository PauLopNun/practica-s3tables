#!/bin/bash
cd "$(dirname "$0")"
# Borra tablas, namespace y table bucket (en AWS real es lo que evita cobros)
ARN=arn:aws:s3tables:us-east-1:000000000000:bucket/mi-table-bucket
for t in $(awslocal s3tables list-tables --table-bucket-arn $ARN --query 'tables[].name' --output text 2>/dev/null); do
  awslocal s3tables delete-table --table-bucket-arn $ARN --namespace ventas --name "$t"
done
awslocal s3tables delete-namespace --table-bucket-arn $ARN --namespace ventas 2>/dev/null
awslocal s3tables delete-table-bucket --table-bucket-arn $ARN 2>/dev/null
awslocal s3tables list-table-buckets
