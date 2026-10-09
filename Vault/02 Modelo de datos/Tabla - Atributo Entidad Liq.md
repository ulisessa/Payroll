---
tipo: tabla
tags: [modelo-de-datos, atributos, vigencias, effective-dated]
fuente: [src/Tables/Tab110005.AtributoEntidadLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50073.PlantillaAtributosLiq.al, src/Codeunits/Cod50079.AltaAtributoEntidadLiq.al]
actualizado: 2026-10-04
---

# Tabla - Atributo Entidad Liq

**Tabla 110005 `Atributo Entidad Liq.`** (caption *Atributo de Entidad*). **Datos persistentes**, con historial (*effective-dated*).

**Propósito.** El valor de un atributo para una entidad (empleado, buque o proyecto), con vigencias. Las reglas de vigencia son las mismas que en `Concepto Liquidación` y que en el historial de estados ([[estado-empleado-effective-dated]]). Es la tabla donde viven hoy el **convenio y la categoría** del empleado (atributos CONVENIO y CATEGORIA), la veda del buque, sindicato, obra social, etc.

## Clave primaria
`("Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde")`. Secundarias: `("Cód. Tipo Atributo","Cód. Entidad","Vigencia Desde")` (la usa la lectura del motor) y `("Tipo Entidad","Cód. Entidad","Vigencia Desde")` (ordena la ficha por fecha sin el tipo en el medio).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Tipo Entidad` | Enum `Tipo Entidad Estado` | Empleado / Buque / Proyecto. |
| `Cód. Entidad` | Code[20] | **Sin `TableRelation`**: apunta a `Employee`, valor de dimensión (buque) o `Job` según el tipo. Mismo criterio que `Estado Empleado."Cód. Entidad"`. |
| `Cód. Tipo Atributo` | Code[20] → [[Tabla - Tipo Atributo Liq]] | |
| `Vigencia Desde` / `Vigencia Hasta` | Date | Hasta vacío = abierta. Desde es parte de la clave. |
| `Cód. Valor` | Code[20] | Para tipo Lista. Sin `TableRelation` (se valida a mano por el padre). |
| `Valor Decimal`, `Valor Texto`, `Valor Fecha` | Decimal/Text[250]/Date | Una columna por tipo de dato; `OnValidate` rechaza la columna equivocada. |
| `Valor Numérico` | Decimal (no editable) | **Congelado al asignar**: lo que lee el motor. Lista → el del valor; Decimal/Entero → `Valor Decimal`; Texto → 1 si hay texto, 0 si no; **Fecha → 0 siempre**. |
| `Cód. Valor Padre` | Code[20] (no editable) | Derivado, nunca tipeado: el valor que la entidad tenía en el atributo **padre** al arrancar esta vigencia (o el padre del valor elegido si el tipo tiene `Padre Según el Valor`). Desambigua `OF01` de 175/75 contra `OF01` de 768/19. |
| `Descripción Valor`, `Tipo Dato` | FlowFields | Lookups a [[Tabla - Valor Atributo Liq]] y [[Tabla - Tipo Atributo Liq]]. |

## Lógica en triggers
- `OnInsert`: exige `Vigencia Desde`, `ValidarYaExiste` (error legible en vez de "registro duplicado"), `ValidarIntervalo`, `ValidarNoSuperponeConAnterior`, `SincronizarContiguidad`, `ValidarNoPisaSiguiente`, `ResolverValorPadre`, `ValidarValorExiste`, `RecalcularValorNumerico`.
- **Cierre automático:** al insertar, si la versión anterior está **abierta**, se cierra el día previo; si ya tenía fecha de fin se respeta (el hueco es una decisión: baja en marzo y vuelve a hacer falta en julio). Si la fila nueva queda sin fin y existe una posterior, se cierra contra ella.
- `OnModify`: sólo revalida si cambió `Vigencia Hasta`.
- `OnDelete`: `ReabrirAnteriorAlBorrar` — reabre (o recorta contra la siguiente) la vigencia anterior **sólo si la había cerrado esta fila** (`Hasta = Desde - 1`); una fecha puesta a mano no se toca.
- **`Vigente(CodTipo, TipoEntidad, CodEntidad, FechaRef)`**: *la regla temporal del sistema en un solo lugar* — última vigencia con `Desde <= FechaRef` y `Hasta = 0D o >= FechaRef`. Sin entidad, tipo o fecha devuelve false (no filtra a todas las entidades). La usan el motor y la página.
- `ValorVigente`, `VigenteA`, `ValorPadreVigente`, `ValorParaMostrar`.

## Quién la lee y la escribe
- **Lee:** `Cod50016 Contexto Liquidación` (`LoadAtributos` → `AtributoVigente` → `Vigente(..., FFechaRef)`; el buque se resuelve desde `Job."Global Dimension 1 Code"`), `Cod50018 Proceso Liq. por Lotes`, `Cod50053 Gestión Francos`, `Cod50080 Convenio Categoría Liq.`, `Cod50078`, páginas `Atributos de Entidad`, `Atributos Entidad Sub`, FactBox y `Entidades`.
- **Escribe:** páginas de atributos, `Cod50073 Plantilla Atributos Liq.` (crea filas vacías de los obligatorios), `Cod50079 Alta Atributo Entidad Liq.` (inserta en su propio ámbito de transacción para altas masivas), reportes `Asignar Atributo Masivo` y `Migrar Convenio y Categoría`, y `Cod50075 Gestión Entidades Liq.` (renombra el `Cód. Entidad` cuando se renombra el valor de dimensión).

## Vigencias
Historial contiguo. **Sin red hacia adelante**: un atributo que empieza después del cierre del período no rige en ese período (adivinar escondería una carga mal fechada).

## Trampas
> [!warning] Fecha de referencia, no "hoy"
> El padre y el valor se resuelven a la fecha de *esa vigencia* y de *la liquidación* (`FFechaRef`). El par (convenio, categoría) de enero sigue siendo el de enero aunque el convenio cambie en julio.

> [!warning] El Valor Numérico queda congelado
> Cambiar el número del valor en la lista no reescribe lo asignado (a propósito).

> [!warning] Atributo de tipo Fecha vale 0 en el Valor Numérico
> Los días dependen de la fecha de referencia de cada liquidación; los calcula la Fuente de Datos declarada como Fecha, no esta tabla.

- Un `Cód. Entidad` renombrado sin el arrastre queda huérfano sin error: ver `Cod50075`.
- Cuando el mismo código existe bajo dos padres y se escribe a mano, `PadreDelValorElegido` corta con error de ambigüedad: hay que elegirlo desde la lista.
- Comparar un atributo de lista por código en una fórmula: ver [[atributo-comparar-por-codigo]].

## Relacionado
[[Tabla - Tipo Atributo Liq]] · [[Tabla - Valor Atributo Liq]] · [[Tabla - Entidad Liq]] · [[Tabla - Estado Empleado]] · [[atributos-tipados]] · [[migracion-atributos-cct-meta4]] · [[sindicato-obra-social-atributos]] · [[tres-capas-fase-estado-asignacion]]
