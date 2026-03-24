BLOQUE 1 — CÓMO DEBE QUEDAR LA WEB ADMIN
1. Objetivo de la experiencia admin

La web admin no debe sentirse como “una app Flutter abierta en navegador”.
Debe sentirse como un panel clínico premium de operación diaria.

Tiene que transmitir estas 5 cosas:

control
claridad
rapidez operativa
confianza clínica
elegancia sobria

No debe parecer:

ni ERP feo
ni app móvil estirada
ni dashboard genérico con tarjetas por todos lados sin jerarquía

Debe parecer:

una plataforma clínica real
moderna
ordenada
con foco en trabajo diario de la doctora
2. Principio rector del layout admin

La web admin debe construirse alrededor de un Shell de escritorio fijo.

No una pantalla distinta cada vez.
No un body que cambia sin estructura fuerte.

Debe existir una estructura constante:

┌──────────────────────────────────────────────────────────────────────────────┐
│ TOPBAR GLOBAL                                                               │
│ Título vista | buscador | alertas | acciones rápidas | perfil doctora       │
├──────────────────────┬───────────────────────────────────────────────────────┤
│ SIDEBAR FIJA         │ ÁREA PRINCIPAL                                       │
│                      │                                                       │
│ Dashboard            │ Header de módulo                                     │
│ Pacientes            │ KPIs / filtros / acciones                            │
│ Agenda               │                                                       │
│ Tratamientos         │ Contenido principal                                  │
│ Pagos                │ tablas / cards / paneles / detalle                   │
│ Simulador            │                                                       │
│ Notificaciones       │                                                       │
│ Configuración        │                                                       │
│                      │                                                       │
│ Salir                │                                                       │
└──────────────────────┴───────────────────────────────────────────────────────┘
Qué resuelve este shell
identidad visual consistente
navegación más profesional
sensación real de escritorio
menos ruptura visual entre módulos
más escalabilidad cuando sumes tratamiento, pagos, simulador y notificaciones
3. Estructura ideal del Shell Admin
3.1 Sidebar izquierda

Debe ser fija, elegante y respirada.

Debe incluir

Arriba:

logo OCG
nombre “OCG Clínica”
subtítulo pequeño: “Panel clínico”

Centro:

Dashboard
Pacientes
Agenda
Tratamientos
Pagos
Simulador
Notificaciones

Abajo:

Configuración
Cerrar sesión
Jerarquía visual
fondo espresso
item activo con highlight bronze suave
ícono + texto
hover muy fino
nada chillón
nada que parezca material default sin curar
Comportamiento
expandida por defecto en desktop
colapsable solo si luego lo necesitas
no debe depender de cada pantalla para volver a dibujarse con personalidad distinta
Visual recomendado
┌────────────────────────────┐
│ OCG                        │
│ Clínica                    │
│ Panel clínico              │
│                            │
│  ◉ Dashboard               │
│  ○ Pacientes               │
│  ○ Agenda                  │
│  ○ Tratamientos            │
│  ○ Pagos                   │
│  ○ Simulador               │
│  ○ Notificaciones          │
│                            │
│  ○ Configuración           │
│                            │
│  ⎋ Cerrar sesión           │
└────────────────────────────┘
3.2 Topbar superior

La topbar no debe ser decorativa.
Debe ser un centro de contexto.

Elementos

Izquierda:

nombre del módulo actual
breadcrumb opcional cuando estés en detalle de paciente

Centro:

buscador global

Derecha:

notificaciones
acciones rápidas
avatar / menú de la doctora
Ejemplo
┌──────────────────────────────────────────────────────────────────────────────┐
│ Pacientes / María Gómez      [Buscar paciente, cita o pago...]   🔔  +  👩‍⚕️ │
└──────────────────────────────────────────────────────────────────────────────┘
Qué debe poder hacer el buscador global

No solo buscar nombres.

Debe poder resolver:

paciente por nombre
paciente por email
cita por paciente
pago por paciente
simulación por paciente

Aunque al inicio la implementación sea solo pacientes, la UI debe nacer con visión de sistema grande.

4. Sistema visual del admin
4.1 Densidad visual

La web admin debe tener una densidad media-alta controlada.

No tan vacía como landing.
No tan apretada como sistema viejo.

Regla
dashboard y overview: más aire
tablas y gestión: más densidad
detalle clínico: aire moderado + agrupación clara
4.2 Contenedores

Tres tipos:

A. Card resumen

Para KPIs y estados

B. Panel funcional

Para agendas, listas, actividad, alertas

C. Vista de detalle

Para paciente, tratamiento, pagos y simulación

5. Página por página — cómo debe quedar la web admin
5.1 Dashboard Admin
Objetivo

Que la doctora entre y entienda el estado operativo en menos de 10 segundos.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ HEADER                                                                      │
│ Buenos días, Dra. Liliana      Hoy: 24 de marzo        [Nueva cita] [Pago]  │
├──────────────────────────────────────────────────────────────────────────────┤
│ KPI 1 │ KPI 2 │ KPI 3 │ KPI 4 │ KPI 5                                       │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Agenda de hoy                        │ Alertas operativas                    │
│ 08:00 Paciente A                     │ - 3 citas sin confirmar               │
│ 09:00 Paciente B                     │ - 5 perfiles incompletos              │
│ 10:00 Paciente C                     │ - 2 pagos vencidos                    │
│ ...                                  │ - 1 simulación pendiente              │
├──────────────────────────────────────┼───────────────────────────────────────┤
│ Actividad reciente                   │ Accesos rápidos                       │
│ - pago registrado                    │ [Pacientes] [Agenda] [Pagos]          │
│ - etapa actualizada                  │ [Simulador] [Notificaciones]          │
│ - cita reprogramada                  │                                       │
└──────────────────────────────────────┴───────────────────────────────────────┘
Estructura concreta
Encabezado
saludo útil, no cursi
fecha
CTA rápidos
KPIs arriba
citas hoy
pendientes por confirmar
pagos vencidos
pacientes nuevos 30d
perfiles pendientes
Columna principal
agenda de hoy
próximas citas
acciones de estado rápidas
Columna secundaria
alertas operativas
actividad reciente
accesos rápidos
Qué debe evitarse
demasiadas cards del mismo tamaño sin prioridad
cards decorativas vacías
métricas sin capacidad de acción
Regla UX

Cada KPI importante debe tener “ver detalle” o navegación al módulo correspondiente.

5.2 Módulo Pacientes

Esta pantalla debe cambiar muchísimo respecto a la sensación actual.

Hoy tiende a ser una lista de cards.
En web debe sentirse como gestión clínica real.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Pacientes                                              [Nuevo paciente]      │
│ [Buscar paciente...]  [Todos] [Pendientes] [Activos] [Alta] [Tratamiento ▼] │
├──────────────────────────────────────────────────────────────────────────────┤
│ TABLA / LISTA RICA                                                           │
│                                                                              │
│ Paciente     Tratamiento   Etapa      Próxima cita     Saldo      Estado     │
│ María G.     Alineadores   Control    12 abr 10:00     $450.000   Incompleto │
│ Juan P.      Convencional  Alta       —                $0         Completo   │
│ Ana R.       Pendiente     Valoración 30 mar 09:00     $800.000   Pendiente  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
Vista recomendada

Tabla rica en desktop.
No solo cards.

Columnas mínimas
paciente
tratamiento
etapa actual
próxima cita
saldo pendiente
estado de perfil
acciones
Interacciones
click en fila → abre detalle
hover discreto
acciones rápidas opcionales al final
filtros persistentes
búsqueda inmediata
Estado visual del paciente

Debe poder leerse en segundos:

si está pendiente de completar
si tiene deuda
si tiene cita próxima
si está en alta
si le falta tratamiento definido
Qué no hacer
depender de solo chips visuales sin estructura
esconder información clave dentro del detalle
obligar demasiados clics para entender el estado
5.3 Detalle de Paciente

Este debe ser el módulo más fuerte de toda la web admin.

Debe sentirse como un expediente clínico digital premium.

Estructura ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Pacientes / María Gómez                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│ AVATAR │ Nombre | Tratamiento | Etapa | Próxima cita | Saldo | Acciones     │
│        │ [Editar] [Nueva cita] [Registrar pago] [Simulación]                │
├──────────────────────────────────────────────────────────────────────────────┤
│ TAB BAR                                                                     │
│ Resumen | Perfil clínico | Citas | Tratamiento | Pagos | Fotos | Simulador  │
├──────────────────────────────────────────────────────────────────────────────┤
│ CONTENIDO DE TAB                                                            │
└──────────────────────────────────────────────────────────────────────────────┘
Bloque superior

Debe incluir:

avatar/foto
nombre completo
email / teléfono
tratamiento
etapa
próxima cita
saldo
estado general del caso
Acciones rápidas
editar paciente
crear cita
registrar pago
abrir simulador
actualizar etapa
eliminar paciente solo si realmente aplica y con confirmación fuerte
Tabs recomendadas
1. Resumen

Visión ejecutiva del caso

2. Perfil clínico

Datos clínicos estructurados

3. Citas

Historial + próximas + acciones

4. Tratamiento

Timeline, progreso, cambios de etapa

5. Pagos

Resumen financiero y transacciones

6. Fotos

Galería clínica

7. Simulador

Simulaciones realizadas y compartidas

Resumen del paciente

Debe mostrar:

etapa actual
avance visual
última cita
próxima cita
saldo
alertas
notas clínicas destacadas
Qué evitar
detalle largo en columna única sin jerarquía
tabs pobres con contenido muy pequeño
repetir información en todos lados
5.4 Agenda Admin

Este módulo debe ser casi una mini app dentro del sistema.

Objetivo

Gestionar el tiempo clínico con claridad.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Agenda                                                                      │
│ [Hoy] [Semana] [Mes]         [Fecha] [Estado] [Tipo]       [Nueva cita]     │
├──────────────────────┬───────────────────────────────────────────────────────┤
│ PANEL IZQUIERDO      │ PANEL DERECHO                                        │
│ Calendario           │ Vista agenda                                         │
│ Filtros              │ 08:00  María Gómez      Confirmada                   │
│ Estados              │ 08:45  Juan Pérez       Programada                   │
│ Tipos                │ 09:30  Ana Rodríguez    Reprogramada                 │
│ Doctor(a) si aplica  │ 10:15  ...                                        │
└──────────────────────┴───────────────────────────────────────────────────────┘
Modos de vista
Hoy
Semana
Lista por fecha
Desktop ideal

Calendario y filtros a la izquierda, agenda operativa a la derecha.

Cada cita debe mostrar
hora
nombre paciente
tipo
duración
estado
acciones rápidas
Acciones rápidas
confirmar
completar
cancelar
reprogramar
abrir detalle del paciente
Color semántico
programada: bronze
confirmada: azul/neutral controlado
completada: verde
cancelada: rojo
reprogramada: morado suave o neutral distinto
Qué debe mejorar respecto a hoy
más estructura de agenda real
menos sensación de “lista simple con chips”
filtros y calendario con más protagonismo
5.5 Tratamientos

Aunque aún esté en bloque siguiente, la web admin debe preverlo.

Objetivo

Que la doctora vea el estado clínico del caso.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Tratamiento                                                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│ Progreso general                                                             │
│ [Valoración]──[Planeación]──[Instalación]──[Controles]──[Retención]──[Alta]  │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Historial de etapas                  │ Fotos / evidencia                     │
│ - fecha                              │ [foto] [foto] [foto]                  │
│ - notas                              │                                       │
│ - quién cambió                       │                                       │
└──────────────────────────────────────┴───────────────────────────────────────┘
La idea

No debe ser solo texto.
Debe ser una mezcla de:

barra de progreso
timeline clínico
historial
evidencia visual
5.6 Pagos Admin

Debe sentirse mucho más financiero y operativo.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Pagos                                                                        │
│ [Buscar paciente...] [Pendientes] [Vencidos] [Pagado total]                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ KPIs: Cobrado mes | Pendiente total | Vencidos | Pacientes con saldo        │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Tabla de cuentas                     │ Detalle paciente                      │
│ Paciente | saldo | próximo pago      │ Total tratamiento                     │
│ estado | acción                       │ Monto pagado                          │
│                                      │ saldo pendiente                       │
│                                      │ historial de transacciones            │
│                                      │ [Registrar pago] [Descargar recibo]   │
└──────────────────────────────────────┴───────────────────────────────────────┘
Muy importante

En web, pagos no debe ser una lista informal de cards.
Debe parecer una herramienta seria.

5.7 Simulador Admin

Este debe ser uno de los módulos más visualmente poderosos.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Simulador                                                                    │
│ [Buscar paciente] [Borradores] [Listas] [Compartidas]                       │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Lista de simulaciones                │ Preview grande                        │
│ - paciente                           │                                       │
│ - fecha                              │    BEFORE / AFTER                     │
│ - estado                             │                                       │
│ - tipo                               │                                       │
│                                      │ notas / tratamiento / compartir       │
└──────────────────────────────────────┴───────────────────────────────────────┘
Debe incluir
comparador grande
estado de simulación
metadata útil
notas de doctora
botón compartir
trazabilidad de compartición
6. Componentes globales que necesita la web admin

La web admin necesita un set visual propio más maduro:

Debes tener
AdminWebShell
AdminTopbar
AdminSidebar
PageHeader
KpiCard
DataTableCard
FilterBar
EmptyStatePanel
SectionPanel
ActionToolbar
StatusBadge
DetailHeader
SplitViewLayout
Idea

No hacer toda la UI dentro de cada pantalla.
Primero crear ladrillos sólidos.

7. Regla crítica para la web admin

La web admin debe sentirse así:

ESCRITORIO
> estructura persistente
> panel de control
> lectura rápida
> trabajo intensivo
> mayor densidad informativa

MÓVIL
> versión resumida
> menos densidad
> acciones principales
> no copiar exacto el escritorio
BLOQUE 2 — CÓMO DEBE QUEDAR LA WEB PACIENTE

Ahora la parte paciente debe ser distinta.

No puede verse igual al admin.
No debe sentirse como backoffice.

Debe sentirse como un portal de seguimiento clínico personal.

1. Objetivo de la experiencia paciente

La web paciente debe transmitir:

tranquilidad
cercanía
claridad
seguimiento
confianza
elegancia suave

No debe sentirse:

demasiado técnica
demasiado administrativa
demasiado saturada
como dashboard de empresa

La paciente debe entrar y pensar:
“entiendo mi proceso, mis citas, mi saldo y mi avance sin confundirme.”

2. Problema actual de la base paciente

Hoy la base principal está organizada como una experiencia con IndexedStack y NavigationBar inferior, lo cual encaja mejor con móvil que con una web paciente de escritorio

En web, el portal paciente debe cambiar a una estructura más de escritorio.

3. Estructura ideal del Shell Paciente Web

Debe existir un shell diferente del admin.

Layout
┌──────────────────────────────────────────────────────────────────────────────┐
│ HEADER PACIENTE                                                             │
│ OCG Clínica | Mi portal | nombre paciente | ayuda | cerrar sesión           │
├──────────────────────┬───────────────────────────────────────────────────────┤
│ MENÚ LATERAL SUAVE   │ CONTENIDO                                             │
│                      │                                                       │
│ Inicio               │ Header de sección                                     │
│ Citas                │ Resumen / contenido / acciones                        │
│ Tratamiento          │                                                       │
│ Pagos                │                                                       │
│ Simulaciones         │                                                       │
│ Perfil               │                                                       │
└──────────────────────┴───────────────────────────────────────────────────────┘
Menú
Inicio
Citas
Tratamiento
Pagos
Simulaciones
Perfil
Tono visual

Más claro y amable que el admin.

Diferencia con admin
menos densidad
más aire
menos métricas
más mensajes de orientación
más enfoque en comprensión, no en operación
4. Página por página — cómo debe quedar la web paciente
4.1 Inicio Paciente

Este debe ser un verdadero “resumen de mi caso”.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Hola, María 👋                                                               │
│ Aquí puedes seguir tu tratamiento, tus citas y tu estado de cuenta          │
├──────────────────────────────────────────────────────────────────────────────┤
│ TARJETAS RESUMEN                                                            │
│ Próxima cita | Etapa actual | Saldo pendiente | Simulación más reciente     │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Mi tratamiento                       │ Próximas acciones                     │
│ progreso visual                      │ - confirmar cita                      │
│ etapa actual                         │ - revisar saldo                       │
│ descripción corta                    │ - ver simulación                      │
├──────────────────────────────────────┼───────────────────────────────────────┤
│ Historial reciente                   │ Mensajes / indicaciones               │
└──────────────────────────────────────┴───────────────────────────────────────┘
Qué debe mostrar

Arriba:

saludo
texto breve de orientación

Debajo:

próxima cita
etapa actual
saldo
acceso rápido a simulaciones
Sección tratamiento
barra de progreso
etapa actual
explicación simple
Acciones prioritarias
ver citas
ir a pagos
ver simulación
completar perfil si hace falta
Qué no debe ser
una lista larga de widgets sin prioridad
un dashboard frío
una copia del admin
4.2 Citas Paciente

Debe ser una experiencia clara y ordenada.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Mis citas                                                                    │
│ [Agendar cita] [Próximas] [Historial] [Canceladas]                          │
├──────────────────────────────────────────────────────────────────────────────┤
│ Próxima cita destacada                                                       │
│ Fecha | hora | tipo | estado | acciones                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│ Lista de citas                                                               │
│ - cita 1                                                                     │
│ - cita 2                                                                     │
│ - cita 3                                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
Elementos
Próxima cita destacada

Debe aparecer primero, con mucha claridad.

Lista de historial

Con estados visibles:

programada
confirmada
completada
cancelada
Acción agendar cita

Muy visible, pero elegante.

Cancelación

Con UX clara:

si puede cancelar
si no puede cancelar
si debe contactar por WhatsApp
Muy importante

En web, las citas deben leerse como agenda personal.
No como lista técnica.

4.3 Tratamiento Paciente

Este módulo debe ser emocionalmente potente, porque es donde el paciente ve su avance.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Mi tratamiento                                                               │
├──────────────────────────────────────────────────────────────────────────────┤
│ Barra de progreso global                                                     │
│ [Valoración]──[Planeación]──[Instalación]──[Controles]──[Retención]──[Alta]  │
├──────────────────────────────────────────────────────────────────────────────┤
│ Etapa actual                                                                 │
│ Título + descripción amigable                                                │
├──────────────────────────────────────┬───────────────────────────────────────┤
│ Historial de cambios                 │ Fotos / evidencia si aplica           │
└──────────────────────────────────────┴───────────────────────────────────────┘
Qué debe tener
barra visual del progreso
etapa actual destacada
explicación simple y humana
historial de etapas
evidencia visual cuando exista
Qué debe evitar
texto clínico frío sin explicación
timeline confuso
exceso de detalle técnico que abrume
4.4 Pagos Paciente

Este módulo debe ser clarísimo.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Mis pagos                                                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ RESUMEN                                                                      │
│ Total tratamiento | Pagado | Pendiente | Próxima fecha de pago              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Estado actual: pendiente / al día / vencido                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ Historial de pagos                                                           │
│ fecha | monto | método | recibo                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Pagar ahora]                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
Reglas UX
nunca hacer que el paciente busque demasiado para entender cuánto debe
el saldo debe estar clarísimo
el CTA pagar debe existir, pero sin agresividad visual
Tono

Más confianza y claridad, menos presión.

4.5 Simulaciones Paciente

Este módulo debe sentirse especial.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Mis simulaciones                                                             │
├──────────────────────────────────────────────────────────────────────────────┤
│ Aviso informativo elegante                                                   │
│ “Las simulaciones son orientativas...”                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Lista de simulaciones                                                        │
│                                                                              │
│ [Simulación 1]                                                               │
│  fecha                                                                       │
│  comparador before/after grande                                              │
│  notas                                                                       │
│                                                                              │
│ [Simulación 2]                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
Muy importante
before/after amplio
limpio
sin saturación
con notas visibles
con disclaimer elegante

Debe sentirse premium.

4.6 Perfil Paciente

Debe ser claro y muy ordenado.

Layout ideal
┌──────────────────────────────────────────────────────────────────────────────┐
│ Mi perfil                                                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ Foto | nombre | correo | teléfono                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ Datos del tratamiento                                                        │
│ tipo | etapa | fecha inicio | fecha estimada fin                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ Información personal                                                         │
│ fecha nacimiento | contacto | etc.                                           │
└──────────────────────────────────────────────────────────────────────────────┘
Si es editable

Solo algunas secciones.

Si es mayormente lectura

Aun así debe verse premium, no como formulario mal acomodado.

5. Sistema visual del portal paciente
5.1 Sensación general

Más editorial, más calmada, más espaciosa.

Debe verse así
fondo marfil
paneles suaves
bronze como acento
espresso para títulos
tarjetas con respiración
textos explicativos
layout centrado y elegante
5.2 Jerarquía

El paciente no necesita ver todo a la vez.

Por eso:

una acción principal
una próxima cita
un estado de tratamiento
un estado de cuenta
un histórico simple
6. Regla crítica de la web paciente
WEB PACIENTE
> portal personal
> más claridad que densidad
> más acompañamiento que operación
> más resumen que tablero técnico

MÓVIL PACIENTE
> navegación inferior sí aplica
> contenidos más compactos
> pantallas por sección
DIAGRAMA GENERAL DE CONVIVENCIA WEB + MÓVIL SIN ROMPER TU PROYECTO

Esto es clave para Borlty:

┌──────────────────────────────────────────────────────────────────────┐
│ CAPA COMPARTIDA                                                      │
│----------------------------------------------------------------------│
│ Firebase / Auth / Firestore / Storage / Functions                    │
│ Models / Repositories / Providers / Business Rules / Theme Tokens    │
└──────────────────────────────────────────────────────────────────────┘
                             │
                             │
                ┌────────────┴────────────┐
                │                         │
┌──────────────────────────────┐   ┌──────────────────────────────────┐
│ PRESENTACIÓN WEB             │   │ PRESENTACIÓN MÓVIL              │
│------------------------------│   │----------------------------------│
│ AdminWebShell                │   │ AdminMobileShell                 │
│ PatientWebShell              │   │ PatientMobileShell               │
│ tablas / split views / rail  │   │ bottom nav / listas / una col    │
│ topbar / sidebar / densidad  │   │ más compacto / táctil            │
└──────────────────────────────┘   └──────────────────────────────────┘

La lógica no se toca.
Se adapta la estructura visual.