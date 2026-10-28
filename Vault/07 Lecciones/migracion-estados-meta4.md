---
aliases: ["Migración estados Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
actualizado: 2026-10-04
---

# Migración estados Meta4

**En una frase:** El historial de estados de Meta4 llega por dos tablas distintas, y el proyecto no viene en los datos — se deduce de Devenga Francos

La migración de estados desde Meta4 entra a `Estado Empleado` de BC por **dos caminos que no se
pisan**, y confundirlos hace buscar datos donde no están:

- **Altas y bajas** → `ARBPRO.M4T_FASES_ALTA` (`ID_MOTIVO_BAJA` → `BAJ-*`), vía
  `scripts/MigrarFasesAlta_*`.
- **Estados operativos y ausencias** → `ARBPRO.M4T_HIST_ESTADOS_EMPL` (`NV PS GP PL PI DQ`,
  `FR OR OI`, `AU*`), vía `scripts/MigrarEstados_*`. Esta tabla **no tiene ni una fila `BAJ-*`**.

**El proyecto no viene en los datos.** `ID_MAREA` nunca es cero —ni en las filas de tierra—, así
que no sirve para distinguir marea de no-marea. El criterio es `Devenga Francos` del
`Cód. Estado Empleado`, el mismo que ya usa `ResolverProyectoInactividad` en Cod50017:

    Devenga Francos = Sí (DQ GP NV PI PL PS) → PP-<buque>-<marea a 6 dígitos>  (PP-114-000311)
    Devenga Francos = No (FR OR OI AU*)      → PN-<buque>-NOMINA

Buques: `HF801→801`, `HF802→802`, `A14→114`, `A28→128` (1 + numeral romano), `PM` = PPM
(Puerto Madryn). Confirmado contra `PN-101-NOMINA` = ARB.I y `PN-110-NOMINA` = ARB.X.

**Abierto (11/9/2026):** el catálogo `Cód. Estado Empleado` de BC se renombró a los códigos de
Meta4, así que los códigos viajan 1:1 — pero los filtros de Fuente Datos quedaron apuntando al
nombre viejo. `DIAS_VAC` y `DIAS_VAC_INICIO` filtran `'FC-VAC'`, código que ya no existe: hoy
devuelven cero en silencio. Ver `scripts/RestaurarFiltrosFuenteDatos.sql:72`. Falta revisar si
`INCID_VACACIONES` (campo 2, otra tabla) es concepto y no estado.

Relacionado: [[estado-empleado-effective-dated]], [[acumuladores-orden-calculo]].

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-novedades-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
