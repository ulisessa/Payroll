---
aliases: ["Una variable de sistema hay que sembrarla"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, project]
actualizado: 2026-10-04
---

# Una variable de sistema hay que sembrarla

> [!warning] Falla en silencio
> Agregar un Cód. Cálculo al motor no crea la variable; sin la fila en Variable Sistema Liq. la fórmula corta en runtime

Una variable de sistema vive en **dos lugares**: el `case` de `ComputeVariableSistema` (Cod50016) y una **fila** en `Variable Sistema Liq.` que la nombra. El motor resuelve por la fila, no por el case. Agregar sólo el código AL compila, publica y no avisa nada — y después revienta al calcular:

```
Variable desconocida en la fórmula: "MESES_PROM_AUS_12".
Ningún Parámetro, Variable de Sistema, Fuente de Datos ni Tipo de Atributo la define.
```

**Por qué:** el error aparece lejos del cambio. Compila, el publish sale bien, y el síntoma llega en la primera liquidación que usa una fórmula con esa variable — a veces semanas después, cuando ya nadie lo asocia con el publish. Pasó el 23/9/2026 con `MESES_PROM_AUS_12`.

**Cómo aplicarlo:** la siembra vive en `Gestión Variables Sistema.Sembrar()`, es idempotente y **ahora corre sola** en Install y Upgrade (Cod110049 / Cod110050, agregadas ese día siguiendo el patrón de `Tipo Liq. Install`/`Upgrade`). Pero **un publish de RAD no dispara Upgrade**, que es como se trabaja en desarrollo: ahí hay que usar la acción **"Sembrar"** de la página Variables de Sistema, o insertar la fila por SQL.

Las variables que necesitan un parámetro —`YTD_ACUM` con su acumulador, `DIAS_ESTADO_PERIODO` con su `Cód. Estado`— no se siembran con su propio nombre: sin el parámetro devuelven cero en silencio. Se siembran con nombre propio y el parámetro puesto (`DIAS_ENFERMEDAD`→AU1, `DIAS_ACCIDENTE`→ACC), vía `AgregarPorEstado`.

Control rápido antes de calcular, que es el mismo que hace el motor: cruzar cada identificador de la fórmula contra `Parámetro`, `Variable Sistema Liq.` (Activo), `Fuente Datos Liquidación` (Activo), `Tipo Atributo Liq.` y los conceptos con `Es Acumulador`. Si no está en ninguna, corta.

## Relacionado

- [[system-variables-conventions]]
- [[variables-rotas-valen-cero]]
- Tema: `formulas-evaluador` (ver [[_Convenciones del vault]])
