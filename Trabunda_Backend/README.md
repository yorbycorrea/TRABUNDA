# Trabunda Backend

## Docker (producción)

El Dockerfile de producción (`Dockerfile.prod`) usa la imagen base de Playwright para incluir las dependencias del sistema necesarias para Chromium/WebKit/Firefox.

```bash
docker build -f Dockerfile.prod -t trabunda-backend .
```

```bash
docker run --rm -p 3000:3000 trabunda-backend
```

### Alternativa si no se usa la base de Playwright

Si prefieres una imagen base de Node estándar, asegúrate de instalar las dependencias del sistema y ejecutar:

```bash
npx playwright install --with-deps
```

### Empaquetar navegadores dentro de la imagen

Si quieres que los navegadores queden dentro de la imagen (en lugar de usar una ruta de caché externa), añade la variable:

```
PLAYWRIGHT_BROWSERS_PATH=0
```

Puedes definirla en el Dockerfile o en `docker-compose.yml` según tu flujo.


## Entornos

- Desarrollo:
  - `flutter run -t lib/main_dev.dart`
- Producción:
  - `flutter build -t lib/main_prod.dart`



# Documentación técnica del repositorio TRABUNDA (inspección estática)

## 1) Arquitectura de carpetas

A nivel alto, el repositorio está dividido en dos productos principales:

- **Trabunda_Backend/**: API REST en Node.js/Express + MySQL.
- **mobile/**: app cliente Flutter (Android/iOS/Desktop), que consume la API.

También hay artefactos de infraestructura y respaldo:

- **build/**: archivos generados de compilación (principalmente Flutter/Windows/CMake).
- SQLs en raíz y backend (`*.sql`, `migrations/`): esquema, backups y migraciones.

### Estructura funcional (backend)

- `Trabunda_Backend/src/index.js`
  - Ensambla la app Express, middlewares, rutas y manejo 404/errores.
- `Trabunda_Backend/src/server.js`
  - Arranque del servidor HTTP y manejo de shutdown.
- `Trabunda_Backend/src/config/env.js`
  - Carga y validación de variables de entorno.
- `Trabunda_Backend/src/db.js`
  - Pool MySQL y selección de DB por entorno (dev/test/prod).
- `Trabunda_Backend/src/routes/`
  - Capa HTTP: auth, users, trabajadores, areas, reportes, health.
- `Trabunda_Backend/src/controllers/`
  - Lógica de autenticación (`auth.controller.js`).
- `Trabunda_Backend/src/services/`
  - Integración con servicio externo de trabajadores (GraphQL) y lógica de lookup/cache.
- `Trabunda_Backend/src/middlewares/`
  - `authMiddleware`, `requireRole`, `asyncHandler`, `errorHandler`.
- `Trabunda_Backend/src/templates/`
  - Plantillas HTML usadas para generación de PDF.

### Estructura funcional (mobile)

- `mobile/lib/core/`
  - Red (`api_client.dart`, token storage), utilidades y UI shared.
- `mobile/lib/data/`
  - Data sources remotos y repositorios concretos.
- `mobile/lib/domain/`
  - Casos de uso y contratos (arquitectura por capas).
- `mobile/lib/features/` y `mobile/lib/menu/`
  - Pantallas, estado y flujo de usuario.
- `mobile/lib/main*.dart`
  - Bootstrap por entorno (`dev/prod`) y routing inicial.

### Patrón de diseño predominante

- **Backend**: estilo por capas tipo **Route → (Controller) → Service → DB**.
- En rutas complejas (ej. `reportes.js`), parte de la lógica de negocio está directamente en la capa Route.
- **Mobile**: enfoque **Clean-ish architecture** (core/data/domain/presentation) con un `ApiClient` central y casos de uso por feature.

---

## 2) Diccionario de endpoints (API)

Base URL configurable por entorno.
Casi todos los endpoints (excepto salud/debug/login) usan Bearer token JWT.

| Método | Ruta | ¿Qué hace (funcional) | Parámetros principales |
|---|---|---|---|
| GET | `/health` | Healthcheck simple del backend. | - |
| GET | `/health/workers` | Verifica conectividad al servicio externo de trabajadores. | usa `WORKERS_HEALTHCHECK_CODIGO` |
| GET | `/debug/workers-url` | Muestra URL configurada del servicio workers (debug). | - |
| GET | `/debug/test-worker?q=` | Prueba lookup de trabajador en modo no producción. | `q` (código/DNI) |
| POST | `/auth/login` | Autentica usuario y devuelve `token` + `refreshToken`. | body: `username`, `password` |
| POST | `/auth/register` | Crea usuario (solo ADMINISTRADOR). | body: `username`, `password`, `nombre`, `roles[]` |
| GET | `/auth/me` | Devuelve perfil y roles del usuario autenticado. | header Bearer |
| POST | `/auth/refresh` | Emite nuevo access token con refresh token válido. | body: `refreshToken` |
| POST | `/auth/logout` | Revoca refresh token actual. | body: `refreshToken` |
| GET | `/users/pickers?roles=...` | Lista usuarios “seleccionables” por roles (admin). | query `roles=PLANILLERO,SANEAMIENTO` |
| GET | `/trabajadores/lookup?q=` | Busca trabajador por código/DNI (cache + fallback servicio externo). | query `q` |
| GET | `/trabajadores/:id` | Obtiene trabajador por código/id. | path `id` |
| GET | `/trabajadores` | Listado no disponible (retorna 501). | - |
| POST | `/trabajadores` | Alta no disponible (501). | - |
| DELETE | `/trabajadores/:id` | Baja no disponible (501). | path `id` |
| PATCH | `/trabajadores/:id/activar` | Activación no disponible (501). | path `id`, body `activo` |
| GET | `/areas` | Lista áreas activas. | query opcional `tipo=APOYO_HORAS|TRABAJO_AVANCE|SANEAMIENTO` |
| POST | `/areas` | Crea área con flags de módulo. | body: `nombre`, flags `es_*`, `activo` |
| PUT | `/areas/:id` | Actualiza nombre/flags/estado de área. | path `id`, body completo de flags |
| PATCH | `/areas/:id/activar` | Activa/desactiva un área. | path `id`, body `activo` |
| GET | `/areas/conteo-rapido` | Lista áreas habilitadas para conteo rápido, ordenadas. | - |
| GET | `/reportes` | Lista reportes con filtros y paginación. | `fecha`,`desde`,`hasta`,`tipo`,`area_id`,`turno`,`activo`,`creador_id`,`q`,`page`,`limit`,`ordenar`,`dir` |
| GET | `/reportes/:id` | Devuelve cabecera de un reporte. | path `id` |
| POST | `/reportes` | Crea cabecera de reporte (tipo, turno, fecha, área según tipo). | body: `fecha`,`turno`,`tipo_reporte`,`area_id?`,`observaciones?` |
| PUT | `/reportes/:id` | Edita cabecera (fecha/turno/área/observaciones según tipo). | path `id`, body parcial |
| PATCH | `/reportes/:id/activar` | Activa/desactiva reporte. | path `id`, body `activo` |
| PATCH | `/reportes/:id/observaciones` | Actualiza observaciones (solo APOYO_HORAS/SANEAMIENTO). | path `id`, body `observaciones` |
| GET | `/reportes/:id/lineas` | Lista líneas (detalle) del reporte. | path `id` |
| POST | `/reportes/:id/lineas` | Crea línea de detalle; valida reglas por tipo y evita duplicados pendientes. | body trabajador + tiempos + área/labores |
| PATCH | `/reportes/lineas/:lineaId` | Actualiza campos de una línea; recalcula estado del reporte. | path `lineaId`, body parcial, `clear` opcional |
| DELETE | `/reportes/lineas/:lineaId` | Elimina línea y recalcula estado del reporte. | path `lineaId` |
| GET | `/reportes/:id/pdf` | Genera PDF del reporte (usa plantilla por tipo). | path `id` |
| GET | `/reportes/apoyo-horas/open` | Abre o crea reporte APOYO_HORAS del usuario para fecha/turno. | query `turno`,`fecha`,`create?` |
| GET | `/reportes/apoyo-horas/pendientes` | Lista reportes/líneas pendientes sin `hora_fin`. | query `horas|hours`,`fecha?`,`turno?` |
| GET | `/reportes/saneamiento/open` | Busca reporte saneamiento del usuario para fecha/turno (continuar/ver). | query `turno`,`fecha?` |
| GET | `/reportes/saneamiento/pendientes` | Lista pendientes de saneamiento (`hora_fin` o `labores` faltantes). | query `horas|hours` |
| GET | `/reportes/conteo-rapido/open` | Abre o crea cabecera de conteo rápido y devuelve items si existen. | query `turno`,`fecha?` |
| POST | `/reportes/conteo-rapido` | Guarda conteo rápido (upsert por área) y cierra reporte. | body `fecha`,`turno`,`items[{area_id,cantidad}]` |
| GET | `/reportes/conteo-rapido/:id` | Devuelve detalle funcional de conteo rápido por áreas. | path `id` |
| GET | `/reportes/conteo-rapido/:id/excel` | Exporta conteo rápido a `.xlsx`. | path `id` |
| GET | `/reportes/trabajo-avance/open` | Busca si ya existe trabajo avance para fecha/turno del usuario. | query `fecha`,`turno` |
| POST | `/reportes/trabajo-avance/start` | Inicia trabajo avance (si no existe). | body `fecha`,`turno` |
| GET | `/reportes/trabajo-avance/:id/resumen` | Resumen de cuadrillas y totales por sección. | path `id` |
| POST | `/reportes/trabajo-avance/:id/cuadrillas` | Crea cuadrilla (recepción/fileteado/apoyo). | body `tipo`,`nombre`,`apoyo_scope?`,`apoyo_de_cuadrilla_id?` |
| GET | `/reportes/trabajo-avance/cuadrillas/:cuadrillaId` | Obtiene detalle de cuadrilla y trabajadores asignados. | path `cuadrillaId` |
| PUT | `/reportes/trabajo-avance/cuadrillas/:cuadrillaId` | Actualiza tiempos y producción kg de cuadrilla. | body `hora_inicio`,`hora_fin`,`produccion_kg` |
| POST | `/reportes/trabajo-avance/cuadrillas/:cuadrillaId/trabajadores` | Agrega trabajador a cuadrilla por lookup (`q`/`codigo`). | body `q` o `codigo` |
| DELETE | `/reportes/trabajo-avance/trabajadores/:id` | Quita trabajador de cuadrilla. | path `id` |
| PUT | `/reportes/trabajo-avance/:reporteId` | Actualiza estado de reporte trabajo avance. | path `reporteId`, body `estado?` |
| GET | `/reportes/test` | Endpoint de prueba. | - |

---

## 3) Flujo de datos (request → procesamiento)

Flujo típico del backend:

1. Entrada HTTP en Express (`index.js`), con `express.json()`.
2. Middlewares: logging global, autenticación JWT (`authMiddleware`) y autorización por rol (`requireRole`) cuando aplica.
3. Route handler (`src/routes/*.js`): valida payload, aplica reglas de negocio por tipo y ejecuta SQL o servicios.
4. Persistencia MySQL (`db.js`) con pool/transacciones.
5. Salida en JSON/PDF/Excel.
6. Manejo de errores por ruta + `errorHandler`.

Flujo de reportes:
**Cabecera de reporte → líneas de trabajo → recalcular estado (ABIERTO/CERRADO) → exportación (PDF/Excel).**

---

## 4) Dependencias críticas

### Backend (imprescindibles)
- `express`: servidor HTTP.
- `mysql2`: acceso a MySQL (pool/transacciones).
- `jsonwebtoken`: emisión/validación JWT.
- `bcryptjs`: hash/validación de contraseñas.
- `dotenv`: carga de configuración.
- `pdfkit` + `playwright`: generación PDF.
- `exceljs`: exportación Excel de conteo rápido.

### Servicios externos críticos
- MySQL (DB principal).
- Servicio GraphQL de trabajadores (`WORKERS_API_URL`).
- Variables sensibles: `JWT_SECRET`, `DB_*`, `DB_NAME_*`, etc.

### Mobile (críticas)
- `flutter_secure_storage` (tokens).
- `ApiClient` centralizado.
- `flutter_dotenv` para ambientes.

---

## 5) Esquema de Base de Datos y Relaciones

### Entidades y propósito
- `users`, `roles`, `user_roles`: identidad, permisos y autorización por rol.
- `reportes`: cabecera de los módulos operativos.
- `lineas_reporte`: detalle operativo por trabajador/actividad/hora.
- `trabajadores`: maestro/cache local de personas.
- `areas`: catálogo transversal con flags por módulo (`es_apoyo_horas`, `es_conteo_rapido`, `es_trabajo_avance`).
- `cuadrillas`: agrupaciones ligadas a reporte (flujo tradicional).
- `trabajo_avance_cuadrillas` + `trabajo_avance_trabajadores`: submodelo específico de Trabajo Avance.
- `conteo_rapido_detalle`: detalle N:N entre reporte de conteo y áreas.
- `refresh_tokens`: almacenamiento de refresh token hasheado y revocable.

### Llaves foráneas y cardinalidades
- `reportes.creado_por_user_id -> users.id` (**1:N** users→reportes).
- `reportes.area_id -> areas.id` (**1:N** areas→reportes, opcional por tipo).
- `lineas_reporte.reporte_id -> reportes.id` (**1:N** reportes→lineas).
- `lineas_reporte.trabajador_id -> trabajadores.id` (**1:N** trabajadores→lineas, con snapshot textual adicional).
- `lineas_reporte.cuadrilla_id -> cuadrillas.id` (**1:N** cuadrillas→lineas, opcional).
- `cuadrillas.reporte_id -> reportes.id` (**1:N** reportes→cuadrillas).
- `conteo_rapido_detalle.reporte_id -> reportes.id` y `area_id -> areas.id` (**N:N** reportes↔areas vía detalle).
- `trabajo_avance_cuadrillas.reporte_id -> reportes.id` (**1:N**).
- `trabajo_avance_cuadrillas.apoyo_de_cuadrilla_id -> trabajo_avance_cuadrillas.id` (auto-relación jerárquica).
- `trabajo_avance_trabajadores.cuadrilla_id -> trabajo_avance_cuadrillas.id` (**1:N**).
- `user_roles.user_id -> users.id` y `user_roles.role_id -> roles.id` (**N:N** users↔roles).
- `refresh_tokens.user_id -> users.id` (**1:N** users→refresh_tokens).

### Restricciones relevantes
- `users.username` único.
- `trabajadores.codigo` único.
- `refresh_tokens.token_hash` único.
- `conteo_rapido_detalle (reporte_id, area_id)` único (upsert idempotente).
- `trabajo_avance_trabajadores (cuadrilla_id, trabajador_codigo)` único.

---

## 6) Estrategia de Manejo de Errores y Códigos HTTP

### Códigos más usados
- **200**: consulta/actualización exitosa.
- **201**: creación exitosa.
- **400**: validación de entrada.
- **401**: no autenticado (token faltante/inválido) o credenciales inválidas.
- **403**: autenticado sin permisos.
- **404**: recurso/ruta no encontrada.
- **409**: conflicto de negocio (duplicidad puntual).
- **500**: error interno.
- **501**: operación no habilitada (ciertos endpoints de trabajadores).

### Estructura JSON de error para mobile
Patrón principal:
```json
{ "error": "mensaje" }
```
Variantes:
```json
{ "error": "Ruta no encontrada", "method": "GET", "url": "/x" }
```
```json
{ "error": "Error consultando reporte", "details": "..." }
```

### Comportamiento en cliente móvil
- `decodeJsonOrThrow` extrae `error` y eleva excepción de dominio.
- Login traduce `401/403` a credenciales inválidas y `404` a ruta inexistente.
- Red/SSL/timeout se normalizan a: `network_timeout`, `network_unreachable`, `ssl_error`, `bad_response`.

---

## 7) Seguridad y Ciclo de Vida de Tokens

### Access Token
- Emitido en `/auth/login` con `sub`, `username`, `roles`.
- Firmado con `JWT_SECRET`.
- Expira según `JWT_EXPIRES_IN` (fallback: **12h**).

### Refresh Token
- Generado criptográficamente.
- Persistido como hash SHA-256 en `refresh_tokens` (no texto plano).
- Expira por `REFRESH_TOKEN_EXPIRES_DAYS` (fallback: **30 días**).
- `/auth/refresh`: valida hash, revocación, expiración y usuario activo; devuelve nuevo access token.
- `/auth/logout`: revoca token (`revoked_at`).

### Protección de rutas
- `authMiddleware`: valida Bearer JWT y monta `req.user`.
- `requireRole(...roles)`: autoriza por rol.
- Regla adicional en múltiples rutas: no-admin solo puede acceder a sus propios recursos.

---

## 8) Lógica de Sincronización y Cache

### Lookup de trabajadores (backend)
1. Entra `q` (código o DNI).
2. Se detecta tipo de búsqueda.
3. Se intenta resolver desde tabla local `trabajadores`.
4. Si hay hit, responde rápido desde cache.
5. En búsquedas por DNI, si el cache está antiguo (>7 días), se refresca en background contra GraphQL.
6. Si no hay hit y aplica, consulta `WORKERS_API_URL`, hace upsert local y retorna.

### Si GraphQL falla
- El backend retorna errores de dominio (`TRABAJADOR_GQL_ERROR`, `TRABAJADOR_NO_ENCONTRADO`) y códigos HTTP de error según endpoint (404/5xx/502).
- Si hay cache local utilizable, la operación puede continuar sin depender del servicio externo.

### Manejo móvil sin conexión
- `ApiClient` aplica timeout y mapea errores de red (`network_timeout`, `network_unreachable`, `ssl_error`).
- La capa auth muestra mensajes amigables al usuario.
- Los tokens se conservan en `flutter_secure_storage`.
- No se observa una cola offline/sincronización diferida de reportes; el flujo de negocio depende de backend en línea.

---

## 9) Archivos de documentación entregados

- `README.md` (documentación completa, secciones 1 a 8)
- `TRABUNDA_Documentacion_Tecnica.pdf` (versión PDF del mismo contenido)
