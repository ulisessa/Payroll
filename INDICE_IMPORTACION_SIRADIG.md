# Índice Completo - Sistema de Importación SIRADIG

## 📑 Documentación

| Archivo | Descripción | Audiencia |
|---------|-------------|-----------|
| [IMPORTACION_SIRADIG_GUIA.md](IMPORTACION_SIRADIG_GUIA.md) | Guía completa de uso, instalación y troubleshooting | Usuarios, Operadores |
| [IMPLEMENTACION_SIRADIG_RESUMEN.md](IMPLEMENTACION_SIRADIG_RESUMEN.md) | Resumen técnico, arquitectura, archivos creados | Desarrolladores |
| [SIRADIG_EJEMPLOS_Y_EXTENSIONES.md](SIRADIG_EJEMPLOS_Y_EXTENSIONES.md) | Ejemplos de código, extensiones, validaciones | Desarrolladores |
| **INDICE_IMPORTACION_SIRADIG.md** | Este archivo - Navegación general | Todos |

---

## 🗂️ Archivos Implementados

### 📊 TABLAS (3)

```
src/Tables/
├── Tab60021.DedGananciasVigente.al           (Existente - tabla de referencia AFIP)
├── Tab60022.DedGananciasEmpleado.al          (Existente - deducciones por empleado)
└── Tab60026.ImportacionSIRADIG.al             ✅ NUEVO - Auditoría de importaciones
```

**Tab60026 - Campos:**
- No. (PK), CUIL Empleado (FK), No. Empleado (FK)
- Período, Nro. Presentación, Fecha Presentación
- Archivo Origen, Fecha Importación, Usuario Importación
- Estado (Enum), Deducciones Importadas, Cargas Familia Importadas
- Mensajes Error (para auditoría)

### 📌 ENUMERACIONES (3)

```
src/Enums/
├── Enum50310.SiradigCodigoDeduccion.al       ✅ NUEVO - Códigos SIRADIG 1-34, 99
├── Enum50311.SiradigParentesco.al             ✅ NUEVO - Códigos parentesco
└── Enum50312.EstadoImportacionSIRADIG.al     ✅ NUEVO - Estados: Pendiente/Exitoso/Error
```

### 🔧 CODEUNITS (4 + 1 existente)

```
src/Codeunits/
├── Cod50014.MotorLiquidacion.al              (Existente)
├── Cod50015.EvaluadorFormula.al              (Existente)
├── Cod50016.ContextoLiquidacion.al           (Existente)
├── Cod50017.GestionEstadoEmpleado.al         (Existente)
├── Cod50018.ProcesoLiqPorLotes.al            (Existente)
├── Cod50019.GestionLiquidacion.al            (Existente)
├── Cod50022.ParserSiradigXml.al              ✅ NUEVO - Lectura y parseo XML
├── Cod50023.GestorArchivosSiradig.al         ✅ NUEVO - Manejo ZIP/temporales
├── Cod50024.ProcesadorImportacionSiradig.al  ✅ NUEVO - Mapeo y actualización datos
└── Cod50025.OrquestadorSiradig.al            ✅ NUEVO - Orquestación del flujo
```

**Diagrama de Dependencias:**
```
Pag50161 (ImportacionesSiradig)
    ↓
Cod50025 (OrquestadorSiradig)
    ├─→ Cod50023 (GestorArchivosSiradig)
    ├─→ Cod50022 (ParserSiradigXml)
    └─→ Cod50024 (ProcesadorImportacionSiradig)
        ├─→ Tab60022 (DedGananciasEmpleado)
        ├─→ Tab60026 (ImportacionSIRADIG)
        └─→ Employee & Employee Relative (estándar)
```

### 📄 PÁGINAS (1)

```
src/Pages/
└── Pag50161.ImportacionesSiradig.al          ✅ NUEVO - Interfaz de usuario
    Actions:
    - Importar Archivos SIRADIG
    - Procesar Importación (individual)
    - Eliminar
```

### 📝 REPORTES (0)

Reporte sugerido en `SIRADIG_EJEMPLOS_Y_EXTENSIONES.md`:
```
Rep50090.ImportacionesSiradig - Resumen      (Ejemplo propuesto)
```

---

## 🔑 Funciones Principales

### Cod50022 - Parser SIRADIG XML
```al
ExtraerDatosDelXml()             // Lectura general
ObtenerDeduccionesDelXml()       // Array de deducciones
ObtenerCargasFamiliaDelXml()     // Array de familiares
```

### Cod50023 - Gestor Archivos SIRADIG
```al
BuscarArchivosZip()              // Busca ZIP en carpeta
ExtraerCuilDelNombreArchivo()    // Valida formato y extrae CUIL
DescomprimirArchivoZip()         // Descomprime y extrae XML
ObtenerCarpetaTemporal()         // Crea /tmp
LimpiarCarpetaTemporal()         // Elimina /tmp
```

### Cod50024 - Procesador Importación SIRADIG
```al
ProcesarImportacionSiradig()     // Orquesta: validar → mapear → actualizar
  ├─ EncontrarEmpleadoPorCuil()
  ├─ ProcesarDeduccionesDelXml()
  └─ ProcesarCargasFamiliaDelXml()
```

### Cod50025 - Orquestador SIRADIG
```al
ImportarYProcesarCarpeta()       // Flujo completo: buscar → importar → procesar
ImportarArchivoSiradig()         // Importar un archivo individual
ProcesarImportacionesPendientes() // Procesar todas las pendientes (Batch/Job Queue)
```

---

## 🚀 Guía Rápida por Rol

### Para USUARIOS
→ Leer: [IMPORTACION_SIRADIG_GUIA.md](IMPORTACION_SIRADIG_GUIA.md) - Secciones "Flujo de Uso" y "Troubleshooting"

**Pasos:**
1. Ir a: Buscar "Importaciones SIRADIG"
2. Clic: "Importar Archivos SIRADIG"
3. Ingresar: Ruta de carpeta con ZIP
4. Responder: ¿Procesar automáticamente?
5. ✓ Ver resultados

### Para DESARROLLADORES
→ Leer: [IMPLEMENTACION_SIRADIG_RESUMEN.md](IMPLEMENTACION_SIRADIG_RESUMEN.md)
→ Luego: [SIRADIG_EJEMPLOS_Y_EXTENSIONES.md](SIRADIG_EJEMPLOS_Y_EXTENSIONES.md)

**Casos de uso:**
- Integración con Job Queue
- Mapeos personalizados
- Validaciones adicionales
- Extensiones de funcionalidad

### Para ADMINISTRADORES
→ Leer: [IMPORTACION_SIRADIG_GUIA.md](IMPORTACION_SIRADIG_GUIA.md) - Sección "Consideraciones Importantes"

**Tareas:**
- Configurar rutas de carpetas
- Definir ciclos de importación
- Revisar auditoría (Tab60026)
- Planificar backups

### Para AUDITORÍA
→ Revisar: Tab60026 - Importación SIRADIG

**Campos disponibles para auditoría:**
- CUIL Empleado, No. Empleado
- Período, Fecha de Presentación
- Fecha/Usuario de Importación
- Estado y Mensajes de Error
- Cantidades importadas

---

## 📊 Campos de Tab60026 (Auditoría)

```al
field(1;  "No."; Integer)                      // ID único
field(2;  "CUIL Empleado"; Code[20])           // Identificador
field(3;  "No. Empleado"; Code[20])            // FK Employee
field(4;  "Período"; Integer)                  // Año: 2024
field(5;  "Nro. Presentación"; Integer)        // Secuencial: 001
field(6;  "Fecha Presentación"; Date)          // Fecha SIRADIG
field(7;  "Archivo Origen"; Text[250])         // Ruta del ZIP
field(8;  "Fecha Importación"; DateTime)       // Cuándo
field(9;  "Usuario Importación"; Code[50])     // Quién
field(10; Estado; Enum)                        // Estado actual
field(11; "Deducciones Importadas"; Integer)   // Cantidad
field(12; "Cargas Familia Importadas"; Int)    // Cantidad
field(13; "Mensajes Error"; Text[500])         // Log de errores
```

---

## 🔄 Flujos Soportados

### Flujo 1: Importación Manual + Procesamiento Automático
```
Usuario selecciona carpeta → Sistema importa → Sistema procesa → Actualización Tab60022
```
Acción: "Importar Archivos SIRADIG" + responder Sí

### Flujo 2: Importación Manual + Procesamiento Diferido
```
Usuario selecciona carpeta → Sistema importa → Estado: Pendiente → Procesar después
```
Acción: "Importar Archivos SIRADIG" + responder No
Luego: Seleccionar registro + acción "Procesar Importación"

### Flujo 3: Procesamiento en Lote (Batch Job)
```
Job Queue diario → OrquestadorSiradig.ProcesarImportacionesPendientes()
```
Ideal para automatización 100%

### Flujo 4: Importación Desde Código Personalizado
```
Tu código → Orquestador.ImportarArchivoSiradig(RutaZip, ProcesarYa)
```
Para integraciones específicas

---

## ⚙️ Configuración Necesaria

### 1. CUIL en Employee
Verificar que `Employee."Social Security No."` contiene el CUIL del empleado.

Si está en otro campo:
- Editar: `Cod50024.EncontrarEmpleadoPorCuil()`

### 2. Carpeta de Archivos SIRADIG
Ejemplo: `C:\SIRADIG\2024\`

Archivos esperados:
- `20666666667_2024_presentacion_001.xml.zip`
- `20666666668_2024_presentacion_001.xml.zip`
- etc.

### 3. Permisos
- Usuario debe tener acceso de lectura a carpeta de ZIPs
- Usuario debe tener permisos de escritura en Tab60022 y Employee Relative

### 4. Opcional: Job Queue
Para automatizar completamente:
```
Buscar: Job Queue Entries
Nuevo:
  Object Type: Codeunit
  Object ID: 50025
  Function: ProcesarImportacionesPendientes
  Frequency: Diariamente (ej: 22:00)
```

---

## 🧪 Pruebas Recomendadas

### Prueba 1: Archivo ZIP Válido
```
Input:  Archivo ZIP válido con XML SIRADIG
Result: Registro creado en Tab60026 (Pendiente)
        Tab60022 actualizada correctamente
        Employee Relative creado correctamente
```

### Prueba 2: Archivo ZIP con CUIL Inexistente
```
Input:  ZIP con CUIL que no existe en Employee
Result: Registro en Tab60026 (Error)
        Mensaje: "No se encontró empleado"
```

### Prueba 3: Archivo ZIP con Nombre Inválido
```
Input:  ZIP sin patrón CUIL_PERIODO_presentacion_NRO.xml.zip
Result: El archivo no se importa
        Mensaje: "Formato de nombre inválido"
```

### Prueba 4: Procesamiento Automático
```
Input:  Responder "Sí" a procesamiento automático
Result: Registro en Tab60026 (Exitoso)
        Sin estado Pendiente intermedio
```

### Prueba 5: Rollback Manual
```
Input:  Eliminar registro en Tab60026
Result: Las deducciones se mantienen (no hay cascade delete)
        Requiere limpieza manual si se desea revertir
```

---

## 📋 Checklist Final

### Implementación
- [x] Crear tabla Tab60026
- [x] Crear enumeraciones (3)
- [x] Crear parser XML (Cod50022)
- [x] Crear gestor de archivos (Cod50023)
- [x] Crear procesador (Cod50024)
- [x] Crear orquestador (Cod50025)
- [x] Crear página UI (Pag50161)
- [x] Documentación completa (3 archivos)

### Validación
- [ ] Compilar sin errores
- [ ] Probar importación de archivo de prueba
- [ ] Validar Tab60022 actualizada
- [ ] Validar Employee Relative creado
- [ ] Validar Tab60026 con auditoría correcta
- [ ] Probar rollback
- [ ] Probar con CUIL inexistente

### Producción
- [ ] Backup base datos antes de primer import
- [ ] Definir ciclo de importación
- [ ] Documentar procedimiento operativo
- [ ] Entrenar usuarios
- [ ] Monitorear Tab60026 regularmente

---

## 🆘 Soporte y Contacto

### Documentos de Referencia
- SIRADIG Manual: `SiRADIG - Empleador - Manual para el desarrollador.pdf`
- BC Documentation: Buscar "AL Language", "Codeunits", "Pages"

### Si algo no funciona
1. Verificar Tab60026 → Estado y "Mensajes Error"
2. Revisar [IMPORTACION_SIRADIG_GUIA.md](IMPORTACION_SIRADIG_GUIA.md) → "Troubleshooting"
3. Validar archivo ZIP: ¿formato correcto?, ¿XML válido?
4. Validar empleado: ¿existe en Employee?, ¿CUIL correcto?

---

## 📈 Estadísticas del Proyecto

| Métrica | Valor |
|---------|-------|
| Tablas nuevas | 1 |
| Enumeraciones nuevas | 3 |
| Codeunits nuevos | 4 |
| Páginas nuevas | 1 |
| Líneas de código AL | ~1,500 |
| Documentación | 4 archivos |
| Tiempo estimado de desarrollo | 8 horas |
| Complejidad | Media |

---

## 📜 Historial de Cambios

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-06-11 | Implementación inicial, soporte SIRADIG v1.24 |

---

## 🎯 Próximos Pasos Sugeridos

1. **Corto plazo (Semana 1-2)**
   - Compilar y validar en DEV
   - Crear archivo de prueba SIRADIG
   - Ejecutar pruebas unitarias

2. **Mediano plazo (Semana 3-4)**
   - Entrenar usuarios
   - Importar datos reales de prueba
   - Validar integración con liquidaciones

3. **Largo plazo**
   - Automatizar con Job Queue
   - Crear dashboards de monitoreo
   - Planificar mejoras (extensiones opcionales en SIRADIG_EJEMPLOS_Y_EXTENSIONES.md)

---

**Última actualización**: 11 de junio de 2026  
**Mantenedor**: Equipo de Desarrollo Payroll  
**Versión SIRADIG**: 1.24+  
**Versión BC**: 25.2+  
**Estado**: ✅ Implementación Completa
