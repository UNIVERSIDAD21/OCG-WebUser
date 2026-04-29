# Checklist — iOS Push Setup (externo a Borlty)

## Apple Developer
- [ ] Tener Apple Developer Account activa.
- [ ] Entrar a Certificates, Identifiers & Profiles.
- [ ] Registrar o verificar el **Bundle ID** definitivo.
- [ ] Activar **Push Notifications** en el App ID.
- [ ] Activar **Background Modes / Remote notifications** si aplica.
- [ ] Crear **APNs Auth Key**.
- [ ] Descargar el archivo `.p8`.
- [ ] Copiar y guardar el **Key ID**.
- [ ] Copiar y guardar el **Team ID**.

## Firebase
- [ ] Registrar la app iOS en Firebase con el Bundle ID correcto.
- [ ] Subir la **APNs Auth Key** a Firebase Cloud Messaging.
- [ ] Verificar que la app iOS quede asociada al proyecto Firebase correcto.
- [ ] Descargar `GoogleService-Info.plist`.
- [ ] Colocarlo en `ios/Runner/`.

## Xcode / proyecto iOS
- [ ] Abrir `ios/Runner.xcworkspace` en Xcode.
- [ ] Revisar **Signing & Capabilities**.
- [ ] Seleccionar el Team correcto.
- [ ] Confirmar capability **Push Notifications**.
- [ ] Confirmar capability **Background Modes > Remote notifications**.
- [ ] Verificar deployment target y firma.

## Variables / configuración
- [ ] Configurar backend/Firebase con el entorno correcto para iOS push.
- [ ] Confirmar que Android siga funcionando.

## Prueba real
- [ ] Tener un iPhone real disponible.
- [ ] Instalar la app en el iPhone.
- [ ] Aceptar permisos de notificaciones.
- [ ] Validar token FCM en iOS.
- [ ] Probar foreground.
- [ ] Probar background.
- [ ] Probar app cerrada.
- [ ] Probar tap y navegación interna.
