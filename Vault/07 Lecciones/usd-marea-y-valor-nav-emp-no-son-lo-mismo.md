---
aliases: ["USD_MAREA y VALOR_NAV_EMP_CAL no son lo mismo"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-08
---

# USD_MAREA y VALOR_NAV_EMP_CAL no son lo mismo

> [!important] Alcance histórico y corrección de febrero de 2026
> La explicación siguiente corresponde a fórmulas anteriores. Desde la generalización
> del acuerdo bruto con fijo de oficiales poteros, `VALOR_NAV_EMP` es el fijo de empresa
> tanto en devengados como en cierre; `GARANT_POT_CCT` separa la garantía normativa del
> convenio, sin precio personal. `USD_MAREA` se conserva para las otras ramas y para la
> historia. No duplicar nuevos acuerdos en ambas bases por aplicar esta lección antigua.
> La garantía anterior se reconstruye por cabecera, fecha y TC histórico mediante
> `ACUM_PARAM_CCT`, sin reescribir enero. Ver [[Producción y premios]].

Los dos llevan el acuerdo individual del oficial, pero alimentan conceptos distintos: hay que cargar los dos

> [!warning] `USD_MAREA` es el **fijo mensual del acuerdo de producción** y es un término de `PROD_EMPRESA`, que gobierna el **cierre**. `VALOR_NAV_EMP_CAL` es lo que lee el **2003** para completar hasta el acuerdo en el **devengado**. Mover el valor de uno al otro rompe el cierre.

```
PROD_EMPRESA = PROD_KN_MAREA/1000 * USD_TON_PROD * PCT_PROD/100
             + USD_MAREA / 30 * DIAS_MAREA          ← el fijo mensual
             + @ADIC_PROD_PESCA

1534 = IF(NETO_GU_MAREA > 0, VALOR_NAV_EMP_CAL, USD_MAREA) / 30 * DIAS_MAREA − convenio
2003 = (cierre)    #PROD_EMPRESA − (…)
       (devengado) VALOR_NAV_EMP_CAL / 30 * DIAS_MAREA − (#1534 + …)
```

Sólo el **1534** y el **2003** nombran `VALOR_NAV_EMP_CAL` en todo el sistema —ningún otro concepto, condición ni Fuente de Datos—, pero `USD_MAREA` además entra en `PROD_EMPRESA`.

**El caso bien cargado es el 01477:** acuerdo de 7.000 en `VALOR_NAV_EMP_CAL_01477`, y su devengado da 990.500,00 contra 990.500,10 de Meta4.

**El síntoma de que falta la fila:** el 2003 del devengado sale **negativo**. Sin `VALOR_NAV_EMP_CAL` propio lee el par —6.900 contra los 7.000 que el 1534 ya pagó— y en vez de completar, resta. Le pasaba al 04791: −14.150.

## El error que costó dos recálculos

Leí el 2003 y concluí que `USD_MAREA` era "el par", que el acuerdo del 04791 estaba en el parámetro equivocado, y lo **moví**. El cierre se cayó 122.633,33 —y el del 04649, 127.350— porque `PROD_EMPRESA` también lo lee. Hubo que revertir entero.

> [!warning] Antes de mover un parámetro, buscar **todos** sus lectores
> No alcanza con leer la fórmula del concepto que falla. `grep` sobre fórmulas **y** condiciones **y** Fuentes de Datos, y mirar los acumuladores intermedios: acá el 2003 del cierre no nombra `USD_MAREA`, pero depende de `PROD_EMPRESA`, que sí. La dependencia estaba a un salto de distancia y no la seguí.

La solución correcta era **agregar** la fila que faltaba, no mover la que había: el 04791 necesita el 7.000 en los dos parámetros.

> [!note] En el cierre el valor es invisible
> El 1534 del cierre toma `MAX(producción, garantizado)` y la producción gana por lejos —12,0 M contra 8,6 M—, así que un garantizado mal cargado no se nota. Sólo asoma en el devengado, donde no hay producción. Y ahí el total puede seguir dando bien **por compensación**: el 1534 se pasa exactamente lo que el 2003 negativo devuelve ([[grossing-up-tapa-errores]] es el mismo patrón).

## Qué queda sin explicar

Meta4 reparte el devengado del 04791 como 1534 375.346,67 + 2003 14.150; BC da 389.496,67 + 0. **El total coincide, el reparto no.** Meta4 usa el par en el 1534 y el acuerdo en el 2003; BC usa el acuerdo en los dos. Cambiar el selector del 1534 rompería al 01477, que hoy sale bien.

## Relacionado

- [[oficiales-netos-al-70]]
- [[condiciones-oficiales-poteros-2026]]
- [[grossing-up-tapa-errores]]
- [[un-valor-una-fuente]]
- [[fuente-datos-apunta-por-numero]]
