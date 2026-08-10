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
                field("Cód. Parámetro Base"; Rec."Cód. Parámetro Base") { ApplicationArea = All; }
                field("Cód. Parámetro"; Rec."Cód. Parámetro") { ApplicationArea = All; }
                field(FNombreVar; FNombreVar)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Variable';
                    Editable = false;
                    ToolTip = 'Nombre con el que este parámetro se usa en las fórmulas. Vacío para códigos con sufijo CCT/Categoría.';
                }
                // Componentes de la clave derivada: hacen visible POR QUÉ un valor aplica a una
                // liquidación y cuál gana en la cascada específico → genérico (ver LoadParametros
                // en "Contexto Liquidación"). Fila sin ninguno de los tres = valor por defecto.
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado al que aplica este valor. Solo se usa si el parámetro tiene Sufijo Empleado.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Convenio al que aplica este valor. Vacío = valor genérico, usado cuando no hay uno más específico.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Categoría a la que aplica este valor. Solo se usa si el parámetro tiene Sufijo Convenio/Categoría.';
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
                    Liq: Record "Liquidación";
                    ParamVig: Record "Parámetro Vigente";
                    Limpiados: Integer;
                begin
                    ParamVig.SetRange("En Uso", true);
                    if ParamVig.FindSet(true) then
                        repeat
                            if ParamVig."No. Empleado" <> '' then begin
                                Liq.SetRange("No. Empleado", ParamVig."No. Empleado");
                                Liq.SetFilter(Estado, '%1|%2|%3',
                                    Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
                                if Liq.IsEmpty() then begin
                                    ParamVig."En Uso" := false;
                                    ParamVig.Modify();
                                    Limpiados += 1;
                                end;
                                Liq.Reset();
                            end else begin
                                Liq.SetFilter(Estado, '%1|%2|%3',
                                    Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
                                if Liq.IsEmpty() then begin
                                    ParamVig."En Uso" := false;
                                    ParamVig.Modify();
                                    Limpiados += 1;
                                end;
                                Liq.Reset();
                            end;
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
                    NuevoParam.Insert(true);
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
        if (Rec."Cód. Parámetro Base" <> '') and Param.Get(Rec."Cód. Parámetro Base") then
            FNombreVar := Param."Nombre Variable"
        else if StrLen(Rec."Cód. Parámetro") <= 20 then
            if Param.Get(Rec."Cód. Parámetro") then
                FNombreVar := Param."Nombre Variable";
    end;

    var
        FNombreVar: Text[30];
}
