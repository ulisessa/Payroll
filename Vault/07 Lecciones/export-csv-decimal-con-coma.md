---
aliases: ["Export-Csv escribe decimales con coma"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, feedback]
actualizado: 2026-10-04
---

# Export-Csv escribe decimales con coma

Export-Csv de PowerShell escribe los decimales con la coma regional, y Perl los trunca a entero avisando sólo con un warning

`Export-Csv` usa la **configuración regional**, así que en esta máquina los números salen como
`-795784,01`. Al leerlos desde Perl (o cualquier cosa que espere punto), `"795784,01" + 0` da
**795784**: se comen los centavos. Perl avisa con un warning por fila, que entre miles de líneas
es exactamente el tipo de aviso que se pasa por alto.

Pasó el 18/9/2026 migrando `M4T_VAL_INCIDENCIA`: 4.747 novedades habrían entrado sin decimales.

**Cómo aplicarlo:** en el lado que lee, `$valor =~ s/,/./;` antes de usarlo — y verificar en la
salida generada que los decimales sobrevivieron (`grep -cE ",-?[0-9]+\.[0-9]+,"`). En el lado que
escribe, la alternativa es forzar `[System.Globalization.CultureInfo]::InvariantCulture` o
exportar con `ConvertTo-Csv` sobre strings ya formateados.

Mismo tipo de trampa que [[sql-dinamico-truncado-4000]]: la pérdida es silenciosa y el dato
resultante es plausible.

## Relacionado

- [[sql-dinamico-truncado-4000]]
- [[anticipos-cta-cte-meta4]]
- [[equivalencia-id-puesto-meta4]]
- [[historia-remuneraciones-migrada]]
