---
tipo: concepto
tags: [motor, conceptos, vigencias, auditoria]
fuente: [src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50070.HistorialFormulasLiq.al, src/Tables/Tab110002.HistorialFormulaConcepto.al, src/Pages/Pag50145.ConceptoLiqCard.al, src/Pages/Pag50107.ConceptosLiquidacion.al]
actualizado: 2026-10-04
---

# Versionado de conceptos y fórmulas

Un concepto es **una cadena de versiones** con la misma clave de código: `Concepto Liquidación` tiene PK
`(Código, Vigencia Desde)`. Cada versión lleva su fórmula, condición, tipo, orden, etc. El motor usa la
versión **vigente a la fecha de referencia** de cada liquidación, de modo que **recalcular un período viejo
reproduce lo que se hizo entonces**. Hay **tres vigencias independientes** (concepto, distribución en
acumuladores y convenios aplicables): ver [[conceptos-tres-vigencias]] (esa lección documenta lo que quedó
abierto).

## Intervalo de la versión: `Vigencia Desde` / `Vigencia Hasta`

- `Vigencia Hasta` = **último día** en que la versión se aplica; `0D` = abierta. Reemplaza al booleano `Activo`, que ahora es **obsoleto y sin efecto** (una versión con `Activo = false` era "invisible" y el motor caía a la anterior activa; esas filas **ahora calculan**, hay que revisarlas en la página *Versiones inactivas a revisar*).
- `VigenteA(fecha)`: `Vigencia Desde <= fecha` y (`Vigencia Hasta` vacío o `>= fecha`). **Es el único lugar donde se decide** si una versión está en vigor.
- `FiltrarVigentesA(fecha)` sólo filtra `Vigencia Desde <= fecha` (candidatas). **Todo consumidor debe cerrar con `VigenteA` sobre el registro elegido**: filtrar el fin con "vacío o `>=`" sobre un campo Date no tiene precedente en el proyecto y falla silenciosamente (devuelve menos filas). Por eso los mapas (`BuildLatestVersionCache`, `CargarVersionesVigentes`) cierran sobre la ganadora.
- Un **hueco** es legítimo (cerrar en marzo, retomar en julio): un concepto en un hueco no devuelve nada, no "resucita" la versión de marzo (`EsAcumuladorVigente` filtra con el intervalo).

## Encadenamiento automático (`OnInsert`, `OnModify`, `OnDelete`, `OnRename`)

| Evento | Qué hace |
|---|---|
| Insert | valida intervalo, **no superponer con la anterior**, `SincronizarContiguidad` (si la anterior estaba abierta, la **cierra el día previo**; si se intercala entre dos, se cierra contra la siguiente), no pisar a la siguiente, `RegistrarAlta` en el historial |
| Modify de `Vigencia Hasta` | valida intervalo, **no cerrar antes de una liquidación que ya usó la versión** (`ValidarSinUsoPosteriorA`), no pisar a la siguiente. Correr el fin hacia adelante es siempre seguro |
| Delete | bloquea si **alguna liquidación no-Borrador usó la versión** (`BuscarUso` por `Vigencia Concepto`); si es la **última** vigencia del código: valida que ninguna fórmula/condición lo nombre (como identificador completo), que no lo use una variable de sistema/novedad pendiente/préstamo/puntero de Config. RRHH, y limpia fracciones y convenios huérfanos; reabre la anterior si la había cerrado esta |
| Rename | **el código no se puede cambiar** (error con instrucciones). La `Vigencia Desde` sí, revalidando contra las vecinas y reencadenando |

> [!danger] Por qué no se renombra un concepto
> El código viaja en el **texto** de las fórmulas (`@1052`, `#1052`, el nombre del acumulador pelado) y
> ahí ningún renombre llega: esas fórmulas **resolverían cero sin error**. Y las líneas ya liquidadas lo
> guardan para poder reproducirse. El camino es **«Copiar como…»** (crea el código nuevo llevándose
> fraccionamientos y convenios), corregir las fórmulas que nombran al viejo y recién entonces cerrarle la
> vigencia.

Una línea **bloquea** la versión mientras la liquidación esté `Calculada`, `Aprobada` o `Contabilizada`; una en `Borrador` se puede recalcular y no bloquea (la línea replica el estado de la cabecera: `Gestión Liquidación` lo sincroniza al aprobar y reabrir).

## Cómo se crea una versión nueva

- Acción **Nueva Vigencia** (lista y ficha): pide una fecha, copia el concepto **entero** con `Vigencia Hasta = 0D` y la fecha nueva; el insert cierra la anterior. Falla si ya existe esa vigencia. **No copia fracciones ni convenios**: tienen su propia vigencia y siguen valiendo hasta que otra fila las reemplace.
- Acción **Copiar como…**: crea un **código nuevo** con `CopiarEn`: copia el concepto, **todas** las vigencias de `Fracción Acumulador` y **todas** las filas de `Concepto CCT Vigente` (sin las filas de convenio, un concepto restringido a un convenio quedaría aplicando a toda la nómina).

Buenas prácticas: cambios de fórmula → **vigencia nueva**, no editar la vigente (las liquidaciones calculadas deben poder reproducirse). Excepción razonable: corregir un error en la versión que todavía no usó ninguna liquidación.

## Historial de fórmulas (`Historial Fórmulas Liq.`, Cod50070)

Registra los cambios de `Fórmula` y `Condición` en `Historial Fórmula Concepto` (110002). Se llama **desde los triggers de la tabla**, no desde la ficha, de modo que cubre **todos** los caminos: ficha, editor con IntelliSense, asistente, «Copiar como…», nueva vigencia y cargas de configuración.

| Tipo de cambio | Cuándo |
|---|---|
| `Alta` | insert con fórmula o condición no vacías |
| `Modificación` | cambió el texto de fórmula o condición |
| `Formato` | reformateo masivo (mismo cálculo, distinto texto): `RegistrarFormato`, porque las acciones de formateo guardan con `Modify(false)` |
| `Eliminación` | delete de una versión con texto (única oportunidad de conservarlo) |

Reglas finas:

- **El texto "anterior" sale de la base, no de `xRec`.** Cuando el guardado viene del editor (control add-in) BC reconstruye la página con `Rec` y `xRec` ya sincronizados y `xRec.Fórmula = Rec.Fórmula`: comparar contra `xRec` **no ve ningún cambio y no escribe, en silencio**. `OnModify` corre antes de escribir la fila, así que `Get` devuelve la versión anterior. Ver [[xrec-no-confiable-con-addin]].
- **Agrupación en sesiones de 15 minutos** (`VentanaAgrupacion`): ediciones sucesivas del mismo usuario sobre la misma versión se agrupan en una entrada (el editor guarda mientras se escribe con *debounce*). La ventana se mide desde el **inicio** de la sesión (`Fecha Hora` no se toca; `Última Edición` avanza). Si el texto vuelve al inicial, la entrada se **borra**. Pasados 15 minutos, entrada nueva encadenada.
- `Restaurar(entrada)`: devuelve el concepto al texto anterior de esa entrada (confirma) con `Modify(true)`, así **el propio restore queda registrado**. No se puede restaurar un `Alta`.
- Páginas: *Historial de fórmulas* (Pag110004: ver cambio, restaurar, abrir concepto).

## Validación al guardar

`Fórmula`/`Condición` pasan por el [[Formateador de fórmulas]] y por dos pasadas del evaluador (sintaxis, y existencia de variables), ver [[Evaluador de fórmulas - sintaxis]]. El camino del **editor con IntelliSense** asigna con `Rec.Fórmula := …; Modify(true)` (no `Validate`): **no corre el `OnValidate` del campo** (ni la validación ni el formateo del campo); el formateo se hace en `GuardarTextoDeEditor` y el diagnóstico en vivo cubre la validación. Ver [[Editor de fórmulas]].

## Parámetros y fracciones

Los parámetros no tienen `Vigencia Hasta` (un valor rige hasta el siguiente); las fracciones se versionan por su propia `Vigencia Desde`; las tablas escalonadas por versión completa. Ver [[Parámetros y vigencias]], [[Acumuladores y fracciones]], [[Tablas escalonadas]].

## Relacionado

[[Aplicabilidad de un concepto a una liquidación]] · [[Detalle del cálculo y trazabilidad]] · [[Tabla - Concepto Liquidación]] · [[al-sin-cortocircuito]]

**Tablas relacionadas:** [[Tabla - Historial Fórmula Concepto]] · [[Tabla - Concepto CCT Vigente]] · [[Tabla - Fracción Acumulador]]
