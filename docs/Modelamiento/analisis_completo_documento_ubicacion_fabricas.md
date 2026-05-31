# Análisis completo del documento: Optimización de ubicación de lugares de producción

Documento original revisado:

`docs/Modelamiento/Investigacion_Ubicacion_Fabricas.docx`

Commit revisado:

`0f8780e577cc00d163e7fd703b1f10ab50143d52`

Archivo generado por Borlty para Erik Sebastian Fuentes Nuñez.

---

## 1. Entendimiento general del documento

El documento describe un proyecto de Investigación de Operaciones cuyo propósito es construir una simulación para encontrar la mejor ubicación de un conjunto de fábricas o lugares de producción dentro de una región geográfica abstracta.

La región se representa como un paralelogramo estricto definido por cuatro vértices en coordenadas `(x, y)`.

Dentro de ese paralelogramo se generan dos tipos de elementos:

1. Puntos de demanda, que representan consumidores o lugares que necesitan recibir producto.
2. Fábricas, que representan lugares de producción o abastecimiento.

El objetivo es evaluar muchas configuraciones posibles de fábricas y determinar cuáles producen el menor costo total de operación.

El método elegido no es un solver exacto ni una optimización matemática cerrada, sino una simulación de Monte Carlo. Esto significa que se generan muchos escenarios aleatorios, se calcula el costo de cada uno y luego se seleccionan los mejores y los peores.

La idea principal es:

```text
Generar muchos escenarios diferentes de ubicación de fábricas,
evaluarlos contra la misma red de demanda,
y escoger el escenario con menor función objetivo total.
```

---

## 2. Propósito del trabajo

El propósito del trabajo es construir una simulación que permita decidir dónde conviene ubicar fábricas para abastecer una red de demanda distribuida en un territorio.

El territorio no es geográfico real, sino geométrico. Se define por coordenadas y se limita a un paralelogramo.

El modelo busca responder preguntas como:

- ¿Dónde deberían estar ubicadas las fábricas?
- ¿Qué configuración reduce más los costos de transporte?
- ¿Qué configuraciones dejan mucho stock sobrante?
- ¿Qué escenarios no logran cubrir toda la demanda?
- ¿Cuáles son los mejores escenarios encontrados?
- ¿Cuáles son los peores escenarios encontrados?

---

## 3. Tipo de modelo

El modelo es una simulación de Monte Carlo aplicada a un problema de localización y asignación.

Es Monte Carlo porque:

- Se generan escenarios aleatorios.
- Las ubicaciones de fábricas cambian aleatoriamente.
- La oferta total de cada escenario cambia aleatoriamente.
- La distribución de oferta entre fábricas también es aleatoria.
- Se comparan miles de resultados posibles.

Es un problema de localización porque busca posiciones óptimas para las fábricas.

Es un problema de asignación porque cada punto de demanda debe recibir producto desde una o varias fábricas.

También tiene elementos de problema de transporte porque el costo depende de cantidad transportada por distancia.

---

## 4. Región geográfica: paralelogramo

La región espacial del problema es un paralelogramo estricto.

Un paralelogramo estricto significa que:

- Tiene cuatro vértices.
- Los lados opuestos son paralelos.
- Los lados opuestos tienen la misma longitud.
- No debe ser una figura degenerada sin área.

El usuario debe ingresar cuatro coordenadas:

```text
P1 = (x1, y1)
P2 = (x2, y2)
P3 = (x3, y3)
P4 = (x4, y4)
```

La validación principal indicada en el documento es verificar que el punto medio de la diagonal `P1-P3` sea igual al punto medio de la diagonal `P2-P4`.

Matemáticamente:

```text
(P1 + P3) / 2 = (P2 + P4) / 2
```

Si eso se cumple, los puntos forman un paralelogramo.

Además, aunque el documento no lo enfatiza como validación separada, conviene verificar que el área no sea cero, porque cuatro puntos colineales podrían cumplir propiedades raras pero no formar una región útil.

---

## 5. Generación de puntos dentro del paralelogramo

El documento explica que un punto aleatorio dentro del paralelogramo puede generarse usando un punto base y dos vectores.

Se toma:

```text
u = P2 - P1
v = P4 - P1
```

Luego se generan dos valores aleatorios uniformes:

```text
s ∈ [0, 1]
t ∈ [0, 1]
```

Y el punto se calcula como:

```text
P = P1 + s*u + t*v
```

Esto garantiza que el punto generado queda dentro del paralelogramo.

Esta fórmula debe usarse tanto para generar puntos de demanda como para generar fábricas.

---

## 6. Puntos de demanda

Los puntos de demanda representan consumidores o destinos que necesitan recibir producto.

Características principales:

- Se generan una sola vez al inicio de la simulación.
- Permanecen fijos durante todos los escenarios.
- Se ubican aleatoriamente dentro del paralelogramo.
- Su cantidad es definida por el usuario.
- Todos tienen la misma demanda individual.

Si la demanda total es `D` y el número de puntos de demanda es `M`, entonces cada punto demanda:

```text
demanda_por_punto = D / M
```

Esto significa que la demanda está distribuida equitativamente.

La decisión de mantener los puntos de demanda fijos es muy importante porque permite comparar escenarios de manera justa.

Si los puntos de demanda cambiaran en cada escenario, no sabríamos si un escenario es mejor por la ubicación de sus fábricas o porque tuvo una demanda más favorable.

---

## 7. Fábricas o lugares de producción

Las fábricas son el elemento variable del modelo.

Características principales:

- La cantidad de fábricas la define el usuario.
- Esa cantidad se mantiene igual en todos los escenarios.
- La ubicación de las fábricas cambia aleatoriamente en cada escenario.
- Cada fábrica tiene una cantidad de oferta o stock disponible.
- La oferta total del escenario también es aleatoria.

El documento establece que la oferta total del escenario está en el rango:

```text
[demanda_total * 0.85, demanda_total * 1.15]
```

Esto significa que un escenario puede tener:

- 15% menos oferta que la demanda total.
- Exactamente oferta cercana a la demanda total.
- Hasta 15% más oferta que la demanda total.

Por ejemplo, si la demanda total es 1000:

```text
Oferta mínima = 850
Oferta máxima = 1150
```

Luego esa oferta se distribuye aleatoriamente entre las fábricas.

La distribución se hace generando números aleatorios positivos, normalizándolos para que sumen 1 y multiplicándolos por la oferta total.

Ejemplo conceptual:

```text
Oferta total = 1000
Pesos aleatorios normalizados = [0.20, 0.35, 0.45]
Stocks de fábricas = [200, 350, 450]
```

---

## 8. Distancia utilizada

La distancia usada es la distancia euclidiana simple.

Para dos puntos `A` y `B`:

```text
A = (xA, yA)
B = (xB, yB)
```

La distancia es:

```text
distancia(A, B) = sqrt((xB - xA)^2 + (yB - yA)^2)
```

No se usa distancia geográfica real, carreteras, rutas, tráfico ni tiempos de viaje.

El modelo trabaja en un espacio plano de coordenadas.

---

## 9. Orden de atención de los puntos de demanda

El orden de atención de los puntos de demanda es una de las partes más importantes del documento.

Para cada escenario:

1. Se calcula la distancia de cada punto de demanda a cada fábrica.
2. Para cada punto de demanda se identifica la fábrica más cercana.
3. Se toma la distancia a esa fábrica más cercana.
4. Los puntos de demanda se ordenan de menor a mayor según esa distancia mínima.

Esto significa que se atienden primero los puntos que tienen alguna fábrica más cerca.

Ejemplo:

```text
Punto D1: fábrica más cercana a distancia 3.2
Punto D2: fábrica más cercana a distancia 1.5
Punto D3: fábrica más cercana a distancia 5.0
```

Orden de atención:

```text
D2 → D1 → D3
```

Este orden es crítico porque el stock de las fábricas se va agotando.

Un punto atendido primero puede consumir stock que luego ya no estará disponible para otro punto.

---

## 10. Asignación en cascada con abastecimiento parcial

Para cada punto de demanda, se aplica una asignación en cascada.

El proceso es:

1. Se ordenan todas las fábricas por distancia al punto de demanda actual.
2. Se intenta cubrir la demanda desde la fábrica más cercana.
3. Si esa fábrica tiene stock suficiente, cubre toda la demanda del punto.
4. Si tiene stock, pero no suficiente, entrega todo lo que tiene y queda en cero.
5. Si no tiene stock, se pasa a la siguiente fábrica.
6. El proceso continúa hasta cubrir la demanda o hasta que no queden fábricas con stock.
7. Si queda demanda sin cubrir, se aplica penalización.

Lo más importante es que un mismo punto de demanda puede recibir producto de varias fábricas.

Ejemplo:

```text
Demanda del punto = 100

Fábrica A entrega 40
Fábrica B entrega 35
Fábrica C entrega 25

Total entregado = 100
```

Esto es abastecimiento parcial desde múltiples fuentes.

---

## 11. Casos posibles durante la asignación

El documento define tres casos:

### Caso A: stock suficiente

La fábrica puede cubrir toda la demanda restante del punto.

```text
stock_fábrica >= demanda_restante
```

Entonces:

```text
entrega = demanda_restante
stock_fábrica -= entrega
demanda_restante = 0
```

El punto queda completamente atendido.

### Caso B: stock parcial

La fábrica tiene stock, pero no alcanza para cubrir todo.

```text
0 < stock_fábrica < demanda_restante
```

Entonces:

```text
entrega = stock_fábrica
demanda_restante -= entrega
stock_fábrica = 0
```

Luego se pasa a la siguiente fábrica.

### Caso C: sin stock

La fábrica no tiene producto disponible.

```text
stock_fábrica = 0
```

Entonces no entrega nada y se pasa a la siguiente fábrica.

---

## 12. FO1: costo de transporte

FO1 mide el costo total de transportar producto desde fábricas hasta puntos de demanda.

La regla básica es:

```text
costo = cantidad_entregada * distancia
```

Si un punto recibe producto desde una sola fábrica:

```text
FO1_punto = cantidad_entregada * distancia_a_fábrica
```

Si recibe producto desde varias fábricas:

```text
FO1_punto = suma(cantidad_entregada_por_fábrica_i * distancia_a_fábrica_i)
```

Ejemplo:

```text
Demanda del punto = 100
Fábrica A entrega 60 a distancia 2
Fábrica B entrega 40 a distancia 5

FO1_punto = 60*2 + 40*5
FO1_punto = 120 + 200
FO1_punto = 320
```

FO1 total es la suma de todos los costos de transporte de todos los puntos, más las penalizaciones por demanda no cubierta.

---

## 13. Penalización por demanda no cubierta

Si después de revisar todas las fábricas todavía queda demanda sin cubrir, se penaliza.

La penalización es:

```text
penalización = demanda_no_cubierta * distancia_a_la_fábrica_más_lejana
```

La fábrica más lejana se calcula respecto al punto de demanda que quedó sin cubrir.

Esto representa un peor caso posible de transporte.

La penalización busca castigar escenarios donde:

- La oferta total no alcanza.
- El stock se distribuyó mal.
- Las fábricas quedaron mal ubicadas.
- Algunos puntos quedaron parcialmente o totalmente desatendidos.

---

## 14. FO2: costo de sobrante en fábricas

FO2 penaliza el producto que queda sin distribuirse al final del escenario.

Para cada fábrica:

```text
FO2_fábrica = stock_sobrante * distancia_media_a_todos_los_puntos_de_demanda
```

La distancia media se calcula contra todos los puntos de demanda, no solo contra los puntos que esa fábrica atendió.

Esto es una aclaración importante del documento.

Ejemplo:

```text
Fábrica A:
stock sobrante = 50
distancia media a demanda = 2
FO2 = 100

Fábrica B:
stock sobrante = 50
distancia media a demanda = 8
FO2 = 400
```

Aunque ambas fábricas tienen el mismo sobrante, la fábrica B recibe mayor penalización porque está más lejos de la demanda.

FO2 total es:

```text
FO2_total = suma de FO2 de todas las fábricas
```

---

## 15. Función objetivo total

La función objetivo total combina FO1 y FO2:

```text
FO_TOTAL = FO1_total + FO2_total
```

El mejor escenario es el que tiene menor FO_TOTAL.

El peor escenario es el que tiene mayor FO_TOTAL.

El documento pide reportar:

- N mejores escenarios.
- N peores escenarios.

El valor de N lo define el usuario.

---

## 16. Qué incentiva el modelo

El modelo premia escenarios donde:

- Las fábricas están cerca de los puntos de demanda.
- La oferta alcanza para cubrir la demanda.
- El stock está bien distribuido entre fábricas.
- Hay poco sobrante.
- El sobrante, si existe, queda en fábricas cercanas a la demanda.
- Hay poca o ninguna demanda no cubierta.

El modelo castiga escenarios donde:

- Las fábricas están lejos de la demanda.
- La oferta es insuficiente.
- El stock se concentra en fábricas lejanas.
- Hay mucho sobrante.
- Hay demanda sin atender.
- Las fábricas con sobrante están lejos de la mayoría de puntos de demanda.

---

## 17. Parámetros configurables por el usuario

El documento indica que el usuario debe poder configurar:

### 17.1 Vértices del paralelogramo

Cuatro coordenadas que definen la región.

Ejemplo:

```text
[(0, 0), (10, 0), (14, 6), (4, 6)]
```

### 17.2 Número de puntos de demanda

Cantidad de consumidores que se generarán.

Debe ser entero positivo.

### 17.3 Número de fábricas

Cantidad de fábricas por escenario.

Debe ser entero positivo.

### 17.4 Demanda total

Volumen total de producto a distribuir.

Debe ser número real positivo.

### 17.5 Número de escenarios

Cantidad de configuraciones aleatorias a generar.

El documento recomienda usar miles de escenarios.

### 17.6 N mejores y N peores

Cantidad de mejores y peores escenarios que se deben mostrar.

Debe ser entero positivo y no debería superar el número total de escenarios.

---

## 18. Flujo general del algoritmo

El algoritmo completo se entiende así:

```text
1. Leer parámetros del usuario.
2. Validar que los cuatro vértices formen un paralelogramo válido.
3. Generar puntos de demanda aleatorios dentro del paralelogramo.
4. Mantener esos puntos fijos para toda la simulación.
5. Para cada escenario:
   a. Generar ubicaciones aleatorias de fábricas.
   b. Generar oferta total aleatoria entre 85% y 115% de la demanda total.
   c. Distribuir aleatoriamente la oferta entre fábricas.
   d. Calcular distancias entre demandas y fábricas.
   e. Ordenar puntos de demanda según distancia a fábrica más cercana.
   f. Asignar producto en cascada.
   g. Calcular FO1.
   h. Calcular FO2.
   i. Calcular FO_TOTAL.
   j. Guardar resultados del escenario.
6. Ordenar todos los escenarios por FO_TOTAL.
7. Mostrar tabla general.
8. Mostrar N mejores escenarios.
9. Mostrar N peores escenarios.
10. Graficar mejores y peores escenarios.
11. Identificar el escenario óptimo global encontrado.
12. Mostrar coordenadas exactas de fábricas del mejor escenario.
```

---

## 19. Pseudocódigo fiel al documento

```text
Leer vértices del paralelogramo
Leer número de puntos de demanda
Leer número de fábricas
Leer demanda total
Leer número de escenarios
Leer N mejores/peores

Validar paralelogramo

Generar puntos_demanda dentro del paralelogramo

demanda_individual = demanda_total / número_puntos_demanda

resultados = []

Para cada escenario desde 1 hasta número_escenarios:

    Generar fábricas dentro del paralelogramo

    oferta_total = aleatorio_uniforme(demanda_total*0.85, demanda_total*1.15)

    pesos = números aleatorios positivos
    pesos = pesos / suma(pesos)
    stock_inicial = pesos * oferta_total
    stock_actual = copia(stock_inicial)

    matriz_distancias = distancia entre cada punto de demanda y cada fábrica

    distancia_minima_por_punto = mínimo de cada fila de matriz_distancias
    orden_puntos = ordenar puntos por distancia_minima_por_punto ascendente

    FO1 = 0

    Para cada punto en orden_puntos:

        demanda_restante = demanda_individual

        fábricas_ordenadas = ordenar fábricas por distancia al punto

        Para cada fábrica en fábricas_ordenadas:

            Si demanda_restante <= 0:
                terminar con este punto

            Si stock_actual[fábrica] > 0:

                entrega = mínimo(stock_actual[fábrica], demanda_restante)

                FO1 += entrega * distancia(punto, fábrica)

                stock_actual[fábrica] -= entrega
                demanda_restante -= entrega

        Si demanda_restante > 0:
            distancia_más_lejana = máximo de distancias del punto a todas las fábricas
            FO1 += demanda_restante * distancia_más_lejana

    FO2 = 0

    Para cada fábrica:
        sobrante = stock_actual[fábrica]
        distancia_media = promedio de distancia desde esa fábrica a todos los puntos de demanda
        FO2 += sobrante * distancia_media

    FO_TOTAL = FO1 + FO2

    Guardar escenario, fábricas, stock inicial, stock final, FO1, FO2, FO_TOTAL

Ordenar resultados por FO_TOTAL ascendente

Mostrar tabla general
Mostrar N mejores
Mostrar N peores
Graficar N mejores y N peores
Mostrar mejor escenario y coordenadas de fábricas
```

---

## 20. Salidas esperadas del notebook

El documento exige varias salidas.

### 20.1 Tabla resumen general

Debe contener todos los escenarios evaluados, ordenados por FO_TOTAL de menor a mayor.

Columnas mínimas:

```text
Escenario | FO1 | FO2 | FO_TOTAL
```

También sería recomendable incluir:

```text
Oferta total | Demanda no cubierta | Stock sobrante total
```

Aunque esas columnas extra no son obligatorias, ayudan a interpretar los resultados.

### 20.2 Tabla de N mejores escenarios

Debe mostrar los escenarios con menor FO_TOTAL.

Columnas mínimas:

```text
Escenario | FO1 | FO2 | FO_TOTAL
```

### 20.3 Tabla de N peores escenarios

Debe mostrar los escenarios con mayor FO_TOTAL.

Columnas mínimas:

```text
Escenario | FO1 | FO2 | FO_TOTAL
```

### 20.4 Gráficas individuales

Para cada uno de los N mejores y N peores escenarios se debe graficar:

- Contorno del paralelogramo.
- Puntos de demanda.
- Fábricas.
- FO_TOTAL en el título.

### 20.5 Escenario óptimo global

Debe identificarse el escenario con menor FO_TOTAL.

Además, se deben mostrar las coordenadas exactas de sus fábricas.

Ejemplo:

```text
Escenario óptimo encontrado: 1287
FO1 = 3450.23
FO2 = 182.90
FO_TOTAL = 3633.13

Coordenadas de fábricas:
F1 = (2.34, 5.67)
F2 = (8.91, 1.25)
F3 = (4.18, 7.40)
```

---

## 21. Información que conviene guardar por escenario

Aunque el documento exige algunas salidas mínimas, una buena implementación debería guardar más información para análisis y depuración.

Por escenario conviene guardar:

- Número de escenario.
- Coordenadas de fábricas.
- Stock inicial de cada fábrica.
- Stock final de cada fábrica.
- Oferta total del escenario.
- FO1.
- FO2.
- FO_TOTAL.
- Demanda no cubierta total.
- Stock sobrante total.
- Asignaciones realizadas.
- Distancias usadas.

Esto permite explicar por qué un escenario fue bueno o malo.

---

## 22. Estructuras de datos recomendadas

Una implementación eficiente en Python debería usar NumPy.

Puntos de demanda:

```python
puntos_demanda = np.array([
    [x1, y1],
    [x2, y2],
    ...
])
```

Fábricas:

```python
fabricas = np.array([
    [x1, y1],
    [x2, y2],
    ...
])
```

Stocks:

```python
stock_inicial = np.array([...])
stock_actual = stock_inicial.copy()
```

Resultados:

```python
resultado = {
    "escenario": i,
    "fabricas": fabricas,
    "stock_inicial": stock_inicial,
    "stock_final": stock_actual,
    "fo1": fo1,
    "fo2": fo2,
    "fo_total": fo_total,
}
```

Lista de resultados:

```python
resultados.append(resultado)
```

Tabla final:

```python
df_resultados = pd.DataFrame(...)
```

---

## 23. Interpretación académica del modelo

El proyecto mezcla varios conceptos de Investigación de Operaciones:

- Localización de instalaciones.
- Asignación de demanda.
- Transporte con costo proporcional a distancia.
- Capacidad limitada mediante stock disponible.
- Penalización por faltantes.
- Penalización por sobrantes.
- Simulación Monte Carlo.
- Evaluación de escenarios.

No es un problema clásico puro de transporte porque las ubicaciones de las fábricas son variables.

No es un problema clásico puro de p-mediana porque existe stock limitado, oferta aleatoria, sobrantes y faltantes.

No es un problema de optimización exacta porque no se garantiza encontrar el óptimo matemático absoluto.

Es más correcto describirlo como:

```text
Modelo heurístico de localización-asignación con simulación Monte Carlo y función objetivo compuesta.
```

---

## 24. Sobre el concepto de escenario óptimo global

El documento habla de escenario óptimo global.

Técnicamente, dentro de una simulación Monte Carlo, el mejor escenario encontrado es el mejor dentro de los escenarios evaluados.

No necesariamente es el óptimo global matemático de todo el espacio continuo posible.

Una forma precisa de escribirlo sería:

```text
Escenario óptimo global encontrado dentro de la simulación.
```

Esto evita prometer que se encontró la mejor solución absoluta posible.

---

## 25. Implicación importante de la oferta aleatoria

La oferta total cambia aleatoriamente entre escenarios.

Esto significa que el modelo no compara únicamente ubicaciones de fábricas.

También compara:

- Diferentes niveles de oferta total.
- Diferentes distribuciones de stock entre fábricas.

Un escenario puede tener buenas ubicaciones pero mala oferta.

Ejemplo:

```text
Demanda total = 1000
Oferta del escenario = 850
```

En ese caso, aunque las fábricas estén perfectamente ubicadas, por lo menos 150 unidades quedarán sin cubrir.

Otro escenario puede tener ubicaciones menos buenas pero una oferta de 1150 y cubrir toda la demanda.

Esto no contradice el documento, pero es una implicación importante.

El resultado final evalúa una combinación de:

```text
ubicación + oferta total + distribución de oferta
```

No evalúa ubicación pura de manera aislada.

---

## 26. Implicación del reparto aleatorio de oferta

La oferta total se distribuye aleatoriamente entre fábricas.

Esto puede afectar mucho los resultados.

Ejemplo:

- Fábrica cercana a mucha demanda recibe poco stock.
- Fábrica lejana recibe mucho stock.
- La fábrica cercana se agota rápido.
- Luego se debe abastecer desde lejos.
- FO1 sube.
- Puede quedar sobrante en fábrica lejana.
- FO2 también sube.

Por eso una configuración espacial buena puede salir mal si el stock se reparte mal.

---

## 27. Punto crítico: la asignación greedy depende del orden

El algoritmo de asignación no busca la combinación global óptima de envíos.

Atiende los puntos uno por uno en un orden definido.

Esto significa que el resultado depende de:

1. El orden de atención de los puntos.
2. El stock disponible en ese momento.
3. La cercanía relativa de fábricas a cada punto.

Un punto atendido temprano puede consumir el stock de una fábrica que habría sido útil para otro punto posterior.

Por lo tanto, la asignación es una heurística greedy.

Esto está bien porque el documento lo define así, pero es importante entenderlo.

---

## 28. Validaciones necesarias

La implementación debería validar:

- Que existan exactamente cuatro vértices.
- Que cada vértice tenga dos coordenadas numéricas.
- Que los vértices formen un paralelogramo.
- Que el paralelogramo tenga área mayor que cero.
- Que el número de puntos de demanda sea entero positivo.
- Que el número de fábricas sea entero positivo.
- Que la demanda total sea positiva.
- Que el número de escenarios sea entero positivo.
- Que N mejores/peores sea entero positivo.
- Que N no sea mayor al número de escenarios.

También conviene validar que los vértices estén en un orden compatible con la fórmula de generación:

```text
P1, P2, P3, P4
```

Donde `P2` y `P4` deben ser los vértices adyacentes a `P1`, y `P3` el opuesto.

---

## 29. Posibles empates

El documento no define qué hacer si:

- Dos fábricas están a la misma distancia de un punto.
- Dos puntos de demanda tienen la misma distancia mínima.
- Dos escenarios tienen exactamente el mismo FO_TOTAL.

En la práctica, NumPy o Python resolverán los empates según el orden original.

Esto es aceptable si se documenta o si se usa un criterio estable.

---

## 30. Reproducibilidad

El documento no menciona semilla aleatoria.

Pero para un notebook académico conviene incluir un parámetro opcional:

```python
semilla = 42
np.random.seed(semilla)
```

O usando el generador moderno:

```python
rng = np.random.default_rng(42)
```

Esto permite que los resultados sean reproducibles.

Si no se usa semilla, cada ejecución generará resultados distintos.

---

## 31. Rendimiento

El documento indica que el rendimiento es clave.

Con miles de escenarios y cientos de puntos, los bucles Python pueden volverse lentos.

Se recomienda usar NumPy para:

- Generar puntos.
- Calcular matrices de distancia.
- Ordenar distancias.
- Calcular distancias medias.

Sin embargo, la asignación en cascada probablemente seguirá necesitando algunos bucles porque el stock cambia dinámicamente después de cada entrega.

Lo ideal es vectorizar lo más posible y dejar bucles solo donde la lógica secuencial lo exige.

---

## 32. Gráficas esperadas

Las gráficas deben mostrar visualmente cómo se distribuyen demanda y fábricas.

Elementos obligatorios:

- Contorno del paralelogramo.
- Puntos de demanda en un color.
- Fábricas en otro color.
- Título con FO_TOTAL.

Elementos recomendables:

- Etiquetas de fábricas: F1, F2, F3, etc.
- Leyenda.
- Ejes con escala igual (`axis equal`).
- Título indicando si es mejor o peor escenario.
- Coordenadas visibles o tabla aparte.

No recomiendo dibujar todas las líneas de abastecimiento si hay muchos puntos, porque la gráfica puede quedar saturada.

---

## 33. Cómo debería explicarse un escenario bueno

Un escenario bueno probablemente tendrá:

- FO1 bajo.
- FO2 bajo.
- Poca demanda no cubierta.
- Poco stock sobrante.
- Fábricas bien distribuidas cerca de zonas de demanda.
- Oferta bien repartida.

En texto, se podría interpretar así:

```text
Este escenario es eficiente porque las fábricas están distribuidas cerca de los puntos de demanda, el costo de transporte es bajo y el stock sobrante final es reducido.
```

---

## 34. Cómo debería explicarse un escenario malo

Un escenario malo probablemente tendrá:

- FO1 alto.
- FO2 alto.
- Mucha demanda no cubierta.
- Mucho stock sobrante lejos de la demanda.
- Fábricas agrupadas en una zona poco útil.
- Mala distribución de stock.

En texto, se podría interpretar así:

```text
Este escenario es deficiente porque las fábricas quedaron alejadas de buena parte de la demanda y/o el stock quedó concentrado en ubicaciones poco convenientes, aumentando el costo de transporte y el sobrante penalizado.
```

---

## 35. Qué debe tener una implementación completa en Colab

Una implementación completa debería contener:

1. Importación de librerías.
2. Parámetros configurables.
3. Función para validar paralelogramo.
4. Función para generar puntos dentro del paralelogramo.
5. Función para calcular distancias.
6. Función para simular un escenario.
7. Función para calcular FO1 y FO2.
8. Bucle principal de escenarios.
9. DataFrame de resultados.
10. Tablas de mejores y peores.
11. Función de graficado.
12. Gráficas de mejores y peores.
13. Impresión del escenario óptimo y coordenadas.
14. Comentarios explicativos.

---

## 36. Librerías esperadas

El notebook probablemente debe usar:

```python
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
```

Opcionalmente:

```python
from dataclasses import dataclass
```

Pero para Colab y entrega académica, NumPy, Pandas y Matplotlib bastan.

---

## 37. Posibles columnas extras útiles

Además de FO1, FO2 y FO_TOTAL, sería útil incluir:

```text
Escenario
Oferta total
Stock inicial total
Stock sobrante total
Demanda no cubierta total
FO1
FO2
FO_TOTAL
```

Esto permitiría entender si un escenario fue malo por falta de oferta, por sobrante o por transporte largo.

---

## 38. Criterio de ordenamiento

La tabla general debe ordenarse así:

```text
FO_TOTAL ascendente
```

Los mejores son:

```text
primeros N registros
```

Los peores son:

```text
últimos N registros
```

Para mostrar peores, conviene ordenarlos de mayor a menor FO_TOTAL.

---

## 39. Qué significa que la investigación esté completa

El documento indica que la fase de investigación, modelado y diseño está completa.

Eso significa que ya están definidos:

- El problema.
- Los supuestos.
- La región.
- Las variables.
- La lógica de asignación.
- Las funciones objetivo.
- Los parámetros.
- Las salidas.
- Las consideraciones técnicas.

La tarea pendiente es la implementación computacional en Python/Google Colab.

---

## 40. Riesgos de implementación incorrecta

Los errores más probables serían:

1. Regenerar puntos de demanda en cada escenario.
2. No permitir abastecimiento parcial desde varias fábricas.
3. Calcular FO1 solo con la fábrica más cercana, ignorando entregas parciales.
4. No penalizar demanda no cubierta.
5. Penalizar demanda no cubierta con una distancia incorrecta.
6. Calcular FO2 usando solo puntos atendidos por cada fábrica.
7. No actualizar stock después de cada entrega.
8. Comparar escenarios sin ordenar por FO_TOTAL.
9. No guardar coordenadas de fábricas del mejor escenario.
10. Graficar sin respetar el paralelogramo.

---

## 41. Interpretación final resumida

El documento define un modelo para evaluar ubicaciones de fábricas dentro de un paralelogramo.

Se generan puntos de demanda fijos y múltiples escenarios con fábricas aleatorias.

Cada escenario tiene oferta total aleatoria entre 85% y 115% de la demanda total, distribuida aleatoriamente entre fábricas.

La demanda se atiende en orden de cercanía a la fábrica más próxima.

Cada punto puede recibir producto de varias fábricas mediante asignación en cascada.

El costo total combina:

```text
FO1 = transporte + penalización por demanda no cubierta
FO2 = penalización por stock sobrante
FO_TOTAL = FO1 + FO2
```

El mejor escenario es el de menor FO_TOTAL.

El peor escenario es el de mayor FO_TOTAL.

El notebook debe mostrar tablas y gráficas para analizar los resultados.

---

## 42. Conclusión

El documento está suficientemente claro para implementar el modelo completo en Python.

La parte más crítica es respetar la lógica de asignación en cascada y calcular correctamente FO1 y FO2.

El proyecto no busca una solución matemática exacta garantizada, sino encontrar la mejor configuración dentro de un conjunto grande de escenarios simulados.

La entrega final debería ser un notebook de Google Colab con parámetros editables, resultados tabulares y gráficas de los mejores y peores escenarios.

---

## 43. Ajustes finales decididos antes de la implementación

Después de revisar las dudas técnicas, se definieron tres ajustes para la implementación final:

### 43.1 Semilla aleatoria configurable

La semilla no se elimina. Se deja configurable.

Por defecto se usa:

```python
SEMILLA = 42
```

Esto permite reproducir exactamente los mismos escenarios, tablas y gráficas durante la sustentación o revisión del docente.

Si se quieren resultados distintos en cada ejecución, se puede usar:

```python
SEMILLA = None
```

La decisión final es mantener la semilla como parámetro editable, no como valor oculto ni como obligación fija.

### 43.2 Mejor escenario encontrado, no óptimo matemático absoluto

El notebook debe evitar afirmar que encontró el óptimo matemático absoluto del espacio continuo.

La forma correcta de reportarlo es:

```text
Mejor escenario encontrado dentro de los escenarios simulados.
```

O también:

```text
Escenario con menor FO_TOTAL encontrado por la simulación Monte Carlo.
```

Esto reconoce que Monte Carlo compara los escenarios generados, pero no garantiza haber explorado todas las posibles ubicaciones continuas de fábricas.

### 43.3 Mayor valor de la función objetivo

Se agrega explícitamente el requisito faltante del enunciado original:

```text
Determinar cuál es el mayor valor de la función objetivo.
```

En la implementación se interpreta como el mayor valor de `FO_TOTAL` entre todos los escenarios evaluados.

Por eso el notebook debe mostrar una salida independiente con:

- Escenario con mayor `FO_TOTAL`.
- FO1 de ese escenario.
- FO2 de ese escenario.
- FO_TOTAL máximo.
- Mayor FO individual dentro de ese escenario.

Esto complementa la tabla de N peores escenarios y deja el requisito respondido de forma explícita.
