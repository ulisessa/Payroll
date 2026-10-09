---
tipo: codeunit
tags: [motor, contexto, variables]
fuente: [src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod110051.NombresVariablesLiq.al, src/Codeunits/Cod50060.CatalogoVariablesLiq.al]
actualizado: 2026-10-04
---

# Contexto de liquidación y variables

`Contexto Liquidación` (Cod50016) construye el **diccionario `Dictionary of [Text, Decimal]`** que ve el
evaluador. La fórmula siempre ve **números**: lo que no es numérico (códigos de lista, textos, fechas) se
proyecta a número y se guarda *además* en su forma original para auditar e imprimir.

## Ciclo de vida

```mermaid
sequenceDiagram
    participant M as Motor
    participant C as Contexto (50016)
    participant E as Evaluador
    M->>C: Init(empleado, proyecto, período, FechaRef, convenio, categoría, LiqNo, tipo, CoberturaDesde)
    Note over C: limpia TODO lo de la liquidación anterior<br/>(acumulados, mapas de parámetros, fin efectivo, caché por par)
    M->>C: BuildContext(Ctx)
    C-->>M: Ctx lleno
    M->>M: InjectGUVariables / InjectZonaDesfavorable
    M->>E: Init(Ctx, FechaRef)
    loop por concepto
        M->>E: evalúa
        M->>M: Ctx[código concepto] = importe; acumuladores += aporte
        M->>E: UpdateContext(Ctx)
    end
```

- El mismo codeunit se **reutiliza** en un lote, por eso `Init` limpia todo: sin eso, los totales de un
  tripulante pasarían al siguiente.
- `Init` fija la ventana: `FPeriodoFechaDesde := CoberturaDesde` si la liquidación la tiene; si no, el inicio del período; si no, `FechaRef`. **La ventana es la de la liquidación, no la del período** (un cierre de marea no ve los días previos al embarque). Ver [[ventana-liquidacion-es-cobertura]].
- También carga los **tramos de cobertura** (`Tramo Cobertura Liq.`); con tramos, las variables de período cuentan días contra cada tramo (`DiasEnLaVentana`, `DiaEnLaVentana`); sin tramos, contra `[FPeriodoFechaDesde, FFechaRef]`. Ver [[cobertura-en-tramos]].

## Orden de armado de `BuildContext`

```
Clear(Ctx)
1. LoadParametros            ← todos los Parámetro con Nombre Variable (+ <VAR>_ESFCY)
2. LoadVariablesSistema      ← las Variable Sistema Liq. con Activo = true
3. LoadDynamicSources        ← las Fuente Datos Liquidación con Activo = true
4. LoadAtributos             ← los Tipo Atributo Liq. con Nombre Variable
5. InitAccumulators          ← los conceptos Es Acumulador vigentes, en 0
```

Después, el **motor** agrega/pisa:

| Momento | Variable | Cómo |
|---|---|---|
| `InjectGUVariables` | `ES_GROSSING_UP`, `NETO_GARANTIZADO`, `COMPLEMENTO_GU` | `Set` en 0 (pisa lo que hubiera) |
| `InjectZonaDesfavorable` | `COD_ZONA` | sólo si **no existe** (una Fuente o Parámetro llamado `COD_ZONA` manda); si no, del proyecto (`Zona Desfavorable > 0`) o de la ficha del empleado |
| idem | `ES_JUBILADO` | `Set`: 1 si `Employee."Fecha Jubilación" <> 0D` y `<= FechaRef` |
| idem | `CANT_INCIDENCIA` | `Add` en 0 si no existe; `RunConceptos` le pone la cantidad de la incidencia del concepto en curso |
| `RunConceptos` | `<código de concepto>` | tras generar la línea: `Ctx[Código] = Importe`, para que `#CÓDIGO` lo lea |
| `ResolverNetoGarantizado` | `NETO_GARANTIZADO`, `ES_GROSSING_UP` | si el concepto objetivo da > 0 |

## Qué gana cuando un nombre se repite

El espacio de nombres es **plano**. Dos orígenes con el mismo nombre no dan error: se pisan.

| Caso | Gana | Por qué |
|---|---|---|
| Parámetro vs. Parámetro (mismo `Nombre Variable`) | el **último por código** | `Ctx.Set` en `LoadParametros`. Ver [[dos-parametros-mismo-nombre]] |
| Parámetro vs. Variable de Sistema vs. Fuente de Datos | el **último** en el orden Parámetro → Sistema → Fuente | `Ctx.Set` sin condición |
| Cualquiera vs. Atributo | el **no-atributo** | `LoadAtributos` salta si el nombre ya está **y no carga su código de lista** (la comparación por código falla). Ver [[parametro-y-atributo-mismo-nombre]] |
| Cualquiera vs. Acumulador (código de concepto) | el **acumulador, en 0** | `InicializarAcumulador` fuerza 0 aunque otro origen haya sembrado el nombre |
| `UsarParCCT` (par alterno) | el **parámetro** | recarga **sólo** parámetros: si una Fuente le había pisado el nombre, el parámetro vuelve a ganar *a mitad del cálculo*. Fue el caso `TC_COMPRADOR`: ver [[tc-comprador-parametro-fantasma]] |
| Variable vs. código de concepto calculado | el **concepto** | `Ctx[Código]` se escribe después de calcular el concepto |

Para que esto no pase se creó `Nombres Variables Liq.`.`ExigirLibre`: al dar de alta un `Nombre Variable` en Parámetro, Variable Sistema, Fuente de Datos o Tipo de Atributo, corta si ya lo usa otro (incluye `<VAR>_ESFCY`). Lo ya duplicado se lista con `Duplicados()`; `Catálogo Variables Liq.`.`NombresEnConflicto` además mira los **códigos de concepto**. Ver [[Nombres de variables y conflictos]].

## Los cinco orígenes

### 1. Parámetros — `LoadParametros`

Para cada `Parámetro` con `Nombre Variable`:

1. `BuildParametroCache`: **una sola pasada** por `Parámetro Vigente` con `Vigencia Desde <= FFechaRef` (clave `Cód. Parámetro, Vigencia Desde`); queda la última vigencia por **clave efectiva**.
2. `ResolverCodigoEfectivo` → `Claves Parámetro Liq.`.`Resolver`: cascada `COD_<empleado> → COD_<convenio>_<categoría> → COD_<convenio> → COD`, gana la primera con valor. Sin ninguna → valor `0`, sin vigencia.
3. Se escribe `Ctx[Nombre] = valor` y `Ctx[Nombre_ESFCY] = 1` si la fila tiene `Moneda`, `0` si no. El primer parámetro con moneda que se recorre fija `FMoneda` (la moneda del grossing-up; ver [[Grossing-up y tipo de cambio]]).
4. Avisos: sin ningún valor para la base → "no tiene ningún valor cargado"; con `Antigüedad Máxima Vigencia` y versión más vieja que `CalcDate(fórmula, FechaRef)` → "desactualizado". Ver [[Avisos y advertencias del cálculo]].
5. Se registran `FParamBaseMap/CodMap/VigMap` para poder marcar `En Uso` después.

Detalle completo en [[Parámetros y vigencias]].

### 2. Variables de sistema — `LoadVariablesSistema`

Cada fila activa llama a `ComputeVariableSistema` (un `case` sobre `Cód. Cálculo`). Si la fila tiene `Etiqueta Det. Ganancias` y hay `LiqNo`, escribe una fila `Paso` en `Detalle Ganancias Liq.`. Catálogo completo en [[Variables de sistema]].

### 3. Fuentes de datos — `LoadDynamicSources`

Cada fuente activa: aviso si no tiene filtros, `ResolveFuente`, `Ctx.Set`. Detalle en [[Fuentes de datos]] y [[Tokens de filtro de fuentes de datos]].

### 4. Atributos — `LoadAtributos`

Para cada `Tipo Atributo Liq.` con `Nombre Variable` que **no esté ya** en el contexto: resuelve la entidad (empleado → `FEmployeeNo`; proyecto → `FJobNo`; buque → `Job."Global Dimension 1 Code"`), busca el valor vigente a `FechaRef` (`Atributo Entidad Liq.`.`Vigente`), y pone su `Valor Numérico`. Guarda además `ValorParaMostrar()` y, si el atributo es de lista, su código en `FCodigosAtributos`. Sin atributo vigente: `0`. Ver [[atributos-tipados]].

### 5. Acumuladores — `InitAccumulators`

Todo concepto con `Es Acumulador = true` cuya **versión vigente** a `FechaRef` lo declare y esté en vigencia (`EsAcumuladorVigente`) arranca en `0`. Ver [[Acumuladores y fracciones]].

## Contexto para validación

`BuildContextParaValidacion` define **los mismos nombres en cero** (parámetros + `_ESFCY`, variables de sistema activas, fuentes activas, atributos, acumuladores) sin resolver nada. Es lo que usa la fase 1 del motor. Lo que se pierde: errores que sólo aparecen con ciertos valores salen en la fase 2.

## Mapas auxiliares que expone

| Método | Para qué |
|---|---|
| `GetTipoMap` | nombre → `'Atributo' \| 'Parámetro' \| 'Sistema' \| 'Fuente Datos' \| 'Acumulador'` |
| `GetValoresTexto` | nombre → valor en su tipo original (texto/fecha/código) para `Resumen Variable Liq.` |
| `GetCodigosAtributos` | nombre → código de lista (para comparaciones por código y para el detalle) |
| `GetParamLog` | entradas `FDS:`, `DED_FAM:` del contexto (van a `Fuente Parámetros`) |
| `GetAdvertenciasParametros` | avisos acumulados |
| `GetMoneda` | moneda del primer parámetro en divisa |

## Par convenio/categoría alterno

`UsarParCCT(convenio, categoría, Ctx)` recarga **sólo los parámetros** y `PCT_ESCALA` con otro par, y el motor la vuelve a llamar con el par original después del concepto. Mantiene una **caché de dos ranuras** (el par del empleado y el alterno) para no reconstruir la cascada por cada concepto marcado. Ver [[Par convenio-categoría por concepto]].

## Acumulados históricos (YTD y período)

Los acumuladores `YTD_*`/`PERIODO_*` se cargan agrupados por concepto **una vez** (`CargarAcumHistorico`) y se cachean hasta el próximo `Init`. Ver [[Variables de sistema]] y [[Rendimiento y caché del cálculo]].

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[Evaluador de fórmulas - sintaxis]] · [[system-variables-conventions]] · [[Tabla - Parámetro Vigente]]

**Tablas relacionadas:** [[Tabla - Variable Sistema Liq]] · [[Tabla - Fuente Datos Liquidación]] · [[Tabla - Tipo Atributo Liq]] · [[Tabla - Atributo Entidad Liq]] · [[Tabla - Tramo Cobertura Liq]]
