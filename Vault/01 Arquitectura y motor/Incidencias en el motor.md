---
tipo: concepto
tags: [motor, incidencias, novedades]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Tables/Tab60020.IncidenciaLiquidacion.al, src/Codeunits/Cod50061.GestionNovedadesLiq.al]
actualizado: 2026-10-04
---

# Incidencias en el motor

Una **incidencia** (`Incidencia Liquidación`, 60020) es un dato cargado **a mano o generado** para **un
concepto de una liquidación**: un importe y/o una cantidad. Es la vía para ajustes, retroactivos,
gratificaciones, horas extras y cuotas de préstamo. La clave primaria es `(No. Liquidación, Cód. Concepto)`:
**una incidencia por concepto por liquidación**.

De dónde salen:

| Origen | Marca |
|---|---|
| Carga manual en la ficha de la liquidación (sólo en Borrador) | — |
| Cuota de préstamo (`Gestión Préstamos`.`AplicarCuotasEnLiquidacion`) | `Cód. Cuota Préstamo` = `NoPréstamo|NoCuota` |
| Novedad pre-liquidación materializada (`Gestión Novedades Liq.`.`AplicarEnLiquidacion`) | `Desde Novedad` = true |

Cada recálculo **borra y regenera** las dos automáticas (`LimpiarParaRecalculo`) y respeta las manuales. Tocar a mano una incidencia que vino de una novedad la convierte en manual (el recálculo ya no la pisa). Ver [[novedades-pre-liquidacion]].

## Tres lecturas de una misma incidencia (`RunConceptos`)

`TieneIncidencia := (Importe <> 0) or (Cantidad = 0)`:

| Importe | Cantidad | Qué pasa |
|---|---|---|
| `<> 0` | cualquiera | el **importe cargado reemplaza a la fórmula** (se respeta el signo que tipeó la persona; antes un `Abs` descartaba la intención). La línea guarda `Cantidad`, `Unidad Cantidad` y `Base Cálculo = Valor Unitario` si hay cantidad |
| `0` | `<> 0` | la **fórmula valoriza la cantidad**: `CANT_INCIDENCIA` en el contexto vale esa cantidad mientras corre ese concepto (modo natural de cargar horas extras: "21 horas" y el concepto sabe cuánto vale la hora). Pasa por todos los filtros de aplicabilidad |
| `0` | `0` | **cero explícito: apaga el concepto** (`TieneIncidencia` = true y el importe de la línea es 0). Antes era indistinguible de "no hay incidencia" y la fórmula calculaba igual |

`Incidencia.Importe` se autocompleta como `Cantidad × Valor Unitario` si ambos están cargados; editar el importe después queda. Ver [[novedad-en-cero-no-apagaba-el-concepto]].

`CANT_INCIDENCIA` se siembra en 0 en las **dos fases** (validación y real) para que una fórmula que la use no falle con "variable desconocida", y `RunConceptos` hace `UpdateContext` sólo cuando el valor **cambia** (copia el diccionario entero).

## Se recorre en su orden

Una incidencia **fuerza** que el concepto se recorra aunque no le aplique al empleado, al convenio ni al tipo de liquidación, y **en su `Orden Cálculo`** (si no, su aporte al acumulador llegaría al final y los lectores verían un subtotal corto sin error). Con incidencia basta con que sea la **última versión** aunque esté discontinuada. Ver [[Orden de cálculo y precedencia]].

La vía de fórmula (CCT, tipo de liquidación, condición) **no se evalúa** si hay incidencia con importe: la incidencia gana. Ver [[Aplicabilidad de un concepto a una liquidación]].

## Lo que no se puede rescatar: `WriteIncidenciasRestantes`

Después del bucle, las incidencias cuyo concepto **no generó línea**:

- **Importe ≠ 0**: se escribe una línea con el concepto vigente a `FechaRef` (par de la cabecera, sin `Fórmula Aplicada`), y su aporte a acumuladores se registra como **tardío** (orden `999999999`) porque llega después de todo.
- **Sólo cantidad (importe 0)**: no hay importe que escribir (lo produce la fórmula, que no corrió). Se avisa al registro: *"Se cargó una cantidad de N en el concepto X pero el concepto no generó línea… Esa cantidad NO se pagó."*

## Las incidencias no son la vía para leer datos de una fuente

La documentación vieja sugiere una Fuente de Datos sobre `Incidencia Liquidación` con filtro `{LIQ_NO}`. Hoy el motor **lee las incidencias directamente** (buffer temporal `FIncidencias`, cargado después de materializar préstamos y novedades). Ver [[Divergencias entre documentación vieja y código]].

## Efectos sobre `#`

Con incidencia, `Ctx[código]` se llena con el importe cargado: `#CÓDIGO` devuelve el importe de la incidencia, **no** lo que habría calculado la fórmula. Reconstruir una base a partir de varios `#` funciona sólo si todos se calcularon por fórmula ([[control-precedencia-formulas]]).

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[novedad-con-proyecto-queda-huerfana]] · [[novedad-tipo-liq-y-fecha-se-pelean]] · [[novedad-proyecto-sale-del-estado]]

**Tablas relacionadas:** [[Tabla - Incidencia Liquidación]] · [[Tabla - Novedad Liquidación]] · [[Tabla - Cuota Préstamo]]
