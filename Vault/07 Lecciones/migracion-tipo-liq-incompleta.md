---
aliases: ["Migración Tipo Liq. incompleta"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
origen: f74796de-b23f-4caa-869e-231702bd4c89
actualizado: 2026-08-14
---

# Migración Tipo Liq. incompleta

> [!warning] Falla en silencio
> Las cabeceras de Liquidación anteriores al cambio enum→código quedaron sin Cód. Tipo Liq. y nada las backfillea

El commit `b97f787` (MVP) reemplazó en `Tab60011.Liquidacion` el `field(10; "Tipo Liquidación"; Enum "Tipo Liq.")` por `field(30; "Cód. Tipo Liq."; Code[20])`. Al ser un ID nuevo, BC dejó la columna vieja atrás: **toda Liquidación creada antes de ese commit tiene el tipo en blanco**, y sigue así.

`Cod50055.GestionTipoLiq.MigrarDatos()` —que corre desde el upgrade `Cod50057`— migra solo `Concepto Liquidación."Tipos Liq. Aplicables"` (captions del enum → códigos). Nunca toca las cabeceras de Liquidación.

**Por qué:** una liquidación sin tipo no falla: el motor filtra los conceptos restringidos por tipo con `ConceptoAplicaATipoLiq` y simplemente no aplica ninguno, sin error ni advertencia. El síntoma aparece lejos del origen — importes bajos, o el nodo "(sin tipo de liquidación)" en el `arbol-liquidaciones-acciones` (lección que no existe en la memoria).

**Cómo aplicarlo:** antes de diagnosticar un cálculo raro en datos viejos, verificar `Cód. Tipo Liq.` de la cabecera. Si hace falta backfillear, el valor original ya no es recuperable desde la tabla —la columna del enum se perdió— y hay que inferirlo por `Fecha Liquidación` / proyecto o cargarlo a mano.

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
