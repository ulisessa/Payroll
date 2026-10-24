namespace UAS.Payroll;

// Busca dónde se usa un símbolo del motor.
//
// LOS OCHO LUGARES. Un símbolo puede estar nombrado en:
//     1. la Fórmula de un concepto          5. el filtro de una Fuente de Datos
//     2. su Condición                       6. una Fracción, en las DOS direcciones: quién le aporta
//     3. su Variable Cantidad                  al símbolo y a qué acumuladores aporta él
//     4. su Variable Base                   7. la definición de una Variable de Sistema
//                                           8. los campos de Concepto que apuntan por código:
//                                              Cód. Parámetro Valor y los dos tipos de atributo
// El que se olvida al revisar a mano es siempre el que rompe. La fracción hacia adelante —punto 6— es
// la que más se olvida: un concepto puede no estar nombrado en ninguna fórmula y mover plata igual,
// porque entra a una base por su fracción.
//
// CÓMO BUSCA. Por texto, pero con los bordes marcados: DIAS no debe encontrar DIAS_MAREA, ni 1053
// encontrar 10530 o 41053. Sin eso la lista se llena de falsos positivos y deja de servir, que es lo
// que pasa con un LIKE a mano. El # y el @ que preceden a un concepto sí cuentan como borde, porque
// son parte de cómo se lo nombra.
//
// LO QUE NO ES. No es un analizador: encuentra el nombre, no entiende la fórmula. Un símbolo dentro
// de un literal, o un número suelto que coincide con un código, aparecerían igual. Para lo que sirve
// —saber a quién le afecta tocar algo, y ver quién lo lee antes de que esté listo— alcanza, y el
// fragmento deja juzgar el resto.
//
// LA VIGENCIA, NO "Activo". El campo Activo de Concepto está marcado para quitar: no tiene efecto en
// el cálculo, la baja se expresa con Vigencia Hasta. Filtrar por Activo esconderría config viva —hay
// 45 versiones con Activo en falso—, así que acá el corte es siempre por fechas.
codeunit 110058 "Buscar Usos Liq."
{
    Access = Public;

    var
        TipoConceptoTok: Label 'Concepto';
        TipoFuenteTok: Label 'Fuente de Datos';
        TipoAcumuladorTok: Label 'Aportante del acum.';
        TipoAportaATok: Label 'Aporta al acumulador';
        TipoVarSistemaTok: Label 'Variable de Sistema';
        CampoFormulaTok: Label 'Fórmula';
        CampoCondicionTok: Label 'Condición';
        CampoVarCantidadTok: Label 'Variable Cantidad';
        CampoVarBaseTok: Label 'Variable Base';
        CampoParametroTok: Label 'Cód. Parámetro Valor';
        CampoAtribDetalleTok: Label 'Tipo Atributo Detalle';
        CampoAtribPrecioTok: Label 'Tipo Atributo Precio';
        CampoFiltroTok: Label 'Filtro';
        CampoApuntaTok: Label 'Apunta a';
        CampoFraccionTok: Label 'Fracción';
        PorcentajeTok: Label 'aporta el %1 %%', Comment = '%1 = porcentaje de la fracción';
        PorcentajeInvTok: Label 'aporta el %1 %% con signo invertido', Comment = '%1 = porcentaje';
        // Las letras que pueden formar parte del nombre de un símbolo. AL no tiene Char.IsLetter, y
        // la lista explícita además deja claro que la Ñ cuenta: AÑOS_ANTIGUEDAD es un símbolo real.
        LetrasNombreTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ0123456789_', Locked = true;
        FConSufijos: Boolean;

    // Llena el buffer con todos los usos del símbolo.
    //
    // SoloVigentes deja afuera las vigencias ya cerradas y las que todavía no arrancaron: sirve para
    // ver el motor de hoy, no su historia.
    //
    // ConSufijos encuentra también las formas sufijadas, que es el caso de un PARÁMETRO: el parámetro
    // se llama PRECIO_NAV y la fórmula puede nombrar PRECIO_NAV_LAN. Apagado por omisión, porque
    // relajar el borde derecho es justamente lo que hace que DIAS encuentre DIAS_MAREA.
    procedure Buscar(Simbolo: Code[50]; SoloVigentes: Boolean; ConSufijos: Boolean; var Buffer: Record "Uso Símbolo Liq." temporary)
    var
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        FiltroFuente: Record "Filtro Fuente Datos Liq.";
        Fraccion: Record "Fracción Acumulador";
        VarSist: Record "Variable Sistema Liq.";
        Linea: Integer;
        OrdenListo: Integer;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        FConSufijos := ConSufijos;
        Simbolo := UpperCase(Simbolo);
        if Simbolo = '' then
            exit;

        OrdenListo := OrdenSimboloListo(Simbolo);

        // ---- conceptos
        if Concepto.FindSet() then
            repeat
                if not (SoloVigentes and not EsVigente(Concepto."Vigencia Desde", Concepto."Vigencia Hasta")) then begin
                    AgregarDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoFormulaTok, Concepto.Fórmula, OrdenListo);
                    AgregarDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoCondicionTok, Concepto.Condición, OrdenListo);
                    AgregarDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoVarCantidadTok, Concepto."Variable Cantidad", OrdenListo);
                    AgregarDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoVarBaseTok, Concepto."Variable Base", OrdenListo);
                    // El valor del franco es una fórmula (nombres de parámetro): se busca por texto.
                    AgregarDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoParametroTok, Concepto."Cód. Parámetro Valor", OrdenListo);
                    // Estos dos apuntan por código, no por texto: la coincidencia es exacta.
                    ApuntaDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoAtribDetalleTok, Concepto."Cód. Tipo Atributo Detalle", OrdenListo);
                    ApuntaDeConcepto(Buffer, Linea, Simbolo, Concepto, CampoAtribPrecioTok, Concepto."Cód. Tipo Atributo Precio", OrdenListo);
                end;
            until Concepto.Next() = 0;

        // ---- fuentes de datos
        if SoloVigentes then
            Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                // Los tres Filtro Valor de la cabecera están marcados para quitar en favor de la
                // subtabla, pero la migración no terminó: 29, 27 y 2 fuentes de 56 siguen usándolos.
                // Dejarlos afuera abriría en esta vista exactamente el agujero que viene a tapar.
                AgregarSuelto(Buffer, Linea, Simbolo, TipoFuenteTok, Fuente."Nombre Variable",
                    Fuente.Descripción, CampoFiltroTok, Fuente."Filtro Valor 1", OrdenListo, Fuente.Activo);
                AgregarSuelto(Buffer, Linea, Simbolo, TipoFuenteTok, Fuente."Nombre Variable",
                    Fuente.Descripción, CampoFiltroTok, Fuente."Filtro Valor 2", OrdenListo, Fuente.Activo);
                AgregarSuelto(Buffer, Linea, Simbolo, TipoFuenteTok, Fuente."Nombre Variable",
                    Fuente.Descripción, CampoFiltroTok, Fuente."Filtro Valor 3", OrdenListo, Fuente.Activo);

                FiltroFuente.SetRange("Nombre Variable", Fuente."Nombre Variable");
                if FiltroFuente.FindSet() then
                    repeat
                        AgregarSuelto(Buffer, Linea, Simbolo, TipoFuenteTok, Fuente."Nombre Variable",
                            Fuente.Descripción, CampoFiltroTok, FiltroFuente."Filtro Valor", OrdenListo, Fuente.Activo);
                    until FiltroFuente.Next() = 0;
            until Fuente.Next() = 0;

        // ---- quién le APORTA al símbolo, si el símbolo es un acumulador.
        // No es un uso en una fórmula, pero es la otra mitad de la pregunta: un acumulador se arma
        // con sus aportantes y el orden de ELLOS decide si está completo cuando alguien lo lee.
        Fraccion.SetRange("Cód. Acumulador", CopyStr(Simbolo, 1, 20));
        if Fraccion.FindSet() then
            repeat
                Linea += 1;
                Buffer.Init();
                Buffer."No. Línea" := Linea;
                Buffer.Símbolo := Simbolo;
                Buffer."Tipo Uso" := CopyStr(TipoAcumuladorTok, 1, 30);
                Buffer."Cód. Objeto" := Fraccion."Cód. Concepto";
                Buffer."Descripción Objeto" := CopyStr(DescripcionConcepto(Fraccion."Cód. Concepto"), 1, 100);
                Buffer.Campo := CopyStr(CampoFormulaTok, 1, 30);
                Buffer."Orden Cálculo" := OrdenDeConcepto(Fraccion."Cód. Concepto");
                Buffer."Orden Símbolo Listo" := OrdenListo;
                if Fraccion."Invertir Signo" then
                    Buffer.Fragmento := CopyStr(StrSubstNo(PorcentajeInvTok, Fraccion.Porcentaje), 1, 250)
                else
                    Buffer.Fragmento := CopyStr(StrSubstNo(PorcentajeTok, Fraccion.Porcentaje), 1, 250);
                Buffer.Vigente := true;
                Buffer."Vigencia Desde" := Fraccion."Vigencia Desde";
                Buffer.Insert();
            until Fraccion.Next() = 0;

        // ---- y la dirección CONTRARIA: a qué acumuladores le aporta el símbolo.
        //
        // ESTA ES LA MITAD QUE SE OLVIDA, y es la que importa más seguido. Un concepto puede no estar
        // nombrado en ninguna fórmula y seguir moviendo plata, porque entra a una base por su
        // fracción. El 4751 es el caso: no lo nombra ninguna fórmula, y sin embargo aporta el 100 % a
        // GAN_NETA_MES, GAN_NETA_A_DEDUC y SS_SAC_DEV. Sin esta vuelta la respuesta sería "casi no se
        // usa", que es exactamente lo contrario de la verdad.
        Fraccion.Reset();
        Fraccion.SetRange("Cód. Concepto", CopyStr(Simbolo, 1, 20));
        if Fraccion.FindSet() then
            repeat
                Linea += 1;
                Buffer.Init();
                Buffer."No. Línea" := Linea;
                Buffer.Símbolo := Simbolo;
                Buffer."Tipo Uso" := CopyStr(TipoAportaATok, 1, 30);
                Buffer."Cód. Objeto" := Fraccion."Cód. Acumulador";
                Buffer."Descripción Objeto" := CopyStr(DescripcionConcepto(Fraccion."Cód. Acumulador"), 1, 100);
                Buffer.Campo := CopyStr(CampoFraccionTok, 1, 30);
                // Acá el orden que interesa es el del ACUMULADOR, que es quien recibe.
                Buffer."Orden Cálculo" := OrdenDeConcepto(Fraccion."Cód. Acumulador");
                Buffer."Orden Símbolo Listo" := OrdenDeConcepto(CopyStr(Simbolo, 1, 20));
                if Fraccion."Invertir Signo" then
                    Buffer.Fragmento := CopyStr(StrSubstNo(PorcentajeInvTok, Fraccion.Porcentaje), 1, 250)
                else
                    Buffer.Fragmento := CopyStr(StrSubstNo(PorcentajeTok, Fraccion.Porcentaje), 1, 250);
                Buffer.Vigente := true;
                Buffer."Vigencia Desde" := Fraccion."Vigencia Desde";
                Buffer.Insert();
            until Fraccion.Next() = 0;

        // ---- variables de sistema que apuntan al símbolo
        if SoloVigentes then
            VarSist.SetRange(Activo, true);
        if VarSist.FindSet() then
            repeat
                AgregarSuelto(Buffer, Linea, Simbolo, TipoVarSistemaTok, VarSist."Cód. Cálculo",
                    VarSist.Descripción, CampoApuntaTok, ExactoOVacio(Simbolo, VarSist."Cód. Acumulador"),
                    OrdenListo, VarSist.Activo);
                AgregarSuelto(Buffer, Linea, Simbolo, TipoVarSistemaTok, VarSist."Cód. Cálculo",
                    VarSist.Descripción, CampoApuntaTok, ExactoOVacio(Simbolo, VarSist."Cód. Concepto"),
                    OrdenListo, VarSist.Activo);
            until VarSist.Next() = 0;

        if Buffer.FindFirst() then;
    end;

    // ------------------------------------------------------------------ orden en que está listo

    // El orden a partir del cual el símbolo ya vale lo que va a valer.
    //
    // Para un concepto común es su propio Orden Cálculo. Para un ACUMULADOR es el de su último
    // aportante, que es más tarde —a veces mucho más tarde— que el del acumulador mismo. Confundir
    // los dos es precisamente el error que esta vista existe para encontrar: el acumulador está
    // creado desde el principio y devuelve un número; el número sólo está COMPLETO al final.
    procedure OrdenSimboloListo(Simbolo: Code[50]): Integer
    var
        Fraccion: Record "Fracción Acumulador";
        Orden: Integer;
        OrdenAportante: Integer;
    begin
        Orden := OrdenDeConcepto(CopyStr(UpperCase(Simbolo), 1, 20));

        Fraccion.SetRange("Cód. Acumulador", CopyStr(UpperCase(Simbolo), 1, 20));
        if Fraccion.FindSet() then
            repeat
                OrdenAportante := OrdenDeConcepto(Fraccion."Cód. Concepto");
                if OrdenAportante > Orden then
                    Orden := OrdenAportante;
            until Fraccion.Next() = 0;

        exit(Orden);
    end;

    // ------------------------------------------------------------------ alta de filas

    local procedure AgregarDeConcepto(var Buffer: Record "Uso Símbolo Liq." temporary; var Linea: Integer;
        Simbolo: Code[50]; var Concepto: Record "Concepto Liquidación"; Campo: Text; Texto: Text; OrdenListo: Integer)
    begin
        Agregar(Buffer, Linea, Simbolo, TipoConceptoTok, Concepto.Código, Concepto.Descripción, Campo, Texto,
            Concepto."Orden Cálculo", OrdenListo,
            EsVigente(Concepto."Vigencia Desde", Concepto."Vigencia Hasta"),
            Concepto."Vigencia Desde", Concepto."Vigencia Hasta", true);
    end;

    // Para los campos de Concepto que apuntan por código: la coincidencia es exacta, sin bordes.
    local procedure ApuntaDeConcepto(var Buffer: Record "Uso Símbolo Liq." temporary; var Linea: Integer;
        Simbolo: Code[50]; var Concepto: Record "Concepto Liquidación"; Campo: Text; Valor: Code[30]; OrdenListo: Integer)
    begin
        Agregar(Buffer, Linea, Simbolo, TipoConceptoTok, Concepto.Código, Concepto.Descripción, Campo,
            ExactoOVacio(Simbolo, Valor), Concepto."Orden Cálculo", OrdenListo,
            EsVigente(Concepto."Vigencia Desde", Concepto."Vigencia Hasta"),
            Concepto."Vigencia Desde", Concepto."Vigencia Hasta", false);
    end;

    local procedure AgregarSuelto(var Buffer: Record "Uso Símbolo Liq." temporary; var Linea: Integer;
        Simbolo: Code[50]; TipoUso: Text; CodObjeto: Code[50]; Descripcion: Text; Campo: Text;
        Texto: Text; OrdenListo: Integer; EstaVigente: Boolean)
    begin
        // Orden 0: una fuente de datos y una variable de sistema se resuelven ANTES del bucle de
        // conceptos, así que no pueden llegar tarde y la columna no las marca.
        Agregar(Buffer, Linea, Simbolo, TipoUso, CodObjeto, Descripcion, Campo, Texto,
            0, OrdenListo, EstaVigente, 0D, 0D, true);
    end;

    local procedure Agregar(var Buffer: Record "Uso Símbolo Liq." temporary; var Linea: Integer;
        Simbolo: Code[50]; TipoUso: Text; CodObjeto: Code[50]; Descripcion: Text; Campo: Text;
        Texto: Text; OrdenUsuario: Integer; OrdenListo: Integer; EstaVigente: Boolean;
        VigDesde: Date; VigHasta: Date; PorTexto: Boolean)
    var
        Pos: Integer;
    begin
        if Texto = '' then
            exit;
        if PorTexto then begin
            Pos := PosicionConBordes(Texto, Simbolo);
            if Pos = 0 then
                exit;
        end else
            Pos := 1;

        Linea += 1;
        Buffer.Init();
        Buffer."No. Línea" := Linea;
        Buffer.Símbolo := Simbolo;
        Buffer."Tipo Uso" := CopyStr(TipoUso, 1, 30);
        Buffer."Cód. Objeto" := CodObjeto;
        Buffer."Descripción Objeto" := CopyStr(Descripcion, 1, 100);
        Buffer.Campo := CopyStr(Campo, 1, 30);
        Buffer."Orden Cálculo" := OrdenUsuario;
        Buffer."Orden Símbolo Listo" := OrdenListo;
        // La señal que importa: quien lee antes de que el símbolo esté listo recibe cero o un valor
        // a medio llenar, y no hay error. Sólo entre conceptos —los únicos con orden— y nunca contra
        // sí mismo, que es el caso legítimo de un concepto que aporta a su propio acumulador.
        Buffer."Lee Antes de Estar Listo" :=
            (OrdenListo > 0) and (OrdenUsuario > 0) and (OrdenUsuario < OrdenListo) and
            (UpperCase(CodObjeto) <> Simbolo);
        Buffer.Fragmento := CopyStr(Fragmento(Texto, Pos), 1, 250);
        Buffer.Vigente := EstaVigente;
        Buffer."Vigencia Desde" := VigDesde;
        Buffer."Vigencia Hasta" := VigHasta;
        Buffer.Insert();
    end;

    // ------------------------------------------------------------------ búsqueda con bordes

    // Dónde aparece el símbolo como palabra entera, o 0 si no aparece.
    //
    // LOS BORDES SON EL PUNTO. Una búsqueda por subcadena de DIAS encuentra DIAS_MAREA,
    // DIAS_GP_PERIODO y veinte más, y la lista deja de servir. Un símbolo está entero cuando lo que
    // lo rodea no es letra, dígito ni guion bajo.
    local procedure PosicionConBordes(Texto: Text; Simbolo: Code[50]): Integer
    var
        Mayus: Text;
        Desde: Integer;
        Pos: Integer;
        Corrido: Integer;
        Largo: Integer;
    begin
        // UpperCase no cambia el largo, así que las posiciones siguen valiendo para el texto original.
        Mayus := UpperCase(Texto);
        Largo := StrLen(Mayus);
        Desde := 1;
        while Desde <= Largo do begin
            Pos := StrPos(CopyStr(Mayus, Desde), Simbolo);
            if Pos = 0 then
                exit(0);
            Corrido := Desde + Pos - 1;
            if EsBorde(Mayus, Corrido - 1, false) and EsBorde(Mayus, Corrido + StrLen(Simbolo), true) then
                exit(Corrido);
            Desde := Corrido + 1;
        end;
        exit(0);
    end;

    // Fuera del texto cuenta como borde; dentro, cualquier cosa que no forme parte de un nombre.
    //
    // El borde DERECHO admite un guion bajo cuando se buscan sufijos: PRECIO_NAV_LAN es un uso de
    // PRECIO_NAV, pero DIAS_MAREA no es un uso de DIAS, y por eso la puerta no queda abierta sola.
    local procedure EsBorde(Texto: Text; Pos: Integer; EsDerecho: Boolean): Boolean
    var
        C: Char;
    begin
        if (Pos < 1) or (Pos > StrLen(Texto)) then
            exit(true);
        C := Texto[Pos];
        if EsDerecho and FConSufijos and (C = '_') then
            exit(true);
        exit(StrPos(LetrasNombreTok, Format(C)) = 0);
    end;

    // Un pedazo de texto alrededor de la aparición, para ver el contexto sin abrir el concepto.
    local procedure Fragmento(Texto: Text; Pos: Integer): Text
    var
        Limpio: Text;
        Desde: Integer;
        Largo: Integer;
    begin
        Limpio := UnaSolaLinea(Texto);
        if StrLen(Limpio) <= 120 then
            exit(Limpio);
        Desde := Pos - 40;
        if Desde < 1 then
            Desde := 1;
        Largo := 120;
        if Desde + Largo - 1 > StrLen(Limpio) then
            Largo := StrLen(Limpio) - Desde + 1;
        exit(CopyStr(Limpio, Desde, Largo));
    end;

    // Las fórmulas son multilínea y en una grilla eso no se ve: los saltos pasan a espacios.
    local procedure UnaSolaLinea(Texto: Text): Text
    var
        CR: Char;
        LF: Char;
        Tabulador: Char;
        Blancos: Text;
    begin
        CR := 13;
        LF := 10;
        Tabulador := 9;
        Blancos := Format(CR) + Format(LF) + Format(Tabulador);
        exit(DelChr(ConvertStr(Texto, Blancos, '   '), '<>', ' '));
    end;

    // ------------------------------------------------------------------ auxiliares

    local procedure ExactoOVacio(Simbolo: Code[50]; Valor: Code[30]): Text
    begin
        if (Valor <> '') and (UpperCase(Valor) = Simbolo) then
            exit(Valor);
        exit('');
    end;

    // Vigente HOY. 0D y 31/12/9999 son las dos maneras de decir abierta que conviven en los datos.
    local procedure EsVigente(VigenciaDesde: Date; VigenciaHasta: Date): Boolean
    begin
        if (VigenciaDesde <> 0D) and (VigenciaDesde > Today()) then
            exit(false);
        if (VigenciaHasta = 0D) or (VigenciaHasta >= DMY2Date(31, 12, 9999)) then
            exit(true);
        exit(VigenciaHasta >= Today());
    end;

    local procedure OrdenDeConcepto(Codigo: Code[20]): Integer
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Codigo = '' then
            exit(0);
        Concepto.SetRange(Código, Codigo);
        if not Concepto.FindSet() then
            exit(0);
        // La vigencia vigente hoy; si ninguna lo está, la última, que sirve igual para ubicarlo.
        repeat
            if EsVigente(Concepto."Vigencia Desde", Concepto."Vigencia Hasta") then
                exit(Concepto."Orden Cálculo");
        until Concepto.Next() = 0;
        if Concepto.FindLast() then
            exit(Concepto."Orden Cálculo");
        exit(0);
    end;

    local procedure DescripcionConcepto(Codigo: Code[20]): Text
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Codigo);
        if Concepto.FindLast() then
            exit(Concepto.Descripción);
        exit('');
    end;
}
