---
aliases: ["A cuenta de futuros aumentos: puerto (2013)"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# A cuenta de futuros aumentos: puerto (2013)

Concepto 2013; prorrateo del neto garantizado menos lo liquidado de puerto, con los operandos identificados pero la base de días sin resolver

Concepto **2013** (`A_CTA_FUT_AUM_P` en Meta4), hermano del 2083 — ver
[[a-cuenta-futuros-aumentos-francos]]. En BC existe **sin fórmula**. La regla de negocio es

    a cuenta = prorrateo del monto garantizado − total liquidación puerto

y al 28/9/2026 está **resuelta para la guardia de puerto**: se verifica exacta en **11 de 11**
entradas de enero a abril de 2026.

    a cuenta = NTO_GARANTIZADO × DOLAR_COMPRA / 30 × días_de_guardia × 1,4
               − ( SUELDO_PUERTO + SUELDO_DIA_FDO + ANTIGUEDAD )

## Implementado el 28/9/2026 (`c2013_asegurado.sql`, commiteado)

Tres parámetros nuevos y la fórmula. Los nombres se acortaron a **`SALARIO_ASEG_CAL`** y
**`SALARIO_ASEG_LAN`** porque `Código` en `Parámetro` es **Code[20]** y `SALARIO_ASEGURADO_CAL` tiene 21.

    IF(TIPOACTIVIDAD = 1,
       IF(SALARIO_ASEG_CAL * DIAS_GP_PERIODO = 0, 0,
          round(SALARIO_ASEG_CAL / 30 * DIAS_GP_PERIODO * IFZERO(COEF_GUARDIA_PUERTO,1) * TC_COMPRADOR
                - (#1083 + #1023 + #1053), PRECISION_REDONDEO)),
       IF(SALARIO_ASEG_LAN * DIAS_GP_PERIODO = 0, 0,  ... ídem con _LAN ... ))

La guarda va sobre **el producto del importe por los días**, que es la lección que dejó el 2083 —ver
[[a-cuenta-futuros-aumentos-francos]]—: con importe cargado y cero días la resta da negativo.

27 vigencias al 1/1/2026: 18 de marinería (9 categorías × 2 pesquerías, escala del Art. 31 sobre 1.600
y 1.500), 8 de oficiales (OF01 6.900, OF03 5.400, OF02 4.783, OF04 4.065, iguales en las dos
pesquerías) y `COEF_GUARDIA_PUERTO_175/75` = 1,4.

**Cobertura medida contra `NTO_GARANTIZADO`, enero a abril:**

    729/15   1.521 entradas / 220 empleados coinciden   |   419 / 52 difieren
    768/19     131 /  20 coinciden                       |    23 /  2 difieren
    175/75      24 /  13 coinciden                       |    54 /  7 difieren

Lo que difiere en marinería es el índice: **ni la categoría ni el puesto de BC lo determinan**
—pesquería+categoría acierta en 6 de 13 grupos y pesquería+puesto en 7 de 14—, y el mismo trio
(CAL, MR08, MR08) aparece con cuatro índices distintos. Falta el historial de puestos:
`M4T_HIST_PUESTOS` sigue sin migrar, ver [[puesto-vs-categoria-cct]].

En oficiales los 7 que difieren tienen acuerdos individuales —5.500, 7.000, 15.000, 5.950— y varios
**cambian de valor dentro del período**, así que necesitan filas por empleado con vigencias. No se
cargaron: las fechas habría que inventarlas. La cascada de [[get-con-menos-argumentos]] ya soporta el
nivel empleado, así que se agregan sin tocar nada más.

## El prorrateo del monto garantizado

Meta4 lo guarda ya calculado en **`BRUTO_PRORRAT`**, y sale de

    BRUTO_PRORRAT = NTO_GARANTIZADO × DOLAR_COMPRA / 30 × días

`NTO_GARANTIZADO` es un importe mensual en dólares, y el TC es el **comprador**, igual que en el 2083.

**No es un importe por empleado: es el SALARIO ASEGURADO del CCT.** Lo confirma el acta de buques
poteros (CCT 356/03), que trae una columna “ASEGURADO U$S” con exactamente estos valores, y otra
“INCENTIVO PRODUCCIÓN” con los restantes. Las dos salen de la escala de Marinero de Planta a
índice 70 —ver [[escala-somu-indice-70]]—, o sea del mismo mecanismo que ya está en el modelo:

    asegurado 100% = 1.600 / 0,70 = 2.285,7143      incentivo 100% = 1.500 / 0,70 = 2.142,8571

    %     asegurado    incentivo        (el acta los imprime redondeados: 2.286, 1.943, 1.829…)
    100    2.285,71     2.142,86
     85    1.942,86     1.821,43
     80    1.828,57     1.714,29
     75    1.714,29     1.607,14
     70    1.600,00     1.500,00

**Las 24 combinaciones de categoría y valor de enero de 2026 caen en esa tabla, sin una sola
excepción**: o son el asegurado de un índice o el incentivo de otro. Ojo con 1.714,29, que es a la vez
el asegurado del 75% y el incentivo del 80% —la escala los hace coincidir—, así que no discrimina.

**El índice que manda no es el de la ficha.** Empleados con categoría MR08 aparecen con valores del
70, 75, 80 y 85%, y por eso agrupar por puesto daba mejor que por categoría: el índice es el del
**puesto a bordo** de esa marea. Ver [[puesto-vs-categoria-cct]].

Yo había leído estos 18 valores como acuerdos individuales y **estaba equivocado**: el usuario lo dudo
—“dudo que haya un neto garantizado distinto para 259 tripulantes”— y tenía razón. El error de método
fue contar empleados en vez de valores distintos: 259 empleados, 18 valores, una escala de 5 índices
por dos columnas.


**Los días son los de GUARDIA de puerto, y llevan una prima de 1,4.** Despejando los días
implícitos —`BRUTO_PRORRAT / (NTO_GARANTIZADO × TC / 30)`— y dividiéndolos por `DIAS_PUERTO`, el
cociente da **exactamente 1,4000 o 1,0000, nunca nada intermedio**, y el 1,4 es el de la guardia. Va como parámetro por convenio (decisión del usuario, 28/9/2026). El
00794 lo repite los cuatro meses: 43,4/31, 39,2/28, 43,4/31 y 5,6/4.

**Y el 1,4 es lo que decide que la regla cierre**, enero a abril de 2026:

    factor 1,4  ->  11 de 11 cumplen al centavo
    factor 1,0  ->   2 de 15

El 1,4 **no está en ninguna columna de la entrada**: es configuración de Meta4. En BC el disparador
es `DIAS_GP_PERIODO`, no `DIAS_PUERTO` — ver [[antiguedad-no-cuenta-dias-gp]], donde la misma
distinción ya había mordido.

**Lo que queda abierto** son los casos de factor 1,0 —puerto sin guardia, 2 de 15— y **mayo y junio
enteros, donde no cierra ninguno**: coincide con el cambio de régimen de
[[precio-puerto-lista-inconsistente]], que en mayo pasa el precio de puerto a dólares.

## El índice sale del PUESTO EFECTIVO, y está en el histórico

`Hist. Liq. Meta4` trae **`ID_PUESTO`** en cada entrada —449.799 filas—, y es él quien determina el
índice, no la categoría de la ficha:

    pesquería + ID_PUESTO      23 de 25 grupos con un solo valor
    pesquería + ID_CATEGORIA   15 de 24

El mapeo es limpio: `PT02` 70%, `CB07` y `MQ05` 75%, `ME02` y `PT04` 80%, `CB06` y `ME01` 85%,
`CB04` 100%. No hace falta migrar `M4T_HIST_PUESTOS` para verificarlo —el dato ya está importado—,
sí para que BC lo use en el cálculo. Ver [[puesto-vs-categoria-cct]].

## Oficiales: cargados por empleado el 28/9/2026

En oficiales el asegurado **no sale del convenio**: son acuerdos particulares. Dentro de 175/75 OF02
y en el mismo mes conviven 4.783, 5.500, 7.000 y 15.000. Se cargaron **70 vigencias a nivel empleado**
—35 tramos × 2 pesquerías— para **21 oficiales**, derivadas de `NTO_GARANTIZADO` mes a mes
(`aseg_oficiales_emp.sql`).

Dos decisiones que conviene recordar: se carga el **historial completo** del empleado y no sólo los
meses que difieren, para que la clave de empleado resuelva sola desde enero sin depender de que el
motor caiga al nivel categoría; y el primer tramo se fuerza al 1/1 aunque el oficial no tenga
liquidación en enero.

**Control: 185 de 185 meses-empleado coinciden**, 39 oficiales, cero diferencias.

## El total liquidación puerto

Es **`TOT_HAB_GZDO`**, que en estos recibos es exactamente
`SUELDO_PUERTO + SUELDO_DIA_FDO + ANTIGUEDAD`. Las dos lecturas dan el mismo resultado, así que la
composición está confirmada.

**El testigo limpio es el 00794 de enero de 2026**, que sólo tiene puerto:

    BRUTO_PRORRAT   9.790.960,43
    TOT_HAB_GZDO    2.160.000,00   ( 1.860.000 puerto + 67.500 feriado + 232.500 antigüedad )
    A_CTA_FUT_AUM_P 7.630.960,43   = la resta, al centavo

## No son dos columnas: son dos escalas, una por pesquería

Leí la tabla del acta de poteros como “asegurado contra incentivo” y **estaba mal**. Cruzando el valor
contra el `TIPOACTIVIDAD` del buque, enero a abril de 2026, la separación es total:

    potero     -> escala de 1.600   833 entradas,  0 de la otra
    tangonero  -> escala de 1.500   821 entradas,  0 de la otra

**Cero cruces.** Lo destrabó el usuario con un dato de negocio que no está en los datos: *de enero a
abril los tangoneros no tienen producción, sólo los poteros*. Cada pesquería tiene su propia acta y su
propio salario asegurado; lo que yo tomaba por la columna “INCENTIVO PRODUCCIÓN” del acta de poteros
es, numéricamente, **el asegurado de los tangoneros**. La escala es la misma de siempre, índice 70
sobre Marinero de Planta —[[escala-somu-indice-70]]—, sólo que con dos bases:

    índice 70:   potero 1.600 USD      tangonero 1.500 USD

**Y está en el texto del convenio**: el Art. 30 del CCT 729/2015 fija esos dos importes por flota,
con base en marinero de planta y pago al dólar comprador del BCRA — ver [[cct-729-15-articulos]].
Los dos números que yo había despejado de los datos son los que dice el convenio.
    y de ahí cada categoría por su índice; la razon entre las dos escalas es 16/15 en todas

O sea que en BC son dos parámetros por pesquería, del mismo modo que `PRECIO_NAV_LAN` / `_CAL` y
`PRECIO_PUERTO_LAN` / `_CAL` —ver [[parametros-somu-por-pesqueria]]—, y no una elección en la fórmula.

**El MAX entre las dos columnas queda descartado por aritmética**, no por los datos: la escala de
poteros es siempre 16/15 de la de tangoneros, así que “el mayor de los dos” daría siempre potero.

Ojo: **1.714,29 es a la vez el índice 75 de la escala potera y el 80 de la tangonera**, así que ese
valor no discrimina —286 entradas— y hay que excluirlo de cualquier medición.

## Callejones ya descartados, para no repetirlos

- **No es el tapón del neto garantizado.** `LIQUIDO` no es `NTO_GARANTIZADO × TC` en **ninguno** de
  los 259 empleados de enero, ni al comprador ni al vendedor, ni usando `NETO_ESTIMADO`.
- **No es precio × días − convenio como el 2083.** El precio implícito por empleado va de 3.772 a
  9.175 USD/mes: no hay lista.
- **El sustraendo no es** `TOT_PUERTO_OF`, `TOT_MAREA_OF`, `A_CUENTA_OF_AUX` ni sólo `SUELDO_PUERTO`:
  los cuatro dan 0 de 50.
- **No se calcula en otra entrada y se guarda en ésta**: no hay ninguna entrada del mismo
  empleado-mes cuyo `BRUTO_PRORRAT − TOT_HAB_GZDO` explique los 37 restantes.
- **Agregar por mes empeora**: 6 de 50 contra 13 de 50 por entrada.

## Dos cosas que aparecieron de paso

**`GROSSING_UP` = 0,785 es constante**, no una marca por empleado: es `1 − 21,5%`, la suma de
jubilación 11 + ley 19032 3 + obra social 3 + cuota sindical 4,5.

**Estas columnas hay que leerlas por `No. Entrada`, no agregadas por empleado.** Un empleado tiene
tres o cuatro entradas en el mes con distinto `Tipo Imputación`, y cada una lleva su propio
`NTO_GARANTIZADO`, su `BRUTO_PRORRAT` y sus días. Agregando con `MAX` la identidad se rompe y parece
que la regla no existe — es la misma trampa de [[tot-remun-27617-es-acumulador]] con otra cara.

## Relacionado

- [[a-cuenta-futuros-aumentos-francos]]
- [[puesto-vs-categoria-cct]]
- [[get-con-menos-argumentos]]
- [[escala-somu-indice-70]]
- [[antiguedad-no-cuenta-dias-gp]]
- [[precio-puerto-lista-inconsistente]]
- [[cct-729-15-articulos]]
- [[parametros-somu-por-pesqueria]]
- [[tot-remun-27617-es-acumulador]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
- [[anticipo-no-es-haber-del-recibo]]
