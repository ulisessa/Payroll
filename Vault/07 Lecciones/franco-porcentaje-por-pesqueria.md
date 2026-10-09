---
aliases: ["El % del franco sale de la pesquería"]
tipo: leccion
tema: francos
tags: [leccion, francos, reference]
actualizado: 2026-10-04
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
