namespace UAS.Payroll;

using System.Text;
using System.Security.Encryption;

/// <summary>
/// Habla OData V4 contra NAV. Es sólo transporte: pide páginas y devuelve JSON, no sabe nada de
/// proyectos ni de descargas.
/// </summary>
/// <remarks>
/// POR QUÉ ESTO NECESITA UNA SEGUNDA INSTANCIA DE NAV, y no es un capricho de configuración:
/// la instancia de producción responde `WWW-Authenticate: NTLM`, y el HttpClient de AL habla Basic
/// y bearer, no NTLM ni Kerberos. No hay forma de arreglarlo del lado de BC. La salida es levantar
/// otro service tier sobre la MISMA base con credential type NavUserPassword, publicando sólo
/// OData/SOAP; la de producción no se toca y ningún usuario de NAV cambia cómo entra.
///
/// V4 Y NO V3. Sobre las Query de NAV —que es lo que son ListaProyectos y DetalleDescargas— el V3
/// devuelve 400 ante un `$top` y sólo contesta si le mandás un `$filter`. El V4 pagina bien, acepta
/// `$top` y `$orderby`, y devuelve JSON en vez de Atom.
///
/// Y OJO CON EL DOCUMENTO DE SERVICIO DE V4: devuelve CERO entity sets aunque los endpoints existan
/// y contesten. Pedirle la lista y concluir que algo no está publicado es el error que hizo creer
/// durante días que no había endpoint de descargas. Para saber qué hay publicado hay que mirar el
/// documento de servicio de V3, o la tabla `Web Service` del origen.
/// </remarks>
codeunit 110040 "Cliente NAV WS"
{
    Access = Internal;

    var
        Cfg: Record "Config Sinc NAV";
        CfgCargada: Boolean;
        UltimoError: Text;
        TxtSinConfig: Label 'No hay configuración de sincronización para la empresa %1, o está inactiva.', Comment = '%1 = empresa de BC';
        TxtFaltaUrl: Label 'Falta la URL base de OData en "Configuración Sincronización NAV".';
        TxtFaltaUsuario: Label 'Falta el usuario de web services en "Configuración Sincronización NAV".';
        TxtFaltaClave: Label 'No hay clave de acceso guardada para el usuario %1. Cargala desde la ficha de configuración.', Comment = '%1 = usuario';
        TxtHttp: Label 'NAV respondió %1 %2 al pedir %3. %4', Comment = '%1 = código; %2 = motivo; %3 = ruta; %4 = cuerpo';
        TxtSinRespuesta: Label 'No hubo respuesta de %1. Verificá que la instancia de web services esté levantada y que el certificado sea válido.', Comment = '%1 = url';
        TxtSinEntidadPrueba: Label 'No hay entity set de proyectos configurado, así que no hay contra qué probar. Cargalo en la ficha de configuración.';
        TxtPruebaOk: Label 'Conecta bien. %1 respondió y devolvió %2 fila(s).', Comment = '%1 = entity set; %2 = cantidad';
        TxtJsonInvalido: Label 'La respuesta de %1 no es JSON válido. Si empieza con "<", es la página de error de IIS o un 401 en HTML: casi siempre significa que la instancia sigue pidiendo NTLM.', Comment = '%1 = ruta';

    /// <summary>
    /// Carga la configuración de la empresa. False si no hay, con el motivo en GetUltimoError.
    /// </summary>
    procedure SetEmpresa(EmpresaBC: Text[30]): Boolean
    begin
        Clear(Cfg);
        CfgCargada := false;
        UltimoError := '';

        if not Cfg.Get(EmpresaBC) then begin
            UltimoError := StrSubstNo(TxtSinConfig, EmpresaBC);
            exit(false);
        end;
        if not Cfg.Activo then begin
            UltimoError := StrSubstNo(TxtSinConfig, EmpresaBC);
            exit(false);
        end;

        CfgCargada := true;
        exit(true);
    end;

    procedure GetUltimoError(): Text
    begin
        exit(UltimoError);
    end;

    /// <summary>
    /// Pide una fila del entity set de proyectos. Es la prueba de vida: si esto anda, andan la URL,
    /// el certificado, la autenticación y los permisos del usuario.
    /// </summary>
    /// <remarks>
    /// Se prueba contra un entity set real y no contra la raíz del servicio a propósito: el
    /// documento de servicio de V4 contesta 200 con CERO entity sets aunque todo esté publicado y
    /// funcionando, así que una prueba contra la raíz diría "conecta" sin haber leído un solo dato,
    /// o "no hay nada publicado" sin que sea cierto. Con $top=1 la prueba es barata y concluyente.
    /// </remarks>
    procedure ProbarConexion(var Detalle: Text): Boolean
    var
        Filas: JsonArray;
        Siguiente: Text;
    begin
        Detalle := '';

        if not CfgCargada then begin
            Detalle := UltimoError;
            exit(false);
        end;
        if Cfg."Entidad Proyectos" = '' then begin
            Detalle := TxtSinEntidadPrueba;
            exit(false);
        end;

        if not ObtenerPagina(Cfg."Entidad Proyectos" + '?$top=1', Filas, Siguiente) then begin
            Detalle := UltimoError;
            exit(false);
        end;

        Detalle := StrSubstNo(TxtPruebaOk, Cfg."Entidad Proyectos", Filas.Count());
        exit(true);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  La clave de acceso
    // ────────────────────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Guarda la clave de acceso a web services en Isolated Storage.
    /// </summary>
    /// <remarks>
    /// NO va en un campo de la tabla, y la diferencia no es de estilo: un campo sale en una
    /// exportación de datos, en un paquete de configuración, en una consulta SQL del DBA y en la
    /// propia página si alguien le saca el HideValue. Isolated Storage no sale por ninguno de esos
    /// caminos. Lo que queda en la tabla es un booleano que dice si está cargada.
    /// </remarks>
    procedure GuardarClave(EmpresaBC: Text[30]; Clave: Text)
    var
        Cripto: Codeunit "Cryptography Management";
        Llave: Text;
    begin
        Llave := LlaveAlmacen(EmpresaBC);

        if Clave = '' then begin
            if IsolatedStorage.Contains(Llave, DataScope::Module) then
                IsolatedStorage.Delete(Llave, DataScope::Module);
        end else
            // Cifrada si la instancia tiene el cifrado habilitado; si no, en claro pero igual fuera
            // del alcance de cualquier exportación. Pedir cifrado sin clave de cifrado configurada
            // es un error en ejecución, no un aviso.
            if Cripto.IsEncryptionEnabled() then
                IsolatedStorage.SetEncrypted(Llave, Clave, DataScope::Module)
            else
                IsolatedStorage.Set(Llave, Clave, DataScope::Module);

        if Cfg.Get(EmpresaBC) then begin
            Cfg."Clave WS Cargada" := (Clave <> '');
            Cfg.Modify(true);
        end;
    end;

    procedure TieneClave(EmpresaBC: Text[30]): Boolean
    begin
        exit(IsolatedStorage.Contains(LlaveAlmacen(EmpresaBC), DataScope::Module));
    end;

    local procedure LlaveAlmacen(EmpresaBC: Text[30]): Text
    begin
        exit('SincNAV-ClaveWS-' + EmpresaBC);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Pedidos
    // ────────────────────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Trae UNA página del entity set. Devuelve las filas en Filas y, si hay más, la URL de la
    /// siguiente en Siguiente. False ante cualquier problema, con el motivo en GetUltimoError.
    /// </summary>
    procedure ObtenerPagina(Ruta: Text; var Filas: JsonArray; var Siguiente: Text): Boolean
    begin
        exit(ObtenerUrl(ArmarUrl(Ruta), Filas, Siguiente));
    end;

    /// <summary>
    /// Trae el entity set entero, siguiendo @odata.nextLink hasta el final.
    /// </summary>
    /// <remarks>
    /// NAV pagina de a 20.000 filas por su cuenta, sin que se lo pidas, y lo avisa con
    /// @odata.nextLink. Quedarse con la primera página es la forma silenciosa de sincronizar de
    /// menos: no hay error, simplemente faltan filas. Por eso el $top del llamador nunca reemplaza
    /// a seguir el nextLink — son cosas distintas.
    ///
    /// MaxPaginas existe para que un filtro mal armado no se convierta en una corrida infinita
    /// contra producción. Si se alcanza, es un error, no un corte silencioso.
    /// </remarks>
    procedure ObtenerTodo(Ruta: Text; var Filas: JsonArray): Boolean
    var
        Pagina: JsonArray;
        Token: JsonToken;
        Url: Text;
        Siguiente: Text;
        Paginas: Integer;
        i: Integer;
    begin
        Clear(Filas);
        Url := ArmarUrl(Ruta);

        while Url <> '' do begin
            Paginas += 1;
            if Paginas > MaxPaginas() then begin
                UltimoError := StrSubstNo(TxtDemasiadasPaginas, MaxPaginas(), Ruta);
                exit(false);
            end;

            Clear(Pagina);
            Siguiente := '';
            if not ObtenerUrl(Url, Pagina, Siguiente) then
                exit(false);

            for i := 0 to Pagina.Count() - 1 do begin
                Pagina.Get(i, Token);
                Filas.Add(Token);
            end;

            Url := Siguiente;
        end;

        exit(true);
    end;

    local procedure ObtenerUrl(Url: Text; var Filas: JsonArray; var Siguiente: Text): Boolean
    var
        Cliente: HttpClient;
        Respuesta: HttpResponseMessage;
        Cuerpo: Text;
        Raiz: JsonObject;
        Token: JsonToken;
    begin
        Clear(Filas);
        Siguiente := '';
        UltimoError := '';

        if not PrepararCliente(Cliente) then
            exit(false);

        Cliente.DefaultRequestHeaders().Clear();
        Cliente.DefaultRequestHeaders().Add('Accept', 'application/json');
        Cliente.DefaultRequestHeaders().Add('Authorization', CabeceraBasic());

        if not Cliente.Get(Url, Respuesta) then begin
            UltimoError := StrSubstNo(TxtSinRespuesta, Url);
            exit(false);
        end;

        Respuesta.Content().ReadAs(Cuerpo);

        if not Respuesta.IsSuccessStatusCode() then begin
            UltimoError := StrSubstNo(TxtHttp, Respuesta.HttpStatusCode(), Respuesta.ReasonPhrase(),
                                      Url, CopyStr(Cuerpo, 1, 500));
            exit(false);
        end;

        if not Raiz.ReadFrom(Cuerpo) then begin
            UltimoError := StrSubstNo(TxtJsonInvalido, Url);
            exit(false);
        end;

        // 'value' es el arreglo de filas en OData V4. Si no está, la respuesta es válida pero no es
        // una colección: devolver vacío sería decir "no hay filas", que no es lo mismo.
        if not Raiz.Get('value', Token) then begin
            UltimoError := StrSubstNo(TxtJsonInvalido, Url);
            exit(false);
        end;
        Filas := Token.AsArray();

        if Raiz.Get('@odata.nextLink', Token) then
            Siguiente := Token.AsValue().AsText();

        exit(true);
    end;

    local procedure PrepararCliente(var Cliente: HttpClient): Boolean
    begin
        if not CfgCargada then begin
            UltimoError := TxtFaltaUrl;
            exit(false);
        end;
        if Cfg."URL Base NAV" = '' then begin
            UltimoError := TxtFaltaUrl;
            exit(false);
        end;
        if Cfg."Usuario WS" = '' then begin
            UltimoError := TxtFaltaUsuario;
            exit(false);
        end;
        if not TieneClave(Cfg."Empresa BC") then begin
            UltimoError := StrSubstNo(TxtFaltaClave, Cfg."Usuario WS");
            exit(false);
        end;

        // CINCO MINUTOS, QUE ES EL MÁXIMO QUE ADMITE BC. Pedir más no es un aviso: el runtime lanza
        // NavNclHttpClientTimeoutTooLargeException y la llamada no llega a salir.
        //
        // Es por PEDIDO, no por corrida. El barrido inicial de las descargas son doscientas mil
        // filas, pero NAV las pagina de a veinte mil por su cuenta, así que lo que tiene que entrar
        // en cinco minutos es una página, no el total. El bucle que sigue los nextLink puede tardar
        // mucho más sin que esto lo corte.
        //
        // Si una página igual no entra en cinco minutos, la salida no es subir el número —no se
        // puede— sino pedir menos por vez con $top.
        Cliente.Timeout(300000);
        exit(true);
    end;

    local procedure CabeceraBasic(): Text
    var
        Base64: Codeunit "Base64 Convert";
        Clave: Text;
    begin
        if not LeerClave(Clave) then
            exit('');
        exit('Basic ' + Base64.ToBase64(Cfg."Usuario WS" + ':' + Clave));
    end;

    local procedure LeerClave(var Clave: Text): Boolean
    begin
        Clave := '';
        exit(IsolatedStorage.Get(LlaveAlmacen(Cfg."Empresa BC"), DataScope::Module, Clave));
    end;

    /// <summary>
    /// Arma la URL completa: base + empresa codificada + ruta.
    /// </summary>
    /// <remarks>
    /// La empresa va DOS veces transformada y las dos importan. Adentro de OData es un literal entre
    /// comillas simples, así que un apóstrofe en el nombre se duplica; y después toda la cadena se
    /// codifica para la URL, que es lo que convierte el espacio de "Arbumasa S.A." en %20. Saltear
    /// la segunda da un 400 que no menciona la empresa por ningún lado.
    /// </remarks>
    local procedure ArmarUrl(Ruta: Text): Text
    var
        Base: Text;
        Empresa: Text;
    begin
        Base := DelChr(Cfg."URL Base NAV", '>', '/');
        Empresa := CodificarUrl(Cfg."Empresa OData".Replace('''', ''''''));
        exit(Base + '/Company(''' + Empresa + ''')/' + Ruta);
    end;

    /// <summary>
    /// Codifica para URL los caracteres que puede tener un nombre de empresa de NAV.
    /// </summary>
    /// <remarks>
    /// Es una lista corta y deliberada, no un codificador general. Lo que entra acá es un nombre de
    /// empresa —"Arbumasa S.A."—, no texto arbitrario: de todo el juego de caracteres reservados,
    /// los únicos que aparecen en la práctica son el espacio y, muy de vez en cuando, el ampersand.
    ///
    /// El porcentaje va PRIMERO y no es un detalle de orden: si se codificara después, convertiría
    /// en %2520 el %20 que acaba de escribir la línea del espacio.
    ///
    /// Se hace a mano porque "Type Helper" no está disponible desde esta extensión. Un codificador
    /// general de tres líneas que cubra mal los casos raros sería peor que esto: acá está escrito
    /// qué cubre y qué no.
    /// </remarks>
    local procedure CodificarUrl(Valor: Text): Text
    begin
        Valor := Valor.Replace('%', '%25');
        Valor := Valor.Replace(' ', '%20');
        Valor := Valor.Replace('&', '%26');
        Valor := Valor.Replace('#', '%23');
        Valor := Valor.Replace('+', '%2B');
        Valor := Valor.Replace('?', '%3F');
        exit(Valor);
    end;

    local procedure MaxPaginas(): Integer
    begin
        exit(500);
    end;

    var
        TxtDemasiadasPaginas: Label 'Se pasaron las %1 páginas pidiendo %2 y no se llegó al final. Es casi seguro un filtro mal armado: revisar antes de volver a correrlo contra producción.', Comment = '%1 = máximo; %2 = ruta';
}
