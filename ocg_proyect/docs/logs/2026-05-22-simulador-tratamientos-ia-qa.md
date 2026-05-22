# QA Simulador IA de Tratamientos Dentales

**Fecha:** 2026-05-22  
**Branch:** main  
**Commit:** 26ad7bb (Bloque 06) + pending (Bloque 07 QA deploy)

## Comandos ejecutados

```bash
# Functions
cd ocg_proyect/functions
npm run build                          # ✅ OK
node --test test/generate_smile_simulation_core.test.mjs  # ✅ 32/32 pass

# Flutter
cd ocg_proyect
flutter analyze                        # ✅ 0 issues
flutter test test/features/simulator   # ✅ 31/31 pass
flutter test test/services/simulator   # ✅ 7/7 pass
```

## Deploy

```bash
firebase --project ocg-humanbionics deploy --only functions:generateSmileSimulation  # ✅ OK
firebase --project ocg-humanbionics deploy --only firestore:rules,storage           # ✅ OK
```

## Resumen de bloques implementados

| Bloque | Descripción | Tests |
|---|---|---|
| 01 | Contrato de datos: SimulationModel + StoragePaths | Flutter 23/23 |
| 02 | Backend prompt profiles: 8 perfiles diferenciados | Functions 24/24 (+15) |
| 03 | UI admin: selector + formulario dinámico | Flutter 23/23 |
| 04 | Preflight foto: PhotoQualityService + guard backend | Flutter 30/30 (+7), Functions 28/28 (+4) |
| 05 | Attempts + revisión: subcolección, aprobar/rechazar | Flutter 31/31 (+1), Functions 32/32 (+4) |
| 06 | Vista paciente: limpia sin metadatos + rules | Flutter 31/31 |
| 07 | QA, deploy, analyze limpio | Flutter 31/31, Functions 32/32, Analyze 0 issues |

## Funcionalidades implementadas

- ✅ 8 perfiles de tratamiento con prompts visualmente diferenciados
- ✅ Selector de tratamiento con chips visuales (admin)
- ✅ Formulario dinámico por perfil (admin)
- ✅ Preflight de foto: bloquea fotos malas, expansor sin intraoral
- ✅ Subcolección de attempts con historial
- ✅ Aprobación del doctor antes de compartir
- ✅ Vista paciente limpia (solo antes/después, sin metadatos)
- ✅ Firestore rules: attempts admin-only
- ✅ Storage rules: `{allPaths=**}` cubre rutas anidadas
- ✅ Backend preflight: rechaza fotos rejected y expansor sin intraoral
- ✅ Compatibilidad legacy: treatmentType → perfil automático

## Limitaciones conocidas

- Node.js 20 deprecation warning (EOL 2026-10-30)
- ML Kit no disponible en web (manejado con warning)
- gpt-image-2 no es modelo dental especializado (mitigado con perfiles de prompt)
- Prueba E2E visual pendiente (requiere app Flutter corriendo)

## Decisión final

✅ **SIMULADOR LISTO PARA USO CONTROLADO**

La IA nunca publica directo al paciente. El doctor revisa, aprueba y solo lo aprobado se comparte.
Cada tratamiento genera prompts visualmente distintos. La foto se valida antes de consumir créditos.
