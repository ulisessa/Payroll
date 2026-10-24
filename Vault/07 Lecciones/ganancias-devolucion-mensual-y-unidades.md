---
tipo: leccion
tema: ganancias
tags: [leccion, ganancias, devoluciones, migracion-meta4]
fuente: [scripts/AplicarDevolucionGananciasMensual.ps1, scripts/CorregirDevolucionGananciasMensual.sql, scripts/VerificarDevolucionGananciasMensual.ps1]
actualizado: 2026-10-13
---

# Ganancias mensual: devoluciones y unidad de deducciones

Meta4 calcula el 5010 como impuesto acumulado menos lo previamente retenido y
permite reintegros. Un importe negativo no implica una novedad: debe verificarse
la tabla de incidencias y conciliarse el impuesto total original contra las
retenciones anteriores. Se confirmó un caso de febrero sin novedad de impuesto.

## Corrección de febrero

La rama mensual de 5010 tenía MAX(impuesto acumulado - YTD_RETENIDO_ANUAL, 0).
Nueva vigencia desde 01/02/2026: sustituir únicamente el piso cero por
-MAX(YTD_RETENIDO_ANUAL, 0). Así la devolución se limita al saldo retenido y no
se paga un crédito fiscal inexistente. La rama LIQ_FINAL conserva su fórmula.
La vigencia anterior se cierra al 31/01/2026; la fracción RETENIDO_IG continúa
al 100 % y computa también el signo negativo en la retención acumulada futura.

Quitar el piso cero no alcanzaba. MNI_ANUAL, DESP_4CAT, CONYUGE, HIJO e HIJO_INC
estaban importados en cada mes como enero multiplicado por número de mes, aunque
Contexto Liquidación y la fórmula esperan valores mensuales. Desde febrero,
MES_ANUAL volvía a acumular importes que ya eran acumulados. Enero ocultaba la
inconsistencia porque su factor era uno.

Se normalizaron 24 vigencias de esos cinco catálogos entre febrero y junio,
verificando antes el patrón exacto Valor = valor de enero * mes. Enero no cambia.
El valor se expresa ahora por mes; la acumulación sigue en la fórmula existente.
No cambian las declaraciones de gastos personales, los familiares, sus fechas,
porcentajes ni las fotos históricas FAM_HIST_M4. Las normas de Meta4 y las escalas
cargadas se leen como evidencia: no cargar resultados de impuesto como novedades.

## Aplicación y verificación

El aplicador queda en preview por defecto. Respalda configuración y datos,
reproduce los resultados anteriores, comprueba los límites de devolución y
prueba todas las escrituras en una transacción que revierte. La escritura
aplicada agrega la vigencia y el historial de fórmula, y normaliza únicamente
las filas fiscales revisadas. Tras SQL directo reinicia BC252 y recalcula el
mes completo de cada afectado mediante AL; no se agregan Commit en AL.

La proyección a partir del resumen final es orientativa: algunos acumuladores
reciben aportes después de 5010. Comprobar el impuesto con la traza TRAMO
capturada al evaluar la fórmula, que conserva resultado, base, tramo, monto fijo
y porcentaje exactos. No usar el contexto final como si fuese el momento del 5010.
La verificación también controla bruto, otros conceptos, enero, cabeceras ajenas,
valores de parámetros y saldos netos de francos.

Los cortes de conexión o publicaciones simultáneas no justifican repetir una
migración ya aplicada. Para retomar, consultar la vigencia del 5010 guardada en
cada documento y recalcular sólo los pendientes. Mantener en borrador cualquier
documento reabierto por otra sesión durante la ejecución.

La corrección requiere configuración y recálculo, sin nuevos objetos ni versión
de la aplicación. No resuelve por sí sola las demás diferencias de febrero
frente a Meta4; verificarlas sobre la misma corrida y el mes completo.

Fuentes, importes, proyecciones y respaldos privados:
.snapshots/devolucion-mensual-20261012 y
.snapshots/devolucion-ganancias-febrero-20261012.
## Resultado verificado y límite de la comparación

La fórmula y las 24 normalizaciones quedaron aplicadas. El caso de referencia
coincide al centavo con el impuesto original de Meta4 y conserva su bruto. No hay
novedad 5010 en febrero. El alcance económico inicial era de 100 empleados:
99 quedaron calculados y uno fue reabierto por otra sesión durante la ejecución,
por lo que se conservó en borrador. Se comprobaron 99 escalas/saldos de sus trazas
y 235 resultados de febrero. Las cabeceras de enero y los saldos netos de francos
se conservan; los demás valores de parámetros también pasan la comparación.

Durante la ejecución se publicaron cambios externos hasta la versión 646. La
resolución de parámetros ahora prioriza la vigencia más reciente y desempata por
especificidad (Cod50071): esto alcanza al coeficiente de pesquería de febrero y
otros parámetros que alimentan haberes y contribuciones. La auditoría registra
63 campos económicos de cabecera cambiados y 1050 diferencias de filas distintas
de 5010. No afirmar que los brutos o las contribuciones de todo el alcance quedaron
iguales. No se revirtieron esos cambios concurrentes ni se republicó la aplicación.

El verificador estricto rechaza diferencias económicas externas. Sólo con la
opción explícita CambiosConcurrentes las guarda en un informe privado y completa
la verificación fiscal contra la escala y el saldo realmente usados. Esta opción
no equivale a aprobar la conciliación de esos otros haberes: sobre los 235 casos
quedan 84 diferencias de Ganancias superiores a un peso frente a Meta4, que deben
revisarse con las corridas y demás entradas del mes. No son devoluciones a cargar
manualmente para forzar coincidencia.
