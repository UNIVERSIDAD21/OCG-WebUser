# Diseno del Simulador de Tratamientos Dentales con IA

Fecha: 2026-05-22  
Proyecto: OCG Web User / App Flutter admin + paciente  
Stack objetivo: Flutter, Firebase Auth, Firestore, Storage, Cloud Functions, OpenAI `gpt-image-2` con `images.edit`

## 0. Resumen ejecutivo

El simulador no debe seguir funcionando como un generador generico de "dientes mejorados". Debe convertirse en un flujo clinico-comercial guiado por perfiles de tratamiento.

La decision principal es esta:

```text
Un solo modelo de IA: gpt-image-2
Varios perfiles de tratamiento: prompts, parametros, validaciones y reglas visuales distintas
Una sola experiencia paciente: comparador antes/despues ya existente
Una experiencia admin mas completa: captura, preflight, configuracion, generacion, revision, iteracion y compartir
```

No se necesitan varias IA. Lo que se necesita es que la Cloud Function deje de mandar un prompt generico y empiece a construir instrucciones por tratamiento, usando parametros estructurados elegidos por el doctor.

El resultado debe seguir siendo orientativo, no una promesa clinica. La calidad debe ser suficientemente realista para apoyar una consulta, pero siempre con revision del doctor antes de compartir con el paciente.

## 1. Respuestas directas a las preguntas

### 1. Flujo de usuario

No recomiendo un solo boton "Generar" como flujo principal.

El flujo correcto debe ser paso a paso, con una opcion rapida basada en defaults. El doctor no debe escribir todo manualmente, pero si debe configurar lo minimo que cambia el resultado visual.

Flujo recomendado:

```text
1. Elegir tratamiento
2. Tomar/subir foto
3. Validar calidad de foto
4. Configurar parametros clinicos/visuales
5. Generar con IA
6. Revisar antes/despues
7. Aprobar, regenerar o compartir con paciente
```

Para no hacerlo pesado:

- Modo rapido: tratamiento + defaults + notas opcionales.
- Modo avanzado: parametros especificos por tratamiento.

La pantalla admin debe sentirse como un asistente clinico, no como una caja de prompt.

### 2. Una IA o varias

Decision del proyecto: se usa una sola IA, `gpt-image-2`.

Mi recomendacion dentro de esa restriccion:

- Mantener una sola Cloud Function principal.
- Mantener un solo proveedor IA: OpenAI.
- Mantener un solo modelo: `gpt-image-2`.
- Crear multiples `TreatmentPromptProfile`.
- Crear multiples formularios de configuracion por tratamiento.
- Versionar prompts y parametros.

La diferencia entre brackets, alineadores, blanqueamiento, carillas, diseno de sonrisa, expansor y retenedor no debe depender de cambiar de modelo. Debe depender de:

- prompt base comun,
- prompt especifico del tratamiento,
- parametros estructurados del doctor,
- validaciones de foto,
- reglas de rechazo cuando la foto no sirve para ese tratamiento,
- post-revision del doctor.

### 3. Antes y despues

Decision del proyecto: mantener el antes y despues como ya esta configurado.

El resultado debe presentarse asi:

```text
Izquierda: foto original
Derecha: foto generada
Interaccion: slider de comparacion antes/despues ya existente
```

No recomiendo mostrar al paciente variaciones multiples por defecto. Eso puede confundir y convertir la simulacion en una promesa visual. Las variaciones deben existir para el admin durante revision, no para el paciente.

Para admin:

- Ver antes/despues.
- Ver parametros usados.
- Ver numero de intento.
- Aprobar resultado.
- Regenerar con ajustes.
- Compartir solo cuando este aprobado.

Para paciente:

- Ver solo comparacion antes/despues.
- No ver prompts.
- No ver parametros internos.
- No pedir ajustes directamente desde el simulador.

### 4. Fidelidad vs utilidad

Debe ser una simulacion orientativa realista, no un resultado indistinguible de una fotografia clinica final.

Objetivo correcto:

```text
Utilidad comercial y educativa en consulta
Realismo suficiente para explicar posibilidades
Control clinico antes de compartir
Disclaimers visibles
No prometer resultado exacto
```

No conviene perseguir "casi indistinguible de un resultado real" porque:

- `gpt-image-2` no es un modelo dental especializado.
- Las fotos de entrada no siempre seran clinicas.
- Algunos tratamientos no son visibles en una sonrisa frontal.
- El resultado real depende de diagnostico, biomecanica, tiempo, respuesta biologica y plan clinico.

La vara de calidad debe ser:

- No deformar rostro, labios, piel ni identidad.
- No inventar anatomia absurda.
- Diferenciar claramente el tratamiento elegido.
- Mantener proporcion, iluminacion y perspectiva.
- Ser revisable y descartable por el doctor.

### 5. Parametros configurables por el doctor

Los parametros deben ser estructurados, no texto libre. Las notas libres existen, pero solo como complemento.

Parametros globales para todos los tratamientos:

- Tipo de tratamiento.
- Objetivo visual: mostrar aparato, mostrar resultado final, o mostrar mejora estetica.
- Arcada visible: superior, inferior, ambas, no definido.
- Severidad orientativa: leve, moderada, severa.
- Nivel de naturalidad: conservador, balanceado, cosmetico.
- Mantener color dental actual, mejorar levemente, mejorar moderadamente.
- Correccion de alineacion: ninguna, leve, moderada.
- Notas clinicas opcionales.
- Foto: sonrisa frontal, intraoral frontal, intraoral superior, intraoral inferior, perfil.

Parametros por tratamiento:

#### Brackets metalicos

- Arcada: superior, inferior, ambas.
- Color de ligas: gris, transparente, azul, rojo, morado, multicolor.
- Etapa visual: inicio de tratamiento, alineacion intermedia, montaje completo.
- Brackets en todos los dientes visibles o solo sector anterior.
- Arco metalico visible: fino, medio.
- Severidad de apiñamiento: leve, moderada, severa.

Objetivo visual: que se vean brackets metalicos reales, arco y ligas, sin "blanquear" como tratamiento principal.

#### Brackets esteticos ceramicos/zafiro

- Material: ceramico, zafiro.
- Ligas: transparentes, perladas, blancas.
- Arco: metalico, estetico claro.
- Arcada: superior, inferior, ambas.
- Nivel de visibilidad: discreto, medio.

Objetivo visual: diferenciar claramente de brackets metalicos. Deben verse translucidos/blancos, no invisibles.

#### Alineadores transparentes

- Alineador puesto: si/no.
- Attachments visibles: ninguno, pocos, varios.
- Arcada: superior, inferior, ambas.
- Brillo/transparencia: sutil, medio.
- Etapa visual: inicio, avance intermedio, refinamiento.

Objetivo visual: mostrar cubetas transparentes sobre dientes, bordes sutiles y posible brillo plastico. No convertirlo automaticamente en blanqueamiento.

#### Blanqueamiento dental

- Tono objetivo: mejora leve, media, alta.
- Naturalidad: natural, brillante controlado.
- Mantener manchas leves: si/no.
- Sensibilidad estetica: evitar blanco artificial.
- Dientes a tratar: visibles anteriores, sonrisa visible completa.

Objetivo visual: cambiar color, no forma ni posicion dental. No crear carillas por accidente.

#### Carillas / vinillas

- Material visual: resina, ceramica.
- Forma: natural, ovalada, cuadrada-suave, Hollywood controlado.
- Tono: natural claro, blanco calido, blanco alto.
- Longitud incisal: conservar, alargar leve, alargar medio.
- Simetria: leve, media, alta.
- Correccion de espacios: cerrar diastemas leves, mantener, no definido.

Objetivo visual: modificar forma, borde incisal, proporcion y color de dientes anteriores, sin cambiar labios ni encia agresivamente.

#### Diseno de sonrisa

- Estilo: natural, armonico, cosmetico.
- Alineacion final: leve, media, idealizada.
- Tono: natural claro, blanco moderado.
- Borde incisal: conservador, armonizado.
- Simetria de sonrisa: leve, media.
- Aparatos visibles: no.

Objetivo visual: resultado final ideal sin brackets, alineadores, expansores ni retenedores.

#### Expansor de paladar

- Tipo visual: Hyrax, Haas, removible.
- Foto requerida: intraoral superior o boca abierta con paladar visible.
- Nivel de visibilidad: realista segun foto.
- Arcada: superior.
- Estado: instalado, referencia educativa.

Regla importante: en una sonrisa frontal normal el expansor casi no se ve. Si la foto no muestra paladar o arcada superior interna, el sistema debe pedir nueva foto o marcar el tratamiento como no simulable con esa imagen.

#### Retenedor post-tratamiento

- Tipo: Essix transparente, Hawley, fijo lingual.
- Arcada: superior, inferior, ambas.
- Visibilidad: sutil, media.
- Estado: post-tratamiento final.

Regla importante: un retenedor fijo lingual no se ve en una sonrisa frontal normal. Un Essix puede verse como brillo/borde transparente. Un Hawley requiere que el alambre sea visible. El doctor debe elegir tipo de retenedor.

### 6. Iteracion

El flujo de iteracion debe ser controlado, no un "generar infinitamente".

Recomiendo:

- Maximo 3 intentos por simulacion, como ya se viene manejando.
- Cada intento guarda parametros, promptVersion y resultPath propio.
- El admin puede marcar un intento como aprobado.
- Solo el intento aprobado se comparte al paciente.
- Si el resultado falla por mala foto, no debe consumir intento clinico si el preflight lo detecta antes de llamar a OpenAI.

Opciones de reintento:

- Regenerar con mismos parametros.
- Ajustar naturalidad.
- Ajustar intensidad del cambio.
- Cambiar tipo/subtipo de tratamiento.
- Cambiar color de ligas o material.
- Cambiar tono dental objetivo.
- Cambiar foto original.
- Agregar nota clinica.

No recomiendo que el paciente pida ajustes desde su vista. Si quiere cambios, debe conversarlo con el doctor y el admin genera una nueva version.

### 7. Lo que ve el paciente vs admin

Decision del proyecto: deben ser diferentes.

Admin ve:

- Foto original.
- Resultado.
- Tratamiento elegido.
- Parametros configurados.
- Estado de foto/preflight.
- Intentos.
- Errores.
- Botones de regenerar, aprobar, archivar y compartir.
- Disclaimer clinico.

Paciente ve:

- Solo comparacion antes/despues.
- Fecha de simulacion.
- Tratamiento o titulo amigable si se desea.
- Disclaimer orientativo.
- Sin prompts.
- Sin parametros.
- Sin boton generar.
- Sin boton regenerar.
- Sin errores internos.

La vista paciente debe seguir siendo simple y segura.

### 8. Edge cases

El sistema debe validar la foto antes de generar.

Casos a detectar:

- Foto con poca luz.
- Foto borrosa.
- Boca cerrada.
- Sonrisa muy pequena.
- Dientes no visibles.
- Rostro de lado.
- Imagen recortada sin boca.
- Mas de una persona.
- Obstrucciones: tapabocas, mano, objetos, labios cubriendo dientes.
- Foto demasiado pequena o comprimida.
- Tratamiento incompatible con el tipo de foto, por ejemplo expansor con sonrisa frontal cerrada.
- Paciente ya tiene brackets y se pide alineadores.
- Paciente tiene retenedor o aparato visible y se pide diseno final sin aparatos.

Estados sugeridos:

```text
photoQuality = valid
photoQuality = usable_with_warning
photoQuality = rejected
```

Comportamiento:

- `valid`: permite generar.
- `usable_with_warning`: permite generar pero muestra advertencia al admin.
- `rejected`: no llama a OpenAI; pide nueva foto.

Esto ahorra costo, evita resultados malos y reduce frustracion.

### 9. Limitaciones tecnicas de gpt-image-2 y mitigacion

`gpt-image-2` no es dental especializado. Mitigaciones recomendadas:

- Usar perfiles de prompt por tratamiento.
- Usar parametros estructurados en vez de notas libres.
- Validar foto antes de generar.
- Limitar edicion a zona dental visible.
- Pedir preservar identidad, rostro, labios, piel, luz y encuadre.
- No permitir tratamientos que no son visibles con la foto cargada.
- Guardar cada intento para auditoria.
- Requerir aprobacion del doctor antes de compartir.
- Mantener disclaimer orientativo.
- Agregar validacion post-generacion.
- Comparar cambios fuera de la zona dental para detectar deformaciones.
- Rechazar resultados con dientes irreales, exceso de blanco, aparatos mal ubicados o cambios de identidad.

La mitigacion mas importante no es tecnica sino de flujo: la IA no debe publicar directo al paciente. Siempre debe pasar por revision del admin/doctor.

## 2. Flujo completo propuesto

### 2.1 Flujo admin

```text
Paciente > Simulador > Nueva simulacion
```

Paso 1: seleccionar tratamiento

- Brackets metalicos.
- Brackets esteticos.
- Alineadores transparentes.
- Blanqueamiento dental.
- Carillas / vinillas.
- Diseno de sonrisa.
- Expansor de paladar.
- Retenedor post-tratamiento.

Paso 2: elegir objetivo visual

- Mostrar aparato.
- Mostrar mejora estetica.
- Mostrar resultado final ideal.

No todos los objetivos aplican a todos los tratamientos. Por ejemplo:

- Blanqueamiento: mejora estetica.
- Diseno de sonrisa: resultado final ideal.
- Brackets: mostrar aparato.
- Expansor: mostrar aparato, solo con foto compatible.

Paso 3: capturar/subir foto

- Camara.
- Galeria.
- Guia visual para centrar rostro/sonrisa.
- Para expansor: pedir foto intraoral superior.
- Para retenedor Hawley: pedir sonrisa con dientes visibles.

Paso 4: preflight de foto

- Analizar rostro y region de sonrisa.
- Validar luz, nitidez, dientes visibles y compatibilidad con tratamiento.
- Si falla, pedir nueva foto antes de llamar a OpenAI.

Paso 5: configurar parametros

- Defaults recomendados por tratamiento.
- Parametros principales visibles.
- Parametros avanzados colapsados.
- Notas clinicas opcionales.

Paso 6: generar

- Crear/actualizar documento en Firestore.
- Llamar Cloud Function.
- Cloud Function construye prompt por tratamiento.
- OpenAI genera resultado.
- Storage guarda resultado.
- Firestore pasa a `ready` o `failed`.

Paso 7: revision doctor/admin

- Comparador antes/despues.
- Ver parametros usados.
- Aprobar.
- Regenerar.
- Cambiar foto.
- Archivar.

Paso 8: compartir

- Solo si `status == ready`.
- Solo si doctor/admin aprueba.
- Cambia a `shared`.
- Paciente ya puede verlo.

### 2.2 Flujo paciente

```text
Paciente > Mis simulaciones > Abrir simulacion compartida
```

El paciente ve:

- Comparador antes/despues.
- Imagen original a la izquierda.
- Imagen despues a la derecha.
- Slider interactivo.
- Disclaimer orientativo.

El paciente no ve:

- Configuracion avanzada.
- Prompts.
- Intentos rechazados.
- Errores tecnicos.
- Botones de generacion.

## 3. Pantallas recomendadas

### 3.1 Admin - Lista/historial de simulaciones

Ubicacion actual probable: `PatientSimulatorTab`.

Debe mostrar:

- Tratamiento.
- Fecha.
- Estado.
- Miniatura.
- Si esta compartida.
- Ultimo intento.
- Boton nueva simulacion.

Estados visibles:

- Borrador.
- Generando.
- Lista para revisar.
- Compartida.
- Error.
- Archivada.

### 3.2 Admin - Setup de simulacion

Puede vivir dentro de `SimulatorScreen`.

Secciones:

- Tratamiento.
- Objetivo visual.
- Foto.
- Calidad de foto.
- Parametros.
- Notas.
- Boton generar.

### 3.3 Admin - Resultado y revision

Debe mantener el `BeforeAfterSlider`.

Acciones:

- Aprobar.
- Compartir con paciente.
- Regenerar.
- Cambiar parametros.
- Cambiar foto.
- Archivar.

### 3.4 Paciente - Resultado compartido

Debe ser una pantalla limpia:

- Antes/despues.
- Titulo del tratamiento.
- Fecha.
- Disclaimer.

Sin herramientas de edicion.

## 4. Tratamientos y comportamiento visual esperado

| Tratamiento | Que debe cambiar visualmente | Que no debe cambiar |
| --- | --- | --- |
| Brackets metalicos | Brackets metalicos, arco, ligas | Color dental como objetivo principal, rostro, labios |
| Brackets esteticos | Brackets claros/translucidos, arco discreto | No convertir en alineadores invisibles |
| Alineadores | Cubeta transparente, brillo sutil, attachments opcionales | No poner brackets, no blanquear de mas |
| Blanqueamiento | Tono dental mas claro y natural | Forma, posicion y tamano dental |
| Carillas/vinillas | Forma, proporcion, tono, borde incisal | Identidad, labios, piel |
| Diseno de sonrisa | Resultado final armonico sin aparatos | No mostrar brackets, alineadores o retenedores |
| Expansor | Aparato palatino si la foto lo permite | No inventarlo si el paladar no se ve |
| Retenedor | Essix/Hawley/fijo segun tipo y visibilidad | No mostrarlo si el tipo/foto lo hace invisible |

## 5. Arquitectura tecnica recomendada

### 5.1 Mantener base actual

El proyecto ya tiene una base aprovechable:

- `patients/{patientId}/simulations/{simulationId}`.
- Storage en `simulations/{patientId}/{simulationId}/...`.
- `SimulationStatus`.
- `generationProvider = openai`.
- `modelUsed = gpt-image-2`.
- `attemptCount`.
- `promptUsed`.
- `promptVersion`.
- `BeforeAfterSlider`.
- Cloud Function `generateSmileSimulation`.

No recomiendo reconstruir todo. Recomiendo evolucionar el contrato.

### 5.2 Cambios recomendados en Firestore

Documento principal:

```json
{
  "id": "sim_123",
  "patientId": "patient_123",
  "originalPath": "simulations/patient_123/sim_123/original.jpg",
  "resultPath": "simulations/patient_123/sim_123/result.jpg",
  "status": "ready",
  "compartidaConPaciente": false,
  "treatmentProfileId": "metal_braces",
  "visualGoal": "show_appliance",
  "doctorConfig": {
    "arch": "both",
    "severity": "moderate",
    "ligatureColor": "gray",
    "naturalness": "balanced"
  },
  "photoQuality": {
    "status": "valid",
    "score": 0.86,
    "warnings": []
  },
  "generationProvider": "openai",
  "modelUsed": "gpt-image-2",
  "promptVersion": "ocg-dental-treatment-v2",
  "attemptCount": 1,
  "doctorReviewStatus": "pending",
  "approvedAttemptId": null,
  "createdBy": "admin_123",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Subcoleccion recomendada:

```text
patients/{patientId}/simulations/{simulationId}/attempts/{attemptId}
```

Ejemplo de intento:

```json
{
  "attemptNumber": 1,
  "resultPath": "simulations/patient_123/sim_123/attempts/1/result.jpg",
  "status": "ready",
  "doctorConfig": {},
  "promptVersion": "ocg-dental-treatment-v2",
  "createdAt": "timestamp",
  "errorMessage": null,
  "reviewStatus": "pending"
}
```

Motivo:

- No perder historial de intentos.
- Poder aprobar uno.
- Evitar que el paciente vea intentos descartados.
- Auditar que parametros generaron cada resultado.

### 5.3 Storage recomendado

```text
simulations/{patientId}/{simulationId}/original.jpg
simulations/{patientId}/{simulationId}/result.jpg
simulations/{patientId}/{simulationId}/attempts/{attemptId}/result.jpg
simulations/{patientId}/{simulationId}/artifacts/mask.png
simulations/{patientId}/{simulationId}/thumb_before.jpg
simulations/{patientId}/{simulationId}/thumb_after.jpg
```

`result.jpg` debe apuntar al resultado activo/aprobado para no romper el comparador actual.

### 5.4 Cloud Function

Se puede evolucionar `generateSmileSimulation` en vez de crear una funcion nueva.

Payload recomendado:

```json
{
  "patientId": "patient_123",
  "simulationId": "sim_123",
  "treatmentProfileId": "metal_braces",
  "visualGoal": "show_appliance",
  "doctorConfig": {
    "arch": "both",
    "severity": "moderate",
    "ligatureColor": "gray"
  },
  "notes": "Paciente desea ver brackets metalicos con ligas grises."
}
```

Proceso backend:

```text
1. Validar auth y rol admin
2. Cargar paciente y simulacion
3. Validar estado permitido
4. Validar limite de intentos
5. Validar calidad/compatibilidad de foto
6. Construir prompt con TreatmentPromptProfile
7. Guardar intento en Firestore
8. Marcar simulacion como generating
9. Descargar original desde Storage
10. Llamar OpenAI images.edit con gpt-image-2
11. Guardar resultado en Storage
12. Ejecutar validaciones post-generacion
13. Actualizar attempt
14. Actualizar resultPath principal
15. Marcar status ready o failed
```

### 5.5 Prompt builder

El archivo actual `build_smile_prompt.ts` debe evolucionar de:

```text
prompt base + treatmentType + notes
```

a:

```text
prompt base comun
+ perfil del tratamiento
+ parametros estructurados
+ restricciones negativas
+ instrucciones de preservacion de identidad
+ advertencia de simulacion orientativa
+ version
```

Estructura sugerida:

```ts
type TreatmentPromptProfile = {
  id: string;
  label: string;
  allowedVisualGoals: string[];
  requiredPhotoTypes: string[];
  defaultConfig: Record<string, unknown>;
  buildTreatmentInstructions(config: DoctorConfig): string[];
  buildNegativeInstructions(config: DoctorConfig): string[];
};
```

Version sugerida:

```text
ocg-dental-treatment-v2
```

## 6. Logica de calidad de foto

### 6.1 Preflight antes de OpenAI

El sistema debe hacer una revision antes de gastar un intento.

Validaciones:

- Resolucion minima.
- Nitidez minima.
- Brillo/contraste minimo.
- Dientes visibles.
- Boca suficientemente visible.
- Una sola persona.
- Region de sonrisa detectable o ajustada manualmente.
- Compatibilidad foto/tratamiento.

Resultado:

```json
{
  "status": "usable_with_warning",
  "score": 0.72,
  "warnings": [
    "La sonrisa es pequena; el resultado puede ser menos preciso."
  ],
  "blockingReasons": []
}
```

### 6.2 Reglas bloqueantes por tratamiento

- Expansor de paladar: bloquear si no se ve paladar o arcada superior interna.
- Retenedor fijo: advertir que no sera visible en sonrisa frontal.
- Blanqueamiento: bloquear si casi no se ven dientes.
- Brackets/alineadores: advertir si la sonrisa muestra muy pocos dientes.
- Carillas/diseno: advertir si la foto esta borrosa o muy inclinada.

## 7. Iteracion y aprobacion

### 7.1 Estados de simulacion

Mantener estados actuales:

- `draft`
- `generating`
- `ready`
- `shared`
- `failed`
- `archived`

Agregar campo complementario:

```text
doctorReviewStatus = pending | approved | rejected
```

Uso:

- `ready + pending`: la IA genero, falta revision.
- `ready + approved`: puede compartirse.
- `ready + rejected`: no compartir, puede regenerarse.
- `shared + approved`: visible al paciente.

### 7.2 Reintentos

Cada reintento debe pedir motivo:

- Resultado poco natural.
- Aparato incorrecto.
- Color dental incorrecto.
- Cambio facial no deseado.
- Foto mala.
- Otro.

El motivo ayuda a ajustar parametros del siguiente intento.

### 7.3 No compartir automaticamente

La Cloud Function nunca debe marcar `shared`. Solo debe marcar `ready`.

Compartir es una accion humana del admin.

## 8. Prioridades por bloques

### Bloque 1 - Diseno funcional y contrato de datos

Objetivo:

- Cerrar definicion de tratamientos.
- Cerrar parametros por tratamiento.
- Cerrar contrato Firestore/Storage.
- Cerrar estados y permisos.

Entregables:

- Documento de perfiles.
- `treatmentProfileId`.
- `visualGoal`.
- `doctorConfig`.
- `photoQuality`.
- `doctorReviewStatus`.

Prioridad: maxima.

### Bloque 2 - UI admin paso a paso

Objetivo:

- Reemplazar "tipo de simulacion/tratamiento" generico por selector real.
- Agregar configuracion dinamica por tratamiento.
- Mantener boton generar, pero despues de la configuracion.

Entregables:

- Selector de tratamiento.
- Formulario dinamico.
- Modo rapido con defaults.
- Modo avanzado.
- Vista de preflight de foto.

Prioridad: maxima.

### Bloque 3 - Prompt profiles en Cloud Functions

Objetivo:

- Reemplazar prompt generico por perfiles por tratamiento.

Entregables:

- `build_dental_treatment_prompt.ts`.
- Profiles: `metal_braces`, `esthetic_braces`, `clear_aligners`, `whitening`, `veneers`, `smile_design`, `palatal_expander`, `retainer`.
- `promptVersion = ocg-dental-treatment-v2`.
- Tests unitarios del prompt builder.

Prioridad: maxima.

### Bloque 4 - Preflight de foto

Objetivo:

- No llamar OpenAI si la foto no sirve.
- Reducir resultados deformes.

Entregables:

- `photoQuality`.
- Reglas por tratamiento.
- Mensajes accionables.
- Bloqueo para expansor con foto incompatible.

Prioridad: alta.

### Bloque 5 - Intentos, revision y aprobacion

Objetivo:

- Permitir iterar sin perder historial.
- Compartir solo resultados aprobados.

Entregables:

- Subcoleccion `attempts`.
- `doctorReviewStatus`.
- Motivo de rechazo.
- Aprobar intento.
- `resultPath` apunta al intento aprobado o ultimo listo.

Prioridad: alta.

### Bloque 6 - Vista paciente simplificada

Objetivo:

- Mantener solo comparador antes/despues.
- Ocultar complejidad.

Entregables:

- Filtro solo `shared`.
- Disclaimer.
- Sin acciones de generacion.

Prioridad: media, porque la base ya existe.

### Bloque 7 - Validacion post-generacion

Objetivo:

- Detectar resultados no compartibles.

Entregables:

- Check de cambios fuera de region dental.
- Check de archivo generado.
- Warning si hubo deformacion aparente.
- Estado `ready + pending` para revision humana.

Prioridad: media.

### Bloque 8 - Refinamiento clinico por tratamiento

Objetivo:

- Ajustar defaults despues de pruebas reales.

Entregables:

- Galeria interna de ejemplos aprobados/rechazados.
- Ajuste de prompts.
- Ajuste de parametros.
- Metricas de intentos exitosos por tratamiento.

Prioridad: posterior a pruebas.

## 9. MVP recomendado

Para lograr diferencia visual rapido, recomiendo este orden:

1. Brackets metalicos.
2. Brackets esteticos.
3. Alineadores transparentes.
4. Blanqueamiento.
5. Carillas / vinillas.
6. Diseno de sonrisa.
7. Retenedor.
8. Expansor de paladar.

Motivo:

- Los primeros seis se pueden entender con una foto de sonrisa frontal.
- Retenedor depende del tipo.
- Expansor requiere una foto intraoral especifica y tiene mayor riesgo de resultado inventado si la foto no muestra paladar.

## 10. Cambios concretos sobre lo existente

### Flutter

Archivos probables:

- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`

Cambios:

- Agregar selector real de tratamiento.
- Agregar parametros por tratamiento.
- Agregar `doctorConfig`.
- Agregar UI de preflight.
- Agregar aprobacion/rechazo.
- Mantener `BeforeAfterSlider`.

### Functions

Archivos probables:

- `functions/src/simulator/build_smile_prompt.ts`
- `functions/src/simulator/generate_smile_simulation_core.ts`
- `functions/src/simulator/generate_smile_simulation.ts`

Cambios:

- Reemplazar prompt generico por prompt profiles.
- Validar `treatmentProfileId`.
- Validar `doctorConfig`.
- Guardar attempt.
- Guardar `doctorReviewStatus`.
- No compartir automaticamente.

### Firestore rules

Mantener regla base:

- Admin puede crear/generar/editar/compartir.
- Paciente solo lee `shared` y `compartidaConPaciente == true`.

### Storage rules

Mantener acceso por paciente/simulacion.

Revisar si se agregan rutas:

- `attempts/{attemptId}/result.jpg`
- `artifacts/mask.png`
- thumbnails.

## 11. Reglas de seguridad y producto

- Nunca poner API Key en Flutter.
- Nunca compartir automaticamente una imagen IA.
- Nunca mostrar intentos rechazados al paciente.
- Nunca presentar la simulacion como resultado garantizado.
- Nunca generar expansor si la foto no muestra zona compatible.
- Nunca permitir texto libre del doctor como unica fuente de instrucciones.
- Siempre guardar promptVersion, modelUsed, generationProvider y attemptCount.
- Siempre permitir archivar.
- Siempre permitir cambiar foto si la base no sirve.

## 12. Definicion de listo

El sistema se considera listo cuando:

- Cada tratamiento produce una diferencia visual reconocible.
- Brackets metalicos no se parecen a blanqueamiento.
- Brackets esteticos no se parecen a metalicos.
- Alineadores se ven transparentes y no como dientes simplemente mejorados.
- Blanqueamiento solo cambia tono.
- Carillas cambian forma/proporcion de forma controlada.
- Diseno de sonrisa no muestra aparatos.
- Expansor solo se genera con foto compatible.
- Retenedor respeta el tipo elegido.
- El admin puede aprobar/rechazar.
- El paciente solo ve antes/despues compartido.
- La simulacion queda claramente marcada como orientativa.

## 13. Mi recomendacion final

Yo lo haria como un flujo paso a paso con defaults inteligentes.

No cambiaria de modelo ni agregaria otra IA. Haria que `gpt-image-2` trabaje con perfiles por tratamiento y parametros clinicos estructurados.

La prioridad no es escribir prompts mas largos. La prioridad es construir un sistema que le diga a la IA exactamente que tratamiento debe visualizar, con que limites, con que foto, y con revision humana antes de compartir.

El cambio minimo de alto impacto es:

```text
1. Crear treatmentProfileId + doctorConfig
2. Crear prompts por tratamiento
3. Agregar UI de configuracion por tratamiento
4. Validar foto antes de generar
5. Mantener antes/despues como esta
6. Compartir al paciente solo resultados aprobados
```

Con eso el simulador deja de ser "dientes bonitos genericos" y empieza a comportarse como un simulador real de tratamientos de ortodoncia y estetica dental.
