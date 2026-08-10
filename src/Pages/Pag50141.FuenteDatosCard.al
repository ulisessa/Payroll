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
                field("Mostrar en Recibo"; Rec."Mostrar en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Imprime el valor en el recibo de sueldo (PDF). La ficha de Liquidación (Acumuladores Anuales) muestra automáticamente cualquier variable con valor distinto de cero, sin necesidad de marcar este campo.';
                }
                field("Etiqueta Recibo"; Rec."Etiqueta Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Etiqueta que aparece en el recibo de sueldo y en la ficha de Liquidación. Si se deja vacío se usa la Descripción.';
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
                        CurrPage.Filtros.Page.SetIdTabla(Rec."Id. Tabla");
                        CurrPage.Filtros.Page.Update(false);
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        AllObj: Record AllObjWithCaption;
                    begin
                        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                        AllObj.SetFilter("Object ID", '>0');
                        if Page.RunModal(Page::"Tabla Liq. Lookup", AllObj) = Action::LookupOK then begin
                            Rec.Validate("Id. Tabla", AllObj."Object ID");
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
                field("Fin Efectivo"; Rec."Fin Efectivo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Para tablas effective-dated (ej. Estado Empleado, sin campo Fecha Fin): el fin de cada intervalo se deriva como el inicio del registro siguiente de la misma entidad − 1. La entidad se define por los filtros con token ({EMP_NO}, {JOB_NO}…); los filtros constantes (ej. Cód. Estado) se ignoran para el fin. Reemplaza al "Campo Fecha Fin".';
                }
            }
            part(Filtros; "Filtro Fuente Datos Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Filtros (tokens: {EMP_NO}, {JOB_NO}, {PERIODO}, {FECHA_REF}, {LIQ_NO}, {MONEDA}, {SEM_DESDE}, {SEM_HASTA})';
                SubPageLink = "Nombre Variable" = FIELD("Nombre Variable");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Copiar)
            {
                ApplicationArea = All;
                Caption = 'Copiar como...';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Crea una copia de esta fuente de datos con un nuevo nombre de variable.';

                trigger OnAction()
                var
                    Dlg: Page "Nuevo Codigo Dialog";
                    NuevoNombre: Code[30];
                begin
                    Dlg.SetCodigo(CopyStr(Rec."Nombre Variable" + '_2', 1, 30));
                    if Dlg.RunModal() <> Action::OK then exit;
                    NuevoNombre := CopyStr(Dlg.GetCodigo(), 1, 30);
                    if NuevoNombre = '' then exit;
                    Rec.CopiarEn(NuevoNombre);
                    Message(MsgCopiada, NuevoNombre);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        IsFuncFechas := EsFuncFechas();
        RefreshNames();
        CurrPage.Filtros.Page.SetIdTabla(Rec."Id. Tabla");
    end;

    var
        NombreTabla: Text[250];
        NombreCampoValor: Text[100];
        NombreFechaInicio: Text[100];
        NombreFechaFin: Text[100];
        IsFuncFechas: Boolean;
        MsgCopiada: Label 'Fuente de datos copiada como ''%1''.';

    local procedure RefreshNames()
    begin
        NombreTabla := GetTableName(Rec."Id. Tabla");
        NombreCampoValor := GetFieldName(Rec."Id. Tabla", Rec."No. Campo Valor");
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
