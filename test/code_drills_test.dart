import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/practice/code_drills.dart';

void main() {
  const code = '''
int add(int a, int b) {
  final sum = a + b;
  return sum;
}''';

  group('generateCodeDrills', () {
    test('fill-blank template + answers reconstruct the original code', () {
      final drills = generateCodeDrills(code);
      expect(drills.fillBlankAnswers, isNotEmpty);

      // Replacing each «k» placeholder with its answer restores the code.
      var rebuilt = drills.fillBlankTemplate!;
      for (var i = 0; i < drills.fillBlankAnswers.length; i++) {
        rebuilt = rebuilt.replaceAll('«$i»', drills.fillBlankAnswers[i]);
      }
      expect(rebuilt, code);
    });

    test('reorder segments are the non-empty lines in order', () {
      final drills = generateCodeDrills(code);
      expect(drills.reorderSegments.length, greaterThan(1));
      expect(drills.reorderSegments.join('\n'),
          code.split('\n').where((l) => l.trim().isNotEmpty).join('\n'));
    });

    test('trivial code yields no drills', () {
      final drills = generateCodeDrills('x');
      expect(drills.fillBlankAnswers, isEmpty);
      expect(drills.reorderSegments, isEmpty);
    });
  });

  group('codeMatches', () {
    test('ignores extra whitespace and trailing comments', () {
      expect(
        codeMatches('final  sum = a + b;    // add them', 'final sum = a + b;'),
        isTrue,
      );
    });

    test('rejects different logic', () {
      expect(codeMatches('return a - b;', 'return a + b;'), isFalse);
    });

    test('rejects empty submission', () {
      expect(codeMatches('   ', 'return a + b;'), isFalse);
    });
  });
}
