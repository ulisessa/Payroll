namespace UAS.Payroll;

page 110074 "Corregir Orden Acum. Dialog"
{
    Caption = 'Corregir orden de cálculo';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Cambio)
            {
                ShowCaption = false;
                field(Acumulador; Acumulador)
                {
                    ApplicationArea = All;
                    Caption = 'Base o fórmula lectora';
                    Editable = false;
                }
                field(CodigoConcepto; CodigoConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto a corregir';
                    Editable = CodigoEditable;
                    TableRelation = "Concepto Liquidación".Código;
                    ToolTip = 'Concepto productor o lector de la fila seleccionada. Se modifica un orden por vez y después se vuelve a verificar.';
                    trigger OnValidate()
                    var
                        Gestor: Codeunit "Corrección Orden Acum.";
                    begin
                        if ConceptoFijo then
                            if CodigoConcepto <> Origen.Código then
                                Error('La revisión está limitada al concepto %1. Abrí el control general para corregir otro concepto.', Origen.Código);
                        if not Gestor.Preparar(Acumulador, FechaReferencia, TipoLiquidacion, Convenio, Categoria, CodigoConcepto, ActualizarVigencia, Origen, NuevoOrden, FechaNueva, Explicacion) then
                            Error('%1', Explicacion);
                        PrepararFechaCreacion();
                        ActualizarPropuesta();
                    end;
                }
                field(DescripcionConcepto; Origen.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                }
                field(InicioOrigen; Origen."Vigencia Desde")
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia original';
                    Editable = false;
                }
                field(OrdenActual; OrdenActual)
                {
                    ApplicationArea = All;
                    Caption = 'Orden actual';
                    Editable = false;
                    MultiLine = true;
                }
                field(NuevoOrden; NuevoOrden)
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo orden';
                    MinValue = 0;
                    ToolTip = 'Posición propuesta para el concepto. La evaluación comprueba sus dependencias antes de permitir guardar.';
                    trigger OnValidate()
                    begin
                        RevisarEdicion();
                    end;
                }
                field(ActualizarVigencia; ActualizarVigencia)
                {
                    ApplicationArea = All;
                    Caption = 'Actualizar esta vigencia';
                    ToolTip = 'Activalo para modificar únicamente el orden de la vigencia original y conservar sus fechas. Los próximos recálculos de todo ese intervalo usarán el nuevo orden. Desactivalo para crear otra vigencia desde una fecha posterior.';
                    trigger OnValidate()
                    begin
                        if ActualizarVigencia then begin
                            FechaCreacion := FechaNueva;
                            FechaNueva := Origen."Vigencia Desde";
                        end else
                            FechaNueva := FechaCreacion;
                        ActualizarTextosModo();
                        RevisarEdicion();
                        CurrPage.Update(false);
                    end;
                }
                field(FechaNueva; FechaNueva)
                {
                    ApplicationArea = All;
                    Caption = 'Vigente desde';
                    Editable = not ActualizarVigencia;
                    ToolTip = 'En una nueva vigencia permite elegir la fecha. Al actualizar la vigencia existente conserva su inicio y fin; todos los períodos de su intervalo usarán el nuevo orden al recalcular. Los recibos guardados no se recalculan.';
                    trigger OnValidate()
                    begin
                        FechaCreacion := FechaNueva;
                        RevisarEdicion();
                    end;
                }
                field(ModoActualizacion; ModoActualizacion)
                {
                    ApplicationArea = All;
                    Caption = 'Forma de aplicar';
                    Editable = false;
                    MultiLine = true;
                }
                field(Alcance; Alcance)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance del nuevo orden';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Los filtros de tipo y convenio delimitan el cambio. El orden se aplica a todas las categorías de ese ámbito; la categoría del diagnóstico no crea una regla nueva de orden.';
                }
                field(FormulaPropuesta; FormulaPropuesta)
                {
                    ApplicationArea = All;
                    Caption = 'Orden resultante';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Expresión exacta que se guardará. Cuando se eligió tipo o convenio, conserva la expresión anterior fuera de ese ámbito.';
                }
            }
            group(Revision)
            {
                Caption = 'Antes de aplicar';
                field(Explicacion; Explicacion)
                {
                    ApplicationArea = All;
                    Caption = 'Propuesta';
                    Editable = false;
                    MultiLine = true;
                }
                field(Evaluacion; Evaluacion)
                {
                    ApplicationArea = All;
                    Caption = 'Evaluación';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = EvaluacionStyle;
                }
                field(Nota; Nota)
                {
                    ApplicationArea = All;
                    Caption = 'Al aceptar';
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    procedure Configurar(CodAcumulador: Code[20]; FechaRef: Date; TipoLiq: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; ConceptoOrigen: Record "Concepto Liquidación"; OrdenPropuesto: Integer; FechaPropuesta: Date; Motivo: Text)
    begin
        Configurar(CodAcumulador, FechaRef, TipoLiq, CodConvenio, CodCategoria, ConceptoOrigen, OrdenPropuesto, FechaPropuesta, Motivo, false);
    end;

    procedure Configurar(CodAcumulador: Code[20]; FechaRef: Date; TipoLiq: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; ConceptoOrigen: Record "Concepto Liquidación"; OrdenPropuesto: Integer; FechaPropuesta: Date; Motivo: Text; ActualizarMismaVigencia: Boolean)
    begin
        ActualizarVigencia := ActualizarMismaVigencia;
        CodigoEditable := not ConceptoFijo;
        Acumulador := CodAcumulador;
        FechaReferencia := FechaRef;
        TipoLiquidacion := TipoLiq;
        Convenio := CodConvenio;
        Categoria := CodCategoria;
        Origen := ConceptoOrigen;
        CodigoConcepto := Origen.Código;
        NuevoOrden := OrdenPropuesto;
        FechaNueva := FechaPropuesta;
        Explicacion := Motivo;
        Alcance := 'Todos los tipos de liquidación y convenios.';
        if TipoLiquidacion <> '' then
            Alcance := 'Tipo de liquidación ' + TipoLiquidacion + '; todos los convenios.';
        if Convenio <> '' then begin
            Alcance := 'Convenio ' + Convenio + '; todos los tipos de liquidación y todas sus categorías.';
            if TipoLiquidacion <> '' then
                Alcance := 'Tipo de liquidación ' + TipoLiquidacion + ', convenio ' + Convenio + ', todas sus categorías.';
        end;
        PrepararFechaCreacion();
        ActualizarTextosModo();
        ActualizarPropuesta();
    end;

    local procedure PrepararFechaCreacion()
    begin
        FechaCreacion := FechaNueva;
        if ActualizarVigencia then begin
            FechaCreacion := FechaReferencia;
            if FechaCreacion <= Origen."Vigencia Desde" then begin
                FechaCreacion := Origen."Vigencia Desde";
                if FechaCreacion < DMY2Date(31, 12, 9999) then
                    FechaCreacion += 1;
            end;
        end;
    end;

    local procedure ActualizarTextosModo()
    begin
        if ActualizarVigencia then begin
            FechaNueva := Origen."Vigencia Desde";
            ModoActualizacion := 'Actualizar la vigencia existente, conservando su código y fechas.';
            Nota := 'Se modificará el orden de todo el intervalo de esta vigencia y quedará auditado. Los próximos recálculos de cualquier período de ese intervalo usarán el nuevo orden. Los recibos guardados no se recalculan.';
        end else begin
            ModoActualizacion := 'Crear una nueva vigencia desde la fecha indicada.';
            Nota := 'Se creará una nueva vigencia y quedará registrado el orden anterior y el nuevo. Los recibos existentes no se recalculan.';
        end;
    end;

    procedure FijarConcepto(Fijar: Boolean)
    begin
        ConceptoFijo := Fijar;
        CodigoEditable := not Fijar;
    end;

    procedure GetResultado(var ConceptoOrigen: Record "Concepto Liquidación"; var OrdenPropuesto: Integer; var FechaPropuesta: Date)
    begin
        if ConceptoFijo then
            if CodigoConcepto <> Origen.Código then
                Error('La revisión está limitada al concepto %1.', Origen.Código);
        ConceptoOrigen := Origen;
        OrdenPropuesto := NuevoOrden;
        FechaPropuesta := FechaNueva;
    end;

    procedure GetResultado(var ConceptoOrigen: Record "Concepto Liquidación"; var OrdenPropuesto: Integer; var FechaPropuesta: Date; var ActualizarMismaVigencia: Boolean)
    begin
        GetResultado(ConceptoOrigen, OrdenPropuesto, FechaPropuesta);
        ActualizarMismaVigencia := ActualizarVigencia;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        // La evaluación ya corresponde a los campos visibles. Aplicar vuelve a leer y validar.
        if CloseAction = Action::OK then
            if not EvaluacionValida then
                Error('%1', Evaluacion);
        exit(true);
    end;

    local procedure RevisarEdicion()
    begin
        // La sugerencia inicial puede corresponder a otro modo o fecha. No mostrarla como vigente.
        Explicacion := StrSubstNo('Orden a comprobar: %1. La evaluación corresponde a la forma de aplicar y la fecha indicadas.', NuevoOrden);
        ActualizarPropuesta();
    end;

    local procedure ActualizarPropuesta()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        if ActualizarVigencia then
            FechaNueva := Origen."Vigencia Desde";
        OrdenActual := Motor.FormulaOrdenConfigurada(Origen);
        Clear(FormulaPropuesta);
        Clear(Evaluacion);
        EvaluacionValida := IntentarValidar();
        if EvaluacionValida then
            EvaluacionStyle := 'Favorable'
        else begin
            Evaluacion := 'No se puede aplicar: ' + GetLastErrorText();
            EvaluacionStyle := 'Unfavorable';
        end;
    end;

    [TryFunction]
    local procedure IntentarValidar()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
    begin
        // Validar sólo lee. Las escrituras se hacen después del diálogo, en una única transacción.
        Gestor.Validar(Acumulador, Origen, FechaNueva, NuevoOrden, TipoLiquidacion, Convenio, Categoria, ActualizarVigencia, FormulaPropuesta, Evaluacion);
    end;

    var
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        CodigoConcepto: Code[20];
        CodigoEditable: Boolean;
        ConceptoFijo: Boolean;
        ActualizarVigencia: Boolean;
        FechaReferencia: Date;
        FechaNueva: Date;
        FechaCreacion: Date;
        TipoLiquidacion: Code[20];
        Convenio: Code[20];
        Categoria: Code[20];
        NuevoOrden: Integer;
        OrdenActual: Text;
        FormulaPropuesta: Text;
        Explicacion: Text;
        Evaluacion: Text;
        EvaluacionValida: Boolean;
        EvaluacionStyle: Text[20];
        Alcance: Text;
        Nota: Text;
        ModoActualizacion: Text;
}
