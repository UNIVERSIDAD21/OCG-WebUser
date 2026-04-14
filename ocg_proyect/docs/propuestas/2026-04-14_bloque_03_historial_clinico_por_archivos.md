# Bloque 03 — Historial clínico del paciente por archivos

## Objetivo

Permitir que la doctora/admin cargue, consulte, organice y gestione archivos clínicos del paciente para construir una historia clínica documental dentro del sistema OCG.

Este bloque debe permitir archivos generales del paciente y archivos asociados a un tratamiento específico cuando aplique.

Depende del Bloque 01 porque los archivos deben poder relacionarse opcionalmente con `treatmentId`.

---

## Qué entendemos del negocio

El historial clínico no será solo texto. La doctora necesita subir archivos reales al perfil del paciente, por ejemplo:

- PDFs,
- imágenes clínicas,
- radiografías,
- fotos intraorales,
- consentimientos,
- fórmulas,
- soportes clínicos,
- documentos administrativos relacionados con el tratamiento.

---

## Resultado funcional esperado

Dentro del paciente debe existir una sección o tab `Historial clínico` donde el admin pueda:

- subir archivos,
- ver archivos cargados,
- abrir o previsualizar archivos,
- descargar archivos si tiene permiso,
- eliminar o desactivar archivos cargados por error,
- filtrar por categoría,
- asociar un archivo al paciente completo,
- asociar un archivo a un tratamiento específico,
- consultar fecha de carga y usuario que lo subió.

---

## Regla central del bloque

Los archivos deben organizarse por paciente y opcionalmente por tratamiento.

Estructura recomendada en Firestore:

```txt
patients/{patientId}/clinicalFiles/{fileId}
```

Cada documento puede tener `treatmentId` opcional.

Esto permite:

- archivo general del paciente,
- archivo específico de tratamiento,
- archivo ligado a una etapa,
- archivo ligado a un procedimiento futuro.

---

## Estructura sugerida en Storage

Ruta recomendada:

```txt
patients/{patientId}/clinical-files/{fileId}_{originalName}
```

Si se quiere separar por tratamiento:

```txt
patients/{patientId}/treatments/{treatmentId}/clinical-files/{fileId}_{originalName}
```

Recomendación práctica: usar una sola subcolección en Firestore y guardar `treatmentId` como campo opcional. En Storage sí puede incluirse treatmentId si ayuda al orden.

---

## Modelo sugerido de archivo clínico

```json
{
  "id": "fileId",
  "patientId": "patientId",
  "treatmentId": "treatmentId",
  "stageId": null,
  "originalName": "radiografia_panorex.pdf",
  "displayName": "Radiografía panorámica inicial",
  "storagePath": "patients/patientId/clinical-files/fileId_radiografia_panorex.pdf",
  "mimeType": "application/pdf",
  "extension": "pdf",
  "sizeBytes": 1200000,
  "category": "radiografia",
  "notes": "Radiografía tomada antes de iniciar tratamiento",
  "uploadedBy": "adminUid",
  "uploadedAt": "timestamp",
  "updatedAt": "timestamp",
  "active": true,
  "deletedAt": null,
  "deletedBy": null
}
```

---

## Categorías iniciales recomendadas

El sistema debe iniciar con categorías simples:

- `radiografia`
- `foto_clinica`
- `foto_intraoral`
- `pdf_clinico`
- `consentimiento`
- `formula`
- `soporte_pago`
- `otro`

La categoría puede ser obligatoria para mantener orden.

---

## Tipos de archivo permitidos

Primera versión recomendada:

- PDF
- JPG
- JPEG
- PNG
- WEBP

No permitir inicialmente:

- archivos ejecutables,
- ZIP/RAR,
- documentos desconocidos,
- archivos sin extensión,
- videos pesados, salvo decisión explícita posterior.

---

## Tamaño máximo sugerido

Definir un límite para evitar costos y lentitud.

Recomendación inicial:

- imágenes: máximo 10 MB por archivo,
- PDF: máximo 20 MB por archivo.

Si la doctora usa radiografías muy pesadas, validar antes de cerrar el límite.

---

## Regla sobre URLs

No guardar ni exponer URLs públicas permanentes como fuente principal.

La fuente real debe ser:

```txt
storagePath
```

Cuando el admin necesite abrir o descargar, el sistema puede resolver el archivo desde Firebase Storage respetando permisos.

---

## Vista admin

La vista admin debe incluir:

- botón `Subir archivo`,
- selector de categoría,
- selector opcional de tratamiento,
- campo opcional de notas,
- lista o tabla de archivos,
- filtro por categoría,
- filtro por tratamiento,
- fecha de carga,
- nombre del archivo,
- acciones: ver, descargar, eliminar/desactivar.

---

## Vista paciente

Por ahora, la interpretación segura es:

- el paciente no ve todos los archivos clínicos por defecto,
- solo admin/doctora tiene acceso completo,
- si más adelante se quiere mostrar archivos al paciente, debe existir un campo explícito:

```txt
visibleToPatient: true
```

No asumir visibilidad automática.

---

## Eliminación de archivos

Recomendación: no borrar físicamente de inmediato.

Usar primero eliminación lógica:

```json
{
  "active": false,
  "deletedAt": "timestamp",
  "deletedBy": "adminUid"
}
```

Esto evita perder evidencia clínica por error.

Si se requiere borrado físico en Storage, debe ser una acción controlada y preferiblemente solo para admin autorizado.

---

## Asociación con tratamiento

Cuando el admin está viendo un tratamiento seleccionado, al subir archivo el sistema debe ofrecer:

- asociar al tratamiento actual,
- dejar como archivo general del paciente.

Si se asocia a tratamiento, guardar:

```txt
treatmentId
treatmentNameSnapshot
```

El snapshot ayuda a entender el archivo aunque después cambie el nombre del tratamiento.

---

## Asociación futura con etapas

No es obligatorio en primera versión, pero el modelo debe quedar preparado para:

```txt
stageId
stageNameSnapshot
```

Esto permitiría asociar archivos a una etapa específica del tratamiento.

---

## Seguridad y permisos

Este bloque es sensible porque maneja información clínica.

Reglas mínimas:

- Solo admin puede subir archivos clínicos.
- Solo admin puede eliminar/desactivar archivos clínicos.
- El paciente solo puede leer archivos marcados explícitamente como visibles para él.
- Un paciente nunca puede acceder a archivos de otro paciente.
- Storage debe validar la ruta y el rol.
- Firestore debe bloquear por defecto todo lo no permitido.
- No exponer rutas públicas sin control.

---

## Validaciones de carga

Antes de subir:

- validar tamaño,
- validar tipo MIME,
- validar extensión,
- validar que exista `patientId`,
- validar que `treatmentId` exista si se seleccionó tratamiento,
- sanitizar el nombre del archivo,
- mostrar error claro si el archivo no es permitido.

---

## Auditoría

Cada archivo debe registrar:

- quién lo subió,
- cuándo lo subió,
- quién lo eliminó/desactivó,
- cuándo se eliminó/desactivó,
- categoría,
- tratamiento asociado si aplica.

Esto es importante por tratarse de documentos clínicos.

---

## Migración o compatibilidad con fotos existentes

El proyecto ya contempla fotos de pacientes en subcolección. Este bloque no debe romper esa estructura.

Si hoy existen fotos en:

```txt
patients/{patientId}/photos
```

Borlty debe decidir una de estas opciones:

1. Mantener `photos` para fotos clínicas y crear `clinicalFiles` para documentos.
2. Migrar gradualmente fotos importantes a `clinicalFiles`.
3. Mostrar ambas fuentes en una vista unificada sin borrar datos.

Recomendación: no migrar agresivamente al inicio. Primero crear `clinicalFiles` y mantener compatibilidad.

---

## Providers / repositorios sugeridos

Borlty debe implementar o ajustar:

- `ClinicalFileModel`
- `ClinicalFilesRepository`
- provider de archivos por paciente,
- provider de archivos por tratamiento,
- servicio de carga a Firebase Storage,
- servicio de validación de tipo/tamaño,
- integración con tab Historial clínico.

---

## Entregables de implementación

Borlty debe entregar:

1. Modelo de archivo clínico.
2. Subcolección `clinicalFiles` por paciente.
3. Integración con Firebase Storage.
4. UI admin para subir archivos.
5. UI admin para listar archivos.
6. Filtros por categoría y tratamiento.
7. Acción de ver/descargar.
8. Eliminación lógica o desactivación.
9. Validaciones de tipo y tamaño.
10. Reglas de Firestore y Storage revisadas.
11. Compatibilidad con fotos existentes.
12. Validación manual con mínimo:
    - subir PDF,
    - subir imagen,
    - asociar archivo a tratamiento,
    - subir archivo general del paciente,
    - eliminar/desactivar archivo,
    - bloquear archivo no permitido.

---

## Riesgos funcionales

- La historia clínica quedará desordenada si no hay categorías.
- Puede haber exposición indebida de información sensible si Storage queda público.
- Se pueden mezclar archivos de tratamientos distintos si no se usa `treatmentId`.
- Se puede perder evidencia clínica si se borra físicamente sin control.
- Los costos pueden crecer si se permiten archivos demasiado pesados.

---

## Decisiones para validar con Jefe/doctora

- Qué tipos de archivo se permitirán exactamente.
- Tamaño máximo por archivo.
- Si el paciente verá algún archivo desde su app.
- Si la categoría será obligatoria.
- Si las fotos clínicas actuales se mantienen separadas o se muestran dentro de Historial clínico.
- Si se permitirá borrar físicamente archivos o solo desactivarlos.

---

## Criterio de aceptación del Bloque 03

El bloque se considera terminado cuando:

- El admin puede subir archivos al paciente.
- El admin puede asociar archivos a un tratamiento.
- El admin puede listar, filtrar y abrir archivos.
- El sistema valida tipo y tamaño.
- Los archivos se guardan en Storage con metadata en Firestore.
- Las reglas de seguridad impiden acceso indebido.
- Las fotos existentes no se rompen.
- El modelo queda preparado para asociar archivos a etapas en el futuro.
