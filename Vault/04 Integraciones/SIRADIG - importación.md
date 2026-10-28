---
tipo: proceso
tags: [siradig, afip, ganancias, importacion, cargas-familia]
fuente: [src/Codeunits/Cod50046.OrquestadorSiradig.al, src/Codeunits/Cod50047.GestorArchivosSiradig.al, src/Codeunits/Cod50048.ProcesadorImportacionSiradig.al, src/Codeunits/Cod50058.ImportadorArchivoSiradigSubido.al, src/Codeunits/Cod50059.AuditoriaAfipInterface.al, src/Pages/Pag50171.ImportacionesSiradig.al, src/Pages/Pag50172.CarpetaSiradigDialog.al, src/Pages/Pag50173.CueSiradig.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, README_SIRADIG.md, IMPORTACION_SIRADIG_GUIA.md]
actualizado: 2026-10-04
---

# SIRADIG - importación

**SIRADIG** es el sistema por el que cada empleado declara a AFIP/ARCA sus deducciones de Ganancias y sus cargas de familia (F.572 web). La extensión **importa los archivos de esas presentaciones** (`.xml` o `.xml.zip`) y actualiza dos cosas: las deducciones de Ganancias del empleado y sus familiares. Es una **importación de archivos**, no una llamada a un web service de AFIP. Modelo y parser: [[SIRADIG - modelo y parser]].

## Flujo

```mermaid
flowchart TD
  U[Usuario: Importaciones SIRADIG<br/>Pag50171] -->|Importar Archivos<br/>FileUpload multi-selección| ORQ
  U -->|Importar desde Carpeta del Servidor| ORQ
  ORQ[Orquestador SIRADIG<br/>Cod50046] -->|1 archivo = 1 Codeunit.Run<br/>Commit previo| IMP[Importador Archivo SIRADIG<br/>Cod50058]
  ORQ -->|carpeta: TryFunction por archivo| IMP2[TryImportarArchivo]
  IMP --> GES[Gestor Archivos Cod50047<br/>ZIP/XML -> texto, CUIL del nombre]
  IMP --> PAR[Parser XML Cod50022<br/>período, nro, fecha, cuit,<br/>cuenta deducciones y cargas]
  PAR --> REG[(Importación SIRADIG<br/>Tab60026, Estado)]
  IMP --> AUD[Auditoria AFIP Interface Cod50059<br/>AFIP Interface Register + detail<br/>guarda el XML]
  REG -->|AutoProcesar| PROC[Procesador Cod50048]
  PROC --> DED[(Ded. Ganancias Empleado<br/>Tab60022)]
  PROC --> REL[(Employee Relative<br/>+ ext Tab52002)]
  DED --> MOT[Motor: CalcDeduccionesGanancias]
  REL --> MOT
```

## Uso (usuario de RRHH)

1. Abrir **Importaciones SIRADIG** (también está en el Role Center de Payroll, con un Cue de *Pendientes*, *Con errores*, *Procesados* - Tab60027/Pag50173).
2. **Importar Archivos SIRADIG**: selector nativo de la PC (selección múltiple). O **Importar desde Carpeta del Servidor** (la carpeta se recuerda en `Human Resources Setup."Carpeta Importación SIRADIG"`).
3. Responder si se procesa automáticamente. Al final hay **un solo resumen** (importados, con error, deducciones y cargas procesadas, errores por archivo).
4. Si se difiere el procesamiento, el registro queda en `Pendiente Procesar`; acción **Procesar Importación**.
5. **Ver Registro AFIP WS** abre el `AFIP Interface Register` con el XML y el detalle campo a campo (valor anterior -> nuevo).

**Nombre de archivo**: `CUIL_PERIODO_presentacion_NRO.xml.zip` (o `.xml`), p. ej. `20666666667_2024_presentacion_001.xml.zip`. Al menos tres guiones bajos y la primera parte tiene que ser un CUIL de 11 dígitos (con o sin guiones). El CUIL se **normaliza a sólo dígitos**.

## Reglas del procesamiento

- **Empleado**: se busca por CUIL en `Social Security No.` y en **`CIF/NIF`** (donde de verdad vive en BC, ver [[cuil-vive-en-cif-nif]]), con y sin guiones; último recurso: recorrer todos los empleados comparando normalizado. No encontrado -> `Error en Procesamiento`.
- **Deducciones**: sólo los tipos `1,2,3,4,5,7,8,9,10,11,21,22,23,24,25,32,33,34,99`; el resto se ignora **sin avisar**. Por cada una se escribe `Ded. Ganancias Empleado."Importe Fijo"`.
- **Cargas de familia**: se busca el familiar por **nº de documento** y, si no viene, por apellido+nombre (más frágil). Si existe se **reemplaza conservando** `Line No.` y los datos que SIRADIG no informa (`Cód. Tipo Ded.`, fechas, `% Deducción`); si no, se crea con `Line No.` +10000.
- **Reimportar la misma presentación no duplica deducciones ni familiares** (se modifican en el lugar), **pero sí duplica el registro de importación**: `Importación SIRADIG` tiene `No.` autoincremental y su clave `K2` (CUIL + período + nº presentación) **no es única**, así que el control "El archivo ya ha sido importado anteriormente" (`if not Insert() then Error`) **nunca se dispara** (verificado leyendo Tab60026).
- Cada alta/modificación deja un detalle en `AFIP Interface Register detail` (`Table No.`, `Field No.`, tipo de cambio, valor viejo/nuevo, clave).

## Qué hay que saber antes de confiar en el resultado

> [!warning] Las deducciones importadas llevan el código numérico de SIRADIG
> El procesador asigna `Cód. Tipo := '1' | '4' | '32'...` por asignación directa. Pero `Ded. Ganancias Empleado."Cód. Tipo"` tiene `TableRelation` a `Ded. Ganancias Vigente.Código` (códigos de BC como `PREPAGA`, `HIPOTECA`, `SERV_DOM`, `HIJO_MENOR`). Sin `Validate`, la relación no se hace cumplir: la fila entra con descripción vacía y el motor la suma igual (`CalcDeduccionesGanancias`, parte 2: todas las filas con `Importe Fijo > 0` de la **última** vigencia, como `Gasto`). No hay tabla de equivalencia SIRADIG -> código BC.

> [!warning] Importar dos veces con tipos distintos puede perder deducciones
> Un tipo nuevo se inserta con `Vigencia Desde = Today()`; uno que ya existe se modifica **en su vigencia original**. El motor lee **sólo la vigencia más reciente** del empleado. Si una presentación posterior agrega un tipo nuevo, las filas de las vigencias anteriores quedan ignoradas por el cálculo (inferido leyendo Cod50048 + Cod50016; no ejecutado).

> [!warning] "Procesar Importación" no funciona sobre archivos subidos
> Los archivos subidos desde la PC guardan en `Archivo Origen` sólo el **nombre**, no una ruta de servidor, y `ProcesarImportacionActual`/`ProcesarImportacionesPendientes` leen el archivo del disco del servidor. Un registro pendiente de una subida falla con "El archivo ... no existe". El XML sí quedó guardado en `AFIP Interface Register.File`, pero ese camino de reproceso no lo usa.

> [!warning] La importación por carpeta usa `[TryFunction]` que escribe
> `Orquestador.TryImportarArchivo` escribe en base de datos dentro de un `[TryFunction]`; la ruta de archivos subidos se reescribió con `Codeunit.Run` porque el runtime rechaza esas escrituras en ese contexto (`NavNclTryFunctionWriteException`, ver comentario de Cod50058 y [[codeunit-run-necesita-commit]]). La ruta de carpeta quedó con el patrón viejo: **sin verificar** que funcione con varios archivos.

- **Una carga importada no deduce hasta completarla a mano**: sin `Cód. Tipo Ded.` y sin alta a efectos del impuesto (`Fecha alta impuesto`, campo 50008 de la extensión Final Version) el motor no la deduce ([[familiar-alta-impuesto]]).
- `Relative Code` recibe el código de parentesco de SIRADIG tal cual (`1` cónyuge, `3` hijo menor de 18, `30` hijastro, `31` hijo incapacitado, `32` hijastro incapacitado, `103` hijo de 18 a 24); `MapearCodigoParentesco` es un `CopyStr`.
- El estado `Procesado con Advertencias` está en el enum pero **nadie lo asigna**; las advertencias (`WarningDeduccionIgnorada`) están declaradas y sin uso.
- No hay Job Queue posible sobre `ProcesarImportacionesPendientes`: es un `procedure`, el codeunit no tiene `OnRun`. La sugerencia de `README_SIRADIG.md` ("Job Queue, función ProcesarImportacionesPendientes") no se puede cumplir tal cual.

## Documentación vieja del repo

Los seis `.md` de la raíz (`README_SIRADIG.md`, `IMPORTACION_SIRADIG_GUIA.md`, `INDICE_IMPORTACION_SIRADIG.md`, `IMPLEMENTACION_SIRADIG_RESUMEN.md`, `GUIA_PRUEBAS_SIRADIG.md`, `SIRADIG_EJEMPLOS_Y_EXTENSIONES.md`) y `EJEMPLO_SIRADIG.xml` son de **11/6/2026** y hablan de **IDs que ya no existen**: `Cod50023/50024/50025` y `Pag50161`. En el código actual son `Cod50047` (gestor), `Cod50048` (procesador), `Cod50046` (orquestador) y `Pag50171`; además aparecieron `Cod50058`, `Cod50059`, `Tab60027` y `Pag50172/50173`. **Manda el código.** El resto del contenido de esos documentos (formato de archivo, códigos de deducción y parentesco, troubleshooting) sigue siendo válido salvo lo marcado arriba.

## Ver también

[[Tabla - Importación SIRADIG]], [[Tabla - Cue SIRADIG]], [[Tabla - Ded. Ganancias Empleado]], [[Tabla - Ded. Ganancias Vigente]], [[Extensión - Employee Relative]], [[Extensión - Human Resources Setup SIRADIG]], [[Deducciones de Ganancias y familiares]], [[SIRADIG - modelo y parser]].

## ZIP con todas las presentaciones (19/10/2026)

AFIP baja las presentaciones de todos los trabajadores en un único ZIP (`resultadosXML.zip`, un XML por trabajador con el nombre `CUIL_PERIODO_presentacion_NRO.xml`). **Importar Archivos SIRADIG** lo acepta: un `.zip` a secas se abre y cada XML se importa como un archivo más, con el CUIL sacado del nombre de la entrada (`Gestor Archivos SIRADIG.ExtraerXmlsDelZip`, Cod50047). Un `.xml.zip` sigue siendo UNA presentación con el CUIL del nombre del zip.

El orquestador (Cod50046, `ImportarArchivosSubidos`) ahora lee primero todo lo subido a una lista de (nombre, XML) y después importa de a uno con el mismo `Commit` + `Run` de siempre; el importador (Cod50058) tiene `SetContenido` para trabajar desde el texto ya leído. Un archivo ilegible o con nombre inválido se anota en el resumen y no frena al resto; reimportar la misma presentación se rechaza con "ya ha sido importado". La importación **por carpeta del servidor** sigue pidiendo `.xml.zip` / `.xml` sueltos: no abre ZIP con varias presentaciones.

Pendiente de probar con la importación real. El archivo de prueba es `2026-01/resultadosXML.zip`: 19 presentaciones de enero de 2026 (37 cargas, 24 deducciones), los 19 CUIL son empleados de BC.

## Cambios del 19/10/2026 sobre el procesamiento (deducciones, familiares y archivos subidos)

Salen de importar `2026-01/resultadosXML.zip` (19 presentaciones de enero de 2026) y comparar lo que el procesador habría hecho con lo que ya hay en BC.

**Procesar un archivo subido desde la PC.** Antes la acción **Procesar Importación** (y el proceso masivo) leían el archivo de la ruta guardada en `Archivo Origen`, que para un archivo subido es sólo el nombre: fallaba. Ahora el XML se lee del registro de auditoría (`Auditoria AFIP Interface.LeerXmlRegistrado`, usa `AFIP Register Entry No.`) y sólo si no está se cae al archivo del servidor (`Orquestador SIRADIG.LeerXmlDeLaImportacion`).

**Deducciones: mes a mes y con la vigencia del mes.** Cada `<deduccion>` trae `<periodo mesDesde mesHasta montoMensual>`: el importe de cada mes. `Ded. Ganancias Empleado."Importe Fijo"` es mensual y el motor lee sólo el conjunto de la vigencia más reciente, así que la declaración se carga como línea de tiempo: una vigencia (día 1 del mes) por cada mes en que cambia el conjunto de deducciones activas, con todas las activas ese mes; cuando deja de haber activas, una línea en cero por cada tipo que terminó. Antes se cargaba `montoTotal` (anual) como mensual y con vigencia = hoy. En enero de 2026: 8 empleados con deducciones, 24 líneas de importe con vigencia 1/1 y 24 líneas en cero con vigencia 1/2 (la presentación de enero sólo declara enero). Un recálculo de enero, febrero o marzo de esos empleados **cambia**: el motor ahora ve las deducciones, sin los topes de Meta4 (educación 40 % de la ganancia no imponible, médica 5 %, etc.).

**Familiares: no se pisa lo que ya está.** `EncontrarFamiliar` busca por documento (SIRADIG informa el CUIL del familiar, 11 dígitos; BC guarda el DNI: son los dígitos 3 a 10), después por fecha de nacimiento si identifica a uno solo del empleado (36 de 37 cargas) y recién después por apellido y nombre (4 de 37: BC y SIRADIG los escriben distinto). Un familiar que ya existe conserva su código de parentesco, documento y datos del impuesto: sólo se completan los vacíos. Uno nuevo se crea con el código de SIRADIG si existe en la tabla Relative (1, 3, 30, 31, 32, 103) o `CC` para el 51, y queda sin `Cód. Tipo Ded.` ni fecha de alta del impuesto: no deduce hasta que alguien se los cargue ([[familiar-alta-impuesto]]). El `mesDesde`, `mesHasta` y `porcentajeDeduccion` del XML hoy no se usan.

## Árbol de importaciones por período (19/10/2026)

`Árbol de Importaciones SIRADIG` (Pag110075, con el buffer temporal Tab110066 y el armado en Cod110076) agrupa **Mes de presentación → Estado → Importación**. El período de SIRADIG es el año fiscal (2026) y todas las presentaciones del año caen en él, por eso el corte es el mes de la `Fecha Presentación` (enero, febrero...); las importaciones sin fecha van a un nodo aparte, con contadores (importaciones, pendientes, con errores, procesadas) por nodo y los pendientes arriba. Se abre desde la lista con **Ver por Período**.

Las acciones corren sobre el **alcance** de lo marcado, igual que el árbol de liquidaciones:
- **Procesar**: de lo marcado toma sólo lo pendiente. Parado en un mes de presentación, procesa todo lo que falte en una sola pasada y con un único resumen (`Orquestador SIRADIG.ProcesarFiltradas`, también lo usa la lista con las filas seleccionadas: antes procesaba una sola).
- **Eliminar**: las que no están procesadas exitosamente, con una confirmación que dice cuántas son.
- **Abrir lista**: la lista acotada al mes de presentación y estado del nodo.
- **Importar Archivos SIRADIG**: la misma carga que la lista (xml, .xml.zip o un zip con todas).

`ProcesarFiltradas` no usa `Commit` ni `TryFunction`: la importación de un CUIL que no existe en BC queda en "Error en Procesamiento" con el motivo y el resto sigue; cualquier otro error corta todo y **deshace la pasada completa** —no queda nada a medias—. Se recorre una lista de números con `Get` porque procesar cambia el `Estado` y un bucle que filtra por Estado y lo modifica se detiene sin avisar.

Los objetos de SIRADIG (página, tabla, codeunits) **no están en ningún permission set**; sólo se agregaron los tres del árbol nuevo. Un usuario sin SUPER no podría abrir la lista.
