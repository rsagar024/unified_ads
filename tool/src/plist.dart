/// Minimal XML property-list reader for tool/verify_ios_plist.dart.
///
/// Handles the XML plist format Xcode writes for `Info.plist` and
/// `PrivacyInfo.xcprivacy` (binary plists are not supported; convert them
/// with `plutil -convert xml1`). Pure Dart, so it runs on any host OS.
library;

import 'package:xml/xml.dart';

/// Thrown when a file is not a readable XML property list.
class PlistFormatException implements Exception {
  /// Creates the exception.
  PlistFormatException(this.message);

  /// What is wrong with the file.
  final String message;

  @override
  String toString() => 'PlistFormatException: $message';
}

/// Parses an XML property list.
///
/// Returns `Map<String, Object?>` for `<dict>`, `List<Object?>` for
/// `<array>`, `String`, `int`, `double`, `bool`, `DateTime` (`<date>`) or the
/// raw base64 `String` (`<data>`).
Object? parsePlist(String source) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(source);
  } on XmlException catch (e) {
    throw PlistFormatException('not XML: ${e.message}');
  }
  final root = doc.rootElement;
  if (root.name.local != 'plist') {
    throw PlistFormatException(
      'root element is <${root.name.local}>, '
      'expected <plist>',
    );
  }
  final values = root.childElements.toList();
  if (values.length != 1) {
    throw PlistFormatException('<plist> must contain exactly one value');
  }
  return _value(values.single);
}

Object? _value(XmlElement e) {
  switch (e.name.local) {
    case 'dict':
      final children = e.childElements.toList();
      final map = <String, Object?>{};
      for (var i = 0; i < children.length; i += 2) {
        final key = children[i];
        if (key.name.local != 'key' || i + 1 >= children.length) {
          throw PlistFormatException('malformed <dict> near <${key.name}>');
        }
        map[key.innerText] = _value(children[i + 1]);
      }
      return map;
    case 'array':
      return [for (final c in e.childElements) _value(c)];
    case 'string':
    case 'data':
      return e.innerText;
    case 'integer':
      return int.parse(e.innerText.trim());
    case 'real':
      return double.parse(e.innerText.trim());
    case 'true':
      return true;
    case 'false':
      return false;
    case 'date':
      return DateTime.parse(e.innerText.trim());
    default:
      throw PlistFormatException('unsupported element <${e.name.local}>');
  }
}
