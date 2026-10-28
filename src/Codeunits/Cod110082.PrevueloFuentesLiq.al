namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using System.Reflection;

/// <summary>Inspección de configuración y cotizaciones, sin construir el contexto de cálculo.</summary>
codeunit 110082 "Prevuelo Fuentes Liq."
{
    Access = Public;

    procedure RevisarConfiguracion(Desde: Date; Hasta: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Fuente: Record "Fuente Datos Liquidación";
        Motivo: Text;
        Bloqueante: Boolean;
        Nivel: Enum "Severidad Registro Liq.";
    begin
        if not Buffer.IsTemporary() then
            Error('El control previo sólo admite resultados temporales.');
        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                if not ConfiguracionValida(Fuente, Motivo, Bloqueante) then begin
                    Nivel := Buffer.Severidad::Advertencia;
                    if Bloqueante then
                        Nivel := Buffer.Severidad::Error;
                    // La incompatibilidad Code/Text -> Decimal devuelve cero en el
                    // motor; sin consumidores no constituye una tarea de cálculo.
                    // Lo estructural se valida SIEMPRE: las fuentes activas se cargan
                    // aunque no exista un lector textual de su resultado.
                    if Bloqueante then
                        Agregar(Buffer, Fuente, Desde, Hasta, Nivel, Motivo)
                    else if TieneConsumidoresConfigurados(Fuente."Nombre Variable") then
                        Agregar(Buffer, Fuente, Desde, Hasta, Nivel, Motivo);
                end
                else
                    if not TieneFiltros(Fuente) then
                        Agregar(Buffer, Fuente, Desde, Hasta, Buffer.Severidad::Advertencia,
                            'Fuente activa sin filtros: confirmar que corresponda leer toda la tabla.');
            until Fuente.Next() = 0;
    end;

    local procedure TieneConsumidoresConfigurados(Nombre: Code[30]): Boolean
    begin
        // Censo conservador: se incluyen todas las versiones y fechas, no sólo la
        // fórmula de importe actual. Una coincidencia dudosa conserva la revisión.
        // No se ejecutan fuentes, fórmulas ni referencias para buscar sus lectores.
        exit(TablaReferencia(Database::"Concepto Liquidación", Nombre) or
             TablaReferencia(Database::"Parámetro", Nombre) or
             TablaReferencia(Database::"Parámetro Vigente", Nombre) or
             TablaReferencia(Database::"Variable Sistema Liq.", Nombre) or
             TablaReferencia(Database::"Tipo Atributo Liq.", Nombre) or
             TablaReferencia(Database::"Fuente Datos Liquidación", Nombre) or
             TablaReferencia(Database::"Filtro Fuente Datos Liq.", Nombre) or
             TablaReferencia(Database::"Human Resources Setup", Nombre));
    end;

    local procedure TablaReferencia(IdTabla: Integer; Nombre: Code[30]): Boolean
    var
        Tabla: RecordRef;
        Campo: FieldRef;
        Campos: Record Field;
        Texto: Text;
        Numeros: List of [Integer];
        Numero: Integer;
    begin
        Campos.SetRange(TableNo, IdTabla);
        Campos.SetRange(Class, Campos.Class::Normal);
        Campos.SetRange(Enabled, true);
        Campos.SetFilter(ObsoleteState, '<>%1', Campos.ObsoleteState::Removed);
        Campos.SetFilter(Type, '%1|%2', Campos.Type::Code, Campos.Type::Text);
        // El nombre de una fuente en la clave de sus filtros no es un lector.
        if IdTabla = Database::"Filtro Fuente Datos Liq." then
            Campos.SetFilter("No.", '<>%1', 1);
        if Campos.FindSet() then
            repeat
                Numeros.Add(Campos."No.");
            until Campos.Next() = 0;
        Tabla.Open(IdTabla);
        // No contabilizar la propia definición como consumidor de sí misma.
        if IdTabla = Database::"Fuente Datos Liquidación" then begin
            Campo := Tabla.Field(1);
            Campo.SetFilter('<>%1', Nombre);
        end;
        if Tabla.FindSet() then
            repeat
                foreach Numero in Numeros do begin
                        Campo := Tabla.Field(Numero);
                        Texto := Format(Campo.Value());
                        if Texto.ToUpper().Contains(Nombre) then begin
                            Tabla.Close();
                            exit(true);
                        end;
                end;
            until Tabla.Next() = 0;
        Tabla.Close();
        exit(false);
    end;

    procedure ConfiguracionValida(Fuente: Record "Fuente Datos Liquidación"; var Motivo: Text): Boolean
    var
        Bloqueante: Boolean;
    begin
        exit(ConfiguracionValida(Fuente, Motivo, Bloqueante));
    end;

    procedure ConfiguracionValida(Fuente: Record "Fuente Datos Liquidación"; var Motivo: Text; var Bloqueante: Boolean): Boolean
    var
        Objeto: Record AllObjWithCaption;
        Campo: Record Field;
        Filtro: Record "Filtro Fuente Datos Liq.";
        AvisoConversion: Text;
    begin
        Clear(Motivo);
        Bloqueante := true;
        Objeto.SetRange("Object Type", Objeto."Object Type"::Table);
        Objeto.SetRange("Object ID", Fuente."Id. Tabla");
        if (Fuente."Id. Tabla" = 0) or Objeto.IsEmpty() then begin
            Motivo := StrSubstNo('La tabla %1 de la fuente no existe o no está indicada.', Fuente."Id. Tabla");
            exit(false);
        end;
        if (Fuente."Tipo Dato" <> Fuente."Tipo Dato"::Decimal) or (Fuente."Función Agregado" in
            [Fuente."Función Agregado"::SUM, Fuente."Función Agregado"::MAX, Fuente."Función Agregado"::MIN,
             Fuente."Función Agregado"::LOOKUP, Fuente."Función Agregado"::FILA_MAS_RECIENTE,
             Fuente."Función Agregado"::FILA_MAS_ANTIGUA])
        then begin
            if not ComprobarCampo(Fuente."Id. Tabla", Fuente."No. Campo Valor", false, 'valor', Motivo) then
                exit(false);
            Campo.Get(Fuente."Id. Tabla", CampoCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
            case Fuente."Tipo Dato" of
                Fuente."Tipo Dato"::Decimal:
                    if not (Campo.Type in [Campo.Type::Decimal, Campo.Type::Integer, Campo.Type::BigInteger]) then
                        Motivo := 'El campo de valor no es numérico, aunque la fuente está declarada como decimal.';
                Fuente."Tipo Dato"::Texto:
                    if not (Campo.Type in [Campo.Type::Text, Campo.Type::Code, Campo.Type::Option]) then
                        Motivo := 'El tipo del campo de valor no coincide con la fuente de texto.';
                Fuente."Tipo Dato"::Fecha:
                    if not (Campo.Type in [Campo.Type::Date, Campo.Type::DateTime]) then
                        Motivo := 'El tipo del campo de valor no coincide con la fuente de fecha.';
            end;
            if Motivo <> '' then begin
                // FieldRefToDecimal del contexto devuelve cero para Code/Text. Es una
                // incompatibilidad real que requiere revisión, pero no una excepción de
                // ejecución demostrada. Los demás defectos conservan su carácter bloqueante.
                if (Fuente."Tipo Dato" = Fuente."Tipo Dato"::Decimal) and
                    (Campo.Type in [Campo.Type::Code, Campo.Type::Text])
                then begin
                    AvisoConversion := Motivo;
                    Clear(Motivo);
                end else
                    exit(false);
            end;
        end;
        if not ComprobarCampo(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio", true, 'fecha de inicio', Motivo) then
            exit(false);
        if not ComprobarCampo(Fuente."Id. Tabla", Fuente."No. Campo Fecha Fin", true, 'fecha de fin', Motivo) then
            exit(false);
        if not ComprobarCampo(Fuente."Id. Tabla", Fuente."No. Campo Clave", true, 'ordenación', Motivo) then
            exit(false);
        if Fuente."Función Agregado" in
            [Fuente."Función Agregado"::DIAS_OVERLAP, Fuente."Función Agregado"::DIAS_OVERLAP_30,
             Fuente."Función Agregado"::DURACION_INICIO, Fuente."Función Agregado"::DURACION_AÑO,
             Fuente."Función Agregado"::FILA_MAS_RECIENTE, Fuente."Función Agregado"::FILA_MAS_ANTIGUA]
        then
            if Fuente."No. Campo Fecha Inicio" = 0 then begin
                Motivo := 'La función de la fuente requiere un campo de fecha de inicio.';
                exit(false);
            end;
        if not ComprobarFecha(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio", Motivo) then
            exit(false);
        if not ComprobarFecha(Fuente."Id. Tabla", Fuente."No. Campo Fecha Fin", Motivo) then
            exit(false);
        // El motor vigente sólo aplica la subtabla; los campos legacy del maestro no filtran.
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if Filtro.FindSet() then
            repeat
                if not ComprobarFiltro(Fuente."Id. Tabla", Filtro."No. Campo", Filtro."Filtro Valor", Motivo) then
                    exit(false);
            until Filtro.Next() = 0;
        if AvisoConversion <> '' then begin
            Motivo := AvisoConversion;
            Bloqueante := false;
            exit(false);
        end;
        Bloqueante := false;
        exit(true);
    end;

    /// <summary>Comprueba una fuente cuando fecha de referencia y de cotización coinciden.</summary>
    /// <remarks>Un token de empleado, documento o cobertura no se reemplaza por un comodín.</remarks>
    procedure ResolverCotizacion(NombreFuente: Code[30]; Moneda: Code[10]; FechaRef: Date; var Valor: Decimal; var Motivo: Text): Boolean
    begin
        exit(ResolverCotizacionFechas(NombreFuente, Moneda, FechaRef, FechaRef, Valor, Motivo));
    end;

    procedure ResolverCotizacionFechas(NombreFuente: Code[30]; Moneda: Code[10]; FechaRef: Date; FechaTC: Date; var Valor: Decimal; var Motivo: Text): Boolean
    var
        AusenciaConfirmada: Boolean;
    begin
        exit(ResolverCotizacionFechas(NombreFuente, Moneda, FechaRef, FechaTC, Valor, Motivo, AusenciaConfirmada));
    end;

    /// <summary>Separa tasa ausente/no positiva de un contexto que no pudo comprobarse.</summary>
    procedure ResolverCotizacionFechas(NombreFuente: Code[30]; Moneda: Code[10]; FechaRef: Date; FechaTC: Date; var Valor: Decimal; var Motivo: Text; var AusenciaConfirmada: Boolean): Boolean
    var
        Fuente: Record "Fuente Datos Liquidación";
        Campo: Record Field;
        Encontrada: Boolean;
    begin
        Clear(Valor);
        Clear(Motivo);
        Clear(AusenciaConfirmada);
        if not Fuente.Get(NombreFuente) then begin
            Motivo := 'No existe la fuente indicada para convertir el parámetro en moneda extranjera.';
            exit(false);
        end;
        if not Fuente.Activo then begin
            Motivo := 'La fuente del tipo de cambio está inactiva.';
            exit(false);
        end;
        if not ConfiguracionValida(Fuente, Motivo) then
            exit(false);
        if (Moneda = '') or (FechaRef = 0D) or (FechaTC = 0D) then begin
            Motivo := 'Faltan moneda o fecha para comprobar la cotización.';
            exit(false);
        end;
        if (Fuente."Tipo Dato" <> Fuente."Tipo Dato"::Decimal) or
           not (Fuente."Función Agregado" in
                [Fuente."Función Agregado"::LOOKUP, Fuente."Función Agregado"::MAX, Fuente."Función Agregado"::MIN,
                 Fuente."Función Agregado"::FILA_MAS_RECIENTE, Fuente."Función Agregado"::FILA_MAS_ANTIGUA])
        then begin
            Motivo := 'Revisar: el tipo de cambio usa una fuente que requiere el contexto completo del cálculo.';
            exit(false);
        end;
        if not TieneFiltros(Fuente) then begin
            Motivo := 'Revisar: la fuente del tipo de cambio no tiene filtros; no se leyó toda la tabla.';
            exit(false);
        end;
        Campo.Get(Fuente."Id. Tabla", Fuente."No. Campo Valor");
        if Campo.Class <> Campo.Class::Normal then begin
            Motivo := 'Revisar: la fuente de cotización requiere un campo calculado y el contexto completo del motor.';
            exit(false);
        end;
        if Fuente."Función Agregado" in [Fuente."Función Agregado"::FILA_MAS_RECIENTE, Fuente."Función Agregado"::FILA_MAS_ANTIGUA] then begin
            Campo.Get(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio");
            if Campo.Type <> Campo.Type::Date then begin
                Motivo := 'Revisar: la función numérica de la fuente requiere una fecha, no una fecha y hora.';
                exit(false);
            end;
        end;
        ClearLastError();
        if not LeerCotizacion(Fuente, Moneda, FechaRef, FechaTC, Valor, Encontrada, Motivo) then begin
            Motivo := 'No se pudo comprobar la fuente de cotización: ' + GetLastErrorText();
            Clear(Valor);
            exit(false);
        end;
        if Motivo <> '' then
            exit(false);
        if not Encontrada then begin
            AusenciaConfirmada := true;
            Motivo := StrSubstNo('No hay cotización que cumpla los filtros de %1 al %2.', NombreFuente, FechaRef);
            exit(false);
        end;
        if Valor <= 0 then begin
            AusenciaConfirmada := true;
            Motivo := 'La fila de cotización existe, pero su valor no es positivo.';
            exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure LeerCotizacion(Fuente: Record "Fuente Datos Liquidación"; Moneda: Code[10]; FechaRef: Date; FechaTC: Date; var Valor: Decimal; var Encontrada: Boolean; var Motivo: Text)
    var
        Tabla: RecordRef;
        Filtro: Record "Filtro Fuente Datos Liq.";
        Actual: Decimal;
        Inicio: Date;
        MejorFecha: Date;
        Elegible: Boolean;
    begin
        Tabla.Open(Fuente."Id. Tabla");
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if Filtro.FindSet() then
            repeat
                if not FiltrarCotizacion(Tabla, Filtro."No. Campo", Filtro."Filtro Valor", Moneda, FechaRef, FechaTC, Motivo) then begin
                    Tabla.Close();
                    exit;
                end;
            until Filtro.Next() = 0;
        if not AplicarClave(Fuente, Tabla, Motivo) then begin
            Tabla.Close();
            exit;
        end;
        if Fuente."Función Agregado" = Fuente."Función Agregado"::LOOKUP then begin
            Encontrada := Tabla.FindLast();
            if Encontrada then
                Valor := ValorNumerico(Tabla.Field(Fuente."No. Campo Valor"));
        end else
            if Tabla.FindSet() then
                repeat
                    Elegible := true;
                    Inicio := 0D;
                    if Fuente."Función Agregado" in [Fuente."Función Agregado"::FILA_MAS_RECIENTE, Fuente."Función Agregado"::FILA_MAS_ANTIGUA] then begin
                        Inicio := ValorFecha(Tabla.Field(Fuente."No. Campo Fecha Inicio"));
                        Elegible := (Inicio <> 0D) and (Inicio <= FechaRef);
                    end;
                    if Elegible then begin
                        Actual := ValorNumerico(Tabla.Field(Fuente."No. Campo Valor"));
                        if not Encontrada or
                           ((Fuente."Función Agregado" = Fuente."Función Agregado"::MAX) and (Actual > Valor)) or
                           ((Fuente."Función Agregado" = Fuente."Función Agregado"::MIN) and (Actual < Valor)) or
                           ((Fuente."Función Agregado" = Fuente."Función Agregado"::FILA_MAS_RECIENTE) and (Inicio >= MejorFecha)) or
                           ((Fuente."Función Agregado" = Fuente."Función Agregado"::FILA_MAS_ANTIGUA) and (Inicio <= MejorFecha))
                        then begin
                            Valor := Actual;
                            MejorFecha := Inicio;
                        end;
                        Encontrada := true;
                    end;
                until Tabla.Next() = 0;
        Tabla.Close();
    end;

    local procedure FiltrarCotizacion(var Tabla: RecordRef; NoCampo: Integer; Texto: Text; Moneda: Code[10]; Fecha: Date; FechaTC: Date; var Motivo: Text): Boolean
    var
        Campo: FieldRef;
    begin
        if (NoCampo = 0) or (Texto = '') then
            exit(true);
        Texto := Texto.Replace('{MONEDA}', Moneda);
        Texto := Texto.Replace('{FECHA_REF}', Format(Fecha));
        Texto := Texto.Replace('{FECHA_TC}', Format(FechaTC));
        Texto := Texto.Replace('{AÑO_DESDE}', Format(DMY2Date(1, 1, Date2DMY(Fecha, 3))));
        if Texto.Contains('{') or Texto.Contains('}') then begin
            Motivo := 'Revisar: la fuente de cotización necesita un documento, empleado o ventana que aún no están determinados.';
            exit(false);
        end;
        Campo := Tabla.Field(CampoCanonico(Tabla.Number(), NoCampo));
        Campo.SetFilter(Texto);
        exit(true);
    end;

    local procedure AplicarClave(Fuente: Record "Fuente Datos Liquidación"; var Tabla: RecordRef; var Motivo: Text): Boolean
    var
        Clave: KeyRef;
        i: Integer;
        j: Integer;
        Elegida: Integer;
        Ultimo: Boolean;
    begin
        if Fuente."No. Campo Clave" = 0 then
            exit(true);
        for i := 1 to Tabla.KeyCount() do begin
            Clave := Tabla.KeyIndex(i);
            for j := 1 to Clave.FieldCount() do
                if (not Ultimo) and (Clave.FieldIndex(j).Number() = CampoCanonico(Fuente."Id. Tabla", Fuente."No. Campo Clave")) then begin
                    Ultimo := j = Clave.FieldCount();
                    if (Elegida = 0) or Ultimo then
                        Elegida := i;
                end;
        end;
        if Elegida = 0 then begin
            Motivo := 'Revisar: la fuente no tiene una clave compatible con el campo de ordenación.';
            exit(false);
        end;
        Tabla.CurrentKeyIndex(Elegida);
        Tabla.Ascending(not Fuente."Orden Descendente");
        exit(true);
    end;

    local procedure ComprobarCampo(IdTabla: Integer; NoCampo: Integer; Opcional: Boolean; Uso: Text; var Motivo: Text): Boolean
    var
        Campo: Record Field;
    begin
        if Opcional and (NoCampo = 0) then
            exit(true);
        if (NoCampo <> 0) then
            if Campo.Get(IdTabla, CampoCanonico(IdTabla, NoCampo)) then
                if Campo.Enabled and (Campo.ObsoleteState <> Campo.ObsoleteState::Removed) then
                    exit(true);
        Motivo := StrSubstNo('Falta o no existe el campo de %1 (%2) en la tabla %3.', Uso, NoCampo, IdTabla);
        exit(false);
    end;

    local procedure ComprobarFecha(IdTabla: Integer; NoCampo: Integer; var Motivo: Text): Boolean
    var
        Campo: Record Field;
    begin
        if NoCampo = 0 then
            exit(true);
        Campo.Get(IdTabla, CampoCanonico(IdTabla, NoCampo));
        if Campo.Type = Campo.Type::Date then
            exit(true);
        Motivo := StrSubstNo('El campo de fecha %1 no es Date. El resolvedor del motor no convierte DateTime para esta ventana.', NoCampo);
        exit(false);
    end;

    local procedure ComprobarFiltro(IdTabla: Integer; NoCampo: Integer; Texto: Text; var Motivo: Text): Boolean
    var
        Inicio: Integer;
        Fin: Integer;
        Token: Text;
        EsLiteral: Boolean;
        Original: Text;
    begin
        if (NoCampo = 0) and (Texto = '') then
            exit(true);
        if not ComprobarCampo(IdTabla, NoCampo, false, 'filtro', Motivo) then
            exit(false);
        Original := Texto;
        EsLiteral := not Texto.Contains('{');
        while Texto.Contains('{') do begin
            Inicio := StrPos(Texto, '{');
            Fin := StrPos(CopyStr(Texto, Inicio), '}');
            if Fin = 0 then begin
                Motivo := 'El filtro contiene un marcador sin llave de cierre.';
                exit(false);
            end;
            Token := CopyStr(Texto, Inicio + 1, Fin - 2);
            if not TokenConocido(Token) then begin
                Motivo := StrSubstNo('El filtro usa el marcador desconocido {%1}.', Token);
                exit(false);
            end;
            Texto := DelStr(Texto, Inicio, Fin);
        end;
        if Texto.Contains('}') then begin
            Motivo := 'El filtro contiene una llave de cierre sin marcador.';
            exit(false);
        end;
        if EsLiteral and (Original <> '') then
            if not ValidarFiltroLiteral(IdTabla, NoCampo, Original) then begin
                Motivo := 'El filtro literal no es válido para su campo: ' + GetLastErrorText();
                exit(false);
            end;
        exit(true);
    end;

    [TryFunction]
    local procedure ValidarFiltroLiteral(IdTabla: Integer; NoCampo: Integer; Texto: Text)
    var
        Tabla: RecordRef;
        Campo: FieldRef;
    begin
        // SetFilter comprueba sintaxis; no se ejecuta Find/Count ni se modifica ninguna fila.
        Tabla.Open(IdTabla);
        Campo := Tabla.Field(CampoCanonico(IdTabla, NoCampo));
        Campo.SetFilter(Texto);
        Tabla.Close();
    end;

    procedure TokenConocido(Token: Text): Boolean
    begin
        if Token in ['EMP_NO', 'JOB_NO', 'BUQUE', 'BUQUE_ULT_MAREA', 'PERIODO', 'LIQ_NO', 'MONEDA',
            'FECHA_REF', 'FECHA_TC', 'PERIODO_DESDE', 'AÑO_DESDE', 'SEM_DESDE', 'SEM_HASTA',
            'ASIG_DESDE', 'ASIG_HASTA', 'MAREA_DESDE', 'MAREA_HASTA', 'PROM_DESDE', 'PROM_HASTA',
            'AUS_PROM_HASTA', 'AUS_PROM6_DESDE', 'AUS_PROM12_DESDE',
            'ENF_PROM_HASTA', 'ENF_PROM6_DESDE', 'ENF_PROM12_DESDE']
        then
            exit(true);
        exit(TokenConArgumento(Token, 'ATRIB_DESDE:') or TokenConArgumento(Token, 'ATRIB_HASTA:') or
             TokenConArgumento(Token, 'PROM_LIC_DESDE:') or TokenConArgumento(Token, 'PROM_LIC_HASTA:'));
    end;

    local procedure TokenConArgumento(Token: Text; Prefijo: Text): Boolean
    begin
        exit(Token.StartsWith(Prefijo) and (StrLen(Token) > StrLen(Prefijo)) and not Token.Contains('{'));
    end;

    local procedure TieneFiltros(Fuente: Record "Fuente Datos Liquidación"): Boolean
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        Filtro.SetFilter("No. Campo", '<>0');
        Filtro.SetFilter("Filtro Valor", '<>%1', '');
        exit(not Filtro.IsEmpty());
    end;

    local procedure CampoCanonico(IdTabla: Integer; NoCampo: Integer): Integer
    begin
        if IdTabla = Database::"Employee Relative" then
            case NoCampo of
                50211: exit(50008);
                50212: exit(50009);
            end;
        exit(NoCampo);
    end;

    local procedure ValorNumerico(Campo: FieldRef): Decimal
    var
        Valor: Decimal;
    begin
        Valor := Campo.Value();
        exit(Valor);
    end;

    local procedure ValorFecha(Campo: FieldRef): Date
    var
        FechaHora: DateTime;
        Fecha: Date;
    begin
        if Campo.Type() = FieldType::DateTime then begin
            FechaHora := Campo.Value();
            exit(DT2Date(FechaHora));
        end;
        Fecha := Campo.Value();
        exit(Fecha);
    end;

    local procedure Agregar(var Buffer: Record "Control Previo Liq. Buffer" temporary; Fuente: Record "Fuente Datos Liquidación"; Desde: Date; Hasta: Date; Nivel: Enum "Severidad Registro Liq."; Motivo: Text)
    var
        Numero: Integer;
    begin
        Buffer.Reset();
        if Buffer.FindLast() then
            Numero := Buffer."No. Línea";
        Buffer.Init();
        Buffer."No. Línea" := Numero + 1;
        Buffer.Severidad := Nivel;
        Buffer.Área := 'Fuente de datos';
        Buffer."Nombre Variable" := Fuente."Nombre Variable";
        Buffer."Nombre Fuente" := Fuente."Nombre Variable";
        Buffer."Fecha Desde" := Desde;
        Buffer."Fecha Hasta" := Hasta;
        Buffer.Mensaje := CopyStr(Motivo, 1, MaxStrLen(Buffer.Mensaje));
        Buffer.Detalle := 'Abrir la fuente y revisar tabla, campos y filtros. No se ejecutó la fuente ni se modificó su configuración.';
        Buffer.Repeticiones := 1;
        Buffer.Insert();
    end;
}
