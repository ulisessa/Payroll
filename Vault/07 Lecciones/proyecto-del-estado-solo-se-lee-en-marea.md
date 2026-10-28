---
tags: [lección, estados, proyectos, liquidación]
fecha: 2026-10-09
---

# El proyecto del estado sólo se lee si transcurre en marea

Un estado de tierra sin `No. Proyecto` **no cambia ningún importe**. El dato falta en la ficha, y
conviene completarlo, pero no es la causa de ninguna diferencia de cálculo.

## Dónde se lee, y por qué eso lo decide todo

`Estado Empleado."No. Proyecto"` aparece en **tres** lugares, y los tres descartan los estados de
tierra:

| Dónde | Qué hace | Filtro |
|---|---|---|
| `Cod50016.CalcularBuqueDeLaUltimaMarea` | buque de la última marea | `CodEstado."Transcurre en Marea"` |
| `Cod50016.DiasPuertoDeclaradosFueraDeLaAsignacion` | días de puerto | `CodEst."Transcurre en Marea"` |
| `Cod50018.EstadoCumpleProyecto` | si el estado matchea el Tipo Proyecto de la línea | — |

Los dos primeros sólo miran estados que transcurren en marea, así que un `AU9` con proyecto
`PN-ADM-*` nunca entra.

El tercero es el que podría morder, y no muerde:

```al
if Estado."No. Proyecto" = '' then
    exit(Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Improductivo);
...
if TipoJob = 0 then
    exit(true);
exit(TipoJob = Linea."Tipo Proyecto");
```

**Proyecto vacío ya cuenta como Improductivo.** Si el proyecto que se completa también es
Improductivo —y los `PN-*` de nómina lo son—, la función devuelve lo mismo antes y después. El
cambio es neutro por construcción, no por suerte.

## El corolario al revés

Completar el proyecto de un estado que **sí** transcurre en marea no es neutro: le cambia el buque
de la última marea y los días de puerto. Ése no se toca sin recalcular y comparar.

## Por qué falta el dato

La asignación de proyecto **crea** estados; no pisa los que ya existen; ver
[[asignacion-no-pisa-el-historial]]. Un estado cargado antes de la asignación queda sin proyecto
para siempre:

- la página no lo deja completar —`No. Proyecto` es `Editable = false` en `Pag110031` y `Pag50103`,
  porque es "el proyecto del que salió este estado";
- y por *Proyectos Asignados* tampoco, porque esa vía crea un estado y corta con
  `%1 ya tiene un estado que arranca el %2` (`Cod50017`). El error es correcto: un empleado tiene un
  solo estado por vez. Lo que hace falta no es un estado nuevo sino completar el campo del que está.

Queda el `UPDATE` directo, acotado y con invariantes, más el reinicio del service tier
([[sql-directo-deja-cache-rancia]]).

## La escala, que es la razón para no arreglarlo entero

En octubre de 2026 hay **41.035** estados sin proyecto y **19.158** tienen una asignación que los
cubriría. Un backfill masivo cambiaría el proyecto de estados históricos y con él las liquidaciones
ya calculadas de meses cerrados, para un dato que —por todo lo anterior— no mueve importes en
tierra. Acotado a enero de 2026 eran **tres**, y se completaron el 9/10/2026.

El cuarto caso de enero no tenía **ninguna** asignación, así que no había de dónde deducir el
proyecto: ése se carga como asignación y lo decide RRHH, no se infiere.
