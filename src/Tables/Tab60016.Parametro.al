namespace UAS.Payroll;

table 60016 "Parámetro"
{
    Caption = 'Parámetro';
    DataClassification = CustomerContent;
    LookupPageId = "Parámetros";
    DrillDownPageId = "Parámetros";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = CustomerContent;
            // Variable name exposed in the formula context. Blank = not auto-loaded.
        }
        field(5; "Sufijo CCT"; Boolean)
        {
            Caption = 'Sufijo Convenio/Categoría';
            DataClassification = CustomerContent;
            // When true the effective lookup key = Código + '_' + CodConvenio + '_' + CodCategoria.
            // Use for per-CCT basic salaries (e.g. 'BASICO_FC_GER').
            trigger OnValidate()
            begin
                if "Sufijo CCT" then begin
                    "Sufijo Empleado" := false;
                    "Sufijo Convenio" := false;
                end;
            end;
        }
        field(6; "Sufijo Empleado"; Boolean)
        {
            Caption = 'Sufijo Empleado';
            DataClassification = CustomerContent;
            // When true the effective lookup key = Código + '_' + EmployeeNo.
            // Use for per-employee salaries (e.g. 'BASICO_EMP001').
            trigger OnValidate()
            begin
                if "Sufijo Empleado" then begin
                    "Sufijo CCT" := false;
                    "Sufijo Convenio" := false;
                end;
            end;
        }
        field(8; "Sufijo Convenio"; Boolean)
        {
            Caption = 'Sufijo Convenio';
            DataClassification = CustomerContent;
            // When true the effective lookup key = Código + '_' + CodConvenio (no category).
            // Use for per-convenio values shared by all categories (e.g. 'COEF_FRANCOS_729/15').
            trigger OnValidate()
            begin
                if "Sufijo Convenio" then begin
                    "Sufijo CCT" := false;
                    "Sufijo Empleado" := false;
                end;
            end;
        }
        field(7; "Antigüedad Máxima Vigencia"; DateFormula)
        {
            Caption = 'Antigüedad Máxima Vigencia';
            DataClassification = CustomerContent;
            // Vacío = sin chequeo. Fórmula de fecha relativa (ej. '-1M', '-35D') aplicada
            // sobre la fecha de la liquidación: si la última "Vigencia Desde" cargada en
            // Parámetro Vigente es anterior a esa fecha límite, se avisa al calcular que
            // el valor podría estar desactualizado (ej. MNI_ANUAL, DESP_4CAT_ANUAL, que
            // la AFIP actualiza periódicamente).
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
    }

    // Renombrar el código tiene que arrastrar los valores vigentes: no solo su "Cód. Parámetro Base",
    // sino también la CLAVE DERIVADA, que lleva el código base como prefijo (ZONA_DESF → ZONA_DESF_ADM).
    // Sin esto, renombrar dejaba las claves apuntando al código viejo y el motor no volvía a encontrar
    // ni un valor: arma la clave efectiva desde el código nuevo (Cod50016 LoadParametros) y no hay nada
    // que la matchee. La misma reconstrucción que hace CopiarEn, que ya la tenía resuelta.
    trigger OnRename()
    var
        Vigente: Record "Parámetro Vigente";
        Snapshot: List of [Guid];
        Id: Guid;
        ClaveVieja: Text;
        NuevaClave: Code[50];
        Sufijo: Text;
    begin
        if xRec.Código = Código then
            exit;

        // Se fotografían los SystemId antes de tocar nada: "Cód. Parámetro" es parte de la clave
        // primaria, así que renombrar en medio del recorrido reordena el conjunto y haría saltear o
        // repetir filas. Mismo criterio que RecalcularClaves en la subpágina.
        Vigente.SetRange("Cód. Parámetro Base", xRec.Código);
        if Vigente.FindSet() then
            repeat
                Snapshot.Add(Vigente.SystemId);
            until Vigente.Next() = 0;

        foreach Id in Snapshot do
            if Vigente.GetBySystemId(Id) then begin
                ClaveVieja := Vigente."Cód. Parámetro";
                NuevaClave := Vigente."Cód. Parámetro";
                if ClaveVieja = xRec.Código then
                    NuevaClave := Código
                else
                    if ClaveVieja.StartsWith(xRec.Código + '_') then begin
                        Sufijo := CopyStr(ClaveVieja, StrLen(xRec.Código) + 1);
                        NuevaClave := CopyStr(Código + Sufijo, 1, MaxStrLen(Vigente."Cód. Parámetro"));
                    end;
                Vigente.Rename(Código, NuevaClave, Vigente."Vigencia Desde");
            end;
    end;

    trigger OnDelete()
    var
        Vigente: Record "Parámetro Vigente";
    begin
        Vigente.SetRange("Cód. Parámetro Base", Código);
        Vigente.SetRange("En Uso", true);
        if not Vigente.IsEmpty() then
            Error(ErrTieneEnUso);
        Vigente.SetRange("En Uso");
        Vigente.DeleteAll();
    end;

    procedure CopiarEn(NuevoCodigo: Code[20])
    var
        NuevoParam: Record "Parámetro";
        VigenteOrig: Record "Parámetro Vigente";
        VigenteNuevo: Record "Parámetro Vigente";
        CodParamOrigTxt: Text;
        Sufijo: Text;
    begin
        NuevoParam := Rec;
        NuevoParam.Código := NuevoCodigo;
        NuevoParam.Insert(true);

        VigenteOrig.SetRange("Cód. Parámetro Base", Código);
        if VigenteOrig.FindSet() then
            repeat
                VigenteNuevo := VigenteOrig;
                VigenteNuevo."Cód. Parámetro Base" := NuevoCodigo;
                // La clave derivada ("Cód. Parámetro") lleva el código base como prefijo
                // (ej. ZONA_DESF_ADM). Al copiar a un código nuevo hay que reconstruirla con
                // el nuevo prefijo; de lo contrario queda apuntando al código viejo y el motor
                // (Contexto Liquidación) nunca la encuentra al armar la clave efectiva.
                CodParamOrigTxt := VigenteOrig."Cód. Parámetro";
                if VigenteOrig."Cód. Parámetro" = Código then
                    VigenteNuevo."Cód. Parámetro" := NuevoCodigo
                else if CodParamOrigTxt.StartsWith(Código + '_') then begin
                    Sufijo := CopyStr(CodParamOrigTxt, StrLen(Código) + 1);
                    VigenteNuevo."Cód. Parámetro" := CopyStr(NuevoCodigo + Sufijo, 1, MaxStrLen(VigenteNuevo."Cód. Parámetro"));
                end;
                VigenteNuevo."En Uso" := false;
                VigenteNuevo.Insert(true);
            until VigenteOrig.Next() = 0;
    end;

    var
        ErrTieneEnUso: Label 'No se puede eliminar el parámetro porque tiene valores que fueron utilizados en liquidaciones registradas.';
}
