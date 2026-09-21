namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;

/// <summary>
/// Alta controlada de entidades y arrastre del código cuando se renombra su valor de dimensión.
/// </summary>
/// <remarks>
/// El código de la entidad es la clave con la que se guardan sus estados y sus atributos. Si el
/// valor de dimensión se renombra y ese arrastre no ocurre, no falla nada: simplemente el histórico
/// del buque y sus atributos quedan colgando del código viejo, invisibles, mientras la entidad nueva
/// aparece sin historia. Es el peor tipo de error — silencioso y difícil de deshacer.
/// </remarks>
codeunit 50075 "Gestión Entidades Liq."
{
    Access = Public;

    // ── Alta controlada ───────────────────────────────────────────────────────

    /// <summary>
    /// Devuelve la entidad del valor de dimensión. Si no existe, ofrece crearla exigiendo clase.
    /// </summary>
    procedure ObtenerOCrear(CodValorDim: Code[20]; DescripcionSugerida: Text[100]; var Entidad: Record "Entidad Liq."): Boolean
    var
        Clase: Record "Clase Entidad Liq.";
        CodClase: Code[20];
    begin
        if Entidad.Get(CodValorDim) then
            exit(true);

        if not Confirm(QstCrear, true, CodValorDim) then
            exit(false);

        // La clase se pide ANTES de insertar, no después: la tabla la exige en OnInsert, así que
        // sin ella el alta abortaría dejando al usuario con un error en vez de una pregunta.
        if Page.RunModal(0, Clase) <> Action::LookupOK then
            exit(false);
        CodClase := Clase.Código;
        if CodClase = '' then
            exit(false);

        Entidad.Init();
        Entidad.Código := CodValorDim;
        Entidad.Descripción := DescripcionSugerida;
        Entidad."Cód. Clase" := CodClase;
        Entidad.Insert(true);
        exit(true);
    end;

    // ── Arrastre del renombrado ───────────────────────────────────────────────

    // Suscripción y no trigger: un tableextension no puede agregar OnRename. Y es la única forma de
    // que el arrastre corra también cuando el renombrado viene de una importación, de un ajuste
    // masivo o de otra extensión — que son justamente los casos que nadie mira.
    [EventSubscriber(ObjectType::Table, Database::"Dimension Value", 'OnAfterRenameEvent', '', false, false)]
    local procedure AlRenombrarValorDimension(var Rec: Record "Dimension Value"; var xRec: Record "Dimension Value"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec.Code = xRec.Code then
            exit;
        if not EsDimensionDeEntidades(Rec."Dimension Code") then
            exit;
        Arrastrar(xRec.Code, Rec.Code);
    end;

    /// <summary>
    /// Lleva el código nuevo a la entidad y a todo lo que la referencia.
    /// </summary>
    procedure Arrastrar(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    begin
        if (CodigoViejo = '') or (CodigoNuevo = '') or (CodigoViejo = CodigoNuevo) then
            exit;
        RenombrarEntidad(CodigoViejo, CodigoNuevo);
        RenombrarAtributos(CodigoViejo, CodigoNuevo);
        ActualizarEstados(CodigoViejo, CodigoNuevo);
        ActualizarPersonalProyecto(CodigoViejo, CodigoNuevo);
    end;

    local procedure RenombrarEntidad(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        Entidad: Record "Entidad Liq.";
    begin
        if Entidad.Get(CodigoViejo) then
            Entidad.Rename(CodigoNuevo);
    end;

    // "Cód. Entidad" forma parte de la clave primaria, así que van con Rename y no con ModifyAll.
    // Los SystemId se juntan primero: renombrar mientras se recorre mueve el registro dentro del
    // orden de la clave y el Next() puede saltear o repetir filas.
    local procedure RenombrarAtributos(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        Atributo: Record "Atributo Entidad Liq.";
        Ids: List of [Guid];
        Id: Guid;
    begin
        Atributo.SetRange("Tipo Entidad", Atributo."Tipo Entidad"::Buque);
        Atributo.SetRange("Cód. Entidad", CodigoViejo);
        if Atributo.FindSet() then
            repeat
                Ids.Add(Atributo.SystemId);
            until Atributo.Next() = 0;

        foreach Id in Ids do
            if Atributo.GetBySystemId(Id) then
                Atributo.Rename(Atributo."Tipo Entidad", CodigoNuevo,
                                Atributo."Cód. Tipo Atributo", Atributo."Vigencia Desde");
    end;

    // OJO con el nombre del campo: en Estado Empleado el código del buque vive en "No. Empleado".
    // La tabla es compartida entre empleados y buques y el campo conserva el nombre original; un
    // arrastre escrito mirando nombres de campo se saltearía justo el histórico de estados, que es
    // el que dispara el pase de la tripulación a francos.
    //
    // Va con ModifyAll porque el campo NO está en la clave primaria (que es "No. Mov."), y sin
    // disparar triggers: el OnModify valida contigüidad y liquidaciones bloqueantes, y acá no se
    // está moviendo ninguna fecha — solo cambia el código de la misma entidad.
    local procedure ActualizarEstados(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        Estado: Record "Estado Empleado";
    begin
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Buque);
        Estado.SetRange("No. Empleado", CodigoViejo);
        if not Estado.IsEmpty() then
            Estado.ModifyAll("No. Empleado", CodigoNuevo);
    end;

    // Copia desnormalizada nuestra: BC arrastra el renombrado a sus propios usos de la dimensión
    // —incluido Job."Global Dimension 1 Code"— pero esta columna no la toca nadie.
    local procedure ActualizarPersonalProyecto(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        PersProy: Record "Personal Proyecto";
    begin
        PersProy.SetRange(Buque, CodigoViejo);
        if not PersProy.IsEmpty() then
            PersProy.ModifyAll(Buque, CodigoNuevo);
    end;

    local procedure EsDimensionDeEntidades(CodDimension: Code[20]): Boolean
    var
        GLSetup: Record "General Ledger Setup";
    begin
        if not GLSetup.Get() then
            exit(false);
        exit((GLSetup."Global Dimension 1 Code" <> '') and (CodDimension = GLSetup."Global Dimension 1 Code"));
    end;

    var
        QstCrear: Label 'El valor %1 todavía no tiene una entidad asociada. ¿Crearla ahora? A continuación se pide la clase de entidad, que es obligatoria.';
}
