---
aliases: ["Marzo 2026 - proyectos, fechas y producción contra Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [meta4, migracion, marzo, proyectos, mareas, produccion, auditoria]
fuente: [M4T_HIST_MAREAS, M4T_HIST_EST_BUQUE, M4T_PROD_SUBMAREA, M4T_VAL_ESPECIE_PUESTO, M4T_ACUMULADO_RL2, M4T_ACUMULADO_RL3, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al]
actualizado: 2026-10-16
---

# Marzo 2026 - proyectos, fechas y producción contra Meta4

Ampliación de [[prevuelo-marzo-2026-meta4]], realizada sólo en lectura. No se
modificaron fórmulas, datos BC ni recibos; tampoco se ejecutaron pruebas AL.
La evidencia privada está en `.snapshots/proyectos-produccion-marzo-20261016/`
y `.snapshots/prevuelo-marzo-20261016/proyectos-fechas/`.

La corrección de hora confirmada por el usuario y la parametrización de calidad
se aplicaron después de esta auditoría. Ver [[marzo-2026-cargas-aplicadas-meta4]];
el detalle siguiente conserva el diagnóstico y sus límites originales.

## Proyectos y fechas

Hay 21 proyectos referenciados en estados vigentes de marzo: 14 PN y siete PP.
Uno de los PP es histórico en AU9; los viajes de marzo y frontera de abril son
seis. Los días con proyecto tienen asignación vigente. No se detectaron fechas
invertidas, zarpes vacíos ni diferencias en la fecha del primer PL de arribo.

`M4T_HIST_MAREAS.FEC_INI` puede incluir preparación PS anterior a navegación.
No equivale siempre a `Job.Starting Date`. Copiarla sobre el proyecto para
incluir personal anticipado alteraría el viaje. Los 69 días-persona PS anteriores
al zarpe están respaldados por los estados originales.

Dos diferencias requieren atención antes de calcular marzo:

- **PP-802-000009:** BC tiene zarpe 24/03 a las 12:30. El motor clasifica ese día
  como puerto; Meta4 tiene NV y sus 30 salidas originales registran ocho días de
  navegación. El modelo offline BC da siete: desplaza un día NV a puerto, sin
  cambiar la suma. La fuente original confirma la clasificación, pero las horas
  y minutos de buque están vacíos: falta respaldo operativo para una hora exacta.
- **PP-128-000062:** zarpe 01/04 correcto, con 31 días-persona PS de 30 empleados
  el 30/31 de marzo. `AplicarFiltroJobs` excluye proyectos que comienzan después
  del cierre mensual. Crear por empleado/asignación incluye esa presencia;
  alternativamente, el filtro masivo debe contemplarla de forma general.

La reproducción offline de navegación/puerto coincide en 149 de 179 salidas de
los seis viajes; las 30 diferencias corresponden a PP-802-000009. No valida aún
los importes. El PL adicional del 23/04 en A28/62 requiere revisar abril antes de
extender el proyecto: el arribo 22/04 ya coincide con el primer PL.

## Producción física y ajuste de calidad

Los cierres tipo 10 de marzo corresponden a tres mareas, con 89 salidas originales.
Las descargas BC contienen calamar entero en las tres:

| Marea / proyecto | Neto físico BC, kg | Snapshot Meta4, kg | Observación |
| --- | ---: | ---: | --- |
| A28/61 - PP-128-000061 | 373.292 | 354.627,4 | Meta4 aplica 95 % |
| HF801/8 - PP-801-000008 | 236.404 | 236.404 | Coinciden |
| HF802/8 - PP-802-000008 | 544.360 | 544.360 | Coinciden |

El comentario original de A28/61 dice «- 5% CONTROL DE CALIDAD PARA TODA LA
TRIPULACION EXCEPTO MAQUINAS». Las salidas pagadas confirman el 95 % en las bases
de marinería y oficiales de cubierta; los dos oficiales de Máquinas conservan
100 %. Los dos casos parciales de marinería no se deben convertir en marea completa.
Las mareas A28/59 y A28/60 no tienen ese ajuste en el origen revisado.

`PROD_KN_MAREA` suma neto de descarga por proyecto, sin factor de calidad. Las
ramas vigentes revisadas consumen esos kilos sin 0,95; no se halló parámetro ni
atributo de calidad que represente la excepción. `COEF_POTERO = 1` cumple otra
función. Se necesita un dato por marea con alcance por modalidad/puesto.

> [!warning] Conservar la descarga física
> Reducir todos los kilos del proyecto descontaría también a Máquinas. El ajuste
> corresponde a la base pagable según su alcance, conservando la descarga NAV.

## Cortes, unidades y precios

Meta4 selecciona `PROD_SUBMAREA` por `FEC_FIN = #160` y la foto anterior por
`FEC_FIN = #140`. No se suman todas las fotos ni se usa la fecha de imputación del
recibo como corte. En HF801/8 hay una foto anterior además de la final: sumarlas
duplicaría producción. Para relevos se debe respetar la ventana/asignación.

`1340` de marinería guarda toneladas, pese al nombre original; `1344` de oficiales
guarda kilos. Los doce oficiales comparados reproducen la valoración original
por cantidad, precio y tipo de cambio. Ese control separa producción base de
garantizados, acuerdos netos y descuentos de devengados.

Meta4 `1343` consulta por puesto. En BC, el modo «Par CCT a Usar = Puesto» cambia
al par resuelto por el atributo PUESTO antes de seleccionar parámetros. Comparar
sólo la categoría salarial produce falsos desvíos. No cambiar esa categoría para
corregir producción: también determina otros haberes. El contraste debe resolver
el puesto: con ese eje, las 231 tarifas comparadas de 77 cierres y tres especies
coinciden exactamente con el original.

BC agrega la producción SOMU en `2498`, cuya fórmula sí tiene vigencia abierta.
El campo `Activo` es «sin efecto» en la tabla; no elimina esa fórmula del motor.
`1343/1373/1383` vacíos no demuestran ausencia de producción: hay que seguir la
rama agregada y sus consumidores. La forma de exponer conceptos separados puede
diferir de Meta4. No se certificó todavía el resultado de un cierre BC de marzo.

Los mapeos físicos comprobados son CAE → 05CALENT, CAV → 08CALVAI y VSS → 07CALREJ.
CR en Meta4 es cola rota de langostino. Los filtros efectivos de fuentes tienen
prioridad sobre los filtros heredados: no corregir alias antiguos sin comprobar
qué filtro ejecuta el motor.

## Devengados anteriores y límites

Los 89 cierres tienen un DEV previo BC calculado; existen 90 DEV de febrero en
los tres proyectos. Todos conservan cantidad `DIAS_MAREA` y TC histórico positivo.
No hay selección de recibos futuros en esta captura. El DEV adicional requiere
clasificar su corrida original; su ausencia en los cierres tipo 10 no autoriza borrarlo.

`A_CUENTA_MAREA` carece de corte temporal, aunque aquí selecciona las mismas filas
que `DEV_PREV_MAREA`. Meta4 `ACM_A_CUENTA` limita a la misma alta/buque/marea,
tipos y los doce meses anteriores al mes del proceso; acumula
`TOT_HAB_GZDO + A_CTA_MAREA`, no cualquier bruto. Las historias originales confirman
un previo y los mismos días para los 89 cierres, sin multiplicación en los joins.
Los seis previos de oficiales sin GU y las seis garantías normativas de puente
coinciden al centavo. Los seis previos GU conservan diferencias nominales de febrero:
no provienen de seleccionar otra historia ni del cierre de marzo aún no calculado.
Los importes de los 77 marineros no se equipararon a esa base propia de oficiales.

No hubo cierres tipo 10 de tangoneros en marzo en este alcance. La conversión
USD/TC de auxiliares antiguos, y los resultados futuros de sus ramas, quedan
fuera de la certificación de estos tres cierres.

## Relacionado

- [[prevuelo-marzo-2026-meta4]]
- [[un-valor-una-fuente]]
- [[novedad-con-proyecto-queda-huerfana]]
