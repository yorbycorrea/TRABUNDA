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