---
aliases: ["Parámetro y atributo con el mismo nombre"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, reference]
actualizado: 2026-10-04
---

# Parámetro y atributo con el mismo nombre

> [!warning] Falla en silencio
> Si un Parámetro y un Tipo Atributo comparten Nombre Variable, gana el parámetro y el atributo nunca llega a la fórmula

`LoadAtributos` publica la variable del atributo **sólo si el nombre está libre**:

```al
if not Ctx.ContainsKey(TipoAtr."Nombre Variable") then
```

y `LoadParametros` corre **antes**. Así que cuando un Parámetro y un Tipo Atributo tienen el
mismo `Nombre Variable`, gana el parámetro y **el atributo se vuelve dato muerto**: se carga,
se ve en la página, tiene historial y vigencias, y ninguna fórmula lo ve. No hay error.

Pasó con `ZONA_DESF` (21/9/2026): el parámetro valía 0,20/0,30 —el adicional de zona por
convenio— y el atributo `ZONA_DESFAVORABLE` valía 7/29/69 —la zona del empleado—. El
detalle de variables de una liquidación mostraba `ZONA_DESF = 0,2000`. Se resolvió
renombrando el parámetro a `PCT_ZONA_DESF`.

**Cómo detectarlo:** el `Detalle Variable Línea Liq.` de una liquidación dice qué valor tomó
cada variable; si un atributo cargado no aparece o aparece con el valor de otra cosa, hay
choque. Buscarlo antes:

```sql
SELECT p.[Nombre Variable] FROM Parámetro p
JOIN [Tipo Atributo Liq_] t ON t.[Nombre Variable] = p.[Nombre Variable]
WHERE p.[Nombre Variable] <> '';
```

**Al renombrar, cuidado con los prefijos.** `ZONA_DESFAV` —la tabla escalonada— empieza igual
que `ZONA_DESF`. Un `REPLACE` ingenuo sobre las fórmulas convierte `TRAMO('ZONA_DESFAV', …)` en
`TRAMO('PCT_ZONA_DESFAV', …)`, que no existe. Reemplazar con el contexto pegado (`* ZONA_DESF,`)
y controlar después excluyendo el prefijo largo.

**Y el riesgo inverso:** liberar el nombre hace que la variable pase a valer otra cosa —de 0,2 a
29— sin que ninguna fórmula falle. Antes de renombrar, barrer TODOS los consumidores: fórmula,
condición, Variable Cantidad, Variable Base y filtros de Fuente de Datos.

Ver [[parametros-somu-por-pesqueria]] para la otra trampa de la misma familia: dos unidades
conviviendo bajo el prefijo `PCT_`.

## Relacionado

- [[sindicato-obra-social-atributos]]
- [[tc-comprador-parametro-fantasma]]
- [[tipo-atributo-tres-campos-silenciosos]]
- [[un-valor-una-fuente]]
- [[veda-como-atributo-del-buque]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
