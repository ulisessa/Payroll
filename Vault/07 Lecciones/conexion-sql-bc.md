---
aliases: ["Conexión SQL de BC"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, reference]
actualizado: 2026-10-04
---

# Conexión SQL de BC

La base de BC es mimir / Migr2013R2; sqlcmd está en C:\Program Files\SqlCmd

La base de datos de BC 25.2 es **`Migr2013R2` en el servidor `mimir`** (el servicio BC
es `https://mimir.arbumasa.com/BC252`, instancia `BC252`). `bragi` es otro SQL Server,
con `Navision`/`Navision26`: no es donde vive BC.

`sqlcmd` (go-sqlcmd) está instalado en `C:\Program Files\SqlCmd\sqlcmd.exe` y **no está
en el PATH**. Se conecta con autenticación Windows:

    "/c/Program Files/SqlCmd/sqlcmd.exe" -S mimir -E -C -d "Migr2013R2" -W -s "|" -i consulta.sql

`-C` es obligatorio (confía en el certificado; sin eso no conecta). `bragi.arbumasa.com`
con FQDN falla por named pipes — usar el nombre corto.

**Por qué:** habilita correr los scripts de `scripts/` directamente en vez de pedirle al
usuario que los pegue en SSMS y devuelva la salida.

**Cómo aplicarlo:** los `SELECT` se corren sin preguntar; los `UPDATE`/`INSERT`/`DELETE`
se muestran primero, como pide [[previsualizar-antes-de-migrar]].

**Desde .NET hay que usar el FQDN `mimir.arbumasa.com`.** Con el nombre corto, `SqlClient`
pide Kerberos, el SPN no coincide y muere con *"El nombre principal no es correcto. No se puede
generar contexto SSPI"*. `sqlcmd` no se entera porque cae a NTLM — o sea que el mismo servidor
anda por sqlcmd y falla por PowerShell, y parece un problema de permisos cuando es de nombre.
`mimir.arbumasa.net.ar` tampoco sirve: el alias vive en `arbumasa.com` (ver [[ares-topologia-bc]]).

## Relacionado

- [[previsualizar-antes-de-migrar]]
- [[ares-topologia-bc]]
- [[campos-extension-tabla-ext]]
- [[cuil-vive-en-cif-nif]]
