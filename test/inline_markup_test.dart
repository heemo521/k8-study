import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/content/inline_markup.dart';

void main() {
  test('parses code and bold spans', () {
    expect(parseInline('Run `kubectl get pods` **now**.'), const [
      InlineSpan('Run ', InlineStyle.plain),
      InlineSpan('kubectl get pods', InlineStyle.code),
      InlineSpan(' ', InlineStyle.plain),
      InlineSpan('now', InlineStyle.bold),
      InlineSpan('.', InlineStyle.plain),
    ]);
  });

  test('unterminated markers render literally', () {
    expect(parseInline('a `b'), const [InlineSpan('a `b', InlineStyle.plain)]);
    expect(parseInline('**x'), const [InlineSpan('**x', InlineStyle.plain)]);
  });

  test('markup inside code is not parsed', () {
    expect(parseInline('`**x**`'), const [
      InlineSpan('**x**', InlineStyle.code),
    ]);
  });

  test('other characters are literal', () {
    expect(parseInline('<name> _x_ # y'), const [
      InlineSpan('<name> _x_ # y', InlineStyle.plain),
    ]);
  });
}
