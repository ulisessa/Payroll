---
aliases: ["Recorrer un estado abierto día por día"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# Recorrer un estado abierto día por día

**En una frase:** Un estado abierto termina el 31/12/9999; recorrerlo día por día desborda el Date y mata el cálculo con "La fecha no es válida"

`Estado Empleado.FechaFinEfectiva()` devuelve **31/12/9999** cuando el estado está abierto. Un bucle
que lo recorra día por día no sólo da casi ocho mil años de vueltas: al llegar al tope, el
`FechaActual += 1` **se pasa del máximo que admite un Date** y el cálculo entero muere con
**"La fecha no es válida."**.

Pasó en `CalcDiasFeriadosGuardia` (Cod50016) el 28/9/2026:

```al
FechaActual := EstadoEmp."Fecha Inicio";
FechaFinEstado := EstadoEmp.FechaFinEfectiva();      // 31/12/9999 si está abierto
while FechaActual <= FechaFinEstado do begin
    if DiaEnLaVentana(FechaActual) then ...          // el filtro estaba DENTRO del bucle
    FechaActual += 1;
end;
```

Eran **14 cierres de marea de enero de 2026 — 183 errores en el registro**. Los 14 tenían un `GP`
abierto iniciado entre el 26/4 y el 2/6 de 2026: un estado **futuro** respecto del mes que se estaba
liquidando, con `Devenga Francos = 1` y `Transcurre en Marea = 0`, que son las dos condiciones que
hacían entrar al bucle. 14 de 14, sin excepciones.

**El arreglo es recortar contra la ventana ANTES de recorrer**, como ya hacía `DiasEnLaVentana`:
intersectar el estado con cada tramo y recorrer sólo la intersección. Preguntar día por día si el día
cae en la ventana da el mismo resultado pero no acota nada. Y un `SetFilter("Fecha Inicio", '<=%1',
FFechaRef)` saca de entrada los estados futuros, que no pueden tocar la ventana porque los tramos
viven dentro del período.

## Y el error se borraba solo

`CalcularYDescartarSiVacia` conservaba bien la liquidación fallida, pero **`BarrerVacias` la borraba
después**: una que falló no tiene líneas, así que `EstaVacia` dice que sí. El cálculo fallido
desaparecía y el único rastro quedaba en el registro de procesos — por eso los 14 pasaron
desapercibidos durante una revisión entera. Se agregó `FFallidas`, que las deja fuera de la barrida y
se limpia al empezar cada corrida.

Ver [[estado-empleado-effective-dated]] y [[cobertura-en-tramos]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[nomina-no-es-intervalo-presencia]]
- [[novedad-proyecto-sale-del-estado]]
- [[proyecto-nomina-dos-fuentes]]
- [[puente-mayor-no-es-la-planta]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
