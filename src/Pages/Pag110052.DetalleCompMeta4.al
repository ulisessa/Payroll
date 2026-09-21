namespace UAS.Payroll;

page 110052 "Detalle Comp. Meta4"
{
    ApplicationArea = All;
    Caption = 'Qué explica la diferencia';
    PageType = List;
    UsageCategory = None;
    SourceTable = "Comp. Det. Meta4 Buffer";
    SourceTableTemporary = true;
    // ESTA PAGINA NO LLEVA "Editable = false" NI "ModifyAllowed = false", y las dos cosas por el
    // mismo motivo: dejan la PAGINA en estado de solo lectura, y entonces no se puede tocar ningun
    // control — tampoco los campos de filtro, que no son del registro sino variables globales. Un
    // "Editable = true" en el campo no alcanza, porque la editabilidad de la pagina manda sobre la
    // del control.
    //
    // Con Insert, Modify y Delete los tres cerrados, BC resuelve la pagina entera como no editable.
    // Por eso queda Modify abierto.
    //
    // Los datos igual estan protegidos: el origen es TEMPORAL —lo que se escriba no va a ninguna
    // tabla— y todos los campos del repetidor son "Editable = false". Lo unico editable es lo que
    // tiene que serlo: los filtros.
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Cabecera)
            {
                Caption = 'Mes';
                field(Titulo; FTitulo) { ApplicationArea = All; Caption = 'Empleado y mes'; Editable = false; }
                field(FTodos; FTodos)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Mostrar también los que coinciden';
                    ToolTip = 'Por defecto sólo se ven los conceptos que difieren, que son los que explican el número.';
                    trigger OnValidate() begin Filtrar(); CurrPage.Update(false); end;
                }
            }
            repeater(Lines)
            {
                field(Origen; Rec.Origen)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = Estilo;
                    ToolTip = 'Sólo Meta4 = el motor no lo liquidó. Sólo BC = lo liquidó de más. Sin equivalencia = hay valor en Meta4 pero no se sabe qué concepto de BC le corresponde.';
                }
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; Editable = false; StyleExpr = Estilo; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; Editable = false; StyleExpr = Estilo; }
                field("Importe Meta4"; Rec."Importe Meta4") { ApplicationArea = All; Editable = false; }
                field("Importe BC"; Rec."Importe BC") { ApplicationArea = All; Editable = false; }
                field(Diferencia; Rec.Diferencia) { ApplicationArea = All; Editable = false; StyleExpr = Estilo; }
                field("Columna Meta4"; Rec."Columna Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Nombre de la columna en las tablas de Meta4, para poder ir a buscarla al archivo.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Origen of
            Rec.Origen::Ambos:
                if Rec.Diferencia = 0 then Estilo := 'Favorable' else Estilo := 'Attention';
            Rec.Origen::"Sólo Meta4":
                Estilo := 'Unfavorable';
            Rec.Origen::"Sólo BC":
                Estilo := 'Attention';
            else
                Estilo := 'Subordinate';
        end;
    end;

    /// <summary>
    /// Carga el detalle de un empleado-mes. La llama el drilldown de "Diferencia".
    /// </summary>
    /// <summary>
    /// Arma el detalle de un empleado-mes, opcionalmente acotado a una marea.
    /// </summary>
    /// <remarks>
    /// LA MAREA LLEGA RESUELTA DESDE LA LISTA, no se vuelve a deducir acá. Son dos datos porque
    /// acotan lados distintos: CodProyecto acota las líneas de BC, NoMareaM4 acota las corridas del
    /// archivo de Meta4. Los dos en cero o en blanco = el mes entero, que es como venía.
    ///
    /// TIENEN QUE IR JUNTOS. Si se acota un lado y el otro no, la pantalla enfrenta una marea contra
    /// un mes y todas las diferencias que muestra son inventadas — que es exactamente lo que pasaba
    /// cuando el concepto 2013 aparecía como "Sólo Meta4": no era de esta marea, era de la anterior.
    /// </remarks>
    procedure Cargar(EmployeeNo: Code[20]; Anio: Integer; MesNo: Integer; CodProyecto: Code[20]; NoMareaM4: Integer)
    var
        Cab: Record "Hist. Liq. Meta4";
        Val: Record "Valor Hist. Meta4";
        Col: Record "Columna Hist. Meta4";
        LinLiq: Record "Línea Liquidación";
        Concepto: Record "Concepto Liquidación";
        M4: Dictionary of [Code[50], Decimal];
        BC: Dictionary of [Code[20], Decimal];
        ColDeConcepto: Dictionary of [Code[20], Code[50]];
        NombreCol: Code[50];
        CodCpt: Code[20];
        Importe: Decimal;
        Previo: Decimal;
        n: Integer;
    begin
        FTitulo := EmployeeNo + '  —  ' + Format(MesNo) + '/' + Format(Anio);
        if NoMareaM4 > 0 then
            FTitulo += '  —  marea ' + Format(NoMareaM4);
        Rec.Reset();
        Rec.DeleteAll();

        // SIN EL CATÁLOGO POBLADO ESTA PÁGINA MIENTE. EsComparable() se apoya en "Cód. Concepto BC"
        // y "Clasificación Meta4"; si están vacíos devuelve false para TODA columna, el lado Meta4
        // queda vacío y todo aparece como "Sólo BC" con Meta4 en cero — que se lee como "Meta4 no
        // liquidó nada", exactamente lo contrario de la verdad.
        //
        // Ya pasó: los campos se publicaron y el script que los llena no se corrió. La página no
        // falló, mostró una comparación creíble y equivocada. Por eso avisa en vez de seguir.
        Col.Reset();
        Col.SetFilter("Clasificación Meta4", '<>%1', '');
        if Col.IsEmpty() then
            Error(ErrCatalogoVacio);

        // ── lo que tiene Meta4, columna por columna ──────────────────────────
        // SE SUMAN LAS CORRIDAS. Antes se tomaba el MÁXIMO, con el argumento de que las columnas de
        // acumulado repiten el snapshot en cada corrida — y el argumento es cierto, pero no se aplica
        // acá: EsComparable() sólo deja pasar DV, RT y SS, que son devengos y retenciones DE SU
        // CORRIDA. Los acumulados de verdad están clasificados AX o BL y ya quedaban afuera.
        //
        // El máximo además no era neutro, se comía plata. Una marea se paga en más de una corrida más
        // seguido de lo que parece: aun descartando la mensual y los anticipos, 184 de los 1.461
        // empleado-marea de 2026 tienen dos o tres. El legajo 00191 cierra la marea 323 de mayo con
        // un TP 15 y un TP 14, y con el máximo sólo se veía la mayor de las dos.
        //
        // LA EXCEPCIÓN SON LAS COLUMNAS IG_. Llevan el estado de Ganancias acumulado en el año, así
        // que repiten el acumulado en cada corrida y sumarlas lo duplica. Para ésas se sigue tomando
        // el máximo, que en un acumulado es el valor al cierre.
        Cab.SetCurrentKey("No. Empleado", "Fecha Imputación", "Fecha Pago");
        Cab.SetRange("No. Empleado", EmployeeNo);
        Cab.SetRange(Año, Anio);
        Cab.SetRange(Mes, MesNo);
        // ACÁ SÍ SE SALTEAN LOS ANTICIPOS, al revés que en la lista, y por el mismo motivo por el que
        // allá no se puede: allá el número es un acumulado corrido y saltear una corrida no la saca,
        // la esconde dentro de la siguiente. Acá cada columna vale por sí misma, así que saltear la
        // corrida del anticipo la saca de verdad.
        Cab.SetFilter("Tipo Imputación", '<>%1', 4);
        // ACÁ SÍ SE FILTRA LA MAREA EN LA CONSULTA, al revés que en la lista. La lista mira
        // TOT_REMUN_27617, que es un acumulado corrido y obliga a restar corridas; esto mira los
        // conceptos uno por uno, y el valor de un concepto es de SU corrida. Filtrar alcanza.
        //
        // Y SE DEJAN AFUERA LA MENSUAL Y LA FINAL. Meta4 las imputa a una marea, pero ninguna de las
        // dos es de la marea: cada una tiene SU PROPIO RECIBO y el de la marea no las incluye.
        //   TP_IMPUT 1  — la mensual. Ahí viven el SUELDO_DIA_FDO y el SUELDO_FRANCO del 03772, que
        //                 aparecían como "Sólo Meta4" contra el recibo de la marea 59, donde no están.
        //   TP_IMPUT 14 — la liquidación final: vacaciones y francos no gozados, egreso, los SAC de
        //                 cada uno y una devolución de Ganancias. Las 7 corridas TP 14 de enero de
        //                 2026 son todas finales. Ahí está lo del 04807 y lo del 04190.
        // Sin filtro de marea entran las dos, que es la vista del mes.
        if NoMareaM4 > 0 then begin
            Cab.SetRange("No. Marea Meta4", NoMareaM4);
            Cab.SetFilter("Tipo Imputación", '<>%1&<>%2&<>%3', 4, 1, 14);
        end;
        if Cab.FindSet() then
            repeat
                Val.SetRange("No. Entrada", Cab."No. Entrada");
                if Val.FindSet() then
                    repeat
                        if Val.Valor <> 0 then
                            if Col.Get(Val."No. Columna") then
                              if EsComparable(Col) then begin
                                if M4.ContainsKey(Col."Nombre Columna") then begin
                                    Previo := M4.Get(Col."Nombre Columna");
                                    if CopyStr(Col."Nombre Columna", 1, 3) = 'IG_' then begin   // StartsWith es de Text, no de Code
                                        if Val.Valor > Previo then
                                            M4.Set(Col."Nombre Columna", Val.Valor);
                                    end else
                                        M4.Set(Col."Nombre Columna", Previo + Val.Valor);
                                end else
                                    M4.Add(Col."Nombre Columna", Val.Valor);
                                if Col."Cód. Concepto BC" <> '' then
                                    if not ColDeConcepto.ContainsKey(Col."Cód. Concepto BC") then
                                        ColDeConcepto.Add(Col."Cód. Concepto BC", Col."Nombre Columna");
                            end;
                    until Val.Next() = 0;
            until Cab.Next() = 0;

        // ── lo que calculó BC ────────────────────────────────────────────────
        LinLiq.SetCurrentKey("No. Empleado", "Fecha Liquidación");
        LinLiq.SetRange("No. Empleado", EmployeeNo);
        LinLiq.SetRange("Fecha Liquidación", DMY2Date(1, MesNo, Anio), CalcDate('<CM>', DMY2Date(1, MesNo, Anio)));
        LinLiq.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
        // Y ACÁ EL ESPEJO: la liquidación sin proyecto tampoco entra. Si del lado de Meta4 se dejó
        // afuera la mensual, del lado de BC hay que dejar afuera la REGULAR de la nómina, que es lo
        // mismo. Con filtro de marea esto compara recibo de marea contra recibo de marea.
        if CodProyecto <> '' then
            LinLiq.SetRange("No. Proyecto", CodProyecto);
        // DOS EXCLUSIONES, Y LAS DOS SON POR SIMETRÍA CON EL LADO DE META4.
        //
        // INFORMATIVO (6): ahí van las CANTIDADES y los acumuladores. AÑOS_ANTIGUEDAD es Informativo
        // y valía 23 — aparecía como una diferencia de 23 pesos a favor de BC. No es un caso
        // aislado: en enero de 2026 hay 1.359 líneas informativas de 45 conceptos distintos.
        //
        // CONTRIBUCIÓN PATRONAL (3): es costo del empleador, no remuneración del empleado. Del lado
        // de Meta4 ya quedaba afuera (clasificación CT no entra en EsComparable), así que incluirla
        // acá era comparar contra la nada: los ocho conceptos 7000-7080 salían como "Sólo BC" por
        // 1,7 millones, sugiriendo que BC liquidaba de más cuando Meta4 los tiene y no se miran.
        //
        // La regla general: lo que se excluye de un lado se excluye del otro. Una asimetría acá no
        // produce un error, produce una diferencia inventada.
        LinLiq.SetFilter("Tipo Concepto", '<>%1&<>%2',
            LinLiq."Tipo Concepto"::Informativo, LinLiq."Tipo Concepto"::"Contribución Patronal");
        if LinLiq.FindSet() then
            repeat
                if LinLiq.Importe <> 0 then
                    if BC.ContainsKey(LinLiq."Cód. Concepto") then
                        BC.Set(LinLiq."Cód. Concepto", BC.Get(LinLiq."Cód. Concepto") + LinLiq.Importe)
                    else
                        BC.Add(LinLiq."Cód. Concepto", LinLiq.Importe);
            until LinLiq.Next() = 0;

        // ── los conceptos que conocen los dos lados ──────────────────────────
        foreach CodCpt in ColDeConcepto.Keys() do begin
            NombreCol := ColDeConcepto.Get(CodCpt);
            n += 1;
            Rec.Init();
            Rec."No. Línea" := n;
            Rec."Cód. Concepto" := CodCpt;
            if Concepto.Get(CodCpt) then
                Rec.Descripción := Concepto.Descripción;
            Rec."Columna Meta4" := NombreCol;
            Rec."Importe Meta4" := M4.Get(NombreCol);
            if BC.ContainsKey(CodCpt) then begin
                Rec."Importe BC" := BC.Get(CodCpt);
                Rec.Origen := Rec.Origen::Ambos;
                BC.Remove(CodCpt);
            end else
                Rec.Origen := Rec.Origen::"Sólo Meta4";
            Rec.Diferencia := Rec."Importe BC" - Rec."Importe Meta4";
            Rec.Insert();
            M4.Remove(NombreCol);
        end;

        // ── lo que sólo tiene BC ─────────────────────────────────────────────
        foreach CodCpt in BC.Keys() do begin
            n += 1;
            Rec.Init();
            Rec."No. Línea" := n;
            Rec."Cód. Concepto" := CodCpt;
            if Concepto.Get(CodCpt) then
                Rec.Descripción := Concepto.Descripción;
            Rec."Importe BC" := BC.Get(CodCpt);
            Rec.Diferencia := Rec."Importe BC";
            Rec.Origen := Rec.Origen::"Sólo BC";
            Rec.Insert();
        end;

        // ── columnas de Meta4 sin concepto conocido ──────────────────────────
        // Van aparte y al final: son un hueco del mapeo, no un defecto del motor. Mezclarlas con
        // "Sólo Meta4" haría parecer que BC dejó de liquidar algo que quizás sí liquida con otro
        // código.
        foreach NombreCol in M4.Keys() do begin
            Importe := M4.Get(NombreCol);
            if Importe <> 0 then begin
                n += 1;
                Rec.Init();
                Rec."No. Línea" := n;
                Rec."Columna Meta4" := NombreCol;
                Rec."Importe Meta4" := Importe;
                Rec.Diferencia := -Importe;
                Rec.Origen := Rec.Origen::"Sin equivalencia";
                Rec.Insert();
            end;
        end;

        Filtrar();
    end;

    /// <summary>
    /// Si esta columna de Meta4 tiene sentido en una comparación de remuneración.
    /// </summary>
    /// <remarks>
    /// De las 1.646 columnas con datos, sólo 420 son importes: devengos, retenciones al empleado y
    /// seguridad social. "D" NO entra: son DÍAS, no descuentos — la inicial engaña, y meterlas
    /// pondría un 27 al lado de un 2.493.907,25 en la misma columna de diferencia. Las otras 1.199 son precios unitarios, cantidades, contribuciones patronales y
    /// maquinaria interna de Meta4 (CTROL_*, PRE_UPD_*): no son conceptos que BC deba liquidar, y
    /// mostrarlas como diferencias sin explicar convierte el drilldown en ruido.
    ///
    /// Una columna CON concepto de BC entra siempre, tenga la clasificación que tenga: si alguien
    /// se tomó el trabajo de mapearla, es porque es comparable.
    /// </remarks>
    local procedure EsComparable(var Col: Record "Columna Hist. Meta4"): Boolean
    begin
        // MANDA LA UNIDAD, NO EL MAPEO AUTOMÁTICO. Antes había un atajo: si la columna tenía
        // concepto de BC asignado se comparaba sin mirar la clasificación. Eso metía CANTIDADES en
        // una columna de pesos — DIAS_MES_VAC (AX, 2,917 días) y PR_FRANCO (P, el precio unitario
        // del franco) salían como diferencias de 2,917 y 64.549,80.
        //
        // Que una columna tenga concepto asignado no la vuelve un importe: el mapeo automático es
        // por nombre y tiene colisiones. El mapeo dice CONTRA QUÉ comparar, la clasificación dice
        // SI se puede comparar, y la segunda manda.
        //
        // La excepción es el mapeo VERIFICADO, que sí gana: hay equivalencias comprobadas cuya
        // columna Meta4 está clasificada AX o sin clasificar. El SAC devengado es el caso —
        // BSAC_MES_RG3976 es AX y su equivalencia con el concepto 4750 se verificó aritméticamente.
        if Col."Mapeo Verificado" then
            exit(true);
        exit(Col."Clasificación Meta4" in ['DV', 'RT', 'SS']);
    end;

    local procedure Filtrar()
    begin
        Rec.Reset();
        if not FTodos then
            Rec.SetFilter(Diferencia, '<>%1', 0);
        if Rec.FindFirst() then;
    end;

    var
        FTitulo: Text;
        FTodos: Boolean;
        Estilo: Text;
        ErrCatalogoVacio: Label 'El catálogo de columnas de Meta4 no tiene cargada la clasificación ni la equivalencia con los conceptos de BC, así que no hay contra qué comparar.Sin eso esta pantalla mostraría todo como "Sólo BC" con Meta4 en cero, que parece decir que Meta4 no liquidó nada. Hay que poblar "Clasificación Meta4" y "Cód. Concepto BC" en el catálogo antes de usarla.';
}
