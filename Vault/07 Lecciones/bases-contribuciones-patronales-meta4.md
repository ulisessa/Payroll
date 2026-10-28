---
aliases: ["Las bases de contribuciones patronales de Meta4"]
tipo: leccion
tema: contribuciones-patronales
tags: [leccion, contribuciones-patronales, sicoss]
fuente: [src/Pages/Pag110051.CompararBCMeta4.al]
actualizado: 2026-10-16
---

# Las bases de contribuciones patronales de Meta4

Cada familia de contribución usa una base distinta, y ninguna es la de Ganancias. Enero de 2026, por
empleado, contra `Hist. Liq. Meta4`:

| Concepto BC | Base correcta | Cierra |
|---|---|---|
| `7000` jubilación, `7010` Ley 19032, `7060` asignaciones, `7070` FNE | `BASE_SS_TRAB + BASE_SS_VAC`, menos la detracción **una vez por mes** | 314 de 328 |
| `7030` obra social | `BASE_OS_TRAB + BASE_OS_VAC` | 327 de 328 |
| `7050` ART | `BASE_SS_TRAB + BASE_SS_VAC + NO_REMUNERATIVO` | 329 de 330 |
| `7053` suma fija ART | `VALOR_ART_FIJO`, a **todos** los convenios | — |
| `7055` tarea diferencial | `PCT_TAR_DIF × (BASE_SS_TRAB + BASE_SS_VAC)` en los tres convenios de navegación | 271 de 271 |

La detracción (`DED_CONT_PATR`) se resta una vez por mes con `MES_BASE_SS_TRAB + MES_BASE_SS_VAC`:
contribuye por la diferencia entre el acumulado del mes con y sin la liquidación actual. Falta el
prorrateo por días que hace Meta4 (≈14 empleados, $100 a $750).

## Qué falló antes, sin error

- **Base de Ganancias en lugar de la remunerativa** (`BASE_IG4 + BASE_EXT_IG4`): 121 % de la de Meta4 en
  jubilación, Ley 19032 y asignaciones, porque incluye conceptos no remunerativos que no contribuyen.
- **`7030` sin `BASE_OS_VAC`**: la liquidación de Vacaciones pagaba obra social cero.
- **ART sobre `BASE_LRT`**: 58 % de la base de Meta4, que suma todo lo no remunerativo.
- **`Concepto CCT Vigente` es una lista blanca por convenio.** El `7053` no corría en FA, 372/04 y 130/75
  y el `7055` sólo en 175/75 y ESP: aunque el parámetro `PCT_TAR_DIF_729/15` existiera, el concepto no
  corría. Cargar el parámetro no alcanzaba.
- **`Tipos Liq. Aplicables` vacío no es comodín en `VACACIONES`**, que tiene "Sólo Conceptos
  Declarados": el `7055` no corría en vacaciones. Ver [[vacio-en-tipos-liq-aplicables-es-comodin]].

## Cómo se encontró

Comparar **por empleado** y mirar la razón entre columnas: una razón constante (1,21 en tres conceptos,
0,82 en uno) delata una base y no una alícuota. Después, probar bases candidatas contra el valor
implícito `contribución / alícuota` de Meta4 hasta que cierre en todos.

## Alcance del comparador

- El `7080` (Seguro de Vida Obligatorio) suma a `Total Contribuciones` de BC y Meta4 no lo guarda en
  `TOT_CONTRIB` ni en `TOT_CONT_SUSS`. El comparador actual ya lo excluye, junto con `7090..7099`,
  para comparar la misma composición contra `TOT_CONT_SUSS`; no volver a descontarlos.
- Meta4 suma a `TOT_CONTRIB` `FARM_CON_NAV` (20 empleados) y `FARMACIA_PAT` (9) que BC no tiene como
  contribución.
- `90331` tiene contribuciones en BC y ninguna en Meta4.

Ver [[detraccion-se-resta-por-liquidacion]], [[Reporte SICOSS]], [[Hallazgos abiertos]].

## Revisión de febrero de 2026

La captura estable del 16/10 reconstruye por componentes los totales patronales de ambos sistemas
para los 339 empleados comparables. La clasificación vacía de una columna no demuestra que sea
ajena al total: `VAC_PAT_CASFECC` también integra las asignaciones originales.

- En 304 empleados la diferencia material queda sólo en ART. En los otros 35 hay 28 casos de
  detracción, seis de arrastre de bases de haberes y uno que combina ambas causas.
- El fijo genérico de ART toma en BC `1602`, mientras el fijo implícito original de febrero es
  `1624` en los 338 comparables con haberes. Es una vigencia de parámetro pendiente de cargar;
  no cambiar la tarifa histórica de enero ni confundir el fijo con la alícuota porcentual.
- Otro comparable tiene haberes cero y ART fijo original. BC lo omite por su condición de bruto
  distinto de cero. Existe también un registro sólo Meta4 con ese costo y sin haberes.
  La fórmula original `6093` aplica el fijo a TP 1, o TP 14 con indicador 280 igual a uno;
  no exige remuneración positiva. Antes de generalizar, mapear esos predicados a los tipos de BC.
- La detracción aparece en 29 casos al incluir el mixto: 18 ordinarios, diez finales con SAC
  y uno de vacaciones. La reconstrucción de las bases originales y de las ramas de detracción
  `5802/5811/5821/5831` reproduce las diferencias. No sustituir la regla por una multiplicación
  universal por `DIAS_ALTA_30`: las ramas no usan necesariamente el mismo tramo ni divisor.

## Parametrización aplicada en febrero

Se versionaron `7000/7010/7060/7070` desde el 01/02 para usar las bases netas
`5811/5821/5831`. Los informativos reconstruyen sueldo, SAC, vacaciones,
prorrateo, mínimo y saldo mensual según las ramas originales. Los acumulados
usan `PERIODO_CONCEPTO`, que cuenta documentos anteriores por orden del tipo
y número. En la cohorte de febrero ese orden coincide con fecha y número.
El contraste offline reproduce los 29 objetivos de detracción y conserva
los otros 310 comparables. El cálculo real de febrero confirma los 29 objetivos
en las cuatro familias dentro de la tolerancia del contraste.

Las ausencias potencialmente no contributivas sin correspondencia original
acreditada conservan la fórmula anterior mediante una condición genérica.
No se convirtió la hipótesis de días de ausencia en una resta universal.
No se modificaron `7002` ni el cálculo semestral de futuros aguinaldos.

Se conserva la tarifa genérica ART de febrero cargada por el usuario y se agrega
la vigencia específica de ESP para evitar que la nueva genérica la eclipse.
`7053` conserva los contextos antes elegibles y agrega los mensuales REGULAR
o DEVENGADOS sin haberes. No habilita automáticamente finales con bruto cero:
el indicador original de TP14 necesita acreditación separada. Las restricciones
CCT se resuelven por fecha propia, sin relación con la versión de `7053`,
y no se clonaron. El registro sólo Meta4 sigue sin un recibo BC comparable.

La aplicación de configuración está confirmada, con cierre de las versiones
anteriores al 31/01 e historial nativo de altas. El mes se recalculó completo
y enero conserva sus nueve controles financieros. Las diferencias patronales
superiores a un peso pasan de 339 a nueve: cuatro grossing-up aceptados y cinco
residuos heredados de bases de haberes. La detracción mensual está verificada
en los nueve; ART concilia en los 339 comparables. Esos arrastres conservan
su diagnóstico independiente y no justifican modificar otra vez la detracción.
Evidencia privada: `.snapshots/aplicar-netos-contribuciones-febrero-20261016/contribuciones/`.

## Modelo de detracción adelantado a enero (16/10/2026)

Enero había quedado con la rama vieja (detracción completa por mes) y 11 empleados de mes parcial (04382, 04785, 04855, 03073, 04486, 04926, 04900, 04775, 04889, 04925, 04901) quedaban 500 a 1.300 pesos abajo de Meta4 en `TOT_CONT_SUSS`; febrero, con el modelo `5802/5811/5821/5831`, cierra los 330. Meta4: `5811` = base − `round(DED_CONT_PATR / 30 × DIAS_REDUC_IMPO)` con un piso en la base mínima de obra social (`605`); `DIAS_REDUC_IMPO` (`5802`) es la suma de días pagados por tipo para embarcados y 30 menos ausencias para mensualizados. `scripts/ContribucionesCNTAEnero.sql` copia a enero las vigencias del modelo (13 conceptos nuevos desde 2026-01-01; `7000/7010/7060/7070` desde 2026-01-02) y los parámetros `CNT_*`. **Supuesto:** `CNT_MIN_BASE` de enero = el de febrero (120.997); verificar contra el valor de sociedad de enero.
