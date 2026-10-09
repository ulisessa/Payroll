---
aliases: ["SQL directo deja la caché rancia"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, feedback]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-19
---

# SQL directo deja la caché rancia

> [!warning] Falla en silencio
> Un UPDATE directo en SQL sobre tablas de BC no invalida la caché del service tier; BC sigue devolviendo el valor viejo

Escribir directo en las tablas de BC con el service tier corriendo —que es como se hacen casi todas las migraciones de este proyecto— **no invalida la caché del servidor**. BC sigue devolviendo el valor que leyó antes, por horas.

**Afecta a los `UPDATE`, no a los `INSERT`.** Una fila nueva no tiene versión previa que cachear, así que las cargas masivas entran bien. El problema es cambiar filas que BC ya leyó.

**Por qué:** no hay error ni síntoma en la base. Verificás el dato por SQL, está correcto, y la pantalla muestra otra cosa. Se confunde con un bug de la aplicación y se busca en el lugar equivocado. Pasó con `Columna Hist. Meta4`: cambié el concepto de `PROD_NTA_CAE` de 1343 a 2498 por SQL, la página del catálogo mostraba 2498 y el drilldown seguía comparando contra 1343.

**Cómo distinguirlo de un defecto real:** mirar `$systemModifiedBy` de la fila. Si es el GUID cero, la escribió un SQL externo y la caché puede estar rancia; si es un usuario, la escribió BC y la caché está al día.

```sql
SELECT [$systemModifiedBy], [$systemModifiedAt] FROM <tabla> WHERE <clave>;
-- 00000000-0000-0000-0000-000000000000 = lo escribió SQL por fuera
```

**Cómo aplicarlo:** después de una tanda de `UPDATE` directos, **reiniciar el service tier** antes de probar nada en la interfaz, y avisarle al usuario que lo haga. Si no se puede reiniciar, tocar la fila desde una página de BC fuerza la relectura de esa fila sola.

Lo más peligroso no es lo que se ve en pantalla sino **la configuración que lee el motor**: filtros de Fuente de Datos, vigencias, parámetros. Un filtro actualizado por SQL que el motor tiene cacheado hace que una fórmula siga dando el resultado viejo sin avisar — ver [[fuente-datos-apunta-por-numero]] y [[previsualizar-antes-de-migrar]].

**El control definitivo para fórmulas de concepto:** la línea guarda `Fórmula Aplicada`, que es el texto que el motor efectivamente ejecutó. Compararla contra `Fórmula` del concepto separa en un solo query "está mal configurado" de "la caché está rancia" — sin adivinar.

```sql
-- conceptos cuya última línea calculada NO coincide con la fórmula almacenada
WITH ult AS (SELECT l.[Cód_ Concepto] cpt, l.[Fórmula Aplicada] ap,
             ROW_NUMBER() OVER (PARTITION BY l.[Cód_ Concepto] ORDER BY l.timestamp DESC) rn
             FROM [<empresa>$Línea Liquidación$<ext>] l WHERE l.[Fórmula Aplicada] <> '')
SELECT u.cpt FROM ult u JOIN [<empresa>$Concepto Liquidación$<ext>] c ON c.[Código]=u.cpt
WHERE u.rn=1 AND CAST(u.ap AS nvarchar(max)) <> CAST(c.[Fórmula] AS nvarchar(max));
```

Pasó el 22/9/2026 con el cambio de `TC_COMPRADOR` a `TC_VENDEDOR`: los 20 conceptos tenían la fórmula nueva en la base y el motor ejecutó la vieja en 490 liquidaciones. Los cambios anteriores sí habían tomado porque hubo un publish en el medio — **publicar la extensión también refresca la caché**, así que el síntoma sólo aparece en los `UPDATE` posteriores al último publish.

Ojo con el atajo de leer `Detalle Variable Línea Liq.` para ver qué variable se usó: el motor no evalúa la rama no tomada de un `IF`, así que una variable que sólo aparece en la rama falsa **no deja fila**. Ahí la ausencia no prueba nada; `Fórmula Aplicada` sí.

**Otro riesgo del INSERT por SQL: los tipos que no son lo que parecen.** Un `0` en una columna `DateFormula` se inserta sin quejarse y envenena la fila: BC falla al LEERLA, con un mensaje que no nombra ni la tabla ni el campo.

```
La fórmula de fecha "0" debe contener una unidad de tiempo.
Las unidades de tiempo pueden ser: D, DS, S, M, T o A.
```

Pasó el 23/9/2026 insertando dos filas en `Parámetro`: el campo 7 es `Antigüedad Máxima Vigencia`, DateFormula, y las filas existentes lo tienen en cadena vacía. El error salió al calcular, sin pista de dónde. Antes de un INSERT a mano conviene mirar los tipos en el AL —`DateFormula`, `Duration`, `Media`— y copiar lo que tienen las filas que ya funcionan en vez de poner `0` por descarte.

## Relacionado

- [[linked-server-leer-escalar-remoto]]
- [[sql-ares-dos-collations]]
- [[sql-dinamico-truncado-4000]]
- [[subconsulta-correlacionada-silenciosa]]
- Tema: `sql-bc-infra` (ver [[_Convenciones del vault]])
