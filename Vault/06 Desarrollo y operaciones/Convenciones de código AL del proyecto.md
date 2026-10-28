---
tipo: guia
tags: [desarrollo, al, convenciones, estilo]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod110032.ProgresoLiq.al, src/Codeunits/Cod50061.GestionNovedadesLiq.al, src/Codeunits/Cod50055.GestionTipoLiq.al, src/Codeunits/Cod110038.NetoGarantizadoUpgrade.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Pages/Pag50108.Parametros.al, src/PermissionSets/PermSet50300.LiqPescaAdmin.al, Translations/Liquidación Sueldos Pesca.g.xlf]
actualizado: 2026-10-04
---

# Convenciones de código AL del proyecto

Lo que se observa leyendo `src/` (más de 20 archivos revisados, entre ellos Cod50014, 50016, 50055, 50061, 110032, 110038, 110049 y las tablas/páginas base). Son convenciones **de hecho**; donde hay desvíos se dice.

## Namespace

- **Todos** los archivos AL de `src/` abren con `namespace UAS.Payroll;` (322 archivos).
- **Única excepción**: `src/PageExtensions/Pag-Ext50356.EmpFamilyExt.al` usa `namespace Payroll.Payroll;`, su archivo no sigue el patrón `PagExt`, declara `pageextension 50357` (no 50356) y su nombre `EmpFamilyExt` va sin comillas ni estilo de caption. Es un resto de otra época: corregir al tocarlo.
- Los `using` se agregan sólo para lo que hace falta de la base (`Microsoft.HumanResources.Employee`, `Microsoft.Projects.Project.Job`, `System.IO`, `System.Utilities`, `System.Upgrade`…).

## Nombre de archivo

`<Prefijo><ID>.<NombreEnPascalCase>.al`, sin espacios ni tildes en el archivo:

| Objeto | Prefijo | Ejemplo |
|---|---|---|
| table | `Tab` | `Tab60012.LineaLiquidacion.al` |
| tableextension | `TabExt` | `TabExt52001.HRSetupLiqExt.al` |
| page | `Pag` | `Pag50108.Parametros.al` |
| pageextension | `PagExt` | `PagExt50353.HRSetupLiqExt.al` |
| codeunit | `Cod` | `Cod50014.MotorLiquidacion.al` |
| report | `Rep` | `Rep50041.ReciboDeSueldo.al` (+ `.rdl`/`.rdlc`) |
| enum | `Enum` | `Enum50300.TipoConceptoLiq.al` |
| permissionset | `PermSet` | `PermSet50300.LiqPescaAdmin.al` |
| profile | `Prof` | `Prof50300.PayrollManager.al` |
| tests | `Cod` en `test/Codeunits/` | `Cod50021.TestEvaluadorFormula.al` |

El **nombre del objeto** dentro del AL sí lleva tildes y espacios: `codeunit 50014 "Motor Liquidación"`. Hay archivos con el ID desfasado respecto del declarado; ver [[Rangos de IDs y licencia]]. Sufijos de nombre habituales: `Liq.` / `Liq` (de «liquidación»), `Sub` (subpágina), `Buffer` (tabla temporal), `Ext` (extensiones), `Upgrade`/`Install`.

## Idioma y captions

- **Español rioplatense** en captions, mensajes, comentarios y nombres de campo (`Cód. Concepto`, `Vigencia Desde`). Los mensajes usan voseo imperativo («Corré el Control…», «Usá "Recalcular en cadena"…»).
- `Caption` explícito en cada tabla, campo, página y acción; `ToolTip` largo y explicativo en lo que no es obvio (`Pag50108.Parametros.al`). `ApplicationArea = All` en cada control (1.698 apariciones), `UsageCategory` sólo en las páginas de entrada.
- `DataClassification = CustomerContent` en cada campo (887 líneas).
- `Comment = '%1=…'` en las `Label` con parámetros, para el traductor (166 casos).
- Identificadores en español (`Código`, `Descripción`, `Fórmula`) **con tildes** también en nombres de campo. Esto afecta a SQL: BC reemplaza `.` por `_` y las consultas usan comodines (`Cód_ Concepto`, `L_nea Liquidaci_n`).

## Traducciones

`app.json` declara `TranslationFile`. En `Translations/`:

- `Liquidación Sueldos Pesca.g.xlf` — generado por el compilador (3.458 `trans-unit`, idioma fuente `es-ES`); **no editar a mano**.
- `Liquidación Sueldos Pesca.g.es-ES.xlf` — 802 unidades con `target` en inglés (`Categoría CCT` → `CCT Category`) aunque el nombre dice `es-ES`: el `target-language` del archivo es `en-EN`. Está atrasado respecto del `.g.xlf` (802 de 3.458) y es lo que dispara `AL1029`. No hay otro idioma.

## Nomenclatura interna

- **Globales de instancia con prefijo `F`**: `FVentana`, `FIncidencias`, `FIteracionGU`, `FAdvertencias`.
- **Labels con prefijo por uso**: `Err…` (para `Error`), `Msg…` (para `Message`), `Txt…` (texto de UI), `Dlg…` (diálogo), `Aviso…`. Los textos que NO se traducen llevan `Locked = true` (`'NETO_GARANT'`, `'TRAMO(%1)'`, 18 casos).
- **Todo texto de usuario va en `Label`**, no literal (584 `Label` en 128 archivos). Sigue habiendo literales sueltos, p. ej. `Error('El archivo ZIP no existe: %1', RutaZip)` en `Cod50047.GestorArchivosSiradig.al`; al tocar esos sitios, pasarlos a `Label`.
- Procedimientos en PascalCase (`SembrarPunteros`, `AplicarEnLiquidacion`); `local procedure` para lo privado. Booleanos con `Es…`/`Hay…`.
- Códigos de dominio en MAYÚSCULAS con guion bajo: `REGULAR`, `CIERRE_MAREA`, `BASE_IG4`, `NETO_GARANT`. Ver [[system-variables-conventions]].

## Comentarios y documentación

Es la parte más característica: **el comentario explica el por qué, con el incidente que lo motivó**, no el qué.

- `/// <summary>` + `/// <remarks>` en codeunits y procedimientos públicos. Las remarks cuentan la trampa, el caso medido (p. ej. «el 90016 en enero de 2026 daba 50.381.512,84 contra los 24.208.252,13 de Meta4») y el efecto de no hacerlo.
- Bloques `//` largos antes de la línea delicada, en mayúsculas para la frase clave («EL RECIBO DE VACACIONES VA EN EL MES EN QUE LAS VACACIONES EMPIEZAN»).
- Fechas absolutas en los comentarios (`23/9/2026`, `22/9/2026`), nunca «ayer» o «recientemente».
- Código retirado: se conserva la codeunit **vacía con su explicación** si un tag de upgrade ya corrió (`Cod50082`); no se borra. Ver [[Install y Upgrade - qué siembra cada uno]].
- Hay archivos que mezclan comentarios en inglés (`// Seeds the Tipo Liquidación master…`, `// Pass 1: syntax only`); no es una norma, es herencia. Lo nuevo va en español.

## Error vs Message vs Confirm

| Uso | Dónde | Cantidad |
|---|---|---|
| `Error(Label, …)` | validaciones y abortos en motor, tablas, codeunits | 263 en 74 archivos |
| `Message(...)` | resultado de acciones de página, avisos tolerables (p. ej. variable desconocida al validar fórmula: avisa, no impide guardar) | 148 en 63 archivos |
| `Confirm(...)` | antes de borrar/recalcular en masa | 38 en 21 archivos |

No se usa `ErrorInfo` ni `#pragma` (0 apariciones). Los avisos del cálculo no se muestran con `Message` sino que se acumulan (`FAdvertencias`) y salen en el informe `Avisos del Cálculo` al final de un proceso largo ([[report-sin-layout-compila]]).

## Transacciones y `Commit`

Sólo 10 `Commit()` en 8 archivos, **todos deliberados** (motor, Siradig, sincronización NAV, registro de procesos, alta de atributos, dos informes masivos, una subpágina):

- `Cod50014.LiquidarConRegistro` hace `Commit()` **antes** de `Ejecutor.Run(Liq)`: el valor de retorno de `Codeunit.Run` sólo se puede usar sin escrituras pendientes, y cada liquidación queda en su propia transacción para que una que falla no arrastre al lote. Regla: [[codeunit-run-necesita-commit]].
- Se usa `Codeunit.Run`, **no** `[TryFunction]`, para todo lo que escribe (16 `TryFunction`, ninguna debe escribir).
- Tras un `Run` fallido se **relee** el registro (`if Liq.Get(...) then;`) porque lo de memoria ya no existe en la base.
- Los lotes marcan resultado y siguen: «199 liquidaciones correctas no deberían perderse por una que falla»; el llamador **debe mirar** el retorno.

## Tablas temporales y buffers

- Tablas puramente de trabajo (`*Buffer`, 11 con `TableType = Temporary`) y variables `Record "X" temporary` (116 líneas, 33 archivos) para acumular en memoria (`TempAcum`, `Incidencia` en el motor).
- Páginas sobre temporal: `SourceTableTemporary = true` (25 páginas). Permission sets les dan `RIMD` aun al rol de lectura, porque construir la vista escribe en memoria.
- Trampas: [[clear-no-vacia-temporary]] (CLEAR no vacía filas de un `Record` temporal) y [[setselectionfilter-tabla-temporal]] (la multiselección se pierde sobre otra variable temporal).

## Patrones frecuentes

- **Caché en `Dictionary of [Text, Decimal]`** (222 usos) y `List of […]` (192): contexto de cálculo, versiones de concepto, fracciones. Reiniciar por liquidación (`ReiniciarCachesLiquidacion`).
- **Idempotencia**: los sembradores (`Sembrar`, `Agregar`) sólo agregan lo que falta; los upgrades convergentes (`ExigirEstado`, `AplicarA`) llevan la configuración al valor del producto. Ver [[Install y Upgrade - qué siembra cada uno]].
- **Dos pasadas** al modificar un conjunto filtrado: primero juntar claves en `List`, luego actuar ([[bucle-modifica-campo-filtrado]]).
- **`SetLoadFields`** (30 usos) para lecturas parciales; **`SetCurrentKey` + `SetRange` + `FindSet`** explícitos. Nunca confiar en `Get` con menos argumentos que la PK ([[get-con-menos-argumentos]]).
- **Sin cortocircuito**: guardas `ContainsKey`/`Get` en sentencias separadas ([[al-sin-cortocircuito]]).
- **`xRec` no confiable** en `OnModify` si el `Modify` vino de un control add-in ([[xrec-no-confiable-con-addin]]).
- **`SingleInstance` con cuidado**: 9 usos; el estado sobrevive a una corrida abortada ([[progreso-singleinstance-sucio]]).
- **Eventos**: sólo 2 `[EventSubscriber]` (`Job.OnBeforeUpdateJobTaskDimension`, `Dimension Value.OnAfterRenameEvent`); **no se publican eventos propios** (0 `IntegrationEvent`/`BusinessEvent`). La extensibilidad es por configuración, no por eventos ([[avoid-tables-principle]]).
- **`Access = Public`** explícito en 20 objetos (los codeunits `110028`–`110033` y similares) y `Access = Internal` en 7; el resto usa el valor por defecto. No hay criterio escrito: sin verificar si existe consumidor externo.
- **Tests**: `TestPermissions = Disabled`, `Assert` local propio ([[Tests automatizados]]).
- **`Format` con expresión** y **informes sin layout** se prueban ejecutando ([[format-no-se-valida-al-compilar]]).
- **Campos de tabla ajena**: `tableextension` con id 52000+ ([[campos-extension-tabla-ext]]).

## Principio rector

«El motor se configura, no se codea»: preferir **Parámetros / Fuente de Datos / Atributos tipados** a tablas o fórmulas escritas en AL ([[avoid-tables-principle]], [[un-valor-una-fuente]]). Un valor, una fuente.

## Permisos

Cada objeto nuevo de datos debe sumarse a los tres permission sets ([[Permission sets de la extensión]]); una tabla que falta produce errores de permisos que se confunden con el límite de licencia ([[Rangos de IDs y licencia]]).
