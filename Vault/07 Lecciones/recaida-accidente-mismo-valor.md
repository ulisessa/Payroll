---
aliases: ["Recaída de accidente: mismo valor"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Recaída de accidente: mismo valor

**En una frase:** En accidente todas las recaídas se pagan al mismo valor, pero no hay forma de distinguir una recaída de un siniestro nuevo; anclar en el primer ACC rompería los casos que hoy dan exacto

Regla de negocio confirmada el 28/9/2026: **en accidente se paga el mismo valor en todas las
recaídas**. En enfermedad es al revés — cada episodio se promedia por sí mismo, y los casos que
Meta4 paga igual son excepciones que RRHH decide a mano, ver [[ventana-promedio-ausentismo]].

`FechaInicioAusencia()` (Cod50016) trata AU1 y ACC con la misma regla: ancla en el primer estado con
`Promedia Ausencia` que llega al período. Para cumplir la regla del accidente habría que anclar en el
**primer episodio de la serie**, no en el que toca el período.

**El bloqueo no es técnico, es de datos: no existe identificador de siniestro.** Los dos empleados con
ACC vigente en enero de 2026 tienen episodios separados por años, que son accidentes distintos y no
recaídas:

```
02854   6 episodios   2002-02-23 → 2025-10-13   (23 años)
04047   2 episodios   2022-09-29 → 2025-10-13   ( 3 años)
```

Anclar en el primer ACC de la historia los mandaría a 2002 y 2022, donde no hay historia migrada, y
rompería los dos: hoy sus ILT dan **exacto** contra los recibos de Meta4 (ver
[[accidente-empleador-y-art]]).

**Por qué:** la regla es correcta y aun así implementarla literal empeora el resultado. Además no hay
ningún caso en enero que la ejercite, así que un cambio no se podría verificar contra nada.

**Cómo aplicarlo:** hace falta primero un criterio de encadenamiento — lo razonable es el mismo que usa
RRHH para enfermedad, "intervalo muy breve", o sea encadenar sólo los ACC separados por menos de N
días. Definir ese N con RRHH antes de tocar `FechaInicioAusencia()`, y esperar a tener un caso real
de recaída para validar.

## Relacionado

- [[recibo-vacaciones-paga-solo-vacaciones]]
- [[vacaciones-tierra-duplica-el-mes]]
- [[vacaciones-tripulantes-promedio]]
- [[ventana-promedio-ausentismo]]
- Tema: `vacaciones-sac-licencias` (ver [[_Convenciones del vault]])
