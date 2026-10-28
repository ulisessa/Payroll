---
aliases: ["Antigüedad: el día por fase"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-01
---

# Antigüedad: el día por fase

la fase contaba fin−inicio y se comía un día por tramo; y por qué no hay que copiar el /365 de Meta4

**Los días de una fase cuentan AMBOS EXTREMOS.** Del 13/11/2013 al 10/3/2014 son 118 días, no 117.
Hasta el 1/10/2026 `Fase Alta Empleado` hacía `fin − inicio` en los dos lugares que los calculaban
—el campo `Días` (`Recalcular`) y `CalcDiasHasta`—, así que perdía **un día por fase**. Con un
historial fragmentado se acumula: a 04066, con 18 fases, le faltaban 18 días.

También se cambió `>` por `>=`: una fase de un solo día —alta y baja la misma fecha— contaba cero.

Y en `Cod50017.CalcAntiguedadFraccionAlFecha` la fracción se **truncaba a 0,1 hacia abajo**
(`Round(x, 0.1, '<')`), que descarta hasta 36 días. Como el consumidor (`AÑOS_ANTIGUEDAD`) le aplica
`PISO` para buscar el tramo, sólo podía restar. Ahora redondea a 0,0001.

**Meta4 divide por 365 y no hay que copiarlo.** Para 04066 al 31/1/2026, con el conteo inclusive:

| criterio | años |
|---|---|
| aniversarios de calendario (BC) | **4,9918** |
| días / 365,25 | 4,9911 |
| días / 365 (Meta4) | 4,9945 |

El /365 **sobreestima**: ignora los bisiestos. El método de aniversarios de BC no aproxima nada
—suma días calendario y compara fechas, y el ciclo mide 366 cuando corresponde— y es el más preciso
de los tres. El `365,25` del código se usa SÓLO para convertir `Antigüedad Reconocida` (que viene en
años y no tiene fechas detrás), y ahí es correcto; hoy no mueve nada porque **ninguno** de los 4.810
empleados la tiene cargada.

**`PISO` se mantiene, y Meta4 también trunca**: de las 451 corridas de enero, el `PORC_ANTIG`
coincide con la escala en **436 truncando** contra **347 redondeando**. Las 15 que no coinciden son
**ajustes a mano**, y se ven porque el mismo `ANIOS_ANTIG` da porcentajes distintos entre corridas
del mismo mes: 04066 tiene 4,9945 con 10% en la de ajuste y 12% en la mensual; 04710 tiene 3,0027 con
4% en la mensual y 8% en la de vacaciones. **No se derivan de ninguna fórmula**: 04066, 04669 y 04710
quedaron cargados como novedad de 1053 el 1/10/2026 con el importe de Meta4, una por liquidación,
apuntadas con proyecto + tipo de liq. (el mapeo sale de la marea: la corrida ti=10 es de la 59 y la
ti=1 de la 60). Ver [[novedad-en-cero-no-apagaba-el-concepto]] para los tres modos de carga.

**Dónde mirar la antigüedad de Meta4**: columna 1246 `ANIOS_ANTIG` de `M4T_ACUMULADO_RL3`, en años
con 4 decimales, una por corrida. **No hay campo de días**: `DIAS_ANT_ALTA` (col 862) existe pero
viene vacío. Y `ANIOS_ANTIG` **no se mide a la fecha de la corrida**: el cierre de marea del 19/1 de
04066 tiene 5,01 y la mensual del 25/1 tiene 4,9945, al revés de la fecha.

**Impacto medido al 31/1/2026**: de 4.777 empleados con fase, **14 cambian de escalón y los 14
suben** — todos a días de un aniversario, varios cayendo exactamente en 2,0000 / 3,0000 / 6,0000, que
es lo que respalda el criterio. **Ninguno de los 10 que difieren en antigüedad en enero cambia de
escalón**, ni 04066. El único de los 14 con liquidación de enero es 04710, y es un acierto: cumple 3
años el 31/1, BC daría 8% y Meta4 **se contradice solo** —4% en la mensual y 8% en la de vacaciones,
con los mismos 3,0027 años—.

**22 fases migradas tienen `Días` propio**, de 3 a 62 días MENOR que el intervalo (03338 a 03341 con
−62, mismo lote). Meta4 registró ahí días efectivamente trabajados. El recálculo del campo las
excluye, pero **`CalcDiasHasta` no lee el campo**: recorre las fechas, así que la antigüedad de esos
22 ya usa el intervalo completo e ignora el dato migrado. Pendiente de decidir.

Las escalas `PCT_ANTIG_SOMU` y `PCT_ANTIG_OFICIALES` son **idénticas** (25/18/14/12/10/8/4/2 a los
10/7/6/5/4/3/2/1 años). Ver [[antiguedad-suma-de-fases]], [[antiguedad-formula-explicita]] y
[[antiguedad-no-cuenta-dias-gp]].

## Relacionado

- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[antiguedad-suma-de-fases]]
- [[antiguedad-formula-explicita]]
- [[antiguedad-no-cuenta-dias-gp]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
