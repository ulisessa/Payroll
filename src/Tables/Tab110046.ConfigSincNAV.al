namespace UAS.Payroll;

using System.Environment;

table 110046 "Config Sinc NAV"
{
    Caption = 'Configuración Sincronización NAV';
    DataClassification = CustomerContent;
    DataPerCompany = false;
    LookupPageId = "Config Sinc NAV";
    DrillDownPageId = "Config Sinc NAV";
    // Dónde está el origen y a qué empresa de BC le corresponde. Una fila por par de empresas.
    //
    // DataPerCompany = false, y no es un detalle: sin prefijo de empresa, la tabla se llama en SQL
    // 'Config Sinc NAV$<AppId>' y el procedimiento la encuentra con un LIKE, sin saber de antemano
    // en qué empresa buscar. Si fuera por empresa habría que decirle al script cuál es la empresa
    // para poder leer... la tabla que dice cuál es la empresa. La configuración de una integración
    // es de la instalación, no de cada empresa.
    //
    // Lo único que NO está acá son las credenciales del linked server: usuario y contraseña se
    // definen una vez con sp_addlinkedsrvlogin y no van en una tabla que se ve desde la interfaz.
    // Acá va el NOMBRE del linked server, que es la etiqueta con la que SQL lo conoce.

    fields
    {
        field(1; "Empresa BC"; Text[30])
        {
            Caption = 'Empresa en BC';
            DataClassification = CustomerContent;
            TableRelation = Company.Name;
            NotBlank = true;
            // Tiene que ser el nombre exacto de la empresa: es el prefijo con el que BC nombra sus
            // tablas en SQL, y el procedimiento lo usa para encontrar las tablas de staging.
        }
        field(10; "Empresa NAV"; Text[30])
        {
            Caption = 'Empresa en NAV (prefijo SQL)';
            DataClassification = CustomerContent;
            NotBlank = true;
            // Puede no llamarse igual que en BC. Es el prefijo de las tablas en la base de NAV:
            // si allá las tablas son 'Grupo Arbumasa$Job', acá va 'Grupo Arbumasa'.
            //
            // Y NO es el nombre lindo de la empresa. NAV reemplaza los caracteres que no valen como
            // identificador de SQL, así que "Arbumasa S.A." se convierte en "Arbumasa S_A_", con los
            // puntos hechos guiones bajos. Poner el nombre con puntos no da un error que lo explique:
            // da "Invalid object name", el mismo mensaje que aparece cuando falta un permiso, y manda
            // a revisar permisos que están bien. El bloque 3 del script de sincronización lista los
            // prefijos que existen de verdad en el origen — de ahí sale el valor, tal cual.
        }
        field(11; "Linked Server"; Text[128])
        {
            Caption = 'Linked Server';
            DataClassification = CustomerContent;
            NotBlank = true;
            // El nombre con que se creó el linked server en el servidor de BC (el @server de
            // sp_addlinkedserver), no el host de NAV. Suelen coincidir y no tienen por qué.
        }
        field(12; "Base NAV"; Text[128])
        {
            Caption = 'Base de Datos NAV';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(20; "Tabla Empleado"; Text[128])
        {
            Caption = 'Tabla Empleado (origen)';
            DataClassification = CustomerContent;
            // Los cuatro nombres de tabla están acá y no fijos en el script porque NAV los transforma
            // al crear las columnas: el punto, la barra y el apóstrofo se vuelven guión bajo. Los
            // valores por defecto son los esperados; el paso 3 del script los confirma contra la
            // base real, y si alguno no coincide se corrige acá sin tocar SQL.
        }
        field(21; "Tabla Proyecto"; Text[128])
        {
            Caption = 'Tabla Proyecto (origen)';
            DataClassification = CustomerContent;
        }
        field(22; "Tabla Descarga Cab"; Text[128])
        {
            Caption = 'Tabla Descarga Cabecera (origen)';
            DataClassification = CustomerContent;
        }
        field(23; "Tabla Descarga Lin"; Text[128])
        {
            Caption = 'Tabla Descarga Líneas (origen)';
            DataClassification = CustomerContent;
        }
        field(24; "Tabla Valor Dimension"; Text[128])
        {
            Caption = 'Tabla Valor de Dimensión (origen)';
            DataClassification = CustomerContent;
            // De acá salen los buques y las mareas que BC todavía no conoce. Se trae sólo lo que
            // usan las tres dimensiones que la sincronización aplica sobre el proyecto; el resto del
            // catálogo de NAV (CARPETA IMPORTACION y compañía) no tiene por qué cruzar.
        }
        field(35; Transporte; Enum "Transporte Sinc NAV")
        {
            Caption = 'Transporte';
            DataClassification = CustomerContent;
            // Se puede cambiar y volver atrás: los dos transportes llenan las mismas tablas de
            // staging y el que aplica sobre las tablas reales es el mismo en los dos casos.
        }
        field(41; "URL Base NAV"; Text[250])
        {
            Caption = 'URL Base OData (NAV)';
            DataClassification = CustomerContent;
            // Hasta ODataV4 inclusive, SIN la empresa y sin barra final. Ejemplo:
            //   https://nav.arbumasa.com:7049/NavisionWS/ODataV4
            //
            // Ojo con el puerto y el nombre de instancia: NO es el de producción. El HttpClient de
            // AL no habla NTLM, así que esto tiene que apuntar a una SEGUNDA instancia de service
            // tier sobre la misma base, configurada con NavUserPassword. La de producción queda
            // como está y ningún usuario de NAV cambia su forma de entrar.
            //
            // Y va V4, no V3: sobre las Query de NAV el V3 devuelve 400 ante un $top y sólo
            // contesta con $filter. El V4 pagina bien y devuelve JSON.
        }
        field(42; "Empresa OData"; Text[100])
        {
            Caption = 'Empresa en la URL de OData';
            DataClassification = CustomerContent;
            // El nombre LINDO de la empresa, con puntos y espacios: 'Arbumasa S.A.'. No el prefijo
            // SQL con guiones bajos — ése es otro campo y otra cosa. La codificación para la URL la
            // hace el cliente, acá va tal como se lee.
        }
        field(43; "Usuario WS"; Text[100])
        {
            Caption = 'Usuario de NAV para Web Services';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(44; "Clave WS Cargada"; Boolean)
        {
            Caption = 'Clave cargada';
            DataClassification = SystemMetadata;
            Editable = false;
            // La clave de acceso a web services NO se guarda acá. Vive en Isolated Storage, que es
            // el único lugar de BC del que un secreto no sale por una exportación de datos, un
            // paquete de configuración ni una página. Este campo es sólo la luz de "ya está puesta",
            // para que la ficha diga algo sin revelar nada.
        }
        field(45; "Entidad Proyectos"; Text[100])
        {
            Caption = 'Entity set de Proyectos';
            DataClassification = CustomerContent;
            // Los nombres de los entity sets son de la instalación, igual que los nombres de tabla
            // del transporte por SQL: los eligió quien publicó el web service en NAV y no hay una
            // convención que los haga predecibles.
        }
        field(46; "Entidad Descargas"; Text[100])
        {
            Caption = 'Entity set de Descargas';
            DataClassification = CustomerContent;
            // Una sola entidad para las DOS tablas de staging: la Query de NAV devuelve cabecera y
            // línea juntas en una fila plana, y el traedor la parte en dos.
        }
        field(47; "Entidad Change Log"; Text[100])
        {
            Caption = 'Entity set del Change Log';
            DataClassification = CustomerContent;
            // El reloj de todo el transporte por web services. Sin esto no hay forma de saber qué
            // cambió: OData no expone el rowversion.
        }
        field(48; "Entidad Empleados"; Text[100])
        {
            Caption = 'Entity set de Empleados';
            DataClassification = CustomerContent;
            // Tiene que estar publicado sobre la FICHA del empleado, no sobre la lista: OData expone
            // sólo los campos que la página MUESTRA, y la lista no muestra fecha de ingreso,
            // domicilio ni número de seguridad social. Sin fecha de ingreso no se abre la fase de
            // alta y la antigüedad da cero.
            //
            // Vacío significa que esta entidad no se trae por este transporte.
        }
        field(49; "Entidad Valores Dim"; Text[100])
        {
            Caption = 'Entity set de Valores de Dimensión';
            DataClassification = CustomerContent;
            // Pesa más de lo que parece: sin valores de dimensión, una marea nueva hace fallar su
            // propio proyecto al aplicarse.
        }
        field(50; "Tabla NAV Proyecto"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Proyecto';
            DataClassification = CustomerContent;
            // Los números de tabla del ORIGEN, que es como el Change Log identifica qué cambió. No
            // tienen nada que ver con los números de BC: acá 167 es Job y 349 es Dimension Value,
            // igual que en NAV. Los dos de descargas (50561 y 50562) son de la personalización.
            //
            // Van configurables por la misma razón que los nombres de tabla del transporte por SQL:
            // el día que no coincidan, se corrigen sin tocar código.
        }
        field(51; "Tabla NAV Empleado"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Empleado';
            DataClassification = CustomerContent;
        }
        field(52; "Tabla NAV Descarga Cab"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Descarga Cabecera';
            DataClassification = CustomerContent;
        }
        field(53; "Tabla NAV Descarga Lin"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Descarga Líneas';
            DataClassification = CustomerContent;
        }
        field(54; "Tabla NAV Valor Dim"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Valor de Dimensión';
            DataClassification = CustomerContent;
        }
        field(55; "Entidad Informe Cap Cab"; Text[100])
        {
            Caption = 'Entity set de Informe Capitán - Cabecera';
            DataClassification = CustomerContent;
            // A diferencia de las descargas, el informe del capitán viene en DOS entity sets: uno de
            // cabecera y otro de líneas. No hay una Query que los junte, así que son dos pedidos.
        }
        field(56; "Entidad Informe Cap Lin"; Text[100])
        {
            Caption = 'Entity set de Informe Capitán - Líneas';
            DataClassification = CustomerContent;
        }
        field(57; "Tabla NAV Informe Cap Cab"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Informe Capitán Cabecera';
            DataClassification = CustomerContent;
        }
        field(58; "Tabla NAV Informe Cap Lin"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Informe Capitán Líneas';
            DataClassification = CustomerContent;
        }
        field(59; "Entidad Dia Abordo Cab"; Text[100])
        {
            Caption = 'Entity set de Diario de Abordo - Cabecera';
            DataClassification = CustomerContent;
        }
        field(60; "Entidad Dia Abordo Lin"; Text[100])
        {
            Caption = 'Entity set de Diario de Abordo - Líneas';
            DataClassification = CustomerContent;
            // El que trae la producción por día. Es la única fuente con esa granularidad.
        }
        field(61; "Tabla NAV Dia Abordo Cab"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Diario de Abordo Cabecera';
            DataClassification = CustomerContent;
        }
        field(62; "Tabla NAV Dia Abordo Lin"; Integer)
        {
            Caption = 'N.º de tabla en NAV - Diario de Abordo Líneas';
            DataClassification = CustomerContent;
        }
        field(30; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
            // Destildarlo saca a esta empresa de la corrida sin borrar la configuración ni tocar el
            // job del Agent, que recorre solamente las activas.
        }
    }

    keys
    {
        key(PK; "Empresa BC") { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Empresa BC", "Empresa NAV", "Linked Server") { }
    }

    trigger OnInsert()
    begin
        PonerNombresPorDefecto();
    end;

    /// <summary>
    /// Completa los nombres de tabla del origen que estén en blanco con los esperados de la
    /// personalización de NAV convertida. No pisa lo que ya esté cargado.
    /// </summary>
    procedure PonerNombresPorDefecto()
    begin
        if "Tabla Empleado" = '' then
            "Tabla Empleado" := 'Employee';
        if "Tabla Proyecto" = '' then
            "Tabla Proyecto" := 'Job';
        if "Tabla Descarga Cab" = '' then
            "Tabla Descarga Cab" := 'Cab_ descarga';
        if "Tabla Descarga Lin" = '' then
            "Tabla Descarga Lin" := 'Lín_ descarga';
        if "Tabla Valor Dimension" = '' then
            "Tabla Valor Dimension" := 'Dimension Value';

        // Los tres que SÍ están publicados hoy en NAV. Empleados y Valores de Dimensión quedan en
        // blanco porque no existen todavía como web service, y en blanco significa "no se trae por
        // este transporte": mejor que un nombre inventado que dé 404 en cada corrida.
        if "Entidad Proyectos" = '' then
            "Entidad Proyectos" := 'ListaProyectos';
        if "Entidad Descargas" = '' then
            "Entidad Descargas" := 'DetalleDescargas';
        if "Entidad Change Log" = '' then
            "Entidad Change Log" := 'MovRegistroCambios';

        // Números de tabla DEL ORIGEN, que es como el Change Log identifica qué cambió. 167 es Job,
        // 5200 Employee y 349 Dimension Value en el NAV estándar; 50561 y 50562 son las descargas de
        // la personalización.
        if "Tabla NAV Proyecto" = 0 then
            "Tabla NAV Proyecto" := 167;
        if "Tabla NAV Empleado" = 0 then
            "Tabla NAV Empleado" := 5200;
        if "Tabla NAV Valor Dim" = 0 then
            "Tabla NAV Valor Dim" := 349;
        if "Tabla NAV Descarga Cab" = 0 then
            "Tabla NAV Descarga Cab" := 50561;
        if "Tabla NAV Descarga Lin" = 0 then
            "Tabla NAV Descarga Lin" := 50562;

        if "Entidad Informe Cap Cab" = '' then
            "Entidad Informe Cap Cab" := 'CabInfoCap';
        if "Entidad Informe Cap Lin" = '' then
            "Entidad Informe Cap Lin" := 'LinInfoCap';
        if "Tabla NAV Informe Cap Cab" = 0 then
            "Tabla NAV Informe Cap Cab" := 50559;
        if "Tabla NAV Informe Cap Lin" = 0 then
            "Tabla NAV Informe Cap Lin" := 50560;

        if "Entidad Dia Abordo Cab" = '' then
            "Entidad Dia Abordo Cab" := 'CabDiaAbordo';
        if "Entidad Dia Abordo Lin" = '' then
            "Entidad Dia Abordo Lin" := 'LinDiaAbordo';
        if "Tabla NAV Dia Abordo Cab" = 0 then
            "Tabla NAV Dia Abordo Cab" := 50501;
        if "Tabla NAV Dia Abordo Lin" = 0 then
            "Tabla NAV Dia Abordo Lin" := 50502;
    end;
}
