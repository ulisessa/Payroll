namespace UAS.Payroll;

page 50109 "Personal Proyecto"
{
    ApplicationArea = All;
    Caption = 'Personal Proyecto';
    DelayedInsert = true;
    PageType = ListPart;
    SourceTable = "Personal Proyecto";
    // Lo más nuevo arriba, igual que el historial de estados. Un tripulante con años de antigüedad
    // acumula una asignación por marea, y la que interesa —la actual— quedaba al final.
    // Ordena por la clave K4 (No. Empleado, Fecha Alta Asignación) y no por la fecha sola: un campo
    // suelto no tiene índice que lo sostenga y BC lo resuelve ordenando en memoria.
    SourceTableView = sorting("No. Empleado", "Fecha Alta Asignación") order(descending);
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("No. Proyecto"; Rec."No. Proyecto") { ApplicationArea = All; }
                field(Buque; Rec.Buque) { ApplicationArea = All; Editable = false; }
                field(Marea; Rec.Marea) { ApplicationArea = All; Editable = false; }
                field("Fecha Alta Asignación"; Rec."Fecha Alta Asignación") { ApplicationArea = All; }
                field("Fecha Baja"; Rec."Fecha Baja") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LiquidarTripulante)
            {
                ApplicationArea = All;
                Caption = 'Crear Liquidación';
                Image = CreateDocument;
                ToolTip = 'Crea una liquidación en borrador para este empleado en el proyecto actual.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Periodo: Record "Período Liquidación";
                    TipoLiqRec: Record "Tipo Liquidación";
                    ProcLiq: Codeunit "Proceso Liq. Por Lote";
                    CodPeriodo: Code[10];
                    NoLiq: Code[20];
                begin
                    Rec.TestField("No. Empleado");
                    Rec.TestField("No. Proyecto");

                    CodPeriodo := Periodo.PeriodoPorDefecto();
                    if CodPeriodo = '' then
                        Error(ErrSinPeriodo);

                    // El tipo se elige y no se infiere. Sin él la liquidación nace en blanco y el
                    // motor filtra mal los conceptos restringidos por tipo sin avisar de nada; en el
                    // árbol esas liquidaciones se juntaban todas bajo un nodo sin nombre. Mismo
                    // criterio que Crear Liq. para Empleado, que corta antes de crear nada.
                    TipoLiqRec.SetRange(Activo, true);
                    if Page.RunModal(Page::"Tipos Liquidación", TipoLiqRec) <> Action::LookupOK then
                        exit;

                    // La cabecera la arma Proceso Liq. Por Lote y no esta página: ahí ya está
                    // resuelto de dónde sale cada campo —el nombre desnormalizado del empleado y la
                    // Fecha Liquidación, que en un Cierre de Marea es el arribo y no el fin de
                    // período—. Armándola a mano acá se escapaban justo esos.
                    NoLiq := ProcLiq.CrearParaAsignacion(Rec, CodPeriodo, TipoLiqRec.Código);
                    if NoLiq = '' then begin
                        Message(MsgYaExiste, CodPeriodo, TipoLiqRec.Código);
                        exit;
                    end;
                    if Liq.Get(NoLiq) then
                        Page.Run(Page::"Ficha Liquidación", Liq);
                end;
            }
        }
    }

    var
        ErrSinPeriodo: Label 'No hay ningún período de liquidación abierto que contenga la fecha de trabajo. Cree o abra el período antes de liquidar.';
        MsgYaExiste: Label 'Este empleado ya tiene una liquidación de tipo %2 para el período %1 en este proyecto.', Comment = '%1=código de período, %2=código de tipo de liquidación';
}
