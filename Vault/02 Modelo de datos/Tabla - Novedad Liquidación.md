---
tipo: tabla
tags: [modelo-de-datos, novedades, pre-liquidacion]
fuente: [src/Tables/Tab110038.NovedadLiquidacion.al, src/Codeunits/Cod50061.GestionNovedadesLiq.al, src/Pages/Pag50013.NovedadesLiquidacion.al, src/Pages/Pag110027.NovedadesLiqSub.al]
actualizado: 2026-10-04
---

# Tabla - Novedad Liquidación

**Tabla 110038 `Novedad Liquidación`**. **Datos persistentes.**

**Propósito.** Carga de novedades **antes** de que exista la liquidación. Su contrapartida, `Incidencia Liquidación` (Tab60020), está clavada por `No. Liquidación` y obliga a crear primero la liquidación en Borrador; acá se carga contra el **período** y el motor la materializa como incidencia al calcular (igual que las cuotas de préstamo). Ver [[novedades-pre-liquidacion]].

## Clave primaria
`"No. Movimiento"` (Integer, `AutoIncrement`). Secundarias: `("Cód. Período",Estado)`, `("Cód. Período","No. Empleado","Cód. Concepto")`, `("No. Liquidación")`, `("Novedad Origen","Cód. Período")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Período` | Code[10] → [[Tabla - Período Liquidación]] | Obligatorio; rechaza períodos **Cerrados**. Al validarlo propone `Fecha` = fin de período. |
| `Fecha` | Date | Debe caer dentro del período. Decide a qué liquidación entra si el empleado tiene más de una en el período. |
| `Cód. Tipo Liq.`, `Cód. Convenio`, `Cód. Categoría`, `No. Empleado`, `No. Proyecto` | Code | **Selectores**: en blanco = "cualquiera". Una misma novedad sirve para un empleado o para toda una categoría. |
| `Cód. Concepto` | Code[20] → [[Tabla - Concepto Liquidación]] | |
| `Cantidad`, `Unidad Cantidad`, `Valor Unitario`, `Importe` | Decimal/Code | `Importe` se recalcula como `Cantidad × Valor Unitario` (redondeo 0,01) al validar cantidad o valor; una edición manual posterior del importe manda hasta volver a validar. |
| `Estado` | Enum `Estado Novedad Liq.` | Pendiente / Aplicada / Anulada (no editable). |
| `No. Liquidación` | Code[20] → [[Tabla - Liquidación]] | Dónde entró (no editable). |
| `Motivo No Aplicada` | Text[250] | Por qué el motor la salteó (en lote no hay dónde mostrar un mensaje). |
| `Recurrente`, `Períodos Restantes`, `Novedad Origen` | Boolean/Integer | Recurrencia: `Períodos Restantes > 0` fuerza `Recurrente`; 0 con Recurrente = indefinida. `Novedad Origen` es la raíz de la cadena (evita generar el período siguiente dos veces). |

**Semántica del importe** (comentario en el campo): `Importe <> 0` reemplaza a la fórmula; `Importe = 0` y `Cantidad <> 0` la fórmula valoriza la cantidad (horas extras); `Importe = 0` y `Cantidad = 0` es **cero explícito**: el concepto no paga y la fórmula ni se evalúa (es la forma de apagar un concepto para un empleado).

## Lógica en triggers
- `OnInsert`: `ValidarEditable` + exige período. `OnModify`/`OnDelete`: `ValidarEditable` — error si el período está Cerrado o si ya se aplicó en una liquidación que **no** está en Borrador (hay que reabrirla).
- `OnValidate No. Empleado`: copia el nombre y propone convenio/categoría con `ParDeEntidad` (los **atributos vigentes** a la fecha, no la ficha), sólo si ambos campos están vacíos; la ficha queda de red.
- `OnValidate Cód. Convenio`: limpia la categoría.
- `OnValidate No. Proyecto`: propone `Fecha` = el menor entre el arribo del proyecto (`Job."Ending Date"`) y el fin del período, siempre dentro del período.

## Quién la lee y la escribe
- **Escribe:** páginas `Novedades Liquidación` (50013) / `Novedades Liq. Sub` (110027) / `Ficha Liquidación` (50117); `Cod50061 Gestión Novedades Liq.`: `AplicarEnLiquidacion` (sólo Borrador; acumula por concepto, materializa en `Incidencia Liquidación` y marca), `LimpiarParaRecalculo` y `RevertirLiquidacion` (vuelven a Pendiente y vacían `No. Liquidación`), `AnularNovedad`/`ReactivarNovedad`, `CopiarDePeriodo`, `GenerarRecurrentes`, `ImportarArchivo` (Excel/CSV).
- **Invoca:** el motor `Cod50014`, donde ya se enganchan las cuotas de préstamo.
- **Lee:** además, `Concepto Liquidación` la referencia.

## Vigencias
Por período + fecha, no effective-dated.

## Trampas
> [!warning] Convenio/categoría filtran sólo las novedades colectivas
> `NovedadAplica` compara convenio y categoría **solamente cuando no hay empleado**. Con empleado son dato, no condición. Si el par no coincide en una colectiva, la novedad no entra: sin error, sin motivo y mostrándose igual en la hoja.

> [!warning] Con Cód. Tipo Liq. cargado, la Fecha no filtra
> La comparación de fecha contra la cobertura sólo corre si `Cód. Tipo Liq.` está en blanco (tipo explícito gana). Ver [[novedad-tipo-liq-y-fecha-se-pelean]].

> [!warning] Novedad con proyecto sólo entra en liquidaciones de ESE proyecto
> Si el empleado no tiene (aún) una liquidación de esa marea, queda huérfana sin aviso: [[novedad-con-proyecto-queda-huerfana]] y [[novedad-estado-apunta-a-proyecto-sin-liquidar]].

> [!warning] Rango de aplicación = cobertura guardada
> `CalcularRangoLiquidacion` usa `Cobertura Desde/Hasta` de la cabecera (escritos por [[Tabla - Tramo Cobertura Liq]] / el motor antes de aplicar novedades). Sin eso, mensual y vacaciones aceptarían la misma novedad y gana la de menor orden. Ver [[ventana-liquidacion-es-cobertura]].

- Si ya existe una `Incidencia Liquidación` del mismo concepto cargada a mano (o por préstamos), la novedad **no la pisa**: queda Pendiente con `Motivo No Aplicada` y se anota una advertencia en el registro de proceso. Dos novedades del mismo concepto se **suman** (una incidencia por concepto y liquidación).
- En una novedad colectiva `No. Liquidación` guarda sólo **la última** liquidación que la tomó; el rastro por liquidación está en las incidencias marcadas `Desde Novedad`.
- Novedad con todo en cero (cantidad 0, importe 0): es el *cero explícito* que apaga el concepto; antes quedaba Aplicada y la fórmula corría igual ([[novedad-en-cero-no-apagaba-el-concepto]]).
- Bucle `LimpiarParaRecalculo` junta claves primero porque modifica el campo filtrado ([[bucle-modifica-campo-filtrado]]).
- Anticipos: sin fórmula a propósito ([[anticipos-como-novedades]]). Proyecto de la novedad: [[novedad-proyecto-sale-del-estado]].

## Relacionado
[[Tabla - Período Liquidación]] · [[Tabla - Liquidación]] · [[Tabla - Concepto Liquidación]] · [[novedades-pre-liquidacion]] · [[migracion-novedades-meta4]] · [[Mapa del modelo de datos - atributos, novedades, francos y sincronización]]
