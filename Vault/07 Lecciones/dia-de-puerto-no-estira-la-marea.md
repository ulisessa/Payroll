---
aliases: ["Un día de puerto no estira la marea"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-21
---

# Un día de puerto no estira la marea

La marea son los días del buque; embarcar antes agrega un día del tripulante, no un día de marea

> [!warning] Los días de la marea salen de la **zarpada al arribo** y son iguales para todos los que la hacen. Un tripulante que sube antes a hacer trabajos de puerto suma **un día suyo**, que se paga como puerto y **no** entra en el prorrateo del neto acordado.

El HF802 zarpó el 3/1 y arribó el 24/1: **22 días de marea**. Un primer oficial subió el **2/1** a trabajar en puerto sobre esa misma marea. Su recibo de Meta4 lo dice sin ambigüedad:

```
Sueldo Navegación   22 × 25.500 = 561.000
Sueldo Puerto        1 × 51.000 =  51.000
A Cta Futuros Aumentos        15.199.400     ← prorrateado sobre 22, no sobre 23
```

Meta4 lleva las dos cuentas por separado —`DIAS_NAVEG` 22, `DIAS_PUERTO` 1, `DIAS_MAREA` 23— **paga el día de puerto** y prorratea el acuerdo sobre los **22**. BC tiene exactamente los mismos días; lo que se había alineado mal era cuál de ellos alimenta el objetivo del grossing-up.

## Cómo se modela

- **La asignación** (`Personal Proyecto`) va de la **zarpada al arribo**: es la parte de la marea que le toca al tripulante, y es de donde sale el prorrateo del neto acordado ([[valor-franco-por-terna]] usa la misma idea para el franco).
- **El día de puerto extra lo declara el estado**: un `PS` sobre el proyecto de la marea, anterior al alta de la asignación.

Hasta el 8/10/2026 el día de puerto sólo existía si la **asignación** arrancaba antes de la zarpada, porque `CalcDiasPuertoMarea` lo deducía como "día de víspera" de esa ventana. Eso forzaba a elegir:

| Asignación | Objetivo | Día de puerto |
|---|---|---|
| 2/1 – 24/1 | 23 días ✗ | se paga ✔ |
| 3/1 – 24/1 | 22 días ✔ | **se pierde** ✗ |

Y perderlo era peor que no pagarlo: el día quedaba **dentro de la cobertura** de la liquidación, así que ninguna otra lo iba a reclamar ([[cobertura-devengado-tapa-dias]]).

`DiasPuertoDeclaradosFueraDeLaAsignacion` suma los días de estado marcados
`Transcurre en Marea` que quedan fuera de la ventana del viaje del tripulante.
Con eso la asignación puede decir la verdad y el día de puerto se paga igual.

> [!note] Qué estado es "de puerto" no está escrito en el código
> Fuera de la ventana del viaje basta la marca `Transcurre en Marea`. El helper no
> distingue códigos de navegación o puerto ni depende de `Estado Liq. Personal
> Predet.` del proyecto. Esa distinción, que describía antes esta nota, no está en
> el código. Ver [[tres-capas-fase-estado-asignacion]].

**Medido antes de escribirlo:** sobre las 180 liquidaciones de marea calculadas, **179 dan exactamente los mismos días** y la única que cambia es la que había perdido su día de puerto.

## Puerto posterior al arribo (21/10/2026)

El mismo criterio vale después del arribo. A28/62 tiene arribo el 22/4 a las
08:30; parte de su personal conserva estado de puerto y asignación hasta el 23/4.
El contador se cortaba en la fecha de valoración y perdía ese día cubierto.

`Init` recibe ahora también `CoberturaHasta`. Sólo para tipos con disparador
`Arribo`, el límite privado de puerto puede llegar a esa cobertura, acotada al fin
del período. La extensión posterior respeta los tramos cargados: un hueco no suma
puerto. La llamada anterior a `Init` conserva su límite original.

No se cambia el arribo, `FFechaRef`, TC, vigencias ni navegación. `DIAS_MAREA`
descuenta ese puerto personal y conserva el viaje. La verificación aislada cubre
21 días de navegación, dos de puerto y 22 de viaje; quien termina su puerto en el
arribo conserva un solo día. También cubre una liquidación que sólo tenga puerto
posterior y la reutilización del contexto. No se recalcularon recibos operativos.
Ver [[Tests automatizados]] y [[ventana-liquidacion-es-cobertura]].

## Puerto posterior en la asignación (21/10/2026, 1.0.0.680)

**El día extra de puerto al finalizar la campaña funciona igual que el del inicio: se suma si el
empleado está asignado a la marea ese día** (regla del usuario). Al inicio lo hace la regla de
víspera de `CalcDiasPuertoMarea` (del alta de la asignación al día anterior al zarpe); al final
no había espejo: `VentanaEmpleadoEnMarea` recorta la baja al arribo ("recorta pero no estira") y el
puerto posterior de arriba sólo llega hasta la **cobertura** de la liquidación.

`DiasPuertoPosterioresEnLaAsignacion` suma, para tipos con disparador Arribo cuya valoración llega
al arribo, los días desde `max(arribo, FFechaHastaPuerto) + 1` hasta `min(Fecha Baja de la asignación,
fin del período)`. Parte después del límite del puerto declarado, así que ningún día se paga dos
veces; `CalcDiasPuertoDelViaje` los resta (el viaje y el prorrateo del neto no cambian). Una baja en
blanco, anterior o igual al arribo, un período inexistente u otro disparador no suman.

Medido en abril de 2026: 40 tripulantes (los que Meta4 paga con un día más de puerto en la corrida de
pilotaje, tipo 12, que BC no tiene) tienen la baja de su asignación un día después del arribo; el cierre
suma ese día. **La baja de la asignación tiene que llegar al día extra** (en esos casos
`Personal Proyecto.Fecha Baja` 24/4). Contrato que cambió: antes una baja posterior al arribo sin
ampliar la cobertura no sumaba nada; el test `PuertoCoberturaSinHastaPosteriorSumaElDiaDeLaAsignacion`
reemplaza al que lo fijaba. Tests nuevos: `PuertoPosteriorSumaHastaLaBajaDeLaAsignacionSinEstirarElViaje`,
`PuertoPosteriorNoSumaSinAsignacionAbiertaNiParaOtroDisparador`, `PuertoPosteriorSeAcotaAlFinDelPeriodo`
(Cod110046; compilan, **no se corrieron** en una empresa TEST_).

## Lo que se descartó, y por qué

Prorratear el objetivo sobre `DIAS_NAVEGADOS` en vez de `DIAS_MAREA` parecía el arreglo obvio. Simulado: **arregla uno y rompe siete**. Los seis devengados de las mareas que arrancan a fin de mes pierden su día de **zarpada**, que sí es día de marea y hoy cuadra exacto contra Meta4.

Y ojo con acotar "días dentro de la ventana del proyecto" sin más: tres administrativos tienen `NETO_GARANT` **sin días de marea** —su objetivo sale del otro término de la fórmula— y un acote recalculado desde cero les daría 31 días donde hoy tienen 0.

## Relacionado

- [[tres-capas-fase-estado-asignacion]]
- [[asignacion-no-pisa-el-historial]]
- [[cobertura-devengado-tapa-dias]]
- [[ventana-liquidacion-es-cobertura]]
- [[oficiales-netos-al-70]]
