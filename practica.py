"""Practica S3 Tables (local): namespace -> tabla Iceberg -> insertar -> consultar -> time travel."""
import duckdb
import pyarrow as pa
from pyiceberg.catalog import load_catalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError

# En AWS real cambiarias esto por el endpoint de S3 Tables y tus credenciales
catalog = load_catalog(
    "lab",
    type="rest",
    uri="http://localhost:8181",
    **{
        "s3.endpoint": "http://localhost:4566",
        "s3.access-key-id": "test",
        "s3.secret-access-key": "test",
        "s3.region": "us-east-1",
        "s3.path-style-access": "true",
    },
)

# 1. Namespace (igual que en S3 Tables: table bucket -> namespace -> tabla)
try:
    catalog.create_namespace("ventas")
except NamespaceAlreadyExistsError:
    pass

# 2. Crear la tabla (se recrea en cada ejecucion para empezar limpio)
if catalog.table_exists("ventas.pedidos"):
    catalog.drop_table("ventas.pedidos")

lote1 = pa.table({
    "id": pa.array([1, 2, 3], pa.int64()),
    "cliente": ["Ana", "Luis", "Marta"],
    "importe": [19.99, 5.50, 42.00],
})
tabla = catalog.create_table("ventas.pedidos", schema=lote1.schema)

# 3. Insertar datos: cada append es un commit -> un snapshot nuevo
tabla.append(lote1)
tabla.append(pa.table({
    "id": pa.array([4, 5], pa.int64()),
    "cliente": ["Pablo", "Ana"],
    "importe": [12.00, 7.25],
}))

# 4. Consultar con SQL usando DuckDB
con = duckdb.connect()
con.register("pedidos", tabla.scan().to_arrow())
print("== Total por cliente ==")
print(con.sql("SELECT cliente, SUM(importe) AS total FROM pedidos GROUP BY cliente ORDER BY total DESC"))

# 5. Snapshots y time travel
print("== Snapshots ==")
for s in tabla.snapshots():
    print(s.snapshot_id, s.summary.operation, s.summary.additional_properties.get("total-records"))
primero = tabla.snapshots()[0].snapshot_id
print("Filas en el primer snapshot:", len(tabla.scan(snapshot_id=primero).to_arrow()))
print("Filas actuales:", len(tabla.scan().to_arrow()))

# 6. Evolucion de esquema (sin reescribir datos)
from pyiceberg.types import StringType
with tabla.update_schema() as upd:
    upd.add_column("pais", StringType())
print("Esquema nuevo:", tabla.schema())
