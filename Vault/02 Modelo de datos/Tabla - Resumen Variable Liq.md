---
tipo: tabla
tags: [modelo-datos, transaccional, recibo]
fuente: [src/Tables/Tab60024.ResumenVariableLiq.al]
actualizado: 2026-10-24
---

# Tabla - Resumen Variable Liq. (60024)

## Propósito
**Variables a nivel de liquidación** (no de línea) guardadas al terminar el cálculo, para auditar y para imprimir en el recibo (días trabajados, obra social, sindicato, fechas…). Es la versión "por liquidación" de [[Tabla - Detalle Variable Línea Liq]].

## PK
`No. Liquidación` + `Nombre Variable` (clustered).

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` (1) | → `Liquidación."No."` | |
| `Nombre Variable` (2) | Code[30] | |
| `Etiqueta` (3) | Text[100] | Etiqueta de recibo (de la fuente/variable) |
| `Valor` (4) | Decimal | La proyección **numérica** con que calculó la fórmula |
| `Valor Texto` (6) | Text[250] | El valor **original** cuando la fuente declara un tipo no numérico (p. ej. "126205 - OSECAC") |
| `Mostrar en Recibo` (5) | Boolean | Copiado de la fuente al guardar, para que el recibo imprima sólo lo destinado a eso |
| `Moneda` (7) | Code[10] | Sólo en las cotizaciones (`TC_*`): la moneda del tipo de cambio con el que se calculó (`FMoneda`, una sola por liquidación) |
| `Fecha Cotización` (8) | Date | Sólo en las cotizaciones: la fecha a la que se pidió (`FechaTipoCambio`: final al egreso, cierre al último día que cubre, o la novedad `FECHA_TC`) |

## Procedimiento
`ValorParaMostrar()`: `Valor Texto` si existe; si no, `Format(Valor, 0, '<Precision,2:2><Standard Format,0>')`.

## Triggers
Ninguno.

## Quién la lee / escribe
Escribe `Cod50014.MotorLiquidacion` (usa una copia temporal y luego persiste); lee `Cod110028.ControlMareaExcelLiq`, `Cod50081.ControlMareaLiq`. Página `Pag50177 Resumen Variable Liq Sub`. Alimentada por [[Tabla - Fuente Datos Liquidación]] y [[Tabla - Variable Sistema Liq]] con `Mostrar en Recibo`.

## Vigencias
No tiene.

## Trampas conocidas
Con **dos** valores conviviendo (`Valor` y `Valor Texto`) hay que acordarse de que son dos preguntas distintas: con qué se calculó y qué hay que imprimir. Ver [[atributos-tipados]].

## Qué NO se guarda (desde el 24/10/2026)
`SaveResumenVariables` **omite** un parámetro cuando se cumplen las cuatro: (1) su versión quedó registrada en [[Tabla - Uso Parámetro Liq]] en ese mismo cálculo, (2) esa versión está en pesos o sin moneda, (3) el valor del contexto es exactamente el `Valor` de la versión, (4) no es de recibo ni de texto ni una cotización. Era el 40 % de las filas (141.780 de 350.622 al 23/10/2026). Cualquier otro caso se guarda como siempre; las liquidaciones calculadas antes conservan el resumen completo.

**Para leerlo completo no se usa `Get` sobre esta tabla**: se pasa por el codeunit `Variables Guardadas Liq.` (`Cod110093`): `Cargar` (todas, en un buffer temporal), `Obtener` (una) y `CargarOmitibles` (lo usa el motor). Lo usan el control de marea (`ConstruirVariablesComunes`), `ACUM_PARAM_CCT` (cantidad y TC históricos) y la subpágina de la ficha (`Pag50177`, que ahora es temporal y se carga desde `OnAfterGetCurrRecord` de la ficha). Si un lector nuevo hace `Get` directo, un parámetro de convenio le va a aparecer como ausente.

No se dejó de guardar la `Etiqueta` (la idea inicial): ahorra poco y obligaba a cambiar todos los lectores.

## El tipo de cambio de un cálculo
Las cotizaciones `TC_COMPRADOR`/`TC_VENDEDOR` quedan con `Moneda` y `Fecha Cotización`. El ledger de francos (`Movimiento Franco Liq.`) **no** lleva valor ni cotización: valúa con las `TC_*` del contexto de la liquidación (`PublicarTiposCambio`), o sea las mismas que quedan acá. Límite conocido: el motor resuelve **una** moneda por liquidación (`FMoneda`, la de la primera fila de parámetro en divisa), así que una liquidación con USD y EUR sólo guarda la cotización de una.
