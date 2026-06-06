namespace UAS.Payroll;

page 50154 "Parámetros Vigentes"
{
    ApplicationArea = All;
    Caption = 'Parámetros Vigentes';
    PageType = List;
    SourceTable = "Parámetro Vigente";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Parámetro"; Rec."Cód. Parámetro") { ApplicationArea = All; }
                field(FNombreVar; FNombreVar)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Variable';
                    Editable = false;
                    ToolTip = 'Nombre con el que este parámetro se usa en las fórmulas. Vacío para códigos con sufijo CCT/Categoría.';
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
                field(Notas; Rec.Notas) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LimpiarEnUso)
            {
                ApplicationArea = All;
                Caption = 'Limpiar bloqueos "En Uso"';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Resetea el flag "En Uso" en todos los parámetros vigentes cuando no existen liquidaciones calculadas, aprobadas o contabilizadas.';
                trigger OnAction()
                var
                    OtraLiq: Record "Liquidación";
                    ParamVig: Record "Parámetro Vigente";
                    Limpiados: Integer;
                begin
                    OtraLiq.SetFilter(Estado, '%1|%2|%3',
                        OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada);
                    if not OtraLiq.IsEmpty() then begin
                        Message('Existen liquidaciones activas (calculadas/aprobadas/contabilizadas). No se pueden limpiar los bloqueos.');
                        exit;
                    end;
                    ParamVig.SetRange("En Uso", true);
                    if ParamVig.FindSet(true) then
                        repeat
                            ParamVig."En Uso" := false;
                            ParamVig.Modify();
                            Limpiados += 1;
                        until ParamVig.Next() = 0;
                    Message('%1 bloqueo(s) liberado(s).', Limpiados);
                    CurrPage.Update(false);
                end;
            }
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo Valor';
                Image = NewRow;
                Promoted = true;
                PromotedCategory = New;
                ToolTip = 'Inserta una nueva vigencia para el parámetro seleccionado, preservando el valor anterior para auditoría.';

                trigger OnAction()
                var
                    NuevoParam: Record "Parámetro Vigente";
                begin
                    Rec.TestField("Cód. Parámetro");
                    NuevoParam := Rec;
                    NuevoParam."Vigencia Desde" := WorkDate();
                    NuevoParam."En Uso" := false;
                    NuevoParam.Descripción := '';
                    if NuevoParam.Insert(true) then
                        CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Param: Record "Parámetro";
    begin
        FNombreVar := '';
        if StrLen(Rec."Cód. Parámetro") <= 20 then
            if Param.Get(Rec."Cód. Parámetro") then
                FNombreVar := Param."Nombre Variable";
    end;

    var
        FNombreVar: Text[30];
}
