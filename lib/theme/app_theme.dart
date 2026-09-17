// ============================================================================
//  app_theme.dart  —  COLORES Y ESTILOS DE TODA LA APP (el "diseño central")
// ============================================================================
//
//  ¿Para qué sirve?
//  ----------------
//  En lugar de poner colores sueltos en cada pantalla, los centralizamos aquí.
//  Así toda la app se ve uniforme y, si quieres cambiar el azul por otro color,
//  solo tienes que tocar UNA línea (AppColors.primary).
//
//  Este archivo define DOS clases:
//    1) AppColors  → todos los COLORES (y alguna lógica de colores de estados).
//    2) AppTheme   → las reglas de ESTILO (botones, campos, tarjetas...).
// ============================================================================

import 'package:flutter/material.dart'; // Trae el sistema de colores y temas.

/// AppColors: la "paleta" de la app, agrupada por nombre.
/// Un Color(0xFF1976D2) es un color en formato hexadecimal: #1976D2.
class AppColors {
  static const primary = Color(0xFF1976D2); // Azul principal (botones, barras).
  static const primaryDark = Color(0xFF1565C0); // Azul más oscuro (pulsado).
  static const primaryLight = Color(0xFFE3F2FD); // Azul muy claro (fondos suaves).
  static const accent = Color(0xFF4CAF50); // Verde de acento (éxito, flechas).
  static const background = Color(0xFFF5F7FA); // Fondo gris claro de las pantallas.
  static const surface = Color(0xFFFFFFFF); // Blanco (tarjetas y campos).
  static const text = Color(0xFF1C1E21); // Casi negro (texto principal).
  static const textSecondary = Color(0xFF5F6368); // Gris (texto secundario).
  static const border = Color(0xFFE0E0E0); // Gris claro (bordes de campos).
  static const error = Color(0xFFD32F2F); // Rojo (errores).
  static const warning = Color(0xFFF57C00); // Naranja (avisos).
  static const success = Color(0xFF388E3C); // Verde oscuro (estado recibido).
  static const disabled = Color(0xFFBDBDBD); // Gris apagado (elementos inactivos).
  static const white = Color(0xFFFFFFFF); // Blanco puro.

  // Colores de los ESTADOS de un pedido (venta):
  static const estadoPendiente = Color(0xFFF57C00); // Naranja (pendiente).
  static const estadoRecibido = Color(0xFF388E3C); // Verde (servido).
  static const estadoCancelado = Color(0xFF9E9E9E); // Gris (cancelado).

  /// estadoCodigo: traduce el texto o código del estado al código Velneo.
  /// Acepta "Recibido" como alias heredado de la interfaz, pero los estados
  /// de pedidos de venta se muestran como Pendiente, Servido y Cancelado.
  /// Se usa al filtrar la lista y al guardar pedidos.
  static String estadoCodigo(String? estado) {
    switch ((estado ?? '').toUpperCase().replaceAll(' ', '_')) {
      case 'P':
      case 'PENDIENTE':
      case 'PENDIENTE_DE_SERVIR':
        return 'P';
      case 'S':
      case 'SERVIDO':
      case 'RECIBIDO':
        return 'S';
      case 'C':
      case 'A':
      case 'CANCELADO':
      case 'ANULADO':
        return 'C';
      default:
        return estado ?? ''; // Desconocido → se envía tal cual (no rompe).
    }
  }

  /// estadoColor: devuelve el color según el estado del pedido.
  /// Acepta tanto los códigos de VELNEO ("P", "S", "C") como los textos
  /// ("Pendiente", "pendiente", "PENDIENTE DE SERVIR"...).
  static Color estadoColor(String? estado) {
    switch (estadoCodigo(estado)) {
      case 'P':
        return estadoPendiente;
      case 'S':
        return estadoRecibido;
      case 'C':
        return estadoCancelado;
      default:
        return primary; // Estado desconocido → azul.
    }
  }

  /// estadoLabel: texto bonito para mostrar ("Pendiente", "Servido"...).
  /// Acepta códigos y textos; da igual cómo lo mande el servidor.
  static String estadoLabel(String? estado) {
    switch (estadoCodigo(estado)) {
      case 'P':
        return 'Pendiente';
      case 'S':
        return 'Servido';
      case 'C':
        return 'Cancelado';
      default:
        return estado ?? '—'; // Desconocido → mostramos el texto tal cual (o guion).
    }
  }
}

/// AppTheme: construye el "tema" (aspecto global) que usará la MaterialApp.
class AppTheme {
  static ThemeData dark() => base(Brightness.dark); // Tema oscuro (no usado aún).
  static ThemeData light() => base(Brightness.light); // Tema claro → el que usamos.

  /// base: función padre que construye el tema dependiendo del brillo.
  /// Se define TODO aquí para no repetir código entre claro y oscuro.
  static ThemeData base(Brightness brightness) {
    // ColorScheme.fromSeed: genera una paleta completa de Material 3 a partir
    // de un color semilla (el azul). "seed" = de dónde saca la gama de colores.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true, // Usa el lenguaje visual moderno de Material.
      colorScheme: scheme, // La paleta generada.
      scaffoldBackgroundColor: AppColors.background, // Fondo general de pantallas.

      // --- Barra superior (AppBar) ---
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary, // Azul.
        foregroundColor: AppColors.white, // Texto e iconos blancos.
        elevation: 0, // Sin sombra.
      ),

      // --- Campos de texto (TextFormField) ---
      inputDecorationTheme: const InputDecorationTheme(
        filled: true, // Fondo relleno.
        fillColor: AppColors.surface, // Blanco.
        border: OutlineInputBorder( // Borde redondeado.
          borderRadius: BorderRadius.all(Radius.circular(10)), // Esquinas redondeadas.
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder( // Borde cuando el campo está activo.
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder( // Borde cuando lo estamos escribiendo.
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), // Respiración interna.
      ),

      // --- Botón principal (ElevatedButton) ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // Azul.
          foregroundColor: AppColors.white, // Texto blanco.
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Esquinas redondeadas.
          ),
        ),
      ),

      // --- Botón secundario (OutlinedButton, con borde) ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // --- Botón de texto (TextButton) ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),

      // --- Tarjetas (Card) ---
      cardTheme: const CardThemeData(
        color: AppColors.surface, // Fondo blanco.
        elevation: 2, // Sombra suave.
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Separación.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // --- Mensajes flotantes (SnackBar) ---
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating, // "Flotan" sobre el contenido.
      ),
    );
  }
}