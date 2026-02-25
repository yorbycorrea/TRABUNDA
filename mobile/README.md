# mobile

Configuración de `API_BASE_URL` con `--dart-define`.

## Ejecutar en desarrollo (Android Emulator)

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Ejecutar en release (API productiva)

```bash
flutter run --release --dart-define=API_BASE_URL=https://api.tudominio.com
```

## Build web en release

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.tudominio.com
```

## iOS Simulator (localhost de tu máquina)

```bash
flutter run -d ios --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

## iOS dispositivo físico (misma red local)

Reemplaza `192.168.1.50` por la IP LAN de tu máquina:

```bash
flutter run -d <IOS_DEVICE_ID> --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

## Notas

- `API_BASE_URL` es obligatoria.
- Debe usar esquema `http` o `https`.
- Si falta o es inválida, la app falla temprano con `StateError`.
