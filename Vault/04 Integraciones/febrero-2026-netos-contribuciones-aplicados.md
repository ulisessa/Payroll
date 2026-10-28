---
tipo: registro
tema: migracion-meta4
tags: [meta4, febrero, ganancias, contribuciones, promedios]
actualizado: 2026-10-16
---

# Febrero 2026: correcciones de netos y contribuciones

Configuración aplicada el 16/10, con vigencias de febrero e historial nativo
de fórmulas. Sin cambios AL, campos ni tablas nuevos. Los recibos de enero
se protegen por revisión de cabeceras, líneas, variables, Ganancias,
incidencias, coberturas, movimientos de francos y novedades.

## Cambios aplicados

| Tema | Cambio |
|---|---|
| Vacaciones | `3553` suma `VAC_HIST_NOFISC` al histórico normal: antecedentes auténticos de promedio omitidos, sin precio personal forzado. |
| Familiares | Doce fotos originales de febrero en `FAM_HIST_M4`, como equivalente mensual del acumulado original. |
| Gastos | Historia acreditada de servicio doméstico y gastos médicos; dos informativos normalizan el acumulado para la fórmula mensual existente. |
| Cuota SSI | `8522` distingue afiliación con tasa cero de ausencia del atributo mediante `TIENE_SINDICATO`; conserva el cero explícito. |
| Aporte solidario | `8563`, ya pagado por novedad, alimenta `CUOTA_SIND_REAL` y `CUOTA_SINDICAL_RET` desde febrero; no genera otro descuento. |
| Comercio | Inclusión de `130/75` en `6010/6030`; los virtuales `4752/4753` ya eran irrestrictos. |
| Francos no gozados | `2803` alimenta `BASE_EXT_IG4`; las nuevas `4750/4754` restan su importe para conservar las provisiones de SAC anteriores. |
| Arrastre fiscal | Informativos separados excluyen de `YTD_SAC_DEV` las provisiones de finales históricos, sin modificar `5010`. |
| Detracción | Bases netas de sueldo, SAC y vacaciones según las ramas originales; saldo mensual mediante `PERIODO_CONCEPTO`. |
| ART | Se conserva la tarifa genérica cargada por el usuario, se agrega vigencia específica ESP y se cubren mensuales con remuneración cero. |

La cuota fiscal virtual de `4754` conserva su selección original de tasa;
no se le trasladó el cambio de la cuota efectiva por analogía.
El aporte solidario `8563` ya está pagado por novedades en la cohorte SSI:
no crear un segundo pago para resolver una diferencia de base fiscal.

## Conservación y alcance

Las fórmulas anteriores se cierran al 31/01 y se conservan las versiones
futuras. El promedio de vacaciones y los auxiliares del arrastre SAC tienen
alcance sólo febrero; no extenderlos a marzo sin contrastar su cohorte.
El complemento histórico de promedio no modifica `BASE_PROMEDIO` compartido
por SAC y enfermedad. Incluye signos y evita duplicar antecedentes ya presentes.

Las ausencias potencialmente no contributivas sin correspondencia acreditada
conservan la fórmula patronal anterior mediante condición genérica. No se
generalizó una resta de días ni se alteró el aguinaldo semestral futuro.
Las restricciones CCT tienen vigencia independiente de las de conceptos:
no se clonaron las de ART; restringir un concepto previamente irrestricto
crearía una lista blanca accidental.

## Validación

Aplicación transaccional con guardas de filas y fuentes, copia privada del
antes y auditoría de altas. Los ensayos de configuración se revirtieron:
no se ejecutaron pruebas AL que generaran recibos de ensayo en la empresa.
Se reinició BC252 antes de utilizar las nuevas fuentes y fórmulas.

Los primeros cinco empleados se recalcularon por el flujo normal mensual.
Vacaciones, gastos acreditados, familia/cadena y arrastre SAC coincidieron
con los controles originales dentro del centavo; las familias patronales
quedaron dentro de la tolerancia del contraste. Los brutos de los controles
ajenos al cambio de promedio permanecieron iguales.
El recálculo normal terminó: **339 empleados y 486 recibos**, todos Calculados,
sin errores. Tras agregar las dos fracciones fiscales de `8563` se reinició
el servicio y se recalcularon nuevamente sólo los cuatro empleados afectados.
El control final confirma que las nueve tablas financieras de enero conservan
las mismas filas y revisiones que antes de la intervención. No hay meses
posteriores calculados. La captura final es estable y conserva los originales
de Meta4. Se comprobaron 276 controles fiscales y 20 de promedio/arrastre:
17 de las 18 retenciones revisadas quedan hasta dos centavos del original;
la restante conserva el residuo educativo sin respaldo individual histórico.
De las 52 vacaciones, sólo cambia el caso diagnosticado; los otros 51 importes
son idénticos al respaldo. Los 29 objetivos de detracción concilian sus cuatro
familias dentro de la tolerancia del contraste.

Las diferencias netas de al menos diez pasan de 25 a cinco: cuatro acuerdos de
grossing-up con fórmula ya aceptada y el caso educativo. No se forzaron importes
para eliminarlas. Dos variaciones de bruto fuera del promedio son inferiores
a un peso, sin cambio material de neto ni cambios de fórmula en sus haberes.
El contraste patronal superior a un peso pasa de 339 casos a nueve; sus residuos
son cuatro grossing-up aceptados y cinco bases de bruto previamente distintas.
En los nueve se verificó la detracción mensual correcta. ART concilia en los
339 comparables. No se declara conciliación exacta universal de los haberes.

Permanece fuera de la carga la deducción educativa sin respaldo individual
histórico. La declaración retroactiva vigente no prueba el dato original.
El registro sólo Meta4 con ART y sin recibo BC se trata aparte de los comparables.

Evidencia privada completa en `.snapshots/aplicar-netos-contribuciones-febrero-20261016/`.
Ver [[Preparar un mes contra Meta4]], [[promedio-vacaciones-regla-original-meta4]],
[[Deducciones de Ganancias y familiares]], [[sin-sindicato-paga-segun-convenio]]
y [[bases-contribuciones-patronales-meta4]].
