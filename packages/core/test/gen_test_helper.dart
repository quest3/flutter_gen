import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:dartx/dartx_io.dart';
import 'package:flutter_gen_core/flutter_generator.dart';
import 'package:flutter_gen_core/generators/assets_generator.dart';
import 'package:flutter_gen_core/generators/colors_generator.dart';
import 'package:flutter_gen_core/generators/fonts_generator.dart';
import 'package:flutter_gen_core/generators/i18n_generator.dart';
import 'package:flutter_gen_core/settings/config.dart';
import 'package:flutter_gen_core/utils/formatter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> clearTestResults() async {}

(File, File) _getGeneratedAndFact(
  String pubspec,
  String type, {
  String? build,
}) {
  final pubspecFile = File(pubspec);
  final buildFile = build == null ? null : File(build);
  final config = loadPubspecConfigOrNull(pubspecFile, buildFile: buildFile);
  final namePrefix = build == null ? '' : 'build_';
  final nameWithoutExtension = (buildFile ?? pubspecFile).nameWithoutExtension;
  final name = '$namePrefix${type}_'
      '${nameWithoutExtension.removePrefix('pubspec_')}'
      '.gen.dart';
  final generated = pubspecFile.parent
      .directory(config?.pubspec.flutterGen.output ?? 'lib/gen')
      .file(name);
  final fact = pubspecFile.parent.directory('actual_data').file(name);
  return (generated, fact);
}

Future<(String, String)> runAssetsGen(
  String pubspec,
  String generated,
  String fact, {
  String? build,
}) async {
  stdout.writeln('[DEBUG] test: Generate assets from config...');
  final pubspecFile = File(pubspec);

  File? buildFile;
  if (build != null) {
    buildFile = File(build);
  }

  await FlutterGenerator(
    pubspecFile,
    buildFile: buildFile,
    assetsName: p.basename(generated),
  ).build();

  stdout.writeln('[DEBUG] test: Generate assets from API...');
  final config = loadPubspecConfig(pubspecFile, buildFile: buildFile);
  final formatter = buildDartFormatterFromConfig(config);

  final actual = await generateAssets(
    AssetsGenConfig.fromConfig(pubspecFile, config),
    formatter,
  );
  final expected = formatter.format(File(fact).readAsStringSync());
  return (actual, expected);
}
///i18n
Future<void> expectedI18nGen(
    String pubspec, String generated, String fact) async {
  await FlutterGenerator(File(pubspec), assetsName: basename(generated))
      .build();

  final pubspecFile = File(pubspec);
  final config = loadPubspecConfig(pubspecFile);
  final formatter = DartFormatter(
      pageWidth: config.pubspec.flutterGen.lineLength, lineEnding: '\n');

  final actual = generateI18n(
      formatter,
      pubspecFile.parent,
      FlutterGenI18n(
          enabled: config.pubspec.flutterGen.i18n.enabled,
          outputs: config.pubspec.flutterGen.i18n.outputs,
          directory: config.pubspec.flutterGen.i18n.directory));
  final expected =
  formatter.format(File(fact).readAsStringSync().replaceAll('\r\n', '\n'));

  expect(
    File(generated).readAsStringSync(),
    isNotEmpty,
  );
  expect(actual, expected);
}
/// Assets
Future<(String, String)> expectedAssetsGen(
  String pubspec, {
  String? build,
}) async {
  final (generated, fact) = _getGeneratedAndFact(
    pubspec,
    'assets',
    build: build,
  );
  final results = await runAssetsGen(
    pubspec,
    generated.path,
    fact.path,
    build: build,
  );
  final (actual, expected) = results;
  expect(
    generated.readAsStringSync(),
    isNotEmpty,
  );
  expect(actual, expected);
  return (actual, expected);
}

Future<(String, String)> runColorsGen(
  String pubspec,
  String generated,
  String fact, {
  String? build,
}) async {
  stdout.writeln('[DEBUG] test: Generate colors from config...');
  final pubspecFile = File(pubspec);

  File? buildFile;
  if (build != null) {
    buildFile = File(build);
  }

  await FlutterGenerator(
    pubspecFile,
    buildFile: buildFile,
    colorsName: p.basename(generated),
  ).build();

  stdout.writeln('[DEBUG] test: Generate colors from API...');
  final config = loadPubspecConfig(pubspecFile, buildFile: buildFile);
  final formatter = buildDartFormatterFromConfig(config);

  final actual = generateColors(
    pubspecFile,
    formatter,
    config.pubspec.flutterGen.colors,
  );
  final expected = formatter.format(File(fact).readAsStringSync());
  return (actual, expected);
}

/// Colors
Future<(String, String)> expectedColorsGen(
  String pubspec, {
  String? build,
}) async {
  final (generated, fact) = _getGeneratedAndFact(
    pubspec,
    'colors',
    build: build,
  );
  final results = await runColorsGen(pubspec, generated.path, fact.path);
  final (actual, expected) = results;
  expect(generated.readAsStringSync(), isNotEmpty);
  expect(actual, expected);
  return results;
}

Future<(String, String)> runFontsGen(
  String pubspec,
  String generated,
  String fact, {
  String? build,
}) async {
  stdout.writeln('[DEBUG] test: Generate fonts from config...');
  final pubspecFile = File(pubspec);

  File? buildFile;
  if (build != null) {
    buildFile = File(build);
  }

  await FlutterGenerator(
    pubspecFile,
    buildFile: buildFile,
    fontsName: p.basename(generated),
  ).build();

  stdout.writeln('[DEBUG] test: Generate fonts from API...');
  final config = loadPubspecConfig(pubspecFile, buildFile: buildFile);
  final formatter = buildDartFormatterFromConfig(config);

  final actual = generateFonts(
    FontsGenConfig.fromConfig(config),
    formatter,
  );
  final expected = formatter.format(File(fact).readAsStringSync());
  return (actual, expected);
}

/// Fonts
Future<(String, String)> expectedFontsGen(
  String pubspec, {
  String? build,
}) async {
  final (generated, fact) = _getGeneratedAndFact(
    pubspec,
    'fonts',
    build: build,
  );
  final results = await runFontsGen(pubspec, generated.path, fact.path);
  final (actual, expected) = results;
  expect(generated.readAsStringSync(), isNotEmpty);
  expect(actual, expected);
  return (actual, expected);
}

/// Verify generated package name.
String? expectedPackageNameGen(
  String pubspec,
  String? fact,
) {
  final pubspecFile = File(pubspec);
  final config = AssetsGenConfig.fromConfig(
    pubspecFile,
    loadPubspecConfig(pubspecFile),
  );
  final actual = generatePackageNameForConfig(config);
  expect(actual, equals(fact));
  return actual;
}
