import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/api_service.dart';
import '../theme/app_theme.dart';

Future<Cliente?> mostrarCrearClienteModal(BuildContext context, {required String initialName}) {
  return showDialog<Cliente>(
    context: context,
    builder: (ctx) => _ClienteFormModal(initialName: initialName),
  );
}

class _ClienteFormModal extends StatefulWidget {
  final String initialName;

  const _ClienteFormModal({required this.initialName});

  @override
  State<_ClienteFormModal> createState() => _ClienteFormModalState();
}

class _ClienteFormModalState extends State<_ClienteFormModal> {
  final _formKey = GlobalKey<FormState>();
  late String _nombre;
  String _cif = '';
  String _telefono = '';
  String _email = '';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombre = widget.initialName;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _guardando = true);

    try {
      final cliente = await PedidosService.crearCliente(
        nombre: _nombre.trim(),
        cif: _cif.trim(),
        telefono: _telefono.trim(),
        email: _email.trim(),
      );
      if (mounted) Navigator.of(context).pop(cliente);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear cliente: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nuevo Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre comercial / Razón social *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                  onSaved: (v) => _nombre = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _cif,
                  decoration: const InputDecoration(labelText: 'CIF / NIF'),
                  onSaved: (v) => _cif = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  onSaved: (v) => _telefono = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSaved: (v) => _email = v ?? '',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Crear Cliente'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
