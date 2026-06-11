# Nota: Manejo de Archivos ZIP en BC 25.2

## Situación

Business Central 25.2 tiene limitaciones en la disponibilidad de APIs para descomprimir archivos ZIP programáticamente. El código ha sido diseñado para:

1. **Intentar descompresión automática** usando las APIs disponibles
2. **Soportar descompresión manual** como alternativa

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
