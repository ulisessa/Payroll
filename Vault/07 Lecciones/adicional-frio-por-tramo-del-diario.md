---
aliases: ["El adicional de frío se reparte por el diario de a bordo"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-08
---

# El adicional de frío se reparte por el diario de a bordo

Los días no prorratean el 20%: seleccionan los renglones de captura, y la captura no es uniforme

> [!warning] Cuando dos tripulantes **comparten el puesto de frío** en una misma marea, cada uno cobra el 20% de **los kilos de sus días**, no una fracción del 20% proporcional a sus días. Con una marea cargada al final, las dos cuentas difieren por un factor de **6,7**.

El 1583 "Adicional trabajos especiales" es en realidad el adicional por **frío**: en Meta4 la columna es `ADIC_TRAB_ESP` y el porcentaje vive en `PORC_ADIC_FRIO` = 20. En BC es `PCT_TRAB_ESP_729/15` a nivel convenio, y la fórmula es un 20% limpio de la producción SOMU:

```
1583 = ROUND((#2403 + ... + #1393 + #2498) * PCT_TRAB_ESP / 100, PRECISION_REDONDEO)
```

Para quien hizo frío la marea entera eso es exacto: en la marea 6 del HF801, **11 de 13** coinciden con Meta4 al centavo, y lo mismo en el HF802 (12) y el A28 (14).

## El caso que lo rompe

El rol del buque lo dice en **OBSERVACIONES**, no en ninguna tabla: dos tripulantes se intercambiaron el puesto a mitad de marea. Uno hizo frío del **3 al 12/1** y pasó a planta; el otro al revés. Sus novedades del 1583 traen **10 y 16 días**, que suman los 26 de la marea.

BC le paga a cada uno el 20% entero: **1.074.554 a los dos**, o sea 1.074.554 de bruto de más repartidos entre ellos. Meta4 reparte **un solo 20%**:

```
diario del 3 al 12   =  69.720 kg   →  20% × 69.720/1000 × 10.000  =   139.440,00   ✔ exacto
desembarcado total   = 537.277 kg
saldo (13 al 28)     = 537.277 − 69.720 = 467.557 kg → 20% × ...    =   935.114,00   ✔ exacto
                                                                       ───────────
                                                       el 20% entero   1.074.554,00
```

Los dos salen de datos de BC —`On board capture lines` y `Lín. descarga`— con diferencia **0,0000** contra Meta4.

## Las dos cuentas que no son

| Criterio | Relevo (10 d) | Otro (16 d) | |
|---|---|---|---|
| Prorrateo por días (10/26 y 16/26) | 413.290 | 661.263 | ✗ el par cierra, el reparto no |
| Diario de **cada** tramo | 139.440 | 912.220 | ✗ pierde 22.894: el diario suma 525.830 y se desembarcaron 537.277 |
| **Diario del tramo + saldo del desembarque** | **139.440** | **935.114** | ✔ |

La base que se reparte es el **desembarque**, que es la cifra que se paga. El diario sólo **recorta el tramo del relevo**, y el saldo queda para el otro: así no se pierde ni se duplica un kilo. Los 11.447 kg de diferencia entre el diario y la descarga son justamente lo que separa a las dos ramas del 2498.

Y los días no sirven como peso porque la captura no es uniforme: los primeros 6 días de esta marea dieron **cero**, y el 23/1 sólo dio 60.380 kg — más que los 10 primeros días juntos.

## Lo que BC no tiene

La novedad dice "10 días", pero **no dice cuáles**. Que sean los primeros sale del documento del rol. No hay dónde leerlo:

- `Personal embarcado` (que tiene `Id. puesto` y `Nombre puesto`) **no tiene filas** de este proyecto.
- `Production amount per employee` —la única con `Role code` + `Starting/Ending date`— se corta en **2024** y no tiene nada de 2026.
- `M4T_HIST_PUESTOS` sigue sin migrar ([[puesto-vs-categoria-cct]]).

Con el orden invertido el importe del relevo pasaría de 139.440 a 912.220, así que esto no se puede adivinar.

## Meta4 tampoco lo calculaba

El importe estaba **tipeado a mano**: una incidencia de concepto `1583` con `ID_TIPO_APLICACION = 0`, cargada el 19/1 por un usuario. Los días viven en otro concepto, el `1582`, con `TIPO_APLICACION = 2`, y ésos los tienen los 38. Desde enero de 2025 hay **15 de estos overrides**, algunos en **negativo** (tres de −795.548,24 en junio de 2025 apareados con positivos a otros): reasignación a mano, caso por caso.

`M4T_HIST_PUESTOS` **no interviene**: uno de los dos no tiene ninguna fila y el otro tiene una sola, gruesa (`PT02 Marinero de Planta`, del 1/1 al 27/4). Es el puesto estructural, no el tramo.

La migración trajo el `1582` a la **`Cantidad`** de la novedad del 1583 de BC —la observación dice literalmente `Meta4 1582`— y **dejó afuera el importe del 1583**. BC diverge exactamente donde Meta4 había pisado la fórmula.

## Cómo quedó: lo calcula el motor

La regla se escribe al revés y así el residuo no hay que nombrarlo: **el tramo que llega al arribo se lleva todo lo que los demás no tomaron**.

```
ROUND(
    (#2403 + ... + #1393 + #2498) * PCT_TRAB_ESP / 100
    * IF(
        TRAMO_HASTA <= 0,
        1 - (DIARIO_KN_MAREA - DIARIO_KN_TRAMO) / IFZERO(IF(MAREA_COMPLETA, PROD_KN_MAREA, DIARIO_KN_MAREA), 1),
        DIARIO_KN_TRAMO / IFZERO(IF(MAREA_COMPLETA, PROD_KN_MAREA, DIARIO_KN_MAREA), 1)
    ),
    PRECISION_REDONDEO)
```

**Degenera exactamente en la fórmula anterior cuando hay un solo tramo**: `1 − 0/base = 1`. Por eso los otros 37 del mes no necesitan ningún dato cargado y no se tocan — y es la propiedad que hace seguro el cambio.

| Pieza | Qué es |
|---|---|
| atributo `TRAMO_PROD` | de empleado, `Tipo Dato = Texto`, **valor = el No. de proyecto**. La vigencia es el tramo. El valor es el proyecto y no un catálogo de puestos porque así el lookup es exacto, una fila por tramo y por marea |
| `{ATRIB_DESDE:X}` / `{ATRIB_HASTA:X}` | los dos tokens nuevos, los únicos con argumento. Ver [[Tokens de filtro de fuentes de datos]] |
| `DIARIO_KN_MAREA` / `DIARIO_KN_TRAMO` | kilos del diario, **sin filtrar familia ni subfamilia**: por totales, así vale para langostino igual que para calamar |
| `TRAMO_HASTA` | `Tipo Dato = Fecha` sobre `Atributo Entidad Liq.` |

> [!tip] `ES_ULTIMO_TRAMO` no hizo falta, y ahí estaba el truco
> Una fuente de `Tipo Dato = Fecha` **no devuelve la fecha: devuelve `FechaRef − fecha`**, en días. Y en un cierre `FechaRef` **es el arribo** (`Cod50014`: `FechaRef := Job."Ending Date"` si `EsArribo`). Así que `TRAMO_HASTA` vale **0** para quien termina el día del arribo, 16 para quien terminó el 12 — y **0 también cuando no hay atributo**, porque la fuente no encuentra fila y sale 0. El fallback sale gratis.
>
> El test va con `<=` y no con `=`: una vigencia abierta, o que pase del arribo, da **negativo**.

El reparto es por **peso**, así que una marea con dos especies de valor muy distinto se repartiría por kilos y no por valor. En enero no hay mezcla.

## Dos novedades del mismo concepto suman sus cantidades

Un tripulante tenía **dos** novedades del 1583 en enero: una cargada a mano con importe, y otra que trajo la migración dos días después con sólo los días. El motor **suma las cantidades** de las novedades que materializa en la misma incidencia, así que su recibo mostraba **52 días** en vez de 26. El importe salía bien; el dato impreso, no.

Y había un segundo efecto, el que importa: con un importe cargado la fórmula **no corre**, así que era el único de su marea cuyo 1583 no salía del motor — y con la vigencia nueva seguiría sin usarla.

Se borró la de importe (8/10/2026) después de verificar contra su propia línea que el 20% de su producción daba **exactamente** el importe cargado: soltarlo a la fórmula no le cambia un peso y la cantidad vuelve a 26. Esa comprobación es la guarda que hay que repetir antes de sacar cualquier importe cargado a mano: si no coincide, no es una limpieza, es un cambio de recibo.

## Relacionado

- [[puesto-vs-categoria-cct]]
- [[produccion-no-se-prorratea]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[dia-de-puerto-no-estira-la-marea]]
- [[parametros-somu-por-pesqueria]]
