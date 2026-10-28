---
tipo: guia
tags: [ejemplos, conceptos, formulas, acumuladores]
fuente: [GUIA-LIQUIDACION.md, src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50077.GestionVariablesSistema.al, src/Codeunits/Cod50014.MotorLiquidacion.al]
actualizado: 2026-10-04
---

# Ejemplos completos de conceptos

Recetas de conceptos, con la configuración de campos de [[Configurar un concepto (guía paso a paso)]]. Se separan en **didácticos** (reescritos de la guía original con la sintaxis que hoy acepta el evaluador: **decimales con punto**, coma = separador de argumentos) y **reales** (fórmulas que hoy están, o estuvieron, en producción según las lecciones del proyecto).

> [!warning] Los nombres de parámetro y de acumulador de los didácticos son ilustrativos
> Antes de copiar un ejemplo, comprobar en el **Asistente de Fórmulas** (*Cargar catálogo completo*) que cada variable existe en *tu* base. Correcciones de la guía original: la variable de sistema se llama **`AÑOS_ANTIGUEDAD`** (con Ñ, no `ANIOS_`), los días de navegación de la marea son **`DIAS_PROYECTO`** (hay además `DIAS_PUERTO` y `DIAS_MAREA` = navegación + puerto) y los códigos de concepto se referencian con `@` o `#`, no escritos pelados.

## Didácticos

### 1. Sueldo básico (haber remunerativo)

| Campo | Valor |
|---|---|
| Tipo Concepto / Aplica A | Haber Remunerativo / Todos |
| Orden Cálculo | 10 |
| Fórmula | `BASICO * PCT_ESCALA` |
| Condición | *(vacía: siempre aplica)* |
| Distribución | `REMUNERATIVO_BRUTO` 100, `BASE_SS` 100, `BASE_OS` 100, `BASE_SINDICAL` 100, `BASE_LRT` 100, `BASE_IG4` 100, `BASE_SAC` 100 |

`BASICO` es un parámetro con valores por convenio y categoría ([[Configurar un parámetro y su vigencia]]); `PCT_ESCALA` es la variable de sistema "porcentaje de escala de la Categoría CCT, dividido 100".

### 2. Antigüedad con condición

| Campo | Valor |
|---|---|
| Orden Cálculo | 50 (**mayor** que el del básico, si lo lee con `#`) |
| Fórmula | `#1003 * AÑOS_ANTIGUEDAD * PCT_ANTIG` |
| Condición | `AÑOS_ANTIGUEDAD >= 1` |
| Distribución | la misma que el básico |

`#1003` lee el importe **ya calculado** del concepto 1003 (no re-evalúa su fórmula). Para la antigüedad que de verdad se usa, ver el ejemplo real **R1**.

### 3. Aporte con tope (Seguridad Social)

| Campo | Valor |
|---|---|
| Tipo Concepto | Seguridad Social (suma a **Total Descuentos**) |
| Orden Cálculo | **mayor** que todos los conceptos que aportan a `BASE_SS` |
| Fórmula | `MIN(BASE_SS, TOPE_SIPA) * 0.11` |

Si `BASE_SS` todavía no recibió todos sus aportes cuando corre este concepto, **el aporte sale chico sin error**: es el caso de [[acumuladores-orden-calculo]]. Verificar con el *Control de Orden de Cálculo*. El SAC tiene sus propios conceptos con tope **mensual** que se agota ([[tope-sac-por-liquidacion]]).

### 4. Descuento con porcentaje por convenio

| Campo | Valor |
|---|---|
| Tipo Concepto | Descuento Empleado |
| Fórmula | `BASE_SINDICAL * PCT_CUOTA_SIND` |
| Convenios aplicables | los que correspondan (vacío = **todos**) |

`PCT_CUOTA_SIND` guarda la tasa como **fracción** (`0.025`). Ojo: en el proyecto conviven parámetros `PCT_` en dos unidades (unos piden `/100`, otros ya son fracción): ver [[parametros-somu-por-pesqueria]].

### 5. Ganancias 4.ª categoría con escala (tramos)

| Campo | Valor |
|---|---|
| Tipo Concepto | Retención |
| Fórmula | `TRAMO('TAB_IMP_4CAT', MAX(BASE_IG4 * 12 - MNI_ANUAL, 0)) / 12` |
| Condición | `BASE_IG4 * 12 > MNI_ANUAL` |
| Etiqueta Det. Ganancias | un texto, para que el recibo muestre el paso |

`TRAMO('código', valor)` busca en la **Tabla Escalonada** vigente a la fecha de referencia el tramo que contiene el valor y devuelve `Monto Fijo + % Excedente × (valor − Límite Inferior)`; el último tramo con *Límite Superior = 0* es "sin límite". Es el patrón mínimo; **la fórmula real de Ganancias es mucho más larga** (acumulados del año, retenido anterior, deducciones por familiar, SAC) y es la más larga del sistema. La página de detalle presenta la línea por etapas **sólo** si la escala se llama `TAB_IMP_4CAT` ([[Asistente de fórmulas y detalle del cálculo]]). Las trampas de Ganancias: [[retenido-true-importe-cero]], [[cuota-sindical-deducida-dos-veces]], [[embargo-cuota-alimentaria-como-retencion]].

### 6. Producción desde una Fuente de Datos

| Campo | Valor |
|---|---|
| Fórmula | `PROD_KB_L1` |
| Condición | `PROD_KB_L1 > 0` |
| Aplica A | Tripulante |

Requiere la fuente `PROD_KB_L1` de [[Configurar fuentes de datos]]. Para que una producción no se pague de más en un devengado, **no se prorratea**: ver [[produccion-no-se-prorratea]].

### 7. Concepto que sólo se carga como novedad (sin fórmula)

| Campo | Valor |
|---|---|
| Tipo Concepto | Descuento Empleado |
| Fórmula | *(vacía a propósito)* |

El importe sale **exclusivamente** de una novedad/incidencia ([[Novedades e incidencias - carga operativa]]). Es el patrón de los anticipos y recuperos ([[anticipos-como-novedades]]). Sin novedad no hay línea. Con importe en una novedad, **reemplaza** a cualquier fórmula que se le agregue después.

### 8. Acumulador

| Campo | Valor |
|---|---|
| Es Acumulador | Sí |
| Tipo Concepto | Informativo |
| Fórmula | *(ninguna)* |

Lo alimentan otros conceptos desde **su** subpágina *Distribución en acumuladores*; en la ficha del acumulador la subpágina *Conceptos que alimentan este acumulador* los lista. Se lee desde fórmulas como una variable (`BASE_SS`). Su valor es el **subtotal** hasta el orden del concepto que lo lee.

## Reales (de las lecciones del proyecto)

> [!note] Fórmulas citadas en lecciones; pueden haber cambiado
> Son las que figuran en las notas de [[Índice de lecciones]] a la fecha indicada. Antes de tocar un concepto real, **abrir la ficha**: el texto vigente manda.

### R1. Antigüedad (29/9/2026)

```
PRECIO_NAV / 30 * pct/100 * (DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO
                             + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO) * coeficiente
```

con el porcentaje elegido por `IFZERO(#PCT_ANTIG_OFICIALES, #PCT_ANTIG_SOMU)`. El coeficiente es el 30% del Dto. 633/18 (aunque el parámetro se llame `COEF_TANGONERO`/`COEF_POTERO`) ([[antiguedad-formula-explicita]], [[antiguedad-no-cuenta-dias-gp]], [[antiguedad-dia-por-fase]]).

### R2. Sueldo de feriado (30/9/2026)

```
BASE_FERIADO / (DIAS_MAREA + DIAS_GP_PERIODO) * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)
```

Es un **promedio diario**, no un precio ([[feriado-divide-por-30-fijo]]).

### R3. Precio en moneda extranjera

```
IF(PRECIO_PUERTO_LAN_ESFCY, PRECIO_PUERTO_LAN * TC_COMPRADOR, PRECIO_PUERTO_LAN)
```

`<PARÁMETRO>_ESFCY` vale 1 si la vigencia del parámetro tiene **Moneda** cargada: la fórmula decide convertir. Comprador para producción, vendedor para sueldos en moneda extranjera ([[que-tc-usa-cada-concepto]]).

### R4. Adicional por tareas mecánicas

```
round(#2499 * COEF_TANGONERO * PCT_TAR_MEC, PRECISION_REDONDEO)
```

`#2499` es la producción total; ya se corrigió para los días de guardia ([[adicional-tareas-mecanicas]]).

### R5. Cuota sindical sobre SAC devengado (propuesta medida el 3/10/2026)

```
round((BASE_SAC_DEV * IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND) / 100), 0.0001)
```

La base es **SAC devengado × pct**, sin dividir por 12 ([[sindical-sac-base-equivocada]]).

### R6. Cero explícito por novedad

Una novedad con importe y cantidad en cero **apaga** el concepto para un empleado puntual sin tocar la fórmula ni el convenio ([[novedad-en-cero-no-apagaba-el-concepto]]).

## Patrones útiles y trampas

| Quiero… | Escribo… | Cuidado |
|---|---|---|
| Que un parámetro faltante no anule el concepto | `IFZERO(PARAM_X, PARAM_Y)` | Un parámetro sin vigencia **vale 0 y multiplica por 0 sin avisar** |
| Evitar división por cero | `DIV(a, b)` | Devuelve 0 si `b = 0` |
| Elegir una rama | `IF(cond, a, b)` o `CASE(cond1, v1, cond2, v2, …, defecto)` | **Todos los argumentos del `IF` se evalúan** antes de elegir |
| Redondear | `ROUND(x, 0.01)` o `REDONDEAR(x, 2)` | `ROUND` con precisión 0 da error |
| Comparar un atributo de lista | `CONVENIO = '729/15'` | Código entre comillas, [[atributo-comparar-por-codigo]] |
| Usar lo que calculó otro concepto con **su** par convenio/categoría | `#CÓDIGO` (orden menor) | `@CÓDIGO` usa el par del que llama ([[arroba-ignora-el-par-del-concepto]]) |

Más recetas de errores en [[Resolución de problemas frecuentes]].

## Ver también

[[Tablas escalonadas]] · [[Evaluador de fórmulas - sintaxis]] · [[Rubros típicos de una liquidación embarcada]] · [[Producción y premios]]
