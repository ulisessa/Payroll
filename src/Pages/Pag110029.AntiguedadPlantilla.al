namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// La antigüedad de toda la plantilla en una lista, calculada con las mismas funciones que usan las
// fórmulas. Sirve para tres cosas distintas:
//
//   · Contrastar contra el sistema anterior antes de liquidar: una columna, mil filas, y las
//     diferencias aparecen ordenando.
//   · Encontrar los legajos rotos. La antigüedad que sale mal no da error: da cero, o da de menos,
//     y se paga así hasta que alguien reclama. Acá los avisos van arriba.
//   · Ver la brecha del Art. 32 — quién ya cumplió otro año pero todavía cobra el tramo anterior
//     porque el corte del 30 de junio pasó antes.
page 110029 "Antigüedad de la Plantilla"
{
    ApplicationArea = All;
    Caption = 'Antigüedad de la Plantilla';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Antigüedad Plantilla Buffer";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    // Sin Editable = false a nivel página: apagaría también los filtros de la cabecera, que no están
    // ligados al registro.

    layout
    {
        area(Content)
        {
            group(Filtro)
            {
                ShowCaption = false;

                field(FFechaRef; FFechaRef)
                {
                    ApplicationArea = All;
                    Caption = 'Antigüedad al';
                    ToolTip = 'Fecha contra la que se mide todo: las fases abiertas, los años y el corte del 30 de junio que rige para esa fecha.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FSoloDeAlta; FSoloDeAlta)
                {
                    ApplicationArea = All;
                    Caption = 'Solo los que están de alta';
                    ToolTip = 'Deja únicamente a quienes tienen un estado vigente que no es una baja a la fecha de referencia. Desmarcado se ven también los que ya no trabajan, útil para liquidaciones finales y para revisar bajas.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FSoloAvisos; FSoloAvisos)
                {
                    ApplicationArea = All;
                    Caption = 'Solo con avisos';
                    ToolTip = 'Deja solo los legajos cuyo historial tiene algo que el cálculo de antigüedad no dice en voz alta: sin altas cargadas, un alta sin su baja, o antigüedad reconocida sumándose encima de las fases.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(ResumenTexto; ResumenTexto)
                {
                    ApplicationArea = All;
                    Caption = 'Resumen';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Cuántos legajos entraron y cuántos tienen algo para revisar.';
                }
            }

            repeater(Plantilla)
            {
                Editable = false;

                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;

                    trigger OnDrillDown()
                    begin
                        AbrirFases();
                    end;
                }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("Años Completos"; Rec."Años Completos")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 0;
                    ToolTip = 'Años enteros cumplidos a la fecha de referencia. Clic para ver las fases una por una.';

                    trigger OnDrillDown()
                    begin
                        AbrirFases();
                    end;
                }
                field("Años al 30/06"; Rec."Años al 30/06")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 0;
                    StyleExpr = EstiloCorte;
                    ToolTip = 'Los que se pagan: el Art. 32 congela la antigüedad al 30 de junio. Resaltado cuando es menor que los años completos, o sea cuando el tripulante ya cumplió el año pero el aumento recién le entra en julio.';
                }
                field("Antigüedad (años)"; Rec."Antigüedad (años)")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 1;
                    ToolTip = 'La antigüedad con fracción, para las fórmulas que prorratean.';
                }
                field(Fases; Rec.Fases)
                {
                    ApplicationArea = All;

                    trigger OnDrillDown()
                    begin
                        AbrirFases();
                    end;
                }
                field("De Alta"; Rec."De Alta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Sale del estado vigente a la fecha de referencia: está de alta quien tiene un estado vigente que no es una baja. No de que la última fase haya quedado abierta — son dos cosas que deberían coincidir, y cuando no coinciden aparece un aviso.';
                }
                field("Estado Vigente"; Rec."Estado Vigente") { ApplicationArea = All; }
                field("Descripción Estado"; Rec."Descripción Estado") { ApplicationArea = All; }
                field("Fecha Primer Alta"; Rec."Fecha Primer Alta") { ApplicationArea = All; }
                field("Fecha Última Alta"; Rec."Fecha Última Alta") { ApplicationArea = All; }
                field("Fecha Última Baja"; Rec."Fecha Última Baja") { ApplicationArea = All; }
                field("Días Totales"; Rec."Días Totales")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suma de los días de las fases. No incluye la Antigüedad Reconocida: si los años no cierran con estos días, es por eso.';
                }
                field("Antigüedad Reconocida"; Rec."Antigüedad Reconocida")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 1;
                }
                field(Aviso; Rec.Aviso)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloAviso;
                }
                field(Avisos; Rec.Avisos) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerFases)
            {
                ApplicationArea = All;
                Caption = 'Fases de Alta';
                Image = History;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Abre el detalle del legajo: cada alta con su baja y los días que aporta.';

                trigger OnAction()
                begin
                    AbrirFases();
                end;
            }
            action(VerEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Ficha del Empleado';
                Image = Employee;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre el legajo.';

                trigger OnAction()
                var
                    Emp: Record Employee;
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    if Emp.Get(Rec."No. Empleado") then
                        Page.Run(Page::"Employee Card", Emp);
                end;
            }
            action(VerHistorial)
            {
                ApplicationArea = All;
                Caption = 'Historial de Estados';
                Image = Timeline;
                ToolTip = 'El historial completo, que es de donde salen las fases. Ahí se corrigen: las altas y las bajas son estados como cualquier otro.';

                trigger OnAction()
                var
                    Estado: Record "Estado Empleado";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
                    Estado.SetRange("No. Empleado", Rec."No. Empleado");
                    Page.Run(Page::"Estados Empleado", Estado);
                end;
            }
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Vuelve a recorrer la plantilla. Necesario después de corregir altas o bajas.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FFechaRef = 0D then
            FFechaRef := WorkDate();
        FSoloDeAlta := true;
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloAviso := 'Standard';
        if Rec.Aviso <> '' then
            EstiloAviso := 'Unfavorable';

        // El corte del Art. 32 en amarillo cuando frena un aumento ya cumplido. No es un error —es
        // lo que manda el convenio— pero es la pregunta que más llega, y conviene poder contestarla
        // señalando la fila en vez de rehacer la cuenta.
        EstiloCorte := 'Standard';
        if Rec."Años al 30/06" < Rec."Años Completos" then
            EstiloCorte := 'Ambiguous';
    end;

    local procedure AbrirFases()
    var
        FasesPage: Page "Fases de Alta";
    begin
        if Rec."No. Empleado" = '' then
            exit;
        FasesPage.SetEmpleado(Rec."No. Empleado");
        FasesPage.RunModal();
    end;

    local procedure Cargar()
    var
        Emp: Record Employee;
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Dlg: Dialog;
        Total: Integer;
        Hechos: Integer;
        ConAviso: Integer;
        MostrarDlg: Boolean;
    begin
        if FFechaRef = 0D then
            FFechaRef := WorkDate();

        Rec.Reset();
        Rec.DeleteAll();
        FExcluidosNoAlta := 0;
        FExcluidosSinAviso := 0;

        Total := Emp.Count();
        // Recorrer la plantilla entera son varias pasadas por el historial de cada legajo. Con
        // cientos de empleados eso se siente, y una pantalla congelada sin explicación se lee como
        // que el sistema se colgó.
        MostrarDlg := GuiAllowed() and (Total > 50);
        if MostrarDlg then
            Dlg.Open(TxtProgreso);

        if Emp.FindSet() then
            repeat
                Hechos += 1;
                if MostrarDlg and (Hechos mod 25 = 0) then begin
                    Dlg.Update(1, Emp."No.");
                    Dlg.Update(2, Round(Hechos / Total * 100, 1));
                end;
                if ArmarFila(Emp, EstadoMgt) then
                    if Rec.Avisos > 0 then
                        ConAviso += 1;
            until Emp.Next() = 0;

        if MostrarDlg then
            Dlg.Close();

        Rec.Reset();
        // Los avisos arriba: si hay un legajo sin altas, tiene que ser lo primero que se vea, no algo
        // que aparezca recién si a alguien se le ocurre ordenar por esa columna.
        Rec.SetCurrentKey(Avisos, "No. Empleado");
        Rec.Ascending(false);
        if Rec.FindFirst() then;

        ResumenTexto := CopyStr(StrSubstNo(TxtResumen, Rec.Count(), ConAviso, FFechaRef), 1, MaxStrLen(ResumenTexto));
        if FExcluidosNoAlta > 0 then
            ResumenTexto := CopyStr(ResumenTexto + StrSubstNo(TxtExcluidosNoAlta, FExcluidosNoAlta), 1, MaxStrLen(ResumenTexto));
        if FExcluidosSinAviso > 0 then
            ResumenTexto := CopyStr(ResumenTexto + StrSubstNo(TxtExcluidosSinAviso, FExcluidosSinAviso), 1, MaxStrLen(ResumenTexto));
        CurrPage.Update(false);
    end;

    /// <summary>Arma la fila de un legajo. Devuelve false si quedó fuera por los filtros.</summary>
    local procedure ArmarFila(var Emp: Record Employee; var EstadoMgt: Codeunit "Gestión Estado Empleado"): Boolean
    var
        Fases: Record "Fase Alta Empleado";
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Avisos: Integer;
        FaseAbierta: Boolean;
        PrimerAviso: Text[250];
        DiasFase: Integer;
    begin
        Rec.Init();
        Rec."No. Empleado" := Emp."No.";
        Rec."Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen(Rec."Nombre Empleado"));
        Rec."Antigüedad Reconocida" := Emp."Antigüedad Reconocida";

        // Las fases se leen de su tabla. Antes se armaban en memoria recorriendo el historial de
        // estados; desde que altas y bajas son su propia entidad, ya están escritas.
        Fases.SetRange("No. Empleado", Emp."No.");
        if Fases.FindSet() then
            repeat
                Rec.Fases += 1;

                // La fase abierta se mide contra la fecha de referencia. En la tabla sus Días son
                // cero a propósito —dependen de contra qué fecha se pregunte— así que sumar la
                // columna tal cual dejaría fuera justamente el tramo que está corriendo.
                if Fases."Fecha Baja" <> 0D then
                    DiasFase := Fases."Fecha Baja" - Fases."Fecha Alta"
                else
                    DiasFase := FFechaRef - Fases."Fecha Alta";
                if DiasFase > 0 then
                    Rec."Días Totales" += DiasFase;

                if Fases."Fecha Alta" <> 0D then begin
                    if (Rec."Fecha Primer Alta" = 0D) or (Fases."Fecha Alta" < Rec."Fecha Primer Alta") then
                        Rec."Fecha Primer Alta" := Fases."Fecha Alta";
                    if Fases."Fecha Alta" > Rec."Fecha Última Alta" then
                        Rec."Fecha Última Alta" := Fases."Fecha Alta";
                end;
                if Fases."Fecha Baja" > Rec."Fecha Última Baja" then
                    Rec."Fecha Última Baja" := Fases."Fecha Baja";
                if Fases.Abierta then
                    FaseAbierta := true;
            until Fases.Next() = 0;

        // 'De Alta' sale del estado vigente, no de que la última fase haya quedado abierta. Son dos
        // cosas que deberían coincidir pero que se rompen por caminos distintos: un empleado puede
        // estar trabajando —con su estado vigente al día— y no tener ninguna fase, porque la
        // migración no lo alcanzó o porque el alta se cargó con un código cuyo Tipo Estado no es
        // Alta. Si el filtro dependiera de las fases, esos legajos —justo los que hay que revisar—
        // desaparecerían de la lista sin dejar rastro, que es lo contrario de para qué existe esto.
        if EstadoMgt.GetEstado(Emp."No.", FFechaRef, EstadoEmp) then begin
            Rec."Estado Vigente" := EstadoEmp."Cód. Estado";
            if CodEst.Get(EstadoEmp."Cód. Estado") then begin
                Rec."Descripción Estado" := CopyStr(CodEst.Descripción, 1, MaxStrLen(Rec."Descripción Estado"));
                Rec."De Alta" := CodEst."Tipo Estado" <> CodEst."Tipo Estado"::Baja;
            end;
        end;

        Rec."Años Completos" := EstadoMgt.CalcAntiguedadAlFecha(Emp."No.", FFechaRef);
        Rec."Antigüedad (años)" := EstadoMgt.CalcAntiguedadFraccionAlFecha(Emp."No.", FFechaRef);
        Rec."Años al 30/06" := EstadoMgt.CalcAntiguedadAl30Junio(Emp."No.", FFechaRef);

        // El desacuerdo entre el estado vigente y las fases. Es el aviso más valioso de la página:
        // significa que alguien está trabajando y cobrando, y el motor le está contando la
        // antigüedad como si hubiera entrado en otro momento, o como si no hubiera entrado nunca.
        if Rec."De Alta" and not FaseAbierta and (Rec.Fases > 0) then begin
            Avisos += 1;
            if PrimerAviso = '' then
                PrimerAviso := CopyStr(TxtAltaSinFaseAbierta, 1, MaxStrLen(PrimerAviso));
        end;
        if FaseAbierta and not Rec."De Alta" then begin
            Avisos += 1;
            if PrimerAviso = '' then
                PrimerAviso := CopyStr(TxtFaseAbiertaSinAlta, 1, MaxStrLen(PrimerAviso));
        end;

        // Un legajo sin una sola fase no da error en ninguna liquidación: da antigüedad cero y el
        // concepto sale en cero o no sale. Es el modo de falla más caro de todos porque no se ve.
        if Rec.Fases = 0 then begin
            Avisos += 1;
            if PrimerAviso = '' then
                PrimerAviso := CopyStr(TxtSinFases, 1, MaxStrLen(PrimerAviso));
        end;

        // Antigüedad Reconocida y fases al mismo tiempo: los años reconocidos se suman ENCIMA de los
        // que aportan las fases. Cuando la reconocida se cargó a mano para suplir un historial que
        // después se migró, eso es contar dos veces el mismo período.
        if (Emp."Antigüedad Reconocida" > 0) and (Rec.Fases > 0) then begin
            Avisos += 1;
            if PrimerAviso = '' then
                PrimerAviso := CopyStr(StrSubstNo(TxtReconocidaYFases, Emp."Antigüedad Reconocida"), 1, MaxStrLen(PrimerAviso));
        end;

        Rec.Avisos := Avisos;
        Rec.Aviso := PrimerAviso;

        // Una lista vacía sin explicación se lee como 'el informe está roto'. Los descartes se
        // cuentan y el resumen los dice.
        if FSoloDeAlta and not Rec."De Alta" then begin
            FExcluidosNoAlta += 1;
            exit(false);
        end;
        if FSoloAvisos and (Avisos = 0) then begin
            FExcluidosSinAviso += 1;
            exit(false);
        end;

        Rec.Insert();
        exit(true);
    end;

    var
        FFechaRef: Date;
        FSoloDeAlta: Boolean;
        FSoloAvisos: Boolean;
        FExcluidosNoAlta: Integer;
        FExcluidosSinAviso: Integer;
        ResumenTexto: Text[250];
        EstiloAviso: Text[20];
        EstiloCorte: Text[20];
        TxtProgreso: Label 'Calculando antigüedades...\Legajo  #1################\Avance  #2######### %', Comment = '#1 = legajo, #2 = porcentaje';
        TxtResumen: Label '%1 legajos · %2 con algo para revisar · antigüedad medida al %3', Comment = '%1 = cantidad, %2 = con avisos, %3 = fecha';
        TxtExcluidosNoAlta: Label ' · %1 fuera por no estar de alta', Comment = '%1 = cantidad';
        TxtExcluidosSinAviso: Label ' · %1 fuera por no tener avisos', Comment = '%1 = cantidad';
        TxtAltaSinFaseAbierta: Label 'Está de alta según su estado vigente, pero ninguna fase quedó abierta: le falta el alta en el historial y la antigüedad le sale de menos.';
        TxtFaseAbiertaSinAlta: Label 'Tiene una fase abierta pero su estado vigente es una baja: la antigüedad le sigue corriendo a alguien que ya no trabaja.';
        TxtSinFases: Label 'Sin altas cargadas: la antigüedad de este legajo es cero para toda fórmula, y ningún cálculo lo va a avisar.';
        TxtReconocidaYFases: Label 'Tiene %1 año(s) de antigüedad reconocida ADEMÁS de sus fases: los años se suman. Revisar que no sea el mismo período contado dos veces.', Comment = '%1 = años reconocidos';
}
