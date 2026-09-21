namespace UAS.Payroll;

// Resumen por concepto de toda la tripulación, como matriz: una fila por concepto, una columna por
// tripulante.
//
// La versión anterior era una lista con el total de cada concepto sumado sobre toda la marea, y no
// servía para lo único que se hace con este informe: recorrer una fila de punta a punta y ver a
// quién le salió distinto. Un total de marea no delata al que cobró de menos; una fila de veinte
// números, sí.
//
// Las celdas en cero no se muestran (BlankZero) y los conceptos que quedaron en cero para toda la
// tripulación no llegan a ser fila: a la vista queda lo que efectivamente se liquidó.
//
// Las 32 columnas son el máximo que soporta el patrón de matriz de Business Central (CaptionClass
// '3,...', que la plataforma resuelve devolviendo el texto tal cual). Una marea más numerosa que eso
// se recorre con "Columnas siguientes"; el rango visible se muestra siempre en la cabecera, para que
// una tripulación cortada no pase por una tripulación completa.
page 110020 "Control Marea Matriz Sub"
{
    ApplicationArea = All;
    Caption = 'Resumen por concepto';
    PageType = ListPart;
    SourceTable = "Control Marea Buffer";
    SourceTableTemporary = true;
    SourceTableView = sorting(Sección, "Orden Cálculo", "Cód. Concepto") where(Sección = const(Resumen));
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                ShowCaption = false;

                field("Orden Cálculo"; Rec."Orden Cálculo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden en que el motor liquidó el concepto. Es el orden inicial de las filas y el mismo del recibo; se puede reordenar haciendo clic en cualquier encabezado.';
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código del concepto. Hacé clic en el encabezado para ordenar la matriz por código en vez de por orden de cálculo.';
                }
                field("Nombre Impresión"; Rec."Nombre Impresión")
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                    ToolTip = 'Nombre con el que el concepto sale impreso en el recibo.';
                }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Naturaleza del concepto: qué suma al neto, qué resta y qué queda del lado patronal.';
                }
                field(Empleados; Rec.Empleados)
                {
                    ApplicationArea = All;
                    ToolTip = 'A cuántos tripulantes les salió este concepto. Un número menor al total de la marea es lo primero que hay que mirar: significa que a alguien no le aplicó.';
                }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Caption = 'Total marea';
                    BlankNumbers = BlankZero;
                    Style = Strong;
                    ToolTip = 'Suma del concepto sobre toda la tripulación. Las columnas de la derecha lo abren tripulante por tripulante.';
                }
                field(Field1; MATRIX_CellData[1])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[1];
                    DecimalPlaces = 2 : 2;
                    Visible = Field1Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(1);
                    end;
                }
                field(Field2; MATRIX_CellData[2])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[2];
                    DecimalPlaces = 2 : 2;
                    Visible = Field2Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(2);
                    end;
                }
                field(Field3; MATRIX_CellData[3])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[3];
                    DecimalPlaces = 2 : 2;
                    Visible = Field3Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(3);
                    end;
                }
                field(Field4; MATRIX_CellData[4])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[4];
                    DecimalPlaces = 2 : 2;
                    Visible = Field4Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(4);
                    end;
                }
                field(Field5; MATRIX_CellData[5])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[5];
                    DecimalPlaces = 2 : 2;
                    Visible = Field5Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(5);
                    end;
                }
                field(Field6; MATRIX_CellData[6])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[6];
                    DecimalPlaces = 2 : 2;
                    Visible = Field6Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(6);
                    end;
                }
                field(Field7; MATRIX_CellData[7])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[7];
                    DecimalPlaces = 2 : 2;
                    Visible = Field7Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(7);
                    end;
                }
                field(Field8; MATRIX_CellData[8])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[8];
                    DecimalPlaces = 2 : 2;
                    Visible = Field8Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(8);
                    end;
                }
                field(Field9; MATRIX_CellData[9])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[9];
                    DecimalPlaces = 2 : 2;
                    Visible = Field9Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(9);
                    end;
                }
                field(Field10; MATRIX_CellData[10])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[10];
                    DecimalPlaces = 2 : 2;
                    Visible = Field10Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(10);
                    end;
                }
                field(Field11; MATRIX_CellData[11])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[11];
                    DecimalPlaces = 2 : 2;
                    Visible = Field11Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(11);
                    end;
                }
                field(Field12; MATRIX_CellData[12])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[12];
                    DecimalPlaces = 2 : 2;
                    Visible = Field12Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(12);
                    end;
                }
                field(Field13; MATRIX_CellData[13])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[13];
                    DecimalPlaces = 2 : 2;
                    Visible = Field13Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(13);
                    end;
                }
                field(Field14; MATRIX_CellData[14])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[14];
                    DecimalPlaces = 2 : 2;
                    Visible = Field14Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(14);
                    end;
                }
                field(Field15; MATRIX_CellData[15])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[15];
                    DecimalPlaces = 2 : 2;
                    Visible = Field15Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(15);
                    end;
                }
                field(Field16; MATRIX_CellData[16])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[16];
                    DecimalPlaces = 2 : 2;
                    Visible = Field16Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(16);
                    end;
                }
                field(Field17; MATRIX_CellData[17])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[17];
                    DecimalPlaces = 2 : 2;
                    Visible = Field17Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(17);
                    end;
                }
                field(Field18; MATRIX_CellData[18])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[18];
                    DecimalPlaces = 2 : 2;
                    Visible = Field18Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(18);
                    end;
                }
                field(Field19; MATRIX_CellData[19])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[19];
                    DecimalPlaces = 2 : 2;
                    Visible = Field19Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(19);
                    end;
                }
                field(Field20; MATRIX_CellData[20])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[20];
                    DecimalPlaces = 2 : 2;
                    Visible = Field20Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(20);
                    end;
                }
                field(Field21; MATRIX_CellData[21])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[21];
                    DecimalPlaces = 2 : 2;
                    Visible = Field21Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(21);
                    end;
                }
                field(Field22; MATRIX_CellData[22])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[22];
                    DecimalPlaces = 2 : 2;
                    Visible = Field22Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(22);
                    end;
                }
                field(Field23; MATRIX_CellData[23])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[23];
                    DecimalPlaces = 2 : 2;
                    Visible = Field23Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(23);
                    end;
                }
                field(Field24; MATRIX_CellData[24])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[24];
                    DecimalPlaces = 2 : 2;
                    Visible = Field24Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(24);
                    end;
                }
                field(Field25; MATRIX_CellData[25])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[25];
                    DecimalPlaces = 2 : 2;
                    Visible = Field25Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(25);
                    end;
                }
                field(Field26; MATRIX_CellData[26])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[26];
                    DecimalPlaces = 2 : 2;
                    Visible = Field26Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(26);
                    end;
                }
                field(Field27; MATRIX_CellData[27])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[27];
                    DecimalPlaces = 2 : 2;
                    Visible = Field27Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(27);
                    end;
                }
                field(Field28; MATRIX_CellData[28])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[28];
                    DecimalPlaces = 2 : 2;
                    Visible = Field28Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(28);
                    end;
                }
                field(Field29; MATRIX_CellData[29])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[29];
                    DecimalPlaces = 2 : 2;
                    Visible = Field29Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(29);
                    end;
                }
                field(Field30; MATRIX_CellData[30])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[30];
                    DecimalPlaces = 2 : 2;
                    Visible = Field30Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(30);
                    end;
                }
                field(Field31; MATRIX_CellData[31])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[31];
                    DecimalPlaces = 2 : 2;
                    Visible = Field31Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(31);
                    end;
                }
                field(Field32; MATRIX_CellData[32])
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[32];
                    DecimalPlaces = 2 : 2;
                    Visible = Field32Visible;

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion(32);
                    end;
                }
            }
        }
    }

    /// <summary>
    /// Restringe la matriz a los tripulantes encuadrados en ese convenio y esa categoría. Blanco =
    /// sin restricción. Hay que llamarlo ANTES de Cargar.
    /// </summary>
    /// <remarks>
    /// Filtra por el par de la CABECERA de la liquidación —el encuadre del tripulante— y no por el de
    /// cada línea: los conceptos que se liquidan con el convenio de la asignación a la marea llevan
    /// otro par, y filtrar por ése dejaría a un mismo tripulante con la mitad de sus conceptos
    /// adentro y la otra mitad afuera.
    /// </remarks>
    procedure Filtrar(Convenio: Code[20]; Categoria: Code[20])
    begin
        FFiltroConvenio := Convenio;
        FFiltroCategoria := Categoria;
    end;

    /// <summary>Carga las filas (conceptos) y las columnas (tripulantes) desde el buffer del control.</summary>
    procedure Cargar(var Origen: Record "Control Marea Buffer" temporary)
    var
        ClaveCelda: Text;
    begin
        Clear(FImporte);
        Clear(FCantidad);
        Clear(FLiquidacion);
        Clear(FEmpleados);
        Clear(FEtiqueta);
        FPrimeraColumna := 1;

        // Columnas: los tripulantes que aparecen en el detalle, por número de empleado. Se recorre el
        // detalle y no la lista de liquidaciones porque quien no tenga ni una línea tampoco tiene
        // nada que controlar.
        Origen.Reset();
        Origen.SetCurrentKey(Sección, "No. Empleado", "Orden Cálculo", "Cód. Concepto");
        Origen.SetRange(Sección, Origen.Sección::Detalle);
        if FFiltroConvenio <> '' then
            Origen.SetRange("Convenio Empleado", FFiltroConvenio);
        if FFiltroCategoria <> '' then
            Origen.SetRange("Categoría Empleado", FFiltroCategoria);
        if Origen.FindSet() then
            repeat
                if not FEtiqueta.ContainsKey(Origen."No. Empleado") then begin
                    FEmpleados.Add(Origen."No. Empleado");
                    FEtiqueta.Add(Origen."No. Empleado", EtiquetaEmpleado(Origen));
                end;
                ClaveCelda := ClaveFila(Origen."Orden Cálculo", Origen."Cód. Concepto") + '|' + Origen."No. Empleado";
                Acumular(FImporte, ClaveCelda, Origen.Importe);
                Acumular(FCantidad, ClaveCelda, Origen.Cantidad);
                // Un concepto puede darle varias líneas al mismo tripulante —el consumo de francos
                // abre una por lote—; cualquiera de ellas sirve para abrir su liquidación.
                FLiquidacion.Set(ClaveCelda, Origen."No. Liquidación");
            until Origen.Next() = 0;

        // El origen se guarda entero: los filtros de fila se aplican al rearmar, no al cargar, para
        // que "Mostrar todos los conceptos" no obligue a reconstruir el buffer desde la base.
        FResumen.Reset();
        FResumen.DeleteAll();
        Origen.Reset();
        Origen.SetCurrentKey(Sección, "Orden Cálculo", "Cód. Concepto");
        Origen.SetRange(Sección, Origen.Sección::Resumen);
        if Origen.FindSet() then
            repeat
                FResumen := Origen;
                FResumen.Insert();
            until Origen.Next() = 0;
        Origen.Reset();

        ArmarFilas();
        ArmarColumnas();
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Deja como filas los conceptos que hay algo que controlar y descarta el resto.
    /// </summary>
    /// <remarks>
    /// Dos reglas, y las dos esconden cosas a propósito: se va el concepto que dio importe cero en
    /// toda la tripulación, y se va el que no imprime en recibo —contribuciones patronales y
    /// acumuladores—, que son números correctos pero que el tripulante no cobra.
    ///
    /// Esconder es riesgoso justamente acá: un concepto mal marcado como "no imprime" se vuelve
    /// invisible en el informe que existe para detectar eso. Por eso "Mostrar todos los conceptos"
    /// las desactiva a las dos, y la cabecera dice cuántas filas se están ocultando.
    /// </remarks>
    local procedure ArmarFilas()
    var
        Clave: Text;
    begin
        FOcultas := 0;
        Rec.Reset();
        Rec.DeleteAll();
        FResumen.Reset();
        FResumen.SetCurrentKey(Sección, "Orden Cálculo", "Cód. Concepto");
        if FResumen.FindSet() then
            repeat
                Clave := ClaveFila(FResumen."Orden Cálculo", FResumen."Cód. Concepto");
                if FMostrarTodos or (FilaConImporte(Clave) and FResumen."Imprime en Recibo") then begin
                    Rec := FResumen;
                    // "Total marea" y "Empleados" se recalculan sobre las columnas que quedaron: con
                    // un filtro de categoría puesto, el total de toda la marea al lado de cuatro
                    // capitanes no es un dato, es una trampa.
                    RecalcularFila(Clave, Rec.Importe, Rec.Empleados);
                    Rec.Insert();
                end else
                    FOcultas += 1;
            until FResumen.Next() = 0;
    end;

    local procedure RecalcularFila(ClaveConcepto: Text; var Total: Decimal; var Cuantos: Integer)
    var
        Emp: Text;
    begin
        Total := 0;
        Cuantos := 0;
        foreach Emp in FEmpleados do
            // La clave existe en cuanto el tripulante tuvo una línea del concepto, aunque sea en
            // cero: "a cuántos les salió" no es lo mismo que "a cuántos les dio importe".
            if FImporte.ContainsKey(ClaveConcepto + '|' + Emp) then begin
                Total += FImporte.Get(ClaveConcepto + '|' + Emp);
                Cuantos += 1;
            end;
    end;

    /// <summary>Cuántos conceptos quedaron fuera de la matriz por los filtros de fila.</summary>
    procedure ConceptosOcultos(): Integer
    begin
        exit(FOcultas);
    end;

    /// <summary>Muestra también los conceptos sin importe y los que no imprimen en recibo.</summary>
    procedure MostrarTodos(Activar: Boolean)
    begin
        FMostrarTodos := Activar;
        ArmarFilas();
        CurrPage.Update(false);
    end;

    /// <summary>Alterna entre ver importes y ver cantidades en las celdas.</summary>
    /// <remarks>
    /// En los conceptos de producción el importe es la consecuencia y los kilos son el dato: si dos
    /// tripulantes de la misma categoría cobraron distinto, lo primero que hay que saber es si
    /// también les cargaron kilos distintos o si la diferencia la puso la fórmula.
    /// </remarks>
    procedure VerCantidades(Activar: Boolean)
    begin
        FVerCantidad := Activar;
        CurrPage.Update(false);
    end;

    procedure ColumnasSiguientes()
    begin
        if FPrimeraColumna + Columnas() > FEmpleados.Count() then
            exit;
        FPrimeraColumna += Columnas();
        ArmarColumnas();
        CurrPage.Update(false);
    end;

    procedure ColumnasAnteriores()
    begin
        if FPrimeraColumna <= 1 then
            exit;
        FPrimeraColumna -= Columnas();
        if FPrimeraColumna < 1 then
            FPrimeraColumna := 1;
        ArmarColumnas();
        CurrPage.Update(false);
    end;

    /// <summary>Qué tripulantes se están viendo, para que la paginación no sea invisible.</summary>
    procedure RangoColumnas(): Text
    var
        Ultima: Integer;
    begin
        if FEmpleados.Count() = 0 then
            exit('');
        if FEmpleados.Count() <= Columnas() then
            exit(StrSubstNo(TxtTodos, FEmpleados.Count()));
        Ultima := FPrimeraColumna + MATRIX_CurrSetLength - 1;
        exit(StrSubstNo(TxtRango, FPrimeraColumna, Ultima, FEmpleados.Count()));
    end;

    trigger OnAfterGetRecord()
    var
        i: Integer;
        ClaveCelda: Text;
    begin
        Clear(MATRIX_CellData);
        for i := 1 to MATRIX_CurrSetLength do begin
            ClaveCelda := ClaveFila(Rec."Orden Cálculo", Rec."Cód. Concepto") + '|' + FEmpleados.Get(FPrimeraColumna + i - 1);
            if FVerCantidad then
                MATRIX_CellData[i] := ValorDe(FCantidad, ClaveCelda)
            else
                MATRIX_CellData[i] := ValorDe(FImporte, ClaveCelda);
        end;
    end;

    local procedure ArmarColumnas()
    var
        i: Integer;
    begin
        Clear(MATRIX_ColumnCaption);
        MATRIX_CurrSetLength := FEmpleados.Count() - FPrimeraColumna + 1;
        if MATRIX_CurrSetLength > Columnas() then
            MATRIX_CurrSetLength := Columnas();
        if MATRIX_CurrSetLength < 0 then
            MATRIX_CurrSetLength := 0;
        for i := 1 to MATRIX_CurrSetLength do
            MATRIX_ColumnCaption[i] := CopyStr(FEtiqueta.Get(FEmpleados.Get(FPrimeraColumna + i - 1)), 1, MaxStrLen(MATRIX_ColumnCaption[i]));
        SetVisible();
    end;

    local procedure AbrirLiquidacion(Columna: Integer)
    var
        Liq: Record "Liquidación";
        ClaveCelda: Text;
        NoLiq: Code[20];
    begin
        if Columna > MATRIX_CurrSetLength then
            exit;
        ClaveCelda := ClaveFila(Rec."Orden Cálculo", Rec."Cód. Concepto") + '|' + FEmpleados.Get(FPrimeraColumna + Columna - 1);
        if not FLiquidacion.ContainsKey(ClaveCelda) then
            exit;
        NoLiq := CopyStr(FLiquidacion.Get(ClaveCelda), 1, MaxStrLen(NoLiq));
        if Liq.Get(NoLiq) then
            Page.Run(Page::"Ficha Liquidación", Liq);
    end;

    /// <remarks>
    /// El orden de cálculo en seis dígitos adelante hace que la clave de fila ordene sola y que dos
    /// conceptos con el mismo código pero distinto orden —que el motor trata como filas distintas— no
    /// se pisen.
    /// </remarks>
    local procedure ClaveFila(Orden: Integer; Codigo: Code[20]): Text
    begin
        exit(Format(Orden, 6, '<Integer,6><Filler Character,0>') + '|' + Codigo);
    end;

    /// <remarks>
    /// Mira celda por celda y no el total del resumen: un concepto que le sumó a uno lo mismo que le
    /// restó a otro da total cero y sin embargo tiene todo para controlar.
    /// </remarks>
    local procedure FilaConImporte(ClaveConcepto: Text): Boolean
    var
        Emp: Text;
    begin
        foreach Emp in FEmpleados do
            if ValorDe(FImporte, ClaveConcepto + '|' + Emp) <> 0 then
                exit(true);
        exit(false);
    end;

    local procedure EtiquetaEmpleado(var Origen: Record "Control Marea Buffer" temporary): Text
    begin
        if Origen."Nombre Empleado" = '' then
            exit(Origen."No. Empleado");
        exit(Origen."No. Empleado" + ' ' + Origen."Nombre Empleado");
    end;

    local procedure Acumular(var Mapa: Dictionary of [Text, Decimal]; Clave: Text; Valor: Decimal)
    begin
        if Mapa.ContainsKey(Clave) then
            Mapa.Set(Clave, Mapa.Get(Clave) + Valor)
        else
            Mapa.Add(Clave, Valor);
    end;

    local procedure ValorDe(var Mapa: Dictionary of [Text, Decimal]; Clave: Text): Decimal
    begin
        if Mapa.ContainsKey(Clave) then
            exit(Mapa.Get(Clave));
        exit(0);
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
        MATRIX_CellData: array[32] of Decimal;
        MATRIX_ColumnCaption: array[32] of Text[80];
        MATRIX_CurrSetLength: Integer;
        FImporte: Dictionary of [Text, Decimal];
        FCantidad: Dictionary of [Text, Decimal];
        FLiquidacion: Dictionary of [Text, Text];
        FEmpleados: List of [Text];
        FEtiqueta: Dictionary of [Text, Text];
        FResumen: Record "Control Marea Buffer" temporary;
        FFiltroConvenio: Code[20];
        FFiltroCategoria: Code[20];
        FPrimeraColumna: Integer;
        FOcultas: Integer;
        FVerCantidad: Boolean;
        FMostrarTodos: Boolean;
        TxtTodos: Label 'Los %1 tripulantes de la marea.', Comment = '%1=cantidad de tripulantes';
        TxtRango: Label 'Tripulantes %1 a %2 de %3. Con "Columnas siguientes" se ve el resto.', Comment = '%1=desde, %2=hasta, %3=total';
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
