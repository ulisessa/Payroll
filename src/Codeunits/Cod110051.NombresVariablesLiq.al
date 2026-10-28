namespace UAS.Payroll;

/// <summary>
/// Un nombre de variable, un solo dueño. Rechaza el alta de un nombre que ya ocupa otra cosa.
/// </summary>
/// <remarks>
/// El contexto de las fórmulas es UN espacio de nombres plano alimentado por cuatro tablas —
/// Parámetro, Variable Sistema Liq., Fuente Datos Liquidación y Tipo Atributo Liq.—. Dos de ellas
/// con el mismo nombre no dan error: se pisan, y cuál gana depende del ORDEN en que el motor arma
/// el contexto, que no es algo que nadie deba tener que saber para leer una fórmula.
///
/// Y no se pisan una sola vez. BuildContext carga parámetros, después variables de sistema, después
/// fuentes y después atributos, así que al arranque gana la última. Pero UsarParCCT —lo que el motor
/// llama cuando un concepto se liquida con otro par convenio/categoría— recarga SOLO los parámetros
/// y deliberadamente no vuelve a correr las fuentes. O sea que el ganador CAMBIA en medio del
/// cálculo, y la misma variable puede valer una cosa en un concepto y otra en el de al lado.
///
/// Eso fue exactamente TC_COMPRADOR: existía como Fuente de Datos (la cotización compradora) y como
/// Parámetro con una sola vigencia de valor 0. En las mismas 449 liquidaciones resolvió bien en las
/// líneas de ADIC_PROD_PESCA y dio cero en 125 de las de PROD_EMPRESA, que es la que tiene "Par CCT
/// a Usar". Sin error, sin aviso, y con la producción de marea valuada a cero.
///
/// El control ya existía, pero SOLO en Tipo Atributo Liq., que era la última tabla que se sumó al
/// espacio de nombres. Acá queda en un lugar y lo llaman las cuatro.
/// </remarks>
codeunit 110051 "Nombres Variables Liq."
{
    Access = Public;

    /// <summary>
    /// Falla si el nombre ya lo usa otra cosa. TablaPropia/ClavePropia identifican al que pregunta,
    /// para no encontrarse a sí mismo al editar un registro que ya existe.
    /// </summary>
    procedure ExigirLibre(Nombre: Code[30]; TablaPropia: Integer; ClavePropia: Code[30])
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if Nombre = '' then
            exit;

        // El parámetro VAR ocupa también VAR_ESFCY, que es el nombre que el contexto deriva de él
        // para preguntar si su valor está en moneda extranjera. Por eso se lo busca por las dos
        // puntas: con el nombre tal cual, y con el nombre sin ese sufijo.
        Param.SetFilter("Nombre Variable", '%1|%2', Nombre, SinSufijoESFCY(Nombre));
        if TablaPropia = Database::"Parámetro" then
            Param.SetFilter(Código, '<>%1', ClavePropia);
        if Param.FindFirst() then
            Error(ErrNombreTomado, Nombre, Param.TableCaption(), Param.Código);

        if TablaPropia <> Database::"Variable Sistema Liq." then begin
            VarSis.SetRange("Nombre Variable", Nombre);
            if VarSis.FindFirst() then
                Error(ErrNombreTomado, Nombre, VarSis.TableCaption(), VarSis."Nombre Variable");
        end;

        if TablaPropia <> Database::"Fuente Datos Liquidación" then begin
            Fuente.SetRange("Nombre Variable", Nombre);
            if Fuente.FindFirst() then
                Error(ErrNombreTomado, Nombre, Fuente.TableCaption(), Fuente."Nombre Variable");
        end;

        TipoAtr.SetRange("Nombre Variable", Nombre);
        if TablaPropia = Database::"Tipo Atributo Liq." then
            TipoAtr.SetFilter(Código, '<>%1', ClavePropia);
        if TipoAtr.FindFirst() then
            Error(ErrNombreTomado, Nombre, TipoAtr.TableCaption(), TipoAtr.Código);
    end;

    /// <summary>Los choques que ya están en la base. Para revisar lo cargado antes del control.</summary>
    /// <remarks>
    /// El control nuevo frena lo que se cargue de acá en adelante; lo que ya estaba duplicado sigue
    /// duplicado y hay que ir a buscarlo. Esto lo lista en vez de dejarlo esperando a que alguien
    /// note un importe raro.
    /// </remarks>
    procedure Duplicados() Texto: Text
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        TipoAtr: Record "Tipo Atributo Liq.";
        TB: TextBuilder;
    begin
        // Las CUATRO tablas, no sólo Parámetro: un choque entre una Fuente de Datos y un Atributo no
        // involucra ningún parámetro y antes no se reportaba.
        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                if OcupadoPorOtro(Param."Nombre Variable", Database::"Parámetro", Param.Código) then
                    TB.AppendLine(Param."Nombre Variable" + ' - Parámetro ' + Param.Código);
            until Param.Next() = 0;

        VarSis.SetFilter("Nombre Variable", '<>%1', '');
        if VarSis.FindSet() then
            repeat
                if OcupadoPorOtro(VarSis."Nombre Variable", Database::"Variable Sistema Liq.", VarSis."Nombre Variable") then
                    TB.AppendLine(VarSis."Nombre Variable" + ' - Variable de Sistema');
            until VarSis.Next() = 0;

        Fuente.SetFilter("Nombre Variable", '<>%1', '');
        if Fuente.FindSet() then
            repeat
                if OcupadoPorOtro(Fuente."Nombre Variable", Database::"Fuente Datos Liquidación", Fuente."Nombre Variable") then
                    TB.AppendLine(Fuente."Nombre Variable" + ' - Fuente de Datos');
            until Fuente.Next() = 0;

        TipoAtr.SetFilter("Nombre Variable", '<>%1', '');
        if TipoAtr.FindSet() then
            repeat
                if OcupadoPorOtro(TipoAtr."Nombre Variable", Database::"Tipo Atributo Liq.", TipoAtr.Código) then
                    TB.AppendLine(TipoAtr."Nombre Variable" + ' - Tipo de Atributo ' + TipoAtr.Código);
            until TipoAtr.Next() = 0;

        exit(TB.ToText());
    end;

    local procedure OcupadoPorOtro(Nombre: Code[30]; TablaPropia: Integer; ClavePropia: Code[30]): Boolean
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        // La tabla Parámetro FALTABA acá, y era el choque más probable de todos: dos parámetros con
        // el mismo nombre de variable. Pasó con BASICO y BASICO_MENSUAL, los dos declarando BASICO.
        // El motor recorre Parámetro por su código y hace Ctx.Set sin condición, así que ganaba el
        // segundo en orden alfabético: BASICO_MENSUAL, cargado sólo por empleado, ponía el token en
        // cero para todo el que no lo tuviera y borraba el básico por convenio de los oficiales.
        // ExigirLibre sí lo chequeaba; esta función, que es la que busca lo YA cargado, no.
        Param.SetFilter("Nombre Variable", '%1|%2', Nombre, SinSufijoESFCY(Nombre));
        if TablaPropia = Database::"Parámetro" then
            Param.SetFilter(Código, '<>%1', ClavePropia);
        if not Param.IsEmpty() then exit(true);

        if TablaPropia <> Database::"Variable Sistema Liq." then begin
            VarSis.SetRange("Nombre Variable", Nombre);
            if not VarSis.IsEmpty() then exit(true);
        end;
        if TablaPropia <> Database::"Fuente Datos Liquidación" then begin
            Fuente.SetRange("Nombre Variable", Nombre);
            if not Fuente.IsEmpty() then exit(true);
        end;
        TipoAtr.SetRange("Nombre Variable", Nombre);
        if TablaPropia = Database::"Tipo Atributo Liq." then
            TipoAtr.SetFilter(Código, '<>%1', ClavePropia);
        exit(not TipoAtr.IsEmpty());
    end;

    local procedure SinSufijoESFCY(Nombre: Code[30]): Code[30]
    var
        Texto: Text;
    begin
        Texto := Nombre;
        if not Texto.EndsWith(SufijoMonedaTok) then
            exit(Nombre);
        exit(CopyStr(Texto.Substring(1, StrLen(Texto) - StrLen(SufijoMonedaTok)), 1, MaxStrLen(Nombre)));
    end;

    var
        ErrNombreTomado: Label 'El nombre de variable %1 ya lo usa %2 (%3). Dos cosas con el mismo nombre no pueden convivir en una fórmula: elegí otro.', Comment = '%1=nombre de variable, %2=nombre de la tabla que ya lo usa, %3=código del registro';
        SufijoMonedaTok: Label '_ESFCY', Locked = true;
}
