# WORK_ORDER_GESTION_PACIENTES.md

## BLOQUE ACTIVO

**04_GESTION_PACIENTES**

## Estado de entrada
- Auth/Login/Guards/FCM: **cerrado para avance**.
- Backend roles: operativo como bloque separado.

## Objetivo del bloque
Implementar gestión de pacientes completa según `docs/specs/04_GESTION_PACIENTES.md`:
- lista admin de pacientes,
- detalle por tabs,
- formulario crear/editar,
- repositorio + provider reactivo,
- vista de perfil propio para paciente.

## Alcance (sí se implementa)
1. `PatientsListScreen` con buscador y filtros en cliente.
2. `PatientDetailScreen` con TabBar (Perfil, Tratamiento, Citas, Pagos, Simulador).
3. `PatientFormScreen` para crear/editar datos permitidos.
4. `patients_repository.dart` con métodos CRUD/streams.
5. `patients_provider.dart` con Riverpod y estado reactivo.
6. `PatientProfileScreen` para paciente con restricciones de edición.

## Fuera de alcance (aún no)
- Pagos funcionales completos.
- Simulador de sonrisa completo.
- Rediseño de arquitectura global.

## Reglas de implementación
- Riverpod para estado; no `FutureBuilder` directo como patrón principal de pantalla.
- Repositorio como única puerta a Firestore.
- `ListView.builder` para listados (evitar render pesado).
- Mantener tema OCG y manejo de errores visible.
- Respetar permisos por rol en rutas y acciones.

## Criterios de cierre del bloque
- [ ] Lista de pacientes funcional (stream + búsqueda + filtros).
- [ ] Detalle de paciente con 5 tabs funcionales.
- [ ] Formulario de alta/edición funcional y validado.
- [ ] Repositorio y provider de pacientes implementados.
- [ ] Perfil paciente propio con campos clínicos en solo lectura.
- [ ] Validación manual mínima de CRUD y navegación por rol.

## Orden recomendado de ejecución
1. Modelos + repositorio + providers.
2. PatientsListScreen.
3. PatientDetailScreen (estructura tabs).
4. PatientFormScreen.
5. PatientProfileScreen.
6. Validación + documentación de cierre.
