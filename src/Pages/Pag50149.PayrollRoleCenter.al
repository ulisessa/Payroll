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
            group(Activities)
            {
                Caption = 'Actividades';

                part(CueSiradig; "Cue SIRADIG")
                {
                    ApplicationArea = All;
                }
            }
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
                action(NavNovedades)
                {
                    ApplicationArea = All;
                    Caption = 'Novedades de Liquidación';
                    Image = Journal;
                    RunObject = Page "Novedades Liquidación";
                    ToolTip = 'Carga de novedades del período antes de liquidar: horas extras, premios, ajustes, descuentos. El motor las convierte en incidencias al calcular.';
                }
                action(NavLanzador)
                {
                    ApplicationArea = All;
                    Caption = 'Lanzador de Liquidaciones';
                    Image = CreateDocuments;
                    RunObject = Page "Lanzador Liquidaciones";
                    ToolTip = 'Crea liquidaciones en lote para múltiples proyectos y empleados.';
                }
                action(NavTiposLiquidacion)
                {
                    ApplicationArea = All;
                    Caption = 'Tipos de Liquidación';
                    RunObject = Page "Tipos Liquidación";
                    ToolTip = 'Configura los tipos de liquidación (Regular, Cierre Marea, etc.) y su comportamiento.';
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
                action(NavImportacionesSiradig)
                {
                    ApplicationArea = All;
                    Caption = 'Importaciones SIRADIG';
                    Image = ElectronicDoc;
                    RunObject = Page "Importaciones SIRADIG";
                    ToolTip = 'Importa y procesa archivos SIRADIG (.xml.zip o .xml) de los empleados.';
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
                action(NavHistorialFormulas)
                {
                    ApplicationArea = All;
                    Caption = 'Historial de Cambios de Fórmula';
                    Image = ChangeLog;
                    RunObject = Page "Historial Fórmulas Concepto";
                    ToolTip = 'Quién cambió qué fórmula, cuándo y de qué texto a qué texto, con la posibilidad de restaurar una versión anterior.';
                }
                action(NavRegistrosProceso)
                {
                    ApplicationArea = All;
                    Caption = 'Registros de Proceso';
                    Image = History;
                    RunObject = Page "Registros Proceso Liq.";
                    ToolTip = 'Historial de cálculos, aprobaciones y reaperturas, con los errores y las acciones de cada uno. Es dónde mirar cuando una liquidación falló o salió con advertencias.';
                }
                action(NavControlOrden)
                {
                    ApplicationArea = All;
                    Caption = 'Control de Orden de Cálculo';
                    Image = CheckList;
                    RunObject = Page "Control Orden Acumuladores";
                    ToolTip = 'Verifica que ningún concepto lea un acumulador antes de que todos sus aportes hayan entrado. Un conflicto acá significa importes menores a los correctos, sin ningún error visible.';
                }
                action(NavConceptosPorTipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Conceptos por Tipo de Liquidación';
                    Image = Allocate;
                    RunObject = Page "Conceptos por Tipo Liq.";
                    ToolTip = 'Asigna conceptos a un tipo de liquidación con dos listas (disponibles / asignados).';
                }
                action(NavConveniosPorConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Convenios por Concepto';
                    Image = Allocate;
                    RunObject = Page "Convenios por Concepto";
                    ToolTip = 'Asigna convenios a varios conceptos a la vez (disponibles / asignados).';
                }
                action(NavConceptosPorConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Conceptos por Convenio';
                    Image = Allocate;
                    RunObject = Page "Conceptos por Convenio";
                    ToolTip = 'Partiendo de un convenio (y opcionalmente una categoría), tilda los conceptos que le aplican.';
                }
                action(NavBuques)
                {
                    ApplicationArea = All;
                    Caption = 'Buques';
                    Image = Vendor;
                    RunObject = Page "Buques";
                    ToolTip = 'Estados de buque y carga en lote (con propagación a empleados).';
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
            action(NavAsignarEstado)
            {
                ApplicationArea = All;
                Caption = 'Asignar Estado Masivo';
                Image = ChangeStatus;
                RunObject = Report "Asignar Estado Masivo";
            }
            action(NavInsertarIncidenciaMasiva)
            {
                ApplicationArea = All;
                Caption = 'Insertar Incidencia Masiva';
                Image = NewItem;
                RunObject = Report "Insertar Incidencia Masiva";
                ToolTip = 'Carga la misma incidencia (concepto + importe, o cantidad × valor unitario) en varias liquidaciones a la vez.';
            }
            action(NavCrearLiqEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Crear Liq. para Empleado';
                Image = Employee;
                RunObject = Report "Crear Liq. para Empleado";
            }
            action(NavPrestamos)
            {
                ApplicationArea = All;
                Caption = 'Préstamos y Anticipos';
                Image = Payment;
                RunObject = Page "Lista Préstamos Empleado";
            }
        }
    }
}
