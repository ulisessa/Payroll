---
tipo: guia
tags: [operacion, control-previo, preparacion]
fuente: [src/Codeunits/Cod110080.ControlPrevioLiq.al, src/Pages/Pag110080.ControlPrevioLiquidacion.al, src/Reports/Rep110080.PreparacionLiquidaciones.al]
actualizado: 2026-10-25
---

# Preparación de liquidaciones (control previo)

Página `Pag110080` ("Preparación de liquidaciones") e informe `Rep110080`. Revisa los datos de entrada de un período **sin calcular**: elige los mismos candidatos que el creador por lotes (fases, tipos, asignaciones, estados y filtros) y, por cada contexto empleado + proyecto + tipo, inspecciona encuadre, atributos, parámetros que usan los conceptos, fuentes y monedas. Todo lo que escribe es temporal. Empleado y proyecto admiten un filtro o se eligen con la búsqueda (lookup).

## Controles por contexto (desde el 25/10/2026)
- **Estados (Error):** todo día de la **cobertura de esa liquidación** —no del período: una marea cubre las fechas del proyecto y una final llega hasta la baja— en que el empleado está de alta tiene que tener un `Estado Empleado`. Informa cada hueco con sus fechas. Sin fases cargadas, se exige en toda la ventana.
- **Fechas del proyecto (Error):** proyecto productivo (tipo 1) sin fecha de inicio, o que termina antes de empezar. La fecha de fin en blanco es la marea en curso y no se informa. **No** se controla la duración (los PP-… de planta son anuales) ni los estados fuera de las fechas del proyecto (los de puerto lo están a propósito).
- **Cotización (Error / Revisión):** por cada moneda de los precios resueltos del contexto, debe haber cotización en "Tipos de cambio" hasta la fecha de cotización (final al egreso, cierre al último día cubierto, novedad `FECHA_TC`). Ninguna = error; la última con más de 5 días = revisión. Se informa una vez por moneda y fecha, sin empleado. Es independiente de la conversión automática de parámetros.

## Límite conocido
La revisión estática resuelve los precios a la fecha de referencia del contexto con su convenio/categoría. Un precio que falta sólo en un tramo del mes (cambio de categoría, fórmulas con varias tarifas) aparece con "Simular cálculo".

## Simular cálculo (opción, desde el 25/10/2026)
Con "Simular cálculo" tildado, después de la revisión estática se **calcula cada contexto candidato** con `Simulación Liq.` (`Cod110095`): arma la misma cabecera que el creador por lotes (número fijo `SIMULACION`), corre `Motor.LiquidarRecord` completo y termina **siempre con un Error** que revierte todo (cabecera, líneas, resumen, uso de parámetros, movimientos de francos). Los resultados viven en las variables de la instancia, que no se revierten. Se invoca con `Codeunit.Run` sin `Commit`: el control sólo escribe temporales. Muestra un diálogo de progreso ("n de N", con los pasos del motor). Tarda lo que una corrida completa del alcance.

Informa, por contexto:
- **Precio sin valor (Error, área Precio):** un parámetro sin ninguna fila para ese empleado/par/fecha que una fórmula leyó **como valor**. Lo detecta el evaluador (`RegistrarPrecioFaltante`, `Cod50015`) con la lista `FParamSinFila` del contexto (`Cod50016.EsParametroSinFila`). **No** se anota si se leyó en la condición de un `IF`, en un `CASE` (incluido su default), en el primer argumento de `IFZERO` o en la condición del concepto: ahí la ausencia es parte de la fórmula. "Conceptos relacionados" lista quiénes lo leyeron.
- **La simulación del cálculo falló (Error, área Cálculo):** el mensaje del error real del motor.

El mismo aviso de precio sin valor queda también en el **registro de cada cálculo real** (`Motor.RegistrarPreciosFaltantes`, categoría Parámetro, severidad Advertencia), así que aparece en "Avisos del cálculo".

Límite: con un par alterno restaurado desde la caché por par (`UsarParCCT`), `FParamSinFila` refleja la última pasada de `LoadParametros` y puede no coincidir con el par de ese concepto.
