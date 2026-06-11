# Guía de Importación de Reportes SIRADIG

## Descripción General

Este sistema permite importar automáticamente reportes SIRADIG (Sistema de Registro y Actualización de Deducciones del Impuesto a las Ganancias) en formato ZIP/XML para actualizar:
- **Deducciones de Ganancias** (Tab60022): Montos de deducciones por empleado
- **Cargas de Familia** (Employee Relative): Dependientes/familiares a cargo

## Estructura de Archivos Esperada

Los archivos SIRADIG deben estar en formato ZIP con la siguiente nomenclatura:

```
CUIL_PERIODO_presentacion_NRO.xml.zip
```

Ejemplo:
```
20666666667_2024_presentacion_001.xml.zip
```

Donde:
- **CUIL**: 11 dígitos (identificador del empleado)
- **PERIODO**: 4 dígitos (año, ej: 2024)
- **NRO**: 3 dígitos (número de presentación)

Cada ZIP contiene un archivo XML con estructura SIRADIG v1.24 (o superior).

## Componentes Creados

### Tablas
- **Tab60026 - Importación SIRADIG**: Registro de todas las importaciones realizadas, con auditoría
  - Almacena: CUIL, período, fecha importación, estado, cantidad de registros importados

### Enumeraciones
- **Enum50310 - SIRADIG Código Deducción**: Códigos de deducción (1-34, 99)
- **Enum50311 - SIRADIG Parentesco**: Códigos de parentesco (1, 3, 30, 31, 32, 103)
- **Enum50312 - Estado Importación SIRADIG**: Estados (Pendiente, Exitoso, Advertencias, Error)

### Codeunits

#### Cod50022 - Parser SIRADIG XML
- **ExtraerDatosDelXml()**: Lee XML y extrae metadatos (período, CUIL, etc.)
- **ObtenerDeduccionesDelXml()**: Extrae listado de deducciones
- **ObtenerCargasFamiliaDelXml()**: Extrae listado de cargas familiares

#### Cod50023 - Gestor Archivos SIRADIG
- **BuscarArchivosZip()**: Busca archivos ZIP en una carpeta (con validación de patrón)
- **ExtraerCuilDelNombreArchivo()**: Obtiene CUIL del nombre del archivo
- **DescomprimirArchivoZip()**: Descomprime ZIP y extrae XML
- **ObtenerCarpetaTemporal()**: Crea carpeta temporal para descompresión
- **LimpiarCarpetaTemporal()**: Limpia archivos temporales

#### Cod50024 - Procesador Importación SIRADIG
- **ProcesarImportacionSiradig()**: Orquesta todo el proceso
  - Valida que el empleado exista (por CUIL)
  - Importa deducciones a Tab60022
  - Importa familiares a Employee Relative
  - Actualiza estado de importación

#### Cod50025 - Orquestador SIRADIG
- **ImportarYProcesarCarpeta()**: Flujo completo
  - Busca ZIPs en carpeta
  - Importa cada archivo
  - Opcionalmente procesa automáticamente
- **ImportarArchivoSiradig()**: Importa un archivo individual
- **ProcesarImportacionesPendientes()**: Procesa todas las importaciones pendientes

### Páginas
- **Pag50161 - Importaciones SIRADIG**: Listado de importaciones con acciones
  - Ver historial de importaciones
  - Importar nuevos archivos
  - Procesar importaciones pendientes

## Flujo de Uso

### Opción 1: Importación Manual desde la Página

1. Ir a: **Importaciones SIRADIG**
2. Hacer clic en acción **"Importar Archivos SIRADIG"**
3. Ingresar la ruta de la carpeta (ej: `C:\SIRADIG\2024\`)
4. El sistema preguntará si desea procesar automáticamente
   - **Sí**: Importa y procesa inmediatamente
   - **No**: Solo importa registros, debe procesarlos después manualmente
5. Ver resultados en el listado

### Opción 2: Procesamiento de Importaciones Pendientes

1. Ir a: **Importaciones SIRADIG**
2. Hacer clic en acción **"Procesar Importación"** (sobre un registro pendiente)
3. El sistema:
   - Descomprime el ZIP
   - Lee el XML
   - Mapea códigos SIRADIG a códigos locales
   - Actualiza Tab60022 y Employee Relative
   - Limpia archivos temporales

### Opción 3: Procesamiento en Lote (desde código)

```al
var
    Orquestador: Codeunit "Orquestador SIRADIG";
    CarpetaOrigen: Text;
begin
    CarpetaOrigen := 'C:\SIRADIG\2024\';
    // Importar y procesar automáticamente
    Orquestador.ImportarYProcesarCarpeta(CarpetaOrigen, true);
    
    // O solo importar (procesamiento manual después)
    Orquestador.ImportarYProcesarCarpeta(CarpetaOrigen, false);
    
    // Procesar después
    Orquestador.ProcesarImportacionesPendientes();
end;
```

## Mapeos de Códigos

### Códigos de Deducción SIRADIG (Tab60026)
Se utilizan los códigos estándar de AFIP/ARCA:

| Código | Descripción |
|--------|-------------|
| 1 | Cuotas Médico-Asistenciales |
| 2 | Primas de Seguro |
| 3 | Donaciones |
| 4 | Intereses Préstamo Hipotecario |
| 5 | Gastos de Sepelio |
| 7 | Gastos Médicos y Paramédicos |
| 8 | Deducción Personal Doméstico |
| 9 | Aporte Soc. Garantía Recíproca |
| 10 | Vehículos Corredores Viajantes |
| ... | (Ver Enum50310) |
| 99 | Otras Deducciones |

### Códigos de Parentesco SIRADIG
| Código | Descripción |
|--------|-------------|
| 1 | Cónyuge |
| 3 | Hijo Menor de 18 Años |
| 30 | Hijastro Menor de 18 Años |
| 31 | Hijo Incapacitado para el Trabajo |
| 32 | Hijastro Incapacitado para el Trabajo |
| 103 | Hijo Mayor de 18 y Hasta 24 años (Gastos de Educación) |

## Consideraciones Importantes

### CUIL vs Social Security No.
- El sistema busca el empleado por **CUIL** en el campo `Employee."Social Security No."`
- Si tu campo de CUIL está en otro lugar, modificar en `ProcesadorImportacionSiradig.EncontrarEmpleadoPorCuil()`

### Vigencia de Deducciones
- Las deducciones se crean con **"Vigencia Desde" = TODAY()**
- Puede editarse manualmente en la tabla Tab60022 si se requiere otra fecha

### Cargas de Familia
- Se crean en **Employee Relative** con el código de parentesco SIRADIG
- Si necesitas mapear a códigos locales diferentes, editar `MapearCodigoParentesco()`

### Auditoría
- Cada importación se registra en Tab60026 con:
  - Fecha y usuario
  - Estado (Exitoso/Error/Advertencias)
  - Cantidad de deducciones y familiares importados
  - Ruta del archivo original

## Posibles Mejoras Futuras

1. **Interfaz de Usuario Mejorada**
   - Dialog de selección de carpeta (nativo de BC)
   - Vista previa de datos antes de procesar

2. **Mapeo Avanzado**
   - Configuración de correspondencia Deducción SIRADIG → Código Local
   - Configuración de Parentesco SIRADIG → Código Local

3. **Validación Extendida**
   - Validar que deducciones sean consistentes con el período
   - Validar fechas de los familiares

4. **Reportes**
   - Reporte de importaciones por período
   - Reporte de cambios en deducciones por empleado

5. **Integración con Liquidación**
   - Automática recalculación de liquidaciones pendientes
   - Notificación de cambios significativos

## Troubleshooting

### "El archivo XML no tiene estructura válida de SIRADIG"
- Verificar que el archivo XML dentro del ZIP cumple con estructura SIRADIG v1.24
- Verificar que el elemento raíz es `<presentacion>`

### "No se encontró empleado con CUIL"
- Verificar que el CUIL en `Employee."Social Security No."` es exactamente igual (sin espacios)
- El CUIL debe ser 11 dígitos sin guiones

### "Formato de nombre de archivo inválido"
- Verificar patrón: `CUIL_PERIODO_presentacion_NRO.xml.zip`
- Ejemplo correcto: `20666666667_2024_presentacion_001.xml.zip`

## Contacto y Soporte

Para reportar problemas o sugerencias, contactar al equipo de Desarrollo.
