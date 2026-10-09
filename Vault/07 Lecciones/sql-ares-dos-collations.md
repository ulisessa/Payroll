---
aliases: ["SQL ARES: collation de la base de BC"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, project]
origen: 507bdbd7-78fd-4a75-8286-b6a7a9ecc332
actualizado: 2026-09-02
---

# SQL ARES: collation de la base de BC

**En una frase:** La base Navision es Modern_Spanish_100_CI_AS y ARES la iguala; el collation de referencia es el de la base, no el del servidor BRAGI

**Confirmado el 31/8/2026:** la base **Navision** está en `Modern_Spanish_100_CI_AS`, y ARES tiene ese mismo collation a nivel instancia. Coinciden: no hay conversión pendiente ni convivencia de collations que gestionar en ARES.

**El collation de referencia es el de la BASE, no el del servidor BRAGI.** BRAGI tiene la instancia en `SQL_Latin1_General_CP1_CI_AS` mientras su base Navision está en `Modern_Spanish_100_CI_AS`. Es fácil mirar el servidor de origen y concluir que había que replicar Latin1 — sería el error.

**Por qué:** por ese desajuste, es **BRAGI** el que hoy tiene el problema latente de conflicto de collation entre sus bases y `tempdb`, no ARES. El servidor nuevo quedó más consistente que el viejo. Si alguna vez se reinstala ARES, el collation a elegir en el instalador es `Modern_Spanish_100_CI_AS`.

**Cómo aplicarlo:** antes de cualquier decisión sobre collations, mirar el de la base, no el de la instancia:

```sql
SELECT name, collation_name, compatibility_level FROM sys.databases WHERE database_id > 4;
```

**Cuidado con las bases satélite.** El procedimiento `Navision.dbo.SincronizarMarcajesC` (sincronización de marcajes biométricos) tiene un `COLLATE LATIN1_GENERAL_CI_AS` **hardcodeado** en el join contra `Marcajes.dbo.USERINFO`. Esa es una tercera collation, distinta de las dos anteriores, puesta a mano para resolver un conflicto entre `Marcajes` y `Navision`. Verificar el collation de `Marcajes` antes de tocar ese procedimiento.

**Y la base de BC no es ninguna de las dos: es `Modern_Spanish_CI_AS`, sin el `_100`.** Confirmado el
11/9/2026 por el error que tiró la sincronización NAV→BC: "Cannot resolve the collation conflict
between Modern_Spanish_CI_AS and Modern_Spanish_100_CI_AS". O sea que **todo cruce entre BC y
Navision compara dos collations distintas**, y como el linked server se crea con
`collation compatible = false` el servidor no las asume iguales.

**Cómo aplicarlo:** en `scripts/SincronizarNAV_2013R2.sql`, cada comparación de texto que cruce el
linked server lleva `COLLATE DATABASE_DEFAULT` **en las dos puntas** — los cuatro `ON` de los MERGE
y los `t.name` / `c.name` de la verificación de nombres. Forzar un solo lado no alcanza. Y las
tablas temporales se declaran con `COLLATE DATABASE_DEFAULT` explícito, porque viven en tempdb y
heredan la collation del SERVIDOR, no la de la base de BC.

Relacionado: [[ares-topologia-bc]], [[dim2-nav-actividad-bc-marea]].

## Relacionado

- [[linked-server-leer-escalar-remoto]]
- [[sql-dinamico-truncado-4000]]
- [[sql-directo-deja-cache-rancia]]
- [[subconsulta-correlacionada-silenciosa]]
- Tema: `sql-bc-infra` (ver [[_Convenciones del vault]])
