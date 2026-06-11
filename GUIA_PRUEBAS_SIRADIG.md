# Guía de Pruebas: Sistema de Importación SIRADIG

## Estado Actual

✅ **Implementación Completada:**
- Codeunits compilados y listos
- Páginas UI implementadas
- Tablas de auditoría creadas
- Enumeraciones de códigos SIRADIG

## Checklist Pre-Compilación

Antes de compilar en BC, verificar:

- [ ] Archivo `Cod50022.ParserSiradigXml.al` - Parser XML simplificado
- [ ] Archivo `Cod50023.GestorArchivosSiradig.al` - Gestor de archivos
- [ ] Archivo `Cod50024.ProcesadorImportacionSiradig.al` - Procesador de datos
- [ ] Archivo `Cod50025.OrquestadorSiradig.al` - Orquestador
- [ ] Archivo `Pag50161.ImportacionesSiradig.al` - Página UI
- [ ] Archivo `Tab60026.ImportacionSIRADIG.al` - Tabla de auditoría
- [ ] Enumeraciones 50310, 50311, 50312 creadas

## Paso 1: Compilación

1. Abrir **Business Central** en DEV
2. Buscar: **Extensión**
3. Hacer clic en **Publicar** o **Compilar sin publicar**
4. Esperar a que compile (sin errores AL)

### Errores Esperados vs. Reales

**Errores que NO debería haber:**
- ❌ AL0791 (Unknown namespace) - Ya corregido
- ❌ AL0134 (XDocument not found) - Ya corregido
- ❌ AL0134 (ZipArchive not found) - Manejado con fallback

**Si aparecen otros errores:**
- Revisar que todas las tablas referenciadas existan
- Verificar que campos de Tab60022 existen
- Verificar que Employee Relative table existe

## Paso 2: Configuración Previa

### 2.1 Preparar datos de empleado

```
Employee (Empleado):
  No.: E-001
  Social Security No.: 20666666667  (← Importante: debe ser CUIL de 11 dígitos)
  First Name: Juan
  Last Name: García
```

**Verificar:**
```sql
SELECT "No.", "Social Security No." FROM Employee 
WHERE "Social Security No." = '20666666667'
```

### 2.2 Crear estructura de carpetas

```
C:\SIRADIG\
├── 2024\
│   ├── XML_Descomprimidos\    (← Para ZIPs descomprimidos manualmente si es necesario)
│   └── (aquí irán los archivos de prueba)
└── 2025\
```

### 2.3 Preparar archivo de prueba

**Opción A: Usar ejemplo incluido**
```
Copiar: EJEMPLO_SIRADIG.xml
Hacia: C:\SIRADIG\2024\20666666667_2024_presentacion_001.xml
```

**Opción B: Renombrar con patrón correcto**
```
Archivo recibido: presentacion_SIRADIG.xml
Renombrar a: 20666666667_2024_presentacion_001.xml
              ↑            ↑    ↑              ↑
              CUIL      Período  Literal    Número
```

## Paso 3: Prueba Manual (Sin ZIP)

### Test 1: Importación de XML directo

1. Abrir BC → Buscar **Importaciones SIRADIG**
2. Hacer clic en **Importar Archivos SIRADIG**
3. Ingresar carpeta: `C:\SIRADIG\2024\`
4. Esperar resultado

**Resultado Esperado:**
```
✅ Mensaje: "Se importaron 1 archivo(s) SIRADIG. 
Puede procesarlos desde la lista de importaciones."
```

**Qué pasó:**
- ✅ Archivo encontrado: `20666666667_2024_presentacion_001.xml`
- ✅ Registro creado en Tab60026 (auditoría)
- ✅ Estado: "Pendiente Procesar"

### Test 2: Procesamiento de importación

1. En la lista **Importaciones SIRADIG**, ver nuevo registro
2. Hacer clic en **Procesar Importación**
3. Esperar resultado

**Resultado Esperado:**
```
✅ Mensaje: "Importación procesada exitosamente. 
3 deducciones, 3 cargas familiares."
```

**Qué pasó:**
- ✅ Tab60022 actualizada con 3 deducciones
- ✅ Employee Relative creado con 3 familiares
- ✅ Estado de importación: "Procesado Exitosamente"

### Test 3: Validar datos importados

**Verificar deducciones (Tab60022):**
```
Employee No.: E-001
Tipo Deducción    | Importe Fijo
─────────────────────────────────
1 (Médica)        | 1.500,00
2 (Seguros)       | 2.000,00
4 (Hipotecario)   | 5.000,00
```

**Verificar familiares (Employee Relative):**
```
Employee: E-001
Line No. | First Name | Last Name | Date of Birth | Relationship
────────────────────────────────────────────────────────────────────
10000    | María      | García    | 1990-05-15    | 1 (Cónyuge)
20000    | Juan       | García    | 2010-03-20    | 3 (Hijo<18)
30000    | Carlos     | García    | 2006-07-10    | 3 (Hijo<18)
```

**Verificar auditoría (Tab60026):**
```
No.    | CUIL Empleado    | Período | Deducciones | Cargas | Estado
─────────────────────────────────────────────────────────────────────
1      | 20666666667      | 202406  | 3           | 3      | Procesado
```

## Paso 4: Prueba con ZIP (Opcional)

Si en tu entorno BC funciona la descompresión automática:

1. Crear archivo ZIP con nombre: `20666666667_2024_presentacion_001.xml.zip`
   - Contiene: `EJEMPLO_SIRADIG.xml`
2. Copiar a: `C:\SIRADIG\2024\`
3. Repetir Test 1 (Importación)

**Resultado Esperado:** Funciona igual pero descomprime automáticamente

## Paso 5: Prueba de Manejo de Errores

### Error 1: CUIL no existe

**Preparar:**
```
Cambiar EJEMPLO_SIRADIG.xml:
<cuit>11111111111</cuit>  (← CUIL inexistente)
Guardar como: 11111111111_2024_presentacion_001.xml
```

**Resultado Esperado:**
```
❌ Error: "No se encontró empleado con CUIL: 11111111111"
```

### Error 2: XML malformado

**Preparar:**
```
Editar archivo XML:
Eliminar: </presentacion>  (← Cerrador faltante)
Guardar como: 20666666667_2024_presentacion_002.xml
```

**Resultado Esperado:**
```
❌ Error: "El archivo XML no tiene estructura válida de SIRADIG"
```

### Error 3: Periodo duplicado

**Preparar:**
```
Usar mismo archivo de prueba otra vez
Resultado esperado:
```
❌ Error: "El archivo ya ha sido importado anteriormente."
```

## Paso 6: Validar Estados de Importación

En Tab60026, verificar que hay diferentes estados:

```al
"Pendiente Procesar"              ← Importado pero no procesado
"Procesado Exitosamente"         ← Procesado sin problemas
"Procesado con Advertencias"     ← Procesado con alertas (futuro)
"Error en Procesamiento"         ← Falló durante procesamiento
```

## Paso 7: Prueba de Batch (Job Queue)

Opcional - para automatizar:

1. Crear importaciones pendientes (no procesar automáticamente)
2. Configurar Job Queue Entry para **Orquestador SIRADIG**
3. Procedimiento: **ProcesarImportacionesPendientes**
4. Ejecutar manualmente o en horario

## Documento de Evidencia

Crear un archivo `PRUEBAS_COMPLETADAS.txt`:

```
═══════════════════════════════════════════════════════════════
  PRUEBAS DE ACEPTACIÓN - SISTEMA SIRADIG
═══════════════════════════════════════════════════════════════

Fecha: _________________
Usuario: _______________
Ambiente: DEV / PROD

═══════════════════════════════════════════════════════════════
CHECKLIST DE VALIDACIÓN
═══════════════════════════════════════════════════════════════

[✓] Paso 1: Compilación exitosa
    Fecha: ____________   Hora: ____________

[✓] Paso 2: Configuración previa completada
    Empleado E-001 con CUIL creado

[✓] Paso 3: Test manual XML
    Archivo: 20666666667_2024_presentacion_001.xml
    Resultado: Importación exitosa
    Fecha: ____________   Hora: ____________

[✓] Paso 4: Test procesamiento
    Deducciones importadas: 3
    Cargas familiares importadas: 3
    Fecha: ____________   Hora: ____________

[✓] Paso 5: Validación de datos
    Tab60022: 3 deducciones creadas ✓
    Employee Relative: 3 cargas creadas ✓
    Tab60026: Registro de auditoría ✓
    Fecha: ____________   Hora: ____________

[✓] Paso 6: Manejo de errores
    Prueba CUIL inexistente: Error correcto ✓
    Prueba XML malformado: Error correcto ✓
    Prueba duplicado: Error correcto ✓
    Fecha: ____________   Hora: ____________

[✓] Paso 7: Job Queue (si aplica)
    Configurado y funcionando
    Fecha: ____________   Hora: ____________

═══════════════════════════════════════════════════════════════
FIRMAS
═══════════════════════════════════════════════════════════════

Desarrollador: ___________________________  Fecha: __________
Probador: _______________________________  Fecha: __________
Aprobado por: ____________________________  Fecha: __________

Notas adicionales:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

## Troubleshooting

| Problema | Causa Probable | Solución |
|----------|---|---|
| Error compilación AL | APIs no disponibles | Revisar que todas las enumeraciones existen |
| "CUIL no encontrado" | Empleado no existe o CUIL diferente | Verificar Employee.Social Security No. |
| No se importa archivo | Nombre no cumple patrón | Asegurar: CUIL_PERIODO_presentacion_NRO.xml |
| ZIP no se descomprime | API no disponible en entorno | Usar descompresión manual (ver NOTA_DESCOMPRESION_ZIP.md) |
| Cargas no se crean | Employee Relative table no tiene permisos | Verificar tabla existe en DB |
| Deducciones no actualizan | Campo "Cód. Tipo" no existe o diferente | Revisar Tab60022 schema |

## Próximos pasos

Después de validar todas las pruebas:

1. ✅ Documentar cualquier desviación en "Notas adicionales"
2. ✅ Entrenar usuarios con manual incluido
3. ✅ Crear procedimientos operativos
4. ✅ Configurar backup automático de Tab60026
5. ✅ Planificar migración a PROD

## Documentos de referencia

- `README_SIRADIG.md` - Visión general
- `NOTA_DESCOMPRESION_ZIP.md` - Manejo de ZIPs
- `IMPLEMENTACION_SIRADIG_RESUMEN.md` - Especificación técnica
- `EJEMPLO_SIRADIG.xml` - Archivo de prueba

---
**Última actualización:** 2026-06-11
