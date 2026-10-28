---
aliases: ["El control de moneda es asimétrico"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-08
---

# El control de moneda es asimétrico

"Ninguna fila con Moneda y sin TC" pasa limpio y no ve el caso que muerde

> [!warning] Antes de encender una conversión por metadato hay que cruzar **las dos direcciones**. El control obvio —*ninguna fila con `Moneda` cargada y sin TC declarado*— pasaba limpio, y el cambio habría roto **226 M** de enero.

Al migrar al esquema de `Cód. Variable TC` (ver [[que-tc-usa-cada-concepto]]) falta el espejo, que es el que hace daño: **una fila sin `Moneda` que la fórmula multiplica por el TC igual**. Ocho de las dieciséis filas de `USD_MAREA` estaban así —valores de 5.500 a 24.000, dólares sin discusión— y como la fórmula convertía sin preguntar, el importe salía bien. Al encender la conversión por `Moneda`, esas ocho dejan de convertirse y caen a 1/1.100.

Y hay una tercera categoría: parámetro **con** `Moneda` en una fórmula que **no** convierte. Ahí la bandera multiplica por 1.100 algo que hoy se usa crudo. `NETO_GARANT` es el caso que bloquea, porque lee `NETO_GU` sin convertir a propósito: el que convierte es el motor.

## Tres maneras de estar bien hoy, y sólo una sobrevive

| Moneda en la fila | La fórmula convierte | Al encender |
|---|---|---|
| sí | sí | ✔ sigue bien |
| **no** | **sí** | ✗ deja de convertir: /1.100 |
| **sí** | **no** | ✗ convierte de más: ×1.100 |

Buscar `TC_COMPRADOR` en las fórmulas encuentra **una** de las tres.

## Cómo se controla

Por cada variable nombrada en una fórmula, comparar si la fórmula convierte contra si **todas** sus filas tienen `Moneda`. Las filas mixtas son legítimas sólo donde la fórmula usa `_ESFCY` por fila —`BASICO`, `PRECIO_PUERTO_CAL`, `PRECIO_PUERTO_LAN`—; en cualquier otra variable, mixto es error de carga.

Los informativos sin consumidores no son riesgo: conviene medirlo antes de frenar por ellos.

## Relacionado

- [[que-tc-usa-cada-concepto]]
- [[usarparcct-deshace-pasadas-posteriores]]
- [[basico-de-tierra-por-empleado]]
- [[precio-puerto-lista-inconsistente]]
- [[usd-marea-y-valor-nav-emp-no-son-lo-mismo]]
