---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, control]
fuente: [src/Tables/Tab110041.CtrlSincNAV.al, src/Codeunits/Cod110036.SincNAVLiq.al, src/Codeunits/Cod110041.TraerNAVWS.al, src/Enums/Enum50328.EntidadSincNAV.al]
actualizado: 2026-10-04
---

# Tabla - Ctrl Sinc NAV

**Tabla 110041 `Ctrl Sinc NAV`** (caption *Control de Sincronización NAV*). **Datos persistentes** (por empresa).

**Propósito.** Una fila por entidad sincronizada: el **único punto donde se tocan las dos mitades** del mecanismo. El job de SQL Agent escribe `Marca Agua`, `Traido El` y `Filas Traidas` por SQL directo; el Job Queue de BC escribe las de proceso. Por eso los nombres de tabla y campo no llevan puntos ni acentos ([[Patrón de las tablas de staging NAV]]).

## Clave primaria
`Entidad` (enum `Entidad Sinc NAV`: Empleado 0, Proyecto 1, Descarga Cabecera 2, Descarga Linea 3, Valor Dimension 4, Informe Cap Cabecera 5, Informe Cap Linea 6, Dia Abordo Cabecera 7, Dia Abordo Linea 8).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Habilitada` | Boolean (InitValue true) | La mira el script SQL antes de traer y BC antes de aplicar. Apagarla corta una entidad sin desarmar el job. |
| `Marca Agua` | Text[20] | Hasta dónde se leyó. Con transporte SQL es el **rowversion** en decimal; con Web Services es el `Entry_No` del Change Log de NAV (uno solo para todas las tablas). **Vaciarla fuerza una traída completa** (no borra nada en BC, vuelve a ofrecer todo el origen). |
| `Traido El`, `Filas Traidas` | DateTime/Integer | Última traída y tamaño del lote. |
| `Procesado El`, `Filas Procesadas`, `Ultima Observacion` | DateTime/Integer/Text[250] | Último proceso: resumen "N aplicadas, M en espera, K con error". |

## Lógica
- `AsegurarFilas()`: crea las filas que falten recorriendo `Ordinals()` del enum; idempotente y **no pisa** `Marca Agua` (puede estar ajustada a mano).
- `ObtenerHabilitada(Ent)`: devuelve la fila (la crea si falta) y si está habilitada.
- `RegistrarProceso(Filas, Obs)`: estampa `Procesado El` y trunca la observación.

## Quién la lee y la escribe
- **Escribe:** `Cod110036 Sinc NAV Liq.` (`RegistrarEnControl`), `Cod110041 Traer NAV WS` (`RegistrarTraida`), el job de SQL Agent (por SQL directo), página `Control Sinc. NAV` (110032).
- **Lee:** `Cod110036`, `Cod110041`, `Cod110042 Traer y Procesar NAV`, página de control.

## Trampas
> [!warning] La marca de agua no es portable entre transportes
> Un rowversion leído como `Entry_No` (o al revés) no da error: da un número enorme que deja todo afuera. Al cambiar el transporte en [[Tabla - Config Sinc NAV]] hay que vaciarla. Ver [[transporte-ws-sincronizacion]].

> [!note] La marca sólo avanza si todo salió bien
> `TraerEntidad` la mueve únicamente al final y sin error; si falla a mitad de camino la corrida siguiente vuelve a pedir lo mismo (el llenado del staging es idempotente; saltear no lo es).

- "Descarga Linea" no se trae sola: la trae la cabecera de un solo pedido (la Query de NAV devuelve ambas planas) y mueve las dos marcas.
- Tabla **por empresa** (a diferencia de [[Tabla - Config Sinc NAV]]).

## Relacionado
[[Tabla - Config Sinc NAV]] · [[Patrón de las tablas de staging NAV]] · [[nav-odata-ntlm]] · [[linked-server-leer-escalar-remoto]]
