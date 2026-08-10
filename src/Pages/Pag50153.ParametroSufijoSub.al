namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50153 "Parámetro Sufijo Sub"
{
    ApplicationArea = All;
    Caption = 'Valores por Clave Derivada';
    PageType = ListPart;
    SourceTable = "Parámetro Vigente";
    DelayedInsert = true;
    // Used on the Parámetro card for all parameter types.
    // For Sufijo Empleado params: user fills No. Empleado → Cód. Parámetro is auto-computed.
    // For Sufijo CCT params: user types the full derived key (e.g. BASICO_ADM_DES) manually.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    Enabled = FIsSufijoEmpleado;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado para el que aplica este valor. Al completarlo se calcula automáticamente la Clave Derivada. Solo aplica si el parámetro tiene activo Sufijo Empleado.';

                    trigger OnValidate()
                    begin
                        if (FBaseCodigo <> '') and (Rec."No. Empleado" <> '') then
                            Rec."Cód. Parámetro" := FBaseCodigo + '_' + Rec."No. Empleado";
                    end;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    Enabled = FIsSufijoCCT or FIsSufijoConvenio;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Convenio para el que aplica este valor. Para Sufijo Convenio arma la clave sola; para Sufijo CCT se completa junto con la categoría. Solo aplica si el parámetro tiene activo Sufijo CCT o Sufijo Convenio.';

                    trigger OnValidate()
                    begin
                        if FIsSufijoCCT then
                            Rec."Cód. Categoría" := '';
                        ArmarClaveDerivada();
                    end;
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    Enabled = FIsSufijoCCT;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Categoría para la que aplica este valor. Al completarla se calcula automáticamente la Clave Derivada. Solo aplica si el parámetro tiene activo Sufijo CCT.';

                    trigger OnValidate()
                    begin
                        ArmarClaveDerivada();
                    end;
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave Derivada';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Clave completa derivada del código base. Para sufijo CCT: BASICO_ADM_DES. Para sufijo empleado: se completa automáticamente al ingresar el No. Empleado.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo Valor';
                Image = NewRow;
                ToolTip = 'Inserta una nueva vigencia para la combinación seleccionada.';

                trigger OnAction()
                var
                    NuevoParam: Record "Parámetro Vigente";
                begin
                    Rec.TestField("Cód. Parámetro");
                    NuevoParam := Rec;
                    NuevoParam."Vigencia Desde" := WorkDate();
                    NuevoParam."En Uso" := false;
                    NuevoParam.Descripción := '';
                    NuevoParam.Insert(true);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        Param: Record "Parámetro";
    begin
        if FBaseCodigo = '' then exit;
        Rec."Cód. Parámetro Base" := FBaseCodigo;
        // Global parameter (no suffix): the derived key equals the base code, so fill it
        // automatically. Read the suffix flags straight from the Parámetro (not the cached
        // page vars) so a stale flag from a previously viewed parameter can't block it.
        if Param.Get(FBaseCodigo) then
            if not (Param."Sufijo CCT" or Param."Sufijo Empleado" or Param."Sufijo Convenio") then
                Rec."Cód. Parámetro" := FBaseCodigo;
    end;

    // Builds the derived key from the entered parts, mirroring how the motor composes the
    // effective code: Sufijo Convenio → Código_Convenio; Sufijo CCT → Código_Convenio_Categoría.
    local procedure ArmarClaveDerivada()
    begin
        if FBaseCodigo = '' then
            exit;
        if FIsSufijoConvenio and (Rec."Cód. Convenio" <> '') then
            Rec."Cód. Parámetro" := FBaseCodigo + '_' + Rec."Cód. Convenio"
        else if FIsSufijoCCT and (Rec."Cód. Convenio" <> '') and (Rec."Cód. Categoría" <> '') then
            Rec."Cód. Parámetro" := FBaseCodigo + '_' + Rec."Cód. Convenio" + '_' + Rec."Cód. Categoría";
    end;

    procedure SetBaseCodigo(BaseCodigo: Code[20]; IsSufijoEmpleado: Boolean; IsSufijoCCT: Boolean; IsSufijoConvenio: Boolean)
    begin
        FBaseCodigo := BaseCodigo;
        FIsSufijoEmpleado := IsSufijoEmpleado;
        FIsSufijoCCT := IsSufijoCCT;
        FIsSufijoConvenio := IsSufijoConvenio;
        Rec.FilterGroup(2);
        Rec.SetRange("Cód. Parámetro Base", BaseCodigo);
        Rec.FilterGroup(0);
        CurrPage.Update(false);
    end;

    // Number of existing lines for the current base code — lets the caller decide whether a confirm
    // prompt is worth showing before calling RecalcularClaves.
    procedure ContarLineas(): Integer
    var
        ParamVig: Record "Parámetro Vigente";
    begin
        if FBaseCodigo = '' then exit(0);
        ParamVig.SetRange("Cód. Parámetro Base", FBaseCodigo);
        exit(ParamVig.Count());
    end;

    // Re-derives "Cód. Parámetro" for every existing line under FBaseCodigo per the NEW suffix mode,
    // mirroring ArmarClaveDerivada's rules. Called when the header's Sufijo flags change after lines
    // already exist — otherwise those lines keep the old-mode key and the motor stops finding them
    // (the same mismatch diagnosed for VAL_CARG_COMP, just triggered by a suffix flip instead of a typo).
    // Lines that lack the data the new mode needs (e.g. a Sufijo Empleado line has no Convenio/Categoría
    // to build a Sufijo CCT key) are left untouched — skipped, not guessed at.
    procedure RecalcularClaves(SufEmpleado: Boolean; SufCCT: Boolean; SufConvenio: Boolean): Integer
    var
        ParamVig: Record "Parámetro Vigente";
        NuevaClave: Code[50];
        Snapshot: List of [Guid];
        Id: Guid;
        Actualizadas: Integer;
    begin
        if FBaseCodigo = '' then exit(0);

        // Snapshot the SystemIds first: renaming mid-iteration (Cód. Parámetro is part of the PK/current
        // key) would move the record within the key's order and can skip or repeat rows on Next().
        // Re-fetching by SystemId after each rename sidesteps that entirely.
        ParamVig.SetRange("Cód. Parámetro Base", FBaseCodigo);
        if ParamVig.FindSet() then
            repeat
                Snapshot.Add(ParamVig.SystemId);
            until ParamVig.Next() = 0;

        foreach Id in Snapshot do
            if ParamVig.GetBySystemId(Id) then begin
                NuevaClave := '';
                if SufEmpleado then begin
                    if ParamVig."No. Empleado" <> '' then
                        NuevaClave := CopyStr(FBaseCodigo + '_' + ParamVig."No. Empleado", 1, 50);
                end else if SufConvenio then begin
                    if ParamVig."Cód. Convenio" <> '' then
                        NuevaClave := CopyStr(FBaseCodigo + '_' + ParamVig."Cód. Convenio", 1, 50);
                end else if SufCCT then begin
                    if (ParamVig."Cód. Convenio" <> '') and (ParamVig."Cód. Categoría" <> '') then
                        NuevaClave := CopyStr(FBaseCodigo + '_' + ParamVig."Cód. Convenio" + '_' + ParamVig."Cód. Categoría", 1, 50);
                end else
                    NuevaClave := FBaseCodigo;

                if (NuevaClave <> '') and (NuevaClave <> ParamVig."Cód. Parámetro") then begin
                    ParamVig.Rename(ParamVig."Cód. Parámetro Base", NuevaClave, ParamVig."Vigencia Desde");
                    Actualizadas += 1;
                end;
            end;

        FIsSufijoEmpleado := SufEmpleado;
        FIsSufijoCCT := SufCCT;
        FIsSufijoConvenio := SufConvenio;
        CurrPage.Update(false);
        exit(Actualizadas);
    end;

    var
        FBaseCodigo: Code[20];
        FIsSufijoEmpleado: Boolean;
        FIsSufijoCCT: Boolean;
        FIsSufijoConvenio: Boolean;
}
