# Práctica Amazon S3 Tables en local

Entorno para practicar **Amazon S3 Tables** (tablas Apache Iceberg gestionadas) en tu ordenador:
gratis, sin sudo y sin tocar una cuenta de AWS.

- **Parte 1 – Iceberg por dentro:** no necesita cuenta. Ves cómo se guardan las tablas (Parquet + metadatos).
- **Parte 2 – S3 Tables:** usa los mismos comandos que en AWS (`aws s3tables ...`). Necesita un token gratuito de estudiante.

> Copia los comandos **tal cual**, en orden, desde la carpeta del proyecto.

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

```bash
git clone https://github.com/<USUARIO>/practica-s3tables.git
cd practica-s3tables

# uv (gestor de Python) y awslocal (AWS CLI apuntando a LocalStack)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
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
4. Guárdalo en el proyecto (cambia `ls-PEGA-AQUI-TU-TOKEN` por el tuyo):
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

### 3.3 Limpiar y parar

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

---

## 5. Problemas frecuentes

| Problema | Solución |
|---|---|
| `uv: command not found` / `awslocal: command not found` | `source $HOME/.local/bin/env` (o abre una terminal nueva) |
| `permission denied ... docker.sock` | Tu usuario no está en el grupo `docker` |
| `port is already allocated` (4566) | Hay otra parte arrancada: `docker compose --profile s3tables down` |
| `License activation failed` en los logs | Falta `.localstack.env` o el token no es válido/Student |
| `s3tables service is not included within your LocalStack license` | Tu cuenta no tiene el plan Student activo (paso 3.1) |
| Algo se ha quedado raro | `docker compose --profile s3tables down` y vuelve a empezar la parte |

## Notas

- Versiones fijadas para que todos tengáis lo mismo: LocalStack `2026.10.0` (S3 Tables), LocalStack `4.9` (S3 de la parte 1), Apache Iceberg REST `1.9.1`, Python 3.12 y librerías en `uv.lock`.
- LocalStack ignora el esquema de `aws s3tables create-table --metadata`; por eso la tabla se crea desde PyIceberg.
- Los datos se pierden al hacer `docker compose down`: cada práctica empieza desde cero.
