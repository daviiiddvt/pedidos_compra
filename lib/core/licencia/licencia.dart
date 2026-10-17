/// Modelo que representa la configuración y estado de la licencia de la aplicación.
class Licencia {
  String tecnico;
  String id;
  String identificador;
  String licenciaCodigo;
  String uuid;
  String serverHost;
  String serverApi;
  String version;
  bool validada;
  String entM;
  String contraclave;
  int offlineIntentos;
  int configIntentos;
  String apiKey;
  String mainLicenseAppEntId;
  bool esAdmin;
  bool esSoloLec;
  String equipo;

  Licencia({
    this.tecnico = '',
    this.id = '',
    this.identificador = '',
    this.licenciaCodigo = '',
    this.uuid = '',
    this.serverHost = defaultBaseHost,
    this.serverApi = '',
    this.version = 'v1',
    this.validada = false,
    this.entM = '',
    this.contraclave = '',
    this.offlineIntentos = 0,
    this.configIntentos = 0,
    this.apiKey = '',
    this.mainLicenseAppEntId = '',
    this.esAdmin = false,
    this.esSoloLec = false,
    this.equipo = '',
  });

  /// Constante de ofuscación usada para calcular el identificador en app_ent.
  static const int constantesSuma = 3259;
  static const String defaultBaseHost = 'https://tecerp.nunsys.com:4331';

  /// Calcula el identificador de la licencia a partir del código numérico:
  /// identificador = codigo - 3259
  static String calcularIdentificador(String codigo) {
    final val = int.tryParse(codigo.trim());
    return val != null ? (val - constantesSuma).toString() : codigo.trim();
  }

  bool get isConfigured =>
      licenciaCodigo.isNotEmpty && identificador.isNotEmpty;

  /// Devuelve la URL completa del endpoint de validación en Velneo:
  /// {ServerApi}/TecERPv7_dat_dat/{Version}/app_ent/{Identificador}?api_key={ApiKey}
  String buildValidateUrl() {
    var rawApi = serverApi.trim();
    var rawHost = serverHost.trim();
    if (rawHost.isEmpty) rawHost = defaultBaseHost;
    if (rawHost.endsWith('/')) rawHost = rawHost.substring(0, rawHost.length - 1);

    String baseUrl;

    if (rawApi.startsWith('http://') || rawApi.startsWith('https://')) {
      var cleanApi = rawApi.endsWith('/') ? rawApi.substring(0, rawApi.length - 1) : rawApi;
      final uri = Uri.tryParse(cleanApi);
      if (uri != null && uri.pathSegments.isEmpty) {
        // Solo es el host sin subruta/instancia
        baseUrl = '$cleanApi/tecmicro';
      } else {
        // Ya tiene la instancia en la propia URL
        baseUrl = cleanApi;
      }
    } else if (rawApi.isNotEmpty) {
      // rawApi es el nombre de la instancia configurada (ej: TECMICRO_PRUEBAS_AD_AVANZADO, TECERPV7_TECPASS, etc.)
      final instance = rawApi.replaceAll('/', '');
      baseUrl = '$rawHost/$instance';
    } else {
      baseUrl = '$rawHost/tecmicro';
    }

    final v = version.trim().isEmpty ? 'v1' : version.trim();
    final key = apiKey.trim().isEmpty ? 'clave' : apiKey.trim();

    // Si baseUrl ya contiene el endpoint completo
    if (baseUrl.contains('/TecERPv7_dat_dat/')) {
      return '$baseUrl/$v/app_ent/$identificador?api_key=$key';
    }

    return '$baseUrl/TecERPv7_dat_dat/$v/app_ent/$identificador?api_key=$key';
  }

  /// Mapeo para persistencia en tabla SQLite `licencia`
  Map<String, dynamic> toDbMap() => {
        'id': 1,
        'tecnico': tecnico,
        'id_licencia': id,
        'identificador': identificador,
        'licencia_codigo': licenciaCodigo,
        'uuid': uuid,
        'server_host': serverHost.isNotEmpty ? serverHost : defaultBaseHost,
        'server_api': serverApi,
        'version': version,
        'validada': validada ? 1 : 0,
        'ent_m': entM,
        'contraclave': contraclave,
        'offline_intentos': offlineIntentos,
        'api_key': apiKey,
      };

  factory Licencia.fromDbMap(Map<String, dynamic> map) {
    final sHost = (map['server_host'] as String?) ?? '';
    final sApiRaw = (map['server_api'] as String?) ?? '';
    final sApi = sApiRaw == Licencia.defaultBaseHost ? '' : sApiRaw;

    return Licencia(
      tecnico: (map['tecnico'] as String?) ?? '',
      id: (map['id_licencia'] as String?) ?? '',
      identificador: (map['identificador'] as String?) ?? '',
      licenciaCodigo: (map['licencia_codigo'] as String?) ?? '',
      uuid: (map['uuid'] as String?) ?? '',
      serverHost: sHost.isNotEmpty ? sHost : Licencia.defaultBaseHost,
      serverApi: sApi,
      version: (map['version'] as String?) ?? 'v1',
      validada: (map['validada'] == 1 || map['validada'] == true),
      entM: (map['ent_m'] as String?) ?? '',
      contraclave: (map['contraclave'] as String?) ?? '',
      offlineIntentos: (map['offline_intentos'] as int?) ?? 0,
      apiKey: (map['api_key'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tecnico': tecnico,
        'id': id,
        'identificador': identificador,
        'licenciaCodigo': licenciaCodigo,
        'uuid': uuid,
        'serverHost': serverHost,
        'serverApi': serverApi,
        'version': version,
        'validada': validada,
        'entM': entM,
        'contraclave': contraclave,
        'offlineIntentos': offlineIntentos,
        'configIntentos': configIntentos,
        'apiKey': apiKey,
        'mainLicenseAppEntId': mainLicenseAppEntId,
        'esAdmin': esAdmin,
        'esSoloLec': esSoloLec,
        'equipo': equipo,
      };

  factory Licencia.fromJson(Map<String, dynamic> json) {
    final sApiRaw = (json['serverApi'] as String?) ?? '';
    final sApi = sApiRaw == Licencia.defaultBaseHost ? '' : sApiRaw;
    return Licencia(
        tecnico: (json['tecnico'] as String?) ?? '',
        id: (json['id'] as String?) ?? '',
        identificador: (json['identificador'] as String?) ?? '',
        licenciaCodigo: (json['licenciaCodigo'] as String?) ?? '',
        uuid: (json['uuid'] as String?) ?? '',
        serverHost: (json['serverHost'] as String?) ?? Licencia.defaultBaseHost,
        serverApi: sApi,
        version: (json['version'] as String?) ?? 'v1',
        validada: (json['validada'] as bool?) ?? false,
        entM: (json['entM'] as String?) ?? '',
        contraclave: (json['contraclave'] as String?) ?? '',
        offlineIntentos: (json['offlineIntentos'] as int?) ?? 0,
        configIntentos: (json['configIntentos'] as int?) ?? 0,
        apiKey: (json['apiKey'] as String?) ?? '',
        mainLicenseAppEntId: (json['mainLicenseAppEntId'] as String?) ?? '',
        esAdmin: (json['esAdmin'] as bool?) ?? false,
        esSoloLec: (json['esSoloLec'] as bool?) ?? false,
        equipo: (json['equipo'] as String?) ?? '',
      );
  }
}
