---
aliases: ["Campos de extensión en la tabla $ext"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-14
---

# Campos de extensión en la tabla $ext

Los campos de un tableextension sobre una tabla del base app viven en una tabla "$ext" nombrada por el id del BASE APP, con el id de la extensión como sufijo de cada columna

Un `tableextension` sobre una tabla del base app NO agrega columnas a la tabla base ni crea una
tabla con el id de nuestra extensión. Crea una compañera terminada en `$ext`, nombrada con el id
del **base app**, y cada columna lleva el id de la extensión que la agregó como **sufijo**:

```
[dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext]
    [Cód_ Convenio$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    [Cód_ Categoría$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
```

Buscar `ArbuTest$Employee$<id de nuestra extensión>` da "Invalid object name". Las tablas propias
de la extensión sí llevan nuestro id (`ArbuTest$Personal Proyecto$d4f5a6b7-...`); la asimetría es
entre tabla propia y extensión de tabla ajena.

Cómo encontrarla siempre:

```sql
SELECT t.name, c.name FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
WHERE t.name LIKE 'ArbuTest$Employee%';
```

En la misma `$ext` conviven campos de OTRAS extensiones sobre la misma tabla. En Employee, la
personalización Final Version (`a423950b-02e9-4ee0-ab32-61517ce330cb`) tiene su propio
`pat_Cod_ convenio` y `pat_ Categoría_Cargo_Rango` — son campos distintos de los nuestros y con el
mismo significado, así que un script que lea "el convenio" tiene que elegir cuál. El motor de
liquidación lee el nuestro. Ver [[migracion-atributos-cct-meta4]].

## Relacionado

- [[migracion-atributos-cct-meta4]]
- [[ares-topologia-bc]]
- [[conexion-sql-bc]]
- [[cuil-vive-en-cif-nif]]
