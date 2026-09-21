namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50350 "Empleado Pesca Card Ext." extends "Employee Card"
{
    layout
    {
        addlast(General)
        {
            group(Liquidación)
            {
                Caption = 'Liquidación';

                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Convenio colectivo de trabajo aplicable por defecto. Se hereda a cada nueva asignación de proyecto.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    ToolTip = 'Categoría dentro del CCT. Define el % de escala sobre el básico.';
                }
                field(AntiguedadCalculada; AntiguedadTexto)
                {
                    ApplicationArea = All;
                    Caption = 'Antigüedad';
                    Editable = false;
                    ToolTip = 'La antigüedad que usa el cálculo: suma todos los tramos entre cada alta y su baja, más la Antigüedad Reconocida. Clic para ver las fases una por una.';

                    trigger OnDrillDown()
                    var
                        Fases: Page "Fases de Alta";
                    begin
                        Rec.TestField("No.");
                        Fases.SetEmpleado(Rec."No.");
                        // RunModal y no Run: abierta sin modo, la página vuelve del OnOpenPage antes
                        // de que el cliente la muestre y el filtro por legajo que dejó SetEmpleado se
                        // pierde. Desde un drilldown o desde una acción de subpágina el síntoma es que
                        // el botón no hace nada.
                        Fases.RunModal();
                    end;
                }
                field("Antigüedad Reconocida"; Rec."Antigüedad Reconocida")
                {
                    ApplicationArea = All;
                    ToolTip = 'Años que se suman a los que salen del historial de estados: los de una relación anterior en la misma empresa, o los reconocidos al ingresar. Entran en el total de arriba.';

                    trigger OnValidate()
                    begin
                        CalcularAntiguedad();
                    end;
                }
                field("Fecha Jubilación"; Rec."Fecha Jubilación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha desde la cual el empleado es jubilado. Vacío = no es jubilado.';
                }
                field("Zona Desfavorable"; Rec."Zona Desfavorable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código de zona desfavorable del empleado. Se usa como valor por defecto si el proyecto no tiene zona asignada.';
                }
            }
        }
        addafter(General)
        {
            // Las cuatro cosas que se consultan y se corrigen sobre un legajo mientras se liquida, en
            // la ficha y no a tres clics: qué atributos tiene, desde cuándo pertenece a la empresa,
            // en qué proyectos está y cómo viene su historial de estados. El FactBox de atributos
            // sigue estando y no se pisa con esto: ahí se ve lo vigente de un vistazo, acá se edita
            // y se ve el historial.
            part(Atributos; "Atributos Entidad Sub")
            {
                ApplicationArea = All;
                Caption = 'Atributos';
                // El tipo de entidad es constante: esta ficha es la del empleado. Sin él, la
                // subpágina mostraría también los atributos de un buque o un proyecto que casualmente
                // tuvieran el mismo código.
                SubPageLink = "Tipo Entidad" = CONST(Empleado), "Cód. Entidad" = FIELD("No.");
                UpdatePropagation = Both;
            }
            // Va ANTES del historial de estados y de los proyectos a propósito: las fases son el
            // marco de las otras dos. Un estado o una asignación fuera de toda fase es un error, y
            // verlas juntas es lo que permite notarlo — la migración dejó 68 estados fuera de fase y
            // 37 fases abiertas de gente que ya no está.
            part(FasesDeAlta; "Fases Alta Empleado Sub")
            {
                ApplicationArea = All;
                Caption = 'Fases de Alta';
                SubPageLink = "No. Empleado" = FIELD("No.");
                UpdatePropagation = Both;
            }
            part(ProyectosAsignados; "Personal Proyecto")
            {
                ApplicationArea = All;
                Caption = 'Proyectos Asignados';
                SubPageLink = "No. Empleado" = FIELD("No.");
                UpdatePropagation = Both;
            }
            part(HistorialEstados; "Estados Empleado Sub")
            {
                ApplicationArea = All;
                Caption = 'Historial de Estados';
                SubPageLink = "Tipo Entidad" = CONST(Empleado), "No. Empleado" = FIELD("No.");
                UpdatePropagation = Both;
            }
            part(DeduccionesGanancias; "Ded. Ganancias Empleado Sub")
            {
                ApplicationArea = All;
                Caption = 'Deducciones Ganancias 4ta Cat.';
                SubPageLink = "No. Empleado" = FIELD("No.");
            }
        }
        addlast(FactBoxes)
        {
            part(EstadoActual; "Estado Empleado FactBox")
            {
                ApplicationArea = All;
                Caption = 'Estado Actual';
                SubPageLink = "No. Empleado" = FIELD("No.");
            }
            // Sin SubPageLink: se alimenta desde OnAfterGetCurrRecord porque usa tabla temporal
            // (solo muestra lo vigente, y eso se decide en código y no con un filtro de fechas).
            part(AtributosVigentes; "Atributos Entidad FactBox")
            {
                ApplicationArea = All;
                Caption = 'Atributos';
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            group(GrpLiquidacion)
            {
                Caption = 'Liquidación';
                Image = PaymentHistory;

                action(VerEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Historial de Estados';
                    Image = History;
                    RunObject = Page "Estados Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerFasesAlta)
                {
                    ApplicationArea = All;
                    Caption = 'Fases de Alta';
                    Image = JobListSetup;
                    ToolTip = 'Los tramos entre cada alta y su baja, con el motivo del egreso y los días que aporta cada uno a la antigüedad. Es la misma información del historial de estados, apareada: ahí una fase son dos filas separadas por todos los estados que hubo en el medio.';

                    trigger OnAction()
                    var
                        Fases: Page "Fases de Alta";
                    begin
                        Fases.SetEmpleado(Rec."No.");
                        // RunModal y no Run: abierta sin modo, la página vuelve del OnOpenPage antes
                        // de que el cliente la muestre y el filtro por legajo que dejó SetEmpleado se
                        // pierde. Desde un drilldown o desde una acción de subpágina el síntoma es que
                        // el botón no hace nada.
                        Fases.RunModal();
                    end;
                }
                action(VerAtributos)
                {
                    ApplicationArea = All;
                    Caption = 'Atributos';
                    Image = Dimensions;
                    RunObject = Page "Atributos de Entidad";
                    RunPageLink = "Tipo Entidad" = const(Empleado), "Cód. Entidad" = field("No.");
                    ToolTip = 'Atributos del empleado con sus vigencias: convenio, categoría y todo lo que se haya definido. Abre mostrando los de hoy; desde ahí se ve el historial completo y se cargan vigencias nuevas.';
                }
                action(VerNovedades)
                {
                    ApplicationArea = All;
                    Caption = 'Novedades';
                    Image = Journal;
                    RunObject = Page "Novedades Liquidación";
                    RunPageLink = "No. Empleado" = field("No.");
                    ToolTip = 'Novedades cargadas para este empleado, con su estado: cuáles ya entraron en una liquidación, cuáles siguen pendientes y cuáles el motor descartó con un motivo.';
                }
                action(VerFrancos)
                {
                    ApplicationArea = All;
                    Caption = 'Francos';
                    Image = Absence;
                    ToolTip = 'Saldo de francos del empleado, abierto por la categoría en que se ganó cada lote. Los francos no son fungibles: se pagan al valor de la categoría en que se devengaron, no a la del encuadre actual, así que un tripulante que ascendió puede tener francos de dos precios.';

                    trigger OnAction()
                    var
                        Francos: Page "Francos por Tripulante";
                    begin
                        Rec.TestField("No.");
                        Francos.SetFiltroEmpleado(Rec."No.");
                        Francos.Run();
                    end;
                }
                action(VerLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentHistory;
                    RunObject = Page "Lista Liquidaciones";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerTripulaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Proyectos Asignados';
                    Image = Employee;
                    RunObject = Page "Personal Proyecto";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerPrestamos)
                {
                    ApplicationArea = All;
                    Caption = 'Préstamos y Anticipos';
                    Image = Payment;
                    RunObject = Page "Lista Préstamos Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver y gestionar los préstamos y anticipos del empleado.';
                }
                action(NuevoPrestamo)
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo Préstamo / Anticipo';
                    Image = NewDocument;
                    ToolTip = 'Registrar un nuevo préstamo o anticipo para este empleado.';
                    trigger OnAction()
                    var
                        Prestamo: Record "Préstamo Empleado";
                        FichaPrestamo: Page "Ficha Préstamo Empleado";
                    begin
                        Clear(Prestamo);
                        Prestamo."No. Empleado" := Rec."No.";
                        Prestamo.Validate("No. Empleado");
                        Prestamo.Fecha := Today();
                        FichaPrestamo.SetRecord(Prestamo);
                        FichaPrestamo.RunModal();
                    end;
                }
            }
        }
    }

    // El factbox de atributos usa tabla temporal, así que no se llena solo con un SubPageLink: hay
    // que empujarle el empleado en cada cambio de registro.
    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.AtributosVigentes.Page.SetEntidad("Tipo Entidad Estado"::Empleado, Rec."No.");
        CalcularAntiguedad();
    end;

    /// <remarks>
    /// Se muestran las dos formas del mismo número porque las fórmulas usan las dos y no dan lo
    /// mismo: la fraccionaria —AÑOS_ANTIGUEDAD— para prorratear, y los años COMPLETOS para los
    /// tramos, que es como leen el convenio y la LCT. Un tripulante con 4,8 años cobra la escala
    /// de 4, no la de 5, y verlo escrito evita la discusión de por qué "tiene casi cinco años y
    /// no le pagan el tramo".
    ///
    /// Sale del MISMO cálculo que usa el motor, no de una cuenta propia: si alguna vez difieren,
    /// la diferencia aparece en la ficha y no en un recibo.
    /// </remarks>
    local procedure CalcularAntiguedad()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Fraccion: Decimal;
        Completos: Decimal;
    begin
        AntiguedadTexto := '';
        if Rec."No." = '' then
            exit;
        Fraccion := EstadoMgt.CalcAntiguedadFraccionAlFecha(Rec."No.", WorkDate());
        Completos := EstadoMgt.CalcAntiguedadAlFecha(Rec."No.", WorkDate());
        AntiguedadTexto := CopyStr(StrSubstNo(TxtAntiguedad, Fraccion, Completos), 1, MaxStrLen(AntiguedadTexto));
    end;

    var
        AntiguedadTexto: Text[100];
        TxtAntiguedad: Label '%1 años  ·  %2 completos', Comment = '%1 = años con fracción, %2 = años completos';
}
