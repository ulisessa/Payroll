---
aliases: ["Una instancia del ledger no ve lo que se le publicó a otra"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
actualizado: 2026-10-08
---

# Una instancia del ledger no ve lo que se le publicó a otra

Cada `Codeunit` declarado es un objeto nuevo con su estado en cero; publicarle algo a uno no alcanza para los demás

> [!warning] Antes de agregar un `Codeunit "Gestión Francos"` local, preguntarse quién le publica las cotizaciones. Son **cinco** declaraciones en el repo y cada una necesita la suya.

`Gestión Francos` valúa el franco leyendo `Parámetro Vigente` **directo**, porque el precio se busca con el convenio y la categoría sellados en cada lote y no con el par de la liquidación. Esa lectura se saltea `ConvertirParametrosEnDivisa`, así que una fila en USD se usaría como si fueran pesos. La solución fue que el contexto le **preste** sus cotizaciones con `PublicarTiposCambio`, guardadas en un `Dictionary` de instancia.

Y ahí está la trampa: el estado es **por instancia**. Quien declara su propio `Gestión Francos` nace con el diccionario vacío y corta con *"la cotización TC_COMPRADOR no existe en el contexto de la liquidación"*. Apareció **tres veces seguidas**, siempre como un agujero nuevo:

1. `Cod50016` (el dueño), que lo publica dentro de `LoadScalars`;
2. `Cod50014`, que tiene su propia instancia para el desglose por lote — se le agregó `GetTiposCambioFrancos` + `PublicarTiposCambio`;
3. `Pag110054 Lotes Franco Consumidos` y `Pag110024 Francos por Tripulante`, que valúan sin armar ningún contexto. El error lo levantó un usuario al abrir el detalle del cálculo de un OF04.

`Cod50017` también declara uno, pero sólo le pide **días** (`SaldoFrancosAFecha`), así que no necesita cotización.

**Cómo aplicarlo:** las páginas van por `Contexto Liquidación.TiposCambioFrancosAFecha(empleado, fecha, moneda, TCs)`, que hace `Init` + resuelve las fuentes `TC_*`, y después `PublicarTiposCambio`. Un buscador honesto del problema es `grep -rn 'Codeunit "Gestión Francos"' src/`: si una declaración nueva llama a algo que devuelve **pesos**, le falta publicar.

> [!warning] La moneda hay que pasarla, y después de `Init`
> La Fuente de Datos `TC_COMPRADOR` filtra la cotización por `{MONEDA}`, token que llena `LoadParametros` —que en una página no corre—. Con el filtro vacío la fuente devuelve la cotización de **cualquier** divisa: un número válido y ajeno, o cero. De ahí `GestionFrancos.MonedaDelPrecio(fecha)`, que la lee del parámetro del precio. Y va **después** de `Init`, que limpia `FMoneda`.
>
> Es la misma trampa de orden que ya había costado dos intentos al ubicar la llamada dentro del motor: antes de `LoadParametros` el token está vacío y el TC sale en cero; después de `LoadDynamicSources`, los francos ya se valuaron ([[tc-del-franco-ventana-de-una-linea]]).

El caso general: **un `Dictionary` o cualquier variable global de un codeunit es estado de esa instancia**, no del objeto. Si el dato tiene que viajar, o lo pasa el llamador en cada llamada, o el codeunit sabe resolverlo solo. Prestárselo a una instancia y esperar que lo vean las demás falla en silencio hasta que alguien abre una página.

## Relacionado

- [[tc-del-franco-ventana-de-una-linea]]
- [[franco-tres-niveles-de-precio]]
- [[valor-franco-por-terna]]
- [[control-moneda-es-asimetrico]]
- [[francos-fifo-ledger]]
