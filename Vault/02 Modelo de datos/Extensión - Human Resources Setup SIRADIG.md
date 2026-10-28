---
tipo: tabla
tags: [modelo-datos, extension, siradig]
fuente: [src/TableExtensions/TabExt52004.HRSetupSiradigExt.al]
actualizado: 2026-10-04
---

# Extensión - Human Resources Setup SIRADIG (TabExt52004 "HR Setup SIRADIG Ext.")

Segunda extensión de `Human Resources Setup` (la primera es [[Extensión - Human Resources Setup]]), separada porque el módulo SIRADIG es independiente.

| Campo | ID | Tipo | Propósito |
|---|---|---|---|
| `Carpeta Importación SIRADIG` | 50100 | Text[250] | Carpeta desde la que se leen los archivos SIRADIG |

## Dónde se lee
`Pag50171 Importaciones Siradig` y `PagExt50355 HRSetupSiradigExt`. Alimenta el flujo de [[Tabla - Importación SIRADIG]].

> [!note] ID de campo
> El ID del campo (50100) cae en el rango 50xxx mientras que los de [[Extensión - Human Resources Setup]] son 52010+; no hay colisión pero conviene verificar el rango contra la licencia ([[rangos-licencia-objetos]]).
