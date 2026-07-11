import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/practice/answer_matching.dart';

void main() {
  group('isAnswerCorrect', () {
    test('exact match after normalization', () {
      expect(isAnswerCorrect('A Mutual-Exclusion Lock.',
          'a mutual exclusion lock'), isTrue);
    });

    test('tolerates a small typo', () {
      expect(isAnswerCorrect('mutuel exclusion lock', 'mutual exclusion lock'),
          isTrue);
    });

    test('accepts a keyword contained in the expected answer', () {
      expect(isAnswerCorrect('mutex', 'a mutex lock'), isTrue);
    });

    test('rejects an unrelated answer', () {
      expect(isAnswerCorrect('a database index', 'a mutual exclusion lock'),
          isFalse);
    });

    test('rejects empty input', () {
      expect(isAnswerCorrect('   ', 'anything'), isFalse);
    });
  });

  group('similarity', () {
    test('identical strings score 1', () {
      expect(similarity('abc', 'abc'), 1);
    });

    test('completely different strings score low', () {
      expect(similarity('abc', 'xyz'), lessThan(0.5));
    });
  });
}
