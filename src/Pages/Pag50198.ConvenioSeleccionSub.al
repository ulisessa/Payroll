namespace UAS.Payroll;

page 50198 "Convenio Selección Sub"
{
    // Checkbox list of every Convenio Colectivo, for the "Convenios por Concepto" tool. Grows
    // automatically as convenios are added to the master — no per-convenio UI to maintain.
    PageType = ListPart;
    Caption = 'Convenios';
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

    // Reloads the full convenio list from the master, preserving the tick state of codes still present.
    procedure Recargar()
    var
        Convenio: Record "Convenio Colectivo";
        Marcados: List of [Code[20]];
    begin
        if Rec.FindSet() then
            repeat
                if Rec.Marcado then
                    Marcados.Add(Rec.Código);
            until Rec.Next() = 0;

        Rec.Reset();
        Rec.DeleteAll();
        if Convenio.FindSet() then
            repeat
                Rec.Código := Convenio.Código;
                Rec.Descripción := CopyStr(Convenio.Descripción, 1, MaxStrLen(Rec.Descripción));
                Rec.Marcado := Marcados.Contains(Convenio.Código);
                Rec.Insert();
            until Convenio.Next() = 0;
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
