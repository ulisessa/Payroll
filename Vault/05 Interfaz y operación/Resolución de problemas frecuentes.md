---
tipo: guia
tags: [troubleshooting, diagnostico, operacion, errores]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50019.GestionLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod50017.GestionEstadoEmpleado.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Tables/Tab60008.ParametroVigente.al, src/Tables/Tab60011.Liquidacion.al]
actualizado: 2026-10-04
---

# Resolución de problemas frecuentes

Primer paso, siempre: **Registros de Proceso** (Herramientas) con filtro *Solo con error*, y para el caso puntual la acción **Registros de proceso** de la ficha. Después el síntoma. Cómo leer avisos y controles: [[Controles y avisos del cálculo]].

## El cálculo se corta con un error

| Mensaje / síntoma | Causa | Solución |
|---|---|---|
| "El período %1 está cerrado. No se puede reliquidar" | Período *Cerrado* | *Períodos* → **Reabrir Período** (pide confirmación; baja a Borrador las liquidaciones sin posteriores) |
| "No se puede calcular %1… ya tiene líquidado el período %4 en la liquidación %3" | Hay un período **posterior** con líneas; el motor mira hacia atrás (francos, anuales, Ganancias) | **Recalcular en cadena** desde la ficha ([[Crear, calcular, aprobar y reabrir liquidaciones]]) |
| "No se puede reabrir %1… porque el empleado ya tiene liquidado el período %4" | Idem, del lado de la reapertura | Recalcular en cadena; no reabrir a mano |
| "La liquidación … está Aprobada y no se puede rehacer" (al recalcular en cadena) | Una de la cadena está aprobada | **Revertir Aprobación** y repetir |
| "El empleado %1 no tiene un estado definido para la fecha %2" | Sin estado a la fecha de referencia | Cargar el estado en *Estados Empleado* ([[estado-empleado-effective-dated]]) |
| "El empleado %1 no está asignado al proyecto %2" | Falta la asignación | *Personal Proyecto* del Job |
| "Las siguientes fórmulas contienen errores…" | Una fórmula no compila | *Fórmulas con errores* → abrir el concepto |
| "Variable desconocida en la fórmula: …" | Nombre mal escrito (**distingue mayúsculas**), parámetro/fuente/atributo inactivo, o una variable de sistema nueva **no sembrada** | Asistente de Fórmulas → *Cargar catálogo*; **Sembrar variables estándar** ([[variable-sistema-hay-que-sembrarla]]) |
| El número de campo '…' no se encuentra en la tabla '…' | Una **Fuente de Datos** apunta a un campo borrado, **aunque ninguna fórmula la use** | Corregir o desactivar la fuente ([[fuente-datos-apunta-por-numero]]) |
| "El grossing-up … no convergió" | Neto garantizado mal definido o descuentos sobre el complemento | Revisar la fórmula del neto garantizado ([[grossing-up-tapa-errores]]) |
| "La serie de numeración de liquidaciones no está configurada" | Falta la serie | *Config. RR.HH.* → **Serie Núm. Liquidaciones** |
| "El proyecto %1 no tiene fecha de arribo" / "No existe un período … que contenga la fecha de arribo" | Cierre de Marea sin *Ending Date*, o sin período del mes del arribo | Cargar la fecha de arribo; crear el período |
| "La asignación … empieza el X, después del Y en que termina el período" | Asignación equivocada | Elegir la asignación del período ([[proyecto-nomina-dos-fuentes]]) |
| "Existe una liquidación no revertida para el período %1… Revertí la liquidación antes de modificar el historial de estados" | Se está editando un estado de un período ya liquidado | Reabrir la liquidación, corregir el estado, recalcular |

## Sale mal, pero sin error (los peores)

| Síntoma | Qué mirar primero |
|---|---|
| Un concepto **no aparece** en las líneas | (1) *Condición* falsa; (2) **Vigencia Hasta** cerrada o versión posterior; (3) *Convenios aplicables* (incl. **Excluye**) o *Aplica A*; (4) **Tipos Liq. Aplicables** distinto del tipo; (5) cabecera con **Cód. Tipo Liq. vacío** (el motor no aplica conceptos restringidos por tipo, [[migracion-tipo-liq-incompleta]]); (6) líneas con importe 0 ocultas (*Mostrar importes cero*) |
| Concepto en **cero** | Parámetro **sin vigencia** para ese convenio/categoría (`IFZERO`), variable en 0, fuente con token vacío, o **novedad en cero** ([[novedad-en-cero-no-apagaba-el-concepto]]) |
| Importe **más bajo** de lo debido | **Orden de cálculo**: un aportante corre después del lector. *Control de Orden de Cálculo*; sumar el *Importe Aportado* del detalle del acumulador y comparar ([[acumuladores-orden-calculo]]) |
| Importe **más alto**, o múltiplo exacto (×2, ×5) | Contar las liquidaciones del empleado en el período: **tipo en blanco** en un lote duplicó 2.748 ([[lote-tipo-liq-en-blanco]]); conceptos sin tipo aplican a todos ([[vacio-en-tipos-liq-aplicables-es-comodin]]) |
| Importe distinto del esperado en **un solo par** convenio/categoría | Valor de parámetro con **clave inconsistente** (*Claves de Parámetro a Revisar*) o `@` re-evaluando con otro par ([[arroba-ignora-el-par-del-concepto]]) |
| **Dos parámetros / parámetro y atributo** con el mismo nombre | Gana uno; el otro queda mudo. *Revisar Nombres de Variable Duplicados* ([[dos-parametros-mismo-nombre]], [[parametro-y-atributo-mismo-nombre]]) |
| Cambié un parámetro **por SQL** y BC sigue con el valor viejo | El service tier cachea; reiniciar o publicar ([[sql-directo-deja-cache-rancia]]) |
| **Novedad cargada que no se pagó** | Hoja → columna **Motivo No Aplicada**; si está vacía, mirar proyecto, tipo y fecha ([[Novedades e incidencias - carga operativa]]) |
| "Días sin liquidar" aunque el período figura liquidado | *Días Liquidados por Empleado*: dos mareas del 1 al 20 dejan julio "liquidado" con 11 días sin cubrir ([[ventana-liquidacion-es-cobertura]]) |
| Antigüedad distinta a la del recibo | El recibo imprime años desde `Employment Date` ÷ 365; el cálculo usa **fases de alta** ([[antiguedad-suma-de-fases]]) |
| Una liquidación **de vacaciones** o **de un tipo especial** paga el recibo entero | Tipo sin **Sólo conceptos declarados** y conceptos sin tipo ([[exclusividad-vacaciones]]) |

## Parámetros y vigencias

| Síntoma | Causa | Solución |
|---|---|---|
| "No se puede modificar ni eliminar un parámetro que ya fue utilizado en una liquidación registrada" | **En Uso** y hay liquidaciones calculadas/aprobadas | Cargar **vigencia nueva**; o *Liberar "En Uso"* si ya no se usa |
| Aviso "*X*: el último valor vigente es del …" **falso** | *Antigüedad Máxima Vigencia* mal cargada (`+1M`) | Usar fórmula negativa ([[antiguedad-maxima-vigencia-avisa-de-mas]]) |
| "*X*: no tiene ningún valor cargado" | No hay **ninguna** vigencia a esa fecha | Cargar el valor |
| No me deja cerrar la vigencia de un concepto | Una liquidación (no Borrador) usó esa versión después de esa fecha | Cerrar en fecha posterior o revertir esa liquidación |
| No me deja borrar un concepto | Lo nombran fórmulas, variables de sistema, novedades sin liquidar, préstamos o Config. RR.HH. | Corregir esas referencias primero |
| Versiones viejas de concepto que ahora calculan | `Activo = false` ya no apaga nada | *Versiones Inactivas a Revisar* |

## Pantallas y herramientas

| Síntoma | Solución |
|---|---|
| **Editor de fórmulas en blanco** | Ficha del concepto → **Reiniciar editor**; si sigue, **Ctrl+F5** (saltea el caché del navegador); mientras tanto *Ver texto plano* |
| Un concepto se ve en el editor distinto de lo que calcula | El editor es espejo del tokenizador: lo subrayado en rojo **no lo entiende el motor** |
| Una acción de lote **procesó sólo uno** | Bucle sobre un campo que cambia al modificar ([[bucle-modifica-campo-filtrado]]); si ve "1 liquidación" con varias marcadas, cancelar y avisar |
| Ventana de progreso con datos de una corrida vieja | Lote anterior cortado ([[progreso-singleinstance-sucio]]) |
| El recibo sale con **CUIL en blanco** | Posible: lee `Social Security No.` ([[cuil-vive-en-cif-nif]]) — **sin verificar** |
| El recibo sale con **borradores** | Tildar **Solo liquidaciones aprobadas/contabilizadas** |
| "Mostrar en Recibo" no imprime | Sólo lo dibuja el diseño **clásico**, no el *Decreto* ([[Recibo de sueldo (reporte)]]) |
| Un usuario no puede abrir una pantalla | Revisar [[Perfiles, Role Center y permisos]]: hay objetos sin permisos asignados en ningún set |
| No puedo borrar una liquidación | Sólo **Borrador** (reabrirla primero). **No borrar por SQL**: deja novedades "Aplicadas" huérfanas |

## Cierre de marea

| Síntoma | Causa y solución |
|---|---|
| **Crear Cierre Marea** deshabilitado | El proyecto no tiene fecha de arribo (*Ending Date*) |
| Cierre sin líneas o con navegación en 0 | Marea sin arribo, o conceptos con condición sobre `DIAS_PROYECTO > 0`. Para Cierre la fecha de referencia es el **arribo** y no el fin del período |
| Devengados con navegación en 0 | Es lo esperado si la marea no terminó: no usar variables del viaje completo en un devengado |
| Una novedad con proyecto "se perdió" | Ver [[novedad-con-proyecto-queda-huerfana]] |
| Un día no lo cubre ninguna liquidación | [[cobertura-en-tramos]], [[cobertura-devengado-tapa-dias]] |

> [!note] Corrección a la guía vieja
> La guía hablaba de `DIAS_MAR` en 0. Hoy las variables de la marea son `DIAS_PROYECTO` (navegación), `DIAS_PUERTO` y `DIAS_MAREA` (navegación + puerto); el nombre lo define la fila de *Variables Sistema*. Y la respuesta a "El período está cerrado: reapertura manual por administrador" es la acción **Reabrir Período**.

## Cuándo pedir ayuda

Si el problema no está acá: (1) anotar el **No. de registro de proceso**; (2) copiar la fila de **Detalle del cálculo** de la línea; (3) indicar empleado, período, tipo y proyecto. Eso alcanza para reproducir sin recalcular.

Relacionado: [[Flujo operativo mensual de liquidación]] · [[Índice Interfaz y operación]]

## Ver también

[[Avisos y advertencias del cálculo]] · [[Transaccionalidad y errores del cálculo]] · [[Runbook - tareas frecuentes]]
