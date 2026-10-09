---
tipo: tabla
tags: [modelo-datos, ganancias, integraciones]
fuente: [src/Tables/Tab60026.ImportacionSIRADIG.al]
actualizado: 2026-10-04
---

# Tabla - Importación SIRADIG (60026)

## Propósito
Registro de cada **archivo SIRADIG** (declaración de deducciones de Ganancias del empleado ante AFIP) importado: qué CUIL/período/presentación, con qué estado y qué resultado. SIRADIG *no* es el libro de sueldos digital (SITRADIB): ver [[firma-recibos-digitales]].

## PK e índices
PK `No.` (autoincremental, clustered); K2 `CUIL Empleado`, `Período`, `Nro. Presentación`; K3 `Estado`, `Fecha Importación`.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No.` (1) | Integer autoinc. | |
| `CUIL Empleado` (2) | Code[20] | NotBlank. El CUIL vive en `CIF_NIF` de la `$ext` del empleado, no en `Social Security No.` ([[cuil-vive-en-cif-nif]]) |
| `No. Empleado` (3) | → `Employee."No."` | Se resuelve a partir del CUIL |
| `Período` (4) | Integer | Año fiscal |
| `Nro. Presentación` (5), `Fecha Presentación` (6) | | La presentación vigente es la de mayor número |
| `Archivo Origen` (7) | Text[250] | |
| `Fecha Importación` (8), `Usuario Importación` (9) | DateTime / Code[50] | No editables |
| `Estado` (10) | Enum [[Enums de liquidación#Estado Importación SIRADIG]] | InitValue `Pendiente Procesar` |
| `Deducciones Importadas` (11), `Cargas Familia Importadas` (12) | Integer | Contadores |
| `Mensajes Error` (13) | Text[500] | |
| `AFIP Register Entry No.` (14) | Integer → `AFIP Interface Register."Entry no."` | Vínculo a la auditoría de interfaces AFIP (tabla de la dependencia *Final Version Customization Extension – Tables Only*, no de esta app) |

## TableRelations
`No. Empleado` → `Employee`; `AFIP Register Entry No.` → `AFIP Interface Register` (dependencia externa).

## Triggers
Ninguno.

## Quién la lee / escribe
`Cod50022.ParserSiradigXml` (parseo), `Cod50046.OrquestadorSiradig`, `Cod50048.ProcesadorImportacionSiradig` (genera [[Tabla - Ded. Ganancias Empleado]] y cargas de familia), `Cod50058.ImportadorArchivoSiradigSubido`, `Cod50059.AuditoriaAfipInterface`. Páginas: `Pag50171 Importaciones Siradig`, `Pag50173 Cue Siradig`. Los enums `SIRADIG Código Deducción` y `SIRADIG Parentesco` están declarados pero ningún objeto los referencia hoy (ver [[Enums de liquidación]]).

## Vigencias
Por año fiscal + número de presentación.

## Trampas conocidas
- Importar no basta: un familiar cargado no deduce sin sus tres pares de fechas ([[familiar-alta-impuesto]]).
- Detalle de la interfaz en `04 Integraciones` (SIRADIG/AFIP).
