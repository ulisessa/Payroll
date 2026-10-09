---
tipo: tabla
tags: [modelo-datos, convenios-cct]
fuente: [src/Tables/Tab60006.CategoriaCCT.al]
actualizado: 2026-10-04
---

# Tabla - Categoría CCT (60006)

## Propósito
Categorías de cada convenio (Capitán, Primer Cocinero, MR05, OF03…). Hijo de [[Tabla - Convenio Colectivo]]. La categoría "paga el sueldo"; el **puesto** (otro eje) "paga la producción" y reutiliza esta misma tabla vía el espejo `Puesto` ([[puesto-vs-categoria-cct]]).

> [!note] IDs
> No existen las tablas 60001, 60002 ni 60005 en el repo (huecos de numeración).

## PK
`Cód. Convenio` + `Código`, clustered. DropDown: Código, Descripción, % Escala.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Convenio` (1) | Code[20] | TableRelation → `Convenio Colectivo.Código` |
| `Código` (2) | Code[20] | Código de categoría (único sólo dentro del convenio) |
| `Descripción` (3) | Text[100] | NotBlank |
| `% Escala` (4) | Decimal (0:4, 0–999,9999) | Índice de la escala salarial de la categoría (ver [[escala-somu-indice-70]]) |
| `Observaciones` (5) | Text[250] | Libre |

## Triggers
Delegan en `Espejo Atributos Liq.` (`Cod50078`): `AlEscribirCategoria` (insert/modify), `AlRenombrarCategoria`, `AlBorrarCategoria`. La copia al valor del atributo es campo a campo porque las dos tablas tienen la misma forma (el convenio es el valor padre).

`OnRename`: **prohíbe cambiar `Cód. Convenio`** (mover una categoría de convenio cambiaría el padre y el historial de los empleados); sólo permite renombrar el código.

## Quién la lee
`Cod50080.ConvenioCategoriaLiq`, `Cod50014`, `Cod50016`, `Cod50053.GestionFrancos`, `Cod110028`, `Cod110029`, `Cod50078`. Referenciada por [[Tabla - Parámetro Vigente]], [[Tabla - Concepto CCT Vigente]], [[Tabla - Liquidación]], [[Extensión - Employee]], `Tab110003`, `Tab110012`, `Tab110038`. Página: `Pag50106 Categorías CCT`.

## Vigencias
Sin vigencia. Los valores por categoría (sueldos, adicionales) viven en [[Tabla - Parámetro Vigente]] con convenio+categoría.

## Trampas conocidas
- Una misma categoría con dos significados según convenio (OF01/OF03 vs OF02/OF04): [[convenio-of-depende-de-la-categoria]].
- Mover una categoría de convenio exige crear la nueva y cargar la vigencia en cada empleado: [[atributos-tipados]].
