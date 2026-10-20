# Práctica Amazon S3 Tables en local

Entorno para practicar **Amazon S3 Tables** (tablas Apache Iceberg gestionadas) en tu ordenador:
gratis, sin sudo y sin tocar una cuenta de AWS.

- **Parte 1 – Iceberg por dentro:** no necesita cuenta. Ves cómo se guardan las tablas (Parquet + metadatos).
- **Parte 2 – S3 Tables:** usa los mismos comandos que en AWS (`aws s3tables ...`) y consultas `SELECT` con **Athena**.
  Necesita un token gratuito de estudiante.

> Copia los comandos **tal cual**, en orden, desde la carpeta del proyecto.

### Chuleta (cuando ya está instalado)

```bash
cd practica-s3tables
docker compose --profile s3tables up -d --wait s3tables   # arrancar S3 Tables
./practica_s3tables.sh                                    # crear table bucket, namespace, tabla y datos
./athena_s3tables.sh                                      # consola Athena: escribe tus SELECT ('salir' para terminar)
./limpiar_s3tables.sh                                     # borrar tabla, namespace y table bucket
docker compose --profile s3tables down                    # parar
```

---

## 0. Requisitos

- Linux o macOS (en Windows, usa WSL).
- **Docker** funcionando sin sudo. Compruébalo:
  ```bash
  docker run --rm hello-world
  ```
  Si da error de permisos, tu usuario no está en el grupo `docker`: pídeselo al profesor.
- **Git**.
- Unos 3 GB libres y conexión a Internet la primera vez.

---

## 1. Instalación (solo la primera vez)

Elige **una** de las dos opciones. Las dos dejan exactamente lo mismo instalado.

### Opción A – Rápida: instalador automático (recomendada)

Ten a mano tu token de LocalStack (cómo conseguirlo: pasos 1 a 3 del [apartado 3.1](#31-consigue-tu-token-solo-la-primera-vez)).
Si aún no lo tienes, puedes instalar igualmente y hacer solo la Parte 1.

```bash
git clone https://github.com/PauLopNun/practica-s3tables.git
cd practica-s3tables
./instalar.sh
```

El instalador:
1. Comprueba Docker, Docker Compose y la red.
2. Instala `uv`, `awslocal` y las librerías de Python (sin sudo).
3. Descarga las imágenes de Docker.
4. **Te pide el token**: pégalo (Ctrl+Shift+V en la terminal) y pulsa Enter. No se ve al pegarlo, es normal;
   después te muestra el principio y el final (`ls-xxxx...xxxx`) para que compruebes que es el tuyo.
   Si pulsas Enter sin pegar nada, se salta este paso.
5. Comprueba que tu licencia es Student y que S3 Tables funciona.

Si todo sale `[OK]`, salta directamente al [apartado 2](#2-parte-1--iceberg-por-dentro-sin-cuenta).
Puedes volver a ejecutar `./instalar.sh` las veces que quieras (por ejemplo, para poner el token más tarde).

Al terminar, en esa misma terminal ejecuta también:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Opción B – Manual: comando a comando

```bash
git clone https://github.com/PauLopNun/practica-s3tables.git
cd practica-s3tables

# uv (gestor de Python) y awslocal (AWS CLI apuntando a LocalStack)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv tool install awscli-local --with awscli

# Librerías de Python del proyecto (versiones fijadas en uv.lock)
uv sync
```

Comprueba que todo está instalado:
```bash
uv --version && awslocal --version && docker compose version
```

---

## 2. Parte 1 – Iceberg por dentro (sin cuenta)

Levanta un S3 local + un catálogo Apache Iceberg (la misma API que usa S3 Tables).

```bash
docker compose up -d --wait
uv run python practica.py
```

Verás: creación de namespace y tabla, inserciones, consulta SQL, *snapshots*, *time travel*
y evolución de esquema. Para ver los ficheros que se han guardado en S3:

```bash
awslocal s3 ls s3://mi-table-bucket --recursive
```

Al terminar:
```bash
docker compose down
```

---

## 3. Parte 2 – S3 Tables con comandos de AWS

### 3.1 Consigue tu token (solo la primera vez)

Cada persona necesita **su propio token**. No compartas el tuyo.

1. Ten activo el **GitHub Student Developer Pack** (https://education.github.com/pack).
2. Entra en https://www.localstack.cloud/localstack-for-students e inicia sesión con **esa cuenta de GitHub**.
3. En https://app.localstack.cloud comprueba que tu plan es **Student** y copia tu **Auth Token** (empieza por `ls-`).
4. Guárdalo en el proyecto. **Si usaste `./instalar.sh` con el token, ya está hecho: salta al 3.2.**
   Para hacerlo a mano (cambia `ls-PEGA-AQUI-TU-TOKEN` por el tuyo):
   ```bash
   echo 'LOCALSTACK_AUTH_TOKEN=ls-PEGA-AQUI-TU-TOKEN' > .localstack.env
   chmod 600 .localstack.env
   ```
   Este fichero está en `.gitignore`: nunca se sube a GitHub.

### 3.2 Ejecutar la práctica

> Si tienes la Parte 1 arrancada, párala antes con `docker compose down` (usan el mismo puerto).

```bash
docker compose --profile s3tables up -d --wait s3tables
docker logs lab-s3tables 2>&1 | grep -i licen
```
La última línea debe terminar en `:student 🔑✅`. Si no, revisa tu token (paso 3.1).

```bash
./practica_s3tables.sh
```

Hace lo siguiente:

| Paso | Comando / herramienta | En AWS real |
|---|---|---|
| Crear table bucket | `awslocal s3tables create-table-bucket` | `aws s3tables create-table-bucket` |
| Crear namespace | `awslocal s3tables create-namespace` | `aws s3tables create-namespace` |
| Crear tabla, insertar, consultar | PyIceberg + DuckDB vía endpoint Iceberg REST | igual, con `https://s3tables.<region>.amazonaws.com/iceberg` |
| Ver la tabla | `awslocal s3tables list-tables` / `get-table` | `aws s3tables list-tables` / `get-table` |

Puedes ejecutar tus propios comandos, por ejemplo:
```bash
awslocal s3tables list-table-buckets
awslocal s3tables list-tables --table-bucket-arn arn:aws:s3tables:us-east-1:000000000000:bucket/mi-table-bucket
```

### 3.3 Consultar con Athena (`SELECT`)

Con la tabla ya creada (paso 3.2), puedes hacer consultas SQL con **Amazon Athena**, igual que en la consola de AWS:

```bash
./athena_s3tables.sh
```

Se abre una **consola**: escribe tu `SELECT` y pulsa Enter. Puedes encadenar todas las consultas que quieras,
usar las flechas ↑/↓ para recuperar las anteriores y escribir `salir` para terminar.

```
athena> SELECT cliente, SUM(importe) AS total FROM pedidos GROUP BY cliente ORDER BY total DESC
Ejecutando (la primera vez tarda unos minutos)... SUCCEEDED
cliente  total
Marta    42.0
Ana      27.24
Pablo    12.0
Luis     5.5

athena> SELECT * FROM pedidos WHERE cliente = 'Ana'
...
athena> salir
```

- Tabla: `pedidos` · columnas: `id`, `cliente`, `importe`.
- Los textos van entre comillas simples: `'Ana'`. El `;` final es opcional.
- Si te equivocas en el SQL, sale `FAILED` y puedes seguir escribiendo.

Ideas para probar:
```sql
SELECT * FROM pedidos ORDER BY importe DESC LIMIT 2
SELECT cliente, COUNT(*) AS pedidos, SUM(importe) AS total FROM pedidos GROUP BY cliente
SELECT MAX(importe) AS maximo, MIN(importe) AS minimo, AVG(importe) AS media FROM pedidos
SELECT cliente, importe, CASE WHEN importe > 15 THEN 'grande' ELSE 'pequeno' END AS tipo FROM pedidos
```

También puedes lanzar una sola consulta sin entrar en la consola:
```bash
./athena_s3tables.sh "SELECT * FROM pedidos WHERE importe > 10"
```

> ⏳ **La primera vez tarda unos 5 minutos** porque LocalStack descarga el motor de Athena (Trino + Hadoop).
> Se guarda en caché (volumen Docker `localstack-cache`) y después cada consulta tarda segundos,
> aunque pares y vuelvas a arrancar.

Cómo funciona por dentro (lo mismo que harías con `aws athena` en AWS real):
```bash
awslocal athena start-query-execution \
  --query-string "SELECT * FROM pedidos" \
  --query-execution-context Catalog=s3tablescatalog/mi-table-bucket,Database=ventas \
  --result-configuration OutputLocation=s3://athena-resultados/
awslocal athena get-query-results --query-execution-id <ID que devuelve el comando anterior>
```
- **Catálogo** = `s3tablescatalog/<nombre del table bucket>` · **Database** = el namespace · **Tabla** = la tabla de S3 Tables.
- Indica catálogo y base de datos en `--query-execution-context` y en el SQL pon solo el nombre de la tabla.
  La forma con el nombre completo (`"s3tablescatalog/mi-table-bucket"."ventas"."pedidos"`) falla en LocalStack.

Probado en LocalStack `2026.10.0` (licencia Student): `GROUP BY`, `WHERE` y `ORDER BY` devuelven los mismos
resultados que DuckDB en el paso 3.2; la consola acepta varias consultas seguidas y sigue tras un error de SQL; primera consulta ≈ 5 min, siguientes ≈ 30 s tras rearrancar el contenedor.

### 3.4 Limpiar y parar

```bash
./limpiar_s3tables.sh
docker compose --profile s3tables down
```
(En AWS real, borrar el table bucket es lo que evita que te sigan cobrando.)

---

## 4. Ejercicios

1. Añade un tercer `append` en `practica.py` y comprueba que aparece un snapshot nuevo.
2. En `practica.py`, rellena la columna `pais` en un lote nuevo y saca las ventas por país con DuckDB.
3. Borra los pedidos de Ana con `tabla.delete("cliente = 'Ana'")` y recupéralos leyendo el snapshot anterior.
4. Parte 2: crea un namespace `marketing` con `awslocal s3tables create-namespace` y una tabla `campanas` desde PyIceberg.
5. Athena: saca con `./athena_s3tables.sh "..."` el pedido de mayor importe y el número de pedidos por cliente.

---

## 5. Problemas frecuentes

| Problema | Solución |
|---|---|
| `uv: command not found` / `awslocal: command not found` | `export PATH="$HOME/.local/bin:$PATH"` (o abre una terminal nueva) |
| `permission denied ... docker.sock` | Tu usuario no está en el grupo `docker` |
| `port is already allocated` (4566) | Hay otra parte arrancada: `docker compose --profile s3tables down` |
| `License activation failed` en los logs | Falta `.localstack.env` o el token no es válido/Student |
| `s3tables service is not included within your LocalStack license` | Tu cuenta no tiene el plan Student activo (paso 3.1) |
| Athena se queda "Ejecutando....." mucho rato | Normal la primera vez (~5 min, descarga el motor). Si falla: `docker logs lab-s3tables 2>&1 \| grep -A5 'Athena error'` |
| Athena: `FAILED` con tabla no encontrada | Ejecuta antes `./practica_s3tables.sh` para crear la tabla |
| Algo se ha quedado raro | `docker compose --profile s3tables down` y vuelve a empezar la parte |

## 6. Qué hay en el repositorio

| Fichero | Para qué sirve |
|---|---|
| `instalar.sh` | Instalador automático (requisitos, dependencias, imágenes y token) |
| `docker-compose.yml` | Servicios: Parte 1 (`s3` + `catalog`) y Parte 2 (perfil `s3tables`) |
| `init/crear-bucket.sh` | Crea el bucket S3 de la Parte 1 al arrancar |
| `practica.py` | Parte 1: Iceberg con PyIceberg + DuckDB |
| `practica_s3tables.sh` | Parte 2: table bucket y namespace con `awslocal s3tables` + ejecuta `practica_s3tables.py` |
| `practica_s3tables.py` | Parte 2: crea la tabla e inserta/consulta por el endpoint Iceberg REST de S3 Tables |
| `athena_s3tables.sh` | Parte 2: consola Athena para hacer `SELECT` |
| `limpiar_s3tables.sh` | Parte 2: borra tablas, namespace y table bucket |
| `pyproject.toml`, `uv.lock`, `.python-version` | Dependencias de Python con versiones fijadas |
| `.localstack.env` | Tu token (lo crea el instalador; **no se sube a GitHub**) |

## Notas

- Versiones fijadas para que todos tengáis lo mismo: LocalStack `2026.10.0` (S3 Tables), LocalStack `4.9` (S3 de la parte 1), Apache Iceberg REST `1.9.1`, Python 3.12 y librerías en `uv.lock`.
- LocalStack ignora el esquema de `aws s3tables create-table --metadata`; por eso la tabla se crea desde PyIceberg.
- Los datos se pierden al hacer `docker compose down`: cada práctica empieza desde cero
  (el volumen `localstack-cache` solo guarda el motor de Athena descargado, no tus tablas).
- Para borrar también esa caché: `docker compose --profile s3tables down -v`.
