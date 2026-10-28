---
tipo: referencia
tags: [modelo-datos, enums]
fuente: [src/Enums/]
actualizado: 2026-10-04
---

# Enums de liquidación

Los 32 enums de `src/Enums` (50300–50333; **no existen** 50306 ni 50316). Cada sección lleva el nombre real del enum entre paréntesis, su ID, si es `Extensible` y quién lo usa. Los valores se escriben `ordinal = Nombre` (el ordinal es lo que se **guarda en la base**: no renumerar ni reutilizar).

> [!warning] Enums sin referencias
> Tres enums no los usa ningún otro objeto del repo: `Tabla Origen Liq.`, `SIRADIG Código Deducción` y `SIRADIG Parentesco`. Se mantienen declarados (probable material para parseo/importación futuros); no los borres sin revisar datos ni ConfigPackage.

Índice por dominio: [[#Conceptos y cálculo]] · [[#Estados y entidades]] · [[#Liquidación y períodos]] · [[#Tipos de liquidación]] · [[#Atributos y fuentes de datos]] · [[#Ganancias SIRADIG]] · [[#Préstamos]] · [[#Registro de procesos y auditoría]] · [[#Sincronización NAV]].

---

## Conceptos y cálculo

### Tipo Concepto Liq
`Tipo Concepto Liq.` (50300, no extensible). Usado en [[Tabla - Concepto Liquidación]], [[Tabla - Línea Liquidación]], [[Tabla - Variable Sistema Liq]].
| Ord. | Valor | Significado |
|---|---|---|
| 0 | Haber Remunerativo | Suma al neto; aporta a bases remunerativas |
| 1 | Haber No Remunerativo | Suma al neto; fuera de las bases de aportes |
| 2 | Descuento Empleado | Resta del neto |
| 3 | Contribución Patronal | Lado patronal, fuera del neto |
| 4 | Retención | Resta; los de este tipo suman a `YTD_RETENIDO_ANUAL` ([[embargo-cuota-alimentaria-como-retencion]]) |
| 5 | Seguridad Social | Aportes de ley |
| 6 | Informativo | No afecta el neto (puede alimentar acumuladores) |
| *7* | *(libre, quemado)* | Era "Deducción Remunerativa". **No reutilizar**: `Tipo Concepto` está desnormalizado en `Línea Liquidación` y las líneas viejas conservan ese ordinal. Hoy es un Haber Remunerativo con importe negativo |

### Aplica A Liq
`Aplica A Liq.` (50301, no extensible). Usado en [[Tabla - Concepto Liquidación]] (`Aplica A`), [[Tabla - Convenio Colectivo]] (`Tipo Empleado`), [[Tabla - Cód. Estado Empleado]], [[Tabla - Tipo Liquidación]] (`Aplica A`).
0 = Todos (no filtra) · 1 = Tripulante · 2 = Mensualizado · 3 = Jornalizado. El tipo de empleado sale del **convenio** de la persona.

### Función Agregado Liq
`Función Agregado Liq.` (50302, no extensible). Usado en [[Tabla - Fuente Datos Liquidación]].
0 = SUM (Suma) · 1 = COUNT (Cantidad) · 2 = MAX · 3 = MIN · 4 = LOOKUP (Búsqueda directa) · 5 = DIAS_OVERLAP (días solapados del intervalo con la ventana de la liquidación) · 6 = DURACION_INICIO (duración desde el inicio) · 7 = DURACION_AÑO (duración en el año). Las tres últimas usan los campos de fecha de la fuente y `Fin Efectivo`.

### Tabla Origen Liq
`Tabla Origen Liq.` (50303, **Extensible**). **Sin uso**: la tabla de una fuente se elige por `Id. Tabla`. 0 = Línea Descarga · 1 = Diario Abordo Lín. · 2 = Proyecto (Marea) · 3 = Parámetro Vigente.

### Grupo Costo Laboral Liq
`Grupo Costo Laboral Liq.` (50309, no extensible). Usado en [[Tabla - Concepto Liquidación]] y [[Tabla - Línea Liquidación]] para agrupar el costo laboral del empleador.
0 = (vacío) · 1 = Sindical · 2 = Seguridad Social · 3 = Obra Social · 4 = INSSJP · 5 = ART · 6 = SCVO.

### Par CCT Liq
`Par CCT Liq.` (50327, no extensible). Usado en [[Tabla - Concepto Liquidación]] (`Par CCT a Usar`): con qué convenio/categoría se resuelven los parámetros del concepto.
| Ord. | Valor | Significado |
|---|---|---|
| 0 | Entidad | "El del empleado (atributos)": el encuadre con historial. Default |
| *1* | *(libre, quemado)* | Era "El de la asignación al proyecto"; se eliminó el 18/9/2026 junto con `Cód. Convenio`/`Cód. Categoría` de Personal Proyecto. **No reutilizar**: hay fórmulas aplicadas guardadas que lo leyeron |
| 2 | Puesto | "El puesto del empleado (atributos)": **cambia sólo la categoría**, no el convenio (el del oficial sale de la flota del buque). Sin puesto vigente a la fecha, usa el par de la cabecera. La producción se paga por puesto ([[puesto-vs-categoria-cct]]) |

### Rol Franco Liq
`Rol Franco Liq.` (50319, extensible). Usado en [[Tabla - Concepto Liquidación]] (`Rol Franco`) y `Cod50053.GestionFrancos`: marca los conceptos que el ledger FIFO reconoce ([[francos-fifo-ledger]]).
0 = Ninguno · 1 = Devengo (devenga días de franco; se sella con categoría) · 2 = Consumo (paga francos gozados, valuado por lote).

---

## Estados y entidades

### Tipo Estado Empleado
`Tipo Estado Empleado` (50308, extensible). Usado en [[Tabla - Cód. Estado Empleado]] (`Tipo Estado`).
0 = Normal · 1 = Alta · 2 = Baja · 3 = Vacaciones · 4 = Francos. **Alta y Baja** son los motivos de las fases de alta y **no se admiten** en el historial [[Tabla - Estado Empleado]]. `Vacaciones` propone el fin por días LCT. Enfermedad y accidente son *Normal*: se distinguen con la bandera `Promedia Ausencia`.

### Tipo Entidad Estado
`Tipo Entidad Estado` (50317, extensible). Usado en [[Tabla - Estado Empleado]] y en los atributos (`Atributo Entidad Liq.`, `Tipo Atributo Liq.`).
0 = Empleado · 1 = Buque · 2 = Proyecto (Marea) — este último lo usan **sólo los atributos**, no el historial de estados. Es seguro agregarlo porque todo consumidor filtra por `::Empleado`/`::Buque` o descarta con `<> ::Empleado`.

### Ámbito Estado
`Ámbito Estado` (50318, extensible). Usado en [[Tabla - Cód. Estado Empleado]]. 0 = Empleado · 1 = Buque · 2 = Ambos. Qué entidades pueden usar el código.

---

## Liquidación y períodos

### Estado Liq
`Estado Liq.` (50304, no extensible). Usado en [[Tabla - Liquidación]] y [[Tabla - Línea Liquidación]] (replicado).
0 = Borrador (editable, recalculable, borrable; **no bloquea** nada) · 1 = Calculada · 2 = Aprobada · 3 = Contabilizada. Calculada/Aprobada/Contabilizada bloquean cambios en estados, parámetros `En Uso` y vigencias de conceptos.

### Estado Período Liq
`Estado Período Liq.` (50305, no extensible). Usado en [[Tabla - Período Liquidación]]: 0 = Abierto · 1 = Cerrado · 2 = Creado (período que existe pero no se opera; valor nuevo al final para no renumerar los que tienen datos).

### Estado Novedad Liq
`Estado Novedad Liq.` (50315, no extensible). Usado en `Novedad Liquidación` (110038).
0 = Pendiente (no entró en ninguna liquidación, o se recalculó y quedó libre) · 1 = Aplicada (se materializó como [[Tabla - Incidencia Liquidación]] en la liquidación de `No. Liquidación`) · 2 = Anulada (excluida a mano: nunca se aplica, copia ni recurre). Ver [[novedades-pre-liquidacion]].

### Aplica Tipo Liq. Concepto
`Aplica Tipo Liq. Concepto` (50307, **Extensible**). Usado **sólo** por el campo obsoleto `Aplica Tipo Liq.` de [[Tabla - Concepto Liquidación]], reemplazado por `Tipos Liq. Aplicables` (texto multiselección).
0 = Todos (caption en blanco) · 1 = Regular · 2 = Aguinaldo · 3 = Vacaciones · 4 = Liquidación Final · 5 = Reliquidación · 6 = Devengados · 7 = Cierre Marea. Es el viejo enum que el maestro [[Tabla - Tipo Liquidación]] reemplazó.

---

## Tipos de liquidación

### Disparador Tipo Liq
`Disparador Tipo Liq.` (50331, extensible). Usado en [[Tabla - Tipo Liquidación]]. Un solo hecho disparador o ninguno (reemplazó tres banderas que podían contradecirse).
| Ord. | Valor | Significado |
|---|---|---|
| 0 | Ninguno | Corre para todos los que pasen los demás filtros (calendario, estados exigidos, fase de alta): Regular, Vacaciones, Aguinaldo |
| 1 | Arribo ("Arribo de marea") | **Cierre de Marea**: fecha de referencia = arribo; cobertura hasta el arribo; filtros de proyecto/personal miran arribo y desembarco |
| 2 | MareaEnCurso | **Devengados**: sólo proyectos que al cierre del período **todavía no arribaron**; mira la **fecha de arribo, no el Status** del Job (que no se mantiene) |
| 3 | BajaEmpleado | **Liquidación Final**: sólo para quien se fue dentro del período; corre todos los meses y sale sólo para los que corresponde |
`Agrupa por Empleado` e `Incluye Francos Puerto` son ortogonales y siguen siendo booleanos.

### Modo Estado Tipo Liq
`Modo Estado Tipo Liq.` (50332, extensible). Usado en `Estado Tipo Liq.` (110059): 0 = Exige (habilita la liquidación) · 1 = Excluye (la impide).

### Ventana Estado Tipo Liq
`Ventana Estado Tipo Liq.` (50333, extensible). Usado en `Estado Tipo Liq.`, `Cod50018`, `Cod50055`: sobre qué días se busca el estado exigido/excluido.
0 = Cobertura ("Días que cubre la liquidación": la definición de `Liquidación.Cobertura`, **no** el período) · 1 = Periodo (completo) · 2 = MesSiguiente (vacaciones que se pagan por adelantado: el empleado todavía no tiene el estado). Ver [[ventana-liquidacion-es-cobertura]].

---

## Atributos y fuentes de datos

### Tipo Dato Fuente Liq
`Tipo Dato Fuente Liq.` (50324, no extensible). Usado en [[Tabla - Fuente Datos Liquidación]]. 0 = Decimal · 1 = Texto · 2 = Fecha. La fórmula **siempre ve un número**; esto sólo conserva el valor original para auditar e imprimir ("126205 - OSECAC").

### Tipo Dato Atributo Liq
`Tipo Dato Atributo Liq.` (50325, no extensible). Usado en `Tipo Atributo Liq.`/`Atributo Entidad Liq.`: define qué columna se completa y cómo se proyecta a número.
0 = Decimal (valor libre) · 1 = Entero · 2 = Lista (validado contra `Valor Atributo Liq.`; la forma preferida para lo que decide un cálculo: un código validado no se rompe en silencio) · 3 = Texto (llega a la fórmula por Fuente de Datos como bandera 1/0, o COUNT con filtro) · 4 = Fecha (llega como días hasta la fecha de referencia). Ver [[atributos-tipados]].

### Espejo Atributo Liq
`Espejo Atributo Liq.` (50326, no extensible). Usado en `Tipo Atributo Liq.`, `Cod50078.EspejoAtributosLiq`, `Cod50080.ConvenioCategoriaLiq`: maestro del que el atributo copia sus valores.
0 = Ninguno (valores a mano) · 1 = Convenio Colectivo ([[Tabla - Convenio Colectivo]]) · 2 = Categoría CCT ([[Tabla - Categoría CCT]]) · 3 = Puesto (copia el **mismo** maestro de categorías pero es un espejo aparte: el par se resuelve buscando el tipo *por su espejo*, y con dos tipos "Categoría CCT" el `FindFirst` devolvería cualquiera). Categoría paga el sueldo; puesto paga la producción. Agregar un maestro = un valor acá + una rama en `Espejo Atributos Liq.` + sus triggers.

---

## Ganancias SIRADIG

### SIRADIG Código Deducción
`SIRADIG Código Deducción` (50310; sin `Extensible` declarado). **Sin uso.** Códigos AFIP de deducción: 1 Cuotas Médico-Asistenciales · 2 Primas de Seguro (muerte/riesgo de muerte) · 3 Donaciones · 4 Intereses Préstamo Hipotecario · 5 Gastos de Sepelio · 7 Gastos Médicos y Paramédicos · 8 Deducción Personal Doméstico · 9 Aporte Soc. Garantía Recíproca · 10 Vehículos Corredores Viajantes · 11 Gastos Representación · 21 Indumentaria y Equipamiento · 22 Alquiler Inmuebles 40% · 23 Primas Ahorro Seguros Mixtos · 24 Aportes Planes Seguro Retiro · 25 Cuotapartes Fondos Comunes · 32 Gastos de Educación · 33 Alquiler Inmuebles 10% · 34 Alquiler Inmuebles Propietarios · 99 Otras Deducciones. (Los ordinales son los códigos oficiales del formulario; hay huecos: 6, 12–20, 26–31, 35–98.)

### SIRADIG Parentesco
`SIRADIG Parentesco` (50311). **Sin uso.** 1 Cónyuge · 3 Hijo Menor 18 · 30 Hijastro Menor 18 · 31 Hijo Incapacitado · 32 Hijastro Incapacitado · 103 Hijo Mayor 18 hasta 24 (gastos de educación).

### Estado Importación SIRADIG
`Estado Importación SIRADIG` (50312). Usado en [[Tabla - Importación SIRADIG]] y la Cue: 0 = Pendiente Procesar · 1 = Procesado Exitosamente · 2 = Procesado con Advertencias · 3 = Error en Procesamiento.

---

## Préstamos

### Tipo Préstamo Emp
`Tipo Préstamo Emp.` (50313, extensible). Usado en [[Tabla - Préstamo Empleado]]: 0 = Anticipo · 1 = Préstamo.

### Estado Cuota Préstamo
`Estado Cuota Préstamo` (50314, no extensible). Usado en [[Tabla - Cuota Préstamo]]: 0 = Pendiente · 1 = Aplicada (al aprobar la liquidación) · 2 = Anulada.

---

## Registro de procesos y auditoría

Las tablas que los usan (`Registro Proceso Liq.` 110000, `Entrada Registro Liq.` 110001, `Historial Fórmula Concepto` 110002) las documenta el área 110xxx.

### Tipo Proceso Liq
`Tipo Proceso Liq.` (50320, extensible): 0 = Cálculo · 1 = Aprobación · 2 = Reapertura · 3 = Reversión Aprobación · 4 = Eliminación · 5 = Creación · 6 = Importación Novedades.

### Severidad Registro Liq
`Severidad Registro Liq.` (50321, no extensible): 0 = Información · 1 = Advertencia · 2 = Error. **El orden importa**: el resultado de un proceso es la severidad **máxima** de sus entradas, por eso van de menos a más grave.

### Categoría Registro Liq
`Categoría Registro Liq.` (50322, extensible): 0 General · 1 Fórmula · 2 Parámetro · 3 Orden Cálculo · 4 Novedad · 5 Incidencia · 6 Préstamo · 7 Estado Empleado · 8 Franco · 9 Grossing Up · 10 Estado (cambio de estado).

### Tipo Cambio Fórmula
`Tipo Cambio Fórmula` (50323, no extensible). Usado en el historial de fórmulas ([[Tabla - Concepto Liquidación]] lo alimenta en insert/modify/delete): 0 = Alta · 1 = Modificación · 2 = Eliminación · 3 = Formato (reescritura canónica de la **misma** fórmula: espacios y saltos de línea, no lo que calcula; va aparte para no perder entre ruido la pregunta "quién tocó este número").

---

## Sincronización NAV

Tablas de staging y control en 110xxx (otro agente). Ver [[transporte-ws-sincronizacion]], [[sincronizacion-valores-dimension]].

### Entidad Sinc NAV
`Entidad Sinc NAV` (50328, extensible): 0 Empleado · 1 Proyecto (Marea) · 2 Descarga Cabecera · 3 Descarga Línea · 4 Valor Dimension · 5 Informe Cap Cabecera · 6 Informe Cap Línea · 7 Dia Abordo Cabecera · 8 Dia Abordo Línea.
> [!warning] El ordinal es identidad, no orden
> El orden de proceso está a mano en `Sinc NAV Liq.`.`ProcesarTodo` y **Valor Dimension va primero** aunque su ordinal sea 4: un valor de dimensión debe existir antes que el proyecto que lo usa, y el proyecto antes que su descarga. El ordinal se guarda en `Ctrl Sinc NAV.Entidad` y en el script T-SQL (`WHERE Entidad = 0..4`): renumerar rompe filas de control y marcas de agua.

### Estado Sinc NAV
`Estado Sinc NAV` (50329, extensible): 0 Pendiente (único estado que el proceso vuelve a mirar solo) · 1 Procesado · 2 Error (requiere reprocesar explícito, para que nada se reintente en silencio una semana) · 3 Omitido.

### Transporte Sinc NAV
`Transporte Sinc NAV` (50330, extensible): 0 = SQL (linked server) — necesita linked server, detecta cambios por rowversion y **no detecta bajas** · 1 = Web Services (OData) — sin nada del lado SQL pero pide un service tier con NavUserPassword (el `HttpClient` de AL no habla NTLM, ver [[nav-odata-ntlm]]); detecta cambios y bajas por el Change Log de NAV. Los dos llenan las **mismas** tablas de staging.

---

Ver también [[Índice Modelo de datos (60xxx)]].
