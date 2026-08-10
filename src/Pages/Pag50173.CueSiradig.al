namespace UAS.Payroll;

page 50173 "Cue SIRADIG"
{
    Caption = 'SIRADIG';
    PageType = CardPart;
    SourceTable = "Cue SIRADIG";

    layout
    {
        area(Content)
        {
            cuegroup(GrpSiradig)
            {
                Caption = 'SIRADIG';

                field("Pendientes"; Rec."Pendientes")
                {
                    ApplicationArea = All;
                    Caption = 'Pendientes de Procesar';
                    ToolTip = 'Especifica la cantidad de importaciones SIRADIG pendientes de procesar.';
                    StyleExpr = PendientesStyleExpr;

                    trigger OnDrillDown()
                    begin
                        AbrirLista("Estado Importación SIRADIG"::"Pendiente Procesar");
                    end;
                }
                field("Con Errores"; Rec."Con Errores")
                {
                    ApplicationArea = All;
                    Caption = 'Con Errores';
                    ToolTip = 'Especifica la cantidad de importaciones SIRADIG con errores de procesamiento.';
                    StyleExpr = ConErroresStyleExpr;

                    trigger OnDrillDown()
                    begin
                        AbrirLista("Estado Importación SIRADIG"::"Error en Procesamiento");
                    end;
                }
                field("Procesados"; Rec."Procesados")
                {
                    ApplicationArea = All;
                    Caption = 'Importados Exitosamente';
                    ToolTip = 'Especifica la cantidad de archivos SIRADIG importados y procesados correctamente. Al hacer clic se abre la lista con esas importaciones.';
                    StyleExpr = ProcesadosStyleExpr;

                    trigger OnDrillDown()
                    begin
                        AbrirLista("Estado Importación SIRADIG"::"Procesado Exitosamente");
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert();
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Pendientes", "Con Errores", "Procesados");

        if Rec."Pendientes" > 0 then
            PendientesStyleExpr := 'Ambiguous'
        else
            PendientesStyleExpr := 'None';

        if Rec."Con Errores" > 0 then
            ConErroresStyleExpr := 'Unfavorable'
        else
            ConErroresStyleExpr := 'None';

        if Rec."Procesados" > 0 then
            ProcesadosStyleExpr := 'Favorable'
        else
            ProcesadosStyleExpr := 'None';
    end;

    var
        PendientesStyleExpr: Text;
        ConErroresStyleExpr: Text;
        ProcesadosStyleExpr: Text;

    local procedure AbrirLista(Estado: Enum "Estado Importación SIRADIG")
    var
        ImportacionSiradig: Record "Importación SIRADIG";
        ImportacionesPage: Page "Importaciones SIRADIG";
    begin
        ImportacionSiradig.SetRange(Estado, Estado);
        ImportacionesPage.SetTableView(ImportacionSiradig);
        ImportacionesPage.Run();
    end;
}
