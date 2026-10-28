---
aliases: ["Meta4 es Oracle"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, reference]
actualizado: 2026-10-04
---

# Meta4 es Oracle

**En una frase:** Meta4 corre en Oracle, no en SQL Server; no hay linked server ni provider para llegarle desde BC

Meta4 es **Oracle**: `m4-vm.arbumasa.net.ar:1521`, SID `Meta4`. No es una base de SQL
Server, así que BRAGI no es el camino para leerla.

Al 18/9/2026 **no hay ninguna vía desde BC**:

- mimir y BRAGI no tienen linked server a Meta4, y ninguno de los dos tiene provider de
  Oracle (`sp_enum_oledb_providers` no lista `OraOLEDB`; sólo SQLOLEDB, SQLNCLI11,
  MSOLEDBSQL y MSDASQL).
- La estación de trabajo no tiene cliente Oracle, ni driver ODBC de Oracle.
- El único JDBC disponible es el `ojdbc11-23.2.0.0.jar` que bajó DBeaver a
  `%APPDATA%\DBeaverData\drivers\maven\maven-central\`, pero no hay JDK para compilarle
  un cliente: el JRE de DBeaver trae `java.sql` y `java.compiler` (la API) pero **no**
  `jdk.compiler` (javac), así que ni `java Foo.java` ni `ToolProvider` sirven.

**Cómo aplicarlo:** las consultas contra Meta4 se corren a mano en DBeaver y se exportan a
CSV. Ver `scripts/ExplorarPuestosMeta4.sql`. Si alguna vez hace falta automatizarlo, la
pieza que falta es transporte —cliente Oracle o un JDK— no credenciales.

Ojo con el doble salto: desde sqlcmd a mimir y de ahí a BRAGI, la credencial se pierde
(`Login failed for user 'NT AUTHORITY\ANONYMOUS LOGON'`). Conectarse **directo** al
servidor que tiene el linked server. Ver [[ares-topologia-bc]] y
[[linked-server-leer-escalar-remoto]].

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
