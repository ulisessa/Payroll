---
tipo: tabla
tags: [modelo-de-datos, meta4, historia, archivo]
fuente: [src/Tables/Tab110054.HistLiqMeta4.al, src/Pages/Pag110047.HistoriaLiqMeta4.al, src/Pages/Pag110051.CompararBCMeta4.al, METODO_COMPARACION_META4_BC.md]
actualizado: 2026-10-04
---

# Tabla - Hist. Liq. Meta4

**Tabla 110054 `Hist. Liq. Meta4`** (*Historia de Liquidaciones Meta4*). **Datos persistentes** (archivo de solo lectura en la práctica; ~485.000 cabeceras).

**Propósito.** Cabecera de un **archivo literal** de liquidaciones de Meta4: no se interpreta, no se mapea a conceptos de BC y **no lo lee el motor de cálculo**. Existe para abrir un recibo de 2003 cuando ANSES pide una certificación de servicios o llega una demanda, y para poder apagar Meta4. Detalle en [[Tabla - Valor Hist. Meta4]], catálogo de columnas en [[Tabla - Columna Hist. Meta4]].

> [!note] No es la historia que usa BC
> La historia que BC calcula vive en [[Tabla - Liquidación]] + [[Tabla - Línea Liquidación]]; las Fuentes de Datos y el recibo sólo leen esas dos. Nada de acá alimenta un promedio ni una antigüedad. Mezclar ambas en una estructura fue la primera idea y es la que hay que evitar: una necesita los bytes originales sin tocar, la otra códigos de concepto de BC. Para la historia de remuneraciones que **sí** alimenta cálculos ver [[historia-remuneraciones-migrada]].

**Por qué no se replican las 5 tablas de Meta4.** `M4T_ACUMULADO_RL` a `RL5` comparten la misma PK: son una fila partida en cinco porque Oracle no admite más de 1.000 columnas. Sumadas dan 1.818 columnas y SQL Server tiene un límite duro de 1.024 columnas por tabla (y ~31 KB por fila contra 8.060 bytes). Y una fila real tiene ~250 valores no nulos de 1.759 columnas numéricas (86% ceros).

## Clave primaria
`"No. Entrada"` (Integer, `AutoIncrement`): sustituto entero de la clave natural de Meta4 (cinco campos); arrastrar esos cinco campos al detalle de ~117 millones de filas costaría ~5 GB. Secundarias: `PorEmpleado ("No. Empleado","Fecha Imputación","Fecha Pago")`, `PorFecha`, `PorAnio (Año, Mes)`, `PorMarea ("Cód. Buque Meta4","No. Marea Meta4")`, `PorEmpMes ("No. Empleado",Año,Mes,"Contador Liq.")`.

## Campos relevantes
| Campo | Origen Meta4 | Propósito |
|---|---|---|
| `Cód. Sociedad`, `Cód. Empresa Meta4` | ID_SOCIEDAD | |
| `No. Empleado` | ID_EMPLEADO | `TableRelation = Employee` con **`ValidateTableRelation = false`**: hay 31 años de historia y gente que ya no está en el padrón. |
| `Fecha Alta Empleado` | FEC_ALTA_EMPLEADO | Parte de la clave en Meta4; un reingreso genera otra serie. |
| `Fecha Imputación`, `Fecha Pago`, `Año`, `Mes` | FEC_IMPUTACION, FEC_PAGO | `Año`/`Mes` derivados y guardados (filtro por año es la consulta más frecuente). |
| `Tipo Imputación` | TP_IMPUT | Número crudo: 4 anticipos, 99 indemnizaciones puras, 14 liquidaciones finales, 3 vacaciones, 1 la corrida más frecuente (deducido por perfilado, no de una tabla de dominio). |
| `Contador Liq.` | CONTADOR_LIQ | **El orden real de las corridas**, que no coincide con la fecha. |
| `Cód. Convenio Meta4` | ID_CONVENIO | Códigos de Meta4 (MR, OF, FA, CA, FE, EC), **no** los de BC (175/75, 729/15). |
| `Cód. Buque Meta4`, `No. Marea Meta4` | ID_BUQUE, ID_MAREA (de RL3) | **La marea que esa corrida paga**, no la que el tripulante tiene en curso. |
| `Apellido Empleado`, `Nombre Empleado` | — | FlowFields al padrón **actual**; quedan vacíos para quien ya no está. |

## Lógica en triggers
Ninguna.

## Quién la lee y la escribe
- **Escribe:** carga masiva por fuera de AL (Oracle → SQL Server). *Sin verificar:* el script de carga de la historia no figura en `scripts/` del repo.
- **Lee:** páginas `Historia Liq. Meta4` (110047), `Ficha Hist. Liq. Meta4` (110048), `Valores Hist. Meta4` (110049), `Comparar BC contra Meta4` (110051) y `Detalle Comp. Meta4` (110052).
- **Permisos:** no figura en ninguno de los tres PermissionSets (verificado): sólo accede un SUPER.

## Vigencias
No aplica (archivo histórico).

## Trampas
> [!warning] Agregado por mes engaña
> Un tripulante con cuatro corridas en enero tiene tres mareas distintas (la 58 en la corrida de puerto, la 59 en el cierre, la 60 en la mensual); tomar el máximo o la última da la que no es. `No. Marea Meta4` sólo vale fila por fila.

> [!warning] El orden lo da el Contador, no la fecha
> El legajo 03774 en enero 2026 tiene la corrida del día 19 con contador 6 y la del día 6 con contador 7. `TOT_REMUN_27617` es un acumulado corrido: el aporte de cada corrida es su valor menos el de la anterior **por contador** ([[tot-remun-27617-es-acumulador]]).

- Códigos de convenio y buque son los de Meta4: no se pueden cruzar con BC sin traducir ([[equivalencia-id-puesto-meta4]]).
- Origen Oracle: [[meta4-es-oracle]], [[meta4-conectar-desde-powershell]].

## Relacionado
[[Tabla - Valor Hist. Meta4]] · [[Tabla - Columna Hist. Meta4]] · [[Buffers temporales - comparador Meta4 y auxiliares]] · [[comparar-columna-contra-total]] · [[Mapa del modelo de datos - atributos, novedades, francos y sincronización]]
