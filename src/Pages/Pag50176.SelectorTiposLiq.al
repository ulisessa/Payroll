namespace UAS.Payroll;

page 50176 "Selector Tipos Liq."
{
    // Checkbox list of every active Tipo Liquidación, used from Concepto Liq. Card to edit a single
    // concept's "Tipos Liq. Aplicables" (pipe-delimited codes; empty = applies to all). Data-driven off the
    // "Tipo Liquidación" table — no per-type control to maintain as types are added.
    PageType = Card;
    Caption = 'Seleccionar Tipos de Liquidación';
    SourceTable = "Tipo Liq. Selección Buffer";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Marcado; Rec.Marcado) { ApplicationArea = All; }
                field(Código; Rec.Código) { ApplicationArea = All; Editable = false; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Aceptar)
            {
                ApplicationArea = All;
                Caption = 'Aceptar';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    FAceptado := true;
                    CurrPage.Close();
                end;
            }
            action(Cancelar)
            {
                ApplicationArea = All;
                Caption = 'Cancelar';
                Image = Cancel;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        CargarTipos();
    end;

    // Call before RunModal(). Texto is the concept's current pipe-delimited codes.
    procedure SetSeleccion(Texto: Text[250])
    begin
        FPreseleccion := Texto;
    end;

    // Call after RunModal() — only meaningful when Confirmado() is true.
    procedure GetSeleccion(): Text[250]
    var
        Resultado: Text;
    begin
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                if Rec.Marcado then begin
                    if Resultado <> '' then Resultado += '|';
                    Resultado += Rec.Código;
                end;
            until Rec.Next() = 0;
        exit(CopyStr(Resultado, 1, 250));
    end;

    // True if the user confirmed (Aceptar) rather than cancelling/closing. Sidesteps relying on RunModal's
    // returned Action value, which isn't guaranteed for a custom Card page's own actions.
    procedure Confirmado(): Boolean
    begin
        exit(FAceptado);
    end;

    local procedure CargarTipos()
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        Rec.Reset();
        Rec.DeleteAll();
        TipoLiq.SetRange(Activo, true);
        TipoLiq.SetCurrentKey(Orden);
        if TipoLiq.FindSet() then
            repeat
                Rec.Código := TipoLiq.Código;
                Rec.Descripción := TipoLiq.Descripción;
                Rec.Marcado := ContieneTipo(FPreseleccion, TipoLiq.Código);
                Rec.Insert();
            until TipoLiq.Next() = 0;
    end;

    local procedure ContieneTipo(Texto: Text; Tipo: Code[20]): Boolean
    begin
        if Texto = '' then exit(false);
        exit(('|' + Texto + '|').Contains('|' + Tipo + '|'));
    end;

    var
        FPreseleccion: Text[250];
        FAceptado: Boolean;
}
