import '../api_service.dart';
import '../models.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime loadedAt;
  final Duration ttl;

  const _CacheEntry({
    required this.data,
    required this.loadedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(loadedAt) > ttl;
}

class MasterCacheService {
  static final MasterCacheService _instance = MasterCacheService._internal();

  factory MasterCacheService() => _instance;

  MasterCacheService._internal();

  final Map<String, _CacheEntry<dynamic>> _cache = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  static const Duration _defaultTtl = Duration(minutes: 10);

  Future<T> getOrLoad<T>({
    required String key,
    required Future<T> Function() loader,
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    final existing = _cache[key];
    if (!forceRefresh && existing != null && !existing.isExpired) {
      return existing.data as T;
    }

    if (_inFlight.containsKey(key)) {
      return await _inFlight[key] as T;
    }

    final future = loader().then((data) {
      _cache[key] = _CacheEntry<T>(
        data: data,
        loadedAt: DateTime.now(),
        ttl: ttl ?? _defaultTtl,
      );
      _inFlight.remove(key);
      return data;
    }).catchError((Object error, StackTrace stackTrace) {
      _inFlight.remove(key);
      throw error;
    });

    _inFlight[key] = future;
    return await future;
  }

  Future<void> syncSessionMasters({Duration timeout = const Duration(seconds: 8)}) async {
    final priorityTasks = <Future<void>>[
      _loadAndCache('series', PedidosService.getSeries, timeout: timeout),
      _loadAndCache('almacenes', PedidosService.getAlmacenes, timeout: timeout),
      _loadAndCache('formas_pago', PedidosService.getFormasPago, timeout: timeout),
      _loadAndCache('comerciales', PedidosService.getComerciales, timeout: timeout),
    ];

    await Future.wait(priorityTasks);
  }

  Future<void> _loadAndCache(
    String key,
    Future<List<OpcionMaestra>> Function() loader, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      await getOrLoad<List<OpcionMaestra>>(
        key: key,
        loader: () => loader().timeout(timeout),
        ttl: const Duration(minutes: 10),
      );
    } catch (_) {
      // Se omite para no bloquear la sesión si un maestro falla.
    }
  }

  Future<List<OpcionMaestra>> searchClientes(
    String query, {
    int limit = 25,
    bool forceRefresh = false,
  }) async {
    final key = 'clientes_search:$query:$limit';
    return getOrLoad<List<OpcionMaestra>>(
      key: key,
      forceRefresh: forceRefresh,
      ttl: const Duration(minutes: 5),
      loader: () => PedidosService.searchClientes(query, limit: limit),
    );
  }

  Future<List<OpcionMaestra>> searchArticulos(
    String query, {
    int limit = 25,
    bool forceRefresh = false,
  }) async {
    final key = 'articulos_search:$query:$limit';
    return getOrLoad<List<OpcionMaestra>>(
      key: key,
      forceRefresh: forceRefresh,
      ttl: const Duration(minutes: 5),
      loader: () => PedidosService.searchArticulos(query, limit: limit),
    );
  }

  Future<OpcionMaestra?> getClienteById(int id, {bool forceRefresh = false}) async {
    final key = 'cliente_id:$id';
    final cached = _cache[key];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.data as OpcionMaestra?;
    }

    // Consulta del id concreto al API (sin descargar el maestro completo).
    final cliente = await PedidosService.getClienteById('$id');

    if (cliente != null) {
      _cache[key] = _CacheEntry<OpcionMaestra>(
        data: cliente,
        loadedAt: DateTime.now(),
        ttl: const Duration(minutes: 30),
      );
    }

    return cliente;
  }

  Future<OpcionMaestra?> getArticuloById(int id, {bool forceRefresh = false}) async {
    final key = 'articulo_id:$id';
    final cached = _cache[key];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.data as OpcionMaestra?;
    }

    // Consulta del id concreto al API (sin descargar el maestro completo).
    final articulo = await PedidosService.getArticuloById('$id');

    if (articulo != null) {
      _cache[key] = _CacheEntry<OpcionMaestra>(
        data: articulo,
        loadedAt: DateTime.now(),
        ttl: const Duration(minutes: 30),
      );
    }

    return articulo;
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();
  }

  bool contains(String key) => _cache.containsKey(key);
}

