namespace UAS.Payroll;

page 50108 "Parámetros"
{
    ApplicationArea = All;
    Caption = 'Parámetros';
    PageType = List;
    SourceTable = "Parámetro";
    UsageCategory = Administration;
    CardPageId = "Parámetro Card";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field("Sufijo CCT"; Rec."Sufijo CCT") { ApplicationArea = All; }
                field("Sufijo Empleado"; Rec."Sufijo Empleado") { ApplicationArea = All; }
                field("Sufijo Convenio"; Rec."Sufijo Convenio") { ApplicationArea = All; }
                field("Antigüedad Máxima Vigencia"; Rec."Antigüedad Máxima Vigencia")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fórmula de fecha (ej. -1M, -35D). Si se completa, al calcular una liquidación se avisa cuando el último valor vigente de este parámetro es anterior a esa antigüedad respecto a la fecha de liquidación. Útil para parámetros que la AFIP actualiza periódicamente (MNI, Deducción Especial). Vacío = sin chequeo.';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LiberarEnUso)
            {
                ApplicationArea = All;
                Caption = 'Liberar "En Uso"';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Libera los bloqueos "En Uso" de los valores vigentes del parámetro seleccionado que ya no estén referenciados por liquidaciones activas.';
                trigger OnAction()
                var
                    ParamVig: Record "Parámetro Vigente";
                    Liq: Record "Liquidación";
                    Limpiados: Integer;
                begin
                    ParamVig.SetRange("Cód. Parámetro Base", Rec.Código);
                    ParamVig.SetRange("En Uso", true);
                    if not ParamVig.FindSet(true) then begin
                        Message(MsgSinBloqueos, Rec.Código);
                        exit;
                    end;
                    repeat
                        if ParamVig."No. Empleado" <> '' then
                            Liq.SetRange("No. Empleado", ParamVig."No. Empleado")
                        else
                            Liq.Reset();
                        Liq.SetFilter(Estado, '%1|%2|%3',
                            Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
                        if Liq.IsEmpty() then begin
                            ParamVig."En Uso" := false;
                            ParamVig.Modify();
                            Limpiados += 1;
                        end;
                        Liq.Reset();
                    until ParamVig.Next() = 0;
                    Message(MsgLimpiados, Limpiados, Rec.Código);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        MsgSinBloqueos: Label 'El parámetro ''%1'' no tiene valores vigentes bloqueados.';
        MsgLimpiados: Label '%1 bloqueo(s) liberado(s) del parámetro ''%2''.';
}
