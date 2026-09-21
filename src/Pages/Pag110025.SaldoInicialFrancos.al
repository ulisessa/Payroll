namespace UAS.Payroll;

// Carga del saldo de francos con el que cada tripulante arranca en el sistema.
//
// Los francos ganados antes de la puesta en marcha no están en ninguna liquidación, y el ledger sólo
// sabe de lo que el motor liquidó. Acá se cargan a mano o se pegan desde Excel, se revisan, y recién
// entonces se aplican: el proceso genera los lotes y deja anotado cuál salió de cada fila, para poder
// revertirlo si la carga estaba mal.
//
// Una fila por tripulante Y categoría. Los francos no son fungibles: se pagan al valor de la
// categoría en que se ganaron, así que quien ascendió necesita una fila por cada categoría en la que
// devengó, con su propia fecha — que es la que decide el orden FIFO en que se van a consumir.
page 110025 "Saldo Inicial de Francos"
{
    ApplicationArea = All;
    Caption = 'Saldo Inicial de Francos';
    PageType = List;
    UsageCategory = Tasks;
    SourceTable = "Saldo Inicial Francos Liq.";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            group(Destino)
            {
                Caption = 'Dónde se generan los lotes';

                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Período de las liquidaciones que van a contener los lotes. Los lotes NO se fechan con este período: cada uno lleva su propia fecha de devengo, que es la que ordena el FIFO.';
                }
                field(TipoLiq; TipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de Liquidación';
                    TableRelation = "Tipo Liquidación".Código;
                    ToolTip = 'Conviene un tipo propio (por ejemplo SALDO INICIAL) para poder distinguir después estas liquidaciones de las reales. Nacen Aprobadas y con importe cero: existen sólo para que los lotes tengan cabecera.';
                }
            }
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Convenio en el que se ganaron estos francos, que puede no ser el encuadre actual del tripulante.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    ToolTip = 'Categoría en la que se ganaron. Es la que fija el precio al que se van a pagar: no la de hoy, la de entonces.';
                }
                field("Fecha Devengo"; Rec."Fecha Devengo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuándo se ganaron. Decide el lugar del lote en la cola FIFO, y por lo tanto a qué precio se paga el próximo franco que el tripulante se tome.';
                }
                field(Días; Rec.Días) { ApplicationArea = All; }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
                field(Aplicado; Rec.Aplicado)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                    StyleExpr = Rec.Aplicado;
                }
                field("No. Liquidación Generada"; Rec."No. Liquidación Generada")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Liquidación en la que quedó el lote generado por esta fila. Abrila para ver la línea.';

                    trigger OnDrillDown()
                    var
                        Liq: Record "Liquidación";
                    begin
                        if Liq.Get(Rec."No. Liquidación Generada") then
                            Page.Run(Page::"Ficha Liquidación", Liq);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AplicarCarga)
            {
                ApplicationArea = All;
                Caption = 'Aplicar';
                Image = PostDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Genera los lotes de francos de todas las filas pendientes. Antes valida la carga entera: si algo está mal no escribe nada, para no dejar el ledger a medio armar.';

                trigger OnAction()
                var
                    Carga: Record "Saldo Inicial Francos Liq.";
                    Proceso: Codeunit "Saldo Inicial Francos Liq.";
                    Aplicadas: Integer;
                begin
                    if not Confirm(QstAplicar, false) then
                        exit;
                    Proceso.SetDestino(CodPeriodo, TipoLiq, 0D);
                    Aplicadas := Proceso.Aplicar(Carga);
                    Message(MsgAplicadas, Aplicadas);
                    CurrPage.Update(false);
                end;
            }
            action(RevertirCarga)
            {
                ApplicationArea = All;
                Caption = 'Revertir';
                Image = Undo;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Borra los lotes que generó esta carga y vuelve a dejar las filas editables. Toca solamente las líneas que anotó al aplicar: los francos que el tripulante haya devengado liquidando no se tocan.';

                trigger OnAction()
                var
                    Carga: Record "Saldo Inicial Francos Liq.";
                    Proceso: Codeunit "Saldo Inicial Francos Liq.";
                    Revertidas: Integer;
                begin
                    if not Confirm(QstRevertir, false) then
                        exit;
                    Revertidas := Proceso.Revertir(Carga);
                    Message(MsgRevertidas, Revertidas);
                    CurrPage.Update(false);
                end;
            }
            action(VerFrancos)
            {
                ApplicationArea = All;
                Caption = 'Ver saldos';
                Image = Absence;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = Page "Francos por Tripulante";
                ToolTip = 'Abre el control de francos para comprobar cómo quedaron los saldos después de aplicar la carga.';
            }
        }
    }

    var
        CodPeriodo: Code[10];
        TipoLiq: Code[20];
        QstAplicar: Label 'Se van a generar los lotes de francos de todas las filas pendientes. ¿Continuar?';
        QstRevertir: Label 'Se van a borrar los lotes generados por esta carga y las filas van a quedar editables otra vez. ¿Continuar?';
        MsgAplicadas: Label '%1 fila(s) aplicada(s).';
        MsgRevertidas: Label '%1 fila(s) revertida(s).';
}
