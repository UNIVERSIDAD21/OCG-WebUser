# BLOQUE 07 - QA, deploy y prueba end-to-end

## Objetivo

Cerrar el simulador como listo para uso controlado con API key ya configurada.

Este bloque valida todo lo anterior, limpia errores de analisis si aplica, despliega la Function y ejecuta una prueba real con paciente ficticio e imagen autorizada.

## Precondiciones

- `OPENAI_API_KEY` ya esta configurada en backend segun confirmacion del usuario.
- No leer ni imprimir el valor del secreto.
- `AI_SIMULATOR_ENABLED=true`.
- `OPENAI_IMAGE_MODEL=gpt-image-2`.
- Paciente ficticio disponible.
- Imagen autorizada para prueba.

## Validacion local obligatoria

Desde `ocg_proyect/functions`:

```bash
npm run build
```

Debe pasar.

Desde `ocg_proyect`:

```bash
flutter test test/features/simulator
```

Debe pasar.

Desde `ocg_proyect`:

```bash
flutter analyze
```

Debe quedar limpio o debe existir justificacion escrita si se decide aceptar warnings externos.

## Limpieza de `flutter analyze`

Antes de crear estos bloques, `flutter analyze` fallaba por 17 issues existentes.

Si el cierre exige analyze limpio, corregir minimamente:

- `lib/features/admin/presentation/web/components/section_panel.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/consultation/providers/consultation_provider.dart`
- `lib/features/dashboard/presentation/admin_modules_screens.dart`
- `lib/features/dashboard/presentation/patient_appointments_screen.dart`
- `lib/features/migration/legacy_migration_service.dart`
- `lib/features/migration/providers/legacy_migration_provider.dart`
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`
- `test/features/migration/legacy_migration_service_test.dart`

No hacer refactors grandes. Solo eliminar imports/variables no usadas y aplicar fixes triviales.

## Deploy Function

Desde `ocg_proyect`:

```bash
firebase --project ocg-humanbionics deploy --only functions:generateSmileSimulation
firebase --project ocg-humanbionics functions:list
```

Validar:

- `generateSmileSimulation` aparece desplegada.
- No se solicita valor del secreto en consola.
- No se imprime API key.

## Deploy rules si se tocaron

Si los bloques 05/06 modificaron reglas:

```bash
firebase --project ocg-humanbionics deploy --only firestore:rules,storage
```

Si se agregaron indices por query nueva:

```bash
firebase --project ocg-humanbionics deploy --only firestore:indexes
```

## Prueba end-to-end admin

Usar paciente ficticio y foto autorizada.

Flujo:

1. Abrir paciente ficticio.
2. Ir a simulador.
3. Crear nueva simulacion.
4. Elegir `metal_braces`.
5. Configurar ligas grises o color elegido.
6. Subir/tomar foto valida.
7. Confirmar preflight.
8. Generar con IA.
9. Esperar `ready`.
10. Ver comparador antes/despues.
11. Confirmar que aparecen brackets metalicos, no solo dientes blancos.
12. Aprobar resultado.
13. Compartir con paciente.

Validar Firestore:

- doc principal tiene `status = shared`;
- `compartidaConPaciente = true`;
- `doctorReviewStatus = approved`;
- `treatmentProfileId = metal_braces`;
- `modelUsed = gpt-image-2`;
- `generationProvider = openai`;
- `promptVersion = ocg-dental-treatment-v2`;
- `attemptCount >= 1`;
- existe attempt.

Validar Storage:

- existe `original.jpg`;
- existe `result.jpg`;
- existe result de attempt si se implemento.

## Prueba paciente

Entrar como paciente ficticio.

Validar:

- solo ve simulacion compartida;
- ve comparador antes/despues;
- no ve `openai`;
- no ve `gpt-image-2`;
- no ve prompt;
- no ve parametros del doctor;
- no puede generar ni regenerar;
- no puede ver intentos rechazados.

## Matriz minima por tratamiento

Ejecutar al menos una prueba visual por perfil antes de declarar listo:

| Perfil | Resultado minimo aceptable |
| --- | --- |
| `metal_braces` | brackets metalicos y arco visibles |
| `esthetic_braces` | brackets claros/ceramicos diferentes a metalicos |
| `clear_aligners` | cubeta transparente o brillo plastico realista |
| `whitening` | solo cambia tono dental, no forma |
| `veneers` | cambia forma/proporcion de dientes anteriores |
| `smile_design` | resultado final sin aparatos |
| `palatal_expander` | bloquea foto frontal incompatible o muestra expansor con foto intraoral |
| `retainer` | respeta Essix/Hawley/fijo segun config |

## Registro de QA

Crear o actualizar un log:

```text
ocg_proyect/docs/logs/YYYY-MM-DD-simulador-tratamientos-ia-qa.md
```

Debe incluir:

- fecha;
- branch/commit si aplica;
- comandos ejecutados;
- resultado de `npm run build`;
- resultado de `flutter test`;
- resultado de `flutter analyze`;
- resultado de deploy;
- paciente ficticio usado, sin datos sensibles;
- perfiles probados;
- errores encontrados;
- decision final.

## Criterios de cierre final

- Functions build pasa.
- Flutter tests del simulador pasan.
- `flutter analyze` limpio o warnings aceptados y documentados.
- Function desplegada.
- Rules desplegadas si cambiaron.
- Prueba real con paciente ficticio completada.
- Cada tratamiento objetivo tiene diferenciacion visual o regla clara de bloqueo.
- Paciente solo ve antes/despues.
- No hay secretos en repo ni logs.

## Resultado esperado

El simulador queda listo para uso controlado en consulta con revision humana, tratamientos diferenciados y seguridad correcta.
