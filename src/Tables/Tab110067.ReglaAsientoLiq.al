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
/// los días que se liquidan, al valor por día del lote; desde el 28/10/2026, lo que se paga (acuerdo,
/// puesto, 100 %), con sus cargas en una regla aparte (Cargas sobre lotes de francos). El asiento lleva la diferencia
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
            OptionMembers = " ",Conceptos,Francos,"Cargas Francos";
            OptionCaption = ' ,Devengado hasta liquidar,Lotes de francos,Cargas sobre lotes de francos';
            // En blanco la fila contabiliza el importe de cada línea. Con provisión, contabiliza la
            // variación del saldo del empleado entre el cierre del período anterior y el de este.
            // Devengado hasta liquidar: lo que el concepto devengó desde el último período en que
            // un Concepto de Consumo pagó algo; ese período lo revierte entero. Lotes de francos:
            // los días que le quedan a cada lote de la cuenta corriente, a su valor por día (ver
            // Fórmula Valor Franco). Cargas sobre lotes de francos: la variación de cada lote por la
            // tasa de cargas de su liquidación de origen (ver Concepto Tasa Cargas).

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
        field(21; "Fórmula Valor Franco"; Text[250])
        {
            Caption = 'Valor del franco a provisionar';
            DataClassification = CustomerContent;
            // LOTES DE FRANCOS. La fórmula con que Gestión Francos valúa el lote, en vez del
            // "Parámetro del valor" del concepto que paga (el 1063). En blanco, la del 1063. Lo que
            // se paga por un franco de OF02/OF04 es el acuerdo de empresa (el 2083 completa el
            // convenio): IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO). Sus nombres se resuelven igual que
            // los del 1063: por pesquería, convenio y categoría del lote, y en la divisa de la fila.
            //
            // ESTE CAMPO Y LOS DOS SIGUIENTES NO TIENEN VIGENCIA: valen para todo el stock abierto.
            // Cambiarlos revalúa los lotes que ya estaban provisionados y esa diferencia no entra en
            // la variación del mes: tocarlos sólo antes del primer asiento contabilizado, o asentar
            // la revaluación a mano. Un acuerdo personal (VALOR_FRANCO_<legajo>) no gana dentro del
            // IFZERO si no se carga también como VALOR_FRANCO_EMP_<legajo>. Con Precio por Puesto el
            // puesto se valúa sin tipo de liquidación: la fórmula no debe usar TIPO_LIQ.

            trigger OnValidate()
            begin
                PropagarProvision();
            end;
        }
        field(22; "Precio por Puesto"; Boolean)
        {
            Caption = 'Al mayor entre categoría y puesto';
            DataClassification = CustomerContent;
            // LOTES DE FRANCOS. El franco se valúa también con el puesto del lote como categoría y
            // queda el mayor de los dos precios: lo que el 1603 le agrega al 1063 cuando el puesto
            // embarcado paga más que la categoría.

            trigger OnValidate()
            begin
                PropagarProvision();
            end;
        }
        field(23; "Sin Coef Pesquería"; Boolean)
        {
            Caption = 'Sin coeficiente de pesquería';
            DataClassification = CustomerContent;
            // LOTES DE FRANCOS. No multiplica por el COEF_PESQUERIA de la liquidación de origen. El
            // 1063 paga el 30 % en tangoneros, pero el 3554 completa el 70 %: el franco cuesta el 100 %.

            trigger OnValidate()
            begin
                PropagarProvision();
            end;
        }
        field(24; "Concepto Tasa Cargas"; Code[20])
        {
            Caption = 'Concepto de las cargas';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
            ValidateTableRelation = false;
            // CARGAS SOBRE LOTES DE FRANCOS. La tasa de cada liquidación es el importe de este
            // concepto sobre el del Concepto Base Tasa: CNT_SAC_DEV / 4750 es la tasa patronal neta del
            // crédito IVA, con la zona y la condición de jubilado del empleado en esa liquidación.

            trigger OnValidate()
            begin
                ExigirConcepto("Concepto Tasa Cargas");
                PropagarProvision();
            end;
        }
        field(26; "Cuenta Debe Liquidación"; Code[20])
        {
            Caption = 'Cuenta Debe en la liquidación';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";
            // PROVISIONES. La liquidación de una provisión es el devengo al revés: se acredita la
            // Cuenta Debe (el gasto) y se debita la Cuenta Haber (la provisión). Si se carga, la
            // liquidación acredita esta cuenta en vez de la Cuenta Debe; en blanco, la misma. Con las
            // mismas cuentas el gasto del mes queda en lo devengado: el pago del recibo entra al
            // gasto y la liquidación lo compensa, cada uno en su línea. Se toma de la regla vigente
            // al cierre del período que liquida, no de la vigencia del devengo.
        }
        field(27; "Cuenta Haber Liquidación"; Code[20])
        {
            Caption = 'Cuenta Haber en la liquidación';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";
            // PROVISIONES. La cuenta que se debita en la liquidación en vez de la Cuenta Haber (la
            // provisión). En blanco, la misma. Si es otra, la provisión de la Cuenta Haber deja de
            // cancelarse sola: hay que conciliarla.
        }
        field(25; "Concepto Base Tasa"; Code[20])
        {
            Caption = 'Base de la tasa de cargas';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
            ValidateTableRelation = false;

            trigger OnValidate()
            begin
                ExigirConcepto("Concepto Base Tasa");
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
                                    Motivo := StrSubstNo(ErrProvisionSinConsumo, "Cód. Concepto")
                                else
                                    if (Provisión = Provisión::"Cargas Francos") and
                                       (("Concepto Tasa Cargas" = '') or ("Concepto Base Tasa" = ''))
                                    then
                                        Motivo := StrSubstNo(ErrCargasSinTasa, "Cód. Concepto");
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
        // Se mira al guardar y no al tipear: una fila nueva hereda la provisión recién al insertarse.
        // Una cuenta de liquidación en una fila que no provisiona no se usaría nunca, sin aviso.
        if (Provisión = Provisión::" ") and (("Cuenta Debe Liquidación" <> '') or ("Cuenta Haber Liquidación" <> '')) then
            Error(ErrLiquidacionSinProvision, "Cód. Concepto");

        Otra.SetRange("Cód. Concepto", "Cód. Concepto");
        Otra.SetFilter(SystemId, '<>%1', SystemId);
        Otra.SetFilter(Provisión, '<>%1', Provisión);
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange(Provisión);
        Otra.SetFilter("Conceptos Consumo", '<>%1', "Conceptos Consumo");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        // Los campos de la definición de francos y de sus cargas, uno por vez: un filtro por campo
        // dentro del mismo SetFilter exigiría que difieran todos juntos.
        Otra.SetRange("Conceptos Consumo");
        Otra.SetFilter("Fórmula Valor Franco", '<>%1', "Fórmula Valor Franco");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange("Fórmula Valor Franco");
        Otra.SetFilter("Precio por Puesto", '<>%1', "Precio por Puesto");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange("Precio por Puesto");
        Otra.SetFilter("Sin Coef Pesquería", '<>%1', "Sin Coef Pesquería");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange("Sin Coef Pesquería");
        Otra.SetFilter("Concepto Tasa Cargas", '<>%1', "Concepto Tasa Cargas");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");
        Otra.SetRange("Concepto Tasa Cargas");
        Otra.SetFilter("Concepto Base Tasa", '<>%1', "Concepto Base Tasa");
        if not Otra.IsEmpty() then
            Error(ErrProvisionDistinta, "Cód. Concepto");

        if Provisión in [Provisión::Francos, Provisión::"Cargas Francos"] then begin
            Otra.Reset();
            Otra.SetFilter("Cód. Concepto", '<>%1', "Cód. Concepto");
            Otra.SetRange(Provisión, Provisión);
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
        Otra.ModifyAll("Fórmula Valor Franco", "Fórmula Valor Franco");
        Otra.ModifyAll("Precio por Puesto", "Precio por Puesto");
        Otra.ModifyAll("Sin Coef Pesquería", "Sin Coef Pesquería");
        Otra.ModifyAll("Concepto Tasa Cargas", "Concepto Tasa Cargas");
        Otra.ModifyAll("Concepto Base Tasa", "Concepto Base Tasa");
    end;

    // Una vigencia o una variante nueva de un concepto que ya es provisión nace como sus hermanas:
    // si no, la fila en blanco no se podría guardar. Se completa campo por campo lo que la fila
    // nueva trae vacío, también si ya eligió la misma provisión: ValidarProvision exige igualdad,
    // así que un valor distinto del de las hermanas nunca se podría guardar.
    local procedure HeredarProvision()
    var
        Otra: Record "Regla Asiento Liq.";
    begin
        Otra.SetRange("Cód. Concepto", "Cód. Concepto");
        if not Otra.FindFirst() then
            exit;
        if (Provisión <> Provisión::" ") and (Provisión <> Otra.Provisión) then
            exit;
        Provisión := Otra.Provisión;
        if "Conceptos Consumo" = '' then
            "Conceptos Consumo" := Otra."Conceptos Consumo";
        if "Fórmula Valor Franco" = '' then
            "Fórmula Valor Franco" := Otra."Fórmula Valor Franco";
        if not "Precio por Puesto" then
            "Precio por Puesto" := Otra."Precio por Puesto";
        if not "Sin Coef Pesquería" then
            "Sin Coef Pesquería" := Otra."Sin Coef Pesquería";
        if "Concepto Tasa Cargas" = '' then
            "Concepto Tasa Cargas" := Otra."Concepto Tasa Cargas";
        if "Concepto Base Tasa" = '' then
            "Concepto Base Tasa" := Otra."Concepto Base Tasa";
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
        ErrProvisionDistinta: Label 'Las filas del concepto %1 tienen que coincidir en Provisión, Conceptos que la liquidan, valor del franco y tasa de cargas: el saldo se calcula una vez por empleado.', Comment = '%1=concepto';
        ErrFrancosEnDosConceptos: Label 'La provisión de lotes de francos (o de sus cargas) ya está en el concepto %1: es una sola cuenta corriente y %2 la asentaría dos veces.', Comment = '%1=concepto existente, %2=concepto nuevo';
        ErrLiquidacionSinProvision: Label 'Las cuentas de la liquidación son de las provisiones, y la regla del concepto %1 no provisiona: no se usarían nunca.', Comment = '%1=concepto';
        ErrCargasSinTasa: Label 'Las cargas sobre lotes de francos del concepto %1 necesitan de qué concepto sale la tasa y sobre qué base (por ejemplo CNT_SAC_DEV sobre 4750).', Comment = '%1=concepto';
        ErrAtributoNoEsLista: Label 'El atributo %1 es de tipo %2. El asiento compara por el código del valor, que sólo tienen los atributos de lista.', Comment = '%1=atributo, %2=tipo de dato';
        MotivoIncompleta: Text;
}
