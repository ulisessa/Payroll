namespace UAS.Payroll;

using System.Reflection;

page 50178 "Filtro Fuente Datos Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Filtros';
    PageType = ListPart;
    SourceTable = "Filtro Fuente Datos Liq.";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Campo"; Rec."No. Campo")
                {
                    ApplicationArea = All;
                    Caption = 'Campo (No.)';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        FieldRec: Record Field;
                    begin
                        if FIdTabla = 0 then begin
                            Message(MsgSinTabla);
                            exit(false);
                        end;
                        FieldRec.SetRange(TableNo, FIdTabla);
                        FieldRec.SetRange(Class, FieldRec.Class::Normal);
                        if Page.RunModal(Page::"Campo Liq. Lookup", FieldRec) = Action::LookupOK then begin
                            Rec."No. Campo" := FieldRec."No.";
                            FNombreCampo := FieldRec.FieldName;
                            Text := Format(FieldRec."No.");
                            exit(true);
                        end;
                    end;

                    trigger OnValidate()
                    begin
                        FNombreCampo := GetNombreCampo(Rec."No. Campo");
                    end;
                }
                field(NombreCampo; FNombreCampo)
                {
                    ApplicationArea = All;
                    Caption = 'Campo';
                    Editable = false;
                    Style = Strong;
                }
                field("Filtro Valor"; Rec."Filtro Valor")
                {
                    ApplicationArea = All;
                    Caption = 'Filtro / Valor';
                    ToolTip = 'Expresión de filtro BC (rangos .., OR |, comodines *). Tokens: {EMP_NO}, {JOB_NO}, {PERIODO}, {FECHA_REF}, {SEM_DESDE}, {SEM_HASTA}.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FNombreCampo := GetNombreCampo(Rec."No. Campo");
    end;

    procedure SetIdTabla(IdTabla: Integer)
    begin
        FIdTabla := IdTabla;
    end;

    local procedure GetNombreCampo(FieldNo: Integer): Text[100]
    var
        FieldRec: Record Field;
    begin
        if (FIdTabla = 0) or (FieldNo = 0) then exit('');
        if FieldRec.Get(FIdTabla, FieldNo) then
            exit(FieldRec.FieldName);
        exit('(campo ' + Format(FieldNo) + ')');
    end;

    var
        FIdTabla: Integer;
        FNombreCampo: Text[100];
        MsgSinTabla: Label 'Configurá primero el Id. de Tabla en la fuente de datos.';
}
