# 🚀 Sistema de Importación SIRADIG - README

## ¿Qué se ha implementado?

Un **sistema completo de importación de reportes SIRADIG** que permite cargar automáticamente deducciones de ganancias y cargas familiares desde archivos ZIP/XML, actualizando:
- **Tab60022** - Deducciones de Ganancias por Empleado
- **Employee Relative** - Cargas de Familia

---

## 📦 Archivos Creados

### Código (8 archivos)
```
✅ src/Enums/Enum50310.SiradigCodigoDeduccion.al       (Códigos SIRADIG)
✅ src/Enums/Enum50311.SiradigParentesco.al             (Parentesco)
✅ src/Enums/Enum50312.EstadoImportacionSIRADIG.al     (Estados)
✅ src/Tables/Tab60026.ImportacionSIRADIG.al            (Auditoría)
✅ src/Codeunits/Cod50022.ParserSiradigXml.al           (Parser XML)
✅ src/Codeunits/Cod50023.GestorArchivosSiradig.al     (Gestión ZIP)
✅ src/Codeunits/Cod50024.ProcesadorImportacionSiradig (Procesar)
✅ src/Codeunits/Cod50025.OrquestadorSiradig.al         (Orquestación)
✅ src/Pages/Pag50161.ImportacionesSiradig.al           (UI)
```

### Documentación (4 archivos)
```
📄 INDICE_IMPORTACION_SIRADIG.md              (Índice y navegación)
📄 IMPORTACION_SIRADIG_GUIA.md                (Guía de uso completa)
📄 IMPLEMENTACION_SIRADIG_RESUMEN.md          (Resumen técnico)
📄 SIRADIG_EJEMPLOS_Y_EXTENSIONES.md          (Ejemplos y extensiones)
📄 README_SIRADIG.md                          (Este archivo)
```

---

## 🎯 Uso Rápido

### Opción 1: Desde la Interfaz

```
1. Buscar: "Importaciones SIRADIG"
2. Clic: "Importar Archivos SIRADIG"
3. Ingresar ruta: C:\SIRADIG\2024\
4. Responder: ¿Procesar automáticamente? Sí/No
5. ✓ Listo
```

### Opción 2: Desde Código

```al
var Orquestador: Codeunit "Orquestador SIRADIG";
begin
    Orquestador.ImportarYProcesarCarpeta('C:\SIRADIG\2024\', true);
end;
```

### Opción 3: Automatizar con Job Queue

```
Crear entrada en Job Queue:
- Objeto: Codeunit 50025
- Función: ProcesarImportacionesPendientes
- Frecuencia: Diariamente
```

---

## 📋 Requerimientos Previos

1. **CUIL en Employee**
   - Campo: `Social Security No.` debe contener CUIL (11 dígitos)

2. **Carpeta con archivos SIRADIG**
   - Formato: `CUIL_PERIODO_presentacion_NRO.xml.zip`
   - Ejemplo: `20666666667_2024_presentacion_001.xml.zip`

3. **Permisos**
   - Lectura en carpeta de ZIPs
   - Escritura en Tab60022 y Employee Relative

---

## 🔍 Características

✅ **Importación automatizada**
- Busca archivos ZIP en carpeta automáticamente
- Valida formato de nombre y estructura XML
- Descomprime y parsea en segundo plano

✅ **Actualización inteligente**
- Crea/actualiza deducciones en Tab60022
- Crea familiares en Employee Relative
- Usa códigos SIRADIG estándar (ARCA)

✅ **Auditoría completa**
- Registra todas las importaciones en Tab60026
- Guarda: CUIL, período, fecha, usuario, estado
- Permite rastrear cambios en deducciones

✅ **Manejo de errores**
- Valida que empleado exista
- Detecta archivos duplicados
- Registra errores y advertencias

✅ **Flexible**
- Procesamiento inmediato o diferido
- Fácil de extender (ver SIRADIG_EJEMPLOS_Y_EXTENSIONES.md)
- Mapeos personalizables

---

## 📊 Datos Soportados

### Deducciones SIRADIG
Códigos: 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 21, 22, 23, 24, 25, 32, 33, 34, 99

Ejemplos:
- 1 = Cuotas Médico-Asistenciales
- 4 = Intereses Préstamo Hipotecario
- 32 = Gastos de Educación
- 99 = Otras Deducciones

### Cargas de Familia (Parentesco)
Códigos: 1, 3, 30, 31, 32, 103

Ejemplos:
- 1 = Cónyuge
- 3 = Hijo menor de 18 años
- 31 = Hijo incapacitado
- 103 = Hijo de 18-24 años (educación)

---

## 📚 Documentación

| Documento | Leer si... |
|-----------|-----------|
| [INDICE_IMPORTACION_SIRADIG.md](INDICE_IMPORTACION_SIRADIG.md) | Necesitas navegación general |
| [IMPORTACION_SIRADIG_GUIA.md](IMPORTACION_SIRADIG_GUIA.md) | Eres usuario o administrador |
| [IMPLEMENTACION_SIRADIG_RESUMEN.md](IMPLEMENTACION_SIRADIG_RESUMEN.md) | Eres desarrollador |
| [SIRADIG_EJEMPLOS_Y_EXTENSIONES.md](SIRADIG_EJEMPLOS_Y_EXTENSIONES.md) | Quieres extender la funcionalidad |

---

## 🧪 Pruebas Recomendadas

1. ✅ Importar archivo de prueba
2. ✅ Validar Tab60022 actualizada
3. ✅ Validar Employee Relative creado
4. ✅ Revisar auditoría en Tab60026
5. ✅ Probar con CUIL inexistente (debe fallar gracefully)
6. ✅ Probar procesamiento automático vs diferido

---

## ⚙️ Configuración Inicial

### 1. Compilar los nuevos archivos
```
En VS Code o Business Central:
- Compilar todos los archivos .al nuevos
- Sin errores esperados
```

### 2. Verificar CUIL en Employee
```
Table: Employee
Field: Social Security No.
Debe contener: CUIL sin guiones (ej: 20666666667)
```

### 3. Crear carpeta para ZIPs
```
Recomendado: C:\SIRADIG\2024\
Permisos: Usuario de BC debe tener acceso de lectura
```

### 4. Opcional: Configurar Job Queue
```
Para automatización diaria:
Object: Codeunit 50025 "Orquestador SIRADIG"
Function: ProcesarImportacionesPendientes
Schedule: 22:00 UTC
```

---

## 🚨 Si Algo No Funciona

### Error: "No se encontró empleado con CUIL"
- Verificar `Employee."Social Security No."` exactamente igual
- CUIL debe ser 11 dígitos sin guiones o espacios

### Error: "Formato de nombre de archivo inválido"
- Patrón esperado: `CUIL_PERIODO_presentacion_NRO.xml.zip`
- Ejemplo: `20666666667_2024_presentacion_001.xml.zip`

### Error: "El archivo XML no tiene estructura válida"
- Verificar que XML dentro del ZIP es SIRADIG v1.24+
- Elemento raíz debe ser `<presentacion>`

### Ver más: [IMPORTACION_SIRADIG_GUIA.md - Troubleshooting](IMPORTACION_SIRADIG_GUIA.md#troubleshooting)

---

## 🔮 Próximas Mejoras (Opcionales)

- [ ] Crear reporte de importaciones por período
- [ ] Crear asistente (wizard) mejorado
- [ ] Integrar recálculo de liquidaciones pendientes
- [ ] Dashboard con resumen de importaciones
- [ ] Mapeos personalizables de códigos

Ver: [SIRADIG_EJEMPLOS_Y_EXTENSIONES.md](SIRADIG_EJEMPLOS_Y_EXTENSIONES.md)

---

## 📞 Información de Contacto

Para preguntas, reportar bugs o sugerencias:
- Contactar al equipo de Desarrollo Payroll

---

## 📈 Estadísticas

| Métrica | Valor |
|---------|-------|
| Tablas creadas | 1 |
| Enumeraciones creadas | 3 |
| Codeunits creados | 4 |
| Páginas creadas | 1 |
| Líneas de código | ~1,500 |
| Documentación | 4 archivos |
| Cobertura SIRADIG | v1.24+ |

---

## ✅ Estado

- **Implementación**: ✅ Completa
- **Documentación**: ✅ Completa
- **Testing**: 🔲 Pendiente (a cargo de usuario)
- **Producción**: 🔲 Por definir

---

## 📖 Quick Links

- 🏠 [Ir al Índice](INDICE_IMPORTACION_SIRADIG.md)
- 📚 [Leer Guía de Uso](IMPORTACION_SIRADIG_GUIA.md)
- 🔧 [Leer Especificación Técnica](IMPLEMENTACION_SIRADIG_RESUMEN.md)
- 💡 [Ver Ejemplos y Extensiones](SIRADIG_EJEMPLOS_Y_EXTENSIONES.md)

---

**Fecha**: 11 de junio de 2026  
**Versión**: 1.0  
**Estado**: Listo para Testing
