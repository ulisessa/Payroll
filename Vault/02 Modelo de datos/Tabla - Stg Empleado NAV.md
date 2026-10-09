---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, empleados]
fuente: [src/Tables/Tab110045.StgEmpleadoNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110036.SincNAVLiq.al]
actualizado: 2026-10-04
---

# Tabla - Stg Empleado NAV

**Tabla 110045 `Stg Empleado NAV`** (*Staging Empleado NAV*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** Espejo del `Employee` de NAV. Trae identidad y datos personales; **no** trae convenio ni categoría (decisión de liquidación, se cargan en BC). El alta deja al empleado marcado `Pendiente Completar Liq.` y lo que NAV tenga como convenio/categoría queda acá al lado como referencia, sin aplicarse.

## Clave primaria
`"No Empleado"` (Code[20]). Secundaria `("Estado Sinc","No Empleado")`.

## Campos relevantes
| Campo | Propósito |
|---|---|
| `Apellido`, `Nombre`, `Segundo Nombre`, `Iniciales`, `Puesto Titulo` | Identidad. |
| `Fecha Ingreso` | Fecha con la que se **abre la fase de alta**. Sin ella el empleado se crea igual pero sin fase y se anota la observación: la antigüedad no se puede calcular. |
| `No Seguridad Social`, `CIF NIF` | Ambos con el CUIL tal como vengan de NAV: la importación SIRADIG busca el CUIL en los dos campos. Ver [[cuil-vive-en-cif-nif]]. |
| `Fecha Nacimiento`, `Direccion`, `Direccion 2`, `Ciudad`, `Cod Postal`, `Telefono`, `Email` | Datos personales (`DataClassification` CustomerContent). |
| `Convenio Origen`, `Categoria Origen` | **Sólo referencia**: la codificación de NAV no es la de `Convenio Colectivo`. |
| 90–95 | Estado de sincronización común. |

## Se aplica sobre
`Employee` y, si es alta, [[Tabla - Fase Alta Empleado]] (`AbrirFase` con el código de estado de alta de `Human Resources Setup`).

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarEmpleados` (WS) o el job SQL. Con `Config Sinc NAV."Entidad Empleados"` en blanco no se trae por WS.
- **Aplica:** `Cod110037.AplicarEmpleado`; el orquestador `Cod110036.ProcesarEmpleados` resuelve `Cód. Estado de Alta (Sinc. NAV)` en `Config. Recursos Humanos`.
- **Lee:** página `Sinc. Empleados NAV` (110034).

## Trampas
> [!danger] El empleado se crea por AL, nunca por MERGE
> Un alta por SQL directo no genera la fase de alta: antigüedad cero y francos sin devengar. Si no hay código de alta configurado y el empleado no existe, la fila queda en **Error** ("definí Cód. Estado de Alta") en vez de crear un empleado sin fase; las modificaciones de empleados existentes pasan igual (no abren fase).

- Hay que haber **un solo** código activo de tipo Alta o definirlo en la configuración de RRHH; con más de uno la sincronización no elige.
- `AbrirFase` devuelve false si ya hay una fase abierta: protege al empleado que ya existía.

## Relacionado
[[Tabla - Fase Alta Empleado]] · [[Tabla - Estado Empleado]] · [[cuil-vive-en-cif-nif]] · [[Tabla - Config Sinc NAV]]
