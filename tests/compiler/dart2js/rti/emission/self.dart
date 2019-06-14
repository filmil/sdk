// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*class: C:checkedInstance,checks=[],instance,typeLiteral*/
class C {}

@pragma('dart2js:noInline')
test(o) => o is C;

main() {
  test(new C());
  test(null);
}