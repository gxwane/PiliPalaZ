String buildHtmlRenderFixture(int minimumLength) {
  const sections = <String>[
    '<h1>动态标题与中文排版</h1>',
    '<p>这是一段用于验证 HTML 渲染稳定性的正文，包含 <strong>粗体</strong>、'
        '<em>强调</em>、<a href="https://example.com/notes">链接</a>和换行。</p>',
    '<blockquote>引用内容应保持可读，并且不会阻塞页面滚动。</blockquote>',
    '<ul><li>第一项列表内容</li><li>第二项列表内容</li></ul>',
    '<table><tr><th>项目</th><th>结果</th></tr>'
        '<tr><td>兼容性</td><td>通过</td></tr></table>',
    '<p>包含不完整标记以覆盖容错路径：<span>仍然可见',
  ];

  final buffer = StringBuffer();
  var index = 0;
  while (buffer.length < minimumLength) {
    buffer
      ..write('<section data-index="$index">')
      ..write(sections[index % sections.length])
      ..write('<p>第 $index 段：PiliPalaZ HTML renderer benchmark。</p>')
      ..write('</section>');
    index++;
  }
  return buffer.toString();
}
