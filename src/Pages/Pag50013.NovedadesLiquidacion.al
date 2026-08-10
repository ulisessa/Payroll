namespace UAS.Payroll;

page 50013 "Novedades Liquidación"
{
    ApplicationArea = All;
    Caption = 'Novedades de Liquidación';
    PageType = Worksheet;
    UsageCategory = Tasks;
    SourceTable = "Novedad Liquidación";
    SourceTableView = sorting("Cód. Período", "No. Empleado", "Cód. Concepto");
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    // Hoja de carga previa a la liquidación. Lo cargado acá lo materializa el motor como Incidencia
    // al calcular; ver Cod50061.

    layout
    {
        area(Content)
        {
            group(GrpPeriodo)
            {
                ShowCaption = false;

                field(CodPeriodoFiltro; CodPeriodoFiltro)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Período sobre el que se cargan las novedades. Se propone el que contiene la fecha de trabajo.';

                    trigger OnValidate()
                    begin
                        AplicarFiltroPeriodo();
                        CurrPage.Update(false);
                    end;
                }
            }
            repeater(Lines)
            {
                field(Fecha; Rec.Fecha)
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha dentro del período. Define a qué liquidación entra cuando el empleado tiene más de una en el mismo período: un cierre de marea solo toma las novedades fechadas dentro del viaje.';
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Empleado al que aplica. En blanco, la novedad alcanza a todos los que cumplan Convenio, Categoría y Tipo Liquidación.';
                }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field(Alcance; Alcance)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance';
                    Editable = false;
                    ToolTip = 'A quiénes alcanza esta novedad, leyendo juntos Empleado, Convenio, Categoría y Tipo Liquidación.';
                }
                field("No. Proyecto"; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = cualquier proyecto. Cargado, la novedad entra únicamente en la liquidación de esa marea, sin depender de la Fecha.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = cualquier convenio.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = cualquier categoría.';
                }
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = cualquier tipo de liquidación (mensual, cierre de marea, SAC…).';
                }
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field(DescConcepto; DescConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                }
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; }
                field("Unidad Cantidad"; Rec."Unidad Cantidad") { ApplicationArea = All; }
                field("Valor Unitario"; Rec."Valor Unitario") { ApplicationArea = All; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    ToolTip = 'Si cargás Cantidad y Valor Unitario se calcula solo; también podés escribirlo directamente. Varias novedades del mismo concepto y empleado se suman en una sola incidencia.';
                }
                field(Recurrente; Rec.Recurrente)
                {
                    ApplicationArea = All;
                    ToolTip = 'La novedad se vuelve a generar en el período siguiente cuando se usa "Generar recurrentes".';
                }
                field("Períodos Restantes"; Rec."Períodos Restantes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuántos períodos más se va a repetir. 0 con Recurrente marcado = indefinidamente, hasta que se desmarque.';
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                }
                field("No. Liquidación"; Rec."No. Liquidación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Liquidación en la que entró esta novedad.';

                    trigger OnDrillDown()
                    var
                        Liq: Record "Liquidación";
                    begin
                        if Liq.Get(Rec."No. Liquidación") then
                            Page.Run(Page::"Ficha Liquidación", Liq);
                    end;
                }
                field("Motivo No Aplicada"; Rec."Motivo No Aplicada")
                {
                    ApplicationArea = All;
                    StyleExpr = 'Unfavorable';
                    ToolTip = 'Por qué el motor la salteó en el último cálculo.';
                }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportarArchivo)
            {
                ApplicationArea = All;
                Caption = 'Importar de Excel/CSV';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Carga novedades desde un archivo, una por fila, en este orden de columnas: No. Empleado, Cód. Concepto, Cantidad, Valor Unitario, Importe, Fecha, Cód. Tipo Liq., Observaciones, No. Proyecto. La fila de encabezado y cualquier fila cuyo empleado o concepto no exista se saltean y se informan al final.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Novedades Liq.";
                    Importadas: Integer;
                    Omitidas: Integer;
                begin
                    VerificarPeriodoElegido();
                    Importadas := Gestion.ImportarArchivo(CodPeriodoFiltro, Omitidas);
                    Message(MsgImportadas, Importadas, Omitidas);
                    CurrPage.Update(false);
                end;
            }
            action(CopiarDePeriodo)
            {
                ApplicationArea = All;
                Caption = 'Copiar de otro período';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Copia al período actual las novedades de otro período (se propone el anterior). No duplica: saltea las que ya existan para el mismo empleado, concepto, convenio, categoría y tipo de liquidación.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Novedades Liq.";
                    Periodo: Record "Período Liquidación";
                    Origen: Record "Período Liquidación";
                    CodOrigen: Code[10];
                    Copiadas: Integer;
                begin
                    VerificarPeriodoElegido();
                    CodOrigen := Periodo.PeriodoAnterior(CodPeriodoFiltro);
                    if CodOrigen <> '' then
                        if Origen.Get(CodOrigen) then;
                    if Page.RunModal(Page::"Períodos Liquidación", Origen) <> Action::LookupOK then
                        exit;
                    Copiadas := Gestion.CopiarDePeriodo(Origen.Código, CodPeriodoFiltro);
                    Message(MsgCopiadas, Copiadas, Origen.Código, CodPeriodoFiltro);
                    CurrPage.Update(false);
                end;
            }
            action(GenerarRecurrentes)
            {
                ApplicationArea = All;
                Caption = 'Generar recurrentes';
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Trae al período actual las novedades marcadas Recurrente del período inmediatamente anterior, descontando un período al contador. Se puede correr dos veces sin duplicar.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Novedades Liq.";
                    Generadas: Integer;
                begin
                    VerificarPeriodoElegido();
                    Generadas := Gestion.GenerarRecurrentes(CodPeriodoFiltro);
                    Message(MsgGeneradas, Generadas, CodPeriodoFiltro);
                    CurrPage.Update(false);
                end;
            }
            action(Anular)
            {
                ApplicationArea = All;
                Caption = 'Anular';
                Image = Cancel;
                ToolTip = 'Excluye las novedades seleccionadas: no se aplican, no se copian y no se recurren. Si alguna ya había entrado en una liquidación en Borrador, se deshace lo generado por novedades en esa liquidación y el próximo cálculo la rearma sin ésta.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Novedades Liq.";
                    Sel: Record "Novedad Liquidación";
                begin
                    CurrPage.SetSelectionFilter(Sel);
                    if Sel.FindSet(true) then
                        repeat
                            Gestion.AnularNovedad(Sel);
                        until Sel.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(Reactivar)
            {
                ApplicationArea = All;
                Caption = 'Reactivar';
                Image = ReOpen;
                ToolTip = 'Vuelve a Pendiente las novedades anuladas seleccionadas, para que el próximo cálculo las tome.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Novedades Liq.";
                    Sel: Record "Novedad Liquidación";
                begin
                    CurrPage.SetSelectionFilter(Sel);
                    if Sel.FindSet(true) then
                        repeat
                            Gestion.ReactivarNovedad(Sel);
                        until Sel.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Periodo: Record "Período Liquidación";
        FiltroRecibido: Code[10];
    begin
        // Si nos abrieron ya filtrados por un período (desde la Ficha Liquidación, por ejemplo),
        // manda ese; si no, el período de trabajo. Sin esto la hoja pisaría el filtro de quien la
        // abrió y mostraría otro período.
        FiltroRecibido := CopyStr(Rec.GetFilter("Cód. Período"), 1, MaxStrLen(FiltroRecibido));
        if (FiltroRecibido <> '') and Periodo.Get(FiltroRecibido) then
            CodPeriodoFiltro := FiltroRecibido
        else
            CodPeriodoFiltro := Periodo.PeriodoPorDefecto();
        AplicarFiltroPeriodo();
    end;

    // El período de la hoja se hereda en cada línea nueva: es el único campo obligatorio que el
    // usuario no debería tener que repetir fila por fila.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if CodPeriodoFiltro <> '' then
            Rec.Validate("Cód. Período", CodPeriodoFiltro);
    end;

    trigger OnAfterGetRecord()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Alcance := Rec.DescribirAlcance();

        Concepto.SetRange(Código, Rec."Cód. Concepto");
        if Concepto.FindLast() then
            DescConcepto := Concepto.Descripción
        else
            DescConcepto := '';

        case Rec.Estado of
            Rec.Estado::Aplicada:
                EstadoStyle := 'Favorable';
            Rec.Estado::Anulada:
                EstadoStyle := 'Subordinate';
            else
                if Rec."Motivo No Aplicada" <> '' then
                    EstadoStyle := 'Unfavorable'
                else
                    EstadoStyle := 'Attention';
        end;
    end;

    local procedure AplicarFiltroPeriodo()
    begin
        if CodPeriodoFiltro <> '' then
            Rec.SetRange("Cód. Período", CodPeriodoFiltro)
        else
            Rec.SetRange("Cód. Período");
    end;

    local procedure VerificarPeriodoElegido()
    begin
        if CodPeriodoFiltro = '' then
            Error(ErrSinPeriodo);
    end;

    var
        CodPeriodoFiltro: Code[10];
        Alcance: Text;
        DescConcepto: Text[100];
        EstadoStyle: Text[20];
        ErrSinPeriodo: Label 'Elegí primero el Período de la hoja.';
        MsgImportadas: Label 'Se importaron %1 novedad(es). %2 fila(s) omitida(s) por empleado o concepto inexistente (incluida la fila de encabezado).';
        MsgCopiadas: Label 'Se copiaron %1 novedad(es) de %2 a %3. Las que ya existían en el destino no se duplicaron.';
        MsgGeneradas: Label 'Se generaron %1 novedad(es) recurrente(s) en %2.';
}
