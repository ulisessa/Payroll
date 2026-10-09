---
aliases: ["Novedad perdida por proyecto sin liquidar"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Novedad perdida por proyecto sin liquidar

> [!warning] Falla en silencio
> La novedad se perdía cuando el estado del empleado a esa fecha apuntaba a un proyecto que no se liquidó; el desempate por proyecto sólo tiene sentido entre liquidaciones de marea

`ProyectoAplica` (Cod50061) terminaba con `exit(EstadoEmp."No. Proyecto" = Liq."No. Proyecto")`: si el
proyecto del estado a la fecha de la novedad no era el de la liquidación, la novedad no entraba y
quedaba Pendiente **sin motivo anotado**.

Esa comparación existe para **desempatar entre dos liquidaciones de marea** —una novedad de la marea
302 va en la de la 302 y no en la de la 303—. Pero cuando el proyecto del estado **no tiene
liquidación propia** no hay empate que resolver, y exigir que coincida sólo pierde la novedad. Es el
mismo caso que la novedad huérfana que ya contemplaba el código, con el proyecto que sobra viniendo
del historial en vez de la novedad.

Corregido el 29/9/2026: si `ExisteLiquidacionDelProyecto` dice que el proyecto del estado no se
liquidó, la novedad entra. En enero de 2026 destrabó **90 novedades de 29 empleados por 13.429.445**
—cuota alimentaria, descuentos de anticipo, horas extras, asistencia perfecta— y **ninguna pendiente
quedó bloqueada**, o sea que la regla vieja no filtraba nada útil.

El caso testigo: el 02792 tenía sus cuatro novedades de anticipo apuntando a `PP-116-000302`, su
estado decía `PN-116-NOMINA` y la liquidación se había creado contra `PN-114-NOMINA` porque
`ProyectoNominaDe` deduce el proyecto del **último embarque**, no de dónde está la persona ahora.

**Por qué:** el descuento de un adelanto no depende de en qué buque terminó el tripulante; la plata se
adelantó igual. Y el síntoma es mudo: Estado en cero, sin motivo, sin error.

**Cómo aplicarlo:** queda abierto el problema de fondo — **62 liquidaciones REGULAR de enero llevan un
proyecto que no coincide con el `ID_BUQUE` de Meta4** (mapeo `A##→1##`, `HF###→###`). Cambiar
`ProyectoNominaDe` para usar el estado vigente arregla 14 y mueve 48 a otro proyecto igual de
incorrecto, así que no alcanza: hay que mirar los estados. Relacionado:
[[novedad-con-proyecto-queda-huerfana]], [[novedad-proyecto-sale-del-estado]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
