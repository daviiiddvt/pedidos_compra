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
    this.serverApi = 'TECERPV7_TECPASS',
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
  /// {serverHost}/{serverApi}/TecERPv7_dat_dat/{version}/app_ent/{identificador}?api_key={apiKey}
  String buildValidateUrl() {
    final host = serverHost.trim().isEmpty ? defaultBaseHost : serverHost.trim();
    final cleanHost = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final instance = serverApi.trim().replaceAll('/', '');
    final v = version.trim().isEmpty ? 'v1' : version.trim();
    return '$cleanHost/$instance/TecERPv7_dat_dat/$v/app_ent/$identificador?api_key=${apiKey.trim()}';
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

  factory Licencia.fromJson(Map<String, dynamic> json) => Licencia(
        tecnico: (json['tecnico'] as String?) ?? '',
        id: (json['id'] as String?) ?? '',
        identificador: (json['identificador'] as String?) ?? '',
        licenciaCodigo: (json['licenciaCodigo'] as String?) ?? '',
        uuid: (json['uuid'] as String?) ?? '',
        serverHost: (json['serverHost'] as String?) ?? Licencia.defaultBaseHost,
        serverApi: (json['serverApi'] as String?) ?? 'TECERPV7_TECPASS',
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
