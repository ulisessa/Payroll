# Revisión de rendimiento de Payroll

Fecha: 18/09/2026. Versión declarada: 1.0.0.470. Business Central 25.2, runtime AL 14, OnPrem.

Se realizó un inventario y barrido estático de los 293 archivos AL de `src`, una revisión dirigida del motor, contexto, evaluador, lotes, francos, índices y pruebas, y una inspección de los puntos de acceso a datos de pantallas, informes e integración. Esto no equivale a una auditoría funcional exhaustiva de cada objeto. Se revisó el código local, incluidos sus cambios sin confirmar. No se modificó código productivo ni se ejecutaron liquidaciones o pruebas en Business Central.

El archivo `PerformanceProfile_Session9.alcpuprofile` corresponde al 08/09/2026 y a la versión 1.0.0.411: concentra muestras en `ResolveFuente` y `CalcFinEfectivo`. Sirve como antecedente para priorizar, no como medición de la versión actual. Los hitCount del perfil no se interpretan como número de consultas SQL. Sin un perfil nuevo y volúmenes de datos no es posible prometer un porcentaje de aceleración.

La mayor oportunidad está en reducir lecturas y escrituras repetidas conservando las mismas reglas, datos históricos y auditoría.

## 1. Prioridad alta: resolver el fin efectivo una sola vez por fecha

Evidencia: `src/Codeunits/Cod50016.ContextoLiquidacion.al:2082`, `CalcFinEfectivo`; carga de fechas en la línea 2109.

Ya existe una caché de fechas por fuente. Sin embargo, cada fila vuelve a recorrer la lista completa para encontrar el menor inicio estrictamente posterior. Con N filas evaluadas y M fechas de la entidad se hacen hasta N × M comparaciones en memoria; cuando ambos crecen juntos, el costo es cuadrático.

Propuesta: ordenar y deduplicar las fechas una sola vez y construir un diccionario inicio → siguiente inicio menos un día. Una búsqueda binaria es otra opción si se necesitan consultas de fechas que no pertenezcan a la lista. La clave de la caché debe identificar correctamente la fuente y su ámbito resuelto; conservar su reinicio por liquidación.

Preservar: siguiente fecha estrictamente mayor, fechas repetidas, intervalo final abierto, filtros token de entidad y exclusión deliberada de filtros constantes al buscar el siguiente estado. No recortar la lista al mes: se perdería el estado posterior que cierra un intervalo. No eliminar historia.

Impacto potencial alto en empleados con mucho historial; riesgo acotado si se verifica equivalencia de los intervalos.

## 2. Prioridad alta: preparar los datos constantes de cada liquidación

Evidencia en `src/Codeunits/Cod50014.MotorLiquidacion.al`:

- Línea 400: `Incid.Get` dentro del recorrido de conceptos, repetido en cada pasada.
- Línea 633: `AplicarParDeConcepto` vuelve a resolver período y par de puesto.
- Línea 1100: `CCTAplicaAConcepto` ejecuta `CalcFields`, búsquedas de exclusión, `IsEmpty`, `FindLast` y `Get`.
- Líneas 311 y 345: validación y cálculo consultan aplicabilidad; grossing-up repite el cálculo.

Propuesta: cargar incidencias en un buffer temporal después de materializar préstamos y novedades; resolver el par de puesto una vez; memorizar la aplicabilidad por concepto, convenio, categoría y fecha durante esa liquidación. Registrar también resultados negativos en la caché.

Esto reduce invocaciones repetidas; la reducción efectiva de viajes a SQL depende también de las cachés de la plataforma y debe medirse.

Preservar: orden de cálculo, incidencias que fuerzan conceptos fuera del convenio, incidencias de cantidad con importe cero, versiones y exclusiones, y alternancia entre par base y puesto. No guardar importes calculados en una caché de aplicabilidad. Reiniciar al comenzar otra liquidación.

## 3. Prioridad alta: filtrar y agregar los francos en la base

Evidencia: `src/Codeunits/Cod50053.GestionFrancos.al:319`, `TotalConsumido`, recorre las líneas del empleado y recién después comprueba si el concepto pertenece a consumo. `TotalPorRolHasta` hace algo similar en la línea 57. `TotalDevengado`, línea 306, suma cantidades fila por fila.

Propuesta inicial: aplicar el conjunto exacto de conceptos como filtro antes de recuperar filas y seleccionar solamente los campos necesarios. Para totales escalares, evaluar `CalcSums(Cantidad)` con los mismos filtros. Reutilizar los códigos por rol y el valor diario por convenio/categoría/fecha dentro de una operación. Los recorridos FIFO siguen siendo necesarios para distribuir el consumo entre lotes.

Preservar exactamente los filtros actuales de liquidación excluida y fechas inclusivas/exclusivas. No cambiar simultáneamente el tratamiento de estados borrador ni la política temporal del ledger: eso sería una modificación funcional separada. Construir filtros sin reinterpretar caracteres especiales de los códigos.

## 4. Prioridad alta/media: alinear agregaciones históricas e índices

Evidencia: `src/Codeunits/Cod50016.ContextoLiquidacion.al:755`, `:805`, `:858` y `:903`. Se ejecutan sumas por concepto para acumuladores anuales y de período. Los filtros incluyen `Estado`, `Cód. Concepto` y, en algunos casos, exclusión de la liquidación actual.

En `src/Tables/Tab60012.LineaLiquidacion.al:213`, K4 y K5 contienen empleado, fecha/período y tipo, pero no todos esos filtros. Por ello no debe suponerse que sus SIFT resuelven íntegramente estas sumas.

Propuesta: comparar dos alternativas con SQL y perfil AL: precargar/agrupar el historial necesario de un empleado una vez durante la construcción de su contexto, o incorporar una clave adaptada a las consultas dominantes. No crear varios índices por intuición: cada inserción y borrado del grossing-up también debe mantenerlos.

Preservar: signos, vigencias, exclusiones, ámbito anual frente a período y diferencias entre las rutinas. La elección de qué vigencia de fracción aporta el signo merece pruebas específicas; esta revisión no propone cambiarla como parte de una optimización.

## 5. Prioridad media: cargar menos campos de las fuentes dinámicas

Evidencia: `src/Codeunits/Cod50016.ContextoLiquidacion.al:1950`. SUM, MIN y MAX recorren registros; los agregados de fechas también usan `RecordRef` sin selección parcial explícita. `GetFechasInicioFuente` sólo necesita la fecha, pero carga el registro.

Propuesta: usar `RecordRef.SetLoadFields` con los campos normales efectivamente necesarios, resueltos mediante `CampoFuenteCanonico`. Para SUM de campos numéricos normales, evaluar agregación SQL conservando una ruta compatible con los tipos y conversiones que hoy admite la configuración.

Preservar: filtros token, valor vacío, equivalencias de campos heredados, tipo de campo y conversiones. No sustituir genéricamente MIN/MAX por primera/última fila sin una clave que garantice el mismo resultado. Evitar lecturas adicionales por acceder después a campos no cargados.

No recomiendo simplemente dejar de resolver fuentes que no aparecen en una fórmula: `SaveResumenVariables` conserva valores para auditoría y recibos. Esa simplificación podría perder información.

## 6. Prioridad media: reutilizar configuración con un ciclo de vida explícito

Evidencia: `src/Codeunits/Cod50016.ContextoLiquidacion.al:515`, `BuildParametroCache`, recorre las vigencias hasta la fecha de referencia. Las cachés del motor son variables de instancia. En la ruta de selección, `LotesLiquidacionLiq.Calcular` llama a `LiquidarConRegistro`, que ejecuta `Ejecutor Liquidación`; el `OnRun` de este último declara su propio `Motor` local (`src/Codeunits/Cod50069.EjecutorLiquidacion.al:22`).

El motor exterior del lote no es el mismo que construye las cachés de cálculo. Por tanto, el comentario sobre reutilización entre empleados no basta para garantizarla en esta ruta.

Propuesta: una instantánea de configuración por lote y fecha, pasada explícitamente a los ejecutores o administrada mediante un servicio con inicio y fin definidos. Empezar por catálogos, fracciones y parámetros de configuración. Medir la reconstrucción actual antes de extender el alcance.

Preservar: empresa, fecha efectiva de arribo, vigencias, cambios de configuración y limpieza tras errores. Nunca compartir contexto, saldos, incidencias o valores de empleado entre liquidaciones. Mantener la transacción independiente por liquidación y el registro de fallas.

## 7. Mayor cambio estructural: grossing-up con resultados temporales

Evidencia: `src/Codeunits/Cod50014.MotorLiquidacion.al:2012`. Hasta 20 iteraciones llaman a `CalcNetoDesdeBD`, `DeleteLineas` y `RunConceptos`; este último inserta líneas físicas. La auditoría intermedia ya está suprimida, pero persisten las escrituras de resultados y el mantenimiento de índices. Cuando hubo iteraciones, existe además una pasada final auditada.

Propuesta: separar evaluación y persistencia. Calcular cada iteración en buffers temporales, obtener el neto de esos buffers y guardar una vez el resultado final con toda su auditoría.

Impacto potencial alto para liquidaciones con varias iteraciones; riesgo mayor que las propuestas anteriores. Antes hay que rastrear todos los lectores de líneas, incluidos francos, fuentes configurables, triggers y extensiones dependientes. Una lectura que hoy depende de una línea recién insertada debe ver el buffer equivalente. No basta con declarar temporal una variable.

Mantener el algoritmo, la tolerancia de 0,01, los redondeos y el límite de iteraciones durante esta refactorización. Definir por separado qué debe ocurrir si se alcanza el límite sin converger; actualmente el bloque termina sin un error explícito por ese motivo. No mezclar esa decisión funcional con la comparación de rendimiento.

## 8. Mejoras secundarias

- `MotorLiquidacion.al:1820`: resolver etiquetas consulta varios catálogos por variable. Transportar metadatos ya leídos por el contexto o cargarlos una vez conserva recibos y reduce búsquedas.
- `Cod110032.ProgresoLiq.al:58`: limitar la frecuencia de repintado del diálogo si una medición demuestra costo significativo. Mantener la actualización final y suficiente feedback en cálculos largos.
- `Cod50081.ControlMareaLiq.al:28`: la matriz lee líneas por liquidación. Una carga agrupada por proyecto puede mejorar pantallas grandes; requiere medir y mantener filtros.
- El evaluador vuelve a analizar el texto de fórmulas. Una caché de sintaxis sería una segunda etapa si aparece como costo importante en el nuevo perfil. Cachear sintaxis no autoriza a cachear resultados dependientes del contexto, `@`, `#`, condiciones o acumuladores.
- Integración NAV y SIRADIG tienen ciclos y límites de transacción propios. El barrido no aporta evidencia suficiente para atribuirles la lentitud del cálculo ni para recomendar eliminar sus commits de recuperación.

## Mejoras ya presentes que conviene conservar

Validación mediante nombres sin construir todos los valores; cachés de versiones y fracciones; caché de fechas de fin efectivo; caché de TRAMO y calendarios; caché de valores por par de convenio/categoría; supresión de auditoría intermedia en grossing-up; eliminación masiva de líneas con limpieza explícita del detalle; índices de sumas por liquidación. Varias recomendaciones generales de rendimiento ya están implementadas.

## Cómo comprobar que no se pierde información ni eficacia

Las pruebas visibles en `test/Codeunits` cubren el evaluador y el formateador. No se encontró allí una suite integral del motor que compare liquidaciones completas.

1. Tomar dos copias equivalentes de datos y configuración. Ejecutar versión actual y candidata sobre el mismo estado inicial: una segunda ejecución sobre la misma base puede ver préstamos, novedades y estados ya modificados.
2. Incluir regular, devengado, cierre de marea, grossing-up, consumo FIFO de varios lotes, incidencias manuales y de cantidad, par de puesto diferente, cambios de vigencia, varias liquidaciones del mismo mes y recálculo en cadena. Agregar un error deliberado dentro de un lote para verificar rollback y continuidad.
3. Comparar por empleado y concepto: importes, cantidades, bases, redondeos, acumuladores, neto, cobertura, fórmulas, vigencias, variables numéricas y texto, detalle de Ganancias, parámetros usados y contenido del recibo. Comparar también cuotas, novedades y estados resultantes. Identificadores técnicos y timestamps se normalizan explícitamente; no se ignoran diferencias funcionales.
4. Medir tiempo por liquidación y lote, consultas y filas SQL, escrituras, memoria, duración de transacciones e iteraciones GU. Separar primera ejecución de ejecuciones con cachés calientes.
5. Aceptar una optimización sólo con equivalencia funcional y mejora medida sobre datos representativos. Compilar no demuestra equivalencia de cálculo.

Orden recomendado: establecer la comparación integral; optimizar fechas e información constante por liquidación; filtrar francos y ajustar lectura/agregación de datos; medir de nuevo; recién después abordar persistencia única del grossing-up y configuración compartida entre empleados.

## Referencias técnicas

- [Microsoft: métodos AL y rendimiento SQL](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/optimize-sql-al-database-methods-and-performance-on-server): condiciones de uso de SIFT y costo de operaciones de agregación.
- [Microsoft: RecordRef.SetLoadFields](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/recordref/recordref-setloadfields-method): selección de campos para reducir lectura de datos.

Estas referencias sustentan los mecanismos de plataforma; las prioridades son inferencias del código inspeccionado, pendientes de validación con un perfil actual.
