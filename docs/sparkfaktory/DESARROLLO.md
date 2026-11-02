# Sparkfaktory Proyectos — Desarrollo

## Rama y base

- Rama: `sparkfaktory/customization`, creada desde la etiqueta `v17.9.6` de `upstream`
  (`https://github.com/opf/openproject.git`). El remoto propio es `origin`
  (`Toom-Company/openproject`).
- Para actualizar de OpenProject: `git fetch upstream --tags` → `git merge v17.9.x` (o `v18.x`
  cuando esté publicada y se haya validado) → regenerar los overrides de idioma → ejecutar las pruebas.

## Dónde está la personalización

Casi todo está en el plugin `modules/sparkfaktory`, registrado al final de `Gemfile.modules`
porque debe cargarse después del resto de plugins. Fuera del plugin solo hay dos cambios mínimos:

| Fichero | Cambio |
|---|---|
| `lib/redmine/menu_manager/mapper.rb` | `items` y `reorder`, para filtrar y ordenar menús sin redefinir sus entradas |
| `frontend/src/global_styles/openproject.sass` | import de los estilos del plugin |

Estructura del plugin:

```
modules/sparkfaktory/
  lib/open_project/sparkfaktory/
    engine.rb                    registro, middleware, parches y orden de arranque
    customization.rb             módulos y permisos desactivados, acciones retiradas
    disabled_routes.rb           middleware 404 para páginas de instancia excluidas
    navigation.rb                menús: ocultar, renombrar, ordenar y ocultar entradas Enterprise sin licencia
    homescreen.rb                bloques y enlaces del inicio
    task_queries.rb              vistas «Mis tareas», «Sin asignar», «Próximas», «Bloqueadas»
    locale_overrides.rb          carga los overrides de idioma al final del load path
    locale_override_generator.rb genera config/locales/overrides/es.yml
    patches/                     barra lateral de tareas, marca tipográfica, ayuda, seeds, panel de proyecto
  app/components/                widgets de inicio y de panel de proyecto, y estilos
  app/seeders/sparkfaktory.yml   datos iniciales (estados, tipos, flujos, plantilla)
  app/seeders/basic_data/...     guarda el id del estado «Bloqueada»
  app/services/sparkfaktory/     InstanceSetupService y AdminAccountsService
  db/seeds.rb                    ejecuta InstanceSetupService al final de db:seed
  lib/tasks/sparkfaktory.rake    setup, create_admins, generate_locale_overrides
  config/locales/                textos propios (en, es), traducción de seeds y overrides
  spec/                          pruebas
```

### Decisiones técnicas

- **Desactivar sin borrar.** El núcleo referencia `TimeEntry`, `Budget`, `story_points`, la
  exportación Gantt, etc., así que las gemas de esos módulos siguen cargadas. Sus permisos se
  deshabilitan con el `ModuleHandler` oficial, lo que los hace inexistentes para la autorización,
  también para administradores. Además se ocultan de la selección de módulos.
- **Orden de carga.** Los plugins definen permisos dentro de `to_prepare`. Las restricciones se
  aplican en `after_initialize` y se vuelven a registrar en `to_prepare`, para que sigan vigentes
  tras cada recarga en desarrollo.
- **Menús.** Se reconstruyen en cada petición desde una cola de bloques. El plugin añade su bloque
  al final, así que sus cambios siempre se aplican después del núcleo y de los demás plugins.
- **Seeds.** Las traducciones de Crowdin de los seeds se indexan por posición (`item_N`). Por eso
  el plugin no edita `standard.yml`: carga su propio `sparkfaktory.yml` con prefijo
  `seeds.sparkfaktory.*`. `SPARKFAKTORY_STANDARD_SEED=true` vuelve al seed original.
- **Terminología.** «Tareas» se aplica con un fichero de override generado a partir del español
  de Crowdin, con concordancia de artículos y adjetivos frecuentes. Ni los modelos ni la API
  cambian de nombre. En inglés el texto sigue siendo «Work packages».
- **Identidad.** Marca tipográfica basada en el título de la aplicación (`app_title`), con la
  tipografía del sistema y sin recursos externos. Si se sube un logo en Administración → Diseño
  (Enterprise), se muestra ese logo.

## Entorno de desarrollo aislado

El servidor es compartido, así que no se usa `bin/compose` (sus nombres y puertos podrían
colisionar). Se usan contenedores propios, sin puertos publicados:

```bash
docker network create sfdev-net
docker volume create sfdev-bundle; docker volume create sfdev-pgdata
docker run -d --name sfdev-db --network sfdev-net --memory 768m --cpus 1 \
  -e POSTGRES_PASSWORD=sfdev -e POSTGRES_USER=sfdev -v sfdev-pgdata:/var/lib/postgresql/data postgres:17
docker run -d --name sfdev-ruby --network sfdev-net --memory 3500m --memory-swap 3500m --cpus 3 \
  -v /root/prod/openproject:/app -v sfdev-bundle:/usr/local/bundle -w /app \
  -e DATABASE_URL=postgres://sfdev:sfdev@sfdev-db/openproject_dev ruby:4.0.9-trixie sleep infinity
docker exec sfdev-ruby bash -lc 'apt-get update -qq && apt-get install -y -qq postgresql-client; bundle install'
docker exec sfdev-ruby bash -lc 'bin/rails db:create db:migrate'
docker exec -e OPENPROJECT_SEED_LOCALE=es sfdev-ruby bin/rails runner \
  'RootSeeder.new(seed_development_data: false).seed!'
```

En desarrollo, `db:seed` también ejecuta los datos de desarrollo de OpenProject, que dependen del
seed estándar. Por eso se usa `RootSeeder` sin datos de desarrollo, igual que en producción.

### Pruebas

```bash
docker exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sfdev:sfdev@sfdev-db/openproject_test sfdev-ruby \
  bash -lc 'bin/rails db:create db:schema:load && bundle exec rspec modules/sparkfaktory/spec'
```

### Regenerar la terminología

Hay que hacerlo después de cada actualización de OpenProject:

```bash
docker exec sfdev-ruby bin/rails sparkfaktory:generate_locale_overrides
git diff modules/sparkfaktory/config/locales/overrides/es.yml
```

### Recursos

Se trabaja con límites (`--memory` y `--cpus`) y comprobando antes `free -m`, `df -h` y `uptime`.
La imagen se compila con un builder BuildKit propio limitado a 4,6 GB y 3 CPU
(ver [DESPLIEGUE.md](DESPLIEGUE.md)).

### Limpieza del entorno de desarrollo

```bash
docker rm -f sfdev-ruby sfdev-db; docker volume rm sfdev-bundle sfdev-pgdata; docker network rm sfdev-net
docker buildx rm sf-builder
```
