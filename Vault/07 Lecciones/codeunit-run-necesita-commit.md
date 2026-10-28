---
aliases: ["Codeunit.Run() necesita Commit antes"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
actualizado: 2026-10-04
---

# Codeunit.Run() necesita Commit antes

if Codeunit.Run() then falla con una transacción de escritura abierta: el patrón de 'una fila mala no frena el lote' necesita un Commit ANTES del Run

> [!warning] Sin un Commit previo, el patrón "una fila mala no frena el lote" falla con una transacción de escritura abierta.

El patrón de **"una fila que falla queda anotada y el lote sigue"** se escribe
`if Aplicador.Run() then ... else <anotar el error>`. Eso es `OK := Codeunit.Run()`, y BC **lo
prohíbe con una transacción de escritura abierta**: el Run necesita bloquear tablas que la
transacción ya tiene tomadas. El mensaje lo dice literal —"Codeunit.Run solo se permite en
transacciones de escritura si no se usa el valor de retorno"— pero el valor de retorno **es** el
mecanismo, así que la salida no es sacarlo: es `Commit()` antes del Run.

**Por qué:** es un bug LATENTE que no aparece en las pruebas. Falla recién cuando algo escribió antes en
la misma transacción, y eso depende de los datos:

- `Cod110036.SincNAVLiq.EjecutarFila` — nunca se ejecutó hasta el 11/9/2026 porque no había filas
  pendientes que aplicar. En cuanto el staging trajo 4477 proyectos, murió en la primera fila: antes
  venían `Ctrl.AsegurarFilas()` y el `RegistrarEnControl` de la entidad anterior, sin confirmar.
- `Cod50046.OrquestadorSiradig` — el **primer** archivo importa bien y el **segundo** falla, porque
  lo que escribió el primero deja la transacción abierta. Con un archivo anda; con una selección
  —que es el caso de uso del bucle— no.

**Cómo aplicarlo:** si el diseño ya confirma después de cada unidad (`MarcarResultado` termina en
`Commit()`), agregar el `Commit()` *antes* del Run no cambia la semántica: cada fila ya era su propia
unidad de trabajo. Ponerlo en TODAS las iteraciones y no sólo en la primera, para no depender de que
ninguna otra ruta escriba antes.

Al revisar código nuevo, `grep -rn "if .*\.Run() then\|:= .*\.Run()" src/` encuentra los candidatos.

**La otra cara de la misma regla:** un `[TryFunction]` que escribe. Ahí no hace falta que la
transacción esté abierta —un TryFunction directamente no puede escribir— pero el síntoma engaña
igual: `Rep50045.AsignarAtributoMasivo` usaba un `[TryFunction]` local con el Insert adentro, la
PRIMERA entidad se asignaba bien y la segunda cortaba el informe entero con "no se permite INSERT
dentro de Empleado - OnAfterGetRecord" (15/9/2026). La salida es la misma: `Commit()` + `Codeunit.Run`
de un envoltorio con `TableNo`. Para los atributos ese envoltorio ya existía —`Cod50079.Alta Atributo
Entidad Liq.`— y `Rep50046.MigrarConvenioCategoria` ya lo usaba bien; el informe viejo no se había
enterado. Al revisar, `grep -rn "TryFunction" src/` lista los candidatos: si el cuerpo escribe, hay
que sacarlo a un codeunit.

Relacionado: [[al-sin-cortocircuito]], [[bucle-modifica-campo-filtrado]].

## Relacionado

- [[al-sin-cortocircuito]]
- [[bucle-modifica-campo-filtrado]]
- [[al-compile-command]]
- [[avoid-tables-principle]]
- [[borrar-rad-json-tras-cada-cambio]]
