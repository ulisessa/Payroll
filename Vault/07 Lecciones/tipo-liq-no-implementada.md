---
aliases: ["TIPO_LIQ no está implementada"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# TIPO_LIQ no está implementada

> [!note] Verificar: Al 2026-10-04 el código contradice esta lección: `TIPO_LIQ` sí está resuelta en `Cod50016` y sembrada en `Cod50077`. Además `Sembrar` da `CIERRE_MAREA` Orden 70 (no 1). Ver [[Divergencias entre documentación vieja y código]].

**En una frase:** TIPO_LIQ figura en la ayuda de Variables de Sistema y en comentarios de Tab50578, pero no está implementada en ningún codeunit ni sembrada como fila

`TIPO_LIQ` aparece en el ToolTip de `Pag50146.VariableSistemaList` como variable disponible, y
`Tab50578.TipoLiquidacion` valida que el `Orden` sea único justamente porque "también se usa como
valor de TIPO_LIQ en fórmulas". Pero al 28/9/2026 **no existe**: ningún codeunit la resuelve y no
hay fila en `Variable Sistema Liq.` con ese Cód. Cálculo. El motor tiene `FTipoLiq` internamente
(Cod50016) pero no lo expone.

Órdenes vigentes, que serían sus valores: SALDO_INICIAL 0, CIERRE_MAREA 1, HIST_REMUN 5,
ANTICIPO 10, VACACIONES 30, LIQ_FINAL 40, RELIQUIDACION 50, DEVENGADOS 60, REGULAR 100,
AGUINALDO 110.

**Por qué:** hace falta para cualquier concepto que deba comportarse distinto en un cierre de marea que
en un devengado — el caso concreto es [[produccion-no-se-prorratea]], donde 1534 y 2003 no pueden
habilitarse en DEVENGADOS hasta poder distinguir. La ayuda promete la variable, así que es fácil
escribirla en una fórmula y que el cálculo corte.

**Cómo aplicarlo:** implementarla en Cod50016 exponiendo `FTipoLiq` y **además** sembrar la fila —
las dos cosas, ver [[variable-sistema-hay-que-sembrarla]]. Mientras tanto, no usarla en fórmulas.

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
