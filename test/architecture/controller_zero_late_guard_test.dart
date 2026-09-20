import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:path/path.dart' as p;

class ControllerLateViolation {
  final String filePath;
  final int lineNumber;
  final String className;
  final String fieldName;

  ControllerLateViolation({
    required this.filePath,
    required this.lineNumber,
    required this.className,
    required this.fieldName,
  });

  String get key => '$className.$fieldName';

  @override
  String toString() =>
      '$filePath:$lineNumber: Dangerous "late" field "$fieldName" in "$className"';
}

class ControllerLateVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final CompilationUnit unit;
  final List<ControllerLateViolation> violations = [];

  ControllerLateVisitor(this.filePath, this.unit);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    final superclassName = extendsClause?.superclass.name2.lexeme ?? '';
    final isController =
        superclassName.contains('Controller') ||
        (node.name.lexeme.endsWith('Controller') &&
            !node.name.lexeme.endsWith('State'));

    if (isController) {
      for (final member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final isLate = member.fields.lateKeyword != null;
          if (isLate) {
            for (final variable in member.fields.variables) {
              if (variable.initializer == null) {
                final line = unit.lineInfo
                    .getLocation(variable.offset)
                    .lineNumber;
                violations.add(
                  ControllerLateViolation(
                    filePath: filePath,
                    lineNumber: line,
                    className: node.name.lexeme,
                    fieldName: variable.name.lexeme,
                  ),
                );
              }
            }
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
}

void main() {
  group('Architecture Guard - Controller Zero Late', () {
    test('VideoDetailController has zero business-state late fields', () {
      final file = File(p.join('lib', 'pages', 'video', 'controller.dart'));
      final result = parseFile(
        path: p.normalize(file.absolute.path),
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
      final visitor = ControllerLateVisitor(file.path, result.unit);
      result.unit.accept(visitor);

      // Only tabCtr (TabBar lifecycle controller) is permitted as late
      final businessLateViolations = visitor.violations
          .where(
            (v) =>
                v.className == 'VideoDetailController' &&
                v.fieldName != 'tabCtr',
          )
          .toList();

      expect(
        businessLateViolations,
        isEmpty,
        reason:
            'VideoDetailController must not contain any late business state. '
            'All state must be nullable or safely initialized.',
      );
    });

    test(
      'Zero new uninitialized late fields in any Controller (Ratchet Baseline)',
      () {
        final libDir = Directory('lib');
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
            )
            .toList();

        final allViolations = <ControllerLateViolation>[];

        for (final file in dartFiles) {
          try {
            final result = parseFile(
              path: p.normalize(file.absolute.path),
              featureSet: FeatureSet.latestLanguageVersion(),
              throwIfDiagnostics: false,
            );
            final visitor = ControllerLateVisitor(file.path, result.unit);
            result.unit.accept(visitor);
            allViolations.addAll(visitor.violations);
          } catch (e) {
            fail('Failed to parse ${file.path}: $e');
          }
        }

        // Legacy baseline set: existing controller fields permitted prior to v1.5.0
        // Any NEW late field in any controller will immediately fail this test.
        const legacyPermittedKeys = <String>{
          'VideoDetailController.tabCtr',
          'BangumiIntroController.playbackQueueController',
          'ColorSelectController.colorThemes',
          'DanmakuBlockController.tabController',
          'DownloadPageController.tabController',
          'DynamicsController.tabController',
          'DynamicsController.tabsPageList',
          'EmotePanelController.emotePackage',
          'EmotePanelController.tabController',
          'FansController.mid',
          'FansController.name',
          'FavDetailController.heroTag',
          'FavSearchController.mediaId',
          'FavSearchController.searchType',
          'FollowController.followTags',
          'FollowController.mid',
          'FollowController.name',
          'FollowController.tabController',
          'HistorySearchController.mid',
          'HomeController.defaultTabs',
          'HomeController.enableGradientBg',
          'HomeController.hideSearchBar',
          'HomeController.sideBarPosition',
          'HomeController.tabController',
          'HomeController.tabbarSort',
          'HomeController.tabsCtrList',
          'HomeController.tabsPageList',
          'HtmlRenderController._sortType',
          'HtmlRenderController.dynamicType',
          'HtmlRenderController.id',
          'HtmlRenderController.response',
          'HtmlRenderController.sortTypeLabel',
          'HtmlRenderController.sortTypeTitle',
          'HtmlRenderController.type',
          'LiveRoomController.heroTag',
          'LiveRoomController.roomId',
          'LoginPageController.tabController',
          'MainController.dynamicBadgeType',
          'MainController.hideTabBar',
          'MainController.pageController',
          'MainController.selectedIndex',
          'MemberController.ownerMid',
          'MemberController.tabController',
          'MemberController.userStat',
          'MemberSearchController.mid',
          'MemberSeasonController.mid',
          'MemberSeasonController.page',
          'MemberSeasonController.seasonId',
          'MemberSeasonsAndSeriesController.page',
          'MemberSeriesController.mid',
          'MemberSeriesController.seriesId',
          'PlPlayerController.blockTypes',
          'PlPlayerController.danmakuDurationVal',
          'PlPlayerController.dataSource',
          'PlPlayerController.enableAutoLongPressSpeed',
          'PlPlayerController.enableLongPressSpeedIncrease',
          'PlPlayerController.enableLongShowControl',
          'PlPlayerController.fontSizeVal',
          'PlPlayerController.fontWeight',
          'PlPlayerController.horizontalScreen',
          'PlPlayerController.massiveMode',
          'PlPlayerController.opacityVal',
          'PlPlayerController.showArea',
          'PlPlayerController.speedsList',
          'PlPlayerController.strokeWidth',
          'PlPlayerController.subtitleStyle',
          'RankController.enableGradientBg',
          'RankController.tabController',
          'RankController.tabsCtrList',
          'RankController.tabsPageList',
          'RcmdController.enableSaveLastData',
          'SubDetailController.heroTag',
          'SubDetailController.id',
          'SubDetailController.item',
          'VideoIntroController.bvid',
          'VideoIntroController.playbackQueueController',
          'WhisperDetailController.face',
          'WhisperDetailController.mid',
          'WhisperDetailController.name',
          'WhisperDetailController.talkerId',
        };

        final newViolations = allViolations
            .where((v) => !legacyPermittedKeys.contains(v.key))
            .toList();

        if (newViolations.isNotEmpty) {
          final message = StringBuffer()
            ..writeln(
              'Found ${newViolations.length} NEW uninitialized "late" field violation(s) in Controllers:',
            )
            ..writeln(
              '------------------------------------------------------------',
            );
          for (final v in newViolations) {
            message.writeln('  • $v');
          }
          message
            ..writeln(
              '------------------------------------------------------------',
            )
            ..writeln(
              'Do NOT declare uninitialized "late" fields in Controllers.',
            )
            ..writeln(
              'Async controller state must be nullable or initialized with a safe default value.',
            );
          fail(message.toString());
        }

        expect(newViolations, isEmpty);
      },
    );
  });
}
