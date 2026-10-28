---
aliases: ["SetSelectionFilter en página temporal"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-16
---

# SetSelectionFilter en página temporal

**En una frase:** En una página con SourceTableTemporary, SetSelectionFilter sobre otra variable temporal no devuelve nada: la multiselección se pierde en silencio

`CurrPage.SetSelectionFilter(Otra)` **tiene que ir sobre `Rec`** (o sobre una variable con
`Otra.Copy(Rec, true)`, que comparte la tabla). En una página con `SourceTableTemporary = true`, dos
variables temporales de la misma tabla son **dos tablas distintas**: la variable aparte nace vacía,
SetSelectionFilter no encuentra filas que marcar, el `FindSet()` da falso y la selección entera se
pierde.

**Por qué:** no falla, y ahí está el problema. El código que sigue suele tener una red del tipo "si no
hay nada seleccionado, uso la fila del cursor" — y esa red se traga el bug. El síntoma que llega es
**"selecciono seis y me procesa uno"**, el último que tocaste, sin error y con el diálogo de
confirmación diciendo "1 registro", que es la única pista.

Pasó en `Pag110017.ArbolLiquidaciones` (15/9/2026): afectaba a Calcular, Aprobar, Reabrir, Eliminar,
Imprimir y Abrir a la vez, porque las seis acciones pasan por el mismo `NodosSeleccionados`. El
patrón bueno ya estaba escrito al lado, en `Pag50073.ConceptosConvenioSub.GetSeleccionados`.

**Cómo aplicarlo:**

```al
ClaveFoco := Rec."Clave Orden";        // el recorrido deja el registro en la última fila
CurrPage.SetSelectionFilter(Rec);
if Rec.FindSet() then
    repeat
        Destino := Rec;
        if Destino.Insert() then;
    until Rec.Next() = 0;
Rec.Reset();
if ClaveFoco <> '' then
    if Rec.Get(ClaveFoco) then;
```

Filtrar `Rec` dentro de la acción es seguro: se pone y se saca en la misma llamada al servidor, así
que el cliente nunca dibuja la vista filtrada. Lo único que hay que reponer es el foco.

Al revisar, `grep -rn "SetSelectionFilter" src/` y mirar si el argumento es `Rec`; si es otra
variable, verificar que venga de un `Copy(Rec, true)`.

Relacionado: [[bucle-modifica-campo-filtrado]], [[al-sin-cortocircuito]].

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[symbolos-final-version-tienen-fuente]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
