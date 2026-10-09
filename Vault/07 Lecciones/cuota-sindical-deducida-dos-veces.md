---
aliases: ["Cuota sindical deducida dos veces"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Cuota sindical deducida dos veces

el 8522 vivia en SS_LIQUIDADO y en CUOTA_SINDICAL_RET; y como reconstruir la base de Ganancias de Meta4 desde sus columnas

Al crear el acumulador `CUOTA_SINDICAL_RET` para que Ganancias deduzca la cuota sindical, el **8522
quedó en los dos acumuladores**: en `SS_LIQUIDADO` (donde estaba desde 2023, porque antes era la
única forma de que se deduzca) y en el nuevo. Igual el **4754** en `SS_SAC_DEV`. El 5010 resta los
dos, así que la cuota sindical se descuenta **dos veces** de la base.

En 00191 enero 2026 eso son 238.143,83 (8522) + 19.845,32 (4754) = **257.989,15 de base de menos**,
que al 31% son 79.976 de impuesto que BC no retiene. **El arreglo es borrar esas dos fracciones**, no
tocar el 5010: `SS_LIQUIDADO`/`SS_SAC_DEV` los usan sólo el 5010 y el 5020, los dos de Ganancias, así
que el acumulador no tiene otro consumidor que pueda extrañar al 8522. Ver [[acumuladores-orden-calculo]].

**Lo importante del método**: la base de Ganancias de Meta4 se reconstruye entera desde sus propias
columnas y tiene que dar su `IG_IMP_RET_ACUM` al centavo, que es **acumulado del año** (en 00191 da
1.341.727,79 en la corrida de vacaciones y 1.178.626,98 en la mensual, y la mensual liquida la
diferencia: −163.100,81). Las columnas son `IG_TOT_C_IM_ST` (conceptos imponibles), `IG_TOT_JUB_ST`,
`IG_TOT_OB_S_ST`, `IG_T_19032_ST`, `DED_CUO_SIND_ST`, `IG_G_NO_IMP` (MNI), `IG_DED_ESP`,
`IG_CONYUGE_REM` + `IG_HIJOS_REM`, y el SAC en `BSAC_MES_RG3976` con sus aportes en `JUB_SAC_MES`,
`LEY_19032_SAC_MES`, `OBRA_SOCIAL_SAC_MES` y `C_SINDICAL_SAC_MES`.

Dos cosas que esa reconstrucción deja resueltas y conviene no volver a discutir:

- **El término `(MNI + DESP + DEDUC) * MES_ANUAL / 12` del 5010 está BIEN.** Parecía el culpable
  porque su valor (258.189,46) es casi igual al desvío, pura coincidencia: sin él la cuenta de Meta4
  no cierra, y con él cierra al centavo. Es la doceava parte por SAC de la RG 4003.
- **El `MAX(..., 0)` del 5010 no hay que tocarlo.** Meta4 devuelve impuesto en la mensual sólo porque
  en la de vacaciones prorratea el MNI y la deducción especial (375.625,46 y 1.803.002,21 contra
  429.316,88 y 2.060.721), retiene de más y después corrige. BC usa el valor entero en las dos, así
  que su impuesto acumulado sólo crece y nunca necesita devolver.

**Borradas las dos fracciones el 2/10/2026.** Queda un residuo de dos causas chicas que completan
los 77.503,81 del mes, y que dejan al 00191 en **+2.473** después de recalcular:

- El **4753 de la REGULAR**: 336,20 de obra social sobre SAC que Meta4 no liquida en la mensual.
- El **4754**, que BC calcula sobre `BASE_SINDICAL` y Meta4 sobre el SAC devengado entero. En el
  00191 son 19.397,06 contra 27.710,08: `BASE_SINDICAL` es el 70% sindicalizable del tangonero
  (5.819.116,93 de 8.313.024,17) y la cuota sindical del SAC va sobre el 100%. **No es un defecto
  solo**: en enero 105 de 327 empleados difieren por 1,27 M, y las razones m4/bc se agrupan en 1,42
  (el 70/30, ~14 casos) y 1,3333 (~6 casos) pero hay sueltas de 2,4 a 8,8, así que hay más de una
  causa y cambiar la base del 4754 arregla sólo una parte. Ver [[franco-porcentaje-por-pesqueria]].

Los otros tres aportes sobre SAC devengado sí coinciden con Meta4 al centavo y no hay que tocarlos,
aunque sus bases parezcan arbitrarias: el **4751** y el **4752** van sobre `BASE_SS_TRAB + BASE_SS_VAC`
(sólo el 30%) y el **4753** sobre `BASE_OS_TRAB + BASE_OS_VAC` topeado por `TOPE_SIPA_OS`.

## Relacionado

- [[acumuladores-orden-calculo]]
- [[franco-porcentaje-por-pesqueria]]
- [[cuatro-conceptos-sin-disparar]]
- [[diferencias-descuentos-enero]]
- [[embargo-cuota-alimentaria-como-retencion]]
