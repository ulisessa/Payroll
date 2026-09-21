# Tope SIPA por acumulado del período

Cambio de formulación de los aportes con tope (jubilación, ley 19032, obra social y su
adicional) para que el tope mensual se reparta correctamente entre las varias liquidaciones
que un empleado tiene en un mismo período.

## Por qué

Los acumuladores son **por liquidación**. La coordinación entre liquidaciones del mismo
período la hace hoy `MES_BASE_*` (variables `PERIODO_ACUM`), que suma las **otras**
liquidaciones excluyendo las que están en Borrador. Eso es correcto en la primera pasada y
en orden, pero **no es estable ante recálculo**: cada liquidación resta a las demás
suponiendo que ella es la última en calcularse.

Con dos liquidaciones de bases V y S en el mismo mes:

| momento | aporte VAC | aporte mensual | total |
|---|---|---|---|
| primera pasada, VAC primero | `MIN(V, TOPE)` | `MIN(S, TOPE−V)` | `MIN(V+S, TOPE)` ✔ |
| se recalcula la VAC | `MIN(V, TOPE−S)` | `MIN(S, TOPE−V)` | `2·TOPE−S−V` ✘ |

Cuando `S+V > TOPE` el segundo renglón retiene de menos. En enero 2026 hay 86 de 284
legajos con dos o más liquidaciones no-vacaciones en el mes (el patrón
`PUE + MAR + EMB` se repite decenas de veces), así que el caso expuesto es la mayoría,
no la excepción.

## La formulación nueva

En vez de repartir el tope por precedencia, cada liquidación calcula el aporte sobre el
**acumulado del período** y descuenta **lo ya retenido**:

```
aporte = MAX(0, MIN(base_del_período, TOPE) * PCT − ya_retenido_en_el_período)
```

Es independiente del orden de cálculo e idempotente ante recálculo: lo ya retenido es un
hecho registrado, no algo que cada liquidación recalcula. Con tres bases a, b, c cada
liquidación aporta su incremento sobre el tope acumulado y la suma da `MIN(a+b+c, TOPE)·PCT`
en cualquier orden; al recalcular la primera, vuelve a dar exactamente lo mismo que daba.

## 1. Acumuladores nuevos

Conceptos con `Es Acumulador = true`, sin fórmula, sin convenios (aplican a todos).
Guardan el importe ya retenido de cada familia.

| Código | Descripción |
|---|---|
| `JUB_LIQUIDADO` | Acum: Jubilación liquidada |
| `L19032_LIQUIDADO` | Acum: Ley 19032 liquidada |
| `OS_LIQUIDADO` | Acum: Obra social liquidada |
| `ADIC_OS_LIQUIDADO` | Acum: Adicional obra social liquidado |

## 2. Fracciones (100%)

| Concepto | Acumulador |
|---|---|
| 6000, 6003 | `JUB_LIQUIDADO` |
| 6010, 6013 | `L19032_LIQUIDADO` |
| 6030, 6035 | `OS_LIQUIDADO` |
| 6032, 6037 | `ADIC_OS_LIQUIDADO` |

## 3. Variables de sistema

`Cód. Cálculo = PERIODO_ACUM`, con el acumulador correspondiente. Mismo patrón que las
cuatro `MES_BASE_*` que ya existen.

| Nombre Variable | Cód. Acumulador |
|---|---|
| `MES_JUB_LIQUIDADO` | `JUB_LIQUIDADO` |
| `MES_L19032_LIQUIDADO` | `L19032_LIQUIDADO` |
| `MES_OS_LIQUIDADO` | `OS_LIQUIDADO` |
| `MES_ADIC_OS_LIQUIDADO` | `ADIC_OS_LIQUIDADO` |

## 4. Fórmulas

Cargar como **vigencia nueva** de cada concepto, no editando la vigente: las liquidaciones
ya calculadas tienen que poder reproducirse con la fórmula que usaron.

La condición de la variante regular suma `AND (BASE_*_VAC = 0)`. Hoy ambas pueden dispararse
en la misma liquidación y eso es correcto, porque cada una grava su propia base; con la
fórmula nueva las dos calculan sobre el total del período, así que dispararlas juntas
duplicaría. En producción nunca coinciden — es un cinturón de seguridad.

### 6000 Jubilación
Condición: `(BASE_SS_TRAB > 0) and (BASE_SS_VAC = 0)`
```
round(
    MAX(0,
        MIN(BASE_SS_TRAB + BASE_SS_VAC + MES_BASE_SS_TRAB + MES_BASE_SS_VAC, TOPE_SIPA) * PCT_JUB
        - MES_JUB_LIQUIDADO
    ),
    0.0001
)
```

### 6003 Jubilación vacaciones
Condición: `BASE_SS_VAC > 0`  · misma fórmula que 6000.

### 6010 Ley 19032
Condición: `(BASE_SS_TRAB > 0) and (BASE_SS_VAC = 0) and (ES_JUBILADO = 0)`
```
round(
    MAX(0,
        MIN(BASE_SS_TRAB + BASE_SS_VAC + MES_BASE_SS_TRAB + MES_BASE_SS_VAC, TOPE_SIPA) * PCT_19032
        - MES_L19032_LIQUIDADO
    ),
    0.0001
)
```

### 6013 Ley 19032 vacaciones
Condición: `(BASE_SS_VAC > 0) and (ES_JUBILADO = 0)`  · misma fórmula que 6010.

> Cambia el criterio: hoy 6013 condiciona por `DIAS_VAC_INICIO > 0` mientras 6003 y 6035
> usan la base de la liquidación. Unificar en la base, que es por liquidación.
> `DIAS_VAC_INICIO` y `DIAS_VAC_PERIODO` son del período y dan >0 también en la mensual.

### 6030 Obra social
Condición: `(BASE_OS_TRAB > 0) and (BASE_OS_VAC = 0) and (ES_JUBILADO = 0)`
```
round(
    MAX(0,
        MIN(BASE_OS_TRAB + BASE_OS_VAC + MES_BASE_OS_TRAB + MES_BASE_OS_VAC, TOPE_SIPA_OS) * PCT_OS
        - MES_OS_LIQUIDADO
    ),
    0.0001
)
```

### 6035 Obra social vacaciones
Condición: `(BASE_OS_VAC > 0) and (ES_JUBILADO = 0)`  · misma fórmula que 6030.

### 6032 Adicional obra social
Condición: `(BASE_OS_TRAB > 0) and (BASE_OS_VAC = 0) and (ES_JUBILADO = 0)`
```
round(
    MAX(0,
        MIN(BASE_OS_TRAB + BASE_OS_VAC + MES_BASE_OS_TRAB + MES_BASE_OS_VAC, TOPE_SIPA_OS)
            * PCT_ADICIONAL_OS / 100 * FAM_ADIC_OS
        - MES_ADIC_OS_LIQUIDADO
    ),
    PRECISION_REDONDEO
)
```
> 6032 está hoy `Activo = false` aunque aparece en 3 recibos de enero. Decidir si se
> reactiva antes de cargar la vigencia nueva.

### 6037 Adicional obra social vacaciones
Condición: `(BASE_OS_VAC > 0) and (ES_JUBILADO = 0)`  · misma fórmula que 6032.
> Su fórmula actual —`MIN(BASE_SAC, TOPE_SIPA_OS) * PCT_ADICIONAL_OS`— lee la base del
> **aguinaldo** en un concepto de vacaciones, y le falta el `/100 * FAM_ADIC_OS` que sí
> tiene 6032. Es la fórmula semilla de 2023 que quedó sin actualizar. Ver punto 6.

## 5. Qué NO cambia, y por qué

- **Cuota sindical (8522 / 8525)**: no tienen tope. `BASE_SINDICAL * PCT_CUOTA_SIND` ya es
  correcto y es insensible al orden.
- **Contribuciones patronales (7000, 7010, 7030, 7050)**: no usan `TOPE_SIPA`. Las
  contribuciones patronales no tienen tope desde 2008 y las fórmulas ya lo reflejan.
- **Conceptos de SAC (6002, 6012, 6034, 6036)**: el SAC tiene su propio tope legal
  (medio tope sobre la mejor remuneración), separado del mensual. No entran en este esquema.

## 6. Problemas adyacentes detectados (no incluidos en este cambio)

Los encontré verificando lo anterior. Cada uno necesita su propia decisión.

1. **`BASE_SS` y `BASE_OS` son códigos borrados** y siguen recibiendo fracciones: 147 y 137
   conceptos respectivamente, contra 43 y 44 que alimentan los códigos vivos `BASE_SS_TRAB`
   y `BASE_OS_TRAB`. Ese importe no entra a ninguna base. Es lo único de todo esto que
   mueve el neto hoy. Hay `scripts/LimpiarFraccionesHuerfanas.sql`, pero **borra sin
   reapuntar**: correrlo antes de crear las fracciones nuevas lleva las bases de bajas a cero.
2. **`gen_config.ps1` regenera el problema**: su `$ACC_NAMES` (línea 40) todavía lista
   `BASE_SS` y `BASE_OS`. Una instalación nueva nace con los huérfanos.
3. **`IMPO_CNT_SS`**: 149 fracciones a un acumulador que tampoco existe como concepto.
4. **7030 Contrib. patronal obra social** lee sólo `BASE_OS_TRAB`. En una liquidación de
   vacaciones da cero: falta la contribución patronal sobre vacaciones.
5. **6012 Ley 19032 SAC** lee `BASE_SS_TRAB` y divide por 12, en vez de leer `BASE_SAC`.
6. **6037** — ver arriba.

7. **El motor fija por nombre tres registros que son configuración.** El motor es dueño
   legítimo de los *tipos* —`Cód. Cálculo` (`PERIODO_ACUM`, `YTD_ACUM`, `PCT_ESCALA`) y
   `Función Agregado` (`DURACION_INICIO`, `DIAS_OVERLAP`)—: ése es el vocabulario. Pero
   tiene a fuego tres *instancias*, que son nombres que eligió quien configuró:

   | Token | Qué es | Dónde |
   |---|---|---|
   | `DIAS_VAC_INICIO` | Fuente Datos | `Cod50014:1791-1793` |
   | `NETO_GU` | Parámetro | `Cod50014:1756-1759` |
   | `BASE_IG4` | Acumulador (concepto) | `Cod50014:198-199` |

   Renombrar cualquiera de los tres en la configuración rompe el motor, y en dos casos en
   silencio: el `ContainsKey` da false y el cálculo sigue sin esa parte. `TAB_IMP_4CAT` y
   `RET_4CAT` aparecen sólo en tooltips y comentarios de ejemplo — ahí no hay acoplamiento.

   `DIAS_VAC_INICIO` es el peor de los tres porque además del nombre fija la regla:
   `NetoObjetivo + NetoObjetivo * dias / 150`. Ese 150 es el diferencial del Art. 155 entre
   pagar a /25 y a /30 (`dias × (1/25 − 1/30) = dias/150`), así que hay tres cosas a fuego:
   el nombre, el divisor de vacaciones y el del mes. Un convenio con otro divisor no se
   puede configurar.

   El patrón para resolverlo ya está en el repo: `TabExt52001.HRSetupLiqExt.al:31` define
   `"Cód. Estado Alta Sinc."`, un campo de setup que nombra el registro de configuración que
   el motor necesita, con error explícito cuando no está definido. Tres campos equivalentes
   en Config. RRHH (más el divisor como parámetro) sacan el acoplamiento y convierten el
   fallo silencioso en un mensaje que dice qué falta cargar.

## 7. Nota sobre los nombres usados

Los cuatro nombres nuevos (`*_LIQUIDADO` y `MES_*_LIQUIDADO`) son configuración pura:
`PERIODO_ACUM` es el `Cód. Cálculo` que el motor tiene a fuego, pero el `Nombre Variable`
es libre. No agregan dependencia de código.

De los nombres que arrastran las fórmulas existentes:

| Token | Origen | Riesgo |
|---|---|---|
| `ES_JUBILADO` | inyectado siempre por el motor (`Cod50014:1745`) | ninguno |
| `PRECISION_REDONDEO`, `TOPE_SIPA*`, `PCT_*` | Parámetro con vigencia | ninguno |
| `BASE_*`, `MES_BASE_*` | Acumulador / Variable Sistema | ninguno |
| `FAM_ADIC_OS` (en 6032/6037) | Fuente Datos (tabla 5205, activa) | ninguno |

`DIAS_VAC_INICIO` sale de una **Fuente de Datos** y el motor lo busca por nombre fijo
(`Cod50014:1788-1792`), guardándolo con `ContainsKey` porque puede no existir. En una
**condición** no hay guarda: si la fuente no trae valor, `TryEvalCondicion` falla y el
cálculo del concepto se cae con `ErrConceptoFalló`. Reemplazarlo por `BASE_*_VAC` — que es
un acumulador, siempre presente — saca esa dependencia además de arreglar el alcance.

> ~~Fuente Datos Liquidación no viaja en el ConfigPackage.~~ **Resuelto el 7/9/2026**: el
> export nuevo incluye `Fuente Datos Liquidación` (32 filas) y `Filtro Fuente Datos
> Liquidación` (76). Con eso `FAM_ADIC_OS` queda verificado y los 21 tokens sin resolver
> bajaron a uno real: `GARANTIA_MAREA` y `PROD_MAREA`, en la fórmula de 1223 (hoy inactivo).
