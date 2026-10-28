---
tipo: tabla
tags: [modelo-datos, ui, ganancias]
fuente: [src/Tables/Tab60027.CueSiradig.al]
actualizado: 2026-10-04
---

# Tabla - Cue SIRADIG (60027)

## Propósito
Tabla **de Cue** (tiles del Role Center) para SIRADIG: sólo cuenta importaciones por estado. No guarda datos de negocio.

## PK
`Primary Key` (Code[10]), clustered. `DataClassification = SystemMetadata`.

## Campos
Tres FlowFields de `Count("Importación SIRADIG")` filtrados por `Estado`: `Pendientes` (Pendiente Procesar), `Con Errores` (Error en Procesamiento), `Procesados` (Procesado Exitosamente). No cuenta "Procesado con Advertencias".

## Triggers
Ninguno.

## Quién la lee
Página `Pag50173 Cue Siradig` (part `CueSiradig` de `Pag50149 Payroll Role Center`). Ver [[Tabla - Importación SIRADIG]].

## Vigencias / trampas
No aplica. Un solo registro (`Primary Key` vacío o fijo) que la página inicializa.
