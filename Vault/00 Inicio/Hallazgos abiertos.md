---
tipo: guia
tags: [inicio, hallazgos, pendientes]
actualizado: 2026-10-08
---

# Hallazgos abiertos

Cosas que el análisis del 2026-10-04 encontró **leyendo el código y los scripts**, sin ejecutarlas ni verificarlas en la base. Son candidatos a revisar, no cambios hechos. Cuando se resuelva uno, borrarlo de acá y, si corresponde, dejar una lección.

> [!note] Origen
> Salen de los reportes de los agentes que redactaron cada área del vault. Cada ítem enlaza a la nota donde está el detalle.

## Código: probables bugs

| # | Hallazgo | Detalle |
|---|---|---|
| 1 | `Sinc NAV Liq.ReprocesarErrores` no arma el `RecordRef` para Informe del Capitán ni Diario de Abordo: falla en ejecución para esas entidades | [[Sincronización NAV - operación y errores]] |
| 2 | Las bajas de NAV se detectan (`Cod110041.Delta` arma `Bajas`) pero ningún código las aplica; el estado `Omitido` no lo asigna nadie | [[Sincronización NAV - visión general]] |
| 3 | `Tipo Liquidación.CodigoArribo()` lee la bandera obsoleta `Liquida al Arribo`, no `Disparador = Arribo`: un tipo de cierre creado sólo con el disparador hace fallar `CrearCierreMarea` | [[Tipos de liquidación]], [[Tabla - Tipo Liquidación]] |
| 4 | El control de cobertura usa el envolvente de `Cobertura Desde/Hasta` (`AjustarCabeceraAlEnvolvente`): el hueco entre dos tramos figura cubierto | [[Cobertura y tramos]], [[Control de períodos liquidados]] |
| 5 | SIRADIG: el control "ya importado" nunca dispara (`No.` autoincremental, clave `K2` no única); "Procesar Importación" no funciona sobre archivos subidos; deducciones de importaciones en fechas distintas quedan en vigencias distintas y el motor lee sólo la última | [[SIRADIG - importación]], [[SIRADIG - modelo y parser]] |
| 6 | `Liquidación.OnDelete` no limpia `Detalle Ganancias Liq.` ni `Resumen Variable Liq.` (no se verificó otro camino) | [[Tabla - Liquidación]] |
| 7 | `Ded. Ganancias Empleado` con `Importe Fijo = 0` no deduce; `Ded. Ganancias Vigente` no la lee el motor | [[Deducciones de Ganancias y familiares]] |
| 8 | `ResumenPorCategoria` (grilla Francos por Tripulante) valúa a valor pleno: sobrestima los lotes de tangonero (30%) | [[Valor del franco]] |
| 9 | `Rep50044` exige `Importe ≠ 0`: no puede cargar un cero explícito ni una incidencia de sólo cantidad | [[Incidencias masivas]] |
| 10 | Rep50042 `Asignar Estado Masivo`: el mensaje de omitidos siempre da 0 | [[Altas masivas y migraciones de fechas]] |
| 11 | `EntraEnCorrida` reenciende su bandera y `AplicarA` revierte `Aplica A` de VACACIONES en cada upgrade, contra el comentario "no pisa lo cargado a mano" | [[Install y Upgrade - qué siembra cada uno]] |
| 12 | Las cachés del motor no se comparten entre liquidaciones de un lote (cada una crea su `Motor`), al revés de lo que dicen los comentarios | [[Rendimiento y caché del cálculo]] |
| 13 | `YTD_ACUM`/`PERIODO_ACUM` usan la fracción más vieja vigente; el cálculo usa la más reciente. Si cambia el signo entre vigencias, discrepan | [[Acumuladores y fracciones]] |
| 14 | `Variable Sistema Liq.`: `DIAS_MES`, `MESES_PROM_AUS_6/12`, `DIAS_ESTADO_PERIODO` y `DIAS_ESTADO_PREVIOS` están en el motor pero no en el menú ni en `Sembrar` | [[Variables de sistema]] |
| 15 | Tablas/enums sin uso: `Diag. Fuente Datos Buffer` (110036), enums `Tabla Origen Liq.`, `SIRADIG Código Deducción`, `SIRADIG Parentesco`; código muerto en `Tipo Atributo Liq.` (`DesufijarESFCY`) | [[Índice Modelo de datos (110xxx)]], [[Enums de liquidación]] |
| 16 | **`VALOR_FRANCO` de los oficiales es un precio en dólares congelado en pesos.** Las ocho filas `OF01..OF04` de `175/75`, `768/19` y `ESP_FE0x` están cargadas sin `Moneda` y sin `Cód. Variable TC`, y **todas son exactamente USD × 1415**: OF01 162.725 = 115, OF02 141.500 = 100, OF03 127.350 = 90, OF04 120.275 = 85. La columna `PR_FRANCO` de Meta4 es `USD × TC del día` (24/01: 90 × 1405 = 126.450; nov: ×1425; mayo: ×1365). BC acierta sólo al TC 1415 y se desactualiza con cada movimiento; el error llega al pago cuando el lote se consume. Las de `729/15 MR0x` **no** son múltiplos de 1415: ésas sí son pesos del CCT y están bien. Se arregla con la maquinaria de TC por parámetro ya construida | [[Valor del franco]], [[control-moneda-es-asimetrico]], [[Grossing-up y tipo de cambio]] |

## Permisos

13 tablas persistentes no figuran en ninguno de los tres permission sets (entre ellas `Filtro Fuente Datos Liq.`, `Estado Tipo Liq.`, `Tramo Cobertura Liq.`, `Préstamo Empleado`, `Cuota Préstamo`, las dos de SIRADIG, las tres de `Hist. Meta4`, `Stg Valor Dim NAV` y las dos `Diag.`). El motor usa `Estado Tipo Liq.` y `Tramo Cobertura Liq.` en cada cálculo: un liquidador sin SUPER podría fallar. Cruce estático, **sin probar con un usuario sin SUPER**. Ver [[Permission sets de la extensión]].

## Repositorio y seguridad de datos

- La raíz pesa ~890 MB: 68 `.app`, 57 xlsx, 94 PDF. Las carpetas `2026-01`…`2026-08` son **recibos de sueldo de Meta4 con CUIL e importes**. Ver [[Mapa de la raíz del repo]] (incluye una propuesta de `.gitignore`, no aplicada).
- En el índice de git sin commit: `PackageLIQUIDACION.rapidstart` (export completo de BC con datos de empleados), `Oracle.ManagedDataAccess.dll`, un `.alcpuprofile`, un `.tsv` de recibos y un `.msg`.
- `.claude/settings*.json` apuntan a la ruta vieja `d:\…\OneDrive\Personal\…`: sus reglas ya no coinciden.
- El último commit es del 20/9/2026; 76 archivos modificados y ~38 sin seguimiento.
- `.vscode/rad.json` reapareció el 3/10 con `Removed` de 2 entradas (página «Control Liquidación Período» 110055, hoy 110056); no son tablas. Ver [[rad.json - peligro]].

## Scripts y migraciones

- Cinco scripts de BC escriben en vivo sin transacción manual; casi todos fijan empresa `ArbuTest`, base `Migr2013R2` y el AppId. Ver [[Catálogo de scripts SQL y PowerShell]].
- `MigrarEstados_2` asigna el proyecto por `Devenga Francos` (regla ya reconocida como errónea, ver [[gp-devenga-francos-pero-es-improductivo]]). `MigrarFasesAlta_1` trae `ID_SOCIEDAD = 'COMPLETAR'`.
- No hay script versionado de la historia Meta4 (`Hist. Liq. Meta4`), de `HIST_REMUN`, de novedades ni de anticipos. Ver [[Migración desde Meta4 - mapa y orden de ejecución]].
- Contradicciones de memoria sin resolver: si `M4T_HIST_PUESTOS` se migró ([[puesto-vs-categoria-cct]] dice que no; el script dice que sí, 18/9/2026) y si la categoría exacta de `M4T_HIST_CATEGORIAS` se migró ([[Migración Meta4 - atributos CCT, puestos y ausentismos]]).

## Paralelo de enero 2026: diferencias que siguen sin explicación

Residuos del cotejo contra Meta4, al 8/10/2026. No son hallazgos de lectura de código: son diferencias medidas que ya no tienen causa identificada.

| Caso | Diferencia | Qué se sabe |
|---|---|---|
| Cierre de marea del 04826 | 491.750 de más en BC | **Causa identificada y criterio confirmado.** Meta4 prorrateó su neto acordado sobre los 22 días de navegación (`15.000 × 22/30 × 0,70 × 1405` = 10.818.500, exacto) y BC sobre los 23 de marea. Pero el 04921 cuadra al centavo con sus **27** (26 nav + 1 puerto) y los dos tienen el día de puerto el 2/1: ninguna regla única da valores redondos para ambos. Se confirmó `DIAS_MAREA` como criterio, así que este residuo queda asignado a Meta4 |
| Regular del 04921 | 2.795,71 de más en BC | **A propósito.** `VALOR_FRANCO_CAL` de OF02 se mantiene en 3.600 (acuerdo de empresa de calamar) y Meta4 paga el equivalente a 3.500, el de langostino. Ver [[franco-tres-niveles-de-precio]] |
| ~~`PRECIO_PUERTO`~~ | **resuelto el 8/10/2026** | Eran 45 vigencias de la lista vieja sin partir por pesquería (marinería 729/15, MR00–MR08), sin fila en `Parámetro` y sin ningún lector: el 1083 nombra `PRECIO_PUERTO_CAL` y `PRECIO_PUERTO_LAN` explícitamente en las dos ramas de su `IF`, y la búsqueda que las dio por referenciadas matcheaba por prefijo. 36 eran idénticas a su gemela de `_LAN` y las 9 restantes, todas del 1/5, traían el valor anterior al split ([[precio-puerto-lista-inconsistente]]). Borradas; no queda **ninguna** base de parámetro huérfana en la base |
| Saldos iniciales de francos | sin medir | El del 04826 (OF04) viene sellado con convenio 768/19, contra la regla OF02/OF04 → 175/75. No se contó cuántos más tienen el par cruzado |
| **Contribuciones** | 114,4 M, y sólo 1 de 331 empleados coincide | Recién incorporadas al comparador; sin analizar |
| 2003 del cierre del 03664 | 1.415.000 de más, en la rama de producción | — |
| 23 períodos cerrados | sin fecha ni usuario de cierre | Anteriores a que el `OnValidate` del estado los estampara; falta decidir si se rellenan |
| `Fórmula Evaluada` ≠ `Importe` | visto 3 veces | El panel *Datos utilizados* muestra los valores reales; afecta la auditabilidad, no el importe |
| Nueve `TableRelation` a `Período Liquidación` | sin filtro de estado | Sólo se arreglaron las de Novedades; las otras siguen ofreciendo períodos cerrados |

## Lecciones que el código ya no respalda

Las que el análisis detectó desactualizadas (cada una lleva o debe llevar un callout de verificación): [[tipo-liq-no-implementada]] (`TIPO_LIQ` sí existe), [[variables-rotas-valen-cero]], [[acumuladores-orden-calculo]] (`Invertir Signo`, no `Restar`), [[puesto-vs-categoria-cct]] (`ParDePuesto` devuelve el par completo), [[francos-fifo-ledger]] (el precio sale de la categoría de la liquidación que paga). Detalle en [[Divergencias entre documentación vieja y código]].

## Sin verificar en este análisis

La suite de tests AL (70 `[Test]`) no se ejecutó; sí corrió y pasa `test/editorFormula.atributos.test.cjs`. Tampoco se comprobaron contra la base: si las propuestas de tope SIPA y de grossing-up/TC están aplicadas, el estado de las cargas de valores 2026 (calamar, langostino) ni si el `.rdl` del recibo muestra bien un concepto `Informativo`.

## Interfaz y recibo

- **`Contabilizada`** existe en el enum de estado de la liquidación pero ningún código la asigna; no hay asiento contable ni Libro de Sueldos Digital, aunque la propuesta comercial los promete. Ver [[Estados y transiciones de una liquidación]].
- **CUIL del recibo** sale de `Social Security No.`, que según [[cuil-vive-en-cif-nif]] está vacío: probablemente sale en blanco (sin verificar). Ver [[Recibo de sueldo (reporte)]].
- El diseño predeterminado *Decreto* del recibo no imprime las variables «Mostrar en Recibo»; «Solo aprobadas» viene destildada (imprime Borradores); la antigüedad impresa es años ÷ 365, no la suma de fases del cálculo.
- **Tooltips desactualizados:** *Par CCT a Usar* y el Asistente de Fórmulas mencionan la asignación al proyecto (hoy es por atributos); Lanzador, *Calcular Período*, Lista y Árbol dicen «Borrador o Calculada» pero sólo calculan Borrador. «Crear Liquidaciones» y «Calcular Período» de Períodos están fijos en `REGULAR`.
- *Cerrar Período* dice «no se puede deshacer» pero existe *Reabrir Período*, y no verifica que todo esté aprobado. Ver [[Discrepancias de la guía original con el código]].
- Objetos sin permisos en ningún set: informes *Crear Liq. para Empleado*, *Insertar Incidencia Masiva*, *Avisos del Cálculo* y varias páginas (SIRADIG, Préstamos, *Tramos Cobertura Sub*, *Selector Tipos Liq.*…). Ver [[Perfiles, Role Center y permisos]].