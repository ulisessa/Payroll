---
aliases: ["Escala SOMU: índice sobre 70"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Escala SOMU: índice sobre 70

Todo SOMU sale de un índice 100/85/80/75/70 sobre el básico de Marinero de Planta

Los valores de SOMU (convenio `729/15`) no se cargan categoría por categoría: salen
de **un solo número** —el básico de Marinero de Planta, `MR08`— por el índice

    MR00 100 · MR01 MR02 85 · MR03 MR06 MR07 MR09 80 · MR04 MR05 75 · MR08 70

y sobre el básico, las demás columnas son múltiplos fijos: **puerto ×2,891,
francos ×2,4, órdenes ×1,5, adic. art. 23/33 ×0,6**. El mismo índice gobierna las
dos pesquerías y también los valores de producción.

Está escrito en las fórmulas de los Excel: `B58:B62` de *Det valores* en
`Valores Liquidación TANGONEROS 2026.xlsx`, y `B3:F5` en
`Valores  producción calamar campaña 2026.xlsx`, cuya columna D se titula
"CONTRAMESTRE FRIO ENFERMERO MOZO" y por eso zanja que MR06 y MR07 siguen a MR03.

**Por qué:** da un control que no depende de ninguna fuente externa. El 17/9/2026
encontró cinco valores de `PRECIO_PUERTO_LAN` fuera de escala —el Primer Pescador
cobrando lo mismo que un Marinero de Cubierta— y 18 de `VALOR_CAL_*` cargados con
el cociente redondeado a cuatro decimales en vez de la fracción exacta.

**Cómo aplicarlo:** el control vale **sólo para los parámetros que derivan del
básico**. Los `PCT_*` son porcentajes —planos por categoría o con escala propia— y
sin excluirlos el control marca 18 celdas de las que 13 son falsos positivos. Ver
[[parametros-somu-por-pesqueria]] y [[previsualizar-antes-de-migrar]].

**La fuente autoritativa del índice por CATEGORÍA es `M4T_VAL_COEF_CAPECA_CATEGORIA`** (confirmada el 23/9/2026). Da el coeficiente por categoría y tipo de buque —`CG` y `PT`, con los mismos valores— y con vigencias. Coincide al decimal con los `PCT_ESCALA_CONV_*` que ya estaban cargados en BC, en las trece categorías:

```
MR00 1,00 · MR01 0,85 · MR02 0,85 · MR03 0,80 · MR04 0,75 · MR05 0,75
MR06 0,80 · MR07 0,80 · MR08 0,70
OF01 1,15 · OF02 1,00 · OF03 0,90 · OF04 0,85
```

Es la hermana de `M4T_VAL_COEF_CAPECA_PUESTO`, que da lo mismo por puesto.

Ojo con **OF03**: vale 0,90 desde el 1/8/2017 y valía 0,85 antes. Ese viejo 0,85 es el que quedó en `PCT_ESCALA_ARBU_*_OF03`, mientras que `PCT_ESCALA_CONV_*_OF03` tiene 0,90 — o sea las dos escalas de BC difieren justo donde Meta4 tuvo un cambio de vigencia.

Y **`M4T_VAL_ESPECIE_PUESTO` no son los básicos**: son los valores de producción por especie y puesto (L1-L6, C1-C3, CAE/CAV, M0/M1, CR1, VSS), o sea la familia `VALOR_*_FC` pero indexada por PUESTO. Es lo que falta para que la producción de oficiales deje de dar cero.

**Los básicos de oficiales no están en ninguna tabla de valores: salen de `PR_NAVEG`** de `M4T_ACUMULADO_RL3`, que es el básico dividido 30 (el recibo imprime "Salario Base" y el cociente da exacto). Enero 2026: OF01 1.485.000 · OF02 900.000 · OF03 1.162.000 · OF04 765.000.

## Relacionado

- [[parametros-somu-por-pesqueria]]
- [[previsualizar-antes-de-migrar]]
- [[art19-calamar-cuenta-corriente]]
- [[basico-de-tierra-por-empleado]]
- [[cct-175-75-remuneracion-navegacion]]
