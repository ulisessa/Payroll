---
aliases: ["Cuota sindical del SAC: base equivocada"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Cuota sindical del SAC: base equivocada

**En una frase:** el 4754 usaba BASE_SINDICAL/12 como proxy del SAC devengado; acierta sólo si todo es sindicalizable

Los cuatro aportes sobre SAC devengado (4751 jubilación, 4752 ley 19032, 4753 obra social, 4754 cuota
sindical, órdenes 925 a 928) se calculaban todos como `base_del_mes * pct / 100 / 12`, donde el `/12`
hace de proxy del SAC devengado. **Ese proxy sólo es correcto cuando la base del mes coincide con la
base del SAC**, y en el 4754 no coincide: `BASE_SINDICAL` es la parte sindicalizable, que en el
tangonero es el **70%** (ver [[franco-porcentaje-por-pesqueria]]). En el 00191 daba 19.397,06 contra
los 27.710,08 de Meta4, y el 4754 ahora alimenta `CUOTA_SINDICAL_RET`, así que el error se propaga a
la base de Ganancias (ver [[cuota-sindical-deducida-dos-veces]]).

**La regla de Meta4 es `SAC devengado × pct`, sin dividir por 12**, porque el SAC devengado ya es la
doceava parte. Se verifica contra el concepto **4750**, que ES esa base: 692.752,02 × 4% = 27.710,08
al centavo, y el porcentaje implícito (`C_SINDICAL_SAC_MES` / 4750) sale limpio en 248 de 263
empleados de enero — 4% en 222, 4,5% en 15, 2,5% en 7 y 2% en 4.

La fórmula que corresponde, con `BASE_SAC_DEV` (que se alimenta del 4750 al 100%) en vez de
`BASE_SINDICAL`:

```
round((BASE_SAC_DEV * IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) / 100), 0.0001)
```

Medido sobre enero antes de aplicarla: los coincidentes pasan del 64% al 88% y la brecha cae de
3,15 M a 1,16 M. **Rompe un solo caso, el 02854**, cuyo porcentaje implícito es 4,67% y que hoy
acierta por casualidad.

Los otros tres NO hay que tocarlos aunque tengan la misma forma: sus bases sí son las completas
(`BASE_SS_TRAB + BASE_SS_VAC` para el 4751 y el 4752, `BASE_OS_TRAB + BASE_OS_VAC` topeado por
`TOPE_SIPA_OS` para el 4753) y coinciden con Meta4 al centavo.

**Lo que queda del 4754 después del arreglo es un problema de carga, no de fórmula**: en 42 empleados
el porcentaje de BC difiere del de Meta4, y el patrón más repetido es **BC 3% contra Meta4 4%**
(00607, 00687, 01591, 02451, 02452, 03809, 04485, 04649). Ver [[sindicato-obra-social-atributos]].

## No es una tasa mal cargada: C_SINDICAL_SAC_MES son CUATRO descuentos

Medido el 3/10/2026. El diagnóstico viejo —"BC usa 3% y Meta4 4%"— **está mal**. La base coincide
exacto: el `BSAC_MES_RG3976` de Meta4 es igual al 4750 de BC corrida por corrida. Lo que difiere es
el porcentaje implícito, y descompone perfecto en los cuatro aportes sindicales:

| Empleado | % implícito | sindical + caja + fondo + acción social |
|---|---|---|
| 04893 | 7,7500 | 2,5 + 5 + 0,25 (sin acción social: base bajo el tope) |
| 01541 | 10,7500 | 2,5 + 8 + 0,25 |
| 04924 | 10,7500 | 2,5 + 5 + 0,25 + 3 |
| 04724 | 11,7500 | 2,5 + 6 + 0,25 + 3 |

Las corridas TI=10 dan algo menos (9,82% en 04924, 10,97% en 04724) porque ahí la acción social
todavía está parcialmente cubierta por el TOPE_SIPA, que es mensual.

O sea: **Meta4 cobra los cuatro descuentos sindicales también sobre el SAC devengado, en una sola
columna**, y BC sólo tiene el sindical (4754 = 2,5% de `BASE_SAC_DEV`). Faltan los equivalentes SAC
de 8542, 8543 y 8593 — igual que 4751/4752/4753 son los equivalentes SAC de 6000/6010/6030.

El mapeo `C_SINDICAL_SAC_MES → 4754` tiene `Mapeo Verificado = 0`, y ahora se sabe por qué: la
columna no es el equivalente de un solo concepto de BC.

**Esto es lo único que separa a 04924 de Meta4**: los 84.609,60 que BC no descuenta elevan la base
de Ganancias y dejan +29.613,36 en el 5010, que es su 35% exacto. Arreglar el 4754 cierra las dos
diferencias de una vez.

## Los tres conceptos SAC, creados el 3/10/2026

| Código | Qué | Orden | Fórmula |
|---|---|---|---|
| 4755 | Caja compensadora SAC | 929 | `BASE_SAC_DEV × PCT_CAJA_COMPENSADORA / 100` |
| 4756 | Fondo de desempleo SAC | 931 | guarda `= 'CAP'`, `BASE_SAC_DEV × PCT_FDO_DESEMPLEO / 100` |
| 4757 | Acción social SAC | 933 | guarda `= 'CAP'`, excedente del mes **/ 12** × 3%, menos `MES_CUOTA_EXT_CAP_SAC` |

Copiados del molde del **4754**: Tipo 5, `Imprime en Recibo` = 0 (el SAC devengado es provisión, no
línea del recibo), grupo de costo 2, el mismo alcance de seis tipos, y **las tres fracciones**
—`CUOTA_SINDICAL_RET`, `GAN_NETA_A_DEDUC`, `GAN_NETA_MES`— puestas en el mismo script que los crea,
para no repetir por tercera vez el olvido de la fracción.

Los órdenes **no son contiguos** (929, 931, 933): del 930 para arriba empieza el bloque de
contribuciones patronales. Lo único que importa es que corran después del 4750, que arma
`BASE_SAC_DEV`, y antes del 5010, que lee `CUOTA_SINDICAL_RET`.

**La prorrata del 4757 es `/12`**, verificada contra Meta4: en 04924 TI=10, el excedente del mes
(8.500.679,21) dividido por 12 y al 3% da 21.251,70, exactamente lo que cobró. Y la cascada
mensual la completa: TI=15 cobra 1.522,54 y TI=1 cobra 1.910,25, sumando los 24.684,49 del mes.

**Efecto lateral en el comparador**: `C_SINDICAL_SAC_MES` sigue mapeada al 4754 y una columna de
Meta4 sólo puede apuntar a un concepto de BC. Así que el detalle por concepto va a seguir mostrando
el 4754 corto en ~84.609 y los tres nuevos como "sólo en BC", aunque los totales de bruto,
descuentos y neto estén bien. Si molesta, se le saca el `Cód. Concepto BC` a esa columna.

## Van en Tipo 6, no en Tipo 5: se deducen de Ganancias pero NO del neto

Los creé en Tipo 5 (Seguridad Social) copiando al 4754 y eso **rompió a los tres empleados que ya
estaban exactos**: 01541 pasó a +14.415,38 de descuentos, 04893 a +7.495,06 y 04924 a +84.609,60 —
en cada caso, exactamente la suma de sus conceptos nuevos.

La causa: `Total Descuentos` de BC suma los tipos 2, 4 y 5, y el `TOT_RETEN` de Meta4 **no incluye**
la caja, el fondo ni la acción social sobre el SAC. **Sí incluye** el 4751-4754, que por eso se
quedan en Tipo 5 y por eso esos empleados daban exactos antes.

Tiene sentido: el SAC devengado es una **provisión**. Esos aportes todavía no se pagaron, así que no
se retienen del neto del mes — pero Meta4 **sí los resta de la base de Ganancias**, y eso se
comprueba solo: con las tres fracciones puestas, el 5010 de 04924 cayó a 2.938.935,64, exactamente
el de Meta4.

Entonces: **Tipo 6 (Informativo)**, con las fracciones intactas. Un informativo no paga pero alimenta
acumuladores y bases, que es justo lo que hace falta. Corregido el 3/10/2026.

**La regla general**: al crear un concepto, el tipo decide si entra al neto y las fracciones deciden
si entra a las bases. Son dos preguntas separadas y hay que contestarlas por separado — acá la
respuesta era "a las bases sí, al neto no", y copiar el tipo de un hermano las juntó mal.

## Relacionado

- [[retenido-true-importe-cero]]
- [[tope-sac-por-liquidacion]]
- [[tot-remun-27617-es-acumulador]]
- Tema: `descuentos-ganancias-sipa` (ver [[_Convenciones del vault]])
