---
tipo: referencia
tags: [motor, variables, contexto]
fuente: [src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Tables/Tab60018.VariableSistemaLiq.al, src/Codeunits/Cod50077.GestionVariablesSistema.al, src/Codeunits/Cod110049.VariablesSistemaInstall.al, src/Codeunits/Cod110050.VariablesSistemaUpgrade.al]
actualizado: 2026-10-04
---

# Variables de sistema

Una **variable de sistema** (tabla `Variable Sistema Liq.`, 60018) ata un **`Cód. Cálculo`** —lógica fija
en AL— a un **`Nombre Variable`** configurable, que es el token que ven las fórmulas. La lógica está en
`ComputeVariableSistema` (Cod50016, un `case` sobre `Cód. Cálculo`); el nombre y los parámetros extra
(`Cód. Acumulador`, `Cód. Concepto`, `Tipo Concepto`, `Cód. Estado`) son datos. Por convención el nombre
arranca igual al código de cálculo, pero se puede renombrar sin tocar nada: el motor busca por
`Cód. Cálculo`.

Campos de la fila: `Cód. Cálculo`, `Nombre Variable` (PK, `Code[30]`), `Descripción`, `Activo`,
`Mostrar en Recibo`, `Etiqueta Recibo`, `Etiqueta Det. Ganancias` / `Orden Det. Ganancias` (si hay
etiqueta y hay `LiqNo`, el motor escribe un paso en `Detalle Ganancias Liq.`), y los cuatro de parámetro.

> [!warning] Dos lugares, tres si agregás un código
> Una variable vive en el `case` de `ComputeVariableSistema` **y** en una **fila** de la tabla. Sólo el
> código compila y publica, pero la primera fórmula que la use revienta con "Variable desconocida"
> (ver [[variable-sistema-hay-que-sembrarla]]). Y un código nuevo toca tres lugares:
> 1. el `case` (Cod50016),
> 2. la lista `Opciones` del `OnLookup` y el comentario de `Tab60018`,
> 3. `Gestión Variables Sistema.Sembrar` (Cod50077).
>
> Un `Cód. Cálculo` que el `case` no conoce vale **0** y agrega una **advertencia** (`AvisarCodigoDesconocido`); ya no es mudo.

## Catálogo completo (33 códigos del `case`)

### Calendario y período

| Cód. Cálculo | Qué devuelve |
|---|---|
| `AÑOS_ANTIGUEDAD` | antigüedad **fraccionaria** a `FechaRef` (`Gestión Estado Empleado`.`CalcAntiguedadFraccionAlFecha`) |
| `AÑOS_ANTIG_30JUN` | años **completos** de antigüedad al corte del 30/6 vigente (Art. 32 CCT): `CalcAntiguedadAl30Junio` |
| `DIAS_HAB` | días hábiles del **período entero** (lun-vie, o según el calendario del período) |
| `DIAS_MES` | días calendario del período (`Fecha Hasta − Fecha Desde + 1`; 31 en enero, 28 en febrero) |
| `DIAS_FERIADOS` | feriados del período: fechas **con entrada propia** `Nonworking` en el calendario, contados sólo si caen en la ventana de la liquidación (tramos). Calendario: el del **convenio** (`Cód. Calendario`) si lo tiene, si no el del período |
| `DIAS_HAB_AÑO` | días hábiles del año calendario de `FechaRef` |
| `DIAS_ALTA_AÑO` | días hábiles del año con el empleado de alta (Alta → Baja; los estados intermedios no cortan) |
| `MES_ANUAL` | mes calendario de `FechaRef` (1 a 12); sirve para anualizar YTD |
| `PCT_ESCALA` | `Categoría CCT."% Escala" / 100` del par (convenio, categoría) en uso; 0 si no existe. **La única que depende del par**: se recalcula en `UsarParCCT` |
| `TIPO_LIQ` | el **`Orden`** del tipo de liquidación (`Tipo Liquidación`); 0 si la liquidación no tiene tipo. Se devuelve el Orden y no el código porque las fórmulas son numéricas |

> [!warning] `TIPO_LIQ` = 0 es ambiguo
> Es el Orden de `SALDO_INICIAL`, pero también lo que da una liquidación vieja sin `Cód. Tipo Liq.`
> ([[migracion-tipo-liq-incompleta]]). Comparar contra cualquier otro orden sí distingue. La lección
> [[tipo-liq-no-implementada]] **ya no es cierta**: la variable existe en el `case` y en `Sembrar`.

### Marea (navegación, puerto, enrolamiento)

| Cód. Cálculo | Qué devuelve |
|---|---|
| `DIAS_PROYECTO` | días de **navegación** de la marea dentro de la ventana de la liquidación, con la regla AM/PM de zarpada y arribo (zarpe a las 12:00 o después → ese día es puerto; arribo a las 12:00 o después → ese día es navegación; corte de mes con la marea abierta → día de navegación entero) |
| `DIAS_PUERTO` | días de **puerto**: víspera (asignación anterior al zarpe) + zarpe PM + arribo AM |
| `DIAS_MAREA` | `DIAS_PROYECTO + DIAS_PUERTO` = ventana completa **del tripulante** sin huecos ni dobles. Existe para campos que piden un *nombre* (`Variable Base`) y no admiten la suma |
| `DIAS_FERIADOS_MAREA` | feriados dentro de la marea (a bordo), acotados por los tramos |
| `DIAS_FERIADOS_GUARDIA` | feriados a bordo **fuera de la marea** (guardia en puerto, dique, pilotaje): estados que devengan francos y no `Transcurre en Marea`. Complemento disjunto del anterior |
| `DIAS_ENROLAMIENTO` | días enrolados en **toda** la marea (no sólo la ventana) en estados `Devenga Francos`; base de `COEF_FRANCOS × días + 1` |

La **ventana del tripulante** (`VentanaEmpleadoEnMarea`) es `[Fecha Alta Asignación, Fecha Baja]` de `Personal Proyecto`, con las fechas del proyecto por defecto; la baja recorta pero no estira. Las tres (navegación, puerto, enrolamiento) parten de la misma ventana para que no se separen.

### Francos

| Cód. Cálculo | Qué devuelve |
|---|---|
| `DIAS_FRANCOS_PERIODO` | días calendario en estado de `Tipo Estado = Francos` dentro de los tramos de la liquidación |
| `FRANCOS_CONSUMIDOS` | `MIN(días en Francos, saldo disponible)` (FIFO, excluye esta liquidación) |
| `PAGO_FRANCOS_FIFO` | importe de esos francos, cada lote a su propio valor |
| `SALDO_FRANCOS` | devengados menos consumidos, excluyendo esta liquidación |

Delegan en `Gestión Francos` (Cod50053) pasando `FLiqNo` para excluir la liquidación en curso. Ver [[francos-fifo-ledger]].

### Vacaciones, ausencias y estados

| Cód. Cálculo | Parámetro | Qué devuelve |
|---|---|---|
| `VACACIONES_ANUALES` | — | 14 / 21 / 28 / 35 días según antigüedad **al 31/12** del año de `FechaRef` (`< 5`, `< 10`, `< 20`, `≥ 20` años) |
| `VACACIONES_PROP_DIAS` | — | `PISO(DIAS_ALTA_AÑO / 20)` (1 día cada 20 hábiles, truncado) |
| `DIAS_VAC_PERIODO` | — | días en estado `Vacaciones` dentro de la ventana, **topeados por el derecho** (`CalcDiasVacaciones`) |
| `MESES_PROM_VAC` | — | meses (0 a 6) con alguna fase de alta en el semestre anterior al mes de inicio de la licencia; divisor del promedio del Art. 34 CCT. Sin fases cargadas devuelve 6 |
| `MESES_PROM_AUS_6` / `MESES_PROM_AUS_12` | — | idem para el promedio de ausentismo (6 meses para 175/75, 12 para 729/15 y 768/19), anclado en el inicio de la licencia con `Promedia Ausencia` |
| `DIAS_ESTADO_PERIODO` | `Cód. Estado` | días en **ese** estado dentro de los tramos (`DIAS_ENFERMEDAD`→AU1, `DIAS_ACCIDENTE`→ACC) |
| `DIAS_ESTADO_PREVIOS` | `Cód. Estado` | días en ese estado **anteriores al período**, desde el inicio de la licencia en curso (art. 13 LRT: 10 días del empleador, del 11 la ART). 0 si la licencia empieza en este período |

Ver [[ventana-promedio-ausentismo]] y [[accidente-empleador-y-art]].

### Ganancias

| Cód. Cálculo | Qué devuelve |
|---|---|
| `DEDUC_GANANCIAS` | deducciones anuales: cargas de familia (fracción por tipo × valor vigente del parámetro del tipo) + gastos deducibles fijos (`Ded. Ganancias Empleado`). Escribe filas `Familiar` y `Gasto` en `Detalle Ganancias Liq.` |

Un familiar deduce sólo si tiene **fecha de alta a efectos del impuesto** ≤ `FechaRef`, sin baja o con baja ≥ inicio de la ventana, y dentro del tope de edad del tipo (`Parámetro."Edad Máxima Familiar"`, 0 = sin tope; el mes del cumpleaños cuenta). El `% Deducción` es el coeficiente (vacío = 100). Ver [[familiar-alta-impuesto]].

### Acumulados históricos

| Cód. Cálculo | Parámetro | Qué suma |
|---|---|---|
| `YTD_ACUM` | `Cód. Acumulador` | lo liquidado en el **año** (1/1 a `FechaRef`, por `Fecha Liquidación`) por los conceptos que alimentan ese acumulador, excluyendo Borrador y esta liquidación |
| `PERIODO_ACUM` | `Cód. Acumulador` | lo mismo acotado al **código de período** de esta liquidación y **excluyendo** la actual; es el tope mensual (SIPA) para el empleado con varias liquidaciones en el mes |
| `PERIODO_CONCEPTO` | `Cód. Concepto` | lo ya liquidado de **un** concepto en el **mes** (todos los períodos del mismo mes: `MENS072026` y `MENS072026B`), sin acumulador dedicado |
| `YTD_LINEAS` | `Tipo Concepto` | suma anual de líneas por `Tipo Concepto` (sin excluir nada más que Borrador) |

Varias filas pueden compartir el mismo `Cód. Cálculo` con acumuladores distintos (`HAB_GRAV_ANUAL`→`BASE_IG4`, `HAB_EXTORD_ANUAL`→`BASE_EXT_IG4`).

> [!warning] En `YTD_ACUM`/`PERIODO_ACUM` cada concepto cuenta **una vez** y con la fracción **más vieja** vigente
> `CalcImporteAnualPorAcumulador` recorre `Fracción Acumulador` en orden de `Vigencia Desde` ascendente
> y toma la primera fila de cada concepto (`Procesados`), así que el `Invertir Signo` que aplica ahí es el
> de la vigencia **más antigua** a `FechaRef`, mientras que el aporte durante el cálculo
> (`BuildFractionCache`) usa la **más reciente**. Si una fracción cambia de signo entre vigencias, los dos
> caminos discrepan. Lo señala también la `REVISION_RENDIMIENTO_2026-09-18.md`. Sin verificar contra datos.

## Siembra

`Gestión Variables Sistema.Sembrar()` (Cod50077) agrega **lo que falte**, idempotente **por `Cód. Cálculo`** (no por nombre, que es renombrable) y sin tocar filas existentes. Corre solo en **Install** y **Upgrade** (Cod110049/Cod110050).

> [!warning] Un publish de RAD no dispara Upgrade
> En desarrollo hay que usar la acción **Sembrar** de la página *Variables de Sistema* (Pag50146) o insertar la fila a mano.

No se siembran con nombre propio: `YTD_ACUM`, `PERIODO_ACUM`, `PERIODO_CONCEPTO`, `YTD_LINEAS`, `DIAS_ESTADO_PERIODO`, `DIAS_ESTADO_PREVIOS` (necesitan su parámetro; sin él darían 0 mudo). Para estados se siembran `DIAS_ENFERMEDAD` (AU1), `DIAS_ACCIDENTE` (ACC) y `DIAS_ACC_PREVIOS` (ACC, `DIAS_ESTADO_PREVIOS`), **sólo si el estado existe** en el catálogo.

> [!note] Divergencias internas halladas (4/10/2026)
> - `DIAS_MES` está en el `case` pero **no** en `Sembrar` ni en la lista `Opciones` del `OnLookup` de `Cód. Cálculo`.
> - `MESES_PROM_AUS_6`, `MESES_PROM_AUS_12`, `DIAS_ESTADO_PERIODO` y `DIAS_ESTADO_PREVIOS` están en el `case` pero **no** en `Opciones`. (Los dos primeros sí en `Sembrar`.)
> - La lección [[variables-rotas-valen-cero]] dice que `AÑOS_ANTIG_30JUN` y `MESES_PROM_AUS_*` no tienen `case`: **hoy sí lo tienen** en el código; si las filas siguen valiendo 0, el problema es el `Cód. Cálculo` cargado en la fila, no el AL.

## Variables que **no** son de sistema pero el motor siempre inyecta

`ES_GROSSING_UP`, `NETO_GARANTIZADO`, `COMPLEMENTO_GU`, `COD_ZONA`, `ES_JUBILADO`, `CANT_INCIDENCIA`: ver [[Contexto de liquidación y variables]]. El catálogo del editor agrega además `NETO_GARANTIZADO_ESFCY`, que el motor **no** siembra (sin verificar si alguna fórmula la usa).

## Relacionado

[[Contexto de liquidación y variables]] · [[Acumuladores y fracciones]] · [[system-variables-conventions]] · [[Tabla - Variable Sistema Liq]]

**Tablas relacionadas:** [[Tabla - Cód. Estado Empleado]] · [[Tabla - Estado Empleado]] · [[Tabla - Fase Alta Empleado]] · [[Tabla - Ded. Ganancias Empleado]] · [[Tabla - Ded. Ganancias Vigente]]
