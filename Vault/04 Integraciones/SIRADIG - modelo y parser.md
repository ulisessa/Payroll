---
tipo: referencia
tags: [siradig, afip, parser, modelo-de-datos, ganancias]
fuente: [src/Codeunits/Cod50022.ParserSiradigXml.al, src/Codeunits/Cod50047.GestorArchivosSiradig.al, src/Codeunits/Cod50048.ProcesadorImportacionSiradig.al, src/Codeunits/Cod50059.AuditoriaAfipInterface.al, src/Tables/Tab60026.ImportacionSIRADIG.al, src/Tables/Tab60027.CueSiradig.al, src/Tables/Tab60022.DedGananciasEmpleado.al, src/Enums/Enum50310.SiradigCodigoDeduccion.al, src/Enums/Enum50311.SiradigParentesco.al, src/Enums/Enum50312.EstadoImportacionSIRADIG.al, EJEMPLO_SIRADIG.xml]
actualizado: 2026-10-04
---

# SIRADIG - modelo y parser

Detalle técnico de los objetos de la importación SIRADIG. Flujo de uso y advertencias: [[SIRADIG - importación]].

## Objetos

| Objeto | Nombre | Rol |
|---|---|---|
| Cod50022 | `Parser SIRADIG XML` (Internal) | Extrae metadatos y arma los JSON de deducciones y cargas. |
| Cod50046 | `Orquestador SIRADIG` (Public) | `ImportarYProcesarCarpeta`, `ImportarArchivosSubidos`, `ProcesarImportacionesPendientes`. |
| Cod50047 | `Gestor Archivos SIRADIG` (Internal) | Buscar `.xml.zip`/`.xml` en carpeta de servidor; descomprimir (`Data Compression`); CUIL del nombre; `NormalizarCuil`. |
| Cod50048 | `Procesador Importación SIRADIG` (Internal) | Empleado por CUIL; deducciones a Tab60022; cargas a `Employee Relative`; marca el estado. |
| Cod50058 | `Importador Archivo SIRADIG` | Importa **un** archivo subido vía `Codeunit.Run` (`SetParametros`, `GetContadores`). |
| Cod50059 | `Auditoria AFIP Interface` | Escribe `AFIP Interface Register` (cabecera, con el XML) y `...detail` (campo/valor anterior/valor nuevo). Numeración manual con `LockTable` + `FindLast`. |
| Tab60026 | `Importación SIRADIG` | Una fila por archivo importado. |
| Tab60027 | `Cue SIRADIG` | FlowFields de conteo por estado (para el Role Center). |
| Tab60022 | `Ded. Ganancias Empleado` | Destino de las deducciones (no es de SIRADIG; es del motor). |
| Pag50171 / 50172 / 50173 | `Importaciones SIRADIG` / `Carpeta SIRADIG Dialog` / `Cue SIRADIG` | UI. |
| Enum50310 / 50311 / 50312 | `SIRADIG Código Deducción` / `SIRADIG Parentesco` / `Estado Importación SIRADIG` | Los dos primeros **no se usan** en ningún código (verificado con grep): la validación del tipo es una lista fija en `ValidarTipoDeduccionSiradig`. |

## Tab60026 `Importación SIRADIG`

`No.` (autoincremental, PK), `CUIL Empleado` (Code[20], solo dígitos), `No. Empleado` (relación a `Employee`), `Período` (Integer: **aaaamm**, p. ej. 202406), `Nro. Presentación`, `Fecha Presentación`, `Archivo Origen` (Text[250]: ruta de servidor en importación por carpeta, **sólo el nombre** en la subida), `Fecha Importación` y `Usuario Importación` (se fijan **al procesar**), `Estado`, `Deducciones Importadas`, `Cargas Familia Importadas`, `Mensajes Error` (500), `AFIP Register Entry No.` (relación al registro de interfaz). Claves: PK, `K2 (CUIL, Período, Nro. Presentación)` (no única), `K3 (Estado, Fecha Importación)`.

`Estado Importación SIRADIG`: `Pendiente Procesar` (0), `Procesado Exitosamente` (1), `Procesado con Advertencias` (2, **sin uso**), `Error en Procesamiento` (3).

## El formato esperado del XML (`EJEMPLO_SIRADIG.xml`)

```xml
<presentacion>
  <periodo>202406</periodo>
  <nroPresentacion>001</nroPresentacion>
  <fechaPresentacion>2024-06-30</fechaPresentacion>
  <cuit>20666666667</cuit>
  <deducciones>
    <deduccion tipo="1"><montoTotal>1500.00</montoTotal><descripcion>...</descripcion></deduccion>
  </deducciones>
  <cargasFamilia>
    <cargaFamilia>
      <tipoDoc>DNI</tipoDoc><nroDoc>...</nroDoc><apellido/><nombre/><fechaNac>1990-05-15</fechaNac><parentesco>1</parentesco>
    </cargaFamilia>
  </cargasFamilia>
</presentacion>
```

> [!warning] Sin verificar contra un archivo real de ARCA
> El parser, los nombres de elemento (`presentacion`, `cuit`, `deduccion tipo=`, `cargaFamilia`) y el `EJEMPLO_SIRADIG.xml` son un **formato simplificado propio**. No se encontró en el repo ninguna presentación real ni el esquema oficial del F.572 web; la documentación habla de "SIRADIG v1.24+" sin respaldo. Hay que probar con un archivo bajado del sistema real antes de asumir que los nombres coinciden.

## Cómo parsea Cod50022

**No usa un parser XML**: busca cadenas de texto con `IndexOf`/`Substring`.

- `ExtraerDatosDelXml`: error si está vacío o no contiene `<presentacion`. Lee `periodo`, `nroPresentacion`, `fechaPresentacion` con `Evaluate` (si falla, queda en 0), **`cuit`** (si falta -> error "No se encontró CUIL"; se normaliza) y **cuenta** ocurrencias de `<deduccion` y `<cargaFamilia` (incluye por prefijo `<deducciones>`, que cuenta como una más: el conteo previo puede quedar inflado; el conteo definitivo lo reescribe el procesador).
- `ObtenerDeduccionesDelXml`: recorre `<deduccion ` ... `</deduccion>`, lee el atributo `tipo` y el elemento `montoTotal`, y arma un **JSON** `[{"tipo":..,"monto":..},..]` por concatenación de texto.
- `ObtenerCargasFamiliaDelXml`: ídem con `<cargaFamilia>` y los elementos `tipoDoc, nroDoc, apellido, nombre, fechaNac, parentesco`.
- `ExtractXmlValue` busca el **primer** par `<tag>`...`</tag>` en el fragmento; no maneja atributos, espacios de nombres, `CDATA` ni elementos repetidos con el mismo nombre dentro de un fragmento.
- El JSON se arma sin escapar: un apellido con comilla doble o contrabarra **rompe el JSON** y `ReadFrom` falla -> el procesador hace `exit` y esa carga se pierde sin error (sólo se vería el contador en 0).
- Tipos de deducción y montos van sin comillas en el JSON; un `monto` con coma decimal no es un número JSON válido (inferido; no probado).

El texto se lee con `ReadText` por líneas y se **concatena sin saltos de línea** (`ReadStreamAsText`).

## Auditoría AFIP (`Auditoria AFIP Interface`)

Reutiliza el esquema de trazabilidad que ya usan las interfaces con AFIP de la extensión Final Version/Grupo Arbumasa (`AFIP Interface Register` / `AFIP Interface Register detail`). Aquí **no hay llamada a un web service**: `Service = 'SIRADIG'`, `Source = Archivo Origen`, `Destination = CUIL`, `UniqueID = período-nroPresentación`, `File` = el XML completo. Es el mismo precedente que propone el [[Firma digital de recibos - decisión]] para el modelo de datos de la evidencia de firma.

## Cómo se consume lo importado

- `Ded. Ganancias Empleado` (60022): versión = conjunto de filas con la misma `(No. Empleado, Vigencia Desde)`; el motor toma la **última** con `Vigencia Desde <= FechaRef`; `Importe Fijo > 0` se usa directo (prepaga, hipoteca, servicio doméstico), `Importe Fijo = 0` toma `Ded. Ganancias Vigente.Importe Anual × Cantidad`.
- Familiares (`Employee Relative` + `TabExt52002`): deducen sólo si tienen `Cód. Tipo Ded.`, **fecha de alta a efectos del impuesto** y están dentro del tope de edad que fija el parámetro del tipo (`Edad Máxima Familiar`). Detalle en [[familiar-alta-impuesto]].
- El cálculo de Ganancias completo está en las notas del motor (retención, grossing-up: [[grossing-up-tapa-errores]]).

## Ver también

[[Tabla - Importación SIRADIG]], [[Tabla - Cue SIRADIG]], [[Tabla - Ded. Ganancias Empleado]], [[Extensión - Employee Relative]], [[Deducciones de Ganancias y familiares]], [[SIRADIG - importación]].
