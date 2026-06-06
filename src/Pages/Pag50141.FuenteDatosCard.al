namespace UAS.Payroll;

using System.Reflection;

page 50141 "Fuente Datos Card"
{
    ApplicationArea = All;
    Caption = 'Fuente de Datos de Liquidación';
    PageType = Card;
    SourceTable = "Fuente Datos Liquidación";

    layout
    {
        area(Content)
        {
            group(GrpGeneral)
            {
                Caption = 'General';
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field("Mostrar en Recibo"; Rec."Mostrar en Recibo") { ApplicationArea = All; }
                field("Etiqueta Recibo"; Rec."Etiqueta Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Etiqueta que aparece en el recibo de sueldo. Si se deja vacío se usa la Descripción.';
                }
            }
            group(GrpOrigen)
            {
                Caption = 'Origen de datos';
                field("Id. Tabla"; Rec."Id. Tabla")
                {
                    ApplicationArea = All;
                    Caption = 'Tabla (ID)';
                    trigger OnValidate()
                    begin
                        Rec."No. Campo Valor" := 0;
                        Rec."No. Filtro 1" := 0;
                        Rec."No. Filtro 2" := 0;
                        Rec."No. Filtro 3" := 0;
                        Rec."No. Campo Fecha Inicio" := 0;
                        Rec."No. Campo Fecha Fin" := 0;
                        RefreshNames();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        AllObj: Record AllObjWithCaption;
                    begin
                        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                        AllObj.SetFilter("Object ID", '>0');
                        if Page.RunModal(Page::"Tabla Liq. Lookup", AllObj) = Action::LookupOK then begin
                            Rec."Id. Tabla" := AllObj."Object ID";
                            Rec."No. Campo Valor" := 0;
                            Rec."No. Filtro 1" := 0;
                            Rec."No. Filtro 2" := 0;
                            Rec."No. Filtro 3" := 0;
                            Rec."No. Campo Fecha Inicio" := 0;
                            Rec."No. Campo Fecha Fin" := 0;
                            NombreTabla := AllObj."Object Caption";
                            Text := Format(AllObj."Object ID");
                            exit(true);
                        end;
                    end;
                }
                field(NombreTabla; NombreTabla)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Tabla';
                    Editable = false;
                    Style = Strong;
                }
                field("No. Campo Valor"; Rec."No. Campo Valor")
                {
                    ApplicationArea = All;
                    Caption = 'Campo Valor (No.)';
                    Visible = not IsFuncFechas;
                    trigger OnValidate()
                    begin
                        NombreCampoValor := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Valor");
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        FieldRec: Record Field;
                    begin
                        if Rec."Id. Tabla" = 0 then begin
                            Message('Seleccioná primero una tabla.');
                            exit(false);
                        end;
                        FieldRec.SetRange(TableNo, Rec."Id. Tabla");
                        FieldRec.SetRange(Class, FieldRec.Class::Normal);
                        if Page.RunModal(Page::"Campo Liq. Lookup", FieldRec) = Action::LookupOK then begin
                            Rec."No. Campo Valor" := FieldRec."No.";
                            NombreCampoValor := FieldRec.FieldName;
                            Text := Format(FieldRec."No.");
                            exit(true);
                        end;
                    end;
                }
                field(NombreCampoValor; NombreCampoValor)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Campo';
                    Editable = false;
                    Visible = not IsFuncFechas;
                }
                field("Función Agregado"; Rec."Función Agregado")
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        IsFuncFechas := EsFuncFechas();
                        if IsFuncFechas then begin
                            Rec."No. Campo Valor" := 0;
                            NombreCampoValor := '';
                        end;
                    end;
                }
            }
            group(GrpDiasOverlap)
            {
                Caption = 'Rango de fechas';
                Visible = IsFuncFechas;
                field("No. Campo Fecha Inicio"; Rec."No. Campo Fecha Inicio")
                {
                    ApplicationArea = All;
                    Caption = 'Campo Fecha Inicio (No.)';
                    trigger OnValidate()
                    begin
                        NombreFechaInicio := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Fecha Inicio");
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFiltro(Rec."No. Campo Fecha Inicio", NombreFechaInicio, Text));
                    end;
                }
                field(NombreFechaInicio; NombreFechaInicio)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Campo Fecha Inicio';
                    Editable = false;
                }
                field("No. Campo Fecha Fin"; Rec."No. Campo Fecha Fin")
                {
                    ApplicationArea = All;
                    Caption = 'Campo Fecha Fin (No.)';
                    ToolTip = 'Dejar en 0 para tratar como fecha abierta (= fin de período).';
                    trigger OnValidate()
                    begin
                        NombreFechaFin := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Fecha Fin");
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupFiltro(Rec."No. Campo Fecha Fin", NombreFechaFin, Text));
                    end;
                }
                field(NombreFechaFin; NombreFechaFin)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Campo Fecha Fin';
                    Editable = false;
                }
            }
            group(GrpFiltros)
            {
                Caption = 'Filtros (tokens: {EMP_NO}, {JOB_NO}, {PERIODO}, {FECHA_REF}, {LIQ_NO})';
                group(GrpF1)
                {
                    ShowCaption = false;
                    field("No. Filtro 1"; Rec."No. Filtro 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Campo Filtro 1';
                        trigger OnValidate()
                        begin
                            NombreFiltro1 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 1");
                        end;

                        trigger OnLookup(var Text: Text): Boolean
                        begin
                            exit(LookupFiltro(Rec."No. Filtro 1", NombreFiltro1, Text));
                        end;
                    }
                    field(NombreFiltro1; NombreFiltro1)
                    {
                        ApplicationArea = All;
                        Caption = 'Nombre Campo 1';
                        Editable = false;
                    }
                    field("Filtro Valor 1"; Rec."Filtro Valor 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Valor / Filtro 1';
                        ToolTip = 'Expresión de filtro BC. Admite rangos (..), OR (|), comodines (*). Tokens: {EMP_NO} {JOB_NO} {PERIODO} {FECHA_REF}.';
                    }
                }
                group(GrpF2)
                {
                    ShowCaption = false;
                    field("No. Filtro 2"; Rec."No. Filtro 2")
                    {
                        ApplicationArea = All;
                        Caption = 'Campo Filtro 2';
                        trigger OnValidate()
                        begin
                            NombreFiltro2 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 2");
                        end;

                        trigger OnLookup(var Text: Text): Boolean
                        begin
                            exit(LookupFiltro(Rec."No. Filtro 2", NombreFiltro2, Text));
                        end;
                    }
                    field(NombreFiltro2; NombreFiltro2)
                    {
                        ApplicationArea = All;
                        Caption = 'Nombre Campo 2';
                        Editable = false;
                    }
                    field("Filtro Valor 2"; Rec."Filtro Valor 2") { ApplicationArea = All; Caption = 'Valor / Filtro 2'; }
                }
                group(GrpF3)
                {
                    ShowCaption = false;
                    field("No. Filtro 3"; Rec."No. Filtro 3")
                    {
                        ApplicationArea = All;
                        Caption = 'Campo Filtro 3';
                        trigger OnValidate()
                        begin
                            NombreFiltro3 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 3");
                        end;

                        trigger OnLookup(var Text: Text): Boolean
                        begin
                            exit(LookupFiltro(Rec."No. Filtro 3", NombreFiltro3, Text));
                        end;
                    }
                    field(NombreFiltro3; NombreFiltro3)
                    {
                        ApplicationArea = All;
                        Caption = 'Nombre Campo 3';
                        Editable = false;
                    }
                    field("Filtro Valor 3"; Rec."Filtro Valor 3") { ApplicationArea = All; Caption = 'Valor / Filtro 3'; }
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        IsFuncFechas := EsFuncFechas();
        RefreshNames();
    end;

    var
        NombreTabla: Text[250];
        NombreCampoValor: Text[100];
        NombreFiltro1: Text[100];
        NombreFiltro2: Text[100];
        NombreFiltro3: Text[100];
        NombreFechaInicio: Text[100];
        NombreFechaFin: Text[100];
        IsFuncFechas: Boolean;

    local procedure RefreshNames()
    begin
        NombreTabla := GetTableName(Rec."Id. Tabla");
        NombreCampoValor := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Valor");
        NombreFiltro1 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 1");
        NombreFiltro2 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 2");
        NombreFiltro3 := GetFieldName(Rec."Id. Tabla", Rec."No. Filtro 3");
        NombreFechaInicio := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Fecha Inicio");
        NombreFechaFin := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Fecha Fin");
    end;

    local procedure LookupFiltro(var FieldNo: Integer; var Nombre: Text[100]; var Text: Text): Boolean
    var
        FieldRec: Record Field;
    begin
        if Rec."Id. Tabla" = 0 then begin
            Message('Seleccioná primero una tabla.');
            exit(false);
        end;
        FieldRec.SetRange(TableNo, Rec."Id. Tabla");
        FieldRec.SetRange(Class, FieldRec.Class::Normal);
        if Page.RunModal(Page::"Campo Liq. Lookup", FieldRec) = Action::LookupOK then begin
            FieldNo := FieldRec."No.";
            Nombre := FieldRec.FieldName;
            Text := Format(FieldRec."No.");
            exit(true);
        end;
    end;

    local procedure GetTableName(TableId: Integer): Text[250]
    var
        AllObj: Record AllObjWithCaption;
    begin
        if TableId = 0 then exit('');
        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object ID", TableId);
        if AllObj.FindFirst() then
            exit(AllObj."Object Caption");
        exit('(tabla ' + Format(TableId) + ')');
    end;

    local procedure GetFieldName(TableId: Integer; FieldNo: Integer): Text[100]
    var
        FieldRec: Record Field;
    begin
        if (TableId = 0) or (FieldNo = 0) then exit('');
        if FieldRec.Get(TableId, FieldNo) then
            exit(FieldRec.FieldName);
        exit('(campo ' + Format(FieldNo) + ')');
    end;

    local procedure EsFuncFechas(): Boolean
    begin
        exit(Rec."Función Agregado" in [
            Rec."Función Agregado"::"DIAS_OVERLAP",
            Rec."Función Agregado"::"DURACION_INICIO",
            Rec."Función Agregado"::"DURACION_ANIO"]);
    end;
}
