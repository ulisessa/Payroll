---
aliases: ["GP devenga francos pero es improductivo"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-27
---

# GP devenga francos pero es improductivo

GP tiene Devenga Francos = 1 pero su proyecto es PN-NOMINA; MigrarEstados_2 deriva el proyecto de esa bandera y mandaría los GP a PP

`GP` (Guardia en Puerto) tiene **`Devenga Francos = 1`** en `Cód. Estado Empleado`, pero es
**improductivo**: su proyecto correcto es `PN-<buque>-NOMINA`, no `PP-<buque>-<marea>`. Confirmado
por el usuario el 27/9/2026.

**Son dos ejes distintos y el script los confunde.** `Devenga Francos` dice si el estado acumula
francos; `Job.Tipo` dice si el trabajo es productivo. Una guardia en puerto acumula francos y no
cuelga de una marea. Pero `scripts/MigrarEstados_2_BC_SqlServer.sql` deriva el proyecto así:

    Devenga Francos = Sí  ->  PP-<buque>-<marea>
    Devenga Francos = No  ->  PN-<buque>-NOMINA

o sea que **si esa migración se vuelve a correr, manda los GP a proyectos productivos**. Los datos
de BC hoy están bien (`PN-<buque>-NOMINA`), así que la migración corrió antes de que GP tuviera la
bandera, o alguien lo corrigió a mano. En enero de 2026 son 106 estados de 105 empleados.

**Por qué importa más de lo que parece:** en la corrida de REGULAR esos `GP` cuentan como
improductivos, y eso es lo que hace que 96 tripulantes queden correctamente excluidos por la regla
`Excluye NV/PL/PS en proyecto productivo` más el `Exige` de un estado improductivo. Si pasaran a
`PP`, cambia el ruteo de tipos de liquidación. Ver [[cuando-corresponde-una-liquidacion]] y
[[job-tipo-cero-no-bloquea]].

**Y no es una discrepancia contra Meta4:** Meta4 no guarda el proyecto. `ID_MAREA` nunca es cero, ni
en las filas de tierra, así que no sirve para distinguir — el proyecto lo deriva BC. Ver
[[migracion-estados-meta4]] y [[fases-bc-contra-meta4]].

## Relacionado

- [[cuando-corresponde-una-liquidacion]]
- [[job-tipo-cero-no-bloquea]]
- [[migracion-estados-meta4]]
- [[fases-bc-contra-meta4]]
- [[algo-parte-estados-en-dos]]
- [[estado-empleado-effective-dated]]
