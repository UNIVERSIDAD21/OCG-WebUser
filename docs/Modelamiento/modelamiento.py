# ============================================================
# OPTIMIZACIÓN DE UBICACIÓN DE LUGARES DE PRODUCCIÓN
# Simulación Monte Carlo con entrada interactiva en Google Colab
#
# Integrantes:
# - Erik Sebastian Fuentes Nuñez
# - Evelyn Raquel Garcia Rincon
#
# MEJORA DE ESTA VERSIÓN:
# 1. Permite digitar los parámetros del documento desde una interfaz bonita.
# 2. Mantiene una opción automática por si se ejecuta fuera de Colab.
# 3. Explica cada gráfica: por qué un escenario fue bueno o malo.
# 4. Agrega una gráfica independiente del mejor escenario encontrado.
# 5. Conserva validaciones, comentarios y estructura profesional.
# 6. Permite semilla aleatoria configurable para reproducibilidad.
# 7. Reporta explícitamente el mayor valor de FO_TOTAL entre escenarios.
# ============================================================

# =========================
# 1. IMPORTACIÓN DE LIBRERÍAS
# =========================

import ast
import time
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from typing import Dict, List, Tuple, Any
from IPython.display import display, HTML, clear_output

# ipywidgets permite crear formularios visuales en Google Colab/Jupyter.
try:
    import ipywidgets as widgets
    from ipywidgets import Layout
    WIDGETS_DISPONIBLES = True
except Exception:
    WIDGETS_DISPONIBLES = False


# =========================
# 2. PARÁMETROS POR DEFECTO
# =========================
# Estos valores sirven como ejemplo y también como respaldo si no se usa
# el formulario interactivo.

PARAMETROS_DEFAULT = {
    "vertices": [[0, 0], [10, 2], [12, 8], [2, 6]],
    "num_puntos_demanda": 100,
    "num_fabricas": 5,
    "demanda_total": 10000.0,
    "num_escenarios": 1000,
    "n_mejores_peores": 3,
    # Use un número entero para resultados reproducibles.
    # Cambia a None si quieres que cada ejecución genere escenarios diferentes.
    "semilla": 42,
    "mostrar_progreso": True
}


# =========================
# 3. FUNCIONES DE VALIDACIÓN
# =========================

def producto_cruzado_2d(a: np.ndarray, b: np.ndarray) -> float:
    """
    Calcula el producto cruzado en 2D entre dos vectores.

    Se usa para calcular el área del paralelogramo.
    Si el valor absoluto es cero o casi cero, los lados son collineales
    y el paralelogramo no tiene área real.
    """
    return float(a[0] * b[1] - a[1] * b[0])


def ordenar_y_validar_vertices_paralelogramo(
    vertices: List[List[float]],
    tolerancia: float = 1e-9
) -> np.ndarray:
    """
    Valida que cuatro puntos formen un paralelogramo estricto y los ordena.

    El usuario puede digitar los puntos en cualquier orden. La función busca
    qué pares de puntos pueden ser diagonales. En un paralelogramo, las dos
    diagonales tienen el mismo punto medio.

    Retorna los vértices ordenados como:
        [P1, P2, P3, P4]

    De este modo:
        - P1 y P3 son opuestos.
        - P2 y P4 son opuestos.
        - P1, P2 y P4 sirven para generar puntos internos con:
              P = P1 + s*(P2-P1) + t*(P4-P1)
    """
    V = np.asarray(vertices, dtype=float)

    if V.shape != (4, 2):
        raise ValueError("Debes ingresar exactamente 4 vértices, cada uno con coordenadas [x, y].")

    if not np.all(np.isfinite(V)):
        raise ValueError("Todos los valores de los vértices deben ser numéricos y finitos.")

    posibles_diagonales = [
        ((0, 1), (2, 3)),
        ((0, 2), (1, 3)),
        ((0, 3), (1, 2)),
    ]

    for (i, k), (j, l) in posibles_diagonales:
        punto_medio_1 = (V[i] + V[k]) / 2.0
        punto_medio_2 = (V[j] + V[l]) / 2.0

        if np.allclose(punto_medio_1, punto_medio_2, atol=tolerancia, rtol=0):
            P1, P3 = V[i], V[k]
            P2, P4 = V[j], V[l]
            area = abs(producto_cruzado_2d(P2 - P1, P4 - P1))

            if area <= tolerancia:
                raise ValueError(
                    "Los puntos cumplen la condición de diagonales, pero el área es cero. "
                    "El paralelogramo debe ser estricto, no degenerado."
                )

            return np.array([P1, P2, P3, P4], dtype=float)

    raise ValueError(
        "Los cuatro puntos no forman un paralelogramo válido. "
        "Recuerda que las diagonales deben tener el mismo punto medio."
    )


def validar_parametros_simulacion(
    num_puntos_demanda: int,
    num_fabricas: int,
    demanda_total: float,
    num_escenarios: int,
    n_mejores_peores: int
) -> None:
    """
    Valida que los parámetros principales sean correctos antes de simular.
    """
    if not isinstance(num_puntos_demanda, int) or num_puntos_demanda <= 0:
        raise ValueError("El número de puntos de demanda debe ser un entero positivo.")

    if not isinstance(num_fabricas, int) or num_fabricas <= 0:
        raise ValueError("El número de fábricas debe ser un entero positivo.")

    if demanda_total <= 0:
        raise ValueError("La demanda total debe ser un número positivo.")

    if not isinstance(num_escenarios, int) or num_escenarios <= 0:
        raise ValueError("El número de escenarios debe ser un entero positivo.")

    if not isinstance(n_mejores_peores, int) or n_mejores_peores <= 0:
        raise ValueError("N mejores/peores debe ser un entero positivo.")

    if n_mejores_peores > num_escenarios:
        raise ValueError("N mejores/peores no puede ser mayor que el número de escenarios.")


def parsear_vertices(texto_vertices: str) -> List[List[float]]:
    """
    Convierte el texto digitado por el usuario en una lista de vértices.

    Formato esperado:
        [[0,0], [10,2], [12,8], [2,6]]

    Se usa ast.literal_eval porque es más seguro que eval().
    """
    try:
        vertices = ast.literal_eval(texto_vertices)
    except Exception as exc:
        raise ValueError(
            "No pude interpretar los vértices. Usa el formato: [[0,0], [10,2], [12,8], [2,6]]"
        ) from exc

    # La validación geométrica final se hace en ordenar_y_validar_vertices_paralelogramo.
    ordenar_y_validar_vertices_paralelogramo(vertices)
    return vertices


def parsear_semilla(valor: Any) -> int | None:
    """
    Convierte la semilla ingresada por el usuario.

    - Un entero, por ejemplo 42, hace que la simulación sea reproducible.
    - None, vacío, "none", "aleatoria" o "random" genera resultados nuevos en cada ejecución.
    """
    if valor is None:
        return None

    if isinstance(valor, str):
        texto = valor.strip().lower()
        if texto in {"", "none", "null", "aleatoria", "aleatorio", "random", "sin semilla"}:
            return None
        try:
            return int(texto)
        except ValueError as exc:
            raise ValueError(
                "La semilla debe ser un número entero o None. Ejemplos válidos: 42, 2025, None."
            ) from exc

    try:
        return int(valor)
    except Exception as exc:
        raise ValueError("La semilla debe ser un número entero o None.") from exc


# =========================
# 4. FUNCIONES GEOMÉTRICAS Y ALEATORIAS
# =========================

def generar_puntos_en_paralelogramo(
    vertices_ordenados: np.ndarray,
    cantidad: int,
    rng: np.random.Generator
) -> np.ndarray:
    """
    Genera puntos aleatorios uniformes dentro del paralelogramo.

    Fórmula:
        P = P1 + s*u + t*v

    Donde:
        u = P2 - P1
        v = P4 - P1
        s,t ~ Uniforme(0,1)
    """
    P1, P2, _, P4 = vertices_ordenados
    u = P2 - P1
    v = P4 - P1

    s = rng.random(cantidad)
    t = rng.random(cantidad)

    return P1 + np.outer(s, u) + np.outer(t, v)


def calcular_matriz_distancias(puntos_a: np.ndarray, puntos_b: np.ndarray) -> np.ndarray:
    """
    Calcula distancias euclidianas entre dos conjuntos de puntos.

    Resultado[i, j] = distancia entre puntos_a[i] y puntos_b[j].
    """
    diferencias = puntos_a[:, np.newaxis, :] - puntos_b[np.newaxis, :, :]
    return np.sqrt(np.sum(diferencias ** 2, axis=2))


def generar_oferta_fabricas(
    num_fabricas: int,
    demanda_total: float,
    rng: np.random.Generator
) -> Tuple[float, np.ndarray]:
    """
    Genera la oferta total y la reparte aleatoriamente entre fábricas.

    La oferta total está entre 85% y 115% de la demanda total.
    """
    oferta_total = rng.uniform(0.85 * demanda_total, 1.15 * demanda_total)

    pesos = rng.random(num_fabricas)
    pesos = pesos / pesos.sum()

    return oferta_total, oferta_total * pesos


# =========================
# 5. EVALUACIÓN DE UN ESCENARIO
# =========================

def evaluar_escenario(
    puntos_demanda: np.ndarray,
    fabricas: np.ndarray,
    oferta_inicial: np.ndarray,
    demanda_por_punto: float,
    tolerancia: float = 1e-9
) -> Dict[str, Any]:
    """
    Evalúa un escenario de fábricas.

    Implementa:
    - Orden de atención por cercanía mínima a alguna fábrica.
    - Asignación en cascada con abastecimiento parcial.
    - FO1: transporte + penalización por demanda no cubierta.
    - FO2: stock sobrante * distancia media a todos los puntos de demanda.

    Además de calcular FO1, FO2 y FO_TOTAL, esta versión registra
    qué hizo cada fábrica dentro del escenario y cuál fue el mayor
    costo individual observado dentro del escenario.

    Métricas por fábrica:
    - Cantidad total entregada.
    - Porcentaje de utilización.
    - Stock sobrante final.
    - Número de puntos de demanda atendidos.
    - Número de puntos donde fue proveedor principal.
    - Aporte individual al costo de transporte FO1.
    - Distancia promedio de entrega.

    Métricas de mayor FO individual:
    - Mayor aporte individual a FO1 generado por un punto de demanda.
    - Mayor aporte individual a FO2 generado por una fábrica.
    - Mayor valor individual del escenario, tomando el máximo entre ambos.
    """
    num_puntos = puntos_demanda.shape[0]
    num_fabricas = fabricas.shape[0]

    # Matriz demanda-fábrica: cada fila es un punto de demanda
    # y cada columna representa una fábrica.
    distancias = calcular_matriz_distancias(puntos_demanda, fabricas)

    # Orden de atención de los puntos de demanda.
    # Primero se atienden los puntos que tienen alguna fábrica cercana.
    distancia_minima_por_punto = distancias.min(axis=1)
    orden_puntos = np.argsort(distancia_minima_por_punto, kind="mergesort")

    # Para cada punto se ordenan las fábricas de más cercana a más lejana.
    orden_fabricas_por_punto = np.argsort(distancias, axis=1)

    # Stock que se va consumiendo durante la asignación.
    stock_restante = oferta_inicial.copy()

    # -----------------------------
    # Acumuladores generales
    # -----------------------------
    costo_transporte_real = 0.0
    costo_penalizacion_demanda_no_cubierta = 0.0
    demanda_no_cubierta_total = 0.0
    cantidad_total_transportada = 0.0
    entregas_realizadas = 0

    # Mayor aporte individual a FO1 por punto de demanda.
    # Se calcula sumando todo lo que ese punto aportó a FO1:
    # transporte real + posible penalización por demanda no cubierta.
    mayor_aporte_FO1_punto = 0.0
    punto_mayor_aporte_FO1 = None

    # -----------------------------
    # Acumuladores por fábrica
    # -----------------------------
    entregado_por_fabrica = np.zeros(num_fabricas, dtype=float)
    aporte_fo1_transporte_por_fabrica = np.zeros(num_fabricas, dtype=float)
    puntos_atendidos_por_fabrica = np.zeros(num_fabricas, dtype=int)
    puntos_como_proveedor_principal = np.zeros(num_fabricas, dtype=int)

    # ------------------------------------------------------------
    # Asignación en cascada
    # ------------------------------------------------------------
    # Esta parte es secuencial porque el stock de una fábrica cambia
    # después de atender cada punto. Por eso no se vectoriza totalmente.
    # ------------------------------------------------------------
    for idx_punto in orden_puntos:
        demanda_restante = demanda_por_punto

        # Aporte total de este punto específico a FO1.
        # Incluye transporte real y, si aplica, penalización.
        aporte_FO1_del_punto = 0.0

        # Guarda las entregas realizadas a este punto para identificar
        # qué fábrica fue su proveedor principal.
        entregas_del_punto = []

        for idx_fabrica in orden_fabricas_por_punto[idx_punto]:
            if demanda_restante <= tolerancia:
                break

            stock_disponible = stock_restante[idx_fabrica]

            if stock_disponible <= tolerancia:
                continue

            cantidad_entregada = min(stock_disponible, demanda_restante)
            distancia_entrega = distancias[idx_punto, idx_fabrica]
            costo_entrega = cantidad_entregada * distancia_entrega

            # FO1 de transporte real: cantidad enviada por distancia recorrida.
            costo_transporte_real += costo_entrega
            aporte_FO1_del_punto += costo_entrega

            # Métricas por fábrica.
            entregado_por_fabrica[idx_fabrica] += cantidad_entregada
            aporte_fo1_transporte_por_fabrica[idx_fabrica] += costo_entrega
            puntos_atendidos_por_fabrica[idx_fabrica] += 1

            # Métricas globales.
            cantidad_total_transportada += cantidad_entregada
            entregas_realizadas += 1

            # Registro de esta entrega para definir proveedor principal del punto.
            entregas_del_punto.append((idx_fabrica, cantidad_entregada))

            # Actualización de stock y demanda pendiente.
            stock_restante[idx_fabrica] -= cantidad_entregada
            demanda_restante -= cantidad_entregada

        # Proveedor principal del punto: la fábrica que más cantidad entregó
        # a ese punto específico.
        if entregas_del_punto:
            idx_principal = max(entregas_del_punto, key=lambda x: x[1])[0]
            puntos_como_proveedor_principal[idx_principal] += 1

        # Si queda demanda sin cubrir, se penaliza con la fábrica más lejana.
        if demanda_restante > tolerancia:
            distancia_fabrica_mas_lejana = distancias[idx_punto].max()
            penalizacion = demanda_restante * distancia_fabrica_mas_lejana
            costo_penalizacion_demanda_no_cubierta += penalizacion
            demanda_no_cubierta_total += demanda_restante
            aporte_FO1_del_punto += penalizacion

        # Registro del punto que más aportó individualmente a FO1.
        if aporte_FO1_del_punto > mayor_aporte_FO1_punto:
            mayor_aporte_FO1_punto = aporte_FO1_del_punto
            punto_mayor_aporte_FO1 = int(idx_punto + 1)

    # FO1 total = transporte real + penalización por demanda no cubierta.
    fo1 = costo_transporte_real + costo_penalizacion_demanda_no_cubierta

    # FO2: stock sobrante multiplicado por distancia media a TODOS los puntos.
    distancia_media_por_fabrica = distancias.mean(axis=0)
    fo2_por_fabrica = stock_restante * distancia_media_por_fabrica
    fo2 = float(fo2_por_fabrica.sum())

    # Mayor aporte individual a FO2 por fábrica.
    if len(fo2_por_fabrica) > 0:
        indice_mayor_FO2 = int(np.argmax(fo2_por_fabrica))
        mayor_aporte_FO2_fabrica = float(fo2_por_fabrica[indice_mayor_FO2])
        fabrica_mayor_aporte_FO2 = indice_mayor_FO2 + 1
    else:
        mayor_aporte_FO2_fabrica = 0.0
        fabrica_mayor_aporte_FO2 = None

    # Mayor valor individual observado dentro del escenario.
    # Compara el punto más costoso para FO1 contra la fábrica más costosa para FO2.
    if mayor_aporte_FO1_punto >= mayor_aporte_FO2_fabrica:
        mayor_FO_individual_escenario = mayor_aporte_FO1_punto
        origen_mayor_FO_individual = "Punto de demanda / FO1"
        id_origen_mayor_FO_individual = punto_mayor_aporte_FO1
    else:
        mayor_FO_individual_escenario = mayor_aporte_FO2_fabrica
        origen_mayor_FO_individual = "Fábrica / FO2"
        id_origen_mayor_FO_individual = fabrica_mayor_aporte_FO2

    fo_total = fo1 + fo2

    # Distancia promedio de entrega por fábrica.
    # Se calcula como aporte FO1 real / cantidad entregada.
    distancia_promedio_entrega_por_fabrica = np.divide(
        aporte_fo1_transporte_por_fabrica,
        entregado_por_fabrica,
        out=np.zeros_like(aporte_fo1_transporte_por_fabrica),
        where=entregado_por_fabrica > tolerancia
    )

    # Porcentaje de utilización de cada fábrica.
    utilizacion_por_fabrica = np.divide(
        entregado_por_fabrica,
        oferta_inicial,
        out=np.zeros_like(entregado_por_fabrica),
        where=oferta_inicial > tolerancia
    ) * 100

    distancia_promedio_transporte = (
        costo_transporte_real / cantidad_total_transportada
        if cantidad_total_transportada > tolerancia
        else 0.0
    )

    porcentaje_demanda_atendida = (
        cantidad_total_transportada / (demanda_por_punto * num_puntos)
    ) * 100

    return {
        "FO1": float(fo1),
        "FO2": float(fo2),
        "FO_TOTAL": float(fo_total),
        "costo_transporte_real": float(costo_transporte_real),
        "costo_penalizacion_demanda_no_cubierta": float(costo_penalizacion_demanda_no_cubierta),
        "demanda_no_cubierta_total": float(demanda_no_cubierta_total),
        "stock_sobrante_total": float(stock_restante.sum()),
        "stock_final": stock_restante,
        "distancia_media_por_fabrica": distancia_media_por_fabrica,
        "cantidad_total_transportada": float(cantidad_total_transportada),
        "porcentaje_demanda_atendida": float(porcentaje_demanda_atendida),
        "distancia_promedio_transporte_aprox": float(distancia_promedio_transporte),
        "entregas_realizadas": int(entregas_realizadas),
        "distancia_minima_promedio_demanda": float(distancia_minima_por_punto.mean()),
        "distancia_minima_maxima_demanda": float(distancia_minima_por_punto.max()),

        # Mayor FO individual dentro del escenario.
        "mayor_aporte_FO1_punto": float(mayor_aporte_FO1_punto),
        "punto_mayor_aporte_FO1": punto_mayor_aporte_FO1,
        "mayor_aporte_FO2_fabrica": float(mayor_aporte_FO2_fabrica),
        "fabrica_mayor_aporte_FO2": fabrica_mayor_aporte_FO2,
        "mayor_FO_individual_escenario": float(mayor_FO_individual_escenario),
        "origen_mayor_FO_individual": origen_mayor_FO_individual,
        "id_origen_mayor_FO_individual": id_origen_mayor_FO_individual,

        # Métricas por fábrica para análisis detallado.
        "entregado_por_fabrica": entregado_por_fabrica,
        "utilizacion_por_fabrica": utilizacion_por_fabrica,
        "puntos_atendidos_por_fabrica": puntos_atendidos_por_fabrica,
        "puntos_como_proveedor_principal": puntos_como_proveedor_principal,
        "aporte_fo1_transporte_por_fabrica": aporte_fo1_transporte_por_fabrica,
        "fo2_por_fabrica": fo2_por_fabrica,
        "distancia_promedio_entrega_por_fabrica": distancia_promedio_entrega_por_fabrica,
    }


# =========================
# 6. SIMULACIÓN MONTE CARLO
# =========================

def simular_monte_carlo(
    vertices: List[List[float]],
    num_puntos_demanda: int,
    num_fabricas: int,
    demanda_total: float,
    num_escenarios: int,
    n_mejores_peores: int,
    mostrar_progreso: bool = True,
    semilla: int | None = 42
) -> Tuple[pd.DataFrame, List[Dict[str, Any]], np.ndarray, np.ndarray]:
    """
    Ejecuta la simulación completa.

    La semilla permite reproducir exactamente los mismos escenarios.
    Si semilla=None, cada ejecución genera escenarios diferentes.
    """
    validar_parametros_simulacion(
        num_puntos_demanda,
        num_fabricas,
        demanda_total,
        num_escenarios,
        n_mejores_peores
    )

    vertices_ordenados = ordenar_y_validar_vertices_paralelogramo(vertices)
    rng = np.random.default_rng(semilla)

    puntos_demanda = generar_puntos_en_paralelogramo(vertices_ordenados, num_puntos_demanda, rng)
    demanda_por_punto = demanda_total / num_puntos_demanda

    filas_resultados = []
    detalles_escenarios = []
    paso_progreso = max(1, num_escenarios // 10)

    for escenario in range(1, num_escenarios + 1):
        fabricas = generar_puntos_en_paralelogramo(vertices_ordenados, num_fabricas, rng)
        oferta_total, oferta_por_fabrica = generar_oferta_fabricas(num_fabricas, demanda_total, rng)

        metricas = evaluar_escenario(puntos_demanda, fabricas, oferta_por_fabrica, demanda_por_punto)

        filas_resultados.append({
            "escenario": escenario,
            "FO1": metricas["FO1"],
            "FO2": metricas["FO2"],
            "FO_TOTAL": metricas["FO_TOTAL"],
            "costo_transporte_real": metricas["costo_transporte_real"],
            "costo_penalizacion_demanda_no_cubierta": metricas["costo_penalizacion_demanda_no_cubierta"],
            "oferta_total": oferta_total,
            "demanda_total": demanda_total,
            "cantidad_total_transportada": metricas["cantidad_total_transportada"],
            "porcentaje_demanda_atendida": metricas["porcentaje_demanda_atendida"],
            "demanda_no_cubierta_total": metricas["demanda_no_cubierta_total"],
            "stock_sobrante_total": metricas["stock_sobrante_total"],
            "distancia_minima_promedio_demanda": metricas["distancia_minima_promedio_demanda"],
            "distancia_minima_maxima_demanda": metricas["distancia_minima_maxima_demanda"],
            "distancia_promedio_transporte_aprox": metricas["distancia_promedio_transporte_aprox"],
            "mayor_aporte_FO1_punto": metricas["mayor_aporte_FO1_punto"],
            "punto_mayor_aporte_FO1": metricas["punto_mayor_aporte_FO1"],
            "mayor_aporte_FO2_fabrica": metricas["mayor_aporte_FO2_fabrica"],
            "fabrica_mayor_aporte_FO2": metricas["fabrica_mayor_aporte_FO2"],
            "mayor_FO_individual_escenario": metricas["mayor_FO_individual_escenario"],
            "origen_mayor_FO_individual": metricas["origen_mayor_FO_individual"],
            "id_origen_mayor_FO_individual": metricas["id_origen_mayor_FO_individual"],
        })

        detalles_escenarios.append({
            "escenario": escenario,
            "fabricas": fabricas,
            "oferta_inicial": oferta_por_fabrica,
            "oferta_total": oferta_total,
            "stock_final": metricas["stock_final"],
            "distancia_media_por_fabrica": metricas["distancia_media_por_fabrica"],
            **metricas
        })

        if mostrar_progreso and (escenario % paso_progreso == 0 or escenario == num_escenarios):
            porcentaje = 100 * escenario / num_escenarios
            print(f"Progreso: {escenario}/{num_escenarios} escenarios evaluados ({porcentaje:.0f}%).")

    tabla_resultados = pd.DataFrame(filas_resultados)
    tabla_resultados = tabla_resultados.sort_values("FO_TOTAL", ascending=True).reset_index(drop=True)

    return tabla_resultados, detalles_escenarios, puntos_demanda, vertices_ordenados


# =========================
# 7. RESULTADOS Y EXPLICACIONES
# =========================

def obtener_mejores_y_peores(tabla_resultados: pd.DataFrame, n_mejores_peores: int):
    """
    Devuelve los N mejores, los N peores, el menor FO_TOTAL y el mayor FO_TOTAL.
    """
    tabla_ordenada = tabla_resultados.sort_values("FO_TOTAL", ascending=True).reset_index(drop=True)
    mejores = tabla_ordenada.head(n_mejores_peores).copy()
    peores = tabla_ordenada.tail(n_mejores_peores).sort_values("FO_TOTAL", ascending=False).reset_index(drop=True)
    escenario_optimo = tabla_ordenada.iloc[0]
    escenario_mayor_fo = tabla_ordenada.iloc[-1]
    return mejores, peores, escenario_optimo, escenario_mayor_fo


def obtener_detalle_por_escenario(detalles_escenarios: List[Dict[str, Any]], numero_escenario: int) -> Dict[str, Any]:
    """
    Recupera el detalle completo de un escenario específico.
    """
    posible_indice = numero_escenario - 1
    if 0 <= posible_indice < len(detalles_escenarios):
        if detalles_escenarios[posible_indice]["escenario"] == numero_escenario:
            return detalles_escenarios[posible_indice]

    for detalle in detalles_escenarios:
        if detalle["escenario"] == numero_escenario:
            return detalle

    raise ValueError(f"No se encontró el escenario {numero_escenario}.")


def construir_tabla_fabricas(detalle_escenario: Dict[str, Any]) -> pd.DataFrame:
    """
    Crea una tabla detallada con lo que hizo cada fábrica.

    Esta tabla es clave para la exposición porque permite hablar con datos:
    cuánto entregó cada fábrica, cuántos puntos atendió, cuánto sobrante dejó
    y cuánto aportó al costo de transporte.
    """
    fabricas = detalle_escenario["fabricas"]
    oferta_inicial = detalle_escenario["oferta_inicial"]
    stock_final = detalle_escenario["stock_final"]
    entregado = detalle_escenario["entregado_por_fabrica"]
    utilizacion = detalle_escenario["utilizacion_por_fabrica"]
    aporte_fo1 = detalle_escenario["aporte_fo1_transporte_por_fabrica"]
    fo2_por_fabrica = detalle_escenario["fo2_por_fabrica"]

    total_entregado = entregado.sum()
    total_fo1_transporte = aporte_fo1.sum()
    total_fo2 = fo2_por_fabrica.sum()

    tabla = pd.DataFrame({
        "fabrica": np.arange(1, len(fabricas) + 1),
        "x": fabricas[:, 0],
        "y": fabricas[:, 1],
        "oferta_inicial": oferta_inicial,
        "cantidad_entregada_total": entregado,
        "stock_sobrante_final": stock_final,
        "utilizacion_%": utilizacion,
        "participacion_en_entregas_%": np.divide(
            entregado,
            total_entregado,
            out=np.zeros_like(entregado),
            where=total_entregado > 1e-9
        ) * 100,
        "num_puntos_atendidos": detalle_escenario["puntos_atendidos_por_fabrica"],
        "num_puntos_como_proveedor_principal": detalle_escenario["puntos_como_proveedor_principal"],
        "aporte_FO1_transporte": aporte_fo1,
        "participacion_FO1_transporte_%": np.divide(
            aporte_fo1,
            total_fo1_transporte,
            out=np.zeros_like(aporte_fo1),
            where=total_fo1_transporte > 1e-9
        ) * 100,
        "FO2_por_sobrante": fo2_por_fabrica,
        "participacion_FO2_%": np.divide(
            fo2_por_fabrica,
            total_fo2,
            out=np.zeros_like(fo2_por_fabrica),
            where=total_fo2 > 1e-9
        ) * 100,
        "distancia_promedio_entrega": detalle_escenario["distancia_promedio_entrega_por_fabrica"],
        "distancia_media_a_todos_los_puntos": detalle_escenario["distancia_media_por_fabrica"]
    })

    # Clasificación interpretativa basada en datos.
    promedio_entregado = tabla["cantidad_entregada_total"].mean()
    promedio_aporte_fo1 = tabla["aporte_FO1_transporte"].mean()
    promedio_puntos = tabla["num_puntos_atendidos"].mean()

    # La distancia promedio de entrega debe influir en el rol.
    # Una fábrica puede estar saturada y atender muchos puntos, pero si lo hace
    # a distancias muy altas no debe llamarse simplemente estratégica.
    distancias_validas = tabla.loc[
        tabla["cantidad_entregada_total"] > 1e-9,
        "distancia_promedio_entrega"
    ]
    promedio_distancia_entrega = distancias_validas.mean() if len(distancias_validas) > 0 else 0.0
    umbral_distancia_alta = promedio_distancia_entrega * 1.35

    def clasificar_fabrica(fila):
        distancia_alta = (
            promedio_distancia_entrega > 0
            and fila["distancia_promedio_entrega"] > umbral_distancia_alta
        )

        if distancia_alta and fila["utilizacion_%"] >= 99:
            return "Saturada con alto costo de transporte"
        if distancia_alta and fila["aporte_FO1_transporte"] > promedio_aporte_fo1:
            return "Alto costo de transporte"
        if fila["stock_sobrante_final"] > 0 and fila["utilizacion_%"] < 70 and distancia_alta:
            return "Baja utilización y lejana"
        if fila["stock_sobrante_final"] > 0 and fila["utilizacion_%"] < 70:
            return "Baja utilización"
        if fila["utilizacion_%"] >= 99 and fila["num_puntos_atendidos"] >= promedio_puntos:
            return "Estratégica y saturada"
        if fila["utilizacion_%"] >= 99:
            return "Saturada"
        if fila["aporte_FO1_transporte"] > promedio_aporte_fo1 * 1.25:
            return "Alto aporte a FO1"
        if fila["cantidad_entregada_total"] > promedio_entregado and fila["num_puntos_atendidos"] >= promedio_puntos:
            return "Proveedor importante"
        return "Apoyo operativo"

    tabla["rol_interpretado"] = tabla.apply(clasificar_fabrica, axis=1)

    return tabla


def generar_analisis_individual_fabricas_html(tabla_fabricas: pd.DataFrame) -> str:
    """
    Genera una explicación individual de TODAS las fábricas del escenario.

    Esta sección evita que el análisis se quede solo en la fábrica que más entregó
    o la que más sobrante dejó. La idea es poder defender el comportamiento de
    cada fábrica con cantidades exactas.
    """
    bloques = []

    for _, fila in tabla_fabricas.iterrows():
        fabrica = int(fila["fabrica"])
        entregado = fila["cantidad_entregada_total"]
        oferta = fila["oferta_inicial"]
        sobrante = fila["stock_sobrante_final"]
        utilizacion = fila["utilizacion_%"]
        puntos = int(fila["num_puntos_atendidos"])
        principales = int(fila["num_puntos_como_proveedor_principal"])
        aporte_fo1 = fila["aporte_FO1_transporte"]
        participacion_fo1 = fila["participacion_FO1_transporte_%"]
        fo2 = fila["FO2_por_sobrante"]
        distancia_entrega = fila["distancia_promedio_entrega"]
        rol = fila["rol_interpretado"]

        texto = f"""
        <li style="margin-bottom:8px;">
            <b>F{fabrica}:</b> inició con <b>{oferta:,.4f}</b> unidades,
            entregó <b>{entregado:,.4f}</b>, dejó <b>{sobrante:,.4f}</b> de sobrante
            y tuvo una utilización de <b>{utilizacion:,.2f}%</b>.
            Atendió <b>{puntos}</b> puntos de demanda y fue proveedor principal en
            <b>{principales}</b>. Su aporte al costo de transporte FO1 fue
            <b>{aporte_fo1:,.4f}</b> ({participacion_fo1:,.2f}% del FO1 de transporte),
            con distancia promedio de entrega de <b>{distancia_entrega:,.4f}</b>.
            Su FO2 por sobrante fue <b>{fo2:,.4f}</b>. Rol: <b>{rol}</b>.
        </li>
        """
        bloques.append(texto)

    return "<ul>" + "".join(bloques) + "</ul>"


def explicar_escenario(
    detalle_escenario: Dict[str, Any],
    tipo: str,
    tabla_resultados: pd.DataFrame
) -> str:
    """
    Genera una explicación textual de un escenario graficado.

    Esta versión explica:
    - Por qué el escenario fue bueno o malo.
    - FO1, FO2 y FO_TOTAL.
    - Ranking del escenario dentro de todos los escenarios evaluados.
    - Qué hicieron TODAS las fábricas con cantidades exactas.
    """
    fo_total = detalle_escenario["FO_TOTAL"]
    fo1 = detalle_escenario["FO1"]
    fo2 = detalle_escenario["FO2"]
    oferta_total = detalle_escenario["oferta_total"]
    demanda_no_cubierta = detalle_escenario["demanda_no_cubierta_total"]
    stock_sobrante = detalle_escenario["stock_sobrante_total"]
    dist_min_prom = detalle_escenario["distancia_minima_promedio_demanda"]
    dist_min_max = detalle_escenario["distancia_minima_maxima_demanda"]

    # Ranking: posición del escenario cuando todos se ordenan de menor a mayor FO_TOTAL.
    # Ranking 1 = mejor escenario de todos.
    total_escenarios = len(tabla_resultados)
    ranking = int((tabla_resultados["FO_TOTAL"] < fo_total).sum() + 1)

    aporte_fo1 = 100 * fo1 / fo_total if fo_total > 0 else 0
    aporte_fo2 = 100 * fo2 / fo_total if fo_total > 0 else 0

    tabla_fabricas = construir_tabla_fabricas(detalle_escenario)

    fabrica_mas_entrego = tabla_fabricas.loc[tabla_fabricas["cantidad_entregada_total"].idxmax()]
    fabrica_mayor_fo1 = tabla_fabricas.loc[tabla_fabricas["aporte_FO1_transporte"].idxmax()]
    fabrica_mayor_sobrante = tabla_fabricas.loc[tabla_fabricas["stock_sobrante_final"].idxmax()]
    fabrica_mas_puntos = tabla_fabricas.loc[tabla_fabricas["num_puntos_atendidos"].idxmax()]

    analisis_todas_las_fabricas = generar_analisis_individual_fabricas_html(tabla_fabricas)

    tipo_normalizado = tipo.lower()

    if "óptimo" in tipo_normalizado or "optimo" in tipo_normalizado or "mejor escenario encontrado" in tipo_normalizado:
        lectura_general = (
            "Este es el mejor escenario encontrado porque obtuvo el menor FO_TOTAL "
            "entre todos los escenarios evaluados. Representa la mejor configuración "
            "encontrada por el proceso de Monte Carlo para los parámetros ingresados; "
            "no necesariamente el óptimo matemático absoluto del espacio continuo."
        )
    elif tipo_normalizado.startswith("mejor"):
        lectura_general = (
            "Este escenario aparece entre los mejores porque logra una combinación favorable: "
            "las fábricas quedaron relativamente bien ubicadas frente a la red de demanda, "
            "la demanda fue abastecida con bajo costo de transporte y el costo total fue bajo "
            "comparado con los demás escenarios simulados."
        )
    else:
        lectura_general = (
            "Este escenario aparece entre los peores porque la configuración espacial de las fábricas, "
            "el balance de stock o la demanda no cubierta generaron un FO_TOTAL alto frente al resto de simulaciones."
        )

    if demanda_no_cubierta > 1e-7:
        lectura_demanda = (
            f"Quedaron <b>{demanda_no_cubierta:,.4f}</b> unidades de demanda sin cubrir. "
            "Esa demanda se penalizó en FO1 usando la distancia a la fábrica más lejana de cada punto afectado."
        )
    else:
        lectura_demanda = "No quedó demanda sin cubrir; toda la demanda fue atendida por alguna fábrica."

    if stock_sobrante > 1e-7:
        lectura_stock = (
            f"Quedaron <b>{stock_sobrante:,.4f}</b> unidades de stock sobrante. "
            "Ese sobrante afecta FO2 según la distancia media de cada fábrica a todos los puntos de demanda."
        )
    else:
        lectura_stock = "No quedó stock sobrante; la oferta disponible fue consumida completamente."

    explicacion = f"""
    <div style="border-left: 5px solid #2f6fed; background:#f7f9fc; padding:14px; margin:10px 0 25px 0; border-radius:8px;">
        <b>Explicación del {tipo.lower()} - Escenario {detalle_escenario['escenario']}</b><br><br>
        {lectura_general}<br><br>

        <b>Ranking del escenario:</b><br>
        Este escenario ocupó el puesto <b>{ranking}</b> de <b>{total_escenarios}</b> escenarios evaluados,
        ordenando de menor a mayor FO_TOTAL. El puesto 1 representa el mejor escenario encontrado.<br><br>

        <b>Lectura numérica del escenario:</b><br>
        - FO_TOTAL = <b>{fo_total:,.4f}</b>.<br>
        - FO1 = {fo1:,.4f}, equivalente al {aporte_fo1:.2f}% del total.<br>
        - FO2 = {fo2:,.4f}, equivalente al {aporte_fo2:.2f}% del total.<br>
        - Costo de transporte real = {detalle_escenario['costo_transporte_real']:,.4f}.<br>
        - Penalización por demanda no cubierta = {detalle_escenario['costo_penalizacion_demanda_no_cubierta']:,.4f}.<br>
        - Oferta total del escenario = {oferta_total:,.4f}.<br>
        - Cantidad total transportada = {detalle_escenario['cantidad_total_transportada']:,.4f}.<br>
        - Porcentaje de demanda atendida = {detalle_escenario['porcentaje_demanda_atendida']:,.2f}%.<br>
        - Distancia mínima promedio desde los puntos de demanda a su fábrica más cercana = {dist_min_prom:,.4f}.<br>
        - Mayor distancia mínima observada en la red de demanda = {dist_min_max:,.4f}.<br>
        - Mayor aporte individual a FO1 por un punto de demanda = {detalle_escenario['mayor_aporte_FO1_punto']:,.4f} en el punto {detalle_escenario['punto_mayor_aporte_FO1']}.<br>
        - Mayor aporte individual a FO2 por una fábrica = {detalle_escenario['mayor_aporte_FO2_fabrica']:,.4f} en la fábrica F{detalle_escenario['fabrica_mayor_aporte_FO2']}.<br>
        - Mayor FO individual del escenario = <b>{detalle_escenario['mayor_FO_individual_escenario']:,.4f}</b>, originado en {detalle_escenario['origen_mayor_FO_individual']} {detalle_escenario['id_origen_mayor_FO_individual']}.<br><br>

        <b>Abastecimiento:</b><br>
        {lectura_demanda}<br>
        {lectura_stock}<br><br>

        <b>Resumen de fábricas destacadas:</b><br>
        - La fábrica F{int(fabrica_mas_entrego['fabrica'])} fue la que más producto entregó:
          <b>{fabrica_mas_entrego['cantidad_entregada_total']:,.4f}</b> unidades, con una utilización de
          {fabrica_mas_entrego['utilizacion_%']:,.2f}%.<br>
        - La fábrica F{int(fabrica_mas_puntos['fabrica'])} fue la que atendió más puntos de demanda:
          <b>{int(fabrica_mas_puntos['num_puntos_atendidos'])}</b> puntos, y fue proveedor principal en
          {int(fabrica_mas_puntos['num_puntos_como_proveedor_principal'])} puntos.<br>
        - La fábrica F{int(fabrica_mayor_fo1['fabrica'])} fue la que más aportó al costo de transporte FO1:
          <b>{fabrica_mayor_fo1['aporte_FO1_transporte']:,.4f}</b>, con una distancia promedio de entrega de
          {fabrica_mayor_fo1['distancia_promedio_entrega']:,.4f}.<br>
        - La fábrica F{int(fabrica_mayor_sobrante['fabrica'])} fue la que dejó mayor sobrante:
          <b>{fabrica_mayor_sobrante['stock_sobrante_final']:,.4f}</b> unidades, generando un FO2 individual de
          {fabrica_mayor_sobrante['FO2_por_sobrante']:,.4f}.<br><br>

        <b>Análisis individual de todas las fábricas:</b><br>
        {analisis_todas_las_fabricas}
    </div>
    """

    return explicacion


def mostrar_resumen_resultados(tabla_resultados, mejores, peores, escenario_optimo, escenario_mayor_fo, detalle_optimo):
    """
    Muestra las tablas principales, el mejor escenario encontrado y el mayor FO_TOTAL.
    """
    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", 160)
    pd.set_option("display.float_format", "{:,.4f}".format)

    display(HTML("<h2>Tabla resumen general</h2>"))
    display(tabla_resultados)

    display(HTML("<h2>N mejores escenarios</h2>"))
    display(mejores)

    display(HTML("<h2>N peores escenarios</h2>"))
    display(peores)

    display(HTML("<h2>Mejor escenario encontrado</h2>"))
    display(HTML("""
    <div style="background:#eef6ff; border:1px solid #bfdbfe; padding:12px; border-radius:8px; margin-bottom:12px;">
        El mejor escenario reportado corresponde al menor FO_TOTAL encontrado dentro de los escenarios simulados.
        No representa necesariamente el óptimo matemático absoluto del espacio continuo, sino la mejor configuración
        encontrada por la simulación Monte Carlo ejecutada.
    </div>
    """))
    display(HTML(f"""
    <div style="background:#ecfdf3; border:1px solid #b7ebc6; padding:14px; border-radius:8px;">
        <b>Mejor escenario encontrado:</b> {int(escenario_optimo['escenario'])}<br>
        <b>FO1:</b> {escenario_optimo['FO1']:,.4f}<br>
        <b>FO2:</b> {escenario_optimo['FO2']:,.4f}<br>
        <b>FO_TOTAL:</b> {escenario_optimo['FO_TOTAL']:,.4f}<br>
        <b>Oferta total:</b> {escenario_optimo['oferta_total']:,.4f}<br>
        <b>Demanda no cubierta:</b> {escenario_optimo['demanda_no_cubierta_total']:,.4f}<br>
        <b>Stock sobrante final:</b> {escenario_optimo['stock_sobrante_total']:,.4f}<br>
        <b>Mayor FO individual del escenario:</b> {escenario_optimo['mayor_FO_individual_escenario']:,.4f}
    </div>
    """))

    display(HTML("<h2>Mayor valor de la función objetivo entre todos los escenarios</h2>"))
    display(HTML(f"""
    <div style="background:#fff1f2; border:1px solid #fecdd3; padding:14px; border-radius:8px;">
        <b>Escenario con mayor FO_TOTAL:</b> {int(escenario_mayor_fo['escenario'])}<br>
        <b>FO1:</b> {escenario_mayor_fo['FO1']:,.4f}<br>
        <b>FO2:</b> {escenario_mayor_fo['FO2']:,.4f}<br>
        <b>FO_TOTAL máximo:</b> {escenario_mayor_fo['FO_TOTAL']:,.4f}<br>
        <b>Mayor FO individual dentro de ese escenario:</b> {escenario_mayor_fo['mayor_FO_individual_escenario']:,.4f}<br>
        Esta salida responde explícitamente al requisito de determinar el mayor valor de la función objetivo.
    </div>
    """))

    display(HTML("<h3>Coordenadas exactas de las fábricas del mejor escenario encontrado</h3>"))
    display(construir_tabla_fabricas(detalle_optimo))


# =========================
# 8. GRÁFICAS EXPLICADAS
# =========================

def graficar_escenario(
    vertices_ordenados: np.ndarray,
    puntos_demanda: np.ndarray,
    detalle_escenario: Dict[str, Any],
    etiqueta: str,
    tabla_resultados: pd.DataFrame
) -> None:
    """
    Grafica un escenario y luego imprime una explicación automática.
    """
    fabricas = detalle_escenario["fabricas"]
    numero_escenario = detalle_escenario["escenario"]
    fo_total = detalle_escenario["FO_TOTAL"]

    contorno = np.vstack([vertices_ordenados, vertices_ordenados[0]])

    plt.figure(figsize=(8, 7))
    plt.plot(contorno[:, 0], contorno[:, 1], linewidth=2, label="Contorno del paralelogramo")
    plt.scatter(puntos_demanda[:, 0], puntos_demanda[:, 1], s=25, alpha=0.7, label="Puntos de demanda")
    plt.scatter(fabricas[:, 0], fabricas[:, 1], s=140, marker="^", label="Fábricas")

    for i, (x, y) in enumerate(fabricas, start=1):
        plt.annotate(f"F{i}", xy=(x, y), xytext=(6, 6), textcoords="offset points", fontsize=10, weight="bold")

    plt.title(f"{etiqueta} | Escenario {numero_escenario} | FO_TOTAL = {fo_total:,.4f}")
    plt.xlabel("Coordenada X")
    plt.ylabel("Coordenada Y")
    plt.axis("equal")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.show()

    display(HTML(explicar_escenario(detalle_escenario, etiqueta, tabla_resultados)))

    display(HTML("<b>Detalle de fábricas en esta gráfica:</b>"))
    display(construir_tabla_fabricas(detalle_escenario))


def graficar_escenario_optimo_global(
    vertices_ordenados: np.ndarray,
    puntos_demanda: np.ndarray,
    detalle_optimo: Dict[str, Any],
    tabla_resultados: pd.DataFrame
) -> None:
    """
    Genera una gráfica independiente y explícita del mejor escenario encontrado.

    Esta salida responde directamente a la sección 7.4 del documento: no depende
    de que el mejor escenario aparezca dentro de las gráficas de los N mejores,
    sino que se muestra como resultado propio del modelo.
    """
    display(HTML("<h2>Gráfica independiente del mejor escenario encontrado</h2>"))
    display(HTML("""
    <div style="background:#ecfdf3; border:1px solid #b7ebc6; padding:12px; border-radius:8px; margin-bottom:12px;">
        Esta gráfica muestra de forma separada la configuración con menor FO_TOTAL
        encontrada en toda la simulación. No depende del listado de N mejores escenarios.
    </div>
    """))
    graficar_escenario(
        vertices_ordenados,
        puntos_demanda,
        detalle_optimo,
        "Mejor escenario encontrado",
        tabla_resultados
    )


def graficar_mejores_y_peores(vertices_ordenados, puntos_demanda, detalles_escenarios, mejores, peores, tabla_resultados):
    """
    Genera gráficas individuales para mejores y peores escenarios,
    cada una con su explicación textual.
    """
    display(HTML("<h2>Gráficas explicadas de los mejores escenarios</h2>"))
    for _, fila in mejores.iterrows():
        detalle = obtener_detalle_por_escenario(detalles_escenarios, int(fila["escenario"]))
        graficar_escenario(vertices_ordenados, puntos_demanda, detalle, "Mejor escenario", tabla_resultados)

    display(HTML("<h2>Gráficas explicadas de los peores escenarios</h2>"))
    for _, fila in peores.iterrows():
        detalle = obtener_detalle_por_escenario(detalles_escenarios, int(fila["escenario"]))
        graficar_escenario(vertices_ordenados, puntos_demanda, detalle, "Peor escenario", tabla_resultados)


# =========================
# 9. EXPORTACIÓN OPCIONAL
# =========================

def exportar_resultados_csv(tabla_resultados, mejores, peores, prefijo="resultados_ubicacion_fabricas"):
    """
    Exporta resultados principales a CSV.
    """
    tabla_resultados.to_csv(f"{prefijo}_tabla_general.csv", index=False)
    mejores.to_csv(f"{prefijo}_mejores.csv", index=False)
    peores.to_csv(f"{prefijo}_peores.csv", index=False)

    print("Archivos CSV generados:")
    print(f"- {prefijo}_tabla_general.csv")
    print(f"- {prefijo}_mejores.csv")
    print(f"- {prefijo}_peores.csv")


# =========================
# 10. EJECUCIÓN CENTRAL
# =========================

def ejecutar_simulacion_con_parametros(parametros: Dict[str, Any]) -> Dict[str, Any]:
    """
    Ejecuta todo el flujo de simulación con un diccionario de parámetros.
    """
    inicio = time.perf_counter()

    tabla_resultados, detalles_escenarios, puntos_demanda, vertices_ordenados = simular_monte_carlo(
        vertices=parametros["vertices"],
        num_puntos_demanda=int(parametros["num_puntos_demanda"]),
        num_fabricas=int(parametros["num_fabricas"]),
        demanda_total=float(parametros["demanda_total"]),
        num_escenarios=int(parametros["num_escenarios"]),
        n_mejores_peores=int(parametros["n_mejores_peores"]),
        mostrar_progreso=bool(parametros["mostrar_progreso"]),
        semilla=parsear_semilla(parametros.get("semilla", 42))
    )

    mejores, peores, escenario_optimo, escenario_mayor_fo = obtener_mejores_y_peores(
        tabla_resultados,
        int(parametros["n_mejores_peores"])
    )

    detalle_optimo = obtener_detalle_por_escenario(
        detalles_escenarios,
        int(escenario_optimo["escenario"])
    )

    fin = time.perf_counter()
    tiempo_total = fin - inicio

    mostrar_resumen_resultados(tabla_resultados, mejores, peores, escenario_optimo, escenario_mayor_fo, detalle_optimo)

    display(HTML(f"""
    <h2>Tiempo de ejecución</h2>
    <div style="background:#fff8e1; border:1px solid #ffe082; padding:12px; border-radius:8px;">
        Tiempo total: <b>{tiempo_total:.4f} segundos</b>
    </div>
    """))

    graficar_escenario_optimo_global(
        vertices_ordenados,
        puntos_demanda,
        detalle_optimo,
        tabla_resultados
    )

    graficar_mejores_y_peores(
        vertices_ordenados,
        puntos_demanda,
        detalles_escenarios,
        mejores,
        peores,
        tabla_resultados
    )

    return {
        "tabla_resultados": tabla_resultados,
        "detalles_escenarios": detalles_escenarios,
        "puntos_demanda": puntos_demanda,
        "vertices_ordenados": vertices_ordenados,
        "mejores": mejores,
        "peores": peores,
        "escenario_optimo": escenario_optimo,
        "escenario_mayor_fo": escenario_mayor_fo,
        "detalle_optimo": detalle_optimo,
        "tiempo_total": tiempo_total
    }


# =========================
# 11. FORMULARIO BONITO PARA COLAB/JUPYTER
# =========================

def mostrar_formulario_interactivo():
    """
    Muestra un formulario visual para que el usuario digite los parámetros.

    En Colab se recomienda:
        1. Ejecutar esta celda.
        2. Cambiar los valores en el formulario.
        3. Presionar el botón azul "Ejecutar simulación".
    """
    if not WIDGETS_DISPONIBLES:
        raise RuntimeError("ipywidgets no está disponible en este entorno.")

    estilo = {"description_width": "190px"}
    ancho = Layout(width="620px")

    titulo = widgets.HTML(
        value="""
        <div style='background:#0f172a; color:white; padding:18px; border-radius:10px; margin-bottom:12px;'>
            <h2 style='margin:0;'>Simulación Monte Carlo - Ubicación de Fábricas</h2>
            <p style='margin:6px 0 0 0;'>Digita los parámetros del modelo y ejecuta la simulación.</p>
        </div>
        """
    )

    vertices_w = widgets.Textarea(
        value=str(PARAMETROS_DEFAULT["vertices"]),
        description="Vértices:",
        placeholder="[[0,0], [10,2], [12,8], [2,6]]",
        layout=Layout(width="620px", height="90px"),
        style=estilo
    )

    puntos_w = widgets.IntText(
        value=PARAMETROS_DEFAULT["num_puntos_demanda"],
        description="Puntos de demanda:",
        layout=ancho,
        style=estilo
    )

    fabricas_w = widgets.IntText(
        value=PARAMETROS_DEFAULT["num_fabricas"],
        description="Número de fábricas:",
        layout=ancho,
        style=estilo
    )

    demanda_w = widgets.FloatText(
        value=PARAMETROS_DEFAULT["demanda_total"],
        description="Demanda total:",
        layout=ancho,
        style=estilo
    )

    escenarios_w = widgets.IntText(
        value=PARAMETROS_DEFAULT["num_escenarios"],
        description="Número de escenarios:",
        layout=ancho,
        style=estilo
    )

    n_w = widgets.IntText(
        value=PARAMETROS_DEFAULT["n_mejores_peores"],
        description="N mejores y peores:",
        layout=ancho,
        style=estilo
    )

    semilla_w = widgets.Text(
        value=str(PARAMETROS_DEFAULT["semilla"]),
        description="Semilla aleatoria:",
        placeholder="42 para reproducible o None para aleatoria",
        layout=ancho,
        style=estilo
    )


    progreso_w = widgets.Checkbox(
        value=PARAMETROS_DEFAULT["mostrar_progreso"],
        description="Mostrar progreso durante la simulación",
        indent=False,
        layout=Layout(width="620px")
    )

    boton = widgets.Button(
        description="Ejecutar simulación",
        button_style="primary",
        icon="play",
        layout=Layout(width="220px", height="42px")
    )

    salida = widgets.Output()

    def al_hacer_click(b):
        with salida:
            clear_output(wait=True)
            try:
                parametros = {
                    "vertices": parsear_vertices(vertices_w.value),
                    "num_puntos_demanda": int(puntos_w.value),
                    "num_fabricas": int(fabricas_w.value),
                    "demanda_total": float(demanda_w.value),
                    "num_escenarios": int(escenarios_w.value),
                    "n_mejores_peores": int(n_w.value),
                    "semilla": parsear_semilla(semilla_w.value),
                    "mostrar_progreso": bool(progreso_w.value)
                }

                display(HTML("<h2>Parámetros recibidos</h2>"))
                display(pd.DataFrame([parametros]))

                # Variable global para poder reutilizar resultados después,
                # por ejemplo para exportar CSV.
                global RESULTADOS_SIMULACION
                RESULTADOS_SIMULACION = ejecutar_simulacion_con_parametros(parametros)

            except Exception as exc:
                display(HTML(f"""
                <div style='background:#fee2e2; border:1px solid #fca5a5; color:#7f1d1d; padding:14px; border-radius:8px;'>
                    <b>Error en los parámetros o en la simulación:</b><br>{exc}
                </div>
                """))

    boton.on_click(al_hacer_click)

    formulario = widgets.VBox([
        titulo,
        vertices_w,
        puntos_w,
        fabricas_w,
        demanda_w,
        escenarios_w,
        n_w,
        semilla_w,
        progreso_w,
        boton,
        salida
    ])

    display(formulario)


# =========================
# 12. INSTRUCCIONES DE USO
# =========================

# OPCIÓN RECOMENDADA PARA EL DOCENTE:
# Ejecuta esta línea y usa el formulario visual.
mostrar_formulario_interactivo()

# OPCIÓN ALTERNATIVA:
# Si quieres ejecutar sin formulario, comenta la línea anterior y descomenta esta:
# RESULTADOS_SIMULACION = ejecutar_simulacion_con_parametros(PARAMETROS_DEFAULT)

# OPCIÓN PARA EXPORTAR DESPUÉS DE EJECUTAR:
# exportar_resultados_csv(
#     RESULTADOS_SIMULACION["tabla_resultados"],
#     RESULTADOS_SIMULACION["mejores"],
#     RESULTADOS_SIMULACION["peores"]
# )
