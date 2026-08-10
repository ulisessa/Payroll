# Nota: Manejo de Archivos ZIP en BC 25.2

## Situación

✅ **Actualización 2026-06-11:** La descompresión automática (Opción 1) está confirmada y funcionando en este entorno On-Premises mediante variables `DotNet` (`System.IO.DirectoryInfo`, `System.Array`, `System.IO.FileInfo`, `System.IO.Compression.ZipFile`).

**Requisito de compilación (1/2):** Estos tipos requieren que los ensamblados .NET 8 correspondientes estén disponibles en la carpeta `.netpackages/` del proyecto (referenciada en `al.assemblyProbingPaths` de `.vscode/settings.json`). Esa carpeta no se versiona en git (ver `.gitignore`), por lo que debe poblarse en cada máquina de desarrollo copiando los siguientes archivos desde `C:\Program Files\dotnet\shared\Microsoft.NETCore.App\<versión>\`:

```
System.Private.CoreLib.dll
System.Runtime.dll
System.Runtime.InteropServices.dll
System.Memory.dll
System.IO.FileSystem.dll
System.IO.Compression.dll
System.IO.Compression.FileSystem.dll
System.IO.Compression.ZipFile.dll
System.Collections.dll
System.Linq.dll
netstandard.dll
```

Adicionalmente, el selector de carpeta local (`Page "Carpeta SIRADIG Dialog"`, acción "Examinar...") usa `System.Windows.Forms.FolderBrowserDialog`, cuyo ensamblado **no** está en `Microsoft.NETCore.App` sino en el runtime de escritorio. Copiar también:

```
System.Windows.Forms.dll
```

desde `C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\<versión>\` (usar la misma versión que las demás DLLs, ej. 8.0.28). Esto solo funciona si el servicio de Business Central se ejecuta con acceso a un escritorio interactivo; en un Windows Service estándar, `ShowDialog()` puede fallar y debe usarse el campo de texto manual como respaldo.

**Requisito de compilación (2/2):** Además de las DLLs, AL necesita declarar explícitamente cada tipo `DotNet` mediante un objeto `dotnet { assembly(...) { type(...) {} } }`. Sin esto, el compilador falla con `AL0185: DotNet 'Tipo' is missing`. Esta declaración ya está incluida en el código fuente (`src/DotNet/Assemblies.al`), por lo que solo es necesario asegurarse de que las DLLs del punto anterior estén presentes en `.netpackages/`.

El código mantiene también el flujo manual (Opción 2) como alternativa para entornos donde estos ensamblados no estén disponibles.

## Dos flujos posibles

### Opción 1: Descompresión Automática (Preferida)

Si el entorno BC 25.2 tiene disponibles las APIs de System.IO.Compression:

```
Carpeta:
├── 20666666667_2024_presentacion_001.xml.zip
├── 20777777778_2024_presentacion_002.xml.zip
└── ...

Usuario hace: Importar Archivos SIRADIG → [Seleccionar carpeta]
Sistema: Descomprime automáticamente y procesa
```

### Opción 2: Descompresión Manual (Respaldo)

Si la descompresión automática no funciona:

**Paso 1: Descomprimir manualmente**
```
C:\SIRADIG\2024\20666666667_2024_presentacion_001.xml.zip
```
Usar Windows o WinRAR para extraer → resultado:
```
C:\SIRADIG\2024\20666666667_2024_presentacion_001.xml
```

**Paso 2: Importar desde BC**
```
Usuario hace: Importar Archivos SIRADIG → [Seleccionar carpeta]
Sistema: Detecta archivos .xml y procesa directamente
```

## Cómo saber cuál usar

### Prueba de descompresión automática

1. Crear un archivo ZIP de prueba (ej: `20666666667_2024_presentacion_001.xml.zip`)
2. Copiarlo en una carpeta de prueba: `C:\SIRADIG\Test\`
3. En BC, ir a **Importaciones SIRADIG**
4. Hacer clic en **Importar Archivos SIRADIG**
5. Seleccionar `C:\SIRADIG\Test\`

**Resultado esperado:**
- ✅ Si funciona: Sistema descomprime automáticamente
- ❌ Si falla: Usar descompresión manual (Opción 2)

## Código que lo soporta

### Codeunit 50023: Gestor Archivos SIRADIG

```al
// Busca tanto ZIPs como XMLs
procedure BuscarArchivosZip(...) - busca *.xml.zip
procedure BuscarArchivosXml(...) - busca *.xml

// Intenta extraer automáticamente
procedure DescomprimirArchivoZip(...) - descomprime ZIP
procedure IntentarExtraerZip(...) - intento fallible
```

### Codeunit 50025: Orquestador SIRADIG

```al
// Importa tanto ZIPs como XMLs
procedure ImportarYProcesarCarpeta(...)
  └─ foreach ArchivosZip
  └─ foreach ArchivosXml

procedure ImportarArchivoSiradig(...) - para .xml.zip
procedure ImportarArchivoXmlDirecto(...) - para .xml directo
```

## Recomendaciones

### Antes de producción

1. **Prueba de concepto en DEV**
   - Crear un ZIP de prueba
   - Intentar importación automática
   - Documentar si funciona o no

2. **Si falla descompresión automática**
   - Crear un script PowerShell reutilizable para descompresión
   - Entrenar usuarios a descomprimir antes de importar
   - Crear carpeta estándar: `C:\SIRADIG\[AÑO]\XML_Descomprimidos\`

3. **Si funciona descompresión automática**
   - ¡Perfecto! Usar tal cual
   - Documentar que es automático en procedimientos de usuario

### Para usuarios

**Manual del usuario - Importación SIRADIG:**

#### Si recibe archivos .xml.zip:

**Opción A - Automática (recomendada si funciona en su sistema):**
1. Copiar archivos ZIP a `C:\SIRADIG\[AÑO]\`
2. Abrir BC → Importaciones SIRADIG
3. Acción: Importar Archivos SIRADIG
4. Ingresar carpeta: `C:\SIRADIG\[AÑO]\`
5. El sistema descomprime y procesa automáticamente

**Opción B - Manual:**
1. Descomprimir ZIP usando Windows o WinRAR
   - Click derecho → Extraer todo...
   - Guardar en: `C:\SIRADIG\[AÑO]\`
2. Abrir BC → Importaciones SIRADIG
3. Acción: Importar Archivos SIRADIG
4. Ingresar carpeta: `C:\SIRADIG\[AÑO]\`
5. El sistema detecta archivos .xml y procesa

## Consideraciones técnicas

### Por qué existe esta limitación

- Business Central AL tiene acceso limitado a APIs .NET
- System.IO.Compression puede no estar expuesta en todos los entornos
- Diferentes versiones de BC (25.0 vs 25.2) pueden tener disponibilidades distintas

### Soluciones alternativas consideradas

1. **PowerShell externo**: Viable pero requiere permisos y configuración adicional
2. **Servicio web**: Overkill para descompresión
3. **Descompresión manual**: Pragmática y simple
4. **API de terceros**: No recomendado por dependencias

### Próximas mejoras

Si BC 25.2 incluye Temp Blob mejorado:
```al
// Futuro: Si Temp Blob expone ZIP handling
TempBlob.FromZip(RutaZip);
```

## Contacto y soporte

Si encuentra problemas con la descompresión:
1. Verificar que usuario tiene permisos de lectura en carpeta
2. Asegurar que archivo ZIP es válido (probar en Windows)
3. Considerar usar descompresión manual como workaround
4. Documentar el comportamiento para equipo de TI
