---
tipo: proceso
tags: [operacion, siradig, ganancias, importacion]
fuente: [src/Pages/Pag50171.ImportacionesSiradig.al, src/Pages/Pag50172.CarpetaSiradigDialog.al, src/Pages/Pag50173.CueSiradig.al, src/Codeunits/Cod50046.OrquestadorSiradig.al, src/Codeunits/Cod50047.GestorArchivosSiradig.al, src/Codeunits/Cod50048.ProcesadorImportacionSiradig.al, src/Codeunits/Cod50058.ImportadorArchivoSiradigSubido.al, src/Tables/Tab60026.ImportacionSIRADIG.al, src/PageExtensions/PagExt50354.EmpleadoRelativoLiqExt.al, src/PageExtensions/PagExt50355.HRSetupSiradigExt.al]
actualizado: 2026-10-04
---

# Importación SIRADIG: operación

## Objetivo

Cargar al sistema las **deducciones de Ganancias 4.ª categoría y las cargas de familia** que cada empleado declaró en SIRADIG, a partir de los archivos que baja de AFIP (`.xml` o `.xml.zip`). Alimenta `Ded. Ganancias Empleado` y `Employee Relative`, que usa el cálculo de Ganancias (`DEDUC_GANANCIAS`). Diseño técnico y archivos fuente: ver las notas de integraciones.

> [!warning] Documentación vieja en la raíz del repo
> `COMIENZA_AQUI.md`, `README_SIRADIG.md`, `GUIA_PRUEBAS_SIRADIG.md`, `IMPORTACION_SIRADIG_GUIA.md`, `INDICE_IMPORTACION_SIRADIG.md`, `IMPLEMENTACION_SIRADIG_RESUMEN.md`, `SIRADIG_EJEMPLOS_Y_EXTENSIONES.md`, `RESUMEN_IMPLEMENTACION.txt` y `NOTA_DESCOMPRESION_ZIP.md` son del 11/6/2026 y describen una versión anterior: nombran la página 50161 (hoy es **50171**), los codeunits 50022-50025 (hoy 50046-50048 y 50058), piden compilar con *Ctrl+Shift+B* "en BC" y operan sólo desde una carpeta del servidor (`C:\SIRADIG\2024\`). Hoy la entrada normal es **subir archivos desde la PC**. Este manual las reemplaza en lo operativo.

## Pantallas

| Caption | ID | Rol |
|---|---|---|
| **Importaciones SIRADIG** | 50171 | Lista de importaciones (Role Center → Empleados). Columnas: número, CUIL, empleado, período, presentación, fecha de presentación, deducciones y cargas importadas, **estado**, fecha y usuario de importación, mensajes de error, **No. Registro AFIP WS** |
| **SIRADIG** (cue) | 50173 | Tarjeta del Role Center: *Pendientes de Procesar*, *Con Errores*, *Importados Exitosamente* |
| **Carpeta SIRADIG** | 50172 | Diálogo de la importación desde carpeta |
| Configuración | `Human Resources Setup` → grupo **SIRADIG** | *Carpeta Importación SIRADIG*: carpeta del servidor por defecto (se recuerda la última usada) |

## Pasos

1. **Verificar el CUIL del empleado.** El sistema busca al empleado por CUIL en **`Nº seguridad social`** y, si no, en **`CIF/NIF`**, con y sin guiones y, como último recurso, comparando sólo dígitos. Si en la base el CUIL vive en `CIF/NIF` ([[cuil-vive-en-cif-nif]]) igual se encuentra.
2. **Importar.** *Importaciones SIRADIG* → **Importar Archivos SIRADIG** (selector de archivos del navegador; admite **varios** `.xml` / `.xml.zip` a la vez). Pregunta *"¿Desea procesar automáticamente las importaciones?"*:
   - **Sí**: importa y procesa en un paso.
   - **No**: sólo registra la importación (estado *Pendiente Procesar*).
   Alternativa avanzada: **Importar desde Carpeta del Servidor** (lee todo el contenido de una carpeta; los `.zip` tienen que llamarse `CUIL_PERIODO_presentacion_NRO.xml.zip`).
3. **Resumen único al final**: "Se importaron N archivo(s) SIRADIG. M archivo(s) con errores" (+ cantidad de deducciones y cargas procesadas y la lista de errores por archivo). Un archivo que falla **no frena** a los demás.
4. **Procesar** lo pendiente: seleccionar la importación → **Procesar Importación** (habilitada sólo en *Pendiente Procesar*). Resultado: "Importación procesada exitosamente. N deducciones, M cargas familiares."
5. **Validar**: en la ficha del empleado, parte *Deducciones Ganancias 4ta Cat.* y *Parientes* (Employee Relatives).
6. **Trazabilidad**: **Ver Registro AFIP WS** abre el registro de interfaz AFIP asociado.

### Estados de una importación

`Pendiente Procesar` → `Procesado Exitosamente` · `Procesado con Advertencias` · `Error en Procesamiento`. **Eliminar** borra la importación seleccionada.

## Errores y advertencias típicos

| Mensaje | Qué hacer |
|---|---|
| "El archivo ya ha sido importado anteriormente" | Esa presentación ya está; no se duplica |
| "El nombre del archivo no cumple el formato esperado CUIL_PERIODO_presentacion_NRO.xml.zip" | Renombrar (sólo aplica a la importación desde carpeta) |
| "No se encontró ningún archivo .xml dentro del ZIP: …" | ZIP vacío o dañado |
| "No se encontró empleado con CUIL: %1. Se buscó en «Nº seguridad social» y en «CIF/NIF»…" | Cargar el CUIL en uno de los dos campos |
| "Código de deducción SIRADIG no válido: %1" / "Deducción tipo %1 no será importada (tipo no soportado)" | El tipo de deducción del XML no está en el enum soportado (19 códigos: cuotas médico-asistenciales, primas de seguro, donaciones, intereses hipotecarios, gastos de sepelio, gastos médicos, personal doméstico, SGR, vehículos de corredores, gastos de representación, indumentaria, alquileres 40% y 10%, seguros mixtos, retiro, cuotapartes, educación, otras…) |

## Lo que la importación **no** hace

Importar un familiar **no alcanza para que deduzca**: el que habilita la deducción es **Fecha alta impuesto** del familiar (el F.572 del empleado); *Fecha inicial*, *Fecha final* y *Fecha baja impuesto* son tres pares de fechas distintos y sólo uno habilita ([[familiar-alta-impuesto]]). En *Employee Relatives*: **Cód. Tipo Ded.** (parámetro `DED_CONYUGE`, `DED_HIJO_MENOR`…), **% Deducción** (**cero no anula la deducción**: se lee como "sin cargar" y aplica el 100%; para excluir hay que usar *Fecha baja impuesto*), **Adic. Obra Social** (1,5% extra por familiar marcado).

## Relacionado

[[Mapa de páginas por menú]] · [[Flujo operativo mensual de liquidación]] · [[Qué es y para qué sirve este sistema]]

## Ver también

[[SIRADIG - importación]] · [[SIRADIG - modelo y parser]] · [[Deducciones de Ganancias y familiares]] · [[Tabla - Importación SIRADIG]] · [[Extensión - Employee Relative]]
