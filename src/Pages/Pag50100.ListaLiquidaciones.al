namespace UAS.Payroll;

page 50100 "Lista Liquidaciones"
{
    ApplicationArea = All;
    Caption = 'Liquidaciones';
    CardPageId = "Ficha Liquidación";
    PageType = List;
    SourceTable = "Liquidación";
    UsageCategory = Lists;
    Editable = false;
    PromotedActionCategories = 'Nuevo,Proceso,Informe,Liquidar';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field("Cód. Período"; Rec."Cód. Período")
                {
                    ApplicationArea = All;
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                }
                field("Nombre Empleado"; Rec."Nombre Empleado")
                {
                    ApplicationArea = All;
                }
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.")
                {
                    ApplicationArea = All;
                }
                field(Job; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                }
                field("Total Haberes"; Rec."Total Haberes")
                {
                    ApplicationArea = All;
                }
                field("Total Descuentos"; Rec."Total Descuentos")
                {
                    ApplicationArea = All;
                }
                field("Neto a Pagar"; Rec."Neto a Pagar")
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
            }
        }
        area(FactBoxes)
        {
            systempart(Control1; Links) { ApplicationArea = All; }
            systempart(Control2; Notes) { ApplicationArea = All; }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalcularSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Calcular';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                ToolTip = 'Calcula todas las liquidaciones marcadas en la lista que estén en estado Borrador o Calculada.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Motor: Codeunit "Motor Liquidación";
                    Registro: Codeunit "Registro Procesos Liq.";
                    Progreso: Dialog;
                    Total: Integer;
                    Procesadas: Integer;
                    Calculadas: Integer;
                    Fallidas: Integer;
                begin
                    CurrPage.SetSelectionFilter(LiqSel);
                    LiqSel.SetFilter(Estado, '%1|%2|%3', LiqSel.Estado::Borrador, LiqSel.Estado::Calculada, LiqSel.Estado::Aprobada);
                    // El Count va ANTES del FindSet: contar reposiciona el cursor.
                    Total := LiqSel.Count();
                    if not LiqSel.FindSet(true) then begin
                        Message(MsgSinSeleccion);
                        exit;
                    end;
                    // Una corrida = una sesión: los registros quedan agrupados y se pueden mirar
                    // todos juntos desde cualquiera de ellos.
                    Registro.IniciarSesion();
                    Progreso.Open(TxtProgresoCalculo);
                    repeat
                        Procesadas += 1;
                        Progreso.Update(1, LiqSel."No.");
                        Progreso.Update(2, LiqSel."No. Empleado");
                        Progreso.Update(3, Round(Procesadas / Total * 10000, 1));
                        if Motor.LiquidarConRegistro(LiqSel) then
                            Calculadas += 1
                        else
                            Fallidas += 1;
                    until LiqSel.Next() = 0;
                    Progreso.Close();
                    Registro.CerrarSesion();
                    CurrPage.Update(false);

                    // Una liquidación que falla ya no aborta el lote: queda anotada y el proceso
                    // sigue. Antes, un error en la número 50 se llevaba puestas las 49 anteriores.
                    if Fallidas > 0 then
                        Message(MsgCalculadasConFallas, Calculadas, Fallidas)
                    else
                        if Motor.GetAdvertencias() <> '' then
                            Message(MsgCalculadasConAdvertencias, Calculadas, Motor.GetAdvertencias())
                        else
                            Message(MsgCalculadas, Calculadas);
                end;
            }
            action(Aprobar)
            {
                ApplicationArea = All;
                Caption = 'Aprobar';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    Gestion.Aprobar(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Reabrir)
            {
                ApplicationArea = All;
                Caption = 'Reabrir';
                Image = ReOpen;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                ToolTip = 'Reabre las liquidaciones marcadas que estén en estado Calculada, devolviéndolas a Borrador.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Liq: Record "Liquidación";
                    Gestion: Codeunit "Gestión Liquidación";
                    Registro: Codeunit "Registro Procesos Liq.";
                    Numeros: List of [Code[20]];
                    Numero: Code[20];
                    Reabiertas: Integer;
                begin
                    CurrPage.SetSelectionFilter(LiqSel);
                    LiqSel.SetRange(Estado, LiqSel.Estado::Calculada);
                    if not LiqSel.FindSet() then begin
                        Message(MsgSinSeleccionReabrir);
                        exit;
                    end;

                    // Se juntan las claves ANTES de tocar nada. Reabrir pasa el Estado a Borrador,
                    // que es justo el campo filtrado: al modificarlo el registro se cae del filtro y
                    // el Next() siguiente devuelve 0, así que el lote reabría solo la primera y se
                    // cortaba sin avisar. Mismo problema y misma solución que LimpiarParaRecalculo
                    // en Gestión Novedades Liq.
                    repeat
                        Numeros.Add(LiqSel."No.");
                    until LiqSel.Next() = 0;

                    // Una corrida = una sesión, igual que Calcular: las reaperturas del lote quedan
                    // agrupadas y se pueden mirar juntas desde cualquiera de ellas.
                    Registro.IniciarSesion();
                    foreach Numero in Numeros do
                        if Liq.Get(Numero) then
                            // Se revalida el estado porque entre el armado de la lista y este punto
                            // el registro pudo cambiar; Reabrir tira Error si no está Calculada.
                            if Liq.Estado = Liq.Estado::Calculada then begin
                                Gestion.Reabrir(Liq);
                                Reabiertas += 1;
                            end;
                    Registro.CerrarSesion();

                    Message(MsgReabiertas, Reabiertas);
                    CurrPage.Update(false);
                end;
            }
            action(EliminarSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Eliminar Selección';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Elimina las liquidaciones seleccionadas que estén en estado Borrador.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Eliminadas: Integer;
                    Omitidas: Integer;
                begin
                    CurrPage.SetSelectionFilter(LiqSel);
                    if not LiqSel.FindSet() then exit;

                    if not Confirm(QstEliminarSeleccion) then
                        exit;

                    repeat
                        if LiqSel.Estado = LiqSel.Estado::Borrador then begin
                            LiqSel.Delete(true);
                            Eliminadas += 1;
                        end else
                            Omitidas += 1;
                    until LiqSel.Next() = 0;

                    CurrPage.Update(false);
                    Message(MsgEliminadasSel, Eliminadas, Omitidas);
                end;
            }
            action(RevertirAprobacion)
            {
                ApplicationArea = All;
                Caption = 'Revertir Aprobación';
                Image = Undo;
                ToolTip = 'Devuelve la liquidación al estado Calculada para permitir su revisión o corrección.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    if Gestion.RevertirAprobacion(Rec) then
                        CurrPage.Update(false);
                end;
            }
        }
        area(Reporting)
        {
            action(ImprimirRecibo)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibo';
                Image = Print;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Imprime el recibo de sueldo de la liquidación seleccionada.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    Liq.SetRange("No.", Rec."No.");
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
            action(ImprimirReciboSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibo (Selección)';
                Image = PrintReport;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Imprime los recibos de sueldo de todas las liquidaciones marcadas.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    CurrPage.SetSelectionFilter(Liq);
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
        }
        area(Navigation)
        {
            action(VerLineas)
            {
                ApplicationArea = All;
                Caption = 'Ver Líneas';
                Image = Line;
                RunObject = Page "Líneas Liquidación";
                RunPageLink = "No. Liquidación" = FIELD("No.");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SetEstadoStyle();
    end;

    local procedure SetEstadoStyle()
    begin
        case Rec.Estado of
            Rec.Estado::Borrador:
                EstadoStyle := 'Subordinate';
            Rec.Estado::Calculada:
                EstadoStyle := 'Favorable';
            Rec.Estado::Aprobada:
                EstadoStyle := 'Strong';
            Rec.Estado::Contabilizada:
                EstadoStyle := 'Attention';
        end;
    end;

    var
        EstadoStyle: Text;
        MsgSinSeleccion: Label 'No hay liquidaciones en estado Borrador o Calculada en la selección.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s).';
        MsgCalculadasConFallas: Label '%1 liquidación(es) calculada(s), %2 con error.\\Las que fallaron quedaron sin calcular; el motivo de cada una está en Registros de Proceso.';
        MsgCalculadasConAdvertencias: Label '%1 liquidación(es) calculada(s).\\Atención — parámetros posiblemente desactualizados:\%2';
        QstEliminarSeleccion: Label '¿Eliminar las liquidaciones seleccionadas en estado Borrador? Las que no estén en Borrador se omitirán.';
        MsgEliminadasSel: Label '%1 liquidación(es) eliminada(s). %2 omitida(s) por no estar en Borrador.';
        // Los #n# son campos de texto y el @n@ es la barra de avance, que va de 0 a 10000.
        TxtProgresoCalculo: Label 'Calculando liquidaciones\\Liquidación  #1##################\Empleado     #2##################\\Progreso     @3@@@@@@@@@@@@@@@@@@@@';
        MsgSinSeleccionReabrir: Label 'No hay liquidaciones en estado Calculada en la selección.';
        MsgReabiertas: Label '%1 liquidación(es) reabierta(s).';
}
