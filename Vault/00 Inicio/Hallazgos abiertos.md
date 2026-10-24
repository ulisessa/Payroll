---
tipo: guia
tags: [inicio, hallazgos, pendientes]
actualizado: 2026-10-21
---

# Hallazgos abiertos

## Entradas de abril aplicadas y pendientes (21/10/2026)

**Corrección autorizada posterior:** se anularon las tres novedades que confundían
precio de franco con días, vaciando su vínculo de seguimiento para que reabrir no
las reactive. Se corrigieron los proyectos de las 32 novedades de vacaciones y el
tipo/proyecto de las ocho gratificaciones; se conservaron cantidades, importes y
fechas originales. Los 12.057 recibos guardados y las 2.401 novedades de enero a
marzo quedaron idénticos; sólo cambió `Novedad Liquidación`. BC252 quedó Running
con caché renovada. El usuario recalcula abril: incluir cierres y finales de los
tres devengos corregidos. No se modificaron fórmulas ni se recalculó en esta tarea.

**Pendiente distinto del error de unidad:** los tres precios manuales de franco de
Meta4 son mayores al precio automático. La matriz no admite precio informado por
empleado o corrida con la configuración actual. No trasladar esos importes a 1063
ni extenderlos al parámetro genérico del convenio. La anulación corrige el saldo
ficticio, pero todavía no acredita igualdad total con Meta4. Evidencia y guardas:
`.snapshots/correcciones-abril-informe-comparador-20261021/`.

Las mejoras del chequeo de proyecto de inactividad y los contadores del comparador
están implementadas y compiladas sin errores, aún sin publicar. El chequeo reconoce
`PROY_NOMINA` vigente del buque con destino válido, sin exigir copiarlo en cada marea;
una eventual transición sin destino queda como revisión opcional. La consulta de
los tres buques señalados confirmó atributos válidos y campos completos también
en sus mareas actuales de abril: no hay un faltante que cargar por ese motivo.
Se prepararon siete regresiones del informe y seis del comparador, con runners limitados a la empresa
aislada; no se ejecutaron sobre la empresa operativa ni sobre el código nuevo.

**Después del cálculo del usuario:** el corte estable de abril tiene 85 empleados
con diferencia de bruto mayor a cien pesos, seis con diferencias menores y dos
pagos con bruto positivo en Meta4 sin cabecera BC. Clasificación hecha sólo en lectura:
tres novedades de precio de franco fueron interpretadas como días y desbordaron
los pagos finales; 32 novedades de vacaciones tienen cantidades correctas pero
quedan fuera del final por el proyecto inferido; ocho gratificaciones apuntan a
un tipo final inexistente para esos empleados; 40 personas no tienen el día de
puerto que Meta4 paga en TP12. Estos grupos se superponen.

Quedan además diferencias de saldo inicial, feriados, reparto de antigüedad,
ancla del promedio de vacaciones, enfermedad, divisa y acuerdos/grossing. Las
41 novedades de pilotaje coinciden con Meta4; no anularlas por estas diferencias.
Los familiares pendientes no explican por sí solos los faltantes de haberes.
Evidencia privada: `.snapshots/clasificar-brutos-abril-20261021/`, clasificación
por empleado y causas comprobadas o pendientes separadas. No se aplicaron nuevas
correcciones ni se recalcularon recibos durante esta revisión.

La carga previa había aplicado 59 operaciones con guardas: tres básicos de abril y un sucesor de
mayo, una sustitución de categoría desde abril, tres fechas de cotización,
tres históricos mensuales de gastos, seis duplicados anulados y 41 destinos de
novedades de pilotaje. De estos destinos, 30 van a REGULAR y 11 a LIQ_FINAL; sus
proyectos coinciden con el creador y se conservaron fechas e importes originales.
Las novedades de importe siguen siendo entradas originales, no pruebas de sus fórmulas.

Quedan pendientes ocho correcciones familiares que afectarían las entradas de
recálculos de enero a marzo, cinco gastos acreditados sólo en finales que el
maestro no puede aislar de la regular, la cotización EUR sin respaldo directo,
el pago posterior a una baja y el acuerdo de prima vacacional sin confirmar.
No convertir estos pendientes en novedades de impuesto o de deducción total.

Las 11.633 cabeceras, los detalles operativos, las fórmulas y las entradas de
enero a marzo se conservaron. Sólo cambiaron las tres tablas previstas;
BC252 se reinició y quedó Running. No se crearon ni recalcularon recibos.
Evidencia privada: `.snapshots/cargas-abril-20261021/`, plan, aplicación,
capturas e `integridad-final.json`. Reglas reutilizables en
[[Preparar un mes contra Meta4]]. Este estado prevalece sobre el diagnóstico
incompleto de abril conservado más abajo.

## Estados y precio manual de vacaciones: revisión marzo/abril (21/10/2026)

El control diario de toda la población activa detectó dos vacaciones abiertas en BC
que Meta4 terminó en enero. **Corregidas con autorización el 21/10/2026:** AU9
cierra el 04/01 y ACT vuelve desde el 05/01, en el mismo proyecto de nómina,
sin modificar los recibos guardados. No se acreditaron desvíos de puestos: conservar la excepción
individual documentada y no exigir puestos marítimos a tierra/DES. Un precio manual
original de vacaciones difiere del automático; el automático de BC coincide con
otro automático de Meta4, por lo que no corresponde cambiar la regla para igualarlo.
**Entrada excepcional cargada con autorización el 21/10/2026:** se actualizó la
novedad existente de la final de abril con precio e importe originales y cantidad
conservada; sigue Pendiente, sin duplicar filas ni materializar incidencias. BC252
se reinició para renovar caché y quedó Running. Las fórmulas y los recibos se
conservaron desde el corte anterior a aplicar; las aprobaciones ajenas de enero
previas a ese corte también se conservaron. No se recalcularon recibos. Alcance y evidencia privada en
[[Preparar un mes contra Meta4]].

El contador de puerto posterior de A28/62 quedó corregido y publicado: mantiene
arribo, valoración y días del viaje. Diez pruebas aisladas pasaron; fórmulas y
recibos operativos se conservaron. El efecto sobre nuevos cálculos de abril queda
pendiente de la liquidación normal. Ver [[Tests automatizados]].

## Novedades de abril a junio cargadas desde Meta4 (20/10/2026)

`scripts/NovedadesMetaAbrilJunio.sql` cargó 109 novedades Pendientes que Meta4 tenía como incidencias y BC no: 1022 (78, 13/4, tipo CIERRE_MAREA), 2073 (24, ceros e importes), 1062 (3), 2083 (2 ceros), 1053 (1) y 4057 (1). No se migran días, precios, bases ni derivados (2003, 5010). Las 805 incidencias que ya tienen novedad del mismo empleado y concepto con otra fecha quedaron sin tocar (no se verificó una por una).

### 2083 de marzo: antigüedad de toda la liquidación contra la del tramo de franco (resuelto 20/10/2026, falta recalcular marzo)

Tres empleados difieren en el 2083 (A cuenta futuros aumentos francos) de marzo: 00406 (−176.500), 03039 (−150.000) y 03196 (−127.500). La causa no es el 2073: la fórmula resta `#1063 + #1053`, y en BC la REGULAR de marzo cubre todo el mes, de modo que el 1053 incluye la antigüedad de los días de GP (marea). Meta4 pagó esos días en otra corrida (tipo 15, 18/3) y en la regular sólo calculó el 1053 de los días de franco, que es lo único que resta. La diferencia de cada caso es exactamente el 1053 de la corrida de marea: 150.000 y 127.500 son 20/31 del 1053 mensual en 03039 y 03196. Los que tienen sólo días de franco (02744, 01073, 04313, 04320) coinciden. Salida posible: restar `#1053 × DIAS_FRANCOS_PERIODO / (DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO)`, es decir, la antigüedad prorrateada a los días de franco (reproduce los tres casos), como vigencia nueva de la fórmula del 2083. APLICADO (`scripts/VigenciaAntiguedadPorTramo2083y2013.sql`): vigencia nueva desde el 1/3/2026 del 2083 (días de franco) y del 2013 (días de GP), con el prorrateo inline; vale mientras el 1053 use un solo precio, porcentaje y coeficiente por liquidación (si pasa a precio por tramo, rehacerlo). Los recibos de 03039 confirman el criterio: Meta4 restó en el 2083 sólo la antigüedad del recibo de franco. Restos aparte: 00406 conserva −4.000 por el valor del franco (1063 de 24.000 menos que Meta4) y 04837 tiene 4.200 de 1053 que Meta4 no pagó.

Segunda parte (20/10/2026): el mismo criterio para pilotaje y dique no se podía copiar tal cual porque 1033, 1043, 2033 y 2023 no tenían fórmula ni fuente de días. Se construyeron desde abril: ver [[pilotaje-y-dique-sin-formula]] (falta crear abril y comparar contra Meta4).

## Marzo 2026: cierre del paralelo contra Meta4 (20/10/2026)
**Estado final (20/10/2026, tras recalcular todo):** de las 15 diferencias de bruto del comparador quedan sólo cuatro casos de feriado de 100 a 469 pesos (02784, 04046, 04496, 04560; 02078 +209 sin explicar), 90016 (−9, redondeo). Resueltos (los borradores 04139 y 04360 se eliminaron: sin días propios, ver [[liquidacion-sin-dias-propios-no-se-calcula]]): 80344 (novedad 1603), 04163 (escalón del 23/3), 02452 (valor de 5.400), 04526 y 03772 (calidad de producción MR04), 04659 y 04722 (antigüedad al fin de mes), 90212 y 90302 (EUR 1.640), 90315 (mejor remuneración sin vacaciones y SAC sobre preaviso e integración), 03196 (2073 y novedad del 2013) y 00406 (novedades del 2083 y del 1023; el 1063 queda −24.000 por no poder tocarse por novedad). Las diferencias de −50.000, −140.000 o −250.000 que muestra una medida por haberes con y sin aportes son anticipos, no cálculo. La tabla de abajo es la de antes de las correcciones.

El comparador de BC (vista «Marzo - Diferencias en bruto») muestra 15 empleados con diferencia de bruto en marzo, tras recalcular 80344 (su 1603 se cargó por novedad y ya no difiere). Un cálculo aparte con los haberes con y sin aportes de Meta4 contra el Total Haberes de BC daba 153 diferencias, pero era una medida equivocada: Meta4 cuenta el anticipo en sus haberes sin aportes y BC no. Vale la del comparador. Las 15, todas explicadas:

| Empleado | Diferencia | Causa |
|---|---|---|
| 02452 | 2003 +135.500 (y sus contribuciones) | `VALOR_NAV_EMP_02452` tenía 6.900 (valor de CB01, su categoría hasta el 11/9/2025); Meta4 usa 5.400 de CB03. Vigencia nueva del 1/3 con 5.400 (`ValorNavEmp02452Marzo.sql`), falta recalcular la DEVENGADOS |
| 04163 | 2003 +3.532.471 | el escalón de marzo (12.000 → 15.000) arranca con la salida de la marea nueva (23/3), no el 1/3: Meta4 liquidó el cierre del 13/3 con 12.000. Corregido (`EscalonGU04163Marzo.sql`), falta recalcular el CIERRE_MAREA de marzo |
| 90212, 90302 | 1003 +628.183 / +163.685 | cotización del EUR de marzo sin cargar (BC tomaba 1.705, Meta4 1.640): cargada, ver `CotizacionEURMarzo2026.sql`, falta recalcular |
| 04526, 03772 | 2498 −199.973 c/u | el 5 % de calidad de producción de A28/61 se aplicaba también al puesto MR04 (MQ05, Máquinas, en Meta4); Meta4 no lo aplica a Máquinas. Excepción `APLICA_CALIDAD_PROD_729/15_MR04` = 0 (`CalidadProdMR04Maquinas.sql`), falta recalcular el CIERRE_MAREA |
| 04659, 04722 | 1053 −20.618 / −10.309 (y 1603 de 04659) | la antigüedad se medía al arribo en el cierre y al fin de mes en la devengada. Se unificó al fin del período (`Cod50016` `CalcAntiguedad`, [[antiguedad-al-fin-de-mes]]): falta republicar y recalcular los cierres |
| 90315 | 3813 (resuelto) y 3904/3944 −413.320 | la mejor remuneración del SAC de egreso incluía la vacación de enero (`MejorRemSacSemestreSinVacaciones.sql`); al corregirla quedó a la vista que el 3904 y el 3944 (SAC sobre preaviso e integración, #3903 / 12 y #3943 / 12) no tenían fórmula: vigencia nueva del 1/3 (`Sac3904y3944Formula.sql`), falta recalcular la final |
| 00406 | 1063 −24.000 (queda) | Meta4 pagó los francos en una corrida aparte el 4/3 a TC 1.385 (BC: regular del 31/3 a 1.355). Igualado por novedad el 2083 (148.666,67, `NovedadFranco00406Marzo.sql`) y el feriado 1023 (67.500, `NovedadFeriado00406Marzo.sql`): bruto y neto coinciden; el 1063 no se puede tocar por novedad (su importe se lee como días). Falta recalcular |
| 03196 | 2013 −18.970 y 2073 (resueltos por novedad) | el 2073 incluía la antigüedad de los días de franco: vigencia nueva del 1/3 (`Vigencia2073AntiguedadSinFrancos.sql`); el 2013 se valuó al TC de la corrida del 18/3 (1.360) y BC al del mes (1.355): novedad de importe (`NovedadMeta2013Marzo03196.sql`). Falta recalcular |
| 04046, 04496, 04560, 02784 | 1023 de +100 a +469 | aceptado: misma causa que 00406 (francos pagados en otra corrida de Meta4); 02078 no tiene francos y sigue sin explicar (+209) |

Borradores 04139 y 04360: eliminados el 20/10/2026 (no tenían días propios).

## Febrero: netos y contribuciones revisados (16/10/2026)

Aplicadas las correcciones paramétricas y recalculados 339 empleados / 486 recibos;
enero conserva filas y revisiones en nueve tablas financieras. Las diferencias
netas de al menos diez bajaron de 25 a cinco: cuatro grossing-up con criterio
ya aceptado y una deducción educativa sin respaldo histórico individual.
Las correcciones acreditadas de familia, gastos y aporte solidario están verificadas;
vacaciones incorpora el antecedente histórico omitido, sin alterar los otros 51 pagos.
Las cuatro familias de los 29 objetivos de detracción cierran dentro de la tolerancia.
Para este alcance prevalece este estado sobre las fotos de diagnóstico anteriores.
Detalle, límites y evidencia: [[febrero-2026-netos-contribuciones-aplicados]].

## Precio pactado por tonelada de oficiales poteros: aplicado y verificado (2026-10-13)

El precio de producción de empresa se carga en `USD_TON_PACTADO`, y el porcentaje
se deriva en `PCT_PROD_CALC` usando `USD_TON_PROD`. Los ocho acuerdos y 27 controles
del evaluador publicado fueron verificados; enero, otras modalidades y adicionales
conservan sus ramas. Aplicado inicialmente desde el 03/02/2026 tras el ensayo revertido y la pausa
de las ediciones/cálculos simultáneos. El servicio BC252 se reinició y quedó en ejecución.
La comprobación posterior confirma recibos y configuración anterior intactos, salvo
el cierre de la fórmula reemplazada. No se recalcularon recibos ni fue necesaria una
publicación de la extensión.

Luego se extendió la conversión al 01/01/2026 por pedido explícito, respetando los
precios de cada vigencia y alcance, incluidas las clases posteriores. Las tres fórmulas
anteriores se auditaron sin cambiar sus demás operaciones. El control posterior confirmó
que todos los recibos, detalles y usos permanecen intactos, al igual que los ocho precios
personales del 03/02. Pasaron nueve pruebas de expresiones en BC y la revisión independiente
de datos/configuración; la caché del servicio quedó renovada. No quedan tareas pendientes
de aplicación de esta conversión.
Ver [[Producción y premios]].

## Oficiales poteros con producción bruta y fijo: febrero conciliado (2026-10-13)

Generalización aplicada con versiones nuevas, acuerdos contrastados contra la planilla
de condiciones de campaña y código publicado en 1.0.0.654. Los seis cierres y sus seis
devengados coinciden con Meta4 en bruto y en los conceptos de premio, complemento y
feriado, dentro de la precisión definida para el cotejo. Las cuatro reconstrucciones
normativas históricas coinciden exactamente y registran sus vigencias utilizadas.

La comprobación final de cabeceras, líneas, resúmenes, detalle de variables y cuenta
corriente confirma que enero y los recibos ajenos al alcance permanecen idénticos.
Las diferencias restantes de neto son menores y corresponden a precisión/redondeo;
el concepto de redondeo no se modificó en este trabajo.

Las quince pruebas nuevas pasaron. La corrida ampliada conserva cuatro fallos de
pruebas anteriores documentados en [[Tests automatizados]]; no se atribuyen a esta
generalización. El código se verificó en el paquete publicado; cambios posteriores
de otras tareas en el checkout compartido se preservan para su propio despliegue.

Ver [[Producción y premios]], [[Evaluador de fórmulas - funciones]] y
[[Orden de cálculo y precedencia]].

Cosas que el análisis del 2026-10-04 encontró **leyendo el código y los scripts**, sin ejecutarlas ni verificarlas en la base. Son candidatos a revisar, no cambios hechos. Cuando se resuelva uno, borrarlo de acá y, si corresponde, dejar una lección.

> [!note] Origen
> Salen de los reportes de los agentes que redactaron cada área del vault. Cada ítem enlaza a la nota donde está el detalle.

## Código: probables bugs

| # | Hallazgo | Detalle |
|---|---|---|
| 1 | `Sinc NAV Liq.ReprocesarErrores` no arma el `RecordRef` para Informe del Capitán ni Diario de Abordo: falla en ejecución para esas entidades | [[Sincronización NAV - operación y errores]] |
| 2 | Las bajas de NAV se detectan (`Cod110041.Delta` arma `Bajas`) pero ningún código las aplica; el estado `Omitido` no lo asigna nadie | [[Sincronización NAV - visión general]] |
| 3 | `Tipo Liquidación.CodigoArribo()` lee la bandera obsoleta `Liquida al Arribo`, no `Disparador = Arribo`: un tipo de cierre creado sólo con el disparador hace fallar `CrearCierreMarea` | [[Tipos de liquidación]], [[Tabla - Tipo Liquidación]] |
| 4 | El control de cobertura usa el envolvente de `Cobertura Desde/Hasta` (`AjustarCabeceraAlEnvolvente`): el hueco entre dos tramos figura cubierto | [[Cobertura y tramos]], [[Control de períodos liquidados]] |
| 5 | SIRADIG: el control "ya importado" nunca dispara (`No.` autoincremental, clave `K2` no única); "Procesar Importación" no funciona sobre archivos subidos; deducciones de importaciones en fechas distintas quedan en vigencias distintas y el motor lee sólo la última | [[SIRADIG - importación]], [[SIRADIG - modelo y parser]] |
| 6 | `Liquidación.OnDelete` no limpia `Detalle Ganancias Liq.` ni `Resumen Variable Liq.` (no se verificó otro camino) | [[Tabla - Liquidación]] |
| 7 | `Ded. Ganancias Empleado` con `Importe Fijo = 0` no deduce; `Ded. Ganancias Vigente` no la lee el motor | [[Deducciones de Ganancias y familiares]] |
| 8 | `ResumenPorCategoria` (grilla Francos por Tripulante) valúa a valor pleno: sobrestima los lotes de tangonero (30%) | [[Valor del franco]] |
| 9 | `Rep50044` exige `Importe ≠ 0`: no puede cargar un cero explícito ni una incidencia de sólo cantidad | [[Incidencias masivas]] |
| 10 | Rep50042 `Asignar Estado Masivo`: el mensaje de omitidos siempre da 0 | [[Altas masivas y migraciones de fechas]] |
| 11 | `EntraEnCorrida` reenciende su bandera y `AplicarA` revierte `Aplica A` de VACACIONES en cada upgrade, contra el comentario "no pisa lo cargado a mano" | [[Install y Upgrade - qué siembra cada uno]] |
| 12 | Las cachés del motor no se comparten entre liquidaciones de un lote (cada una crea su `Motor`), al revés de lo que dicen los comentarios | [[Rendimiento y caché del cálculo]] |
| 13 | `YTD_ACUM`/`PERIODO_ACUM` usan la fracción más vieja vigente; el cálculo usa la más reciente. Si cambia el signo entre vigencias, discrepan | [[Acumuladores y fracciones]] |
| 14 | `Variable Sistema Liq.`: `DIAS_MES`, `MESES_PROM_AUS_6/12`, `DIAS_ESTADO_PERIODO` y `DIAS_ESTADO_PREVIOS` están en el motor pero no en el menú ni en `Sembrar` | [[Variables de sistema]] |
| 15 | Tablas/enums sin uso: `Diag. Fuente Datos Buffer` (110036), enums `Tabla Origen Liq.`, `SIRADIG Código Deducción`, `SIRADIG Parentesco`; código muerto en `Tipo Atributo Liq.` (`DesufijarESFCY`) | [[Índice Modelo de datos (110xxx)]], [[Enums de liquidación]] |
| 16 | **`VALOR_FRANCO` de los oficiales es un precio en dólares congelado en pesos.** Las ocho filas `OF01..OF04` de `175/75`, `768/19` y `ESP_FE0x` están cargadas sin `Moneda` y sin `Cód. Variable TC`, y **todas son exactamente USD × 1415**: OF01 162.725 = 115, OF02 141.500 = 100, OF03 127.350 = 90, OF04 120.275 = 85. La columna `PR_FRANCO` de Meta4 es `USD × TC del día` (24/01: 90 × 1405 = 126.450; nov: ×1425; mayo: ×1365). BC acierta sólo al TC 1415 y se desactualiza con cada movimiento; el error llega al pago cuando el lote se consume. Las de `729/15 MR0x` **no** son múltiplos de 1415: ésas sí son pesos del CCT y están bien. Se arregla con la maquinaria de TC por parámetro ya construida | [[Valor del franco]], [[control-moneda-es-asimetrico]], [[Grossing-up y tipo de cambio]] |
| 17 | **La detracción del art. 4 de la ley 27.541 se resta UNA VEZ POR LIQUIDACIÓN y es mensual.** Las fórmulas del `7000`, `7010`, `7060` y `7070` hacen `MAX(0, BASE_IG4 + BASE_EXT_IG4 - DED_CONT_PATR)` sin guarda `MES_`/`PERIODO_`, al revés del `TOPE_SIPA`, que sí se protege con `MES_BASE_SS_TRAB`. En enero de 2026, 157 de 329 empleados tuvieron más de una liquidación: la detracción del mes sumó **3.992.097,60** donde correspondían **2.239.815,77** (178%), y cada peso de detracción de más es contribución patronal de menos. Se arregla en la fórmula, no en el reporte: el **Reporte SICOSS** lo expone en la columna `DIF DETRACCION` de la hoja TOTALES | [[Reporte SICOSS]] |
| 18 | **La base de contribuciones patronales es la base de GANANCIAS, no la remuneración.** El `7000` y compañía parten de `BASE_IG4 + BASE_EXT_IG4`, que incluye los conceptos no remunerativos porque son gravables; Meta4 contribuye sobre el total con aportes. En enero de 2026 eso da una base de **1.946 M contra 1.607 M (121%)**, +339 M de base que arrastra jubilación, INSSJP, asignaciones familiares y FNE. Conflación de dos bases distintas: la fiscal y la de la seguridad social | [[Reporte SICOSS]], [[Acumuladores y fracciones]] |
| 19 | **`BASE_LRT` excluye lo no remunerativo y la base de ART de Meta4 no.** Enero de 2026: **1.142 M contra 1.959 M (58%)**, −816 M de base al 7,4% ≈ 60 M de contribución de ART. Lo mismo pasa con la base de contribución de obra social, que en BC es `BASE_OS_TRAB` (sin vacaciones) y da **1.579 M contra 1.956 M (81%)**. Las bases de APORTES, en cambio, cierran al 100,0%: lo que diverge son las tres bases de CONTRIBUCIÓN | [[Reporte SICOSS]] |
| 20 | **La zona está cargada en 90 de 330 empleados** y en enero de 2026 sólo 41 la publicaron a la fecha de su liquidación: 288 de 329 salen sin zona. Sin zona no hay crédito del decreto 814 —Meta4 declaró 70.445.755,69 en enero— y tampoco hay localidad para SICOSS. El atributo es `ZONA_DESFAVORABLE`, con valores 1 Capital Federal, 7 Resto de la Provincia, 29 Chubut y 69 Santa Cruz | [[Reporte SICOSS]], [[Atributos tipados]] |

## Suite AL: cinco fallos de la primera corrida

Primera corrida completa de la suite, el 13/10/2026, con `Runner Tests Liq.` (`Cod110070`) desde el servidor: **90 pruebas, 5 fallos**. Antes sólo la validaba el compilador, así que nadie sabía que estaban rotas. Cómo correrla: [[Tests automatizados]].

Los cinco se diagnosticaron uno por uno y cada diagnóstico lo revisó después un escéptico que intentó refutarlo leyendo el código por su cuenta. **Ninguno lo causó el cambio de la resolución de parámetros del 13/10/2026** ([[generica-nueva-pisa-especifica-vieja]]), y ninguno de los cinco diagnósticos fue refutado.

| Prueba | Qué pasa | Dónde se arregla |
|---|---|---|
| `Test Evaluador Fórmula.`<br>`AtributoComparaCodigoAunqueNumeroSeRepita` | **La prueba se borra su propio fixture.** `PrepararAtributoLista()` inserta filas reales en `Tipo Atributo Liq.`; los tres `asserterror` del medio revierten el ámbito de escritura del test y se las llevan. La caché `FCodigosValidos` tapa el agujero para los códigos ya validados, así que la que falla es la primera comparación posterior que vuelve a la base (`D'ANGELO`). Es la misma trampa que ya está anotada en [[Tests automatizados]] para francos | La prueba: partirla en dos o mover los `asserterror` al final. **No** meter un `Commit` para salvar el fixture |
| `Test Evaluador Fórmula.DecimalConComa` | **Prueba desactualizada.** El tokenizador dejó de aceptar la coma como separador decimal a propósito —está documentado en `Cod50015:1413-1422`— y hoy la coma es siempre separador de argumentos | La prueba: afirmar el contrato vigente (`asserterror` sobre `0,5 + 1`). `DecimalConPunto` ya cubre el caso bueno |
| `Test Formateador Fórmula.CortaLoQueNoEntra` | **Prueba desactualizada.** El fixture mide 88 caracteres y el ancho de corte es 96: entra en una línea y el formateador, correctamente, no la toca | La prueba: alargar el fixture ≥8 caracteres. **No** tocar `AnchoMaximo()`, que `CortaLasCadenasLargas` verifica en 96 |
| `Test Correcciones Rend. Liq.`<br>`FiltroConApostrofesYOperadores` | **Resuelto y publicado el 20/10/2026.** Las comillas no garantizaban igualdad literal para comodines y `@`. `FiltrarCodigos` conserva el OR para listas numéricas y usa `SetRange` por código con marcas locales para los demás; una lista vacía selecciona cero filas | Prueba original ampliada y tres regresiones nuevas aprobadas dentro de **56/56** en empresa aislada. Recibos, fórmulas y 59 tablas operativas intactos. Ver [[Tests automatizados]] y [[Francos - ledger FIFO]] |
| `Test Cuenta Francos.`<br>`AntiguedadUnificadaConservaTotalesYBases` | **Depende de los datos.** Corre el recálculo en cadena del empleado 80344 en 202601, y hoy existe LIQ-00052447 del mismo empleado en 202602 ya Calculada: el control de orden cronológico salta, como debe | La prueba. Ojo: saltear el primer control no alcanza, porque `LiquidarRecord` vuelve a chequear con el mismo `PrimeraPosterior` |

## Permisos

13 tablas persistentes no figuran en ninguno de los tres permission sets (entre ellas `Filtro Fuente Datos Liq.`, `Estado Tipo Liq.`, `Tramo Cobertura Liq.`, `Préstamo Empleado`, `Cuota Préstamo`, las dos de SIRADIG, las tres de `Hist. Meta4`, `Stg Valor Dim NAV` y las dos `Diag.`). El motor usa `Estado Tipo Liq.` y `Tramo Cobertura Liq.` en cada cálculo: un liquidador sin SUPER podría fallar. Cruce estático, **sin probar con un usuario sin SUPER**. Ver [[Permission sets de la extensión]].

## Repositorio y seguridad de datos

- La raíz pesa ~890 MB: 68 `.app`, 57 xlsx, 94 PDF. Las carpetas `2026-01`…`2026-08` son **recibos de sueldo de Meta4 con CUIL e importes**. Ver [[Mapa de la raíz del repo]] (incluye una propuesta de `.gitignore`, no aplicada).
- En el índice de git sin commit: `PackageLIQUIDACION.rapidstart` (export completo de BC con datos de empleados), `Oracle.ManagedDataAccess.dll`, un `.alcpuprofile`, un `.tsv` de recibos y un `.msg`.
- `.claude/settings*.json` apuntan a la ruta vieja `d:\…\OneDrive\Personal\…`: sus reglas ya no coinciden.
- El último commit es del 20/9/2026; 76 archivos modificados y ~38 sin seguimiento.
- `.vscode/rad.json` reapareció el 3/10 con `Removed` de 2 entradas (página «Control Liquidación Período» 110055, hoy 110056); no son tablas. Ver [[rad.json - peligro]].

## Scripts y migraciones

- Cinco scripts de BC escriben en vivo sin transacción manual; casi todos fijan empresa `ArbuTest`, base `Migr2013R2` y el AppId. Ver [[Catálogo de scripts SQL y PowerShell]].
- `MigrarEstados_2` asigna el proyecto por `Devenga Francos` (regla ya reconocida como errónea, ver [[gp-devenga-francos-pero-es-improductivo]]). `MigrarFasesAlta_1` trae `ID_SOCIEDAD = 'COMPLETAR'`.
- No hay script versionado de la historia Meta4 (`Hist. Liq. Meta4`), de `HIST_REMUN`, de novedades ni de anticipos. Ver [[Migración desde Meta4 - mapa y orden de ejecución]].
- Contradicciones de memoria sin resolver: si `M4T_HIST_PUESTOS` se migró ([[puesto-vs-categoria-cct]] dice que no; el script dice que sí, 18/9/2026) y si la categoría exacta de `M4T_HIST_CATEGORIAS` se migró ([[Migración Meta4 - atributos CCT, puestos y ausentismos]]).

## Paralelo de enero 2026: diferencias que siguen sin explicación

> [!tip] La lista viva de la liquidación final está en [[Pendientes liquidación final]]
> Ahí están los seis pendientes en orden, con los importes medidos y lo que se descartó. Esta sección
> guarda los residuos del cotejo general; la otra, el trabajo abierto de los egresados.

Residuos del cotejo contra Meta4, al 8/10/2026. No son hallazgos de lectura de código: son diferencias medidas que ya no tienen causa identificada.

| Caso | Diferencia | Qué se sabe |
|---|---|---|
| Cierre de marea del 04826 | 491.750 de más en BC | **Causa identificada y criterio confirmado.** Meta4 prorrateó su neto acordado sobre los 22 días de navegación (`15.000 × 22/30 × 0,70 × 1405` = 10.818.500, exacto) y BC sobre los 23 de marea. Pero el 04921 cuadra al centavo con sus **27** (26 nav + 1 puerto) y los dos tienen el día de puerto el 2/1: ninguna regla única da valores redondos para ambos. Se confirmó `DIAS_MAREA` como criterio, así que este residuo queda asignado a Meta4 |
| Regular del 04921 | 2.795,71 de más en BC | **A propósito.** `VALOR_FRANCO_CAL` de OF02 se mantiene en 3.600 (acuerdo de empresa de calamar) y Meta4 paga el equivalente a 3.500, el de langostino. Ver [[franco-tres-niveles-de-precio]] |
| ~~`PRECIO_PUERTO`~~ | **resuelto el 8/10/2026** | Eran 45 vigencias de la lista vieja sin partir por pesquería (marinería 729/15, MR00–MR08), sin fila en `Parámetro` y sin ningún lector: el 1083 nombra `PRECIO_PUERTO_CAL` y `PRECIO_PUERTO_LAN` explícitamente en las dos ramas de su `IF`, y la búsqueda que las dio por referenciadas matcheaba por prefijo. 36 eran idénticas a su gemela de `_LAN` y las 9 restantes, todas del 1/5, traían el valor anterior al split ([[precio-puerto-lista-inconsistente]]). Borradas; no queda **ninguna** base de parámetro huérfana en la base |
| Saldos iniciales de francos | sin medir | El del 04826 (OF04) viene sellado con convenio 768/19, contra la regla OF02/OF04 → 175/75. No se contó cuántos más tienen el par cruzado |
| **Contribuciones** | 114,4 M, y sólo 1 de 331 empleados coincide | Recién incorporadas al comparador; sin analizar |
| 2003 del cierre del 03664 | 1.415.000 de más, en la rama de producción | — |
| 23 períodos cerrados | sin fecha ni usuario de cierre | Anteriores a que el `OnValidate` del estado los estampara; falta decidir si se rellenan |
| `Fórmula Evaluada` ≠ `Importe` | visto 3 veces | El panel *Datos utilizados* muestra los valores reales; afecta la auditabilidad, no el importe |
| Nueve `TableRelation` a `Período Liquidación` | sin filtro de estado | Sólo se arreglaron las de Novedades; las otras siguen ofreciendo períodos cerrados |

## Lecciones que el código ya no respalda

Las que el análisis detectó desactualizadas (cada una lleva o debe llevar un callout de verificación): [[variables-rotas-valen-cero]], [[acumuladores-orden-calculo]] (`Invertir Signo`, no `Restar`), [[puesto-vs-categoria-cct]] (`ParDePuesto` devuelve el par completo), [[francos-fifo-ledger]] (el precio sale de la categoría de la liquidación que paga). Detalle en [[Divergencias entre documentación vieja y código]].

## Sin verificar en este análisis

La suite de tests AL (70 `[Test]`) no se ejecutó; sí corrió y pasa `test/editorFormula.atributos.test.cjs`. Tampoco se comprobaron contra la base: si las propuestas de tope SIPA y de grossing-up/TC están aplicadas, el estado de las cargas de valores 2026 (calamar, langostino) ni si el `.rdl` del recibo muestra bien un concepto `Informativo`.

## Interfaz y recibo

- **`Contabilizada`** existe en el enum de estado de la liquidación pero ningún código la asigna; no hay asiento contable ni Libro de Sueldos Digital, aunque la propuesta comercial los promete. Ver [[Estados y transiciones de una liquidación]].
- **CUIL del recibo** sale de `Social Security No.`, que según [[cuil-vive-en-cif-nif]] está vacío: probablemente sale en blanco (sin verificar). Ver [[Recibo de sueldo (reporte)]].
- El diseño predeterminado *Decreto* del recibo no imprime las variables «Mostrar en Recibo»; «Solo aprobadas» viene destildada (imprime Borradores); la antigüedad impresa es años ÷ 365, no la suma de fases del cálculo.
- **Tooltips desactualizados:** *Par CCT a Usar* y el Asistente de Fórmulas mencionan la asignación al proyecto (hoy es por atributos); Lanzador, *Calcular Período*, Lista y Árbol dicen «Borrador o Calculada» pero sólo calculan Borrador. «Crear Liquidaciones» y «Calcular Período» de Períodos están fijos en `REGULAR`.
- *Cerrar Período* dice «no se puede deshacer» pero existe *Reabrir Período*, y no verifica que todo esté aprobado. Ver [[Discrepancias de la guía original con el código]].
- Objetos sin permisos en ningún set: informes *Crear Liq. para Empleado*, *Insertar Incidencia Masiva*, *Avisos del Cálculo* y varias páginas (SIRADIG, Préstamos, *Tramos Cobertura Sub*, *Selector Tipos Liq.*…). Ver [[Perfiles, Role Center y permisos]].
## Prevuelo de febrero (12/10/2026)

**Ganancias: familiares históricos recuperados en 639.** Se importaron nueve fotos
mensuales verificadas contra las 20 corridas originales y se recalcularon 20 documentos.
Con la corrección adicional de SAC fiscal aprobada y aplicada en 643, los 14 casos
familiares y los otros dos casos de Ganancias por SAC STIA concilian al centavo.
4750 excluye 4683 y 4754 conserva su importe anterior. Se recalcularon los 13
afectados, con bruto, aportes, SAC real y saldos de francos conservados.
Sobre los 329 empleados comparables queda un caso de Ganancias superior a un peso
por aportes regulares, más 21 residuos entre un centavo y un peso. Ver
[[ganancias-familiares-meta4-vs-recibo-historico]]. Las fotos de diagnóstico siguientes
son anteriores a esta recuperación.


Ganancias de enero: de los 14 casos familiares se corrigieron seis clasificaciones y se
recalcularon seis meses completos. Cinco diferencias quedan inferiores al centavo;
los 14 cálculos de deducción coinciden con el maestro actual de Meta4. Nueve recibos
siguen difiriendo de la foto histórica, con filas actualizadas después de enero y una
baja fiscal actual anterior al período: no forzar la coincidencia alterando el maestro.
Ver [[ganancias-familiares-meta4-vs-recibo-historico]]. Quedan además dos casos por base
de SAC virtual que incluye el no remunerativo STIA y uno por aportes regulares distintos.
Ver [[diferencias-descuentos-enero]].

**Ganancias: devengo adicional de obra social del SAC mensual (Meta4 5397), resuelto.**
Aplicado desde 01/01/2026 y recalculados los meses de los tres afectados. Residuos del
impuesto inferiores al centavo contra Meta4; demás conceptos y francos conservados.
Ver [[tope-sac-por-liquidacion]].

Carga aplicada mediante AL en 638: cuatro cuotas AHA de febrero programadas, cuatro novedades
8850 agregadas (135 movimientos / 49 empleados, importes coincidentes), encuadres corregidos
y 12 puestos informativos de tierra cargados. El básico que parecía faltar era un cambio de
categoría: tarifa existente, sin parámetro personal nuevo. Calendario BASE con entradas fijas
08/09 además de 16/17 y cuatro ajustes manuales siguen pendientes de revisión.
Ver [[prevuelo-febrero-2026-migracion-meta4]] para cobertura, pruebas y saldo sin programación.

## Ganancias mensual de febrero: corrección aplicada (13/10/2026)

Se corrigió el piso de devolución de 5010 desde 01/02/2026 y la unidad de cinco
catálogos fiscales (24 vigencias), sin cambiar enero ni cargar novedades de impuesto.
El caso original concilia al centavo. Quedan 99 afectados calculados y uno reabierto
por otra sesión se conserva en borrador. Se verificaron escalas y saldos de sus
trazas. Durante la ejecución se publicó 646 con otra resolución de vigencias:
no atribuir todos los cambios de haberes/contribuciones al impuesto. Quedan 84
casos superiores a un peso frente a Meta4 entre los 235 controlados; la conciliación
de febrero sigue abierta. Ver [[ganancias-devolucion-mensual-y-unidades]].

## Haberes brutos de febrero al 15 de octubre

Se cargaron tres novedades originales de Meta4; luego, recuperada la conexión directa,
se aplicaron las vigencias reales de un básico, el porcentaje original opcional de
antigüedad y 58 precios originales de feriado con su auxiliar. Los ensayos finales
con rollback y los controles numéricos BC pasaron; enero y los recibos calculados
siguen intactos. El efecto final requiere recálculo puntual de febrero. Enfermedad
continuada y maternidad siguen sin aplicar; el plan de maternidad debe preservar
el SAC fiscal. Reparto navegación y puerto, guardia, historia de vacaciones y SAC
administrativo siguen abiertos. Ver
[[Control de haberes brutos de febrero 2026]] para alcance, verificaciones y límites.

## El feriado y los francos en otra corrida (20/10/2026)

El 1023 de marzo de 00406, 04046, 04496, 04560 y 02784 (+100 a +2.609) tiene una sola causa: Meta4 pagó los francos en una corrida aparte (tipo 13, el 4/3 y el 16/3) y en la regular del 25/3 el precio del feriado, que sale de la base de la corrida dividida por los días trabajados, no incluye la antigüedad de esos días de franco. BC liquida todo en la regular y su base sí la incluye. Restando `#1053 × días de franco / días de la antigüedad` a la base, BC coincide al centavo en 00406 (67.499,9957 contra 67.500), 04046, 04496 y 04560. **No se cambió la fórmula**: en febrero Meta4 pagó francos y feriado en la misma corrida (03325, 04164, 04207, 04706) y BC, con la base completa, coincide exacto; restar siempre rompería esos casos. La diferencia depende de cómo Meta4 reparte las corridas, y BC no lo sabe. 02078 (+209) no tiene francos y no se pudo explicar.

**Igualados por novedad (20/10/2026):** el feriado de marzo de 02078, 02784, 04046 y 04496 se cargó con lo que pagó Meta4 (`scripts/NovedadesFeriadoMarzoMeta4.sql`, cuatro novedades de importe del 1023, fecha 25/3). 02078 no tiene francos: su causa es un día de órdenes (1/3) pagado en otra corrida de Meta4 (antigüedad 6.275,88 / 30 ≈ 209); 02784 tiene un día de franco (31/3) y 148 pesos que la regla no explica. Falta recalcular las REGULAR de marzo de los cuatro.

## Descuentos de marzo: diferencias de Ganancias (20/10/2026)

Las 21 diferencias de descuentos de marzo son todas del 5010 (Ganancias). Causas encontradas:
- **Ficha de familia editada en Meta4 después de marzo** (altas y bajas retroactivas cargadas en abril): 90251, 04874, 04877, 04843, 04809 y 04313. Decisión del usuario (opción B): reproducir lo que Meta4 liquidó en marzo moviendo las fechas de la ficha (`FamiliaGananciasComoMeta4Marzo.sql`, siete filas de Employee Relative). **Revertir en abril**: no son los valores reales; los originales están en el encabezado del script.
- **Hijo que cumple 18 en enero o febrero** (00794, 04169, 03664): resuelto el 20/10/2026 con la deducción acumulada mes por mes (`DEDUC_GANANCIAS_ACUM`, ver [[deduccion-ganancias-acumulada-por-mes]]); falta recalcular y verificar.
- **90451**: BC descuenta 127.925 más de seguridad social que Meta4 (el acumulado topeado del año).
- **90184**: resuelto el 20/10/2026. Meta4 deduce servicio doméstico acumulado (`DED_SER_DOM_ST`: 281.741,78 en febrero, 563.483,56 en marzo) y BC sólo tenía febrero en `GAS_DOM_HIST_90184`; se cargó marzo (`scripts/GastoDomesticoHistorico90184Marzo.sql`). La carga sola no alcanzó: la vigencia del 5010 de marzo (`DEDUC_GANANCIAS_ACUM`) no leía el concepto virtual `DEDUC_GANANCIAS` donde entran los `GAS_*_HIST`, así que marzo los ignoraba para todos; corregido sumando `GASTOS_IG4_HIST / (1 + 1/12)` al término acumulado (`scripts/Gastos5010AcumuladoConHistoricos.sql`). Cuando falte una deducción de gastos, mirar primero qué `DED_*_ST` trae Meta4 en `M4_ACUMULADO_RL` y si existe el `GAS_*_HIST` de ese mes.
- **01477** (−130.016): no era el neto garantizado sino la cuota alimentaria (8893, novedad pura). La incidencia de Meta4 del 19/3 vale 3.890.693,08 pero la corrida retuvo 4.020.709,40 (la incidencia se editó el 31/3, después de liquidar); la del 25/3 devolvió 91.740,32. Se igualó la novedad 3017 a lo retenido (`scripts/NovedadCuotaAlimentaria01477Marzo.sql`). Si el trabajador reclama, esos 130.016,32 fueron un exceso de Meta4 que no se devolvió en marzo.
- **04848** (−42.505): tampoco era el neto garantizado sino la cuota alimentaria (8893). La novedad 5251 (42.504,75) estaba fechada el 25/3 y 04848 sólo tiene la DEVENGADOS que cubre del 27 al 31/3, así que quedaba sin aplicar; se movió al 31/3 (`scripts/NovedadCuotaAlimentaria04848Marzo.sql`). Es la lección [[novedad-con-proyecto-queda-huerfana]] en versión fecha: una novedad fuera de toda cobertura no avisa. Tras esto no quedan novedades de marzo en Estado 0 con importe.
- **04775** (+13.470, 5010): la base de Ganancias de BC tenía 112.252,17 de más, el SAC devengado de la LIQ_FINAL de enero (alta nueva el 2/2). Los conceptos virtuales `SAC_DEV_YTD_BASE`/`YTD_SAC_DEV` (que restan el 4750 de las finales del año del arrastre) sólo tenían vigencia en febrero; se extendieron desde el 1/3 (`scripts/ArrastreSacSinFinalesDesdeMarzo.sql`). La cohorte de marzo son 7 empleados con final y liquidación posterior (04139, 04486, 04751, 04775, 04803, 04854, 04889): hay que verificar que ninguno se mueva a peor. Cómo se halló: con la escala de marzo, 13.470,26 / 12 % = 112.252, igual al 4750 de enero.
**Verificado (20/10/2026, tras recalcular):** descuentos de marzo iguales a Meta4 (±0,02) en 90184, 90454, 01477, 04848, 04775 y los otros seis de la cohorte con final (04139, 04486, 04751, 04803, 04854, 04889). Quedan 02854 (+375) y los chicos: 80267, 90414, 80002, 90447, 90451.
### 02854 desde enero (21/10/2026): enfermedad sin precio informado

Tras recalcular el trimestre, 02854 tenía diferencia desde enero. Causa: el 4110 usa `PRECIO_ENF_INF` (suma de las novedades 4057 del período, ignora las Anuladas) y, sin precio, el promedio `PROM_ENF_MES`. Meta4 paga la enfermedad con `PRE_ENFER` = 135.153,34 (incidencia 4057 del 25/1): 135.153,34 × 26 × 30 % = 1.054.196,05 en enero y × 5 = 675.766,70 en febrero. BC no tenía esa 4057: su enero se igualaba con la novedad 9431 (4110 por importe), anulada el 16/10 al pasar al precio informado, y febrero nunca se igualó. Quedaban 4110 +48.729,13 (enero) y +31.236,62 (febrero), y el 3554 de enero +113.702 por depender del mismo promedio. Es el único empleado con diferencia de 4110 entre enero y marzo (64 de 66 mes-empleado coinciden). Corregido con dos novedades 4057 (`scripts/Novedad4057Precio02854EneFeb.sql`). **Falta recalcular en cadena enero a marzo de 02854.** Lección: al reemplazar una novedad de importe por el precio informado, revisar que cada empleado que la tenía quede con su 4057. Los 4057 de BC no coinciden con las incidencias 4057 de Meta4 de enero (00291, 02670, 04216 tienen incidencia y no novedad en BC, pero su 4110 coincide).

### Abril de 2026 contra Meta4: diferencias clasificadas (21/10/2026)

Abril ya está calculado en BC (424 liquidaciones: 90 cierres, 53 finales, 279 regulares, 2 vacaciones). De 332 empleados comparables, 112 difieren en bruto (>1 peso), 75 en descuentos y 91 en contribuciones; 3 de ellos (04163, 04455, 04836) tienen datos viejos (ver 5). Comparación por concepto: Meta4 por columna (`M4_ACUMULADO_RL*` con el mapa `m4_conceptos`) contra las líneas de BC. **No son diferencias** y se ignoran: 4750-4754 (en Meta4 se llaman `BSAC_MES`, `JUB_SAC_MES`…), 2498/1343 (mismo total con otro nombre), 1062 (en Meta4 es un precio), anticipos 4813/4823 (BC los toma de préstamos), 5498 (redondeo).

**Por popularidad:**
1. **Novedades pendientes que nunca se aplicaron (64 novedades, unos 60 empleados).** 3973 (32), 8850 (10), 2043 (8), 2041 (7), 5310 (5), 8830 y 4057 (1 c/u). El 3973 (vacaciones no gozadas) fija `CANT_INCIDENCIA` y sin la novedad paga 0: en 29 finales Meta4 paga 31,2 M de vacaciones no gozadas y 2,6 M de SAC que BC no. **Causas distintas (analizado y corregido el 21/10/2026, `scripts/NovedadesPendientesAbril.sql`):** (a) 3973 (32) y 2043 (8): ya tenían tipo y proyecto coincidentes con su liquidación (se completaron a las 21:10, después del cálculo de las 21:01): sólo faltaba recalcular, no hacía falta cambiar la fecha porque con tipo explícito la fecha no filtra; (b) 8850 (8) y 8830 (1) tenían el **proyecto de la marea** y su fecha del 25/4 cae en la regular, que va con el proyecto de nómina: huérfanas por proyecto (se vació el proyecto en las 8850; la 8830 de 04848 pasó al 23/4 para entrar en el cierre de su proyecto); (c) 8850 de 04802 (2), 4057 de 01767, 5310 de 04351 y 02879: fecha fuera de la cobertura de su liquidación, re-fechadas; (d) 2041 (7): tipo REGULAR en empleados que sólo tienen LIQ_FINAL en abril, pasado a LIQ_FINAL; (e) 5310 de 02297, 02804 y 90308: no tienen liquidación de abril en BC, siguen pendientes (necesitan decisión). Un tipo explícito gana sobre la fecha, pero el proyecto explícito no: ver [[novedad-con-proyecto-queda-huerfana]].
2. **1083 sueldo de puerto un día menos en 37 empleados**, siempre exacto un día de precio (50.207 en 04839). Arrastra 1053 antigüedad, 1603, 8522, aportes e impuesto. 04839: NV hasta el 22/4, PL el 23, PI 24-25 y GP 26-30; BC paga 1 + 5 = 6 días y Meta4 7. El 1043 de pilotaje coincide al peso porque se cargó como novedad por importe (40 aplicadas): **la fórmula nueva de pilotaje no está probada**.
3. **5010 distinto sin diferencia de haberes** (03774 +309.490, 04313 +205.435 y otros): arrastre fiscal o 5310 (5 novedades pendientes de 5310 en 02879, 04351…).
4. **2803/2804 y 3813 de las finales** (9 empleados): 04139 BC 2.755.361 contra 899.710 de Meta4 (3 veces), 04889 3.655.071 contra 2.249.275, y +5 % en 03791, 04802, 03104, 04046 (valuación FIFO del saldo).
5. **Tres oficiales con 2803 de 16.754 a 22.862 millones** (04163, 04455, 04836): venían de tres novedades 1062 con el precio cargado como importe, leído como días. Ya se anularon (21:10, "el 1062 de Meta4 informa un precio, no días"); su cálculo es anterior: recalcular.
6. **Feriado 1023 y 2043** (15 y 8 empleados, ~1 %).
7. **4110 sin precio informado** en 02670 (+650.162) y 04216 (+156.340): el mismo caso de 02854; Meta4 arrastra `PRE_ENFER` y BC pide una 4057 por mes.
8. **Básicos personales de abril** (90016, 90361: 1003; 90302, 90212: euro) pendientes de cargar.

**Verificado tras recalcular las 58 liquidaciones (21/10/2026):** bruto fuera de 1 peso 112 → 104, descuentos 75 → 70, contribuciones 91 → 89. Se resolvieron los pendientes: 3973 de 32 empleados con diferencia a 5 (3974 de 31 a 2), 2043 8 → 0, 8850 y 8830 → 0, 2041 sin efecto visible; el 5310 queda en 3 (los sin liquidación). Los tres oficiales (04163, 04455, 04836) ya no tienen miles de millones pero el 2803 de BC es 1/1,2 del de Meta4 y el 1063 igual (BC 236.300 contra 283.560; 4.844.150 contra 5.812.980): **Meta4 valúa el franco de abril a 141.780 (OF04) y 165.600 (OF02), exactamente un 20 % más que los 118.150 y 138.000 de BC**; es el precio que traían las tres novedades 1062 anuladas ("precio manual pendiente de representación"). `VALOR_FRANCO` está en USD y sólo existe `175/75 OF04`, `175/75 OF02`, `768/19 OF01` y `768/19 OF03`; falta además `768/19 OF04` y `768/19 OF02`, que son los de estos tres empleados. **Aplicado el 21/10/2026 por decisión del usuario (`scripts/FrancoAbril20PctYBajaPuerto.sql`, falta recalcular):** (1) vigencia de abril de `VALOR_FRANCO` con +20 % para las seis filas de oficiales (175/75 OF02 3.600, OF04 3.060; 768/19 OF01 4.140, OF03 3.240; ESP FE01 4.140, FE02 3.600 USD); `VALOR_FRANCO_EMP` no se tocó (con el convenio por encima de él, el 2083 debe dar 0 como Meta4). El primer INSERT copió por error también las 9 filas de tripulantes (729/15 MR00-MR08) con +20 %; se borraron el mismo día y el script quedó filtrado por categoría. **Los MR no tienen vigencia de abril en `VALOR_FRANCO`** (hay enero, febrero, marzo, mayo y junio): abril toma el valor de marzo; no se comprobó contra Meta4. (2) Personal Proyecto: `Fecha Baja` de la asignación de marea (PP-…) de 23/4 a 24/4 en los 40 empleados con el día de puerto de menos (39 con exactamente un día de precio de diferencia y 02452 con 1,06). **Verificado tras recalcular los 40 (21/10/2026):** (1) el +20 % del franco **funcionó**: 1063 de los tres oficiales igual a Meta4 (283.560 y 496.800) y 2803/2804 de 04163 exactos (5.812.980 y 484.415); quedan 04455 con 331.200 menos (= 2 días × 165.600) y 04836 con 141.780 menos (= 1 día); el 2083 de BC da negativo (−17.400 y −8.897) donde Meta4 da 0: **falta el `MAX(0, …)` en la fórmula del 2083** ahora que el convenio supera el franco de la empresa; el 5010 de las finales sigue lejos (04836: BC −2,72 M, Meta4 +2,73 M; 04163: −0,97 M contra +3,45 M). **CORRECCIÓN POSTERIOR (21/10/2026, a indicación del usuario): la conclusión de abajo sobre la baja estaba mal.** El día extra de puerto *al finalizar* la campaña funciona igual que el del inicio: se suma si el empleado está asignado a la marea en ese período (ver "Puerto posterior al arribo" en [[dia-de-puerto-no-estira-la-marea]]). Ese código (`Init` con `CoberturaHasta` en Cod50016) estaba en el repo desde las 15:36 pero **sin publicar** (mis publicaciones posteriores fallaban por la compilación de Control Previo, que ya compila), por eso el 1083 no se movió. Se publicó la 1.0.0.679 y **la baja ampliada a 24/4 en Personal Proyecto es necesaria: no revertir**. **Verificado tras publicar la 1.0.0.679 y recalcular los 40: el 1083 no cambió (104/70/89 igual).** El código no implementa la regla: `VentanaEmpleadoEnMarea` documenta que "el fin recorta pero no estira: una baja posterior al arribo no agrega días", y el "puerto posterior al arribo" de la 679 sólo suma días de estado `Transcurre en Marea` hasta la **cobertura** de la liquidación (`FFechaHastaPuerto` = Cobertura Hasta = arribo, 23/4); el día extra (24/4) cae en la cobertura de la regular. A diferencia del inicio —donde `CalcDiasPuertoMarea` suma los días de víspera entre el alta de la asignación y el zarpe— no hay un equivalente que sume los días entre el arribo y la baja de la asignación. **Implementado y publicado el 21/10/2026 (1.0.0.680, ver [[dia-de-puerto-no-estira-la-marea]]) y VERIFICADO tras recalcular los 40: el 1083 pasó de 40 empleados con diferencia a 6 (exacto en 04839, 04526, 04838, 04914…; quedan 04791 −917, 04924 −717 y 02452 −14.347 por precio); bruto fuera de 1 peso 104 → 103, descuentos 70 → 67, contribuciones 89 → 86.** Lo que queda en esos 40 es otra cosa: el **pilotaje**. Meta4 paga la corrida de pilotaje (tipo 12) con `DS_PILOT_REALES` 2 (los días reales del estado PI) pero `DIAS_PILOTAJE` **5** y `SUELDO_PILOTAJE` = 5 × `PRECIO_PILOTAJE` (2 × precio de puerto / 30) = 502.070 en 04839; la antigüedad y los acuerdos usan esos 5 días (BC 31 días de antigüedad contra 34 de Meta4: 22 + 7 + 5; BC cuenta 22 + 7 + 2). **Regla medida en todo el historial de Meta4 (RL3, 2001-2026): con 1, 2, 3, 4, 5 o 6 días reales de pilotaje se pagan siempre 5** (663 casos con 4 reales, 524 con 3, 360 con 1, 334 con 2, 216 con 5, 32 con 6). BC usa los días reales del estado (`DIAS_PILOTAJE`) en el 1043, en la suma de días de la antigüedad (1053) y en 2033/2023, y tapa el 1043 con 40 novedades por importe. **ACTUALIZACIÓN 22/10/2026: el pilotaje pasa a liquidarse aparte (tipo `PILOTAJE`, un proyecto por marea con horas); la tabla en días de abajo se reemplazó por `TAB_HORAS_PILOTAJE` y se publicó la 1.0.0.681 con `HORAS_PROYECTO` (`scripts/PilotajeLiquidacionAparte.sql`). Falta: recalcular los 40 cierres, "Crear y calcular" PILOTAJE de abril y recalcular regulares y finales; 03777 (buque 802), 04518 (buque 128) y 04906 (buque 801) cobraron la corrida de pilotaje en Meta4 y no estaban asignados: asignados el 22/10 a PN-802-260423, PN-128-260424 y PN-801-260423; 02924 estaba asignado sin haber embarcado (estado OR en abril) y se le sacó la asignación (`scripts/AsignacionesPilotajeAbril.sql`): quedan 13 + 14 + 13 = 40, los mismos de Meta4. Los 43 estados PI siguen en los proyectos de marea. Detalle en [[pilotaje-y-dique-sin-formula]].** Lo que sigue es el paso previo (21/10): aplicado el 21/10/2026 con el texto del convenio que aportó el usuario (SOMU art. 43, oficiales art. 29: 5/10/15/30 días según la duración; `scripts/PilotajeDiasPagadosCCT.sql`, detalle en [[pilotaje-y-dique-sin-formula]]): tabla `TAB_DIAS_PILOTAJE`, concepto `DIAS_PILOT_PAGO` y ocho fórmulas que lo leen; 40 novedades 1043 anuladas. Falta recalcular abril de los 40 y verificar el 1043 y la antigüedad contra Meta4.** Propuesta aprobada: sumar al puerto de las liquidaciones con disparador Arribo los días desde max(arribo, `FFechaHastaPuerto`) + 1 hasta min(baja de la asignación, fin del período), restarlos también de `DIAS_MAREA` (como los días declarados) y no tocar el viaje. Lo que sigue es el análisis previo, parcialmente superado: (2) Ampliar la baja de Personal Proyecto **no cambió nada**: el cierre sigue cubriendo 1-23/4 (la cobertura sale de la fecha de arribo del proyecto, no de la asignación) y `DIAS_PUERTO` sigue en 1; 1083 idéntico en los 40. **Lo que sí distingue a los 40:** todos tienen exactamente 2 días en estado PI (24 y 25/4) y ninguno de los otros 50 cierres tiene PI; los estados de Meta4 y de BC son idénticos (mismas fechas de PL, PI y GP). Meta4 paga con esos mismos estados 5 días de pilotaje (1043 = 5 × 2 × precio/30) y 1 día más de puerto: es una regla de pilotaje distinta, no un dato. Falta extraer la regla original de Meta4 (como se hizo con el 4057 de enfermedad) y escribir la fórmula; mientras tanto el 1043 sigue cargado por importe y tapa la fórmula. **La baja ampliada a 24/4 en los 40 es inocua pero inútil; conviene revertirla (24/4 → 23/4).** Queda abierto: 1083 (40 empleados, un día menos), 5010 (52), 8522/6000/6010/6030 (derivados), 1053, 1023 (16), 2803/2804 (12; 04139 y 04889 3 veces más en BC), 2003 (10), 1603 (10), 1063 (6), 2083 (6), 4110 (2), básicos (4).

**Problemas de formulación o de diseño:** 2803/`PAGO_FRANCOS_SALDO` (sin tope ni cordura: miles de millones por un dato malo, y 3 veces más en 04139), conteo de días de puerto/PI en el 1083, `PRECIO_ENF_INF` (no persiste el precio entre meses) y la falta de aviso para novedades pendientes fuera de cobertura.

### 04724 en febrero: 1.099 de neto de más en BC, ACEPTADO (21/10/2026)

El único empleado con `NETO_GU_MAREA` personal liquidado en febrero (12.750 USD). El cierre del 7/2 coincide con Meta4; en los devengados todos los conceptos coinciden al centavo salvo el 2003 (complemento del grossing-up): BC 7.016.188,57 y Meta4 7.014.191 (+1.997,57 de bruto, +903 de descuentos, +1.094 de neto). **No es tipo de cambio:** BC usa `TC_COMPRADOR` 1.370 (27/2) y Meta4 también (`NTO_GARANTIZADO` 5.400 USD × 1.370 × 16/30 = `BRUTO_PRORRAT` 3.945.600); con 1.365 BC se desviaría unos 22.700. BC converge al objetivo (6.005.809,40; neto 6.005.804,10) y Meta4 liquida 6.004.710, 1.099 por debajo de lo garantizado, probablemente por la tolerancia o el redondeo de su grossing-up. Decisión del usuario: aceptar la diferencia. **No se puede igualar con una novedad en el 2003:** el motor persigue el neto garantizado ajustando ese concepto y lo trata como un piso (`ConvergerGrossingUp` nunca acepta quedar por debajo, sólo por encima dentro de un escalón de redondeo); fijar el 2003 por novedad deja el neto 1.099 abajo y la liquidación falla con "El grossing-up no convergió… No se guardó". La única forma de reproducir a Meta4 sería una vigencia con un `NETO_GU_MAREA` reducido (~12.747,85 USD), que no se hizo.

### Preparación de abril de 2026 (diagnóstico del 21/10/2026, incompleto por pérdida de conexión)

> [!warning] Diagnóstico histórico superado
> La conexión se recuperó y las correcciones seguras se aplicaron con guardas.
> Consultar «Entradas de abril aplicadas y pendientes» al inicio de esta nota.
> No ejecutar la reversión familiar propuesta abajo sin resolver su efecto histórico.

**Listo:** período 202604 existe (estado *Creado*, calendario `BASE`; marzo usa `M4BASE`); parámetros fiscales de abril cargados (MNI, deducción especial, cónyuge/hijo, `TOPE_SIPA` y `TOPE_SIPA_OS` 4.162.912,57, `VALOR_ART_FIJO` 1.724, básico 130/75 EC01) y `TAB_IMP_4CAT` de abril; USD completo (20 cotizaciones al 30/4); población: 335 empleados con fase de alta en abril contra 336 que Meta4 liquidó; ingresos de abril 04351 (alta 23/4) y 04726 (22/4) coinciden; nada vence el 31/3 sin sucesor salvo el 4874 (Meta4 no tiene cuota de abril del bono).

**Hay que decidir o resolver antes de crear:**
- EUR de abril sin cargar: última fila 1/3 (1.640); Meta4 muestra 1.690 (90302) y 1.764,01 (90212) en abril, 1.685 en mayo.
- 61 novedades **pendientes** de abril con **importe** sobre conceptos que ya tienen fórmula y que la congelan: 1043 (40) y 2033 (13) de pilotaje/dique, 2013 (4), 1062 (3) y 4115 (1); los -1 de 1022 (78) son intencionales. Las 132 en Estado *Anulada* (4813 y 4823 que salen de préstamos, 8870 duplicadas, 4110) no cuentan. Para verificar las fórmulas de pilotaje contra Meta4 hay que anular las de 1043/2033 o pasarlas a cantidad.
- Básicos personales de abril (`M4T_VAL_FASE_ALTA`, concepto 1002, 8 empleados): sin fila de abril en BC para 90355 (Meta4 5.531.335; BC 6.426.257 desde marzo), 90418 (3.416.667; BC 2.635.285), 90361 (9.246.956; BC 1.807.228 desde enero), 80668 (2.610.441) y 90016 (16.778.033); 90212, 90302 y 90251 están en divisa y no se pueden comparar directo (90251: 8.222.500 = 5.750 USD × 1.430).
- Empleados con fase de alta en abril sin convenio o categoría: 0.
- 5310 (Ganancias año anterior): 161 novedades por -117.746.037,12, iguales a las 161 de Meta4 (mayo trae 2 más). Confirmar el tratamiento antes de calcular.
- Meta4 corre en abril los tipos de imputación 11 (139 empleados) y 12 (40) que marzo no tuvo; sin equivalente documentado en BC (12 sería pilotaje).
- 90308 (baja 13/3): Meta4 le liquida 2.287.469,47 el 25/4 sin devengo; BC no tiene fase en abril.
- Revertir en abril las fechas de familia de `FamiliaGananciasComoMeta4Marzo.sql`.
- Calendario de abril `BASE` contra `M4BASE` de marzo (los calendarios copiados no se actualizan solos).
- Marzo todavía no está cerrado: el recálculo en cadena de enero a marzo estaba corriendo (~1.500 liquidaciones) y quedan 80344 por recalcular y los 5 ingresantes de enero. Abril lee los acumulados de marzo.
- NAV: última sincronización 13/9/2026 sin filas pendientes; 9 proyectos con arribo en abril.
- **No se pudo medir:** básicos personales de abril (Meta4 trae 8 valores de `1002`, alta de vigencia en abril), empleados sin convenio/categoría, y el informe *Preparación de liquidaciones* (se corre desde la interfaz). Publicar código está bloqueado mientras los archivos sin versionar de `Control Previo Liq.` no compilen.

### Contribuciones de marzo contra Meta4 (20/10/2026)

**Cómo comparar:** el `TOT_CONTRIB` de Meta4 (`M4_ACUMULADO_RL2`, suma de las corridas del mes) **no incluye las contribuciones de vacaciones ni de SAC**, que están en columnas aparte (`JUBIL_PAT_VAC`/`_SAC`, `VAC_23660_PAT`/`SAC_23660_PAT`, `VAC_PAT_CASFECC`/`SAC_PAT_CASFEC`, `VAC_PAT_L_19032`/`SAC_PAT_L_19032`, `PAT_ART_VAC`/`_SAC`, `AP_F_NAC_EM_VAC`/`_SAC`); hay que sumarlas, y el ART de Meta4 (`PAT_ART`) trae junto lo que BC parte en 7050 + 7053. Aparte, 7080 (seguro de vida, 424,62 fijo) y 7090 (contribuciones sindicales) no existen en Meta4 y se excluyen. Con eso, 305 de 349 empleados coinciden a menos de 1 peso antes de los arreglos de hoy. Los 44 restantes:
- **12 empleados con el bono 4874** (80002, 80267, 80316, 80344, 80668, 90319, 90414, 90419, 90440, 90444, 90447, 90449): −14.060 de ART cada uno. Meta4 cobra ART sobre los 190.000 (7,4 %); el bono es remunerativo pero no integra `BASE_SS_TRAB`. Corregido con una vigencia del 7050 desde el 1/3 que suma `#4874` a la base (`scripts/Art7050ConBono4874.sql`). No se usó `BASE_LRT` (difiere de la base de ART en 89 liquidaciones de marzo) ni `NO_REMUNERATIVO` (lo leen 7090 y 7093 y entra en el bruto). **Verificado (21/10/2026):** 11 de los 12 coinciden (±0,01); 80344 quedó con la liquidación vieja (usa la vigencia del 1/1 del 7050) y falta recalcularla. Comparación completa tras el arreglo: 316 de 349 dentro de 1 peso (se excluyen 7080 y 7090-7099).
- **18 ingresantes en mes de 31 días** (+42,01 cada uno: 03183, 04001, 04046, 04137, 04139, 04347, 04393, 04487, 04496, 04542, 04606, 04672, 04751, 04928-04932): la detracción (`5802` → `CNT_RED_SUELDO`) usa `DIAS_ALTA_30`, que saltea el 31; Meta4 cuenta el 31 para el primer mes (04751: 7 días y BC 6; 04139: 10 y BC 9; 03183: 30 y BC 29), con lo que descuenta 233,46 más de base. **Corregido y verificado el 21/10/2026** (los 18 coinciden a ±0,01; marzo queda en 334 de 349 dentro de 1 peso) (`scripts/DetraccionIngresanteDia31.sql`): vigencia del 5802 desde el 1/3 que suma 1 a `DIAS_ALTA_30` si el período tiene 31 días, el alta es parcial (0 < días < 30) y la liquidación no es `LIQ_FINAL`. No se tocó `DIAS_ALTA_30` (lo usan el 4703 y los topes SIPA, verificado así contra Meta4). **La vigencia de enero del 5802 tiene la misma fórmula vieja y enero también tiene 31 días**: **medido (21/10/2026): enero tiene el mismo error en 5 ingresantes de REGULAR/DEVENGADOS (04486 7 días contra 8 de Meta4, 04703, 04855, 04901, 04926: +42 cada uno)**; **extendido a enero el 21/10/2026** por decisión del usuario, editando en el lugar la vigencia 1/1-31/1 (`scripts/DetraccionIngresanteDia31Enero.sql`); falta recalcular enero de esos 5 y verificar. Enero coincide en 308 de 330 empleados; los otros fuera de 1 peso son 4 finales con +18 (03964, 04775, 04889, 04900: otra causa), 04807/90452 −84, 03073 −1.135, 04706 −1.602, 04190 −168 y redondeos.
- **Individuales:** 90451 −798 (maternidad: Meta4 prorratea también la detracción por los 11 días pagados), 02048 +378 (vacaciones más regular, detracción repartida entre las dos), 04185 −126 (liquidación final), 04560 +34, 02879 −1.637 (Meta4 corrió una liquidación en cero que sólo cobra el ART fijo; BC no tiene liquidación de marzo) y ocho de −1 a −9 por redondeo.

- **90451** (−1.869,68 de impuesto, causa hallada y corregida el 20/10/2026, falta recalcular): el bruto acumulado y los aportes mensuales (6000/6010/6030) ya coincidían; lo que quedaba era el SAC. Los aportes sobre SAC devengado (4751/4752/4753) prorrateaban el tope SIPA sólo por `DIAS_ALTA_30` y Meta4 lo hace por los días pagados sin maternidad (11 de 30): 13.597,68 y 3.708,46 contra 19.965 y 5.445 de BC. Esos 9.840,40 de más se restaban en la base de Ganancias (×19 % = 1.869,67). Vigencia nueva desde el 1/3 con `(DIAS_ALTA_30 - DIAS_MATERNIDAD_30)` (`scripts/TopeAportesSacSinMaternidad4751.sql`), igual que el 6000/6010/6030. Accidente y ART, que Meta4 también excluye del tope, siguen sin tocar.
**Estado de los descuentos de marzo (20/10/2026, tras recalcular 90451):** de 348 empleados comparados, 338 coinciden con Meta4 a menos de 1 peso. Fuera quedan 10: 02854 (+374,87, aceptado; ver su entrada), 04560 (+21,08), y ocho de entre −1,67 y −11,60 (04163, 04826, 04921, 04724, 04836, 04868, 90016, 90212), todos de redondeo/tipo de cambio y sin analizar. 90451 quedó en −33.081,06 igual a Meta4.
- **Los cuatro chicos de marzo (80267 +2.948,17, 90414 +2.948,18, 80002 +2.327,51, 90447 +1.861,99)**: causa común, el concepto **4874** (Bono Fin de Año STIA, cuota de marzo, 190.000 fijos, 12 empleados: 80002, 80267, 80316, 80344, 80668, 90319, 90414, 90419, 90440, 90444, 90447, 90449). Integra `BASE_IG4` pero Meta4 no lo cuenta en el SAC devengado: su `BSAC_MES_RG3976` es (bruto − 190.000)/12 (verificado en 90414, 80267, 80002 y 90447). BC lo incluía en el 4750 (+15.833,33 por mes) y en el 4754; eso movía la base de Ganancias (×19 % del tramo) y la cuota sindical del SAC. Los aportes 4751-4753 ya coincidían. Corregido con una vigencia desde el 1/3, **abierta**, de 4750 y 4754 que resta `#4874` (`scripts/SacDevengadoSinBono4874Marzo.sql` y su corrección `SacDevengadoSinBono4874Abierta.sql`). La primera versión las limitaba a marzo por creer que un `#` a un concepto fuera de vigencia da error: **no es así**. `ResolveConceptoCalculado` (Cod50015) busca el concepto con `Vigencia Desde <= fecha` y no mira `Vigencia Hasta`; sólo da error si el concepto todavía no existía (antes del 1/3 para el 4874). Si no corrió en la liquidación, vale 0. Si el bono vuelve en otro mes no hay nada que hacer en estas fórmulas. 90451 no está en este grupo. **Verificado (20/10/2026, tras recalcular):** los 12 empleados con 4874 coinciden con Meta4 en descuentos (±0,01) y en bruto (±1). De los chicos de marzo sólo queda 90451 (−1.869,68, impuesto).
- **02854** (+375 en marzo, causa hallada, ACEPTADO por el usuario el 20/10/2026): el impuesto acumulado de BC queda 374,86 por encima porque la cuota sindical acumulada que deduce es 1.972,84 menor (×19 %, el tramo de marzo). Nace en **enero**: el 4754 (cuota sindical sobre SAC devengado) de la vigencia de enero usa `(BASE_IG4 + BASE_EXT_IG4) / 12` = 3.513.986,90 / 12 y da 11.713,29; Meta4 usa la base sindical entera, 4.105.838,44 / 12 × 4 % = 13.686,13 (hay 591.851,54 que cuentan para el sindicato y no para Ganancias). **Extender el arreglo de febrero no sirve para este caso**: lo que febrero agregó fue `− #2803` (francos no gozados) y 02854 no tiene 2803 en enero; lo suyo es la prestación ILT (4125 y 4165, 591.851,55), que cuenta en `BASE_SINDICAL` pero no en `BASE_IG4`/`BASE_EXT_IG4`. Medido en enero (20/10/2026): el 4754 coincide con el `C_SINDICAL_SAC_MES` de Meta4 en 271 de 278 empleados; de los 7 restantes 4 son los de caja/fondo (04724, 04924, 01541, 04893: ver la lección de los cuatro descuentos) y 3 son de base (02854, 04190, 04807). Marzo (liquidaciones vacaciones y regular) coincide en todo lo demás: bruto, aportes, cuota sindical del mes y la novedad 8563 (el reparto entre las dos liquidaciones no mueve el total). Opciones: aceptar los 375, o una novedad de 13.686,13 en el 4754 de enero y recalcular enero-marzo de 02854.

**04495 (descuentos de marzo, −127.831):** la VACACIONES se paga con la novedad del 3553 y su historia de estados no tiene días de vacaciones en marzo (`DIAS_VAC_INICIO` = 0), así que el 6013 (Ley 19032 vacaciones, 54.785) y el 8525 (cuota sindical vacaciones, 73.047) no corrían: su condición era por los días. Vigencia nueva del 1/3 con condición por la base, como el 6003 (`Condicion6013y8525PorBase.sql`). El 6037 y el 8810 tienen la misma condición y no se tocaron (sin evidencia de Meta4). Falta recalcular la VACACIONES de marzo de 04495.

**Verificado (20/10/2026):** tras recalcular, 04495 coincide en descuentos (6013 y 8525 de la VACACIONES) y quedan 11 empleados con diferencia de descuentos de marzo: 02854 (+255.357), 90184 (+174.680), 01477 (−130.016), 90451 (+93.779), 04848 (−42.505), 90308 (−22.925), 04775 (+13.470) y cuatro de 1.800 a 2.900 (80267, 90414, 80002, 90447).

**90308 (descuentos de marzo, −22.925):** la base de aportes de la final supera el tope SIPA prorrateado. BC lo prorratea por los días de alta del mes comercial (13: tope × 13 / 30 = 1.753.089,18) y Meta4 por 14 (`CANT_DIAS_TOPE` = 14 con `DIAS_ALTA` = 13: 1.887.942,21). Mismo +1 en 90315 (12 y 13), donde el tope no corta. En las finales de la corrida del 11/3 los dos valores coinciden: es una regla de Meta4 para las bajas liquidadas en la corrida mensual (concepto 551) que con dos casos no se pudo generalizar. Igualado con tres novedades de importe (6000, 6010, 6030: `NovedadesAportesFinal90308Marzo.sql`); falta recalcular la final. Si aparece otra final de este tipo con tope cortando, conviene mirar si el +1 se repite.

**90451 (descuentos de marzo, +93.779):** licencia por maternidad (AU3) desde el 12/3: la maternidad se paga aparte (4135) y Meta4 prorratea el tope SIPA por los días pagados (`CANT_DIAS_TOPE` = 11 = 30 − 19 de maternidad: base 1.483.383,17, jubilación 163.172,15, ley 19032 y obra social 44.501,50), según su fórmula 551 (los días pagados en otro concepto no cuentan para el tope). BC lo prorrateaba por los días de alta (30) y aportaba sobre 2.178.000 (+127.925). Vigencia nueva del 1/3 de 6000, 6010 y 6030 con `(DIAS_ALTA_30 − DIAS_MATERNIDAD_30)` en la rama mensual (`TopeAportesSinMaternidad6000.sql`). Accidente y ART, que Meta4 también excluye, no se tocaron (sin caso medido). Falta recalcular.

**02854 (descuentos de marzo, +255.357):** es SSI (aporte solidario 8563 cargado por novedad en la cohorte SSI: 02854, 04913, 04914, 04915). Su VACACIONES descontaba además el 8525 (cuota sindical vacaciones, 4 % = 314.792,19) porque el 8525 leía `IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)` y el SSI tiene afiliación con tasa cero, que cae a la tasa del convenio. Meta4 descuenta una sola cosa (TOT_CTA_SIND 314.792,19 en vacaciones y 2.838,37 en la regular). Con el 8525 sobrando, CUOTA_SINDICAL_RET subía y la retención bajaba 59.435 (el resto de la diferencia). Pasó a `IF(TIENE_SINDICATO > 0, ...)` como el 8522 (`Cuota8525SsiTasaCero.sql`). El 8523 (SAC) y el 4754 tienen el mismo patrón y no se tocaron (sin caso medido). Falta recalcular la VACACIONES de 02854. Nota aparte: la novedad del 8563 de 02854 (317.630,56) junta la de vacaciones (314.792,19) y la de la regular (2.838,37) en una sola liquidación; el total por empleado coincide.

**Verificado (20/10/2026, tras recalcular):** 90451 coincide en aportes (6000 163.172,15; 6010 y 6030 44.501,50) y queda −1.870 de impuesto; 02854 queda +375 (reparto de la novedad 8563 entre regular y vacaciones); 90308 resuelto. Diferencias de descuentos de marzo que siguen: 90184 (+174.680), 01477 (−130.016, GU), 04848 (−42.505, GU), 04775 (+13.470) y seis de menos de 3.000 (80267, 90414, 80002, 90447, 90451, 02854).

## Abril 2026: sueldo de franco (1063) y Ganancias de 04921 (22/10/2026)

- **04921, Ganancias del pilotaje (BC 438.913, Meta4 780.930):** el pilotaje deduce 140.000 de gastos declarados (tipos 2 y 23, 70.000 cada uno desde el 1/3, `Ded. Ganancias Empleado`) que se cargaron hoy a las 14:09-14:12 UTC, **después** del cierre (13:38) y de la regular (13:45) y antes del pilotaje (17:11). Meta4 no tiene gastos declarados para él en abril (ninguna columna de deducción en sus corridas). También cargadas hoy, sin recalcular: 00949, 01404, 02786, 03849, 03909, 03995, 04185, 04313, 04419, 04455, 90184, 90454, 02078, 04096, 04540, 04591, 04759, 04047, 03207, 01707. Falta decidir desde cuándo rigen en BC contra Meta4.
- **1063 con BC = Meta4 × 1,2 (18 de 23 diferencias):** el +20 % del valor de franco (`VALOR_FRANCO` oficiales, vigencia 1/4/2026) no está en la corrida mensual de Meta4 del 25/4 (116.025 / 122.850 / 136.500 / 156.975 por día = valores viejos) pero sí en las finales de 4/23 (141.780) y de mayo. Es el orden en que se cargó el precio en Meta4, no una fecha de vigencia; BC no puede reproducirlo con fechas (las finales son anteriores a la regular del 30/4). 
- **1063 por días:** Meta4 paga como franco los días de OR (órdenes) de 02452 (3 días: FR 28 + OR 29-30), 04933 (7: FR 24 + OR 25-30) y 03957 (7: FR 24-29 + OR 30); BC sólo paga el franco del estado FR.
- **02297 y 02804:** sin liquidación de abril en BC.

### Seguimiento (22/10/2026): estados de franco y 02297 / 02804

- **Estados de franco partidos (02452, 03957, 04419, 04933):** comparación día por día contra `M4T_HIST_ESTADOS_EMPL` (289 empleados, abril): sólo esos cuatro difieren en estados operativos, y es el FR cortado y el resto como OR sin proyecto (en BC; Meta4 lo mantiene FR). Corregido con `EstadosFranco4Empleados.sql` (FR al fin de Meta4, OR borradas). **No se pudo establecer quién las creó:** las borré antes de leer su `$systemCreatedBy` (error de proceso: guardar la fila antes de borrar). Creadas el 22/10 a las 12:03 y 12:27 UTC y el 21/10 a las 20:16 UTC; no fue la cola de trabajos, ni los scripts de la sesión, y `Change Log` no registra la tabla 60000. Las únicas rutas de código que insertan un OR sin proyecto son `SetEstadoEntidad` (acción "Estado en lote" / "Asignar estado masivo") y el avance de empleados cuando cambia el estado de un buque productivo a improductivo (`AvanzarEmpleadosAEstadoSiguiente`, FR → OR por "Estado Siguiente"); no hubo estados de buque nuevos hoy. Otras dos filas OR (04020, 04185) se crearon el 20/10 a las 03:12 UTC con el usuario del equipo y sí coinciden con Meta4. Para rastrearlo la próxima vez: activar el registro de cambios (`Change Log Setup`) sobre la tabla 60000.
- **02297 y 02804 sin liquidación de abril:** sus estados AU9, FR, OR y AU1 estaban en el proyecto de marea PP-119-000307 y no en PN-119-NOMINA, así que la regular no los veía (son los únicos tres empleados con FR/OR/OI/AU* en un PP-; el tercero, 04220, en junio). `EstadosTierraA19ANomina.sql`. Falta crear y calcular su REGULAR de abril (llevan además la novedad 5310 del 20/4).

### 2003 de oficiales 175/75 y 768/19 sin neto garantizado (22/10/2026)

Cierre de A28/62: 01477, 02452, 03664 y 04455 daban menos que Meta4 (−53 mil, −1,71 M, −883 mil, −336 mil). La planilla `A28 62 CLC producción.xlsx` trae el cálculo (filas 29-39: "a pagar", "mens 03", "dif total", "a cta") y su "a cta" es el 2003 de Meta4. Para 03664: asegurado 15.000 USD × TC 1.365 / 30 × **24 días** = 16.380.000 + parte de producción 2.064.235 = 18.444.235; menos lo pagado en marzo 677.500 = 17.766.735 (= `A_CTA_MAREA` + `TOT_HAB_GZDO` de Meta4). BC usaba **23 días y TC 1.350**: el proyecto PP-128-000062 tenía Ending Date 22/4 (la CLC dice llegada 23/4, y las asignaciones tienen baja 23/4). Con el fin en 22/4 la ventana del tripulante da 23 días de enrolamiento mientras `A_CUENTA_MAREA` ya descuenta el día de marzo (se paga un día de menos), y la Fecha de Liquidación y el TC son los del 22/4 (1.350). `Job128_62FinDeMarea.sql` (fin 23/4). Falta recalcular el cierre de las 30 liquidaciones de la marea y ver el resultado; quedan aparte los netos garantizados (04163, 04836, 04826, 04868).

**Corrección del apartado anterior (22/10/2026):** mover el fin de PP-128-000062 al 23/4 **empeoró a la tripulación**: pasó de 21 días de navegación y 2 de puerto (lo que paga Meta4) a 22 y 1, y 23 de los 30 perdieron unos 9.300 de bruto (los oficiales sí mejoraron: 03664 quedó a 2 pesos). El 22/4 es la llegada real (PL el 22 y el 23) y el 23/4 de la CLC es el último día de puerto. Se revirtió (`Job128_62FinDeMarea_Revertir.sql`) y se resuelve en el código (Cod50016, sin publicar): `DIAS_ENROLAMIENTO` de un cierre llega hasta el último día que cubre la liquidación (sin pasar de la baja de la asignación) y `FechaTipoCambio` de un cierre cotiza al último día que cubre si es posterior al fin del proyecto. **Lección:** "Ending Date" del proyecto no es el último día de la marea para todos los conceptos; no se mueve para arreglar un solo concepto sin medir a toda la tripulación (se guardó la comparación de antes para poder hacerlo).

**Resultado del cierre de A28/62 con 1.0.0.683 (22/10/2026):** la tripulación volvió a 1-2 pesos de Meta4 (sin regresión) y 01477 quedó exacto en el 2003 (4.439.577). 03664 y 04455 quedaron a −4.840 y −4.568 en el 2003, que es su diferencia de 1023 (feriado): Meta4 divide por **DIAS_MAREA 23** (21 de navegación + 2 de puerto) y BC por 22, porque el segundo día de puerto (PL 23/4) se restaba como "puerto personal fuera de la asignación" al estar la ventana del tripulante topada en el fin del proyecto (22/4). 1.0.0.684: `VentanaCierreHastaCobertura` (Cod50016) la usan `DIAS_ENROLAMIENTO` y los días de puerto del viaje (`DIAS_MAREA`), sólo en cierres; navegación y el puerto del 1083 siguen con el fin del proyecto. **02452**: Meta4 pagó el 2003 según la CLC con 6.900 USD (celda G14 de A28/62) aunque su `NTO_GARANTIZADO` diga 5.400: vigencia nueva `VALOR_NAV_EMP_02452` 6.900 desde el 1/4 (`ValorNavEmp02452Abril.sql`; marzo sigue en 5.400). Falta recalcular el cierre de los 30 y ver 03664, 04455 y 02452.

**Verificado con 1.0.0.684 (22/10/2026):** 2003 exacto en 01477, 02452, 03664, 04455 (y 04791, 04924), marinería de A28/62 a 1-2 pesos. Totales de abril: bruto fuera de 1 peso 104, descuentos 54. 04921: su cierre, recalculado después de cargar los gastos declarados, ahora también difiere del 2003 (−358.141, igual que el pilotaje): confirma que la diferencia de 04921 es esa deducción. Quedan del 2003: netos garantizados 04163 (−74.113), 04836 (−74.114), 04826 (+64.552) y 04868 (−1.902.408). Diferencias residuales de 02452: franco +20 % (1063 +73.710), 1083 −7.173 y 2013 −82.196; de 04455: 2803/2804 (−331.200 / −27.600) y 5010.

### Recibo de francos, +20 % por novedad y neto garantizado del 2003 (22/10/2026)

- **Recibo (Rep50041, layout V2; sin publicar, 1.0.0.685):** el recibo agrupaba las filas por concepto (`GrpConceptosV2` por `LinCodConcepto`), así que las tajadas de franco (una `Línea Liquidación` por lote FIFO) se juntaban en UNA fila que mostraba el importe de la primera. Ahora cada tajada es una fila (`LinClaveFila` = `|` + No. Línea cuando hay `No. Lote Franco`) y lleva en el nombre el detalle del lote (`LinFrancoDetalle`): puesto (descripción y código), buque, marea y fecha de devengamiento, leídos del `Movimiento Franco Liq.` del lote (tipo Devengo o, si no hay, Inicio) y del proyecto con sus dimensiones. Un saldo inicial muestra sólo el puesto y la fecha. Falta imprimir un recibo (01477, 02452) para ver el alto de fila con el texto largo.
- **+20 % del franco por novedad (`FactorFrancoNovedadAbril.sql`):** las novedades no pueden llevar plata en un concepto de consumo (su importe entra como DÍAS a consumir), así que se usa el "Factor Importe Consumo" del 1063 (opera sobre los pesos después del FIFO): vigencia nueva del 1/4 con `IFZERO(FACTOR_FRANCO_NOV, 1)`, concepto informativo `FACTOR_FRANCO`, fuente de datos `FACTOR_FRANCO_NOV` (copia de `IND_GUARDIA_2041`) y 18 novedades de Cantidad 1/1,2: 00406 00619 00794 01073 01477 02452 03039 03196 04313 04320 04582 04649 (final) 04710 04724 04791 04826 04868 04924. Son 18, no sólo 02452 y 01477. Para quitarlo: anular las novedades.
- **Neto garantizado, 2003 (cierre de abril):** 04163 y 04836 (−74.113 / −74.114): BC prorratea el tope SIPA del cierre por los 27 días de su baja (aportes al 90 %: 412.128 en lugar de 457.920) porque la final ya existe; la corrida de Meta4 del 13/4 se hizo antes de la baja y lleva el tope entero. El neto coincide (a 6 pesos) y el bruto difiere en lo que cambian los aportes y la cuota sindical. 04826 (+64.552): es su 1603 de cierre (110.070 contra 169.470 de Meta4: el reparto de francos entre cierre y regular) y su 1023 (93.078 contra 98.243). 04868 (−1.902.408): bruto y neto convergen igual, pero la Ganancias del cierre es 692 mil menor que Meta4 (7,39 M contra 8,09 M) con la misma base de años anteriores (108.595.122 contra 108.595.172) y la misma deducción de cónyuge; no se encontró qué suma Meta4 a la base (su `BASE_IMPUESTO` es 126.028.612). Además, las finales de 04163 y 04836 difieren por días de franco en la indemnización (2803: 40 contra 41 y 62 contra 64 días) y por la Ganancias final (5010: −998 mil contra +3,4 M, −2,8 M contra +2,7 M).

**Corrección (22/10/2026): no hubo cambio de precio del franco.** Indicación del usuario. `FrancoSinCambioDePrecioAbril.sql` deshace el factor por novedad (novedades, fuente `FACTOR_FRANCO_NOV`, concepto `FACTOR_FRANCO`, vigencia del 1/4 del 1063) y las seis filas de +20 % de `VALOR_FRANCO` del 1/4 (la decisión del 21/10 quedó sin efecto; quedan las del 1/1: 3.000 / 2.550 / 3.450 / 2.700 USD, las de la lista de precios de Meta4). La corrida mensual de Meta4 del 25/4 y su cierre del 13/4 pagaron a todos los oficiales el valor viejo, valuando por CATEGORÍA y no por puesto (04826, puesto MQ01/OF02 y categoría OF04: 116.025 = OF04). El único lugar donde Meta4 usó 1,2 × fue en las finales del 23/4 de 04163 y 04836 (141.780) y 04455 (165.600), mientras 02450 —mismo puesto MQ01 y categoría OF02 que 04455— salió normal (139.000); las tres bajas son del 28-29/4, motivo BAJ-1, igual que 04649 (finales de 10/4, normal). En BC los lotes de franco de los 18 oficiales están valuados con su categoría (sólo 04826 tiene puesto OF02 con categoría OF04, 57 lotes, y Meta4 también paga por OF04): no se encontró un error de puesto del lado de BC. Si el 1,2 de esas tres finales de Meta4 es un puesto mal cargado en Meta4, BC es el correcto.

### Re-análisis del bruto de abril (22/10/2026): 101 empleados fuera de 1 peso, 60 de ellos por 1-3 pesos de redondeo (el 5498 de Meta4, que BC no genera)

Quedan 41 con diferencia real, por causa principal: (1) **2803/2804, indemnización de francos de las finales: 17 empleados, ~10 M**: 8 finales posteriores al pilotaje con 1 día menos que Meta4 (04518 04591 04714 04822 04825 04906 04923 04932) más 04455, 04163 y 04836 (1-2 días; precio 1,2 de Meta4 aparte), porque Meta4 devenga 1 día de franco en la corrida de pilotaje y BC no (1062 no aplicaba a PILOTAJE: `DevengoFrancosEnPilotaje.sql`); 04139 y 04889 (+3,3 M, saldo de 49 y 54 días contra 16 y 33 de Meta4); y 03104 03791 04046 04802, con 2 días más y 1023 de más (feriados 2 y 3/4 dentro del tramo de francos). (2) **1023 feriado**: 9 empleados (1,1 M; 4 de ellos los de los feriados de abril). (3) **2003 neto garantizado**: 04868 (−1,9 M), 04921 (gastos declarados), 04163/04836 (tope SIPA). (4) **1003 sueldo**: 90016, 90212, 90302 (básico personal). (5) **4110 enfermedad**: 02670, 04216.

- **Saldo de francos arrastrado entre fases (22/10/2026):** corregido en código (`InicioDeFase` en `Cod110059`), compilado, sin publicar. 04139 y 04889 deberían pasar a 16 y 40 días de 2803 al recalcular. Verificar también 04351, 04726, 04751 y 04775.

- **Feriados de guardia de las finales de abril (22/10/2026):** 03104, 03791, 04046 y 04802: Meta4 omitió el feriado del 2 y 3/4 (DIAS_FERIADO = 0) y devengó sólo 50 % de los días de puerto. Se replicó con novedades LIQ_FINAL: 1023 en cero y 1062 por 5/5/4/5 días (`scripts/NovedadesFinalesAbrilFeriadoOmitidoMeta4.sql`; mismo criterio que enero, novedades 9741-9743). Falta recalcular las cuatro finales y verificar. Diferencias de 1023 que quedan sin explicar: 00406, 00794, 04347, 04542, 04710, 04826.

- **1023 de la regular con francos u órdenes en el mes (22/10/2026):** los 16 REGULAR de abril sin días de franco/órdenes coinciden con Meta4; los 7 con ellos (00406, 00794, 04001, 04347, 04542, 04672, 04710) difieren porque Meta4 resta de la base del precio del feriado `#1053 × (franco + órdenes) / días de la antigüedad`. Se extendió la resta que ya existía para LIQ_FINAL a REGULAR (`scripts/Concepto1023BaseSinAntiguedadDeFrancosRegular.sql`, vigencia del 1/4). Falta recalcular y verificar; vigilar que enero a marzo, ya conciliados, no se muevan (en febrero Meta4 no restó).
  **Verificado (22/10/2026):** tras recalcular los 7, el 1023 de los 22 REGULAR de abril con feriado coincide con Meta4 (0 fuera de 2 pesos).

- **1603 y 1023 del cierre de 04826 (22/10/2026):** la base del 1603 de Meta4 incluye el 1533 (adicional art. 23, 336.600) y la de BC no: −59.400 (= 336.600 × 15/85) en el 1603, que baja el precio del feriado (1023 −5.165). Es el único con 1533 y 1603 en abril. Se agregó `#1533` a las dos bases del 1603 de la vigencia del 1/4 (`scripts/Concepto1603Suma1533.sql`). Falta recalcular el cierre y verificar; marzo de 04826 (otra vigencia del 1603) puede tener lo mismo.

- **Euro de abril (22/10/2026):** 90302 y 90212 liquidaban abril con el EUR de marzo (1.640); Meta4 usó 1.690 (neto de 90302 = 3.380.000 = 2.000 × 1.690). Se cargó el EUR del 1/4 (1.690) y del 1/5 (1.640, para no arrastrar) con `scripts/CotizacionEURAbril2026.sql`. Falta recalcular la regular de 90212 y 90302 y verificar. 90212 además difiere en el 4743 (descuento de vacaciones: −9.270.697 contra −7.362.818) y 90016 (USD) tiene un neto de Meta4 que no es redondo: sin investigar.

- **4743 en grossing-up (23/10/2026):** 90212 con vacaciones en abril: Meta4 descuenta −(1003 + 2703)/30 × 30 = −9.270.697 y BC sólo el complemento (−7.664.831): la rama de grossing-up dejaba afuera el adicional por zona desfavorable. Vigencia nueva del 1/4 con `COMPLEMENTO_GU + #1053 + #4573 + #2703 + #2103` (`scripts/Concepto4743GrossingUpConAdicionales.sql`). Falta recalcular 90212 y verificar el bruto (Meta4 12.978.976). El neto de Meta4 (10.584.049) no es el objetivo redondo (6.000 × 1.690 = 10.140.000): no explicado.
  **Verificado 23/10/2026:** el 4743 de 90212 ya descuenta 1003 + 2703 como Meta4 (−10.511.759 = 8.759.799 + 1.751.960). El bruto sigue −715.257 (12.263.719 contra 12.978.976) porque el neto objetivo de BC es 10.140.000 y el de Meta4 10.584.049: +444.049 (4,38 %), que con ~38 % de carga explica el faltante. Es la prima de vacaciones del acuerdo neto (`PRIMA_VAC_GU`, sin cargar por indicación del usuario hasta confirmar contrato y fecha).

- **90212, vacaciones en la regular (23/10/2026):** Meta4 no calcula el grossing-up (lo hace el usuario a mano) y paga las vacaciones de los administrativos dentro del recibo regular: sueldo base 7.725.581 + 3553 (35 días × (1003 + 2703)/25) − 4743 (−(1003 + 2703)) + 2703. Tras el 4743 y el neto objetivo cargado (10.584.000), BC daba el bruto a 90 pesos (12.978.887 contra 12.978.976) pero con las líneas corridas (1003 9.270.633, 2703 1.854.127): el 3553 en grossing-up pagaba sólo COMPLEMENTO_GU. Vigencia nueva del 3553 desde el 1/4 con `COMPLEMENTO_GU + #1053 + #4573 + #2703 + #2103` (`scripts/Concepto3553GrossingUpConAdicionales.sql`). Falta recalcular 90212: esperado 1003 ≈ 7.725.581.
- **Cotizaciones del BNA (23/10/2026):** `scripts/ImportarCotizacionesBNA.ps1` baja el CSV de billetes del BNA (GET sin sesión, ids 12 = EUR y 22 = USD) y hace upsert en `Currency Exchange Rate` (Compra al comprador, Venta al vendedor). Previsualiza por defecto; `-Aplicar` escribe y después hay que reiniciar el servicio. Verificado: 116 filas del USD de abril a octubre coinciden con el BNA. El gap compra/venta del EUR no es fijo (100 y 110).

- **COEF_FRANCOS_175/75 (23/10/2026):** Meta4 devenga los francos de todos los oficiales (OF01-OF04) al 52 % en 2025 y 2026 (marinería 50 %); BC tenía 175/75 en 0,50 (768/19 ya estaba en 0,52). Explicaba el día de menos de 04455 en el 2803 (cierre de marzo: 0,52 × 30 + 1 = 16,6 → 17 contra 16) y los días de 04163 y 04836. Se corrigió el valor de la vigencia del 1/1/2026 a 0,52. Falta recalcular en orden los devengos de enero a abril de los oficiales 175/75 (cierres, devengados, regulares, pilotaje) y después las finales.

- **Marzo no recalculaba (23/10/2026):** el 2073 (vigencia desde el 1/3) lee #DIAS_PILOT_PAGO, que sólo existía desde el 1/4: todas las liquidaciones de marzo con 2073 cortaban y quedaban en Borrador al recalcular enero a abril de los oficiales 175/75. Se agregó la vigencia 1/3-31/3 de DIAS_PILOT_PAGO (`scripts/ConceptoDiasPilotPagoMarzo.sql`). Falta recalcular marzo y abril de esos oficiales y verificar.

- **Deducciones de Ganancias desde marzo (23/10/2026):** por indicación del usuario las filas de `Ded. Ganancias Empleado` rigen desde el 1/3 (antes tenían vigencia 1/1 y 1/2, cargadas el 22/10): se borraron 80 filas de enero y febrero y 3 (la última de un tipo sin fila de marzo en adelante) se pasaron al 1/3 (`scripts/DeduccionesGananciasDesdeMarzo.sql`; backup de las filas fuera del repo). Falta recalcular enero a abril de los empleados con deducciones (28).
