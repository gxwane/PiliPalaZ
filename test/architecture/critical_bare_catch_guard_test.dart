import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class BareCatchViolation {
  final String filePath;
  final int lineNumber;
  final String contextName;

  BareCatchViolation({
    required this.filePath,
    required this.lineNumber,
    required this.contextName,
  });

  @override
  String toString() =>
      '$filePath:$lineNumber: Bare catch block in "$contextName" (missing "on <ExceptionType>" clause)';
}

class BareCatchVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final CompilationUnit unit;
  final List<BareCatchViolation> violations = [];
  final List<String> _enclosingStack = [];

  BareCatchVisitor(this.filePath, this.unit);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _enclosingStack.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
    _enclosingStack.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _enclosingStack.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
    _enclosingStack.removeLast();
  }

  @override
  void visitCatchClause(CatchClause node) {
    // If exceptionType is null, it's a bare catch (e) or catch (_)
    if (node.exceptionType == null) {
      final line = unit.lineInfo.getLocation(node.offset).lineNumber;
      violations.add(
        BareCatchViolation(
          filePath: filePath,
          lineNumber: line,
          contextName: _enclosingStack.isNotEmpty
              ? _enclosingStack.last
              : '<anonymous>',
        ),
      );
    }
    super.visitCatchClause(node);
  }
}

void main() {
  group('Architecture Guard - Critical Bare Catch', () {
    test('generatePlaybackSnapshot has zero bare catch blocks', () {
      final file = File(p.join('lib', 'pages', 'video', 'controller.dart'));
      final result = parseFile(
        path: p.normalize(file.absolute.path),
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      final visitor = BareCatchVisitor(file.path, result.unit);
      result.unit.accept(visitor);

      final snapshotViolations = visitor.violations
          .where((v) => v.contextName == 'generatePlaybackSnapshot')
          .toList();

      expect(
        snapshotViolations,
        isEmpty,
        reason:
            'generatePlaybackSnapshot must never use bare catch (e) or catch (_). '
            'Always use "on Exception catch" or specific exception types to prevent swallowing fatal Errors.',
      );
    });

    test('Diagnostics models have zero bare catch blocks', () {
      final file = File(
        p.join('lib', 'models', 'diagnostics', 'playback_snapshot.dart'),
      );
      final result = parseFile(
        path: p.normalize(file.absolute.path),
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      final visitor = BareCatchVisitor(file.path, result.unit);
      result.unit.accept(visitor);

      expect(
        visitor.violations,
        isEmpty,
        reason:
            'Diagnostics models must not swallow fatal Errors with bare catch.',
      );
    });
  });
}
