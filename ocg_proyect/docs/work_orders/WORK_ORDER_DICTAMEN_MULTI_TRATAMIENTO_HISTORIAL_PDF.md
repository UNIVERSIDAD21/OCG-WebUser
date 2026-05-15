# WORK ORDER - Dictamen ligado a tratamiento, historial clinico y PDF

> Fecha: 2026-05-15  
> Repo: `ocg_proyect`  
> Alcance: cerrar la trazabilidad entre citas, dictamen, firma, documentos clinicos y tratamientos; soportar varios tratamientos por paciente; agregar generacion de PDF de dictamen con diseno profesional.  
> Prioridad: alta, porque afecta auditoria clinica, navegacion del admin y claridad cuando un paciente tiene mas de un tratamiento.

---

## 1. Objetivo

Garantizar que cada dictamen clinico quede ligado de forma explicita al tratamiento correcto, a la cita que lo origina, a la firma del paciente y a sus documentos clinicos.

Ademas, el sistema debe permitir:

1. ver el historial clinico de un tratamiento especifico desde la pantalla del paciente;
2. gestionar correctamente pacientes con varios tratamientos;
3. generar un PDF tipo reporte del dictamen para que la doctora pueda compartirlo o mostrarlo fuera del sistema;
4. mantener compatibilidad con registros legacy que todavia no tengan `treatmentId`.

---

## 2. Principios de implementacion

1. `patientId` identifica al paciente, pero no basta para trazabilidad clinica cuando existen varios tratamientos.
2. `treatmentId` debe ser el eje principal para citas, dictamenes, pagos, documentos y stage history.
3. La pantalla de dictamen no debe elegir automaticamente el tratamiento principal si la cita ya trae `treatmentId`.
4. Todo dato visible en PDF debe salir de un snapshot persistido, no de estado temporal de UI.
5. El PDF debe ser un reporte clinico sobrio, legible y exportable, no una captura de pantalla.
6. Los documentos generados deben respetar privacidad: no publicar URLs abiertas sin control.
7. Los registros legacy deben seguir viendose, pero las nuevas acciones deben escribir con el contrato nuevo.
8. Cada bloque debe cerrar con pruebas o validacion manual documentada.

---

## 3. Estado actual detectado

### Tratamientos

Ruta nueva:

```text
patients/{patientId}/treatments/{treatmentId}
```

Cada tratamiento tiene `id`, `patientId`, `displayName`, `isPrimary`, `estado`, `etapaActual`, fechas y datos financieros.

### Historial de etapas

Ruta general legacy:

```text
patients/{patientId}/stageHistory/{historyId}
```

Ruta por tratamiento:

```text
patients/{patientId}/treatments/{treatmentId}/stageHistory/{historyId}
```

`StageHistoryEntry` ya soporta:

```text
patientId
treatmentId
consultationId
signatureUrl
diagnosticoBreve
planSiguienteEtapa
adjuntosDescripcion
fechaEfectiva
```

### Citas

`AppointmentModel` ya soporta:

```text
patientId
treatmentId
stageId
```

Pero al crear citas desde admin actualmente no siempre se llena `treatmentId`.

### Dictamen / consulta

Ruta actual:

```text
patients/{patientId}/consultations/{consultationId}
```

`ConsultationModel` guarda:

```text
appointmentId
signatureUrl
signatureCapturedAt
clinicalNotes
phaseSnapshot
photos
auditTrail
```

El repositorio `ConsultationRepository.saveCompletedConsultation()` ya puede escribir historial por tratamiento si recibe `treatmentId`.

### Documentos clinicos

Ruta actual:

```text
patients/{patientId}/clinicalFiles/{fileId}
```

`ClinicalFileModel` ya soporta:

```text
patientId
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
category
visibleToPatient
```

Falta formalizar `consultationId` para que un documento pueda quedar ligado directamente al dictamen que lo genero.

---

## 4. Arquitectura objetivo

Cada flujo clinico debe terminar con esta relacion:

```text
Paciente
  patients/{patientId}

Tratamiento
  patients/{patientId}/treatments/{treatmentId}

Cita
  appointments/{appointmentId}
    patientId
    treatmentId
    stageId

Dictamen
  patients/{patientId}/consultations/{consultationId}
    patientId
    appointmentId
    treatmentId
    stageId
    signatureUrl
    clinicalFileIds

Historial del tratamiento
  patients/{patientId}/treatments/{treatmentId}/stageHistory/{historyId}
    consultationId
    signatureUrl

Documentos clinicos
  patients/{patientId}/clinicalFiles/{fileId}
    treatmentId
    consultationId
    category
    visibleToPatient

PDF generado
  patients/{patientId}/clinicalFiles/{pdfFileId}
    treatmentId
    consultationId
    category: dictamen_pdf
```

La ruta general `patients/{patientId}/stageHistory` se mantiene solo como espejo del tratamiento principal o compatibilidad legacy.

---

## 5. Bloques de implementacion

### Bloque 00 - Auditoria tecnica y pruebas base

Estado: iniciado / completado en base tecnica.

Objetivo: congelar el comportamiento actual antes de cambiar el flujo.

Tareas:

1. Documentar rutas actuales usadas por dictamen, tratamientos, documentos y citas.
2. Identificar pruebas existentes que cubren `ConsultationScreen`, `PatientTreatmentTab`, `PatientClinicalHistoryTab` y agenda admin.
3. Agregar pruebas minimas si no existen para:
   - resolver tratamiento desde una cita;
   - guardar historial de tratamiento;
   - listar documentos clinicos por tratamiento.

Criterio de cierre:

1. Se sabe que pruebas corren antes de tocar logica.
2. No hay cambios funcionales todavia.

Resultado de auditoria:

1. Rutas actuales confirmadas:

```text
appointments/{appointmentId}
patients/{patientId}/consultations/{consultationId}
patients/{patientId}/clinicalFiles/{fileId}
patients/{patientId}/stageHistory/{historyId}
patients/{patientId}/treatments/{treatmentId}
patients/{patientId}/treatments/{treatmentId}/stageHistory/{historyId}
payments/{patientId}/treatments/{treatmentId}
```

2. Pruebas base identificadas:

```text
test/features/consultation/consultation_rules_test.dart
test/features/consultation/consultation_model_test.dart
test/features/consultation/consultation_repository_test.dart
test/features/clinical_files/clinical_file_model_test.dart
test/features/clinical_files/clinical_files_repository_test.dart
test/features/patients/patient_treatment_tab_multitreatment_test.dart
test/treatment/stage_history_entry_test.dart
```

3. Brecha detectada para Bloque 03:

```text
ConsultationScreen todavia debe resolver primero appointment.treatmentId.
Ese cambio queda fuera del Bloque 00/01 y se implementa en Bloque 03.
```

---

### Bloque 01 - Contrato oficial de datos

Estado: iniciado / completado en modelos.

Objetivo: definir los campos obligatorios para nuevos dictamenes y documentos clinicos.

Tareas:

1. Extender `ConsultationModel` con:

```text
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
reportPdfFileId
reportPdfUrl
```

2. Extender `ClinicalFileModel` con:

```text
consultationId
sourceType
sourceId
```

Valores sugeridos:

```text
sourceType: manual_upload | consultation_attachment | consultation_pdf
sourceId: consultationId o id del flujo origen
```

3. Mantener compatibilidad con documentos viejos donde esos campos no existan.
4. Revisar reglas de Firestore/Storage si aplican para permitir los nuevos campos.

Criterio de cierre:

1. Modelos parsean datos nuevos y legacy.
2. Ningun registro viejo rompe UI.

Resultado de implementacion:

1. `ConsultationModel` extendido con:

```text
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
reportPdfFileId
reportPdfUrl
```

2. `ClinicalFileModel` extendido con:

```text
consultationId
sourceType
sourceId
```

3. `ClinicalFileModel` soporta la categoria futura:

```text
dictamen_pdf
```

4. Fuentes iniciales aplicadas:

```text
manual_upload
consultation_attachment
```

5. Reglas revisadas:

```text
firestore.rules no limita campos por lista cerrada para consultations/clinicalFiles.
storage.rules ya permite firmas y archivos de consulta para admin.
La ruta futura de reportes PDF se revisara en Bloque 10 antes de guardar PDFs en Storage.
```

---

### Bloque 02 - Citas asociadas a tratamiento

Estado: iniciado / completado en flujo de creacion de citas.

Objetivo: que una cita nueva pueda quedar ligada al tratamiento correcto.

Tareas:

1. En el dialogo de crear cita admin, cargar tratamientos efectivos del paciente seleccionado.
2. Si el paciente tiene un tratamiento activo, seleccionarlo por defecto.
3. Si tiene varios tratamientos activos, mostrar selector obligatorio.
4. Guardar en `appointments/{appointmentId}`:

```text
treatmentId
stageId
treatmentNameSnapshot
stageNameSnapshot
```

5. Para citas creadas por paciente, resolver el tratamiento principal como fallback inicial.

Criterio de cierre:

1. Una cita nueva de paciente con varios tratamientos no queda ambigua.
2. El dictamen abierto desde la cita recibe el `treatmentId` correcto.

Resultado de implementacion:

1. `AppointmentModel` ahora serializa y deserializa:

```text
treatmentNameSnapshot
stageNameSnapshot
```

2. El dialogo admin de crear cita carga los tratamientos efectivos del paciente seleccionado.
3. Si hay un solo tratamiento nuevo, queda asociado automaticamente.
4. Si hay varios tratamientos nuevos, se muestra selector de `Tratamiento asociado`.
5. La cita creada por admin guarda:

```text
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
```

6. La cita creada por paciente desde Cloud Function resuelve el tratamiento principal como fallback y toma snapshot desde:

```text
patients/{patientId}/treatments/{primaryTreatmentId}
```

7. Si no existe tratamiento nuevo, la cita se mantiene compatible en modo legacy sin romper el flujo.

Pruebas agregadas:

```text
test/features/appointments/appointment_model_test.dart
```

---

### Bloque 03 - Dictamen usa el tratamiento correcto

Estado: iniciado / completado en resolucion de tratamiento del dictamen.

Objetivo: corregir el punto critico donde `ConsultationScreen` puede caer al tratamiento principal aunque la cita tenga otro `treatmentId`.

Tareas:

1. En `ConsultationScreen._loadPatientData()`, resolver tratamiento en este orden:

```text
1. appointment.treatmentId si existe y coincide con un tratamiento
2. tratamiento primario
3. primer tratamiento disponible
4. auto-crear tratamiento si no existe ninguno
```

2. Mostrar en la pantalla de dictamen el tratamiento asociado de forma clara.
3. Bloquear cambio accidental de tratamiento durante el dictamen si viene desde una cita real.
4. Para dictamen sintetico desde la pestaña Tratamiento, conservar el `treatmentId` enviado.

Criterio de cierre:

1. Dictamen desde tratamiento secundario escribe en historial del tratamiento secundario.
2. Dictamen desde cita con `treatmentId` no se va al principal.

Resultado de implementacion:

1. Se agrego un resolver dedicado:

```text
ConsultationTreatmentResolver
```

2. `ConsultationScreen._loadPatientData()` ahora resuelve el tratamiento en este orden:

```text
1. appointment.treatmentId si existe y coincide con un tratamiento
2. tratamiento primario
3. primer tratamiento disponible
4. sin tratamiento: se mantiene el auto-create existente al guardar
```

3. El dictamen muestra un indicador de trazabilidad:

```text
Ligado a la cita
Fallback al tratamiento principal
Fallback al primer tratamiento disponible
```

4. La linea de fases del dictamen usa la etapa del tratamiento resuelto, no la etapa plana del paciente.
5. Los dictamenes sinteticos abiertos desde tratamientos ahora llevan:

```text
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
```

6. `PatientTreatmentsRepository.getPatientTreatments()` conserva `doc.id`; esto evita que una cita con `treatmentId` falle al hacer match cuando el documento no trae `id` en su data.

Pruebas agregadas/actualizadas:

```text
test/features/consultation/consultation_treatment_resolver_test.dart
test/treatment/patient_treatments_repository_test.dart
test/features/appointments/appointment_model_test.dart
```

---

### Bloque 04 - Guardado atomico de dictamen, firma y documentos

Estado: iniciado / completado en repositorio de dictamen.

Objetivo: que firma, adjuntos, historial y cita queden ligados de forma consistente.

Tareas:

1. Guardar `treatmentId`, `treatmentNameSnapshot`, `stageId` y `stageNameSnapshot` en `ConsultationModel`.
2. Guardar `consultationId` en cada `ClinicalFileModel` creado desde el dictamen.
3. Guardar `sourceType: consultation_attachment` en adjuntos del dictamen.
4. Guardar `clinicalFileIds` en la consulta.
5. Asegurar que `StageHistoryEntry` conserve:

```text
consultationId
signatureUrl
treatmentId
fechaEfectiva
```

6. Si falla algun upload o metadata, limpiar archivos subidos antes de fallar.

Criterio de cierre:

1. Al guardar dictamen, todo se puede rastrear desde el tratamiento.
2. La firma aparece en el historial correspondiente.
3. Los adjuntos aparecen en documentos clinicos filtrados por ese tratamiento.

Resultado de implementacion:

1. `ConsultationRepository.saveCompletedConsultation()` mantiene un `WriteBatch` unico para:

```text
patients/{patientId}/consultations/{consultationId}
patients/{patientId}/clinicalFiles/{fileId}
patients/{patientId}/treatments/{treatmentId}/stageHistory/{historyId}
patients/{patientId}/stageHistory/{historyId} cuando aplica espejo legacy/principal
appointments/{appointmentId} solo si la cita existe realmente
```

2. El repositorio normaliza los adjuntos antes de escribir:

```text
consultationId: consultationId
sourceType: consultation_attachment si viene vacio
sourceId: consultationId si viene vacio
treatmentId: treatmentId canonico
treatmentNameSnapshot: snapshot del dictamen
stageId / stageNameSnapshot: snapshot del dictamen
```

3. `clinicalFileIds` se guarda en el documento de consulta usando ids limpios.
4. El historial conserva:

```text
consultationId
signatureUrl
treatmentId
fechaEfectiva
diagnosticoBreve
planSiguienteEtapa
adjuntosDescripcion
```

5. Las citas reales quedan completadas con trazabilidad del dictamen:

```text
consultationId
treatmentId
treatmentNameSnapshot
stageId
stageNameSnapshot
```

6. Las citas sinteticas `dictamen-*` ya no se actualizan en `appointments`, evitando fallos al guardar dictamen desde la pestana de Tratamientos.
7. `ConsultationScreen` ya mantiene limpieza de archivos subidos a Storage si falla el guardado de metadata posterior.

Pruebas agregadas/actualizadas:

```text
test/features/consultation/consultation_repository_test.dart
```

---

### Bloque 05 - Navegacion "Ver historial clinico"

Estado: iniciado / completado en navegacion por query params.

Objetivo: agregar acceso directo al historial del tratamiento desde donde el admin lo espera.

Tareas:

1. Agregar boton `Ver historial clinico` en cada tarjeta de tratamiento.
2. Agregar boton equivalente desde documentos clinicos cuando un archivo tenga `treatmentId`.
3. Soportar query params en detalle de paciente:

```text
/admin/patients/{patientId}?section=tratamientos&treatmentId={treatmentId}&focus=history
```

o, si se decide que documentos sea el punto central:

```text
/admin/patients/{patientId}?section=historial&treatmentId={treatmentId}
```

4. En mobile y desktop, seleccionar automaticamente el tratamiento indicado por `treatmentId`.
5. Hacer scroll o abrir el bloque de historial si `focus=history`.

Criterio de cierre:

1. Desde un tratamiento se abre su historial, no el historial general.
2. Desde un documento ligado se puede ir al tratamiento correcto.

Resultado de implementacion:

1. `PatientDetailScreen` ahora lee query params:

```text
section
treatmentId
focus
```

2. La URL canonica para abrir historial de tratamiento queda:

```text
/admin/patients/{patientId}?section=tratamientos&treatmentId={treatmentId}&focus=history
```

3. En desktop, `DefaultTabController` se reinicializa con key basada en:

```text
patientId
section
treatmentId
focus
```

4. En mobile, `_AdminPatientWorkspace` reacciona a cambios de query y abre la seccion correcta.
5. `PatientTreatmentTab` acepta:

```text
initialTreatmentId
focusHistory
```

6. `PatientTreatmentTab` selecciona automaticamente el tratamiento indicado por `treatmentId` y hace scroll al panel `Historial del tratamiento` cuando `focus=history`.
7. Se agrego accion `Ver historial clinico` en el modulo de tratamientos.
8. `PatientClinicalHistoryTab` acepta `initialTreatmentId` para filtrar documentos por tratamiento al abrir con URL directa.
9. Los documentos clinicos ligados a un tratamiento muestran accion `Ver historial clinico`, que lleva al historial del tratamiento correcto.
10. En mobile, el tab de tratamientos ahora tambien expone el bloque `Historial del tratamiento`, no solo el ultimo movimiento.

Validacion automatizada:

```text
flutter analyze lib/features/patients/presentation/patient_detail_screen.dart lib/features/patients/presentation/tabs/patient_treatment_tab.dart lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart
flutter test test/features/patients/patient_treatment_tab_multitreatment_test.dart test/treatment/patient_treatments_repository_test.dart test/features/clinical_files/clinical_file_model_test.dart
flutter test test/features/patients/patient_detail_workspace_test.dart test/features/admin/admin_desktop_modules_alignment_test.dart test/features/admin/admin_desktop_validation_matrix_test.dart
```

---

### Bloque 06 - Vista de historial clinico por tratamiento

Objetivo: convertir el historial en una vista util para varios tratamientos.

Tareas:

1. En `PatientTreatmentTab`, mantener el historial por tratamiento seleccionado.
2. En `PatientClinicalHistoryTab`, permitir filtros:

```text
Todos
Tratamiento A
Tratamiento B
Sin tratamiento / legacy
```

3. Mostrar agrupacion por fuente:

```text
Dictamenes
Documentos
Citas asociadas
Pagos asociados
```

4. En cada entrada de dictamen, mostrar:

```text
fecha
tratamiento
etapa
doctor/admin
firma disponible
adjuntos
boton PDF
```

Criterio de cierre:

1. El admin entiende que cada tratamiento tiene su propio expediente.
2. Los registros legacy siguen visibles como "Sin tratamiento / migrado".

---

### Bloque 07 - Generacion de PDF de dictamen

Objetivo: crear un reporte PDF profesional del dictamen.

#### 07A - Diseno del reporte

El PDF debe incluir:

1. Encabezado:
   - logo o nombre de la clinica;
   - titulo: `Dictamen clinico`;
   - fecha de generacion;
   - codigo de dictamen.

2. Datos del paciente:
   - nombre;
   - documento si existe en el futuro;
   - telefono/correo;
   - fecha de la cita/dictamen.

3. Datos del tratamiento:
   - nombre del tratamiento;
   - estado;
   - etapa antes/despues;
   - si es tratamiento principal o secundario.

4. Resumen clinico:
   - notas clinicas;
   - diagnostico breve;
   - plan de siguiente etapa;
   - observaciones de adjuntos.

5. Firma:
   - imagen de la firma del paciente si existe;
   - fecha/hora de captura;
   - texto legal breve de consentimiento o constancia.

6. Adjuntos:
   - lista de archivos ligados al dictamen;
   - categoria;
   - visibilidad;
   - nombre del archivo.

7. Pie:
   - nombre de la clinica;
   - nota de confidencialidad;
   - version del reporte;
   - ID de paciente, tratamiento, cita y dictamen.

#### 07B - Estrategia tecnica recomendada

MVP recomendado:

1. Generar PDF desde Flutter con paquete `pdf`/`printing`.
2. Descargar o abrir el PDF sin guardarlo automaticamente.
3. Usar datos ya cargados de:

```text
ConsultationModel
StageHistoryEntry
ClinicalFileModel
PatientModel
PatientTreatment
AppointmentModel
```

Fase profesional:

1. Crear Callable Function `generateConsultationReportPdf`.
2. Backend lee datos desde Firestore.
3. Backend genera PDF canonico.
4. PDF se guarda en Storage:

```text
patients/{patientId}/consultations/reports/{consultationId}.pdf
```

5. Metadata se guarda como documento clinico:

```text
category: dictamen_pdf
sourceType: consultation_pdf
consultationId
treatmentId
visibleToPatient: false por defecto
```

Recomendacion:

Empezar con MVP en Flutter si se necesita velocidad. Migrar a Function si se necesita auditoria fuerte, versionado y generacion canonica desde servidor.

Criterio de cierre:

1. El boton `Generar PDF` produce un documento legible y bien disenado.
2. El PDF contiene la firma y los IDs de trazabilidad.
3. El PDF no requiere abrir manualmente varios documentos para entender el dictamen.

---

### Bloque 08 - Acciones UI para PDF

Objetivo: ubicar el PDF donde la doctora lo necesita.

Tareas:

1. En cada entrada de historial/dictamen mostrar:

```text
Ver dictamen
Generar PDF
Descargar PDF
Compartir / abrir
```

2. Si ya existe PDF generado, mostrar `Descargar PDF`.
3. Si no existe, mostrar `Generar PDF`.
4. En documentos clinicos, los PDFs generados deben verse como categoria `Dictamen PDF`.
5. Permitir marcar el PDF como visible para paciente solo si el admin lo decide.

Criterio de cierre:

1. La doctora puede generar el PDF desde el historial del tratamiento.
2. El PDF queda asociado al dictamen correcto.

---

### Bloque 09 - Migracion y compatibilidad legacy

Objetivo: que los datos actuales no se pierdan ni queden invisibles.

Tareas:

1. Citas sin `treatmentId`:
   - si el paciente tiene un solo tratamiento, asociarlas a ese tratamiento;
   - si tiene varios, dejarlas como `legacy_unlinked` hasta revision manual.

2. Stage history con `treatmentId` vacio:
   - si es espejo del tratamiento principal, mantener en historial general;
   - no mover automaticamente si hay duda.

3. Documentos sin `treatmentId`:
   - mostrarlos en `Sin tratamiento / legacy`;
   - permitir reasignarlos manualmente en fase posterior.

4. Dictamenes existentes:
   - inferir `consultationId` desde stage history cuando exista;
   - no inventar `treatmentId` si el dato no es confiable.

Criterio de cierre:

1. No desaparecen historiales viejos.
2. Las nuevas acciones ya escriben con contrato nuevo.

---

### Bloque 10 - Seguridad, privacidad y permisos

Objetivo: proteger datos clinicos y PDF.

Tareas:

1. Revisar reglas de Firestore para:
   - consultas;
   - documentos clinicos;
   - stage history por tratamiento;
   - PDFs generados.

2. Revisar reglas de Storage para:

```text
patients/{patientId}/clinicalFiles/...
patients/{patientId}/consultations/signatures/...
patients/{patientId}/consultations/reports/...
```

3. Asegurar que paciente solo vea documentos con `visibleToPatient == true`.
4. El PDF generado debe ser `visibleToPatient: false` por defecto.
5. Evitar enviar datos clinicos sensibles por email; solo notificar que existe actualizacion.

Criterio de cierre:

1. Admin puede generar/ver PDFs.
2. Paciente solo ve lo que la clinica marca como visible.

---

### Bloque 11 - Pruebas automatizadas

Objetivo: cerrar regresiones.

Pruebas minimas:

1. `ConsultationScreen` resuelve tratamiento por `appointment.treatmentId`.
2. Dictamen de tratamiento secundario crea history en:

```text
patients/{patientId}/treatments/{treatmentId}/stageHistory
```

3. Dictamen de tratamiento principal tambien espeja en:

```text
patients/{patientId}/stageHistory
```

4. Documento creado desde dictamen tiene:

```text
treatmentId
consultationId
sourceType
```

5. Cita nueva desde admin con varios tratamientos exige seleccion.
6. Boton `Ver historial clinico` abre el tratamiento correcto.
7. PDF renderer incluye:
   - nombre paciente;
   - tratamiento;
   - notas;
   - firma;
   - IDs de trazabilidad.

Criterio de cierre:

1. `flutter analyze` limpio en archivos tocados.
2. Tests especificos de pacientes, tratamientos, citas y documentos pasan.

---

### Bloque 12 - Validacion manual

Escenarios manuales:

1. Paciente con un solo tratamiento:
   - crear cita;
   - abrir dictamen;
   - firmar;
   - adjuntar documento;
   - guardar;
   - revisar historial;
   - generar PDF.

2. Paciente con dos tratamientos:
   - crear cita para tratamiento B;
   - abrir dictamen desde esa cita;
   - confirmar que el dictamen dice tratamiento B;
   - guardar;
   - verificar que tratamiento A no recibio ese historial.

3. Documento clinico manual:
   - subir documento a tratamiento A;
   - filtrar por tratamiento A;
   - ir a `Ver historial clinico`.

4. Legacy:
   - paciente con registros viejos;
   - verificar que siguen visibles como migrados/sin tratamiento.

Criterio de cierre:

1. La doctora puede explicar el historial por tratamiento sin ambiguedad.
2. El PDF se ve profesional y completo.

---

## 6. Orden recomendado de ejecucion

1. Bloque 00 - Auditoria y pruebas base.
2. Bloque 01 - Contrato de datos.
3. Bloque 03 - Resolver tratamiento correcto en dictamen.
4. Bloque 04 - Guardado atomico de firma/documentos/historial.
5. Bloque 02 - Citas con selector de tratamiento.
6. Bloque 05 - Navegacion `Ver historial clinico`.
7. Bloque 06 - Vista de historial por tratamiento.
8. Bloque 07 - PDF de dictamen.
9. Bloque 08 - Acciones UI para PDF.
10. Bloque 09 - Compatibilidad legacy.
11. Bloque 10 - Seguridad.
12. Bloque 11 y 12 - Pruebas y validacion manual.

Motivo del orden: primero se corrige el vinculo critico del dictamen, luego se mejora la entrada de citas y finalmente se agregan vistas/PDF sobre datos ya confiables.

---

## 7. Riesgos

1. Asociar automaticamente registros legacy al tratamiento equivocado.
2. Generar PDFs con URLs publicas no controladas.
3. Duplicar historial entre general y tratamiento sin distinguir espejo/primario.
4. Que el dictamen use el tratamiento principal aunque fue abierto desde un tratamiento secundario.
5. Que el PDF se vea bien en desktop pero se genere mal en mobile/web.

Mitigacion:

1. Migracion conservadora.
2. Campos snapshot en documentos y dictamenes.
3. Tests sobre tratamiento secundario.
4. PDF generado desde modelo, no desde captura visual.

---

## 8. Definicion de terminado

Se considera terminado cuando:

1. Citas nuevas tienen `treatmentId` cuando corresponde.
2. Dictamen nuevo siempre queda ligado al tratamiento correcto.
3. Firma del paciente aparece en el historial del tratamiento.
4. Adjuntos del dictamen aparecen en documentos clinicos del tratamiento.
5. Existe boton `Ver historial clinico` y abre el tratamiento correcto.
6. Existe boton `Generar PDF` para dictamen.
7. El PDF tiene diseno profesional, firma, notas, tratamiento y trazabilidad.
8. Los datos legacy siguen visibles.
9. Pruebas y validacion manual estan documentadas.
