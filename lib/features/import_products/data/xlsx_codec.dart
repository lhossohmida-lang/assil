import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// قارئ/كاتب xlsx مصغَّر.
///
/// لماذا مكتوب يدوياً بدل حزمة جاهزة: كل حزم الجداول المتاحة
/// (`excel`، `spreadsheet_decoder`) تشترط `xml ^6`، بينما `pdf` — وهو
/// أساس كل الطباعة في التطبيق — يشترط `xml ^7`. لا يمكن الجمع بينهما.
/// وملف xlsx في جوهره ملف zip فيه بضعة ملفات XML، وقراءته وكتابته
/// أبسط من التنازل عن مكتبة الطباعة.
class XlsxCodec {
  XlsxCodec._();

  static const String _mainNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const String _relsNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const String _pkgRelsNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  // ───────────────────────── القراءة ─────────────────────────

  /// يقرأ أول ورقة في الملف كصفوف من النصوص.
  ///
  /// الصفوف مستطيلة: الخلايا الفارغة تُملأ بنصوص فارغة حتى لا تنزاح
  /// الأعمدة (ملفات إكسل تحذف الخلايا الفارغة من الـ XML).
  static List<List<String>> readRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final sharedStrings = _readSharedStrings(archive);
    final sheetPath = _firstSheetPath(archive);
    final sheetFile = archive.findFile(sheetPath);
    if (sheetFile == null) {
      throw const FormatException('لم توجد ورقة عمل داخل الملف');
    }

    final doc = XmlDocument.parse(utf8.decode(sheetFile.content));
    final rows = <List<String>>[];

    for (final rowNode in doc.findAllElements('row', namespaceUri: '*')) {
      final cells = <int, String>{};
      var maxColumn = -1;

      for (final cellNode in rowNode.findElements('c', namespaceUri: '*')) {
        final reference = cellNode.getAttribute('r') ?? '';
        final column = _columnIndex(reference);
        if (column < 0) continue;
        if (column > maxColumn) maxColumn = column;
        cells[column] = _cellText(cellNode, sharedStrings);
      }

      rows.add([
        for (var i = 0; i <= maxColumn; i++) cells[i] ?? '',
      ]);
    }

    return rows;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(file.content));
    return [
      for (final si in doc.findAllElements('si', namespaceUri: '*'))
        // النص قد يكون موزّعاً على عدّة <t> (نص منسّق) — نجمعها كلها.
        si
            .findAllElements('t', namespaceUri: '*')
            .map((t) => t.innerText)
            .join(),
    ];
  }

  /// مسار أول ورقة، متتبَّعاً عبر العلاقات لا بالتخمين.
  static String _firstSheetPath(Archive archive) {
    const fallback = 'xl/worksheets/sheet1.xml';
    try {
      final workbook = archive.findFile('xl/workbook.xml');
      final rels = archive.findFile('xl/_rels/workbook.xml.rels');
      if (workbook == null || rels == null) return fallback;

      final sheet = XmlDocument.parse(utf8.decode(workbook.content))
          .findAllElements('sheet', namespaceUri: '*')
          .firstOrNull;
      final relId = sheet?.getAttribute('id', namespaceUri: _relsNs) ??
          sheet?.getAttribute('r:id');
      if (relId == null) return fallback;

      for (final rel in XmlDocument.parse(utf8.decode(rels.content))
          .findAllElements('Relationship', namespaceUri: '*')) {
        if (rel.getAttribute('Id') != relId) continue;
        final target = rel.getAttribute('Target') ?? '';
        if (target.isEmpty) return fallback;
        return target.startsWith('/')
            ? target.substring(1)
            : (target.startsWith('xl/') ? target : 'xl/$target');
      }
    } catch (_) {
      // ملف غير معتاد — نجرّب المسار الشائع.
    }
    return fallback;
  }

  static String _cellText(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');

    if (type == 'inlineStr') {
      return cell
          .findAllElements('t', namespaceUri: '*')
          .map((t) => t.innerText)
          .join();
    }

    final value =
        cell.findElements('v', namespaceUri: '*').firstOrNull?.innerText ?? '';

    if (type == 's') {
      final index = int.tryParse(value);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }

    if (type == 'b') return value == '1' ? 'TRUE' : 'FALSE';

    return value;
  }

  /// «C5» → 2. يتجاهل الأرقام ويقرأ الحروف فقط.
  static int _columnIndex(String reference) {
    var index = 0;
    var seen = false;
    for (final code in reference.codeUnits) {
      if (code >= 65 && code <= 90) {
        index = index * 26 + (code - 64);
        seen = true;
      } else if (code >= 97 && code <= 122) {
        index = index * 26 + (code - 96);
        seen = true;
      } else if (seen) {
        break;
      }
    }
    return seen ? index - 1 : -1;
  }

  // ───────────────────────── الكتابة ─────────────────────────

  /// يبني ملف xlsx بسيطاً من صفوف نصّية (نصوص مضمَّنة، بلا sharedStrings).
  static Uint8List writeRows(
    List<List<String>> rows, {
    String sheetName = 'Sheet1',
  }) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="$_mainNs"><sheetData>');

    for (var r = 0; r < rows.length; r++) {
      buffer.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final ref = '${_columnName(c)}${r + 1}';
        final text = _escape(rows[r][c]);
        buffer.write(
          '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
          '$text</t></is></c>',
        );
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData></worksheet>');

    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes))
      ..addFile(_file('_rels/.rels', _packageRels))
      ..addFile(_file('xl/workbook.xml', _workbook(sheetName)))
      ..addFile(_file('xl/_rels/workbook.xml.rels', _workbookRels))
      ..addFile(_file('xl/worksheets/sheet1.xml', buffer.toString()));

    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  static ArchiveFile _file(String name, String content) =>
      ArchiveFile.bytes(name, utf8.encode(content));

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// 0 → A، 26 → AA.
  static String _columnName(int index) {
    var name = '';
    var i = index;
    while (i >= 0) {
      name = String.fromCharCode(65 + (i % 26)) + name;
      i = (i ~/ 26) - 1;
    }
    return name;
  }

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';

  static const String _packageRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="$_pkgRelsNs">'
      '<Relationship Id="rId1" '
      'Type="$_relsNs/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="$_pkgRelsNs">'
      '<Relationship Id="rId1" '
      'Type="$_relsNs/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>';

  static String _workbook(String sheetName) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_mainNs" xmlns:r="$_relsNs">'
      '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/>'
      '</sheets></workbook>';
}

/// قارئ CSV بسيط يدعم الاقتباس والفاصلة أو الفاصلة المنقوطة.
class CsvCodec {
  CsvCodec._();

  static List<List<String>> readRows(Uint8List bytes) {
    // UTF-8 مع تسامح مع BOM — ملفات إكسل العربية تبدأ به غالباً.
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);

    final separator = _detectSeparator(text);
    final rows = <List<String>>[];
    var cells = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (inQuotes) {
        if (char == '"') {
          // اقتباس مزدوج داخل حقل مقتبَس = علامة اقتباس حقيقية.
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
        continue;
      }

      if (char == '"') {
        inQuotes = true;
      } else if (char == separator) {
        cells.add(cell.toString());
        cell.clear();
      } else if (char == '\n') {
        cells.add(cell.toString());
        cell.clear();
        rows.add(cells);
        cells = <String>[];
      } else if (char != '\r') {
        cell.write(char);
      }
    }

    if (cell.isNotEmpty || cells.isNotEmpty) {
      cells.add(cell.toString());
      rows.add(cells);
    }
    return rows;
  }

  /// الفاصلة المنقوطة شائعة في إكسل الفرنسي/العربي.
  static String _detectSeparator(String text) {
    final head = text.split('\n').take(5).join('\n');
    final semicolons = ';'.allMatches(head).length;
    final commas = ','.allMatches(head).length;
    return semicolons > commas ? ';' : ',';
  }

  static Uint8List write(List<List<String>> rows) {
    final buffer = StringBuffer('﻿'); // BOM ليفتحه إكسل بترميز صحيح
    for (final row in rows) {
      buffer.writeln(row.map(_quote).join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _quote(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains(';')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
