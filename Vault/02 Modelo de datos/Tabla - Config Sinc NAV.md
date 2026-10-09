---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, configuracion]
fuente: [src/Tables/Tab110046.ConfigSincNAV.al, src/Codeunits/Cod110040.ClienteNAVWS.al, src/Codeunits/Cod110041.TraerNAVWS.al, src/Codeunits/Cod110042.TraerYProcesarNAV.al, src/Pages/Pag110037.ConfigSincNAV.al]
actualizado: 2026-10-04
---

# Tabla - Config Sinc NAV

**Tabla 110046 `Config Sinc NAV`** (caption *Configuración Sincronización NAV*). **Datos persistentes**, **`DataPerCompany = false`**.

**Propósito.** Dónde está el origen (NAV) y a qué empresa de BC le corresponde. Una fila por par de empresas. Cubre los dos transportes: SQL por linked server y Web Services OData V4.

## Clave primaria
`"Empresa BC"` (Text[30], `TableRelation = Company.Name`).

## Campos relevantes
| Grupo | Campos | Notas |
|---|---|---|
| Identidad | `Empresa BC`, `Empresa NAV` (prefijo SQL), `Activo` | `Empresa NAV` **no** es el nombre lindo: NAV reemplaza caracteres no válidos (`Arbumasa S.A.` → `Arbumasa S_A_`). Con el nombre con puntos el error es "Invalid object name", idéntico al de falta de permiso. |
| Transporte SQL | `Linked Server`, `Base NAV`, `Tabla Empleado/Proyecto/Descarga Cab/Descarga Lin/Valor Dimension` | `Linked Server` es el `@server` de `sp_addlinkedserver`, no el host. Los nombres de tabla están acá y no fijos en el script porque NAV transforma `.`, `/` y `'` en `_`. |
| Selector | `Transporte` (enum `Transporte Sinc NAV`: SQL linked server / Web Services OData) | Se puede cambiar y volver: ambos llenan las mismas tablas. |
| Web Services | `URL Base NAV`, `Empresa OData`, `Usuario WS`, `Clave WS Cargada`, `Entidad Proyectos/Descargas/Change Log/Empleados/Valores Dim/Informe Cap Cab/Informe Cap Lin/Dia Abordo Cab/Dia Abordo Lin` | `URL Base` hasta `ODataV4`, sin empresa ni barra final, apuntando a una **segunda instancia** de NAV con `NavUserPassword`. |
| Change Log | `Tabla NAV Proyecto/Empleado/Descarga Cab/Descarga Lin/Valor Dim/Informe Cap Cab/Lin/Dia Abordo Cab/Lin` | **N.º de tabla de NAV** (167, 5200, 349, 50561, 50562, 50559, 50560, 50501, 50502), con que el Change Log identifica qué cambió. |

La **clave del web service no se guarda acá**: vive en Isolated Storage (`Cod110040.GuardarClave`); `Clave WS Cargada` es sólo la luz de "ya está puesta". Las credenciales del linked server tampoco: se definen con `sp_addlinkedsrvlogin`.

## Lógica en triggers
`OnInsert` → `PonerNombresPorDefecto()`: completa sin pisar los nombres de tabla de origen (`Employee`, `Job`, `Cab_ descarga`, `Lín_ descarga`, `Dimension Value`), los entity sets publicados hoy (`ListaProyectos`, `DetalleDescargas`, `MovRegistroCambios`, `CabInfoCap`, `LinInfoCap`, `CabDiaAbordo`, `LinDiaAbordo`) y los números de tabla de NAV. `Entidad Empleados` y `Entidad Valores Dim` **quedan en blanco** a propósito (no existen como web service todavía; en blanco = "no se trae por este transporte"; mejor que un nombre inventado que dé 404).

## Quién la lee y la escribe
- **Lee:** `Cod110040 Cliente NAV WS` (`SetEmpresa`, `PrepararCliente`, `ArmarUrl`), `Cod110041 Traer NAV WS`, `Cod110042 Traer y Procesar NAV` (`TraerTodo` sólo corre si `Activo` y `Transporte = Web Services`), el script T-SQL de SQL Agent (por SQL directo contra la tabla sin prefijo de empresa).
- **Escribe:** página `Config Sinc NAV` (110037) y la acción de clave (`Clave Web Service NAV`, 110039).

## Trampas
> [!warning] DataPerCompany = false
> Sin prefijo de empresa, SQL la nombra `Config Sinc NAV$<AppId>` y el procedimiento la encuentra con un `LIKE`; si fuera por empresa habría que decirle al script la empresa para leer la tabla que dice cuál es la empresa. Es configuración de instalación, no de empresa.

> [!warning] V4 y no V3; NTLM no
> El `HttpClient` de AL no habla NTLM ni Kerberos: la instancia de producción de NAV responde NTLM, por eso hace falta una segunda instancia con `NavUserPassword`. Sobre las Query de NAV, V3 devuelve 400 ante un `$top`. Ver [[nav-odata-ntlm]] y [[transporte-ws-sincronizacion]].

- `Entidad Empleados` debe estar publicado sobre la **ficha** del empleado, no la lista (OData sólo expone lo que la página muestra; sin fecha de ingreso no se abre la fase de alta y la antigüedad da cero).
- Cambiar los números de tabla NAV o los nombres de entity set es configuración: no requiere tocar código.

## Relacionado
[[Tabla - Ctrl Sinc NAV]] · [[Patrón de las tablas de staging NAV]] · [[Tabla - Stg Proyecto NAV]] · [[sincronizacion-valores-dimension]]
