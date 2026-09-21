# Carga de valores de liquidación — SOMU, oficiales y fuera de convenio

**Estado:** las ocho preguntas abiertas están contestadas (17/9/2026). El lado
**calamar está completo y verificado**; falta cargar el lado **langostino**, que
depende de una sola decisión pendiente (ver el final).

**Vigencia de esta tanda:** `2026-05-01`, con la salvedad del apartado *Vigencias*.

---

## Lo verificado contra la base

La versión anterior de este documento daba tres valores por confirmados. **Dos no
existen**: `PRECIO_PUERTO_175/75_OF01` y `_OF02` no están en la base. El único
real es:

| Parámetro | Valor | Celda del Excel |
|---|---|---|
| `VALOR_PLUS_PROD_ESP_FE01` | 41,91 | Fuera de convenio · ADICIONAL PRODUCCIÓN · Patrón argentino · banda 6000-8000 |

Y `105 × 0,77 × 0,9 × 0,8 × 0,72 = 41,91` cierra exacto, así que confirma la
cadena de cálculo del bloque *fuera de convenio* y que la banda cargada es
**6000-8000**. No confirma nada sobre oficiales.

---

## El modelo, que es uno solo

Todo SOMU —las dos pesquerías, los valores fijos y los de producción— sale de
**un índice y unos pocos números base**. El índice está escrito en las fórmulas
de los dos Excel, sin ambigüedad:

```
ROUND(base/70*100, 0)   MR00  PRIMER PESCADOR
ROUND(base/70* 85, 0)   MR01  CONTRAMAESTRE      MR02  PRIMER COCINERO
ROUND(base/70* 80, 0)   MR03  MOZO   MR06 ENFERMERO   MR07 CONTRAM. FRÍO   MR09
ROUND(base/70* 75, 0)   MR04  ENGRASADOR         MR05  MARINERO CUBIERTA
base                    MR08  MARINERO DE PLANTA        ← el único a mano
```

En tangoneros son las celdas `B58:B62` de *Det valores*; en calamar, `B3:F5`.
El archivo de calamar además **nombra** la agrupación —su columna D se titula
*"CONTRAMESTRE FRIO ENFERMERO MOZO"*—, lo que cierra sin margen la pregunta de a
quién siguen `MR06` y `MR07`.

Sobre el básico, las demás columnas son múltiplos fijos:

| Columna | Múltiplo del básico |
|---|---|
| PUERTO | × 2,891 |
| FRANCOS | × 2,4 |
| ÓRDENES | × 1,5 |
| ADIC ART 23 / ART 33 | × 0,6 |

Por eso arrastran el mismo índice, y por eso **un valor de SOMU cuyo cociente
contra `MR08` no dé 100/85/80/75/70 está mal por dentro**, sin necesidad de
compararlo contra ninguna fuente externa. Ese control encontró hoy dos errores
(ver *Correcciones aplicadas*).

> **Ojo con ese control:** vale sólo para los parámetros que derivan del básico.
> Los `PCT_*` no —son porcentajes, planos por categoría o con escala propia—, y
> sin excluirlos el control marca 18 celdas de las que 13 son falsos positivos.

---

## Las ocho preguntas, contestadas

| # | Pregunta | Respuesta |
|---|---|---|
| 1.1 | ¿Oficiales también a `768/19`? | **Todo se parametriza en `768/19`.** |
| 1.2 | ¿`MR06` y `MR09`? | **Siguen a Mozo** (índice 80). `MR09` Segundo Contramaestre Argentino existe pero tiene **cero legajos**. |
| 1.3 | ¿Español vs argentino? | **Atributo del empleado.** Cambia sólo la reducción 2016 (0,23 vs 0,28) y si cobra adicional por producción. Una sola categoría `FE01`. |
| 1.4 | ¿Crear ahora los parámetros base sin uso? | **Sí.** |
| 2.1 | ¿Banda arriba de 8500? | **No hay.** El escalón alto es `>= 8000` y no reduce. |
| 2.2 | ¿`MR07` en producción? | **Sigue a Mozo**, igual que en los valores fijos. |
| 2.3 | ¿Existe el +15 % por tareas mecánicas? | **Sí: concepto `2073`, "Adicional tareas mecanicas".** |
| 2.4 | ¿La tabla base de empresa oficiales? | El **índice ya existe** como `PCT_ESCALA_ARBU_175/75_*` (1,15 / 1,00 / 0,85 / 0,85). Falta sólo la columna base, que en el libro está a mano. |

---

## Estructura real de los parámetros

Tres cosas que la versión anterior de este documento tenía mal.

**1. Los parámetros de SOMU se parten por pesquería.** No existe `PRECIO_PUERTO`
a secas: son `PRECIO_PUERTO_LAN` y `PRECIO_PUERTO_CAL`, y lo mismo
`VALOR_FRANCO_*`, `PRECIO_ORDENES_*` y `PRECIO_NAV_*`. Hoy las fórmulas consumen
`_CAL`, porque las pruebas van por poteros.

**2. `PCT_DOLAR_PROD` NO se parte por pesquería.** Es un único parámetro por
convenio y categoría: 60 para `175/75`, 78 para `729/15`, 90 para `768/19`. La
misma fila sirve a langostino y a calamar, así que no hay forma de que las dos
pesquerías difieran aunque se quisiera. Los tres valores están probados y son
correctos; **no se tocan**.

**3. Los porcentajes se guardan como porcentaje, no como fracción.**
`PCT_PROD_768/19_OF01` vale `2.20`, no `0,022`. Es deliberado, para presentarlos
tal cual en el recibo. Las tablas de este documento están en fracción: **hay que
multiplicar por 100 al cargar.**

Y un residuo: hay **45 valores cargados bajo `PRECIO_PUERTO` pelado**, un
parámetro base que no existe en la tabla `Parámetro` y que ninguna fórmula lee.
34 son idénticos a los de `_LAN` y 11 difieren: es una copia vieja a medio
actualizar. Se borra apenas se resuelva la decisión pendiente.

---

## Vigencias

SOMU ya tiene **cinco vigencias en 2026** para los parámetros que se actualizan
por paritaria: `2026-01-01`, `02-01`, `03-01`, `05-01` y `06-01`. Cargar esta
tanda sólo con vigencia `2026-05-01` dejaría los valores nuevos una vigencia
atrás de los que ya están. Los valores de enero a mayo salen de
`Valores Liquidación TANGONEROS 08-2025.xlsx`.

---

## Qué falta cargar

### SOMU · `729/15` · langostino

De los 40 valores del bloque (8 categorías × 5 parámetros), **32 no existen**:
`BASICO`, `VALOR_FRANCO_LAN`, `PRECIO_ORDENES_LAN` y `PRECIO_INCENT`. Los 8 de
`PRECIO_PUERTO_LAN` sí están.

Base de mayo 2026, Marinero de Planta: `747844`. El resto sale del índice.

| Categoría | `BASICO` | `VALOR_FRANCO_LAN` | `PRECIO_ORDENES_LAN` | `PRECIO_INCENT` |
|---|---|---|---|---|
| MR00 | 1.068.349 | 2.564.037 | 1.602.523 | 2.143 |
| MR01 · MR02 | 908.096 | 2.179.431 | 1.362.144 | 1.821 |
| MR03 · MR06 · MR07 | 854.679 | 2.051.229 | 1.282.018 | 1.714 |
| MR04 · MR05 | 801.261 | 1.923.027 | 1.201.892 | 1.607 |
| MR08 | 747.844 | 1.794.826 | 1.121.766 | 1.500 |

### Oficiales · `768/19`

| Categoría | `BASICO` | `PRECIO_PUERTO_LAN` | `VALOR_FRANCO_LAN` | `PRECIO_ORDENES_LAN` |
|---|---|---|---|---|
| OF01 Capitán | 3.000.000 | 5.500 | 3.450 | 3.000.000 |
| OF02 Jefe de Máquinas | 1.500.000 | 3.600 | 3.000 | 2.250.000 |
| OF03 1er Of. Cubierta | 2.295.000 | 4.304 | 2.700 | 2.295.000 |
| OF04 1er Of. Máquinas | 1.275.000 | 3.060 | 2.550 | 1.912.500 |

### Producción langostino

| Qué | Cómo | Cuántos |
|---|---|---|
| `PROM_EXPORT_USD_TON` | parámetro global, vigencia por fecha | 1 |
| Factor de banda | Tabla Escalonada sobre el anterior, tramos `<6000` / `6000-8000` / `>=8000` | 2 tablas × 3 |
| `VAL_TON_PROD` por clasificación | 5.800 / 5.500 / 4.500 / 3.900 / 3.500 / 3.100 · colas 4.500 · roto 3.000 | 8 |
| `PCT_PROD` por categoría | ver abajo, **×100 al cargar** | 8 |
| Índice empresa oficiales | ya existe (`PCT_ESCALA_ARBU`) | — |
| Reducciones 2008 / 2016 / −15 % nominal | atributo del empleado | 3 |

Factores de banda: **0,78 / 0,82 / 1,00** general y **0,73 / 0,77 / 1,00** patrón
de pesca. `PCT_PROD`: Capitán 0,0220 · 1er Of. Cubierta 0,0180 · Jefe Máq. 0,0191
· 1er Of. Máq. 0,0163 · MR00 0,0105 · MR01/MR02 0,0100 · MR03/MR04/MR05 0,0090 ·
MR08 0,0085.

### Columnas sin destino

Siguen sin parámetro base y sin fórmula que las consuma. Por la respuesta 1.4 se
crean igual, vacías, para que estén cuando exista el concepto: `ASEG MAREA CCT`,
`ASEG PUERTO EMPRESA`, `ASEG MAREA EMPRESA`, `ASEG REPARAC`, `FRANCOS EMPRESA`,
`ASEG MAREA` (SOMU), `ASEGURADO VACACIONES`, `% PARTICIPACIÓN`, `% REDUC 2008` y
`% REDUC 2016`.

`ADIC ART 23` y `ADIC ART 33` **no** se cargan: son el 60 % del básico y el
sistema ya tiene `PCT_ADIC_ART_33` = 0,6.

---

## Producción calamar — completo

`Valores  producción calamar campaña 2026.xlsx`, tres números base y el índice:

| Clasificación | Base (`MR08`) | Parámetro |
|---|---|---|
| ENTERO | 10.000 | `VALOR_CAL_ENT` |
| REJO SUCIO | 6.400 | `VALOR_CAL_REJ` |
| VAINA | 18.303 | `VALOR_CAL_VAI` |

Las 30 celdas (3 × 10 categorías, incluida `MR09`) están cargadas con vigencia
`2026-01-01` y **verificadas contra el Excel**.

---

## Correcciones aplicadas el 17/9/2026

**`PRECIO_PUERTO_LAN` — cinco categorías fuera de escala**, todas de menos.
`scripts/CorregirEscalaPrecioPuertoLAN.sql`.

| Vigencia | Categoría | Índice que tenía | Debía | Diferencia |
|---|---|---|---|---|
| 2026-01 | MR01 Contramaestre | 58,79 | 85 | +719.407 |
| 2026-01 | MR02 Primer Cocinero | 58,79 | 85 | +719.407 |
| 2026-05 | MR00 Primer Pescador | 75 | 100 | +809.063 |
| 2026-05 | MR06 Enfermero | 75 | 80 | +161.813 |
| 2026-05 | MR07 Contram. de Frío | 70 | 80 | +323.625 |

En mayo el Primer Pescador —el tope de la escala— cobraba lo mismo que un
Marinero de Cubierta. **Sin liquidaciones afectadas:** ninguna fórmula consume
`_LAN` todavía.

**`VALOR_CAL_*` — 18 valores con el cociente redondeado.**
`scripts/CorregirValoresCalamar2026.sql`. Se habían multiplicado por el cociente
a cuatro decimales (`1,4286`) en vez de por la fracción exacta, y sin redondear:
`6400 × 1,4286 = 9143,04` donde el Excel dice `9143`. Diferencias de −0,17 a
+0,67 por tonelada.

> **Pendiente de esta corrección:** hay **29 liquidaciones en estado Calculada**
> del 29/1/2026 que usaron los valores viejos. Hay que recalcularlas; el script
> las lista. Las 74 Aprobadas son del 31/12/2025, anteriores a la vigencia. No
> hay ninguna Contabilizada.

---

## Lo único que queda abierto

**¿Cuál es el valor base de puerto de mayo 2026 para SOMU?** Hay tres números
para el mismo concepto:

| Fuente | Valor (`MR08`) |
|---|---|
| Excel de tangoneros | 2.162.017 |
| `PRECIO_PUERTO` pelado | 2.162.552 |
| `PRECIO_PUERTO_LAN` | 2.265.375 |

Y el `× 2,891` del Excel **está redondeado**: el archivo de 08-2025 implica
2,8916. O sea que copiar el Excel probablemente empeore el dato en vez de
mejorarlo. Esto lo tiene que zanjar nómina, y de su respuesta dependen la carga
del bloque SOMU langostino y el borrado de los 45 valores huérfanos.
