---
tipo: tabla
tags: [modelo-datos, conceptos, effective-dating, motor]
fuente: [src/Tables/Tab60007.ConceptoLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Concepto Liquidación (60007)

## Propósito
Catálogo de **conceptos** del recibo (haberes, descuentos, contribuciones, acumuladores, informativos). Cada fila es una **versión** de un concepto: `Código` + `Vigencia Desde`. Lleva la fórmula, la condición, el orden de cálculo y todo lo que el motor necesita para generar una [[Tabla - Línea Liquidación]]. Es el centro de la configuración: ver [[avoid-tables-principle]].

> [!note] Tres vigencias independientes
> La **fórmula** se versiona acá; la **distribución** (fracciones a acumuladores) en [[Tabla - Fracción Acumulador]]; los **convenios** en [[Tabla - Concepto CCT Vigente]]. No se mueven juntas. Ver [[conceptos-tres-vigencias]].

## PK e índices
| Clave | Campos |
|---|---|
| PK (clustered) | `Código`, `Vigencia Desde` |
| K2 | `Orden Cálculo`, `Código` |
| K3 | `Aplica A`, `Vigencia Desde`, `Vigencia Hasta` (acompaña a `SelectConceptos` de `Cod50014`) |

FieldGroups: DropDown (Código, Descripción, Tipo Concepto), Brick. Sin SumIndexFields.

## Campos (agrupados)
| Grupo | Campos | Propósito |
|---|---|---|
| Identidad | `Código`, `Vigencia Desde`, `Vigencia Hasta`, `Descripción`, `Nombre Impresión` | `Vigencia Hasta` 0D = abierta |
| Clasificación | `Tipo Concepto` (5, enum [[Enums de liquidación#Tipo Concepto Liq]]), `Grupo Costo Laboral` (9), `Aplica A` (10), `Tipos Liq. Aplicables` (22, Text[250]) | `Tipos Liq. Aplicables` es una lista de códigos de [[Tabla - Tipo Liquidación]]; **vacío = comodín (aplica a todos)**, ver [[vacio-en-tipos-liq-aplicables-es-comodin]] |
| Cálculo | `Fórmula` (6, Text[2048]), `Condición` (7), `Orden Cálculo` (8) | Ver validaciones |
| Acumulador | `Es Acumulador` (13) | Concepto sin fórmula que recibe aportes de otros ([[acumuladores-orden-calculo]]) |
| Presentación | `Variable Cantidad` (16), `Variable Base` (21) (Code[100], nombre **o expresión**), `Unidad Cantidad` (17 → `Unit of Measure`), `Imprime en Recibo` (19, InitValue true), `Etiqueta Det. Ganancias` (18), `Cód. Tipo Atributo Detalle` (25 → `Tipo Atributo Liq.`) | Sólo columnas de lectura; no intervienen en el importe |
| Resolución | `Par CCT a Usar` (24, enum [[Enums de liquidación#Par CCT Liq]]) | Con qué convenio/categoría se resuelven los parámetros del concepto: Entidad (default) o Puesto |
| Francos | `Es Devengo` (20), `Rol Franco` (23, enum [[Enums de liquidación#Rol Franco Liq]]), `Cód. Parámetro Valor` (26), `Cód. Tipo Atributo Precio` (27), `Divisor Valor` (28) | Valuación de lotes del ledger de francos ([[francos-fifo-ledger]], [[valor-franco-por-terna]]) |
| FlowField | `Vigencia CCT Más Reciente` (15) | `Max("Concepto CCT Vigente"."Vigencia Desde")`; 0D = sin restricción de convenio |
| Obsoletos | `Activo` (11, Pending), `Aplica Tipo Liq.` (14, Pending) | `Activo` **no tiene efecto**: la baja se expresa con `Vigencia Hasta`. Quedan filas con `Activo = false` que *ahora calculan* (página `Pag110006 Versiones inactivas a revisar`) |

## TableRelations
`Unidad Cantidad` → `Unit of Measure.Code`; `Cód. Tipo Atributo Detalle` y `Cód. Tipo Atributo Precio` → `Tipo Atributo Liq.`.

## Triggers y validaciones con lógica real
- **OnValidate de `Fórmula` y `Condición`**: primero `Formateador Fórmula Liq.` (`Cod110033`) la deja en forma canónica; pasada 1: sintaxis en modo tolerante (error duro); pasada 2: existencia de variables (modo estricto + "modo validación" que parsea también las ramas no elegidas de IF/CASE) → sólo **Message** "Variable desconocida" (no bloquea). El universo conocido se arma en `BuildKnownVarsCtx` con: `Parámetro."Nombre Variable"` (+`_ESFCY`), `Variable Sistema Liq.` activas, `Fuente Datos Liquidación` activas, acumuladores y los tokens de runtime `COD_ZONA`, `CANT_INCIDENCIA`, `ES_JUBILADO`, `ES_GROSSING_UP`, `NETO_GARANTIZADO(_ESFCY)`, `COMPLEMENTO_GU`.
- **OnValidate de `Variable Cantidad`/`Variable Base`**: sólo sintaxis (los nombres se validan solos porque el campo se carga antes de que exista el destino).
- **OnInsert**: `ValidarIntervalo`, `ValidarNoSuperponeConAnterior`, `SincronizarContiguidad` (cierra la anterior si estaba abierta; cierra la nueva contra la siguiente si se intercala), `ValidarNoPisaSiguiente`, y `Historial Fórmulas Liq.`.RegistrarAlta.
- **OnModify**: si cambia `Vigencia Hasta` → intervalo + `ValidarSinUsoPosteriorA` (no se puede cerrar por delante de una liquidación **no Borrador** que ya usó esta versión) + no pisar siguiente. Siempre registra en el historial ([[Tabla - Historial Fórmula Concepto]], tabla 110002).
- **OnDelete**: bloquea si la versión fue usada (`ValidarSinUsoAlguno`); si es la **última vigencia**: bloquea si otra fórmula/condición nombra el código (como identificador completo), bloquea si lo referencian `Variable Sistema Liq.`, `Novedad Liquidación` sin liquidar, `Préstamo Empleado` o los punteros de `Human Resources Setup` (`Cód. Concepto Neto Garantizado`, `Cód. Acum. Haberes Gravados`); y limpia fracciones y restricciones de convenio huérfanas. Luego reabre la anterior y registra la baja.
- **OnRename**: **prohibido cambiar el `Código`** (las fórmulas lo nombran como texto libre: `@1052`, `#1052`; renombrar las deja resolviendo cero sin error). Sí permite mover `Vigencia Desde` (revalida y reencadena). Camino correcto: `CopiarEn()` ("Copiar como…") y cerrar la vigencia del viejo.
- `CopiarEn(NuevoCodigo)`: copia el concepto, **todas** las fracciones y **todas** las restricciones de convenio (sin filas de convenio = aplica a todos; no copiarlas liquidaría a toda la nómina).
- `VigenteA(FechaRef)` y `FiltrarVigentesA(FechaRef)`: **únicos** lugares donde se decide la vigencia. `FiltrarVigentesA` sólo filtra `Vigencia Desde <= fecha`; **todo consumidor debe cerrar con `VigenteA`** sobre el registro elegido.

## Quién la lee / escribe
Lee: `Cod50014.MotorLiquidacion` (`SelectConceptos`, `BuildLatestVersionCache`), `Cod50015.EvaluadorFormula`, `Cod50016`, `Cod50053.GestionFrancos`, `Cod50055.GestionTipoLiq`, `Cod50060.CatalogoVariablesLiq`, `Cod50061.GestionNovedadesLiq`, `Cod50067.ControlOrdenAcumuladores`, `Cod110039/110044/110055` (presentación). Escribe: páginas `Pag50107` (lista), `Pag50145 Concepto Liq Card`, editor de fórmulas (control add-in), `Cod50070.HistorialFormulasLiq`. Referencian el código: [[Tabla - Fracción Acumulador]], [[Tabla - Concepto CCT Vigente]], [[Tabla - Incidencia Liquidación]], [[Tabla - Variable Sistema Liq]], [[Tabla - Préstamo Empleado]], `Tab110038 Novedad Liquidación`.

## Vigencias
Intervalo `[Vigencia Desde, Vigencia Hasta]` por código, encadenado: insertar una versión cierra la anterior el día previo; un **hueco** deliberado (cerrar en marzo, volver en julio) se respeta y la superposición se rechaza. [[Tabla - Línea Liquidación]] guarda `Vigencia Concepto` para reproducir el cálculo.

## Trampas conocidas
> [!danger] Un concepto inexistente no da error: vale cero
> Una fórmula que nombra una variable o un concepto borrado resuelve **cero** y sigue. Por eso las validaciones de borrado y de renombrado son duras. Casos: BASE_SS/BASE_OS. Ver [[acumuladores-orden-calculo]], [[control-precedencia-formulas]], [[variables-rotas-valen-cero]].

- Un concepto que corre **antes** de lo que lee da importe bajo sin error: [[concepto-negativo-despues-de-sus-consumidores]].
- `@` re-evalúa con el par de quien llama; ver [[arroba-ignora-el-par-del-concepto]].
- Tipo de liquidación en blanco: [[migracion-tipo-liq-incompleta]], [[lote-tipo-liq-en-blanco]].
- Anticipos sin fórmula a propósito: [[anticipos-como-novedades]].
- `Format()` no se valida al compilar: [[format-no-se-valida-al-compilar]].

Ver [[Mapa del modelo de datos - configuración y empleado]].
