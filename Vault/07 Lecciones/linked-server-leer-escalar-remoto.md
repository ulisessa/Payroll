---
aliases: ["Leer un escalar remoto por linked server"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, reference]
actualizado: 2026-10-04
---

# Leer un escalar remoto por linked server

**En una frase:** Leer un escalar de otra base por linked server sin MSDTC y sin depender del catálogo — sp_executesql con nombre de cuatro partes

Para traer **un valor escalar** de una base remota por linked server hay tres caminos y dos son
trampa. Salió de leer `min_active_rowversion()` de Navision (ARES) desde BC (mimir), 11/9/2026:

- `INSERT INTO #t EXEC ('...') AT [srv]` → el resultado vuelve dentro de la transacción y SQL Server
  lo promueve a **transacción distribuida**. Pide MSDTC habilitado y con acceso de red en los dos
  servidores; si no: *"The partner transaction manager has disabled its support for remote/network
  transactions"*.
- `OPENQUERY(srv, '...')` → no necesita MSDTC, pero **corre en el catálogo por defecto del linked
  server** y no admite `USE`. Para una función por base como `min_active_rowversion()` eso significa
  que si el catálogo no está puesto —lo habitual— el número sale de otra base. No falla: da un valor
  plausible y equivocado. Y el catálogo **no se puede cambiar con `sp_serveroption`**: hay que
  recrear el linked server, y eso se lleva puesto el mapeo de login.
- **El que sirve:** llamar al `sp_executesql` del ORIGEN con nombre de cuatro partes.

```sql
DECLARE @RpcSp nvarchar(400) = QUOTENAME(@Servidor) + N'.' + QUOTENAME(@BaseNAV) + N'.sys.sp_executesql';
EXEC @RpcSp N'SELECT @t = CONVERT(bigint, min_active_rowversion()) - 1;', N'@t bigint OUTPUT', @t = @Techo OUTPUT;
```

La base queda **fijada en el nombre**, no en una opción invisible; el valor vuelve por `OUTPUT`, que
no es `INSERT ... EXEC` y por lo tanto **no promueve a transacción distribuida**. Lo único que pide
es `rpc out` en true (`sp_serveroption`, una línea, sin recrear nada) y que el login remoto tenga
`VIEW DATABASE STATE` además de `db_datareader`.

Implementado en `scripts/SincronizarNAV_2013R2.sql`, paso 5.2.

Relacionado: [[sql-ares-dos-collations]], [[ares-topologia-bc]].

## Relacionado

- [[sql-ares-dos-collations]]
- [[sql-dinamico-truncado-4000]]
- [[sql-directo-deja-cache-rancia]]
- [[subconsulta-correlacionada-silenciosa]]
- Tema: `sql-bc-infra` (ver [[_Convenciones del vault]])
