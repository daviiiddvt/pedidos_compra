import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final source = File('docs/GUIA_PROYECTO_PEDIDOS_VENTA.md');
  final output = File('docs/GUIA_PROYECTO_PEDIDOS_VENTA.pdf');
  final lines = source.readAsLinesSync();
  final regular = _loadFont(
    'C:/Windows/Fonts/segoeui.ttf',
    fallback: pw.Font.helvetica(),
  );
  final bold = _loadFont(
    'C:/Windows/Fonts/segoeuib.ttf',
    fallback: pw.Font.helveticaBold(),
  );
  final mono = _loadFont(
    'C:/Windows/Fonts/consola.ttf',
    fallback: pw.Font.courier(),
  );
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final document = pw.Document(theme: theme);
  final body = <pw.Widget>[];
  var inCode = false;
  final code = <String>[];

  void flushCode() {
    if (code.isEmpty) return;
    body.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F1F5F8'),
          border: pw.Border(
            left: pw.BorderSide(
              color: PdfColor.fromHex('#1E7A8A'),
              width: 3,
            ),
          ),
        ),
        child: pw.Text(
          code.join('\n'),
          style: pw.TextStyle(font: mono, fontSize: 6.8, color: PdfColor.fromHex('#263746')),
        ),
      ),
    );
    code.clear();
  }

  for (final line in lines) {
    if (line.startsWith('```')) {
      if (inCode) flushCode();
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      code.add(line);
      continue;
    }
    if (line.startsWith('# ')) {
      body.add(_title(line.substring(2), bold));
    } else if (line.startsWith('## ')) {
      body.add(_heading(line.substring(3), bold, 1));
    } else if (line.startsWith('### ')) {
      body.add(_heading(line.substring(4), bold, 2));
    } else if (line.startsWith('- ')) {
      body.add(
        pw.Bullet(
          text: _clean(line.substring(2)),
          style: pw.TextStyle(font: regular, fontSize: 8.7, color: PdfColor.fromHex('#263238')),
        ),
      );
    } else if (line.trim().isNotEmpty) {
      body.add(
        pw.Paragraph(
          text: _clean(line),
          style: pw.TextStyle(font: regular, fontSize: 8.7, lineSpacing: 2.8, color: PdfColor.fromHex('#263238')),
        ),
      );
    } else {
      body.add(pw.SizedBox(height: 5));
    }
  }
  flushCode();

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Container(
        color: PdfColor.fromHex('#F7FAFC'),
        padding: const pw.EdgeInsets.all(42),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 12, color: PdfColor.fromHex('#176B87')),
            pw.SizedBox(height: 70),
            pw.Text(
              'PEDIDOS DE VENTA',
              style: pw.TextStyle(font: bold, fontSize: 28, color: PdfColor.fromHex('#17324D')),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Guia de desarrollo para continuar el proyecto Flutter',
              style: pw.TextStyle(font: regular, fontSize: 14, color: PdfColor.fromHex('#176B87')),
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E5F1F3'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                'Arquitectura, Velneo, modelos, pantallas, filtros y comandos practicos.',
                style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColor.fromHex('#234E70')),
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Text('Proyecto pedidos_venta', style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    ),
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      header: (context) => pw.Text(
        'Guia del proyecto Pedidos de Venta',
        style: pw.TextStyle(font: regular, fontSize: 7.5, color: PdfColors.grey600),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Pagina ${context.pageNumber}',
          style: pw.TextStyle(font: regular, fontSize: 7.5, color: PdfColors.grey600),
        ),
      ),
      build: (context) => body,
    ),
  );

  output.writeAsBytesSync(await document.save());
  stdout.writeln(output.path);
}

pw.Font _loadFont(String path, {required pw.Font fallback}) {
  final file = File(path);
  return file.existsSync() ? pw.Font.ttf(file.readAsBytesSync().buffer.asByteData()) : fallback;
}

String _clean(String value) {
  return value.replaceAll('**', '').replaceAll('`', '');
}

pw.Widget _title(String text, pw.Font bold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Text(
      _clean(text),
      style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColor.fromHex('#17324D')),
    ),
  );
}

pw.Widget _heading(String text, pw.Font bold, int level) {
  return pw.Container(
    margin: pw.EdgeInsets.only(top: level == 1 ? 14 : 8, bottom: 5),
    padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: PdfColor.fromHex('#1E7A8A'), width: 3)),
    ),
    child: pw.Text(
      _clean(text),
      style: pw.TextStyle(
        font: bold,
        fontSize: level == 1 ? 12.5 : 10.5,
        color: level == 1 ? PdfColor.fromHex('#176B87') : PdfColor.fromHex('#234E70'),
      ),
    ),
  );
}
