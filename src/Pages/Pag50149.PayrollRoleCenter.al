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
                action(NavArbolLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Árbol de Liquidaciones';
                    Image = Hierarchy;
                    RunObject = Page "Árbol de Liquidaciones";
                    ToolTip = 'Las liquidaciones agrupadas por período, tipo y proyecto, con los subtotales de haberes, descuentos y neto en cada nodo.';
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
                action(NavFormulasConErrores)
                {
                    ApplicationArea = All;
                    Caption = 'Fórmulas con errores';
                    Image = ErrorLog;
                    RunObject = Page "Fórmulas con Errores";
                    ToolTip = 'Conceptos cuya fórmula o condición no se puede parsear. Corre el mismo control que la primera fase del cálculo, pero sin necesitar una liquidación: sirve para encontrarlas al configurar y no el día que hay que pagar.';
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
                action(NavArbolParametros)
                {
                    ApplicationArea = All;
                    Caption = 'Árbol de Parámetros';
                    Image = Hierarchy;
                    RunObject = Page "Árbol de Parámetros";
                    ToolTip = 'Los valores de parámetro ordenados por especificidad: el valor por defecto arriba y las excepciones por convenio, categoría o empleado colgando debajo. Es la misma cascada que resuelve el motor.';
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
                action(NavTiposAtributo)
                {
                    ApplicationArea = All;
                    Caption = 'Tipos de Atributo';
                    Image = Dimensions;
                    RunObject = Page "Tipos de Atributo";
                    ToolTip = 'Define qué atributos se pueden cargar en empleados, buques y mareas. Se leen desde las fórmulas con una Fuente de Datos.';
                }
                action(NavValoresAtributo)
                {
                    ApplicationArea = All;
                    Caption = 'Valores de Atributo';
                    Image = DimensionSets;
                    RunObject = Page "Valores de Atributo";
                    ToolTip = 'Listas cerradas contra las que se validan los atributos, con el número que cada valor le pasa a las fórmulas.';
                }
                action(NavClasesEntidad)
                {
                    ApplicationArea = All;
                    Caption = 'Clases de Entidad';
                    Image = Category;
                    RunObject = Page "Clases de Entidad";
                    ToolTip = 'Agrupa a las entidades por tipo —buques, plantas, mareas— y define qué atributos le corresponden a cada grupo.';
                }
                action(NavEntidades)
                {
                    ApplicationArea = All;
                    Caption = 'Entidades';
                    Image = List;
                    RunObject = Page "Entidades";
                    ToolTip = 'Las entidades sobre las que se cargan atributos, tomadas de los valores de dimensión. Desde acá se clasifican y se les aplica la plantilla de su clase.';
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
                action(NavAntiguedadPlantilla)
                {
                    ApplicationArea = All;
                    Caption = 'Antigüedad de la Plantilla';
                    Image = Timeline;
                    RunObject = Page "Antigüedad de la Plantilla";
                }
                action(NavCodEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Estados';
                    Image = Status;
                    RunObject = Page "Cód. Estados Empleado";
                }
                action(NavFrancos)
                {
                    ApplicationArea = All;
                    Caption = 'Francos por Tripulante';
                    Image = Absence;
                    RunObject = Page "Francos por Tripulante";
                    ToolTip = 'Saldo de francos abierto por tripulante y por la categoría en que se ganaron, con lo que costaría pagarlos a la fecha de corte.';
                }
                action(NavSaldoInicialFrancos)
                {
                    ApplicationArea = All;
                    Caption = 'Saldo Inicial de Francos';
                    Image = ImportExcel;
                    RunObject = Page "Saldo Inicial de Francos";
                    ToolTip = 'Carga de los francos que cada tripulante ya tenía ganados antes de la puesta en marcha. Se revisa y después se aplica: el proceso genera los lotes y deja anotado cuál salió de cada fila, para poder revertirlo.';
                }
                action(NavAsignarAtributoMasivo)
                {
                    ApplicationArea = All;
                    Caption = 'Asignar Atributos en Lote';
                    Image = Apply;
                    RunObject = Report "Asignar Atributo Masivo";
                    ToolTip = 'Asigna un mismo atributo a muchos empleados, buques o proyectos de una vez, con una vigencia común. La vigencia anterior de cada entidad se cierra sola.';
                }
                action(NavMigrarConvenioCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Migrar Convenio y Categoría';
                    Image = ChangeTo;
                    RunObject = Report "Migrar Convenio y Categoría";
                    ToolTip = 'Carga inicial del historial: toma el convenio y la categoría que cada empleado ya tiene en su ficha o en su asignación a proyecto y los escribe como atributos con una fecha común. Se corre una vez, y conviene probarlo antes en modo simulación.';
                }
                action(NavAtributosEntidad)
                {
                    ApplicationArea = All;
                    Caption = 'Atributos';
                    Image = List;
                    RunObject = Page "Atributos de Entidad";
                    ToolTip = 'Valores de los atributos por empleado, buque o marea, con su historial de vigencias. Abre mostrando solo los vigentes hoy.';
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
                    Caption = 'Historial de Fórmulas';
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
                action(NavVersionesInactivas)
                {
                    ApplicationArea = All;
                    Caption = 'Versiones Inactivas a Revisar';
                    Image = Versions;
                    RunObject = Page "Versiones Inactivas a Revisar";
                    ToolTip = 'Conceptos con una versión marcada como inactiva, y qué cambia para cada uno ahora que la baja se resuelve por fecha de vigencia y no por el booleano. Revisar antes de liquidar.';
                }
                action(NavControlOrden)
                {
                    ApplicationArea = All;
                    Caption = 'Control de Orden de Cálculo';
                    Image = CheckList;
                    RunObject = Page "Control Orden Acumuladores";
                    ToolTip = 'Verifica que ningún concepto lea un acumulador antes de que todos sus aportes hayan entrado. Un conflicto acá significa importes menores a los correctos, sin ningún error visible.';
                }
                action(NavDiasSinLiquidar)
                {
                    ApplicationArea = All;
                    Caption = 'Días Liquidados por Empleado';
                    Image = PeriodEntries;
                    RunObject = Page "Control de Cobertura Liq.";
                    ToolTip = 'Los días en que un empleado tuvo estado y ninguna liquidación cubrió. Detecta lo que el período esconde: dos mareas del 1 al 20 dejan julio "liquidado" con once días sin liquidar.';
                }
                action(NavConceptosPorTipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Conceptos por Tipo Liq.';
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
