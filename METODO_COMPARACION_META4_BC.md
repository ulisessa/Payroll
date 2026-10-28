# Cómo se compara una liquidación de Meta4 contra una de BC

Meta4 fue producción de enero a julio de 2026 y BC corrió en paralelo. Esto es el método para
decidir si el motor de BC está dando bien, y para que una diferencia se pueda atribuir a algo
concreto en vez de discutirse.

La regla que ordena todo lo demás: **una diferencia no es un hallazgo hasta que se sabe de qué capa
viene.** Hay cuatro capas y sólo la última es "el motor está mal".

| Capa | Qué significa la diferencia | Dónde se resuelve |
|---|---|---|
| Asimetría | de un lado entra algo que del otro no | el filtro de la comparación |
| Mapeo | no se sabe contra qué concepto comparar | el catálogo de columnas |
| Dato | falta un parámetro, una novedad, un estado | la configuración |
| Motor | la fórmula da otro número | la fórmula o el orden de cálculo |

## Los cuatro niveles de la comparación

### 0 — El archivo literal de Meta4, adentro de BC

Es la fuente contra la que se compara todo: 485.000 cabeceras y ~117 millones de valores, los 31
años, sin traducir.

- [Hist. Liq. Meta4](src/Tables/Tab110054.HistLiqMeta4.al) — la cabecera de cada corrida
- [Columna Hist. Meta4](src/Tables/Tab110055.ColumnaHistMeta4.al) — el catálogo de las ~1.818 columnas
- [Valor Hist. Meta4](src/Tables/Tab110056.ValorHistMeta4.al) — forma angosta, sólo los no nulos

Se navega con [Historia de Liquidaciones (Meta4)](src/Pages/Pag110047.HistoriaLiqMeta4.al). Está
adentro del producto a propósito: la comparación tiene que poder filtrar y hacer drilldown, y un
Excel exportado envejece en cuanto alguien recalcula.

**Nada de acá alimenta el cálculo de BC.** Los conceptos `HIST_*` vencen el 31/12/2025 y 2026 no se
cargó como historia: si se cargara, el mes contaría dos veces en los acumuladores en cuanto se
aprueben las liquidaciones que BC ya tiene calculadas.

### 1 — La pantalla, por empleado-mes o por marea

[Comparar BC contra Meta4](src/Pages/Pag110051.CompararBCMeta4.al) pone lado a lado **tres pares de
importes, no uno**: bruto, descuentos y neto.

Son tres porque un bruto que cierra no garantiza un neto que cierre —las retenciones tienen sus
propios topes y escalas— y porque el grossing-up tapa los errores al revés: donde hay neto
garantizado el neto sale bien siempre y el bruto es el que miente.

De cada lado:

| | Meta4 | BC |
|---|---|---|
| Bruto | `TOT_REMUN_27617` | `REMUNERATIVO_BRUTO` **+** `NO_REMUNERATIVO` |
| Descuentos | `TOT_RETEN` | `Total Descuentos` de la cabecera |
| Neto | `LIQUIDO` | `Neto a Pagar` de la cabecera |

El bruto de Meta4 incluye el acuerdo sindical del Dto 633/18, que es no remunerativo; enfrentarlo
contra `REMUNERATIVO_BRUTO` solo mostraba un −70% inexistente, y justo en los tripulantes, donde el
70/30 del 729/15 es más grande que la parte remunerativa.

Los descuentos y el neto salen de la **cabecera** y no de sumar líneas por tipo de concepto: daría
casi lo mismo pero no igual, y lo que se compara es lo que el recibo dice que cobra la persona.

### 2 — El drilldown, concepto por concepto

Clic en la diferencia abre [Qué explica la diferencia](src/Pages/Pag110052.DetalleCompMeta4.al), que
clasifica cada fila en cuatro orígenes:

- **Ambos** — hay valor de los dos lados; interesa el que no cierra
- **Sólo Meta4** — el motor no lo liquidó
- **Sólo BC** — el motor liquidó de más
- **Sin equivalencia** — hay valor en Meta4 y no se sabe qué concepto de BC le corresponde

Las dos últimas no se mezclan nunca: "Sin equivalencia" es un hueco del mapeo, no un defecto del
motor, y confundirlas hace perder tardes persiguiendo fórmulas que están bien.

### 3 — El recibo de Meta4 en PDF

Cuando el archivo no alcanza —un valor que no está en ninguna columna, o hay que ver el recibo tal
como lo vio la persona— se va al PDF. Están por mes en `2026-01/` … `2026-08/`, nombrados por fecha y
tipo de corrida: `FRA` francos, `PUE` puerto, `MAR` marea, `EMB` embarcados, `VAC` vacaciones, `ADM`
administrativos, `BAJ` bajas.

[recibos_2026-01_extraidos.tsv](recibos_2026-01_extraidos.tsv) es el índice página por página de
enero (archivo, tipo, página, legajo, CUIL, ingreso, buque, desde/hasta, categoría, grupo): sirve
para no abrir seis PDF buscando un legajo.

Se extraen con `pdftotext`. **`-layout` no respeta la grilla cuando una celda queda vacía** y corre
las columnas una posición: hay que usar `-table`. Con `-layout`, ESCALANTE salía con la categoría del
renglón de al lado — ver la nota en
[CorregirCategoriaPersonalProyectoA28M59.sql](scripts/CorregirCategoriaPersonalProyectoA28M59.sql).

Del PDF salieron cosas que no existen en ninguna otra parte: los básicos de oficiales de enero-abril
2026 ([CargarValoresOficiales768.sql](scripts/CargarValoresOficiales768.sql)) y la validación 49/52
de vacaciones de tripulantes.

## Lo que hace que la comparación no mienta

### Simetría: lo que se excluye de un lado se excluye del otro

Una asimetría no produce un error, produce **una diferencia inventada**, y esas cuestan más caro que
un bug porque parecen un bug.

| Se deja afuera de Meta4 | Y por lo tanto de BC |
|---|---|
| la corrida mensual (`TP_IMPUT` 1) | la liquidación sin proyecto (la regular de la nómina) |
| la liquidación final (`TP_IMPUT` 14) | ídem |
| contribuciones patronales (clasificación `CT`) | `Tipo Concepto` = Contribución Patronal |
| días, cantidades y precios (`D`, `P`, `U`) | `Tipo Concepto` = Informativo |
| — | `Es Devengo` = sí |
| — | `Cód. Tipo Liq.` = `HIST_REMUN` |

Las dos últimas no tienen contraparte porque no existen en Meta4: el devengo (SAC 4750-4754, francos
1062) se provisiona y no está en el recibo, y `HIST_REMUN` **es** Meta4 importado — compararlo contra
Meta4 da cero siempre.

Cada una de esas filas se pagó con una diferencia falsa: `AÑOS_ANTIGUEDAD` = 23 aparecía como 23
pesos a favor de BC; los 7000-7080 salían como "Sólo BC" por 1,7 millones; el SAC devengado del 00949
inventaba un 30% sobre un recibo de 1.094.676.

### Cada columna de Meta4 tiene su propia semántica temporal

Viven en la misma tabla y no se comportan igual. Confundirlas es el error más caro del método.

| Columna | Qué guarda cada corrida | Cómo se agrega |
|---|---|---|
| `TOT_REMUN_27617` | el acumulado del mes **hasta ella** | diferencia contra la corrida anterior, en orden de `CONTADOR_LIQ` |
| `TOT_RETEN`, `LIQUIDO` | lo suyo | suma |
| `IG_*` | el acumulado del año | máximo |
| devengos y retenciones (`DV`/`RT`/`SS`) | lo suyo | suma |

Consecuencias que no son evidentes:

- **El orden es `CONTADOR_LIQ`, no la fecha.** El legajo 03774 en enero 2026 tiene la corrida del 19
  con contador 6 y la del 6 con contador 7.
- **No se puede saltear ninguna corrida del acumulado corrido.** Filtrar los anticipos (`TP_IMPUT` 4)
  no los saca: los esconde dentro de la corrida siguiente, atribuidos a otra marea. El 04190 tiene un
  anticipo de 250.000 en el contador 0 que aparecía dentro del cierre. En el **drilldown** sí se
  saltean, porque ahí cada columna vale por sí misma.
- **No se puede filtrar la marea en la consulta del bruto.** Leer directo la corrida de la marea 58
  devuelve 58 + 59, porque la 59 corrió antes y ya está adentro del número. Se recorren todas las
  corridas del empleado-mes, se resta contra la anterior y después se suman sólo las diferencias de la
  marea pedida. En el drilldown sí se filtra.
- **El corte es por mes entero.** Partir un mes enfrenta el acumulado de todo el mes contra unos días
  de BC.

### La unidad manda sobre el mapeo

De las 1.646 columnas con datos sólo 420 son importes (`DV` devengos, `RT` retenciones al empleado,
`SS` seguridad social). El resto son días, cantidades, precios unitarios, contribuciones y maquinaria
interna de Meta4.

**`D` es DÍAS, no descuentos.** La inicial engaña y meterlas pone un `27` al lado de un
`2.493.907,25` en la misma columna de diferencia. Se detectan por el total: `DIAS_ALTA` suma 9.958
para 330 empleados, que son 30 días cada uno, no pesos.

Que una columna tenga concepto de BC asignado **no la vuelve un importe**: el mapeo automático es por
nombre y `DIAS_MES_VAC` (2,917 días) y `PR_FRANCO` (precio unitario) salían como diferencias. El
mapeo dice *contra qué* comparar, la clasificación dice *si* se puede comparar, y la segunda manda.

La única excepción es `Mapeo Verificado`: equivalencias comprobadas cuya columna está clasificada `AX`
o sin clasificar. Comprobadas **aritméticamente**, no por nombre — el incremento mensual de
`IG_TOT_C_IM_ST` es exactamente `TOT_REMUN_27617` + `BSAC_MES_RG3976` al centavo, y eso valida el
4750. De los 205 mapeos que salieron por nombre, al menos cinco son colisiones reales: 1054 es "Ds
vacac deveng mes act" en Meta4 y "Antigüedad mensuales" en BC.

### La marea sólo existe fila por fila

`ID_MAREA` agregado por empleado-mes engaña: da la marea de la última corrida, que suele ser la
siguiente, ya reembarcado. El 03664 en enero tiene contador 1 → marea 59 (el cierre, el que coincide
con el recibo), contador 2 → marea 58, contador 3 → marea 60.

El filtro de marea acota **los dos lados a la vez**: del lado de BC por proyecto (`PP-128-000059` es
buque 128, marea 59), del lado de Meta4 por `ID_MAREA` de cada corrida. Acotar uno solo enfrenta una
marea contra un mes y **todas** las diferencias que muestra son inventadas.

Sin filtro se compara el mes entero, que es otra pregunta y también válida. El 37% de los
empleado-mes tienen más de una marea: no es un caso de borde.

## El procedimiento

1. **Antes que nada, el catálogo tiene que estar poblado** (`Clasificación Meta4` y `Cód. Concepto
   BC`). Sin eso el drilldown mostraba todo como "Sólo BC" con Meta4 en cero, que se lee como "Meta4
   no liquidó nada" — lo contrario de la verdad. Ya pasó: los campos se publicaron, el script que los
   llena no se corrió, la página no falló y mostró una comparación creíble y equivocada. Hoy avisa con
   un error en vez de seguir.
2. Abrir la pantalla: año 2026, **Sólo meses que BC calculó** y **Sólo diferencias**. Sin el primero
   aparecen los meses que BC todavía no calculó, que son la mayoría y tapan lo que importa.
3. Mirar `% Dif.` del bruto, pero **no sólo el bruto**: las tres columnas están coloreadas por
   separado porque el bruto puede cerrar y el neto no.
4. Drilldown en la diferencia y clasificar el hallazgo en una de las cuatro capas de arriba. "Sin
   equivalencia" → capa mapeo. "Sólo BC" de un concepto que Meta4 no tiene en el recibo → revisar
   simetría antes de tocar la fórmula.
5. Si es del motor, contra el recibo en PDF: el archivo dice el número, el recibo dice qué vio la
   persona.
6. Limpiar **de arriba hacia abajo**: fase, después estado, después asignación. El síntoma aparece una
   capa abajo del problema.

### Cómo se leen los signos

Siempre **BC menos Meta4**, pero no significan lo mismo:

- bruto positivo → BC liquidó de más → sube el neto
- **descuentos positivo → BC retuvo de más → BAJA el neto**
- neto positivo → la persona cobraría más con BC

`Con borrador` marca que entraron liquidaciones en Borrador. Cuentan en esta comparación pero **no**
en los acumuladores del motor, que filtran `Estado <> Borrador`: sin la marca, una diferencia de cero
acá puede convivir con un YTD en cero allá y no se entiende por qué.

## Lo que NO es este método

[CompararEneroMotor.ps1](scripts/CompararEneroMotor.ps1) es otra cosa: compara **BC contra BC**, antes
y después de un cambio en el motor. Hashea fila por fila las cinco tablas de resultado de las 519
liquidaciones de enero 2026 y guarda `Before.json` / `After.json`. Se usa para demostrar que un
refactor no movió nada, no para validar contra Meta4. Se corre `-Before` antes de tocar y `-After`
después; se niega a sobrescribir una referencia existente.

Los dos se complementan: la comparación contra Meta4 encuentra el error, el snapshot demuestra que
arreglarlo no rompió lo que ya cerraba.

## Límites conocidos

- **La unidad mínima es el empleado-mes, o el empleado-marea.** No se compara recibo por recibo: un
  mes con tres corridas de Meta4 y dos liquidaciones de BC se compara agregado.
- **El mapeo por nombre es parcial.** El `NOMBRE_CORTO` de `M4SYS_CONCEPTOS` no siempre es el nombre
  de la columna física: 1003 Sueldo tiene `NOMBRE_CORTO` = `SAL_BASE` y la columna se llama `SUELDO` —
  el concepto más grande de todos. Reconstruir importes desde ese mapeo dio 25% bajo; por eso las
  bases de Ganancias salieron de diferenciar acumuladores, no de acá.
- **Una columna sin concepto no es un error**, es que no hay equivalencia conocida.
- **Un `DATE` de Oracle lleva hora** y el campo de fecha del archivo no la admite. La inserción no
  falla: falla la página al abrir. Cualquier carga nueva trunca del lado de Oracle.
- **2026 es referencia, no insumo.** Nada de esta comparación se escribe en ninguna tabla: los buffers
  ([Comp. Meta4 Buffer](src/Tables/Tab110057.CompMeta4Buffer.al),
  [Comp. Det. Meta4 Buffer](src/Tables/Tab110058.CompDetMeta4Buffer.al)) son temporales y se arman en
  memoria cada vez que se abre la página.
