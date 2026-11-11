import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xavier_billiard_libre/models/billiard_specs.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/ball_contact_diagram.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/cue_ball_effet_diagram.dart';

void main() {
  group('I. Kiểm thử Hình học & Phân số phần tám (BallContactSpec)', () {
    test('1. 7 nấc rời rạc k=1..7 và góc cắt lí tưởng AimGeometry (4/8 cho đúng 30°, 8/8 cho 0°)', () {
      final kExpected = [
        (1, 0.125, '1/8 trái'),
        (2, 0.250, '2/8 (1/4) trái'),
        (3, 0.375, '3/8 trái'),
        (4, 0.500, '4/8 (1/2) trái'),
        (5, 0.625, '5/8 trái'),
        (6, 0.750, '6/8 (3/4) trái'),
        (7, 0.875, '7/8 trái'),
      ];

      for (final (k, frac, label) in kExpected) {
        final spec = BallContactSpec.eighths(k);
        expect(spec.fraction, closeTo(frac, 1e-9));
        expect(spec.eighthsStep, equals(k));
        expect(spec.label, equals(label));
      }

      // Kiểm tra góc cắt lí tưởng AimGeometry theta = arcsin(1 - f):
      // - Tại k=4 (f = 0.5): theta = arcsin(0.5) = 30°
      final halfSpec = BallContactSpec.eighths(4);
      expect(halfSpec.cutAngleDegrees, closeTo(30.0, 1e-4));

      // - Tại k=8 (Tràn mặt): theta = arcsin(0) = 0°
      final fullSpec = BallContactSpec.full();
      expect(fullSpec.cutAngleDegrees, closeTo(0.0, 1e-4));
      expect(fullSpec.fraction, equals(1.0));
      expect(fullSpec.side, equals(ContactSide.center));
      expect(fullSpec.eighthsStep, equals(8));
    });

    test('2. Bảo toàn bài học cũ (1/3 và 2/3): không bị làm tròn khi đọc, nhận diện đúng legacy', () {
      final oneThird = BallContactSpec.oneThird();
      expect(oneThird.fraction, closeTo(1.0 / 3.0, 1e-9));
      expect(oneThird.eighthsStep, isNull, reason: '1/3 không nằm trên lưới phần tám');
      expect(oneThird.label, equals('1/3 trái'));

      final twoThirds = BallContactSpec.twoThirds();
      expect(twoThirds.fraction, closeTo(2.0 / 3.0, 1e-9));
      expect(twoThirds.eighthsStep, isNull, reason: '2/3 không nằm trên lưới phần tám');
      expect(twoThirds.label, equals('2/3 trái'));
    });
  });

  group('II. Kiểm thử Widget Thanh trượt 8 phần (BallContactDiagram / Slider)', () {
    testWidgets('3. Slider 7 nấc, nút [-]/[+], đổi má giữ độ dày, đổi độ dày giữ má', (tester) async {
      BallContactSpec currentSpec = BallContactSpec.eighths(4, side: ContactSide.right);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BallContactDiagram(
                  spec: currentSpec,
                  mode: DiagramDisplayMode.interactive,
                  onSpecChanged: (newSpec) {
                    setState(() {
                      currentSpec = newSpec;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Ban đầu: Chạm 4/8 (1/2) • Má phải
      expect(find.textContaining('4/8 (1/2)'), findsWidgets);
      expect(find.textContaining('Má phải'), findsWidgets);
      expect(find.textContaining('30.0°'), findsWidgets);

      // Bấm nút [+] để tăng lên 5/8
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(currentSpec.eighthsStep, equals(5));
      expect(currentSpec.fraction, closeTo(0.625, 1e-9));
      expect(currentSpec.side, equals(ContactSide.right), reason: 'Đổi độ dày phải giữ nguyên má');
      expect(find.textContaining('5/8'), findsWidgets);

      // Bấm nút [-] để lùi về 4/8
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(currentSpec.eighthsStep, equals(4));
      expect(currentSpec.side, equals(ContactSide.right));

      // Đổi má sang Má Trái qua SegmentedButton
      await tester.tap(find.text('Má Trái'));
      await tester.pumpAndSettle();

      expect(currentSpec.side, equals(ContactSide.left));
      expect(currentSpec.eighthsStep, equals(4), reason: 'Đổi má phải giữ nguyên độ dày');
      expect(currentSpec.fraction, closeTo(0.50, 1e-9));
    });

    testWidgets('4. Nút Tràn mặt 8/8 và khôi phục chính xác độ dày và má trước đó', (tester) async {
      // Bắt đầu với 3/8 Má Trái
      BallContactSpec currentSpec = BallContactSpec.eighths(3, side: ContactSide.left);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BallContactDiagram(
                  spec: currentSpec,
                  mode: DiagramDisplayMode.interactive,
                  onSpecChanged: (newSpec) {
                    setState(() {
                      currentSpec = newSpec;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('3/8'), findsWidgets);
      expect(find.textContaining('Má trái'), findsWidgets);

      // Bấm nút Tràn mặt 8/8
      await tester.tap(find.text('Tràn mặt 8/8'));
      await tester.pumpAndSettle();

      expect(currentSpec.fraction, equals(1.0));
      expect(currentSpec.side, equals(ContactSide.center));
      expect(find.textContaining('Tràn mặt'), findsWidgets);

      // Bấm nút Tràn mặt 8/8 một lần nữa -> PHỤC HỒI lại đúng 3/8 và Má Trái!
      await tester.tap(find.text('Tràn mặt 8/8 (Đang chọn)'));
      await tester.pumpAndSettle();

      expect(currentSpec.fraction, closeTo(0.375, 1e-9));
      expect(currentSpec.side, equals(ContactSide.left), reason: 'Phục hồi phải giữ đúng má trái trước đó');
      expect(find.textContaining('3/8'), findsWidgets);
      expect(find.textContaining('Má trái'), findsWidgets);
    });

    testWidgets('5. Mở bài học cũ 1/3: hiển thị nhãn gốc, không tự làm tròn khi build', (tester) async {
      final legacySpec = BallContactSpec.oneThird(side: ContactSide.right);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallContactDiagram(
              spec: legacySpec,
              mode: DiagramDisplayMode.interactive,
              onSpecChanged: (_) {},
            ),
          ),
        ),
      );

      // Phải hiển thị rõ phân số gốc 1/3 và phần trăm gốc 33.3%
      expect(find.textContaining('1/3 trái (Gốc 33.3%)'), findsOneWidget);
    });
  });

  group('III. Kiểm thử Điểm Mũi Cơ theo mm & Thang 4 mức (CueBallEffetSpec)', () {
    test('6. Kích thước chuẩn Bi 61.5mm, R=30.75mm, Thang 4 mức mỗi mức 3.84375mm', () {
      expect(CueBallEffetSpec.ballDiameterMm, equals(61.5));
      expect(CueBallEffetSpec.ballRadiusMm, equals(30.75));
      expect(CueBallEffetSpec.tierStepMm, closeTo(30.75 * 0.125, 1e-9));
      expect(CueBallEffetSpec.tierStepMm, closeTo(3.84375, 1e-5));

      // Mức 0 (Tâm): 0 mm
      final centerSpec = CueBallEffetSpec.fromTiers(horizontalTier: 0, verticalTier: 0);
      expect(centerSpec.contactOffsetXMm, closeTo(0.0, 1e-6));
      expect(centerSpec.contactOffsetZMm, closeTo(0.0, 1e-6));
      expect(centerSpec.contactRadiusMm, closeTo(0.0, 1e-6));

      // Mức 2 Cu-lê (cao): z = +7.6875 mm
      final culeSpec = CueBallEffetSpec.fromTiers(horizontalTier: 0, verticalTier: 2);
      expect(culeSpec.contactOffsetXMm, closeTo(0.0, 1e-6));
      expect(culeSpec.contactOffsetZMm, closeTo(7.6875, 1e-4));
      expect(culeSpec.nearestVerticalTier, equals(2));

      // Mức 3 Trô (thấp): z = -11.53125 mm
      final retroSpec = CueBallEffetSpec.fromTiers(horizontalTier: 0, verticalTier: -3);
      expect(retroSpec.contactOffsetZMm, closeTo(-11.53125, 1e-4));
      expect(retroSpec.nearestVerticalTier, equals(-3));

      // Mức 4 (Biên an toàn 0.5R): 15.375 mm
      final maxSafetySpec = CueBallEffetSpec.fromTiers(horizontalTier: 4, verticalTier: 0);
      expect(maxSafetySpec.contactOffsetXMm, closeTo(15.375, 1e-4));
      expect(maxSafetySpec.isOutsideReferenceSafetyZone, isFalse);
    });

    test('7. Ràng buộc đĩa tròn an toàn (Circular Constraint): Vừa 4 trái vừa 4 cao tự động chiếu về r <= 15.375mm', () {
      // Khi chọn chéo (hTier = 4, vTier = 4):
      // Raw: x = 15.375mm, z = 15.375mm => r = sqrt(2) * 15.375 ≈ 21.74mm > 15.375mm
      final diagonalSpec = CueBallEffetSpec.fromTiers(horizontalTier: 4, verticalTier: 4);

      // Điểm tiếp xúc sau khi chiếu đĩa tròn bắt buộc phải nằm trong r <= 15.375mm
      expect(diagonalSpec.contactRadiusMm, lessThanOrEqualTo(15.375 + 1e-9));
      expect(diagonalSpec.contactOffsetXMm, closeTo(15.375 / math.sqrt(2), 1e-4));
      expect(diagonalSpec.contactOffsetZMm, closeTo(15.375 / math.sqrt(2), 1e-4));
      expect(diagonalSpec.isOutsideReferenceSafetyZone, isFalse);
    });

    test('8. Mốc tham khảo Natural Roll tại z = +0.40R = +12.30mm', () {
      expect(CueBallEffetSpec.naturalRollZRatio, equals(0.40));
      expect(CueBallEffetSpec.naturalRollZMm, closeTo(30.75 * 0.40, 1e-9));
      expect(CueBallEffetSpec.naturalRollZMm, closeTo(12.30, 1e-5));
    });

    test('9. Đổi tipDiameter không làm thay đổi tọa độ tiếp xúc vật lý hay spin', () {
      final spec12 = CueBallEffetSpec.fromTiers(horizontalTier: 2, verticalTier: -1, tipDiameterMm: 12.0);
      final spec115 = spec12.copyWith(tipDiameterMm: 11.5);

      expect(spec115.tipDiameterMm, equals(11.5));
      expect(spec115.contactOffsetXMm, closeTo(spec12.contactOffsetXMm, 1e-9));
      expect(spec115.contactOffsetZMm, closeTo(spec12.contactOffsetZMm, 1e-9));
      expect(spec115.physicalTipOffsetRatio, equals(spec12.physicalTipOffsetRatio));
    });
  });

  group('IV. Kiểm thử Widget Điểm Mũi Cơ (CueBallEffetDiagram)', () {
    testWidgets('10. Hiển thị thông số mm, chọn đầu cơ và bấm chip Natural Roll (+12.3mm)', (tester) async {
      CueBallEffetSpec currentSpec = CueBallEffetSpec.fromTiers(
        horizontalTier: 0,
        verticalTier: 0,
        tipDiameterMm: 12.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CueBallEffetDiagram(
                  spec: currentSpec,
                  mode: DiagramDisplayMode.interactive,
                  onSpecChanged: (newSpec) {
                    setState(() {
                      currentSpec = newSpec;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Ban đầu: Tâm bi (0,0)
      expect(find.textContaining('X: +0.0 mm'), findsOneWidget);
      expect(find.textContaining('Z: +0.0 mm'), findsOneWidget);
      expect(find.textContaining('Đầu cơ 12.0 mm'), findsOneWidget);

      // Bấm chip Roll (+12.3mm)
      await tester.tap(find.text('Roll (+12.3mm)'));
      await tester.pumpAndSettle();

      expect(currentSpec.contactOffsetZMm, closeTo(12.30, 0.1));
      expect(find.textContaining('Z: +12.3 mm'), findsOneWidget);

      // Đổi đầu cơ sang 11.5mm
      await tester.tap(find.text('11.5mm'));
      await tester.pumpAndSettle();

      expect(currentSpec.tipDiameterMm, equals(11.5));
      expect(find.textContaining('Đầu cơ 11.5 mm'), findsOneWidget);
      expect(currentSpec.contactOffsetZMm, closeTo(12.30, 0.1), reason: 'Đổi đầu cơ phải giữ nguyên điểm tiếp xúc');
    });
  });
}

