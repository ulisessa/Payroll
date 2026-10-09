---
aliases: ["Ventana del promedio de ausentismo"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Ventana del promedio de ausentismo

**En una frase:** Criterio del promedio de ausentismo confirmado por RRHH: la recaída no continúa la licencia (salvo ART) y sin 12 meses se promedia la fracción activa; BC ya lo cumple y quien se aparta es Meta4

`PROM_AUS_12` suma `BASE_PROMEDIO` en los 12 meses previos al arranque de la ausencia, lo divide por
`MESES_PROM_AUS_12` —meses con **fase de alta**, no con remuneración— y el ancla la da
`FechaInicioAusencia()` (Cod50016): el primer estado con **`Promedia Ausencia`**, que son sólo **AU1**
y **ACC**, cuya fecha fin alcanza el período.

**Criterio confirmado por RRHH el 28/9/2026:**

1. Una recaída **no** continúa la licencia anterior a efectos del promedio — *"a priori no, excepto
   ART que tomamos el mismo valor"*.
2. Sin 12 meses completos *"se promedia la fracción de tiempo que está activo, excepto que el ingreso
   haya sido en la misma marea en que se accidenta"*.

**BC cumple las dos.** Verificado sobre enero de 2026: los 5 casos cuya ventana difiere de Meta4
(01607, 01767, 01961, 02449, 02924) tienen **dos episodios AU1 separados** por días o meses, y BC
ancla en el segundo —el que se está liquidando—, que es lo correcto si la recaída no continúa. Meta4
ancla en el primero. Y de los 3 que Meta4 resuelve con un solo mes, 02737 y 03986 tienen 12 meses de
fase continua y BC promedia 12, mientras el 04185 tiene fases fragmentadas y BC promedia sobre **8**,
que es exactamente "la fracción de tiempo que está activo".

**Por qué:** durante la reconciliación es natural suponer que Meta4 tiene razón y que una diferencia es un
defecto de BC. Acá es al revés en las 8 diferencias, y sólo se puede afirmar después de tener el
criterio por escrito.

**Cómo aplicarlo:** no "arreglar" estas diferencias contra Meta4. Queda un riesgo latente, no un
defecto: `FechaInicioAusencia()` trata AU1 y ACC igual, pero para ART la recaída **sí** toma el mismo
valor, así que si aparece un accidente con dos episodios habría que anclar en el primero. Hoy no
muerde — los ILT del 02854 y el 04047 dan exacto, ver [[accidente-empleador-y-art]]. Relacionado:
[[enfermedad-sin-convenio-paga-cero]], [[historia-remuneraciones-migrada]].

## Relacionado

- [[recaida-accidente-mismo-valor]]
- [[recibo-vacaciones-paga-solo-vacaciones]]
- [[vacaciones-tierra-duplica-el-mes]]
- [[vacaciones-tripulantes-promedio]]
- Tema: `vacaciones-sac-licencias` (ver [[_Convenciones del vault]])
