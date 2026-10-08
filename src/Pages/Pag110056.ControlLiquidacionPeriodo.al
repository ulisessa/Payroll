namespace UAS.Payroll;

// Control de liquidación de un PERÍODO, para el liquidador.
//
// El gemelo de "Control de Liquidación por Marea" (Pag110022), que recorta por proyecto. Acá el
// recorte es el mes, que es como se cierra la nómina de tierra y como se revisa el total de una
// corrida: la marea sirve para cerrar un viaje, pero no contesta "¿a quién le cambió el sueldo
// este mes?" ni "¿quién cobró este concepto en enero?".
//
// REUSA LA MATRIZ Y LAS DIFERENCIAS DEL CONTROL DE MAREA. Son la misma pregunta con otro recorte:
// conceptos en las filas, empleados en las columnas, y la lista corta de quién se apartó de su
// categoría. Duplicar esas dos páginas para cambiar el filtro habría dejado dos matrices que hay
// que arreglar dos veces.
//
// LOS FILTROS NO SON UN LUJO. Una marea tiene treinta tripulantes y entra en la matriz; un período
// tiene trescientos empleados y no entra en ninguna pantalla. Por eso la página arranca sin cargar
// nada y pide que se acote: sin al menos un filtro, el informe sería tan grande que no se podría
// leer, y armarlo cuesta recorrer todas las líneas del mes.
page 110056 "Control Liquidación Período"
{
    ApplicationArea = All;
    Caption = 'Control de Liquidación por Período';
    PageType = Card;
    UsageCategory = ReportsAndAnalysis;
    // SIN SourceTable A PROPÓSITO. Atada a "Período Liquidación" la página es una Card, y una Card
    // SIEMPRE se para en un registro: entrando por el buscador caía en el primero de la tabla —el más
    // viejo y cerrado— y moverse de ahí peleaba contra el propio posicionamiento de BC. Sin registro
    // de origen no hay dónde caer: el período es un filtro más, como los otros siete, y la página
    // arranca vacía hasta que se elige uno.
    InsertAllowed = false;
    DeleteAllowed = false;
    // Sin "Editable = false" a nivel página, por lo mismo que el control de marea: eso bloquearía
    // también los filtros, que son lo único que acá se escribe. La protección va campo por campo.

    layout
    {
        area(Content)
        {
            group(Periodo)
            {
                Caption = 'Período';

                // EL ÚNICO CAMPO EDITABLE DE LA CABECERA, y el que hace usable la página cuando se
                // entra por el buscador: así se abre en el primer período de la tabla —el más viejo,
                // y encima cerrado— sin ninguna forma de moverse. El control de marea no lo necesita
                // porque siempre se entra desde un proyecto concreto.
                //
                // Cambiarlo reposiciona el registro con Get: no es un filtro sobre Rec, es saltar a
                // otro período. Por eso después hay que recargar las dos partes.
                field(PeriodoSel; PeriodoSel)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'El mes que se controla. Cambiarlo recarga el informe entero.';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        if PeriodoSel = '' then
                            exit;
                        CargarPeriodo();
                    end;
                }
                field(FechaDesdePer; FechaDesdePer) { ApplicationArea = All; Editable = false; Caption = 'Fecha Desde'; }
                field(FechaHastaPer; FechaHastaPer) { ApplicationArea = All; Editable = false; Caption = 'Fecha Hasta'; }
                field(EstadoPer; EstadoPer) { ApplicationArea = All; Editable = false; Caption = 'Estado'; }
            }

            group(Filtros)
            {
                Caption = 'Filtros';
                InstructionalText = 'Acotá el informe antes de cargarlo: un período entero no entra en la matriz. Los filtros admiten la sintaxis de BC (04360|04455, 1053..1083, <>8522).';

                field(FiltroEmpleado; FiltroEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Empleado';
                    ToolTip = 'Uno o varios legajos. Vacío = todos los del período, que puede ser demasiado para la matriz.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroConcepto; FiltroConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                    ToolTip = 'Recorta las LÍNEAS, no las liquidaciones: con un concepto cargado siguen apareciendo todos los empleados, y los que no lo cobraron se ven vacíos. Es la forma de contestar a quién no le salió.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroProyecto; FiltroProyecto)
                {
                    ApplicationArea = All;
                    Caption = 'Proyecto';
                    ToolTip = 'Mareas o proyectos de nómina. Un empleado puede tener varias liquidaciones en el mes sobre proyectos distintos.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroTipoLiq; FiltroTipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de Liquidación';
                    ToolTip = 'REGULAR, CIERRE_MAREA, VACACIONES… Vacío = todos, y entonces un mismo concepto puede venir de dos liquidaciones del mismo empleado.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FechaDesde; FechaDesde)
                {
                    ApplicationArea = All;
                    Caption = 'Fecha liquidación desde';
                    ToolTip = 'Sobre la Fecha Liquidación de la cabecera, que en un cierre de marea es la fecha de arribo. Sirve para separar dos mareas del mismo mes.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FechaHasta; FechaHasta)
                {
                    ApplicationArea = All;
                    Caption = 'Fecha liquidación hasta';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroConvenio; FiltroConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Convenio';
                    ToolTip = 'El encuadre del empleado en la cabecera. Filtra las liquidaciones y además acota la comparación de las diferencias.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroCategoria; FiltroCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Categoría';
                    ToolTip = 'Dentro del convenio. Las diferencias se buscan contra lo habitual de la MISMA categoría, así que acotar acá hace la lista más precisa.';
                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
            }

            group(Totales)
            {
                Caption = 'Totales';

                field(CantLiquidaciones; CantLiquidaciones)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Liquidaciones';
                    ToolTip = 'Cuántas cabeceras entraron con los filtros puestos. En cero, los filtros no alcanzan ninguna.';
                }
                field(CantEmpleados; CantEmpleados) { ApplicationArea = All; Editable = false; Caption = 'Empleados'; }
                field(TotalHaberes; TotalHaberes) { ApplicationArea = All; Editable = false; Caption = 'Total Haberes'; }
                field(TotalDescuentos; TotalDescuentos) { ApplicationArea = All; Editable = false; Caption = 'Total Descuentos'; }
                field(TotalContribuciones; TotalContribuciones) { ApplicationArea = All; Editable = false; Caption = 'Total Contribuciones'; }
                field(TotalNeto; TotalNeto) { ApplicationArea = All; Editable = false; Caption = 'Neto a Pagar'; Style = Strong; }
                field(RangoColumnas; RangoColumnas)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Columnas';
                    ToolTip = 'Qué tramo de empleados muestra la matriz. Con muchos, se recorre con Columnas siguientes y anteriores.';
                }
                field(CantDiferencias; CantDiferencias)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Diferencias';
                    ToolTip = 'Cuántos se apartaron de lo habitual de su categoría. Es la lista corta por donde conviene empezar.';
                }
            }

            part(Resumen; "Control Marea Matriz Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos por empleado';
            }
            part(Diferencias; "Control Marea Difs. Sub")
            {
                ApplicationArea = All;
                Caption = 'Diferencias contra la categoría';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Recargar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer las liquidaciones con los filtros puestos.';
                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(MostrarTodos)
            {
                ApplicationArea = All;
                Caption = 'Mostrar todos los conceptos';
                Image = ExpandAll;
                ToolTip = 'La matriz esconde los conceptos en cero para que entre lo que importa. Esto los trae de vuelta.';
                trigger OnAction()
                begin
                    FMostrarTodos := not FMostrarTodos;
                    CurrPage.Resumen.Page.MostrarTodos(FMostrarTodos);
                    ActualizarIndicadores();
                end;
            }
            action(VerCantidades)
            {
                ApplicationArea = All;
                Caption = 'Ver cantidades';
                Image = NumberSetup;
                ToolTip = 'Cambia los importes por las cantidades: días, horas, unidades.';
                trigger OnAction()
                begin
                    FVerCantidades := not FVerCantidades;
                    CurrPage.Resumen.Page.VerCantidades(FVerCantidades);
                end;
            }
            action(ColumnasSiguientes)
            {
                ApplicationArea = All;
                Caption = 'Columnas siguientes';
                Image = NextRecord;
                trigger OnAction()
                begin
                    CurrPage.Resumen.Page.ColumnasSiguientes();
                    ActualizarIndicadores();
                end;
            }
            action(ColumnasAnteriores)
            {
                ApplicationArea = All;
                Caption = 'Columnas anteriores';
                Image = PreviousRecord;
                trigger OnAction()
                begin
                    CurrPage.Resumen.Page.ColumnasAnteriores();
                    ActualizarIndicadores();
                end;
            }
        }
    }

    /// <summary>Para abrir el control ya parado en un período, desde la lista de períodos.</summary>
    procedure SetPeriodo(CodPeriodo: Code[10])
    begin
        PeriodoSel := CodPeriodo;
        CargarPeriodo();
    end;

    /// <remarks>
    /// El informe NO se arma solo al abrir la página. Recorrer todas las líneas de un mes cuesta, y
    /// el período que BC elegiría por su cuenta es casi siempre el equivocado — el más viejo, o uno
    /// sin calcular. Se arma cuando hay un período elegido.
    /// </remarks>
    local procedure CargarPeriodo()
    var
        Periodo: Record "Período Liquidación";
    begin
        Clear(FechaDesdePer);
        Clear(FechaHastaPer);
        Clear(EstadoPer);
        if PeriodoSel = '' then begin
            Limpiar();
            exit;
        end;
        if not Periodo.Get(PeriodoSel) then
            Error(ErrPeriodoInexistente, PeriodoSel);
        FechaDesdePer := Periodo."Fecha Desde";
        FechaHastaPer := Periodo."Fecha Hasta";
        EstadoPer := Format(Periodo.Estado);
        Cargar();
    end;

    /// <remarks>
    /// Arranca por los totales y recién después llena las dos partes: si los filtros no alcanzan
    /// ninguna liquidación, el contador en cero lo dice sin que haya que mirar una matriz vacía y
    /// preguntarse si el informe falló o si de verdad no hay nada.
    /// </remarks>
    local procedure Cargar()
    var
        Control: Codeunit "Control Marea Liq.";
        Buffer: Record "Control Marea Buffer" temporary;
        Liq: Record "Liquidación";
    begin
        Clear(CantLiquidaciones);
        Clear(CantEmpleados);
        Clear(TotalHaberes);
        Clear(TotalDescuentos);
        Clear(TotalContribuciones);
        Clear(TotalNeto);

        FiltrarLiquidaciones(Liq);
        CantLiquidaciones := Control.ConstruirFiltrado(Buffer, Liq, FiltroConcepto);
        Totalizar(Liq);

        CurrPage.Resumen.Page.Filtrar(FiltroConvenio, FiltroCategoria);
        CurrPage.Resumen.Page.Cargar(Buffer);
        CurrPage.Diferencias.Page.Cargar(Buffer, FiltroConvenio, FiltroCategoria);
        ActualizarIndicadores();
    end;

    /// <remarks>
    /// El período SIEMPRE acota, incluso sin ningún filtro cargado: es el registro de la página y lo
    /// que le da sentido. Lo demás se aplica sólo si está completo, para que los campos vacíos no
    /// filtren por cadena vacía y dejen el informe en cero.
    /// </remarks>
    local procedure FiltrarLiquidaciones(var Liq: Record "Liquidación")
    begin
        Liq.Reset();
        Liq.SetRange("Cód. Período", PeriodoSel);
        if FiltroEmpleado <> '' then
            Liq.SetFilter("No. Empleado", FiltroEmpleado);
        if FiltroProyecto <> '' then
            Liq.SetFilter("No. Proyecto", FiltroProyecto);
        if FiltroTipoLiq <> '' then
            Liq.SetFilter("Cód. Tipo Liq.", FiltroTipoLiq);
        if FiltroConvenio <> '' then
            Liq.SetFilter("Cód. Convenio", FiltroConvenio);
        if FiltroCategoria <> '' then
            Liq.SetFilter("Cód. Categoría", FiltroCategoria);
        if (FechaDesde <> 0D) and (FechaHasta <> 0D) then
            Liq.SetRange("Fecha Liquidación", FechaDesde, FechaHasta)
        else
            if FechaDesde <> 0D then
                Liq.SetFilter("Fecha Liquidación", '>=%1', FechaDesde)
            else
                if FechaHasta <> 0D then
                    Liq.SetFilter("Fecha Liquidación", '<=%1', FechaHasta);
    end;

    /// <remarks>
    /// Los totales salen de las CABECERAS y no de sumar el buffer, por el filtro de concepto: con un
    /// concepto puesto el buffer trae sólo sus líneas, y sumarlo daría el total de ese concepto
    /// presentado como el total del período. Lo que el liquidador necesita arriba es cuánto se pagó
    /// en el recorte de empleados y proyectos, no en el de conceptos.
    /// </remarks>
    local procedure Totalizar(var Liq: Record "Liquidación")
    var
        Vistos: Dictionary of [Code[20], Boolean];
    begin
        if not Liq.FindSet() then
            exit;
        repeat
            TotalHaberes += Liq."Total Haberes";
            TotalDescuentos += Liq."Total Descuentos";
            TotalContribuciones += Liq."Total Contribuciones";
            TotalNeto += Liq."Neto a Pagar";
            if not Vistos.ContainsKey(Liq."No. Empleado") then
                Vistos.Add(Liq."No. Empleado", true);
        until Liq.Next() = 0;
        CantEmpleados := Vistos.Count();
    end;

    /// <summary>Deja las dos partes y los totales en blanco, sin período elegido.</summary>
    local procedure Limpiar()
    var
        Vacio: Record "Control Marea Buffer" temporary;
    begin
        Clear(CantLiquidaciones);
        Clear(CantEmpleados);
        Clear(TotalHaberes);
        Clear(TotalDescuentos);
        Clear(TotalContribuciones);
        Clear(TotalNeto);
        CurrPage.Resumen.Page.Cargar(Vacio);
        CurrPage.Diferencias.Page.Cargar(Vacio, '', '');
        ActualizarIndicadores();
    end;

    local procedure ActualizarIndicadores()
    begin
        RangoColumnas := CopyStr(CurrPage.Resumen.Page.RangoColumnas(), 1, MaxStrLen(RangoColumnas));
        CantDiferencias := CurrPage.Diferencias.Page.Cuantas();
        CurrPage.Update(false);
    end;

    var
        FiltroEmpleado: Text;
        FiltroConcepto: Text;
        FiltroProyecto: Text;
        FiltroTipoLiq: Text;
        FiltroConvenio: Code[20];
        FiltroCategoria: Code[20];
        FechaDesde: Date;
        FechaHasta: Date;
        CantLiquidaciones: Integer;
        CantEmpleados: Integer;
        CantDiferencias: Integer;
        TotalHaberes: Decimal;
        TotalDescuentos: Decimal;
        TotalContribuciones: Decimal;
        TotalNeto: Decimal;
        RangoColumnas: Text[50];
        FechaDesdePer: Date;
        FechaHastaPer: Date;
        EstadoPer: Text[30];
        PeriodoSel: Code[10];
        FMostrarTodos: Boolean;
        FVerCantidades: Boolean;
        ErrPeriodoInexistente: Label 'No existe el período %1.', Comment = '%1 = código de período';
}
