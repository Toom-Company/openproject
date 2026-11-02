# Sparkfaktory Proyectos — Despliegue

> **Estado:** preparado, **no publicado**. No se ha modificado Nginx, no se ha hecho push y no hay
> nada expuesto. Los pasos marcados con 🔒 requieren aprobación explícita.

## Piezas

| Elemento | Ubicación |
|---|---|
| Imagen | `sparkfaktory/proyectos:<versión>-sf.<commit>`, compilada desde este fork (`docker/prod/Dockerfile`, target `slim`) |
| Compose de producción | `deploy/sparkfaktory/docker-compose.yml` (proyecto `sparkfaktory-proyectos`) |
| Variables | `deploy/sparkfaktory/.env.example` → `.env` (modo 600, ignorado por git) |
| Nginx (ejemplo) | `deploy/sparkfaktory/nginx/proyectos.sparkfaktory.com.conf.example` |
| Scripts | `deploy/sparkfaktory/scripts/` (`init-env.sh`, `create-admins.sh`, `backup.sh`, `restore.sh`) |

Servicios: `db` (PostgreSQL 17), `cache` (memcached), `seeder` (migraciones y seed, se ejecuta una
vez y termina), `web` (Puma en `127.0.0.1:8090`), `worker` (GoodJob) y `cron`. Todos tienen
`restart: unless-stopped` y límites de memoria. `web` y `db` tienen comprobaciones de salud.

Volúmenes **con nombre explícito**, distintos de los del despliegue de prueba anterior
(`openproject_pgdata` y `openproject_opdata`, que **no se tocan**):

- `sparkfaktory_proyectos_pgdata`
- `sparkfaktory_proyectos_assets`

## 1. Compilar y etiquetar la imagen

Comprueba antes los recursos (`free -m`, `df -h /`, `uptime`). La compilación de Angular necesita
unos 4 GB, así que se usa un builder limitado que no puede afectar a otras aplicaciones:

```bash
cd /root/prod/openproject
docker buildx create --name sf-builder --driver docker-container 2>/dev/null || true
docker buildx inspect --bootstrap sf-builder >/dev/null
docker update --memory 4600m --memory-swap 4600m --cpus 3 buildx_buildkit_sf-builder0

TAG="17.9.6-sf.$(git rev-parse --short HEAD)"
nice -n 10 docker buildx build --builder sf-builder -f docker/prod/Dockerfile --target slim \
  --build-arg BIM_SUPPORT=false \
  --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
  --label org.opencontainers.image.version="$TAG" \
  -t "sparkfaktory/proyectos:$TAG" --load .
```

Comprueba que la imagen ejecuta nuestro código y no la oficial:

```bash
docker run --rm --entrypoint ls "sparkfaktory/proyectos:$TAG" /app/modules/sparkfaktory
docker image inspect -f '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "sparkfaktory/proyectos:$TAG"
```

Se etiqueta siempre con versión y commit. No se usa `latest`.

## 2. Preparar el directorio de despliegue

Se usa un directorio propio, separado del repositorio y del despliegue anterior:

```bash
install -d -m 700 /root/prod/sparkfaktory-proyectos
cp -r /root/prod/openproject/deploy/sparkfaktory/. /root/prod/sparkfaktory-proyectos/
cd /root/prod/sparkfaktory-proyectos
SF_IMAGE="sparkfaktory/proyectos:$TAG" \
SPARKFAKTORY_ADMIN_EMAILS="javier.arias@sparkfaktory.com,hector.perez@sparkfaktory.com,vladimir.moreno@mcwonka.com" \
  scripts/init-env.sh
```

`init-env.sh` genera secretos aleatorios (contraseña de PostgreSQL, `SECRET_KEY_BASE` y clave del
admin inicial) sin mostrarlos. Revisa después `.env`:

- **SMTP**: rellena `OPENPROJECT_SMTP__*` y `OPENPROJECT_MAIL__FROM`. Si prefieres configurarlo
  desde Administración → Correo, borra esas líneas: cuando una variable está definida, el ajuste
  queda bloqueado en la interfaz.
- **Puerto**: `SF_BIND=127.0.0.1:8090`. Comprueba que está libre con `ss -ltn | grep ':8090 '`
  (en la revisión del 02/11/2026 lo estaba).

Valida la configuración:

```bash
docker compose config --quiet && echo "compose OK"
```

## 3. Primer arranque (instalación limpia)

```bash
docker compose up -d db cache
docker compose up seeder            # migraciones + seed; termina con "exit 0"
docker compose up -d web worker cron
docker compose ps                   # web debe quedar "healthy"
curl -fsS http://127.0.0.1:8090/health_checks/default
```

El seed crea los estados, tipos, prioridades, roles, flujos, la plantilla de proyecto y los
ajustes iniciales (título, idioma español, banners ocultos, registro abierto desactivado e inicio
de sesión obligatorio).

## 4. Primeros administradores (creación segura)

```bash
scripts/create-admins.sh
```

- Crea las cuentas de `SPARKFAKTORY_ADMIN_EMAILS` con privilegios completos de administrador.
- Cada una recibe una **clave temporal aleatoria distinta**, que se muestra **una sola vez** en la
  terminal. Hay que entregarla por un canal privado.
- El primer inicio de sesión **obliga a cambiarla**.
- Bloquea la cuenta genérica `admin` del seed.
- Si se pierde una clave temporal, genera una nueva solo para esa cuenta:
  `RESET=true SPARKFAKTORY_ADMIN_EMAILS=persona@sparkfaktory.com scripts/create-admins.sh`.

## 5. DNS y certificado TLS 🔒

1. **DNS**: registro `A` (y `AAAA` si hay IPv6) de `proyectos.sparkfaktory.com` → IP pública del VPS.
   Comprueba la propagación con `dig +short proyectos.sparkfaktory.com`.
2. **Certificado**, con certbot y webroot, sin tocar otras configuraciones:
   ```bash
   install -d /var/www/letsencrypt
   # Publica primero solo el bloque :80 del ejemplo, sirviendo /.well-known/acme-challenge/
   certbot certonly --webroot -w /var/www/letsencrypt -d proyectos.sparkfaktory.com
   ```
3. **Nginx**: copia el ejemplo a `/etc/nginx/sites-available/proyectos.sparkfaktory.com`, enlázalo
   en `sites-enabled`, ejecuta `nginx -t` y después `systemctl reload nginx`. No modifiques los
   sitios existentes.
4. La renovación la hace el temporizador de certbot. Verifícalo con `certbot renew --dry-run`.

`OPENPROJECT_HTTPS=true` y `OPENPROJECT_HOST__NAME=proyectos.sparkfaktory.com` ya están en `.env`.

## 6. Verificación tras publicar

- `https://proyectos.sparkfaktory.com/health_checks/default` responde `PASSED`.
- Inicio de sesión con cada administrador y cambio de clave.
- Correo de prueba desde Administración → Correo → «Enviar correo de prueba».
- Crear un proyecto desde «Plantilla: proyecto estándar» y mover una tarjeta en el Kanban.

## Actualización y reversión

Ver [OPERACION.md](OPERACION.md#actualizar-a-una-nueva-imagen).
