---
tipo: proceso
tags: [dominio, prestamos, anticipos, cuotas]
fuente: [src/Codeunits/Cod50051.GestionPrestamos.al, src/Tables/Tab50575.PrestamoEmpleado.al, src/Tables/Tab50576.CuotaPrestamo.al, src/Pages/Pag50180.ListaPrestamos.al, src/Pages/Pag50181.FichaPrestamo.al, src/Pages/Pag50182.CuotasPrestamoSub.al, src/Enums/Enum50313.TipoPrestamo.al, src/Enums/Enum50314.EstadoCuotaPrestamo.al]
actualizado: 2026-10-16
---

# Préstamos y cuotas

Módulo de **préstamos y anticipos con devolución en cuotas**: se define el préstamo, se generan las cuotas y el motor las descuenta solas, como [[Incidencias|incidencias]], en la liquidación que corresponda.

> [!note] Ids de objeto
> Los archivos se llaman `Tab50575`/`Tab50576`, pero los objetos son la tabla **50579** `Préstamo Empleado` y la **50580** `Cuota Préstamo`.

## Tablas

**`Préstamo Empleado`** (50579, captions "Préstamo / Anticipo"): `No.` (serie `Cód. Serie Préstamos` de *Human Resources Setup*), `No. Empleado`, `Tipo` (enum `Anticipo` / `Préstamo`), `Fecha`, `Descripción`, `Importe Total`, `Cant. Cuotas`, **`Cód. Concepto Descuento`** (concepto de descuento con el que se descuenta), `Total Aplicado` (FlowField: suma de cuotas Aplicadas), `Observaciones`. No se puede borrar si tiene cuotas Aplicadas.

**`Cuota Préstamo`** (50580): `No. Préstamo`, `No. Cuota` (autoincremental), `Importe`, destino (`Cód. Período` **o** `No. Liquidación`), `Estado` (`Pendiente / Aplicada / Anulada`), `No. Liquidación Aplicada`, `Fecha Aplicada`. Una cuota Aplicada no se modifica.

> [!note] `Tipo` es informativo
> El enum `Anticipo / Préstamo` no lo lee ninguna regla de cálculo (verificado por búsqueda en `src/`). Lo que decide cómo se descuenta es el concepto y el destino de cada cuota.

## Ciclo de vida

```mermaid
flowchart LR
  A[Ficha préstamo] -->|Generar Cuotas| B[Cuotas Pendientes<br/>importe/N, la última absorbe el redondeo]
  B -->|motor: AplicarCuotasEnLiquidacion| C[Incidencia en Borrador<br/>Cód. Cuota Préstamo = Préstamo\|Cuota]
  C -->|Aprobar| D[Cuota Aplicada<br/>+ liquidación y fecha]
  D -->|Reabrir / Revertir Aprobación| B
```

1. **Generar Cuotas** (`GenerarCuotas`): exige empleado, importe, cantidad de cuotas y concepto de descuento. Borra las cuotas **Pendientes** existentes y las regenera en partes iguales (`Round(Importe/Cuotas, 0.01)`); la **última absorbe el redondeo**.
2. Cada cuota se asigna a un destino: **`Cód. Período`** (se descuenta en cualquier liquidación del empleado en ese período) o **`No. Liquidación`** (tiene prioridad y la ata a una). Sin ninguno, **no se aplica sola** (`CuotaAplicaALiquidacion` devuelve falso).
3. **Al calcular** (`AplicarCuotasEnLiquidacion`, sólo Borrador): por cada cuota Pendiente del empleado que corresponda crea una incidencia con `Importe = cuota` en el `Cód. Concepto Descuento`; si ya hay incidencia de ese concepto, **suma** el importe. Marca la cuota con `No. Liquidación`.
4. **Al aprobar** (`MarcarCuotasAplicadas`, desde `Gestión Liquidación.Aprobar`): las cuotas vinculadas pasan a Aplicada con liquidación y fecha.
5. **Al reabrir o revertir la aprobación** (`RevertirCuotasLiquidacion`): las cuotas vuelven a Pendiente, se liberan y se borran las incidencias de préstamo.
6. En cada **recálculo** `LimpiarParaRecalculo` limpia el estado del cálculo anterior (cuotas Pendientes enlazadas a esa liquidación, incidencias con `Cód. Cuota Préstamo`) **sin tocar las Aplicadas**, que son de liquidaciones ya aprobadas.

El motor llama a `LimpiarParaRecalculo` y `AplicarCuotasEnLiquidacion` **antes** de las novedades: así una cuota cuenta como incidencia manual y una novedad del mismo concepto se saltea en vez de duplicar (ver [[Novedades pre-liquidación]]).

Si además existe una novedad por el mismo movimiento, verificar cuota, importe,
período y destino antes de retirarla. El procedimiento y las precauciones para
conservar recibos están en [[novedad-duplicada-por-cuota-de-prestamo]].

> [!warning] Recálculo por lote con liquidaciones ya calculadas
> `AplicarCuotasEnLiquidacion` sólo actúa en Borrador, pero un recálculo por lote puede llegar a una liquidación Calculada o Aprobada. El motor la vuelve a Borrador antes de aplicar; sin eso las cuotas se saltearían en silencio en cualquier recálculo que no pase por *Reabrir*.

## Anticipos: no son lo mismo

Los **anticipos de poder / llegada / haberes** (4803, 4813, 4823) **no usan este módulo**: son [[anticipos-como-novedades]] sin fórmula; sus descuentos (8830/8840/8850) se cargan como novedades. Y el anticipo en sí **no es un haber del recibo** ([[anticipo-no-es-haber-del-recibo]]; 897 novedades anuladas el 28/9/2026).

Lo que sí es un préstamo en cuotas es **AHA** de Meta4 (`M4T_CTA_CTE_ANTICIPOS`, tierra,
cuotas mensuales): corresponde a `Préstamo Empleado` + `Cuota Préstamo`, concepto **8870**.
Los cuatro anticipos con descuento en febrero fueron cargados/completados el 12/10/2026:
[[prevuelo-febrero-2026-migracion-meta4]]. Se importan los vencimientos conocidos; no se
regenera un plan en partes iguales cuando Meta4 tiene cuotas distintas ni se inventa el saldo.

## Pantallas

`Lista Préstamos Empleado` (50180; también en la ficha/lista de empleados y el Role Center) · `Ficha Préstamo Empleado` (50181, con la acción *Generar Cuotas*) · `Cuotas Préstamo Sub` (50182, con *Anular* / *Reactivar*).

Tablas: [[Tabla - Préstamo Empleado]], [[Tabla - Cuota Préstamo]]. Relacionadas: [[Incidencias]], [[Índice Dominio - marea y pagos]].
