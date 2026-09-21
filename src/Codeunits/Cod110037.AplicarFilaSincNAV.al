namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;
using Microsoft.Finance.Dimension;

/// <summary>
/// Aplica UNA fila de staging sobre la tabla real. Nunca se llama directo: el orquestador lo corre
/// con Run() para que una fila mala deje su error anotado y el lote siga.
/// </summary>
/// <remarks>
/// No tiene TableNo a propósito. Las cinco entidades viven en cinco tablas distintas y un TableNo
/// sólo puede apuntar a una; el contexto entra por SetContexto y el Run() se hace sobre la instancia.
/// El orquestador hace Clear() antes de cada uso, así que no hay estado que sobreviva entre filas.
///
/// La regla de qué se escribe con Validate y qué por asignación directa no es estética:
///   · Campos base de Job y Employee → Validate, porque ahí está la lógica que importa (las
///     dimensiones globales del proyecto se materializan en Default Dimension dentro del OnValidate).
///   · Campos de "Job Ext." (la extensión Tables Only convertida de NAV) → asignación directa. Son
///     datos planos de otra extensión sobre los que este módulo no manda; validarlos sería ejecutar
///     lógica ajena en un proceso desatendido.
/// </remarks>
codeunit 110037 "Aplicar Fila Sinc NAV"
{
    Access = Internal;

    var
        EntidadCtx: Enum "Entidad Sinc NAV";
        ClaveCode: Code[20];
        ClaveInt: Integer;
        ClaveCode2: Code[20];
        CodEstadoAlta: Code[20];
        Aviso: Text;
        TxtDimensionInexistente: Label 'La dimensión %1 no existe en BC, así que no se puede crear su valor %2. Crear una dimensión es una decisión de configuración contable y la sincronización no la toma sola.', Comment = '%1 = código de dimensión; %2 = código de valor';
        TxtNombreDistinto: Label 'El valor ya existía y se dejó como está. En BC se llama "%1" y en NAV "%2".', Comment = '%1 = nombre en BC; %2 = nombre en NAV';
        TxtSinFechaIngreso: Label 'Se creó el empleado, pero NAV no trajo fecha de ingreso: no se abrió la fase de alta y la antigüedad no se puede calcular hasta cargarla a mano.';

    /// <summary>
    /// El contexto de la fila a aplicar. Las claves compuestas entran por la segunda mitad que
    /// corresponda: las líneas de descarga usan Clave2 (entero) y los valores de dimensión usan
    /// Clave3 (código). Las entidades de clave simple pasan 0 y '' respectivamente.
    /// </summary>
    procedure SetContexto(Entidad: Enum "Entidad Sinc NAV"; Clave1: Code[20]; Clave2: Integer; CodAlta: Code[20]; Clave3: Code[20])
    begin
        EntidadCtx := Entidad;
        ClaveCode := Clave1;
        ClaveInt := Clave2;
        ClaveCode2 := Clave3;
        CodEstadoAlta := CodAlta;
        Aviso := '';
    end;

    /// <summary>
    /// Lo que la fila dejó dicho aunque se haya aplicado bien. Sólo tiene sentido leerlo después de
    /// un Run() exitoso: si el Run falló, la fila no se aplicó y lo que hay que mirar es el error.
    /// </summary>
    procedure GetAviso(): Text
    begin
        exit(Aviso);
    end;

    trigger OnRun()
    begin
        case EntidadCtx of
            EntidadCtx::"Valor Dimension":
                AplicarValorDimension();
            EntidadCtx::Empleado:
                AplicarEmpleado();
            EntidadCtx::Proyecto:
                AplicarProyecto();
            EntidadCtx::"Descarga Cabecera":
                AplicarDescargaCab();
            EntidadCtx::"Descarga Linea":
                AplicarDescargaLin();
            EntidadCtx::"Informe Cap Cabecera":
                AplicarInformeCapCab();
            EntidadCtx::"Informe Cap Linea":
                AplicarInformeCapLin();
            EntidadCtx::"Dia Abordo Cabecera":
                AplicarDiaAbordoCab();
            EntidadCtx::"Dia Abordo Linea":
                AplicarDiaAbordoLin();
        end;
    end;

    local procedure AplicarDiaAbordoCab()
    var
        Stg: Record "Stg Dia Abordo Cab NAV";
        Cab: Record "On board capture";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode);

        EsAlta := not Cab.Get(Stg."No Proyecto");
        if EsAlta then begin
            Cab.Init();
            Cab."Cód. Proyecto" := Stg."No Proyecto";
        end;

        Cab.Buque := Stg.Buque;
        Cab.Marea := Stg.Marea;
        Cab."Patrón" := CopyStr(Stg.Patron, 1, MaxStrLen(Cab."Patrón"));
        Cab."Fecha Salida" := Stg."Fecha Salida";
        Cab."Histórico" := Stg.Historico;

        // "Zona de pesca" NO se escribe: allá es un campo de opción y acá llega su caption. Traducir
        // una caption a su ordinal sin haber mirado el OptionMembers real es exactamente cómo el Tipo
        // del proyecto terminó en blanco y las descargas fallaron con un mensaje que hablaba de otra
        // cosa. El texto queda en el staging por si alguien lo necesita.

        if EsAlta then
            Cab.Insert(true)
        else
            Cab.Modify(true);
    end;

    local procedure AplicarDiaAbordoLin()
    var
        Stg: Record "Stg Dia Abordo Lin NAV";
        Lin: Record "On board capture lines";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode, ClaveInt);

        EsAlta := not Lin.Get(Stg."No Proyecto", Stg."Line No");
        if EsAlta then begin
            Lin.Init();
            Lin."Cód. proyecto" := Stg."No Proyecto";
            Lin."No. Línea" := Stg."Line No";
        end;

        Lin."Fecha registro" := Stg."Fecha Registro";
        Lin.Concepto := Stg.Concepto;
        Lin."No." := Stg.Producto;
        Lin."Descripción" := CopyStr(Stg.Descripcion, 1, MaxStrLen(Lin."Descripción"));
        Lin.Cantidad := Stg.Cantidad;
        Lin.Kilos := Stg.Kilos;

        if EsAlta then
            Lin.Insert(true)
        else
            Lin.Modify(true);
    end;

    /// <summary>
    /// La cabecera del informe del capitán de una marea.
    /// </summary>
    /// <remarks>
    /// Igual que en las descargas: los campos se llenan ANTES del Insert. El OnInsert de estas
    /// tablas convertidas de NAV valida campos propios, y con la fila vacía rechaza con un mensaje
    /// que señala un campo que el staging sí tiene cargado.
    ///
    /// Buque y Marea NO se escriben: la página publicada en NAV no los expone, y no se deducen —
    /// están en el proyecto, que es la clave de esta misma fila. Si el día de mañana hacen falta acá,
    /// se agregan a la página de NAV y son un campo en tres lugares.
    /// </remarks>
    local procedure AplicarInformeCapCab()
    var
        Stg: Record "Stg Informe Cap Cab NAV";
        Cab: Record "Cab. informe capitán";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode);

        EsAlta := not Cab.Get(Stg."No Proyecto");
        if EsAlta then begin
            Cab.Init();
            Cab."No. proyecto" := Stg."No Proyecto";
        end;

        Cab."Capitán" := CopyStr(Stg.Capitan, 1, MaxStrLen(Cab."Capitán"));
        Cab.Actividad := Stg.Actividad;
        Cab."Fecha de inicio de descarga" := Stg."Fecha Inicio Descarga";

        // Cantidad no se escribe: en NAV es un FlowField, la suma de las líneas. Escribirlo sería
        // guardar un total que deja de coincidir con su propio detalle en cuanto cambie una línea.

        if EsAlta then
            Cab.Insert(true)
        else
            Cab.Modify(true);
    end;

    local procedure AplicarInformeCapLin()
    var
        Stg: Record "Stg Informe Cap Lin NAV";
        Lin: Record "Lín. informe capitán";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode, ClaveInt);

        EsAlta := not Lin.Get(Stg."No Proyecto", Stg."Line No");
        if EsAlta then begin
            Lin.Init();
            Lin."No. proyecto" := Stg."No Proyecto";
            Lin."No. línea" := Stg."Line No";
        end;

        Lin."Clasificación" := Stg.Clasificacion;
        Lin."Descripción" := CopyStr(Stg.Descripcion, 1, MaxStrLen(Lin."Descripción"));
        Lin."Unidad medida" := Stg."Unidad Medida";
        Lin.Cantidad := Stg.Cantidad;

        if EsAlta then
            Lin.Insert(true)
        else
            Lin.Modify(true);
    end;

    /// <summary>
    /// Da de alta en BC un valor de dimensión que vino de NAV. Si ya existe, no lo toca.
    /// </summary>
    /// <remarks>
    /// NO ACTUALIZA LOS QUE YA ESTÁN, y es una decisión, no un olvido. NAV es el origen de los
    /// códigos NUEVOS —una marea que todavía no existía—, pero el nombre que se ve todos los días es
    /// el de BC, y ahí se corrigen las cosas: en NAV conviven "HAI XIANG 16" con "HAI XIANG" para el
    /// buque siguiente, y "Vistoria II" por Victoria. Pisar el nombre en cada corrida devolvería esos
    /// errores una y otra vez sobre lo que alguien ya arregló.
    /// </remarks>
    local procedure AplicarValorDimension()
    var
        Stg: Record "Stg Valor Dim NAV";
        Dim: Record Dimension;
        DimVal: Record "Dimension Value";
    begin
        Stg.Get(ClaveCode, ClaveCode2);

        // Sin la dimensión no hay dónde colgar el valor, y crearla sería otra decisión: una
        // dimensión nueva en BC toca la configuración contable, no el catálogo de una marea.
        if not Dim.Get(Stg."Cod Dimension") then
            Error(TxtDimensionInexistente, Stg."Cod Dimension", Stg.Codigo);

        if DimVal.Get(Stg."Cod Dimension", Stg.Codigo) then begin
            if DimVal.Name <> Stg.Nombre then
                Aviso := StrSubstNo(TxtNombreDistinto, DimVal.Name, Stg.Nombre);
            exit;
        end;

        DimVal.Init();
        DimVal.Validate("Dimension Code", Stg."Cod Dimension");
        DimVal.Validate(Code, Stg.Codigo);
        DimVal.Validate(Name, CopyStr(Stg.Nombre, 1, MaxStrLen(DimVal.Name)));
        // Un valor bloqueado en el origen se crea bloqueado: existe para que los movimientos
        // históricos lo encuentren, no para que alguien lo elija en un proyecto nuevo.
        DimVal.Validate(Blocked, Stg.Bloqueado);
        DimVal.Insert(true);
    end;

    local procedure AplicarEmpleado()
    var
        Stg: Record "Stg Empleado NAV";
        Empl: Record Employee;
        Fase: Record "Fase Alta Empleado";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode);
        EsAlta := not Empl.Get(Stg."No Empleado");
        if EsAlta then begin
            Empl.Init();
            Empl."No." := Stg."No Empleado";
            Empl.Insert(true);
        end;

        Empl.Validate("First Name", CopyStr(Stg.Nombre, 1, MaxStrLen(Empl."First Name")));
        Empl.Validate("Middle Name", CopyStr(Stg."Segundo Nombre", 1, MaxStrLen(Empl."Middle Name")));
        Empl.Validate("Last Name", CopyStr(Stg.Apellido, 1, MaxStrLen(Empl."Last Name")));
        Empl.Validate(Initials, CopyStr(Stg.Iniciales, 1, MaxStrLen(Empl.Initials)));
        Empl.Validate("Job Title", CopyStr(Stg."Puesto Titulo", 1, MaxStrLen(Empl."Job Title")));
        Empl.Validate("Social Security No.", CopyStr(Stg."No Seguridad Social", 1, MaxStrLen(Empl."Social Security No.")));
        Empl.Validate("Birth Date", Stg."Fecha Nacimiento");
        Empl.Validate(Address, CopyStr(Stg.Direccion, 1, MaxStrLen(Empl.Address)));
        Empl.Validate("Address 2", CopyStr(Stg."Direccion 2", 1, MaxStrLen(Empl."Address 2")));
        Empl.Validate(City, CopyStr(Stg.Ciudad, 1, MaxStrLen(Empl.City)));
        Empl.Validate("Post Code", CopyStr(Stg."Cod Postal", 1, MaxStrLen(Empl."Post Code")));
        Empl.Validate("Phone No.", CopyStr(Stg.Telefono, 1, MaxStrLen(Empl."Phone No.")));
        Empl.Validate("E-Mail", CopyStr(Stg.Email, 1, MaxStrLen(Empl."E-Mail")));
        // Campo de la extensión Tables Only; la importación de SIRADIG busca el CUIL acá además de
        // en "Social Security No.", así que se copian los dos tal como vengan.
        Empl."CIF/NIF" := CopyStr(Stg."CIF NIF", 1, MaxStrLen(Empl."CIF/NIF"));

        // "Employment Date" es un dato de la ficha; la antigüedad de verdad la da la FASE de alta,
        // que se abre unas líneas más abajo. Se completan los dos.
        if Stg."Fecha Ingreso" <> 0D then
            Empl.Validate("Employment Date", Stg."Fecha Ingreso");

        // Convenio, categoría y zona NO se tocan nunca, ni en el alta ni en la modificación: son
        // decisión de liquidación y no existen en NAV. El empleado queda con el convenio en blanco,
        // que es justo lo que filtra la vista "Pendientes de completar (Sinc.)" de la lista de
        // empleados: la marca de incompleto ya existe en el dato y no hace falta un campo aparte.
        Empl.Modify(true);

        if not EsAlta then
            exit;

        if Stg."Fecha Ingreso" = 0D then begin
            Aviso := TxtSinFechaIngreso;
            exit;
        end;

        // LA FASE, NO UN ESTADO. El alta dejó de ser una fila del historial operativo y pasó a ser
        // un tramo en "Fase Alta Empleado": el día que alguien ingresa y embarca, las dos cosas son
        // ciertas y en el historial sólo entraba una.
        //
        // AbrirFase devuelve false si ya hay una abierta, y eso protege el caso del empleado que ya
        // estaba —una migración previa, un alta cargada a mano—: la fase que ya existe vale más que
        // la que traería NAV, que no sabe de reingresos.
        Fase.AbrirFase(Empl."No.", Stg."Fecha Ingreso", CodEstadoAlta, '');
    end;

    local procedure AplicarProyecto()
    var
        Stg: Record "Stg Proyecto NAV";
        Job: Record Job;
    begin
        Stg.Get(ClaveCode);
        if not Job.Get(Stg."No Proyecto") then begin
            Job.Init();
            Job."No." := Stg."No Proyecto";
            Job.Insert(true);
        end;

        Job.Validate(Description, CopyStr(Stg.Descripcion, 1, MaxStrLen(Job.Description)));
        Job.Validate("Description 2", CopyStr(Stg."Descripcion 2", 1, MaxStrLen(Job."Description 2")));

        // LA FECHA DE ARRIBO SE LIMPIA ANTES DE TOCAR LA DE ZARPADA, y no es rebusque: BC valida que
        // la inicial no sea posterior a la final, y lo hace contra el valor que el proyecto TIENE en
        // ese momento, no contra el que va a tener. Un proyecto que ya existía en BC con una fecha de
        // arribo vieja rechaza la zarpada nueva —"Fecha inicial debe ser igual o anterior a Fecha
        // final"— aunque el par que viene de NAV sea perfectamente coherente. Vaciarla primero saca
        // del medio al valor viejo; la definitiva se escribe al final, con Validate, que es donde
        // corresponde que se dispare el cierre de la marea.
        //
        // Va por asignación directa y no por Validate: validar un blanco intermedio dispararía la
        // lógica de cierre dos veces, una de ellas con un valor que no es el real.
        Job."Ending Date" := 0D;

        Job.Validate("Starting Date", Stg."Fecha Inicio");
        // Las dimensiones van por Validate: el OnValidate de Job es el que crea o corrige la Default
        // Dimension. Asignarlas directo dejaría el proyecto con el código a la vista y sin dimensión
        // por defecto, que es la que después arrastra todo.
        //
        // La 3 es la actividad, y tiene campo propio: "Final Version Customization" agrega al Job los
        // campos 50000..50004 para las dimensiones 3 a 7, cada uno con su OnValidate que llama a
        // ValidateShortcutDimCode. O sea que escribir sólo la Default Dimension dejaba el campo
        // 50000 en blanco, y ese es el que leen los FlowFilters "Filtro actividad" de la propia
        // personalización y los informes que dependen de ellos: la
        // dimensión quedaba bien y el proyecto igual no aparecía filtrado por actividad.
        //
        // El campo es Code[10]; el staging lo trae Code[20] porque del lado de NAV es una dimensión
        // común. LAN y CAL entran, pero el CopyStr evita que un valor largo corte la fila con un
        // error de longitud en vez de decir qué pasó.
        Job.Validate("Global Dimension 1 Code", Stg.Buque);
        Job.Validate("Global Dimension 2 Code", Stg.Marea);
        Job.Validate("Global Dimension 3 Code", CopyStr(Stg.Actividad, 1, MaxStrLen(Job."Global Dimension 3 Code")));
        Job.Validate(Tipo, Stg."Tipo Proyecto");

        Job.Patron := CopyStr(Stg.Patron, 1, MaxStrLen(Job.Patron));
        Job."Hora de zarpada" := Stg."Hora Zarpada";
        Job."Hora ingreso a puerto" := Stg."Hora Ingreso Puerto";
        Job."Fecha llegada prevista" := Stg."Fecha Llegada Prevista";
        Job."Puerto zarpada" := Stg."Puerto Zarpada";
        Job."Puerto Descarga" := Stg."Puerto Descarga";
        Job."Year tide" := Stg."Anio Marea";

        // Última, y por Validate: pasar la fecha de arribo de vacía a cargada es cerrar la marea, y
        // el OnModify de "Proyecto Pesca Ext." cierra con ella las asignaciones de personal abiertas.
        // Si esa cadena falla, falla toda la fila y la marea no queda cerrada a medias.
        Job.Validate("Ending Date", Stg."Fecha Fin");

        Job.Modify(true);
    end;

    local procedure AplicarDescargaCab()
    var
        Stg: Record "Stg Descarga Cab NAV";
        Cab: Record "Cab. descarga";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode);

        // LOS CAMPOS SE LLENAN ANTES DEL INSERT, no después.
        //
        // "Cab. descarga" es de la personalización de NAV y su OnInsert exige Puerto. Insertando
        // primero y asignando después, el trigger corre con la fila vacía y rechaza: "Puerto debe
        // tener un valor... No puede ser cero ni estar vacío" — sobre una fila cuyo puerto está
        // perfectamente cargado en el staging, que es lo que hace el error incomprensible.
        //
        // Y el síntoma engaña dos veces, porque sólo falla en las descargas NUEVAS: las que ya
        // existían entran por Get y nunca ejecutan el OnInsert. De 2957 cabeceras fallaban 148 —las
        // nuevas— y parecía un problema de datos de esas 148.
        EsAlta := not Cab.Get(Stg."No Proyecto");
        if EsAlta then begin
            Cab.Init();
            Cab."No. proyecto" := Stg."No Proyecto";
        end;

        Cab."Capitán" := CopyStr(Stg.Capitan, 1, MaxStrLen(Cab."Capitán"));
        Cab.Actividad := Stg.Actividad;
        Cab."Fecha de inicio de descarga" := Stg."Fecha Inicio Descarga";
        Cab.Buque := Stg.Buque;
        Cab.Marea := Stg.Marea;
        Cab.Location := Stg."Cod Camara";
        Cab."Libro Diario" := Stg."Libro Diario";
        Cab.Puerto := Stg.Puerto;
        Cab."Pallets desde" := Stg."Pallets Desde";
        Cab."Pallets hasta" := Stg."Pallets Hasta";
        Cab."Hora inicio descarga" := Stg."Hora Inicio Descarga";
        Cab."Hora fin descarga" := Stg."Hora Fin Descarga";
        Cab."Scale code" := Stg."Cod Balanza";
        Cab.Registrado := Stg.Registrado;
        Cab.Validate("Origen del cartón", Stg."Origen Carton");

        if EsAlta then
            Cab.Insert(true)
        else
            Cab.Modify(true);
    end;

    local procedure AplicarDescargaLin()
    var
        Stg: Record "Stg Descarga Lin NAV";
        Lin: Record "Lín. descarga";
        EsAlta: Boolean;
    begin
        Stg.Get(ClaveCode, ClaveInt);

        // Mismo motivo que en la cabecera: el OnInsert de la personalización valida campos que
        // todavía no están puestos si se inserta primero. Ver el comentario de AplicarDescargaCab.
        EsAlta := not Lin.Get(Stg."No Proyecto", Stg."Line No");
        if EsAlta then begin
            Lin.Init();
            Lin."No. proyecto" := Stg."No Proyecto";
            Lin."Line no." := Stg."Line No";
        end;

        Lin."No. remito" := Stg."No Remito";
        Lin."Item no." := Stg."Item No";
        Lin.Description := CopyStr(Stg.Descripcion, 1, MaxStrLen(Lin.Description));
        Lin."Unidad medida" := Stg."Unidad Medida";
        Lin.Cantidad := Stg.Cantidad;
        Lin."Net weight" := Stg."Peso Neto";
        Lin."Gross weight" := Stg."Peso Bruto";
        Lin."Fecha remito" := Stg."Fecha Remito";
        Lin."Transport's license" := Stg."Licencia Transporte";
        Lin.Temperatura := Stg.Temperatura;
        Lin."Hora de ingreso" := Stg."Hora Ingreso";
        Lin.Validate("Tipo de amparo sanitario", Stg."Tipo Amparo Sanitario");
        Lin."No. amparo sanitario" := Stg."No Amparo Sanitario";
        Lin.Destino := Stg.Destino;
        Lin."No. Pallet" := Stg."No Pallet";
        Lin.Location := Stg."Cod Camara";
        Lin.Buque := Stg.Buque;
        Lin.Marea := Stg.Marea;
        Lin.Puerto := Stg.Puerto;
        Lin.Promedio := Stg.Promedio;
        Lin."Bin code" := Stg."Bin Code";
        Lin.Tare := Stg.Tara;
        Lin."Gross + Tare" := Stg."Bruto Mas Tara";
        Lin."Weighing Date and Time" := Stg."Fecha Hora Pesaje";
        Lin.Validate(Confirmed, Stg.Confirmado);
        Lin.Status := CopyStr(Stg."Estado Origen", 1, MaxStrLen(Lin.Status));
        Lin.Actividad := Stg.Actividad;
        Lin.Familia := Stg.Familia;
        Lin.Subfamilia := Stg.Subfamilia;
        Lin."Manual unit of measure" := Stg."Unidad Medida Manual";
        Lin."Manual weight" := Stg."Peso Manual";

        if EsAlta then
            Lin.Insert(true)
        else
            Lin.Modify(true);
    end;
}
