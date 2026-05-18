# Auditoría de Seguridad - OCG Clinica

**Fecha:** 2026-05-18
**Alcance:** Bloque 10 - Seguridad, privacidad y permisos
**Estado:** ✅ Completado

---

## 1. Reglas de Firestore

### 1.1 Consultas (`patients/{patientId}/consultations/{consultationId}`)

| Operación | Admin | Paciente |
|---|---|---|
| Read | ✅ | ❌ |
| Create | ✅ | ❌ |
| Update | ✅ | ❌ |
| Delete | ❌ | ❌ |

**Justificación:** Las consultas contienen datos clinicos sensibles (diagnostico, tratamiento, notas clinicas). El paciente no debe acceder directamente a estos documentos. Solo el administrador/clinico puede leerlos.

### 1.2 Documentos Clinicos (`patients/{patientId}/clinicalFiles/{fileId}`)

| Operación | Admin | Paciente |
|---|---|---|
| Read | ✅ | ✅ Solo si `visibleToPatient == true` Y `active == true` |
| Create | ✅ | ❌ |
| Update | ✅ | ❌ |
| Delete | ❌ | ❌ |

**Justificación:** Los documentos clinicos pueden ser visibles para el paciente si la clinica lo marca explicitamente (`visibleToPatient`). Por defecto, los PDFs generados tienen `visibleToPatient: false`.

### 1.3 Documentos por Tratamiento (`patients/{patientId}/treatments/{treatmentId}/clinicalFiles/{fileId}`)

| Operación | Admin | Paciente |
|---|---|---|
| Read | ✅ | ✅ Solo si `visibleToPatient == true` Y `active == true` |
| Create | ✅ | ❌ |
| Update | ✅ | ❌ |
| Delete | ❌ | ❌ |

### 1.4 Historial de Etapas (General y por Tratamiento)

| Colección | Admin Read | Paciente Read | Write | Delete |
|---|---|---|---|---|
| `stageHistory/{entryId}` | ✅ | ✅ | ✅ Admin + validaciones | ❌ |
| `treatments/{treatmentId}/stageHistory/{entryId}` | ✅ | ✅ | ✅ Admin + validaciones | ❌ |

### 1.5 Citas (`appointments/{appointmentId}`)

| Operación | Admin | Paciente |
|---|---|---|
| Read | ✅ | ✅ Solo sus propias citas |
| Create | ✅ | ❌ |
| Update | ✅ | ✅ Solo para cancelar (`estado == 'cancelada'`) |
| Delete | ✅ | ❌ |

### 1.6 Pagos y Transacciones

- Admin: acceso total
- Paciente: solo lectura de sus propios pagos/transacciones

### 1.7 Simulaciones

- Admin: acceso total
- Paciente: solo si `compartidaConPaciente == true` Y `status == 'shared'`

---

## 2. Reglas de Storage

### 2.1 Paths protegidos

| Path | Admin | Paciente |
|---|---|---|
| `patients/{patientId}/clinical-files/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/treatments/{treatmentId}/clinical-files/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/consultations/signatures/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/consultations/files/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/consultations/reports/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/photos/{fileName}` | ✅ R/W | ❌ |
| `patients/{patientId}/profile/{fileName}` | ✅ R/W | ✅ R/W |
| `admins/{adminId}/profile/{fileName}` | ✅ R/W | ❌ |

**Notas:**
- Firmas digitales y PDFs generados son **exclusivamente** accesibles por admin
- Los archivos clinicos en Storage no son accesibles directamente por el paciente (se sirven via app con validacion de `visibleToPatient`)
- Perfil: ambos pueden leer/escribir sus propias fotos

---

## 3. Proteccion de Datos Sensibles

### 3.1 PDFs Generados (Dictamenes)

- Por defecto: `visibleToPatient: false`
- Solo el admin puede cambiar esta flag
- El paciente no ve el PDF en su vista de historial clinico a menos que el admin lo marque como visible

### 3.2 Notificaciones por Email

- Las notificaciones de recordatorio de cita NO contienen datos clinicos
- Solo incluyen: fecha, hora, nombre de la clinica
- **Prohibido** enviar diagnosticos, tratamientos o notas clinicas por email

### 3.3 Trazabilidad

- Todos los documentos clinicos incluyen: `createdBy`, `createdAt`, `updatedBy`, `updatedAt`
- Los dictamenes incluyen `dictamenTreatmentId`, `dictamenStageName`, `dictamenCreatedAt`
- Esto permite auditar quien creo/modifico cada registro

---

## 4. Recomendaciones Pendientes

1. **Rate limiting:** Considerar limitacion de peticiones a consultas clinicas
2. **Audit logging:** Implementar registro de accesos a datos sensibles
3. **Encryptacion en reposo:** Considerar encripcion de datos clinicos sensibles
4. **Consentimiento del paciente:** Implementar flujo de consentimiento explicito para compartir documentos
5. **Retencion de datos:** Definir politica de retencion y eliminacion de datos clinicos

---

## 5. Criterio de Cierre - Bloque 10

- [x] Reglas de Firestore revisadas y actualizadas para todas las colecciones relevantes
- [x] Reglas de Storage revisadas y actualizadas (incluyendo `consultations/reports/`)
- [x] Paciente solo ve documentos con `visibleToPatient == true`
- [x] PDF generado tiene `visibleToPatient: false` por defecto
- [x] Notificaciones por email no envian datos clinicos sensibles
- [x] Admin puede generar/ver PDFs
- [x] Documento de auditoria creado
