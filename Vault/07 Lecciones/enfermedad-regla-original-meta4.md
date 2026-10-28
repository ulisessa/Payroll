---
aliases: ["Regla original de enfermedad en Meta4"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, ausentismo, migracion-meta4, acumuladores]
fuente: [M4_TEXTO_FORMULA_1, M4_TEXTO_FORMULA_2, M4SYS_SYSLONG, M4SYS_HIST_NORMAS, M4SYS_CONCEPTOS]
actualizado: 2026-10-15
---

# Regla original de enfermedad en Meta4

El concepto `4110` paga precio por unidades, con ramas diferentes para embarcados,
mensualizados y jornales por hora. Las definiciones originales vigentes en enero y
febrero de 2026 no equivalen a una única base dividida por treinta para todos.

## Precio de embarcados

El `4057` utiliza los siguientes promedios cuando corresponde iniciar el precio:

| Convenio y categoría original | Concepto de promedio | Meses |
|---|---|---|
| MR | 4051 | 12 |
| OF, categorías OF02 u OF04 | 4050 | 6 |
| OF, categorías OF01 u OF03 | 4051 | 12 |

Las consultas `ACM_6_MESES_EXTR` y `ACM_12_MESES_EXTR` suman `TOT_PROMEDIOS`,
concepto `4448` y total 19. Filtran sociedad, empleado y **fecha de alta del vínculo**;
no reúnen vínculos anteriores. Admiten las imputaciones `1, 10, 11, 12, 13, 14, 15, 3`.
La ventana contiene los seis o doce meses calendario anteriores al proceso.

Si el alta acumula al menos 181 o 362 días hasta el primer día del mes, el promedio
mensual es el total dividido por 6 o 12; el precio diario se obtiene dividiendo por 30.
Con menos días, el promedio mensual es `total / días_desde_alta * 30`, de modo que
el precio diario queda en `total / días_desde_alta`. El alta del mismo mes devuelve
cero. No se fuerza un divisor mínimo de un mes ni se divide por meses con pago.

La condición literal para iniciar el precio en `4057` es que **la última fila de
AUSENTISMO** sea de tipo `1` y comience dentro del período. De lo contrario consulta
`PR_ENFERMEDAD.PRE_ENFER`: precio de la última fecha de imputación `1` anterior al
proceso, para la misma sociedad, empleado y alta. Esa consulta no exige precio
positivo ni filtra el episodio de licencia. No equivale literalmente a buscar el
primer recibo del AU1 actual, aunque coincida en una licencia continuada normal.

> [!warning] Una novedad puede conservar el precio de una licencia anterior
> Hay incidencias originales de `4057` cuyo valor coincide con el precio pagado
> al comenzar otra licencia. Los meses posteriores recuperan ese valor desde la
> última paga mensual. Un promedio reconstruido para el nuevo inicio puede diferir
> aunque la consulta y el vínculo sean correctos. Antes de atribuir la diferencia
> a la fórmula, revisar `M4T_VAL_INCIDENCIA` para `4057`, sus fechas y el alta.
> En un caso verificado, el precio original anterior se reconstruye con la suma
> histórica del vínculo dividida por 312 días; la novedad conserva ese precio.

`4050`, `4051` y `4057` no incorporan una actualización explícita por aumentos ni
sustituyen la antigüedad histórica por la actual. Esta observación describe esas
fórmulas; no demuestra la ausencia de toda otra regla salarial o novedad.

## Mensualizados y jornales

Para agrupación `AD`, convenio `MA` o categoría `JO01`, el precio de `4057` es
`4040 / 30`, sólo en imputación `1`. `4040` es `TOT_P_COMP_EA`, total 10 denominado
«Total precios a complementar enf/acc»; no es el promedio histórico de embarcados
ni se identifica automáticamente con el básico solo.

Para `JO02`, `JO03` o `JO04`, el precio se arma con `1692` o `1702`, según la
localización, más los porcentajes `2701` y `1048`. `4110` usa horas `501` en las
agrupaciones `P1`, `P2`, `P5`; las ramas diarias utilizan `500`. No se debe extender
la fórmula mensual a todos los jornales.

## Unidades e importe

El `410` suma intersecciones de ausentismos tipo `1` con la ventana de paga. En
jornales distingue las quincenas de las imputaciones `1` y `14`.

Para `AD`, `CE`, `JO01` o `MA`, si el tipo salarial es mensual y la ausencia cubre
el mes calendario completo, completa febrero a 30. Luego limita los días al `405`
(30 para mensual, días del mes para el resto). Un tramo parcial que termina en
febrero **no recibe automáticamente los dos días adicionales**.

`4110` calcula precio por días u horas en las imputaciones admitidas por su rama.
Sólo si el tipo de buque es `CG` multiplica después por `(100 - 4676) / 100`, y
redondea a centavos. No corresponde fijar un 70/30 para todos los casos. `4112` y
`4113` admiten valores informados o asignados desde otro concepto; sus propias
fórmulas no calculan por sí solas ese porcentaje. `4052`, promedio no remunerativo,
no es llamado por `4057`: no debe sumarse otra vez sin comprobar la composición.

En agrupaciones `AD`, `P3`, `P4` e imputación `1`, `4115` devuelve `-4110`. Es una
deducción espejo que debe considerarse al comparar el efecto sobre el bruto.
`4111` es un ajuste informado por incidencias.

## Comprobación y diferencias con BC

La reconstrucción offline reprodujo las 23 salidas de enfermedad de febrero
revisadas mediante precio y unidades registrados. Las cinco continuaciones
conservaron el precio previo. Dos reconstrucciones desde la historia original
confirmaron, respectivamente, el promedio anual y el divisor por días de un alta
reciente. Esto no certifica todos los convenios ni los recibos actuales de BC.

La configuración de BC revisada conserva una ventana anclada a la licencia, más
específica que la consulta literal de precio anterior de Meta4. También utiliza
solapamiento comercial para mensualizados y una rama diaria para no tripulantes.
La normalización de períodos parciales y los jornales horarios requieren contraste
antes de afirmar equivalencia general. No se modificaron fórmulas ni recibos en
esta investigación; los respaldos originales y casos individuales están fuera
del vault, en `.snapshots/enfermedad-original-meta4-20261015/` y
`.snapshots/febrero-tras-publicacion-20261015/enfermedad-offline/`.

## Relacionado

- [[enfermedad-base-total-no-base-fiscal]]
- [[ventana-promedio-ausentismo]]
- [[base-promedio-no-mezcla-porciones-y-totales]]

## Medición sin novedades y enero con la regla de febrero (15/10/2026)

Al medir el 4110 de enero y febrero hay que **separar las líneas con novedad**: la novedad con importe reemplaza a la fórmula y tapa la diferencia. La fórmula evaluada de cada línea queda guardada en `Fórmula Evaluada`, así que se puede reconstruir qué habría dado sin la novedad.

Resultado: 34 de 51 casos sin novedad coinciden con Meta4; los 17 con novedad (12 de enero, 5 de febrero) no coincidían con la fórmula sola.
- **Enero (12):** el 4110 de enero leía `#PROM_AUS_MES` (mezcla vieja de `BASE_PROMEDIO`). El precio de Meta4 (`PRE_ENFER`) se reconstruye con 12 meses de `TOT_PROMEDIOS` del vínculo actual anclados en el **mes de inicio del episodio** (11 de 12 al centavo; 03986 queda 2,8% arriba). Con ese precio, los días de BC y el coeficiente 0,3 de enero, los 12 importes dan exacto: los días estaban bien, el desvío era el precio. `scripts/EnfermedadEneroConReglaDeFebrero.sql` da a enero las vigencias 2026-01-03 de 4110 y PROM_ENF_MES (copia de las de febrero) y **anula** las 12 novedades (reversible).
- **Febrero (5):** continuaciones (Meta4 recupera el precio de la última paga anterior). Con el precio de Meta4 por las unidades de BC dan exacto.
- **Diferencia de diseño demostrada:** `PesoDiaComercial` suma los 2 días extra a cualquier licencia que incluya el 28/2; Meta4 sólo si cubre el mes completo (afecta convenios con `AUS_MES_COMERCIAL`: 130/75, 372/04, FA). Sin casos en enero/febrero.
- La ventana 6/12 meses de BC (`PROM_LIC_MESES`, por convenio) coincide con Meta4 salvo un OF01 cargado en 175/75.

**Resultado del recálculo de enero (16/10/2026):** de las 12 novedades, **4 sobran** (02670, 02854, 04185, 04216: la vigencia de febrero da exacto sin novedad). Las otras **8 siguen necesitando novedad** (01607, 01767, 01961, 02449, 02737, 02924, 03073, 03986): son continuaciones. Meta4 ancla el precio en el inicio del episodio previo (octubre/noviembre) y BC ancla en el AU1 vigente: en 01607 hay un AU1 del 28/11 al 27/12 y otro del 8/1 al 27/1 (intervalo breve, Meta4 conserva el precio anterior); en 01767, 02737 y 02924 el episodio de Meta4 empieza un mes antes que el AU1 de BC. Es el punto 3 de la regla ("recupera el precio de la última paga anterior") y coincide con las excepciones de RRHH de febrero. 03073 ancla igual que Meta4 y queda 12% abajo: sin explicar. Trampa: al anular una novedad hay que vaciar `No. Liquidación`, o `LimpiarParaRecalculo` la devuelve a Pendiente.

**03986 explicado (16/10/2026, cadena en Meta4):** el precio nace en abril de 2025 con `TOT_PROMEDIOS` del vínculo del 24/5/2024 dividido por 312 días (al centavo). Hay novedades originales del 4057 en agosto y septiembre de 2025 con ese mismo precio; aunque en septiembre empieza otra licencia, esa novedad conserva el precio anterior y las pagas siguientes lo recuperan por `PR_ENFERMEDAD`. Sin mezcla con el vínculo de 2023. El +2,8% de la reconstrucción no se reproduce con los datos originales (recalcular al nuevo inicio de septiembre da un precio 9,30% menor que el de Meta4). Clasificación: **precio informado por novedad y arrastrado**, no diferencia de la fórmula del promedio. Para reproducirlo en BC hay que representar esa entrada original (novedad) sin tocar la regla general: la novedad de 4110 de 03986 se queda.

## Regla aplicada: precio informado (4057) en lugar de novedades de importe (16/10/2026)

`scripts/EnfermedadPrecioInformadoPR.sql`. Meta4 no corrige importes: informa el **precio diario** en una novedad del 4057 y las pagas siguientes de la licencia lo recuperan por `PR_ENFERMEDAD`. BC ahora lo representa igual, sin tablas nuevas:
- Concepto informativo **4057** (molde 2041) y fuente **`PRECIO_ENF_INF`** (suma el Valor Unitario de las novedades 4057 del empleado en el período; tabla 110038, campo 14).
- **4110**, vigencias 2026-01-04..31 y 2026-02-04..abierta: `IF(PRECIO_ENF_INF > 0, PRECIO_ENF_INF * 30, #PROM_ENF_MES) * coeficiente / 30 * días`. Con precio informado manda; sin él, el promedio de siempre.
- 21 novedades 4057 (Cantidad 1, Importe 0, Valor Unitario = `PRE_ENFER` de Meta4): enero 8, febrero 5, marzo-junio 8. Las 21 novedades 4110 de importe quedan **Anuladas** con `No. Liquidación` vacío.
- Cuando un caso nuevo de continuación aparezca, se carga una novedad 4057 con el precio de Meta4, no un importe.

**03073 explicado y corregido (16/10/2026):** el ancla (nov 2024 a oct 2025, divisor 12) era correcta; faltaban noviembre y diciembre de 2024 en el histórico de BC (`TOT_REM_IMP` = 0 y `TOT_PROMEDIOS` > 0, descartados por el criterio de la migración) y explicaban exacto el 12,1129 % que quedaba abajo. `scripts/HistoricoEnfermedad03073.sql` los incorpora como cabeceras `HIST_REMUN` informativas con una línea `AJ_HIST_AUS` (3.046.106,70 y 3.046.106,52), igual que los tres meses omitidos de 02737 y 03986. Sin tocar fórmula, ancla ni divisor; la novedad 4057 de 03073 de enero se anuló porque el precio ya sale solo. Ojo: otros empleados con el mismo criterio de migración (`TOT_REM_IMP` = 0 con `TOT_PROMEDIOS` > 0) pueden tener meses omitidos; se detectan comparando los meses de `Hist. Liq. Meta4` con las cabeceras `HIST_REMUN`.
