---
tipo: tabla
tags: [modelo-datos, transaccional, auditoria, motor]
fuente: [src/Tables/Tab60023.DetalleVariableLineaLiq.al]
actualizado: 2026-10-24
---

# Tabla - Detalle Variable Línea Liq. (60023)

> [!note] Nombre de archivo
> El objeto termina en punto (`Detalle Variable Línea Liq.`). La nota omite el punto final.

## Propósito
**Qué variables (y con qué valor) intervinieron en cada línea** de [[Tabla - Línea Liquidación]], más el *snapshot de la escala* cuando se usó `TRAMO`. Es la base de la pantalla "Variables del cálculo" y del detalle de cálculo.

## PK
`No. Liquidación`, `No. Línea`, `Nombre Variable` (clustered). Sin otros índices ni SumIndexFields.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` (1) | → `Liquidación."No."` | |
| `No. Línea` (2) | Integer | Línea de la liquidación |
| `Nombre Variable` (3) | Text[50] | Variable usada |
| `Valor` (4) | Decimal (0:6) | Valor que vio la fórmula |
| `Detalle` (5) | Text[250] | Sólo para filas que no son variable de configuración (hoy, consultas `TRAMO`): en qué tramo cayó la base y con qué fijo/porcentaje |
| `Tabla Tramo` (6), `Base Tramo` (7), `Límite Tramo` (8), `Fijo Tramo` (9), `Porcentaje Tramo` (10), `Vigencia Tramo` (11), `Snapshot Tramo` (12) | | Snapshot de la escala aplicada ([[Tabla - Tabla Escalonada]]); `Snapshot Tramo` = escala conservada |
| `Código Atributo` (13) | Text[100] | Código del atributo usado (para explicar variables derivadas de atributos) |

## Triggers
Ninguno propio. Las **borra** `Línea Liquidación.OnDelete` (las de esa línea) y `Liquidación.OnDelete` (todas con `DeleteAll` directo, sin trigger por línea).

## Quién la lee / escribe
Escribe: `Cod50014.MotorLiquidacion` (variables de la línea, `WriteTramoDetail`). Lee: `Cod110044.DetalleCalculoLinea`, `Cod110055.PresentacionCalculoLiq`. Páginas: `Pag50156 Detalle Variable Línea Sub`, `Pag50159 Variables Cálculo Línea`.

## Vigencias
No tiene; es evidencia del cálculo.

## Trampas conocidas
- Si una liquidación vieja se recalcula con una escala distinta, esto es lo que muestra "lo que se aplicó" ([[Tabla - Tabla Escalonada]]).
- El detalle de la fórmula con valores vive aparte, en `Fórmula Evaluada` de la línea.

## Qué NO se escribe por línea (desde el 24/10/2026)
Medido el 24/10 sobre 569 liquidaciones recalculadas: de 186.317 filas, el 99 % era la misma variable con el mismo valor en todas las líneas de la liquidación (`TIPO_LIQ`, `PRECISION_REDONDEO`, `PCT_*`…).

`WriteVariableDetail` ya no escribe esas filas durante el cálculo: las deja en un buffer (`FDetalleDif`, sólo mientras `FDiferirDetalle`, que prende `DeleteLineas` y apaga `FlushDetalleDiferido`) y al cerrar (`FaseCerrar`, **antes** de `SaveResumenVariables`) las compara con el valor **final** del contexto:
- Si coincide, no se escribe la fila: el **nombre** va en una fila `~USO1`, `~USO2`… de la línea (`Detalle` = nombres separados por `|`, hasta 250 caracteres; una línea común lee unas cinco) y el valor se recupera del resumen de la liquidación (`Resumen Variable Liq.` + uso del parámetro). Una variable en cero no está en el resumen: se lee como cero.
- Si difiere (par alterno de convenio, una variable que cambió entre líneas) la fila se escribe como siempre.
- **Siempre se escriben** las referencias `#`/`@`, los conceptos que no son acumuladores (su valor es el importe de otra línea y el resumen no los guarda), los `TRAMO(...)` y las de más de 30 caracteres. El `Código Atributo` (p. ej. `TIPO_LIQ = 'REGULAR'`) viaja en la fila `~USO` como `NOMBRE=CÓDIGO`; sólo se queda en su fila si el código trae `|` o `=`. (En la 693 se quedaban todas: 17.272 filas, entre ellas el `TIPO_LIQ` repetido de la ficha.)

**Quien lea esta tabla no debe hacer `Get`/`FindSet` directo**: pasa por `Variables Guardadas Liq.`.`CargarDetalle(Liq, Línea, Destino)` (Cod110093), que deshace el trato: filas guardadas + una por cada nombre de `~USO` con su valor. Con `Línea = 0` devuelve **todas** las líneas y agrupa en una sola fila de línea 0 ("vale para todas") toda variable que tenga el mismo valor y el mismo código en todas las líneas que la leen, esté guardada o en `~USO`; si en alguna línea vale distinto, se muestra línea por línea. Tramos y `ACUM_PARAM_CCT` no se agrupan. Es lo que muestra la ficha. Lo usan `Cod110044.CargarContexto` y `Cod110044.SembrarReferencias` (el paso a paso re-evalúa con estos valores y estos códigos, y **no** reemplaza variables faltantes por cero; en la 694 `SembrarReferencias` leía directo y daba "No se conservó el código de atributo TIPO_LIQ"), `Cod110055.CargarDatos` y las páginas `Pag50156` y `Pag50159`, que ahora son temporales y se cargan a mano (`Cargar`) desde la ficha, la lista de líneas y la acción "Variables del cálculo".
Las filas `~USO` son del almacenamiento: ningún lector las muestra. Las liquidaciones calculadas antes de este cambio no las tienen y se leen igual que antes.

Por qué no se usó `Fuente Parámetros` de la línea para saber qué leyó cada una: arranca con `GetParamLog()` (todas las fuentes cargadas) y se corta en 2048, así que las variables del concepto quedan afuera en las 40.219 líneas medidas. Esa columna pesa 295 MB (casi el mismo prefijo en cada línea) y queda pendiente como mejora aparte.
