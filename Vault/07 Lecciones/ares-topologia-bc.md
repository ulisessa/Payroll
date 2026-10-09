---
aliases: ["ARES: topología BC + SQL"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, project]
origen: 507bdbd7-78fd-4a75-8286-b6a7a9ecc332
actualizado: 2026-08-29
---

# ARES: topología BC + SQL

ARES aloja SQL y el service tier BC14 juntos; alias DNS en arbumasa.com pero dominio AD en arbumasa.net.ar, y qué se rompe por eso

Servidor **ARES** (`ARES.arbumasa.net.ar`, 192.168.90.6 en Ethernet0, 10.10.0.2 en Ethernet1). Corre **SQL Server 2022 y el service tier de Business Central 14 en la misma máquina** (instancia `Navision`, ruta `...\Business Central\140\Service\`). Puesto en marcha el 29/8/2026.

**El dominio AD es `arbumasa.net.ar`, pero todos los alias DNS viven en `arbumasa.com`:**

- `navdb.arbumasa.com` → ARES — alias por el que BC se conecta a SQL
- `nav.arbumasa.com` → ARES — alias de los servicios web (`PublicODataBaseUrl` y compañía)

**Por qué:** esa discrepancia de sufijos es la raíz de casi todos los problemas de autenticación acá. Kerberos busca SPN por el nombre usado en la conexión, y los alias no coinciden con el FQDN real de la máquina, así que todo SPN hay que registrarlo a mano sobre `ARES$`.

**Cómo aplicarlo:**

- **SPN de SQL:** `MSSQLSvc/navdb.arbumasa.com` (con y sin `:1433`) van sobre la cuenta de equipo `ARES$`. Sin eso la conexión cae a NTLM. Verificar con `setspn -L ARES` y con `SELECT auth_scheme FROM sys.dm_exec_connections WHERE session_id=@@SPID` conectando a `tcp:navdb.arbumasa.com` (por memoria compartida siempre dice NTLM y no prueba nada).
- **El service tier corre como `NETWORK SERVICE`**, o sea que ante SQL se presenta como `ARBUMASA\ARES$`. Ese es el login que necesita permisos en la base, no una cuenta de usuario. Pendiente pasarlo a una cuenta de dominio dedicada — y ahí los SPN dejan de auto-registrarse y hay que crearlos a mano.
- **URL ACL reservadas en la raíz del puerto**, no por ruta: `https://+:7047/`, `https://+:7048/`, `http://+:7049/`, todas a `NT AUTHORITY\NETWORK SERVICE`. Reservar rutas puntuales (`/Navision/`, `/Navision/OData/`) no funciona: BC administra sus propias reservas al iniciar y detenerse, y se lleva puestas las manuales en cada arranque fallido. El 7046 es net.tcp y no lleva reserva.
- **Certificado wildcard `CN=*.arbumasa.com`**, thumbprint `B300A55A269C5906D7061EC9F345359150C11FF1`, **vence el 4/12/2026**. Tiene que estar atado en HTTP.SYS a 443, **7047 y 7048** (`netsh http add sslcert`). Si falta el binding de un puerto, HTTP.SYS resetea el handshake y el navegador muestra `PR_CONNECT_RESET_ERROR` — no un error de certificado, lo que despista. Al renovarlo hay que reatarlo a los tres puertos. El wildcard **no** cubre `ARES.arbumasa.net.ar`.

**Lección de higiene:** los SPN de BC estaban registrados sobre `admdario`, una cuenta personal de administrador, de una instalación anterior. Eso hacía fallar el registro con error **8647** (`SPN_VALUE_NOT_UNIQUE_IN_FOREST`), que el mensaje de BC reporta como si fuera falta de permisos. Cuando algo falla al registrar SPN, mirar primero `setspn -Q <spn>` antes de tocar permisos.

Relacionado: [[sql-ares-dos-collations]].

## Relacionado

- [[sql-ares-dos-collations]]
- [[campos-extension-tabla-ext]]
- [[conexion-sql-bc]]
- [[cuil-vive-en-cif-nif]]
