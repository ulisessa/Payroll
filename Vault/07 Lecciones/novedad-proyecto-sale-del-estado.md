---
aliases: ["El proyecto de la novedad sale del estado"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-04
---

# El proyecto de la novedad sale del estado

**En una frase:** Con el proyecto en blanco, la novedad la ubica el historial de estados a su fecha, no el orden de cálculo

`NovedadAplica` (Cod50061) resuelve el proyecto así, desde el 18/9/2026:

1. Si la novedad **nombra** un proyecto, manda ése. Es la excepción explícita.
2. Si está en blanco, se busca el **estado del empleado a la fecha de la novedad** y se usa SU
   proyecto. Navegando → el estado nombra la marea y la novedad es del cierre de marea; en
   francos u órdenes → nombra el proyecto de nómina y es del mensual.
3. Si la fecha no cae en ningún estado, o el estado no tiene proyecto, **no se filtra**: se
   vuelve al comportamiento anterior en vez de descartar la novedad sin motivo.

**Por qué:** un tripulante tiene el mensual y el cierre de marea cubriendo los mismos días, así que
la fecha sola no elige. Antes caía en la liquidación que se calculara primero — no se cobraba
dos veces, pero en cuál entraba dependía del orden, que no es un criterio. El historial de
estados sí sabe qué estaba haciendo la persona ese día.

**Cómo aplicarlo:** al migrar novedades desde Meta4 **no** derivar el proyecto y guardarlo: dejarlo
en blanco. `M4T_VAL_INCIDENCIA` tampoco lo tiene —resuelve por fecha— así que llenarlo sería
inventarle una precisión que el origen no tiene, y equivocarse deja la novedad sin entrar en
ninguna liquidación, en silencio.

Del mismo modo, **convenio y categoría van en blanco**: sólo filtran en novedades colectivas
(empleado en blanco). Con un empleado nombrado no pueden incluir nada que el empleado no
incluyera ya, sólo excluir — y ya causaron ese bug. Ver [[novedades-pre-liquidacion]] y
[[tres-capas-fase-estado-asignacion]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[nomina-no-es-intervalo-presencia]]
- [[proyecto-nomina-dos-fuentes]]
- [[puente-mayor-no-es-la-planta]]
- [[recorrer-estado-abierto-dia-por-dia]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
