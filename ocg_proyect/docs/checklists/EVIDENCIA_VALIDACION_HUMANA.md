# Evidencia de validación humana OCG

> Usa esta plantilla para registrar la ejecución real de validación final.

---

## 1. Datos generales

- **Fecha:**
- **Equipo donde se probó:**
- **Sistema operativo:**
- **Responsable:**
- **Rama:**
- **Commit:**
- **Repositorio:**

---

## 2. Estado git

### `git status --short`

```text
Pegar aquí
```

### Observaciones git

- 

---

## 3. Flutter doctor

### `flutter doctor -v`

```text
Pegar aquí
```

### Observaciones Flutter/SDK

- 

---

## 4. Flutter analyze

### `flutter analyze`

```text
Pegar aquí
```

### Resultado

- [ ] Verde
- [ ] Falló

---

## 5. Flutter test

### `flutter test`

```text
Pegar aquí
```

### Resultado

- [ ] Verde
- [ ] Falló
- **Cantidad total de tests:**

---

## 6. Build Android

### `flutter build apk --debug`

```text
Pegar aquí
```

### Resultado

- [ ] APK generado
- [ ] Falló por proyecto
- [ ] No ejecutable por entorno

### Ruta del APK

- 

### Evidencia adicional

- capturas / instalación / logs:

---

## 7. Functions build/test

### `npm run build`

```text
Pegar aquí
```

### `node --test test/*.test.mjs`

```text
Pegar aquí
```

### Resultado Functions

- [ ] Build verde
- [ ] Tests verdes
- [ ] Falló
- **Cantidad total de tests:**

---

## 8. Evidencia PayU

### Caso aprobado

- referencia:
- tratamiento:
- resultado:
- evidencia:

### Caso rechazado

- referencia:
- tratamiento:
- resultado:
- evidencia:

### Caso pendiente

- referencia:
- tratamiento:
- resultado:
- evidencia:

### Webhook duplicado

- referencia:
- resultado:
- evidencia:

### Paciente con dos tratamientos

- paciente:
- tratamiento pagado:
- tratamiento no afectado:
- evidencia:

### Firestore / logs

- ruta sesión PayU:
- ruta transacción:
- logs relevantes:

---

## 9. Evidencia IA

### Configuración

- `OPENAI_API_KEY` configurada: sí / no
- `AI_SIMULATOR_ENABLED` activo: sí / no
- modelo usado:

### Flujo

- paciente:
- simulación creada:
- estado `generating` observado: sí / no
- estado `ready` observado: sí / no
- error controlado observado: sí / no

### Storage / Firestore

- ruta original:
- ruta resultado:
- `resultPath` registrado: sí / no
- compartida al paciente: sí / no

### Evidencia

- capturas:
- logs:

---

## 10. Evidencia Android push

- dispositivo:
- token guardado con `platform=android`: sí / no
- foreground: ok / fail
- background: ok / fail
- tap navigation: ok / fail
- token inválido desactivado: sí / no / no probado
- evidencia:

---

## 11. Evidencia iOS push

- dispositivo:
- token guardado con `platform=ios`: sí / no
- foreground: ok / fail
- background: ok / fail
- terminated: ok / fail
- tap navigation: ok / fail
- token inválido desactivado: sí / no / no probado
- payload con `apns`: sí / no
- Android siguió funcionando: sí / no
- evidencia:

---

## 12. Bugs encontrados

| ID | Módulo | Severidad | Descripción | Pasos para reproducir | Evidencia |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

---

## 13. Decisión final

- [ ] Aprobado
- [ ] Aprobado con observaciones
- [ ] Rechazado

### Resumen de decisión

- 

### Observaciones finales

- 
