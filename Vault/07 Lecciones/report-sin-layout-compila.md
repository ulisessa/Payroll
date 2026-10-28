---
aliases: ["Un report sin layout compila"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
actualizado: 2026-10-04
---

# Un report sin layout compila

> [!warning] Falla en silencio
> un report sin layout compila y falla recién al abrirlo; y el Commit que hace falta para abrirlo tras calcular

Un `report` de AL **sin layout compila perfecto** y falla recién en runtime: *"El informe NNNNN no
tiene un diseño válido. Los tipos de diseño válidos son: Word, RDLC, Excel y personalizado."* No hay
advertencia de compilación que lo anticipe, así que un informe nuevo no está terminado hasta
**abrirlo** una vez.

El layout se declara con el bloque `rendering`, y entonces **`DefaultRenderingLayout` es obligatorio**
(error AL0721) aunque haya un solo layout:

```al
DefaultRenderingLayout = RDLCLayout;
...
rendering
{
    layout(RDLCLayout)
    {
        Type = RDLC;
        LayoutFile = './src/Reports/RepNNNNN.Nombre.rdl';
        Caption = '...';
    }
}
```

El `.rdl` se escribe a mano tomando `Rep50041.ReciboDeSueldo.rdl` de plantilla. El orden de los
bloques en ese esquema (2016/01) es `DefaultFontFamily`, `AutoRefresh`, `DataSources`,
**`ReportSections`** y recién al final **`DataSets`**. El DataSet se llama `DataSet_Result` y cada
`<Field Name="X"><DataField>X</DataField></Field>` tiene que coincidir con el nombre de un
`column(X; ...)` del AL. Los campos de la cabecera se leen con
`First(Fields!X.Value, "DataSet_Result")`.
**Dónde va este informe, que no es donde lo puse primero**: al final de un **proceso largo** y sólo
si hay **5 avisos o más** (`ValeLaPena` / `MinimoParaInforme`), no al terminar una liquidación suelta
—ahí quedó el cartel de siempre, que se lee de un vistazo—. Filtra por **`No. Sesión`**, el Guid que
`Registro Procesos Liq.` crea con `IniciarSesion` y que agrupa toda la corrida.

Se dispara desde `Registro.MostrarAvisosDeLaSesion()`, que vive en el codeunit del registro porque
ahí vive la sesión, y **se llama antes de `CerrarSesion`**, que es la que olvida el Guid. Devuelve si
lo mostró, para que el proceso no repita después las mismas advertencias concatenadas en un cartel.
Los tres procesos que lo usan: `CrearYCalcularPorPeriodo` y `CalcularPorPeriodo` (Cod50018, que es a
lo que llaman el Lanzador y la lista de Períodos) y `Lotes.Calcular` (Cod50076, la selección en la
lista de liquidaciones).

**El Commit sigue haciendo falta**, ahora en `MostrarAvisosDeLaSesion`: un informe con página de
solicitud no corre dentro de una transacción de escritura y, al cortar, revierte el lote entero. Un
`Message` no abría transacción, y por eso cambiar un cartel por un informe lo trae de arrastre.
Cerrar la ventana de progreso ANTES del informe también importa: con la ventana abierta el informe
queda detrás y parece que el proceso se colgó.

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
