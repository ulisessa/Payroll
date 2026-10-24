namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Finance.Currency;

table 60008 "Parámetro Vigente"
{
    Caption = 'Parámetro Vigente';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Parámetro"; Code[50])
        {
            Caption = 'Clave Derivada';
            NotBlank = true;
            DataClassification = CustomerContent;
            Editable = false;
            // Se calcula SIEMPRE a partir del código base y de los campos que la fila tenga
            // completos (ver RecalcularClave). Antes se tipeaba a mano en unos casos y se derivaba
            // en otros según qué bandera de sufijo tuviera el parámetro; eso obligaba a habilitar y
            // deshabilitar columnas y a migrar las claves cada vez que la bandera cambiaba.
            //
            // Sin TableRelation: las claves derivadas (BASICO_175/75_CAPITAN) no existen como
            // registros de Parámetro. La integridad la sostiene Parámetro.OnDelete.
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción Versión';
            DataClassification = CustomerContent;
        }
        field(4; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
        }
        field(5; Moneda; Code[10])
        {
            Caption = 'Moneda';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(14; "Cód. Variable TC"; Code[60])
        {
            Caption = 'Variable Tipo de Cambio';
            DataClassification = CustomerContent;
            // Qué variable convierte ESTE valor a pesos. Acompaña a Moneda y por eso vive en la misma
            // fila: tener la moneda en un lado y su tipo de cambio en otro es de las cosas que seis
            // meses después nadie entiende.
            //
            // POR FILA Y NO POR PARÁMETRO, a propósito. Queda por alcance —USD_MAREA_04724 puede ir
            // al vendedor y USD_MAREA_768/19_OF03 al comprador, porque son filas distintas— y por
            // vigencia, así que un cambio de convención se expresa con una fila nueva en vez de
            // reescribir la anterior.
            //
            // El motor TODAVÍA NO LA LEE. Hoy convierte el neto del grossing-up con el vendedor
            // cableado (Cod50014, TipoCambioVendedor), que es correcto para los cuatro de tierra y no
            // para todos: la producción va al comprador. El plan para encenderla, con sus seis pasos
            // y qué verificar en cada uno, está en GROSSING_UP_Y_TC_CONFIGURABLES.md.
            //
            // Sin TableRelation que valide: hoy los dos candidatos —TC_COMPRADOR y TC_VENDEDOR— son
            // Fuentes de Datos, pero el TC de una marea NO es una cotización sino un valor acordado,
            // y ese caso puede resolverse por otra vía. El lookup ayuda a cargar; no acota.
            TableRelation = "Fuente Datos Liquidación"."Nombre Variable";
            ValidateTableRelation = false;
        }
        field(6; "En Uso"; Boolean)
        {
            Caption = 'En Uso';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(8; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";

            trigger OnValidate()
            begin
                // El empleado es el eje más específico y no se combina con los otros: cargarlo
                // limpia convenio y categoría en vez de armar una clave que nadie va a buscar.
                if "No. Empleado" <> '' then begin
                    "Cód. Convenio" := '';
                    "Cód. Categoría" := '';
                end;
                RecalcularClave();
            end;
        }
        field(10; "Cód. Parámetro Base"; Code[20])
        {
            Caption = 'Cód. Parámetro Base';
            DataClassification = CustomerContent;
            TableRelation = "Parámetro";

            trigger OnValidate()
            begin
                RecalcularClave();
            end;
        }
        field(11; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;

            trigger OnValidate()
            begin
                if "Cód. Convenio" = '' then
                    "Cód. Categoría" := '';
                if "Cód. Convenio" <> '' then
                    "No. Empleado" := '';
                RecalcularClave();
            end;
        }
        field(12; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));

            trigger OnValidate()
            begin
                if ("Cód. Categoría" <> '') and ("Cód. Convenio" = '') then
                    Error(ErrCategoriaSinConvenio);
                RecalcularClave();
            end;
        }
        field(13; Nivel; Integer)
        {
            Caption = 'Nivel';
            DataClassification = CustomerContent;
            Editable = false;
            // 0 base, 1 convenio o empleado, 2 convenio + categoría. Es la columna de indentación
            // del árbol de parámetros: se calcula junto con la clave y no se carga a mano.
            //
            // Los ejes NO suben el nivel: _CAL y _LAN del mismo convenio son hermanos, no uno hijo
            // del otro. Ver Claves Parámetro Liq..NivelDeFila.
        }
        // Los tres ejes de atributo. Qué TIPO de atributo es cada uno lo declara el Parámetro —la
        // cabecera—, y acá va el SUFIJO que ese atributo aporta a la clave.
        //
        // POR QUÉ EL SUFIJO Y NO EL CÓDIGO DEL VALOR. Varios valores de un mismo tipo pueden aportar
        // el mismo segmento: `TA` Tangonero y `ML` Arrastrero/Merlucero tienen los dos
        // `Sufijo Parámetro = LAN`, así que una sola fila `_LAN` sirve a los dos. Guardando el código
        // del valor habría que cargar una fila por valor, y la que faltara daría cero sin aviso —es
        // exactamente lo que dejó al Puente Mayor sin precio de franco el 6/10/2026—.
        //
        // LA TableRelation SÍ SE PUEDE, Y ESTÁ PUESTA. El obstáculo aparente es que el TIPO del eje
        // vive en la cabecera y el `where` de una TableRelation sólo ve campos de la propia tabla; lo
        // resuelve un FlowField de lookup —los tres de abajo— que lo trae de "Parámetro". Compilado y
        // verificado el 9/10/2026.
        //
        // PERO EL LOOKUP NATIVO NO ALCANZA, y por eso la página igual define su OnLookup: como el
        // sufijo no es único —`TA` y `ML` dan los dos LAN—, la lista de la plataforma muestra "LAN"
        // DOS VECES, una por cada valor. El OnLookup de "Parámetro Sufijo Sub" ofrece en cambio los
        // tres valores con su descripción —Potero, Tangonero, Arrastrero/Merlucero— y guarda el
        // sufijo del que se elija: el usuario elige un concepto del negocio, no una convención.
        //
        // Y LA RELACIÓN NO REEMPLAZA A ValidarSufijoEje: no sabe nada de la DENSIDAD de la lista —el
        // eje 2 cargado con el 1 vacío—, que es el modo de falla silencioso y el que de verdad
        // importa. La relación es la red; el OnValidate es el control.
        field(15; "Sufijo Atributo 1"; Code[10])
        {
            Caption = 'Sufijo Atributo 1';
            DataClassification = CustomerContent;
            TableRelation = "Valor Atributo Liq."."Sufijo Parámetro"
                WHERE("Cód. Tipo Atributo" = FIELD("Tipo Atr. Eje 1"), "Sufijo Parámetro" = FILTER(<> ''));

            trigger OnValidate()
            begin
                ValidarSufijoEje(1, "Sufijo Atributo 1");
                RecalcularClave();
            end;
        }
        field(16; "Sufijo Atributo 2"; Code[10])
        {
            Caption = 'Sufijo Atributo 2';
            DataClassification = CustomerContent;
            TableRelation = "Valor Atributo Liq."."Sufijo Parámetro"
                WHERE("Cód. Tipo Atributo" = FIELD("Tipo Atr. Eje 2"), "Sufijo Parámetro" = FILTER(<> ''));

            trigger OnValidate()
            begin
                ValidarSufijoEje(2, "Sufijo Atributo 2");
                RecalcularClave();
            end;
        }
        field(17; "Sufijo Atributo 3"; Code[10])
        {
            Caption = 'Sufijo Atributo 3';
            DataClassification = CustomerContent;
            TableRelation = "Valor Atributo Liq."."Sufijo Parámetro"
                WHERE("Cód. Tipo Atributo" = FIELD("Tipo Atr. Eje 3"), "Sufijo Parámetro" = FILTER(<> ''));

            trigger OnValidate()
            begin
                ValidarSufijoEje(3, "Sufijo Atributo 3");
                RecalcularClave();
            end;
        }
        // Los tipos declarados en la cabecera, traídos acá para que la TableRelation de arriba pueda
        // filtrar por ellos. No se muestran en ninguna página: existen sólo para eso.
        field(18; "Tipo Atr. Eje 1"; Code[20])
        {
            Caption = 'Tipo de Atributo del eje 1';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = lookup("Parámetro"."Cód. Tipo Atributo 1" where(Código = field("Cód. Parámetro Base")));
        }
        field(19; "Tipo Atr. Eje 2"; Code[20])
        {
            Caption = 'Tipo de Atributo del eje 2';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = lookup("Parámetro"."Cód. Tipo Atributo 2" where(Código = field("Cód. Parámetro Base")));
        }
        field(20; "Tipo Atr. Eje 3"; Code[20])
        {
            Caption = 'Tipo de Atributo del eje 3';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = lookup("Parámetro"."Cód. Tipo Atributo 3" where(Código = field("Cód. Parámetro Base")));
        }
    }

    keys
    {
        key(PK; "Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde")
        {
            Clustered = true;
        }
        key(Codigo; "Cód. Parámetro", "Vigencia Desde") { }
    }

    trigger OnInsert()
    begin
        if "Cód. Parámetro Base" = '' then
            "Cód. Parámetro Base" := DeriveBase("Cód. Parámetro");
        RecalcularClave();
        // Alta: la fila todavía no existe, así que no hay nada que excluir.
        ValidarClaveLibre('', '', 0D);
    end;

    /// <summary>
    /// Recalcula la clave derivada y el nivel a partir de los campos completos.
    /// </summary>
    procedure RecalcularClave()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        if "Cód. Parámetro Base" = '' then
            exit;
        "Cód. Parámetro" := Claves.ArmarDeFila(Rec);
        Nivel := Claves.NivelDeFila(Rec);
    end;

    /// <summary>
    /// El Tipo de Atributo que la cabecera declara para el eje N, o vacío si no declara ninguno.
    /// </summary>
    procedure TipoAtributoDeclarado(Indice: Integer): Code[20]
    var
        Param: Record "Parámetro";
    begin
        if "Cód. Parámetro Base" = '' then
            exit('');
        if not Param.Get("Cód. Parámetro Base") then
            exit('');
        case Indice of
            1:
                exit(Param."Cód. Tipo Atributo 1");
            2:
                exit(Param."Cód. Tipo Atributo 2");
            3:
                exit(Param."Cód. Tipo Atributo 3");
        end;
    end;

    local procedure SufijoEje(Indice: Integer): Code[10]
    begin
        case Indice of
            1:
                exit("Sufijo Atributo 1");
            2:
                exit("Sufijo Atributo 2");
            3:
                exit("Sufijo Atributo 3");
        end;
    end;

    /// <summary>
    /// Valida un sufijo de eje contra el tipo que declara la cabecera, y la densidad de la lista.
    /// </summary>
    /// <remarks>
    /// LOS EJES NO PUEDEN TENER HUECOS. La clave los concatena en orden salteando los vacíos, así que
    /// una fila con el eje 2 cargado y el 1 vacío derivaría la misma clave que una con sólo el eje 1
    /// —el sufijo ocupa la primera posición igual—, y las dos se pisarían. Peor: la cascada arma sus
    /// candidatas desde los ejes DECLARADOS en orden, así que el valor quedaría inalcanzable sin un
    /// solo error. Corta acá.
    /// </remarks>
    local procedure ValidarSufijoEje(Indice: Integer; Sufijo: Code[10])
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        CodTipo: Code[20];
        Validos: List of [Code[10]];
        i: Integer;
    begin
        if Sufijo = '' then begin
            // Al vaciar un eje, no puede quedar uno posterior cargado.
            for i := Indice + 1 to 3 do
                if SufijoEje(i) <> '' then
                    Error(ErrEjeConHueco, i, Indice);
            exit;
        end;

        CodTipo := TipoAtributoDeclarado(Indice);
        if CodTipo = '' then
            Error(ErrEjeSinTipo, Indice, "Cód. Parámetro Base");

        // Y los anteriores tienen que estar cargados: la lista se lee como prefijo.
        for i := 1 to Indice - 1 do
            if SufijoEje(i) = '' then
                Error(ErrEjeConHueco, Indice, i);

        Validos := Claves.SufijosDelTipo(CodTipo);
        if Validos.Count() = 0 then
            Error(ErrTipoSinSufijos, CodTipo);
        if not Validos.Contains(Sufijo) then
            Error(ErrSufijoDesconocido, Sufijo, CodTipo, FormatearLista(Validos));
    end;

    local procedure FormatearLista(var Lista: List of [Code[10]]) Texto: Text
    var
        Item: Code[10];
    begin
        foreach Item in Lista do begin
            if Texto <> '' then
                Texto += ', ';
            Texto += Item;
        end;
    end;

    /// <summary>
    /// Corta si otra fila ya responde por la misma clave derivada en la misma vigencia.
    /// </summary>
    /// <remarks>
    /// La clave derivada identifica el valor que va a buscar el motor. Dos filas con la misma clave
    /// y la misma vigencia son dos respuestas para la misma pregunta, y la clave primaria las
    /// admitiría solo si difieren en el código base — que es justo el caso confuso.
    ///
    /// Los tres parámetros son la clave primaria de la fila que se está editando, para que no se
    /// detecte a sí misma. En un alta llegan vacíos y no excluyen nada.
    ///
    /// Se recorre en vez de usar IsEmpty() porque hay que mirar la PK de cada candidato: la fila
    /// propia y una duplicada real comparten el filtro, y solo se distinguen por el código base.
    /// </remarks>
    local procedure ValidarClaveLibre(BasePropia: Code[20]; ParamPropio: Code[50]; VigPropia: Date)
    var
        Existente: Record "Parámetro Vigente";
    begin
        Existente.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        Existente.SetRange("Cód. Parámetro", "Cód. Parámetro");
        Existente.SetRange("Vigencia Desde", "Vigencia Desde");
        if Existente.FindSet() then
            repeat
                if not ((Existente."Cód. Parámetro Base" = BasePropia) and
                        (Existente."Cód. Parámetro" = ParamPropio) and
                        (Existente."Vigencia Desde" = VigPropia))
                then
                    Error(ErrClaveDuplicada, "Cód. Parámetro", "Vigencia Desde");
            until Existente.Next() = 0;
    end;

    trigger OnModify()
    begin
        // La clave derivada se rearma en los OnValidate de empleado, convenio, categoría y vigencia
        // (ver RecalcularClave). Sin este control, modificar cualquiera de esos campos podía dejar
        // dos filas respondiendo por la misma clave: la validación vivía solo en el alta.
        //
        // Acá la PK no pudo cambiar —si cambia, BC va por OnRename, no por acá—, así que la fila
        // propia se excluye con su propia clave y no hace falta xRec.
        ValidarClaveLibre("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");

        if xRec."En Uso" and "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else begin
                "En Uso" := false;
                xRec."En Uso" := false;
            end;
    end;

    // "Cód. Parámetro" es parte de la clave primaria, así que cuando RecalcularClave lo cambia la
    // página no guarda con Modify sino con Rename, y el control de OnModify no llega a correr.
    // Acá la fila propia se excluye con su clave ANTERIOR, que es la que todavía está en la base.
    trigger OnRename()
    begin
        ValidarClaveLibre(xRec."Cód. Parámetro Base", xRec."Cód. Parámetro", xRec."Vigencia Desde");
    end;

    trigger OnDelete()
    begin
        if "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else
                "En Uso" := false;
    end;

    local procedure HayLiquidacionesBloqueantes(): Boolean
    var
        Liq: Record "Liquidación";
    begin
        if "No. Empleado" <> '' then
            Liq.SetRange("No. Empleado", "No. Empleado");
        Liq.SetFilter(Estado, '%1|%2|%3',
            Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        exit(not Liq.IsEmpty());
    end;

    local procedure DeriveBase(CodParam: Code[50]): Code[20]
    var
        Param: Record "Parámetro";
        BestCode: Code[20];
        BestLen: Integer;
        CodParamTxt: Text;
    begin
        CodParamTxt := CodParam;
        if Param.FindSet() then
            repeat
                if (StrLen(Param.Código) > BestLen) and
                   ((CodParam = Param.Código) or
                    CodParamTxt.StartsWith(Param.Código + '_'))
                then begin
                    BestCode := Param.Código;
                    BestLen := StrLen(Param.Código);
                end;
            until Param.Next() = 0;
        exit(BestCode);
    end;

    var
        ErrEnUso: Label 'No se puede modificar ni eliminar un parámetro que ya fue utilizado en una liquidación registrada.';
        ErrClaveDuplicada: Label 'Ya existe un valor con la clave %1 y vigencia %2. Cambiá el convenio, la categoría o el empleado, o modificá la fila existente.';
        ErrCategoriaSinConvenio: Label 'La categoría se carga junto con el convenio: primero indicá el convenio.';
        ErrEjeConHueco: Label 'El eje %1 no puede quedar cargado con el eje %2 vacío: los ejes se cargan en orden y sin huecos. Con un hueco, el valor deriva la misma clave que otra fila y el cálculo no lo alcanza.', Comment = '%1 = índice del eje cargado; %2 = índice del eje vacío';
        ErrEjeSinTipo: Label 'El parámetro %2 no declara un Tipo de Atributo para el eje %1. Cargalo primero en la ficha del parámetro.', Comment = '%1 = índice del eje; %2 = código del parámetro base';
        ErrTipoSinSufijos: Label 'Ningún valor del atributo %1 tiene cargado un "Sufijo Parámetro", así que no puede usarse como eje. Cargá el sufijo en los valores que correspondan.', Comment = '%1 = código del tipo de atributo';
        ErrSufijoDesconocido: Label 'El sufijo %1 no corresponde a ningún valor del atributo %2. Los válidos son: %3.', Comment = '%1 = sufijo tipeado; %2 = tipo de atributo; %3 = lista de sufijos válidos';
}
