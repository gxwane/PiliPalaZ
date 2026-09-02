import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'api_result.dart';
import 'http_runtime.dart';

final class HtmlArticleData {
  const HtmlArticleData({
    required this.avatar,
    required this.userName,
    required this.updateTime,
    required this.content,
    required this.commentId,
  });

  final String avatar;
  final String userName;
  final String updateTime;
  final String content;
  final int commentId;
}

class HtmlHttp {
  static Future<ApiResult<HtmlArticleData>> reqHtml(
    String id,
    String dynamicType,
  ) async {
    var response = await HttpRuntime.instance.client.getText(
      'https://www.bilibili.com/opus/$id',
      endpoint: 'article.opus',
      options: Options(
        headers: <String, Object?>{
          HttpHeaders.userAgentHeader: HttpRuntime.instance.headerUa(
            type: 'pc',
          ),
        },
      ),
    );
    if (response case ApiFailure<String> failure) {
      return failure.cast<HtmlArticleData>();
    }

    var html = (response as ApiSuccess<String>).data;
    if (html.contains('Redirecting to')) {
      final match = RegExp(r'//([\w\.]+)/(\w+)/(\w+)').firstMatch(html);
      final redirect = match?.group(0);
      if (redirect != null) {
        response = await HttpRuntime.instance.client.getText(
          'https:$redirect/',
          endpoint: 'article.opusRedirect',
          options: Options(
            headers: <String, Object?>{
              HttpHeaders.userAgentHeader: HttpRuntime.instance.headerUa(
                type: 'pc',
              ),
            },
          ),
        );
        if (response case ApiFailure<String> failure) {
          return failure.cast<HtmlArticleData>();
        }
        html = (response as ApiSuccess<String>).data;
      }
    }

    try {
      final match = RegExp(
        r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\});',
        dotAll: true,
      ).firstMatch(html);
      if (match == null) {
        return const ApiFailure<HtmlArticleData>(
          kind: ApiFailureKind.malformedResponse,
          message: '专栏页面缺少初始化数据',
          endpoint: 'article.opus',
        );
      }
      final decoded = jsonDecode(match.group(1)!);
      if (decoded is! Map) {
        throw const FormatException('Initial state is not an object');
      }
      final state = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final detailValue = state['detail'] ?? state['fallback'];
      if (detailValue is! Map) {
        throw const FormatException('Missing article detail');
      }
      final detail = detailValue.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      var avatar = '';
      var userName = '';
      var updateTime = '';
      var content = '';
      final modules = detail['modules'];
      if (modules is List) {
        for (final moduleValue in modules) {
          if (moduleValue is! Map) {
            continue;
          }
          final module = moduleValue;
          if (module['module_type'] == 'MODULE_TYPE_AUTHOR') {
            final author = module['module_author'];
            if (author is Map) {
              avatar = author['face'] as String? ?? '';
              userName = author['name'] as String? ?? '';
              updateTime = author['pub_time'] as String? ?? '';
            }
          } else if (module['module_type'] == 'MODULE_TYPE_CONTENT') {
            content += _contentFromModule(module['module_content']);
          } else if (module['module_type'] == 'MODULE_TYPE_DYNAMIC') {
            final dynamicModule = module['module_dynamic'];
            final description = dynamicModule is Map
                ? dynamicModule['desc']
                : null;
            if (description is Map && description['text'] is String) {
              content += description['text'] as String;
            }
          }
        }
      } else {
        final author = detail['module_author'];
        if (author is Map) {
          avatar = author['face'] as String? ?? '';
          userName = author['name'] as String? ?? '';
          updateTime = author['pub_time'] as String? ?? '';
        }
        final dynamicModule = detail['module_dynamic'];
        final description = dynamicModule is Map ? dynamicModule['desc'] : null;
        final major = dynamicModule is Map ? dynamicModule['major'] : null;
        content = description is Map
            ? description['text'] as String? ?? ''
            : '';
        content = _legacyCoverAndSummary(major, content);
      }

      if (avatar.isNotEmpty) {
        avatar = avatar.replaceFirst('http:', 'https:');
      }
      final basic = detail['basic'];
      final commentIdValue = basic is Map ? basic['comment_id_str'] : null;
      final commentId = int.tryParse(commentIdValue?.toString() ?? id);
      if (commentId == null) {
        throw const FormatException('Invalid comment id');
      }
      return ApiSuccess<HtmlArticleData>(
        HtmlArticleData(
          avatar: avatar,
          userName: userName,
          updateTime: updateTime,
          content: content,
          commentId: commentId,
        ),
      );
    } catch (_) {
      return const ApiFailure<HtmlArticleData>(
        kind: ApiFailureKind.decoding,
        message: '专栏内容无法解析',
        endpoint: 'article.opus',
      );
    }
  }

  static Future<ApiResult<HtmlArticleData>> reqReadHtml(
    String id,
    String dynamicType,
  ) async {
    final response = await HttpRuntime.instance.client.getText(
      'https://www.bilibili.com/$dynamicType/$id/',
      endpoint: 'article.read',
      options: Options(
        headers: const <String, Object?>{
          HttpHeaders.userAgentHeader: 'Mozilla/5.0',
          HttpHeaders.refererHeader: 'https://www.bilibili.com/',
          HttpHeaders.cookieHeader: 'opus-goback=1',
        },
      ),
    );
    if (response case ApiFailure<String> failure) {
      return failure.cast<HtmlArticleData>();
    }
    final html = (response as ApiSuccess<String>).data;
    try {
      final Document document = parse(html);
      final app = document.body?.querySelector('#app');
      final author = app?.querySelector('.up-left');
      final article = app?.querySelector('.article-content');
      if (author == null || article == null) {
        throw const FormatException('Missing article elements');
      }
      final avatarMatch = RegExp(
        r'"author":\{"mid":\d+?,"name":".+?","face":"(.+?)"',
      ).firstMatch(html);
      final rawAvatar = avatarMatch?.group(1);
      if (rawAvatar == null) {
        throw const FormatException('Missing author avatar');
      }
      final avatar = rawAvatar.replaceAll(r'\u002F', '/').split('@').first;
      final content =
          article.querySelector('#read-article-holder')?.innerHtml ?? '';
      if (content.isEmpty) {
        final opusId = RegExp(
          r'"dyn_id_str":"(\d+)"',
        ).firstMatch(html)?.group(1);
        if (opusId == null || opusId == id) {
          return const ApiFailure<HtmlArticleData>(
            kind: ApiFailureKind.malformedResponse,
            message: '专栏正文为空',
            endpoint: 'article.read',
          );
        }
        return reqHtml(opusId, 'opus');
      }
      final number = RegExp(r'\d+').firstMatch(id)?.group(0);
      if (number == null) {
        throw const FormatException('Invalid article id');
      }
      return ApiSuccess<HtmlArticleData>(
        HtmlArticleData(
          avatar: avatar,
          userName: author.querySelector('.up-name')?.text.trim() ?? '',
          updateTime: '',
          content: content,
          commentId: int.parse(number),
        ),
      );
    } catch (_) {
      return const ApiFailure<HtmlArticleData>(
        kind: ApiFailureKind.decoding,
        message: '专栏页面无法解析',
        endpoint: 'article.read',
      );
    }
  }

  static String _contentFromModule(Object? value) {
    if (value is! Map || value['paragraphs'] is! List) {
      return '';
    }
    final buffer = StringBuffer();
    for (final paragraphValue in value['paragraphs'] as List) {
      if (paragraphValue is! Map) {
        continue;
      }
      if (paragraphValue['para_type'] == 1) {
        final text = paragraphValue['text'];
        final nodes = text is Map ? text['nodes'] : null;
        if (nodes is List) {
          for (final nodeValue in nodes) {
            if (nodeValue is Map &&
                nodeValue['type'] == 'TEXT_NODE_TYPE_WORD') {
              final word = nodeValue['word'];
              if (word is Map && word['words'] is String) {
                buffer.write(word['words']);
              }
            }
          }
          buffer.write('<br/>');
        }
      } else if (paragraphValue['para_type'] == 2) {
        final picture = paragraphValue['pic'];
        final pictures = picture is Map ? picture['pics'] : null;
        if (pictures is List) {
          for (final pictureValue in pictures) {
            if (pictureValue is Map && pictureValue['url'] is String) {
              buffer.write('<img src="${pictureValue['url']}"><br/>');
            }
          }
        }
      }
    }
    return buffer.toString();
  }

  static String _legacyCoverAndSummary(Object? majorValue, String content) {
    if (majorValue is! Map) {
      return content;
    }
    final opus = majorValue['opus'];
    final article = majorValue['article'];
    var cover = '';
    if (opus is Map) {
      final summary = opus['summary'];
      if (content.isEmpty && summary is Map && summary['text'] is String) {
        content = summary['text'] as String;
      }
      final pictures = opus['pics'];
      if (pictures is List && pictures.isNotEmpty && pictures.first is Map) {
        cover = (pictures.first as Map)['url'] as String? ?? '';
      }
    } else if (article is Map) {
      if (content.isEmpty && article['desc'] is String) {
        content = article['desc'] as String;
      }
      final covers = article['covers'];
      if (covers is List && covers.isNotEmpty && covers.first is String) {
        cover = covers.first as String;
      }
    }
    return cover.isEmpty ? content : '<img src="$cover">$content';
  }
}
