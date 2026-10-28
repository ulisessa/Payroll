namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Matriz del asiento de sueldos: a qué cuenta del debe y a qué cuenta del haber va el importe de un
/// concepto, según el tipo de liquidación, el proyecto, una dimensión o un atributo del empleado.
/// </summary>
/// <remarks>
/// CADA FILA BALANCEA SOLA. Un concepto va a un par de cuentas: el básico al gasto contra el neto a
/// pagar, una cuota sindical al neto contra el sindicato, una contribución al gasto de cargas
/// sociales contra el SUSS. Un importe negativo invierte el par. No hace falta un control de balance
/// por concepto, como en la versión de rubros: no hay forma de cargar un concepto que no compense.
///
/// LA FILA MÁS ESPECÍFICA GANA, Y DESPUÉS LA FECHA. Cada combinación de filtros es una variante; de
/// cada una vale la última vigencia a la fecha de la liquidación. Entre las variantes que coinciden,
/// gana la que tiene más filtros cargados (tipo de liquidación, proyecto, dimensión, atributo). Dos
/// que coinciden con la misma cantidad de filtros son un error de carga y la previa lo avisa: no se
/// desempatan solas. Es al revés que los parámetros (ver la lección generica-nueva-pisa-especifica):
/// una cuenta nueva para buques no tiene por qué mover lo que la administración ya tenía resuelto.
///
/// UNA PROVISIÓN NO CONTABILIZA EL IMPORTE DEL CONCEPTO, sino cuánto se movió su saldo en el
/// período. La regla es una sola para el SAC, sus cargas, las vacaciones y los francos (decidida
/// con el usuario el 26/10/2026): se registra el devengado hasta que se liquida; ahí se revierte
/// el devengado y queda lo liquidado. En el SAC y las vacaciones, cualquier pago de un concepto de
/// consumo revierte todo lo devengado desde el pago anterior. En los francos se revierte por lote:
/// los días que se liquidan, al valor del día en que se devengaron. El asiento lleva la diferencia
/// contra el saldo al cierre del período anterior, así que correrlo dos veces da lo mismo, y un
/// período recalculado se corrige solo en el siguiente.
/// </remarks>
table 110067 "Regla Asiento Liq."
{
    Caption = 'Reglas del asiento de sueldos';
    DataClassification = CustomerContent;
    DrillDownPageId = "Reglas Asiento Liq.";
    LookupPageId = "Reglas Asiento Liq.";

    fields
    {
        field(1; "Cód. Concepto"; Code[20])
        {
            Caption = 'Concepto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
            ValidateTableRelation = false;

            trigger OnValidate()
            begin
                ExigirConcepto("Cód. Concepto");
            end;
        }
        field(2; "Filtro Tipo Liq."; Code[80])
        {
            Caption = 'Filtro de tipo de liquidación';
            DataClassification = CustomerContent;
            // Para lo que cambia de cuenta según la liquidación: las contribuciones del aguinaldo van
            // a cargas sociales del SAC y no a las del mes.

            trigger OnValidate()
            begin
                ValidarFiltro("Filtro Tipo Liq.");
            end;
        }
        field(3; "Filtro Proyecto"; Code[100])
        {
            Caption = 'Filtro de proyecto';
            DataClassification = CustomerContent;
            // ES UN FILTRO sobre el proyecto de la liquidación: 'PN-ADM-BAIRES', 'PN-ARB*|PP-ARB*'.
            // Una liquidación sin proyecto sólo encuentra filas sin este filtro.

            trigger OnValidate()
            begin
                ValidarFiltro("Filtro Proyecto");
            end;
        }
        field(4; "Cód. Dimensión Filtro"; Code[20])
        {
            Caption = 'Dimensión del filtro';
            DataClassification = CustomerContent;
            TableRelation = Dimension.Code;
            // El valor se busca entre las dimensiones por defecto del proyecto de la liquidación y,
            // si el proyecto no la tiene, entre las del empleado.
        }
        field(5; "Filtro Valor Dimensión"; Code[60])
        {
            Caption = 'Filtro de valor de dimensión';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                ValidarFiltro("Filtro Valor Dimensión");
            end;
        }
        field(6; "Cód. Atributo Filtro"; Code[20])
        {
            Caption = 'Atributo del filtro';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
            // Un atributo del empleado (CONVENIO, SINDICATO…) o de la marea, vigente a la fecha de
            // los atributos de la liquidación: la misma que usa el motor.

            trigger OnValidate()
            begin
                ExigirAtributoSoportado("Cód. Atributo Filtro");
            end;
        }
        field(7; "Filtro Valor Atributo"; Code[60])
        {
            Caption = 'Filtro de valor de atributo';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                ValidarFiltro("Filtro Valor Atributo");
            end;
        }
        field(8; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(10; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(11; "Cuenta Debe"; Code[20])
        {
            Caption = 'Cuenta Debe';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";
        }
        field(12; "Nombre Cuenta Debe"; Text[100])
        {
            Caption = 'Nombre cuenta Debe';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("G/L Account".Name where("No." = field("Cuenta Debe")));
        }
        field(13; "Cuenta Haber"; Code[20])
        {
            Caption = 'Cuenta Haber';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";
        }
        field(14; "Nombre Cuenta Haber"; Text[100])
        {
            Caption = 'Nombre cuenta Haber';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("G/L Account".Name where("No." = field("Cuenta Haber")));
        }
        field(15; "No Contabiliza"; Boolean)
        {
            Caption = 'No contabiliza';
            DataClassification = CustomerContent;
            // ES UNA DECISIÓN, no un olvido: el concepto está mapeado y su importe no va al asiento
            // (las retenciones sobre el SAC devengado, el anticipo que vive en su propia
            // liquidación). Un concepto con importe y sin ninguna fila sale en los avisos.
        }
        field(16; "Cód. Atributo Cuenta"; Code[20])
        {
            Caption = 'Cuenta según atributo';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
            // CUANDO LA CUENTA DEPENDE DE LA PERSONA, como la cuota sindical: el valor que el
            // empleado tiene en este atributo se busca como valor de la Dimensión Cuenta entre las
            // dimensiones por defecto de las cuentas (SINDICATOS: SOM → 2113012, CAP → 2113008…), la
            // relación que ya usaba la interfaz de Meta4. Si no hay, va a la cuenta fija del lado.

            trigger OnValidate()
            begin
                ExigirAtributoSoportado("Cód. Atributo Cuenta");
            end;
        }
        field(17; "Dimensión Cuenta"; Code[20])
        {
            Caption = 'Dimensión de la cuenta';
            DataClassification = CustomerContent;
            TableRelation = Dimension.Code;
        }
        field(18; "Lado Atributo"; Enum "Lado Asiento Liq.")
        {
            Caption = 'Lado de la cuenta según atributo';
            DataClassification = CustomerContent;
        }
        field(19; Provisión; Option)
        {
            Caption = 'Provisión';
            DataClassification = CustomerContent;
            OptionMembers = " ",Conceptos,Francos;
            OptionCaption = ' ,Devengado hasta liquidar,Lotes de francos';
            // En blanco la fila contabiliza el importe de cada línea. Con provisión, contabiliza la
            // variación del saldo del empleado entre el cierre del período anterior y el de este.
            // Devengado hasta liquidar: lo que el concepto devengó desde el último período en que
            // un Concepto de Consumo pagó algo; ese período lo revierte entero. Lotes de francos:
            // los días que le quedan a cada lote de la cuenta corriente, al valor del día en que se
            // devengó (VALOR_FRANCO_DIA × COEF_PESQUERIA de la liquidación que lo originó).

            trigger OnValidate()
            begin
                PropagarProvision();
            end;
        }
        field(20; "Conceptos Consumo"; Text[250])
        {
            Caption = 'Conceptos que liquidan la provisión';
            DataClassification = CustomerContent;
            // Lista con | (3553|3573|3973|3975). En el período en que alguno paga, el devengado
            // acumulado se revierte y queda lo liquidado: es lo que hacía Meta4 con PROV_SAC en la
            // liquidación del aguinaldo.

            trigger OnValidate()
            begin
                ValidarListaConceptos("Conceptos Consumo");
                PropagarProvision();
            end;
        }
    }

    keys
    {
        key(PK; "Cód. Concepto", "Filtro Tipo Liq.", "Filtro Proyecto", "Cód. Dimensión Filtro", "Filtro Valor Dimensión",
            "Cód. Atributo Filtro", "Filtro Valor Atributo", "Vigencia Desde")
        { Clustered = true; }
    }

    // LA FILA COMPLETA SE EXIGE AL INSERTAR, NO EN CADA CAMBIO. La página inserta al salir de la
    // fila (DelayedInsert), así que ahí ya está todo cargado. Después, cada campo se guarda solo, y
    // los que van de a pares (dimensión y valor, atributo y valor, atributo y dimensión de la
    // cuenta) no se pueden cargar de a uno si cada Modify exige el par: algunos son parte de la
    // clave y el cambio es un Rename. Una fila que quedó incompleta no rompe nada: la previa la
    // saltea y la avisa (Incompleta).
    trigger OnInsert()
    begin
        HeredarProvision();
        ExigirConcepto("Cód. Concepto");
        if Incompleta(MotivoIncompleta) then
            Error(MotivoIncompleta);
        ValidarProvision();
    end;

    trigger OnModify()
    begin
        ExigirConcepto("Cód. Concepto");
        ValidarProvision();
    end;

    trigger OnRename()
    begin
        ExigirConcepto("Cód. Concepto");
        ValidarProvision();
    end;

    /// <summary>
    /// Cuántos ejes acota la fila. Gana la que coincide con más.
    /// </summary>
    procedure Especificidad(): Integer
    var
        Cantidad: Integer;
    begin
        if "Filtro Tipo Liq." <> '' then
            Cantidad += 1;
        if "Filtro Proyecto" <> '' then
            Cantidad += 1;
        if "Cód. Dimensión Filtro" <> '' then
            Cantidad += 1;
        if "Cód. Atributo Filtro" <> '' then
            Cantidad += 1;
        exit(Cantidad);
    end;

    /// <summary>
    /// La combinación de filtros de la fila, sin la fecha: identifica a la variante.
    /// </summary>
    procedure ClaveVariante(): Text
    begin
        exit("Filtro Tipo Liq." + '¦' + "Filtro Proyecto" + '¦' + "Cód. Dimensión Filtro" + '¦' + "Filtro Valor Dimensión" + '¦' +
             "Cód. Atributo Filtro" + '¦' + "Filtro Valor Atributo");
    end;

    /// <summary>
    /// Si a la fila le falta algo para usarse: un par a medio cargar o la cuenta de un lado.
    /// Motivo dice qué, para el error al insertar o el aviso de la previa.
    /// </summary>
    procedure Incompleta(var Motivo: Text): Boolean
    begin
        Motivo := '';
        if ("Cód. Dimensión Filtro" = '') <> ("Filtro Valor Dimensión" = '') then
            Motivo := StrSubstNo(ErrFiltroIncompleto, FieldCaption("Cód. Dimensión Filtro"), FieldCaption("Filtro Valor Dimensión"))
        else
            if ("Cód. Atributo Filtro" = '') <> ("Filtro Valor Atributo" = '') then
                Motivo := StrSubstNo(ErrFiltroIncompleto, FieldCaption("Cód. Atributo Filtro"), FieldCaption("Filtro Valor Atributo"))
            else
                if ("Cód. Atributo Cuenta" = '') <> ("Dimensión Cuenta" = '') then
                    Motivo := ErrAtributoSinDimension
                else
                    if not "No Contabiliza" then begin
                        if ("Cuenta Debe" = '') and not AtributoDelLado("Lado Atributo"::Debe) then
                            Motivo := StrSubstNo(ErrSinCuenta, FieldCaption("Cuenta Debe"), "Cód. Concepto")
                        else
                            if ("Cuenta Haber" = '') and not AtributoDelLado("Lado Atributo"::Haber) then
                                Motivo := StrSubstNo(ErrSinCuenta, FieldCaption("Cuenta Haber"), "Cód. Concepto")
                            else
                                if (Provisión = Provisión::Conceptos) and ("Conceptos Consumo" = '') then
                                    Motivo := StrSubstNo(ErrProvisionSinConsumo, "Cód. Concepto");
                    end;
        exit(Motivo <> '');
    end;

    /// <remarks>
    /// LA PROVISIÓN ES DEL CONCEPTO, NO DE LA FILA. El saldo se calcula una sola vez por empleado;
    /// si una variante dijera otra cosa, el mismo saldo tendría dos definiciones. Por eso un cambio
    /// en una fila se propaga a las demás (PropagarProvision) en vez de rechazarse: rechazarlo
    /// dejaba al concepto trabado, porque la primera fila editada siempre chocaba con las otras.
    /// Y los lotes de francos son una sola cuenta corriente: en dos conceptos se asentaría dos veces.
    /// </remarks>
    local procedure ValidarProvision()
    var
        Otra: Record "Regla Asiento Liq.";
    begin
        Otra.SetRange("Cód. Concepto", "Cód. Concepto");
        Otra.SetFilter(SystemId, '<>%1', SystemId);
        Otra.SetFilter(Provisión, '<>%1', Provisión);
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange(Provisión);
        Otra.SetFilter("Conceptos Consumo", '<>%1', "Conceptos Consumo");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");

        if Provisión = Provisión::Francos then begin
            Otra.Reset();
            Otra.SetFilter("Cód. Concepto", '<>%1', "Cód. Concepto");
            Otra.SetRange(Provisión, Provisión::Francos);
            if Otra.FindFirst() then
                Error(ErrFrancosEnDosConceptos, Otra."Cód. Concepto", "Cód. Concepto");
        end;
    end;

    // Sólo en una fila que ya existe: una nueva todavía no se guardó, y si el usuario la descarta
    // las demás quedarían cambiadas. La nueva hereda al insertarse.
    local procedure PropagarProvision()
    var
        Otra: Record "Regla Asiento Liq.";
    begin
        if IsNullGuid(SystemId) then
            exit;
        Otra.SetRange("Cód. Concepto", "Cód. Concepto");
        Otra.SetFilter(SystemId, '<>%1', SystemId);
        if Otra.IsEmpty() then
            exit;
        Otra.ModifyAll(Provisión, Provisión);
        Otra.ModifyAll("Conceptos Consumo", "Conceptos Consumo");
    end;

    // Una vigencia o una variante nueva de un concepto que ya es provisión nace como sus hermanas:
    // si no, la fila en blanco no se podría guardar.
    local procedure HeredarProvision()
    var
        Otra: Record "Regla Asiento Liq.";
    begin
        if (Provisión <> Provisión::" ") or ("Conceptos Consumo" <> '') then
            exit;
        Otra.SetRange("Cód. Concepto", "Cód. Concepto");
        if Otra.FindFirst() then begin
            Provisión := Otra.Provisión;
            "Conceptos Consumo" := Otra."Conceptos Consumo";
        end;
    end;

    local procedure AtributoDelLado(LadoBuscado: Enum "Lado Asiento Liq."): Boolean
    begin
        exit(("Cód. Atributo Cuenta" <> '') and ("Lado Atributo" = LadoBuscado));
    end;

    local procedure ExigirConcepto(CodConcepto: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if CodConcepto = '' then
            exit;
        Concepto.SetRange(Código, CodConcepto);
        if Concepto.IsEmpty() then
            Error(ErrConceptoInexistente, CodConcepto);
    end;

    local procedure ExigirAtributoSoportado(CodTipoAtributo: Code[20])
    var
        TipoAtributo: Record "Tipo Atributo Liq.";
    begin
        if CodTipoAtributo = '' then
            exit;
        TipoAtributo.Get(CodTipoAtributo);
        if not (TipoAtributo."Tipo Entidad" in [TipoAtributo."Tipo Entidad"::Empleado, TipoAtributo."Tipo Entidad"::Proyecto]) then
            Error(ErrAtributoNoSoportado, CodTipoAtributo, TipoAtributo."Tipo Entidad");
        // El asiento compara y busca cuentas por el código del valor (Cód. Valor), que sólo tienen
        // los atributos de lista. Uno decimal o de texto nunca coincidiría, sin aviso.
        if TipoAtributo."Tipo Dato" <> TipoAtributo."Tipo Dato"::Lista then
            Error(ErrAtributoNoEsLista, CodTipoAtributo, TipoAtributo."Tipo Dato");
    end;

    local procedure ValidarListaConceptos(Lista: Text)
    var
        Codigo: Text;
    begin
        foreach Codigo in Lista.Split('|') do
            if Codigo <> '' then
                ExigirConcepto(CopyStr(Codigo, 1, 20));
    end;

    local procedure ValidarFiltro(Filtro: Text)
    begin
        if Filtro = '' then
            exit;
        if not TryAplicarFiltro(Filtro) then
            Error(ErrFiltroInvalido, Filtro);
    end;

    // El SetFilter revienta con sintaxis inválida; el IsEmpty fuerza que se evalúe al cargar la
    // fila y no recién cuando alguien arma el asiento.
    [TryFunction]
    local procedure TryAplicarFiltro(Filtro: Text)
    var
        Proyecto: Record Job temporary;
    begin
        Proyecto.SetFilter("No.", Filtro);
        if Proyecto.IsEmpty() then;
    end;

    var
        ErrFiltroInvalido: Label 'El filtro "%1" no es válido. Se puede usar un código (PN-ADM-BAIRES), una lista (PN-ADM-BAIRES|PN-ADM-MARDEL) o un comodín (PN-ARB*).', Comment = '%1=filtro';
        ErrFiltroIncompleto: Label '%1 y %2 van juntos: el filtro necesita qué mirar y qué valores acepta.', Comment = '%1 y %2=campos';
        ErrConceptoInexistente: Label 'El concepto %1 no existe.', Comment = '%1=concepto';
        ErrSinCuenta: Label 'Falta la %1 del concepto %2. Si el concepto no va al asiento, marcá No contabiliza.', Comment = '%1=campo, %2=concepto';
        ErrAtributoSinDimension: Label 'La cuenta según atributo necesita las dos cosas: el tipo de atributo y la dimensión que lo identifica en las cuentas.';
        ErrAtributoNoSoportado: Label 'El atributo %1 es de %2. El asiento sólo lee atributos del empleado o de la marea.', Comment = '%1=atributo, %2=tipo de entidad';
        ErrProvisionSinConsumo: Label 'La provisión del concepto %1 necesita los conceptos que la liquidan (los que pagan lo devengado).', Comment = '%1=concepto';
        ErrProvisionDistinta: Label 'Las filas del concepto %1 tienen que coincidir en Provisión y Conceptos que la liquidan: el saldo se calcula una vez por empleado.', Comment = '%1=concepto';
        ErrFrancosEnDosConceptos: Label 'La provisión de lotes de francos ya está en el concepto %1: es una sola cuenta corriente y %2 la asentaría dos veces.', Comment = '%1=concepto existente, %2=concepto nuevo';
        ErrAtributoNoEsLista: Label 'El atributo %1 es de tipo %2. El asiento compara por el código del valor, que sólo tienen los atributos de lista.', Comment = '%1=atributo, %2=tipo de dato';
        MotivoIncompleta: Text;
}
