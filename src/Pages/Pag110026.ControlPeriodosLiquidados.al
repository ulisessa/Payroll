namespace UAS.Payroll;

// Control de días liquidados: una fila por empleado, una columna por estado con los días que pasó en
// él, y al final cuántos de esos días quedaron sin liquidar.
//
// Es la planilla que el liquidador venía llevando a mano. Se lee de izquierda a derecha: los días del
// rango se reparten entre los estados, y si la suma no llega —o si "Sin Liquidar" no es cero— a esa
// persona le falta algo.
//
// La unidad es el día y no el período, y esa es toda la diferencia: un tripulante que estuvo en dos
// mareas del 1 al 20 de julio tiene dos liquidaciones de julio, así que por período el mes figura
// cubierto — cuando del 21 al 31 no se le liquidó nada.
//
// Las 32 columnas son el máximo del patrón de matriz de Business Central. Es de sobra para los
// estados que suele haber; si alguna vez no alcanzara, se recorren con "Estados siguientes".
page 110026 "Control de Cobertura Liq."
{
    ApplicationArea = All;
    Caption = 'Días Liquidados por Empleado';
    PageType = List;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = "Cobertura Liq. Buffer";
    SourceTableTemporary = true;
    SourceTableView = sorting("Nombre Empleado");
    InsertAllowed = false;
    DeleteAllowed = false;
    // Sin "Editable = false" ni "ModifyAllowed = false" a nivel página: bloquean TODOS los controles,
    // incluidos los de la cabecera, que no pertenecen al registro y son lo único que acá se escribe.
    // La grilla se protege campo por campo.

    layout
    {
        area(Content)
        {
            group(Rango)
            {
                Caption = 'Rango a controlar';

                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Período de liquidación a controlar. Elegirlo pone el rango en sus fechas; con los botones de período anterior y siguiente se recorre el calendario sin tocar las fechas a mano. Queda en blanco si el rango se editó a mano y no coincide con ningún período.';

                    trigger OnValidate()
                    var
                        Periodo: Record "Período Liquidación";
                    begin
                        if CodPeriodo = '' then
                            exit;
                        Periodo.Get(CodPeriodo);
                        FechaDesde := Periodo."Fecha Desde";
                        FechaHasta := Periodo."Fecha Hasta";
                        Cargar();
                    end;
                }
                field(FechaDesde; FechaDesde)
                {
                    ApplicationArea = All;
                    Caption = 'Desde';
                    ToolTip = 'Primer día del rango a controlar.';
                    trigger OnValidate()
                    begin
                        // El rango dejó de coincidir con un período: se limpia el código para no
                        // mostrar un período que no es el que se está viendo.
                        CodPeriodo := '';
                        Cargar();
                    end;
                }
                field(FechaHasta; FechaHasta)
                {
                    ApplicationArea = All;
                    Caption = 'Hasta';
                    ToolTip = 'Último día del rango. Cuidado con ponerlo en el futuro: los días que todavía no se liquidaron porque el mes no cerró aparecerían como faltantes.';
                    trigger OnValidate()
                    begin
                        // El rango dejó de coincidir con un período: se limpia el código para no
                        // mostrar un período que no es el que se está viendo.
                        CodPeriodo := '';
                        Cargar();
                    end;
                }
                field(FiltroEmpleado; FiltroEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Filtro de empleado';
                    ToolTip = 'Acepta un filtro de Business Central. En blanco, todos los que hayan tenido algún estado en el rango.';
                    trigger OnValidate()
                    begin
                        // No limpia el período: filtrar por empleado no cambia el rango de fechas.
                        Cargar();
                    end;
                }
                field(TotalEmpleados; TotalEmpleados)
                {
                    ApplicationArea = All;
                    Caption = 'Empleados';
                    Editable = false;
                }
                field(ConFaltantes; ConFaltantes)
                {
                    ApplicationArea = All;
                    Caption = 'Con días sin liquidar';
                    Editable = false;
                    Style = Attention;
                    StyleExpr = ConFaltantes > 0;
                    ToolTip = 'A cuántos empleados les falta liquidar algún día del rango. Es el número que se mira.';
                }
                field(TotalDias; TotalDias)
                {
                    ApplicationArea = All;
                    Caption = 'Días sin liquidar';
                    Editable = false;
                    Style = Attention;
                    StyleExpr = TotalDias > 0;
                }
                field(SinCobertura; SinCobertura)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones sin fechas de cobertura';
                    Editable = false;
                    Style = Ambiguous;
                    StyleExpr = SinCobertura > 0;
                    ToolTip = 'Liquidaciones anteriores a que se empezaran a guardar las fechas que cubren. Mientras haya alguna, este control las lee como si no cubrieran ningún día y muestra faltantes que no existen. Corregilo con "Completar fechas de cobertura".';
                }
                field(RangoEstados; RangoEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Estados a la vista';
                    Editable = false;
                    Visible = HayPaginado;
                }
            }
            repeater(Lines)
            {
                ShowCaption = false;

                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; Editable = false; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; Editable = false; }
                field("Fecha Alta"; Rec."Fecha Alta")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Fecha de alta. Recorta el rango: quien entró el 15 no debe la primera quincena.';
                }
                field("Fecha Baja"; Rec."Fecha Baja")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Fecha de baja. También recorta: quien se fue en junio no debe julio.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; Editable = false; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; Editable = false; }
                field(Field1; MATRIX_CellData[1])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[1];
                    DecimalPlaces = 0 : 0;
                    Visible = Field1Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(1);
                    end;
                }
                field(Field2; MATRIX_CellData[2])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[2];
                    DecimalPlaces = 0 : 0;
                    Visible = Field2Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(2);
                    end;
                }
                field(Field3; MATRIX_CellData[3])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[3];
                    DecimalPlaces = 0 : 0;
                    Visible = Field3Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(3);
                    end;
                }
                field(Field4; MATRIX_CellData[4])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[4];
                    DecimalPlaces = 0 : 0;
                    Visible = Field4Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(4);
                    end;
                }
                field(Field5; MATRIX_CellData[5])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[5];
                    DecimalPlaces = 0 : 0;
                    Visible = Field5Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(5);
                    end;
                }
                field(Field6; MATRIX_CellData[6])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[6];
                    DecimalPlaces = 0 : 0;
                    Visible = Field6Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(6);
                    end;
                }
                field(Field7; MATRIX_CellData[7])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[7];
                    DecimalPlaces = 0 : 0;
                    Visible = Field7Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(7);
                    end;
                }
                field(Field8; MATRIX_CellData[8])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[8];
                    DecimalPlaces = 0 : 0;
                    Visible = Field8Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(8);
                    end;
                }
                field(Field9; MATRIX_CellData[9])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[9];
                    DecimalPlaces = 0 : 0;
                    Visible = Field9Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(9);
                    end;
                }
                field(Field10; MATRIX_CellData[10])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[10];
                    DecimalPlaces = 0 : 0;
                    Visible = Field10Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(10);
                    end;
                }
                field(Field11; MATRIX_CellData[11])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[11];
                    DecimalPlaces = 0 : 0;
                    Visible = Field11Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(11);
                    end;
                }
                field(Field12; MATRIX_CellData[12])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[12];
                    DecimalPlaces = 0 : 0;
                    Visible = Field12Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(12);
                    end;
                }
                field(Field13; MATRIX_CellData[13])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[13];
                    DecimalPlaces = 0 : 0;
                    Visible = Field13Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(13);
                    end;
                }
                field(Field14; MATRIX_CellData[14])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[14];
                    DecimalPlaces = 0 : 0;
                    Visible = Field14Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(14);
                    end;
                }
                field(Field15; MATRIX_CellData[15])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[15];
                    DecimalPlaces = 0 : 0;
                    Visible = Field15Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(15);
                    end;
                }
                field(Field16; MATRIX_CellData[16])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[16];
                    DecimalPlaces = 0 : 0;
                    Visible = Field16Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(16);
                    end;
                }
                field(Field17; MATRIX_CellData[17])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[17];
                    DecimalPlaces = 0 : 0;
                    Visible = Field17Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(17);
                    end;
                }
                field(Field18; MATRIX_CellData[18])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[18];
                    DecimalPlaces = 0 : 0;
                    Visible = Field18Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(18);
                    end;
                }
                field(Field19; MATRIX_CellData[19])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[19];
                    DecimalPlaces = 0 : 0;
                    Visible = Field19Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(19);
                    end;
                }
                field(Field20; MATRIX_CellData[20])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[20];
                    DecimalPlaces = 0 : 0;
                    Visible = Field20Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(20);
                    end;
                }
                field(Field21; MATRIX_CellData[21])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[21];
                    DecimalPlaces = 0 : 0;
                    Visible = Field21Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(21);
                    end;
                }
                field(Field22; MATRIX_CellData[22])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[22];
                    DecimalPlaces = 0 : 0;
                    Visible = Field22Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(22);
                    end;
                }
                field(Field23; MATRIX_CellData[23])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[23];
                    DecimalPlaces = 0 : 0;
                    Visible = Field23Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(23);
                    end;
                }
                field(Field24; MATRIX_CellData[24])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[24];
                    DecimalPlaces = 0 : 0;
                    Visible = Field24Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(24);
                    end;
                }
                field(Field25; MATRIX_CellData[25])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[25];
                    DecimalPlaces = 0 : 0;
                    Visible = Field25Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(25);
                    end;
                }
                field(Field26; MATRIX_CellData[26])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[26];
                    DecimalPlaces = 0 : 0;
                    Visible = Field26Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(26);
                    end;
                }
                field(Field27; MATRIX_CellData[27])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[27];
                    DecimalPlaces = 0 : 0;
                    Visible = Field27Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(27);
                    end;
                }
                field(Field28; MATRIX_CellData[28])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[28];
                    DecimalPlaces = 0 : 0;
                    Visible = Field28Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(28);
                    end;
                }
                field(Field29; MATRIX_CellData[29])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[29];
                    DecimalPlaces = 0 : 0;
                    Visible = Field29Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(29);
                    end;
                }
                field(Field30; MATRIX_CellData[30])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[30];
                    DecimalPlaces = 0 : 0;
                    Visible = Field30Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(30);
                    end;
                }
                field(Field31; MATRIX_CellData[31])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[31];
                    DecimalPlaces = 0 : 0;
                    Visible = Field31Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(31);
                    end;
                }
                field(Field32; MATRIX_CellData[32])
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[32];
                    DecimalPlaces = 0 : 0;
                    Visible = Field32Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirEstado(32);
                    end;
                }
                field("Días con Estado"; Rec."Días con Estado")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'La suma de las columnas de estado. Si es menor que "Días del Rango", hay días en que la persona estaba de alta y sin ningún estado: un agujero en el historial, anterior al de la liquidación.';
                }
                field("Días del Rango"; Rec."Días del Rango")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Días del rango en que la persona estuvo de alta. No es el largo del rango: el alta y la baja lo recortan.';
                }
                field("Días Liquidados"; Rec."Días Liquidados") { ApplicationArea = All; Editable = false; }
                field("Días sin Liquidar"; Rec."Días sin Liquidar")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    Style = Attention;
                    StyleExpr = Rec."Días sin Liquidar" > 0;
                    ToolTip = 'Días con estado que ninguna liquidación CALCULADA cubre. Una liquidación en borrador no cuenta: existe el documento pero no hay ni líneas ni importes. Hacé clic en el encabezado para ordenar y traer arriba a los que tienen algo que revisar.';
                }
                field("Días en Borrador"; Rec."Días en Borrador")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    Style = Ambiguous;
                    StyleExpr = Rec."Días en Borrador" > 0;
                    ToolTip = 'De los días sin liquidar, cuántos ya tienen la liquidación creada pero en borrador. Es el mismo faltante con otra solución: no hay que crear nada, hay que calcular lo que ya está. Un borrador no cubre nada — no tiene ni líneas ni importes.';
                }
                field("Tramos sin Liquidar"; Rec."Tramos sin Liquidar")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'En cuántos pedazos sueltos caen esos días. Uno solo al final del mes es un olvido simple; tres desperdigados suele ser el historial de estados mal cargado.';
                }
                field("Detalle Sin Liquidar"; Rec."Detalle Sin Liquidar")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Los tramos concretos que faltan, con el estado de cada uno: "21/07/26..31/07/26 ORDENES".';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PeriodoAnterior)
            {
                ApplicationArea = All;
                Caption = 'Período anterior';
                Image = PreviousRecord;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Corre el rango al período de liquidación anterior.';

                trigger OnAction()
                begin
                    IrAPeriodo(-1);
                end;
            }
            action(PeriodoSiguiente)
            {
                ApplicationArea = All;
                Caption = 'Período siguiente';
                Image = NextRecord;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Corre el rango al período de liquidación siguiente.';

                trigger OnAction()
                begin
                    IrAPeriodo(1);
                end;
            }
            action(Actualizar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Vuelve a comparar estados contra liquidaciones con el rango y el filtro actuales.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(SoloFaltantes)
            {
                ApplicationArea = All;
                Caption = 'Sólo los que tienen faltantes';
                Image = FilterLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Deja en la grilla únicamente a los empleados con días sin liquidar. Volvé a apretarlo para ver a todos.';

                trigger OnAction()
                begin
                    FiltrarFaltantes := not FiltrarFaltantes;
                    AplicarFiltro();
                end;
            }
            action(CompletarCoberturas)
            {
                ApplicationArea = All;
                Caption = 'Completar fechas de cobertura';
                Image = UpdateDescription;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Completa las fechas que cubre cada liquidación en las que se calcularon antes de que el sistema las guardara. No recalcula nada ni toca ningún importe: la cobertura se deriva del período, el tipo y el proyecto.';

                trigger OnAction()
                var
                    Control: Codeunit "Control Cobertura Liq.";
                    Actualizadas: Integer;
                begin
                    Actualizadas := Control.CompletarCoberturas();
                    Message(MsgCompletadas, Actualizadas);
                    Cargar();
                end;
            }
            action(VerLiquidaciones)
            {
                ApplicationArea = All;
                Caption = 'Liquidaciones del empleado';
                Image = PaymentJournal;
                ToolTip = 'Abre las liquidaciones de este empleado para ver cuáles hay y qué días cubre cada una.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    Liq.SetCurrentKey("No. Empleado", "No. Proyecto", "Cód. Período", "Cód. Tipo Liq.");
                    Liq.SetRange("No. Empleado", Rec."No. Empleado");
                    Page.Run(Page::"Lista Liquidaciones", Liq);
                end;
            }
            action(VerEstados)
            {
                ApplicationArea = All;
                Caption = 'Estados del empleado';
                Image = EmployeeAgreement;
                ToolTip = 'Abre el historial de estados para ver por qué esos días había que liquidarlos — o si el estado quedó abierto de más.';

                trigger OnAction()
                var
                    Estado: Record "Estado Empleado";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
                    Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
                    Estado.SetRange("No. Empleado", Rec."No. Empleado");
                    Page.Run(Page::"Estados Empleado", Estado);
                end;
            }
            action(EstadosAnteriores)
            {
                ApplicationArea = All;
                Caption = 'Estados anteriores';
                Image = PreviousSet;
                Visible = HayPaginado;
                ToolTip = 'Corre la matriz al bloque anterior de estados.';

                trigger OnAction()
                begin
                    if FPrimeraColumna <= 1 then
                        exit;
                    FPrimeraColumna -= Columnas();
                    if FPrimeraColumna < 1 then
                        FPrimeraColumna := 1;
                    ArmarColumnas();
                    CurrPage.Update(false);
                end;
            }
            action(EstadosSiguientes)
            {
                ApplicationArea = All;
                Caption = 'Estados siguientes';
                Image = NextSet;
                Visible = HayPaginado;
                ToolTip = 'Corre la matriz al siguiente bloque de estados.';

                trigger OnAction()
                begin
                    if FPrimeraColumna + Columnas() > FEstados.Count() then
                        exit;
                    FPrimeraColumna += Columnas();
                    ArmarColumnas();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    /// <remarks>
    /// Abre SIN rango y sin cargar nada, y es deliberado. Antes arrancaba en el período de la fecha
    /// de trabajo: cómodo cuando lo que se quiere ver es justo ése, y molesto el resto de las veces
    /// —que son la mayoría, porque a esta pantalla se entra a mirar un mes que ya pasó—. Peor: la
    /// carga es una matriz de todos los empleados por todos los estados, así que se pagaba entera
    /// para descartarla en el acto y elegir otro rango.
    ///
    /// Con la cabecera vacía, la primera acción del usuario es decir qué quiere ver. Los botones de
    /// período anterior y siguiente siguen funcionando desde vacío: arrancan en el período de la
    /// fecha de trabajo, que es de donde partía la página antes.
    /// </remarks>
    trigger OnOpenPage()
    begin
    end;

    /// <summary>Corre el rango Paso períodos hacia adelante o hacia atrás.</summary>
    /// <remarks>
    /// Recorre los PERÍODOS definidos y no meses calendario: es el calendario real con el que se
    /// liquida, y saltar de mes en mes se desalinearía en cuanto un período no coincida con un mes.
    ///
    /// Si el rango se editó a mano y no hay período seleccionado, se parte del que contiene la fecha
    /// de inicio; y si tampoco lo hay, del más cercano hacia el lado en que se está yendo.
    /// </remarks>
    local procedure IrAPeriodo(Paso: Integer)
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.SetCurrentKey(Año, Mes);
        // Página recién abierta, sin nada elegido: se arranca en el período de la fecha de trabajo,
        // que es de donde partía antes, y el primer clic lleva al anterior o al siguiente. Sin esto
        // los dos botones morían con "no hay más períodos" sobre una pantalla vacía, que es la peor
        // forma de descubrir que hay que elegir algo primero.
        if (CodPeriodo = '') and (FechaDesde = 0D) and (FechaHasta = 0D) then begin
            Periodo.SetFilter("Fecha Desde", '<=%1', WorkDate());
            Periodo.SetFilter("Fecha Hasta", '>=%1', WorkDate());
            if Periodo.FindFirst() then
                CodPeriodo := Periodo.Código;
            Periodo.Reset();
            Periodo.SetCurrentKey(Año, Mes);
        end;

        if CodPeriodo <> '' then begin
            Periodo.Get(CodPeriodo);
            Periodo.SetCurrentKey(Año, Mes);
            if Periodo.Next(Paso) = 0 then begin
                Message(MsgSinPeriodo);
                exit;
            end;
        end else begin
            if Paso < 0 then begin
                Periodo.SetFilter("Fecha Hasta", '<%1', FechaDesde);
                if not Periodo.FindLast() then begin
                    Message(MsgSinPeriodo);
                    exit;
                end;
            end else begin
                Periodo.SetFilter("Fecha Desde", '>%1', FechaHasta);
                if not Periodo.FindFirst() then begin
                    Message(MsgSinPeriodo);
                    exit;
                end;
            end;
        end;

        CodPeriodo := Periodo.Código;
        FechaDesde := Periodo."Fecha Desde";
        FechaHasta := Periodo."Fecha Hasta";
        Cargar();
    end;

    trigger OnAfterGetRecord()
    var
        i: Integer;
    begin
        Clear(MATRIX_CellData);
        for i := 1 to MATRIX_CurrSetLength do
            MATRIX_CellData[i] := FControl.DiasDe(Rec."No. Empleado", FEstados.Get(FPrimeraColumna + i - 1));
    end;

    local procedure Cargar()
    begin
        // Sin rango completo no hay nada que construir, y construirlo igual sería peor que no
        // hacerlo: la matriz saldría con todos los empleados y cero días en todas las columnas, que
        // se lee como "no se liquidó nada" en vez de como "todavía no elegiste qué mirar".
        if (FechaDesde = 0D) or (FechaHasta = 0D) then begin
            Rec.Reset();
            Rec.DeleteAll();
            TotalEmpleados := 0;
            ConFaltantes := 0;
            TotalDias := 0;
            SinCobertura := 0;
            CurrPage.Update(false);
            exit;
        end;

        TotalEmpleados := FControl.Construir(Rec, FechaDesde, FechaHasta, FiltroEmpleado);
        FControl.Estados(FEstados);
        FPrimeraColumna := 1;
        ArmarColumnas();

        ConFaltantes := 0;
        TotalDias := 0;
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                if Rec."Días sin Liquidar" > 0 then begin
                    ConFaltantes += 1;
                    TotalDias += Rec."Días sin Liquidar";
                end;
            until Rec.Next() = 0;

        // El aviso importa más que el número: mientras queden liquidaciones sin fechas de cobertura,
        // los faltantes de arriba son en parte inventados. Se avisa una sola vez por apertura —no en
        // cada recarga— porque el usuario ya está viendo la grilla equivocada y necesita saber que lo
        // que tiene delante no es un problema de liquidación sino de datos por completar.
        SinCobertura := FControl.PendientesDeCobertura();
        if (SinCobertura > 0) and not FAvisado then begin
            FAvisado := true;
            Message(MsgSinCobertura, SinCobertura);
        end;

        AplicarFiltro();
    end;

    local procedure AplicarFiltro()
    begin
        Rec.Reset();
        if FiltrarFaltantes then
            Rec.SetFilter("Días sin Liquidar", '>%1', 0);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure ArmarColumnas()
    var
        CodEstado: Record "Cód. Estado Empleado";
        i: Integer;
        Cod: Code[20];
    begin
        Clear(MATRIX_ColumnCaption);
        MATRIX_CurrSetLength := FEstados.Count() - FPrimeraColumna + 1;
        if MATRIX_CurrSetLength > Columnas() then
            MATRIX_CurrSetLength := Columnas();
        if MATRIX_CurrSetLength < 0 then
            MATRIX_CurrSetLength := 0;
        for i := 1 to MATRIX_CurrSetLength do begin
            Cod := FEstados.Get(FPrimeraColumna + i - 1);
            MATRIX_ColumnCaption[i] := Cod;
            if CodEstado.Get(Cod) then
                MATRIX_ColumnCaption[i] := CopyStr(Cod + ' ' + CodEstado.Descripción, 1, MaxStrLen(MATRIX_ColumnCaption[i]));
        end;
        SetVisible();

        HayPaginado := FEstados.Count() > Columnas();
        if HayPaginado then
            RangoEstados := StrSubstNo(TxtRango, FPrimeraColumna, FPrimeraColumna + MATRIX_CurrSetLength - 1, FEstados.Count())
        else
            RangoEstados := '';
    end;

    /// <remarks>
    /// Abre el historial de estados filtrado por ese código. En una celda vacía no hay nada que
    /// abrir, y eso —que no pase nada— confirma que la persona no estuvo en ese estado.
    /// </remarks>
    local procedure AbrirEstado(Columna: Integer)
    var
        Estado: Record "Estado Empleado";
    begin
        if Columna > MATRIX_CurrSetLength then
            exit;
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Rec."No. Empleado");
        Estado.SetRange("Cód. Estado", FEstados.Get(FPrimeraColumna + Columna - 1));
        Page.Run(Page::"Estados Empleado", Estado);
    end;

    local procedure Columnas(): Integer
    begin
        exit(32);
    end;

    local procedure SetVisible()
    begin
        Field1Visible := MATRIX_CurrSetLength > 0;
        Field2Visible := MATRIX_CurrSetLength > 1;
        Field3Visible := MATRIX_CurrSetLength > 2;
        Field4Visible := MATRIX_CurrSetLength > 3;
        Field5Visible := MATRIX_CurrSetLength > 4;
        Field6Visible := MATRIX_CurrSetLength > 5;
        Field7Visible := MATRIX_CurrSetLength > 6;
        Field8Visible := MATRIX_CurrSetLength > 7;
        Field9Visible := MATRIX_CurrSetLength > 8;
        Field10Visible := MATRIX_CurrSetLength > 9;
        Field11Visible := MATRIX_CurrSetLength > 10;
        Field12Visible := MATRIX_CurrSetLength > 11;
        Field13Visible := MATRIX_CurrSetLength > 12;
        Field14Visible := MATRIX_CurrSetLength > 13;
        Field15Visible := MATRIX_CurrSetLength > 14;
        Field16Visible := MATRIX_CurrSetLength > 15;
        Field17Visible := MATRIX_CurrSetLength > 16;
        Field18Visible := MATRIX_CurrSetLength > 17;
        Field19Visible := MATRIX_CurrSetLength > 18;
        Field20Visible := MATRIX_CurrSetLength > 19;
        Field21Visible := MATRIX_CurrSetLength > 20;
        Field22Visible := MATRIX_CurrSetLength > 21;
        Field23Visible := MATRIX_CurrSetLength > 22;
        Field24Visible := MATRIX_CurrSetLength > 23;
        Field25Visible := MATRIX_CurrSetLength > 24;
        Field26Visible := MATRIX_CurrSetLength > 25;
        Field27Visible := MATRIX_CurrSetLength > 26;
        Field28Visible := MATRIX_CurrSetLength > 27;
        Field29Visible := MATRIX_CurrSetLength > 28;
        Field30Visible := MATRIX_CurrSetLength > 29;
        Field31Visible := MATRIX_CurrSetLength > 30;
        Field32Visible := MATRIX_CurrSetLength > 31;
    end;

    var
        FControl: Codeunit "Control Cobertura Liq.";
        MATRIX_CellData: array[32] of Decimal;
        MATRIX_ColumnCaption: array[32] of Text[80];
        MATRIX_CurrSetLength: Integer;
        FEstados: List of [Code[20]];
        FPrimeraColumna: Integer;
        FiltrarFaltantes: Boolean;
        FAvisado: Boolean;
        HayPaginado: Boolean;
        CodPeriodo: Code[10];
        FechaDesde: Date;
        FechaHasta: Date;
        FiltroEmpleado: Text;
        RangoEstados: Text;
        TotalEmpleados: Integer;
        ConFaltantes: Integer;
        TotalDias: Integer;
        SinCobertura: Integer;
        TxtRango: Label 'Estados %1 a %2 de %3.', Comment = '%1=desde, %2=hasta, %3=total';
        MsgCompletadas: Label '%1 liquidación(es) actualizada(s) con las fechas que cubren.';
        MsgSinPeriodo: Label 'No hay más períodos de liquidación en esa dirección.';
        MsgSinCobertura: Label 'Hay %1 liquidación(es) sin las fechas que cubren, así que el control las lee como si no cubrieran ningún día y va a mostrar faltantes que no existen.\Apretá "Completar fechas de cobertura" antes de sacar conclusiones. No recalcula nada ni toca ningún importe.', Comment = '%1=cantidad';
        Field1Visible: Boolean;
        Field2Visible: Boolean;
        Field3Visible: Boolean;
        Field4Visible: Boolean;
        Field5Visible: Boolean;
        Field6Visible: Boolean;
        Field7Visible: Boolean;
        Field8Visible: Boolean;
        Field9Visible: Boolean;
        Field10Visible: Boolean;
        Field11Visible: Boolean;
        Field12Visible: Boolean;
        Field13Visible: Boolean;
        Field14Visible: Boolean;
        Field15Visible: Boolean;
        Field16Visible: Boolean;
        Field17Visible: Boolean;
        Field18Visible: Boolean;
        Field19Visible: Boolean;
        Field20Visible: Boolean;
        Field21Visible: Boolean;
        Field22Visible: Boolean;
        Field23Visible: Boolean;
        Field24Visible: Boolean;
        Field25Visible: Boolean;
        Field26Visible: Boolean;
        Field27Visible: Boolean;
        Field28Visible: Boolean;
        Field29Visible: Boolean;
        Field30Visible: Boolean;
        Field31Visible: Boolean;
        Field32Visible: Boolean;
}
