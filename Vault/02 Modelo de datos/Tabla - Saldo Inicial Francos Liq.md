---
tipo: tabla
tags: [modelo-de-datos, francos, carga-inicial]
fuente: [src/Tables/Tab110012.SaldoInicialFrancosLiq.al, src/Codeunits/Cod110029.SaldoInicialFrancosLiq.al, src/Pages/Pag110025.SaldoInicialFrancos.al]
actualizado: 2026-10-04
---

# Tabla - Saldo Inicial Francos Liq

**Tabla 110012 `Saldo Inicial Francos Liq.`** (caption *Saldo Inicial de Francos*). **Datos persistentes** (hoja de carga).

**Propósito.** Hoja de carga del saldo de francos con el que arranca cada tripulante. Los francos ganados antes de la puesta en marcha no están en ninguna liquidación, y el ledger de francos (que vive en [[Tabla - Línea Liquidación]], sin tabla propia) sólo sabe de lo que el motor liquidó. Se llena a mano o pegando desde Excel, se revisa y **recién entonces se aplica**, generando los lotes. Es tabla y no proceso directo porque escribe en el ledger, que es plata: la carga en firme permite revisar de a dos, corregir sin deshacer, y revertir sabiendo qué se generó. Ver [[francos-fifo-ledger]].

## Clave primaria
`("No. Empleado","Cód. Convenio","Cód. Categoría","Fecha Devengo")`. Secundarias: `(Aplicado,"No. Empleado")`, `("No. Liquidación Generada")`.

Los francos **no son fungibles**: cada lote se paga al valor de la categoría en que se ganó, por eso la fila es *(empleado, convenio, categoría, fecha)* y un tripulante que ascendió necesita dos.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Empleado` | Code[20] → `Employee` | `OnValidate` completa `Nombre Empleado`. |
| `Cód. Convenio` | → [[Tabla - Convenio Colectivo]] | |
| `Cód. Categoría` | → [[Tabla - Categoría CCT]] (filtrada por convenio) | |
| `Fecha Devengo` | Date | Decide la posición del lote en la cola **FIFO**: determina a qué precio se paga el próximo franco que se tome. |
| `Días` | Decimal | |
| `Observaciones` | Text[250] | |
| `Aplicado` | Boolean (no editable) | Ya generó lote. |
| `No. Liquidación Generada`, `No. Línea Generada` | Code/Integer (no editables) | Identifican el lote exacto que salió de esta fila: es lo que hace **reversible** la carga. |
| `Valor Franco Estimado` | Decimal (no editable) | Sólo informativo para revisar; el importe real se resuelve al consumir con el `VALOR_FRANCO` vigente ese día. |

## Lógica en triggers
- `OnModify` y `OnDelete`: error si `Aplicado` (hay que revertir primero).

## Quién la lee y la escribe
- **Escribe:** página `Saldo Inicial de Francos` (110025) y `Cod110029 Saldo Inicial Francos Liq.`: `Aplicar` (una liquidación **continente** por tripulante + una línea de lote por fila; marca `Aplicado`), `Revertir`.
- **Lee:** esos mismos.

## Trampas
> [!danger] La liquidación continente no se debe poder recalcular
> `Aplicar` crea la liquidación por tripulante ya **Aprobada**, con importes en cero, sólo para que las líneas tengan cabecera. Si quedara en Borrador, el primer *Calcular por lote* que la tomara le borraría las líneas (`DeleteLineas`) y el saldo inicial de toda la empresa desaparecería sin aviso.

- La línea del lote lleva su **propia** `Fecha Liquidación` (la del lote), que puede no ser la de la cabecera.
- Borrar la fila **no** borra el lote: son dos cosas, y la segunda es plata.

## Relacionado
[[Tabla - Línea Liquidación]] · [[Buffers temporales - francos y antigüedad]] · [[francos-fifo-ledger]] · [[valor-franco-por-terna]] · [[franco-porcentaje-por-pesqueria]]
