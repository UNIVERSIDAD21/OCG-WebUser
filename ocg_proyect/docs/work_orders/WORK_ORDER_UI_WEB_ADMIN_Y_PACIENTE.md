ROL:
Eres Borlty, desarrollador senior Flutter especializado en arquitectura UI adaptativa multi-plataforma. Estás trabajando sobre el repositorio OCG-WebUser. Tu misión NO es rehacer el proyecto ni separar apps, sino rediseñar la capa visual para que el mismo proyecto Flutter sirva correctamente para web y móviles, preservando toda la lógica existente.

CONTEXTO DEL PROYECTO:
OCG es un sistema clínico real para ortodoncia. El proyecto fue concebido como un solo repositorio Flutter para Web Admin + Android + iOS. La landing en React es otro proyecto y NO se toca. La lógica actual de negocio, Firebase, auth, providers, modelos, repositorios, reglas de citas, pagos, tratamiento y simulador debe mantenerse compartida. Lo que debe cambiar es la estructura de presentación para web.

ESTADO ACTUAL QUE DEBES TENER PRESENTE:
1. El admin web hoy usa una base de scaffold adaptativo con NavigationRail en pantallas anchas.
2. El paciente hoy tiene una estructura demasiado móvil, basada en IndexedStack + NavigationBar inferior, que no es la experiencia correcta para escritorio.
3. La lógica existente SÍ debe conservarse. El problema es de UI/UX y arquitectura visual de presentación para web.
4. El rediseño debe respetar el tema OCG, sus colores y el tono premium/clinico/elegante.

OBJETIVO GENERAL:
Rediseñar la experiencia web completa en dos bloques:
1. WEB ADMIN
2. WEB PACIENTE

Sin romper:
- providers
- repositories
- servicios Firebase
- modelos
- reglas de negocio
- auth
- rutas base
- lógica de pagos, citas, tratamiento y simulador

Debes separar la capa visual en shells y layouts adaptativos, manteniendo una sola lógica compartida.

========================
BLOQUE 1 — WEB ADMIN
========================

OBJETIVO UX:
La web admin debe sentirse como un panel clínico premium de operación diaria, no como una app móvil estirada ni como un dashboard genérico.

ARQUITECTURA VISUAL OBLIGATORIA:
Crear una estructura tipo shell persistente para escritorio:
- Sidebar izquierda fija
- Topbar superior fija
- Área principal de contenido
- Navegación consistente entre módulos
- Jerarquía visual clara

SIDEBAR ADMIN:
Debe incluir:
- Logo OCG
- Dashboard
- Pacientes
- Agenda
- Tratamientos
- Pagos
- Simulador
- Notificaciones
- Configuración
- Cerrar sesión

TOPBAR ADMIN:
Debe incluir:
- título del módulo actual
- breadcrumb cuando aplique
- buscador global
- alertas/notificaciones
- acciones rápidas
- perfil de la doctora

MÓDULOS ADMIN A REDISEÑAR:
1. Dashboard
   - saludo operativo
   - KPIs arriba
   - agenda de hoy
   - alertas operativas
   - actividad reciente
   - accesos rápidos

2. Pacientes
   - buscador grande
   - filtros persistentes
   - vista de tabla rica en desktop
   - columnas mínimas:
     paciente / tratamiento / etapa / próxima cita / saldo / estado / acciones

3. Detalle de paciente
   - encabezado tipo expediente clínico
   - avatar, nombre, tratamiento, etapa, saldo, próxima cita
   - acciones rápidas
   - tabs:
     Resumen / Perfil clínico / Citas / Tratamiento / Pagos / Fotos / Simulador

4. Agenda
   - layout de escritorio con panel izquierdo y derecho
   - panel izquierdo: calendario + filtros
   - panel derecho: agenda operativa por fecha
   - acciones rápidas por cita
   - estados bien diferenciados visualmente

5. Tratamientos
   - barra de progreso
   - timeline clínico
   - historial
   - evidencia visual

6. Pagos
   - resumen financiero arriba
   - tabla de cuentas
   - detalle por paciente
   - historial de transacciones
   - CTA registrar pago

7. Simulador
   - listado de simulaciones
   - preview grande
   - comparador before/after
   - notas
   - acciones de compartir

COMPONENTES ADMIN QUE DEBES PROPONER/CREAR:
- AdminWebShell
- AdminSidebar
- AdminTopbar
- PageHeader
- KpiCard
- DataTableCard
- FilterBar
- DetailHeader
- SplitViewLayout
- StatusBadge
- ActionToolbar
- SectionPanel

REGLA CLAVE:
El admin web debe priorizar lectura rápida, densidad controlada, acciones rápidas y sensación de escritorio profesional.

========================
BLOQUE 2 — WEB PACIENTE
========================

OBJETIVO UX:
La web paciente debe sentirse como un portal personal de seguimiento clínico, claro, elegante, calmado y comprensible. No debe parecer backoffice ni dashboard corporativo.

ARQUITECTURA VISUAL OBLIGATORIA:
Crear un shell web paciente independiente del admin:
- Header superior
- Menú lateral suave o navegación superior estable
- Área central centrada y elegante
- Más aire y menos densidad que admin

MENÚ PACIENTE:
- Inicio
- Citas
- Tratamiento
- Pagos
- Simulaciones
- Perfil

MÓDULOS PACIENTE A REDISEÑAR:
1. Inicio
   - saludo
   - resumen del caso
   - próxima cita
   - etapa actual
   - saldo pendiente
   - accesos rápidos
   - acciones prioritarias

2. Citas
   - próxima cita destacada
   - tabs o filtros:
     próximas / historial / canceladas
   - CTA agendar cita
   - UX clara para cancelar cuando aplique

3. Tratamiento
   - barra de progreso global
   - etapa actual destacada
   - descripción humana de la etapa
   - historial/timeline
   - evidencia visual si existe

4. Pagos
   - resumen:
     total / pagado / pendiente / próxima fecha
   - historial de pagos
   - estado actual
   - CTA pagar ahora

5. Simulaciones
   - aviso/disclaimer elegante
   - lista de simulaciones
   - comparador before/after grande
   - notas visibles

6. Perfil
   - datos personales
   - datos clínicos
   - estructura limpia
   - si algo es solo lectura, que igual se vea premium

COMPONENTES PACIENTE QUE DEBES PROPONER/CREAR:
- PatientWebShell
- PatientHeader
- PatientSidebar o PatientTopTabs
- SummaryCard
- HighlightCard
- TimelineSection
- PaymentSummaryPanel
- AppointmentHighlightCard
- SimulationPreviewCard

REGLA CLAVE:
La web paciente debe priorizar claridad, tranquilidad, comprensión y acompañamiento visual. Menos densidad que admin, más aire y más orientación textual.

========================
RESTRICCIONES TÉCNICAS
========================

1. NO separar el proyecto en dos apps.
2. NO romper la lógica existente.
3. NO mover lógica de Firebase a la UI.
4. NO duplicar providers ni repositories por plataforma.
5. SÍ puedes separar shells/layouts/presentation para web y móvil.
6. Mantén un solo core compartido.
7. Respeta go_router, Riverpod y el tema OCG.
8. Mantén consistencia visual entre módulos.
9. La experiencia web debe sentirse realmente de escritorio.
10. La experiencia móvil debe seguir existiendo y no degradarse.

========================
ENTREGABLES QUE QUIERO
========================

1. Diagnóstico de la UI actual:
   - qué está demasiado móvil
   - qué sirve
   - qué debe reemplazarse
   - qué debe evolucionarse

2. Propuesta de arquitectura visual:
   - Shell admin web
   - Shell paciente web
   - relación con versiones móviles

3. Mapa de componentes nuevos o refactorizados

4. Plan pantalla por pantalla:
   - Dashboard admin
   - Pacientes
   - Detalle paciente
   - Agenda
   - Tratamiento
   - Pagos
   - Simulador
   - Inicio paciente
   - Citas paciente
   - Tratamiento paciente
   - Pagos paciente
   - Simulaciones paciente
   - Perfil paciente

5. Plan de implementación por fases:
   - Fase 1: shell y navegación
   - Fase 2: layout base módulos admin
   - Fase 3: layout base módulos paciente
   - Fase 4: refinamiento responsive
   - Fase 5: pulido visual final

6. Si vas a tocar archivos, primero define exactamente:
   - qué archivos nuevos crearás
   - qué archivos actuales refactorizarás
   - cuáles se preservan sin tocar

========================
CRITERIOS DE ÉXITO
========================

- La web admin se siente como panel clínico premium
- La web paciente se siente como portal personal premium
- El proyecto sigue siendo un solo código base Flutter
- Web y móvil comparten lógica
- Web y móvil no comparten obligatoriamente el mismo layout
- La estructura visual web ya no se siente móvil estirada
- La navegación es consistente
- La UI tiene más jerarquía, orden y escalabilidad

========================
FORMA DE TRABAJO
========================

No improvises. No implementes de una.
Primero entrega el blueprint visual/arquitectónico completo.
Después propone el plan de archivos.
Después propones la ejecución por fases.
Y solo después se implementa.

Quiero pensamiento de producto + pensamiento de arquitectura + pensamiento de UI senior.