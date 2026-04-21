# Sistema Responsive Admin Desktop — Validación y Mantenimiento

## Matriz oficial obligatoria
Toda pantalla admin nueva o modificada debe validarse, como mínimo, en estas resoluciones:

- 1600x900
- 1440x900
- 1366x768
- 1280x800
- 1256x1016
- 1180x820

## Regla de arquitectura
Ninguna pantalla admin nueva puede introducir responsive local por fuera del sistema central.

La implementación debe pasar primero por:
- `AdminDesktopLayoutData`
- `AdminDesktopLayoutScope`
- `SplitViewLayout`
- shell admin oficial
- sidebar/tier/density tokens oficiales

### Prohibido
- breakpoints locales inventados por pantalla sin pasar por el layout central
- colapsos bruscos de arquitectura con thresholds aislados
- alturas rígidas innecesarias para contenedores principales
- duplicar lógica de spacing, split o sidebar en módulos individuales

## Checklist obligatorio por módulo admin
Antes de cerrar cualquier pantalla admin nueva o modificada, confirmar:

- [ ] Usa tiers globales del admin (`wide`, `standard`, `compact`, `tight`)
- [ ] Usa el shell admin oficial
- [ ] Usa componentes desktop admin oficiales / reutilizables
- [ ] Evita breakpoints locales innecesarios
- [ ] Evita heights rígidas innecesarias
- [ ] Mantiene jerarquía desktop en resoluciones medias
- [ ] Degrada progresivamente (sidebar → padding/gaps → proporciones → split)
- [ ] Se probó en toda la matriz oficial
- [ ] No introduce nuevos magic numbers de responsive fuera del sistema central

## Evidencia actual validada
Cobertura validada con tests y/o harnesses desktop del sistema actual:

- Dashboard
- Pacientes
- Agenda
- Tratamientos
- Pagos
- Simulador
- Detalle paciente

## Comandos de verificación recomendados
- `flutter test test/features/admin/admin_desktop_layout_test.dart`
- `flutter test test/features/admin/admin_desktop_modules_alignment_test.dart`
- `flutter test test/features/admin/admin_modules_responsive_base_test.dart`
- `flutter test test/features/admin/admin_modules_tiers_smoke_test.dart`
- `flutter test test/features/patients/patient_detail_workspace_test.dart`

## Criterio de cierre
No cerrar una tarea responsive del admin con “debería verse bien”.

Debe existir al menos una de estas evidencias reales:
- widget test por matriz
- harness desktop validado por tiers
- analyze limpio de archivos tocados

Si no hay evidencia verificable, el trabajo responsive no se considera terminado.
