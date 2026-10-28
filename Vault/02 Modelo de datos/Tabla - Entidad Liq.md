---
tipo: tabla
tags: [modelo-de-datos, entidades, buques]
fuente: [src/Tables/Tab110008.EntidadLiq.al, src/Codeunits/Cod50075.GestionEntidadesLiq.al, src/Pages/Pag110018.Entidades.al]
actualizado: 2026-10-04
---

# Tabla - Entidad Liq

**Tabla 110008 `Entidad Liq.`** (caption *Entidad*). **Datos persistentes.**

**Propósito.** La entidad operativa: un buque, una planta de proceso, una administración. Su código es **siempre** el del valor de dimensión (dimensión global 1) del que nace; esa igualdad sostiene el resto: los proyectos se vinculan al buque por `Job."Global Dimension 1 Code"`, y los estados y atributos guardan ese mismo string.

## Clave primaria
`Código` (Code[20], `TableRelation = "Dimension Value".Code`, no editable). Secundaria: `("Cód. Clase", Código)`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Descripción` | Text[100] | |
| `Cód. Clase` | Code[20] → [[Tabla - Clase Entidad Liq]] | Obligatoria. Define qué atributos le corresponden. |
| `Cant. Atributos` | FlowField Count | Filas de [[Tabla - Atributo Entidad Liq]] con ese `Cód. Entidad`. |

## Lógica en triggers
- `OnInsert`: `TestField("Cód. Clase")` y `ValidarValorDimension` (el valor debe existir en la dimensión global 1 de `General Ledger Setup`; si no, la entidad nacería huérfana).
- `OnDelete`: error si tiene atributos cargados.

## Quién la lee y la escribe
- **Escribe:** `Cod50075 Gestión Entidades Liq.` (`ObtenerOCrear` ofrece crearla exigiendo clase) y página `Entidades` / `Ficha Entidad`.
- **Renombrado:** `Cod50075` se suscribe a `OnAfterRenameEvent` de `Dimension Value` y arrastra el código viejo al nuevo en entidad, atributos, **estados** (`Estado Empleado`) y `Personal Proyecto`.
- **Lee:** `Cod50017 Gestión Estado Empleado` (alta masiva de estado por entidades, `SetEstadoEnLoteEntidades`), páginas `Buques` (50191), reporte `Asignar Atributo Masivo`, tableextension `Clase en Dimension Value`.

## Trampas
> [!danger] Renombrar el valor de dimensión sin el arrastre deja histórico invisible
> Si el arrastre no ocurre no falla nada: el histórico del buque y sus atributos quedan colgando del código viejo, y la entidad nueva aparece sin historia. Por eso la entidad no se renombra sola; se renombra el valor de dimensión y el suscriptor hace el cascade.

- No se da de alta suelta: siempre desde el valor de dimensión.
- La entidad Empleado y la entidad Proyecto **no** pasan por esta tabla: `Atributo Entidad Liq.` guarda `Cód. Entidad` sin relación y resuelve por `Tipo Entidad`.

## Relacionado
[[Tabla - Clase Entidad Liq]] · [[Tabla - Atributo Entidad Liq]] · [[Tabla - Estado Empleado]] · [[estado-empleado-effective-dated]] · [[veda-como-atributo-del-buque]]
