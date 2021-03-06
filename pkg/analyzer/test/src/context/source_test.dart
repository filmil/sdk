// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/context/source.dart';
import 'package:analyzer/src/file_system/file_system.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';
import 'package:package_config/packages.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SourceFactoryImplTest);
  });
}

@reflectiveTest
class SourceFactoryImplTest with ResourceProviderMixin {
  void test_restoreUri() {
    String libPath = convertPath('/pkgs/somepkg/lib');
    Uri libUri = getFolder(libPath).toUri();
    Map<String, Uri> packageUriMap = <String, Uri>{'foo': libUri};
    SourceFactoryImpl sourceFactory = new SourceFactoryImpl(
      <UriResolver>[new ResourceUriResolver(resourceProvider)],
      new _MockPackages(packageUriMap),
    );
    Source libSource = newFile('/pkgs/somepkg/lib').createSource();
    Uri uri = sourceFactory.restoreUri(libSource);
    try {
      expect(uri, Uri.parse('package:foo/'));
    } catch (e) {
      print('=== debug info ===');
      print('libPath: $libPath');
      print('libUri: $libUri');
      print('libSource: ${libSource?.fullName}');
      rethrow;
    }
  }
}

/**
 * An implementation of [Packages] used for testing.
 */
class _MockPackages implements Packages {
  final Map<String, Uri> map;

  _MockPackages(this.map);

  @override
  Iterable<String> get packages => map.keys;

  @override
  Map<String, Uri> asMap() => map;

  @override
  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)}) {
    fail('Unexpected invocation of resolve');
  }

  @override
  String get defaultPackageName {
    fail('Unexpected invocation of defaultPackageName');
  }

  @override
  String libraryMetadata(Uri libraryUri, String key) {
    fail('Unexpected invocation of libraryMetadata');
  }

  @override
  String packageMetadata(String packageName, String key) {
    fail('Unexpected invocation of packageMetadata');
  }
}
