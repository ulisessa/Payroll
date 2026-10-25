namespace UAS.Payroll;

using Microsoft.Finance.Currency;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;

/// <summary>Inspección de datos de entrada, sin construir el contexto ni ejecutar una liquidación.</summary>
/// <remarks>
/// La presencia es una FILA vigente, nunca un valor distinto de cero. La selección de candidatos
/// no asigna días propios ni anticipa importes: una condición que depende del cálculo se informa
/// como revisión. Todas las inserciones/modificaciones de este objeto son sobre temporales.
/// </remarks>
codeunit 110080 "Control Previo Liq."
{
    /// <summary>Acota la captura temporal sin perder casos ni filtros del usuario.</summary>
    procedure FiltrarVista(var Buffer: Record "Control Previo Liq. Buffer" temporary; Vista: Integer)
    var
        GrupoOriginal: Integer;
    begin
        if not Buffer.IsTemporary() then
            Error('Las vistas del control previo sólo admiten resultados temporales.');
        if not (Vista in [0, 1, 2]) then
            Error('La vista de preparación indicada no existe.');
        GrupoOriginal := Buffer.FilterGroup();
        Buffer.FilterGroup(2);
        case Vista of
            0: Buffer.SetRange(Severidad, Buffer.Severidad::Error);
            1: Buffer.SetFilter(Severidad, '%1|%2', Buffer.Severidad::Error, Buffer.Severidad::Advertencia);
            2: Buffer.SetRange(Severidad);
        end;
        Buffer.FilterGroup(GrupoOriginal);
    end;

    procedure Analizar(CodPeriodo: Code[10]; TipoLiq: Code[20]; FiltroEmpleado: Text; FiltroProyecto: Text; var Buffer: Record "Control Previo Liq. Buffer" temporary): Integer
    var
        Periodo: Record "Período Liquidación";
        Tipos: Record "Tipo Liquidación";
        Fase: Record "Fase Alta Empleado";
        Empleado: Record Employee;
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Progreso: Codeunit "Progreso Liq.";
        Vistos: Dictionary of [Code[20], Boolean];
        FiltroJob: Record Job;
    begin
        Reiniciar();
        Buffer.Reset();
        Buffer.DeleteAll();
        FCodPeriodo := CodPeriodo;
        if not Periodo.Get(CodPeriodo) then begin
            Emitir(Buffer, "Severidad Registro Liq."::Error, 'Contexto', '', '', '', 'El período no existe.', 'Seleccioná un período existente. No se inspeccionó ningún empleado.');
            exit(Buffer.Count());
        end;
        FDesde := Periodo."Fecha Desde";
        FHasta := Periodo."Fecha Hasta";
        if (FDesde = 0D) or (FHasta = 0D) or (FHasta < FDesde) then begin
            Emitir(Buffer, "Severidad Registro Liq."::Error, 'Contexto', '', '', '', 'El período no tiene un intervalo de fechas válido.', 'No se infieren fechas a partir del código del período.');
            exit(Buffer.Count());
        end;
        if not AplicarFiltroEmpleado(Empleado, FiltroEmpleado) then begin
            Emitir(Buffer, "Severidad Registro Liq."::Error, 'Contexto', '', '', '', 'El filtro de empleados no es válido.', GetLastErrorText());
            exit(Buffer.Count());
        end;
        if not AplicarFiltroProyecto(FiltroJob, FiltroProyecto) then begin
            Emitir(Buffer, "Severidad Registro Liq."::Error, 'Contexto', '', '', '', 'El filtro de proyectos no es válido.', GetLastErrorText());
            exit(Buffer.Count());
        end;
        if TipoLiq <> '' then begin
            if not Tipos.Get(TipoLiq) then begin
                Emitir(Buffer, "Severidad Registro Liq."::Error, 'Contexto', '', '', '', 'El tipo de liquidación no existe.', 'No se amplió la selección a otros tipos.');
                exit(Buffer.Count());
            end;
            Tipos.SetRange(Código, TipoLiq);
        end else
            Tipos.SetRange("Entra en Corrida Completa", true);
        Tipos.SetRange(Activo, true);
        CargarCatalogos();
        CargarVersiones(FHasta);
        FAnalizando := true;
        RevisarReglasVigencia(Buffer);
        Prevuelo.RevisarConfiguracion(FDesde, FHasta, Buffer);
        // Total desconocido: los candidatos salen recién al recorrer fases y asignaciones.
        Progreso.AbrirLote(0);
        Fase.SetFilter("Fecha Alta", '<=%1', FHasta);
        Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, FDesde);
        if Fase.FindSet() then
            repeat
                if not Vistos.ContainsKey(Fase."No. Empleado") then begin
                    Vistos.Add(Fase."No. Empleado", true);
                    Empleado.SetRange("No.", Fase."No. Empleado");
                    // El filtro del usuario queda en otro grupo: SetRange nunca puede ampliarlo.
                    if not Empleado.IsEmpty() then begin
                        Progreso.Registro(Fase."No. Empleado", TxtRevisando);
                        if Tipos.FindSet() then
                            repeat
                                if Tipos.CorreEnElMes(Tipos.Código, FHasta) then
                                    InspeccionarEmpleado(Fase."No. Empleado", Tipos, Periodo, FiltroProyecto, Buffer);
                            until Tipos.Next() = 0;
                        Progreso.FinalizarRegistro();
                    end;
                end;
            until Fase.Next() = 0;
        // El creador conserva a quien todavía no tiene fases migradas, siempre que exista una
        // ruta de estado/asignación. Una fase existente fuera del mes sí excluye a la persona.
        Empleado.SetRange("No.");
        if Empleado.FindSet() then
            repeat
                if not Vistos.ContainsKey(Empleado."No.") then begin
                    Fase.Reset();
                    Fase.SetRange("No. Empleado", Empleado."No.");
                    if Fase.IsEmpty() then
                        if TieneRutaEnPeriodo(Empleado."No.") then begin
                            FEmpleadosSinFase.Set(Empleado."No.", true);
                            if Tipos.FindSet() then
                                repeat
                                    if Tipos.CorreEnElMes(Tipos.Código, FHasta) then
                                        InspeccionarEmpleado(Empleado."No.", Tipos, Periodo, FiltroProyecto, Buffer);
                                until Tipos.Next() = 0;
                        end;
                end;
            until Empleado.Next() = 0;
        if FCandidatos = 0 then begin
            Clear(FEmpleado);
            Clear(FProyecto);
            Clear(FConvenio);
            Clear(FCategoria);
            FTipo := TipoLiq;
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Contexto', '', '', '', 'No se encontraron contextos elegibles para esta selección.', 'Se respetaron fases de alta, tipos, asignaciones, estados y filtros. Esto no acredita que la preparación del mes esté completa.');
        end;
        Progreso.Cerrar();
        FAnalizando := false;
        FRevisandoCondicion := false;
        if FSimular then
            SimularContextos(Buffer);
        AgruparResultados(Buffer);
        exit(Buffer.Count());
    end;

    /// <summary>Presencia y cascada exactas; el cero cargado devuelve true.</summary>
    procedure ResolverParametro(CodigoBase: Code[20]; Empleado: Code[20]; Proyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20]; FechaRef: Date; var Fila: Record "Parámetro Vigente"; var Motivo: Text): Boolean
    var
        Param: Record "Parámetro";
        Claves: Codeunit "Claves Parámetro Liq.";
        Ejes: List of [Code[10]];
        Clave: Code[50];
        BaseFisica: Code[20];
        CodigoFisico: Code[50];
    begin
        Clear(Fila);
        Clear(Motivo);
        if (CodigoBase = '') or (FechaRef = 0D) then begin
            Motivo := 'Falta el código de parámetro o la fecha de referencia.';
            exit(false);
        end;
        if FAnalizando then begin
            if not FParametros.Get(CodigoBase) then begin
                Motivo := 'No existe la definición del parámetro.';
                exit(false);
            end;
            Param := FParametros;
        end else
            if not Param.Get(CodigoBase) then begin
                Motivo := 'No existe la definición del parámetro.';
                exit(false);
            end;
        // La API pública también sirve fuera de Analizar: no retiene datos de llamadas anteriores.
        if not FAnalizando then
            CargarVersiones(FechaRef);
        PrepararMapa(FechaRef);
        Ejes := EjesDelParametro(Param, Empleado, Proyecto, FechaRef);
        Clave := Claves.ResolverConEjes(CodigoBase, Ejes, Empleado, Convenio, Categoria, FValores, FFechas);
        if not FValores.ContainsKey(Clave) then begin
            Motivo := 'No hay una fila vigente entre las claves candidatas de empleado, convenio/categoría, convenio y base, incluidos sus prefijos de ejes.';
            exit(false);
        end;
        BaseFisica := FBasesFisicas.Get(Clave);
        CodigoFisico := FCodigosFisicos.Get(Clave);
        FVersiones.Reset();
        if not FVersiones.Get(BaseFisica, CodigoFisico, FFechas.Get(Clave)) then begin
            Motivo := 'No se pudo identificar la fila física de la clave seleccionada.';
            exit(false);
        end;
        Fila := FVersiones;
        exit(true);
    end;

    procedure AtributoPresente(CodTipo: Code[20]; TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; FechaRef: Date): Boolean
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        exit(Atributo.Vigente(CodTipo, TipoEntidad, CodEntidad, FechaRef));
    end;

    /// <summary>Variables léxicas, sin textos, funciones, operadores ni referencias #/@.</summary>
    procedure ExtraerVariables(Texto: Text; var Nombres: List of [Text])
    var
        Control: Codeunit "Control Orden Acumuladores";
        Catalogo: Codeunit "Catálogo Variables Liq.";
        Tokens: List of [Text];
        Funciones: List of [Text];
        Operadores: List of [Text];
        Token: Text;
    begin
        Clear(Nombres);
        Control.ExtraerIdentificadores(Texto, Tokens);
        if FFunciones.Count() = 0 then
            FFunciones := Catalogo.GetNombresFunciones();
        if FOperadores.Count() = 0 then
            FOperadores := Catalogo.GetNombresOperadores();
        Funciones := FFunciones;
        Operadores := FOperadores;
        foreach Token in Tokens do begin
            Token := Token.ToUpper();
            if not Token.StartsWith('#') and not Token.StartsWith('@') then
                if not Funciones.Contains(Token) and not Operadores.Contains(Token) then
                    if not Nombres.Contains(Token) then
                        Nombres.Add(Token);
        end;
    end;

    /// <summary>0 ausente; 1 directo; 2 rama no demostrada; 3 IFZERO; 4 selector con cero admitido.</summary>
    procedure ClasificarUso(Expresion: Text; Nombre: Text): Integer
    begin
        exit(ClasificarSegmento(Expresion, Nombre.ToUpper(), 1, false, 0));
    end;

    /// <summary>Reúne lectores del mismo dato sin mezclar personas, fechas, causas ni vigencias.</summary>
    procedure AgruparResultados(var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Original: Record "Control Previo Liq. Buffer" temporary;
        Grupos: Dictionary of [Text, Integer];
        Clave: Text;
        Numero: Integer;
        Conceptos: Text;
        Repeticiones: Integer;
        Combinar: Boolean;
    begin
        if not Buffer.IsTemporary() then
            Error('El control previo sólo agrupa resultados temporales.');
        Buffer.Reset();
        if Buffer.FindSet() then
            repeat
                Original := Buffer;
                Original.Insert();
            until Buffer.Next() = 0;
        Buffer.DeleteAll();
        if Original.FindSet() then
            repeat
                Clave := ClaveDelAviso(Original);
                Repeticiones := Original.Repeticiones;
                if Repeticiones < 1 then
                    Repeticiones := 1;
                Combinar := Grupos.Get(Clave, Numero);
                if Combinar then begin
                    Buffer.Get(Numero);
                    Conceptos := UnirConceptos(Buffer."Conceptos relacionados", Original."Conceptos relacionados", Original."Cód. Concepto");
                    // Una lista completa es preferible a truncar silenciosamente su evidencia.
                    Combinar := StrLen(Conceptos) <= MaxStrLen(Buffer."Conceptos relacionados");
                end;
                if Combinar then begin
                    Buffer.Repeticiones += Repeticiones;
                    Buffer."Conceptos relacionados" := Conceptos;
                    // El barrido obligatorio y un lector condicional pueden describir la
                    // misma ausencia. Conservamos toda la evidencia y la severidad mayor.
                    if Original.Severidad.AsInteger() > Buffer.Severidad.AsInteger() then
                        Buffer.Severidad := Original.Severidad;
                    if Buffer."Cód. Concepto" = '' then
                        Buffer."Cód. Concepto" := Original."Cód. Concepto";
                    Buffer.Modify();
                end else begin
                    Buffer := Original;
                    Buffer.Repeticiones := Repeticiones;
                    Buffer."Conceptos relacionados" := UnirConceptos('', Original."Conceptos relacionados", Original."Cód. Concepto");
                    Buffer.Insert();
                    Grupos.Set(Clave, Buffer."No. Línea");
                end;
            until Original.Next() = 0;
        Buffer.Reset();
    end;

    local procedure ClaveDelAviso(Fila: Record "Control Previo Liq. Buffer" temporary): Text
    var
        Partes: List of [Text];
        Parte: Text;
        Clave: Text;
    begin
        if (Fila.Área = 'Atributos') and (Fila."Cód. Tipo Atributo" <> '') then
            Partes.Add('ATRIBUTO')
        else
            Partes.Add(Format(Fila.Severidad.AsInteger()));
        Partes.Add(Fila.Área);
        Partes.Add(Fila."Nombre Variable");
        Partes.Add(Fila."Cód. Parámetro");
        Partes.Add(Fila."No. Empleado");
        Partes.Add(Fila."No. Proyecto");
        Partes.Add(Fila."Cód. Convenio");
        Partes.Add(Fila."Cód. Categoría");
        Partes.Add(Fila."Cód. Tipo Liq.");
        Partes.Add(Format(Fila."Fecha Desde", 0, 9));
        Partes.Add(Format(Fila."Fecha Hasta", 0, 9));
        Partes.Add(Format(Fila."Vigencia Desde", 0, 9));
        Partes.Add(Fila."Clave Parámetro");
        Partes.Add(Format(Fila."Tipo Entidad".AsInteger()));
        Partes.Add(Fila."Cód. Entidad");
        Partes.Add(Fila."Cód. Tipo Atributo");
        Partes.Add(Fila."Nombre Fuente");
        Partes.Add(Fila.Mensaje);
        Partes.Add(Fila.Detalle);
        foreach Parte in Partes do
            Clave += Format(StrLen(Parte)) + ':' + Parte;
        exit(Clave);
    end;

    local procedure UnirConceptos(Lista: Text; Agregar: Text; Concepto: Code[20]): Text
    var
        Unicos: List of [Text];
        Elementos: List of [Text];
        Elemento: Text;
        Resultado: Text;
    begin
        Elementos := (Lista + '|' + Agregar + '|' + Concepto).Split('|');
        foreach Elemento in Elementos do begin
            Elemento := Elemento.Trim();
            if (Elemento <> '') and not Unicos.Contains(Elemento) then begin
                Unicos.Add(Elemento);
                if Resultado <> '' then
                    Resultado += '|';
                Resultado += Elemento;
            end;
        end;
        exit(Resultado);
    end;

    local procedure Reiniciar()
    begin
        FAnalizando := false;
        FRevisandoCondicion := false;
        FVersiones.Reset();
        FVersiones.DeleteAll();
        FConceptos.Reset();
        FConceptos.DeleteAll();
        FParametros.Reset();
        FParametros.DeleteAll();
        FFuentes.Reset();
        FFuentes.DeleteAll();
        Clear(FParametrosPorNombre);
        Clear(FAtributosPorNombre);
        Clear(FCodigosSistema);
        Clear(FNombresSistema);
        Clear(FNombresConcepto);
        Clear(FFunciones);
        Clear(FOperadores);
        Clear(FFuentesPorNombre);
        Clear(FVariablesExpresion);
        Clear(FValores);
        Clear(FFechas);
        Clear(FBasesFisicas);
        Clear(FCodigosFisicos);
        Clear(FEmitidos);
        Clear(FCandidatosVistos);
        Clear(FEmpleadosSinFase);
        Clear(FConversionRevisada);
        Clear(FParametrosConRegla);
        Clear(FVigenciasRevisadas);
        Clear(FProyectosNominaRevisados);
        Clear(FCoberturaRevisada);
        Clear(FContextosSimular);
        Clear(FCotizacionRevisada);
        Clear(FFechasProyectoRevisadas);
        Clear(FAvisosVigencia);
        Clear(FBasesEnFecha);
        Clear(FMotor);
        FFechaMapa := 0D;
        FCandidatos := 0;
        Clear(FEmpleado);
        Clear(FProyecto);
        Clear(FConvenio);
        Clear(FCategoria);
        Clear(FConvenioEvaluacion);
        Clear(FCategoriaEvaluacion);
        Clear(FTipo);
        Clear(FCodPeriodo);
        FDesde := 0D;
        FHasta := 0D;
        FFechaRef := 0D;
        FFechaAtributos := 0D;
        FAutoConversion := false;
    end;

    local procedure CargarCatalogos()
    var
        Param: Record "Parámetro";
        TipoAtr: Record "Tipo Atributo Liq.";
        Sistema: Record "Variable Sistema Liq.";
        Concepto: Record "Concepto Liquidación";
        Catalogo: Codeunit "Catálogo Variables Liq.";
        Setup: Record "Human Resources Setup";
        Fuente: Record "Fuente Datos Liquidación";
    begin
        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                FParametrosPorNombre.Set(Param."Nombre Variable", Param.Código);
                FParametros := Param;
                FParametros.Insert();
                if Format(Param."Antigüedad Máxima Vigencia") <> '' then
                    FParametrosConRegla.Add(Param.Código);
            until Param.Next() = 0;
        TipoAtr.SetFilter("Nombre Variable", '<>%1', '');
        if TipoAtr.FindSet() then
            repeat
                FAtributosPorNombre.Set(TipoAtr."Nombre Variable", TipoAtr.Código);
            until TipoAtr.Next() = 0;
        Sistema.SetRange(Activo, true);
        if Sistema.FindSet() then
            repeat
                FNombresSistema.Set(Sistema."Nombre Variable", true);
            until Sistema.Next() = 0;
        Sistema.SetRange("Cód. Cálculo", 'TIPO_LIQ');
        if Sistema.FindSet() then
            repeat
                FCodigosSistema.Set(Sistema."Nombre Variable", true);
            until Sistema.Next() = 0;
        FFunciones := Catalogo.GetNombresFunciones();
        if Setup.Get() then
            FAutoConversion := Setup."Convertir Param. por TC";
        if Fuente.FindSet() then
            repeat
                FFuentes := Fuente;
                FFuentes.Insert();
                FFuentesPorNombre.Set(Fuente."Nombre Variable", true);
            until Fuente.Next() = 0;
        Concepto.SetFilter("Vigencia Desde", '<=%1', FHasta);
        if Concepto.FindSet() then
            repeat
                FConceptos := Concepto;
                FConceptos.Insert();
                FNombresConcepto.Set(Concepto.Código, true);
            until Concepto.Next() = 0;
    end;

    local procedure CargarVersiones(FechaMaxima: Date)
    var
        Version: Record "Parámetro Vigente";
    begin
        FVersiones.Reset();
        FVersiones.DeleteAll();
        Version.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        Clear(FBasesEnFecha);
        Version.SetFilter("Vigencia Desde", '<=%1', FechaMaxima);
        if Version.FindSet() then
            repeat
                FVersiones := Version;
                FVersiones.Insert();
            until Version.Next() = 0;
        FFechaMapa := 0D;
    end;

    local procedure PrepararMapa(FechaRef: Date)
    var
        Clave: Code[50];
    begin
        if FFechaMapa = FechaRef then
            exit;
        Clear(FValores);
        Clear(FFechas);
        Clear(FBasesFisicas);
        Clear(FCodigosFisicos);
        FVersiones.Reset();
        FVersiones.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        FVersiones.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if FVersiones.FindSet() then
            repeat
                Clave := ClaveEfectiva(FVersiones);
                // Misma normalización y recorrido que Contexto.BuildParametroCache; En Uso no filtra.
                FValores.Set(Clave, FVersiones.Valor);
                FFechas.Set(Clave, FVersiones."Vigencia Desde");
                FBasesFisicas.Set(Clave, FVersiones."Cód. Parámetro Base");
                FCodigosFisicos.Set(Clave, FVersiones."Cód. Parámetro");
            until FVersiones.Next() = 0;
        FFechaMapa := FechaRef;
    end;

    local procedure ClaveEfectiva(Version: Record "Parámetro Vigente"): Code[50]
    begin
        if (Version."Cód. Parámetro Base" = '') or (Version."Cód. Parámetro" = Version."Cód. Parámetro Base") then
            exit(Version."Cód. Parámetro");
        if Format(Version."Cód. Parámetro").StartsWith(Version."Cód. Parámetro Base" + '_') then
            exit(Version."Cód. Parámetro");
        exit(CopyStr(Version."Cód. Parámetro Base" + '_' + Version."Cód. Parámetro", 1, 50));
    end;

    local procedure EjesDelParametro(Param: Record "Parámetro"; Empleado: Code[20]; Proyecto: Code[20]; FechaRef: Date) Ejes: List of [Code[10]]
    var
        Tipos: List of [Code[20]];
        Tipo: Code[20];
        Sufijo: Code[10];
    begin
        if Param."Cód. Tipo Atributo 1" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 1");
        if Param."Cód. Tipo Atributo 2" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 2");
        if Param."Cód. Tipo Atributo 3" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 3");
        foreach Tipo in Tipos do begin
            Sufijo := SufijoDeEje(Tipo, Empleado, Proyecto, FechaRef);
            if Sufijo = '' then
                exit;
            Ejes.Add(Sufijo);
        end;
    end;

    local procedure SufijoDeEje(CodTipo: Code[20]; Empleado: Code[20]; Proyecto: Code[20]; FechaRef: Date): Code[10]
    var
        Tipo: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
        Valor: Record "Valor Atributo Liq.";
        Entidad: Code[20];
        Fecha: Date;
    begin
        if not Tipo.Get(CodTipo) then
            exit('');
        Entidad := EntidadDelContexto(Tipo."Tipo Entidad", Empleado, Proyecto);
        Fecha := FechaRef;
        if FAnalizando and (Empleado = FEmpleado) and (Tipo."Tipo Entidad" = Tipo."Tipo Entidad"::Empleado) then
            Fecha := FFechaAtributos;
        if not Atributo.Vigente(CodTipo, Tipo."Tipo Entidad", Entidad, Fecha) then
            exit('');
        // El motor elige por tipo/código (no por el padre). No se altera esa semántica aquí.
        Valor.SetRange("Cód. Tipo Atributo", CodTipo);
        Valor.SetRange(Código, Atributo."Cód. Valor");
        if Valor.FindFirst() then
            exit(Valor."Sufijo Parámetro");
        exit('');
    end;

    local procedure InspeccionarEmpleado(Empleado: Code[20]; Tipo: Record "Tipo Liquidación"; Periodo: Record "Período Liquidación"; FiltroProyecto: Text; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Personal: Record "Personal Proyecto";
        Proyecto: Record Job;
        Fase: Record "Fase Alta Empleado";
        ProyectoNomina: Code[20];
        UltimaBaja: Date;
    begin
        if Tipo.EsBajaEmpleado(Tipo.Código) then begin
            Fase.SetRange("No. Empleado", Empleado);
            Fase.SetRange("Fecha Baja", FDesde, FHasta);
            if not Fase.FindLast() then
                exit;
            UltimaBaja := Fase."Fecha Baja";
        end;
        if Tipo."Agrupa por Empleado" then begin
            ProyectoNomina := ProyectoNominaDe(Empleado, FDesde, FHasta);
            if FiltroProyecto <> '' then begin
                if ProyectoNomina = '' then
                    exit;
                AplicarFiltroProyecto(Proyecto, FiltroProyecto);
                Proyecto.SetRange("No.", ProyectoNomina);
                if Proyecto.IsEmpty() then
                    exit;
            end;
            InspeccionarContexto(Empleado, ProyectoNomina, Tipo, Periodo, UltimaBaja, Buffer);
            exit;
        end;
        Personal.SetRange("No. Empleado", Empleado);
        Personal.SetFilter("Fecha Alta Asignación", '<=%1', FHasta);
        if not Tipo.EsArribo(Tipo.Código) then
            Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, FDesde);
        if Personal.FindSet() then
            repeat
                Proyecto.Reset();
                AplicarFiltroProyecto(Proyecto, FiltroProyecto);
                Proyecto.SetRange("No.", Personal."No. Proyecto");
                if Tipo."Tipo Proyecto" > 0 then
                    Proyecto.SetRange(Tipo, Tipo."Tipo Proyecto");
                if Tipo.EsArribo(Tipo.Código) then
                    Proyecto.SetRange("Ending Date", FDesde, FHasta)
                else
                    if Tipo.Disparador = Tipo.Disparador::MareaEnCurso then
                        Proyecto.SetFilter("Ending Date", '%1|>%2', 0D, FHasta);
                if Proyecto.FindFirst() then
                    if (not Tipo.EsArribo(Tipo.Código)) or (Personal."Fecha Baja" = 0D) or (Personal."Fecha Baja" >= Proyecto."Starting Date") then
                        InspeccionarContexto(Empleado, Proyecto."No.", Tipo, Periodo, UltimaBaja, Buffer);
            until Personal.Next() = 0;
    end;

    local procedure InspeccionarContexto(Empleado: Code[20]; Proyecto: Code[20]; Tipo: Record "Tipo Liquidación"; Periodo: Record "Período Liquidación"; FechaBaja: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Lote: Codeunit "Proceso Liq. Por Lote";
        Par: Codeunit "Convenio Categoría Liq.";
        Cabecera: Record "Liquidación" temporary;
        Job: Record Job;
        Convenio: Record "Convenio Colectivo";
        Clave: Text;
        DesdeCobertura: Date;
        HastaCobertura: Date;
    begin
        Clave := ClaveContexto(Empleado, Proyecto, Tipo.Código);
        if FCandidatosVistos.ContainsKey(Clave) then
            exit;
        FCandidatosVistos.Add(Clave, true);
        if not Lote.EstadosJustifican(Empleado, Periodo.Código, Tipo.Código, Proyecto) then
            exit;
        FEmpleado := Empleado;
        FProyecto := Proyecto;
        FTipo := Tipo.Código;
        FFechaRef := FHasta;
        if Tipo.EsArribo(Tipo.Código) then
            if Job.Get(Proyecto) then
                if Job."Ending Date" <> 0D then
                    FFechaRef := Job."Ending Date";
        Cabecera."Cód. Período" := Periodo.Código;
        Cabecera."Cód. Tipo Liq." := Tipo.Código;
        Cabecera."No. Empleado" := Empleado;
        Cabecera."No. Proyecto" := Proyecto;
        Cabecera.Cobertura(DesdeCobertura, HastaCobertura);
        if (FechaBaja <> 0D) and (FechaBaja < HastaCobertura) then
            HastaCobertura := FechaBaja;
        FFechaAtributos := FFechaRef;
        if Tipo.EsBajaEmpleado(Tipo.Código) and (HastaCobertura <> 0D) and (HastaCobertura < FFechaAtributos) then
            FFechaAtributos := HastaCobertura;
        FFechaTC := FechaDeCotizacion(Empleado, Proyecto, Tipo.Código, FFechaRef, HastaCobertura);
        Clear(FMonedaContexto);
        FMonedasMixtas := false;
        FEncuadreConocido := Par.ParDeEntidad(Empleado, FFechaAtributos, DesdeCobertura, HastaCobertura, FConvenio, FCategoria);
        if FEncuadreConocido then
            if Convenio.Get(FConvenio) then begin
                if (Tipo."Aplica A" <> Tipo."Aplica A"::Todos) and (Convenio."Tipo Empleado" <> Convenio."Tipo Empleado"::Todos) then
                    if Tipo."Aplica A" <> Convenio."Tipo Empleado" then
                        exit;
            end else
                FEncuadreConocido := false;
        FCandidatos += 1;
        RevisarProyectoInactividad(Tipo, Buffer);
        RevisarFechasProyecto(Buffer);
        RevisarCoberturaEstados(Empleado, DesdeCobertura, HastaCobertura, Buffer);
        RevisarCotizacionReciente(FConvenio, FCategoria, Buffer);
        if FEmpleadosSinFase.ContainsKey(Empleado) then
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Contexto', '', '', '', 'El empleado no tiene fases de alta cargadas.', 'Se conservó la ruta de estados/asignaciones, igual que el creador. Falta confirmar la pertenencia a la empresa y su cobertura temporal.');
        if not FEncuadreConocido then
            Emitir(Buffer, "Severidad Registro Liq."::Advertencia, 'Encuadre', '', '', '', 'No se pudo resolver un convenio vigente del empleado.', 'Las dependencias que requieren convenio/categoría quedan como revisión; no se supone un precio faltante para un encuadre desconocido.');
        RevisarAtributosObligatorios(Buffer);
        RevisarVigenciasContexto(FConvenio, FCategoria, Buffer);
        RevisarConversionContexto(FConvenio, FCategoria, 1, Buffer);
        RevisarConceptos(Tipo, DesdeCobertura, HastaCobertura, Buffer);
        if FSimular then
            FContextosSimular.Add(StrSubstNo('%1|%2|%3|%4|%5', Empleado, Proyecto, Tipo.Código, FConvenio, FCategoria));
    end;

    /// <summary>
    /// Además de la revisión estática, calcula cada contexto en una simulación que se revierte, para encontrar los precios que una
    /// fórmula usó sin fila y los errores del cálculo. Tarda lo que una corrida completa del alcance.
    /// </summary>
    procedure SetSimularCalculo(Simular: Boolean)
    begin
        FSimular := Simular;
    end;

    /// <summary>Corre la simulación de cada contexto candidato y vuelca lo que encontró, con progreso.</summary>
    /// <remarks>
    /// Cada simulación es un Codeunit.Run que termina en Error y revierte todo (ver "Simulación Liq."): por eso no puede haber
    /// escrituras pendientes, y no las hay, porque el control sólo escribe temporales. Un cálculo que falla de verdad se informa
    /// como error con su mensaje; uno que termina, con un error por cada precio que leyó sin fila.
    /// </remarks>
    local procedure SimularContextos(var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Simulacion: Codeunit "Simulación Liq.";
        Progreso: Codeunit "Progreso Liq.";
        Faltantes: Dictionary of [Text, Text];
        Partes: List of [Text];
        Contexto: Text;
        Parametro: Text;
        Conceptos: Text;
        Primero: Text;
    begin
        if FContextosSimular.Count() = 0 then
            exit;
        Progreso.AbrirLote(FContextosSimular.Count());
        foreach Contexto in FContextosSimular do begin
            Partes := Contexto.Split('|');
            FEmpleado := CopyStr(Partes.Get(1), 1, MaxStrLen(FEmpleado));
            FProyecto := CopyStr(Partes.Get(2), 1, MaxStrLen(FProyecto));
            FTipo := CopyStr(Partes.Get(3), 1, MaxStrLen(FTipo));
            FConvenio := CopyStr(Partes.Get(4), 1, MaxStrLen(FConvenio));
            FCategoria := CopyStr(Partes.Get(5), 1, MaxStrLen(FCategoria));
            Progreso.Registro(FEmpleado, StrSubstNo(TxtSimulando, FTipo, FProyecto));

            Clear(Simulacion);
            Simulacion.Preparar(FEmpleado, FProyecto, FTipo, FCodPeriodo);
            ClearLastError();
            if Simulacion.Run() then;
            if Simulacion.Completa() then begin
                Simulacion.GetPreciosFaltantes(Faltantes);
                foreach Parametro in Faltantes.Keys() do begin
                    Conceptos := Faltantes.Get(Parametro);
                    Primero := Conceptos;
                    if Primero.Contains('|') then
                        Primero := Primero.Substring(1, Primero.IndexOf('|') - 1);
                    Emitir(Buffer, "Severidad Registro Liq."::Error, 'Precio', Parametro, '', CopyStr(Primero, 1, 20),
                        StrSubstNo('Precio sin valor: %1.', Parametro),
                        StrSubstNo('Al simular el cálculo, la fórmula de %1 leyó %2 como valor y no tiene ninguna fila vigente para este empleado (%3/%4): liquida en cero sin dar error. Cargá la vigencia que corresponda o cubrí la ausencia en la fórmula (IFZERO) si es intencional.',
                            Conceptos.Replace('|', ', '), Parametro, FConvenio, FCategoria));
                    Buffer."Conceptos relacionados" := CopyStr(Conceptos.Replace('|', ', '), 1, MaxStrLen(Buffer."Conceptos relacionados"));
                    Buffer.Modify();
                end;
            end else
                Emitir(Buffer, "Severidad Registro Liq."::Error, 'Cálculo', '', '', '',
                    'La simulación del cálculo falló.',
                    CopyStr(GetLastErrorText(), 1, 2048));
            Progreso.FinalizarRegistro();
        end;
        Progreso.Cerrar();
    end;

    local procedure RevisarProyectoInactividad(Tipo: Record "Tipo Liquidación"; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Proyecto: Record Job;
        HRSetup: Record "Human Resources Setup";
        Atributo: Record "Atributo Entidad Liq.";
        NominaBuque: Code[20];
        Detalle: Text;
        Numero: Integer;
    begin
        // Se llega sólo desde un candidato que pasó fases, asignación, estados y filtros.
        // Se comprueba el destino, no una copia obligatoria del atributo en cada marea.
        // La nómina administrativa no necesita esta revisión ni se barre el histórico de Job.
        if Tipo."Agrupa por Empleado" or (FProyecto = '') then
            exit;
        if not Proyecto.Get(FProyecto) then
            exit;
        if Proyecto.Tipo <> 1 then
            exit;
        if (Proyecto."Ending Date" <> 0D) and (Proyecto."Ending Date" < FDesde) then
            exit;
        if FProyectosNominaRevisados.ContainsKey(FProyecto) then
            exit;

        if Proyecto."Global Dimension 1 Code" <> '' then
            NominaBuque := Atributo.ValorVigente('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", FFechaRef);
        // El creador agrupado usa PROY_NOMINA del buque; su presencia válida ya acredita
        // parametrización. No se fuerza a duplicarla en Proyecto Inactividad Nómina.
        if DestinoNominaValido(NominaBuque, Proyecto."No.") then
            exit;
        // Son otras rutas existentes: la transición de estados conserva Job -> RR.HH.
        // Reconocerlas no cambia el asignador ni afirma que éste ya lea el atributo.
        if DestinoNominaValido(Proyecto."Proyecto Inactividad Nómina", Proyecto."No.") then
            exit;
        if HRSetup.Get() then
            if DestinoNominaValido(HRSetup."Proyecto Nómina", Proyecto."No.") then
                exit;
        // Un candidato de marea no prueba que se insertará una transición de estados.
        // Por eso la ausencia de estas rutas es revisión opcional, no error de importe.
        FProyectosNominaRevisados.Add(FProyecto, true);
        Detalle := StrSubstNo('No se encontró un destino de nómina válido en las rutas configuradas: PROY_NOMINA del buque %1 vigente al %2 (valor: %3), Proyecto Inactividad Nómina de la marea (valor: %4) y Proyecto Nómina de recursos humanos (valor: %5). El destino debe existir, ser improductivo y distinto de la marea. Revisar si se necesitará una transición de estados; esta candidatura no demuestra un error del cálculo. No se completaron datos ni se modificó la resolución del motor.',
            Proyecto."Global Dimension 1 Code", Format(FFechaRef, 0, 9), NominaBuque,
            Proyecto."Proyecto Inactividad Nómina", HRSetup."Proyecto Nómina");

        // Tarea del proyecto, sin el empleado/tipo del primer consumidor. Abrir dato abre Job Card.
        Buffer.Reset();
        if Buffer.FindLast() then
            Numero := Buffer."No. Línea";
        Buffer.Init();
        Buffer."No. Línea" := Numero + 1;
        Buffer.Severidad := Buffer.Severidad::Advertencia;
        Buffer.Área := 'Proyectos';
        Buffer."No. Proyecto" := Proyecto."No.";
        Buffer."Tipo Entidad" := Buffer."Tipo Entidad"::Proyecto;
        Buffer."Cód. Entidad" := Proyecto."No.";
        Buffer."Fecha Desde" := FDesde;
        Buffer."Fecha Hasta" := FHasta;
        Buffer.Mensaje := 'Revisar el destino de nómina para una eventual transición de estados.';
        Buffer.Detalle := CopyStr(Detalle, 1, MaxStrLen(Buffer.Detalle));
        Buffer.Repeticiones := 1;
        Buffer.Insert();
    end;

    /// <summary>Todos los días que cubre ESTA liquidación, mientras el empleado está de alta, tienen que tener un estado.</summary>
    /// <remarks>
    /// La ventana es la cobertura del contexto y no el período: una liquidación de marea cubre sólo las fechas del proyecto, y una
    /// final llega hasta la baja. Fuera de una fase de alta no se exige estado; sin fases cargadas, se exige en toda la ventana.
    /// Un día sin estado no se liquida en ninguna parte y no da error: es lo que este control existe para mostrar antes.
    /// </remarks>
    local procedure RevisarCoberturaEstados(Empleado: Code[20]; Desde: Date; Hasta: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Estado: Record "Estado Empleado";
        Fase: Record "Fase Alta Empleado";
        Cubiertos: Dictionary of [Date, Boolean];
        Dia: Date;
        Inicio: Date;
        Fin: Date;
        HuecoDesde: Date;
        TieneFases: Boolean;
        EnFase: Boolean;
    begin
        if (Desde = 0D) or (Hasta = 0D) or (Hasta < Desde) then
            exit;
        if FCoberturaRevisada.ContainsKey(Empleado + '|' + Format(Desde, 0, 9) + '|' + Format(Hasta, 0, 9)) then
            exit;
        FCoberturaRevisada.Add(Empleado + '|' + Format(Desde, 0, 9) + '|' + Format(Hasta, 0, 9), true);

        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
        if Estado.FindSet() then
            repeat
                Fin := Estado.FechaFinEfectiva();
                if Fin >= Desde then begin
                    Inicio := Estado."Fecha Inicio";
                    if Inicio < Desde then
                        Inicio := Desde;
                    if Fin > Hasta then
                        Fin := Hasta;
                    for Dia := Inicio to Fin do
                        if not Cubiertos.ContainsKey(Dia) then
                            Cubiertos.Add(Dia, true);
                end;
            until Estado.Next() = 0;

        Fase.SetRange("No. Empleado", Empleado);
        TieneFases := not Fase.IsEmpty();
        for Dia := Desde to Hasta + 1 do begin
            EnFase := false;
            if Dia <= Hasta then
                if not TieneFases then
                    EnFase := true
                else begin
                    Fase.SetFilter("Fecha Alta", '<=%1', Dia);
                    Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, Dia);
                    EnFase := not Fase.IsEmpty();
                end;
            if EnFase and not Cubiertos.ContainsKey(Dia) then begin
                if HuecoDesde = 0D then
                    HuecoDesde := Dia;
            end else
                if HuecoDesde <> 0D then begin
                    EmitirHuecoEstado(Buffer, HuecoDesde, Dia - 1);
                    HuecoDesde := 0D;
                end;
        end;
    end;

    local procedure EmitirHuecoEstado(var Buffer: Record "Control Previo Liq. Buffer" temporary; Desde: Date; Hasta: Date)
    begin
        Emitir(Buffer, "Severidad Registro Liq."::Error, 'Estados', '', '', '',
            StrSubstNo('Días de alta sin estado del %1 al %2.', Format(Desde), Format(Hasta)),
            StrSubstNo('%1 día(s) de la cobertura de esta liquidación, con el empleado de alta, no tienen ningún estado cargado: no se liquidan en ninguna parte. Cargá el estado que corresponda en Estados del Empleado.', Hasta - Desde + 1));
        Buffer."Fecha Desde" := Desde;
        Buffer."Fecha Hasta" := Hasta;
        Buffer."Tipo Entidad" := Buffer."Tipo Entidad"::Empleado;
        Buffer."Cód. Entidad" := FEmpleado;
        Buffer.Modify();
    end;

    /// <summary>Una marea sin fecha de inicio, o que termina antes de empezar, no se puede liquidar bien.</summary>
    /// <remarks>
    /// La fecha de fin en blanco no es un error: es la marea en curso. Tampoco se controla la duración: hay proyectos productivos de
    /// planta (PP-…) que duran el año entero. Los estados fuera de las fechas del proyecto tampoco: los de puerto lo están a propósito.
    /// </remarks>
    local procedure RevisarFechasProyecto(var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Proyecto: Record Job;
        Mensaje: Text;
    begin
        if FProyecto = '' then
            exit;
        if FFechasProyectoRevisadas.ContainsKey(FProyecto) then
            exit;
        FFechasProyectoRevisadas.Add(FProyecto, true);
        if not Proyecto.Get(FProyecto) then
            exit;
        if Proyecto.Tipo <> 1 then
            exit;
        if Proyecto."Starting Date" = 0D then
            Mensaje := 'El proyecto no tiene fecha de inicio.'
        else
            if (Proyecto."Ending Date" <> 0D) and (Proyecto."Ending Date" < Proyecto."Starting Date") then
                Mensaje := StrSubstNo('El proyecto termina (%1) antes de empezar (%2).', Format(Proyecto."Ending Date"), Format(Proyecto."Starting Date"));
        if Mensaje = '' then
            exit;
        Emitir(Buffer, "Severidad Registro Liq."::Error, 'Proyectos', '', '', '', Mensaje,
            'Las fechas del proyecto definen la cobertura de sus liquidaciones, la fecha de referencia del cierre y la cotización. Corregilas en la ficha del proyecto.');
        Buffer."Tipo Entidad" := Buffer."Tipo Entidad"::Proyecto;
        Buffer."Cód. Entidad" := FProyecto;
        Buffer.Modify();
    end;

    /// <summary>Cada moneda en que hay un precio del contexto necesita una cotización cargada y reciente a la fecha de cotización.</summary>
    /// <remarks>
    /// Independiente de la conversión automática: con ella apagada, las fórmulas multiplican por TC_COMPRADOR/TC_VENDEDOR, que
    /// salen de la misma tabla. Sin ninguna cotización hasta la fecha es error; con la última de más de 5 días, revisión (cubre fines
    /// de semana y feriados). Se informa una vez por moneda y fecha, no por empleado.
    /// </remarks>
    local procedure RevisarCotizacionReciente(Convenio: Code[20]; Categoria: Code[20]; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Catalogo: Record "Parámetro" temporary;
        Fila: Record "Parámetro Vigente";
        Cotizacion: Record "Currency Exchange Rate";
        Monedas: List of [Code[10]];
        Moneda: Code[10];
        Motivo: Text;
        Clave: Text;
    begin
        if FFechaTC = 0D then
            exit;
        Catalogo.Copy(FParametros, true);
        Catalogo.Reset();
        if Catalogo.FindSet() then
            repeat
                if ResolverParametro(Catalogo.Código, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, Fila, Motivo) then
                    if (Fila.Moneda <> '') and not Monedas.Contains(Fila.Moneda) then
                        Monedas.Add(Fila.Moneda);
            until Catalogo.Next() = 0;

        foreach Moneda in Monedas do begin
            Clave := Moneda + '|' + Format(FFechaTC, 0, 9);
            if not FCotizacionRevisada.ContainsKey(Clave) then begin
                FCotizacionRevisada.Add(Clave, true);
                Cotizacion.SetRange("Currency Code", Moneda);
                Cotizacion.SetFilter("Starting Date", '<=%1', FFechaTC);
                if not Cotizacion.FindLast() then
                    EmitirCotizacion(Buffer, "Severidad Registro Liq."::Error, Moneda,
                        StrSubstNo('No hay cotización de %1 hasta el %2.', Moneda, Format(FFechaTC)),
                        'Hay precios cargados en esta moneda y la liquidación los convierte con la cotización de "Tipos de cambio" a la fecha de cotización. Cargala o traela con "Traer cotizaciones del BNA".')
                else
                    if FFechaTC - Cotizacion."Starting Date" > 5 then
                        EmitirCotizacion(Buffer, "Severidad Registro Liq."::Advertencia, Moneda,
                            StrSubstNo('La última cotización de %1 es del %2 (%3 días antes del %4).', Moneda, Format(Cotizacion."Starting Date"), FFechaTC - Cotizacion."Starting Date", Format(FFechaTC)),
                            'Se usaría esa cotización. Si hubo cotizaciones posteriores, cargalas o traelas con "Traer cotizaciones del BNA".');
            end;
        end;
    end;

    local procedure EmitirCotizacion(var Buffer: Record "Control Previo Liq. Buffer" temporary; Severidad: Enum "Severidad Registro Liq."; Moneda: Code[10]; Mensaje: Text; Detalle: Text)
    var
        Empleado: Code[20];
        Proyecto: Code[20];
        Tipo: Code[20];
        Convenio: Code[20];
        Categoria: Code[20];
    begin
        // Es de la moneda y la fecha, no de una persona: se emite sin contexto para que no parezca un problema de este empleado.
        Empleado := FEmpleado;
        Proyecto := FProyecto;
        Tipo := FTipo;
        Convenio := FConvenio;
        Categoria := FCategoria;
        Clear(FEmpleado);
        Clear(FProyecto);
        Clear(FTipo);
        Clear(FConvenio);
        Clear(FCategoria);
        Emitir(Buffer, Severidad, 'Moneda', '', '', '', Mensaje, Detalle);
        Buffer."Fecha Desde" := FFechaTC;
        Buffer."Fecha Hasta" := FFechaTC;
        Buffer.Modify();
        FEmpleado := Empleado;
        FProyecto := Proyecto;
        FTipo := Tipo;
        FConvenio := Convenio;
        FCategoria := Categoria;
    end;

    local procedure DestinoNominaValido(Codigo: Code[20]; Marea: Code[20]): Boolean
    var
        Destino: Record Job;
    begin
        if (Codigo = '') or (Codigo = Marea) then
            exit(false);
        if not Destino.Get(Codigo) then
            exit(false);
        exit(Destino.Tipo = 2);
    end;

    local procedure RevisarConceptos(Tipo: Record "Tipo Liquidación"; DesdeCobertura: Date; HastaCobertura: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Version: Record "Concepto Liquidación" temporary;
        Ultimas: Dictionary of [Code[20], Date];
        Codigo: Code[20];
        Convenio: Record "Convenio Colectivo";
        Condicion: Integer;
        Grado: Integer;
        Par: Codeunit "Convenio Categoría Liq.";
        ConvenioEval: Code[20];
        CategoriaEval: Code[20];
    begin
        FConceptos.Reset();
        FConceptos.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if FConceptos.FindSet() then
            repeat
                Ultimas.Set(FConceptos.Código, FConceptos."Vigencia Desde");
            until FConceptos.Next() = 0;
        foreach Codigo in Ultimas.Keys() do begin
            FConceptos.Get(Codigo, Ultimas.Get(Codigo));
            Version := FConceptos;
            if Version.VigenteA(FFechaRef) and TipoCompatible(Version, Tipo) then begin
                Grado := 1;
                ConvenioEval := FConvenio;
                CategoriaEval := FCategoria;
                if Version."Par CCT a Usar" = Version."Par CCT a Usar"::Puesto then
                    if not Par.ParDePuesto(FEmpleado, FFechaRef, FDesde, FHasta, ConvenioEval, CategoriaEval) then begin
                        ConvenioEval := FConvenio;
                        CategoriaEval := FCategoria;
                    end;
                if FEncuadreConocido then begin
                    if not FMotor.CCTAplicaAConcepto(Version, ConvenioEval, CategoriaEval, FFechaRef) then
                        Grado := 0;
                    if Convenio.Get(FConvenio) then
                        if (Version."Aplica A" <> Version."Aplica A"::Todos) and (Convenio."Tipo Empleado" <> Convenio."Tipo Empleado"::Todos) then
                            if Version."Aplica A" <> Convenio."Tipo Empleado" then
                                Grado := 0;
                end else
                    Grado := 2;
                if Grado <> 0 then begin
                    FConvenioEvaluacion := ConvenioEval;
                    FCategoriaEvaluacion := CategoriaEval;
                    // UsarParCCT reconvierte todo el conjunto resuelto, antes de la condición.
                    RevisarVigenciasContexto(ConvenioEval, CategoriaEval, Buffer);
                    RevisarConversionContexto(ConvenioEval, CategoriaEval, Grado, Buffer);
                    Condicion := CondicionEstatica(Version.Condición, 0);
                    // La condición también puede necesitar entradas, aun si no produce línea.
                    FRevisandoCondicion := true;
                    RevisarExpresion(Version, Version.Condición, Grado, DesdeCobertura, HastaCobertura, Buffer);
                    FRevisandoCondicion := false;
                    if Condicion <> 0 then begin
                        if Condicion = -1 then
                            Grado := 2;
                        RevisarExpresion(Version, Version.Fórmula, Grado, DesdeCobertura, HastaCobertura, Buffer);
                        RevisarExpresion(Version, Version."Variable Cantidad", Grado, DesdeCobertura, HastaCobertura, Buffer);
                        RevisarExpresion(Version, Version."Variable Base", Grado, DesdeCobertura, HastaCobertura, Buffer);
                        RevisarExpresion(Version, Version."Fórmula Orden Cálculo", Grado, DesdeCobertura, HastaCobertura, Buffer);
                        RevisarExpresion(Version, Version."Factor Importe Consumo", 2, DesdeCobertura, HastaCobertura, Buffer);
                        RevisarExpresion(Version, Version."Cantidad Matriz", Grado, DesdeCobertura, HastaCobertura, Buffer);
                        if Version."Cód. Parámetro Valor" <> '' then
                            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Parámetros', '', CopyStr(Version."Cód. Parámetro Valor", 1, 20), Version.Código, 'El precio por lote requiere el contexto de cada lote.', 'No se usa el encuadre actual para certificar precios históricos de una matriz o de consumos de francos.');
                    end;
                end;
            end;
        end;
    end;

    local procedure TipoCompatible(Concepto: Record "Concepto Liquidación"; Tipo: Record "Tipo Liquidación"): Boolean
    var
        Lista: Text;
    begin
        Lista := Concepto."Tipos Liq. Aplicables";
        if Lista = '' then begin
            if Tipo."Sólo Conceptos Declarados" and (Concepto."Tipo Concepto" <> Concepto."Tipo Concepto"::Informativo) then
                exit(false);
            exit(true);
        end;
        exit(('|' + Lista + '|').Contains('|' + Tipo.Código + '|'));
    end;

    local procedure RevisarExpresion(Concepto: Record "Concepto Liquidación"; Expresion: Text; Grado: Integer; DesdeCobertura: Date; HastaCobertura: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Variables: List of [Text];
        Nombre: Text;
        Uso: Integer;
        Param: Record "Parámetro";
        TipoAtr: Record "Tipo Atributo Liq.";
        Fuente: Record "Fuente Datos Liquidación";
    begin
        if Expresion = '' then
            exit;
        if not FVariablesExpresion.Get(Expresion, Variables) then begin
            ExtraerVariables(Expresion, Variables);
            FVariablesExpresion.Add(Expresion, Variables);
        end;
        foreach Nombre in Variables do begin
            Uso := ClasificarSegmento(Expresion, Nombre, Grado, true, 0);
            if Uso <> 0 then
                if FParametrosPorNombre.ContainsKey(Nombre) then begin
                    if FParametros.Get(FParametrosPorNombre.Get(Nombre)) then begin
                        Param := FParametros;
                        if FRevisandoCondicion and SoloSelectoresConCero(Expresion, Nombre) then
                            Uso := 4;
                        if NombreParametroSinColision(Nombre) then
                            RevisarParametro(Param, Concepto, Uso, DesdeCobertura, HastaCobertura, Buffer)
                        else
                            Emitir(Buffer, "Severidad Registro Liq."::Advertencia, 'Contexto', Nombre, Param.Código, Concepto.Código,
                                'La variable tiene más de un origen; confirmar el valor que recibe esta lectura.',
                                'Un concepto, fuente, atributo o variable de sistema comparte el nombre del parámetro. No se poda la condición ni se presume que su valor sea el del parámetro.');
                    end;
                end else
                    if FAtributosPorNombre.ContainsKey(Nombre) then begin
                        if TipoAtr.Get(FAtributosPorNombre.Get(Nombre)) then
                            RevisarAtributo(TipoAtr, Concepto.Código, Uso, false, Buffer);
                    end else
                        if FFuentesPorNombre.ContainsKey(Nombre) then
                            if FFuentes.Get(CopyStr(Nombre, 1, 30)) then begin
                                Fuente := FFuentes;
                                if Fuente.Activo then
                                    RevisarFuente(Fuente, Concepto.Código, Buffer)
                                else begin
                                    // El cero admitido de un parámetro no convierte una fuente
                                    // inactiva en una entrada disponible para un selector.
                                    if Uso = 4 then
                                        Uso := 1;
                                    Emitir(Buffer, SeveridadDelUso(Uso), 'Fuentes', Nombre, '', Concepto.Código, 'La fórmula referencia una fuente de datos inactiva.', 'La fuente no se incorpora al contexto. Si la referencia está en una rama no demostrada, se informa como revisión.');
                                    Buffer."Nombre Fuente" := Fuente."Nombre Variable";
                                    Buffer.Modify();
                                end;
                            end;
        end;
        // Las referencias @ ejecutan otra fórmula con el contexto del llamador. No se las trata
        // como parámetros ni se certifica esa expansión dinámica mediante el escaneo de texto.
        if TieneReferenciaFormula(Expresion) then
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Contexto', '', '', Concepto.Código, 'Hay fórmulas referidas cuyo contexto debe revisarse al calcular.', 'El control inspecciona las entradas directas de los conceptos compatibles. No ejecuta referencias @, matrices ni asignación de días propios.');
    end;

    local procedure RevisarParametro(Param: Record "Parámetro"; Concepto: Record "Concepto Liquidación"; Uso: Integer; DesdeCobertura: Date; HastaCobertura: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Fila: Record "Parámetro Vigente";
        Par: Codeunit "Convenio Categoría Liq.";
        Convenio: Code[20];
        Categoria: Code[20];
        Motivo: Text;
        Grado: Integer;
    begin
        Convenio := FConvenio;
        Categoria := FCategoria;
        Grado := Uso;
        if Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Puesto then
            if not Par.ParDePuesto(FEmpleado, FFechaRef, FDesde, FHasta, Convenio, Categoria) then begin
                Convenio := FConvenio;
                Categoria := FCategoria;
                Grado := 2;
                Emitir(Buffer, "Severidad Registro Liq."::Advertencia, 'Encuadre', Param."Nombre Variable", Param.Código, Concepto.Código, 'No hay un puesto que permita resolver el par alternativo.', 'El motor vuelve al encuadre del empleado. Confirmá que ese fallback sea intencional.');
            end;
        if not ResolverParametro(Param.Código, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, Fila, Motivo) then begin
            if Format(Param."Antigüedad Máxima Vigencia") <> '' then
                if not BaseConVersionA(Param.Código, FFechaRef) then
                    exit; // La comprobación independiente de la regla ya conserva esta ausencia.
            if not FEncuadreConocido then
                Grado := 2;
            // Sólo un selector o alternativa acreditados por la expresión admiten la
            // ausencia sin tarea de carga. Ser Informativo no prueba inocuidad: puede
            // alimentar un haber, un acumulador o una retención por #/@/nombre.
            if Grado in [3, 4] then
                exit;
            // El catálogo no declara obligatoriedad. Una lectura directa no demuestra por sí
            // sola un precio impago: el contexto del motor publica cero cuando no hay fila.
            Emitir(Buffer, SeveridadParametro(Grado), 'Parámetros', Param."Nombre Variable", Param.Código, Concepto.Código, MensajeFaltante(Grado), Motivo);
            exit;
        end;
        // La regla explícita de fecha se comprueba para todo el catálogo cargado por el
        // motor, no sólo para lectores léxicos ni como una posible falta de precio.
        if (Fila.Moneda <> '') and not FAutoConversion then
            RevisarMoneda(Param, Fila, Concepto.Código, Grado, Convenio, Categoria, Buffer);
    end;

    local procedure RevisarReglasVigencia(var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Codigo: Code[20];
        Param: Record "Parámetro";
        Fila: Record "Parámetro Vigente";
        Limite: Date;
    begin
        // Una base sin ninguna fila es un incumplimiento acreditado de su política
        // explícita de actualización, aun sin candidatos o sin lectores textuales.
        foreach Codigo in FParametrosConRegla do begin
            FParametros.Get(Codigo);
            Param := FParametros;
            if ComprobarReglaVigencia(Param, FHasta, Limite, Buffer) then
                if not BaseConVersionA(Codigo, FHasta) then
                    EmitirVigencia(Buffer, Param, Fila, FHasta,
                        'El parámetro con regla de fecha no tiene ningún valor vigente.',
                        StrSubstNo('No existe ninguna fila de la base al %1. Regla configurada: %2. Una fila futura no cubre este período; un cero cargado sí es un valor.', FHasta, Format(Param."Antigüedad Máxima Vigencia")));
        end;
    end;

    local procedure RevisarVigenciasContexto(Convenio: Code[20]; Categoria: Code[20]; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Codigo: Code[20];
        Clave: Text;
        Motivo: Text;
        Limite: Date;
        Param: Record "Parámetro";
        Fila: Record "Parámetro Vigente";
    begin
        Clave := ClaveContexto(FEmpleado, FProyecto, Format(FFechaRef, 0, 9)) + ClaveContexto(Convenio, Categoria, Format(FFechaAtributos, 0, 9));
        if FVigenciasRevisadas.ContainsKey(Clave) then
            exit;
        FVigenciasRevisadas.Add(Clave, true);
        foreach Codigo in FParametrosConRegla do begin
            FParametros.Get(Codigo);
            Param := FParametros;
            if ComprobarReglaVigencia(Param, FFechaRef, Limite, Buffer) then
                if not BaseConVersionA(Codigo, FFechaRef) then begin
                    Clear(Fila);
                    // Un arribo puede tener una referencia anterior al fin del período.
                    EmitirVigencia(Buffer, Param, Fila, FFechaRef,
                        'El parámetro con regla de fecha no tiene ningún valor vigente.',
                        StrSubstNo('No existe ninguna fila de la base al %1. Regla configurada: %2. Una fila futura no cubre esta fecha; un cero cargado sí es un valor.', FFechaRef, Format(Param."Antigüedad Máxima Vigencia")));
                end else
                    if FEncuadreConocido then
                        if ResolverParametro(Codigo, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, Fila, Motivo) then
                            if Fila."Vigencia Desde" < Limite then
                                EmitirVigencia(Buffer, Param, Fila, FFechaRef,
                                    'La fila seleccionada incumple la antigüedad máxima configurada.',
                                    StrSubstNo('Referencia: %1. Regla: %2. Fecha mínima admitida: %3. La cascada selecciona esta fila en al menos un contexto elegible. Se acredita el incumplimiento de la fecha, sin evaluar el importe.', FFechaRef, Format(Param."Antigüedad Máxima Vigencia"), Limite));
            // Si la base tiene filas pero ninguna corresponde al contexto, no se exige una
            // nueva carga para alguien ajeno a su alcance. Es la distinción del motor.
        end;
    end;

    local procedure BaseConVersionA(Codigo: Code[20]; FechaRef: Date): Boolean
    var
        Versiones: Record "Parámetro Vigente" temporary;
        Clave: Text;
        Existe: Boolean;
    begin
        Clave := ClaveContexto(Codigo, Format(FechaRef, 0, 9), '');
        if FBasesEnFecha.Get(Clave, Existe) then
            exit(Existe);
        Versiones.Copy(FVersiones, true);
        Versiones.Reset();
        Versiones.SetRange("Cód. Parámetro Base", Codigo);
        Versiones.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        Existe := not Versiones.IsEmpty();
        if not Existe then begin
            // El resolvedor también admite claves antiguas sin base física declarada.
            // Su existencia impide acreditar una ausencia global de esta base.
            Versiones.SetRange("Cód. Parámetro Base", '');
            if Versiones.FindSet() then
                repeat
                    if (Versiones."Cód. Parámetro" = Codigo) or Format(Versiones."Cód. Parámetro").StartsWith(Codigo + '_') then
                        Existe := true;
                until (Versiones.Next() = 0) or Existe;
        end;
        FBasesEnFecha.Add(Clave, Existe);
        exit(Existe);
    end;

    local procedure ComprobarReglaVigencia(Param: Record "Parámetro"; FechaRef: Date; var Limite: Date; var Buffer: Record "Control Previo Liq. Buffer" temporary): Boolean
    var
        Fila: Record "Parámetro Vigente";
        Motivo: Text;
    begin
        if not FechaLimite(FechaRef, Param."Antigüedad Máxima Vigencia", Limite) then begin
            Motivo := GetLastErrorText();
            EmitirVigencia(Buffer, Param, Fila, FechaRef,
                'No se puede evaluar la regla de fecha del parámetro.', Motivo);
            exit(false);
        end;
        // Una regla anclada como <-CM> puede devolver la propia referencia el día 1;
        // admite una fila de ese día. Un límite futuro nunca puede satisfacerse.
        if Limite > FechaRef then begin
            EmitirVigencia(Buffer, Param, Fila, FechaRef,
                'La regla de fecha exige una vigencia posterior a la fecha de referencia.',
                StrSubstNo('Referencia: %1. Regla: %2. Límite: %3. Ninguna fila vigente a la referencia puede cumplir este límite.', FechaRef, Format(Param."Antigüedad Máxima Vigencia"), Limite));
            exit(false);
        end;
        exit(true);
    end;

    local procedure EmitirVigencia(var Buffer: Record "Control Previo Liq. Buffer" temporary; Param: Record "Parámetro"; Fila: Record "Parámetro Vigente"; FechaRef: Date; Mensaje: Text; Detalle: Text)
    var
        Clave: Text;
        Numero: Integer;
    begin
        // Consolidar por dato a corregir, no por cada persona/tipo que lo cargue. Nunca
        // atribuir al primer consumidor un alcance que corresponde a toda la fila.
        Clave := ClaveContexto(Param.Código, Fila."Cód. Parámetro", Format(Fila."Vigencia Desde", 0, 9)) + ClaveContexto(Format(FechaRef, 0, 9), Mensaje, '');
        if FAvisosVigencia.ContainsKey(Clave) then
            exit;
        FAvisosVigencia.Add(Clave, true);
        Buffer.Reset();
        if Buffer.FindLast() then
            Numero := Buffer."No. Línea";
        Buffer.Init();
        Buffer."No. Línea" := Numero + 1;
        Buffer.Severidad := Buffer.Severidad::Error;
        Buffer.Área := 'Vigencia de parámetros';
        Buffer."Nombre Variable" := Param."Nombre Variable";
        Buffer."Cód. Parámetro" := Param.Código;
        Buffer."No. Empleado" := Fila."No. Empleado";
        Buffer."Cód. Convenio" := Fila."Cód. Convenio";
        Buffer."Cód. Categoría" := Fila."Cód. Categoría";
        Buffer."Fecha Desde" := FDesde;
        Buffer."Fecha Hasta" := FHasta;
        Buffer."Vigencia Desde" := Fila."Vigencia Desde";
        Buffer."Clave Parámetro" := Fila."Cód. Parámetro";
        Buffer.Mensaje := CopyStr(Mensaje, 1, MaxStrLen(Buffer.Mensaje));
        Buffer.Detalle := CopyStr(Detalle, 1, MaxStrLen(Buffer.Detalle));
        Buffer.Repeticiones := 1;
        Buffer.Insert();
    end;

    local procedure RevisarConversionContexto(Convenio: Code[20]; Categoria: Code[20]; Uso: Integer; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Catalogo: Record "Parámetro" temporary;
        Fila: Record "Parámetro Vigente";
        Motivo: Text;
        Clave: Text;
    begin
        if not FAutoConversion then
            exit;
        Clave := ClaveContexto(FEmpleado, FProyecto, FTipo) + ClaveContexto(Convenio, Categoria, Format(FFechaRef, 0, 9));
        if FConversionRevisada.ContainsKey(Clave) then
            exit;
        FConversionRevisada.Add(Clave, true);
        if not FEncuadreConocido then
            Uso := 2;
        Catalogo.Copy(FParametros, true);
        Catalogo.Reset();
        // Primera pasada: el contexto toma la primera divisa resuelta de TODO el catálogo,
        // no solamente de las variables que aparece usando la fórmula del concepto.
        if Catalogo.FindSet() then
            repeat
                if ResolverParametro(Catalogo.Código, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, Fila, Motivo) then
                    if Fila.Moneda <> '' then
                        if FMonedaContexto = '' then
                            FMonedaContexto := Fila.Moneda
                        else
                            if FMonedaContexto <> Fila.Moneda then
                                FMonedasMixtas := true;
            until Catalogo.Next() = 0;
        if FMonedasMixtas then
            Emitir(Buffer, "Severidad Registro Liq."::Advertencia, 'Moneda', '', '', '', 'Hay parámetros resueltos en más de una divisa.', 'El contexto conserva una moneda para las fuentes de cotización. No se certifica cada precio suponiendo que sus filtros cambian de moneda de forma independiente.');
        // No se informan parámetros opcionales sin fila. Sí se inspeccionan TODAS las filas en
        // divisa presentes: la conversión automática las requiere aunque no haya un uso textual.
        if Catalogo.FindSet() then
            repeat
                if ResolverParametro(Catalogo.Código, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, Fila, Motivo) then
                    if Fila.Moneda <> '' then
                        RevisarMoneda(Catalogo, Fila, '', Uso, Convenio, Categoria, Buffer);
            until Catalogo.Next() = 0;
    end;

    local procedure RevisarMoneda(Param: Record "Parámetro"; Fila: Record "Parámetro Vigente"; Concepto: Code[20]; Uso: Integer; Convenio: Code[20]; Categoria: Code[20]; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Setup: Record "Human Resources Setup";
        TCParam: Record "Parámetro";
        TCFila: Record "Parámetro Vigente";
        Fuente: Record "Fuente Datos Liquidación";
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Valor: Decimal;
        Motivo: Text;
        ConversionAutomatica: Boolean;
        Encontrada: Boolean;
        ErrorConfirmado: Boolean;
    begin
        if Setup.Get() then
            ConversionAutomatica := Setup."Convertir Param. por TC";
        if Fila."Cód. Variable TC" = '' then begin
            if ConversionAutomatica then
                Emitir(Buffer, SeveridadDelUso(Uso), 'Moneda', Param."Nombre Variable", Param.Código, Concepto, 'La conversión automática requiere una variable de tipo de cambio.', 'El precio está en moneda extranjera y la conversión automática de parámetros está activada.')
            else
                Emitir(Buffer, "Severidad Registro Liq."::Información, 'Moneda', Param."Nombre Variable", Param.Código, Concepto, 'Precio en divisa con conversión a cargo de la fórmula.', 'Sin conversión automática, una variable TC vacía puede ser intencional. No se evalúa la fórmula ni se presume una cotización faltante.');
            CompletarVersion(Buffer, Fila);
            exit;
        end;
        if not ConversionAutomatica then begin
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Moneda', Param."Nombre Variable", Param.Código, Concepto, 'La fórmula determina si utiliza la cotización declarada.', 'La conversión automática está desactivada; se informa la metadata sin asegurar que la rama de conversión vaya a ejecutarse.');
            CompletarVersion(Buffer, Fila);
            exit;
        end;
        if FMonedasMixtas then begin
            // RevisarConversionContexto ya conserva una revisión por contexto. No
            // repetir el mismo límite como una falta de cotización de cada precio.
            exit;
        end;
        if FParametrosPorNombre.ContainsKey(Fila."Cód. Variable TC") then begin
            FParametros.Get(FParametrosPorNombre.Get(Fila."Cód. Variable TC"));
            TCParam := FParametros;
            Encontrada := ResolverParametro(TCParam.Código, FEmpleado, FProyecto, Convenio, Categoria, FFechaRef, TCFila, Motivo);
            ErrorConfirmado := not Encontrada;
            if Encontrada then begin
                Valor := TCFila.Valor;
                if TCFila.Moneda <> '' then begin
                    Encontrada := false;
                    Motivo := 'El parámetro de cotización también está expresado en divisa; su conversión no se puede certificar sin ejecutar el contexto.';
                end;
            end;
        end else
            if FFuentesPorNombre.ContainsKey(Fila."Cód. Variable TC") then begin
                FFuentes.Get(CopyStr(Fila."Cód. Variable TC", 1, 30));
                Fuente := FFuentes;
                Encontrada := Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", FMonedaContexto, FFechaRef, FFechaTC, Valor, Motivo, ErrorConfirmado);
            end else
                Motivo := 'La variable de tipo de cambio no es un parámetro ni una fuente simple verificable antes del cálculo.';
        if Encontrada and (Valor > 0) then
            exit;
        if Encontrada then begin
            Motivo := 'La fila existe, pero la cotización debe ser mayor que cero.';
            ErrorConfirmado := true;
        end;
        // Un token/camino no inspeccionable no acredita una ausencia. Se mantiene como revisión.
        if ErrorConfirmado then
            Emitir(Buffer, SeveridadDelUso(Uso), 'Moneda', Param."Nombre Variable", Param.Código, Concepto, 'La conversión automática no tiene una cotización positiva aplicable.', Motivo)
        else
            Emitir(Buffer, "Severidad Registro Liq."::Advertencia, 'Moneda', Param."Nombre Variable", Param.Código, Concepto, 'Revisar la cotización para la conversión automática.', Motivo);
        CompletarVersion(Buffer, Fila);
    end;

    local procedure RevisarAtributosObligatorios(var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Tipo: Record "Tipo Atributo Liq.";
    begin
        Tipo.SetRange(Obligatorio, true);
        if Tipo.FindSet() then
            repeat
                RevisarAtributo(Tipo, '', 1, true, Buffer);
            until Tipo.Next() = 0;
    end;

    local procedure RevisarAtributo(Tipo: Record "Tipo Atributo Liq."; Concepto: Code[20]; Uso: Integer; Obligatorio: Boolean; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Atributo: Record "Atributo Entidad Liq.";
        Entidad: Record "Entidad Liq.";
        CodigoEntidad: Code[20];
        Fecha: Date;
        Severidad: Enum "Severidad Registro Liq.";
        Mensaje: Text;
    begin
        CodigoEntidad := EntidadDelContexto(Tipo."Tipo Entidad", FEmpleado, FProyecto);
        Obligatorio := Obligatorio or Tipo.Obligatorio;
        // La clase restringe entidades genéricas como buques. Empleado y proyecto se
        // identifican por su tipo; una clase administrativa cargada no los excluye.
        if (Tipo."Cód. Clase" <> '') and (Tipo."Tipo Entidad" = Tipo."Tipo Entidad"::Buque) then begin
            if Entidad.Get(CodigoEntidad) then begin
                if Tipo."Cód. Clase" <> Entidad."Cód. Clase" then
                    exit;
            end else begin
                Emitir(Buffer, "Severidad Registro Liq."::Información, 'Atributos', Tipo."Nombre Variable", '', Concepto, MensajeDeAtributo(Tipo, 'No se conoce la clase de la entidad para este atributo.'), 'No se afirma que un atributo de una clase específica sea obligatorio para una entidad sin clase resuelta.');
                CompletarAtributo(Buffer, Tipo, CodigoEntidad);
                exit;
            end;
        end;
        if CodigoEntidad = '' then begin
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Atributos', Tipo."Nombre Variable", '', Concepto, MensajeDeAtributo(Tipo, 'No hay entidad disponible para inspeccionar este atributo.'), 'Se requiere el proyecto o buque del contexto. No se interpreta la falta de contexto como un valor numérico cero ni como un dato impago.');
            CompletarAtributo(Buffer, Tipo, CodigoEntidad);
            exit;
        end;
        Fecha := FFechaRef;
        if Tipo."Tipo Entidad" = Tipo."Tipo Entidad"::Empleado then
            Fecha := FFechaAtributos;
        if Atributo.Vigente(Tipo.Código, Tipo."Tipo Entidad", CodigoEntidad, Fecha) then begin
            // La existencia de una fila numérica acredita incluso 0. Para listas/textos/fechas,
            // una fila obligatoria vacía sigue siendo una carga incompleta.
            if not Obligatorio then
                exit;
            case Tipo."Tipo Dato" of
                Tipo."Tipo Dato"::Decimal, Tipo."Tipo Dato"::Entero:
                    exit;
                Tipo."Tipo Dato"::Lista:
                    if Atributo."Cód. Valor" <> '' then
                        exit;
                Tipo."Tipo Dato"::Texto:
                    if Atributo."Valor Texto" <> '' then
                        exit;
                Tipo."Tipo Dato"::Fecha:
                    if Atributo."Valor Fecha" <> 0D then
                        exit;
            end;
            Mensaje := 'El atributo obligatorio tiene una fila vigente sin valor.';
        end else
            Mensaje := 'No hay una asignación vigente del atributo en este contexto.';
        Severidad := "Severidad Registro Liq."::Información;
        // Obligatorio es una exigencia del catálogo; no demuestra necesidad de
        // pago en cada candidato ni un fallo del motor. Se conserva como revisión
        // opcional sin alterar el dato, las plantillas ni su obligatoriedad.
        if Obligatorio then
            Severidad := "Severidad Registro Liq."::Advertencia;
        if not Obligatorio then
            Mensaje := 'El atributo opcional no tiene asignación vigente; confirmar si corresponde informarlo.';
        Emitir(Buffer, Severidad, 'Atributos', Tipo."Nombre Variable", '', Concepto, MensajeDeAtributo(Tipo, Mensaje), 'Una asignación numérica en cero es válida. Una referencia condicional u opcional necesita revisión, no prueba por sí sola que falte un pago.');
        CompletarAtributo(Buffer, Tipo, CodigoEntidad);
    end;

    local procedure MensajeDeAtributo(Tipo: Record "Tipo Atributo Liq."; Mensaje: Text): Text
    begin
        // El nombre de variable es opcional para atributos administrativos. Su identidad no
        // puede perderse al deduplicar varias faltas del mismo contexto y con el mismo mensaje.
        if Tipo."Nombre Variable" = '' then
            exit(StrSubstNo('%1 [Atributo %2]', Mensaje, Tipo.Código));
        exit(Mensaje);
    end;

    local procedure RevisarFuente(Fuente: Record "Fuente Datos Liquidación"; Concepto: Code[20]; var Buffer: Record "Control Previo Liq. Buffer" temporary)
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
        FaltaRecibo: Boolean;
    begin
        // Contexto aplica los filtros de la subtabla; los campos legacy no se ejecutan.
        FaltaRecibo := false;
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if Filtro.FindSet() then
            repeat
                if Filtro."Filtro Valor".Contains('{LIQ_NO}') then
                    FaltaRecibo := true;
            until Filtro.Next() = 0;
        if FaltaRecibo then begin
            Emitir(Buffer, "Severidad Registro Liq."::Información, 'Fuentes', Fuente."Nombre Variable", '', Concepto, 'La fuente requiere contexto de liquidación; su resultado no fue comprobado.', 'Se revisó su configuración por separado. Esta revisión no construye el contexto de un recibo, exista o no, y no consulta la fuente sin el filtro de liquidación.');
            Buffer."Nombre Fuente" := Fuente."Nombre Variable";
            Buffer.Modify();
        end;
    end;

    local procedure EntidadDelContexto(TipoEntidad: Enum "Tipo Entidad Estado"; Empleado: Code[20]; Proyecto: Code[20]): Code[20]
    var
        Job: Record Job;
    begin
        case TipoEntidad of
            TipoEntidad::Empleado:
                exit(Empleado);
            TipoEntidad::Proyecto:
                exit(Proyecto);
            TipoEntidad::Buque:
                if Job.Get(Proyecto) then
                    exit(Job."Global Dimension 1 Code");
        end;
        exit('');
    end;

    local procedure ProyectoNominaDe(Empleado: Code[20]; Desde: Date; FechaRef: Date): Code[20]
    var
        Estado: Record "Estado Empleado";
        CodigoEstado: Record "Cód. Estado Empleado";
        Proyecto: Record Job;
        Atributo: Record "Atributo Entidad Liq.";
    begin
        // Misma ruta de lectura que la creación agrupada: estado no-marea, último buque y
        // finalmente el atributo de proyecto de nómina del empleado que nunca embarcó.
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', FechaRef);
        if not Estado.FindLast() then
            exit('');
        repeat
            if Estado.FechaFinEfectiva() >= Desde then
                if Estado."No. Proyecto" <> '' then
                    if CodigoEstado.Get(Estado."Cód. Estado") then
                        if not CodigoEstado."Transcurre en Marea" then
                            exit(Estado."No. Proyecto");
        until Estado.Next(-1) = 0;
        Estado.FindLast();
        repeat
            if Estado."No. Proyecto" <> '' then
                if CodigoEstado.Get(Estado."Cód. Estado") then
                    if CodigoEstado."Transcurre en Marea" then begin
                        if Proyecto.Get(Estado."No. Proyecto") then
                            exit(Atributo.ValorVigente('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", FechaRef));
                        exit('');
                    end;
        until Estado.Next(-1) = 0;
        exit(Atributo.ValorVigente('PROY_NOMINA', "Tipo Entidad Estado"::Empleado, Empleado, FechaRef));
    end;

    local procedure TieneRutaEnPeriodo(Empleado: Code[20]): Boolean
    var
        Estado: Record "Estado Empleado";
        Personal: Record "Personal Proyecto";
    begin
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', FHasta);
        Estado.SetFilter("Fecha Fin", '%1|>=%2', 0D, FDesde);
        if not Estado.IsEmpty() then
            exit(true);
        Personal.SetRange("No. Empleado", Empleado);
        Personal.SetFilter("Fecha Alta Asignación", '<=%1', FHasta);
        Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, FDesde);
        exit(not Personal.IsEmpty());
    end;

    local procedure FechaDeCotizacion(Empleado: Code[20]; Proyecto: Code[20]; Tipo: Code[20]; FechaRef: Date; HastaCobertura: Date) Fecha: Date
    var
        Novedad: Record "Novedad Liquidación";
    begin
        // FECHA_TC es el mecanismo existente del contexto, no un ajuste particular de este control.
        Fecha := FechaRef;
        if (Tipo = 'LIQ_FINAL') and (HastaCobertura <> 0D) and (HastaCobertura < Fecha) then
            Fecha := HastaCobertura;
        Novedad.SetCurrentKey("Cód. Período", "No. Empleado", "Cód. Concepto");
        Novedad.SetRange("Cód. Período", FCodPeriodo);
        Novedad.SetRange("No. Empleado", Empleado);
        Novedad.SetRange("Cód. Concepto", 'FECHA_TC');
        Novedad.SetFilter(Estado, '<>%1', Novedad.Estado::Anulada);
        if Novedad.FindSet() then
            repeat
                if (Novedad.Fecha <> 0D) and ((Novedad."Cód. Tipo Liq." = '') or (Novedad."Cód. Tipo Liq." = Tipo)) and ((Novedad."No. Proyecto" = '') or (Novedad."No. Proyecto" = Proyecto)) then
                    Fecha := Novedad.Fecha;
            until Novedad.Next() = 0;
    end;

    local procedure SeveridadDelUso(Uso: Integer): Enum "Severidad Registro Liq."
    begin
        case Uso of
            1:
                exit("Severidad Registro Liq."::Error);
            3, 4:
                exit("Severidad Registro Liq."::Información);
        end;
        exit("Severidad Registro Liq."::Advertencia);
    end;

    local procedure SeveridadParametro(Uso: Integer): Enum "Severidad Registro Liq."
    begin
        if Uso in [3, 4] then
            exit("Severidad Registro Liq."::Información);
        exit("Severidad Registro Liq."::Advertencia);
    end;

    local procedure MensajeFaltante(Uso: Integer): Text
    begin
        case Uso of
            1:
                exit('Parámetro sin fila vigente en una lectura directa; confirmar si corresponde cargarlo.');
            3:
                exit('El parámetro no tiene fila; la fórmula declara un fallback IFZERO.');
            4:
                exit('Parámetro sin fila en un selector, alternativa explícita o auxiliar informativo.');
        end;
        exit('Revisar parámetro sin fila vigente en una referencia condicional.');
    end;

    local procedure Emitir(var Buffer: Record "Control Previo Liq. Buffer" temporary; Severidad: Enum "Severidad Registro Liq."; NombreArea: Text; Variable: Text; Parametro: Code[20]; Concepto: Code[20]; Mensaje: Text; Detalle: Text)
    var
        Clave: Text;
        Numero: Integer;
        Ultimo: Record "Control Previo Liq. Buffer" temporary;
    begin
        Clave := ClaveContexto(FEmpleado, FProyecto, FTipo) + '|' + NombreArea + '|' + Variable + '|' + Parametro + '|' + Concepto + '|' + Mensaje;
        Buffer.Reset();
        if FEmitidos.Get(Clave, Numero) then begin
            if Buffer.Get(Numero) then
                if Severidad.AsInteger() > Buffer.Severidad.AsInteger() then begin
                    Buffer.Severidad := Severidad;
                    Buffer.Modify();
                end;
            exit;
        end;
        if Buffer.FindLast() then
            Numero := Buffer."No. Línea";
        Numero += 1;
        Buffer.Init();
        Buffer."No. Línea" := Numero;
        Buffer.Severidad := Severidad;
        Buffer."Área" := CopyStr(NombreArea, 1, MaxStrLen(Buffer."Área"));
        Buffer."Nombre Variable" := CopyStr(Variable, 1, MaxStrLen(Buffer."Nombre Variable"));
        Buffer."Cód. Parámetro" := Parametro;
        Buffer."Cód. Concepto" := Concepto;
        Buffer."No. Empleado" := FEmpleado;
        Buffer."No. Proyecto" := FProyecto;
        Buffer."Cód. Convenio" := FConvenio;
        Buffer."Cód. Categoría" := FCategoria;
        Buffer."Cód. Tipo Liq." := FTipo;
        Buffer."Fecha Desde" := FDesde;
        Buffer."Fecha Hasta" := FHasta;
        Buffer.Mensaje := CopyStr(Mensaje, 1, MaxStrLen(Buffer.Mensaje));
        Buffer.Detalle := CopyStr(Detalle, 1, MaxStrLen(Buffer.Detalle));
        Buffer.Repeticiones := 1;
        Buffer."Conceptos relacionados" := Concepto;
        Buffer.Insert();
        FEmitidos.Add(Clave, Numero);
    end;

    local procedure CompletarVersion(var Buffer: Record "Control Previo Liq. Buffer" temporary; Fila: Record "Parámetro Vigente")
    begin
        Buffer."Vigencia Desde" := Fila."Vigencia Desde";
        Buffer."Clave Parámetro" := Fila."Cód. Parámetro";
        Buffer.Modify();
    end;

    local procedure CompletarAtributo(var Buffer: Record "Control Previo Liq. Buffer" temporary; Tipo: Record "Tipo Atributo Liq."; Entidad: Code[20])
    begin
        Buffer."Tipo Entidad" := Tipo."Tipo Entidad";
        Buffer."Cód. Entidad" := Entidad;
        Buffer."Cód. Tipo Atributo" := Tipo.Código;
        Buffer.Modify();
    end;

    local procedure ClaveContexto(Empleado: Text; Proyecto: Text; Tipo: Text): Text
    begin
        exit(StrSubstNo('%1:%2%3:%4%5:%6', StrLen(Empleado), Empleado, StrLen(Proyecto), Proyecto, StrLen(Tipo), Tipo));
    end;

    [TryFunction]
    local procedure AplicarFiltroEmpleado(var Empleado: Record Employee; Filtro: Text)
    var
        SinFilas: Boolean;
    begin
        Empleado.Reset();
        Empleado.FilterGroup(10);
        if Filtro <> '' then
            Empleado.SetFilter("No.", Filtro);
        Empleado.FilterGroup(0);
        SinFilas := Empleado.IsEmpty();
    end;

    [TryFunction]
    local procedure AplicarFiltroProyecto(var Proyecto: Record Job; Filtro: Text)
    var
        SinFilas: Boolean;
    begin
        Proyecto.Reset();
        Proyecto.FilterGroup(10);
        if Filtro <> '' then
            Proyecto.SetFilter("No.", Filtro);
        Proyecto.FilterGroup(0);
        SinFilas := Proyecto.IsEmpty();
    end;

    [TryFunction]
    local procedure FechaLimite(Desde: Date; Formula: DateFormula; var Hasta: Date)
    begin
        Hasta := CalcDate(Formula, Desde);
    end;

    local procedure TieneReferenciaFormula(Texto: Text): Boolean
    var
        Tokens: List of [Text];
        Token: Text;
        Control: Codeunit "Control Orden Acumuladores";
    begin
        Control.ExtraerIdentificadores(Texto, Tokens);
        foreach Token in Tokens do
            if Token.StartsWith('@') then
                exit(true);
        exit(false);
    end;

    // Parser de dependencias: sólo recorre texto. No calcula importes, días, fuentes ni @fórmulas.
    local procedure ClasificarSegmento(Texto: Text; Nombre: Text; Heredado: Integer; Contextual: Boolean; Profundidad: Integer) Resultado: Integer
    var
        Posicion: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        Fin: Integer;
        I: Integer;
        Estado: Integer;
        Token: Text;
        Argumentos: List of [Text];
        Parte: Text;
        Uso: Integer;
        ResultadoIf: Integer;
    begin
        if (Profundidad > 40) or (Texto = '') or (Heredado = 0) then
            exit(0);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else
                if (Texto[Posicion] = '#') or (Texto[Posicion] = '@') then begin
                    Posicion += 1;
                    while Posicion <= StrLen(Texto) do begin
                        if not EsIdentificador(Texto[Posicion]) then
                            break;
                        Posicion += 1;
                    end;
                end else
                    if EsInicioIdentificador(Texto[Posicion]) then begin
                        Inicio := Posicion;
                        Posicion += 1;
                        while Posicion <= StrLen(Texto) do begin
                            if not EsIdentificador(Texto[Posicion]) then
                                break;
                            Posicion += 1;
                        end;
                        Token := CopyStr(Texto, Inicio, Posicion - Inicio).ToUpper();
                        Siguiente := Posicion;
                        while Siguiente <= StrLen(Texto) do begin
                            if not EsEspacio(Texto[Siguiente]) then
                                break;
                            Siguiente += 1;
                        end;
                        Fin := 0;
                        if Siguiente <= StrLen(Texto) then
                            if Texto[Siguiente] = '(' then
                                Fin := FinParentesis(Texto, Siguiente);
                        if Fin > 0 then begin
                            SepararArgumentos(CopyStr(Texto, Siguiente + 1, Fin - Siguiente - 1), Argumentos);
                            if (Token = 'IF') and (Argumentos.Count() = 3) then begin
                                Parte := Argumentos.Get(1);
                                if SoloSelectoresConCero(Parte, Nombre) then
                                    Uso := 4
                                else
                                    Uso := ClasificarSegmento(Parte, Nombre, Heredado, Contextual, Profundidad + 1);
                                ResultadoIf := Uso;
                                Estado := -1;
                                if Contextual then
                                    Estado := CondicionEstatica(Parte, Profundidad + 1);
                                if Estado = -1 then begin
                                    Uso := ClasificarSegmento(Argumentos.Get(2), Nombre, 2, Contextual, Profundidad + 1);
                                    ResultadoIf := MejorUso(ResultadoIf, Uso);
                                    Uso := ClasificarSegmento(Argumentos.Get(3), Nombre, 2, Contextual, Profundidad + 1);
                                end else
                                    if Estado = 1 then
                                        Uso := ClasificarSegmento(Argumentos.Get(2), Nombre, Heredado, Contextual, Profundidad + 1)
                                    else
                                        Uso := ClasificarSegmento(Argumentos.Get(3), Nombre, Heredado, Contextual, Profundidad + 1);
                                ResultadoIf := MejorUso(ResultadoIf, Uso);
                                // Sin contexto sólo se acepta el fallback que se demuestra por
                                // el propio IF: al faltar esta variable vale cero, y la rama
                                // elegida entonces no vuelve a necesitarla. Un uso exterior gana.
                                if not Contextual and EsAlternativaConCero(Argumentos, Nombre) then
                                    ResultadoIf := 4;
                                Resultado := MejorUso(Resultado, ResultadoIf);
                            end else
                                if (Token = 'IFZERO') and (Argumentos.Count() = 2) then begin
                                    Uso := ClasificarSegmento(Argumentos.Get(1), Nombre, 3, Contextual, Profundidad + 1);
                                    Resultado := MejorUso(Resultado, Uso);
                                    Uso := ClasificarSegmento(Argumentos.Get(2), Nombre, 2, Contextual, Profundidad + 1);
                                    Resultado := MejorUso(Resultado, Uso);
                                end else
                                    for I := 1 to Argumentos.Count() do begin
                                        Estado := Heredado;
                                        if Token = 'CASE' then
                                            Estado := 2;
                                        Uso := ClasificarSegmento(Argumentos.Get(I), Nombre, Estado, Contextual, Profundidad + 1);
                                        Resultado := MejorUso(Resultado, Uso);
                                    end;
                            Posicion := Fin + 1;
                        end else
                            if Token = Nombre then
                                Resultado := MejorUso(Resultado, Heredado);
                    end else
                        Posicion += 1;
    end;

    local procedure MejorUso(Anterior: Integer; Nuevo: Integer): Integer
    begin
        if Anterior = 0 then
            exit(Nuevo);
        if Nuevo = 0 then
            exit(Anterior);
        if Nuevo < Anterior then
            exit(Nuevo);
        exit(Anterior);
    end;

    local procedure EsSelectorConCero(Texto: Text; Nombre: Text): Boolean
    var
        Operador: Text;
        Izquierda: Text;
        Derecha: Text;
        Numero: Decimal;
    begin
        if not SepararComparacionSimple(Texto, Izquierda, Derecha, Operador) then
            exit(false);
        if Izquierda.ToUpper() = Nombre then
            exit(Evaluate(Numero, Derecha, 9) and (Numero = 0));
        if Derecha.ToUpper() = Nombre then
            exit(Evaluate(Numero, Izquierda, 9) and (Numero = 0));
        exit(false);
    end;

    local procedure SoloSelectoresConCero(Texto: Text; Nombre: Text): Boolean
    begin
        exit(SoloSelectoresConCero(Texto, Nombre, 0));
    end;

    local procedure SoloSelectoresConCero(Texto: Text; Nombre: Text; Profundidad: Integer): Boolean
    var
        Posicion: Integer;
        Longitud: Integer;
        Izquierda: Text;
        Derecha: Text;
        Correcto: Boolean;
        Nombres: List of [Text];
        UsaIzquierda: Boolean;
        UsaDerecha: Boolean;
    begin
        if Profundidad > 30 then
            exit(false);
        Texto := SinParentesisExternos(Texto);
        if (Texto.ToUpper() = Nombre) or EsSelectorConCero(Texto, Nombre) then
            exit(true);
        Posicion := BuscarOperadorLogico(Texto, 'OR');
        Longitud := 2;
        if Posicion = 0 then begin
            Posicion := BuscarOperadorLogico(Texto, 'AND');
            Longitud := 3;
        end;
        if Posicion > 0 then begin
            Izquierda := CopyStr(Texto, 1, Posicion - 1);
            Derecha := CopyStr(Texto, Posicion + Longitud);
            ExtraerVariables(Izquierda, Nombres);
            UsaIzquierda := Nombres.Contains(Nombre);
            ExtraerVariables(Derecha, Nombres);
            UsaDerecha := Nombres.Contains(Nombre);
            if not (UsaIzquierda or UsaDerecha) then
                exit(false);
            Correcto := true;
            if UsaIzquierda then
                Correcto := SoloSelectoresConCero(Izquierda, Nombre, Profundidad + 1);
            if UsaDerecha then
                Correcto := Correcto and SoloSelectoresConCero(Derecha, Nombre, Profundidad + 1);
            exit(Correcto);
        end;
        if Texto.ToUpper().StartsWith('NOT ') then
            exit(SoloSelectoresConCero(CopyStr(Texto, 5), Nombre, Profundidad + 1));
        exit(false);
    end;

    local procedure EsAlternativaConCero(Argumentos: List of [Text]; Nombre: Text): Boolean
    var
        Izquierda: Text;
        Derecha: Text;
        Operador: Text;
        Elegida: Integer;
        Nombres: List of [Text];
    begin
        if not EsSelectorConCero(Argumentos.Get(1), Nombre) then
            exit(false);
        SepararComparacionSimple(Argumentos.Get(1), Izquierda, Derecha, Operador);
        Elegida := 3;
        if CompararNumeros(0, 0, Operador) = 1 then
            Elegida := 2;
        ExtraerVariables(Argumentos.Get(Elegida), Nombres);
        exit(not Nombres.Contains(Nombre));
    end;

    local procedure SepararComparacionSimple(Texto: Text; var Izquierda: Text; var Derecha: Text; var Operador: Text): Boolean
    var
        Posicion: Integer;
        Nivel: Integer;
    begin
        Texto := SinParentesisExternos(Texto);
        Clear(Izquierda);
        Clear(Derecha);
        Clear(Operador);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else begin
                if Texto[Posicion] = '(' then Nivel += 1;
                if Texto[Posicion] = ')' then Nivel -= 1;
                if (Nivel = 0) and (CopyStr(Texto, Posicion, 1) in ['=', '<', '>']) then begin
                    Operador := CopyStr(Texto, Posicion, 1);
                    if Posicion < StrLen(Texto) then
                        if (Texto[Posicion + 1] = '=') or ((Texto[Posicion] = '<') and (Texto[Posicion + 1] = '>')) then
                            Operador := CopyStr(Texto, Posicion, 2);
                    Izquierda := SinParentesisExternos(CopyStr(Texto, 1, Posicion - 1));
                    Derecha := SinParentesisExternos(CopyStr(Texto, Posicion + StrLen(Operador)));
                    exit((Izquierda <> '') and (Derecha <> ''));
                end;
                Posicion += 1;
            end;
        exit(false);
    end;

    local procedure SinParentesisExternos(Texto: Text): Text
    begin
        Texto := Texto.Trim();
        while Texto <> '' do begin
            if Texto[1] <> '(' then
                exit(Texto);
            if FinParentesis(Texto, 1) <> StrLen(Texto) then
                exit(Texto);
            Texto := CopyStr(Texto, 2, StrLen(Texto) - 2).Trim();
        end;
        exit(Texto);
    end;

    local procedure EsInicioIdentificador(Caracter: Char): Boolean
    begin
        exit(((Caracter >= 'A') and (Caracter <= 'Z')) or ((Caracter >= 'a') and (Caracter <= 'z')) or (Caracter = '_') or (Caracter > 127));
    end;

    local procedure EsIdentificador(Caracter: Char): Boolean
    begin
        exit(EsInicioIdentificador(Caracter) or ((Caracter >= '0') and (Caracter <= '9')));
    end;

    local procedure EsEspacio(Caracter: Char): Boolean
    begin
        exit((Caracter = ' ') or (Caracter = 9) or (Caracter = 10) or (Caracter = 13));
    end;

    local procedure SaltarTexto(Texto: Text; var Posicion: Integer)
    begin
        Posicion += 1;
        while Posicion <= StrLen(Texto) do begin
            if Texto[Posicion] = '''' then begin
                Posicion += 1;
                if Posicion > StrLen(Texto) then
                    exit;
                if Texto[Posicion] <> '''' then
                    exit;
            end;
            Posicion += 1;
        end;
    end;

    local procedure FinParentesis(Texto: Text; Inicio: Integer): Integer
    var
        Posicion: Integer;
        Nivel: Integer;
    begin
        Posicion := Inicio;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else begin
                if Texto[Posicion] = '(' then
                    Nivel += 1;
                if Texto[Posicion] = ')' then begin
                    Nivel -= 1;
                    if Nivel = 0 then
                        exit(Posicion);
                end;
                Posicion += 1;
            end;
        exit(0);
    end;

    local procedure SepararArgumentos(Texto: Text; var Argumentos: List of [Text])
    var
        Posicion: Integer;
        Inicio: Integer;
        Nivel: Integer;
    begin
        Clear(Argumentos);
        Inicio := 1;
        Posicion := 1;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else begin
                case Texto[Posicion] of
                    '(':
                        Nivel += 1;
                    ')':
                        Nivel -= 1;
                    ',':
                        if Nivel = 0 then begin
                            Argumentos.Add(CopyStr(Texto, Inicio, Posicion - Inicio).Trim());
                            Inicio := Posicion + 1;
                        end;
                end;
                Posicion += 1;
            end;
        Argumentos.Add(CopyStr(Texto, Inicio).Trim());
    end;

    /// <summary>Triestado: sólo constantes y comparaciones de códigos conocidos. -1 = revisar.</summary>
    local procedure CondicionEstatica(Texto: Text; Profundidad: Integer): Integer
    var
        Posicion: Integer;
        Nivel: Integer;
        ParteIzquierda: Text;
        ParteDerecha: Text;
        Operador: Text;
        Izquierda: Text;
        Derecha: Text;
        Numero: Decimal;
        ResultadoIzquierda: Integer;
        ResultadoDerecha: Integer;
        EsNumeroIzquierda: Boolean;
        EsNumeroDerecha: Boolean;
        NumeroIzquierda: Decimal;
        NumeroDerecha: Decimal;
    begin
        Texto := Texto.Trim();
        if Texto = '' then
            exit(1);
        if Profundidad > 30 then
            exit(-1);
        if Texto[1] = '(' then
            if FinParentesis(Texto, 1) = StrLen(Texto) then
                exit(CondicionEstatica(CopyStr(Texto, 2, StrLen(Texto) - 2), Profundidad + 1));
        // Separación conservadora de AND/OR sólo a nivel superior, sin ejecutar operandos.
        Posicion := BuscarOperadorLogico(Texto, 'OR');
        if Posicion = 0 then
            Posicion := BuscarOperadorLogico(Texto, 'AND');
        if Posicion > 0 then begin
            Operador := 'OR';
            if CopyStr(Texto, Posicion, 3).ToUpper() = 'AND' then
                Operador := 'AND';
            ResultadoIzquierda := CondicionEstatica(CopyStr(Texto, 1, Posicion - 1), Profundidad + 1);
            ResultadoDerecha := CondicionEstatica(CopyStr(Texto, Posicion + StrLen(Operador)), Profundidad + 1);
            // No se poda con un único operando conocido: el evaluador lee ambos operandos.
            if (ResultadoIzquierda = -1) or (ResultadoDerecha = -1) then
                exit(-1);
            if Operador = 'AND' then begin
                if (ResultadoIzquierda = 1) and (ResultadoDerecha = 1) then
                    exit(1);
                exit(0);
            end;
            if (ResultadoIzquierda = 1) or (ResultadoDerecha = 1) then
                exit(1);
            exit(0);
        end;
        if Texto.ToUpper().StartsWith('NOT ') then begin
            ResultadoIzquierda := CondicionEstatica(CopyStr(Texto, 5), Profundidad + 1);
            if ResultadoIzquierda = -1 then
                exit(-1);
            exit(1 - ResultadoIzquierda);
        end;
        if Evaluate(Numero, Texto, 9) then begin
            if Numero = 0 then
                exit(0);
            exit(1);
        end;
        Posicion := 1;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else begin
                if Texto[Posicion] = '(' then
                    Nivel += 1;
                if Texto[Posicion] = ')' then
                    Nivel -= 1;
                if (Nivel = 0) and ((Texto[Posicion] = '=') or (Texto[Posicion] = '<') or (Texto[Posicion] = '>')) then begin
                    Operador := CopyStr(Texto, Posicion, 1);
                    if Posicion < StrLen(Texto) then
                        if (Texto[Posicion + 1] = '=') or ((Texto[Posicion] = '<') and (Texto[Posicion + 1] = '>')) then
                            Operador := CopyStr(Texto, Posicion, 2);
                    ParteIzquierda := CopyStr(Texto, 1, Posicion - 1).Trim();
                    ParteDerecha := CopyStr(Texto, Posicion + StrLen(Operador)).Trim();
                    if not OperandoEstatico(ParteIzquierda, Izquierda, EsNumeroIzquierda, NumeroIzquierda) then
                        exit(-1);
                    if not OperandoEstatico(ParteDerecha, Derecha, EsNumeroDerecha, NumeroDerecha) then
                        exit(-1);
                    // ParseCompare del motor elige código sólo ante un literal a la derecha.
                    // Lista contra lista sin comillas usa las proyecciones numéricas selladas.
                    if EsLiteralTexto(ParteDerecha) then begin
                        if not CodigoComparacionValido(ParteIzquierda, Derecha) then
                            exit(-1);
                        case Operador of
                            '=':
                                if Izquierda = Derecha then exit(1) else exit(0);
                            '<>':
                                if Izquierda <> Derecha then exit(1) else exit(0);
                        end;
                        exit(-1);
                    end;
                    if EsNumeroIzquierda and EsNumeroDerecha then
                        exit(CompararNumeros(NumeroIzquierda, NumeroDerecha, Operador));
                    exit(-1);
                end;
                Posicion += 1;
            end;
        exit(-1);
    end;

    local procedure OperandoEstatico(Texto: Text; var Codigo: Text; var EsNumero: Boolean; var Numero: Decimal): Boolean
    var
        Tipo: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
        VariableSistema: Record "Variable Sistema Liq.";
        TipoLiq: Record "Tipo Liquidación";
        FilaParametro: Record "Parámetro Vigente";
        Motivo: Text;
        Fuente: Record "Fuente Datos Liquidación" temporary;
    begin
        Texto := SinParentesisExternos(Texto);
        Clear(Codigo);
        EsNumero := Evaluate(Numero, Texto, 9);
        if EsNumero then
            exit(true);
        if StrLen(Texto) >= 2 then
            if (Texto[1] = '''') and (Texto[StrLen(Texto)] = '''') then begin
                Codigo := CopyStr(Texto, 2, StrLen(Texto) - 2).Replace('''''', '''').ToUpper();
                exit(true);
            end;
        if FCodigosSistema.ContainsKey(Texto.ToUpper()) then begin
            Codigo := FTipo;
            if not TipoLiq.Get(FTipo) then
                exit(false);
            EsNumero := true;
            Numero := TipoLiq.Orden;
            exit(true);
        end;
        if FAnalizando and FEncuadreConocido and FParametrosPorNombre.ContainsKey(Texto.ToUpper()) then begin
            // Nunca reutilizar el valor de un parámetro si el motor puede sobrescribir ese
            // nombre, ni comparar el precio en divisa antes de su conversión automática.
            if not NombreParametroSinColision(Texto.ToUpper()) then
                exit(false);
            EsNumero := true;
            Numero := 0;
            if ResolverParametro(FParametrosPorNombre.Get(Texto.ToUpper()), FEmpleado, FProyecto, FConvenioEvaluacion, FCategoriaEvaluacion, FFechaRef, FilaParametro, Motivo) then begin
                if FAutoConversion and (FilaParametro.Moneda <> '') then
                    exit(false);
                Numero := FilaParametro.Valor;
            end;
            exit(true);
        end;
        if not FAtributosPorNombre.ContainsKey(Texto.ToUpper()) then
            exit(false);
        if FNombresConcepto.ContainsKey(Texto.ToUpper()) or FNombresSistema.ContainsKey(Texto.ToUpper()) or FParametrosPorNombre.ContainsKey(Texto.ToUpper()) then
            exit(false);
        if FFuentesPorNombre.ContainsKey(Texto.ToUpper()) then begin
            Fuente.Copy(FFuentes, true);
            if Fuente.Get(CopyStr(Texto.ToUpper(), 1, 30)) then
                if Fuente.Activo then
                    exit(false);
        end;
        if not Tipo.Get(FAtributosPorNombre.Get(Texto.ToUpper())) then
            exit(false);
        if Tipo."Tipo Dato" <> Tipo."Tipo Dato"::Lista then
            exit(false);
        if not Atributo.Vigente(Tipo.Código, Tipo."Tipo Entidad", EntidadDelContexto(Tipo."Tipo Entidad", FEmpleado, FProyecto), FechaDelAtributo(Tipo."Tipo Entidad")) then
            exit(false);
        Codigo := Atributo."Cód. Valor";
        EsNumero := true;
        Numero := Atributo."Valor Numérico";
        exit(true);
    end;

    local procedure EsLiteralTexto(Texto: Text): Boolean
    var
        Posicion: Integer;
    begin
        Texto := Texto.Trim();
        if StrLen(Texto) < 2 then
            exit(false);
        if (Texto[1] <> '''') or (Texto[StrLen(Texto)] <> '''') then
            exit(false);
        Posicion := 1;
        SaltarTexto(Texto, Posicion);
        exit(Posicion > StrLen(Texto));
    end;

    local procedure CodigoComparacionValido(Nombre: Text; Codigo: Text): Boolean
    var
        Valor: Record "Valor Atributo Liq.";
        TipoLiq: Record "Tipo Liquidación";
    begin
        Nombre := Nombre.Trim().ToUpper();
        if Codigo = '' then
            exit(false);
        if FCodigosSistema.ContainsKey(Nombre) then
            exit(TipoLiq.Get(CopyStr(Codigo, 1, 20)));
        if not FAtributosPorNombre.ContainsKey(Nombre) then
            exit(false);
        // Igual que ValidarCodigoAtributo: el literal pertenece al tipo, pero su número
        // no se toma del catálogo actual. Se conservó el sellado en OperandoEstatico.
        Valor.SetRange("Cód. Tipo Atributo", FAtributosPorNombre.Get(Nombre));
        Valor.SetRange(Código, CopyStr(Codigo, 1, 20));
        exit(not Valor.IsEmpty());
    end;

    local procedure NombreParametroSinColision(Nombre: Text): Boolean
    var
        Fuente: Record "Fuente Datos Liquidación" temporary;
    begin
        if FNombresConcepto.ContainsKey(Nombre) or FAtributosPorNombre.ContainsKey(Nombre) or FNombresSistema.ContainsKey(Nombre) then
            exit(false);
        if FFuentesPorNombre.ContainsKey(Nombre) then begin
            Fuente.Copy(FFuentes, true);
            if Fuente.Get(CopyStr(Nombre, 1, 30)) then
                if Fuente.Activo then
                    exit(false);
        end;
        exit(true);
    end;

    local procedure FechaDelAtributo(TipoEntidad: Enum "Tipo Entidad Estado"): Date
    begin
        if TipoEntidad = TipoEntidad::Empleado then
            exit(FFechaAtributos);
        exit(FFechaRef);
    end;

    local procedure CompararNumeros(Izquierda: Decimal; Derecha: Decimal; Operador: Text): Integer
    var
        Resultado: Boolean;
    begin
        case Operador of
            '=': Resultado := Izquierda = Derecha;
            '<>': Resultado := Izquierda <> Derecha;
            '<': Resultado := Izquierda < Derecha;
            '>': Resultado := Izquierda > Derecha;
            '<=': Resultado := Izquierda <= Derecha;
            '>=': Resultado := Izquierda >= Derecha;
        end;
        if Resultado then exit(1);
        exit(0);
    end;

    local procedure BuscarOperadorLogico(Texto: Text; Operador: Text): Integer
    var
        Posicion: Integer;
        Nivel: Integer;
        Antes: Boolean;
        Despues: Boolean;
    begin
        Posicion := 1;
        while Posicion <= StrLen(Texto) do
            if Texto[Posicion] = '''' then
                SaltarTexto(Texto, Posicion)
            else begin
                if Texto[Posicion] = '(' then Nivel += 1;
                if Texto[Posicion] = ')' then Nivel -= 1;
                if (Nivel = 0) and (CopyStr(Texto, Posicion, StrLen(Operador)).ToUpper() = Operador) then begin
                    Antes := Posicion = 1;
                    if not Antes then Antes := not EsIdentificador(Texto[Posicion - 1]);
                    Despues := Posicion + StrLen(Operador) > StrLen(Texto);
                    if not Despues then Despues := not EsIdentificador(Texto[Posicion + StrLen(Operador)]);
                    if Antes and Despues then exit(Posicion);
                end;
                Posicion += 1;
            end;
        exit(0);
    end;

    var
        FVersiones: Record "Parámetro Vigente" temporary;
        FConceptos: Record "Concepto Liquidación" temporary;
        FParametros: Record "Parámetro" temporary;
        FFuentes: Record "Fuente Datos Liquidación" temporary;
        FMotor: Codeunit "Motor Liquidación";
        FParametrosPorNombre: Dictionary of [Text, Code[20]];
        FAtributosPorNombre: Dictionary of [Text, Code[20]];
        FCodigosSistema: Dictionary of [Text, Boolean];
        FNombresSistema: Dictionary of [Text, Boolean];
        FNombresConcepto: Dictionary of [Text, Boolean];
        FFunciones: List of [Text];
        FOperadores: List of [Text];
        FFuentesPorNombre: Dictionary of [Text, Boolean];
        FVariablesExpresion: Dictionary of [Text, List of [Text]];
        FValores: Dictionary of [Code[50], Decimal];
        FFechas: Dictionary of [Code[50], Date];
        FBasesFisicas: Dictionary of [Code[50], Code[20]];
        FCodigosFisicos: Dictionary of [Code[50], Code[50]];
        FEmitidos: Dictionary of [Text, Integer];
        FCandidatosVistos: Dictionary of [Text, Boolean];
        FEmpleadosSinFase: Dictionary of [Code[20], Boolean];
        FConversionRevisada: Dictionary of [Text, Boolean];
        FParametrosConRegla: List of [Code[20]];
        FVigenciasRevisadas: Dictionary of [Text, Boolean];
        FProyectosNominaRevisados: Dictionary of [Code[20], Boolean];
        FCoberturaRevisada: Dictionary of [Text, Boolean];
        FSimular: Boolean;
        // Contextos a simular: empleado|proyecto|tipo|convenio|categoría, en el orden en que se encontraron.
        FContextosSimular: List of [Text];
        FCotizacionRevisada: Dictionary of [Text, Boolean];
        FFechasProyectoRevisadas: Dictionary of [Code[20], Boolean];
        FAvisosVigencia: Dictionary of [Text, Boolean];
        FBasesEnFecha: Dictionary of [Text, Boolean];
        FFechaMapa: Date;
        FFechaRef: Date;
        FFechaAtributos: Date;
        FFechaTC: Date;
        FDesde: Date;
        FHasta: Date;
        FCodPeriodo: Code[10];
        FTipo: Code[20];
        FEmpleado: Code[20];
        FProyecto: Code[20];
        FConvenio: Code[20];
        FCategoria: Code[20];
        FConvenioEvaluacion: Code[20];
        FCategoriaEvaluacion: Code[20];
        FCandidatos: Integer;
        FAnalizando: Boolean;
        FRevisandoCondicion: Boolean;
        FEncuadreConocido: Boolean;
        FAutoConversion: Boolean;
        FMonedaContexto: Code[10];
        FMonedasMixtas: Boolean;
        TxtRevisando: Label 'Revisando datos de entrada';
        TxtSimulando: Label 'Simulando el cálculo %1 %2', Comment = '%1=tipo de liquidación, %2=proyecto';
}
