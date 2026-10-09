---
aliases: ["Atributos tipados"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-12
---

# Atributos tipados

Atributos de entidad tipados y con historial (análogo de las Dimensiones de BC) que llegan a la fórmula vía Fuente Datos sin tocar el motor.

Built 2026-08-12. Equivalente a Dimensiones/Valores de Dimensión de BC, pero **tipado y con historial**, para cargar datos que importan al cálculo (zona desfavorable, obra social, régimen horario) sin agregar campos ni código.

| Objeto | Rol |
|---|---|
| `Tipo Atributo Liq.` (110003) | La "dimensión": código, `Tipo Dato`, `Tipo Entidad` |
| `Valor Atributo Liq.` (110004) | El "valor de dimensión" + **`Valor Numérico`** |
| `Atributo Entidad Liq.` (110005) | La asignación con `Vigencia Desde`/`Hasta` |

**Llegan a la fórmula solos** (desde el 15/9/2026). `Tipo Atributo Liq."Nombre Variable"` dejó de ser documentación: con ese nombre cargado, `Cod50016.LoadAtributos` pone un valor en el contexto de cada liquidación —la entidad sale del `Tipo Entidad` del atributo: empleado, proyecto, o el buque del proyecto vía `Global Dimension 1 Code`— resuelto a la vigencia de `FFechaRef`. **NO pisa** lo que ya hayan definido un parámetro, una variable de sistema o una Fuente de Datos, y el campo rechaza un nombre ya tomado. Antes había que declarar una fila de `Fuente Datos Liquidación` por atributo; eso sigue sirviendo cuando hace falta una cascada o un agregado.

**Ojo con las fuentes decimales:** `LOOKUP` aplica SOLO los filtros configurados, no agrega vigencia por su cuenta (eso es `FilaVigenteAFechaRef`, que corre únicamente para las de texto/fecha). Una fuente sobre atributos necesita los dos filtros de fecha a mano, y el de `Vigencia Hasta` tiene que aceptar el blanco.

Claves del diseño:
- **`Valor Numérico` está desnormalizado** en la asignación porque Fuente Datos lee UNA tabla y no hace joins. Se congela al asignar: cambiar el número del valor de la lista NO reescribe lo ya asignado, para que un recálculo viejo dé lo mismo.
- **Contigüidad idéntica a Concepto Liquidación** (ver [[conceptos-tres-vigencias]]): cierre automático solo si la anterior estaba abierta, superposición rechazada, huecos permitidos.
- **Preferir `Lista` sobre `Texto`** para todo lo que decida un cálculo: el código queda validado por relación de tabla; un literal de texto en la fórmula se rompe en silencio si alguien renombra el valor.
- **NO migrar `Estado Empleado` acá.** Situación de Revista parece un atributo más pero lleva comportamiento: auto-transiciones, devengo de francos, proyecto de inactividad.

`Fuente Datos Liquidación` se amplió al mismo tiempo con `Tipo Dato` (Decimal/Texto/Fecha): conserva el valor original en `Resumen Variable Liq."Valor Texto"` para auditar e imprimir, y proyecta a número para la fórmula (texto → 1/0, fecha → días hasta la fecha de referencia). **Importante: antes de esto, `LOOKUP`/`SUM`/`MAX`/`MIN` NO filtraban por vigencia** — los campos de fecha los usaban solo los agregados `DIAS_*`.

Pendiente: comparar texto dentro de una fórmula (`IF(PUESTO = 'ASISTENTE', ...)`) requiere tocar el evaluador, que es decimal en todos sus niveles. Hoy se resuelve con una fuente `COUNT` + filtro por el texto, que compara en SQL.

## Relacionado

- [[conceptos-tres-vigencias]]
- [[antiguedad-maxima-vigencia-avisa-de-mas]]
- [[dos-parametros-mismo-nombre]]
- [[fuente-datos-apunta-por-numero]]
