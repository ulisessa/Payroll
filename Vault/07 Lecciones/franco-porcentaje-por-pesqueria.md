---
aliases: ["El % del franco sale de la pesquería"]
tipo: leccion
tema: francos
tags: [leccion, francos, reference]
actualizado: 2026-10-12
---

# El % del franco sale de la pesquería

El franco de marinería se paga 30% en tangoneros y 100% en poteros; lo decide el buque, no la categoría

El día de franco de **marinería SOMU (729/15)** se paga sobre `PR_FRANCO` a **30 % en los
tangoneros y 100 % en los poteros**. Lo decide la **pesquería del buque**, no la categoría:
en enero 2026, 25 corridas, cero excepciones.

```
A14 A15 A16 A17 A18 A19   mareas 300–323   30 %    (langostino, tangoneros)
A28 HF801 HF802 PM        mareas 1–59     100 %    (calamar, poteros)
```

Por eso parecía que una misma categoría cobraba dos valores "a la vez": MR04 aparece con
17.086,70 y con 56.955,67, que es el mismo `PR_FRANCO` de 56.955,67 al 30 % y al 100 %, en
buques distintos.

**Los oficiales (175/75 y 768/19) cobran siempre 100 %**, también en tangoneros, así que para
ellos no hay corte por pesquería.

**Cómo aplicarlo:** `VALOR_FRANCO` se parte `_LAN` / `_CAL` como el resto de los parámetros de
importe de SOMU —ver [[parametros-somu-por-pesqueria]]— y esto es lo que destraba cargarle
vigencias. Mientras estuvo sin vigencias el concepto 1063 pagó 0 contra 26.152.577,31 que Meta4
pagó en enero.

**Descartado como criterio:** la categoría, el tipo de imputación (04925 es un TP 14 al 30 % y
04495 un TP 1 al 100 %), la fecha de baja (solo 3 de 12 de los que cobran 100 % tienen baja en
enero) y el estado del empleado al 31/01. `PM`, con una sola corrida, se comporta como potero
pero conviene confirmarlo.

Ver [[francos-fifo-ledger]] para cómo se valúan los francos consumidos.

## Relacionado

- [[parametros-somu-por-pesqueria]]
- [[francos-fifo-ledger]]
- [[a-cuenta-futuros-aumentos-francos]]
## Febrero 2026: el reparto está suspendido en Meta4

Verificado en Oracle, sólo en lectura, el 12/10/2026. La regla de enero no se
extiende a febrero: en M4SYS_HIST_NORMAS, 4676 (PORC_SIND_EXENT) y 4675
(AC_SIND_EXEN_MT) tienen vigencia desde 01/07/2025 hasta 31/01/2026 y su
siguiente vigencia comienza en mayo. No hay norma activa de esos conceptos en febrero.

Las fórmulas de 1063 y 3553 aplican el recorte al tipo de buque CG con el
porcentaje 4676; 4675 arma el complemento no remunerativo. Con ese porcentaje
inactivo, los pagos de febrero quedan enteros en los conceptos remunerativos.

La comparación de las corridas originales confirma el cambio con el mismo criterio:

- Enero: los 16 pagos de francos MR de los seis tangoneros están al 30 %
  de PR_FRANCO por DIAS_FRANCO, con complemento no remunerativo.
- Febrero: sus 27 pagos de francos están al 100 %, sin complemento.
- En las 199 corridas MR de febrero de esos buques, AC_SIND_EXEN_MT es cero;
  hay 40 corridas con vacaciones remunerativas. En enero, 188 de 190 tenían
  acuerdo no remunerativo. Los oficiales ya estaban al 100 %.

La configuración de BC debe respetar la vigencia mensual: no arrastrar el
coeficiente remunerativo 0,30 de enero a febrero. No se modificaron fórmulas,
parámetros ni liquidaciones en esta revisión. Las fuentes y resultados originales
están en el respaldo privado .snapshots/pesqueria-febrero-20261012.

## Cambio del 13/10/2026: el 30% sale del importe y pasa al coeficiente

El 30% estaba en el IMPORTE de `VALOR_FRANCO_LAN_729/15_*`, y por eso en febrero, con el reparto
suspendido en Meta4, BC seguía pagando el 30 %. El recorte pertenece a `COEF_PESQUERIA`
(`COEF_TANGONERO_729/15` = 0,30 desde 2026-01-01; el genérico en 1 desde 2026-02-01 lo pisa en febrero).
Se cargaron `VALOR_FRANCO_729/15_<cat>` (el valor pleno, sin sufijo de atributo), se borraron los 90
`_LAN`/`_CAL` de 729/15 y el `1063` multiplica siempre por `#COEF_PESQUERIA`. Respaldo en
`scripts/respaldo-francos-20261013/`; script `scripts/FrancoSinAperturaPesqueria.sql`.

**Verificado el 13/10/2026 después de recalcular:** enero queda igual que antes —`1063` 39 de 39, `2803` 7 de 7 (incluida la final 04925: 34.173,40 / 1.480.847,33), `2804` 7 de 7 y `3554` 328 de 328 contra Meta4—, así que el riesgo del `2803` no se dio: el saldo ya salía del valor pleno. Febrero pasó de 12 a 34 de 43 en el `1063` con `COEF_PESQUERIA` = 1. Lo que queda en febrero no es valor ni coeficiente sino **días**: 04837 paga 2 días contra 16 de Meta4, 03772/04848/04207 no generan el `1063` y 8 de las 9 finales traen menos días de saldo (04726: 56 contra 85).

**Otros precios con apertura LAN/CAL:** `PRECIO_PUERTO` (1,4458 y 1,5145 en 729/15: lista de precios
distinta, no un recorte), `VALOR_NAV_EMP`, `VALOR_FRANCO_EMP` y `PRECIO_INCENT`. `PRECIO_NAV` y
`PRECIO_ORDENES` no tienen apertura: usan sólo el coeficiente. El puerto de oficiales de 175/75 en enero
y febrero es el genérico en pesos y coincide con Meta4 en 20 de 20. Los `PRECIO_PUERTO_LAN_175/75`
(60 % del `_CAL`, USD) son de mayo y de la misma carga que `COEF_TANGONERO_175/75` = 0,30 desde mayo:
revisar que no se reduzcan dos veces cuando se liquide mayo.
