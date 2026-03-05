# 06 — Seguimiento de Etapas del Tratamiento

> **Tu objetivo:** el módulo de mayor valor percibido para el paciente. Ver visualmente en qué punto está su tratamiento es lo que hace que el paciente sienta que la clínica es organizada y profesional. Hazlo visualmente impecable.

---

## Lo que debes entregar al terminar este bloque

- [ ] TreatmentTimeline widget funcionando con animaciones correctas
- [ ] TreatmentProgressBar en el home del paciente
- [ ] UpdateStageDialog para el admin con validación
- [ ] StageHistoryList con el historial de cambios
- [ ] Notificación push automática al cambiar la etapa (ver doc 09)

---

## Las 7 etapas y su lógica

```
diagnostico → planificacion → instalacion → seguimientoActivo
                                                    ↓
                                             ajusteFinal → retencion → alta
```

La etapa solo puede avanzar. Si el admin comete un error al cambiar la etapa, NO se puede revertir con un botón — hay que crear una nota en el historial explicando el ajuste y continuar desde donde está. Esto es para mantener la integridad del historial clínico.

---

## TreatmentTimeline Widget

El timeline es vertical. Cada nodo (etapa) tiene tres estados visuales posibles:

**Completada:** ícono de checkmark verde (OcgColors.success), línea de conexión verde sólida hacia abajo.

**Activa (etapa actual):** ícono de reloj en bronze con animación de pulso suave (AnimationController con RepeatMode.reverse). El borde del nodo parpadea sutilmente para indicar que está en progreso.

**Pendiente:** ícono de círculo gris claro (OcgColors.mist con borde), línea de conexión gris punteada hacia abajo.

Cada nodo al ser tocado muestra la StageCard con los detalles de esa etapa.

---

## UpdateStageDialog — Solo para el admin

Antes de permitir el cambio de etapa, mostrar un dialog de confirmación que incluya:
1. La etapa actual y la etapa nueva visualmente
2. Campo de texto obligatorio para notas del cambio (mínimo 10 caracteres)
3. Advertencia visible: "Esta acción no se puede deshacer. El historial quedará registrado."
4. Botón confirmar en OcgColors.espresso
5. Botón cancelar en outline

Si el admin deja el campo de notas vacío o con menos de 10 caracteres, no permitir confirmar y mostrar el error en el campo.

---

## StageCard — Detalle de cada etapa

Cuando el usuario toca una etapa en el timeline, se expande una card con:
- Nombre completo de la etapa
- Descripción clínica (texto fijo según la etapa, definido en el código)
- Fecha de inicio de la etapa (si aplica)
- Fecha de finalización (si aplica)
- Notas que dejó la doctora al cambiar a esta etapa
- Fotos asociadas a esta etapa (si hay alguna subida)

---

## Descripciones clínicas por etapa

Define estas descripciones como constantes en el código:

```dart
const Map<TreatmentStage, String> stageDescriptions = {
  TreatmentStage.diagnostico:
      'Valoración inicial completa: radiografías panorámicas, fotografías clínicas y elaboración del plan de tratamiento personalizado.',
  TreatmentStage.planificacion:
      'Plan clínico detallado definido y aprobado. Presupuesto acordado y consentimiento informado firmado.',
  TreatmentStage.instalacion:
      'Colocación de brackets, alineadores o aparatología indicada. Inicio oficial del movimiento dental.',
  TreatmentStage.seguimientoActivo:
      'Fase de controles periódicos. Se realizan ajustes y se monitorea el movimiento dental hacia los objetivos del plan.',
  TreatmentStage.ajusteFinal:
      'Refinamientos finales de la posición dental. Detallado estético y correcciones menores para el resultado óptimo.',
  TreatmentStage.retencion:
      'Tratamiento activo completado. Retenedores instalados para estabilizar el resultado obtenido.',
  TreatmentStage.alta:
      'Tratamiento finalizado exitosamente. Se han logrado los objetivos clínicos y estéticos planeados.',
};
```
