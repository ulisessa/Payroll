namespace UAS.Payroll;

// Los atributos de UNA entidad, para incrustar en su ficha.
//
// Es la misma lista que "Atributos de Entidad" sin las dos columnas que en una ficha sobran —el tipo
// y el código de entidad los pone el vínculo— y con el comportamiento de la columna Valor tomado de
// "Atributos Entidad UI", que es el mismo que usa la lista completa. Las dos pantallas no pueden
// aceptar cosas distintas para el mismo atributo: por eso lo que decide vive en la codeunit y acá
// solo queda la disposición.
page 110030 "Atributos Entidad Sub"
{
    ApplicationArea = All;
    Caption = 'Atributos';
    PageType = ListPart;
    SourceTable = "Atributo Entidad Liq.";
    InsertAllowed = false;
    // Ordena por FECHA DE INICIO descendente: lo último asignado arriba, sin importar de qué tipo
    // sea. Es el orden con el que se lee una ficha —qué le pasó a esta persona, de lo más reciente
    // hacia atrás— y el mismo del historial de estados y de las asignaciones a proyecto.
    //
    // Usa K3 y no la clave primaria a propósito: la primaria tiene "Cód. Tipo Atributo" antes de la
    // fecha, así que agrupa por tipo y ordena por fecha recién adentro de cada grupo. Eso mezcla
    // vigencias viejas de un atributo por encima de las nuevas de otro.
    SourceTableView = sorting("Tipo Entidad", "Cód. Entidad", "Vigencia Desde") order(descending);
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Vigencia Desde"; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                    ToolTip = 'Desde cuándo rige este valor. Se completa a mano: es parte de la clave, así que corregirla después no es editar el campo, es renombrar el registro.';
                }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = vigencia abierta. Al cargar una vigencia nueva, la anterior se cierra sola el día previo si estaba abierta.';
                }
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo")
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        // CalcFields a mano: en una fila nueva el FlowField se calculó cuando el
                        // atributo todavía estaba vacío —y dio Decimal, que es el valor cero del
                        // enum— y sin esto la columna Valor seguiría interpretando lo que se escriba
                        // como número aunque el atributo sea de lista.
                        Rec.CalcFields("Tipo Dato");
                        AtributosUI.ProponerVigenciaLibre(Rec);
                        AtributosUI.AbrirListaSiCorresponde(Rec, ValorEntrada);
                    end;
                }
                field("Tipo Dato"; Rec."Tipo Dato") { ApplicationArea = All; }
                field(ValorEntrada; ValorEntrada)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                    ToolTip = 'El valor de este atributo. Si es de lista se elige de la lista —que se abre sola al elegir el atributo, y solo ofrece los que cuelgan del padre vigente ese día—; si es numérico, texto o fecha, se escribe.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        ValorAtr: Record "Valor Atributo Liq.";
                    begin
                        Rec.CalcFields("Tipo Dato");
                        if Rec."Tipo Dato" <> Rec."Tipo Dato"::Lista then
                            exit(false);
                        if not AtributosUI.ElegirValorDeLista(Rec, Text, ValorAtr) then
                            exit(false);
                        Text := ValorAtr.Código;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        AtributosUI.AplicarValor(Rec, ValorEntrada);
                    end;
                }
                field("Descripción Valor"; Rec."Descripción Valor") { ApplicationArea = All; }
                field("Cód. Valor"; Rec."Cód. Valor") { ApplicationArea = All; Visible = false; }
                field("Cód. Valor Padre"; Rec."Cód. Valor Padre")
                {
                    ApplicationArea = All;
                    Caption = 'Cuelga de';
                    Visible = false;
                    ToolTip = 'Para los atributos encadenados, el valor del padre que la entidad tenía vigente el día en que empieza esta vigencia. Queda congelado: el par de enero sigue siendo el de enero aunque el padre cambie después.';
                }
                field("Valor Numérico"; Rec."Valor Numérico")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'El número que efectivamente ve la fórmula. Queda congelado al asignar, para que un recálculo de un período viejo dé lo mismo que dio.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Dos acciones que se turnan la visibilidad: en AL el Caption de una acción es constante
            // y no admite expresión, así que es la única forma de que el botón diga qué va a hacer.
            action(VerTodas)
            {
                ApplicationArea = All;
                Caption = 'Ver historial completo';
                Image = History;
                Visible = SoloActualesActivo;
                ToolTip = 'Muestra todas las vigencias de cada atributo, y habilita cargar una nueva.';
                trigger OnAction()
                begin
                    SoloActuales := false;
                    AplicarFiltros();
                end;
            }
            action(VerActuales)
            {
                ApplicationArea = All;
                Caption = 'Ver solo el último';
                Image = FilterLines;
                Visible = VerTodasActivo;
                ToolTip = 'Una fila por atributo: la última vigencia que se le asignó, haya terminado o no.';
                trigger OnAction()
                begin
                    SoloActuales := true;
                    AplicarFiltros();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        SoloActuales := true;
        AplicarFiltros();
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Tipo Dato");
        ValorEntrada := AtributosUI.ValorParaEditar(Rec);
    end;

    // La columna Valor no es un campo de la tabla sino la variable ValorEntrada, y en una fila nueva
    // OnAfterGetRecord no corre: sin esto, la variable mostraría el valor de la fila anterior como si
    // fuera el de ésta — y si el usuario no lo pisaba, se guardaba.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        ValorEntrada := '';
    end;

    local procedure AplicarFiltros()
    begin
        SoloActualesActivo := SoloActuales;
        VerTodasActivo := not SoloActuales;
        // Los filtros del vínculo con la ficha viven en otro grupo, así que esto no los toca: sigue
        // siendo la entidad de la ficha, con o sin historial.
        //
        // En el resumen NO SE PUEDE INSERTAR, y es a propósito: el filtro es por SystemId, así que
        // una fila nueva no lo matchearía y desaparecería al guardarse — el usuario la cargaría dos
        // veces creyendo que no quedó. Cargar una vigencia es además algo que se hace mirando el
        // historial, no el resumen.
        if SoloActuales then
            AtributosUI.FiltrarUltimaPorTipo(Rec)
        else
            AtributosUI.FiltrarVigentes(Rec, false, WorkDate());
        CurrPage.Update(false);
    end;

    var
        AtributosUI: Codeunit "Atributos Entidad UI";
        SoloActuales: Boolean;
        SoloActualesActivo: Boolean;
        VerTodasActivo: Boolean;
        ValorEntrada: Text;
}
