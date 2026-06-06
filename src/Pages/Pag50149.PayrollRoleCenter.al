namespace UAS.Payroll;

page 50149 "Payroll Role Center"
{
    ApplicationArea = All;
    Caption = 'Liquidación de Sueldos';
    PageType = RoleCenter;

    layout
    {
        area(RoleCenter)
        {
        }
    }

    actions
    {
        area(Sections)
        {
            group(GrpPayroll)
            {
                Caption = 'Nómina';

                action(NavLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentJournal;
                    RunObject = Page "Lista Liquidaciones";
                    ToolTip = 'Lista de liquidaciones de haberes.';
                }
                action(NavPeriodos)
                {
                    ApplicationArea = All;
                    Caption = 'Períodos';
                    Image = Period;
                    RunObject = Page "Períodos Liquidación";
                    ToolTip = 'Gestión de períodos de liquidación.';
                }
                action(NavLanzador)
                {
                    ApplicationArea = All;
                    Caption = 'Lanzador de Liquidaciones';
                    Image = CreateDocuments;
                    RunObject = Page "Lanzador Liquidaciones";
                    ToolTip = 'Crea liquidaciones en lote para múltiples proyectos y empleados.';
                }
            }
            group(GrpAgreements)
            {
                Caption = 'Convenios';

                action(NavConvenios)
                {
                    ApplicationArea = All;
                    Caption = 'Convenios Colectivos';
                    Image = Agreement;
                    RunObject = Page "Convenios Colectivos";
                }
                action(NavCategorias)
                {
                    ApplicationArea = All;
                    Caption = 'Categorías CCT';
                    Image = Category;
                    RunObject = Page "Categorías CCT";
                }
                action(NavConceptos)
                {
                    ApplicationArea = All;
                    Caption = 'Conceptos';
                    Image = ItemLines;
                    RunObject = Page "Conceptos Liquidación";
                }
            }

            group(GrpParametros)
            {
                Caption = 'Parámetros';

                action(NavParametros)
                {
                    ApplicationArea = All;
                    Caption = 'Parámetros';
                    Image = SetupList;
                    RunObject = Page "Parámetros";
                }
                action(NavParametrosVigentes)
                {
                    ApplicationArea = All;
                    Caption = 'Parámetros Vigentes';
                    Image = DateRange;
                    RunObject = Page "Parámetros Vigentes";
                }
                action(NavVariablesSistema)
                {
                    ApplicationArea = All;
                    Caption = 'Variables Sistema';
                    Image = VariableList;
                    RunObject = Page "Variable Sistema Liq.";
                }
                action(NavFuenteDatos)
                {
                    ApplicationArea = All;
                    Caption = 'Fuentes de Datos';
                    Image = DataEntry;
                    RunObject = Page "Fuente Datos Liquidación";
                }
                action(NavTablasEscalonadas)
                {
                    ApplicationArea = All;
                    Caption = 'Tablas Escalonadas';
                    Image = Table;
                    RunObject = Page "Tabla Escalonada List";
                }
                action(NavDedGanancias)
                {
                    ApplicationArea = All;
                    Caption = 'Ded. Ganancias (AFIP)';
                    Image = TaxSetup;
                    RunObject = Page "Ded. Ganancias Vigente";
                }
            }

            group(GrpEmpleados)
            {
                Caption = 'Empleados';

                action(NavEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Estados Empleado';
                    Image = EmployeeAgreement;
                    RunObject = Page "Estados Empleado";
                }
                action(NavCodEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Estados';
                    Image = Status;
                    RunObject = Page "Cód. Estados Empleado";
                }
            }

            group(GrpHerramientas)
            {
                Caption = 'Herramientas';

                action(NavAsistente)
                {
                    ApplicationArea = All;
                    Caption = 'Asistente de Fórmulas';
                    Image = CalculateSimulation;
                    RunObject = Page "Asistente Fórmula Liq.";
                }
            }

        }

        area(Reporting)
        {
            action(NavRecibo)
            {
                ApplicationArea = All;
                Caption = 'Recibo de Sueldo';
                Image = "Report";
                RunObject = Report "Recibo de Sueldo";
            }
        }
    }
}
