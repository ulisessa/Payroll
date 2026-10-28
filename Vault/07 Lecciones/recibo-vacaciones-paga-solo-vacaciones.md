---
aliases: ["El recibo de vacaciones paga sólo vacaciones"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# El recibo de vacaciones paga sólo vacaciones

**En una frase:** El recibo de Vacaciones de Meta4 paga sólo el concepto de vacaciones y sus derivados; no lleva sueldo, básico, antigüedad ni producción

**Un documento de vacaciones de Meta4 —`Tipo Imputación = 3`— no paga el mensual.** Medido sobre las
**148 entradas** de vacaciones de enero a junio de 2026, lleva **24 conceptos y ninguno más**, y
**ninguno es de sueldo**: no hay básico, ni navegación, ni puerto, ni antigüedad, ni producción.

Los diez que están en el **100%** de las entradas:

    3553  VACACIONES          el haber
    1054  DIAS_MES_VAC        los días
    6003  JUBILACION_VAC      seguridad social PROPIA de vacaciones,
    6013  LEY_19032_VAC       con conceptos distintos de los regulares
    6035  OBRA_SOCIAL_VAC     (6000 / 6010 / 6030)
    4750  BSAC_MES_RG3976     SAC devengado y sus cargas
    4751  JUB_SAC_MES
    4752  LEY_19032_SAC_MES
    4753  OBRA_SOCIAL_SAC_MES
    4754  C_SINDICAL_SAC_MES

Y después: 8525 sindical de vacaciones (99%), 5498 redondeo (98%), 5010 impuesto (72%), 3554 (35%),
8522 (35%), 6030 (33%), 8893 cuota alimentaria (18%), 8553, 6037, 8542, 8593, 8830, 8563, 8543.

## Qué significa para BC

BC paga el paquete completo en los dos documentos porque `VACACIONES` tiene
**`Sólo Conceptos Declarados = false`** —lo tienen los nueve tipos— y 216 conceptos tienen
`Tipos Liq. Aplicables` en blanco, que es comodín: ver
[[vacio-en-tipos-liq-aplicables-es-comodin]]. El testigo es el 90016: Vacaciones 24.208.251,76 y
Regular 26.173.261,08, con netos casi idénticos.

**El arreglo es prender la bandera y declarar esos 24**, y no prorratear: Meta4 no reparte el
mensual, directamente no lo pone. Es el mismo cambio que **ya se intentó antes en este proyecto y
falló por lista incompleta —perdió 18 conceptos—**; la diferencia es que ahora la lista sale de medir
lo que Meta4 efectivamente paga y no de armarla a mano.

## Implementado el 28/9/2026 (`vacaciones_declarados.sql`, commiteado)

Bandera prendida en VACACIONES, **6 conceptos declarados** y **5 des-declarados**: 6000 y 6010
—jubilación y ley 19032 regulares, que en vacaciones son 6003 y 6013—, 6032 —reemplazado por 6037—,
3573 "Adicional vacaciones art. 76" y 4743 "Descuento días de vacaciones". Los 23 finales no
incluyen **ni un concepto de sueldo**.

**Tres cosas que el ensayo destapó y que no estaban en el plan:**

- **Las contribuciones patronales SÍ van en el recibo de vacaciones** —`JUBIL_PAT_VAC`, `PAT_ART_VAC`,
  `VAC_23660_PAT`, `VAC_PAT_L_19032`, `AP_F_NAC_EM_VAC`, en las 148 entradas— pero **ninguna columna
  patronal está mapeada a un concepto de BC**, así que la lista medida es ciega a ellas. Sacarlas
  habría dejado el costo laboral del período sin contribuciones. Se excluyó el tipo 3 del borrado.
- **Informativo es el tipo 6, no el 4.** El 4 es Retención. Una salvaguarda escrita sobre el 4 protege
  a las retenciones y deja desprotegidos a los acumuladores — al revés de lo que se quería.
- **`DIAS_MES_VAC` está mapeado al concepto 1054, que en BC es "Antigüedad mensuales".** Es un mapeo
  equivocado de la misma clase que `PR_FRANCO` → 1062. Se dejó **fuera** de la lista: declararlo
  habría hecho correr la antigüedad justo en el recibo del que se la quiere sacar.

Quedan **4 informativos con lista propia**, que el motor no restringe pero conviene mirar.

## Relacionado

- [[recaida-accidente-mismo-valor]]
- [[vacaciones-tierra-duplica-el-mes]]
- [[vacaciones-tripulantes-promedio]]
- [[ventana-promedio-ausentismo]]
- Tema: `vacaciones-sac-licencias` (ver [[_Convenciones del vault]])
