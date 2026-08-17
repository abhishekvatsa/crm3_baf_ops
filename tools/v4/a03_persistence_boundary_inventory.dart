import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:crypto/crypto.dart';

final _root = Directory.current;
final _manifestFile = File(
  '${_root.path}${Platform.pathSeparator}governance${Platform.pathSeparator}a03-persistence-boundaries-v1.json',
);

void main(List<String> arguments) {
  final discovered = <Map<String, Object?>>[];
  final lib = Directory('${_root.path}${Platform.pathSeparator}lib');
  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    final relative = _relative(file.path);
    final result = parseString(
      content: source,
      path: file.path,
      throwIfDiagnostics: false,
    );
    final handles = _discoverHandles(result.unit);
    final visitor = _PersistenceVisitor(
      relativePath: relative,
      source: source,
      lineInfo: result.lineInfo,
      firestoreHandles: handles.firestore,
      isarHandles: handles.isar,
    );
    result.unit.accept(visitor);
    discovered.addAll(visitor.operations);
  }

  discovered.sort((left, right) {
    final byPath = (left['path']! as String).compareTo(
      right['path']! as String,
    );
    if (byPath != 0) return byPath;
    return (left['operation']! as String).compareTo(
      right['operation']! as String,
    );
  });

  final stableOperations = discovered
      .map(
        (operation) => <String, Object?>{
          'path': operation['path'],
          'operation': operation['operation'],
          'stores': operation['stores'],
          'modes': operation['modes'],
          'primitives': operation['primitives'],
          'siteCount': operation['siteCount'],
        },
      )
      .toList(growable: false);
  final inventoryDigest =
      sha256
          .convert(utf8.encode(jsonEncode(stableOperations)))
          .toString()
          .toUpperCase();

  if (arguments.contains('--write-policy-template')) {
    _writePolicyTemplate(discovered, inventoryDigest);
    stdout.writeln(_manifestFile.path);
    return;
  }

  final report = <String, Object?>{
    'findingId': 'A-03',
    'gitHead': _gitHead(),
    'operationCount': discovered.length,
    'siteCount': discovered.fold<int>(
      0,
      (total, operation) => total + (operation['siteCount']! as int),
    ),
    'inventoryDigest': inventoryDigest,
    'operations': discovered,
  };
  if (arguments.contains('--summary')) {
    final byPath = <String, List<Map<String, Object?>>>{};
    for (final operation in discovered) {
      byPath.putIfAbsent(operation['path']! as String, () => []).add(operation);
    }
    report
      ..remove('operations')
      ..['fileCount'] = byPath.length
      ..['files'] = byPath.entries
          .map((entry) {
            final stores = <String>{};
            final modes = <String>{};
            for (final operation in entry.value) {
              stores.addAll((operation['stores']! as List).cast<String>());
              modes.addAll((operation['modes']! as List).cast<String>());
            }
            return <String, Object?>{
              'path': entry.key,
              'operationCount': entry.value.length,
              'stores': stores.toList()..sort(),
              'modes': modes.toList()..sort(),
            };
          })
          .toList(growable: false);
  }
  if (!arguments.contains('--summary') && !arguments.contains('--discover')) {
    final failures = _verifyPolicy(discovered, inventoryDigest);
    report
      ..['result'] = failures.isEmpty ? 'PASS' : 'FAIL'
      ..['failures'] = failures;
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    if (failures.isNotEmpty) exitCode = 1;
    return;
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

void _writePolicyTemplate(
  List<Map<String, Object?>> operations,
  String inventoryDigest,
) {
  final byPath = <String, List<Map<String, Object?>>>{};
  for (final operation in operations) {
    byPath.putIfAbsent(operation['path']! as String, () => []).add(operation);
  }
  final surfaces = byPath.entries
      .map((entry) {
        final stores = <String>{};
        final modes = <String>{};
        for (final operation in entry.value) {
          stores.addAll((operation['stores']! as List).cast<String>());
          modes.addAll((operation['modes']! as List).cast<String>());
        }
        return <String, Object?>{
          'path': entry.key,
          'profile': _profileFor(entry.key, modes),
          'allowedStores': stores.toList()..sort(),
          'allowedModes': modes.toList()..sort(),
          'regressionTests': <String>[
            'test/a03_persistence_boundary_contract_test.dart',
          ],
        };
      })
      .toList(growable: false);
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'findingId': 'A-03',
    'title': 'Operation-level persistence boundary inventory',
    'inventoryDigest': inventoryDigest,
    'decision':
        'Presentation owns no direct persistence. Every discovered operation is classified by an exact surface, authority profile, store, access mode, offline behavior, and transaction owner.',
    'profiles': <String, Object?>{
      'composition-root': <String, Object?>{
        'layer': 'composition-root',
        'authorityBoundary':
            'Startup opens the governed local store before user-facing providers run; it grants no application role.',
        'offlineSemantics':
            'Owns database lifecycle only and does not read or mutate business records.',
        'transactionOwnership':
            'No business transaction is admitted at the composition root.',
      },
      'service': <String, Object?>{
        'layer': 'service',
        'authorityBoundary':
            'The service validates caller or workflow admission before privileged reads and mutations, while Firestore Rules remain final remote authority.',
        'offlineSemantics':
            'Coordinates explicit local, remote, or cross-source behavior and surfaces failures without treating partial work as success.',
        'transactionOwnership':
            'The service owns orchestration; atomic store mutations remain explicit in the inventoried operation.',
      },
      'repository': <String, Object?>{
        'layer': 'repository',
        'authorityBoundary':
            'The repository consumes admitted calls; Firestore Rules enforce remote access and local callers must not infer authority from stored payloads.',
        'offlineSemantics':
            'Owns the declared store boundary and exposes typed outcomes to callers.',
        'transactionOwnership':
            'Repository methods own their declared reads, batches, and transactions.',
      },
      'repository-adapter': <String, Object?>{
        'layer': 'repository-adapter',
        'authorityBoundary':
            'The adapter consumes admitted repository calls; remote Rules remain final authority and local data never grants roles.',
        'offlineSemantics':
            'Local adapters preserve dirty-state and replay semantics; remote adapters preserve server truth and strict decoding.',
        'transactionOwnership':
            'The adapter alone owns its declared local or remote transaction primitives.',
      },
      'read-provider': <String, Object?>{
        'layer': 'read-provider',
        'authorityBoundary':
            'The provider exposes a bounded read stream after feature admission; Firestore Rules remain final remote authority.',
        'offlineSemantics':
            'Read-only projection failures remain visible as loading or error state and never mutate durable data.',
        'transactionOwnership': 'No mutation or transaction is admitted.',
      },
      'auth-provider': <String, Object?>{
        'layer': 'authentication-provider',
        'authorityBoundary':
            'Firebase identity establishes the subject; approval and roles are read from the governed user document and are never self-asserted.',
        'offlineSemantics':
            'Authentication/profile failures deny application admission instead of using stale role data.',
        'transactionOwnership':
            'Only authentication bootstrap/profile registration writes are admitted; no business transaction is owned.',
      },
      'diagnostic-read-adapter': <String, Object?>{
        'layer': 'diagnostic-read-adapter',
        'authorityBoundary':
            'The presentation verifies Admin/SI authority before constructing this privacy-safe local read adapter.',
        'offlineSemantics':
            'Reads local counts and provenance only; it does not sync, reset, delete, or mark records clean.',
        'transactionOwnership': 'No mutation or transaction is admitted.',
      },
    },
    'surfaces': surfaces,
  };
  _manifestFile.parent.createSync(recursive: true);
  _manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
}

String _profileFor(String path, Set<String> modes) {
  if (path == 'lib/main.dart') return 'composition-root';
  if (path.endsWith('local_diagnostics_read_adapter.dart')) {
    return 'diagnostic-read-adapter';
  }
  if (path.endsWith('auth_provider.dart')) return 'auth-provider';
  if (path.contains('/services/')) return 'service';
  if (path.contains('/repositories/') ||
      path.contains('/domain/') && path.endsWith('_repository.dart')) {
    return 'repository';
  }
  if (path.endsWith('.local.dart') || path.endsWith('.remote.dart')) {
    return 'repository-adapter';
  }
  if (path.contains('/providers/')) {
    return modes.contains('mutating') ? 'repository-adapter' : 'read-provider';
  }
  return 'repository';
}

List<String> _verifyPolicy(
  List<Map<String, Object?>> operations,
  String inventoryDigest,
) {
  final failures = <String>[];
  if (!_manifestFile.existsSync()) return <String>['A-03 manifest is missing.'];
  final manifest = jsonDecode(_manifestFile.readAsStringSync());
  if (manifest is! Map<String, dynamic> ||
      manifest['schemaVersion'] != 1 ||
      manifest['findingId'] != 'A-03') {
    return <String>['A-03 manifest identity is invalid.'];
  }
  if (manifest['inventoryDigest'] != inventoryDigest) {
    failures.add(
      'operation inventory drift: expected ${manifest['inventoryDigest']} actual $inventoryDigest',
    );
  }
  final profiles = manifest['profiles'];
  final rawSurfaces = manifest['surfaces'];
  if (profiles is! Map<String, dynamic> || rawSurfaces is! List) {
    return <String>[...failures, 'A-03 profiles and surfaces are required.'];
  }

  final discoveredByPath = <String, List<Map<String, Object?>>>{};
  for (final operation in operations) {
    final path = operation['path']! as String;
    discoveredByPath.putIfAbsent(path, () => []).add(operation);
    if (path.contains('/presentation/') || path.contains('/widgets/')) {
      failures.add('$path: presentation/widget persistence is prohibited');
    }
  }
  final declared = <String, Map<String, dynamic>>{};
  for (final raw in rawSurfaces) {
    if (raw is! Map) {
      failures.add('every A-03 surface must be an object');
      continue;
    }
    final surface = Map<String, dynamic>.from(raw);
    final path = surface['path'];
    if (path is! String || path.isEmpty || declared.containsKey(path)) {
      failures.add('A-03 surface paths must be non-empty and unique: $path');
      continue;
    }
    declared[path] = surface;
    final profileName = surface['profile'];
    final profile = profiles[profileName];
    if (profileName is! String || profile is! Map) {
      failures.add('$path: unknown profile $profileName');
      continue;
    }
    for (final field in <String>[
      'layer',
      'authorityBoundary',
      'offlineSemantics',
      'transactionOwnership',
    ]) {
      final value = profile[field];
      if (value is! String || value.trim().isEmpty) {
        failures.add('$path: profile $profileName is missing $field');
      }
    }
    final actual = discoveredByPath[path];
    if (actual == null) {
      failures.add('$path: stale classified surface');
      continue;
    }
    final stores = <String>{};
    final modes = <String>{};
    for (final operation in actual) {
      stores.addAll((operation['stores']! as List).cast<String>());
      modes.addAll((operation['modes']! as List).cast<String>());
    }
    if (!_sameStrings(surface['allowedStores'], stores) ||
        !_sameStrings(surface['allowedModes'], modes)) {
      failures.add('$path: declared store/access modes drifted');
    }
    if (modes.contains('mutating') &&
        !<String>{
          'service',
          'repository',
          'repository-adapter',
          'auth-provider',
        }.contains(profileName)) {
      failures.add('$path: mutation is not repository/service owned');
    }
    if (stores.length > 1 &&
        !<String>{'service', 'repository'}.contains(profileName)) {
      failures.add(
        '$path: cross-source access is not repository/service owned',
      );
    }
    if (profileName == 'diagnostic-read-adapter' &&
        (stores.difference(<String>{'isar'}).isNotEmpty ||
            modes.difference(<String>{'read'}).isNotEmpty)) {
      failures.add('$path: diagnostic adapter must remain Isar read-only');
    }
    final tests = surface['regressionTests'];
    if (tests is! List || tests.isEmpty) {
      failures.add('$path: regression tests are required');
    } else {
      for (final test in tests) {
        if (test is! String ||
            !File(
              '${_root.path}${Platform.pathSeparator}${test.replaceAll('/', Platform.pathSeparator)}',
            ).existsSync()) {
          failures.add('$path: missing regression test $test');
        }
      }
    }
  }
  final unclassified = discoveredByPath.keys.toSet().difference(
    declared.keys.toSet(),
  );
  if (unclassified.isNotEmpty) {
    failures.add(
      'unclassified persistence surfaces: ${unclassified.toList()..sort()}',
    );
  }
  return failures;
}

bool _sameStrings(Object? raw, Set<String> actual) {
  if (raw is! List) return false;
  return raw.whereType<String>().toSet().containsAll(actual) &&
      actual.containsAll(raw.whereType<String>());
}

String _gitHead() {
  final result = Process.runSync('git', <String>['rev-parse', 'HEAD']);
  return result.exitCode == 0 ? (result.stdout as String).trim() : 'UNKNOWN';
}

String _relative(String path) => path
    .substring(_root.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');

_KnownHandles _discoverHandles(CompilationUnit unit) {
  final collector = _HandleCollector();
  unit.accept(collector);
  final firestore = <String>{};
  final isar = <String>{'isar', '_isar', 'localIsar'};

  for (final declaration in collector.variables) {
    if (_isFirestoreType(declaration.type)) firestore.add(declaration.name);
    if (_isIsarType(declaration.type)) isar.add(declaration.name);
  }
  for (final declaration in collector.parameters) {
    if (_isFirestoreType(declaration.type)) firestore.add(declaration.name);
    if (_isIsarType(declaration.type)) isar.add(declaration.name);
  }
  for (final declaration in collector.getters) {
    if (_isFirestoreType(declaration.type)) firestore.add(declaration.name);
    if (_isIsarType(declaration.type)) isar.add(declaration.name);
  }

  var changed = true;
  while (changed) {
    changed = false;
    for (final declaration in collector.variables) {
      final initializer = declaration.initializer;
      if (initializer == null) continue;
      if (!firestore.contains(declaration.name) &&
          (initializer.contains('FirebaseFirestore.instance') ||
              _startsWithHandle(initializer, firestore))) {
        changed = firestore.add(declaration.name) || changed;
      }
      if (!isar.contains(declaration.name) &&
          (initializer.contains('Isar.getInstance(') ||
              initializer.contains('Isar.open(') ||
              _startsWithHandle(initializer, isar))) {
        changed = isar.add(declaration.name) || changed;
      }
    }
  }
  return _KnownHandles(firestore: firestore, isar: isar);
}

bool _isFirestoreType(String? type) =>
    type != null &&
    RegExp(
      r'\b(?:FirebaseFirestore|CollectionReference|DocumentReference|Query|WriteBatch|Transaction)\b',
    ).hasMatch(type);

bool _isIsarType(String? type) =>
    type != null &&
    RegExp(r'\b(?:Isar|IsarCollection|QueryBuilder)\b').hasMatch(type);

bool _containsHandle(String source, Set<String> handles) => handles.any(
  (handle) => RegExp(
    '(^|[^A-Za-z0-9_])${RegExp.escape(handle)}([^A-Za-z0-9_]|\$)',
  ).hasMatch(source),
);

bool _startsWithHandle(String source, Set<String> handles) {
  final normalized = source.trimLeft().replaceFirst(RegExp(r'^await\s+'), '');
  return handles.any(
    (handle) =>
        RegExp('^${RegExp.escape(handle)}(?:[.?(]|\$)').hasMatch(normalized),
  );
}

final class _PersistenceVisitor extends RecursiveAstVisitor<void> {
  _PersistenceVisitor({
    required this.relativePath,
    required this.source,
    required this.lineInfo,
    required this.firestoreHandles,
    required this.isarHandles,
  });

  final String relativePath;
  final String source;
  final LineInfo lineInfo;
  final Set<String> firestoreHandles;
  final Set<String> isarHandles;
  final Map<String, _OperationAccumulator> _operations = {};

  List<Map<String, Object?>> get operations => _operations.values
      .where((operation) => operation.stores.isNotEmpty)
      .map((operation) => operation.toJson())
      .toList(growable: false);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? '';
    final method = node.methodName.name;
    final invocation = node.toSource();
    final store = _storeForInvocation(target, method, invocation);
    if (store != null) {
      final mode = _modeForInvocation(store, method, invocation);
      _record(node, store, mode, '$method()');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target?.toSource() ?? '';
    final property = node.propertyName.name;
    if (_containsHandle(target, isarHandles) &&
        _looksLikeIsarCollection(property)) {
      _record(node, 'isar', 'read', property);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    final identifier = node.identifier.name;
    if (_containsHandle(prefix, isarHandles) &&
        _looksLikeIsarCollection(identifier)) {
      _record(node, 'isar', 'read', identifier);
    }
    super.visitPrefixedIdentifier(node);
  }

  String? _storeForInvocation(String target, String method, String source) {
    if (method == 'writeTxn' ||
        ((method == 'getInstance' || method == 'open') &&
            RegExp(r'(^|\.)Isar$').hasMatch(target))) {
      return 'isar';
    }
    if (_containsHandle(target, isarHandles) &&
        (method == 'collection' ||
            const <String>{
              'where',
              'filter',
              'get',
              'getAll',
              'findAll',
              'findFirst',
              'count',
              'watch',
              'watchLazy',
              'and',
              'or',
              'put',
              'putAll',
              'delete',
              'deleteAll',
              'clear',
            }.contains(method))) {
      return 'isar';
    }
    if (source.contains('FirebaseFirestore.instance') ||
        target.contains('FirebaseFirestore.instance') ||
        (_containsHandle(target, firestoreHandles) &&
            const <String>{
              'collection',
              'collectionGroup',
              'runTransaction',
              'batch',
            }.contains(method))) {
      return 'firestore';
    }
    if (_containsHandle(target, firestoreHandles) &&
        const <String>{
          'get',
          'snapshots',
          'set',
          'update',
          'delete',
          'add',
        }.contains(method)) {
      return 'firestore';
    }
    return null;
  }

  String _modeForInvocation(String store, String method, String source) {
    if (store == 'isar') {
      if (method == 'writeTxn' ||
          RegExp(
            r'\.(?:put|putAll|delete|deleteAll|clear)\s*\(',
          ).hasMatch(source)) {
        return 'mutating';
      }
      return method == 'open' ? 'lifecycle' : 'read';
    }
    if (const <String>{
      'runTransaction',
      'batch',
      'set',
      'update',
      'delete',
      'add',
    }.contains(method)) {
      return 'mutating';
    }
    return 'read';
  }

  bool _looksLikeIsarCollection(String name) {
    if (const <String>{
      'schemas',
      'directory',
      'name',
      'isOpen',
    }.contains(name)) {
      return false;
    }
    return name.endsWith('s') ||
        name.endsWith('Records') ||
        name.endsWith('Entrys');
  }

  void _record(AstNode node, String store, String mode, String primitive) {
    final owner = _ownerFor(node);
    final key = '$relativePath::$owner';
    final operation = _operations.putIfAbsent(
      key,
      () => _OperationAccumulator(
        path: relativePath,
        operation: owner,
        line: lineInfo.getLocation(node.offset).lineNumber,
      ),
    );
    operation
      ..stores.add(store)
      ..modes.add(mode)
      ..primitives.add(primitive);
    operation.siteCount++;
  }

  String _ownerFor(AstNode node) {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null) {
      final typeName = _enclosingTypeName(method) ?? '<type>';
      return '$typeName.${method.name.lexeme}';
    }
    final constructor = node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (constructor != null) {
      final type = constructor.thisOrAncestorOfType<ClassDeclaration>();
      final suffix = constructor.name?.lexeme;
      return '${type?.name.lexeme ?? '<type>'}.${suffix ?? '<constructor>'}';
    }
    final function = node.thisOrAncestorOfType<FunctionDeclaration>();
    if (function != null) return function.name.lexeme;
    final variable = node.thisOrAncestorOfType<VariableDeclaration>();
    if (variable != null) {
      final enclosingTypeName = _enclosingTypeName(variable);
      final typeName = enclosingTypeName == null ? '' : '$enclosingTypeName.';
      return '$typeName${variable.name.lexeme}';
    }
    return '<top-level>';
  }

  String? _enclosingTypeName(AstNode node) {
    final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration != null) return classDeclaration.name.lexeme;
    final enumDeclaration = node.thisOrAncestorOfType<EnumDeclaration>();
    if (enumDeclaration != null) return enumDeclaration.name.lexeme;
    final extensionDeclaration =
        node.thisOrAncestorOfType<ExtensionDeclaration>();
    if (extensionDeclaration != null) {
      return extensionDeclaration.name?.lexeme ?? '<extension>';
    }
    final mixinDeclaration = node.thisOrAncestorOfType<MixinDeclaration>();
    if (mixinDeclaration != null) return mixinDeclaration.name.lexeme;
    return null;
  }
}

final class _KnownHandles {
  const _KnownHandles({required this.firestore, required this.isar});

  final Set<String> firestore;
  final Set<String> isar;
}

final class _VariableHandleCandidate {
  const _VariableHandleCandidate({
    required this.name,
    required this.type,
    required this.initializer,
  });

  final String name;
  final String? type;
  final String? initializer;
}

final class _TypedHandleCandidate {
  const _TypedHandleCandidate({required this.name, required this.type});

  final String name;
  final String? type;
}

final class _HandleCollector extends RecursiveAstVisitor<void> {
  final List<_VariableHandleCandidate> variables = [];
  final List<_TypedHandleCandidate> parameters = [];
  final List<_TypedHandleCandidate> getters = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final list = node.parent;
    variables.add(
      _VariableHandleCandidate(
        name: node.name.lexeme,
        type: list is VariableDeclarationList ? list.type?.toSource() : null,
        initializer: node.initializer?.toSource(),
      ),
    );
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final name = node.name?.lexeme;
    if (name != null) {
      parameters.add(
        _TypedHandleCandidate(name: name, type: node.type?.toSource()),
      );
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    parameters.add(
      _TypedHandleCandidate(
        name: node.name.lexeme,
        type: node.type?.toSource(),
      ),
    );
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter) {
      getters.add(
        _TypedHandleCandidate(
          name: node.name.lexeme,
          type: node.returnType?.toSource(),
        ),
      );
    }
    super.visitMethodDeclaration(node);
  }
}

final class _OperationAccumulator {
  _OperationAccumulator({
    required this.path,
    required this.operation,
    required this.line,
  });

  final String path;
  final String operation;
  final int line;
  final Set<String> stores = {};
  final Set<String> modes = {};
  final Set<String> primitives = {};
  int siteCount = 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'operation': operation,
    'line': line,
    'stores': stores.toList()..sort(),
    'modes': modes.toList()..sort(),
    'primitives': primitives.toList()..sort(),
    'siteCount': siteCount,
  };
}
