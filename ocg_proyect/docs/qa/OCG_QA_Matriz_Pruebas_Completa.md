# OCG — Matriz Completa de Pruebas Funcionales y de Regresión

## Objetivo
Este documento define la batería de pruebas funcionales, de integración, regresión y validación visual para el sistema OCG en su estado actual.

El objetivo es usar esta matriz como criterio de aceptación para validar que el sistema no presente errores antes de considerarlo estable.

## Alcance actual cubierto
Esta matriz cubre:

- Autenticación y control de acceso
- Módulo paciente
  - Home
  - Tratamiento
  - Citas
  - Pagos
  - Perfil
  - Simulaciones
- Módulo admin
  - Pacientes
  - Detalle de paciente
  - Tratamiento
  - Agenda / Citas
  - Pagos
  - Simulador
- Integración, consistencia y regresión
- Responsive y navegación general

## Convención sugerida para ejecución
Usar estas columnas al momento de probar:

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| AUTH-01 | Autenticación | Login correcto con admin | Redirige al panel admin | Pendiente |  |

Estados sugeridos:

- Pendiente
- OK
- Falló
- Bloqueado

---

# 1. Autenticación y acceso

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| AUTH-01 | Autenticación | Iniciar sesión con credenciales válidas de admin | Accede correctamente y redirige al panel/rutas de administrador | Pendiente |  |
| AUTH-02 | Autenticación | Iniciar sesión con credenciales válidas de paciente | Accede correctamente y redirige a `/patient/home` | Pendiente |  |
| AUTH-03 | Autenticación | Intentar login con correo vacío | El formulario valida y no intenta iniciar sesión | Pendiente |  |
| AUTH-04 | Autenticación | Intentar login con correo inválido | El formulario muestra error y no intenta iniciar sesión | Pendiente |  |
| AUTH-05 | Autenticación | Intentar login con contraseña vacía | El formulario valida y no intenta iniciar sesión | Pendiente |  |
| AUTH-06 | Autenticación | Login con contraseña incorrecta | Muestra mensaje de credenciales incorrectas y no entra | Pendiente |  |
| AUTH-07 | Autenticación | Login con usuario inexistente o eliminado | No entra, permanece en login y muestra error controlado | Pendiente |  |
| AUTH-08 | Autenticación | Login con usuario deshabilitado | No entra y muestra error controlado | Pendiente |  |
| AUTH-09 | Autenticación | Login sin conexión a internet | Muestra mensaje de red y no rompe la pantalla | Pendiente |  |
| AUTH-10 | Autenticación | Presionar varias veces seguidas el botón de login | Solo se procesa una operación y la UI permanece estable | Pendiente |  |
| AUTH-11 | Autenticación | Crear cuenta desde login con datos válidos | Se crea la cuenta y aparece banner de éxito | Pendiente |  |
| AUTH-12 | Autenticación | Crear cuenta con correo duplicado | No crea la cuenta y muestra error claro | Pendiente |  |
| AUTH-13 | Autenticación | Crear cuenta con contraseñas distintas | No crea la cuenta y muestra validación | Pendiente |  |
| AUTH-14 | Autenticación | Crear cuenta con contraseña inválida o débil | No crea la cuenta y muestra validación/error | Pendiente |  |
| AUTH-15 | Autenticación | Abrir “¿Olvidaste tu contraseña?” | Navega a la pantalla de recuperación | Pendiente |  |
| AUTH-16 | Autenticación | Recuperación con correo válido | Muestra confirmación de envío de enlace | Pendiente |  |
| AUTH-17 | Autenticación | Recuperación con correo inválido | Muestra mensaje de correo inválido | Pendiente |  |
| AUTH-18 | Autenticación | Recuperación con correo no registrado | Muestra mensaje de cuenta inexistente | Pendiente |  |
| AUTH-19 | Autenticación | Recuperación sin internet | Muestra mensaje de red y no crashea | Pendiente |  |
| AUTH-20 | Seguridad / Rutas | Usuario no autenticado abre una ruta protegida | Es redirigido a login | Pendiente |  |
| AUTH-21 | Seguridad / Rutas | Paciente intenta abrir ruta admin | Es redirigido a home del paciente | Pendiente |  |
| AUTH-22 | Seguridad / Rutas | Admin intenta abrir ruta paciente | Es redirigido al panel admin | Pendiente |  |
| AUTH-23 | Seguridad / Rutas | Resolver sesión/rol en splash | No debe mostrar zonas protegidas antes de validar rol | Pendiente |  |
| AUTH-24 | Autenticación | Cerrar sesión como paciente | Sale correctamente y vuelve a login | Pendiente |  |
| AUTH-25 | Autenticación | Cerrar sesión como admin | Sale correctamente y vuelve a login | Pendiente |  |

---

# 2. Paciente — Home y tratamiento

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| PAT-HOME-01 | Paciente / Home | Abrir home con paciente válido | Carga saludo, progreso, próxima cita, pagos y etapas | Pendiente |  |
| PAT-HOME-02 | Paciente / Home | Abrir home sin perfil clínico válido | Muestra estado vacío “Perfil no encontrado” o equivalente | Pendiente |  |
| PAT-HOME-03 | Paciente / Home | Tocar avatar/perfil | Navega correctamente a la sección perfil | Pendiente |  |
| PAT-HOME-04 | Paciente / Home | Tocar acceso a pagos desde home | Navega correctamente a la sección pagos | Pendiente |  |
| PAT-HOME-05 | Paciente / Navegación | Cambiar entre Inicio, Citas, Tratamiento, Pagos, Simulación y Perfil | Cambia de sección sin errores ni pérdida indebida de estado | Pendiente |  |
| PAT-HOME-06 | Paciente / Home | Ver próxima cita cuando existe | Muestra fecha y hora correctas | Pendiente |  |
| PAT-HOME-07 | Paciente / Home | Ver próxima cita cuando no existe | Muestra mensaje de ausencia de cita | Pendiente |  |
| PAT-HOME-08 | Paciente / Home | Ver estado de cuenta con total, pagado y pendiente | Las cifras deben ser coherentes | Pendiente |  |
| PAT-HOME-09 | Paciente / Home | Ver barra de avance de pago | El porcentaje debe ser correcto | Pendiente |  |
| PAT-HOME-10 | Paciente / Home | Ver etapas del tratamiento | La etapa actual se marca correctamente y las anteriores como completadas | Pendiente |  |
| PAT-TRAT-01 | Paciente / Tratamiento | Abrir sección tratamiento | Carga historial y etapa actual | Pendiente |  |
| PAT-TRAT-02 | Paciente / Tratamiento | Abrir tratamiento sin tratamiento activo | Muestra estado vacío controlado | Pendiente |  |
| PAT-TRAT-03 | Paciente / Tratamiento | Ver tarjeta de resumen del tratamiento | Muestra progreso, fechas y citas realizadas | Pendiente |  |
| PAT-TRAT-04 | Paciente / Tratamiento | Ver fase/barra visual | Coincide con la etapa actual | Pendiente |  |
| PAT-TRAT-05 | Paciente / Tratamiento | Expandir/colapsar timeline de etapas | Funciona sin errores visuales | Pendiente |  |
| PAT-TRAT-06 | Paciente / Tratamiento | Ver notas clínicas cuando existen | Las muestra correctamente | Pendiente |  |
| PAT-TRAT-07 | Paciente / Tratamiento | Validar fechas del historial por etapa | Corresponden al registro real | Pendiente |  |
| PAT-TRAT-08 | Paciente / Tratamiento | Intentar modificar historial clínico desde paciente | No debe permitir edición | Pendiente |  |

---

# 3. Paciente — Citas

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| PAT-CIT-01 | Paciente / Citas | Abrir “Mis citas” | Carga KPIs y listado correctamente | Pendiente |  |
| PAT-CIT-02 | Paciente / Citas | Filtrar por activas | Solo muestra programadas y confirmadas | Pendiente |  |
| PAT-CIT-03 | Paciente / Citas | Filtrar por completadas | Solo muestra completadas | Pendiente |  |
| PAT-CIT-04 | Paciente / Citas | Filtrar por incidencias | Solo muestra canceladas, no asistió y reprogramadas | Pendiente |  |
| PAT-CIT-05 | Paciente / Citas | Validar estado vacío por filtro | Muestra el mensaje correcto según el filtro | Pendiente |  |
| PAT-CIT-06 | Paciente / Citas | Revisar tarjeta de cita | Debe mostrar tipo, fecha, estado y notas/detalle | Pendiente |  |
| PAT-CIT-07 | Paciente / Citas | Abrir diálogo de nueva cita con botón “+” | Se abre correctamente | Pendiente |  |
| PAT-CIT-08 | Paciente / Citas | Revisar tipos disponibles al agendar | Solo permite valoración y control | Pendiente |  |
| PAT-CIT-09 | Paciente / Citas | Cambiar fecha en agendamiento | Refresca disponibilidad del día | Pendiente |  |
| PAT-CIT-10 | Paciente / Citas | Expandir y colapsar bloques mañana/tarde | Funciona sin romper el diálogo | Pendiente |  |
| PAT-CIT-11 | Paciente / Citas | Elegir día sin disponibilidad | Informa que no hay horarios disponibles | Pendiente |  |
| PAT-CIT-12 | Paciente / Citas | Agendar en horario válido | Crea la cita y muestra éxito | Pendiente |  |
| PAT-CIT-13 | Paciente / Citas | Intentar agendar dos citas el mismo día | Lo bloquea por regla de negocio | Pendiente |  |
| PAT-CIT-14 | Paciente / Citas | Intentar agendar cita en pasado | Lo bloquea | Pendiente |  |
| PAT-CIT-15 | Paciente / Citas | Intentar agendar fuera de horario laboral | Lo bloquea | Pendiente |  |
| PAT-CIT-16 | Paciente / Citas | Elegir slot que se ocupa antes de guardar | Muestra error de disponibilidad y no crea la cita | Pendiente |  |
| PAT-CIT-17 | Paciente / Citas | Cancelar cita con 24 horas o más | Permite cancelación normal | Pendiente |  |
| PAT-CIT-18 | Paciente / Citas | Cancelar cita con menos de 24 horas | No cancela directo; obliga a flujo por WhatsApp | Pendiente |  |
| PAT-CIT-19 | Paciente / Citas | Abrir WhatsApp desde cancelación tardía | Abre el chat con mensaje precargado | Pendiente |  |
| PAT-CIT-20 | Paciente / Citas | WhatsApp no disponible | Muestra mensaje de fallback sin romper la app | Pendiente |  |
| PAT-CIT-21 | Paciente / Citas | Revisar citas canceladas/completadas | No deben mostrar botón cancelar | Pendiente |  |
| PAT-CIT-22 | Paciente / Citas | Cambiar filtros varias veces | No duplica elementos ni altera conteos | Pendiente |  |

---

# 4. Paciente — Pagos

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| PAT-PAG-01 | Paciente / Pagos | Abrir “Mis pagos” | Carga resumen financiero | Pendiente |  |
| PAT-PAG-02 | Paciente / Pagos | Abrir pagos sin resumen financiero | Muestra error claro | Pendiente |  |
| PAT-PAG-03 | Paciente / Pagos | Validar total, pagado, pendiente y porcentaje | Los valores son correctos | Pendiente |  |
| PAT-PAG-04 | Paciente / Pagos | Caso sin base suficiente para porcentaje | No rompe la vista y muestra texto alterno | Pendiente |  |
| PAT-PAG-05 | Paciente / Pagos | Ver próximo pago con fecha | Muestra fecha correcta | Pendiente |  |
| PAT-PAG-06 | Paciente / Pagos | Ver próximo pago sin fecha | Muestra “Sin fecha programada” | Pendiente |  |
| PAT-PAG-07 | Paciente / Pagos | Saldo pendiente mayor a cero | Botón “Pagar con PayU” habilitado | Pendiente |  |
| PAT-PAG-08 | Paciente / Pagos | Saldo pendiente igual a cero | Botón deshabilitado y texto “Tratamiento pagado” | Pendiente |  |
| PAT-PAG-09 | Paciente / Pagos | Pulsar “Pagar con PayU” | Primero muestra confirmación | Pendiente |  |
| PAT-PAG-10 | Paciente / Pagos | Cancelar confirmación de pago | No inicia el flujo PayU | Pendiente |  |
| PAT-PAG-11 | Paciente / Pagos | Confirmar pago y recibir checkout URL | Navega a checkout PayU | Pendiente |  |
| PAT-PAG-12 | Paciente / Pagos | Error al iniciar pago PayU | Muestra snackbar de error controlado | Pendiente |  |
| PAT-PAG-13 | Paciente / Pagos | Filtro “Todos” | Muestra todas las transacciones | Pendiente |  |
| PAT-PAG-14 | Paciente / Pagos | Filtro “Pagados” | Muestra transacciones pagadas | Pendiente |  |
| PAT-PAG-15 | Paciente / Pagos | Filtro “Pendientes” con saldo | Muestra tarjeta de pago pendiente | Pendiente |  |
| PAT-PAG-16 | Paciente / Pagos | Filtro “Pendientes” sin saldo | Muestra estado vacío correcto | Pendiente |  |
| PAT-PAG-17 | Paciente / Pagos | Historial vacío | Muestra estado vacío correcto | Pendiente |  |
| PAT-PAG-18 | Paciente / Pagos | Revisar transacción individual | Muestra método, fecha, referencia y monto correctos | Pendiente |  |
| PAT-PAG-19 | Paciente / Pagos | Validar traducción del método de pago | Efectivo, Transferencia y PayU correctos | Pendiente |  |

---

# 5. Paciente — Perfil

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| PAT-PER-01 | Paciente / Perfil | Abrir perfil | Carga datos personales, clínicos y financieros | Pendiente |  |
| PAT-PER-02 | Paciente / Perfil | Abrir perfil sin registro clínico válido | Muestra mensaje controlado | Pendiente |  |
| PAT-PER-03 | Paciente / Perfil | Editar teléfono con valor nuevo válido | Guarda correctamente y muestra éxito | Pendiente |  |
| PAT-PER-04 | Paciente / Perfil | Abrir edición de teléfono y cancelar | No modifica el dato | Pendiente |  |
| PAT-PER-05 | Paciente / Perfil | Guardar teléfono vacío o igual al anterior | No debe generar cambios ni errores | Pendiente |  |
| PAT-PER-06 | Paciente / Perfil | Cambiar foto con imagen válida | Sube la imagen y actualiza el avatar | Pendiente |  |
| PAT-PER-07 | Paciente / Perfil | Abrir selector de imagen y cancelar | No rompe el flujo | Pendiente |  |
| PAT-PER-08 | Paciente / Perfil | Error en subida de foto | Muestra snackbar de error controlado | Pendiente |  |
| PAT-PER-09 | Paciente / Perfil | Pulsar “Cambiar” contraseña | Envía correo de reset al email del paciente | Pendiente |  |
| PAT-PER-10 | Paciente / Perfil | Error al enviar reset de contraseña | Muestra snackbar y mantiene la vista estable | Pendiente |  |
| PAT-PER-11 | Paciente / Perfil | Revisar campos clínicos y financieros | Son solo lectura para el paciente | Pendiente |  |
| PAT-PER-12 | Paciente / Perfil | Cerrar sesión desde perfil | Sale correctamente y vuelve a login | Pendiente |  |

---

# 6. Paciente — Simulaciones

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| PAT-SIM-01 | Paciente / Simulaciones | Abrir simulaciones sin datos | Muestra estado vacío correcto | Pendiente |  |
| PAT-SIM-02 | Paciente / Simulaciones | Abrir simulaciones con datos | Muestra disclaimer al inicio | Pendiente |  |
| PAT-SIM-03 | Paciente / Simulaciones | Simulación con imagen original y resultado | Muestra slider before/after | Pendiente |  |
| PAT-SIM-04 | Paciente / Simulaciones | Simulación con imágenes faltantes | Muestra fallback o placeholder | Pendiente |  |
| PAT-SIM-05 | Paciente / Simulaciones | URL de imagen dañada | Muestra mensaje de que no se pudo cargar | Pendiente |  |
| PAT-SIM-06 | Paciente / Simulaciones | Varias simulaciones compartidas | Lista correctamente todas | Pendiente |  |
| PAT-SIM-07 | Paciente / Simulaciones | Simulación con notas | Muestra notas si existen | Pendiente |  |
| PAT-SIM-08 | Paciente / Simulaciones | Intentar editar/generar simulación desde vista paciente | No debe existir esa acción en el estado actual | Pendiente |  |

---

# 7. Admin — Pacientes

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-PAC-01 | Admin / Pacientes | Abrir listado de pacientes | Carga correctamente | Pendiente |  |
| ADM-PAC-02 | Admin / Pacientes | Buscar por nombre | Filtra correctamente | Pendiente |  |
| ADM-PAC-03 | Admin / Pacientes | Buscar por correo | Filtra correctamente | Pendiente |  |
| ADM-PAC-04 | Admin / Pacientes | Aplicar filtro “Todos” | Muestra todos los pacientes | Pendiente |  |
| ADM-PAC-05 | Admin / Pacientes | Aplicar filtro “Pendientes” | Muestra solo pacientes pendientes | Pendiente |  |
| ADM-PAC-06 | Admin / Pacientes | Aplicar filtro “Activos” | Muestra solo pacientes activos | Pendiente |  |
| ADM-PAC-07 | Admin / Pacientes | Aplicar filtro “Alta” | Muestra solo pacientes dados de alta | Pendiente |  |
| ADM-PAC-08 | Admin / Pacientes | Filtrar por tipo de tratamiento | Segmenta correctamente | Pendiente |  |
| ADM-PAC-09 | Admin / Pacientes | Pulsar KPI Total pacientes | Aplica flujo/ruta correcta | Pendiente |  |
| ADM-PAC-10 | Admin / Pacientes | Pulsar KPI Activos | Aplica flujo/ruta correcta | Pendiente |  |
| ADM-PAC-11 | Admin / Pacientes | Pulsar KPI Citas hoy | Abre agenda | Pendiente |  |
| ADM-PAC-12 | Admin / Pacientes | Pulsar KPI Saldo pendiente | Abre pagos | Pendiente |  |
| ADM-PAC-13 | Admin / Pacientes | Crear paciente con datos válidos | Crea cuenta y aparece en listado | Pendiente |  |
| ADM-PAC-14 | Admin / Pacientes | Crear paciente con correo duplicado | No crea y muestra error claro | Pendiente |  |
| ADM-PAC-15 | Admin / Pacientes | Crear paciente con monto inválido o cero | No crea y valida correctamente | Pendiente |  |
| ADM-PAC-16 | Admin / Pacientes | Crear paciente con contraseñas distintas | No crea y valida correctamente | Pendiente |  |
| ADM-PAC-17 | Admin / Pacientes | Crear paciente desde FAB en móvil | Abre y funciona correctamente | Pendiente |  |
| ADM-PAC-18 | Admin / Pacientes | Abrir detalle tocando fila/tarjeta de paciente | Abre el detalle correcto | Pendiente |  |
| ADM-PAC-19 | Admin / Pacientes | Cerrar sesión desde módulo pacientes | Sale correctamente con confirmación | Pendiente |  |

---

# 8. Admin — Detalle de paciente

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-DET-01 | Admin / Detalle paciente | Abrir detalle de paciente válido | Carga workspace completo | Pendiente |  |
| ADM-DET-02 | Admin / Detalle paciente | Abrir detalle de paciente inexistente | Muestra mensaje de no encontrado y opción de volver | Pendiente |  |
| ADM-DET-03 | Admin / Detalle paciente | Abrir con `?section=perfil` | Entra en perfil | Pendiente |  |
| ADM-DET-04 | Admin / Detalle paciente | Abrir con `?section=tratamiento` | Entra en tratamiento | Pendiente |  |
| ADM-DET-05 | Admin / Detalle paciente | Abrir con `?section=citas` | Entra en citas | Pendiente |  |
| ADM-DET-06 | Admin / Detalle paciente | Abrir con `?section=pagos` | Entra en pagos | Pendiente |  |
| ADM-DET-07 | Admin / Detalle paciente | Abrir con `?section=simulador` | Entra en simulador | Pendiente |  |
| ADM-DET-08 | Admin / Detalle paciente | Pulsar botón editar | Navega a edición del paciente | Pendiente |  |
| ADM-DET-09 | Admin / Detalle paciente | Pulsar eliminar y cancelar | No elimina el paciente | Pendiente |  |
| ADM-DET-10 | Admin / Detalle paciente | Pulsar eliminar y confirmar | Elimina, muestra éxito y vuelve al listado | Pendiente |  |
| ADM-DET-11 | Admin / Detalle paciente | Validar estado posterior a eliminación | El paciente no debe volver a aparecer ni abrirse | Pendiente |  |
| ADM-DET-12 | Admin / Detalle paciente | Agendar cita desde detalle | Abre diálogo con paciente preseleccionado | Pendiente |  |

---

# 9. Admin — Tratamiento del paciente

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-TRAT-01 | Admin / Tratamiento | Abrir pestaña tratamiento en detalle | Carga timeline e historial | Pendiente |  |
| ADM-TRAT-02 | Admin / Tratamiento | Paciente con tratamiento y monto definidos | Muestra badge de definición inicial correcta | Pendiente |  |
| ADM-TRAT-03 | Admin / Tratamiento | Pulsar avanzar etapa | Abre diálogo de actualización de etapa | Pendiente |  |
| ADM-TRAT-04 | Admin / Tratamiento | Confirmar cambio de etapa | Actualiza la etapa actual | Pendiente |  |
| ADM-TRAT-05 | Admin / Tratamiento | Revisar historial tras cambio de etapa | Agrega registro nuevo correctamente | Pendiente |  |
| ADM-TRAT-06 | Admin / Tratamiento | Reabrir vista tras cambio | La persistencia debe mantenerse | Pendiente |  |

---

# 10. Admin — Agenda / Citas

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-CIT-01 | Admin / Agenda | Abrir agenda | Carga pestaña Hoy por defecto | Pendiente |  |
| ADM-CIT-02 | Admin / Agenda | Cambiar entre Hoy, Mes e Historial | Cambia correctamente sin errores | Pendiente |  |
| ADM-CIT-03 | Admin / Agenda | Pulsar “Nueva cita” | Abre diálogo de creación | Pendiente |  |
| ADM-CIT-04 | Admin / Agenda | Pulsar “Crear cuenta paciente” | Abre flujo y crea cuenta correctamente | Pendiente |  |
| ADM-CIT-05 | Admin / Agenda | Intentar crear cita sin seleccionar paciente | Bloquea y muestra error | Pendiente |  |
| ADM-CIT-06 | Admin / Agenda | Buscar paciente por nombre en diálogo | Muestra resultados correctos | Pendiente |  |
| ADM-CIT-07 | Admin / Agenda | Seleccionar paciente del dropdown | Queda seleccionado correctamente | Pendiente |  |
| ADM-CIT-08 | Admin / Agenda | Quitar chip de paciente seleccionado | Permite cambiar paciente y limpia el buscador | Pendiente |  |
| ADM-CIT-09 | Admin / Agenda | Crear cita válida | La cita aparece en agenda | Pendiente |  |
| ADM-CIT-10 | Admin / Agenda | Crear cita en horario ocupado o dentro de buffer | Lo bloquea | Pendiente |  |
| ADM-CIT-11 | Admin / Agenda | Crear cita en pasado | Lo bloquea | Pendiente |  |
| ADM-CIT-12 | Admin / Agenda | Crear cita fuera de horario laboral | Lo bloquea | Pendiente |  |
| ADM-CIT-13 | Admin / Agenda | Crear cita y verificarla en agenda del paciente | Ambas vistas son consistentes | Pendiente |  |
| ADM-CIT-14 | Admin / Agenda | Confirmar cita programada | Cambia a confirmada | Pendiente |  |
| ADM-CIT-15 | Admin / Agenda | Cancelar cita programada o confirmada | Cambia a cancelada | Pendiente |  |
| ADM-CIT-16 | Admin / Agenda | Reprogramar cita | Cambia fecha/hora/duración/notas respetando reglas | Pendiente |  |
| ADM-CIT-17 | Admin / Agenda | Reprogramar a slot inválido | Lo bloquea | Pendiente |  |
| ADM-CIT-18 | Admin / Agenda | Completar cita que no es valoración | Cambia a completada | Pendiente |  |
| ADM-CIT-19 | Admin / Agenda | Completar valoración sin tratamiento definido | Obliga a dictamen inicial | Pendiente |  |
| ADM-CIT-20 | Admin / Agenda | Dictamen sin seleccionar tratamiento | No deja guardar | Pendiente |  |
| ADM-CIT-21 | Admin / Agenda | Dictamen con monto inválido o cero | No deja guardar | Pendiente |  |
| ADM-CIT-22 | Admin / Agenda | Dictamen completo válido | Actualiza tratamiento, monto y etapa; completa la cita | Pendiente |  |
| ADM-CIT-23 | Admin / Agenda | Completar valoración con paciente ya configurado | No vuelve a pedir dictamen | Pendiente |  |
| ADM-CIT-24 | Admin / Agenda | Reabrir cita completada | Vuelve a estado confirmada | Pendiente |  |
| ADM-CIT-25 | Admin / Agenda | Revisar resumen diario | Totales correctos por estado | Pendiente |  |
| ADM-CIT-26 | Admin / Agenda | Revisar calendario mensual | Marca días con citas correctamente | Pendiente |  |
| ADM-CIT-27 | Admin / Agenda | Seleccionar día en vista Mes | Muestra detalle correcto de citas de ese día | Pendiente |  |
| ADM-CIT-28 | Admin / Agenda | Revisar historial con filtros | Agrupa y filtra correctamente | Pendiente |  |
| ADM-CIT-29 | Admin / Agenda | Pulsar “Cargar más” en historial | Pagina correctamente | Pendiente |  |
| ADM-CIT-30 | Admin / Agenda | Abrir perfil del paciente desde una cita | Lleva al detalle correcto del paciente | Pendiente |  |

---

# 11. Admin — Pagos

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-PAG-01 | Admin / Pagos | Abrir módulo pagos | Carga cartera activa correctamente | Pendiente |  |
| ADM-PAG-02 | Admin / Pagos | Revisar KPI “Con saldo” | Cantidad correcta | Pendiente |  |
| ADM-PAG-03 | Admin / Pagos | Revisar KPI “Vencidos” | Cantidad correcta | Pendiente |  |
| ADM-PAG-04 | Admin / Pagos | Revisar KPI “Saldo pendiente” | Valor correcto | Pendiente |  |
| ADM-PAG-05 | Admin / Pagos | Toggle “Con saldo / Vencidos” en desktop | Filtra correctamente | Pendiente |  |
| ADM-PAG-06 | Admin / Pagos | Toggle “Todos / Vencidos” en móvil | Filtra correctamente | Pendiente |  |
| ADM-PAG-07 | Admin / Pagos | Paciente con deuda vencida | Se marca visualmente como crítico | Pendiente |  |
| ADM-PAG-08 | Admin / Pagos | Abrir detalle tocando paciente de cartera | Navega al detalle correcto | Pendiente |  |
| ADM-PAG-09 | Admin / Pagos | Registrar pago manual desde pagos del paciente | Abre diálogo correspondiente | Pendiente |  |
| ADM-PAG-10 | Admin / Pagos | Registrar pago manual válido | Crea transacción y actualiza saldo | Pendiente |  |
| ADM-PAG-11 | Admin / Pagos | Registrar pago manual con monto inválido o cero | No registra y no rompe la vista | Pendiente |  |
| ADM-PAG-12 | Admin / Pagos | Validar consistencia después de registrar pago | Resumen, saldo e historial quedan actualizados | Pendiente |  |

---

# 12. Admin — Simulador

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| ADM-SIM-01 | Admin / Simulador | Abrir módulo simulador | Lista pacientes con acceso | Pendiente |  |
| ADM-SIM-02 | Admin / Simulador | Tocar paciente desde simulador | Abre detalle del paciente en sección simulador | Pendiente |  |
| ADM-SIM-03 | Admin / Simulador | Abrir simulador del paciente desde detalle | Carga simulaciones compartidas | Pendiente |  |
| ADM-SIM-04 | Admin / Simulador | Paciente sin simulaciones | Muestra estado vacío correcto | Pendiente |  |
| ADM-SIM-05 | Admin / Simulador | Paciente con simulaciones | Muestra slider o fallback correctamente | Pendiente |  |
| ADM-SIM-06 | Admin / Simulador | Revisar acciones disponibles en estado actual | No deben existir acciones de generación si aún no están implementadas | Pendiente |  |

---

# 13. Responsive, integración y regresión

| ID | Módulo | Prueba | Resultado esperado | Estado | Evidencia |
|---|---|---|---|---|---|
| REG-01 | Responsive | Login en móvil | Footer correctamente ubicado y sin huecos visuales | Pendiente |  |
| REG-02 | Responsive | Login en desktop | Layout centrado y funcional | Pendiente |  |
| REG-03 | Responsive / Admin | Pantallas admin en desktop | Usan shell y rail correctamente | Pendiente |  |
| REG-04 | Responsive / Admin | Pantallas admin en móvil | Usan drawer y mantienen navegación estable | Pendiente |  |
| REG-05 | Integración | Embedded screens dentro del detalle del paciente | No duplican AppBar ni rompen scroll | Pendiente |  |
| REG-06 | Integración | Vista admin viewer con `patientIdOverride` | Muestra datos del paciente, no del admin autenticado | Pendiente |  |
| REG-07 | Integración | Editar teléfono o foto desde perfil | El cambio se refleja en otras vistas relacionadas | Pendiente |  |
| REG-08 | Integración | Cambios en citas desde admin | Se reflejan correctamente en vistas del paciente y admin | Pendiente |  |
| REG-09 | Integración | Registrar pago manual | Se refleja en saldo e historial del paciente | Pendiente |  |
| REG-10 | Integración | Avanzar etapa o completar valoración con dictamen | Tratamiento e historial quedan sincronizados | Pendiente |  |
| REG-11 | Integración | Eliminar paciente | Limpia acceso a detalle y evita enlaces rotos | Pendiente |  |
| REG-12 | Regresión | Cancelar/cerrar cualquier diálogo | No queda diálogo colgado ni UI bloqueada | Pendiente |  |
| REG-13 | Regresión | Disparar acción repetida rápidamente | No duplica registros ni crea estados inconsistentes | Pendiente |  |
| REG-14 | Regresión | Error de red/Auth/Firestore/Storage | No rompe la UI ni la deja bloqueada | Pendiente |  |
| REG-15 | Regresión | Revisar banners, snackbars y empty states | El mensaje corresponde al caso real | Pendiente |  |

---

# 14. Pruebas bloqueantes

Estas pruebas deben considerarse críticas. Si alguna falla, el sistema no debería darse por estable.

| ID | Motivo |
|---|---|
| AUTH-07 | Usuario eliminado o inexistente no puede entrar ni generar rebote de sesión |
| AUTH-20 | Usuario no autenticado no puede acceder a rutas protegidas |
| AUTH-21 | Paciente no puede entrar al área admin |
| AUTH-22 | Admin no puede quedar expuesto en rutas de paciente |
| PAT-CIT-13 | No debe poder agendar dos citas el mismo día si la regla lo prohíbe |
| PAT-CIT-14 | No debe poder agendar en el pasado |
| PAT-CIT-15 | No debe poder agendar fuera del horario laboral |
| PAT-CIT-16 | Debe manejar correctamente carreras de disponibilidad |
| PAT-CIT-17 | Cancelación normal debe funcionar cuando está permitida |
| PAT-CIT-18 | Cancelación con menos de 24 horas debe respetar la regla de negocio |
| ADM-CIT-10 | Admin no puede agendar sobre un horario ocupado o dentro del buffer |
| ADM-CIT-16 | Reprogramación debe respetar todas las reglas del sistema |
| ADM-CIT-19 | Valoración inicial debe obligar dictamen cuando corresponde |
| ADM-CIT-22 | Dictamen completo debe actualizar correctamente tratamiento y cita |
| ADM-CIT-24 | Reabrir una cita completada debe funcionar sin dañar consistencia |
| ADM-PAG-10 | Registro manual de pago debe actualizar correctamente saldo e historial |
| REG-08 | La consistencia entre vistas de admin y paciente en citas es obligatoria |
| REG-09 | La consistencia financiera después de registrar pagos es obligatoria |
| REG-10 | La sincronización entre tratamiento e historial es obligatoria |

---

# 15. Recomendación final de ejecución

## Orden sugerido

1. Autenticación y guards
2. Pacientes admin
3. Agenda admin
4. Flujo paciente de citas
5. Flujo paciente de pagos
6. Perfil paciente
7. Tratamiento admin/paciente
8. Simulador
9. Regresión completa
10. Responsive final

## Evidencia recomendada

Guardar para cada prueba que falle:

- Captura de pantalla
- Video corto si aplica
- Usuario probado
- Rol probado
- Ruta exacta
- Fecha y hora
- Pasos ejecutados
- Resultado obtenido
- Resultado esperado

---

# 16. Criterio de aceptación final

El sistema solo debe considerarse listo cuando:

- No existan fallos en pruebas bloqueantes
- No existan inconsistencias entre vistas admin y paciente
- No existan errores funcionales en autenticación, citas, pagos, tratamiento y perfil
- No existan errores de navegación o acceso por rol
- No existan errores graves de responsive o de diálogos bloqueados

