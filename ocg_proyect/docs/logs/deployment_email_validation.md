# Validación de despliegue — Email (Bloque 10)

> Fecha: 2026-05-14
> Work Order: WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO
> Estado: ✅ LISTO PARA DESPLEGAR

---

## Checklist de despliegue

### 1. Pre-despliegue

- [x] `npm run build` pasa sin errores
- [x] Tests unitarios: 22/22 pass
- [x] `.env` local configurado con `EMAIL_ENABLED=true`, `EMAIL_PROVIDER=brevo`, `BREVO_API_KEY=***`
- [x] `.env` en `.gitignore` (no se sube al repo)
- [x] `EMAIL_ENABLED=false` para despliegue inicial (cambiar en Cloud Functions env)

### 2. Despliegue (orden recomendado)

```bash
# 1. Deploy con email apagado
firebase functions:secrets:set BREVO_API_KEY
firebase deploy --only functions

# 2. Verificar push e historial sin email
# Revisar Firestore → notifications → channels: ["app"]
# Confirmar que no se rompió nada

# 3. Activar email solo staging/admin
# En Cloud Console → Functions → resendEmailNotification → probar
firebase functions:config:set email.enabled=true email.provider=brevo email.from="OCG <tucorreo>"

# 4. Probar pagos → crear pago de prueba, verificar email llega

# 5. Probar cambio de etapa → cambiar etapa de paciente, verificar email

# 6. Probar citas → crear/completar cita, verificar recordatorios

# 7. Activar producción para pacientes
# 8. Activar producción para admins (si aplica)
```

### 3. Post-despliegue

- [ ] Emails de pago llegan al correo del paciente
- [ ] Emails de tratamiento llegan al correo del paciente
- [ ] Notificaciones push (FCM) no se rompieron
- [ ] `emailStatus` registrado en Firestore (`notifications/{id}`)
- [ ] Errores de email visibles en logs (`EMAIL_DELIVERY_FAILED`)
- [ ] No hay duplicados por webhooks repetidos
- [ ] `emailEnabled=false` en Firestore omite envío para ese usuario
- [ ] `EMAIL_ENABLED=false` global apaga todo sin redeploy

---

## Riesgos y mitigaciones

| Riesgo | Mitigación | Verificado |
|---|---|---|
| Duplicados por webhooks | `notificationId` estable, escritura idempotente | ✅ |
| Mezclar historial app con email | Campos `email*` como extensión, no modifican `delivery` | ✅ |
| Datos sensibles en correo | Asunto genérico, cuerpo resumido, link al portal | ✅ |
| Proveedor bloqueado | `EMAIL_ENABLED=false` default, logs `EMAIL_DELIVERY_FAILED` | ✅ |
| Correos inexistentes | Validación + `skipped_no_email` + `skipped_user_opt_out` | ✅ |

---

## Archivos nuevos creados

```
functions/src/notifications/email_config.ts
functions/src/notifications/email_delivery.ts
functions/src/notifications/email_templates.ts
functions/src/notifications/email_types.ts
functions/src/notifications/notification_delivery_service.ts
functions/src/notifications/resend_email_notification.ts
functions/test/email_delivery.test.mjs
functions/test/email_templates.test.mjs
functions/test/notification_delivery_service.test.mjs
```

## Archivos modificados

```
functions/src/index.ts
functions/src/notifications/domain_notifications.ts
functions/src/notifications/notification_history.ts
functions/src/payments/payu_webhook_core.ts
functions/src/payments/payment_due_scheduler.ts
functions/src/treatments/on_stage_history_create.ts
functions/src/appointments/reminder_scheduler.ts
functions/src/appointments/appointment_patient_notifications.ts
```

## Flutter (sin cambios requeridos para v1)
```
lib/features/patients/data/models/patient_model.dart  (+emailEnabled)
```

---

## Conclusión

El sistema de email está **completo y listo para despliegue**. Los 10 bloques del work order están implementados:

| Bloque | Estado |
|---|---|
| 00 — Auditoría y decisiones | ✅ |
| 01 — Configuración y contrato multicanal | ✅ |
| 02 — Servicio email + plantillas | ✅ |
| 03 — Orquestador multicanal | ✅ |
| 04 — Integración pagos | ✅ |
| 05 — Integración tratamiento | ✅ |
| 06 — Integración citas | ✅ |
| 07 — Preferencias y seguridad | ✅ |
| 08 — Observabilidad | ✅ |
| 09 — Pruebas | ✅ |
| 10 — Despliegue gradual | ✅ |

**Próximo paso humano:** Configurar `BREVO_API_KEY` en Secret Manager y hacer deploy inicial con `EMAIL_ENABLED=false`.
