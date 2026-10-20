"""Practica S3 Tables (LocalStack): crear tabla, insertar, consultar y time travel
a traves del endpoint Iceberg REST de S3 Tables. El table bucket y el namespace
se crean antes con `awslocal s3tables` (ver practica_s3tables.sh)."""
import duckdb
import pyarrow as pa
from pyiceberg.catalog import load_catalog

TABLE_BUCKET = "mi-table-bucket"

# En AWS real: uri="https://s3tables.us-east-1.amazonaws.com/iceberg",
# warehouse=<ARN del table bucket> y sin s3.endpoint ni credenciales "test"
catalog = load_catalog(
    "s3tables",
    type="rest",
    uri="http://s3tables.localhost.localstack.cloud:4566/iceberg",
    warehouse=TABLE_BUCKET,
    **{
        "rest.sigv4-enabled": "true",
        "rest.signing-name": "s3tables",
        "rest.signing-region": "us-east-1",
        "s3.endpoint": "http://localhost.localstack.cloud:4566",
        "s3.access-key-id": "test",
        "s3.secret-access-key": "test",
        "s3.region": "us-east-1",
    },
)

print("Namespaces:", catalog.list_namespaces())

# Crear la tabla Iceberg (se recrea en cada ejecucion para empezar limpio)
esquema = pa.schema([
    pa.field("id", pa.int64()),
    pa.field("cliente", pa.string()),
    pa.field("importe", pa.float64()),
])
if catalog.table_exists("ventas.pedidos"):
    catalog.drop_table("ventas.pedidos")
tabla = catalog.create_table("ventas.pedidos", schema=esquema)
print("Tablas en ventas:", catalog.list_tables("ventas"))

# Cada append es un commit -> un snapshot nuevo
tabla.append(pa.table({
    "id": [1, 2, 3], "cliente": ["Ana", "Luis", "Marta"], "importe": [19.99, 5.50, 42.00],
}, schema=esquema))
tabla.append(pa.table({
    "id": [4, 5], "cliente": ["Pablo", "Ana"], "importe": [12.00, 7.25],
}, schema=esquema))

con = duckdb.connect()
con.register("pedidos", tabla.scan().to_arrow())
print("== Total por cliente ==")
print(con.sql("SELECT cliente, SUM(importe) AS total FROM pedidos GROUP BY cliente ORDER BY total DESC"))

print("== Snapshots (time travel) ==")
for s in tabla.snapshots():
    filas = len(tabla.scan(snapshot_id=s.snapshot_id).to_arrow())
    print(s.snapshot_id, s.summary.operation, "filas:", filas)
