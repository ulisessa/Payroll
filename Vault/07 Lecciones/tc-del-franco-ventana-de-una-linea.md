---
aliases: ["El TC del franco: una ventana de una línea"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-08
---

# El TC del franco: una ventana de una línea

La llamada que le presta las cotizaciones al ledger de francos tiene exactamente un lugar donde funciona

> [!warning] `ResolverTiposCambioFrancos` va **entre** `LoadParametros` y `LoadVariablesSistema`. Un paso antes, el TC sale en cero; un paso después, los francos ya se valuaron.

`Gestión Francos` lee `Parámetro Vigente` directo —el precio sale del par sellado en cada lote— y por eso se saltea `ConvertirParametrosEnDivisa`. El contexto le presta sus cotizaciones con `PublicarTiposCambio`, y ubicar esa llamada costó dos intentos fallidos:

| Dónde se puso | Qué pasó |
|---|---|
| Después de `LoadDynamicSources` | **Tarde.** `LoadVariablesSistema` ya había valuado los francos → `ErrFrancoTCInexistente` |
| Antes de `LoadScalars` | **Temprano.** `{MONEDA}` todavía está vacío, el filtro de la fuente no acota y el TC vuelve 0 → `ErrFrancoTCEnCero` |
| Entre `LoadParametros` y `LoadVariablesSistema` | **Justo.** `FMoneda` ya está, los francos todavía no |

**Por qué la ventana es tan angosta:** `TC_COMPRADOR` es una Fuente de Datos sobre `Currency Exchange Rate` que filtra por `{MONEDA}` y `<={FECHA_REF}`. El token `{MONEDA}` lo llena `LoadParametros` al descubrir la moneda de los parámetros en divisa, así que antes de eso la fuente existe pero no sabe de qué moneda hablar. Y los francos se valúan dentro de `LoadVariablesSistema`, que es el paso siguiente.

**Los dos errores son distintos y cortan:** `ErrFrancoTCInexistente` cuando la variable no está en el diccionario, `ErrFrancoTCEnCero` cuando está pero vale cero. Ninguno deja pasar el importe en divisa, que sería lo peor: un número válido mil cuatrocientas veces más chico, que ningún control de importe detecta.

**Cómo aplicarlo:** si hay que mover algo en `LoadScalars`, verificar que esta llamada siga en medio. Y para valuar francos **fuera** de un cálculo —una página— no se replica el orden: se usa `TiposCambioFrancosAFecha`, que hace `Init`, fija la moneda y resuelve las fuentes por su cuenta ([[instancia-de-ledger-no-ve-lo-publicado]]).

## Relacionado

- [[instancia-de-ledger-no-ve-lo-publicado]]
- [[franco-tres-niveles-de-precio]]
- [[valor-franco-por-terna]]
- [[que-tc-usa-cada-concepto]]
- [[tc-de-marea-no-es-cotizacion]]
- [[usarparcct-deshace-pasadas-posteriores]]
