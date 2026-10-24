---
tipo: codeunit
tags: [motor, formulas, editor, control-addin, intellisense]
fuente: [src/ControlAddIns/EditorFormulaLiq.al, src/ControlAddIns/EditorFormula/editorFormula.js, src/ControlAddIns/EditorFormula/startup.js, src/ControlAddIns/EditorFormula/editorFormula.css, src/Codeunits/Cod50060.CatalogoVariablesLiq.al, src/Pages/Pag50145.ConceptoLiqCard.al, src/Pages/Pag50139.AsistenteFormulaLiq.al]
actualizado: 2026-10-08
---

# Editor de fórmulas (control add-in)

El **editor con IntelliSense** es el control add-in `Editor Fórmula Liq.` (`src/ControlAddIns/`). Se usa en
la **ficha del concepto** (`Pag50145`) y en el **asistente de fórmulas** (`Pag50139`) para editar la
**Fórmula** y la **Condición** con resaltado de sintaxis, autocompletado, ayuda de firma y diagnóstico en
vivo. La ficha conserva siempre una vía alternativa: **Ver texto plano** (campos comunes), visible por
defecto hasta que el editor avisa que arrancó.

## Reparto cliente / servidor

```mermaid
sequenceDiagram
    participant JS as editorFormula.js (navegador)
    participant AL as Página AL (Pag50145 / Pag50139)
    participant CAT as Catálogo Variables Liq. (Cod50064)
    JS->>AL: ControlAddInReady() (tras init exitoso)
    AL->>CAT: BuildCatalogoCompletoJson
    AL->>JS: SetCatalogo(json)
    AL->>JS: SetValores(Fórmula, Condición)
    AL->>JS: SetDiagnostico(campo) (evalúa en servidor)
    loop mientras escribe
        JS->>JS: render + autocompletado (100 % en el cliente)
        JS->>AL: OnTextoCambiado(campo, texto) (debounce 500 ms; inmediato al perder foco)
        AL->>AL: GuardarTextoDeEditor + EnviarDiagnostico
        AL->>JS: SetDiagnostico(json)
    end
```

- El **catálogo completo** (funciones, operadores, variables, conceptos) se empuja **una vez** con `SetCatalogo`; el filtrado del autocompletado ocurre **entero en el navegador**: una consulta por tecla agregaría cientos de ms al camino crítico del tipeo.
- Al servidor sólo vuelve el **texto**, con *debounce* de 500 ms, para evaluarlo de verdad y devolver el diagnóstico.

API del control (`EditorFormulaLiq.al`): eventos `ControlAddInReady()`, `OnTextoCambiado(Campo; Texto)` (`Campo` = `'formula'` | `'condicion'`); procedimientos `SetCatalogo(CatalogoJson)`, `SetValores(Formula, Condicion)` (no pisa el campo en edición), `SetDiagnostico(DiagnosticoJson)` (`{campo, estado, mensaje, valor}`). Tamaño: `RequestedWidth` 900 (mínimo 300) × `RequestedHeight` 500 (mínimo 400), con estiramiento horizontal y alto fijo; el `body` del add-in tiene `overflow: hidden` para que el popup no genere una segunda barra de scroll.

## Catálogo (`Catálogo Variables Liq.`, Cod50064)

`CargarCatalogo` arma el listado de lo que una fórmula puede nombrar **leyendo las tablas reales** (nunca una lista escrita a mano):

1. Constantes inyectadas por el motor: `COD_ZONA`, `CANT_INCIDENCIA`, `ES_JUBILADO`, `ES_GROSSING_UP`, `NETO_GARANTIZADO`, `COMPLEMENTO_GU`, `NETO_GARANTIZADO_ESFCY`.
2. Parámetros con `Nombre Variable` (valor vigente para el contexto recibido, resuelto con la misma cascada) **y su `<VAR>_ESFCY`**.
3. Variables de sistema activas, fuentes de datos activas y tipos de atributo con nombre: valor **0** (necesitan una corrida real; el asistente los completa con *Cargar contexto*).
4. Acumuladores (sin filtro de vigencia: es un diccionario de **nombres**, y la pantalla *Variables del cálculo* resuelve liquidaciones viejas).

Más los **conceptos** (`@`/`#`, con la **última** descripción de cada código), las **funciones** y **operadores** (`Inicializar`/`DefFunc`, espejo del `case` del evaluador) y, por variable de lista, los **valores de atributo** (`codigo`, `desc`, `padre`) para sugerir códigos tras `=`/`<>`. Los valores del catálogo son **orientativos**.

El diagnóstico evalúa en **modo validación** contra ese contexto: da un resultado orientativo (`= valor`) o el error del evaluador. Un error de *ejecución* que dependa del valor real no aparece.

## Qué hace el cliente (`editorFormula.js`)

| Función | Detalle |
|---|---|
| **Tokenizador espejo** | replica `NextTok` del evaluador (coma = separador, decimal con punto, letras del español, `@`/`#`, comillas con `''`). Si se toca el de AL hay que tocar éste (y `Formateador Fórmula Liq.`) |
| **Resaltado** | capa `.uas-hl` bajo un `textarea` transparente que coincide carácter por carácter; clases por tipo (`var-parametro`, `var-sistema`, `var-fuente-datos`, `var-atributo`, `var-acumulador`, `concepto`, `funcion`, `operador`, `cadena`, `error`) |
| **Errores en rojo** | comilla sin cerrar, carácter no válido, **función desconocida** (si el nombre va seguido de `(`), **variable desconocida**, **concepto inexistente** en `@`/`#`, y **variable configurada en minúsculas** (el motor pasa la fórmula a mayúsculas y no la encontraría nunca) |
| **Autocompletado** | `Ctrl+Espacio` o al tipear; prioriza prefijo > contiene > descripción; máximo 120 ítems; `Tab`/`Enter` aceptan, `Esc` cierra (con `stopPropagation`: si `Esc` llegara a BC cerraría la página modal); `@`/`#` sugieren conceptos ("reevalúa" / "ya calculado"); tras `variable = ` o `<>` sugiere los **códigos del atributo de lista** entre comillas |
| **Ayuda de firma** | argumento actual subrayado (`IF(`**`condición`**`, …)`), pila de llamadas |
| **Auto-cierre** | `(` inserta `()`, `'` inserta `''`; `)` y `'` "pasan por encima" del que ya está |
| **Resaltado de paréntesis** | marca el `(` y `)` del grupo más interno que contiene el cursor (sólo con foco) |
| **Ver nombres** | vista de **sólo lectura** que reemplaza el campo por la misma fórmula con la descripción de cada concepto referenciado por `@`/`#` y de cada variable (parámetro, sistema, fuente de datos, atributo) que tenga descripción cargada |
| **Tema** | detecta claro/oscuro del host (`fondoDelHost`, `esOscuro`) y se adapta |
| **Auto-altura** | el `textarea` crece; quien scrollea es el contenedor (una sola barra de scroll) |

Campos: *Fórmula* (264 px de alto: ~13 renglones, lo que ocupa la más larga ya formateada) y *Condición (opcional)* (72 px).

## Robustez del add-in

El control a veces queda **en blanco** (BC lo recrea o corre el `startup` antes de que exista el `div controlAddIn` o el módulo `UASEditorFormula`). Defensas:

- `startup.js`: **reintenta** cada 100 ms hasta 60 veces (~6 s); si no, escribe en el contenedor qué faltó y manda a recargar con `Ctrl+F5` (el navegador cachea los archivos del control) o a usar **Ver texto plano**; captura excepciones de `init` con el motivo. Sólo después de un `init` exitoso invoca `ControlAddInReady`.
- `vigilar()` (en `editorFormula.js`): cada **2 s** comprueba que la raíz siga en el DOM; si BC la sacó, **reconstruye** y reenvía `ControlAddInReady` para que AL reenvíe catálogo y valores (el trigger de AL es **idempotente**). Tope de **20** reconstrucciones para no entrar en un ciclo infinito.
- `setValores` no pisa el campo con foco ni una fórmula **equivalente** (mismos tokens sin espacios): el guardado refresca la ficha y devuelve el texto formateado; reemplazar movería el cursor y parecería que "no guarda".

> [!warning] Una tecla que el popup consume en `keydown` no se reprocesa en `keyup`
> Las flechas no movían la lista de sugerencias. Hacían las **dos** cosas: el `keydown` corría `mover(1)` y marcaba la fila, y al soltar la tecla el `keyup` —que re-renderiza cuando el cursor se movió— llamaba a `actualizarPopup`, que recalcula las mismas sugerencias y termina en `abrirPopup`, donde hay un **`pop.sel = 0`**. La selección volvía a la primera fila en cada pulsación: se movía y rebotaba, y desde afuera parecía que la lista no respondía.
>
> El guard va sobre `ArrowDown`/`ArrowUp`/`PageDown`/`PageUp` **sólo con el popup abierto**. Izquierda y derecha quedan afuera a propósito: el `keydown` no las intercepta, mueven el cursor de verdad y el popup tiene que recalcularse con el prefijo nuevo. Arreglado el 8/10/2026.
>
> Vale como regla general del add-in: si una tecla se consume con `preventDefault` + `stopPropagation`, el `keyup` de esa misma tecla tiene que salir temprano. Los dos manejadores miran el mismo evento y el segundo no sabe que el primero ya actuó.

## Cómo guarda (`GuardarTextoDeEditor`)

El add-in guarda con **asignación directa + `Modify(true)`**, sin `Validate`, así que **no corre el `OnValidate` de los campos** (formateo y validación de sintaxis). Por eso la página llama al **formateador** ella misma y el **diagnóstico en vivo** hace de validación (un error duro ahí reventaría la ficha a mitad de cada fórmula). Si el registro aún no existe (alta recién empezada) no se hace `Modify`. El historial de fórmulas **no puede confiar en `xRec`** en este camino: lee la versión almacenada ([[xrec-no-confiable-con-addin]], [[Versionado de conceptos y fórmulas]]).

## Mantenimiento: dónde tocar al cambiar el lenguaje

| Cambio | Archivos |
|---|---|
| Función nueva | `CallFunction` (evaluador), `Catálogo Variables Liq.`.`Inicializar`, `IsFormulaKeyword` (motor) |
| Regla léxica nueva | `NextTok` (AL), `Tokenizar` del formateador (AL), `tokenizar` (JS) |
| Operador/palabra reservada | los tres tokenizadores + `DefOp` |
| Origen de variable nuevo | `CargarCatalogo`, `BuildKnownVarsCtx` (validación de la ficha), `BuildContextParaValidacion` |

> [!note] Comentarios desactualizados en el JS
> La cabecera dice *"el motor distingue mayúsculas: 'basico' NO es 'BASICO', y 'and' no es el operador
> AND"*. **Ya no**: el evaluador pasa la fórmula a mayúsculas (los propios comentarios de `clasificar`
> lo reconocen). Está en [[Divergencias entre documentación vieja y código]].

## Pruebas

`test/editorFormula.atributos.test.cjs` (Node: ejecuta el JS en un `vm` y prueba las sugerencias de códigos de atributo tras `=`/`<>`). Los tokenizadores de AL tienen sus pruebas en `Test Evaluador Fórmula` y `Test Formateador Fórmula`.

## Relacionado

[[Evaluador de fórmulas - sintaxis]] · [[Evaluador de fórmulas - funciones]] · [[Formateador de fórmulas]] · [[atributo-comparar-por-codigo]]

## Menú contextual: abrir la ficha (13/10/2026)
Botón derecho sobre un token que sea **concepto** (`@`/`#`), **parámetro**, **fuente de datos**, **variable de sistema** o **atributo** abre su ficha. Sobre cualquier otra cosa no se intercepta, para conservar el menú del navegador (copiar/pegar).
- **JS** (`editorFormula.js`): `destinoDeFicha` decide el tipo con el mismo `clasificar` del resaltado, y el menú dispara el evento `OnAbrirFicha(Tipo; Nombre)` del control add-in. El tipo es el del catálogo (`Parámetro`, `Fuente Datos`, `Sistema`, `Atributo`) o `concepto`.
- **AL**: `Cod110071 "Abrir Ficha Fórmula Liq."` resuelve nombre → registro y hace `Page.Run` (no modal, para poder comparar fichas). Lo llaman `Pag50139` y `Pag50145`. Concepto: versión vigente a `WorkDate`, o la última si no hay. Parámetro: por `Nombre Variable`, quitando `_ESFCY`. Atributo: quitando `_ULT_MAREA`. Variables de sistema que inyecta el motor (sin fila) avisan que no tienen ficha.
- Un **acumulador** se abre como concepto (`Es Acumulador`): el JS lo manda con tipo `concepto`. Agregado el 14/10/2026, faltaba.
- **Hay que republicar** (cambia el control add-in) y recargar con Ctrl+F5: el navegador cachea los archivos del control.
