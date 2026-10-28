---
aliases: ["Sindicato y obra social como atributos"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-18
---

# Sindicato y obra social como atributos

**En una frase:** El sindicato y la obra social viven en la persona, no en el par convenio+categoría; y una tasa efectivo-fechada obliga a partir las vigencias del atributo

`SINDICATO` y `OBRA_SOCIAL` son atributos de entidad sobre EMPLEADO, migrados el 18/9/2026 desde
`ARBPRO.M4T_HIST_SINDICATOS` y `ARBPRO.M4T_HIST_OBRA_SOCIAL` (9.784 y 9.789 vigencias, 4.789
empleados). La tasa de la cuota está en `M4T_VAL_SINDICATO` con `ID_CONCEPTO = 622`, también
efectivo-fechada. `M4T_VAL_OBRA_SOCIAL` tiene los conceptos 633/634/635 con valores 10-20, que NO
son el aporte: ése es el 3% de ley y el 6030 ya lo clava.

**Por qué:** la cuota sindical NO se puede deducir del par convenio+categoría. 04649 y 04766 son los
dos Capitán en 768/19 y pagan 3% y 2,5%, porque están en PAT y ASO respectivamente. El sufijo de
parámetro llega hasta convenio+categoría y ahí se termina ([[get-con-menos-argumentos]] no aplica
acá; el orden de candidatos está en `Cod50071.Candidatos`). El dato es de la persona y cambia en
el tiempo, que es exactamente lo que un atributo de entidad ya sabe hacer.

**Cómo aplicarlo:**

- El atributo es de **Lista** y la tasa va en el `Valor Numérico` del valor del catálogo; el motor
  inyecta ese número (`Cod50016.LoadAtributos` lee `Atributo."Valor Numérico"`). El del SINDICATO se
  llama `PCT_SINDICATO`; el de OBRA_SOCIAL va **sin** Nombre Variable, porque su número no se usa en
  ninguna fórmula y ponerlo inyectaría un cero en todo contexto de cálculo.
- **Una tasa efectivo-fechada obliga a partir las vigencias del atributo.** El primer intento
  congeló en cada afiliación la tasa del día en que la persona se afilió, y quedó mal por los dos
  lados: ASO cobró 3, 4, 3 y 2,5 en distintas épocas y los afiliados viejos arrastraban la vieja; y
  SOM tiene tarifa recién desde 1998, así que las afiliaciones de 1990 caían fuera de todo tramo y
  daban CERO, que habría liquidado cuota sindical cero sin un solo error. La forma correcta es
  cruzar afiliación × tramos de tarifa y emitir una vigencia por intersección, extendiendo el primer
  tramo hacia atrás hasta el inicio de la afiliación. Son sólo 54 afiliaciones partidas sobre 9.703.
- El control que destapa esto es **"un gremio, una tasa"**: agrupar por valor a una fecha y contar
  `DISTINCT Valor Numérico`. Si da más de uno, las vigencias no están partidas por tarifa.
- Meta4 deja vigencias **abiertas** y abre otra encima (441 pares), y en los bordes **comparte el día**
  porque su fin es exclusivo y el de BC inclusivo (`AtributoVigente` filtra `Vigencia Hasta >= fecha`).
  Hay que cerrar cada una el día antes de que empiece la siguiente, igual que
  [[estado-empleado-effective-dated]].
- El renglón bajo el nombre en el recibo de Meta4 es la **obra social**, no el sindicato. El
  "Personal del Espectáculo Público" de 04066 no es basura: es su obra social, y es el único que la
  tiene.

Ver [[atributos-tipados]] y [[previsualizar-antes-de-migrar]].

## La caja compensadora NO es una tasa del sindicato

Medido el 3/10/2026: de los 9 empleados que pagan caja compensadora y llegan a 2024, BC conoce el
sindicato de 3 y **los tres son CAP**, con porcentajes de caja **7, 8 y 5**. Mismo sindicato, misma
fecha, tres tasas. Así que el porcentaje **no cuelga del sindicato**: va por empleado, y
probablemente por una tercera dimensión —la caja compensadora es un fondo de asignaciones
familiares, así que la carga de familia es el candidato—. Los valores que conviven son 2, 3, 5, 6,
7 y 8.

Por eso los tipos de atributo `CAJA_COMPENSADORA` (`PCT_CAJA_COMPENSADORA`) y `FDO_DESEMPLEO`
(`PCT_FDO_DESEMPLEO`) se crearon **por empleado**, decimales, clase EMPLEADO, `Obligatorio` en 0.
Creados el 3/10/2026 y **vacíos**: la carga espera las vigencias declaradas de Meta4.

El fondo de desempleo es 0,25% para **los 304** que lo pagan, sin excepción en 26 años, pero
*quién* lo paga no sale del sindicato: lo pagan CON (184), CAP (79), SOM (12), SSI (11) y PAT (2).
Una guarda por sindicato dejaría afuera al grueso.

**Dato aparte**: 6 de esos 9 empleados **no tienen el atributo SINDICATO cargado** y cobran cuota
sindical igual, por el camino de `PCT_CUOTA_SIND` (el parámetro por convenio+categoría que es el
`else` del 8522). `M4T_HIST_SINDICATOS` sigue sin migrar y está documentado como pendiente en
`scripts/MigrarAtributosCCT_1_Meta4_Oracle.sql`.

**Dónde iría una tasa que SÍ fuera por sindicato**: `Valor Atributo Liq.` tiene `Sufijo Parámetro`,
que ya se usa para la pesquería (TIPOACTIVIDAD PO→CAL, TA→LAN, ver
[[parametros-somu-por-pesqueria]]). Pero hoy sólo lo lee Cod50053.GestionFrancos, no el resolvedor
general de parámetros, cuyos sufijos son CCT, empleado y convenio.

## La fuente autoritativa es M4T_VAL_SINDICATO (Oracle)

Leída el 3/10/2026 por el puente `scratchpad/ora/m4.js`. **PK = (ID_SINDICATO, ID_CONCEPTO,
FEC_INICIO)**: la tasa cuelga del sindicato y del concepto, **con vigencia**, y no del empleado.
`ID_TIPO_APLICACION` vale 2 en las 20 filas. `ID_CONCEPTO` **no es** el código de nómina — filtrar
por 8542/8543 da cero filas; es un catálogo propio, y el puente al de nómina es
`Columna Hist. Meta4."Cód. Concepto Meta4"`.

Los cuatro que nos importan:

| ID_CONCEPTO | qué es | valores |
|---|---|---|
| 622 | cuota sindical | 10 sindicatos, 1,5 a 4,5, con historial |
| 621 | centro de capacitación | **PAT = 1** desde 1998 |
| 623 | fondo de desempleo | **CAP = 0,25** abierto; CON = 3 cerrado el 30/11/2023 |
| 8591 | cuota extraord. acción social | **CAP = 3** desde 2007-11 |

**Lo que esto resuelve.** El 621 confirma por fuente independiente el 1% del centro de
capacitación que ya cargué como `PCT_CENTRO_CAPACIT` (ver [[cuatro-conceptos-sin-disparar]]). El
8591 destraba el 8593, que usaba `PCT_CUOTA_EXT_CAP` y sólo existía como `_ESP_FE01` = 0,03: el
valor real es 3 para CAP. Y el 623 dice que el fondo de desempleo **va por sindicato**, así que el
tipo de atributo `FDO_DESEMPLEO` que creé por empleado hay que **borrarlo**.

**Y lo que NO resuelve: la caja compensadora no está en la tabla.** `PORC_CAJA_COMP` mapea al
concepto Meta4 **8541**, que no tiene ninguna fila acá. Eso confirma por la otra punta que es por
empleado —coherente con los tres CAP con 7, 8 y 5— así que `CAJA_COMPENSADORA` sí se queda.

**Las 10 tasas del 622 coinciden EXACTO con el `Valor Numérico` que BC tiene hoy** en los valores
de la lista SINDICATO (ASO 2,5 · CAP 2,5 · CON 4,5 · FEC 2,5 · MAQ 3 · PAT 3 · SBA 4,5 · SEC 4,5 ·
SOM 4 · STI 2). **Pero BC guarda un solo número por valor de lista y Meta4 lo versiona**: ASO fue
3 → 4 → 3 → 2,5, CON 3 → 4,5 el 1/12/2023, SEC 1,5 → 4,5 en 2001. O sea que BC tiene bien el corte
vigente y **recalcular cualquier período anterior a mayo de 2023 usa la tasa equivocada, sin
avisar**. Es exactamente el riesgo anotado arriba en esta misma nota.

**Dónde vive una tasa por sindicato con vigencia**: `Valor Atributo Liq."Valor Numérico"` no tiene
vigencia, así que no alcanza. El candidato es un Parámetro Vigente resuelto por el
`Sufijo Parámetro` del valor de lista — que existe y ya se usa para la pesquería, pero hoy sólo lo
lee Cod50053.GestionFrancos, no el resolvedor general, cuyos sufijos son CCT, empleado y convenio.

## Por qué NO se agregó el eje "por sindicato" a los parámetros

Se evaluó y se descartó el 3/10/2026, y la razón es una decisión de alcance: **sólo se liquida
desde 2026**. El eje se justificaba por el historial de la cuota sindical, pero las **diez
vigencias del concepto 622 están abiertas y todas arrancan antes de 2026** —la última que se movió
fue CON el 1/12/2023 y ASO el 1/5/2023—, así que dentro de 2026 no hay un solo cambio de tasa y el
único corte vigente es el que BC ya tiene bien en `Valor Numérico`.

Sin historial que representar quedaban tres tasas de un sindicato cada una, y para eso
`Parámetro Vigente` ya alcanza: tiene vigencia propia y la comparación por código funciona sola
(ver [[atributo-comparar-por-codigo]]). **Sin tocar el motor.**

Si alguna vez hay que liquidar un año en el que un sindicato renegocia a mitad de camino, el eje
vuelve a hacer falta: `Valor Numérico` no puede sostener "4,5 hasta junio y 5 después". El diseño
estaba medido y es chico —un campo `Cód. Sindicato` en `Parámetro Vigente`, el eje en
`Cod50071.ClavesParametroLiq` (que es deliberadamente el único lugar de la cascada) y resolver el
sindicato del empleado—, con **una trampa**: `LoadParametros` corre ANTES de `LoadAtributos`
(Cod50016, líneas 153 y 155), así que el código de sindicato no está en el contexto todavía y hay
que leerlo aparte. Reordenar no sirve: `LoadAtributos` está escrito para no pisar lo que ya ocupó
un parámetro, y el orden inverso invertiría esa precedencia.

Hay señal de que los valores se mueven dentro del año en curso: el concepto 4676 de
`M4T_VAL_SINDICATO` tiene vigencia nueva al 1/5/2026 con valores entre 70 y 75.

## Lo que quedó cargado el 3/10/2026

| Concepto | Fórmula | Tasa |
|---|---|---|
| 8542 caja compensadora | `round(BASE_SINDICAL * PCT_CAJA_COMPENSADORA / 100, …)` | atributo **por empleado**, 11 tramos |
| 8543 fondo de desempleo | guarda `= 'CAP'` | parámetro 0,25 |
| 8593 cuota extraord. | guarda `= 'CAP'` + `MAX(0, BASE_SINDICAL − TOPE_SIPA)` | parámetro **3** |

Tres cosas no obvias de esa carga:

- El **`MAX(0, …)` del 8593 es necesario**: 01541 (2,1 M) y 04893 (1,7 M) tienen base sindical por
  debajo del TOPE_SIPA (3.823.372,95), así que la resta da negativo y el concepto pagaría un
  crédito en lugar de un descuento.
- `PCT_CUOTA_EXT_CAP` pasó de fracción a porcentaje. La fila preexistente `_ESP_FE01` se
  **reescaló de 0,03 a 3** para que siga valiendo el mismo 3% ahora que la fórmula divide por 100:
  es conversión de unidad, no cambio de tasa. Es el riesgo de [[parametros-somu-por-pesqueria]]
  ("los PCT_ conviven en dos unidades").
- Los tramos de caja compensadora de los **cinco empleados cuyo último dato es de 2024-2025 se
  cerraron**, y quedaron abiertos sólo los cuatro que llegan al borde de los datos (2026-05/06).
  Dejarlos abiertos les cobraría en 2026 una tasa de cuando todavía aportaban.

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[tc-comprador-parametro-fantasma]]
- [[tipo-atributo-tres-campos-silenciosos]]
- [[un-valor-una-fuente]]
- [[veda-como-atributo-del-buque]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
