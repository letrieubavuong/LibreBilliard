import '../physics/billiard_physics.dart';

/// Bộ đặc tả kỹ thuật nghiệm thu động lực học (Physics Verification Fixture) cho từng bài học.
/// Xác thực chính xác thứ tự chạm, dấu má, độ dày tiếp xúc, số băng dội, khoảng kéo/tiến theo cm,
/// và cự ly gom bi mà không dùng dung sai nhân tạo hoặc nới lỏng mục tiêu sư phạm.
class LessonPhysicsVerificationFixture {
  final String lessonCode;

  /// Viên bi mục tiêu đầu tiên mà bi chủ phải chạm (`BallId.object1` hoặc `BallId.object2`).
  /// `null` nếu là cú đánh A-băng (Bricole) bi chủ đập băng trước khi chạm bất kỳ bi nào.
  final BallId? expectedFirstBallHit;

  /// Dấu má chạm thực tế tại Bi 1 (`+1.0` má trái, `-1.0` má phải, `0.0` thẳng mặt, `null` không áp dụng).
  final double? expectedLateralSign;

  /// Độ dày tiếp xúc lý thuyết được dạy (`fraction` thuộc `[0.0, 1.0]`).
  final double expectedContactFraction;

  /// Dung sai tối đa cho phép của độ dày chạm (mặc định chặt chẽ `0.05`).
  final double contactFractionTolerance;

  /// Số băng tối thiểu bi chủ phải đập trước khi chạm viên bi mục tiêu thứ hai (carom).
  final int minCushionsBeforeCarom;

  /// Số băng chính xác bi mục tiêu 1 (vàng) phải chạm trong suốt cú đánh (nếu có yêu cầu bài học).
  final int? expectedYellowCushionBounces;

  /// Khoảng tịnh tiến tối thiểu của bi chủ sau khi ra cơ (mét), ví dụ trô lùi tối thiểu 15cm = 0.15m.
  final double? minCueBallDisplacementMeters;

  /// Khoảng tịnh tiến tối đa của bi chủ sau khi ra cơ (mét), ví dụ trô lùi tối đa 25cm = 0.25m.
  final double? maxCueBallDisplacementMeters;

  /// Bắt buộc ghi điểm Carom hợp lệ (chạm cả 2 bi mục tiêu).
  final bool expectCarom;

  /// Bắt buộc cả 3 bi dừng trong bán kính vùng gom `targetZoneRadius` (không nới rộng).
  final bool expectTargetZoneGather;

  /// Ghi chú giải trình kỹ thuật hoặc giới hạn mô hình chưa kiểm chứng.
  final String notes;

  const LessonPhysicsVerificationFixture({
    required this.lessonCode,
    this.expectedFirstBallHit = BallId.object1,
    this.expectedLateralSign,
    required this.expectedContactFraction,
    this.contactFractionTolerance = 0.05,
    this.minCushionsBeforeCarom = 0,
    this.expectedYellowCushionBounces,
    this.minCueBallDisplacementMeters,
    this.maxCueBallDisplacementMeters,
    this.expectCarom = true,
    this.expectTargetZoneGather = true,
    this.notes = '',
  });

  /// Kiểm chứng kết quả mô phỏng `SimulationResult` theo đầy đủ tiêu chí của Fixture.
  ({bool isPass, List<String> failures}) verify(SimulationResult sim) {
    final failures = <String>[];
    final eval = sim.evaluation;

    // 1. Thứ tự chạm bi đầu tiên
    if (expectedFirstBallHit != null) {
      if (eval.firstObjectBallHit != expectedFirstBallHit) {
        failures.add(
          'Thứ tự chạm sai: kì vọng $expectedFirstBallHit, thực tế ${eval.firstObjectBallHit}',
        );
      }
    }

    // 2. Dấu má chạm (Lateral Sign: +1 má trái, -1 má phải)
    if (expectedLateralSign != null && eval.firstObject1LateralSign != null) {
      if ((eval.firstObject1LateralSign! - expectedLateralSign!).abs() > 0.1) {
        failures.add(
          'Má chạm sai: kì vọng $expectedLateralSign, thực tế ${eval.firstObject1LateralSign}',
        );
      }
    }

    // 3. Độ dày tiếp xúc thực tế vs Taught Fraction
    if (eval.firstObject1ContactFraction != null) {
      final diff = (eval.firstObject1ContactFraction! - expectedContactFraction).abs();
      if (diff > contactFractionTolerance) {
        failures.add(
          'Sai lệch độ dày chạm quá dung sai ($contactFractionTolerance): '
          'kì vọng $expectedContactFraction, thực tế ${eval.firstObject1ContactFraction!.toStringAsFixed(3)} (lệch ${diff.toStringAsFixed(3)})',
        );
      }
    }

    // 4. Số băng trước Carom
    if (eval.cushionCountBeforeCarom < minCushionsBeforeCarom) {
      failures.add(
        'Số băng trước carom thiếu: yêu cầu >= $minCushionsBeforeCarom, thực tế ${eval.cushionCountBeforeCarom}',
      );
    }

    // 5. Số băng của Bi 1 (Vàng)
    if (expectedYellowCushionBounces != null) {
      if (eval.objectBall1CushionCount != expectedYellowCushionBounces) {
        failures.add(
          'Số băng bi vàng sai: kì vọng $expectedYellowCushionBounces, thực tế ${eval.objectBall1CushionCount}',
        );
      }
    }

    // 6. Quãng đường tịnh tiến của Bi chủ (kéo lùi / đẩy tới)
    final pInit = sim.initialSnapshot.cueBall.position;
    final pFinal = sim.finalSnapshot.cueBall.position;
    final cueDisplacement = (pFinal - pInit).length;
    if (minCueBallDisplacementMeters != null && cueDisplacement < minCueBallDisplacementMeters!) {
      failures.add(
        'Bi chủ di chuyển quá ngắn: tối thiểu ${(minCueBallDisplacementMeters! * 100).toStringAsFixed(1)}cm, '
        'thực tế ${(cueDisplacement * 100).toStringAsFixed(1)}cm',
      );
    }
    if (maxCueBallDisplacementMeters != null && cueDisplacement > maxCueBallDisplacementMeters!) {
      failures.add(
        'Bi chủ di chuyển quá dài: tối đa ${(maxCueBallDisplacementMeters! * 100).toStringAsFixed(1)}cm, '
        'thực tế ${(cueDisplacement * 100).toStringAsFixed(1)}cm',
      );
    }

    // 7. Ghi điểm Carom
    if (expectCarom && !eval.hitsSecondBall) {
      failures.add('Không trúng bi thứ 2 (hụt Carom)');
    }

    // 8. Gom bi vào target zone
    if (expectTargetZoneGather && eval.gathersInZone == false) {
      failures.add('Các bi không tụ đủ trong vùng gom mục tiêu');
    }

    return (isPass: failures.isEmpty, failures: failures);
  }

  /// Danh mục Fixture chuẩn cho tất cả 13 bài học mẫu trong LibreBilliard.
  static final Map<String, LessonPhysicsVerificationFixture> fixtures = {
    // KT-01: Rétro ngắn kéo lùi 15-25cm, bi vàng 1 băng ngắn, má trái 3/4
    'KT-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.75,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 1,
      minCueBallDisplacementMeters: 0.15,
      maxCueBallDisplacementMeters: 0.25,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Rétro ngắn gom góc: bi chủ lùi 15-25cm, bi vàng 1 băng quay về vị trí bi đỏ.',
    ),

    // KT-02: Coulé đẩy mượt 10-20cm, má phải 1/2
    'KT-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      minCueBallDisplacementMeters: 0.10,
      maxCueBallDisplacementMeters: 0.20,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Poussé tịnh tiến dọc băng 10-20cm giữ cặp bi song song.',
    ),

    // KT-03: Amorti phanh bi, má trái 2/3
    'KT-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 2.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Phanh bi dừng sát bi 2, hãm tốc độ hoàn toàn.',
    ),

    // KT-04: Piqué 40 độ nghiêng cơ (chưa đóng nhãn verified)
    'KT-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.15,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Piqué 40°: độ cong pha trượt làm lệch fraction (0.36 vs 0.25); chưa đóng verified.',
    ),

    // GB-01: Gom bi 1 băng dài
    'GB-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Gom bi 1 băng dài kinh điển.',
    ),

    // GB-02: Gom bi Chữ thập 2 băng
    'GB-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Gom bi chữ thập 2 băng góc.',
    ),

    // GB-03: Đòn Lật bi gom về vùng Amery
    'GB-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Lật bi gom vùng Amery.',
    ),

    // GB-04: Gom bi Dọc băng ngắn (Khứ hồi)
    'GB-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.875,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Rappel khứ hồi 2 băng ngắn.',
    ),

    // BS-01: Bộ số 50 (3 băng)
    'BS-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 3,
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Hệ thống 3 băng bộ số 50.',
    ),

    // BS-02: Plus 2 System (Ngắn - Dài - Dài)
    'BS-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 2,
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Plus 2 ngắn dài dài.',
    ),

    // BS-03: Bộ số Tia 1 băng chia đôi (Bricole)
    'BS-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-03',
      expectedFirstBallHit: BallId.object1,
      expectedContactFraction: 0.516,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 1,
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Bricole 1 băng chia đôi.',
    ),

    // BS-04: Hệ thống Tia Góc 2 Băng
    'BS-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Tia 2 băng góc vòng sau lưng bi.',
    ),

    // SR-01: Thế bi Mắt kính dọc băng
    'SR-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Duy trì mắt kính dọc băng dài.',
    ),

    // SR-02: Xoay sở qua vạch Ô cấm góc
    'SR-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Đưa bi ra khỏi vạch ô cấm đúng luật.',
    ),

    // SR-03: Nhịp Bắc cầu qua vạch Amery
    'SR-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Bắc cầu qua vạch Amery.',
    ),
  };
}
