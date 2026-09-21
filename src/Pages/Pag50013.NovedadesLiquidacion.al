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
                    ShowMandatory = true;
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Período sobre el que se cargan las novedades. Se propone el que contiene la fecha de trabajo. Junto con el Concepto son los dos únicos datos obligatorios de una novedad: todo lo demás se puede dejar en blanco y el motor lo resuelve.';

                    trigger OnValidate()
                    begin
                        AplicarFiltroPeriodo();
                        ContarEstados();
                        CurrPage.Update(false);
                    end;
                }
                field(CantPendientes; CantPendientes)
                {
                    ApplicationArea = All;
                    Caption = 'Pendientes';
                    Editable = false;
                    Style = Ambiguous;
                    StyleExpr = CantPendientes > 0;
                    ToolTip = 'Novedades del período que todavía no entraron en ninguna liquidación. Antes de cerrar el período esto tendría que estar en cero: lo que quede acá no se le pagó a nadie.';
                }
                field(CantAplicadas; CantAplicadas)
                {
                    ApplicationArea = All;
                    Caption = 'Aplicadas';
                    Editable = false;
                }
                field(CantNoAplicadas; CantNoAplicadas)
                {
                    ApplicationArea = All;
                    Caption = 'Con motivo de no aplicación';
                    Editable = false;
                    Style = Attention;
                    StyleExpr = CantNoAplicadas > 0;
                    ToolTip = 'Novedades que el motor evaluó y descartó, con el motivo anotado. Son las que hay que mirar: alguien las cargó esperando que se pagaran.';
                }
                field(CantAnuladas; CantAnuladas)
                {
                    ApplicationArea = All;
                    Caption = 'Anuladas';
                    Editable = false;
                }
            }
            repeater(Lines)
            {
                field(Fecha; Rec.Fecha)
                {
                    ApplicationArea = All;
                    ToolTip = 'Día al que corresponde la novedad, dentro del período. Es lo que decide en qué liquidación entra: se mira qué estaba haciendo el empleado ese día —navegando, en francos, en puerto— y la novedad va a la liquidación de ese proyecto. En blanco aplica a todo el período y no distingue entre las liquidaciones del empleado.';
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
                    ToolTip = 'Normalmente se deja en blanco: el proyecto lo deduce la Fecha, mirando el historial de estados del empleado ese día. Cargalo sólo para forzar la novedad a una marea concreta, ignorando lo que diga el historial.';
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
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Qué se paga o se descuenta. Es el único dato que la novedad no puede deducir de nada: sin concepto no hay nada que liquidar.';
                }
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
        ContarEstados();
    end;

    // El período de la hoja se hereda en cada línea nueva: es el único campo obligatorio que el
    // usuario no debería tener que repetir fila por fila.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if CodPeriodoFiltro <> '' then
            Rec.Validate("Cód. Período", CodPeriodoFiltro);
    end;

    trigger OnAfterGetRecord()
    begin
        Alcance := Rec.DescribirAlcance();
        DescConcepto := DescMgt.Descripcion(Rec."Cód. Concepto");

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

    /// <remarks>
    /// Cuenta sobre una instancia aparte y no sobre Rec: contar exigiría cambiarle los filtros a la
    /// grilla, y el usuario vería la hoja saltando de vista sola cada vez que se recalculan los
    /// números.
    /// </remarks>
    local procedure ContarEstados()
    var
        Nov: Record "Novedad Liquidación";
    begin
        CantPendientes := 0;
        CantAplicadas := 0;
        CantAnuladas := 0;
        CantNoAplicadas := 0;
        if CodPeriodoFiltro = '' then
            exit;

        Nov.SetCurrentKey("Cód. Período", Estado);
        Nov.SetRange("Cód. Período", CodPeriodoFiltro);

        Nov.SetRange(Estado, Nov.Estado::Pendiente);
        CantPendientes := Nov.Count();
        Nov.SetRange(Estado, Nov.Estado::Aplicada);
        CantAplicadas := Nov.Count();
        Nov.SetRange(Estado, Nov.Estado::Anulada);
        CantAnuladas := Nov.Count();

        // Las descartadas no son un estado sino un motivo anotado: pueden haber quedado Pendientes
        // después de que el motor las evaluara y las dejara afuera.
        Nov.SetRange(Estado);
        Nov.SetFilter("Motivo No Aplicada", '<>%1', '');
        CantNoAplicadas := Nov.Count();
    end;

    local procedure VerificarPeriodoElegido()
    begin
        if CodPeriodoFiltro = '' then
            Error(ErrSinPeriodo);
    end;

    var
        CodPeriodoFiltro: Code[10];
        CantPendientes: Integer;
        CantAplicadas: Integer;
        CantAnuladas: Integer;
        CantNoAplicadas: Integer;
        Alcance: Text;
        DescConcepto: Text[100];
        DescMgt: Codeunit "Descripción Concepto Liq.";
        EstadoStyle: Text[20];
        ErrSinPeriodo: Label 'Elegí primero el Período de la hoja.';
        MsgImportadas: Label 'Se importaron %1 novedad(es). %2 fila(s) omitida(s) por empleado o concepto inexistente (incluida la fila de encabezado).';
        MsgCopiadas: Label 'Se copiaron %1 novedad(es) de %2 a %3. Las que ya existían en el destino no se duplicaron.';
        MsgGeneradas: Label 'Se generaron %1 novedad(es) recurrente(s) en %2.';
}
