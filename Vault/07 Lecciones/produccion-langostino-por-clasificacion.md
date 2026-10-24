---
aliases: ["Producción de langostino por clasificación"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-15
---

# Producción de langostino por clasificación

**En una frase:** el langostino se valúa por clasificación (L1, L2, L3, C1, C2, CR…), con el peso **neto**, sea cual sea la serie o la presentación del ítem; y el que no termina la marea cobra lo del diario de a bordo.

El código del ítem es `LTBP-<serie>-<clasificación>-<presentación>` (`LTBP-AA21-L1-12 K`); la serie no cambia entre mareas, lo que cambia es qué clasificaciones captura cada marea. Las fuentes `PROD_KN_*` (peso neto, campo 8 de `Lín. descarga`, la que valúa) y `PROD_KB_*` (peso bruto, campo 9) filtran el ítem (campo 4) por `LTBP-*-<clasificación>-*`. Antes `PROD_KN_L2` y `PROD_KN_L3` estaban cruzadas, y `L4`, `L5`, `L6` y `C3` apuntaban a ítems inexistentes (`AA23-L4`, `AA23-L5`, `AA23-L6`, `AB22-C3`; los reales son `AA24-L4`, `AA25-L5`, `AB23-C3`). `PROD_KB_LANG_COLA` filtraba el ítem con `L-COLA` (es una subfamilia, campo 50002).

**Quien no termina la marea** (relevo o baja): `DIARIO_KN_LAN_<clasificación>` (tabla 50502 `On board capture lines`, kilos campo 18, producto campo 7, ventana `{ASIG_DESDE}..{ASIG_HASTA}`). Los conceptos 1393, 2403 a 2483, 2499 y 2498 (rama de tangonero) leen `IF(MAREA_COMPLETA, PROD_KN_<c>, DIARIO_KN_LAN_<c>)`. Los kilos del diario de PP-119-000315 coinciden con el neto de la descarga (L1 46.086 contra 46.080).

Totales sin merluza: `PROD_KN_LAN`, `PROD_KB_LAN`, `DIARIO_KN_LAN` (Actividad `LAN` y producto `LTBP-*`). Scripts: `FuentesProduccionLangostino.sql`, `FuentesDiarioLangostino.sql`, `ProduccionLangostinoPorClasificacion.sql`. **Sin verificar:** no hay cierres de tangoneros en enero ni febrero de 2026 para comparar contra Meta4; se mide con el primero. Ver [[baja-a-mitad-de-marea-produccion-en-el-devengado]].
