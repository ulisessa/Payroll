namespace UAS.Payroll;

page 50196 "Tipo Liq. Selección Sub"
{
    // Checkbox list of every active Tipo Liquidación, for the "Conceptos por Tipo Liq." tool. Grows
    // automatically as types are added to the master — no per-type UI to maintain.
    PageType = ListPart;
    Caption = 'Tipos de Liquidación';
    SourceTable = "Tipo Liq. Selección Buffer";
    SourceTableTemporary = true;
    // FactBox parts render read-only by default unless the part page explicitly opts in.
    Editable = true;

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

    trigger OnOpenPage()
    begin
        Recargar();
    end;

    // Reloads the full active-type list from the master, preserving the tick state of codes still present.
    procedure Recargar()
    var
        TipoLiq: Record "Tipo Liquidación";
        Marcados: List of [Code[20]];
    begin
        if Rec.FindSet() then
            repeat
                if Rec.Marcado then
                    Marcados.Add(Rec.Código);
            until Rec.Next() = 0;

        Rec.Reset();
        Rec.DeleteAll();
        TipoLiq.SetRange(Activo, true);
        TipoLiq.SetCurrentKey(Orden);
        if TipoLiq.FindSet() then
            repeat
                Rec.Código := TipoLiq.Código;
                Rec.Descripción := TipoLiq.Descripción;
                Rec.Marcado := Marcados.Contains(TipoLiq.Código);
                Rec.Insert();
            until TipoLiq.Next() = 0;
        CurrPage.Update(false);
    end;

    procedure GetSeleccionados(): List of [Code[20]]
    var
        Resultado: List of [Code[20]];
        CurrRec: Record "Tipo Liq. Selección Buffer" temporary;
    begin
        // ShareTempTable=true: without it, Copy() on a temporary record starts a fresh, empty buffer
        // instead of pointing at Rec's actual rows — GetSeleccionados would always return nothing.
        CurrRec.Copy(Rec, true);
        if CurrRec.FindSet() then
            repeat
                if CurrRec.Marcado then
                    Resultado.Add(CurrRec.Código);
            until CurrRec.Next() = 0;
        exit(Resultado);
    end;
}
