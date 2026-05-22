# BLOQUE 03 - UI admin de configuracion por tratamiento

## Objetivo

Convertir el flujo admin en un proceso paso a paso con defaults inteligentes y configuracion especifica por tratamiento.

El admin debe poder seleccionar que quiere simular antes de llamar a la IA.

## Estado actual

`PatientSimulatorTab` permite:

- tomar foto;
- subir desde galeria;
- crear draft;
- abrir historial.

`SimulatorScreen` muestra:

- foto original;
- boton `Generar con IA`;
- notas clinicas;
- estado;
- comparador si hay resultado.

Problema:

- El tratamiento sale de `widget.patient.tipoTratamiento`.
- No hay selector real de los 8 tratamientos objetivo.
- No hay parametros por tratamiento.
- El boton de tomar foto aparece antes de configurar el caso.

## Archivos a tocar

- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `test/features/simulator/simulator_mobile_flow_test.dart`
- `test/features/simulator/simulator_provider_test.dart`

Archivos nuevos sugeridos:

- `lib/features/simulator/domain/dental_treatment_profile.dart`
- `lib/features/simulator/presentation/widgets/treatment_profile_selector.dart`
- `lib/features/simulator/presentation/widgets/doctor_config_form.dart`

## Perfiles en Flutter

Crear una fuente local de perfiles, sincronizada con backend:

```dart
class DentalTreatmentProfile {
  final String id;
  final String label;
  final String description;
  final String defaultVisualGoal;
  final Map<String, dynamic> defaultConfig;
}
```

IDs:

```text
metal_braces
esthetic_braces
clear_aligners
whitening
veneers
smile_design
palatal_expander
retainer
```

## Flujo admin nuevo

### Paso 1 - Tratamiento

El admin elige:

- Brackets metalicos.
- Brackets esteticos.
- Alineadores transparentes.
- Blanqueamiento dental.
- Carillas / vinillas.
- Diseno de sonrisa.
- Expansor de paladar.
- Retenedor post-tratamiento.

Default sugerido:

- Si paciente tiene `TreatmentType.alineadores`, seleccionar `clear_aligners`.
- Si `TreatmentType.retenedores`, seleccionar `retainer`.
- Si `TreatmentType.estetico`, seleccionar `esthetic_braces`.
- Si `TreatmentType.convencional` o `autoligado`, seleccionar `metal_braces`.
- Si no hay dato, seleccionar `smile_design`.

### Paso 2 - Parametros

Mostrar formulario dinamico segun perfil.

Parametros minimos:

- `arch`: upper | lower | both
- `severity`: mild | moderate | severe
- `naturalness`: conservative | balanced | cosmetic

Por perfil:

- `metal_braces`: `ligatureColor`, `archwireVisibility`
- `esthetic_braces`: `material`, `ligatureStyle`, `wireStyle`
- `clear_aligners`: `attachments`, `alignerVisibility`
- `whitening`: `shadeIntensity`
- `veneers`: `shapeStyle`, `targetShade`, `incisalLength`
- `smile_design`: `smileStyle`, `alignmentLevel`, `targetShade`
- `palatal_expander`: `expanderType`, `photoType`
- `retainer`: `retainerType`, `visibility`

Usar controles simples:

- `DropdownButtonFormField` o segmented controls.
- Chips para opciones cortas.
- No convertirlo en prompt libre.

### Paso 3 - Foto

Despues de seleccionar tratamiento y parametros:

- Tomar foto.
- Subir desde galeria.

La foto debe crear draft con:

- `treatmentProfileId`
- `visualGoal`
- `doctorConfig`
- `doctorReviewStatus = pending`

### Paso 4 - Generar

El boton `Generar con IA` debe enviar:

- `treatmentProfileId`
- `visualGoal`
- `doctorConfig`
- `photoQuality`
- `notes`

## Cambios en `PatientSimulatorTab`

La tarjeta de acciones rapidas actual puede mantenerse, pero debe respetar configuracion.

Recomendacion:

- `Nueva` abre `SimulatorScreen` en modo setup.
- Evitar que `Tomar foto` cree draft sin perfil seleccionado.
- Si se mantiene boton rapido, debe usar perfil default y permitir editar antes de generar.

## Cambios en `SimulatorScreen`

Agregar una seccion superior:

```text
Tratamiento
Configuracion
Foto
Resultado
```

Estados esperados:

- Sin foto: muestra selector + parametros + captura.
- Con draft: muestra configuracion bloqueada o editable con confirmacion.
- Generando: deshabilita cambios.
- Ready: muestra resultado y botones de revision.
- Failed: permite ajustar parametros o cambiar foto.

## Restricciones UX

- Mantener el comparador actual.
- No hacer landing page.
- No meter texto explicativo largo en pantalla.
- No mostrar al paciente esta configuracion.
- No crear cards dentro de cards si se edita UI.
- Los controles deben caber en mobile.

## Tests requeridos

Actualizar/crear tests:

- Nueva simulacion muestra selector de tratamiento.
- Default desde `TreatmentType.alineadores` selecciona `clear_aligners`.
- Draft creado desde camara guarda `treatmentProfileId` y `doctorConfig`.
- Boton `Generar con IA` manda config al provider/repository.
- En estado `generating` los controles quedan deshabilitados.
- La pantalla embebida sigue sin scroll anidado.

## Criterios de cierre

- Admin puede elegir cualquiera de los 8 tratamientos.
- Admin puede configurar parametros minimos por tratamiento.
- Draft guarda config.
- Generar envia config.
- Flujo viejo con paciente `tipoTratamiento` sigue teniendo default util.
- `flutter test test/features/simulator` pasa.

## Resultado esperado

El admin deja de generar simulaciones genericas y empieza a producir requests especificos para el tratamiento seleccionado.
