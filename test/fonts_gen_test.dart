@TestOn('vm')
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:flutter_gen/src/generators/fonts_generator.dart';
import 'package:flutter_gen/src/settings/config.dart';
import 'package:flutter_gen/src/utils/error.dart';
import 'package:test/test.dart';

import 'gen_test_helper.dart';

void main() {
  group('Test Fonts generator', () {
    test('Fonts on pubspec.yaml', () async {
      final pubspec = 'test_resources/pubspec_fonts.yaml';
      final fact = 'test_resources/actual_data/fonts.gen.dart';
      final generated = 'test_resources/lib/gen/fonts.gen.dart';

      expectedFontsGen(pubspec, generated, fact);
    });

    test('Wrong fonts settings on pubspec.yaml', () async {
      final config = await Config(
        File('test_resources/pubspec_fonts_no_family.yaml'),
      ).load();
      final formatter = DartFormatter(
          pageWidth: config.flutterGen.lineLength, lineEnding: '\n');

      expect(() {
        return generateFonts(formatter, config.flutter.fonts);
      }, throwsA(isA<InvalidSettingsException>()));
    });
  });
}
