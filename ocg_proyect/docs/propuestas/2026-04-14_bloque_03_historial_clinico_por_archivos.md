# Bloque 03 — Historial clínico del paciente por archivos

## Objetivo

Permitir que la doctora/admin cargue archivos clínicos al paciente para construir una historia clínica documental dentro del sistema.

## Qué entendemos del negocio

El historial clínico no será solo texto. La doctora necesita subir archivos reales al perfil del paciente, por ejemplo:

- PDFs
- imágenes clínicas
- radiografías
- fotos intraorales
- consentimientos
- fórmulas o soportes clínicos

## Resultado funcional esperado

Dentro del paciente debe existir una sección o tab `Historial clínico` donde el admin pueda:

- subir archivos
- ver archivos ya cargados
- descargar/abrir archivos
- eliminar archivos si se cargaron por error
- filtrar o asociar el archivo al tratamiento si aplica

## Recomendación de diseño funcional

### Nivel mínimo
Asociar archivos al paciente.

### Nivel recomendado
Asociar archivos al paciente y opcionalmente al tratamiento seleccionado.

Eso permitiría cosas como:
- archivo general del paciente
- archivo específico de tratamiento de ortodoncia
- archivo específico de ortopedia
- archivo ligado a una etapa o procedimiento

## Metadatos sugeridos por archivo

Cada archivo debería registrar:

- `id`
- `patientId`
- `treatmentId` opcional
- `name`
- `storagePath`
- `downloadUrl` temporal o resoluble
- `mimeType`
- `sizeBytes`
- `uploadedBy`
- `uploadedAt`
- `category` opcional (`radiografia`, `pdf_clinico`, `foto`, `consentimiento`, etc.)
- `notes` opcional

## UX sugerida

### Vista admin
- botón `Subir archivo`
- tabla o lista de archivos
- preview según tipo
- chips por categoría
- columna de fecha
- columna de tratamiento relacionado
- acciones: ver, descargar, eliminar

### Vista paciente
Esto debe definirse. Por ahora, la interpretación más segura es:
- solo admin/doctora tiene acceso completo
- no asumir que el paciente verá todos los archivos clínicos sensibles

## Reglas de seguridad

- no exponer URLs públicas permanentes
- controlar lectura/escritura por rol admin
- usar Storage con rutas por paciente
- dejar trazabilidad de quién subió cada archivo

## Estructura sugerida

### En Firestore
Colección o subcolección tipo:
- `patients/{patientId}/clinicalFiles/{fileId}`

### En Storage
Ruta sugerida:
- `patients/{patientId}/clinical-files/{fileId}_{originalName}`

Si se asocia a tratamiento, puede incluirse también:
- `patients/{patientId}/treatments/{treatmentId}/clinical-files/...`

## Casos de uso clave

1. La doctora abre el paciente.
2. Entra al tab Historial clínico.
3. Sube un PDF o imagen.
4. Opcionalmente lo asocia al tratamiento seleccionado.
5. El archivo queda listado con fecha, nombre y categoría.

## Riesgos funcionales

- si los archivos no se asocian bien, la historia clínica quedará desordenada
- si no hay permisos finos, puede haber exposición indebida de información sensible
- si no hay nombres/categorías claras, luego será difícil buscar documentos

## Entregables sugeridos

- modelo de archivo clínico
- repositorio para upload/list/delete
- UI admin para historial clínico
- integración con Firebase Storage
- políticas de seguridad revisadas

## Decisiones para validar

- qué tipos de archivo se permitirán exactamente
- tamaño máximo por archivo
- si el paciente verá alguno de esos archivos desde su app/web
- si debe existir clasificación obligatoria por categoría
