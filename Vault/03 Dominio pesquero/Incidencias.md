---
tipo: tabla
tags: [dominio, incidencias, novedades, motor]
fuente: [src/Tables/Tab60020.IncidenciaLiquidacion.al, src/Pages/Pag50148.IncidenciasLiquidacionSub.al, src/Codeunits/Cod50014.MotorLiquidacion.al]
actualizado: 2026-10-04
---

# Incidencias

Una **incidencia** (`Incidencia Liquidación`, tabla 60020) es un dato manual **de una liquidación puntual** para un concepto: ajustes, retroactivos, gratificaciones, horas extras, descuentos. Se ve en la subpágina `Incidencias Liquidación Sub` de la ficha de liquidación.

PK: `(No. Liquidación, Cód. Concepto)` — **una sola fila por concepto y liquidación**. De ahí que varias [[Novedades pre-liquidación|novedades]] del mismo concepto se **sumen**.

## Campos

`Importe` · `Cantidad` · `Unidad Cantidad` · `Valor Unitario` · `Observaciones` · y dos marcas de origen que identifican quién generó la fila:

| Marca | Quién la escribe | Qué permite |
|---|---|---|
| `Cód. Cuota Préstamo` (`"No.Prestamo\|NoCuota"`) | [[Préstamos y cuotas]] | borrarla y regenerarla en cada recálculo |
| `Desde Novedad` | `Gestión Novedades Liq.` | idem para novedades; **tocarla a mano la apaga** (`OnModify`) y desde ahí la respeta el recálculo |
| ninguna | una persona o [[Incidencias masivas]] | se respeta siempre |

`Importe = Cantidad × Valor Unitario` se autocompleta cuando ambos están cargados; si después se edita el importe, esa edición queda hasta que se vuelva a validar cantidad o valor unitario.

**Sólo se puede insertar, modificar o borrar con la liquidación en Borrador** (`ValidarEstadoBorrador`). Para corregir una aprobada hay que reabrirla.

## Cómo la lee el motor (`Cod50014`)

`CargarIncidencias` copia las incidencias de la liquidación a un buffer en memoria; el motor consulta `Incid.Get(Liq."No.", Concepto.Código)` por cada concepto.

```text
TieneIncidencia := (Incid.Importe <> 0) or (Incid.Cantidad = 0)
```

| Importe | Cantidad | Resultado |
|---|---|---|
| ≠ 0 | – | `Importe` de la incidencia **reemplaza** la fórmula; **se respeta el signo** cargado (una persona tipeó un negativo porque quiso un negativo) |
| 0 | ≠ 0 | la fórmula corre y puede leer `CANT_INCIDENCIA` (horas extras) |
| 0 | 0 | **cero explícito**: la línea sale en cero y la fórmula no se evalúa |

- Una incidencia **fuerza el concepto a recorrerse en su Orden Cálculo** aunque no le aplique al tipo de empleado ni al convenio, y alcanza con que la versión sea la **última** aunque esté discontinuada. Relegar el aporte al final haría que los conceptos que leen el acumulador ya lo hubieran leído (importe corto sin error) — ver [[acumuladores-orden-calculo]].
- `WriteIncidenciasRestantes` rescata las incidencias **con importe** cuyo concepto no generó línea; una de **sólo cantidad** no se puede rescatar (el importe lo produce la fórmula) y se **avisa** en el registro del cálculo: alguien cargó 21 horas y no se pagaron.
- Una línea escrita por esa vía llega tarde por definición: se registra explícitamente como aporte fuera de orden (`RegistrarAporteFueraDeOrden`).
- En una Fuente de Datos se puede leer por el token `{LIQ_NO}`: filtro 1 `No. Liquidación = {LIQ_NO}`, filtro 2 `Cód. Concepto = <literal>`, función `LOOKUP`, campo `Importe` → variable `INCID_<concepto>` (ej. `INCID_VACACIONES`).

> [!warning] Una novedad se materializa como incidencia sólo si ninguna manual la pisa
> Si la liquidación ya tenía una incidencia manual (o de préstamo) del concepto, la novedad **no la pisa**: queda Pendiente con `Motivo No Aplicada`. Es a propósito, pero obliga a mirar el motivo.

Tablas: [[Tabla - Incidencia Liquidación]]. Relacionadas: [[Incidencias masivas]], [[novedad-en-cero-no-apagaba-el-concepto]], [[Tabla - Línea Liquidación]], [[Índice Dominio - marea y pagos]].
