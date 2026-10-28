namespace UAS.Payroll;

using System.IO;
using Microsoft.HumanResources.Employee;

/// <summary>
/// Reporte mensual para SICOSS en Excel: una fila por empleado y mes, con las cuatro hojas de la
/// planilla que se venía armando a mano (TOTALES, CNT, FSR y Dto 814).
/// </summary>
/// <remarks>
/// REPRODUCE LA PLANILLA EXISTENTE A PROPÓSITO, con sus nombres de hoja y de columna. La declaración
/// de SICOSS se arma, se discute y se archiva en ese formato desde antes de BC; un Excel con otras
/// columnas obliga a traducir mes a mes y hace imposible comparar contra los meses de Meta4, que es
/// justamente lo que hay que hacer durante la corrida en paralelo.
///
/// LA UNIDAD ES EL EMPLEADO Y EL MES, no la liquidación. Un tripulante puede tener en el mismo mes
/// una liquidación regular, un cierre de marea y una de vacaciones; SICOSS declara una línea por
/// CUIL. Los acumuladores se suman entre liquidaciones y los topes se aplican UNA vez sobre la suma,
/// que es cómo los aplica la ley y cómo los trabaja el motor con sus variables MES_/PERIODO_.
///
/// LAS BASES SALEN DE LOS ACUMULADORES Y LOS IMPORTES DE LOS CONCEPTOS, los dos leídos de lo que el
/// motor dejó calculado. Nada se recalcula acá: si el reporte recalculara, podría decir una cosa y el
/// recibo otra, y no habría manera de saber cuál de los dos tiene razón.
///
/// LO QUE SÍ RECALCULA LA PLANILLA son las contribuciones, y eso no es un descuido: la planilla
/// original existe para eso —tomar las bases y volver a aplicar las alícuotas, para comparar contra
/// lo declarado—. Por eso las columnas de montos de CNT y FSR salen como FÓRMULAS de Excel sobre la
/// base y el porcentaje, y al lado va lo que BC liquidó de verdad con la diferencia entre ambos. Una
/// diferencia distinta de cero es un dato, no un error de la planilla.
///
/// LOS DEVENGOS NO SE DECLARAN. La familia 475x (jubilación, ley 19032, obra social y cuota sindical
/// sobre el SAC devengado) es una provisión contable: se calcula todos los meses pero no se aporta
/// hasta que el SAC se paga. El reporte saltea toda línea con "Es Devengo", así que no hace falta
/// excluir el tipo de liquidación DEVENGADOS a mano.
/// </remarks>
codeunit 110064 "Reporte SICOSS Liq."
{
    Access = Public;

    /// <summary>
    /// Arma el libro y lo baja. TiposLiq vacío = todos los tipos de liquidación del período.
    /// </summary>
    procedure Generar(CodPeriodo: Code[10]; TiposLiq: Text; IncluirBorradores: Boolean)
    var
        Periodo: Record "Período Liquidación";
        Libro: Record "Excel Buffer" temporary;
        LibroCnt: Record "Excel Buffer" temporary;
        LibroFsr: Record "Excel Buffer" temporary;
        LibroDto: Record "Excel Buffer" temporary;
        LibroAvisos: Record "Excel Buffer" temporary;
    begin
        if CodPeriodo = '' then
            Error(ErrSinPeriodo);
        if not Periodo.Get(CodPeriodo) then
            Error(ErrPeriodoInexistente, CodPeriodo);

        FPeriodo := CodPeriodo;
        FFechaDesde := Periodo."Fecha Desde";
        FFechaHasta := Periodo."Fecha Hasta";
        FTiposLiq := TiposLiq;
        FIncluirBorradores := IncluirBorradores;

        ExigirMapeo();
        LeerParametros();
        Recolectar();
        if FEmpleados.Count() = 0 then
            Error(ErrSinLiquidaciones, CodPeriodo);
        OrdenarZonas();

        Libro.CreateNewBook(HojaTotalesTok);
        EscribirTotales(Libro);
        Libro.WriteSheet(HojaTotalesTok, CompanyName(), UserId());

        // Cada hoja se arma en su PROPIO buffer y no vaciando el primero: "Excel Buffer" guarda el
        // WorkbookWriter de .NET en una global de la tabla, o sea en la variable. Vaciar con DeleteAll
        // para reusarla deja el writer sin instanciar y SelectOrAddSheet muere con "No se pudo crear
        // el libro de Excel", con la primera hoja ya escrita y el informe reventando al final.
        // Es el mismo patrón que usa la base en WriteSheet con su hoja de información.
        EscribirCnt(LibroCnt);
        Libro.SelectOrAddSheet(HojaCntTok);
        Libro.WriteAllToCurrentSheet(LibroCnt);

        EscribirFsr(LibroFsr);
        Libro.SelectOrAddSheet(HojaFsrTok);
        Libro.WriteAllToCurrentSheet(LibroFsr);

        EscribirDto814(LibroDto);
        Libro.SelectOrAddSheet(HojaDtoTok);
        Libro.WriteAllToCurrentSheet(LibroDto);

        // La hoja de Avisos va SIEMPRE, incluso sin nada que avisar: una hoja que aparece sólo cuando
        // hay problemas se busca y, al no estar, deja la duda de si el control corrió.
        EscribirAvisos(LibroAvisos);
        Libro.SelectOrAddSheet(HojaAvisosTok);
        Libro.WriteAllToCurrentSheet(LibroAvisos);

        Libro.CloseBook();
        Libro.OpenExcel();
    end;

    /// <summary>
    /// Resumen de una línea para mostrar en la página antes de generar, sin escribir el Excel.
    /// </summary>
    procedure Resumen(CodPeriodo: Code[10]; TiposLiq: Text; IncluirBorradores: Boolean): Text
    var
        Periodo: Record "Período Liquidación";
    begin
        if (CodPeriodo = '') or not Periodo.Get(CodPeriodo) then
            exit('');

        FPeriodo := CodPeriodo;
        FFechaDesde := Periodo."Fecha Desde";
        FFechaHasta := Periodo."Fecha Hasta";
        FTiposLiq := TiposLiq;
        FIncluirBorradores := IncluirBorradores;
        LeerParametros();
        Recolectar();

        exit(StrSubstNo(
            TxtResumen,
            FEmpleados.Count(), FLiquidaciones, FSinMapear.Count(),
            FSinZona.Count(), FSinCuil.Count(), FFaltanParametros.Count()));
    end;

    /// <remarks>
    /// Si NINGÚN concepto tiene columna asignada, el reporte saldría completo y prolijo con las seis
    /// columnas de descuentos y las siete de contribuciones en cero, y las bases bien: la clase de
    /// planilla que se archiva sin mirar porque parece correcta. Es la única condición que se frena
    /// antes de empezar; que falte el mapeo de ALGUNOS conceptos no se frena, se avisa.
    /// </remarks>
    local procedure ExigirMapeo()
    var
        Concepto: Record "Concepto Liquidación";
        Columna: Enum "Columna SICOSS Liq.";
    begin
        Concepto.SetFilter("Columna SICOSS", '<>%1', Columna::" ");
        if Concepto.IsEmpty() then
            Error(ErrSinMapeo);
    end;

    /// <summary>
    /// Propone la Columna SICOSS de los conceptos que la tengan en blanco. Devuelve cuántos tocó.
    /// </summary>
    /// <remarks>
    /// ES UNA PROPUESTA Y NO UNA DERIVACIÓN, y por eso se escribe en el campo en vez de resolverse
    /// en vivo: el grupo del costo laboral y el tipo de concepto alcanzan para la mayoría, pero
    /// adentro del grupo Seguridad Social hay que distinguir jubilación de INSSJP, de asignaciones
    /// familiares y de fondo nacional de empleo, y eso sólo se puede adivinar por la descripción.
    /// Adivinar en vivo, en cada corrida, es mucho peor que adivinar una vez y dejar el resultado a
    /// la vista para corregirlo.
    ///
    /// SÓLO COMPLETA LO QUE ESTÁ EN BLANCO. Nunca pisa una columna ya asignada: la asignación a mano
    /// es la que manda, y una corrida de esto no puede deshacerla.
    ///
    /// LOS DEVENGOS QUEDAN AFUERA. La familia 475x tiene grupo y tipo de un aporte real, así que la
    /// derivación por grupo le pondría una columna; pero un devengo no se declara, y dejarle la
    /// columna en blanco es lo correcto —y además es lo que hace que no aparezca en Avisos, porque el
    /// reporte saltea las líneas de devengo antes de mirar la columna—.
    /// </remarks>
    procedure ProponerColumnas() Cant: Integer
    var
        Concepto: Record "Concepto Liquidación";
        Columna: Enum "Columna SICOSS Liq.";
    begin
        Concepto.SetRange("Columna SICOSS", Columna::" ");
        Concepto.SetRange("Es Devengo", false);
        Concepto.SetFilter("Tipo Concepto", '%1|%2|%3|%4',
            Concepto."Tipo Concepto"::"Descuento Empleado",
            Concepto."Tipo Concepto"::"Contribución Patronal",
            Concepto."Tipo Concepto"::Retención,
            Concepto."Tipo Concepto"::"Seguridad Social");
        if not Concepto.FindSet(true) then
            exit(0);

        repeat
            Columna := ColumnaPropuesta(Concepto);
            if Columna <> Columna::" " then begin
                Concepto."Columna SICOSS" := Columna;
                Concepto.Modify();
                Cant += 1;
            end;
        until Concepto.Next() = 0;
    end;

    local procedure ColumnaPropuesta(var Concepto: Record "Concepto Liquidación"): Enum "Columna SICOSS Liq."
    var
        Columna: Enum "Columna SICOSS Liq.";
        Desc: Text;
    begin
        Desc := LowerCase(Concepto.Descripción);

        case Concepto."Tipo Concepto" of
            Concepto."Tipo Concepto"::Retención:
                if Desc.Contains('ganancia') then
                    exit(Columna::"Impuesto a las Ganancias");

            Concepto."Tipo Concepto"::"Descuento Empleado":
                if Concepto."Grupo Costo Laboral" = "Grupo Costo Laboral Liq."::Sindical then
                    exit(Columna::"Cuota Sindical");

            Concepto."Tipo Concepto"::"Seguridad Social":
                case Concepto."Grupo Costo Laboral" of
                    "Grupo Costo Laboral Liq."::"Obra Social":
                        if Desc.Contains('adicional') then
                            exit(Columna::"Aporte Adicional OS")
                        else
                            exit(Columna::"Aporte Obra Social");
                    "Grupo Costo Laboral Liq."::INSSJP:
                        exit(Columna::"Aporte INSSJP");
                    "Grupo Costo Laboral Liq."::"Seguridad Social":
                        // El 6010 y el 6013 están en el grupo Seguridad Social y no en INSSJP, así
                        // que la ley hay que buscarla en la descripción.
                        if Desc.Contains('19032') or Desc.Contains('inssjp') or Desc.Contains('pami') then
                            exit(Columna::"Aporte INSSJP")
                        else
                            exit(Columna::"Aporte Jubilación");
                end;

            Concepto."Tipo Concepto"::"Contribución Patronal":
                begin
                    if Desc.Contains('diferencial') then
                        exit(Columna::"Contribución Tarea Diferencial");
                    case Concepto."Grupo Costo Laboral" of
                        "Grupo Costo Laboral Liq."::"Obra Social":
                            exit(Columna::"Contribución Obra Social");
                        "Grupo Costo Laboral Liq."::INSSJP:
                            exit(Columna::"Contribución INSSJP");
                        "Grupo Costo Laboral Liq."::ART:
                            exit(Columna::"Contribución ART");
                        "Grupo Costo Laboral Liq."::SCVO:
                            exit(Columna::"Contribución SCVO");
                        "Grupo Costo Laboral Liq."::"Seguridad Social":
                            begin
                                if Desc.Contains('familiar') then
                                    exit(Columna::"Contribución Asig. Familiares");
                                // 'empleo' y no 'desempleo': el 7070 se llama "Fondo Nacional de
                                // Empleo" y buscando 'desempleo' caía en la jubilación —18 M en la
                                // columna equivocada, sin que nada avise porque la columna existía—.
                                if Desc.Contains('empleo') or Desc.Contains('fne') then
                                    exit(Columna::"Contribución FNE");
                                if Desc.Contains('seguro de vida') or Desc.Contains('svo') or Desc.Contains('scvo') then
                                    exit(Columna::"Contribución SCVO");
                                exit(Columna::"Contribución Jubilación");
                            end;
                    end;
                end;
        end;

        exit(Columna::" ");
    end;

    // ── Recolección ───────────────────────────────────────────────────────────

    /// <remarks>
    /// Recorre las liquidaciones del período por empleado y, dentro de cada una, sus líneas. El bucle
    /// externo es por LIQUIDACIÓN y no por línea del período aunque las líneas tengan "Cód. Período":
    /// la base de contribuciones se arma por liquidación —cada una resta su propia detracción— y sólo
    /// después se suma al mes, así que hay que poder cerrar el cálculo de una liquidación antes de
    /// pasar a la siguiente.
    /// </remarks>
    local procedure Recolectar()
    var
        Liq: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Emp: Code[20];
        BaseIG4Liq: Decimal;
        DetraccionLiq: Decimal;
    begin
        Clear(FEmpleados);
        Clear(FNombre);
        Clear(FVal);
        Clear(FZona);
        Clear(FObraSocial);
        Clear(FConvenio);
        Clear(FDias);
        Clear(FSinMapear);
        Clear(FSinZona);
        Clear(FSinCuil);
        Clear(FTiposPresentes);
        Clear(FZonas);
        Clear(FCuil);
        Clear(FIngreso);
        Clear(FEgreso);
        FLiquidaciones := 0;

        Liq.SetCurrentKey("Cód. Período", "No. Empleado");
        Liq.SetRange("Cód. Período", FPeriodo);
        if not FIncluirBorradores then
            Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if Liq.FindSet() then
            repeat
                if TipoSeleccionado(Liq."Cód. Tipo Liq.") then begin
                    Emp := Liq."No. Empleado";
                    RegistrarEmpleado(Emp, Liq);
                    FLiquidaciones += 1;

                    BaseIG4Liq := 0;

                    Lin.SetRange("No. Liquidación", Liq."No.");
                    Lin.SetRange("Es Devengo", false);
                    if Lin.FindSet() then
                        repeat
                            if Lin.Importe <> 0 then
                                BaseIG4Liq += ImputarLinea(Emp, Lin);
                        until Lin.Next() = 0;

                    // La detracción del artículo 4 de la ley 27.541 se resta UNA VEZ por liquidación,
                    // que es como la resta el motor: la fórmula del 7000 hace
                    // MAX(0, BASE_IG4 + BASE_EXT_IG4 - DED_CONT_PATR) sin guarda MES_. Acá se suma lo
                    // que efectivamente se restó, no lo que correspondería al mes, para que la
                    // diferencia contra la detracción mensual quede a la vista en la planilla en vez
                    // de taparse con el valor "correcto".
                    DetraccionLiq := VariableDeLiq(Liq."No.", VarDetraccionTok);
                    Sumar(Emp, ClvBaseCnt, MaximoDe(0, BaseIG4Liq - DetraccionLiq));
                    Sumar(Emp, ClvDetrac, DetraccionLiq);

                    // Los días del mes comercial son del MES, no de la liquidación: cada liquidación
                    // del mes publica el mismo DIAS_ALTA_30. Sumarlos daría 60 o 90 días de alta.
                    MaximoEn(FDias, Emp, VariableDeLiq(Liq."No.", VarDias30Tok));
                    GuardarTexto(FZona, Emp, VariableTextoDeLiq(Liq."No.", VarZonaTok));
                    GuardarTexto(FObraSocial, Emp, VariableTextoDeLiq(Liq."No.", VarObraSocialTok));
                end;
            until Liq.Next() = 0;

        CerrarMagnitudes();
    end;

    /// <summary>
    /// Suma la línea a la magnitud que le corresponde. Devuelve lo que aporta a la base de
    /// contribuciones, que se cierra por liquidación y no por mes.
    /// </summary>
    local procedure ImputarLinea(Emp: Code[20]; var Lin: Record "Línea Liquidación"): Decimal
    begin
        // Los acumuladores se reconocen por su código. Son nombres reservados del motor —están
        // escritos igual en Cod50014 y Cod50016—, no configuración: un acumulador que cambiara de
        // nombre rompería el cálculo antes que este reporte.
        case Lin."Cód. Concepto" of
            AcumRemunerativoTok:
                Sumar(Emp, ClvRem, Lin.Importe);
            AcumNoRemunerativoTok:
                Sumar(Emp, ClvNoRem, Lin.Importe);
            AcumBaseSSTrabTok,
            AcumBaseSSVacTok:
                Sumar(Emp, ClvBaseSS, Lin.Importe);
            AcumBaseOSTrabTok:
                begin
                    Sumar(Emp, ClvBaseOS, Lin.Importe);
                    Sumar(Emp, ClvBaseOSTrab, Lin.Importe);
                end;
            AcumBaseOSVacTok:
                Sumar(Emp, ClvBaseOS, Lin.Importe);
            AcumBaseLRTTok:
                Sumar(Emp, ClvBaseLRT, Lin.Importe);
            AcumBaseSacTok:
                Sumar(Emp, ClvBaseSac, Lin.Importe);
            AcumBaseIG4Tok,
            AcumBaseExtIG4Tok:
                exit(Lin.Importe);
        end;

        exit(ImputarPorColumna(Emp, Lin));
    end;

    local procedure ImputarPorColumna(Emp: Code[20]; var Lin: Record "Línea Liquidación"): Decimal
    var
        Concepto: Record "Concepto Liquidación";
        Columna: Enum "Columna SICOSS Liq.";
    begin
        if not Concepto.Get(Lin."Cód. Concepto", Lin."Vigencia Concepto") then
            exit(0);
        Columna := Concepto."Columna SICOSS";

        case Columna of
            Columna::"Aporte Jubilación":
                Sumar(Emp, ClvApoJub, Lin.Importe);
            Columna::"Aporte INSSJP":
                Sumar(Emp, ClvApoIns, Lin.Importe);
            Columna::"Aporte Obra Social":
                Sumar(Emp, ClvApoOs, Lin.Importe);
            Columna::"Aporte Adicional OS":
                Sumar(Emp, ClvApoAdicOs, Lin.Importe);
            Columna::"Cuota Sindical":
                Sumar(Emp, ClvSindical, Lin.Importe);
            Columna::"Impuesto a las Ganancias":
                Sumar(Emp, ClvImpuesto, Lin.Importe);
            Columna::"Contribución Jubilación",
            Columna::"Contribución INSSJP",
            Columna::"Contribución Asig. Familiares",
            Columna::"Contribución FNE",
            Columna::"Contribución Obra Social",
            Columna::"Contribución ART",
            Columna::"Contribución SCVO",
            Columna::"Contribución Tarea Diferencial":
                Sumar(Emp, ClvCntBC, Lin.Importe);
            Columna::"No se declara":
                ;
            else
                // Sin columna asignada: si es plata que entra o sale del recibo —un descuento, una
                // contribución, una retención o seguridad social— tiene que aparecer en SICOSS, y si
                // no aparece hay que decirlo. Los haberes y los informativos no se listan: no son
                // columnas de la declaración, se declaran a través de las bases.
                if Lin."Tipo Concepto" in [
                    Lin."Tipo Concepto"::"Descuento Empleado",
                    Lin."Tipo Concepto"::"Contribución Patronal",
                    Lin."Tipo Concepto"::Retención,
                    Lin."Tipo Concepto"::"Seguridad Social"] then
                    AcumularSinMapear(Lin);
        end;

        exit(0);
    end;

    local procedure AcumularSinMapear(var Lin: Record "Línea Liquidación")
    var
        Clave: Text;
        Acum: Decimal;
    begin
        Clave := Lin."Cód. Concepto" + '  ' + Lin."Descripción Concepto";
        if FSinMapear.ContainsKey(Clave) then
            Acum := FSinMapear.Get(Clave);
        FSinMapear.Set(Clave, Acum + Lin.Importe);
    end;

    /// <remarks>
    /// Los topes se aplican acá, sobre el mes cerrado, y no liquidación por liquidación: el tope del
    /// SIPA es mensual y se agota —ver la lección del tope del SAC—, así que topear cada liquidación
    /// por separado dejaría pasar tantas veces el tope como liquidaciones tenga el empleado.
    /// </remarks>
    local procedure CerrarMagnitudes()
    var
        Emp: Code[20];
    begin
        foreach Emp in FEmpleados do begin
            Poner(Emp, ClvImpoRet, MinimoDe(Leer(Emp, ClvBaseSS), FTopeSipa));
            Poner(Emp, ClvImpoRetOs, MinimoDe(Leer(Emp, ClvBaseOS), FTopeSipaOs));
            if TextoDe(FZona, Emp) = '' then
                FSinZona.Add(Emp);
        end;
    end;

    local procedure RegistrarEmpleado(Emp: Code[20]; var Liq: Record "Liquidación")
    var
        Empleado: Record Employee;
        Cuil: Text;
    begin
        if FNombre.ContainsKey(Emp) then begin
            // El convenio se guarda el de la ÚLTIMA liquidación del mes, que es la que refleja el
            // encuadre con el que terminó. Un tripulante recategorizado a mitad de mes tiene dos, y
            // la declaración lleva uno.
            FConvenio.Set(Emp, Liq."Cód. Convenio");
            exit;
        end;

        FEmpleados.Add(Emp);
        FNombre.Set(Emp, Liq."Nombre Empleado");
        FConvenio.Set(Emp, Liq."Cód. Convenio");

        // El CUIL vive en "CIF/NIF" y no en "Nº seguridad social", que está vacío en el maestro
        // migrado. Se leen los dos igual, en ese orden, porque es lo que hace la importación de
        // SIRADIG y porque un alta nueva podría cargarlo en el campo estándar.
        if Empleado.Get(Emp) then begin
            Cuil := Empleado."CIF/NIF";
            if Cuil = '' then
                Cuil := Empleado."Social Security No.";
        end;
        FCuil.Set(Emp, Cuil);
        if Cuil = '' then
            FSinCuil.Add(Emp);

        LeerFases(Emp);

        if not FTiposPresentes.Contains(Liq."Cód. Tipo Liq.") then
            FTiposPresentes.Add(Liq."Cód. Tipo Liq.");
    end;

    /// <remarks>
    /// INGRESO sale de la PRIMERA fase y no de la vigente: es la fecha de ingreso que lleva la
    /// declaración y la que figura en el legajo, aunque la antigüedad del cálculo sume fases —ver la
    /// lección de antigüedad por suma de fases—. EGRESO sólo se informa si la baja cae dentro del
    /// período: una baja de hace tres años no es una baja de este mes.
    /// </remarks>
    local procedure LeerFases(Emp: Code[20])
    var
        Fase: Record "Fase Alta Empleado";
    begin
        // Por "Fecha Alta" y no por "No. Fase": el número de fase es el orden de carga y una fase
        // vieja cargada después quedaría primera.
        Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
        Fase.SetRange("No. Empleado", Emp);
        if Fase.FindFirst() then
            FIngreso.Set(Emp, Fase."Fecha Alta");

        if Fase.FindLast() then
            if (Fase."Fecha Baja" >= FFechaDesde) and (Fase."Fecha Baja" <= FFechaHasta) then
                FEgreso.Set(Emp, Fase."Fecha Baja");
    end;

    local procedure TipoSeleccionado(Tipo: Code[20]): Boolean
    begin
        if FTiposLiq = '' then
            exit(true);
        exit(StrPos(UpperCase('|' + FTiposLiq + '|'), UpperCase('|' + Tipo + '|')) > 0);
    end;

    // ── Variables de sistema que dejó el motor ────────────────────────────────

    local procedure VariableDeLiq(LiqNo: Code[20]; Nombre: Code[30]): Decimal
    var
        Resumen: Record "Resumen Variable Liq.";
    begin
        if Resumen.Get(LiqNo, Nombre) then
            exit(Resumen.Valor);
        exit(0);
    end;

    local procedure VariableTextoDeLiq(LiqNo: Code[20]; Nombre: Code[30]): Code[20]
    var
        Resumen: Record "Resumen Variable Liq.";
    begin
        if Resumen.Get(LiqNo, Nombre) then
            exit(CopyStr(Resumen."Valor Texto", 1, 20));
        exit('');
    end;

    // ── Parámetros ────────────────────────────────────────────────────────────

    /// <remarks>
    /// Todo se lee al ÚLTIMO DÍA del período, que es la fecha a la que se declara. Y se lee del nivel
    /// genérico —sin convenio, sin categoría y sin empleado—: los topes, la detracción y las alícuotas
    /// de la seguridad social son de la ley y no del encuadre. Si alguna estuviera cargada sólo a
    /// nivel convenio, el reporte la ve como faltante y la lista en Avisos, que es lo correcto: una
    /// alícuota patronal que dependa del convenio no se puede resumir en una columna de la planilla.
    /// </remarks>
    local procedure LeerParametros()
    begin
        Clear(FFaltanParametros);
        FTopeSipa := Parametro(ParTopeSipaTok, true);
        FTopeSipaOs := Parametro(ParTopeSipaOsTok, true);
        FDetraccionMes := Parametro(ParDetraccionTok, true);
        FArtFijo := Parametro(ParArtFijoTok, true);
        FSvco := Parametro(ParSvoTok, true);
        FBaseMinima := Parametro(ParBaseMinTok, true);

        FPctCntJub := Puntos(ParPctCntJubTok);
        FPctCntIns := Puntos(ParPctCntInsTok);
        FPctCntAfm := Puntos(ParPctAsigFamTok);
        FPctCntFne := Puntos(ParPctFneTok);
        FPctCntOs := Puntos(ParPctCntOsTok);
        FPctArt := Puntos(ParPctArtTok);
        FPctTarDif := Puntos(ParPctTarDifTok);
        FPctApoOs := Puntos(ParPctOsTok);
        FPctFsr := Puntos(ParPctFsrTok);

        // Un tope en cero no es un tope: dejaría todas las bases imponibles en cero y la declaración
        // saldría vacía sin una sola celda en rojo. Es lo único que se frena con un error.
        if FTopeSipa = 0 then
            Error(ErrTopeEnCero, ParTopeSipaTok, FFechaHasta);
        if FTopeSipaOs = 0 then
            Error(ErrTopeEnCero, ParTopeSipaOsTok, FFechaHasta);
    end;

    local procedure Parametro(Cod: Code[50]; Avisar: Boolean): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
    begin
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro", Cod);
        ParamVig.SetRange("Cód. Convenio", '');
        ParamVig.SetRange("Cód. Categoría", '');
        ParamVig.SetRange("No. Empleado", '');
        ParamVig.SetFilter("Vigencia Desde", '..%1', FFechaHasta);
        if ParamVig.FindLast() then
            exit(ParamVig.Valor);

        if Avisar and not FFaltanParametros.Contains(Cod) then
            FFaltanParametros.Add(Cod);
        exit(0);
    end;

    /// <summary>
    /// El parámetro expresado en PUNTOS porcentuales, que es lo que muestran las columnas de %.
    /// </summary>
    /// <remarks>
    /// Los PCT_ del motor conviven en DOS UNIDADES y la diferencia no está documentada en ninguna
    /// parte más que en las fórmulas que los usan. PCT_CONT_JUB vale 0,1077 porque el 7000 lo
    /// multiplica directo —`... * PCT_CONT_JUB`—; PCT_JUB vale 11 porque el 6000 hace
    /// `* PCT_JUB / 100`. La lista de abajo sale de leer esas fórmulas, no de una convención: si una
    /// fórmula cambia de unidad hay que cambiarla también acá, y el control que lo delata es la
    /// columna de diferencia contra lo que BC liquidó, que se iría por un factor de cien.
    /// </remarks>
    local procedure Puntos(Cod: Code[50]): Decimal
    var
        Valor: Decimal;
    begin
        Valor := Parametro(Cod, true);
        case Cod of
            ParPctCntJubTok,
            ParPctCntInsTok,
            ParPctAsigFamTok,
            ParPctFneTok,
            ParPctCntOsTok,
            ParPctArtTok,
            ParPctTarDifTok:
                exit(Valor * 100);
        end;
        exit(Valor);
    end;

    /// <remarks>
    /// El crédito del decreto 814 se busca como PCT_DTO_814_&lt;código de zona&gt; —PCT_DTO_814_29
    /// para Chubut—, un parámetro por zona y no una tabla: es un porcentaje con vigencia, que es
    /// exactamente lo que un parámetro sabe hacer. Sin cargar, el porcentaje sale en cero y el
    /// parámetro aparece en Avisos con su nombre completo, listo para copiar.
    /// </remarks>
    local procedure PctZona(Zona: Code[20]): Decimal
    begin
        if Zona = '' then
            exit(0);
        exit(Parametro(CopyStr(ParPctDto814Tok + Zona, 1, 50), true));
    end;

    local procedure OrdenarZonas()
    var
        Emp: Code[20];
        Zona: Code[20];
    begin
        foreach Emp in FEmpleados do begin
            Zona := '';
            if FZona.ContainsKey(Emp) then
                Zona := FZona.Get(Emp);
            if (Zona <> '') and not FZonas.Contains(Zona) then
                FZonas.Add(Zona);
        end;
    end;

    // ── Hoja TOTALES ──────────────────────────────────────────────────────────

    local procedure EscribirTotales(var Libro: Record "Excel Buffer" temporary)
    var
        Emp: Code[20];
        Fila: Integer;
        Cred: Text;
        Detrac: Text;
    begin
        FFilaPrimera := 2;
        Libro.NewRow();
        Texto(Libro, StrSubstNo(TxtTituloTotales, FPeriodo), true);
        Texto(Libro, '', false);
        Texto(Libro, StrSubstNo(TxtGenerado, Format(FFechaDesde), Format(FFechaHasta), Format(CurrentDateTime())), false);

        Libro.NewRow();
        EncabezadosTotales(Libro);

        Fila := FFilaPrimera;
        Detrac := Num(FDetraccionMes);
        foreach Emp in FEmpleados do begin
            Fila += 1;
            Libro.NewRow();
            Texto(Libro, Emp, false);                                            // A  LEG
            Texto(Libro, Nombre(Emp), false);                                    // B  APELLIDO_Y_NOMBRES
            Texto(Libro, FormatearCuil(Emp), false);                             // C  CUIL
            Fecha(Libro, ValorFecha(FIngreso, Emp));                             // D  INGRESO
            Fecha(Libro, ValorFecha(FEgreso, Emp));                              // E  EGRESO
            Formula(Libro, Ref('G', Fila) + '+' + Ref('H', Fila));               // F  TOT_DEV
            Numero(Libro, Leer(Emp, ClvRem), false);                             // G  TOT_C_AP
            Numero(Libro, Leer(Emp, ClvNoRem), false);                           // H  TOT_S_AP
            Numero(Libro, Leer(Emp, ClvImpoRet), false);                         // I  IMPO_RET
            Numero(Libro, Leer(Emp, ClvImpoRetOs), false);                       // J  IMPO_RET_OS
            Numero(Libro, Leer(Emp, ClvBaseLRT), false);                         // K  IMPO_ART
            Numero(Libro, Leer(Emp, ClvBaseCnt), false);                         // L  IMPO_CNT
            Numero(Libro, Leer(Emp, ClvBaseOSTrab), false);                      // M  IMPO_CNT_OS
            Numero(Libro, Leer(Emp, ClvApoJub), false);                          // N  JUBILACION
            Numero(Libro, Leer(Emp, ClvApoIns), false);                          // O  LEY_19032
            Numero(Libro, Leer(Emp, ClvApoOs), false);                           // P  OBRA_SOCIAL
            Numero(Libro, Leer(Emp, ClvApoAdicOs), false);                       // Q  ADIC_OBS
            Numero(Libro, Leer(Emp, ClvSindical), false);                        // R  SINDICATO
            Numero(Libro, Leer(Emp, ClvImpuesto), false);                        // S  IMPUESTO
            Formula(Libro, 'SUM(' + Ref('N', Fila) + ':' + Ref('S', Fila) + ')');// T  TOT_RET
            Formula(Libro, Ref('F', Fila) + '-' + Ref('T', Fila));               // U  LIQUIDO
            Texto(Libro, TextoDe(FObraSocial, Emp), false);                      // V  OBS
            Texto(Libro, TextoDe(FZona, Emp), false);                            // W  ZONA
            Texto(Libro, TextoDe(FConvenio, Emp), false);                        // X  CNV

            // El crédito apunta a la celda del porcentaje en la hoja Dto 814 en vez de llevar el
            // número adentro: así se corrige el porcentaje en un solo lugar y la columna entera se
            // actualiza, que es como se usaba la planilla a mano.
            Cred := CeldaPctZona(TextoDe(FZona, Emp));
            if Cred = '' then
                Numero(Libro, 0, false)                                          // Y  CREDITO
            else
                Formula(Libro, Ref('L', Fila) + '*' + Cred + '/100');

            Numero(Libro, ValorDe(FDias, Emp), false);                           // Z  DS MES
            Numero(Libro, DiasSac(Emp), false);                                  // AA DS SAC
            Formula(Libro, Detrac + '/30*' + Ref('Z', Fila));                    // AB DET REM
            Formula(Libro, Detrac + '/360*' + Ref('AA', Fila));                  // AC DET SAC
            Formula(Libro, Ref('AB', Fila) + '+' + Ref('AC', Fila));             // AD DET TOTAL
            Formula(Libro, 'MAX(' + Ref('G', Fila) + '-' + Ref('AD', Fila) + ',' + Num(FBaseMinima) + ')'); // AE IMPO CNT SS
            Numero(Libro, Leer(Emp, ClvDetrac), false);                          // AF DET APLICADA BC
            Formula(Libro, Ref('AF', Fila) + '-' + Ref('AD', Fila));             // AG DIF DETRACCIÓN
        end;

        FFilaUltima := Fila;
        TotalesTotales(Libro, Fila);
    end;

    local procedure EncabezadosTotales(var Libro: Record "Excel Buffer" temporary)
    begin
        Texto(Libro, 'LEG', true);
        Texto(Libro, 'APELLIDO_Y_NOMBRES', true);
        Texto(Libro, 'CUIL', true);
        Texto(Libro, 'INGRESO', true);
        Texto(Libro, 'EGRESO', true);
        Texto(Libro, 'TOT_DEV', true);
        Texto(Libro, 'TOT_C_AP', true);
        Texto(Libro, 'TOT_S_AP', true);
        Texto(Libro, 'IMPO_RET', true);
        Texto(Libro, 'IMPO_RET_OS', true);
        Texto(Libro, 'IMPO_ART', true);
        Texto(Libro, 'IMPO_CNT', true);
        Texto(Libro, 'IMPO_CNT_OS', true);
        Texto(Libro, 'JUBILACION', true);
        Texto(Libro, 'LEY_19032', true);
        Texto(Libro, 'OBRA_SOCIAL', true);
        Texto(Libro, 'ADIC_OBS', true);
        Texto(Libro, 'SINDICATO', true);
        Texto(Libro, 'IMPUESTO', true);
        Texto(Libro, 'TOT_RET', true);
        Texto(Libro, 'LIQUIDO', true);
        Texto(Libro, 'OBS', true);
        Texto(Libro, 'ZONA', true);
        Texto(Libro, 'CNV', true);
        Texto(Libro, 'CREDITO', true);
        Texto(Libro, 'DS MES', true);
        Texto(Libro, 'DS SAC', true);
        Texto(Libro, 'DET REM', true);
        Texto(Libro, 'DET SAC', true);
        Texto(Libro, 'DET TOTAL', true);
        Texto(Libro, 'IMPO CNT SS', true);
        Texto(Libro, 'DET APLICADA BC', true);
        Texto(Libro, 'DIF DETRACCION', true);
    end;

    local procedure TotalesTotales(var Libro: Record "Excel Buffer" temporary; UltimaFila: Integer)
    var
        Col: Integer;
    begin
        Libro.NewRow();
        Formula(Libro, 'COUNTA(' + Rango('A', UltimaFila) + ')');
        Texto(Libro, TxtTotales, true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Formula(Libro, 'COUNT(' + Rango('E', UltimaFila) + ')');
        for Col := 6 to 21 do
            Formula(Libro, 'SUM(' + Rango(Letra(Col), UltimaFila) + ')');
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        for Col := 25 to 33 do
            Formula(Libro, 'SUM(' + Rango(Letra(Col), UltimaFila) + ')');
    end;

    // ── Hoja CNT ──────────────────────────────────────────────────────────────

    /// <remarks>
    /// Las bases apuntan a TOTALES en vez de repetir los números: la planilla se usa corrigiendo una
    /// base y mirando cómo se mueve la contribución, y con los valores duplicados hay que corregir en
    /// dos lugares o la hoja empieza a mentir.
    /// </remarks>
    local procedure EscribirCnt(var Libro: Record "Excel Buffer" temporary)
    var
        Emp: Code[20];
        Fila: Integer;
        FilaT: Integer;
        Col: Integer;
    begin
        // Fila 1: los dos rótulos de bloque sobre sus columnas —PORCENTAJES en G, MONTOS en N— y, a
        // la derecha de todo, el valor fijo de ART por empleado en AB1. Está en UNA celda y las
        // fórmulas de la columna ART la referencian absoluta ($AB$1): es un valor por empleado que
        // cambia por resolución, y repetido en 330 filas se corrige mal.
        Libro.NewRow();
        Texto(Libro, StrSubstNo(TxtTituloCnt, FPeriodo), true);
        for Col := 2 to 6 do
            Texto(Libro, '', false);
        Texto(Libro, TxtPorcentajes, true);
        for Col := 8 to 13 do
            Texto(Libro, '', false);
        Texto(Libro, TxtMontos, true);
        for Col := 15 to 26 do
            Texto(Libro, '', false);
        Texto(Libro, TxtArtFijo, true);
        Numero(Libro, FArtFijo, true);

        Libro.NewRow();
        Texto(Libro, 'LEG', true);
        Texto(Libro, 'APELLIDO_Y_NOMBRES', true);
        Texto(Libro, 'CNV', true);
        Texto(Libro, 'IMPO_ART', true);
        Texto(Libro, 'IMPO CNT SS', true);
        Texto(Libro, 'IMPO CNT OS', true);
        Texto(Libro, 'JUB', true);
        Texto(Libro, 'INS', true);
        Texto(Libro, 'AFM', true);
        Texto(Libro, 'FNE', true);
        Texto(Libro, 'OBS', true);
        Texto(Libro, 'ART', true);
        Texto(Libro, 'DIF', true);
        Texto(Libro, 'JUB', true);
        Texto(Libro, 'INS', true);
        Texto(Libro, 'AFM', true);
        Texto(Libro, 'FNE', true);
        Texto(Libro, 'TOT_SS', true);
        Texto(Libro, 'OBS', true);
        Texto(Libro, 'ART', true);
        Texto(Libro, 'BASE DIF', true);
        Texto(Libro, 'DIFERENCIAL', true);
        Texto(Libro, 'TOT CNT TEORICO', true);
        Texto(Libro, 'TOT CNT BC', true);
        Texto(Libro, 'DIF BC', true);

        Fila := 2;
        FilaT := FFilaPrimera;
        foreach Emp in FEmpleados do begin
            Fila += 1;
            FilaT += 1;
            Libro.NewRow();
            Texto(Libro, Emp, false);                                             // A  LEG
            Texto(Libro, Nombre(Emp), false);                                     // B
            Texto(Libro, TextoDe(FConvenio, Emp), false);                         // C  CNV
            Formula(Libro, RefTotales('K', FilaT));                               // D  IMPO_ART
            Formula(Libro, RefTotales('L', FilaT));                               // E  IMPO CNT SS
            Formula(Libro, RefTotales('M', FilaT));                               // F  IMPO CNT OS
            Numero(Libro, FPctCntJub, false);                                     // G  JUB %
            Numero(Libro, FPctCntIns, false);                                     // H  INS %
            Numero(Libro, FPctCntAfm, false);                                     // I  AFM %
            Numero(Libro, FPctCntFne, false);                                     // J  FNE %
            Numero(Libro, FPctCntOs, false);                                      // K  OBS %
            Numero(Libro, FPctArt, false);                                        // L  ART %
            Numero(Libro, FPctTarDif, false);                                     // M  DIF %
            Formula(Libro, Ref('E', Fila) + '*' + Ref('G', Fila) + '/100');       // N  JUB
            Formula(Libro, Ref('E', Fila) + '*' + Ref('H', Fila) + '/100');       // O  INS
            Formula(Libro, Ref('E', Fila) + '*' + Ref('I', Fila) + '/100');       // P  AFM
            Formula(Libro, Ref('E', Fila) + '*' + Ref('J', Fila) + '/100');       // Q  FNE
            Formula(Libro, 'SUM(' + Ref('N', Fila) + ':' + Ref('Q', Fila) + ')'); // R  TOT_SS
            Formula(Libro, Ref('F', Fila) + '*' + Ref('K', Fila) + '/100');       // S  OBS
            Formula(Libro, Ref('D', Fila) + '*' + Ref('L', Fila) + '/100+$AB$1'); // T  ART
            Formula(Libro, RefTotales('I', FilaT));                               // U  BASE DIF
            Formula(Libro, Ref('U', Fila) + '*' + Ref('M', Fila) + '/100');       // V  DIFERENCIAL
            Formula(Libro, Ref('R', Fila) + '+' + Ref('S', Fila) + '+' + Ref('T', Fila) + '+' + Ref('V', Fila)); // W
            Numero(Libro, Leer(Emp, ClvCntBC), false);                            // X  TOT CNT BC
            Formula(Libro, Ref('X', Fila) + '-' + Ref('W', Fila));                // Y  DIF BC
        end;

        Libro.NewRow();
        Formula(Libro, 'COUNTA(' + Rango('A', Fila) + ')');
        Texto(Libro, TxtTotales, true);
        Texto(Libro, '', false);
        for Col := 4 to 6 do
            Formula(Libro, 'SUM(' + Rango(Letra(Col), Fila) + ')');
        for Col := 7 to 13 do
            Texto(Libro, '', false);
        for Col := 14 to 25 do
            Formula(Libro, 'SUM(' + Rango(Letra(Col), Fila) + ')');

        PieCnt(Libro, Fila + 1);
    end;

    /// <remarks>
    /// El pie reproduce el bloque con el que se cerraba la declaración a mano. "Otras contribuciones"
    /// queda EN CERO y editable a propósito: no sale de la liquidación —son contribuciones que se
    /// declaran por fuera— y rellenarla con un número inventado sería peor que dejarla vacía.
    /// </remarks>
    local procedure PieCnt(var Libro: Record "Excel Buffer" temporary; FilaTotal: Integer)
    var
        FilaCnt: Integer;
        FilaSvco: Integer;
        FilaOtras: Integer;
        Col: Integer;
    begin
        FilaCnt := FilaTotal + 1;
        Libro.NewRow();
        for Col := 1 to 17 do
            Texto(Libro, '', false);
        Texto(Libro, TxtTotalCnt, true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Formula(Libro, Ref('R', FilaTotal) + '+' + Ref('S', FilaTotal) + '+' + Ref('T', FilaTotal) + '+' + Ref('V', FilaTotal));

        FilaSvco := FilaCnt + 1;
        Libro.NewRow();
        for Col := 1 to 17 do
            Texto(Libro, '', false);
        Texto(Libro, TxtSvco, true);
        Numero(Libro, FSvco, false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Formula(Libro, Ref('A', FilaTotal) + '*' + Ref('S', FilaSvco));

        FilaOtras := FilaSvco + 1;
        Libro.NewRow();
        for Col := 1 to 17 do
            Texto(Libro, '', false);
        Texto(Libro, TxtOtrasCnt, true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Numero(Libro, 0, false);

        Libro.NewRow();
        for Col := 1 to 17 do
            Texto(Libro, '', false);
        Texto(Libro, TxtTotalDdjj, true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Formula(Libro, Ref('W', FilaCnt) + '+' + Ref('W', FilaSvco) + '+' + Ref('W', FilaOtras));
    end;

    // ── Hoja FSR ──────────────────────────────────────────────────────────────

    /// <remarks>
    /// El Fondo Solidario de Redistribución se expresa como UN parámetro —PCT_FSR, el porcentaje del
    /// aporte y de la contribución de obra social que va al fondo— y las cuatro columnas de % salen
    /// de él. Son cuatro números que siempre se movieron juntos: dejarlos como cuatro parámetros
    /// sueltos permitía que el reparto dejara de sumar el total de obra social sin que nada avise.
    /// </remarks>
    local procedure EscribirFsr(var Libro: Record "Excel Buffer" temporary)
    var
        Emp: Code[20];
        Fila: Integer;
        FilaT: Integer;
        Col: Integer;
        PctRetFsr: Decimal;
        PctRetOs: Decimal;
        PctCntFsr: Decimal;
        PctCntOs: Decimal;
    begin
        PctRetFsr := FPctApoOs * FPctFsr / 100;
        PctRetOs := FPctApoOs - PctRetFsr;
        PctCntFsr := FPctCntOs * FPctFsr / 100;
        PctCntOs := FPctCntOs - PctCntFsr;

        Libro.NewRow();
        Texto(Libro, StrSubstNo(TxtTituloFsr, FPeriodo), true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, TxtPorcentajes, true);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, TxtMontos, true);

        Libro.NewRow();
        Texto(Libro, 'LEG', true);
        Texto(Libro, 'APELLIDO_Y_NOMBRES', true);
        Texto(Libro, 'OBS', true);
        Texto(Libro, 'IMPO_RET_OS', true);
        Texto(Libro, 'IMPO CNT OS', true);
        Texto(Libro, 'RET', true);
        Texto(Libro, 'FSR', true);
        Texto(Libro, 'CNT', true);
        Texto(Libro, 'FSR', true);
        Texto(Libro, 'RET', true);
        Texto(Libro, 'FSR', true);
        Texto(Libro, 'TOT RET', true);
        Texto(Libro, 'CNT', true);
        Texto(Libro, 'FSR', true);
        Texto(Libro, 'TOT CNT', true);

        Fila := 2;
        FilaT := FFilaPrimera;
        foreach Emp in FEmpleados do begin
            Fila += 1;
            FilaT += 1;
            Libro.NewRow();
            Texto(Libro, Emp, false);                                              // A  LEG
            Texto(Libro, Nombre(Emp), false);                                      // B
            Texto(Libro, TextoDe(FObraSocial, Emp), false);                        // C  OBS
            Formula(Libro, RefTotales('J', FilaT));                                // D  IMPO_RET_OS
            Formula(Libro, RefTotales('M', FilaT));                                // E  IMPO CNT OS
            Numero(Libro, PctRetOs, false);                                        // F  RET %
            Numero(Libro, PctRetFsr, false);                                       // G  FSR %
            Numero(Libro, PctCntOs, false);                                        // H  CNT %
            Numero(Libro, PctCntFsr, false);                                       // I  FSR %
            Formula(Libro, Ref('D', Fila) + '*' + Ref('F', Fila) + '/100');        // J  RET
            Formula(Libro, Ref('D', Fila) + '*' + Ref('G', Fila) + '/100');        // K  FSR
            Formula(Libro, 'SUM(' + Ref('J', Fila) + ':' + Ref('K', Fila) + ')');  // L  TOT RET
            Formula(Libro, Ref('E', Fila) + '*' + Ref('H', Fila) + '/100');        // M  CNT
            Formula(Libro, Ref('E', Fila) + '*' + Ref('I', Fila) + '/100');        // N  FSR
            Formula(Libro, 'SUM(' + Ref('M', Fila) + ':' + Ref('N', Fila) + ')');  // O  TOT CNT
        end;

        Libro.NewRow();
        Formula(Libro, 'COUNTA(' + Rango('A', Fila) + ')');
        Texto(Libro, TxtTotales, true);
        Texto(Libro, '', false);
        Formula(Libro, 'SUM(' + Rango('D', Fila) + ')');
        Formula(Libro, 'SUM(' + Rango('E', Fila) + ')');
        for Col := 6 to 9 do
            Texto(Libro, '', false);
        for Col := 10 to 15 do
            Formula(Libro, 'SUM(' + Rango(Letra(Col), Fila) + ')');
    end;

    // ── Hoja Dto 814 ──────────────────────────────────────────────────────────

    /// <remarks>
    /// La base de cada zona se suma con SUMIF sobre TOTALES y no acá: así se puede filtrar o corregir
    /// una fila de TOTALES y ver el crédito moverse. Es la hoja que decide un número de la
    /// declaración, y tiene que poder revisarse mirando de dónde sale cada peso.
    /// </remarks>
    local procedure EscribirDto814(var Libro: Record "Excel Buffer" temporary)
    var
        ValorAtrib: Record "Valor Atributo Liq.";
        Zona: Code[20];
        Fila: Integer;
    begin
        Libro.NewRow();
        Texto(Libro, 'ZONA', true);
        Texto(Libro, 'PROVINCIA', true);
        Texto(Libro, 'BASE', true);
        Texto(Libro, '%', true);
        Texto(Libro, 'CREDITO', true);

        Fila := 1;
        foreach Zona in FZonas do begin
            Fila += 1;
            Libro.NewRow();
            Texto(Libro, Zona, false);
            // La PK de "Valor Atributo Liq." lleva TRES campos —tipo, valor padre y código—, y el
            // padre vacío va explícito: un Get con dos argumentos compila y asigna el código al
            // campo del padre, devolviendo que no existe.
            if ValorAtrib.Get(AtribZonaTok, '', Zona) then
                Texto(Libro, ValorAtrib.Descripción, false)
            else
                Texto(Libro, '', false);
            Formula(Libro, 'SUMIF(' + HojaTotalesTok + '!$W$' + Format(FFilaPrimera + 1) + ':$W$' + Format(FFilaUltima) +
                           ',' + Ref('A', Fila) + ',' + HojaTotalesTok + '!$L$' + Format(FFilaPrimera + 1) + ':$L$' + Format(FFilaUltima) + ')');
            Numero(Libro, PctZona(Zona), false);
            Formula(Libro, Ref('C', Fila) + '*' + Ref('D', Fila) + '/100');
        end;

        Libro.NewRow();
        Texto(Libro, '', false);
        Texto(Libro, TxtTotales, true);
        Formula(Libro, 'SUM(C2:' + Ref('C', Fila) + ')');
        Texto(Libro, '', false);
        Formula(Libro, 'SUM(E2:' + Ref('E', Fila) + ')');
    end;

    /// <summary>Referencia absoluta a la celda del % de esa zona en la hoja Dto 814.</summary>
    local procedure CeldaPctZona(Zona: Code[20]): Text
    var
        Indice: Integer;
    begin
        if Zona = '' then
            exit('');
        Indice := IndiceZona(Zona);
        if Indice = 0 then
            exit('');
        exit('''' + HojaDtoTok + '''!$D$' + Format(Indice + 1));
    end;

    local procedure IndiceZona(Zona: Code[20]): Integer
    var
        Otra: Code[20];
        Indice: Integer;
    begin
        foreach Otra in FZonas do begin
            Indice += 1;
            if Otra = Zona then
                exit(Indice);
        end;
        exit(0);
    end;

    // ── Hoja Avisos ───────────────────────────────────────────────────────────

    local procedure EscribirAvisos(var Libro: Record "Excel Buffer" temporary)
    var
        Clave: Text;
        Cod: Code[50];
        Tipo: Code[20];
        Emp: Code[20];
        Legajos: Text;
    begin
        Libro.NewRow();
        Texto(Libro, StrSubstNo(TxtTituloAvisos, FPeriodo), true);

        Etiqueta(Libro, TxtPeriodo, FPeriodo + '  (' + Format(FFechaDesde) + ' a ' + Format(FFechaHasta) + ')');
        Etiqueta(Libro, TxtGeneradoEl, Format(CurrentDateTime()));
        Etiqueta(Libro, TxtUsuario, UserId());
        if FTiposLiq = '' then
            Etiqueta(Libro, TxtTiposFiltro, TxtTodosLosTipos)
        else
            Etiqueta(Libro, TxtTiposFiltro, FTiposLiq);
        Etiqueta(Libro, TxtEstados, EstadosIncluidos());
        Etiqueta(Libro, TxtEmpleados, Format(FEmpleados.Count()));
        Etiqueta(Libro, TxtLiquidaciones, Format(FLiquidaciones));
        foreach Tipo in FTiposPresentes do
            Etiqueta(Libro, TxtTipoPresente, Tipo);

        if FFaltanParametros.Count() > 0 then begin
            Libro.NewRow();
            Libro.NewRow();
            Texto(Libro, TxtAvisoParametros, true);
            foreach Cod in FFaltanParametros do begin
                Libro.NewRow();
                Texto(Libro, '', false);
                Texto(Libro, Cod, false);
            end;
        end;

        if FSinMapear.Count() > 0 then begin
            Libro.NewRow();
            Libro.NewRow();
            Texto(Libro, TxtAvisoSinMapear, true);
            Texto(Libro, '', false);
            Texto(Libro, '', false);
            Texto(Libro, TxtComoSacarDeAvisos, false);
            foreach Clave in SinMapearPorImporte() do begin
                Libro.NewRow();
                Texto(Libro, '', false);
                Texto(Libro, Clave, false);
                Numero(Libro, FSinMapear.Get(Clave), false);
            end;
        end;

        if FSinZona.Count() > 0 then begin
            Libro.NewRow();
            Libro.NewRow();
            Texto(Libro, StrSubstNo(TxtAvisoSinZona, FSinZona.Count()), true);
            Legajos := '';
            foreach Emp in FSinZona do
                if StrLen(Legajos) < 200 then
                    Legajos += Emp + ' ';
            Libro.NewRow();
            Texto(Libro, '', false);
            Texto(Libro, Legajos, false);
        end;

        if FSinCuil.Count() > 0 then begin
            Libro.NewRow();
            Libro.NewRow();
            Texto(Libro, StrSubstNo(TxtAvisoSinCuil, FSinCuil.Count()), true);
            Legajos := '';
            foreach Emp in FSinCuil do
                if StrLen(Legajos) < 200 then
                    Legajos += Emp + ' ';
            Libro.NewRow();
            Texto(Libro, '', false);
            Texto(Libro, Legajos, false);
        end;

        Libro.NewRow();
        Libro.NewRow();
        Texto(Libro, TxtComoLeer, true);
        EscribirNota(Libro, TxtNotaDetraccion);
        EscribirNota(Libro, TxtNotaDif);
        EscribirNota(Libro, TxtNotaDevengos);
        EscribirNota(Libro, TxtNotaTopes);
        EscribirNota(Libro, TxtNotaCnv);
    end;

    /// <remarks>
    /// Ordenado por importe descendente y a mano, porque List de AL no tiene Sort(). Es una selección
    /// sobre unas pocas decenas de claves, no vale una estructura mejor; lo que sí vale es el orden:
    /// la primera vez que se corre el reporte esta lista es la cola de trabajo, y arrancar por los
    /// 83 millones y no por el concepto que empieza con 4 cambia cuánto tarda en quedar limpia.
    /// </remarks>
    local procedure SinMapearPorImporte() Ordenadas: List of [Text]
    var
        Pendientes: List of [Text];
        Clave: Text;
        Mayor: Text;
        Indice: Integer;
        IndiceMayor: Integer;
    begin
        Pendientes := FSinMapear.Keys();
        while Pendientes.Count() > 0 do begin
            IndiceMayor := 1;
            Mayor := Pendientes.Get(1);
            for Indice := 2 to Pendientes.Count() do begin
                Clave := Pendientes.Get(Indice);
                if Abs(FSinMapear.Get(Clave)) > Abs(FSinMapear.Get(Mayor)) then begin
                    Mayor := Clave;
                    IndiceMayor := Indice;
                end;
            end;
            Ordenadas.Add(Mayor);
            Pendientes.RemoveAt(IndiceMayor);
        end;
    end;

    /// <remarks>
    /// Las notas son el único texto del libro que puede pasar los 250 caracteres de una celda, y
    /// recortarlas sería recortar justamente la explicación de por qué una columna no cierra. Se
    /// parten en celdas contiguas de la misma fila, cortando en el último espacio: en la hoja de
    /// Avisos no hay nada más a la derecha, así que la nota se lee corrida.
    /// </remarks>
    local procedure EscribirNota(var Libro: Record "Excel Buffer" temporary; Nota: Text)
    var
        Resto: Text;
        Corte: Integer;
    begin
        Libro.NewRow();
        Texto(Libro, '', false);
        Resto := Nota;
        while Resto <> '' do begin
            if StrLen(Resto) <= MaxCelda() then begin
                Texto(Libro, Resto, false);
                exit;
            end;
            Corte := UltimoEspacio(Resto);
            Texto(Libro, CopyStr(Resto, 1, Corte), false);
            Resto := CopyStr(Resto, Corte + 1);
        end;
    end;

    /// <summary>Último espacio dentro de lo que cabe en una celda; el largo entero si no hay ninguno.</summary>
    local procedure UltimoEspacio(Cadena: Text): Integer
    var
        Indice: Integer;
    begin
        for Indice := MaxCelda() downto 1 do
            if CopyStr(Cadena, Indice, 1) = ' ' then
                exit(Indice);
        exit(MaxCelda());
    end;

    /// <summary>
    /// Lo que entra en una celda de texto del Excel Buffer.
    /// </summary>
    /// <remarks>
    /// Sale de MaxStrLen del campo y no de un 250 escrito a mano: si la base cambiara el largo, el
    /// reporte lo sigue sin que nadie se acuerde de este número.
    /// </remarks>
    local procedure MaxCelda(): Integer
    var
        Buffer: Record "Excel Buffer";
    begin
        exit(MaxStrLen(Buffer."Cell Value as Text"));
    end;

    local procedure EstadosIncluidos(): Text
    begin
        if FIncluirBorradores then
            exit(TxtConBorradores);
        exit(TxtSinBorradores);
    end;

    // ── Magnitudes ────────────────────────────────────────────────────────────

    local procedure Sumar(Emp: Code[20]; Clave: Text; Importe: Decimal)
    var
        Id: Text;
        Acum: Decimal;
    begin
        Id := Emp + '|' + Clave;
        if FVal.ContainsKey(Id) then
            Acum := FVal.Get(Id);
        FVal.Set(Id, Acum + Importe);
    end;

    local procedure Poner(Emp: Code[20]; Clave: Text; Importe: Decimal)
    begin
        FVal.Set(Emp + '|' + Clave, Importe);
    end;

    local procedure Leer(Emp: Code[20]; Clave: Text): Decimal
    var
        Id: Text;
    begin
        Id := Emp + '|' + Clave;
        // ContainsKey y Get NUNCA en la misma expresión: AL no cortocircuita y el Get corre igual.
        if not FVal.ContainsKey(Id) then
            exit(0);
        exit(FVal.Get(Id));
    end;

    /// <remarks>
    /// Los días de SAC salen en cero salvo que el mes haya liquidado base de aguinaldo. No se derivan
    /// del semestre ni del calendario: el aguinaldo se paga cuando se paga —puede adelantarse o
    /// partirse— y lo único que sabe el reporte es si este mes hubo base de SAC.
    /// </remarks>
    local procedure DiasSac(Emp: Code[20]): Decimal
    begin
        if Leer(Emp, ClvBaseSac) = 0 then
            exit(0);
        exit(ValorDe(FDias, Emp));
    end;

    local procedure MaximoEn(var Dict: Dictionary of [Code[20], Decimal]; Emp: Code[20]; Valor: Decimal)
    var
        Actual: Decimal;
    begin
        Actual := ValorDe(Dict, Emp);
        if Valor > Actual then
            Actual := Valor;
        Dict.Set(Emp, Actual);
    end;

    /// <remarks>
    /// Sólo escribe si llega con algo. Un tripulante con tres liquidaciones en el mes puede tener la
    /// zona publicada en una y vacía en otra —COD_ZONA sale del atributo vigente a la fecha de cada
    /// liquidación—, y pisarla con el vacío de la última lo dejaría sin crédito del decreto 814.
    /// </remarks>
    local procedure GuardarTexto(var Dict: Dictionary of [Code[20], Code[20]]; Emp: Code[20]; Valor: Code[20])
    begin
        if Valor = '' then begin
            if not Dict.ContainsKey(Emp) then
                Dict.Set(Emp, '');
            exit;
        end;
        Dict.Set(Emp, Valor);
    end;

    local procedure ValorDe(var Dict: Dictionary of [Code[20], Decimal]; Emp: Code[20]): Decimal
    begin
        if not Dict.ContainsKey(Emp) then
            exit(0);
        exit(Dict.Get(Emp));
    end;

    local procedure ValorFecha(var Dict: Dictionary of [Code[20], Date]; Emp: Code[20]): Date
    begin
        if not Dict.ContainsKey(Emp) then
            exit(0D);
        exit(Dict.Get(Emp));
    end;

    local procedure TextoDe(var Dict: Dictionary of [Code[20], Code[20]]; Emp: Code[20]): Code[20]
    begin
        if not Dict.ContainsKey(Emp) then
            exit('');
        exit(Dict.Get(Emp));
    end;

    local procedure Nombre(Emp: Code[20]): Text
    begin
        if not FNombre.ContainsKey(Emp) then
            exit('');
        exit(FNombre.Get(Emp));
    end;

    /// <remarks>
    /// El CUIL se formatea con guiones porque es como lo lleva la planilla y como lo espera el
    /// importador de SICOSS. Si viene con cualquier otra forma se normaliza a dígitos primero: en el
    /// maestro migrado conviven los dos formatos.
    /// </remarks>
    local procedure FormatearCuil(Emp: Code[20]): Text
    var
        Crudo: Text;
        Digitos: Text;
        Indice: Integer;
        Caracter: Text[1];
    begin
        if not FCuil.ContainsKey(Emp) then
            exit('');
        Crudo := FCuil.Get(Emp);
        // Los dígitos se reconocen con StrPos sobre una constante y no con un helper de .NET:
        // Char.IsLetterOrDigit no existe en AL y un rango ['0'..'9'] compara Char contra Text.
        for Indice := 1 to StrLen(Crudo) do begin
            Caracter := CopyStr(Crudo, Indice, 1);
            if StrPos(DigitosTok, Caracter) > 0 then
                Digitos += Caracter;
        end;
        if StrLen(Digitos) <> 11 then
            exit(Crudo);
        exit(CopyStr(Digitos, 1, 2) + '-' + CopyStr(Digitos, 3, 8) + '-' + CopyStr(Digitos, 11, 1));
    end;

    local procedure MinimoDe(A: Decimal; B: Decimal): Decimal
    begin
        if A < B then
            exit(A);
        exit(B);
    end;

    local procedure MaximoDe(A: Decimal; B: Decimal): Decimal
    begin
        if A > B then
            exit(A);
        exit(B);
    end;

    // ── Envoltorios del Excel Buffer ──────────────────────────────────────────

    /// <remarks>
    /// EL CORTE A 250 NO ES DEFENSA DE MÁS. "Cell Value as Text" es Text[250] y AddColumn ASIGNA al
    /// campo, así que un texto más largo no se trunca: tira error. Y tira error en el momento de
    /// escribir la celda, o sea con las cuatro hojas ya armadas y el libro perdido —pasó con una
    /// etiqueta de la hoja de Avisos de 251 caracteres—. Cualquier etiqueta nueva, o una traducción
    /// más larga que el original, podría repetirlo. Lo que no se puede cortar va por EscribirNota,
    /// que lo parte en celdas en vez de recortarlo.
    /// </remarks>
    local procedure Texto(var Libro: Record "Excel Buffer" temporary; Valor: Text; Negrita: Boolean)
    begin
        Libro.AddColumn(CopyStr(Valor, 1, MaxCelda()), false, '', Negrita, false, false, '', Libro."Cell Type"::Text);
    end;

    local procedure Numero(var Libro: Record "Excel Buffer" temporary; Valor: Decimal; Negrita: Boolean)
    begin
        Libro.AddColumn(Valor, false, '', Negrita, false, false, '#,##0.00', Libro."Cell Type"::Number);
    end;

    local procedure Fecha(var Libro: Record "Excel Buffer" temporary; Valor: Date)
    begin
        if Valor = 0D then begin
            Texto(Libro, '', false);
            exit;
        end;
        Libro.AddColumn(Valor, false, '', false, false, false, 'dd/mm/yyyy', Libro."Cell Type"::Date);
    end;

    /// <remarks>
    /// La fórmula va SIN el "=" adelante, como la escribe la base en ExportBudgetFilterToFormula, y
    /// con el punto como separador decimal: el writer la pasa tal cual a Excel, así que un Format
    /// local —que acá escribe coma— la rompería en silencio. Por eso los números se arman con Num().
    /// </remarks>
    local procedure Formula(var Libro: Record "Excel Buffer" temporary; Expresion: Text)
    begin
        Libro.AddColumn(Expresion, true, '', false, false, false, '#,##0.00', Libro."Cell Type"::Number);
    end;

    local procedure Etiqueta(var Libro: Record "Excel Buffer" temporary; Etiq: Text; Valor: Text)
    begin
        Libro.NewRow();
        Texto(Libro, Etiq, true);
        Texto(Libro, Valor, false);
    end;

    local procedure Num(Valor: Decimal): Text
    begin
        exit(Format(Valor, 0, 9));
    end;

    local procedure Ref(Columna: Text; Fila: Integer): Text
    begin
        exit(Columna + Format(Fila));
    end;

    local procedure RefTotales(Columna: Text; Fila: Integer): Text
    begin
        exit(HojaTotalesTok + '!$' + Columna + '$' + Format(Fila));
    end;

    local procedure Rango(Columna: Text; UltimaFila: Integer): Text
    begin
        exit(Columna + Format(FFilaPrimera + 1) + ':' + Columna + Format(UltimaFila));
    end;

    local procedure Letra(Numero: Integer): Text
    var
        Abc: Text;
        Letras: Text;
        Resto: Integer;
    begin
        Abc := AbcTok;
        while Numero > 0 do begin
            Resto := (Numero - 1) mod 26;
            Letras := CopyStr(Abc, Resto + 1, 1) + Letras;
            Numero := (Numero - 1 - Resto) div 26;
        end;
        exit(Letras);
    end;

    var
        FEmpleados: List of [Code[20]];
        FNombre: Dictionary of [Code[20], Text];
        FCuil: Dictionary of [Code[20], Text];
        FConvenio: Dictionary of [Code[20], Code[20]];
        FZona: Dictionary of [Code[20], Code[20]];
        FObraSocial: Dictionary of [Code[20], Code[20]];
        FIngreso: Dictionary of [Code[20], Date];
        FEgreso: Dictionary of [Code[20], Date];
        FDias: Dictionary of [Code[20], Decimal];
        FVal: Dictionary of [Text, Decimal];
        FSinMapear: Dictionary of [Text, Decimal];
        FFaltanParametros: List of [Code[50]];
        FSinZona: List of [Code[20]];
        FSinCuil: List of [Code[20]];
        FTiposPresentes: List of [Code[20]];
        FZonas: List of [Code[20]];
        FPeriodo: Code[10];
        FTiposLiq: Text;
        FIncluirBorradores: Boolean;
        FFechaDesde: Date;
        FFechaHasta: Date;
        FLiquidaciones: Integer;
        FFilaPrimera: Integer;
        FFilaUltima: Integer;
        FTopeSipa: Decimal;
        FTopeSipaOs: Decimal;
        FDetraccionMes: Decimal;
        FArtFijo: Decimal;
        FSvco: Decimal;
        FBaseMinima: Decimal;
        FPctCntJub: Decimal;
        FPctCntIns: Decimal;
        FPctCntAfm: Decimal;
        FPctCntFne: Decimal;
        FPctCntOs: Decimal;
        FPctArt: Decimal;
        FPctTarDif: Decimal;
        FPctApoOs: Decimal;
        FPctFsr: Decimal;
        AbcTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', Locked = true;
        DigitosTok: Label '0123456789', Locked = true;
        HojaTotalesTok: Label 'TOTALES', Locked = true;
        HojaCntTok: Label 'CNT', Locked = true;
        HojaFsrTok: Label 'FSR', Locked = true;
        HojaDtoTok: Label 'Dto 814', Locked = true;
        HojaAvisosTok: Label 'Avisos', Locked = true;
        AcumRemunerativoTok: Label 'REMUNERATIVO_BRUTO', Locked = true;
        AcumNoRemunerativoTok: Label 'NO_REMUNERATIVO', Locked = true;
        AcumBaseSSTrabTok: Label 'BASE_SS_TRAB', Locked = true;
        AcumBaseSSVacTok: Label 'BASE_SS_VAC', Locked = true;
        AcumBaseOSTrabTok: Label 'BASE_OS_TRAB', Locked = true;
        AcumBaseOSVacTok: Label 'BASE_OS_VAC', Locked = true;
        AcumBaseLRTTok: Label 'BASE_LRT', Locked = true;
        AcumBaseSacTok: Label 'BASE_SAC', Locked = true;
        AcumBaseIG4Tok: Label 'BASE_IG4', Locked = true;
        AcumBaseExtIG4Tok: Label 'BASE_EXT_IG4', Locked = true;
        AtribZonaTok: Label 'ZONA_DESFAVORABLE', Locked = true;
        VarDetraccionTok: Label 'DED_CONT_PATR', Locked = true;
        VarDias30Tok: Label 'DIAS_ALTA_30', Locked = true;
        VarZonaTok: Label 'COD_ZONA', Locked = true;
        VarObraSocialTok: Label 'OBRA_SOCIAL', Locked = true;
        ParTopeSipaTok: Label 'TOPE_SIPA', Locked = true;
        ParTopeSipaOsTok: Label 'TOPE_SIPA_OS', Locked = true;
        ParDetraccionTok: Label 'DED_CONT_PATR', Locked = true;
        ParArtFijoTok: Label 'VALOR_ART_FIJO', Locked = true;
        ParSvoTok: Label 'VALOR_SVO', Locked = true;
        ParBaseMinTok: Label 'BASE_MIN_SIPA', Locked = true;
        ParPctCntJubTok: Label 'PCT_CONT_JUB', Locked = true;
        ParPctCntInsTok: Label 'PCT_CONT_19032', Locked = true;
        ParPctAsigFamTok: Label 'PCT_ASIG_FAMI', Locked = true;
        ParPctFneTok: Label 'PCT_FNE', Locked = true;
        ParPctCntOsTok: Label 'PCT_CONT_23660', Locked = true;
        ParPctArtTok: Label 'PCT_ART', Locked = true;
        ParPctTarDifTok: Label 'PCT_TAR_DIF', Locked = true;
        ParPctOsTok: Label 'PCT_OS', Locked = true;
        ParPctFsrTok: Label 'PCT_FSR', Locked = true;
        ParPctDto814Tok: Label 'PCT_DTO_814_', Locked = true;
        ClvRem: Label 'REM', Locked = true;
        ClvNoRem: Label 'NOREM', Locked = true;
        ClvBaseSS: Label 'BASE_SS', Locked = true;
        ClvBaseOS: Label 'BASE_OS', Locked = true;
        ClvBaseOSTrab: Label 'BASE_OS_TRAB', Locked = true;
        ClvBaseLRT: Label 'BASE_LRT', Locked = true;
        ClvBaseCnt: Label 'BASE_CNT', Locked = true;
        ClvBaseSac: Label 'BASE_SAC', Locked = true;
        ClvDetrac: Label 'DETRAC', Locked = true;
        ClvImpoRet: Label 'IMPO_RET', Locked = true;
        ClvImpoRetOs: Label 'IMPO_RET_OS', Locked = true;
        ClvApoJub: Label 'APO_JUB', Locked = true;
        ClvApoIns: Label 'APO_INS', Locked = true;
        ClvApoOs: Label 'APO_OS', Locked = true;
        ClvApoAdicOs: Label 'APO_ADIC_OS', Locked = true;
        ClvSindical: Label 'SINDICAL', Locked = true;
        ClvImpuesto: Label 'IMPUESTO', Locked = true;
        ClvCntBC: Label 'CNT_BC', Locked = true;
        ErrSinPeriodo: Label 'Elegí el período a declarar.';
        ErrPeriodoInexistente: Label 'No existe el período %1.', Comment = '%1 = código de período';
        ErrSinLiquidaciones: Label 'El período %1 no tiene liquidaciones para declarar con los filtros elegidos.', Comment = '%1 = código de período';
        ErrSinMapeo: Label 'Ningún concepto tiene Columna SICOSS asignada, así que todas las columnas de aportes y contribuciones saldrían en cero. Corré primero "Proponer Columna SICOSS" en Conceptos Liquidación y revisá la propuesta.';
        ErrTopeEnCero: Label 'El parámetro %1 no tiene valor al %2. Sin tope imponible todas las bases saldrían en cero y la declaración quedaría vacía.', Comment = '%1 = código de parámetro; %2 = fecha';
        TxtTituloTotales: Label 'Reporte SICOSS — período %1', Comment = '%1 = código de período';
        TxtTituloCnt: Label 'Contribuciones patronales — período %1', Comment = '%1 = código de período';
        TxtTituloFsr: Label 'Fondo Solidario de Redistribución — período %1', Comment = '%1 = código de período';
        TxtTituloAvisos: Label 'Avisos del reporte SICOSS — período %1', Comment = '%1 = código de período';
        TxtGenerado: Label 'Cobertura %1 a %2. Generado el %3.', Comment = '%1 = fecha desde; %2 = fecha hasta; %3 = fecha y hora';
        TxtTotales: Label 'TOTALES';
        TxtPorcentajes: Label 'PORCENTAJES';
        TxtMontos: Label 'MONTOS';
        TxtArtFijo: Label 'ART fijo por empleado';
        TxtTotalCnt: Label 'total cnt';
        TxtSvco: Label 'svco';
        TxtOtrasCnt: Label 'otras contribuciones (cargar a mano)';
        TxtTotalDdjj: Label 'total contribuciones';
        TxtPeriodo: Label 'Período';
        TxtGeneradoEl: Label 'Generado el';
        TxtUsuario: Label 'Usuario';
        TxtTiposFiltro: Label 'Tipos de liquidación';
        TxtTodosLosTipos: Label 'todos';
        TxtEstados: Label 'Estados incluidos';
        TxtConBorradores: Label 'Borrador, Calculada, Aprobada y Contabilizada';
        TxtSinBorradores: Label 'Calculada, Aprobada y Contabilizada (sin borradores)';
        TxtEmpleados: Label 'Empleados declarados';
        TxtLiquidaciones: Label 'Liquidaciones leídas';
        TxtTipoPresente: Label 'Tipo presente';
        TxtAvisoParametros: Label 'PARÁMETROS SIN VALOR a la fecha de declaración. Las columnas que dependen de ellos salen en cero:';
        TxtAvisoSinMapear: Label 'CONCEPTOS CON IMPORTE Y SIN COLUMNA SICOSS. No entran en ninguna columna de la declaración:';
        TxtComoSacarDeAvisos: Label 'Los que corresponda declarar se mapean en Conceptos; a los que no van —anticipos, embargos, gastos— se les pone "No se declara" y dejan de aparecer acá.';
        TxtAvisoSinZona: Label 'EMPLEADOS SIN ZONA (%1). Sin zona no hay crédito del decreto 814:', Comment = '%1 = cantidad';
        TxtAvisoSinCuil: Label 'EMPLEADOS SIN CUIL (%1). SICOSS los rechaza:', Comment = '%1 = cantidad';
        TxtComoLeer: Label 'CÓMO LEER LAS PLANILLAS';
        TxtNotaDetraccion: Label 'TOTALES: "DET APLICADA BC" es la detracción que el motor restó de verdad; "DET TOTAL" es la que corresponde al mes según los días. Si DIF DETRACCION no da cero, el empleado tuvo más de una liquidación en el mes y cada una restó la detracción completa.';
        TxtNotaDif: Label 'CNT: "TOT CNT TEORICO" recalcula la contribución desde la base y la alícuota; "TOT CNT BC" es lo que liquidó el motor. DIF BC distinta de cero es una diferencia real entre la alícuota plana y lo que se liquidó, no un error de la planilla.';
        TxtNotaDevengos: Label 'No se declaran los devengos: la familia 475x (jubilación, ley 19032, obra social y cuota sindical sobre el SAC devengado) es una provisión y se aporta cuando el SAC se paga.';
        TxtNotaTopes: Label 'Los topes del SIPA se aplican una sola vez sobre el mes entero, no liquidación por liquidación: el tope es mensual y se agota.';
        TxtNotaCnv: Label 'La columna CNV lleva el código de convenio de la última liquidación del mes, no la sigla de dos letras de las planillas anteriores (MR, OF, CA, FA, EC).';
        TxtResumen: Label '%1 empleados, %2 liquidaciones. Avisos: %3 conceptos sin columna SICOSS, %4 sin zona, %5 sin CUIL, %6 parámetros sin valor.', Comment = '%1..%6 = cantidades';
}
