import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/licencia/licencia.dart';
import '../core/licencia/licencia_service.dart';

class LicenciaConfigScreen extends StatefulWidget {
  final Licencia initialLicencia;
  final LicenciaService licenseService;
  final bool showBack;
  final void Function(Licencia)? onConfigured;

  const LicenciaConfigScreen({
    super.key,
    required this.initialLicencia,
    required this.licenseService,
    this.showBack = false,
    this.onConfigured,
  });

  @override
  State<LicenciaConfigScreen> createState() => _LicenciaConfigScreenState();
}

class _LicenciaConfigScreenState extends State<LicenciaConfigScreen> {
  late TextEditingController _tecnicoCtrl;
  late TextEditingController _licenciaCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _uuidCtrl;
  late TextEditingController _serverHostCtrl;
  late TextEditingController _serverApiCtrl;
  late TextEditingController _versionCtrl;
  late TextEditingController _apiKeyCtrl;

  bool _loading = false;
  bool _obscureLicencia = true;
  bool _obscureApiKey = true;
  String? _errorMsg;
  late int _configIntentos;
  bool _bloqueado = false;

  // Contador para el gesto secreto de desbloqueo (7 toques rápidos en el logo)
  int _secretTaps = 0;
  DateTime? _lastSecretTapTime;

  @override
  void initState() {
    super.initState();
    final lic = widget.initialLicencia;
    _configIntentos = lic.configIntentos;
    _bloqueado = _configIntentos >= 3;

    _tecnicoCtrl = TextEditingController(text: lic.tecnico);
    _licenciaCtrl = TextEditingController(text: lic.licenciaCodigo);
    _idCtrl = TextEditingController(text: lic.id);
    _uuidCtrl = TextEditingController(text: lic.uuid);
    _serverHostCtrl = TextEditingController(
      text: lic.serverHost.isNotEmpty ? lic.serverHost : Licencia.defaultBaseHost,
    );
    _serverApiCtrl = TextEditingController(
      text: lic.serverApi.isNotEmpty ? lic.serverApi : 'TECERPV7_TECPASS',
    );
    _versionCtrl = TextEditingController(
      text: lic.version.isNotEmpty ? lic.version : 'v1',
    );
    _apiKeyCtrl = TextEditingController(text: lic.apiKey);

    _initUuid();
  }

  Future<void> _initUuid() async {
    if (_uuidCtrl.text.isEmpty) {
      final uuid = await widget.licenseService.getOrCreateUuid();
      if (mounted) {
        setState(() {
          _uuidCtrl.text = uuid;
        });
      }
    }
  }

  @override
  void dispose() {
    _tecnicoCtrl.dispose();
    _licenciaCtrl.dispose();
    _idCtrl.dispose();
    _uuidCtrl.dispose();
    _serverHostCtrl.dispose();
    _serverApiCtrl.dispose();
    _versionCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _onLogoTapped() {
    final now = DateTime.now();
    if (_lastSecretTapTime == null || now.difference(_lastSecretTapTime!) > const Duration(seconds: 2)) {
      _secretTaps = 1;
    } else {
      _secretTaps++;
    }
    _lastSecretTapTime = now;

    if (_secretTaps >= 7) {
      _secretTaps = 0;
      setState(() {
        _configIntentos = 0;
        _bloqueado = false;
        _errorMsg = null;
      });
      final lic = _buildLicencia();
      lic.configIntentos = 0;
      widget.licenseService.save(lic);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔓 Modo técnico: Intentos de configuración restablecidos'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Licencia _buildLicencia() {
    final cod = _licenciaCtrl.text.trim();
    return Licencia(
      tecnico: _tecnicoCtrl.text.trim(),
      id: _idCtrl.text.trim(),
      identificador: Licencia.calcularIdentificador(cod),
      licenciaCodigo: cod,
      uuid: _uuidCtrl.text.trim(),
      serverHost: _serverHostCtrl.text.trim(),
      serverApi: _serverApiCtrl.text.trim(),
      version: _versionCtrl.text.trim().isEmpty ? 'v1' : _versionCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      configIntentos: _configIntentos,
      validada: widget.initialLicencia.validada,
      esAdmin: widget.initialLicencia.esAdmin,
      esSoloLec: widget.initialLicencia.esSoloLec,
    );
  }

  Future<void> _conectar() async {
    final lic = _buildLicencia();

    if (lic.licenciaCodigo.isEmpty) {
      setState(() => _errorMsg = 'El código de licencia es obligatorio');
      return;
    }
    if (lic.uuid.isEmpty) {
      setState(() => _errorMsg = 'No se ha podido resolver el UUID del dispositivo');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final result = await widget.licenseService.validate(lic);

      if (!mounted) return;

      if (result.ok) {
        setState(() {
          _loading = false;
          _configIntentos = 0;
        });
        lic.validada = true;
        lic.configIntentos = 0;
        lic.offlineIntentos = 0;
        await widget.licenseService.save(lic);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Licencia validada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onConfigured != null) {
          widget.onConfigured!(lic);
        } else {
          Navigator.of(context).pop(lic);
        }
      } else {
        // Si fue error de red/timeout, no penalizamos con intento fallido
        if (result.estado == LicenciaEstado.denegada) {
          _configIntentos++;
          lic.configIntentos = _configIntentos;
          await widget.licenseService.save(lic);
          if (!mounted) return;
          if (_configIntentos >= 3) {
            _bloqueado = true;
          }
        }

        if (!mounted) return;

        setState(() {
          _loading = false;
          _errorMsg = result.mensaje;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Error al validar la licencia: $e';
        });
      }
    }
  }

  void _copiarUuid() {
    final text = _uuidCtrl.text.trim();
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UUID copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación de Licencia'),
        automaticallyImplyLeading: widget.showBack,
      ),
      body: _bloqueado ? _buildBloqueadoView(colorScheme) : _buildFormulario(colorScheme),
    );
  }

  Widget _buildBloqueadoView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _onLogoTapped,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person, size: 72, color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Has agotado los 3 intentos de configuración',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Para desbloquear la aplicación, contacte con el equipo de soporte técnico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'UUID: ${_uuidCtrl.text}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _copiarUuid,
                    tooltip: 'Copiar UUID',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _onLogoTapped,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified_user, color: colorScheme.onPrimaryContainer, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sistema de Licencias',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Configure su licencia para activar la aplicación en este dispositivo',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Técnico / Empresa
          TextField(
            controller: _tecnicoCtrl,
            decoration: const InputDecoration(
              labelText: 'Técnico / Empresa',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 14),

          // Código de Licencia
          TextField(
            controller: _licenciaCtrl,
            obscureText: _obscureLicencia,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Código de Licencia',
              hintText: 'Ej: 3314',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.vpn_key),
              suffixIcon: IconButton(
                icon: Icon(_obscureLicencia ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureLicencia = !_obscureLicencia),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ID (opcional)
          TextField(
            controller: _idCtrl,
            decoration: const InputDecoration(
              labelText: 'ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 14),

          // UUID (Solo lectura con botón de copiar)
          TextField(
            controller: _uuidCtrl,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'UUID del Dispositivo',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.fingerprint),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar UUID',
                onPressed: _copiarUuid,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // URL Servidor de Licencia
          TextField(
            controller: _serverHostCtrl,
            decoration: const InputDecoration(
              labelText: 'URL Servidor de Licencia',
              hintText: 'https://tecerp.nunsys.com:4331',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cloud_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Nombre de Servidor de Licencia
          TextField(
            controller: _serverApiCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre Servidor de Licencia',
              hintText: 'Ej: TECERPV7_TECPASS',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns),
            ),
          ),
          const SizedBox(height: 14),

          // Versión de la API de Licencia
          TextField(
            controller: _versionCtrl,
            decoration: const InputDecoration(
              labelText: 'Versión de la API',
              hintText: 'Ej: v1',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 14),

          // Clave API de Licencia
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              labelText: 'Clave API de Licencia',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botón Conectar
          FilledButton.icon(
            onPressed: _loading ? null : _conectar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_done),
            label: Text(_loading ? 'Validando...' : 'Conectar y Validar'),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_configIntentos > 0 && _configIntentos < 3) ...[
            const SizedBox(height: 10),
            Text(
              '⚠️ Intento fallido $_configIntentos de 3',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
