namespace UAS.Payroll;

page 110067 "Reglas Asiento Liq."
{
    ApplicationArea = All;
    Caption = 'Reglas del asiento de sueldos';
    // La fila se inserta al salir de ella: el OnInsert exige la fila completa (los pares y las dos
    // cuentas), y sin esto se insertaba con el primer campo cargado.
    DelayedInsert = true;
    PageType = List;
    SourceTable = "Regla Asiento Liq.";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(CodConcepto; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'El concepto de liquidación. Su importe va al debe de una cuenta y al haber de otra; un importe negativo invierte el par.';
                }
                field(FiltroTipoLiq; Rec."Filtro Tipo Liq.")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué tipos de liquidación aplica la fila (AGUINALDO, LIQ_FINAL|RELIQUIDACION). En blanco, a todos.';
                }
                field(FiltroProyecto; Rec."Filtro Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué proyectos aplica la fila (PN-ADM-BAIRES, PN-ARB*). En blanco, a todos. Entre las filas que coinciden gana la que tiene más filtros cargados.';
                }
                field(CodDimensionFiltro; Rec."Cód. Dimensión Filtro")
                {
                    ApplicationArea = All;
                    ToolTip = 'Una dimensión que acota la fila. El valor sale de las dimensiones por defecto del proyecto de la liquidación o, si el proyecto no la tiene, de las del empleado.';
                }
                field(FiltroValorDimension; Rec."Filtro Valor Dimensión")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué valores de la dimensión acepta la fila.';
                }
                field(CodAtributoFiltro; Rec."Cód. Atributo Filtro")
                {
                    ApplicationArea = All;
                    ToolTip = 'Un atributo del empleado o de la marea que acota la fila (CONVENIO, SINDICATO), vigente a la fecha de la liquidación.';
                }
                field(FiltroValorAtributo; Rec."Filtro Valor Atributo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué valores del atributo acepta la fila (FA|CE).';
                }
                field(VigenciaDesde; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                    ToolTip = 'Desde qué fecha de liquidación vale la fila. Un cambio de cuenta es una vigencia nueva: los meses anteriores se siguen armando con la cuenta de entonces.';
                }
                field(CuentaDebe; Rec."Cuenta Debe")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuenta que se debita con el importe del concepto.';
                }
                field(NombreCuentaDebe; Rec."Nombre Cuenta Debe")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la cuenta del debe.';
                }
                field(CuentaHaber; Rec."Cuenta Haber")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuenta que se acredita con el importe del concepto.';
                }
                field(NombreCuentaHaber; Rec."Nombre Cuenta Haber")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la cuenta del haber.';
                }
                field(NoContabiliza; Rec."No Contabiliza")
                {
                    ApplicationArea = All;
                    ToolTip = 'El concepto está mapeado y no va al asiento. Un concepto con importe y sin ninguna fila aparece en los avisos de la previa.';
                }
                field(CodAtributoCuenta; Rec."Cód. Atributo Cuenta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuando la cuenta depende de la persona, como la cuota sindical: el valor del empleado en este atributo se busca como valor de la Dimensión de la cuenta entre las dimensiones por defecto de las cuentas. Si no aparece, va a la cuenta fija del lado.';
                }
                field(DimensionCuenta; Rec."Dimensión Cuenta")
                {
                    ApplicationArea = All;
                    ToolTip = 'La dimensión que identifica la cuenta por el valor del atributo. Para sindicatos es SINDICATOS.';
                }
                field(LadoAtributo; Rec."Lado Atributo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué lado del par sale del atributo.';
                }
                field(Provision; Rec.Provisión)
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco, contabiliza el importe de cada línea. Con provisión, contabiliza cuánto se movió el saldo del empleado en el período: se registra el devengado hasta que se liquida, y ahí se revierte y queda lo liquidado. Debita la Cuenta Debe (el gasto) y acredita la Cuenta Haber (la provisión) cuando sube, y al revés cuando baja.';
                }
                field(ConceptosConsumo; Rec."Conceptos Consumo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Los conceptos que liquidan lo devengado (3553|3573|3973|3975 para vacaciones). En el período en que alguno paga, el devengado acumulado se revierte entero. No se usa en los lotes de francos, que se revierten por los días que consume cada liquidación.';
                }
                field(Descripcion; Rec.Descripción)
                {
                    ApplicationArea = All;
                    ToolTip = 'Para qué es la fila.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Previa)
            {
                ApplicationArea = All;
                Caption = 'Previa del asiento';
                Image = PreviewChecks;
                RunObject = page "Asiento Sueldos Previa";
                ToolTip = 'Arma el asiento de un período con estas reglas, sin escribir el diario.';
            }
            action(Conceptos)
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
                Image = Journals;
                RunObject = page "Conceptos Liquidación";
                ToolTip = 'Abre los conceptos de liquidación.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Previa_Promoted; Previa) { }
            }
        }
    }
}
