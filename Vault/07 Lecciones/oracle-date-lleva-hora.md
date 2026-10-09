---
aliases: ["Un DATE de Oracle lleva hora"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, feedback]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-19
---

# Un DATE de Oracle lleva hora

> [!warning] Falla en silencio
> Un DATE de Oracle lleva hora; escribirlo en un campo Date de BC no falla al insertar, falla al abrir la página

Un `DATE` de Oracle **es un timestamp al segundo**, no una fecha. Escribirlo tal cual en un campo `Date` de BC **no falla en la inserción**: falla después, cuando alguien abre la página, con *"La fecha no es válida"*, y la página se cierra entera.

**Por qué:** la carga parece perfecta. Todos los controles de invariante dan bien —los importes cierran al centavo, no hay huérfanos, no hay duplicados— porque ninguno mira la hora de un campo de fecha. El defecto sólo aparece cuando un humano abre el registro, que puede ser días después. Es el mismo patrón que varias trampas de esta migración: **el fallo no avisa donde se produce**.

Pasó en la carga del archivo de Meta4: 2.200.914 filas, todas de `FEC_ULT_ACTUALIZACION`, en las cinco tablas de acumulados.

**Cómo aplicarlo:** truncar **del lado de Oracle** al extraer — `TRUNC(col)` o `TO_CHAR(col,'YYYY-MM-DD')` — o truncar en el cliente antes del bulk copy (`$f.Date` en PowerShell). Las fechas que pasaron por `TO_CHAR` del lado de Oracle salieron limpias; las que se leyeron con `GetDateTime()` directo, no. Ése es el contraste que lo identifica.

Y si el dato es un archivo literal, la hora **no se tira**: se guarda aparte (en el campo de texto, en ISO) antes de truncar. En este caso eran 52.000 horas distintas, o sea información real sobre cuándo Meta4 tocó cada fila. Resolver el síntoma perdiendo el dato no es resolverlo.

**Control barato** después de cualquier carga con fechas:
```sql
SELECT COUNT(*) FROM <tabla> WHERE [Campo] <> CONVERT(datetime, CONVERT(date, [Campo]));
```

Relacionado: [[meta4-conectar-desde-powershell]], [[meta4-number-castea-a-cero]], [[previsualizar-antes-de-migrar]].

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
