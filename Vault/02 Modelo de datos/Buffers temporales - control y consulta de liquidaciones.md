---
tipo: referencia
tags: [modelo-de-datos, buffers, temporales, paginas]
fuente: [src/Tables/Tab110007.ArbolLiquidacionesBuffer.al, src/Tables/Tab110010.ControlMareaBuffer.al, src/Tables/Tab110013.PeriodosLiqBuffer.al, src/Tables/Tab110053.PasoCalculoLinea.al, src/Tables/Tab110034.VariableLiqTest.al]
actualizado: 2026-10-04
---

# Buffers temporales - control y consulta de liquidaciones

Tablas `TableType = Temporary`: **no persisten nada**, se arman en memoria para una página o informe y se descartan. Por eso no tienen "datos" que migrar ni respaldar. Las de este grupo sirven para mirar y controlar liquidaciones. Otros grupos: [[Buffers temporales - francos y antigüedad]], [[Buffers temporales - comparador Meta4 y auxiliares]] y [[Buffers de selección y diagnóstico (110035-110037)]].

> [!note] Por qué temporales
> Guardar el resultado obligaría a mantenerlo sincronizado con recálculos, anulaciones y borrados, y quedaría mintiendo apenas uno fallara. Reconstruirlo cuesta una lectura y no puede quedar desactualizado. Ver [[avoid-tables-principle]].

## Árbol Liquidaciones Buffer (110007)
- **Para qué:** página `Árbol de Liquidaciones` (110017). Armado por `Cod50074 Árbol Liquidaciones Liq.` (`Construir`).
- **PK:** `"Clave Orden"` (Code[100]) armada por prefijos: mes (fecha invertida, el más reciente arriba) → fecha → `<Orden>_<TIPO>` → proyecto → liquidación. Un prefijo ordena antes que sus extensiones, así el padre queda sobre sus hijos sin columna de ordenamiento extra.
- **Campos clave:** `Nivel` (0 mes, 1 fecha, 2 tipo, 3 proyecto, 4 liquidación; 3 si no se agrupa por proyecto), `Filtro Período` (Text[250]: códigos de período del nodo separados por `|`), `Cantidad`, `Total Haberes/Descuentos`, `Neto a Pagar`.
- **Trampa:** el nodo raíz agrupa por **mes** y un mes puede tener más de un código de período (mensual y aguinaldo): con un solo `Cód. Período` las acciones de lote operarían sobre la mitad de lo mostrado. Por eso existe `Filtro Período`.

## Control Marea Buffer (110010)
- **Para qué:** `Control Liquidación Marea` (110022), `Control Marea Matriz Sub` (110020), `Control Marea Difs. Sub` (110021) y `Control Liquidación Período` (110056). Lo arma `Cod50081 Control Marea Liq.` (y el export `Cod110028 Control Marea Excel Liq.`).
- **PK:** `(Sección, "No. Empleado", "Orden Cálculo", "Cód. Concepto", "No. Línea")`. `Sección` es un Option: Resumen, Detalle, Diferencia, Tripulante (las filas de tripulante las arma la propia página).
- **Campos clave:** `Cantidad`, `Base Cálculo`, `Importe`, `Empleados` (en resumen: a cuántos les salió el concepto), `Convenio/Categoría` de la **línea** vs `Convenio Empleado/Categoría Empleado` de la **cabecera**, `Importe Habitual` y `Diferencia` (apartamiento contra lo que cobró la **mayoría de la categoría**, no contra un representante).
- **Trampas:** `No. Línea` en la PK porque un concepto puede dar varias líneas al mismo empleado (el consumo de francos se abre por categoría de lote). Filtrar por categoría usa la columna del empleado, no la de la línea, para dejar afuera al tripulante entero.

## Cobertura Liq. Buffer (110013)
- **Para qué:** `Control de Cobertura Liq.` (110026), armado por `Cod110030 Control Cobertura Liq.`. Archivo `Tab110013.PeriodosLiqBuffer.al` (el nombre del archivo no coincide con el objeto).
- **PK:** `"No. Empleado"`. Una fila por empleado con totales; las columnas de días por estado son dinámicas (matriz) y las arma la página.
- **Campos clave:** `Días del Rango` (los días de alta dentro del rango, no el largo del rango), `Días con Estado`, `Días Liquidados`, `Días sin Liquidar`, `Tramos sin Liquidar`, `Días en Borrador`, `Detalle Sin Liquidar` (tramos en texto "21/07..31/07 ORDENES").
- **Trampas:** si `Días con Estado < Días del Rango` es un **agujero en el historial de estados**, problema anterior al de la liquidación; `Días en Borrador` distingue "falta crear" de "falta calcular". Usa [[Tabla - Fase Alta Empleado]] y los tramos de [[Tabla - Tramo Cobertura Liq]].

## Paso Cálculo Línea (110053)
- **Para qué:** `Detalle Cálculo Línea` (110046) y su subpágina `Pasos Cálculo Sub` (110057), armados por `Cod110044 Detalle Cálculo Línea` y `Cod110055 Presentación Cálculo Liq.` re-evaluando la fórmula guardada.
- **PK:** `"No. Paso"`.
- **Campos clave:** `Nivel` (arranca en **0**, normalizado restando el mínimo, porque `IndentationColumn` lo espera así), `Signo`, `Término`, `Descripción`, `Valor`, `Acumulado` (total corriente: convierte una lista de valores en un paso a paso), `Detalle` (auditoría, p. ej. qué tramo de TRAMO aplicó), `Es Total` (compara lo reconstruido contra el importe guardado), `Es Subtotal`, `Es Base Escala`.
- **Trampa:** como se re-evalúa, si la configuración cambió desde que se calculó la liquidación el paso a paso puede diferir del importe guardado: es lo que marca `Es Total`.

## Variable Liq. Test (110034)
- **Para qué:** catálogo de variables disponible en el asistente de fórmulas (`Asistente Fórmula Liq.`, `Variables Liq. Test Sub`, `Variables Cálculo Línea`), cargado por `Cod50060 Catálogo Variables Liq.` (`CargarCatalogo`).
- **PK:** `Nombre` (Text[100]); clave `(Tipo, Nombre)`.
- **Campos clave:** `Valor`, `Descripción`, `Tipo` (texto: Parámetro, Sistema, Fuente Datos, Acumulador; el contexto agrega Atributo — ver [[Tabla - Tipo Atributo Liq]]).

## Relacionado
[[Índice Modelo de datos (110xxx)]] · [[clear-no-vacia-temporary]] · [[setselectionfilter-tabla-temporal]]
