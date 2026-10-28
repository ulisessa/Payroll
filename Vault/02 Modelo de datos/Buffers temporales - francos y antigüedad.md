---
tipo: referencia
tags: [modelo-de-datos, buffers, temporales, francos, antiguedad]
fuente: [src/Tables/Tab110011.FrancosBufferLiq.al, src/Tables/Tab110014.LoteFrancoBufferLiq.al, src/Tables/Tab110040.AntiguedadPlantillaBuffer.al, src/Codeunits/Cod50053.GestionFrancos.al]
actualizado: 2026-10-04
---

# Buffers temporales - francos y antigüedad

Tablas `TableType = Temporary` (no persisten nada). El ledger de francos **no tiene tabla propia**: vive en [[Tabla - Línea Liquidación]] y estos buffers sólo lo muestran. Ver [[francos-fifo-ledger]]. Otros grupos: [[Buffers temporales - control y consulta de liquidaciones]], [[Buffers temporales - comparador Meta4 y auxiliares]].

## Francos Buffer Liq. (110011)
- **Para qué:** página `Francos por Tripulante` (110024), armado por `Cod50053 Gestión Francos`.
- **PK:** `("No. Empleado","Cód. Convenio","Cód. Categoría")`. La fila **no** es por persona: los francos **no son fungibles**; cada lote se sella con el convenio y la categoría con que se ganó y se paga al valor de *esa* categoría aunque hoy el tripulante esté en otra. Un total por persona escondería lo que hay que controlar.
- **Campos clave:** `Devengados`, `Consumidos` (atribuidos por **FIFO** recorriendo del lote más viejo al más nuevo, que es como los paga el motor), `Saldo`, `Valor Franco` (`VALOR_FRANCO_<CONVENIO>_<CATEGORÍA>` a la fecha de corte; **0 = el parámetro no existe y esos francos se pagarían a cero**), `Importe Saldo`, `Lote Más Antiguo/Reciente`, `Lotes`.
- **Trampa:** el consumo no dice de qué categoría salió; se deduce, no se lee.

## Lote Franco Buffer Liq. (110014)
- **Para qué:** `Lotes Franco Consumidos` (110054): el desglose FIFO de **un** pago de francos (concepto 1063). Es el detalle que faltaba: el importe salía del motor sin que se pudiera ver de dónde.
- **PK:** `"No. Línea"` (el 1 es el lote más antiguo). `Access = Public`.
- **Campos clave:** `Fecha Lote`, `No. Liquidación Origen`, `No. Proyecto` (→ `Job`; de la marea sale la pesquería y con ella el coeficiente), `Cód. Convenio/Categoría` del lote, `Días del Lote`, `Días Disponibles`, `Días Tomados`, `Valor Franco`, `Coeficiente` (proporción del valor pleno: 1 = entero, 0,30 = marinería 729/15 en tangonero; **no multiplica nada**, el valor ya viene resuelto), `Tipo Buque` (CAL potero / LAN tangonero), `Importe` (días × valor × coeficiente), `Cód. Concepto Lote`.
- **Trampa:** se reconstruye llamando a `Gestión Francos`, que recorre en el mismo orden y **con la misma exclusión de la liquidación en curso** que el cálculo; así lo que se ve es lo que se pagó. Una tabla real habría que mantenerla sincronizada con recálculos y anulaciones. Ver [[valor-franco-por-terna]], [[franco-porcentaje-por-pesqueria]].

## Antigüedad Plantilla Buffer (110040)
- **Para qué:** `Antigüedad de la Plantilla` (110029): la misma cuenta del motor, hecha para toda la plantilla de una vez. Los problemas de antigüedad no se ven de a uno: un legajo con antigüedad 0 por no tener alta parece normal en su ficha y salta en una lista de mil ordenada por avisos.
- **PK:** `"No. Empleado"`. Claves `PorAviso (Avisos, No. Empleado)`, `PorAntiguedad (Días Totales)`, `PorNombre`.
- **Campos clave:** `Fecha Primer/Última Alta`, `Fecha Última Baja`, `De Alta` (última fase abierta a la fecha de referencia), `Estado Vigente`, `Fases`, `Días Totales`, `Años Completos`, `Antigüedad (años)` (fraccionaria, la que usan las fórmulas que prorratean), `Años al 30/06` (el corte del Art. 32, el que realmente se paga durante el año), `Antigüedad Reconocida`, `Avisos`, `Aviso`.
- **Trampas:** `Días Totales` es informativo y **no incluye** la Antigüedad Reconocida (que sí entra en los años); si los años no cierran con los días es por eso. La primera alta no es la que manda cuando hubo bajas en el medio. Lee [[Tabla - Fase Alta Empleado]]; ver [[antiguedad-suma-de-fases]], [[antiguedad-dia-por-fase]].

## Relacionado
[[Tabla - Saldo Inicial Francos Liq]] · [[Índice Modelo de datos (110xxx)]]
