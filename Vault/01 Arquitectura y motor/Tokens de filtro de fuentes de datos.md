---
tipo: referencia
tags: [motor, fuentes-de-datos, tokens]
fuente: [src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Tables/Tab60029.FiltroFuenteDatosLiq.al]
actualizado: 2026-10-04
---

# Tokens de filtro de fuentes de datos

Un **token** es un marcador `{NOMBRE}` dentro del `Filtro Valor` de una fila de `Filtro Fuente Datos Liq.`
(ver [[Fuentes de datos]]). `ApplyTokens` (Cod50016) los reemplaza **antes** de aplicar `SetFilter`. Los
tokens se escriben **en mayúsculas** y con llaves; las fechas se insertan con `Format(fecha)` (formato
local de la sesión) y combinan con `..` para armar rangos: `{PERIODO_DESDE}..{FECHA_REF}`.

> [!warning] Los comentarios de las tablas están desactualizados
> `Tab60015` lista 4 tokens y `Tab60029` lista 13; el código reconoce los **23** de la tabla de abajo
> —contados uno por uno el 8/10/2026; el «20» que decía esta nota ya estaba corto—. Esta nota sigue
> al código.

## Catálogo

### Identidad de la liquidación

| Token | Se reemplaza por | Vacío cuando… |
|---|---|---|
| `{EMP_NO}` | `No. Empleado` de la liquidación | nunca en liquidaciones reales |
| `{JOB_NO}` | `No. Proyecto` | liquidación sin proyecto → la fuente devuelve 0 |
| `{BUQUE}` | `Global Dimension 1 Code` del proyecto (el buque). Se resuelve con la misma función que los atributos de buque | sin proyecto → la fuente devuelve 0 (evita sumar la veda de toda la flota) |
| `{BUQUE_ULT_MAREA}` | el buque de la **última marea en que el empleado estuvo embarcado**: el último `Estado Empleado` ya iniciado cuyo código tiene `Transcurre en Marea` (hoy NV, PL y PS), y la dimensión 1 de su proyecto | nunca embarcado → vacío → la fuente devuelve 0 |
| `{PERIODO}` | `Cód. Período` | — |
| `{LIQ_NO}` | `No. Liquidación` | fase de validación (`LiqNo = ''`) |
| `{MONEDA}` | moneda del primer parámetro en divisa (`FMoneda`) | si todavía no se resolvió ningún parámetro en divisa |

### Fechas de la ventana

| Token | Valor |
|---|---|
| `{FECHA_REF}` | fecha de referencia (`FFechaRef`: fin de período o arribo) |
| `{PERIODO_DESDE}` | inicio de la **ventana de la liquidación** (la cobertura; si no hay, inicio del período). Con `{FECHA_REF}` acota ambas puntas: sin la inferior, el cierre de agosto de una marea a caballo de dos meses vuelve a sumar lo que el devengado de julio ya pagó |
| `{AÑO_DESDE}` | `1/1` del año de `FechaRef`, para cuentas corrientes que se reinician con el año (Art. 19 del CCT 729/15). Ver [[art19-calamar-cuenta-corriente]] |
| `{SEM_DESDE}` / `{SEM_HASTA}` | primer / segundo semestre calendario según el mes de `FechaRef` (1/1–30/6 o 1/7–31/12) |

### Alta/baja del tripulante y de la marea

| Token | Valor |
|---|---|
| `{ASIG_DESDE}` / `{ASIG_HASTA}` | alta y baja **de este tripulante en esta marea** (`Personal Proyecto`), acotadas a la ventana: el alta no antes de `FPeriodoFechaDesde`; la baja en blanco se resuelve como `FechaRef` (no 31/12/9999, que arrastraría descargas posteriores). Sin asignación: la ventana de la liquidación |
| `{MAREA_DESDE}` / `{MAREA_HASTA}` | zarpada y arribo **del proyecto**, sin recortar por el período (comparar contra `{ASIG_*}` dice si el tripulante hizo la marea entera). Sin proyecto/fechas: la ventana de la liquidación |

La producción se cuenta hasta el día en que cada uno desembarca: por eso `{ASIG_*}` y no el rango del período.

### Vigencia de un atributo — los únicos con argumento

| Token | Valor |
|---|---|
| `{ATRIB_DESDE:X}` / `{ATRIB_HASTA:X}` | la vigencia del atributo de empleado **X** cuyo valor apunta al proyecto de esta liquidación (`Cód. Valor` o `Valor Texto` = `{JOB_NO}`), recortada a la ventana de la asignación |

`X` es el **código del tipo de atributo**, y va escrito en el filtro de la fuente. Es el único token que lleva argumento, y hay una razón de orden: las fuentes se resuelven **antes** de que corra cualquier fórmula —son las que arman el contexto que la fórmula lee—, así que una fórmula no puede decirle a una fuente cómo filtrar. Nombrarlo en el filtro lo deja donde se lee, y evita un campo de configuración que lo diga.

> [!note] Sin fila cae a la ventana de la asignación, **nunca a vacío**
> Y es deliberado, porque es la excepción a la regla 2 de más abajo. La fuente que usa estos tokens suma producción: quien no tiene tramo cargado tiene que ver la marea entera, que es lo que veía antes de que el tramo existiera. Con vacío, `TokenResolvedToEmpty` le daría **cero** y el concepto pagaría cero sin un solo error a la vista. Misma convención que los `{ASIG_*}`.

Dos filas para la misma marea —un tramo partido, frío/planta/frío— **no se adivinan**: tomar del primero al último contaría el hueco del medio ([[cobertura-en-tramos]]). Se avisa y se cae al fallback. Ver [[adicional-frio-por-tramo-del-diario]].

### Ventanas de promedio

| Token | Valor |
|---|---|
| `{PROM_DESDE}` / `{PROM_HASTA}` | los **seis meses calendario anteriores** al mes en que **empieza la licencia** de vacaciones (Art. 34 CCT). Ancla: `FechaInicioVacaciones()` (la primera vigencia de `Tipo Estado = Vacaciones` que llega al período o más allá); sin vacaciones, `FechaRef`. El mes en curso queda afuera (sería circular) |
| `{AUS_PROM_HASTA}` | último día del mes anterior al del inicio de la licencia con `Promedia Ausencia` |
| `{AUS_PROM6_DESDE}` / `{AUS_PROM12_DESDE}` | primer día del mes 6 / 12 meses atrás de ese `HASTA` (175/75 usa 6; 729/15 y 768/19 usan 12) |

Ver [[ventana-promedio-ausentismo]], [[vacaciones-tripulantes-promedio]] y [[historia-remuneraciones-migrada]].

## Reglas de resolución

1. Se reemplaza token por token; los que no están en el texto no cuestan nada (los de fechas con cuenta cara —`ASIG`, `MAREA`, `SEM`, `PROM`, `AUS_PROM`— se calculan sólo si el texto los contiene).
2. Si el valor original contenía `{` y el resultado quedó **vacío**, la fuente completa devuelve **0** (`TokenResolvedToEmpty`).
3. Un token mal escrito **no se reemplaza** y queda literal en el filtro (no hay error): el filtro simplemente no encuentra filas. Revisar la ortografía.
4. `{MONEDA}` depende del orden: se resuelve al recorrer fuentes, después de `LoadParametros`, así que vale lo que ese paso dejó en `FMoneda`.

## Cómo agregar un token

1. `ApplyTokens` (Cod50016): `Value := Value.Replace('{X}', ...)`.
2. Documentarlo acá y en los comentarios de `Tab60015` y `Tab60029` (hoy desactualizados).
3. Si es de fecha cara, protegerlo con `Value.Contains('{X}')` para no calcularlo en cada filtro.

## Relacionado

[[Fuentes de datos]] · [[Contexto de liquidación y variables]] · [[ventana-liquidacion-es-cobertura]] · [[Tabla - Fuente Datos Liquidación]]

## `{BUQUE}` contra `{BUQUE_ULT_MAREA}`

No son lo mismo y la diferencia **sólo aparece cuando el empleado ya no está embarcado**, que es justo cuando hace falta: para decidir si cobra sueldo a órdenes o el Art. 48 párrafo 11 hay que saber si su última marea fue en un potero o en un tangonero, y esa liquidación corre contra el `PN-` de nómina.

Los `PN-` son **por buque** (`PN-116-NOMINA`, `PN-128-NOMINA`), así que `{BUQUE}` no queda vacío: devuelve el buque de la nómina a la que el empleado está asignado, que es otro concepto. Medido sobre las 324 liquidaciones REGULAR de enero de 2026:

| | Empleados |
|---|---|
| `{BUQUE_ULT_MAREA}` vacío (nunca embarcado) | 66 |
| Coincide con `{BUQUE}` | 240 |
| **Difiere de `{BUQUE}`** | **18** |

Cuatro de los dieciocho cruzan la serie 801/802 —los poteros—, que es exactamente el caso que decide órdenes contra Art. 48. `{BUQUE}` ahí no falla: miente, con un buque plausible.

El criterio de "embarcado" **no está en el código**: sale de la bandera `Transcurre en Marea` de `Cód. Estado Empleado`. Por eso no se puede expresar con una Fuente de Datos —la bandera vive en el maestro de códigos y filtrarla es un join, y una fuente lee una sola tabla—; poner `NV|PL|PS` en una línea de filtro cablearía justo lo que la bandera configura. Con NV estricto el resultado de enero es idéntico, así que la bandera no cuesta nada y aguanta un cambio de criterio.

### Cómo se usa: Órdenes contra Artículo 48

**El buque de la liquidación NO se cambia.** Es el correcto para el recibo, para los precios y para el coeficiente de pesquería. Lo único que mira la última marea es la decisión entre sueldo a órdenes y Art. 48, y eso se expresa agregando variables, no redefiniendo las que ya hay.

Reemplazar `TIPOACTIVIDAD` habría arrastrado `COEF_PESQUERIA` —que es `IF(TIPOACTIVIDAD = 0, IFZERO(COEF_TANGONERO, 1), 1)`, y `COEF_TANGONERO_729/15` vale **0,30**— y el importe habría quedado mal por el otro lado: 30.376,36 contra los 101.254,53 del recibo.

Tres pasos:

1. Tildar **`Publicar Última Marea`** en el Tipo de Atributo `TIPOACTIVIDAD`. Aparece `TIPOACTIVIDAD_ULT_MAREA` con su código registrado, así que se puede comparar `= 'TA'`. Importa que sea por código: el numérico de `TA` es **cero**, indistinguible de "nunca navegó".
2. Crear la Fuente de Datos **`DIAS_VEDA_ULT_MAREA`**, clon exacto de `DIAS_VEDA_BUQUE` —tabla `110005`, `DIAS_OVERLAP`, fechas en los campos 4 y 5 con Fin Efectivo, filtros `Tipo Entidad = Buque` y `Cód. Tipo Atributo = ART48`— cambiando sólo `{BUQUE}` por `{BUQUE_ULT_MAREA}`.
3. Cambiar la fórmula de `DIAS_ART48`:

```
IF(TIPOACTIVIDAD_ULT_MAREA = 'TA', MIN(DIAS_ORD_PERIODO, DIAS_VEDA_ULT_MAREA), 0)
```

El resto queda igual: el 1076 sigue tomando `PRECIO_NAV` y `COEF_PESQUERIA` del buque de la liquidación.

**Caso de control (02748, enero 2026).** Nómina en el 128 (potero, veda desde el 1/5), última marea en el 117 (tangonero, veda del 1/1 al 31/5), convenio 729/15 categoría MR03, 4 días de órdenes. Antes: `DIAS_ART48` = 0 y el 1073 paga 151.881,87. Después: `DIAS_ART48` = 4, el 1073 pasa a cero y el 1076 paga `4 × 759.409 / 30 × 1` = **101.254,53**, que es el recibo de Meta4 al centavo.

## Ventana configurable de licencia (13/10/2026)

`{PROM_LIC_DESDE:VARIABLE}` y `{PROM_LIC_HASTA:VARIABLE}` leen una fila activa de Variables de
Sistema con cálculo `DIV_PROM_LIC`. El campo `Cód. Estado` elige la licencia; los parámetros
vigentes `PROM_LIC_MESES`, `PROM_LIC_UMBRAL` y `PROM_LIC_DIAS_MES` definen ventana y divisor.
La fórmula debe usar esa misma variable como divisor para conservar una única definición.
Los tokens se resuelven sólo cuando aparecen en el filtro; la fecha resultante conserva el
formato local utilizado por las demás fuentes.

La ventana termina antes del mes de inicio de la licencia y se recorta al vínculo que contiene
ese inicio. Si no hay historia previa válida, se usa una fecha centinela y divisor cero;
nunca un filtro vacío que pueda sumar toda la historia. Ver [[enfermedad-base-total-no-base-fiscal]].

## Costo de `{BUQUE_ULT_MAREA}` (4/10/2026)
`BuqueDeLaUltimaMarea` recorre todo el historial de estados del empleado. `ApplyTokens` la llamaba en **cada filtro de cada fuente**, esté o no el token en el texto: 488 de 4.021 muestras (12 %) en un cálculo del árbol. Ahora sólo se resuelve si el texto contiene el token, y el resultado se recuerda por liquidación (`FBuqueUltMarea`, se vacía en `Init`). Cualquier token nuevo que consulte la base debe seguir el mismo patrón: `Contains` antes de resolver.

## `{FECHA_TC}`: la fecha de la cotización

Lo usan las Fuentes `TC_COMPRADOR` y `TC_VENDEDOR` (`<={FECHA_TC}`, antes `<={FECHA_REF}`) y el grossing-up
(`FechaTipoCambio()`, `Cod50016`). Resuelve así, de más a menos específico:

1. **La novedad `FECHA_TC`** del empleado y del período (concepto informativo, sin fórmula, fuera del
   recibo; queda Pendiente a propósito). Es para el sueldo en divisa de nómina, cuyo tipo de cambio es el de
   la fecha en que se CORTÓ el proceso y cambia cada mes.
2. **En una `LIQ_FINAL`, el fin de la cobertura**, que es el egreso (versión 1.0.0.656). Meta4 cotiza la
   final al último día trabajado: 04766 (baja el 7/2) cobra el franco de un oficial a 1.400, la cotización
   del 6/2, y BC lo pagaba a 1.370, la del 27/2 que da FechaRef en una final de febrero.
3. La fecha de referencia de la liquidación.

Configuración: `scripts/ConfigurarFechaTC.sql` (concepto `FECHA_TC` y el cambio de las dos Fuentes).
Ver [[Grossing-up y tipo de cambio]].
