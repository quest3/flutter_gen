@TestOn('vm')
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:flutter_gen_core/generators/i18n_generator.dart';
import 'package:flutter_gen_core/settings/config.dart';
import 'package:flutter_gen_core/utils/error.dart';
import 'package:test/test.dart';

import 'gen_test_helper.dart';

void main() {
  group('Test I18n generator', () {
    test('I18n on pubspec.yaml', () async {
      const pubspec = 'test_resources/pubspec_i18n.yaml';
      const fact = 'test_resources/actual_data/i18n.gen.dart';
      const generated = 'test_resources/lib/gen/i18n.gen.dart';

      await expectedI18nGen(pubspec, generated, fact);
    });
  });
}
