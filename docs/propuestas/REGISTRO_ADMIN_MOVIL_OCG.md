# Registro Admin Móvil OCG

## Objetivo general
Optimizar la experiencia del administrador en móvil para que no sea una copia rota del dashboard desktop, sino una versión operativa, clínica y profesional.

## Principio UX
Desktop = administración completa.
Móvil = operación rápida en consulta.

## Fecha de inicio
- 2026-04-28

## Problemas encontrados
- Pantalla: Shell admin principal
- Qué se rompe: la estructura general sigue naciendo desde módulos pensados para desktop; aunque existe `OcgAdaptiveScaffold`, varias pantallas aún heredan densidad, bloques y acciones de escritorio.
- Por qué se rompe: el sistema mezcla navegación responsive con contenido todavía desktop-first.
- Archivo probable:
  - `lib/features/dashboard/presentation/admin_modules_screens.dart`
  - `lib/features/admin/presentation/web/layout/admin_desktop_layout.dart`
  - `lib/features/admin/presentation/web/components/admin_sidebar.dart`

- Pantalla: Sidebar en móvil
- Qué se rompe: el sidebar desktop sigue siendo la referencia conceptual del panel; en móvil no debe ser el centro del flujo.
- Por qué se rompe: el contenido y rutas están organizados como módulos laterales de escritorio, no como navegación clínica rápida.
- Archivo probable:
  - `lib/features/admin/presentation/web/components/admin_sidebar.dart`
  - `lib/features/dashboard/presentation/admin_modules_screens.dart`

- Pantalla: Pantalla de pacientes admin
- Qué se rompe: alta probabilidad de densidad excesiva y navegación de escritorio comprimida cuando se entra al detalle desde móvil.
- Por qué se rompe: el flujo principal del admin hoy sigue muy orientado a administración completa.
- Archivo probable:
  - `lib/features/dashboard/presentation/admin_patients_screen.dart`
  - `lib/features/dashboard/presentation/patient_home_screen.dart`

- Pantalla: Detalle del paciente
- Qué se rompe: todavía opera por tabs y secciones pesadas; no está claramente reorganizado como ficha clínica móvil por cards.
- Por qué se rompe: el detalle actual está pensado para contener mucha administración en un solo punto.
- Archivo probable:
  - `lib/features/dashboard/presentation/patient_home_screen.dart`

- Pantalla: Tab Tratamientos
- Qué se rompe: el flujo de tratamientos incluye edición compleja y estructuras amplias poco aptas para celular.
- Por qué se rompe: el módulo de tratamiento sigue teniendo mentalidad desktop y formularios/modales extensos.
- Archivo probable:
  - `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
  - `lib/features/treatment/presentation/widgets/manage_patient_treatment_dialog.dart`

- Pantalla: Tab Pagos
- Qué se rompe: en desktop ya existe una capa más rica; en móvil el detalle del paciente puede quedar desactualizado o demasiado denso si intenta replicarla.
- Por qué se rompe: pagos mezcla resumen, historial y acciones de escritorio con riesgo de overflow o exceso de información.
- Archivo probable:
  - `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
  - `lib/features/dashboard/presentation/admin_modules_screens.dart`

- Pantalla: Tab Simulador
- Qué se rompe: aunque el flujo ya está mejor orientado, todavía depende de pantallas con secciones largas que deben priorizar consulta en vertical.
- Por qué se rompe: el simulador ya está funcional, pero necesita refinamiento móvil como herramienta de consulta rápida en silla.
- Archivo probable:
  - `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
  - `lib/features/simulator/presentation/simulator_screen.dart`

- Pantalla: Simulador del sidebar admin
- Qué se rompe: la pantalla global del simulador mantiene tono dashboard con grids/cards de escritorio, no experiencia móvil enfocada.
- Por qué se rompe: está montada dentro de `admin_modules_screens.dart` con estrategia responsive superficial.
- Archivo probable:
  - `lib/features/dashboard/presentation/admin_modules_screens.dart`

- Pantalla: PatientSimulatorTab
- Qué se rompe: debe verificarse que en móvil no exponga demasiado contexto y que priorice CTA claros (nueva simulación, ver estado, compartir).
- Por qué se rompe: el tab aún convive con lógica pensada para módulos administrativos más amplios.
- Archivo probable:
  - `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`

- Pantalla: SimulatorScreen
- Qué se rompe: la longitud vertical está bien para móvil, pero necesita validación de jerarquía visual, bloqueo de acciones, y simplificación de acciones secundarias.
- Por qué se rompe: el flujo todavía tiene herencia de casos desktop/diagnóstico y no una capa claramente “consulta rápida”.
- Archivo probable:
  - `lib/features/simulator/presentation/simulator_screen.dart`

- Pantalla: PatientSimulationsScreen
- Qué se rompe: la visualización de simulaciones compartidas y comparador before/after puede ser funcional, pero debe revisarse la densidad de cards e imágenes en pantallas estrechas.
- Por qué se rompe: aún conserva estructuras pensadas para listas más amplias.
- Archivo probable:
  - `lib/features/simulator/presentation/patient_simulations_screen.dart`

## Decisión UX
Desktop:
- Mantener sidebar completo.
- Mantener módulos amplios de administración, filtros, KPIs, tablas/cards complejos y edición profunda.

Móvil:
- Convertir el admin en una experiencia clínica de consulta rápida.
- Priorización por tareas de consulta:
  - buscar paciente
  - abrir detalle clínico
  - revisar tratamiento activo
  - revisar saldo e historial reciente
  - registrar pago básico si ya existe
  - tomar/subir foto clínica
  - crear simulación con IA
  - revisar before/after
  - compartir simulación
- Todo lo pesado o administrativo debe simplificarse o delegarse a desktop con mensaje claro.

## Módulos que sí van en móvil
- Inicio
- Pacientes
- Agenda
- Simulador
- Más

## Módulos que se simplifican en móvil
- Tratamientos
- Pagos
- Configuración

## Archivos candidatos a modificar
- `lib/features/dashboard/presentation/admin_modules_screens.dart`
- `lib/features/dashboard/presentation/patient_home_screen.dart`
- `lib/features/dashboard/presentation/admin_patients_screen.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`
- Si hace falta:
  - `lib/features/admin/presentation/web/layout/admin_desktop_layout.dart`
  - `lib/features/admin/presentation/web/components/admin_sidebar.dart`

## Riesgos
- Romper desktop si se mezclan decisiones móviles dentro de layouts globales sin separación clara.
- Duplicar navegación si no se centraliza bien el shell responsive.
- Dejar tabs del detalle del paciente inconsistentes entre móvil y desktop.
- Generar deuda UX si se intenta “encoger” desktop en vez de resumirlo.
- Crear más de un flujo del simulador si no se reutiliza la base ya construida.

## Plan mínimo de implementación
1. Auditar shell y pantallas clave del admin móvil.
2. Separar visualmente el shell móvil del shell desktop.
3. Definir navegación móvil compacta:
   - Inicio
   - Pacientes
   - Agenda
   - Simulador
   - Más
4. Rehacer el detalle de paciente móvil como ficha clínica por cards.
5. Simplificar Tratamientos móvil a resumen operativo.
6. Simplificar Pagos móvil a cards + acción básica.
7. Afinar Simulador móvil como flujo principal clínico.
8. Probar responsive en varios tamaños.

## Bloque 02 — Shell admin móvil

### Fecha
- 2026-04-28

### Estado
- completado

### Problema trabajado
El admin móvil se estaba mostrando como una versión comprimida del desktop, causando problemas de navegación, sidebar, overflow y mala experiencia de consulta.

### Decisión UX
Desktop mantiene sidebar completo.
Móvil usa navegación compacta orientada a operación rápida.

### Archivos revisados
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`
- `lib/features/dashboard/presentation/admin_modules_screens.dart`
- `lib/features/admin/presentation/web/layout/admin_desktop_layout.dart`
- `lib/features/admin/presentation/web/components/admin_sidebar.dart`
- `lib/features/dashboard/presentation/admin_patients_screen.dart`
- `lib/features/dashboard/presentation/admin_dashboard_screen.dart`

### Archivos modificados
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`
- `lib/features/dashboard/presentation/admin_dashboard_screen.dart`

### Breakpoint usado
- `isWide = MediaQuery.of(context).size.width > 800`
- Desktop por encima de 800 px.
- Móvil/compacto en 800 px o menos.

### Navegación móvil definida
- Inicio
- Pacientes
- Agenda
- Simulador
- Más

Dentro de “Más”:
- Pagos
- Tratamientos
- Configuración
- Cerrar sesión

### Qué se mantuvo igual en desktop
- Sidebar lateral completo con `NavigationRail`.
- Navegación administrativa existente.
- Layout ancho.
- Módulos desktop sin simplificación adicional en este bloque.
- `railTrailing` y acciones de escritorio intactas.

### Qué cambió en móvil
- Se eliminó el drawer/sidebar desktop como navegación principal en móvil.
- Se reemplazó por `NavigationBar` inferior compacta.
- Se añadió hoja modal “Más” para módulos secundarios y cierre de sesión.
- Se envolvió el body móvil en `SafeArea` para mejorar estabilidad visual.
- Se eliminó el logout duplicado del dashboard móvil para dejar el cierre de sesión centralizado en “Más”.

### Riesgos detectados
- Algunas pantallas siguen siendo desktop-first en contenido, aunque el shell ya no se vea como desktop reducido.
- Todavía quedan pendientes los bloques de detalle de paciente, tratamientos, pagos y simulador móvil.
- Configuración aún no tiene pantalla móvil específica; en este bloque queda como acceso preparado con mensaje controlado.

### Pruebas responsive realizadas
- Revisión estructural del shell para estos targets:
  - 360x800
  - 390x844
  - 412x915
  - tablet pequeña
  - desktop
- En esta sesión la validación fue estructural/código; la validación visual final queda pendiente de ejecución local por Erik.

### Pendientes para siguientes bloques
- Detalle paciente móvil
- Tratamientos móvil
- Pagos móvil
- Simulador móvil

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.
- Comando para Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Commit
- Pendiente hasta cerrar commit de este bloque.

## Bloque 03 — Detalle de paciente móvil

### Fecha
- 2026-04-28

### Estado
- completado

### Problema trabajado
El detalle del paciente en móvil estaba heredando una estructura de desktop, haciendo que Tratamientos, Pagos y Simulador se vieran pesados o se rompieran.

### Decisión UX
Desktop mantiene detalle completo.
Móvil usa ficha clínica por cards.

### Archivos revisados
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/dashboard/presentation/admin_patients_screen.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`

### Archivos modificados
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `docs/propuestas/REGISTRO_ADMIN_MOVIL_OCG.md`

### Secciones móviles implementadas
- Resumen: card con nombre, contacto, estado de tratamiento, saldo, próxima cita y última simulación.
- Tratamiento: card resumida con tratamiento activo, etapa, valor total, saldo pendiente y última nota clínica visible.
- Pagos: card resumida con total, pagado, saldo pendiente y último pago.
- Citas: card resumida con próxima cita, estado y CTA para agendar/ver agenda.
- Simulador: card con estado de última simulación, mensaje de contexto y accesos rápidos al simulador.
- Fotos: card de acceso simple a ver/tomar/subir foto.

### Acciones rápidas implementadas
- Agendar cita
- Registrar pago
- Tomar foto
- Abrir simulador

### Qué se mantuvo igual en desktop
- Se mantuvo la pantalla existente y sus secciones completas embebidas.
- No se rediseñó el flujo amplio de desktop.
- El detalle completo por secciones sigue disponible mediante acceso interno.

### Qué cambió en móvil
- El detalle ahora abre con una ficha clínica vertical por cards.
- Se añadieron acciones rápidas prioritarias para consulta.
- Se dejó una fila de atajos a secciones completas (Resumen, Tratamiento, Citas, Pagos, Simulador, Historial) sin depender de tabs pesadas como punto de entrada principal.
- Se evita que el usuario caiga de frente a contenido denso desktop-first.

### Riesgos detectados
- Algunas secciones profundas siguen siendo pesadas cuando se abren completas dentro del bloque embebido.
- Tratamientos, Pagos y Simulador todavía requieren bloques propios de refinamiento móvil.
- La validación visual real en dispositivos sigue pendiente.

### Pendientes para siguientes bloques
- Tratamientos móvil completo
- Pagos móvil completo
- Simulador móvil completo

### Pruebas responsive realizadas
- Revisión estructural del detalle móvil pensando en:
  - 360x800
  - 390x844
  - 412x915
  - tablet pequeña
  - desktop
- En esta sesión la validación fue de estructura y composición; la validación visual final queda pendiente para Erik.

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.
- Comando para Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Commit
- Pendiente hasta cerrar commit de este bloque.

## Bloque 04 — Tratamientos móvil

### Fecha
- 2026-04-28

### Estado
- completado

### Problema trabajado
La vista de tratamientos en móvil heredaba lógica visual pesada de desktop y podía romperse o ser incómoda en consulta.

### Decisión UX
Desktop mantiene edición completa.
Móvil muestra resumen clínico operativo por cards.

### Archivos revisados
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/patients/presentation/patient_detail_screen.dart`
- widgets/modales relacionados con tratamiento y conceptos financieros

### Archivos modificados
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `docs/propuestas/REGISTRO_ADMIN_MOVIL_OCG.md`

### Cards implementadas
- Estado del tratamiento: nombre, estado, etapa actual, progreso y fecha de inicio.
- Resumen financiero: valor total, total pagado, saldo pendiente y próximo pago.
- Conceptos: lista vertical resumida de conceptos principales con CTA “Ver todos” como placeholder seguro.
- Notas clínicas: última nota visible y último movimiento del historial si existe.
- Acciones: ver tratamiento completo, agregar nota (mensaje controlado), ir a pagos y aviso de usar escritorio para edición completa.

### Compatibilidad con pacientes legacy
- Si el tratamiento existe pero no tiene conceptos, la vista muestra: `No hay conceptos registrados para este tratamiento.`
- Si faltan notas, historial o fechas, se muestran estados vacíos claros sin trabarse.
- Se reutiliza el fallback financiero previo para tratamientos con datos incompletos.

### Estados vacíos manejados
- Sin tratamiento activo: se mantiene el empty state general del tab (`No hay tratamiento activo registrado.` / flujo existente del módulo).
- Sin conceptos: mensaje claro sin loading infinito.
- Sin notas: mensaje claro.
- Sin próximo pago: `Sin fecha programada`.

### Qué se mantuvo igual en desktop
- El flujo completo premium de tratamiento, timeline, historial y edición profunda permanece intacto para desktop/tablet amplia.
- No se tocaron los modales pesados como flujo principal desktop.

### Qué cambió en móvil
- El tab de tratamientos ahora detecta móvil (`< 700`) y renderiza una vista resumida por cards.
- Se evita mostrar de entrada la composición pesada desktop-first.
- Las acciones móviles son seguras y orientadas a consulta, no a edición profunda.

### Riesgos detectados
- `Ver todos` en conceptos todavía no abre una vista específica móvil; queda como placeholder seguro mientras el detalle completo siga viviendo abajo o en escritorio.
- La nota rápida todavía no tiene flujo dedicado móvil; por ahora deja mensaje controlado.

### Pendientes para siguientes bloques
- Pagos móvil completo
- Simulador móvil admin

### Pruebas responsive realizadas
- Revisión estructural pensada para:
  - paciente con tratamiento activo completo
  - paciente con tratamiento sin conceptos
  - paciente antiguo con datos incompletos
  - paciente sin tratamiento activo
  - 360x800
  - 390x844
  - 412x915
  - tablet pequeña
  - desktop
- Validación visual final pendiente para Erik.

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.
- Comando para Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Commit
- Pendiente hasta cerrar commit de este bloque.

## Bloque 05 — Pagos móvil

### Fecha
- 2026-04-28

### Estado
- completado

### Problema trabajado
La vista de pagos en móvil estaba desactualizada frente a desktop y no estaba optimizada para consulta rápida.

### Decisión UX
Desktop mantiene gestión financiera completa.
Móvil muestra resumen financiero y pagos en cards.

### Archivos revisados
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/features/patients/presentation/patient_detail_screen.dart`
- providers y modelos de pagos/transacciones existentes

### Archivos modificados
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `docs/propuestas/REGISTRO_ADMIN_MOVIL_OCG.md`

### Cards implementadas
- Resumen financiero: valor total, total pagado, saldo pendiente, porcentaje pagado y estado.
- Último pago: fecha, valor, método, concepto y estado.
- Historial de pagos: cards verticales con pagos recientes y CTA `Ver todos` como placeholder seguro.
- Acciones: registrar pago, ver historial completo, ir a tratamiento y mensaje para usar escritorio en gestión completa.

### Compatibilidad con pacientes sin pagos
- Si no existen transacciones, la vista muestra: `No hay pagos registrados para este paciente.`
- No queda cargando infinito ni intenta renderizar tablas vacías.

### Compatibilidad con datos incompletos o legacy
- Si falta método de pago: muestra `Sin método`.
- Si falta concepto: muestra `Sin concepto`.
- Si faltan notas o estado de transacción: usa fallbacks seguros (`Registrado`).
- Si total/pagado/saldo vienen incompletos, la suma agregada sigue usando valores por defecto de la resolución actual.

### Estados vacíos manejados
- Paciente sin pagos.
- Paciente con datos antiguos o incompletos.
- Paciente con saldo pendiente.
- Paciente al día.

### Qué se mantuvo igual en desktop
- La vista completa de pagos con cuentas por tratamiento, resumen ampliado, conceptos y registro detallado permanece intacta fuera del flujo móvil.
- No se cambió lógica financiera profunda ni integraciones existentes.

### Qué cambió en móvil
- El tab detecta móvil (`< 700`) y muestra una versión resumida por cards.
- Se evita exponer de entrada bloques más pesados del flujo desktop.
- El registro de pago básico se mantiene disponible si existe cuenta seleccionada.

### Riesgos detectados
- `Ver todos` e historial completo quedan como accesos placeholder/seguros mientras el bloque completo de pagos móvil siga evolucionando.
- Si en ciertos datos legacy hay campos con nombres distintos a los esperados, puede requerirse un ajuste fino posterior tras validación real.

### Pendientes para siguientes bloques
- Simulador móvil admin
- Prueba responsive completa
- Prueba con GPT-Image-2 real cuando exista API Key

### Pruebas responsive realizadas
- Revisión estructural pensada para:
  - paciente con pagos completos
  - paciente sin pagos
  - paciente con saldo pendiente
  - paciente al día
  - paciente con datos incompletos
  - móvil 360x800
  - móvil 390x844
  - móvil 412x915
  - tablet pequeña
  - desktop
- Validación visual final pendiente para Erik.

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.
- Comando para Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Commit
- Pendiente hasta cerrar commit de este bloque.

## Bloque 06 — Simulador móvil admin

### Fecha
- 2026-04-28

### Estado
- completado

### Problema trabajado
El simulador móvil del admin no estaba listo para consulta real: debía permitir tomar/subir foto, crear simulación, generar con IA, revisar before/after y compartir con paciente.

### Decisión UX
Desktop mantiene simulador completo.
Móvil usa flujo guiado: foto → preview → generar IA → revisar → compartir.

### Archivos revisados
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/services/firebase/image_picker_service.dart`

### Archivos modificados
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `docs/propuestas/REGISTRO_ADMIN_MOVIL_OCG.md`

### Flujo móvil implementado
- Sin simulaciones: empty state profesional + card principal con botones `Tomar foto` y `Subir desde galería`.
- Tomar foto: reutiliza `ImagePickerService` vía `pickOriginalFromCamera(...)` del provider.
- Subir desde galería: reutiliza `ImagePickerService` vía `pickOriginalFromGallery(...)`.
- Draft: muestra preview de foto original + texto `Foto lista para generar simulación.` + botón `Generar con IA`.
- Generating: loading claro + texto `Generando simulación con IA...` + acciones bloqueadas.
- Ready: preview original, resultado, before/after slider, botones de compartir, regenerar y archivar según estado.
- Failed: mensaje amigable + botón `Reintentar generación` + botón `Cambiar foto`.
- Shared: before/after + mensaje de simulación compartida.
- Historial: simulaciones recientes como cards con estado, provider/modelo, abrir, compartir y eliminar.

### Manejo de cámara/galería
- Se reutilizó el servicio existente `ImagePickerService`.
- Flutter solo toma/sube foto y crea draft; no envía imagen directa a OpenAI.

### Manejo de errores
- Si backend indica falta de API Key: se muestra mensaje amigable ya mapeado por provider.
- Si IA está desactivada: mensaje amigable.
- Si falla la generación: estado `failed` visible con reintento.
- No se permite doble clic mientras está en `generating`.

### Compatibilidad con datos legacy
- La resolución de media sigue tolerando `originalPath/resultPath` y fallbacks legacy ya soportados por repository/model.
- Si falta `resultPath`, el flujo sigue mostrando preview original sin romperse.

### Qué se mantuvo igual en desktop
- Se mantuvo el simulador completo existente.
- No se creó otro simulador paralelo.
- No se tocó backend real ni API Key.

### Qué cambió en móvil
- Header móvil más claro con estado reciente y CTA `Nueva simulación`.
- Card principal de acción para cámara/galería.
- Flujo visual guiado por estado dentro de `SimulatorScreen`.
- Cambio de foto accesible cuando la simulación falla.
- Historial más útil para consulta rápida.

### Riesgos detectados
- La validación visual final en dispositivos reales sigue pendiente.
- Algunos accesos como descompartir siguen viviendo en cards/historial y podrían refinarse después.
- La prueba real con GPT-Image-2 continúa bloqueada por configuración backend/API key.

### Pendientes
- API Key real
- prueba end-to-end con GPT-Image-2
- paciente ficticio
- imagen autorizada

### Pruebas responsive realizadas
- Revisión estructural para:
  - paciente sin simulaciones
  - simulación draft
  - simulación generating
  - simulación ready
  - simulación failed
  - simulación shared
  - tomar foto desde móvil
  - subir foto desde galería
  - 360x800
  - 390x844
  - 412x915
  - tablet pequeña
  - desktop
- Validación visual final pendiente para Erik.

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.
- Comando para Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Commit
- Pendiente hasta cerrar commit de este bloque.

## Corrección post-validación local Erik

### Fecha
- 2026-04-28

### Resultado recibido
- flutter analyze: falló con 15 issues
- flutter test test/features/simulator/: pasó
- functions npm run build: pasó

### Errores corregidos
- Provider real de tratamientos efectivos reimportado/corregido en `patient_detail_screen.dart`.
- Getter `hasResult` agregado a `SimulationModel` para soportar el uso actual de la UI.
- Imports/tipos reales de pagos corregidos en `patient_payments_tab.dart`.
- Helper móvil de pagos corregido para no depender de `widget` fuera de contexto.
- Error de sintaxis (`]`) corregido en `patient_simulator_tab.dart`.
- Campo correcto de `StageHistoryEntry` usado en lugar de `fecha` inexistente.
- Warning de llaves corregido en `manage_financial_items_dialog.dart`.
- Código muerto `_mobileItem` eliminado de `ocg_adaptive_scaffold.dart`.

### Archivos modificados
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/payments/presentation/widgets/manage_financial_items_dialog.dart`
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`

### Decisiones tomadas
- No se inventaron providers ni modelos nuevos; se usaron los tipos reales del proyecto.
- No se tocaron Cloud Functions ni GPT-Image-2.
- No se cambió arquitectura; solo correcciones de compilación y warnings seguros.

### Warnings corregidos
- `dynamic?` innecesario en `patient_detail_screen.dart`.
- `curly_braces_in_flow_control_structures` en `manage_financial_items_dialog.dart`.
- `_mobileItem` no referenciado en `ocg_adaptive_scaffold.dart`.

### Pendientes
- Erik debe reejecutar `flutter analyze` para confirmar que ya no queden issues adicionales fuera de este lote.

### Resultado final esperado
flutter analyze sin errores críticos

## Estado actual
- Bloque 01 (auditoría): completado.
- Bloque 02 (shell admin móvil): completado.
- Bloque 03 (detalle de paciente móvil): completado.
- Bloque 04 (tratamientos móvil): completado.
- Bloque 05 (pagos móvil): completado.
- Bloque 06 (simulador móvil admin): completado.

## Pruebas realizadas
- Revisión estructural inicial de shell admin, módulos admin, tabs de paciente y pantallas del simulador.
- Inspección de archivos clave responsive/desktop-first.
- Ajuste del scaffold adaptativo para navegación móvil compacta.
- Conversión del detalle del paciente móvil a ficha clínica por cards.
- Simplificación del tab de tratamientos para móvil con cards y estados vacíos seguros.
- Simplificación del tab de pagos para móvil con cards y fallbacks legacy.
- Optimización del simulador móvil admin con flujo guiado de cámara/galería → preview → generar → revisar → compartir.

## Pendientes inmediatos
- Validación visual final de responsive por Erik en tamaños objetivo.
- Configuración backend real para la prueba con GPT-Image-2.
