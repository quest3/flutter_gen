// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:dartx/dartx_io.dart';
import 'package:flutter_gen_core/generators/generator_helper.dart';
import 'package:flutter_gen_core/settings/pubspec.dart';
import 'package:flutter_gen_core/utils/error.dart';

const _tempSeparator = '_@#_';
const _separatorsToRemove = ['-', '_', '.'];

String generateI18n(
  DartFormatter formatter,
  Directory rootDirectory,
  FlutterGenI18n i18nConfig,
) {
  Directory i18nDirectory =
      Directory('${rootDirectory.path}/${i18nConfig.directory}');
  if (!i18nDirectory.existsSync()) {
    throw InvalidSettingsException(
        'directory "${i18nDirectory.path}" not exists.');
  }
  LocaleData localeData =
      _generateDictionaries(i18nDirectory, i18nConfig.localeForDocs);

  final className = i18nConfig.outputs.className;
  return localeData.generateFileContent(className, formatter);
}

LocaleData _generateDictionaries(
    Directory i18nDirectory, String localeForDocs) {
  List<Directory> dirs =
      i18nDirectory.listSync().whereType<Directory>().toList();
  if (dirs.isEmpty) {
    throw InvalidSettingsException(
        'no locale directory (such as "en/") found in "${i18nDirectory.path}".');
  }
  List<LocaleData> localeData = dirs
      .map((e) => LocaleData(
          _generateDictionariesForLocale(
              Directory('${i18nDirectory.path}/${e.nameWithoutExtension}')),
          e.nameWithoutExtension))
      .toList();
  return _determineLocaleData(localeData, localeForDocs);
}

LocaleData _determineLocaleData(
    List<LocaleData> localeData, String localeForDocs) {
  if (localeData.length == 1) {
    return localeData[0];
  }
  int? maxCount;
  bool differentKeyCount = false;
  int maxCountIndex = 0;
  int? targetLocaleIndex;
  for (int i = 0; i < localeData.length; i++) {
    var value = localeData[i];
    if (!differentKeyCount && maxCount != null && maxCount != value.keyCount) {
      differentKeyCount = true;
    }
    if (value.keyCount > (maxCount ?? 0)) {
      maxCount = value.keyCount;
      maxCountIndex = i;
    }
    if (localeForDocs == value.localeName) {
      targetLocaleIndex = i;
    }
  }
  LocaleData maxKeyData = localeData[maxCountIndex];
  List<String> maxDatakeys = maxKeyData.keys;

  List<String> missing = [];
  for (int i = 0; i < localeData.length; i++) {
    LocaleData data = localeData[i];
    if (data == maxKeyData) {
      continue;
    }
    missing.addAll(data.keys.where((e) => !maxDatakeys.contains(e)).map(
        (e) => 'warning: ${maxKeyData.localeName}.json missing key: "$e"'));
    missing.addAll(maxDatakeys
        .where((e) => !data.keys.contains(e))
        .map((e) => 'warning: ${data.localeName}.json missing key: "$e"'));
    missing.addAll(data.namespaces
        .map((e) => e.flattenData.entries.map((entry) =>
            MapEntry('${e.namespaceName}.${entry.key}', entry.value)))
        .reduce((value, e) => value.append(e))
        .where((e) => e.value.toString().isEmpty)
        .map((e) =>
            'warning: ${data.localeName}.json empty content: "${e.key}"'));
  }
  missing.sort(
    (a, b) => a.compareTo(b),
  );
  stderr.writeln(missing.join('\n'));
  if (differentKeyCount) {
    return maxKeyData;
  } else {
    return localeData[targetLocaleIndex ?? maxCountIndex];
  }
}

///generate map for all namespaces in single locale
List<NamespaceData> _generateDictionariesForLocale(Directory localeDir) {
  List<File> files = localeDir
      .listSync()
      .whereType<File>()
      .where((e) => e.extension == '.json')
      .toList();
  return files
      .map((e) => NamespaceData(_readJsonFile(e), e.nameWithoutExtension))
      .toList();
}

Map<String, dynamic> _readJsonFile(File file) {
  return json.decode(file.readAsStringSync());
}

class LocaleData {
  final List<NamespaceData> namespaces;
  final String localeName;

  LocaleData(this.namespaces, this.localeName);

  int get keyCount =>
      namespaces.map((e) => e.keyCount).reduce((value, e) => value + e);

  List<String> get keys => namespaces
      .map((e) => e.keys)
      .reduce((value, e) => value..addAll(e))
      .toList();

  String generateFileContent(String className, DartFormatter formatter) {
    final buffer = StringBuffer();
    buffer.writeln(header);
    buffer.writeln(ignore);
    buffer.writeln('class $className {');
    buffer.writeln('$className._();');
    for (final namespace in namespaces) {
      buffer.writeln(
          'static const ${namespace.className} ${namespace.namespaceName} = ${namespace.className}();');
    }
    buffer.writeln('}');
    for (final namespace in namespaces) {
      buffer.writeln(namespace.generateFileContent(localeName, formatter));
    }
    return formatter.format(buffer.toString());
  }
}

class _PluralData {
  final String name;
  final String key;
  Map<String, String> translation = {};

  _PluralData(this.name, this.key);
}

class NamespaceData {
  final Map<String, dynamic> data;
  final Map<String, dynamic> flattenData;
  final String namespaceName;
  final String className;

  List<String> get keys =>
      flattenData.keys.map((e) => '$namespaceName.$e').toList();

  int get keyCount => flattenData.length;

  NamespaceData(this.data, this.namespaceName)
      : className = '\$I18nDictionary${namespaceName.capitalize()}',
        flattenData = _flatJson(data, null);

  String generateFileContent(String localeName, DartFormatter formatter) {
    final buffer = StringBuffer();
    buffer.writeln('class $className {');
    buffer.writeln('const $className();');
    Map<String, _PluralData> plurals = {};
    for (final key in flattenData.keys) {
      List<String> words = key.split(_tempSeparator);
      String i18nKey = words.join('.');

      final splitOfLast = words.last.split('-');
      if (splitOfLast.length == 2) {
        // maybe plural
        int? number = int.tryParse(splitOfLast[1]);
        if (number != null || splitOfLast[1] == 'other') {
          // is plural
          for (final separator in _separatorsToRemove) {
            words = words.expand((e) => e.split(separator)).toList();
          }
          words.removeLast();
          i18nKey = words.join('.');
          String name = words[0];
          for (int i = 1; i < words.length; i++) {
            name = name + words[i].capitalize();
          }
          plurals[name] ??= _PluralData(name, i18nKey);
          if (number != null) {
            plurals[name]?.translation['$number'] =
                escapeString(flattenData[key].toString());
          } else if (splitOfLast[1] == 'other') {
            plurals[name]?.translation['other'] =
                escapeString(flattenData[key].toString());
          }
          continue;
        }
      }
      for (final separator in _separatorsToRemove) {
        words = words.expand((e) => e.split(separator)).toList();
      }
      String name = words[0];
      for (int i = 1; i < words.length; i++) {
        name = name + words[i].capitalize();
      }
      buffer.writeln('''
      /// key : $namespaceName.$i18nKey
      ///
      /// value ($localeName): ${escapeString(flattenData[key].toString())}
      String get $name => "$namespaceName.$i18nKey";
      ''');
    }
    if (plurals.isNotEmpty) {
      buffer.writeln('/// Plurals\n');
      for (final plural in plurals.values) {
        buffer.writeln('''
      /// key : $namespaceName.${plural.key}
      ///
      /// value ($localeName): ''');
        for (final e in plural.translation.entries) {
          buffer.writeln('///   ${e.key} => ${e.value}');
        }
        buffer.writeln(
            'String get ${plural.name} => "$namespaceName.${plural.key}";');
      }
    }
    buffer.writeln('}');
    return formatter.format(buffer.toString());
  }

  String escapeString(String s) {
    if (s.isEmpty) {
      return s;
    }
    var str = jsonEncode(s);
    return str.substring(1, str.length - 1);
  }

  /// flatten i18n json
  static Map<String, dynamic> _flatJson(
      Map<String, dynamic> data, String? prefix) {
    Map<String, dynamic> result = {};
    var keys = data.keys;
    for (final key in keys) {
      var value = data[key];
      String newKey = prefix == null ? key : _getTempKey(prefix, key);
      if (value is Map<String, dynamic>) {
        result.addAll(_flatJson(value, newKey));
      } else if (value is String) {
        if (result.containsKey(newKey)) {
          throw InvalidSettingsException(
              'key "$newKey" already exists with value "${result[newKey]}".');
        }
        result[newKey] = data[key];
      } else {
        throw InvalidSettingsException(
            'value "$value" is not String or Map, it\'s "${value.runtimeType}".');
      }
    }
    return result;
  }

  static String _getTempKey(String prefix, String key) {
    return '$prefix$_tempSeparator$key';
  }
}
