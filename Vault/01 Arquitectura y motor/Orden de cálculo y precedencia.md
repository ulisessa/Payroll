---
tipo: concepto
tags: [motor, orden-calculo, acumuladores, controles]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50067.ControlOrdenAcumuladores.al, src/Codeunits/Cod110074.CorreccionOrdenAcum.al, src/Pages/Pag50014.ControlOrdenAcumuladores.al, src/Pages/Pag50145.ConceptoLiqCard.al, src/Pages/Pag110074.CorregirOrdenAcumDialog.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50015.EvaluadorFormula.al]
actualizado: 2026-10-20
---

# Orden de cálculo y precedencia

Desde la corrección publicada el 20/10/2026 (1.0.0.673), el validador del motor y los
dos recorridos del control distinguen `AND`/`OR`/`NOT` de llamadas a funciones cuando
los sigue un paréntesis. No amplía las funciones permitidas ni las referencias estables
admisibles. El selector aislado `EjecutarValidadorOrden` pasó 18 pruebas AL, con las once
expresiones configuradas y comprobaciones positivas del orden resuelto; una prueba local
del evaluador por sí sola no cubre estos validadores. Ver [[Tests automatizados]] y
[[Revisión de conflictos de orden octubre 2026]].

> [!warning] Incidente de pruebas concurrentes detectado el 15/10/2026
> La primera corrida de pruebas de 660 coincidió con recálculos operativos. Esos cálculos leyeron
> conceptos sintéticos transitorios y los conservaron en 32 recibos de enero; siete tuvieron líneas
> remunerativas de prueba no nulas. Las comprobaciones sin concurrencia de 661/662 no cubrían ese
> efecto anterior. El usuario recalculó enero y la verificación estable posterior confirmó los 41
> recibos previstos Calculados, los siete corregidos y ausencia global de líneas de prueba y
> huérfanas. Febrero no se certifica inalterado por el otro trabajo concurrente confirmado por el
> usuario. La verificación fue sólo en lectura. Las suites que escriben configuración deben
> correr exclusivamente en empresa/BD de prueba aislada. Ver [[Tests automatizados]].

El motor recorre los conceptos **uno por uno** en el orden `(Orden Cálculo, Código)` (clave `K2` de
`Concepto Liquidación`). No hay grafo de dependencias: **el orden lo decide quien configura**. Lo que un
concepto lee tiene que estar ya calculado, y si no lo está, **lee cero o un subtotal, sin error**. Es el
error de configuración más silencioso del motor.

## Reglas del recorrido

- **Empates**: con el mismo `Orden Cálculo` corren por `Código` (orden de texto). Un empate sólo es problema si el código del que aporta cae **después** del que lee.
- Sólo se procesa la **fila ganadora** de cada código (la última `Vigencia Desde <= FechaRef`, no cerrada); su `Orden Cálculo` es el que vale. Si dos versiones tienen órdenes distintos, rige el de la versión en uso.
- Una **incidencia manual** hace que un concepto se recorra **en su orden** aunque no le aplique al empleado o al convenio (`SelectConceptosParaCalculo` no filtra por `Aplica A`). Antes se filtraba de entrada y la incidencia caía en `WriteIncidenciasRestantes`, que aporta al acumulador *al final*: mirando la liquidación el orden parecía correcto, pero el aporte llegaba tarde. Ver [[Incidencias en el motor]].
- Los acumuladores **no** se evalúan: sólo reciben.

## Las tres formas de leer un resultado ajeno

| Forma | Qué lee | ¿Depende del orden? |
|---|---|---|
| nombre de acumulador (`BASE_SS_TRAB`) | subtotal acumulado **hasta ese punto** | **Sí**: los aportes de orden mayor faltan |
| `#CÓDIGO` | `Ctx[CÓDIGO]` = importe ya calculado (con la incidencia que lo sobrescribió) | **Sí**: si no corrió aún, o su condición dio falso, vale 0 |
| `@CÓDIGO` | re-evalúa condición + fórmula del concepto en el contexto actual | **No** (pero ignora el par del concepto: [[arroba-ignora-el-par-del-concepto]]) |

Un `@` que a su vez lee un acumulador **hereda** el problema de orden del acumulador, y el análisis estático por texto no lo ve: para eso existe el control en runtime.

## Controles que existen

### 1. Estático: `Control Orden Acumuladores` (Cod50067, página 50014)

`Analizar(FechaRef, Buffer)` no liquida a nadie. La sobrecarga con tipo de liquidación,
convenio y categoría permite acotar la configuración. Revisa **cada acumulador vigente** y
las **fórmulas que dependen de resultados calculados**:

- **Aportes**: última fracción de cada par concepto/acumulador a la fecha. Porcentaje cero anula el aporte anterior. Se respeta el filtro de convenio cuando se conoce el par que valoriza la línea.
- **Orden**: usa `Motor.FormulaOrdenConfigurada`, no la columna numérica de compatibilidad. Intenta resolver el orden exacto; si faltan datos y hay un árbol `IF` con hojas enteras, comprueba todas sus posiciones posibles. Las demás expresiones quedan pendientes de contexto, sin inventar ceros ni elegir una rama por defecto.
- **Lecturas**: identificadores completos de fórmula, condición, cantidad, base, factor de consumo y cantidad de matriz, omitiendo cadenas y nombres de funciones. `#CONCEPTO` consume un resultado ya calculado. El nombre y `#ACUM` leen el subtotal. `@CONCEPTO` expande su fórmula y condición para heredar las dependencias reales; no exige que se haya ejecutado la definición referida.
- **Precedencia potencial**: se compara `(orden, código)` entre aportantes y lectores con orden resuelto. La igualdad del par propio no se marca. Los extremos consideran también el código en los empates.
- **Alcance**: los filtros de tipo y de par completo descartan conceptos incompatibles con la selección normal. Un par alternativo por puesto requiere información del empleado y se conserva como posibilidad. Las novedades manuales y condiciones no se deducen de estos filtros.

La página distingue **aportes posteriores**, **lectura por etapas** y **contexto insuficiente**.
Un lector que también aporta al mismo acumulador puede necesitar un subtotal deliberadamente
(por ejemplo, zona sobre una base que después incluye esa zona). No afirma que el importe sea
menor ni propone moverlo automáticamente después de todos los aportes: eso puede crear un ciclo.
La acción de abrir el concepto respeta la fecha de referencia.

Límites: no evalúa condiciones del empleado ni reconstruye incidencias. Un nombre sin prefijo
que ya está cargado en el contexto se distingue de una referencia calculada: puede leerse
antes de que se ejecute el concepto homónimo. Al mover un orden se conserva de qué lado de
esa publicación estaba la lectura, sin asumir que la variable prevalece durante todo el cálculo.
**Ausencia de avisos estáticos no demuestra igualdad con Meta4.**
Las lecturas efectivas, incluso indirectas, se registran durante el cálculo. El selector de pruebas
`Runner Tests Liq.` / `EjecutarControlOrden` ejecuta exclusivamente los casos de este diagnóstico,
con datos sintéticos y reversión por función.

Verificado en BC252 con la versión **1.0.0.658**: doce pruebas de orden configurado,
contexto faltante, fracciones anuladas, tipos y pares incompatibles, puesto alternativo,
desempates, subtotales y literales. Sin cambios en las seis tablas financieras controladas
antes y después de publicar y ejecutar las pruebas. Esta revisión no cambió las fórmulas
ni el orden de los conceptos de sueldo: los avisos globales no demostraron una diferencia
de importe en los casos consultados.

### 2. En runtime: `RegistrarLecturasAcumuladores` / `VerificarOrdenAporte` (Cod50014)

- Desde **1.0.0.660** se conservan lecturas por **acumulador y concepto lector**, para que un informativo temprano no tape a una lectura económica posterior. El nombre y `#ACUM` leen el subtotal; `@ACUM` no se normaliza como lectura del subtotal. Las lecturas indirectas de `@CONCEPTO` llegan por la traza del evaluador.
- Sólo cuentan aportes de importe distinto de cero y fracción vigente aplicable al convenio de valoración. Se excluye el aporte propio del lector; en un empate se compara el código.
- Se informa la lectura si produce una línea económica o un devengo, o si otro concepto con efecto consume su resultado, incluso mediante referencias calculadas o aportes ya recibidos por otra base. Un informativo sin uso, ni devengo, o una condición descartada sin consumidor no genera aviso. Si el lector también aporta, el mensaje identifica la posible **lectura por etapas**, sin afirmar una diferencia de importe.
- Las incidencias escritas fuera del bucle se registran con orden `999999999`.
- Se **reinicia por pasada** y se ignora en las vueltas de grossing-up (`FIteracionGU`); queda vigente el aviso de la **pasada final**.
- Salida: `FAvisosOrden` (va al mensaje consolidado con `AcumularAdvertencias`) y entradas filtrables en el registro (`Categoría Registro Liq."::"Orden Cálculo"`). Ver [[Avisos y advertencias del cálculo]].

### 3. Dependencias entre fórmulas

El mismo control incorpora una fila por **fórmula lectora** con referencias calculadas, incluso
si no participa de ningún acumulador. Muestra el lector, sus productores, el productor más
tardío y las precedencias potenciales. También conserva filas sin conflicto para comprobar
la estabilidad del lote. Referencias inexistentes, ciclos y órdenes no
verificables quedan pendientes; no se inventa un orden para resolverlos.

El buffer existente usa el código real del lector como clave de estas filas. Una versión
ganadora no puede ser simultáneamente acumulador y lector ordinario, por lo que no se
necesitan claves sintéticas, campos, tablas ni objetos nuevos. La pantalla distingue
**Acumulador** y **Fórmula** y reserva la consulta de fracciones para las primeras.

`#B` no expande las entradas de B como si se tratara de `@B`: B tiene su propia revisión.
Una cadena de `@` hereda las lecturas de sus definiciones sin imponer sus órdenes. Se
detectan autorreferencias y ciclos entre resultados calculados, además de las recursiones
de `@`. Un conflicto estático puede depender de condiciones que sólo se resuelven al liquidar.

La lección [[control-precedencia-formulas]] conserva el antecedente del script `precedencia.sql`
(no encontrado en el repo el 4/10/2026); el control y la corrección actuales están en AL.

**Publicada la ampliación en 1.0.0.668 (16/10/2026).** Comparte extracción de dependencias
entre diagnóstico y corrector, con catálogos y tokens por operación y grafos reconstruidos
desde versiones temporales vigentes. La ficha incorpora sus dependencias, sus consumidores
y sus bases; el lote general incluye ambos tipos de fila. No cambia el esquema ni agrega
campos de tabla, objetos o llamadas a `Commit`.

Compilación completa sin errores y revisión cruzada de parser, ciclos, alcance y excepciones
de cruce. Doce grupos nuevos elevan a 86 las pruebas del corrector; sólo se compilaron,
pendientes de ejecución en empresa/BD aislada. Publicación HTTP 200 e instalación 1.0.0.668
confirmadas; las ocho tablas controladas conservaron cantidades y revisiones máximas.
No se aplicaron correcciones ni se recalcularon recibos durante el desarrollo o publicación.
La verificación de interacción en BC sigue pendiente por autenticación del navegador de
herramientas. Evidencia privada en `.snapshots/dependencias-formulas-20261016/`.

### Nombres precargados y publicación del concepto homónimo

El contexto es un diccionario compartido. Parámetros, variables de sistema, fuentes y
atributos pueden cargar una clave antes del recorrido. Más tarde, un concepto ordinario
publica su importe bajo su código y puede reemplazar esa misma clave. Ser informativo no
lo exime de publicar. Un acumulador, en cambio, se inicializa en cero aunque hubiera otra
fuente con el mismo nombre.

La extracción distingue las dependencias calculadas (`#`, conceptos sin valor precargado
y acumuladores) de las lecturas de claves inicializadas. Estas últimas no crean aristas
ni ciclos calculados, pero sí límites que el corrector debe conservar en todas las ramas
de orden: leer antes del concepto homónimo obtiene el valor previo; leer después puede
obtener su importe publicado. No se permite cruzar esa frontera para resolver otro conflicto.

Por eso `AÑOS_ANTIGUEDAD = PISO(AÑOS_ANTIGUEDAD)` con la variable de sistema activa no es
un ciclo: lee su valor de entrada antes de publicar el resultado. Una llamada `@` hereda
estas lecturas en el punto del llamador. `#AÑOS_ANTIGUEDAD` sigue siendo una referencia
calculada explícita. Si una expresión usa `#A + A`, ambas clases se conservan y sus guardas
se combinan; la referencia explícita no autoriza a cambiar el significado de la otra lectura.

La captura fiscal `GASTOS_IG4_BASE` a orden 0 lee el valor inicial de `DEDUC_GANANCIAS`;
el concepto homónimo lo transforma a orden 1 y los consumidores posteriores leen el valor
publicado. No es un ciclo entre ambas fórmulas. Esta interpretación surge del motor y de
la configuración, sin modificar esas fórmulas ni tomar importes de empleados como excepción.

**Publicada en 1.0.0.669 el 16/10/2026.** Compilación completa sin errores, con seis grupos
nuevos de regresiones (92 pruebas del corrector), pendientes de ejecución en empresa/BD
aislada. La publicación devolvió HTTP 200; la instalación confirmó la versión y un paquete
nuevo. Las ocho tablas controladas conservaron cantidades y revisiones máximas. No se
ejecutaron correcciones de órdenes, pruebas AL ni recálculos operativos. Se usó `Synchronize`,
sin RAD, ForceSync ni reinicio. Evidencia privada en `.snapshots/contexto-orden-20261016/`.
La publicación corrige el diagnóstico y sus guardas; no demuestra que todos los pendientes
del lote anterior tengan una solución automática.

### Acceso administrativo al diagnóstico y a una propuesta revisada

`Corrección Orden Acum.` expone `DiagnosticarOrdenesJson(Text)` y
`AplicarOrdenSeguroJson(Text)` para invocación administrativa con un único argumento.
No son runners de pruebas ni modifican liquidaciones. El contexto exige fecha ISO,
tipo, convenio, categoría y modo de vigencia explícitos; los códigos vacíos significan
revisión general, no se infieren fechas ni filtros de una sesión anterior.

El diagnóstico devuelve filas y propuestas mediante un error identificado
`CONTROL_ORDEN_JSON:…:FIN_CONTROL_ORDEN_JSON`: es una salida de sólo lectura, necesaria
porque `Invoke-NAVCodeunit` descarta valores de retorno. Se puede omitir la generación
de propuestas o pedir un objetivo/candidato concreto para limitar la salida.

Una propuesta disponible contiene `peticionAplicar` con contexto, objetivo, código,
vigencia original, `rowversion` como cadena, fecha y orden propuestos. La aplicación
relee esa PK, vuelve a preparar **ese mismo concepto**, exige coincidencia exacta y
delega en `Aplicar`, que revalida bajo sus locks. Un rechazo no autoriza otro movimiento.
El éxito retorna normalmente; no se usa el error de transporte después de escribir.
No agrega tablas, campos ni llamadas a `Commit`.

La revisión operativa de los pendientes y las cinco reglas aplicadas al orden histórico
del 4124 se documentan en [[Revisión de conflictos de orden octubre 2026]].

> [!warning] Un `MIN(base, TOPE)` puede tapar el error
> Una base incompleta pero muy por encima del tope no mueve el resultado; con un sueldo más bajo sí.
> No tomar como "validado" un concepto porque dio bien en un caso. Ver [[concepto-negativo-despues-de-sus-consumidores]].

## Cómo corregir un orden

### Clasificación de configuración contrastada con Meta4 (15/10/2026)

La foto estable distingue 14 filas globales pendientes: cinco con precedencias numéricas conocidas
y nueve que sólo requieren contexto. No son catorce errores de importe. Al completar tipo, convenio,
categoría y par de valoración, varios cruces desaparecen; las condiciones y novedades se verifican
en el recibo. Febrero tiene mayormente borradores con resultados guardados de una vigencia anterior,
por lo que esos valores no certifican la nueva parametrización pendiente de recalcular.

| Grupo | Evaluación | Corrección propuesta, sin aplicar |
|---|---|---|
| `CURR_DED_ESP_SAC` / `BASE_DED_ESP_SAC` | El auxiliar lee a orden 0 antes de sus dos productores a 0 por desempate alfabético. No tiene consumidores ni fracciones salientes | Orden 1 del auxiliar, mediante nueva vigencia compatible con usos. Corrige el auxiliar, sin justificar diferencias de Ganancias |
| `BASE_ZONA` / `1823` | El original 1822 no incluye 2603/4453/4473. Los pagos de frío cotejados coinciden con Meta4; no coaplican ajustes tardíos no nulos | Fracciones nuevas a 0 para esos tres aportes. Mantener 30 en los casos actuales. Para los ajustes válidos 2763/2773/2783 existe un riesgo latente: 321 sería candidato estático después de limpiar la composición, sujeto a guardas y prueba contextual; no mover a 431 para incluir feriados ajenos al original |
| `BASE_FERIADO` / `1023` | 4893 no pertenece al total 21 original y no tiene aportes efectivos en la muestra | Fracción nueva 4893→BASE_FERIADO a 0. No atrasar el feriado por ese aviso |
| `BASE_IG4` / `2703` | Subtotal intencional, conforme a 2702/total 09. Los aportes posteriores no pertenecen a esa base de zona | Conservar 28; no mover después del total fiscal |
| `REMUNERATIVO_BRUTO` / `3554` | Reparto por etapas. En la liquidación final la rama económica usa componentes explícitos; SAC/vacaciones tienen tratamiento propio | Conservar 452 y sus ramas; no incorporar indiscriminadamente las remuneraciones posteriores |
| `BASE_IG4` / `4905` | Los resultados guardados consultados son nulos y no hay aporte posterior efectivo | No moverlo por la presencia de conceptos de ajuste vacíos |
| `BASE_PROMEDIO` / `3813` | No aparece aporte posterior efectivo en los SAC calculados revisados. El orden 668 ya aplica sólo a LIQ_FINAL/372/04; 470 al resto | Conservar el orden condicional; no trasladar todos los SAC a 686 |

También se detectó una referencia por etapas a revisar en oficiales poteros: `1534` puede leer
`#1023` a 451 aunque el feriado corra a 470. En los valores guardados, modificar aisladamente esa
resta se compensa en `2003`, conservando bruto y bases en el modelo; no se presenta como diferencia
de bruto demostrada. No hay fracción `1534→BASE_FERIADO`, por lo que no existe ese supuesto ciclo.
Una corrección acotada puede ordenar feriado 450 antes del premio 451 en la rama de producción fija,
validando primero precio original 1022, componentes y consumidores. No modificar globalmente las
ramas ni afirmar que los borradores de febrero ya materializaron esa corrección.

### Acción en el control

**Corregir orden…** trabaja sobre la base o fórmula lectora seleccionada y prepara un cambio de **un
concepto por vez**. El diálogo muestra concepto, expresión anterior, posición propuesta, fecha,
alcance y evaluación de dependencias. Se pueden ajustar el concepto, la posición y la fecha antes
de aceptar. Si no hay una propuesta verificable, explica qué falta; no ejecuta una reordenación
masiva de lecturas por etapas.

Desde **1.0.0.660**, la página muestra una **Propuesta para la fila seleccionada**: concepto,
orden propuesto y evaluación. La vista y la acción usan el mismo método `Proponer`; al abrir
la acción se vuelve a comprobar la configuración. Si no existe un movimiento verificable,
el orden queda **vacío** y se muestra el motivo. No se presenta el orden actual como si fuera
una corrección ni se interpreta el cero de la antigua columna oculta como una sugerencia.

La revisión del 16/10 cambia la preparación a **bajo demanda**: seleccionar o redibujar una
fila sólo muestra su estado; **Corregir orden…** busca la propuesta para ese acumulador.
Se conserva mientras no cambien la selección, el contexto o se pulse **Verificar**.
Al reabrir el diálogo se valida la propuesta otra vez; al aplicar se relee la configuración
bajo los bloqueos existentes. No se conserva una aprobación entre operaciones.

La búsqueda calcula una **ventana de enteros** compatible con las entradas y los consumidores
del concepto, preservando los subtotales de las otras bases. Considera el desempate por código
y las fronteras de vigencia futuras ya programadas. Intenta primero aportantes posteriores;
si no pueden adelantarse, prueba otros aportantes y lectores que sí admitan moverse. Puede
encontrar un empate seguro que la regla simple «primer lector menos uno» o «último aporte más
uno» descartaba. La propuesta final debe superar la misma validación que se exige al aplicar.

Una ventana vacía identifica la entrada o consumidor que fija cada límite. Las lecturas que
también aportan a la misma base requieren revisar la etapa; un puesto/asignación o un orden
que no pueda resolverse requiere más contexto. En esos casos no se crea ninguna vigencia.

Para una fila de fórmula se autoriza corregir únicamente las relaciones de sus productores
calculados con ese lector. Si se atrasa el lector, debe quedar después de sus entradas;
si se adelanta un productor, debe quedar antes del lector objetivo. Los demás consumidores
y los subtotales de acumuladores conservan su relación anterior. El movimiento no modifica
la expresión de importe: cambia sólo el orden, con la misma auditoría y validación de vigencias.

La acción crea **una vigencia nueva** del mismo concepto, sin cambiar su fórmula de importe ni
sus fracciones y restricciones de convenio. Cierra la versión anterior mediante validación normal
para respetar los usos calculados y conserva el fin previsto cuando se intercala entre versiones.
Al elegir tipo o convenio, envuelve el nuevo orden en una condición que conserva la expresión
anterior fuera de ese ámbito. **El filtro de categoría sólo acota el diagnóstico: el cambio de
orden alcanza todas las categorías del tipo/convenio indicados**, como aclara el diálogo.

Antes de guardar vuelve a leer la configuración y comprueba la versión de origen. No aplica si
aparecen cruces con dependencias propias, referencias calculadas o lectores de otros acumuladores,
o si falta contexto para comprobarlos. Expande las fórmulas `@` para revisar sus dependencias; no
les impone el orden del concepto referenciado. Un lector que también alimenta el acumulador no
se atrasa automáticamente después de sus propios aportes. Las escrituras de cierre, alta y
auditoría pertenecen a una misma transacción; no hay `Commit` ni recálculo de recibos.

La revisión comprende todas las fechas de cambio ya programadas dentro del intervalo nuevo:
inicios y días siguientes al fin de conceptos, e inicios de fracciones y restricciones. Así un
consumidor o una distribución futuros no quedan fuera del control. Un rechazo indica la fecha
y el motivo. También se comprueban los usos calculados durante la previsualización, antes de
cerrar la versión original al aplicar.

El historial distingue el tipo **Orden de cálculo** y conserva las expresiones anterior y nueva.
Esa entrada no se restaura como si fuera una fórmula de importe: para revertir el orden se crea
otra vigencia. Ver [[Versionado de conceptos y fórmulas]].

Publicada y verificada en BC252 con **1.0.0.659**: doce pruebas del diagnóstico y dieciséis de
corrección (28 en total), incluidas concurrencia, conservación de recibos/vigencias, expresión
condicional, auditoría y cruces futuros. Las seis tablas financieras controladas conservaron
sus cantidades y revisiones máximas después de publicar y ejecutar las pruebas con reversión.

La mejora de **1.0.0.660** quedó publicada y validada en **1.0.0.662** el 15/10/2026;
no se aplicaron reordenamientos de conceptos económicos. La suite del gestor tiene 24 pruebas,
incluidos empates seguros, alternativas al aportante inicial, ventanas imposibles, límites
futuros y la llamada booleana con envoltura `TryFunction` que utiliza la página.
La selección de avisos y orden pasó **63 de 63 pruebas** con reversión: 7 de auditoría/informe,
20 de motor/caché, 12 de diagnóstico y 24 de propuestas. Las diez tablas operativas y
financieras controladas conservaron sus cantidades y revisiones máximas, y las ocho tablas
de configuración conservaron exactamente su contenido durante la publicación y las pruebas
finales. La verificación de 28 pruebas indicada arriba corresponde a la versión 659.

### Revisión de dependencias

1. **Mover el productor hacia atrás, no el consumidor hacia adelante**: mover al lector arrastra sus propios consumidores, y puede cruzarse con conceptos que alimentan los mismos acumuladores (aguinaldo sobre aguinaldo).
2. El **primer orden válido** del productor lo fija **su propia fórmula**: lo que él lee tiene que estar antes.
3. Antes de mover, listar (a) qué acumuladores alimenta, (b) qué conceptos los leen y en qué orden, (c) qué lee el concepto que se mueve. Las tres salen de `Fracción Acumulador` cruzada con `Concepto Liquidación`.
4. Mover **mirando los dos lados**: acercar un concepto a lo que lee lo acerca a sus consumidores.
5. Correr el control estático y recalcular un caso conocido.

## Guía histórica de rangos (sin verificar)

`GUIA-LIQUIDACION.md` propone rangos (`1–99` haberes base, `100–199` adicionales, …, `900–929` aportes, `999` redondeo). Es una **recomendación de la guía**; los órdenes reales viven en datos y varios conceptos están fuera de esos rangos (por ejemplo la absorción del art. 36 en 412 y el SAC devengado en 460-462, según las lecciones). No usarla como contrato.

## Relacionado

[[Acumuladores y fracciones]] · [[Ciclo de cálculo de una liquidación]] · [[acumuladores-orden-calculo]] · [[orden-calculo-del-lote]] (otro "orden": el de las **liquidaciones** dentro de un lote) · [[Tabla - Concepto Liquidación]]

## Rendimiento y repetición de la pantalla (16/10/2026)

El diagnóstico prepara una sola vez las versiones ganadoras y su inclusión, y tokeniza fórmula
y condición una vez por concepto. Un índice asocia identificadores con sus lectores; ya no
recorre y tokeniza todos los conceptos para cada acumulador. La sobrecarga con código de
acumulador permite que el corrector compruebe sólo su fila. El parser, la selección de
fracciones, los desempates y los órdenes que necesitan contexto mantienen sus reglas.

El corrector carga conceptos, fracciones y restricciones en temporales una vez por operación.
Reutiliza ganadoras por fecha, fronteras futuras, tokens, dependencias, alcance y órdenes;
las listas se copian para evitar modificar el contenido de las memorias. Cada entrada pública
descarta los datos anteriores. `Aplicar` sigue validando todo con una foto nueva bajo locks,
incluidos rowversion, usos calculados y todas las fronteras futuras. No cambia `Commit`.

Lookup y validación consecutivos del mismo contexto no repiten el análisis. **Verificar**
siempre fuerza lectura nueva. Se conserva la vista y la fila pendiente; cuando desaparece,
se busca el siguiente código disponible, o se vuelve al primero. Esa continuidad sigue el
código, no necesariamente el orden visual si el usuario ordenó otra columna. Tras guardar,
el éxito se informa con una notificación sin un segundo diálogo modal.

Al aceptar el diálogo se comprueba que la última evaluación sea válida, sin repetir el
análisis completo; éste se conserva al abrir, editar y aplicar. No se modifican fórmulas de
importe, datos de liquidación ni esquema. Se agregaron
nueve regresiones (33 del corrector): equivalencia de fila/global, contexto y rechazo de
configuración obsoleta. Compilación completa sin errores; ejecución AL pendiente en una
empresa aislada y medición de tiempo pendiente en BC tras publicar. La versión de la app
se conserva para el proceso de publicación del usuario. No se ejecutaron pruebas operativas.

## Corrección en lote desde el control (16/10/2026)

**Recalcular órdenes** intenta corregir todos los acumuladores del contexto de fecha, tipo,
convenio y categoría de la página, aunque los filtros visuales oculten algunas filas. Ejecuta
movimientos individuales verificables hasta que no encuentra otro; presenta un único resumen
con los conceptos y órdenes cambiados y los acumuladores pendientes con su motivo.

El lote usa exactamente la fecha de referencia: si la versión ya empieza ese día, prueba
otro candidato o deja el caso pendiente; no desplaza la fecha al día siguiente. Cada concepto
puede recibir como máximo una nueva vigencia en esa fecha. Repetir la acción no duplica una
corrección. Las bases con lecturas por etapas o contexto incompleto requieren revisión
individual. Tampoco se fuerza un movimiento ante dependencias incompatibles, matrices,
usos calculados posteriores o cruces con futuras vigencias.

Se conserva la validación del corrector individual, incluidas las otras categorías del
convenio. Los cambios cierran la versión anterior, crean la nueva y registran el historial
de orden, sin cambiar fórmulas de importe, fracciones ni recibos existentes. Todo el lote
pertenece a una transacción: un error de escritura o de comprobación final revierte todos
sus cambios. No se agregan llamadas a `Commit`, campos, tablas ni objetos.

Hay dos diagnósticos globales, inicial y final. Entre cambios se comprueba sólo el acumulador
afectado; las búsquedas comparten el catálogo hasta que una escritura obliga a releerlo.
La página reutiliza el resultado final y conserva su vista y selección. La ejecución está
acotada por conceptos distintos movidos, no por la cantidad de aportantes tardíos: al atrasar
uno de varios lectores, ese conteo puede permanecer igual hasta mover los demás. Se rechaza
cualquier aumento de conflictos o nueva falta de contexto.

Se agregaron once regresiones del lote (44 pruebas del corrector en total), compiladas con
el proyecto completo sin errores. Ejecución AL pendiente en una empresa/BD aislada; no se
publicó ni se escribieron datos de BC durante este desarrollo. La versión de la app queda
sin cambios para la publicación del usuario.

## Revisión desde la ficha del concepto (16/10/2026)

La ficha ofrece **Recalcular órdenes** y el botón de asistencia del campo **Orden de cálculo**.
Ambos guardan las ediciones normales de la ficha, recargan su versión física y abren el
control en modo concepto. No ejecutan el lote global. La revisión muestra el código, el
intervalo de la versión, los acumuladores que lee o alimenta y una propuesta inicial bajo
demanda; navegar entre filas no repite la búsqueda.

La fecha inicial es la de trabajo, acotada al intervalo de la ficha. No se sustituye una
versión histórica por la vigente hoy: el servidor comprueba PK, rowversion, intervalo y
versión ganadora a la fecha. Tipo, convenio y categoría se pueden completar en el control;
sólo se propone el tipo inicial cuando el concepto tiene uno único declarado.

En este modo, **Recalcular órdenes** revisa una corrección del concepto abierto mediante el
diálogo existente: el código queda fijo, se muestra la posición y la expresión propuestas,
la fecha y las dependencias o motivos de rechazo. Al aplicar se mantienen las guardas de
versionado, concurrencia, usos calculados y fronteras futuras. El control pasa a revisar la
nueva vigencia. Si la ficha corresponde a un acumulador, se revisa únicamente esa base y se
pueden proponer movimientos de sus aportantes o lectores: el acumulador no tiene orden propio.

Las relaciones consideran las fracciones vigentes y las dependencias, incluidas las llamadas
indirectas `@`. Un resultado sin bases no equivale a validar las referencias `#` entre
conceptos; la pantalla aclara ese límite. Dependencias no comprobables y contexto faltante
se informan, sin inventar una posición. No se analiza desde `OnAfterGetRecord` de la ficha,
no se añaden objetos ni campos de tabla y no se alteran fórmulas de importe o recibos.

Diez regresiones nuevas verifican el alcance, referencias indirectas, versión histórica,
concurrencia, propuesta fija y fracciones vigentes (54 pruebas del corrector en total).
Compilación completa sin errores; ejecución AL pendiente en empresa/BD aislada. No se
publicó ni se ejecutaron pruebas o escrituras de BC en esta revisión.

### Publicación 1.0.0.663 (16/10/2026)

Publicadas las optimizaciones, la corrección en lote y el acceso desde la ficha, por pedido
expreso del usuario. Paquete completo con `Synchronize`, sin RAD ni ForceSync. Compilación
sin errores; POST de publicación HTTP 200. La metadata de BC252 confirmó la versión
**1.0.0.663** instalada y un identificador de paquete nuevo; el servicio respondió HTTP 200
después. Ocho tablas controladas conservaron cantidades y revisiones máximas, incluidas
cabeceras, líneas, conceptos, fracciones e historial. No se recalcularon recibos ni se
ejecutaron pruebas AL en la empresa operativa; las regresiones nuevas continúan pendientes
en entorno aislado. No fue necesario reiniciar el servicio. Evidencia técnica privada en
`.snapshots/publicacion-1.0.0.663-20261016/`.

### Actualizar el orden de la misma vigencia (16/10/2026)

El corrector también admite **Actualizar esta vigencia**: conserva código, inicio y fin,
y modifica únicamente la expresión de orden y su compatibilidad numérica. Registra el
antes/después en el historial de orden. La opción está activada al abrir desde la ficha;
en el control general se mantiene desactivada hasta elegirla expresamente. El diálogo
muestra el modo y bloquea la fecha de inicio cuando se actualiza la misma versión.

Desde el diálogo también se puede cambiar explícitamente **Actualizar esta vigencia**.
Al activarlo fija la fecha original; al desactivarlo recupera la fecha propuesta o editada
para crear otra versión. Cambiar la fecha por sí solo no cambia el modo. Cada edición vuelve
a validar el orden y su alcance, incluidas todas las fronteras del intervalo cuando se
actualiza la versión existente. La sugerencia inicial se sustituye por el cambio que se
está revisando para no conservar un texto correspondiente a otra fecha o modo.
El diálogo devuelve el modo elegido junto al concepto, orden y fecha: el control utiliza
ese mismo valor para aplicar, refrescar y avisar. Cancelar no cambia el modo del control.

**Ajuste del diálogo publicado en 1.0.0.666 el 16/10/2026.** Sólo cambian las dos páginas;
el algoritmo y las guardas del corrector se conservan. Compilación completa sin errores y
revisión independiente del modo devuelto al aplicar. La publicación devolvió HTTP 200 y
se confirmó la instalación; las ocho tablas controladas conservaron cantidades y revisiones
máximas. No se ejecutaron correcciones, pruebas AL ni recálculos operativos. La interacción
del diálogo queda pendiente de comprobación en BC. Evidencia privada en
`.snapshots/dialogo-modo-orden-20261016/`.

**Edición de cabecera corregida en 1.0.0.667 (16/10/2026).** La página 50014 mantenía
`Editable = false` global: además de proteger la grilla, bloqueaba las variables de filtro
y el selector **Actualizar esta vigencia**. Se quitó ese bloqueo general y se trasladó
al repetidor de resultados, conservando las restricciones de insertar y eliminar.
No sustituirlo por `ModifyAllowed = false` global: también puede dejar la página sin
controles editables, como ya documenta el comparador BC/Meta4.

Sólo cambia la página del control. Compilación sin errores; publicación HTTP 200,
instalación 1.0.0.667 confirmada y ocho tablas controladas con cantidades y revisiones
máximas sin cambios. No se ejecutaron correcciones ni recálculos. El navegador de
herramientas rechazó la autenticación (`ERR_INVALID_AUTH_CREDENTIALS`), por lo que
la comprobación visual quedó pendiente. Evidencia privada en
`.snapshots/edicion-control-orden-20261016/`.

Es una excepción solicitada por el usuario a la regla de crear una nueva vigencia, limitada
al orden de cálculo. Se permite aunque haya recibos guardados que usaron esa versión:
**sus importes no se reescriben, pero los próximos recálculos de todo el intervalo usarán
el orden nuevo**. El aviso figura tanto en el control como en la evaluación antes de aplicar.
La alternativa de crear otra vigencia conserva sus restricciones de cierre y usos posteriores.

La búsqueda y la validación de la actualización recorren todas las fronteras desde el
inicio original, aunque la fecha de referencia sea posterior. Se mantienen las guardas
de concurrencia, dependencias, consumidores, otras bases y lecturas por etapas. Un tramo
sin cambio no obliga a modificarlo; la ausencia global de cambio sí se rechaza. El lote
no vuelve a mover un código ya corregido en esa ejecución. Después de aplicar, la revisión
conserva su fecha de referencia y recarga la misma PK con su nueva versión interna.

No se agregan campos, tablas, objetos ni llamadas a `Commit`; no se modifican las fórmulas
de importe ni se ejecuta un recálculo de recibos.

**Publicada en 1.0.0.664 el 16/10/2026.** Compilación sin errores y diez regresiones nuevas
(64 pruebas del corrector), pendientes de ejecución en empresa aislada. El POST de
publicación devolvió HTTP 200 y la metadata confirmó la versión instalada y un paquete
nuevo. Las ocho tablas controladas conservaron cantidades y revisiones máximas; no se
ejecutaron correcciones de órdenes ni recálculos operativos durante la publicación.
Se usó `Synchronize`, sin RAD, ForceSync ni reinicio del servicio. Evidencia privada en
`.snapshots/orden-vigencia-actual-20261016/`.

### Órdenes condicionales sin completar filtros (16/10/2026)

El lote no rechaza una base completa sólo porque una referencia tenga un orden condicional.
Primero intenta resolver su orden exacto con el contexto disponible. Si faltan datos, admite
un conjunto conservador de resultados de un árbol `IF` cuyas ramas sean enteros válidos:
por ejemplo, el 3813 puede ubicarse en 470 o 668. No elige una rama ni reemplaza esa fórmula.

Para mover otro concepto se comprueban **todos** esos valores: un aporte debe preceder al
menor orden de sus lectores y una lectura debe seguir al mayor de sus aportantes. Las otras
entradas y consumidores deben conservar su lado para cada variante, en todas las fronteras
de vigencia. Las fórmulas que no puedan acotarse siguen bloqueando el candidato relacionado,
pero no impiden intentar otro movimiento independiente.

El concepto que se modifica sigue necesitando un orden anterior exacto; no se aplana su
fórmula condicional sin contexto. Tampoco se supone que el par de un puesto sea el convenio
de la cabecera. El diagnóstico muestra extremos posibles y lo aclara en la observación;
una diferencia potencial entre ramas no demuestra un error en un recibo concreto.
Las lecturas por etapas, matrices y demás guardas conservan sus restricciones.

El resumen utiliza saltos de línea reales: las barras dentro de un argumento de `Message`
se mostraban literalmente. Este cambio afecta al control y sus propuestas; no ejecuta
correcciones de orden ni recálculos de recibos por sí mismo.

**Publicada en 1.0.0.665 el 16/10/2026.** Compilación completa sin errores, con diez
regresiones nuevas (74 del corrector), pendientes de ejecución en empresa/BD aislada.
El POST devolvió HTTP 200; metadata y consulta de instalación confirmaron la versión y
un paquete nuevo. Las ocho tablas controladas conservaron cantidades y revisiones máximas.
No se ejecutaron correcciones, pruebas AL ni recálculos operativos. Se usó `Synchronize`,
sin RAD, ForceSync ni reinicio. Evidencia privada en `.snapshots/orden-variantes-20261016/`.

## Orden como un único campo (2026-10-12)

Ficha y lista muestran sólo **Orden de cálculo**, ligado a `Fórmula Orden Cálculo`: admite `455` o `IF(TIPO_LIQ = 'LIQ_FINAL' AND CONVENIO = '372/04', 667, 455)`. No hace falta mantener un orden predeterminado visible ni usar `ORDEN_BASE` en fórmulas nuevas.

`Orden Concepto Upgrade` convierte valores publicados y configuración alternativa a expresiones equivalentes al actualizar la extensión. Las columnas numérica y alternativas se conservan por compatibilidad del esquema. El motor materializa un entero efectivo en su copia temporal y ordena esa copia. Desde el 14/10 el control estático también utiliza esa fórmula; cuando le faltan datos no sustituye el resultado por la columna antigua. Los avisos del cálculo utilizan el orden efectivo de su contexto completo.

### Contexto estable disponible al ordenar (2026-10-13)

La fórmula de orden recibe parámetros, atributos, fuentes y variables de sistema ya
resueltos antes del recorrido, además de `TIPO_LIQ`, `CONVENIO` y `ORDEN_BASE`.
Se excluyen conceptos, acumuladores, valores de fila, cantidad de incidencia y
complemento iterativo de grossing-up. Se rechazan `#`, `@` y funciones que consultan
datos durante la evaluación del orden, incluso en ramas no elegidas. El orden no puede
depender de un resultado que su propia decisión determina.

Una condición sobre la modalidad puede ordenar el premio después del feriado sólo en
la rama que lo absorbe, conservando el orden anterior en las demás modalidades.

## Comparación por contextos compatibles (16/10/2026)

El control compara el orden y las dependencias dentro de una misma combinación de tipo,
convenio, categoría y rama. Un filtro vacío enumera los ámbitos configurados; no elige
una rama por omisión. El código vacío de un contexto enumerado sí es un valor conocido.
Se respeta la selección del motor, incluidos tipos exclusivos, informativos, la última
restricción de convenio/categoría y la última fracción, aunque ésta anule el aporte en cero.

Las ramas `IF` y `CASE` se seleccionan sólo cuando su condición puede resolverse con el
tipo y convenio conocidos y funciones puras. Los datos del empleado que faltan no se
sustituyen por cero. `@` hereda el contexto y el par del llamador; no adopta el par de la
definición expandida. El par de puesto/asignación sigue siendo incierto sin liquidación.
Las referencias de una condición evaluada se conservan como guardas, aunque el cuerpo
no se ejecute; eso no demuestra que el lector vaya a publicar un resultado.

La elegibilidad del concepto, la producción de su resultado y las lecturas de su
condición se distinguen. Una condición pura falsa excluye al productor. Una condición
opaca conserva sus relaciones potenciales y queda pendiente. Tanto el aportante como
el lector usados para demostrar la necesidad de un cambio deben tener producción
comprobada. Las relaciones potenciales siguen limitando la seguridad del movimiento.

El corrector exige dos comprobaciones distintas: existe una precedencia incorrecta en
algún ámbito compatible, y el movimiento conserva las otras entradas, consumidores,
semillas y etapas en todos los ámbitos y fronteras de vigencia alcanzados. Una categoría
seleccionada para diagnosticar no limita la fórmula de orden a esa categoría: la validación
recorre todas sus clases. Un contexto sin contraparte del objetivo sólo exige las guardas
comunes; no invalida una necesidad demostrada en otro contexto. No se aplana un orden
condicional global ni se propone el orden actual como arreglo.

La grilla muestra ambos extremos de un mismo ámbito testigo, identificado en la
observación. Los contadores reúnen relaciones verificadas; no vuelven a comparar el
máximo de un convenio con el mínimo de otro. Las bases con lecturas por etapas requieren
revisión individual: no se intenta completar todos sus aportes antes del primer subtotal.

Los catálogos e índices son temporales y se reutilizan dentro de la operación. Las
categorías con la misma máscara de aplicabilidad forman una clase, con el blanco separado.
La extracción de aristas se reutiliza sólo dentro de la misma foto y fecha del análisis,
con sensibilidad a tipo/convenio y expansión `@`; los ciclos se reconstruyen por contexto.
El corrector inicia otra foto después de escribir. No se agregan objetos, campos, tablas
ni `Commit`, ni se alteran fórmulas de importe o recibos al verificar.

**Publicado en 1.0.0.673.** Compilación sin errores; 117 pruebas ejecutadas y aprobadas en
la empresa aislada `TEST_ORDEN_20261017` (105 del corrector y 12 del diagnóstico), en
11,15 segundos. Publicación `Synchronize`, HTTP 200 e instalación confirmada, sin reinicio.
Las 59 tablas operativas controladas conservaron cantidades y revisiones máximas; los
volcados completos de conceptos, historial, fracciones y restricciones siguieron idénticos.
No se aplicaron órdenes ni se recalcularon recibos operativos. En febrero desaparecieron
los avisos de 1603, 2103 y 3814: 11 pendientes pasan a 8, sin forzar los restantes.
El análisis global compatible mide unos 20 segundos; la primera implementación sin los
índices y clases equivalentes tardaba unos 62. No comparar ese recorrido más completo con
el anterior cruce de extremos sin contexto. Evidencia privada:
`.snapshots/orden-contextos-compatibles-20261017/`.
