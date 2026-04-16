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
# Bloque 03 — Historial clínico del paciente por archivos

## 1) Problemática

Borlty, el Bloque 03 tampoco está cumplido. Ya hay evidencia real de que el historial clínico por archivos no está funcionando como debía.

### Hallazgos reales reportados en pruebas

- En historial clínico aparece el error:
  - `[cloud_firestore/permission-denied] Missing or insufficient permissions`
- Tampoco deja subir archivos.
- En consecuencia, el admin no puede usar la historia clínica documental del paciente como se definió.

### Lo que este bloque debía lograr y no logró

Este bloque no era “mostrar una pestaña bonita de archivos”. Debía permitir que el admin:

- suba archivos clínicos reales,
- liste archivos cargados,
- los filtre,
- los abra o descargue,
- los desactive si fueron cargados por error,
- los asocie al paciente general o a un tratamiento específico,
- y deje metadata clínica/auditora confiable.

El modelo también debía quedar preparado para que los archivos pudieran depender opcionalmente de `treatmentId` y a futuro de `stageId`.

Si hoy da `permission-denied` y no sube archivos, entonces el bloque no está cerrado. Y si además no hay flujo funcional de ver / descargar / desactivar / filtrar, mucho menos.

---

## 2) Análisis Problemática

### A. Fallo de permisos en Firestore y/o Storage

El error reportado ya demuestra que no resolviste la seguridad operativa del módulo. Aquí puede estar fallando una o varias capas:

- reglas de Firestore,
- reglas de Storage,
- validación de rol admin,
- path real usado por el cliente,
- metadata que no coincide con la estructura esperada,
- repositorio o provider mal configurado.

Si el admin no puede leer ni subir, el módulo es inutilizable.

### B. El bloque trata información clínica sensible

Este no es un módulo cualquiera. Maneja información clínica, consentimientos, radiografías, fotos intraorales, PDFs y soportes. No puedes dejarlo a medio hacer porque aquí un error de permisos o exposición es delicado.

### C. No quedó resuelta la organización documental

El objetivo era construir historia clínica documental ordenada. Para eso necesitabas:

- categorías,
- metadata,
- ruta de Storage controlada,
- subcolección clínica,
- asociación opcional con tratamiento,
- visibilidad restringida,
- eliminación lógica.

Si solo intentaste subir archivos sin cerrar el modelo, el bloque quedó mal desde su base.

### D. Falta de integración real con tratamiento

Este bloque dependía del Bloque 01 porque los archivos podían asociarse opcionalmente a `treatmentId`. Si eso no está bien resuelto, el historial clínico queda ambiguo.

### E. Riesgo de romper fotos existentes

El proyecto ya tenía estructura de fotos en el paciente. Si intentaste meter historial clínico sin pensar en compatibilidad, puedes haber generado rutas inconsistentes o consultas rotas.

---

## 3) Solución Problemática

Vas a implementar correctamente el Bloque 03 como módulo documental clínico, no como subida improvisada de archivos.

### A. Crear subcolección real de archivos clínicos

Debes implementar la estructura recomendada:

```txt
patients/{patientId}/clinicalFiles/{fileId}
```

Cada documento debe permitir opcionalmente:

- `treatmentId`
- `stageId` a futuro

Modelo mínimo sugerido:

- `id`
- `patientId`
- `treatmentId`
- `originalName`
- `displayName`
- `storagePath`
- `mimeType`
- `extension`
- `sizeBytes`
- `category`
- `notes`
- `uploadedBy`
- `uploadedAt`
- `updatedAt`
- `active`
- `deletedAt`
- `deletedBy`

### B. Integrar correctamente Firebase Storage

La fuente real debe ser `storagePath`, no una URL pública permanente.

Ruta sugerida:

```txt
patients/{patientId}/clinical-files/{fileId}_{originalName}
```

Si ayuda al orden, también puedes usar una ruta que incluya `treatmentId`, pero la metadata en Firestore debe seguir siendo la fuente organizadora principal.

### C. Permitir al admin subir, listar y gestionar archivos

La vista admin debe incluir de forma funcional:

- botón `Subir archivo`,
- selector de categoría,
- selector opcional de tratamiento,
- notas opcionales,
- lista o tabla de archivos,
- filtros por categoría,
- filtros por tratamiento,
- fecha,
- nombre,
- acciones: ver, descargar, desactivar.

### D. Validaciones obligatorias de carga

Antes de subir debes validar:

- tamaño,
- MIME type,
- extensión,
- existencia de `patientId`,
- existencia de `treatmentId` si se seleccionó,
- sanitización del nombre.

Tipos permitidos para primera versión:

- PDF
- JPG
- JPEG
- PNG
- WEBP

No permitir inicialmente:

- ejecutables,
- ZIP/RAR,
- formatos desconocidos,
- archivos sin extensión.

### E. Categorías iniciales obligatorias

Debes implementar al menos:

- `radiografia`
- `foto_clinica`
- `foto_intraoral`
- `pdf_clinico`
- `consentimiento`
- `formula`
- `soporte_pago`
- `otro`

La categoría debe servir para ordenar de verdad la historia clínica.

### F. Asociación opcional con tratamiento

Al subir archivo, el admin debe poder decidir:

- archivo general del paciente,
- archivo asociado al tratamiento actual.

Si se asocia a tratamiento, guardar:

- `treatmentId`
- `treatmentNameSnapshot`

Esto evita ambigüedad futura.

### G. Eliminación lógica, no destrucción inmediata

No debes borrar físicamente de entrada. Debes usar primero:

- `active: false`
- `deletedAt`
- `deletedBy`

Solo si luego se define una política explícita, se considera borrado físico controlado.

### H. Corregir reglas de seguridad

Reglas mínimas obligatorias:

- solo admin puede subir archivos clínicos,
- solo admin puede eliminar/desactivar,
- el paciente solo puede leer archivos marcados explícitamente como visibles para él,
- un paciente nunca puede leer archivos de otro,
- Storage debe validar rol y ruta,
- Firestore debe bloquear por defecto lo no permitido.

### I. Mantener compatibilidad con fotos existentes

Debes decidir e implementar sin romper datos existentes:

1. mantener `photos` separado y crear `clinicalFiles` nuevo,
2. o mostrar ambas fuentes en una vista unificada,
3. pero no migrar agresivamente sin validación.

La recomendación segura es mantener compatibilidad al inicio.

### J. Providers / repositorios obligatorios

Debes implementar o ajustar:

- `ClinicalFileModel`
- `ClinicalFilesRepository`
- provider de archivos por paciente,
- provider de archivos por tratamiento,
- servicio de carga a Storage,
- servicio de validación de tipo/tamaño,
- integración con tab Historial clínico.

### K. Entregables obligatorios

No cierres este bloque hasta entregar de verdad:

1. Modelo de archivo clínico.
2. Subcolección `clinicalFiles` por paciente.
3. Integración real con Firebase Storage.
4. UI admin para subir archivos.
5. UI admin para listar archivos.
6. Filtros por categoría y tratamiento.
7. Acción funcional de ver / descargar.
8. Eliminación lógica o desactivación.
9. Validaciones de tipo y tamaño.
10. Reglas de Firestore y Storage corregidas.
11. Compatibilidad con fotos existentes.
12. Validación manual real con:
   - subir PDF,
   - subir imagen,
   - asociar archivo a tratamiento,
   - subir archivo general,
   - desactivar archivo,
   - bloquear archivo no permitido.

### L. Criterio de aceptación real

El Bloque 03 solo se considera terminado cuando:

- el admin puede subir archivos al paciente,
- el admin puede asociarlos a tratamiento,
- el admin puede listar, filtrar y abrir archivos,
- el sistema valida tipo y tamaño,
- los archivos se guardan en Storage con metadata en Firestore,
- las reglas de seguridad impiden acceso indebido,
- las fotos existentes no se rompen,
- el modelo queda preparado para `stageId` futuro.

---

## 4) Regaña al desarrollador

Borlty, en un módulo clínico no puedes dejar un `permission-denied` como si fuera un detalle menor. Si el admin no puede leer ni subir archivos, entonces el módulo no existe. Y si además no resolviste Storage, metadata, categorías y permisos, lo que hay no es historia clínica documental; es una pestaña vacía con errores.

Esto exige mucho más cuidado que una tarjeta visual. Aquí hay información sensible, trazabilidad y estructura documental. No vuelvas a dar por listo un bloque clínico sin cerrar reglas, rutas, permisos, validaciones y flujo real de uso.

Quiero un módulo utilizable por la doctora, no una promesa. Si no se puede subir, listar, abrir y desactivar archivos con seguridad correcta, entonces el bloque sigue incumplido.
