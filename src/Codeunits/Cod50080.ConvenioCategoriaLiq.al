namespace UAS.Payroll;

/// <summary>
/// De dónde salen el convenio y la categoría de un empleado a una fecha.
/// </summary>
/// <remarks>
/// Hay dos respuestas posibles y las dos son legítimas:
///
///  · La de la ENTIDAD — los atributos del empleado, con su historial de vigencias. Es el par que
///    lo describe: su encuadre real. Es el predeterminado.
///  · La de la ASIGNACIÓN — el convenio y la categoría con los que se lo embarcó en una marea
///    concreta. Puede diferir del anterior: un mensualizado que sale a navegar cobra los conceptos
///    de producción como tripulante sin dejar de ser un mensualizado.
///
/// Los tipos de atributo NO se nombran acá: se identifican por su espejo. El que refleja Convenio
/// Colectivo es el del convenio y el que refleja Categoría CCT es el de la categoría, se llamen como
/// se llamen en cada instalación.
/// </remarks>
codeunit 50080 "Convenio Categoría Liq."
{
    Access = Public;

    /// <summary>
    /// El par que el empleado tiene en sus atributos para esta liquidación. False si no hay ninguno.
    /// </summary>
    /// <remarks>
    /// Manda la FECHA DE REFERENCIA, igual que en todo el resto del motor: los parámetros, la versión
    /// del concepto y la distribución en acumuladores se resuelven todos contra ella, y el par tiene
    /// que salir del mismo corte temporal o el importe se arma con piezas de dos momentos distintos.
    ///
    /// El RANGO es la red, no el criterio: si a la fecha de referencia no hay ninguna vigencia, se
    /// busca la primera que se solape con el período liquidado. Eso cubre el Cierre de Marea, donde
    /// la referencia es el arribo y puede ser anterior a una vigencia cargada más adelante dentro del
    /// mismo período — sin la red, esa liquidación resolvería sin atributo y caería al par viejo.
    /// </remarks>
    procedure ParDeEntidad(EmployeeNo: Code[20]; FechaRef: Date; RangoDesde: Date; RangoHasta: Date; var Convenio: Code[20]; var Categoria: Code[20]): Boolean
    var
        CodTipoConv: Code[20];
        CodTipoCat: Code[20];
        PadreNoUsado: Code[20];
    begin
        Clear(Convenio);
        Clear(Categoria);
        if (EmployeeNo = '') or (FechaRef = 0D) then
            exit(false);

        CodTipoConv := TipoConEspejo("Espejo Atributo Liq."::"Convenio Colectivo");
        if CodTipoConv = '' then
            exit(false);
        Convenio := ValorParaLiquidacion(EmployeeNo, CodTipoConv, FechaRef, RangoDesde, RangoHasta, PadreNoUsado);
        if Convenio = '' then
            exit(false);

        // La categoría es opcional: hay personal sin categoría asignada, y su ausencia no invalida
        // el convenio. Lo que no puede pasar es lo inverso.
        CodTipoCat := TipoConEspejo("Espejo Atributo Liq."::"Categoría CCT");
        if CodTipoCat <> '' then
            Categoria := ValorParaLiquidacion(EmployeeNo, CodTipoCat, FechaRef, RangoDesde, RangoHasta, PadreNoUsado);
        exit(true);
    end;

    /// <summary>
    /// El par que corresponde al PUESTO del empleado a esa fecha. False si no tiene puesto vigente.
    /// </summary>
    /// <remarks>
    /// El puesto es el segundo eje del encuadre: la categoría del CCT paga el sueldo y el puesto paga
    /// la producción. Son independientes y difieren de verdad — un Contramaestre Argentino que navega
    /// de Primer Pescador cobra el sueldo por lo primero y la producción por lo segundo.
    ///
    /// DEVUELVE EL PAR COMPLETO, convenio incluido, y ese convenio sale del PADRE DEL VALOR, no del
    /// llamador. Antes devolvía sólo la categoría y quien llamaba conservaba el convenio de la
    /// cabecera. Eso funciona mientras los dos ejes caen en el mismo convenio, y se rompe justo
    /// cuando el puesto sirve para algo: un oficial encuadrado en 768/19 que navega de Pesca tiene
    /// el puesto FE01, que vive bajo ESP. Cruzarlo con el convenio de la cabecera arma (768/19,
    /// FE01), un par que no existe — no se encuentra la Categoría CCT y ni el básico ni ningún
    /// parámetro por categoría resuelven. Sin error: con ceros.
    ///
    /// El padre es confiable porque la clave de "Categoría CCT" es (convenio, código) y el atributo
    /// lo guarda por eso mismo: ningún valor de PUESTO existe sin él.
    ///
    /// Usa la MISMA resolución temporal que ParDeEntidad, incluida la red del rango: sin ella, un
    /// Cierre de Marea cuya referencia es el arribo no vería un puesto cargado más adelante dentro
    /// del mismo período.
    /// </remarks>
    procedure ParDePuesto(EmployeeNo: Code[20]; FechaRef: Date; RangoDesde: Date; RangoHasta: Date; var Convenio: Code[20]; var Categoria: Code[20]): Boolean
    var
        CodTipoPuesto: Code[20];
    begin
        Clear(Convenio);
        Clear(Categoria);
        if (EmployeeNo = '') or (FechaRef = 0D) then
            exit(false);

        CodTipoPuesto := TipoConEspejo("Espejo Atributo Liq."::Puesto);
        if CodTipoPuesto = '' then
            exit(false);

        Categoria := ValorParaLiquidacion(EmployeeNo, CodTipoPuesto, FechaRef, RangoDesde, RangoHasta, Convenio);
        exit(Categoria <> '');
    end;

    /// <summary>El tipo de atributo declarado como espejo de ese maestro, o vacío.</summary>
    procedure TipoConEspejo(Espejo: Enum "Espejo Atributo Liq."): Code[20]
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        TipoAtr.SetRange("Espejo De", Espejo);
        if TipoAtr.FindFirst() then
            exit(TipoAtr.Código);
        exit('');
    end;

    /// <summary>El valor vigente del atributo; por ValorPadre, el padre de ESE valor.</summary>
    /// <remarks>
    /// El padre sale de la MISMA FILA que el valor y nunca de una segunda consulta: son un par, y
    /// separarlos abre la puerta a devolver la categoría de una vigencia con el convenio de otra.
    /// </remarks>
    local procedure ValorParaLiquidacion(EmployeeNo: Code[20]; CodTipoAtributo: Code[20]; FechaRef: Date; RangoDesde: Date; RangoHasta: Date; var ValorPadre: Code[20]): Code[20]
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Clear(ValorPadre);
        // 1) La vigente a la fecha de referencia. Misma regla que el resto del historial: la última
        //    que empezó antes de esa fecha y que no haya cerrado antes de ella.
        FiltrarEntidad(Atributo, EmployeeNo, CodTipoAtributo);
        Atributo.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        Atributo.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, FechaRef);
        if Atributo.FindLast() then begin
            ValorPadre := Atributo."Cód. Valor Padre";
            exit(Atributo."Cód. Valor");
        end;

        if (RangoDesde = 0D) and (RangoHasta = 0D) then
            exit('');

        // 2) La red: la PRIMERA que se solape con el período liquidado. Se toma la primera y no la
        //    última porque llegar acá significa que la vigencia empieza después de la referencia —
        //    la más temprana es la que antes entra a regir dentro del período.
        FiltrarEntidad(Atributo, EmployeeNo, CodTipoAtributo);
        if RangoHasta <> 0D then
            Atributo.SetFilter("Vigencia Desde", '<=%1', RangoHasta);
        if RangoDesde <> 0D then
            Atributo.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, RangoDesde);
        if Atributo.FindFirst() then begin
            ValorPadre := Atributo."Cód. Valor Padre";
            exit(Atributo."Cód. Valor");
        end;
        exit('');
    end;

    local procedure FiltrarEntidad(var Atributo: Record "Atributo Entidad Liq."; EmployeeNo: Code[20]; CodTipoAtributo: Code[20])
    begin
        Atributo.Reset();
        Atributo.SetRange("Tipo Entidad", Atributo."Tipo Entidad"::Empleado);
        Atributo.SetRange("Cód. Entidad", EmployeeNo);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
    end;
}
