---
tipo: codeunit
tags: [motor, formulas, formateador]
fuente: [src/Codeunits/Cod110033.FormateadorFormulaLiq.al, test/Codeunits/Cod110034.TestFormateadorFormula.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Pages/Pag50145.ConceptoLiqCard.al]
actualizado: 2026-10-08
---

# Formateador de fórmulas

`Formateador Fórmula Liq.` (Cod110033) da **forma canónica** al texto de una fórmula o condición: una sola
manera de escribir lo mismo. No es un embellecedor opcional: **es la forma en que las fórmulas se
guardan**. Antes el campo las aplanaba a una línea reemplazando saltos por espacios; ahora se guardan en
varias líneas con sangría.

## Por qué es canónico

El [[Versionado de conceptos y fórmulas|historial de fórmulas]] guarda "Fórmula Anterior" y "Fórmula Nueva" enteras en cada cambio. Con todo en una línea, comparar dos versiones de 200 caracteres es buscar la diferencia a ojo. Con una sola forma posible, dos textos que dicen lo mismo son **idénticos**: el historial ni registra la entrada (compara textos) y lo que aparece en un *diff* es siempre un cambio real.

## Garantía: no cambia lo que la fórmula calcula

`Formatear(Texto)`:

1. Texto vacío → vacío.
2. `Tokenizar` con las **mismas reglas que `NextTok` del evaluador** (la coma nunca es decimal; `@`/`#` arrancan identificador; letras del español). Si hay algo que no reconoce (carácter raro, comilla sin cerrar) devuelve el **original intacto**: suele ser una fórmula a medio escribir y reordenarla sería pelearse con quien la escribe.
3. `TryEmitir` (envuelto en `[TryFunction]`: corre **con cada tecla** del editor sobre texto incompleto; un error ahí mostraría un diálogo por letra).
4. **Vuelve a tokenizar el resultado y compara la secuencia con la original** (`MismaSecuencia`); si difiere en algo que no sea espacio en blanco, descarta el trabajo y devuelve el original. «Un formateador que rompe una fórmula sería mucho peor que uno que a veces no formatea.»

`Reconoce(Texto)` dice si el formateador **entiende** el texto: desde afuera "no cambió" es ambiguo (ya estaba canónico **o** no pudo leerlo) y quien avisa al usuario necesita distinguirlas.

## Reglas de formato

- **Ancho máximo 96**, **sangría 4**. Cada grupo entre paréntesis se escribe en una línea **si entra**; si no, se abre, **un argumento por línea** y se cierra. La decisión se toma mirando si el grupo **entero** entra en lo que queda de línea (`LargoGrupo`): un grupo chico dentro de uno roto se escribe de un tirón, sin "escalera de una palabra por línea".
- **`CASE` se corta de a pares**: la coma después de la **condición** no corta y la coma después del **valor** sí (se ve la escala entera de un vistazo).
- **Cadenas largas de `+`/`-`** (la base imponible de Ganancias: ~15 términos): se corta **antes del operador** (cada renglón dice qué se suma o resta antes de decir qué) sólo si lo que sigue —operador + término— no entra. `*` y `/` **no** cortan (encadenan factores de una unidad).
- **Menos unario pegado** a lo que niega (`-SUELDO`); espacios alrededor de operadores binarios, `AND`/`OR`/`NOT` y comparadores; nombre + `(` = llamada, pegada.
- **No cambia mayúsculas ni números**: los tokens se conservan tal cual (el evaluador pasa todo a mayúsculas al evaluar).
- Dentro de la fórmula se usan saltos **CRLF** (desde el 8/10/2026; antes LF solo). El tokenizador del evaluador y el del editor tratan el CR y el LF como espacio, así que el cambio no toca ningún cálculo.

> [!warning] Con LF solo la sangría no se veía
> El formateador cortaba e indentaba bien, pero **el control multilínea no rompe con un LF suelto**: la
> fórmula aparecía de corrido y la sangría como una tira de espacios en el medio, con toda la pinta de
> que el formateador no hacía nada. Y la base estaba **mezclada** —16 fórmulas en CRLF contra 48 en LF—,
> así que dos textos que decían lo mismo no eran iguales y el historial registraba una entrada con el
> *diff* completo cada vez que se reguardaba una fórmula sin tocarla: justo lo que la forma canónica
> existe para evitar. Al unificar hubo que migrar las 64 **por SQL**, sin pasar por el `OnValidate`,
> para no generar esas entradas falsas.

> [!warning] El campo tiene 2.048 caracteres
> `Fórmula` y `Condición` son `Text[2048]` y la forma canónica **agrega saltos y sangría** — con CRLF,
> un carácter más por línea que antes. `Formatear` ahora **devuelve el texto original** si el resultado
> pasa de 2.048 (`LargoMaximoCampo`): formatear corre dentro del `OnValidate` y con **cada tecla** del
> editor, así que pasarse abortaría la validación con un error por letra. Medido al migrar: la más larga
> es el 2498 con 1.058 caracteres, que en CRLF queda en 1.085; ninguna se acerca al límite.

## Dónde se aplica

| Camino | Cuándo |
|---|---|
| `Concepto Liquidación.Fórmula` / `Condición` `OnValidate` | primera cosa que hace el trigger, antes de validar sintaxis |
| `Pag50145.GuardarTextoDeEditor` (editor con IntelliSense) | el editor guarda por asignación directa (sin `Validate`), así que formatea acá. **No** devuelve el texto formateado al editor mientras se escribe (reacomodar renglones bajo el cursor es molesto); se ve formateado al reabrir. El editor además ignora `SetValores` cuyo texto sea la misma fórmula con otro espacio en blanco (`mismaFormula`) |
| Acción **Formatear** de la ficha (`Pag50145`) | formatea la fórmula y la condición del concepto; guarda con `Modify(false)` y deja un registro tipo `Formato` en el historial. Corre **siempre** el control de sintaxis: avisa *"Ojo: este concepto NO se va a poder calcular"* (y formatea igual), *"ya está en forma canónica"* o *"La fórmula quedó como estaba: tiene algo que el formateador no reconoce…"* |
| Acción **Formatear todas las fórmulas** de la lista (`Pag50107`) | pensada para correrse **una sola vez** tras actualizar la extensión: recorre **todas las versiones de todos los conceptos**, con confirmación; `Modify(false)` + `RegistrarFormato`; informa cuántas cambió. No muestra diagnósticos de sintaxis |

## Pruebas

`test/Codeunits/Cod110034.TestFormateadorFormula.al` (codeunit de prueba "Test Formateador Fórmula").

## Relacionado

[[Evaluador de fórmulas - sintaxis]] · [[Editor de fórmulas]] · [[Versionado de conceptos y fórmulas]] · [[xrec-no-confiable-con-addin]]
