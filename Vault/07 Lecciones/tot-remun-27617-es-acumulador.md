---
aliases: ["TOT_REMUN_27617 es acumulador"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-19
---

# TOT_REMUN_27617 es acumulador

**En una frase:** En M4T_ACUMULADO_RL el importe del mes es el MÁXIMO de TOT_REMUN_27617, no la suma; sumar las filas duplica

`TOT_REMUN_27617` en `ARBPRO.M4T_ACUMULADO_RL` es un **acumulador corrido dentro del mes**, no el importe de cada corrida. Se reinicia cada mes. La remuneración del mes es `MAX(TOT_REMUN_27617)` por empleado-mes, nunca `SUM(...)`.

El orden de las corridas lo da `CONTADOR_LIQ`, **no `FEC_IMPUTACION`**: en enero 2026 el legajo 03774 tiene la fila TP_IMPUT 10 del día 19 con contador 6 y la TP_IMPUT 15 del día 6 con contador 7. Ordenado por contador el acumulador sí es monótono, así que tomar el máximo equivale a tomar la última corrida.

**Cómo se verifica:** el importe que devengó cada corrida está en `TOT_DEVENGO` / `TOT_HAB_CON_AP`, que sí son por corrida. Para 03774 en enero 2026: 165.551,68 + 9.918.318,23 + 100.296,32 = 10.184.166, que es el `TOT_REMUN_27617` de la última corrida (10.184.165,26). Y febrero (9.959.703) es **menor** que enero, lo que descarta que el acumulador sea del año — a diferencia de `BASE_IMPUESTO`, que sí es YTD.

**Por qué importa:** un recibo individual reproduce **una** corrida (los cinco recibos verificados de enero 2026 son la fila TP_IMPUT 10), pero el total del mes es el acumulador final. Son preguntas distintas y se responden con filas distintas de la misma tabla.

**Qué es cada TP_IMPUT** (perfilado por qué columnas trae en no-cero): 4 = anticipos (sólo LIQUIDO, sin aportes); 99 = indemnizaciones puras (DIAS_ALTA≈0, sin aportes); 14 = liquidaciones finales (376 de 998 con VAC_NO_GOZADAS); 3 = vacaciones; 1 = la corrida más frecuente, única fila en 1.790 empleado-mes de 2025. **`TP_IMPUT = 1` no es descartable**: descartarla dejó 2.531 empleado-mes en vez de 4.598.

## La base de promediación es TOT_PROMEDIOS, y se SUMA

`TOT_REMUN_27617` es la base de APORTES: incluye el SAC y las indemnizaciones. **No sirve para promediar.** La base de promediación —el `BASE_PROMEDIO` de BC— es **`TOT_PROMEDIOS`**, y al revés que el anterior **es por corrida, así que se SUMA por empleado-mes, no se toma el máximo**. Dos columnas parecidas con reglas de agregación opuestas.

`BASE_PROMEDIO` incluye los complementos no remunerativos (producción calamar, langostino, merluza, incrementos SOMU y STIA) y los descuentos (reducciones pactadas, enfermedad, accidente, huelga), y excluye lo extraordinario: el propio SAC, las indemnizaciones, la gratificación por jubilación. Tiene 126 conceptos contra 149 de `REMUNERATIVO_BRUTO`, y decenas alimentan uno y no el otro.

**Cómo se verificó:** `SUM(TOT_PROMEDIOS)` por empleado-mes, promediado a seis meses, reproduce el `PROM_6_ULT_MES` de Meta4 **exacto en 1.014 de 1.135 casos**, razón mediana 1,0000. Con `TOT_REMUN_27617` la razón daba 1,0719. Esa brecha del 7% que parecía un ajuste que faltaba era simplemente la columna equivocada.

`PROM_6_ULT_MES` **divide por la cantidad de meses disponibles, no por seis** — corrobora el diseño de `MESES_PROM_VAC` en [[system-variables-conventions]]. Sólo está poblado para los convenios MR y OF, o sea los tripulantes: es el promedio de vacaciones del Art. 34. Aparece copiado en filas posteriores (hasta en anticipos), así que el valor guardado puede referirse a un ancla anterior — de ahí los ~85 casos que no cierran.

## Relacionado

- [[retenido-true-importe-cero]]
- [[sindical-sac-base-equivocada]]
- [[tope-sac-por-liquidacion]]
- Tema: `descuentos-ganancias-sipa` (ver [[_Convenciones del vault]])
