---
aliases: ["Devengado de una marea que arranca después del cierre"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-18
---

# Devengado de una marea que arranca después del cierre

el día de puerto del 31/3 sobre una marea que zarpa el 1/4 se devenga en marzo, y el filtro de proyectos no la dejaba entrar

> [!warning] Los Devengados recorrían sólo los proyectos con `Starting Date` <= fin del período. Una marea con gente asignada desde el 31/3 y zarpada el 1/4 quedaba afuera: el día de puerto del 31/3 no lo pagaba ni el Cierre de la marea anterior (arribó el 30/3), ni la Regular (excluye los estados de marea), ni su propio Devengado (no se creaba).

Caso de marzo de 2026: la marea PP-128-000062 zarpa el 1/4 y 30 tripulantes tienen asignación desde el 30 o 31/3 y estado `PS` el 31/3. Meta4 paga ese día como puerto en marzo (1083 con 2 días en vez de 1). BC pagaba 1.

## Qué se cambió

`AplicarFiltroJobs` (Cod50018) ya no filtra por `Starting Date` en los tipos que no son de arribo. Quién entra lo decide `AplicarFiltroPersonal` (asignación con alta <= fin del período) y `EstadosJustifican`. El cálculo no cambió: `CalcDiasPuertoMarea` ya cuenta los días de víspera dentro de la ventana de la liquidación.

Hoy los proyectos futuros son 92 y sólo el 62 tiene asignaciones con alta <= 31/3.

## Cómo verificarlo

Crear y calcular marzo: debe haber un DEVENGADOS por tripulante de la 62 con cobertura 31/3 – 31/3 y 1083 con 1 día, que sumado al del Cierre de la 61 da los 2 días de Meta4.

Ver [[dia-de-puerto-no-estira-la-marea]], [[cobertura-devengado-tapa-dias]] y [[cuando-corresponde-una-liquidacion]].

## Segunda barrera: la ventana de estados quedaba invertida

Sacar el filtro del Job no alcanzó: al crear marzo no apareció el Devengado de la 62. `CalcularVentana` (Cod50018) arma la ventana "Cobertura" con `Liquidación.Cobertura` sin empleado, y ese recorta el desde contra el inicio del proyecto: con la marea zarpando el 1/4 queda 1/4 .. 31/3, ningún estado la toca y `EstadosJustifican` descarta a todos. Ahora, si la ventana queda invertida, el desde vuelve al inicio del período. Para decidir si corresponde crear alcanza con el período; el tramo propio de cada empleado (31/3 a 31/3) lo recorta `Cobertura` ya con empleado.

Aprendizaje: un cambio de filtro que "debería alcanzar" se prueba creando de verdad. Compilar no dice si la liquidación aparece.
