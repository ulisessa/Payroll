namespace UAS.Payroll;

using System.Reflection;

page 50134 "Fuente Datos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Fuente Datos Liquidación';
    PageType = List;
    SourceTable = "Fuente Datos Liquidación";
    UsageCategory = Administration;
    CardPageId = "Fuente Datos Card";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(NombreTabla; NombreTabla)
                {
                    ApplicationArea = All;
                    Caption = 'Tabla';
                    Editable = false;
                }
                field("Función Agregado"; Rec."Función Agregado") { ApplicationArea = All; }
                field(NombreCampoValor; NombreCampoValor)
                {
                    ApplicationArea = All;
                    Caption = 'Campo Valor';
                    Editable = false;
                }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        NombreTabla := GetTableName(Rec."Id. Tabla");
        NombreCampoValor := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Valor");
    end;

    var
        NombreTabla: Text[250];
        NombreCampoValor: Text[100];

    local procedure GetTableName(TableId: Integer): Text[250]
    var
        AllObj: Record AllObjWithCaption;
    begin
        if TableId = 0 then exit('');
        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object ID", TableId);
        if AllObj.FindFirst() then
            exit(AllObj."Object Caption");
        exit('(' + Format(TableId) + ')');
    end;

    local procedure GetFieldName(TableId: Integer; FieldNo: Integer): Text[100]
    var
        FieldRec: Record Field;
    begin
        if (TableId = 0) or (FieldNo = 0) then exit('');
        if FieldRec.Get(TableId, FieldNo) then
            exit(FieldRec.FieldName);
        exit('(' + Format(FieldNo) + ')');
    end;
}
