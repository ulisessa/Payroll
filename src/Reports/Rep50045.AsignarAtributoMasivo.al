namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Projects.Project.Job;

// Asigna un mismo atributo a muchas entidades de una vez: "todos los de este convenio pasan a zona
// Patagonia desde el 1/9", "todos los buques de la flota sur toman este coeficiente".
//
// Los tres dataitems conviven porque la entidad puede ser un empleado, un valor de dimensión o un
// proyecto, y cada uno se filtra con sus propios campos. Solo corre el que coincide con el tipo
// elegido; los otros dos se cortan en OnPreDataItem.
report 50045 "Asignar Atributo Masivo"
{
    ApplicationArea = All;
    Caption = 'Asignar Atributo Masivo';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Empleado; Employee)
        {
            RequestFilterFields = "No.", Status;

            trigger OnPreDataItem()
            begin
                if TipoEntidad <> TipoEntidad::Empleado then
                    CurrReport.Break();
                Preparar();
            end;

            trigger OnAfterGetRecord()
            begin
                Procesar(Empleado."No.", Empleado."No." + ' · ' + Empleado."First Name" + ' ' + Empleado."Last Name");
            end;

            trigger OnPostDataItem()
            begin
                Terminar();
            end;
        }

        // Itera entidades y no valores de dimensión: la entidad ya está acotada a la dimensión que
        // corresponde y trae su clase, así que el filtro por clase sale solo y no hace falta
        // recortar por Dimension Code ni por tipo de valor.
        dataitem(EntidadOper; "Entidad Liq.")
        {
            RequestFilterFields = Código, "Cód. Clase";

            trigger OnPreDataItem()
            begin
                if TipoEntidad <> TipoEntidad::Buque then
                    CurrReport.Break();
                Preparar();
            end;

            trigger OnAfterGetRecord()
            begin
                Procesar(EntidadOper.Código, EntidadOper.Código + ' · ' + EntidadOper.Descripción);
            end;

            trigger OnPostDataItem()
            begin
                Terminar();
            end;
        }

        dataitem(Proyecto; Job)
        {
            RequestFilterFields = "No.", "Global Dimension 1 Code";

            trigger OnPreDataItem()
            begin
                if TipoEntidad <> TipoEntidad::Proyecto then
                    CurrReport.Break();
                Preparar();
            end;

            trigger OnAfterGetRecord()
            begin
                Procesar(Proyecto."No.", Proyecto."No." + ' · ' + Proyecto.Description);
            end;

            trigger OnPostDataItem()
            begin
                Terminar();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Que)
                {
                    Caption = 'Qué asignar';

                    field(TipoEntidadFld; TipoEntidad)
                    {
                        ApplicationArea = All;
                        Caption = 'Tipo de entidad';
                        ToolTip = 'A qué maestro pertenecen las entidades que van a recibir el atributo. Los filtros de abajo cambian según esta elección.';
                    }
                    field(CodTipoAtributoFld; CodTipoAtributo)
                    {
                        ApplicationArea = All;
                        Caption = 'Atributo';
                        TableRelation = "Tipo Atributo Liq.".Código;
                        ToolTip = 'Atributo a asignar. Su tipo de dato define en cuál de los campos de valor hay que cargar.';

                        trigger OnValidate()
                        begin
                            LeerTipoDato();
                            LimpiarValor();
                        end;
                    }
                    field(TipoDatoFld; Format(TipoDato))
                    {
                        ApplicationArea = All;
                        Caption = 'Tipo de dato';
                        Editable = false;
                    }
                }
                group(Valor)
                {
                    Caption = 'Valor';

                    // UN campo para los cuatro tipos, y no uno por tipo con Visible: en una request
                    // page el Visible se evalúa AL ABRIR y no vuelve a evaluarse. Elegir el atributo
                    // cambiaba las banderas pero no los controles, así que con un atributo de lista
                    // seguías viendo el campo numérico del tipo por defecto y no había forma de
                    // cargar el valor. Con un solo campo no hay nada que mostrar ni que ocultar: se
                    // interpreta contra el tipo de dato al validar, y el lookup se adapta.
                    field(ValorFld; ValorEntrada)
                    {
                        ApplicationArea = All;
                        Caption = 'Valor';
                        ToolTip = 'El valor a asignar. Si el atributo es de lista, se elige con el botón de búsqueda; si es numérico, fecha o texto, se escribe y se verifica el formato al confirmar.';

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            ValorAtr: Record "Valor Atributo Liq.";
                        begin
                            if CodTipoAtributo = '' then
                                Error(ErrFaltaAtributo);
                            if TipoDato <> TipoDato::Lista then
                                exit(false);
                            // Sin filtrar por valor padre: en una asignación masiva cada entidad
                            // resuelve el suyo. Elegís "OF01" y cada empleado recibe la OF01 de su
                            // propio convenio.
                            //
                            // La página va nombrada y NO con Page.RunModal(0, ...): el 0 significa
                            // "el lookup por defecto de la tabla", y desde una request page la
                            // plataforma no lo resuelve — intenta abrir literalmente la página 0 y
                            // corta con "no existe ningún objeto con ese id".
                            ValorAtr.FilterGroup(4);
                            ValorAtr.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
                            ValorAtr.FilterGroup(0);
                            if Page.RunModal(Page::"Valores de Atributo", ValorAtr) <> Action::LookupOK then
                                exit(false);
                            Text := ValorAtr.Código;
                            exit(true);
                        end;

                        trigger OnValidate()
                        begin
                            InterpretarValor();
                        end;
                    }
                    field(VigenciaDesdeFld; VigenciaDesde)
                    {
                        ApplicationArea = All;
                        Caption = 'Vigencia desde';
                        ToolTip = 'Fecha desde la que rige el valor. La vigencia anterior de cada entidad se cierra sola el día previo, si estaba abierta.';
                    }
                }
                group(Existentes)
                {
                    Caption = 'Si la entidad ya tiene el atributo';

                    field(ModoFld; Modo)
                    {
                        ApplicationArea = All;
                        Caption = 'Acción';
                        OptionCaption = 'Crear una vigencia nueva,Omitir la entidad';
                        ToolTip = 'Crear una vigencia nueva cierra la anterior el día previo y conserva el historial. Omitir sirve para completar solo las entidades que todavía no lo tienen.';
                    }
                }
            }
        }

        trigger OnOpenPage()
        begin
            if VigenciaDesde = 0D then
                VigenciaDesde := WorkDate();
            LeerTipoDato();
        end;
    }

    // ── Proceso ───────────────────────────────────────────────────────────────

    local procedure Preparar()
    begin
        if CodTipoAtributo = '' then
            Error(ErrFaltaAtributo);
        if VigenciaDesde = 0D then
            Error(ErrFaltaFecha);
        LeerTipoDato();
        if TipoDato = TipoDato::Lista then begin
            if CodValor = '' then
                Error(ErrFaltaValorLista);
            // Se verifica acá y no solo en el lookup: el código se puede tipear a mano, y un valor
            // de otro atributo daría Valor Numérico 0 en cada entidad, en silencio.
            //
            // Por código y no con Get: desde que los atributos se pueden encadenar, la clave lleva el
            // valor padre en el medio y el mismo código puede existir bajo varios padres —OF01 en dos
            // convenios—. Acá alcanza con saber que el código es de este atributo; de qué padre cuelga
            // en cada entidad lo resuelve la tabla al insertar, contra el padre vigente de esa entidad.
            // (Un Get de dos argumentos, además, hoy compilaría igual y compararía el código contra el
            // campo equivocado.)
            ValorAtrChk.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
            ValorAtrChk.SetRange(Código, CodValor);
            if ValorAtrChk.IsEmpty() then
                Error(ErrValorAjeno, CodValor, CodTipoAtributo);
        end;

        Progreso.Open(TxtProgreso);
        Corrio := true;
    end;

    /// <remarks>
    /// La bandera no es defensiva de más: `CurrReport.Break()` en el OnPreDataItem saltea el BUCLE
    /// del dataitem pero NO su OnPostDataItem, así que los dos dataitems descartados llegan igual
    /// hasta acá. Sin la guarda, el primero de ellos moría con "la operación no se completó porque
    /// el cuadro de diálogo no está abierto" —cerrando un progreso que nunca abrió— justo después
    /// de que el dataitem bueno hubiera terminado su trabajo.
    /// </remarks>
    local procedure Terminar()
    begin
        if not Corrio then
            exit;
        Corrio := false;
        Progreso.Close();
        Message(MsgResultado, Asignados, Omitidos, Vistos);
    end;

    local procedure Procesar(CodEntidad: Code[20]; Descripcion: Text)
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Vistos += 1;
        Progreso.Update(1, CopyStr(Descripcion, 1, 60));
        Progreso.Update(2, Asignados);

        Atributo.SetRange("Tipo Entidad", TipoEntidad);
        Atributo.SetRange("Cód. Entidad", CodEntidad);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtributo);

        if (Modo = Modo::Omitir) and not Atributo.IsEmpty() then begin
            Omitidos += 1;
            exit;
        end;

        // Una fila con la MISMA vigencia se omite siempre, en cualquiera de los dos modos: podría
        // tener un valor ya usado en una liquidación, y sobrescribirlo en un proceso masivo es
        // exactamente la clase de cambio que después nadie puede explicar.
        Atributo.SetRange("Vigencia Desde", VigenciaDesde);
        if not Atributo.IsEmpty() then begin
            Omitidos += 1;
            exit;
        end;

        if not Insertar(CodEntidad) then begin
            Omitidos += 1;
            exit;
        end;
        Asignados += 1;
    end;

    /// <summary>
    /// Da de alta la fila en su propia transacción. Devuelve false si el alta falló, para que la
    /// entidad se cuente como omitida y el lote siga.
    /// </summary>
    /// <remarks>
    /// Vía Codeunit.Run y NO con [TryFunction], que es como estaba: un TryFunction no puede escribir
    /// en la base, y acá todo es escritura. El síntoma engaña, porque la PRIMERA entidad se asignaba
    /// bien —la transacción todavía no tenía escrituras— y recién la segunda cortaba el informe
    /// entero con "no se permite INSERT dentro de Empleado - OnAfterGetRecord".
    ///
    /// El Commit va antes de CADA Run y no solo de la primera: la plataforma únicamente deja leer el
    /// valor de retorno del Run cuando no hay escrituras pendientes, y en un lote la vuelta anterior
    /// siempre dejó alguna. No cambia la semántica —cada entidad ya era su propia unidad de trabajo—
    /// y lo que se confirma es exactamente lo que el contador ya dio por asignado.
    ///
    /// Un solo Insert con la fila completa, en vez del Insert + Validate + Modify anterior: el
    /// OnInsert de la tabla resuelve el valor padre vigente a esa fecha, verifica que el valor exista
    /// colgando de él y congela el Valor Numérico, que es lo único que después lee la Fuente de
    /// Datos. El control de tipo ya corrió al cargar el valor en la request page.
    /// </remarks>
    local procedure Insertar(CodEntidad: Code[20]): Boolean
    var
        Nuevo: Record "Atributo Entidad Liq.";
    begin
        Clear(Nuevo);
        Nuevo."Tipo Entidad" := TipoEntidad;
        Nuevo."Cód. Entidad" := CodEntidad;
        Nuevo."Cód. Tipo Atributo" := CodTipoAtributo;
        Nuevo."Vigencia Desde" := VigenciaDesde;
        case TipoDato of
            TipoDato::Lista:
                Nuevo."Cód. Valor" := CodValor;
            TipoDato::Decimal, TipoDato::Entero:
                Nuevo."Valor Decimal" := ValorDecimal;
            TipoDato::Texto:
                Nuevo."Valor Texto" := ValorTexto;
            TipoDato::Fecha:
                Nuevo."Valor Fecha" := ValorFecha;
        end;

        Commit();
        exit(FAlta.Run(Nuevo));
    end;

    /// <remarks>
    /// Solo LEE el tipo. La limpieza del valor va en el OnValidate del campo Atributo y no acá, que
    /// es un detalle del que depende que el proceso funcione: Preparar() vuelve a llamar a esta
    /// función justo antes de verificar, así que limpiar adentro borraba el valor recién cargado y
    /// el proceso moría con "elegí el valor" teniéndolo a la vista en la pantalla.
    /// </remarks>
    local procedure LeerTipoDato()
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        Clear(TipoDato);
        if TipoAtr.Get(CodTipoAtributo) then
            TipoDato := TipoAtr."Tipo Dato";
    end;

    // Cambiar de atributo invalida lo cargado: se interpretó contra el tipo anterior, y arrastrarlo
    // dejaría un código de lista guardado como si fuera un número.
    local procedure LimpiarValor()
    begin
        Clear(ValorEntrada);
        Clear(CodValor);
        Clear(ValorDecimal);
        Clear(ValorTexto);
        Clear(ValorFecha);
    end;

    /// <summary>
    /// Vuelca lo escrito en la variable que corresponda al tipo de dato del atributo.
    /// </summary>
    /// <remarks>
    /// Acá se rechaza lo que no encaja —"mañana" en una fecha, un código que no es de este atributo—
    /// y no al ejecutar: el error aparece en el campo, con el diálogo todavía abierto, en vez de
    /// después de haber elegido los filtros.
    /// </remarks>
    local procedure InterpretarValor()
    var
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        Clear(CodValor);
        Clear(ValorDecimal);
        Clear(ValorTexto);
        Clear(ValorFecha);
        if ValorEntrada = '' then
            exit;
        if CodTipoAtributo = '' then
            Error(ErrFaltaAtributo);

        case TipoDato of
            TipoDato::Lista:
                begin
                    CodValor := CopyStr(ValorEntrada, 1, MaxStrLen(CodValor));
                    ValorAtr.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
                    ValorAtr.SetRange(Código, CodValor);
                    if ValorAtr.IsEmpty() then
                        Error(ErrValorAjeno, CodValor, CodTipoAtributo);
                end;
            TipoDato::Decimal, TipoDato::Entero:
                if not Evaluate(ValorDecimal, ValorEntrada) then
                    Error(ErrNoEsNumero, ValorEntrada);
            TipoDato::Fecha:
                if not Evaluate(ValorFecha, ValorEntrada) then
                    Error(ErrNoEsFecha, ValorEntrada);
            TipoDato::Texto:
                ValorTexto := CopyStr(ValorEntrada, 1, MaxStrLen(ValorTexto));
        end;
    end;

    var
        ValorAtrChk: Record "Valor Atributo Liq.";
        FAlta: Codeunit "Alta Atributo Entidad Liq.";
        Progreso: Dialog;
        TipoEntidad: Enum "Tipo Entidad Estado";
        TipoDato: Enum "Tipo Dato Atributo Liq.";
        CodTipoAtributo: Code[20];
        CodValor: Code[20];
        ValorTexto: Text[250];
        ValorDecimal: Decimal;
        ValorFecha: Date;
        VigenciaDesde: Date;
        Modo: Option "Nueva vigencia",Omitir;
        ValorEntrada: Text[250];
        Corrio: Boolean;
        Vistos: Integer;
        Asignados: Integer;
        Omitidos: Integer;
        TxtProgreso: Label 'Asignando atributo\\Entidad   #1##################################\Asignados #2########';
        ErrFaltaAtributo: Label 'Elegí el atributo a asignar.';
        ErrFaltaFecha: Label 'Indicá desde qué fecha rige el valor.';
        ErrFaltaValorLista: Label 'Este atributo se carga de una lista: elegí el valor.';
        ErrValorAjeno: Label 'El valor %1 no pertenece al atributo %2.';
        ErrNoEsNumero: Label '"%1" no es un número.', Comment = '%1=lo tipeado';
        ErrNoEsFecha: Label '"%1" no es una fecha.', Comment = '%1=lo tipeado';
        MsgResultado: Label '%1 asignación(es) creada(s), %2 omitida(s), sobre %3 entidad(es) evaluada(s).';
}
