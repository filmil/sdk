// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UndefinedNamedParameterTest);
  });
}

@reflectiveTest
class UndefinedNamedParameterTest extends DriverResolutionTest {
  test_undefined() async {
    await assertErrorsInCode('''
f({a, b}) {}
main() {
  f(c: 1);
}''', [
      error(CompileTimeErrorCode.UNDEFINED_NAMED_PARAMETER, 26, 1),
    ]);
  }
}
