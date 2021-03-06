// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.target_implementation;

import 'package:_fe_analyzer_shared/src/messages/severity.dart' show Severity;

import 'package:kernel/ast.dart' show Source;

import 'package:kernel/target/targets.dart' as backend show Target;

import '../base/processed_options.dart' show ProcessedOptions;

import 'builder/class_builder.dart';
import 'builder/library_builder.dart';
import 'builder/member_builder.dart';

import 'compiler_context.dart' show CompilerContext;

import 'loader.dart' show Loader;

import 'messages.dart' show FormattedMessage, LocatedMessage, Message;

import 'rewrite_severity.dart' show rewriteSeverity;

import 'target.dart' show Target;

import 'ticker.dart' show Ticker;

import 'uri_translator.dart' show UriTranslator;

import '../api_prototype/experimental_flags.dart' show ExperimentalFlag;

/// Provides the implementation details used by a loader for a target.
abstract class TargetImplementation extends Target {
  final UriTranslator uriTranslator;

  final backend.Target backendTarget;

  final CompilerContext context = CompilerContext.current;

  /// Shared with [CompilerContext].
  final Map<Uri, Source> uriToSource = CompilerContext.current.uriToSource;

  MemberBuilder cachedAbstractClassInstantiationError;
  MemberBuilder cachedCompileTimeError;
  MemberBuilder cachedDuplicatedFieldInitializerError;
  MemberBuilder cachedNativeAnnotation;

  bool enableExtensionMethods;
  bool enableNonNullable;
  bool enableTripleShift;
  bool enableVariance;
  bool enableNonfunctionTypeAliases;

  TargetImplementation(Ticker ticker, this.uriTranslator, this.backendTarget)
      : enableExtensionMethods = CompilerContext.current.options
            .isExperimentEnabled(ExperimentalFlag.extensionMethods),
        enableNonNullable = CompilerContext.current.options
            .isExperimentEnabled(ExperimentalFlag.nonNullable),
        enableTripleShift = CompilerContext.current.options
            .isExperimentEnabled(ExperimentalFlag.tripleShift),
        enableVariance = CompilerContext.current.options
            .isExperimentEnabled(ExperimentalFlag.variance),
        enableNonfunctionTypeAliases = CompilerContext.current.options
            .isExperimentEnabled(ExperimentalFlag.nonfunctionTypeAliases),
        super(ticker);

  /// Creates a [LibraryBuilder] corresponding to [uri], if one doesn't exist
  /// already.
  ///
  /// [fileUri] must not be null and is a URI that can be passed to FileSystem
  /// to locate the corresponding file.
  ///
  /// [origin] is non-null if the created library is a patch to [origin].
  LibraryBuilder createLibraryBuilder(
      Uri uri, Uri fileUri, covariant LibraryBuilder origin);

  /// The class [cls] is involved in a cyclic definition. This method should
  /// ensure that the cycle is broken, for example, by removing superclass and
  /// implemented interfaces.
  void breakCycle(ClassBuilder cls);

  Uri translateUri(Uri uri) => uriTranslator.translate(uri);

  /// Returns a reference to the constructor of
  /// [AbstractClassInstantiationError] error.  The constructor is expected to
  /// accept a single argument of type String, which is the name of the
  /// abstract class.
  MemberBuilder getAbstractClassInstantiationError(Loader loader) {
    if (cachedAbstractClassInstantiationError != null) {
      return cachedAbstractClassInstantiationError;
    }
    return cachedAbstractClassInstantiationError =
        loader.coreLibrary.getConstructor("AbstractClassInstantiationError");
  }

  /// Returns a reference to the constructor used for creating a compile-time
  /// error. The constructor is expected to accept a single argument of type
  /// String, which is the compile-time error message.
  MemberBuilder getCompileTimeError(Loader loader) {
    if (cachedCompileTimeError != null) return cachedCompileTimeError;
    return cachedCompileTimeError = loader.coreLibrary
        .getConstructor("_CompileTimeError", bypassLibraryPrivacy: true);
  }

  /// Returns a reference to the constructor used for creating a runtime error
  /// when a final field is initialized twice. The constructor is expected to
  /// accept a single argument which is the name of the field.
  MemberBuilder getDuplicatedFieldInitializerError(Loader loader) {
    if (cachedDuplicatedFieldInitializerError != null) {
      return cachedDuplicatedFieldInitializerError;
    }
    return cachedDuplicatedFieldInitializerError = loader.coreLibrary
        .getConstructor("_DuplicatedFieldInitializerError",
            bypassLibraryPrivacy: true);
  }

  /// Returns a reference to the constructor used for creating `native`
  /// annotations. The constructor is expected to accept a single argument of
  /// type String, which is the name of the native method.
  MemberBuilder getNativeAnnotation(Loader loader) {
    if (cachedNativeAnnotation != null) return cachedNativeAnnotation;
    LibraryBuilder internal = loader.read(Uri.parse("dart:_internal"), -1,
        accessor: loader.coreLibrary);
    return cachedNativeAnnotation = internal.getConstructor("ExternalName");
  }

  void loadExtraRequiredLibraries(Loader loader) {
    for (String uri in backendTarget.extraRequiredLibraries) {
      loader.read(Uri.parse(uri), 0, accessor: loader.coreLibrary);
    }
    if (context.compilingPlatform) {
      for (String uri in backendTarget.extraRequiredLibrariesPlatform) {
        loader.read(Uri.parse(uri), 0, accessor: loader.coreLibrary);
      }
    }
  }

  void addSourceInformation(
      Uri importUri, Uri fileUri, List<int> lineStarts, List<int> sourceCode);

  void readPatchFiles(covariant LibraryBuilder library) {}

  FormattedMessage createFormattedMessage(
      Message message,
      int charOffset,
      int length,
      Uri fileUri,
      List<LocatedMessage> messageContext,
      Severity severity) {
    ProcessedOptions processedOptions = context.options;
    return processedOptions.format(
        message.withLocation(fileUri, charOffset, length),
        severity,
        messageContext);
  }

  Severity fixSeverity(Severity severity, Message message, Uri fileUri) {
    severity ??= message.code.severity;
    return rewriteSeverity(severity, message.code, fileUri);
  }

  String get currentSdkVersion {
    return CompilerContext.current.options.currentSdkVersion;
  }

  int _currentSdkVersionMajor;
  int _currentSdkVersionMinor;
  int get currentSdkVersionMajor {
    if (_currentSdkVersionMajor != null) return _currentSdkVersionMajor;
    _parseCurrentSdkVersion();
    return _currentSdkVersionMajor;
  }

  int get currentSdkVersionMinor {
    if (_currentSdkVersionMinor != null) return _currentSdkVersionMinor;
    _parseCurrentSdkVersion();
    return _currentSdkVersionMinor;
  }

  void _parseCurrentSdkVersion() {
    bool good = false;
    if (currentSdkVersion != null) {
      List<String> dotSeparatedParts = currentSdkVersion.split(".");
      if (dotSeparatedParts.length >= 2) {
        _currentSdkVersionMajor = int.tryParse(dotSeparatedParts[0]);
        _currentSdkVersionMinor = int.tryParse(dotSeparatedParts[1]);
        good = true;
      }
    }
    if (!good) {
      throw new StateError("Unparsable sdk version given: $currentSdkVersion");
    }
  }

  void releaseAncillaryResources();
}
