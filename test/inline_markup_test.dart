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

  group('leadInLength', () {
    test('short "Label: " prefix is a lead-in', () {
      expect(leadInLength('CPU: `0.1` = `100m`'), 4);
      expect(leadInLength('`storageClassName`: binds by class'), 19);
    });

    test('colon inside code is not a lead-in', () {
      expect(leadInLength('Use `apiVersion: v2` for charts'), 0);
    });

    test('long prefix, existing bold, or no colon gives none', () {
      expect(
        leadInLength('A sentence that runs on well past forty characters: x'),
        0,
      );
      expect(leadInLength('**Bold** already: x'), 0);
      expect(leadInLength('Plain bullet text'), 0);
      expect(leadInLength('ratio 1:2 here'), 0);
    });
  });
}
