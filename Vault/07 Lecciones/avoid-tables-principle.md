---
aliases: ["Principio: evitar tablas nuevas"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
origen: c60bb641-6f64-4ab1-9d8b-eabba2faf874
actualizado: 2026-10-04
---

# Principio: evitar tablas nuevas

Antes de crear una tabla nueva hay que agotar Parámetros, Fuente Datos y Condición: el motor se configura, no se programa.

Directiva de diseño central, repetida varias veces por el usuario: **"El objetivo es evitar crear tablas cuando puede ser evitado."**

## Por qué

El motor de liquidación está pensado para configurarse, no para codificarse. Una tabla nueva significa esquema nuevo, migraciones, permisos y UI: el costo que el motor paramétrico se construyó para evitar.

## Cómo aplicarlo

Antes de agregar una tabla, probar en este orden:

1. Un `Parámetro` (EAV, valor por código+fecha, con Sufijo Empleado/CCT/Convenio).
2. Una `Fuente Datos` (lee de cualquier tabla a una variable de fórmula).
3. Una `Condición`.
4. Una variable de sistema reservada, ver [[system-variables-conventions]].
5. Un campo de configuración en una tabla de configuración existente (Concepto, Cód. Estado).

Las tablas se justifican sólo cuando el dato es genuinamente relacional o multi-atributo y no encaja en nada de lo anterior; incluso entonces, revisar si una tabla existente sirve (por ejemplo, el libro FIFO de francos reutiliza `Línea Liquidación` en vez de una tabla nueva). Ver [[francos-fifo-ledger]] y [[estado-empleado-effective-dated]].

## Relacionado

- [[system-variables-conventions]]
- [[francos-fifo-ledger]]
- [[estado-empleado-effective-dated]]
- [[atributos-tipados]]
- [[dos-parametros-mismo-nombre]]
