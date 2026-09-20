import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

class FieldShadowingViolation {
  final String filePath;
  final int lineNumber;
  final String className;
  final String fieldName;

  FieldShadowingViolation({
    required this.filePath,
    required this.lineNumber,
    required this.className,
    required this.fieldName,
  });

  @override
  String toString() =>
      '$filePath:$lineNumber: Local variable "$fieldName" shadows instance field in "$className"';
}

class FieldShadowingVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final CompilationUnit unit;
  final List<FieldShadowingViolation> violations = [];
  final List<Set<String>> _fieldStack = [];
  final List<String> _classNameStack = [];
  final List<bool> _staticMemberStack = [];

  FieldShadowingVisitor(this.filePath, this.unit);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _staticMemberStack.add(node.isStatic);
    super.visitMethodDeclaration(node);
    _staticMemberStack.removeLast();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _staticMemberStack.add(node.factoryKeyword != null);
    super.visitConstructorDeclaration(node);
    _staticMemberStack.removeLast();
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final fields = <String>{};
    for (final member in node.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        for (final variable in member.fields.variables) {
          fields.add(variable.name.lexeme);
        }
      }
    }
    _fieldStack.add(fields);
    _classNameStack.add(node.name.lexeme);
    super.visitClassDeclaration(node);
    _fieldStack.removeLast();
    _classNameStack.removeLast();
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final fields = <String>{};
    for (final member in node.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        for (final variable in member.fields.variables) {
          fields.add(variable.name.lexeme);
        }
      }
    }
    _fieldStack.add(fields);
    _classNameStack.add(node.name.lexeme);
    super.visitMixinDeclaration(node);
    _fieldStack.removeLast();
    _classNameStack.removeLast();
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_fieldStack.isNotEmpty) {
      if (_staticMemberStack.isNotEmpty && _staticMemberStack.last) {
        super.visitVariableDeclaration(node);
        return;
      }
      final parent = node.parent;
      if (parent is VariableDeclarationList) {
        final grandParent = parent.parent;
        // Exclude field declarations and top-level variable declarations
        if (grandParent is! FieldDeclaration &&
            grandParent is! TopLevelVariableDeclaration) {
          final varName = node.name.lexeme;
          final currentFields = _fieldStack.last;
          if (currentFields.contains(varName)) {
            final lineInfo = unit.lineInfo;
            final line = lineInfo.getLocation(node.offset).lineNumber;
            violations.add(
              FieldShadowingViolation(
                filePath: filePath,
                lineNumber: line,
                className: _classNameStack.last,
                fieldName: varName,
              ),
            );
          }
        }
      }
    }
    super.visitVariableDeclaration(node);
  }
}

void main() {
  group('Architecture Guard - Field Shadowing', () {
    test('Zero local variable shadowing in lib/ classes', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
          .toList();

      final allViolations = <FieldShadowingViolation>[];

      for (final file in dartFiles) {
        try {
          final result = parseFile(
            path: file.absolute.path,
            featureSet: FeatureSet.latestLanguageVersion(),
            throwIfDiagnostics: false,
          );
          final visitor = FieldShadowingVisitor(file.path, result.unit);
          result.unit.accept(visitor);
          allViolations.addAll(visitor.violations);
        } catch (e) {
          fail('Failed to parse ${file.path}: $e');
        }
      }

      if (allViolations.isNotEmpty) {
        final message = StringBuffer()
          ..writeln(
            'Found ${allViolations.length} local variable shadowing violation(s):',
          );
        for (final v in allViolations) {
          message.writeln('  • $v');
        }
        message.writeln(
          '\nDo NOT declare local variables that shadow enclosing class instance fields.',
        );
        message.writeln(
          'Rename local variables to prevent state desynchronization.',
        );
        fail(message.toString());
      }

      expect(allViolations, isEmpty);
    });
  });
}
