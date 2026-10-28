---
aliases: ["Art. 19: calamar y cuenta corriente"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Art. 19: calamar y cuenta corriente

la veda de un potero es art. 19 y no art. 48; paga básico/30 por los días embarcados del año, con cuenta corriente que se reinicia el 1/1

**La veda de un potero no es el artículo 48: es el artículo 19** ("Pesca de calamar") del CCT
729/2015 — concepto **1075**. El anteúltimo párrafo del artículo mete las paradas biológicas y
los períodos de veda dentro de ese artículo. La CCT no sirve para separarlos (tangoneros y
poteros son los dos 729/15), así que el ruteo va por pesquería: `DIAS_ART48 = IF(TIPOACTIVIDAD
= 1, 0, MIN(DIAS_ORD_PERIODO, DIAS_VEDA_BUQUE))`.

**La aritmética:** `ART_19_SOMU = DIAS_ART_19 × básico / 30`, sin coeficiente de pesquería —
en poteros el 100% es remunerativo. Exacto en los 14 casos de Meta4 que tienen los dos datos,
de 2015 a 2026.

**Los días** son los que estuvo embarcado, y el artículo dice expresamente que los de puerto y
los de **accidente laboral** cuentan (`NV|PS|PL|PI|GP|ACC`). La enfermedad inculpable `AU1`
no: el artículo nombra el accidente, y son dos estados distintos. No son acumulables por año,
así que la cuenta corriente se reinicia el 1 de enero.

**Para el reinicio no hizo falta ni CalcDate ni variable nueva:** la función de agregado
**`DURACION_AÑO`** ya recorta los intervalos al año calendario de la fecha de referencia —
estaba desde antes, la usa `VAC_TOMADAS_AÑO`. Lo que sí hizo falta fue el token
**`{AÑO_DESDE}`**, porque una suma sobre Línea Liquidación necesita el filtro de fecha
explícito: `DIAS_ART19_PAGADOS` suma la **Cantidad** (no el importe) de las líneas de 1075
desde el 1 de enero.

**Consecuencia a verificar:** con el reinicio al 1/1, en enero el saldo arranca en cero —
los días embarcados de la temporada anterior quedaron en el año que cerró. Los días de órdenes
de enero de un potero no los paga el art. 19; según el usuario el resto va a `OI` (órdenes
impagas), que es un estado que hoy se carga a mano.

Ver [[veda-como-atributo-del-buque]] y [[sueldo-ordenes-por-convenio]].

**El art. 19 y el sueldo a las órdenes son excluyentes.** En los 14 casos de `ART_19_SOMU`,
`SUELDO_ORDENES` y `ART48_PAR11` están los dos en cero: el art. 19 *es* el pago de órdenes del
potero después de la temporada, no algo que se suma encima. Pero los días de órdenes siguen
existiendo — el 04286 en octubre de 2025 tenía `DIAS_ORDENES` = 31 y cobró 31 días por art. 19.

Por eso **cada artículo de veda tiene su auxiliar de días y 1073 resta los dos**:
`DIAS_ART48` (orden 62, no calamar) y `DIAS_ART19` (orden 63, `TIPOACTIVIDAD = 1`), y
`1073 = MAX(0, DIAS_ORD_PERIODO - #DIAS_ART48 - #DIAS_ART19)`. El auxiliar que no aplica al
empleado se lee como cero. Los auxiliares van **antes** de sus consumidores (1073 en 65, 1075
en 70, 1076 en 75) — mover el productor hacia atrás, no el consumidor hacia adelante, como en
[[concepto-negativo-despues-de-sus-consumidores]].

Sin eso el potero cobraba 1075 por sus días de órdenes **y además** 1073 por los mismos días.
Los dos importes son razonables por separado y la suma no dispara ningún control: sólo se ve
comparando contra el recibo.

**Diferencia deliberada con Meta4:** ahí `DIAS_ART_19` a veces supera los días del mes (33, 40,
66) porque pagan el saldo en cuotas cuando alguien lo decide. La fórmula de BC paga `MIN(días
de órdenes del mes, saldo)`, que es la regla tal como está enunciada; los pagos retroactivos en
bloque habría que cargarlos aparte.

## Relacionado

- [[veda-como-atributo-del-buque]]
- [[sueldo-ordenes-por-convenio]]
- [[concepto-negativo-despues-de-sus-consumidores]]
- [[basico-de-tierra-por-empleado]]
- [[cct-175-75-remuneracion-navegacion]]
- [[cct-729-15-articulos]]
