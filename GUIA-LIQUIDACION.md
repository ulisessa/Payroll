# Guía de Uso — Sistema de Liquidación de Sueldos Pesca

Sistema paramétrico de liquidación para la industria pesquera argentina. Permite definir conceptos de sueldo mediante fórmulas configurables sin modificar código, con soporte para múltiples CCTs, tipos de liquidación y fuentes de datos externas.

---

## Índice

1. [Acceso y perfiles](#acceso-y-perfiles)
2. [Conceptos fundamentales](#conceptos-fundamentales)
3. [Referencia de tablas del sistema](#referencia-de-tablas-del-sistema)
   - [Dominio de configuración](#dominio-de-configuración)
   - [Dominio del empleado](#dominio-del-empleado)
   - [Dominio transaccional](#dominio-transaccional)
4. [Liquidaciones de marinería (Devengados y Cierre Marea)](#liquidaciones-de-marinería-devengados-y-cierre-marea)
5. [Configuración inicial](#configuración-inicial)
6. [Declaración de conceptos y fórmulas](#declaración-de-conceptos-y-fórmulas)
7. [Variables disponibles en fórmulas](#variables-disponibles-en-fórmulas)
8. [Funciones incorporadas](#funciones-incorporadas)
9. [Acumuladores y Fracción Acumulador](#acumuladores-y-fracción-acumulador)
10. [Tablas escalonadas (tramos)](#tablas-escalonadas-tramos)
11. [Gestión de versiones](#gestión-de-versiones)
12. [Fuentes de datos dinámicas](#fuentes-de-datos-dinámicas)
13. [Incidencias manuales](#incidencias-manuales)
14. [Flujo operativo de liquidación](#flujo-operativo-de-liquidación)
15. [Ejemplos completos de conceptos](#ejemplos-completos-de-conceptos)
16. [Resolución de problemas](#resolución-de-problemas)

---

## Acceso y perfiles

El sistema expone dos perfiles de BC:

| Perfil | Role Center | Uso |
|---|---|---|
| **Payroll Manager** | Liquidación de Sueldos | Operación diaria: liquidar, aprobar, imprimir |
| **Director de TI** | IT Manager + sección Payroll | Configuración completa + operación |

La barra de navegación del Role Center contiene las secciones **Liquidaciones**, **Convenios**, **Parámetros**, **Empleados** y **Herramientas**.

---

## Conceptos fundamentales

El motor ejecuta **conceptos** en orden numérico (`Orden Cálculo`). Cada concepto tiene una fórmula evaluada con las variables del contexto. El resultado se clasifica según el tipo:

| Tipo | Efecto en el recibo |
|---|---|
| **Haber Remunerativo** | Suma al bruto remunerativo y bases imponibles |
| **Haber No Remunerativo** | Suma al neto; no cuenta para aportes |
| **Seguridad Social** | Aportes previsionales del empleado (SIPA, OS) |
| **Descuento Empleado** | Deducciones no previsionales (sindical, anticipos, embargos) |
| **Retención** | Retención fiscal (4ª categoría, embargos judiciales) |
| **Contribución Patronal** | Costo patronal; no aparece en el recibo del empleado |

**Regla clave de orden:** un concepto solo puede referenciar acumuladores actualizados por conceptos anteriores. Planificar el orden antes de declarar fórmulas. Dejar huecos (10, 20, 30…) para poder intercalar conceptos sin renumerar.

---

## Referencia de tablas del sistema

El sistema está compuesto por tres dominios de tablas con responsabilidades bien delimitadas. Las tablas de **configuración** definen las reglas del cálculo y no cambian en operación normal. Las del **empleado** describen quién cobra qué y en qué condición. Las **transaccionales** registran el resultado de cada cálculo y son de solo escritura una vez aprobadas.

```
CONFIGURACIÓN ──────────────────────────────────────────────────────────
Convenio Colectivo → Categoría CCT
Parámetro → Parámetro Vigente
Variable Sistema Liq.
Concepto Liquidación → Concepto CCT Vigente
                     → Fracción Acumulador
Tabla Escalonada → Tabla Escalonada Det.
Fuente Datos Liquidación

EMPLEADO ────────────────────────────────────────────────────────────────
Cód. Estado Empleado → Estado Empleado
Personal Proyecto
Ded. Ganancias Vigente
Ded. Ganancias Empleado

TRANSACCIONAL ───────────────────────────────────────────────────────────
Período Liquidación
Liquidación → Línea Liquidación → Detalle Variable Línea Liq.
            → Incidencia Liquidación
```

---

### Dominio de configuración

---

#### Convenio Colectivo

**Función:** Catálogo de acuerdos colectivos de trabajo (CCTs) reconocidos por el sistema. Define el universo de convenios para los que pueden configurarse conceptos, categorías y parámetros.

**Datos que contiene:** código corto (ej. `729/15`), descripción, número oficial de homologación, sindicato firmante.

**Rol en el cálculo:** El motor filtra los conceptos aplicables a la liquidación usando el `Cód. Convenio` asignado al empleado en `Personal Proyecto`. Solo se calculan los conceptos cuya tabla `Concepto CCT Vigente` incluya ese convenio (o que no tengan restricción de CCT).

**Relaciones clave:** es PK padre de `Categoría CCT`, `Concepto CCT Vigente`, `Parámetro Vigente` (vía sufijo).

**Nota de diseño:** no tiene versiones. Cambiar el código de un convenio invalida todas las referencias existentes; en su lugar, crear uno nuevo.

---

#### Categoría CCT

**Función:** Define las categorías laborales dentro de cada CCT y su factor de escala salarial. Permite que una sola fórmula como `BASICO * PCT_ESCALA` devuelva importes diferentes según la categoría del empleado.

**Datos que contiene:** `Cód. Convenio` + `Código` (PK compuesta), descripción, `% Escala`.

**Rol en el cálculo:** el motor computa la variable de sistema `PCT_ESCALA = Categoría."%Escala" / 100` al construir el contexto. Si `% Escala = 100`, la variable vale `1,0`; si la escala es `85`, vale `0,85`.

**Cuándo usar escala ≠ 100:** si el BASICO del CCT es un único valor de referencia (básico de máxima categoría) y el resto de las categorías son proporciones de él. Si cada categoría tiene su propio BASICO independiente (caso de `Parámetro` con `Sufijo CCT = true`), todas las categorías tienen `% Escala = 100`.

**Relaciones clave:** depende de `Convenio Colectivo`; define el valor de `PCT_ESCALA` en el contexto de cada liquidación.

---

#### Parámetro

**Función:** Catálogo de variables configurables disponibles en las fórmulas. Define el *qué* (nombre, propósito, comportamiento de sufijo) pero no el *cuánto*, que está en `Parámetro Vigente`.

**Datos que contiene:** `Código` (PK), `Nombre Variable` (nombre en la fórmula), `Sufijo CCT` (booleano), notas.

**Rol en el cálculo:** al construir el contexto, el motor itera todos los `Parámetro` con `Nombre Variable ≠ ''` y carga su valor vigente. Si `Sufijo CCT = true`, construye la clave compuesta `CÓDIGO_CONVENIO_CATEGORÍA` para buscar en `Parámetro Vigente` el valor específico del empleado.

**El mecanismo de sufijo explicado:**
```
Parámetro:   BASICO  (Sufijo CCT = true)
Empleado:    CCT = 729/15, Categoría = MR00
Clave buscada en Parámetro Vigente: BASICO_729/15_MR00
Variable en fórmula:                BASICO → 174.286
```

**Nota:** los parámetros con `Sufijo CCT = true` requieren tantos registros en `Parámetro Vigente` como combinaciones CCT × Categoría existan. Los sin sufijo tienen un único registro por vigencia.

**El flag `En Uso`:** el motor marca automáticamente como `En Uso = true` el registro de `Parámetro Vigente` que fue efectivamente leído por alguna fórmula. Sirve para auditoría; permite detectar parámetros configurados pero nunca usados.

---

#### Parámetro Vigente

**Función:** Almacena el valor histórico de cada parámetro. Es la tabla donde se actualizan tasas (SMVM, TOPE_SIPA, porcentajes de aportes, básicos por categoría, precios diarios). Cada actualización de valores se hace insertando un nuevo registro con fecha posterior, sin modificar los existentes.

**Datos que contiene:** `Cód. Parámetro` + `Vigencia Desde` (PK compuesta), valor decimal, moneda opcional, notas, `En Uso`.

**Cómo resuelve el motor:** `SELECT TOP 1 WHERE Vigencia Desde <= FechaRef ORDER BY Vigencia Desde DESC`. Toma siempre el registro más reciente con vigencia anterior o igual a la fecha del período.

**Ejemplos de parámetros globales (sin sufijo):**

| Código | Descripción |
|---|---|
| `SMVM` | Salario Mínimo Vital y Móvil |
| `TOPE_SIPA` | Tope imponible SIPA (jubilación, ley 19032) |
| `TOPE_SIPA_OS` | Tope imponible SIPA (obra social) |
| `MNI_ANUAL` | Mínimo no imponible anual Ganancias 4ta (art. 23 LIG) |
| `DEDUCCION_ESP` | Deducción especial Ganancias 4ta (art. 23 bis LIG) |
| `PCT_JUB` | Tasa aporte jubilatorio del empleado (11%) |
| `PCT_19032` | Tasa aporte ley 19032 — INSSJP (3%) |
| `PCT_OS` | Tasa aporte obra social del empleado (3%) |
| `PCT_ADICIONAL_OS` | Tasa aporte adicional OS (1,5%) |
| `PCT_CONT_JUB` | Tasa contribución patronal jubilación (10,77%) |
| `PCT_ART` | Tasa contribución patronal ART sobre remuneración (5,51%) |
| `VALOR_ART_FIJO` | Valor fijo ART por empleado por mes |
| `PCT_ANTIG` | Porcentaje de antigüedad por año completo (0,01 = 1%) |

**Ejemplos de parámetros con sufijo (CCT × Categoría):**

| Código | Descripción |
|---|---|
| `BASICO_372/04_CA02` | Básico mensualizado STIA, Categoría 2 |
| `PRECIO_NAV_729/15_MR00` | Precio diario navegación marinería, Primer Pescador |
| `PRECIO_FRANCO_729/15_MR00` | Precio diario de franco, Primer Pescador |
| `PRECIO_PUERTO_729/15_MR01` | Precio diario de puerto, Contramaestre |
| `PCT_CUOTA_SIND_729/15_MR00` | Tasa cuota sindical SOMU para marinería |

**Nota sobre moneda:** el campo `Moneda` (ej. `USD`) no convierte automáticamente; es informativo. Las fórmulas que requieren conversión deben multiplicar explícitamente por `TC_COMPRADOR`.

---

#### Variable Sistema Liq.

**Función:** Define qué cálculos automáticos del motor están disponibles como variables de fórmula, y con qué nombre. Separa el nombre de código del cálculo (hardcoded) del nombre visible en la fórmula (configurable).

**Datos que contiene:** `Cód. Cálculo` (identifica la lógica en el código), `Nombre Variable` (nombre en la fórmula), descripción, `Activo`.

**Variables del sistema disponibles:**

| Cód. Cálculo | Variable por defecto | Descripción |
|---|---|---|
| `ANIOS_ANTIGUEDAD` | `ANIOS_ANTIGUEDAD` | Años completos desde `Employment Date` hasta la fecha del período |
| `DIAS_HAB` | `DIAS_HAB` | Días hábiles lunes–viernes dentro del período |
| `PCT_ESCALA` | `PCT_ESCALA` | `Categoría CCT."% Escala"` ÷ 100 |
| `DIAS_PROYECTO` | `DIAS_MAR` | `Job."Ending Date" − Job."Starting Date"` (días corridos del proyecto) |
| `DEDUC_GANANCIAS` | `DEDUC_GANANCIAS` | Total deducción Ganancias 4ta del empleado (cargas de familia + SIRADIG, anual) |

**Nota de diseño:** esta tabla permite renombrar variables del sistema sin modificar código. Si se desea usar `DIAS_VIAJE` en lugar de `DIAS_MAR`, basta cambiar el `Nombre Variable` en esta tabla. Desactivar una fila deja esa variable en `0` en el contexto.

---

#### Concepto Liquidación

**Función:** Es la tabla central del sistema. Define cada ítem del recibo de sueldo: su naturaleza (tipo), la fórmula con que se calcula, las condiciones de aplicación, el orden de ejecución y la vigencia temporal.

**Datos que contiene:** `Código` + `Vigencia Desde` (PK compuesta), descripción, `Nombre Impresión` (texto para el recibo), `Tipo Concepto`, `Fórmula`, `Condición`, `Orden Cálculo`, `Aplica A`, `Aplica Tipo Liq.`, `Activo`, `Es Acumulador`.

**Tipos de concepto y su efecto en el recibo:**

| Tipo | Suma a... | Aparece en recibo |
|---|---|---|
| Haber Remunerativo | `Total Haberes` | Sí, como haber |
| Haber No Remunerativo | `Total Haberes` | Sí, como haber |
| Seguridad Social | `Total Descuentos` | Sí, como descuento previsional |
| Descuento Empleado | `Total Descuentos` | Sí, como descuento |
| Retención | `Total Descuentos` | Sí, como retención |
| Contribución Patronal | `Total Contribuciones` | Solo en liquidación patronal |

**El flag `Es Acumulador`:** cuando está activo, el concepto no tiene fórmula propia; su valor lo alimentan otros conceptos mediante `Fracción Acumulador`. Los acumuladores se inicializan en `0` al inicio del cálculo y se actualizan tras cada concepto calculado. Sirven como bases de cálculo acumuladas (base SS, base OS, base SAC, etc.).

**Restricción por tipo de liquidación (`Aplica Tipo Liq.`):** permite definir conceptos que solo existen en liquidaciones de SAC, vacaciones o egreso, sin que aparezcan en la liquidación mensual normal.

**Versiones:** cada cambio de fórmula, descripción o porcentaje se implementa como una nueva fila con nueva `Vigencia Desde`. El motor selecciona automáticamente la versión más reciente vigente.

---

#### Concepto CCT Vigente

**Función:** Tabla de intersección muchos-a-muchos entre conceptos y convenios colectivos, con versionado por fecha. Responde a la pregunta: *¿a qué CCTs aplica este concepto a partir de determinada fecha?*

**Datos que contiene:** `Cód. Concepto` + `Vigencia Desde` + `Cód. Convenio` (PK compuesta).

**Regla del motor:** si un concepto no tiene ninguna fila en esta tabla, aplica a **todos** los CCTs. Si tiene filas, el motor toma la vigencia más reciente ≤ fecha del período y aplica el concepto únicamente a los CCTs listados en esa vigencia.

**Caso de uso:** el concepto `1075 — Artículo 19 CCT 729/15` solo aplica al CCT `729/15`. La fila `(1075, 01/01/2015, 729/15)` en esta tabla lo restringe; un empleado con CCT `372/04` no lo verá calculado.

**Actualización de restricciones:** para agregar un CCT a partir de una fecha, insertar una nueva vigencia con todas las filas de la vigencia anterior más la nueva.

---

#### Fracción Acumulador

**Función:** Define cuánto (en porcentaje) del importe calculado de un concepto se acumula en cada acumulador. Es el mecanismo que alimenta las bases de cálculo (BASE_SS, BASE_OS, BASE_IG4, etc.) conforme se ejecutan los conceptos.

**Datos que contiene:** `Cód. Concepto` + `Vigencia Desde` + `Cód. Acumulador` (PK compuesta), `Porcentaje`, descripción.

**Mecánica:** inmediatamente después de calcular el importe de un concepto, el motor itera todas las fracciones activas de ese concepto y ejecuta:
```
Acumulador[X] += Importe * Porcentaje / 100
```

**Nota sobre porcentajes:** el porcentaje refleja *qué parte de ese concepto* va a *ese acumulador*. No es la proporción del acumulador total. Es completamente válido que 10 conceptos diferentes contribuyan al 100% a `BASE_SS`; el acumulador simplemente suma todos.

**Casos especiales:**

- Concepto 100% remunerativo: todas las bases (SS, OS, sindical, LRT, IG4, SAC, promedio) reciben el 100%.
- Concepto 100% no remunerativo: solo `NO_REMUNERATIVO`, `BASE_OS`, `BASE_SINDICAL` y `BASE_SAC`. No va a `BASE_SS` ni `BASE_IG4`.
- Split rem/no rem (ej. 30% rem + 70% no rem): no se divide el importe del concepto; se crean **dos conceptos separados** que suman el importe total, cada uno con sus propias fracciones.
- Descuentos y SS: el tipo `Seguridad Social` acumula al 100% en `TOTAL_DESCUENTOS` (acumulador principal). No acumula en bases de cálculo.

---

#### Tabla Escalonada / Tabla Escalonada Det.

**Función:** Almacena estructuras de tramos para cálculos progresivos. El caso más común es la tabla del impuesto a las Ganancias 4ª categoría (AFIP), pero puede usarse para cualquier escala progresiva (ej. escalas de productividad, becas por antigüedad).

**Tabla Escalonada** (encabezado): `Código` + `Vigencia Desde` (PK), descripción.

**Tabla Escalonada Det.** (detalle): `Código` + `Vigencia Desde` + `Nro. Tramo` (PK), `Límite Inferior`, `Límite Superior` (0 = sin límite), `Monto Fijo`, `% Excedente`.

**Fórmula de cada tramo:**
```
Si Límite Inferior ≤ Valor < Límite Superior:
    Importe = Monto Fijo + (% / 100) × (Valor − Límite Inferior)
```

**La función `TRAMO()`** en las fórmulas recorre los tramos de menor a mayor e itera hasta encontrar el que contiene el valor. Para la función acumulativa de Ganancias (impuesto sobre todos los tramos anteriores), cargar el `Monto Fijo` con el impuesto acumulado hasta el inicio de cada tramo.

**Versionado:** al cambiar la tabla AFIP, usar la acción **Nueva Vigencia** que duplica encabezado + todos los detalles con nueva fecha. La versión anterior queda intacta para reliquidaciones históricas.

---

#### Fuente Datos Liquidación

**Función:** Permite incorporar al contexto de cálculo valores de cualquier tabla de BC (producción por especie, horas trabajadas, consumos a bordo, etc.) sin modificar código. Define una consulta genérica vía RecordRef con filtros parametrizados.

**Datos que contiene:** `Nombre Variable` (nombre en la fórmula), `Id. Tabla`, `No. Campo Valor`, `Función Agregado` (SUM, COUNT, MAX, MIN, LOOKUP), hasta 3 pares (campo de filtro, valor de filtro).

**Mecanismo de tokens en filtros:** los valores de filtro admiten marcadores que el motor reemplaza en tiempo de ejecución:

| Token | Valor en tiempo de ejecución |
|---|---|
| `{EMP_NO}` | No. Empleado de la liquidación |
| `{JOB_NO}` | No. Proyecto (marea/proyecto asignado) |
| `{PERIODO}` | Cód. Período |
| `{FECHA_REF}` | Fecha hasta del período |
| `{LIQ_NO}` | No. Liquidación |

**Caso de uso típico:** sumar los kilos de langostino cola descargados en el proyecto de la marea actual, filtrando la tabla `Lín. descarga` (tabla 50562) por No. Proyecto = `{JOB_NO}` y subfamilia del ítem. El resultado queda disponible como `PROD_KB_LANG_COLA` en la fórmula del concepto de producción.

**Consideración de rendimiento:** cada fuente de datos ejecuta una consulta a BC por cada liquidación. Evitar fuentes sin filtros en tablas grandes; siempre filtrar por `{EMP_NO}` o `{JOB_NO}` como mínimo.

---

### Dominio del empleado

---

#### Cód. Estado Empleado

**Función:** Catálogo de estados posibles para un empleado (ej. Activo, Suspendido, Embarcado, En tierra). Define, además, si ese estado corresponde a un empleado de tipo "Tripulante" o "Mensualizado", lo que afecta el filtrado de conceptos por `Aplica A`.

**Datos que contiene:** `Código`, descripción, `Tipo Empleado` (enum: Todos / Tripulante / Mensualizado / Jornalizado).

**Rol en el cálculo:** el motor obtiene el estado del empleado a la fecha del período, lee el `Tipo Empleado` del código de estado y lo usa para filtrar `Concepto Liquidación.Aplica A`. Un concepto con `Aplica A = Tripulante` no se calcula para un empleado en estado "Administrativo".

---

#### Estado Empleado

**Función:** Registra la historia de estados del empleado a lo largo del tiempo. Responde a la pregunta: *¿en qué estado estaba el empleado a la fecha de cálculo?*

**Datos que contiene:** `No. Empleado` + `Fecha Desde` (PK compuesta), `Cód. Estado`, notas.

**Mecánica:** el motor busca el estado más reciente con `Fecha Desde ≤ Fecha de período`. Si no hay ninguno, el cálculo falla con error de validación. Es obligatorio tener al menos un registro antes de la primera liquidación del empleado.

**Diseño append-only:** nunca modificar un estado existente. Registrar el cambio con nueva fecha. Los estados anteriores quedan para auditoría y reliquidaciones.

---

#### Personal Proyecto

**Función:** Registra la asignación de un empleado a un proyecto (marea, temporada, obra, etc.) con el convenio y la categoría correspondiente. Es el nexo entre el empleado, el proyecto y las condiciones salariales.

**Datos que contiene:** `No. Empleado` + `No. Proyecto` (PK), `Fecha Alta`, `Fecha Baja`, `Cód. Convenio`, `Cód. Categoría`.

**Rol en el cálculo:** la liquidación lee el convenio y la categoría del empleado desde esta tabla (o desde la cabecera de la liquidación si ya fueron copiados). El convenio determina qué conceptos aplican; la categoría resuelve los parámetros con sufijo.

**Nota:** un empleado puede estar asignado a más de un proyecto (ej. si realizó dos mareas en el período), pero cada liquidación referencia un único proyecto. Si el empleado tiene asignaciones en varios proyectos del período, se generan liquidaciones separadas por proyecto.

---

#### Ded. Ganancias Vigente

**Función:** Almacena los importes anuales que la AFIP publica para cada tipo de deducción familiar (cónyuge, hijo, etc.). Los valores cambian cada año fiscal; se versionan con `Vigencia Desde`.

**Datos que contiene:** `Código` + `Vigencia Desde` (PK), descripción, `Importe Anual`, `Aplica Cantidad`.

**Rol en el cálculo:** la variable `DEDUC_GANANCIAS` (computada por el motor) consulta esta tabla para los tipos de deducción declarados por el empleado en `Ded. Ganancias Empleado`. Para cada tipo, multiplica el importe AFIP por la cantidad declarada por el empleado.

**Actualización:** cuando AFIP publica nuevos valores (típicamente enero y/o cuando se indexan), insertar nuevas filas con la vigencia correspondiente. Las liquidaciones históricas recalculadas usarán el valor vigente a su fecha.

---

#### Ded. Ganancias Empleado

**Función:** Registra las cargas de familia y deducciones propias que cada empleado tiene declaradas en el SIRADIG o en el formulario 572. Determina el importe personalizado de deducción que se resta de la base imponible de Ganancias 4ta.

**Datos que contiene:** `No. Empleado` + `Vigencia Desde` + `Cód. Tipo` (PK), `Cantidad`, `Importe Fijo`, observaciones.

**Mecánica de cálculo:**
- Si `Importe Fijo > 0`: se usa ese importe directamente (deducción de monto declarado, ej. alquiler).
- Si `Importe Fijo = 0`: se multiplica `Ded. Ganancias Vigente.Importe Anual × Cantidad` (ej. 2 hijos = 2 × importe AFIP por hijo).

**Versionado:** cuando cambia la situación familiar del empleado, insertar un nuevo conjunto de filas con nueva `Vigencia Desde`. El motor usa siempre la vigencia más reciente ≤ fecha del período.

---

### Dominio transaccional

---

#### Período Liquidación

**Función:** Define los rangos de fecha para los que se liquidan sueldos. Actúa como guardia: impide calcular en períodos cerrados y agrupa las liquidaciones de un mes.

**Datos que contiene:** `Código` (PK), `Fecha Desde`, `Fecha Hasta`, `Estado` (Abierto / Cerrado).

**Rol en el cálculo:** el motor valida que el período esté abierto antes de calcular. La `Fecha Hasta` del período es la **fecha de referencia** usada para resolver vigencias de parámetros, conceptos, estados y tablas. Todos los `WHERE Vigencia Desde ≤ FechaRef` usan esta fecha.

**Cierre:** una vez cerrado, no es posible crear ni recalcular liquidaciones del período. El cierre es irreversible desde la interfaz estándar.

---

#### Liquidación

**Función:** Cabecera de cada liquidación individual. Representa el recibo de un empleado para un período y un proyecto dado.

**Datos que contiene:** `No.` (PK), `No. Empleado`, `No. Proyecto`, `Cód. Período`, `Fecha Liquidación`, `Cód. Convenio`, `Cód. Categoría`, `Tipo Liquidación`, `Estado` (Borrador / Calculada / Aprobada), `Total Haberes`, `Total Descuentos`, `Total Contribuciones`, `Neto a Pagar`.

**Ciclo de vida:**
```
Borrador → [Calcular] → Calculada → [Aprobar] → Aprobada
                ↑                       |
                └── [Reabrir] ──────────┘
```

Una liquidación aprobada no puede reabrir ni modificarse. Los totales son calculados por el motor y no se ingresan manualmente.

**Tipos de liquidación:**

| Tipo | Descripción |
|---|---|
| **Regular** | Liquidación mensual estándar |
| **Aguinaldo** | SAC semestral |
| **Vacaciones** | Pago de días de vacaciones |
| **Liquidación Final** | Egreso del empleado |
| **Reliquidación** | Corrección de una liquidación anterior |
| **Devengados** | Fijos mensuales acumulados durante la marea (se liquidan estando embarcado) |
| **Cierre Marea** | Liquidación completa al regreso: navegación + producción + antigüedad + descuentos |

El tipo filtra los conceptos: los conceptos con `Aplica Tipo Liq.` en blanco aplican a todos los tipos; los conceptos con un tipo específico solo se calculan en liquidaciones de ese tipo.

---

#### Línea Liquidación

**Función:** Registra el resultado del cálculo de cada concepto aplicado a la liquidación. Es el detalle del recibo y el registro de auditoría del cálculo.

**Datos que contiene:** `No. Liquidación` + `No. Línea` (PK), `Cód. Concepto`, descripción, `Nombre Impresión`, `Tipo Concepto`, `Importe`, `Orden Cálculo`, `Fórmula Aplicada`, `Vigencia Concepto`, `Fuente Parámetros`.

**Campo `Fuente Parámetros`:** lista pipe-separada de las variables (`VAR:nombre`) y tablas escalonadas (`TRAMO:código|fecha`) efectivamente leídas al evaluar ese concepto. Permite rastrear qué valores intervinieron.

**Detalle de variables:** cada línea tiene filas asociadas en `Detalle Variable Línea Liq.` con el valor numérico concreto de cada variable en el momento del cálculo. Visible en la solapa **Variables del Cálculo** (FactBox) de la Ficha Liquidación.

**Regeneración:** las líneas —y sus detalles de variables— se borran completamente y se recalculan en cada ejecución del motor.

---

#### Incidencia Liquidación

**Función:** Permite ingresar manualmente importes que alimentan conceptos específicos en una liquidación puntual. Sirve para ajustes, retroactivos, gratificaciones extraordinarias o cualquier valor que no puede calcularse automáticamente.

**Datos que contiene:** `No. Liquidación` + `Cód. Concepto` (PK), `Importe`, `Observaciones`.

**Cómo se usa en la fórmula:** el concepto que consume la incidencia tiene una `Fuente Datos Liquidación` configurada para leer la tabla de incidencias con filtro `{LIQ_NO}` y `{COD_CONCEPTO}`. El importe ingresado queda disponible como variable en la fórmula.

**Restricción:** solo modificables cuando la liquidación está en estado Borrador. Al calcular, los importes se fijan en las líneas; reabrir la liquidación permite corregirlos.

---

#### Detalle Variable Línea Liq.

**Función:** Almacena el valor numérico de cada variable usada por cada concepto calculado. Es el registro estructurado y consultable del estado del contexto en el momento exacto del cálculo de cada línea.

**Datos que contiene:** `No. Liquidación` + `No. Línea` + `Nombre Variable` (PK), `Valor` (Decimal).

**Rol en la operación:** el motor lo popula automáticamente al calcular cada concepto. Solo se registran las variables efectivamente leídas por la fórmula o la condición de ese concepto (no todo el contexto). Se borra y regenera junto con las líneas en cada recálculo.

**Cómo usarlo:** en la **Ficha Liquidación**, el panel de **Variables del Cálculo** (FactBox derecho) muestra en tiempo real, para cada línea, qué variables se usaron y con qué valor. Permite verificar que `DIAS_MAR`, `PRECIO_NAV`, `BASICO` y similares tenían el valor esperado sin necesidad de abrir blobs ni snapshots.

---

## Liquidaciones de marinería (Devengados y Cierre Marea)

El personal embarcado en un proyecto de marea (Job productivo o improductivo) puede tener dos tipos de liquidación específicos durante el transcurso del viaje:

### Devengados

Cubre los conceptos de sueldo fijo mensual que el tripulante devenga mientras está en el mar (básico, antigüedad, adicionales fijos). Se crea mientras el proyecto está abierto (Job sin fecha de fin).

- `Aplica Tipo Liq. = Devengados` en los conceptos correspondientes
- El proyecto puede no tener fecha de fin al momento del cálculo; `DIAS_MAR` estará en `0` si el Job no tiene fecha de fin — no usar en fórmulas de Devengados

### Cierre Marea

Se liquida al regreso del buque (cuando el Job tiene `Ending Date` asignado). Incluye los conceptos de navegación, producción e incentivos que dependen de los días y la producción del viaje.

- `Aplica Tipo Liq. = Cierre Marea` en los conceptos de navegación y producción
- La variable `DIAS_MAR` (`DIAS_PROYECTO`) = `Job."Ending Date" − Job."Starting Date"` está disponible
- Parámetros típicos con sufijo CCT: `PRECIO_NAV`, `PRECIO_FRANCO`, `PRECIO_ORDENES`, `PRECIO_INCENT`

### Cómo crear liquidaciones de marea

**Desde el Job Card** (por proyecto individual):

| Acción | Tipo creado |
|---|---|
| **Personal Proyecto → Liquidar Personal (Regular)** | Regular |
| **Personal Proyecto → Crear Devengados** | Devengados |
| **Personal Proyecto → Crear Cierre Marea** | Cierre Marea (solo habilitado si Job tiene Ending Date) |

Cada acción solicita el período y crea borradores para todo el personal activo del proyecto que aún no tenga liquidación del mismo tipo en ese período.

**Desde el Lanzador de Liquidaciones** (en lote, todos los proyectos):

Disponible desde el Role Center → **Nómina → Lanzador de Liquidaciones**. Permite crear liquidaciones en lote para todos los proyectos del período según tipo y filtro de proyecto (Todos / Productivo / Improductivo).

### Conceptos de Cierre Marea CCT 729/15 (marinería SOMU)

| Código | Concepto | Fórmula |
|---|---|---|
| `1013` | Sueldo de navegación | `DIAS_MAR * PRECIO_NAV` |
| `1063` | Sueldo de franco | `DIAS_MAR * PRECIO_FRANCO` |
| `1073` | Sueldo a órdenes | `DIAS_MAR * PRECIO_ORDENES` |
| `1547` | Incentivo a la producción | `DIAS_MAR * PRECIO_INCENT` |

Los parámetros `PRECIO_NAV`, `PRECIO_FRANCO`, `PRECIO_ORDENES` y `PRECIO_INCENT` se configuran con `Sufijo CCT = true` (se resuelven por CCT + Categoría del empleado).

---

## Configuración inicial

Completar estas tablas maestras en orden antes de la primera liquidación:

### 1. Convenios Colectivos (`Convenios Colectivos`)

Registrar cada CCT: código, descripción, número oficial y sindicato.

Códigos usados en el sistema:

| Código | CCT |
|---|---|
| `175/75` | CCT 175/75 Personal Embarcado Oficiales CAPECA |
| `768/19` | CCT 768/19 Personal Embarcado Oficiales AACPyPP |
| `729/15` | CCT 729/15 Personal Embarcado Marinería SOMU-CAPECA |
| `ESP` | Sin CCT — Personal Embarcado España |
| `130/75` | CCT 130/1975 Comercio |
| `372/04` | CCT 372/2004 STIA |
| `ADM` | Sin CCT — Personal Administrativo |

### 2. Categorías por CCT (`Categorías CCT`)

Definir categorías y su porcentaje de escala por convenio. El motor divide automáticamente por 100; si la escala es 150, la variable `PCT_ESCALA` vale `1,50`.

### 3. Parámetros (`Parámetros`)

Define las variables configurables disponibles en fórmulas. Cada parámetro tiene:

| Campo | Descripción |
|---|---|
| **Código** | Identificador interno |
| **Nombre Variable** | Nombre con que aparece en la fórmula (ej: `SMVM`) |
| **Sufijo CCT** | Si está activo, el motor busca `CÓDIGO_CONVENIO_CATEGORÍA` para resolverlo por empleado |

El básico del convenio usa `Sufijo CCT = true`, código `BASICO`. El motor lo resuelve a `BASICO_175/75_CAPITAN` automáticamente según el convenio y categoría del empleado.

### 4. Parámetros Vigentes (`Parámetros`)

Valores numéricos con fecha de vigencia. Para cambiar un valor se inserta un nuevo registro con fecha posterior; el anterior queda intacto para auditoría.

Parámetros a completar antes del primer cálculo:

| Parámetro | Descripción |
|---|---|
| `SMVM` | Salario Mínimo Vital y Móvil vigente |
| `TOPE_SIPA` | Tope imponible SIPA (base remunerativa) |
| `TOPE_SIPA_OS` | Tope imponible SIPA (obra social) |
| `MNI_ANUAL` | Mínimo no imponible anual Ganancias 4ta |
| `PCT_ANTIG` | Porcentaje de antigüedad por año (ej: `0,01` = 1% por año) |
| `PCT_CUOTA_SIND` | Tasa de cuota sindical (varía por CCT) |
| `BASICO_[CCT]_[CAT]` | Básico por convenio/categoría (se crea automáticamente con Sufijo CCT) |

> **Formato decimal:** usar **coma** como separador decimal en todos los valores (`0,11`, no `0.11`). Lo mismo aplica en las fórmulas.

### 5. Variables Sistema (`Variables Sistema`)

Mapea cálculos automáticos del motor a nombres de variable disponibles en fórmulas. No requiere modificación en uso normal.

| Cód. Cálculo | Variable | Contenido |
|---|---|---|
| `ANIOS_ANTIGUEDAD` | `ANIOS_ANTIGUEDAD` | Años completos desde fecha de contratación |
| `DIAS_HAB` | `DIAS_HAB` | Días hábiles (lun–vie) del período |
| `PCT_ESCALA` | `PCT_ESCALA` | % escala de la categoría ÷ 100 |
| `DIAS_PROYECTO` | `DIAS_MAR` | Días entre inicio y fin del proyecto (marea) |

### 6. Períodos de Liquidación (`Períodos Liquidación`)

Crear el período mensual con fecha desde/hasta antes de empezar a liquidar. Un período cerrado no admite nuevas liquidaciones.

---

## Declaración de conceptos y fórmulas

Ir a **Conceptos Liquidación** y crear un nuevo concepto. Los campos principales:

| Campo | Descripción |
|---|---|
| **Código** | Identificador. Puede usarse como variable en otras fórmulas si el concepto fue calculado antes |
| **Vigencia Desde** | Fecha de vigencia de esta versión |
| **Tipo Concepto** | Define cómo se clasifica y acumula el importe |
| **Aplica A** | Todos / Embarcado / Mensualizado / Jornalizado |
| **Aplica Tipo Liq.** | En blanco = todos los tipos; o restringir a Regular, Aguinaldo, Vacaciones, Liquidación Final, Reliquidación, Devengados, Cierre Marea |
| **Orden Cálculo** | El motor ejecuta de menor a mayor |
| **Activo** | Desactivar para excluir sin borrar |
| **Es Acumulador** | El concepto es solo receptor de sumas; no tiene fórmula propia |
| **Fórmula** | Expresión matemática/lógica |
| **Condición** | Si evalúa `0` (falso), el concepto no se aplica en esa liquidación |

### Restricción por CCT

La asignación de conceptos a convenios se hace en la solapa **Convenios aplicables** dentro de la ficha del concepto (tabla `Concepto CCT Vigente`). Si no hay filas, el concepto aplica a **todos** los CCTs. Si hay filas, aplica solo a los convenios listados para la vigencia vigente.

### Orden de cálculo recomendado

```
1–99     Haberes base (sueldo, navegación, producción, antigüedad)
100–199  Adicionales y complementos
200–299  Haberes no remunerativos
300–399  Licencias, ILT, accidentes
400–499  Conceptos específicos por CCT
500–599  Indemnizaciones (liquidación final)
600–699  Descuentos de días (enfermedad, ausencias)
700–799  Deducciones sindicales y solidarias
800–829  Embargos y retenciones judiciales
850–899  Retención 4ta categoría
900–929  Aportes Seguridad Social (Jubilación, OS, Ley 19032)
999      Redondeo
```

---

## Variables disponibles en fórmulas

### Parámetros configurados

Cualquier `Parámetro` con `Nombre Variable` definido está disponible. Los básicos se resuelven por sufijo:

```
BASICO        → valor de BASICO_[CONVENIO]_[CATEGORÍA] del empleado
SMVM          → Salario Mínimo Vital y Móvil
TOPE_SIPA     → Tope imponible SIPA
TOPE_SIPA_OS  → Tope imponible SIPA para OS
MNI_ANUAL     → Mínimo no imponible anual Ganancias 4ta
PCT_ANTIG     → Porcentaje de antigüedad por año
PCT_CUOTA_SIND→ Tasa cuota sindical
```

### Variables del sistema (calculadas automáticamente)

```
PCT_ESCALA        → % escala de la categoría ÷ 100
ANIOS_ANTIGUEDAD  → Años completos de antigüedad
DIAS_HAB          → Días hábiles del período
DIAS_MAR          → Días del proyecto/marea
```

### Acumuladores (actualizados en tiempo real)

Los acumuladores se actualizan después de cada concepto calculado. Los disponibles por defecto:

```
REMUNERATIVO_BRUTO    BASE_SS         BASE_PROMEDIO
NO_REMUNERATIVO       BASE_OS         BASE_FERIADO
TOTAL_DESCUENTOS      BASE_SINDICAL   BASE_ZONA
TOTAL_CONTRIBUCIONES  BASE_LRT        BASE_AUSENTISMO
                      BASE_IG4
                      BASE_SAC
```

### Variables de fuentes dinámicas

Cualquier variable definida en **Fuente Datos Liquidación** (ej: `PROD_KB_LANG_COLA`, `PROD_KB_L1`) estará disponible con el nombre configurado.

### Código del concepto como variable

Un concepto calculado previamente puede referenciarse por su código. Por ejemplo, si `1003` calculó el sueldo básico, en conceptos posteriores se puede escribir `1003 * 0,5`.

---

## Funciones incorporadas

> **Separador decimal:** siempre **coma** (`0,11`, `0,03`, `1,5`).

### `TRAMO('Código', Valor)`

Evalúa una tabla escalonada y devuelve el importe para el valor dado.

```
TRAMO('TAB_IMP_4CAT', MAX(BASE_IG4 * 12 - MNI_ANUAL, 0)) / 12
```

### `ROUND(Valor, Precisión)`

```
ROUND(BASICO * PCT_ESCALA, 0,01)   → centavos
ROUND(BASICO * PCT_ESCALA, 1)      → pesos enteros
```

### `ABS(Valor)`

```
ABS(DIAS_MAR - 20)
```

### `MIN(Val1, Val2)` / `MAX(Val1, Val2)`

```
MIN(BASE_SS, TOPE_SIPA) * 0,11
MAX(BASICO * PCT_ESCALA, SMVM)
```

### `IF(Condición, ValorSiTrue, ValorSiFalse)`

```
IF(ANIOS_ANTIGUEDAD >= 10, BASICO * 0,02, BASICO * 0,01)
```

### Operadores lógicos (solo en el campo `Condición`)

| Operador | Uso |
|---|---|
| `AND` / `OR` / `NOT` | Lógica booleana |
| `=`, `<>`, `<`, `>`, `<=`, `>=` | Comparación numérica |

```
ANIOS_ANTIGUEDAD >= 2 AND DIAS_MAR > 10
BASE_SS > 0
NOT DIAS_MAR = 0
```

---

## Acumuladores y Fracción Acumulador

### Qué es un acumulador

Un acumulador es un concepto con `Es Acumulador = true` que no tiene fórmula propia; recibe sumas de otros conceptos vía la tabla **Fracción Acumulador**.

Los 14 acumuladores base ya están creados en el sistema (ver Configuración inicial para la lista completa).

### Configurar en qué acumuladores contribuye un concepto

En la ficha del concepto, solapa **Distribución en acumuladores**, definir las fracciones:

| Campo | Descripción |
|---|---|
| **Vigencia Desde** | Fecha desde la que aplica esta distribución |
| **Cód. Acumulador** | Código del concepto acumulador destino |
| **Porcentaje** | Parte del importe que va a ese acumulador (0–100) |

**Ejemplo:** un sueldo remunerativo que acumula el 100% al bruto remunerativo y también al 100% a las bases SS, OS, sindical, LRT, SAC y Ganancias:

| Acumulador | % |
|---|---|
| `REMUNERATIVO_BRUTO` | 100 |
| `BASE_SS` | 100 |
| `BASE_OS` | 100 |
| `BASE_SINDICAL` | 100 |
| `BASE_LRT` | 100 |
| `BASE_SAC` | 100 |
| `BASE_IG4` | 100 |

> La suma de porcentajes hacia un mismo acumulador puede superar 100 si múltiples conceptos contribuyen. Lo que importa es que cada fracción refleje qué porción de *ese concepto* va a *ese acumulador*.

**Caso no remunerativo con split parcial** (70% no rem / 30% rem):

| Acumulador | % |
|---|---|
| `NO_REMUNERATIVO` | 100 |
| `BASE_OS` | 100 |
| `BASE_SINDICAL` | 100 |
| `BASE_SAC` | 100 |

Un haber 100% no remunerativo no contribuye a `BASE_SS` ni `BASE_IG4`.

---

## Tablas escalonadas (tramos)

Permiten calcular importes progresivos (impuesto 4ª categoría, escalas de productividad).

### Crear una tabla

**Tablas Escalonadas** → Nuevo:

```
Código:         TAB_IMP_4CAT
Vigencia Desde: 01/01/2025
Descripción:    Impuesto 4ta Categoría 2025
```

### Agregar tramos

En la subpágina de detalle:

| Nro. Tramo | Límite Inferior | Límite Superior | Monto Fijo | % Excedente |
|---|---|---|---|---|
| 1 | 0 | 800.000 | 0 | 0 |
| 2 | 800.000 | 1.200.000 | 0 | 9 |
| 3 | 1.200.000 | 0 | 36.000 | 12 |

> `Límite Superior = 0` en el último tramo significa "sin límite".

**Fórmula de cada tramo:**
```
Importe = Monto Fijo + (% / 100) × (Valor - Límite Inferior)
```

### Uso típico para Ganancias 4ta

```
Fórmula:    TRAMO('TAB_IMP_4CAT', MAX(BASE_IG4 * 12 - MNI_ANUAL, 0)) / 12
Condición:  BASE_IG4 * 12 > MNI_ANUAL
```

La fórmula anualiza la base, aplica la tabla, y divide por 12 para obtener la retención mensual.

---

## Gestión de versiones

Conceptos, parámetros y tablas escalonadas son **append-only**: nunca se modifica un registro activo; se agrega una nueva versión con fecha posterior.

### Actualizar un concepto

**Conceptos Liquidación** → seleccionar → acción **Nueva Vigencia**:
- Crea una copia con fecha de hoy como `Vigencia Desde`
- Modificar la nueva versión
- El motor usa automáticamente la versión más reciente ≤ fecha de cálculo

La versión anterior queda intacta para auditoría y recálculos históricos.

### Actualizar un parámetro

En la ficha del parámetro, solapa **Valores Vigentes** → insertar nueva fila con fecha y valor nuevo.

### Actualizar la asignación de CCTs de un concepto

En la solapa **Convenios aplicables** de la ficha del concepto, agregar nuevas filas con la nueva `Vigencia Desde`. El motor toma la última vigencia ≤ fecha de referencia como conjunto activo.

### Actualizar fracciones de un acumulador

En la solapa **Distribución en acumuladores**, agregar todas las filas de la nueva distribución con la nueva `Vigencia Desde`. Las fracciones viejas se conservan.

### Actualizar una tabla escalonada

**Tablas Escalonadas** → acción **Nueva Vigencia**:
- Duplica el encabezado y los tramos con la nueva fecha
- Modificar los tramos de la nueva versión

---

## Fuentes de datos dinámicas

Permiten incorporar al contexto valores de cualquier tabla de BC (kilos descargados, horas trabajadas, etc.) sin modificar código.

### Configurar una fuente

**Fuentes de Datos** → Nuevo. Los campos usan **IDs numéricos** de tabla y campo:

| Campo | Descripción |
|---|---|
| **Nombre Variable** | Nombre que tendrá en la fórmula |
| **Id. Tabla** | Número de tabla BC (ej: `50562` para `Lín. descarga`) |
| **No. Campo Valor** | Número del campo a leer/sumar |
| **Función Agregado** | `First` (primer registro) o `Sum` (suma todos los registros filtrados) |
| **No. Filtro 1/2/3** | Número del campo usado como filtro |
| **Filtro Valor 1/2/3** | Valor del filtro; admite tokens reemplazados en runtime |

### Tokens disponibles en valores de filtro

| Token | Se reemplaza por |
|---|---|
| `{JOB_NO}` | No. Proyecto (marea) del empleado |
| `{EMP_NO}` | No. Empleado |
| `{PERIODO}` | Cód. Período |
| `{FECHA_REF}` | Fecha de referencia (fin del período) |
| `{LIQ_NO}` | No. Liquidación |

### Cómo encontrar IDs de tabla y campo

Usar la página **Seleccionar Campo** (`Campo Liq. Lookup`) disponible en la acción de lookup de los campos de Fuente Datos. Muestra No. de campo, nombre y tipo para cualquier tabla.

### Ejemplo: kilos brutos por subfamilia desde `Lín. descarga` (tabla 50562)

```
Nombre Variable:  PROD_KB_LANG_COLA
Id. Tabla:        50562        (Lín. descarga)
No. Campo Valor:  9            (Gross weight = KB)
Función Agregado: Sum
No. Filtro 1:     1            (No. proyecto)
Filtro Valor 1:   {JOB_NO}
No. Filtro 2:     50002        (Subfamilia)
Filtro Valor 2:   [cód. subfamilia langostino cola]
```

### Ejemplo: kilos brutos por clasificación (ítem L-1)

```
Nombre Variable:  PROD_KB_L1
Id. Tabla:        50562
No. Campo Valor:  9
Función Agregado: Sum
No. Filtro 1:     1            (No. proyecto)
Filtro Valor 1:   {JOB_NO}
No. Filtro 2:     4            (Item no. = Clasificación)
Filtro Valor 2:   [código ítem L-1]
```

### Usar en una fórmula

```
Código:    2463
Fórmula:   PROD_KB_L1
Condición: PROD_KB_L1 > 0
```

---

## Incidencias manuales

Las incidencias permiten ingresar importes manuales para conceptos de ajuste, retroactivos o gratificaciones específicas de una liquidación particular, sin crear un concepto nuevo.

### Cómo ingresar una incidencia

En la **Ficha Liquidación**, solapa **Incidencias** (visible solo en estado Borrador):

| Campo | Descripción |
|---|---|
| **Cód. Concepto** | Concepto al que aplica el importe manual |
| **Importe** | Valor a utilizar en la fórmula |
| **Observaciones** | Motivo del ajuste |

### Acceder en la fórmula

Una vez ingresada, el importe queda disponible en el contexto con el nombre `{LIQ_NO}` resuelto internamente. El concepto con `Fuente Datos` configurada apuntando a la tabla de incidencias con filtro `{LIQ_NO}` lee automáticamente ese valor.

---

## Flujo operativo de liquidación

```
1. SETUP (una vez por cliente/convenio)
   Convenios → Categorías → Parámetros (definición) → Parámetros Vigentes (valores)
   Variables Sistema → Fuentes de Datos → Acumuladores (ya creados)
   Conceptos + Fracciones Acumulador + Asignación CCT → Tablas Escalonadas

2. INICIO DE PERÍODO
   Períodos Liquidación → Nuevo período (Fecha desde/hasta)

3. ASIGNACIÓN DE PERSONAL
   Job Card → solapa Personal Proyecto → asignar empleado con Convenio y Categoría
   Estados Empleado → confirmar estado activo para el período

4. CREAR LIQUIDACIÓN
   Lista Liquidaciones → Nuevo
     ó
   Job Card → Personal Proyecto → acciones "Liquidar Personal (Regular)" / "Crear Devengados" / "Crear Cierre Marea"
     ó
   Role Center → Nómina → Lanzador de Liquidaciones (proceso en lote para múltiples proyectos)
   Estado inicial: Borrador

5. INCIDENCIAS (opcional)
   Ficha Liquidación → solapa Incidencias → ingresar ajustes manuales

6. CALCULAR
   Ficha Liquidación → "Calcular"
   El motor ejecuta los conceptos y genera las líneas.
   Estado: Calculada

7. REVISAR
   Solapa Líneas → verificar importes por concepto y fórmula aplicada
   FactBox "Variables del Cálculo" → ver qué variables y valores usó cada concepto

8. CORREGIR (si es necesario)
   "Reabrir" → vuelve a Borrador → corregir → recalcular

9. APROBAR
   "Aprobar" → Estado: Aprobada (no editable)

10. CERRAR PERÍODO
    Períodos Liquidación → "Cerrar Período"

11. IMPRIMIR
    Reporte "Recibo de Sueldo"
```

---

## Ejemplos completos de conceptos

### Sueldo básico

```
Código:          1003
Tipo:            Haber Remunerativo
Aplica A:        Todos
Aplica Tipo Liq: (en blanco = todos)
Orden Cálculo:   10
Fórmula:         BASICO * PCT_ESCALA
Fracciones:      REMUNERATIVO_BRUTO 100%, BASE_SS 100%, BASE_OS 100%,
                 BASE_SINDICAL 100%, BASE_LRT 100%, BASE_IG4 100%, BASE_SAC 100%
```

### Antigüedad

```
Código:          1053
Tipo:            Haber Remunerativo
Orden Cálculo:   50
Fórmula:         BASICO * PCT_ESCALA * ANIOS_ANTIGUEDAD * PCT_ANTIG
Condición:       ANIOS_ANTIGUEDAD >= 1
Fracciones:      igual que sueldo básico
```

### Producción langostino cola L-1 (desde descarga)

```
Código:          2463
Tipo:            Haber Remunerativo
Aplica A:        Embarcado
Orden Cálculo:   147
Fórmula:         PROD_KB_L1
Condición:       PROD_KB_L1 > 0
Fracciones:      REMUNERATIVO_BRUTO 100%, BASE_SS 100%, BASE_OS 100%,
                 BASE_SINDICAL 100%, BASE_LRT 100%, BASE_IG4 100%,
                 BASE_SAC 100%, BASE_PROMEDIO 100%, BASE_ZONA 100%
```

*(requiere fuente dinámica `PROD_KB_L1` configurada en Fuente Datos)*

### Jubilación (11%)

```
Código:          6000
Tipo:            Seguridad Social
Aplica Tipo Liq: (en blanco)
Orden Cálculo:   900
Fórmula:         MIN(BASE_SS, TOPE_SIPA) * 0,11
```

### Jubilación SAC

```
Código:          6002
Tipo:            Seguridad Social
Aplica Tipo Liq: Aguinaldo
Orden Cálculo:   902
Fórmula:         MIN(BASE_SAC, TOPE_SIPA) * 0,11
```

### Obra social (3% + adicional 1,5%)

```
Código:          6030
Tipo:            Seguridad Social
Orden Cálculo:   912
Fórmula:         MIN(BASE_OS, TOPE_SIPA_OS) * 0,03

Código:          6032
Tipo:            Seguridad Social
Orden Cálculo:   914
Fórmula:         MIN(BASE_OS, TOPE_SIPA_OS) * 0,015
```

### Cuota sindical

```
Código:          8522
Tipo:            Descuento Empleado
Orden Cálculo:   700
Fórmula:         BASE_SINDICAL * PCT_CUOTA_SIND
```

### Retención 4ª categoría

```
Código:          5010
Tipo:            Retención
Orden Cálculo:   850
Fórmula:         TRAMO('TAB_IMP_4CAT', MAX(BASE_IG4 * 12 - MNI_ANUAL, 0)) / 12
Condición:       BASE_IG4 * 12 > MNI_ANUAL
```

### SAC (aguinaldo)

```
Código:          3613
Tipo:            Haber Remunerativo
Aplica Tipo Liq: Aguinaldo
Orden Cálculo:   460
Fórmula:         BASE_SAC / 2
Fracciones:      REMUNERATIVO_BRUTO 100%, BASE_SS 100%, BASE_OS 100%,
                 BASE_SINDICAL 100%, BASE_LRT 100%, BASE_IG4 100%
```

### Redondeo (opcional)

```
Código:          5498
Tipo:            Haber Remunerativo
Orden Cálculo:   999
Fórmula:         ROUND(REMUNERATIVO_BRUTO - TOTAL_DESCUENTOS, 1) - (REMUNERATIVO_BRUTO - TOTAL_DESCUENTOS)
Activo:          false  (activar si el CCT requiere neto redondeado al peso)
```

---

## Resolución de problemas

| Problema | Causa probable | Solución |
|---|---|---|
| Concepto no aparece en las líneas | `Activo = false`, condición falsa, o CCT no asignado | Verificar `Activo`, condición, y solapa Convenios aplicables |
| Importe incorrecto | Versión vieja de concepto o parámetro | Verificar fechas de vigencia vs fecha del período |
| "El empleado no tiene estado" | Falta registro en Estado Empleado | Asignar estado en la ficha del empleado |
| Acumulador en 0 | El concepto no tiene fracciones configuradas | Agregar filas en Distribución en acumuladores |
| Base SS o OS incorrecta | Fracción mal configurada o falta `BASE_SS`/`BASE_OS` | Revisar las fracciones del concepto |
| "El período está cerrado" | Estado = Cerrado | Reapertura manual por administrador |
| Fuente dinámica devuelve 0 | Filtros incorrectos o datos no cargados | Verificar IDs de tabla/campo y tokens en filtro |
| Resultado con muchos decimales | Fórmula sin `ROUND` | Envolver la fórmula en `ROUND(..., 0,01)` |
| Concepto no aplica al CCT | Vigencia CCT posterior a fecha del período | Verificar fecha de vigencia en solapa Convenios aplicables |
| `DIAS_MAR` vale 0 en Cierre Marea | El Job no tiene `Ending Date` asignado | Cerrar la marea (asignar fecha de fin al Job) antes de crear el Cierre Marea |
| Liquidación de Cierre Marea sin líneas | Job sin fecha de fin; conceptos con condición `DIAS_MAR > 0` no se evalúan | Verificar Ending Date del proyecto |
| FactBox "Variables del Cálculo" vacío | La liquidación no fue calculada aún, o los conceptos no usan variables | Calcular primero; verificar fórmulas |
