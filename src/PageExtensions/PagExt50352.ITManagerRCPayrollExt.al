namespace UAS.Payroll;

using Microsoft.RoleCenters;
using Microsoft.HumanResources.Setup;

pageextension 50352 "IT Manager RC Payroll Ext." extends "Administrator Role Center"

{
    actions
    {
        addlast(Sections)
        {
            group(GrpPayrollLiq)
            {
                Caption = 'Liquidaciones';

                action(NavLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentJournal;
                    RunObject = Page "Lista Liquidaciones";
                }
                action(NavPeriodos)
                {
                    ApplicationArea = All;
                    Caption = 'Períodos';
                    Image = Period;
                    RunObject = Page "Períodos Liquidación";
                }
                action(NavLanzador)
                {
                    ApplicationArea = All;
                    Caption = 'Lanzador de Liquidaciones';
                    Image = CreateDocuments;
                    RunObject = Page "Lanzador Liquidaciones";
                }
            }

            group(GrpPayrollConvenios)
            {
                Caption = 'Convenios CCT';

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

            group(GrpPayrollParametros)
            {
                Caption = 'Config. Payroll';

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
                action(NavAsistente)
                {
                    ApplicationArea = All;
                    Caption = 'Asistente de Fórmulas';
                    Image = CalculateSimulation;
                    RunObject = Page "Asistente Fórmula Liq.";
                }
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
                action(NavHRSetup)
                {
                    ApplicationArea = All;
                    Caption = 'Config. RR.HH. (Series)';
                    Image = NumberSetup;
                    RunObject = Page "Human Resources Setup";
                    ToolTip = 'Configuración de RR.HH.: aquí se define la serie de numeración de liquidaciones.';
                }
            }
        }
    }
}
