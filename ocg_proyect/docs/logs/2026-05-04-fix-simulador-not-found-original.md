# Fix simulador NOT_FOUND de imagen original + simplificación de región manual

Fecha: 2026-05-04

## Problema reportado

En validación humana Android del simulador se confirmó:

- la cámara funciona;
- la foto se toma correctamente;
- la imagen sí se sube a Firebase Storage;
- pero al intentar **Generar con IA** aparece un error relacionado con **Imagen original** y `NOT_FOUND`.

Además, el flujo mostraba controles técnicos confusos para el admin:

- `Ajustar región manualmente`
- sliders `X / Y / W / H`

## Decisión de producto sobre región manual

Se decidió **sacar del flujo principal** todo el ajuste técnico manual de región.

La región detectada por ML Kit:

- **se sigue guardando internamente** en `detectedRegion`;
- **se puede seguir usar como metadata** del proceso;
- **no se expone al admin/doctora** como sliders técnicos en el flujo principal.

En la UI se reemplazó por un mensaje amigable:

- **“La foto fue analizada automáticamente para orientar la simulación.”**

## Causa raíz exacta del NOT_FOUND

La causa raíz principal sí era un **mismatch de IDs** entre Storage y Firestore.

### Antes del fix

En Flutter se hacía esto:

1. se generaba un `simulationId` temporal para Storage:
   - `sim_${DateTime.now().microsecondsSinceEpoch}`
2. con ese id se subía la imagen a:
   - `simulations/{patientId}/{simulationIdTemporal}/original.jpg`
3. luego `createDraftSimulation()` creaba el documento Firestore con:
   - `ref.doc()`
   - o sea, **otro id distinto**
4. más tarde, al tocar **Generar con IA**, el callable recibía el **id del documento Firestore**, no el id temporal usado en Storage

Resultado:

- `originalPath` quedaba apuntando a un path de Storage con un id;
- la simulación Firestore tenía otro id;
- el sistema era difícil de auditar y podía terminar con errores `NOT_FOUND` según el momento y la ruta usada por generación.

Aunque la imagen sí subía, el flujo quedaba **desalineado** entre:

- documento Firestore,
- carpeta Storage,
- callable,
- `simulationId` visible en estado.

## Solución aplicada

### 1) Unificación del `simulationId`

Se corrigió `createDraftSimulation()` para aceptar `simulationId` opcional.

Ahora el mismo id se reutiliza para:

- documento Firestore,
- carpeta Storage,
- `originalPath`,
- callable `generateSmileSimulation`,
- `resultPath` esperado.

### 2) Logs de diagnóstico seguros

Se agregaron logs controlados en Flutter y Functions para auditar:

#### Flutter

- `patientId`
- `localSimulationId`
- `originalPath`
- `draft.id`
- `simulationId` enviado al generate

#### Functions

- `patientId`
- `simulationId`
- `originalPath`
- bucket name en el callable
- punto exacto de falla:
  - paciente inexistente
  - simulación inexistente
  - `originalPath` vacío
  - descarga storage fallida

### 3) Mensaje amigable para admin

Si falla la descarga de la imagen original o Storage devuelve `not found`, ahora el mensaje esperado es:

- **“No se encontró la imagen original de esta simulación. Toma la foto nuevamente o crea una nueva simulación.”**

Ya no debe quedar solo `NOT_FOUND` crudo como mensaje visible.

### 4) Functions descargan desde `originalPath` guardado

Se reforzó y probó que el core descarga desde el `originalPath` persistido en Firestore y no desde una ruta reconstruida a ciegas.

## App Check

No se desactivó App Check.

Conclusión actual:

- los warnings de App Check siguen siendo relevantes para el entorno debug;
- **no** se tocaron reglas ni seguridad;
- el hallazgo principal corregido en este fix fue el desalineamiento de `simulationId` y la UX técnica confusa;
- si en pruebas futuras App Check sigue afectando debug, el paso correcto será humano/configuracional en Firebase, no un bypass desde código.

## Cómo revalidar en Android real

1. Instalar APK actualizado.
2. Ir a paciente → tab Simulador.
3. Tocar **Tomar foto**.
4. Aceptar la foto.
5. Confirmar:
   - aparece el borrador,
   - aparece **Generar con IA**,
   - no aparecen sliders `X/Y/W/H`,
   - aparece el mensaje amigable de análisis automático.
6. Escribir notas opcionales.
7. Tocar **Generar con IA**.
8. Observar:
   - si falta API key: mensaje claro ya conocido;
   - si hay problema real de imagen original: mensaje amigable, no `NOT_FOUND` crudo.
9. Revisar logs nuevos para confirmar:
   - `localSimulationId == draft.id == simulationId enviado al callable`
   - `originalPath` consistente.

## Validación esperada después del fix

- El admin ya no ve controles técnicos de región manual.
- La región detectada sigue guardándose internamente.
- El flujo mantiene visible el botón **Generar con IA** con draft válido.
- Firestore y Storage quedan alineados por el mismo `simulationId`.
- Si ocurre un problema real de imagen original, el mensaje para el admin es entendible.
