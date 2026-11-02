# Sparkfaktory Proyectos — Alcance

Herramienta interna para organizar proyectos, equipos, tareas y reuniones, publicada en
`proyectos.sparkfaktory.com`. Es un fork de OpenProject que conserva su stack y su arquitectura.
No hay sistemas paralelos de usuarios, proyectos ni tareas: todo usa los modelos, permisos y
vistas nativos.

## Base

- **OpenProject v17.9.6**, la última versión estable publicada (30/10/2026). La rama `dev` (18.1.0)
  y `release/18.0` no están publicadas, así que se descartan para producción.
- La rama de trabajo es `sparkfaktory/customization`, creada desde la etiqueta `v17.9.6`. `dev` no tenía cambios locales.
- Antes de cambiar de base se comprobó en el código de la 17.9.6 que todas las funciones del alcance
  existen y **no requieren Enterprise**: tableros por estado, reuniones recurrentes, plantillas de
  proyecto, calendario, wiki y vista global de wikis.

## Funciones conservadas y cómo se cubren

| Necesidad | Implementación nativa |
|---|---|
| Proyectos: crear, editar, archivar, subproyectos | Proyectos de OpenProject |
| Nombre, descripción, estado general | Campos nativos del proyecto |
| Fechas del proyecto | Atributos de proyecto «Fecha de inicio» y «Fecha de fin» (tipo fecha, para todos los proyectos) |
| Equipos | Grupos nativos añadidos como miembros del proyecto |
| Roles por proyecto | Roles **Administrador**, **Líder** y **Miembro** (más los internos No miembro y Anónimo) |
| Plantillas | Proyecto plantilla «Plantilla: proyecto estándar», con Kanban, vistas, wiki, tareas de ejemplo y reunión semanal |
| Panel del proyecto | Resumen con descripción, estado, **widget de tareas** (por estado, por responsable, vencidas y próximas), reuniones, miembros, subproyectos y atributos |
| Tareas y subtareas | Paquetes de trabajo de tipo «Tarea» (y «Hito»), con jerarquía |
| Responsable, prioridad, fechas | Asignado, prioridad (Baja, Normal, Alta, Urgente), inicio y vencimiento |
| Comentarios, menciones, adjuntos, historial | Actividad, menciones y adjuntos nativos |
| Dependencias sencillas | Relaciones (precede/sigue, relacionada…) |
| Lista y Kanban | Lista de tareas y tablero por estado (módulo Tableros) |
| Filtros | Filtros nativos por proyecto, responsable, estado, prioridad y fechas |
| Sin asignar, vencidas, próximas, bloqueadas | Vistas predefinidas en la barra lateral de tareas |
| «Mis tareas» | Entrada principal: tareas abiertas asignadas a mí o a mis grupos, agrupadas por proyecto |
| Reuniones puntuales y recurrentes, agenda, participantes, acuerdos | Módulo Reuniones (elementos de agenda y resultados) |
| Vincular tareas con reuniones | Elementos de agenda con tarea vinculada |
| Calendario | Módulo Calendario (entregas). Las reuniones tienen su propia vista y exportación iCal |
| Documentación | Wiki de cada proyecto, más la vista global «Documentación» (índice de wikis) |
| Notificaciones | Centro de notificaciones y correo nativos |
| Correo | SMTP por variables de entorno o desde Administración → Correo |

### Estados iniciales

| Estado | Cerrado | Por defecto |
|---|---|---|
| Pendiente | no | sí |
| En progreso | no | |
| Bloqueada | no | |
| En revisión | no | |
| Completada | **sí** | |

Solo «Completada» cuenta como trabajo terminado. Los estados se siguen configurando en
Administración → Tareas → Estados. Los flujos de trabajo permiten todas las transiciones a los
roles Miembro, Líder y Administrador, y se pueden restringir por rol en Administración → Flujo
de trabajo. Al mover una tarjeta en el Kanban se cambia el estado por la API, que valida el
flujo y los permisos en el servidor.

### Roles

- **Administrador** (de proyecto): todos los permisos del proyecto. Es el rol que recibe quien crea un proyecto.
- **Líder**: igual que Administrador, salvo archivar el proyecto, elegir módulos y gestionar tipos y campos personalizados.
- **Miembro**: crea y actualiza tareas, comenta, adjunta, usa tableros, calendario, reuniones y wiki.
- Los **administradores de la instancia** (`admin = true`) gestionan usuarios, grupos, roles,
  estados, flujos, SMTP y la configuración general.

## Navegación

Navegación principal: **Inicio · Mis tareas · Proyectos · Calendario · Reuniones · Documentación ·
Administración** (la última solo para administradores).

- *Calendario* y *Documentación* son índices globales de los calendarios y las wikis de los
  proyectos accesibles. Para crear un elemento nuevo se elige el proyecto desde la propia vista.
- *Reuniones* es la lista global de las reuniones de los proyectos accesibles.
- Dentro de cada proyecto el orden es: Resumen, Tareas, Tableros (Kanban), Calendario,
  Reuniones, Wiki, Miembros y Configuración (según permisos).

El inicio muestra datos reales y filtrados por permisos (`WorkPackage.visible`, `Project.visible`):

- contadores de mis tareas abiertas, mis vencidas, tareas bloqueadas y tareas que vencen en 7 días;
- próximas entregas;
- proyectos accesibles;
- próximas reuniones y proyectos favoritos.

## Funciones desactivadas

Se desactivan con mecanismos de servidor, no con CSS:

1. **Módulos de proyecto** deshabilitados con `OpenProject::Plugins::ModuleHandler`, el mismo
   mecanismo que usa la opción oficial `disabled_modules`. Sus permisos dejan de existir, así que
   no se pueden conceder ni usar por interfaz, URL ni API, tampoco siendo administrador. Además
   desaparecen de la lista de módulos seleccionables.
2. **Permisos sueltos** deshabilitados y **acciones de controlador** retiradas de permisos conservados.
3. **Rutas de instancia** que solo comprueban `admin?` responden **404** mediante un middleware.
4. **Menús** reducidos. Las entradas de funciones Enterprise sin licencia se ocultan en lugar de mostrar promoción.
5. **Datos iniciales** propios: sin proyectos demo de Scrum, sin fases, sin tipos ágiles y sin actividades de horas.

| Función | Mecanismo |
|---|---|
| Presupuestos y costes | módulos `budgets`, `costs` (permisos); `/cost_reports`, `/cost_types`, `/admin/costs*` → 404 |
| Registro de horas | módulo `costs`; temporizador y `/my/time-tracking` retirados; actividades de tiempo en admin → 404 |
| Gantt | módulo `gantt` oculto; `/gantt` y `/projects/*/gantt` → 404 |
| Recursos y capacidad | módulos `resource_management`, `team_planner_view` |
| Scrum, sprints, puntos de historia, burndown | módulo `backlogs`; `/admin/backlogs` → 404; tipos Épica, Historia de usuario y Funcionalidad no se crean |
| Versiones y roadmap | permisos `manage_versions` y `assign_versions` deshabilitados; roadmap retirado de `view_work_packages` |
| Portafolios, programas, fases y gates | permisos `add_portfolios`, `add_programs` y `*_project_phases`; asistente de iniciación retirado |
| BIM | módulo `bim` (además, la imagen se compila con `BIM_SUPPORT=false`) |
| Foros y noticias | módulos `forums`, `news`; `/news` → 404 |
| Integraciones externas | GitHub, GitLab, repositorios SCM, almacenamiento de archivos (Nextcloud/OneDrive), webhooks; módulo Documentos |
| Promociones Enterprise | `ee_hide_banners`, bloques de inicio de comunidad y venta retirados, menú de ayuda reducido, `/admin/enterprise_trial` → 404, insignia de versiones desactivada |

El código de estos módulos **no se ha borrado**: el núcleo depende de `costs`, `budgets`,
`backlogs` y `gantt` en modelos, API y migraciones. Se pueden reactivar sin recompilar con
`SPARKFAKTORY_REENABLE_MODULES`.

## Enterprise

No se usan ni se falsean tokens. Las funciones Enterprise que el alcance no necesita (plantillas
de reunión, planificador de equipo, portafolios, SSO, campos personalizados en Kanban, etc.)
siguen sin licencia y sus menús se ocultan. Ninguna función requerida depende de Enterprise.

## Fuera de alcance

No hay chat interno ni gestor documental nuevo. La documentación se hace en la wiki de cada
proyecto.
