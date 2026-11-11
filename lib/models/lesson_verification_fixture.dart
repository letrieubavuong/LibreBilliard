import 'dart:math' as math;
import '../physics/billiard_physics.dart';

/// Hướng chuyển động tương đối của bi chủ sau va chạm với Bi mục tiêu 1.
enum CuePostImpactMotionType {
  /// Rétro / Trô lùi: Bi chủ có thành phần độ dời / vận tốc giật lùi ngược hướng tới (`s_par < 0`).
  drawBack,

  /// Coulé / Poussé / Đẩy tới: Bi chủ tiếp tục tịnh tiến cùng chiều hướng tới (`s_par > 0`).
  pushForward,

  /// Không ràng buộc chiều dọc (áp dụng cho các cú đánh xiên góc hoặc tự do).
  any,
}

/// Bộ đặc tả kỹ thuật nghiệm thu động lực học (Physics Verification Fixture) cho từng bài học.
/// Xác thực chính xác thứ tự chạm, dấu má, độ dày tiếp xúc, số băng dội, chuỗi thành băng,
/// hướng chuyển động sau va chạm (kéo lùi / đẩy tới), và cự ly gom bi.
/// Không dùng dung sai nhân tạo hoặc nới lỏng mục tiêu sư phạm.
class LessonPhysicsVerificationFixture {
  final String lessonCode;

  /// Viên bi mục tiêu đầu tiên mà bi chủ phải chạm (`BallId.object1` hoặc `BallId.object2`).
  /// `null` nếu là cú đánh A-băng (Bricole) bi chủ đập băng trước khi chạm bất kỳ bi nào.
  final BallId? expectedFirstBallHit;

  /// Dấu má chạm thực tế tại Bi 1 (`+1.0` má trái, `-1.0` má phải, `0.0` thẳng mặt).
  /// `null` nếu không áp dụng (ví dụ Bricole 1 băng).
  final double? expectedLateralSign;

  /// Độ dày tiếp xúc lý thuyết được dạy (`fraction` thuộc `[0.0, 1.0]`).
  final double expectedContactFraction;

  /// Dung sai tối đa cho phép của độ dày chạm (mặc định chặt chẽ `0.05`).
  final double contactFractionTolerance;

  /// Hướng chuyển động bắt buộc của bi chủ sau khi chạm Bi mục tiêu 1 (kéo lùi hoặc đẩy tới).
  final CuePostImpactMotionType? expectedCuePostImpactMotion;

  /// Khoảng dời sau va chạm tối thiểu của bi chủ (mét), tính từ điểm va chạm Bi 1 đến khi chạm bi 2 hoặc dừng.
  final double? minCueBallPostImpactDisplacementMeters;

  /// Khoảng dời sau va chạm tối đa của bi chủ (mét).
  final double? maxCueBallPostImpactDisplacementMeters;

  /// Số băng tối thiểu bi chủ phải đập TRƯỚC khi chạm Bi mục tiêu 1 (ví dụ Bricole = 1).
  final int minCueCushionsBeforeFirstBall;

  /// Số băng tối thiểu bi chủ phải đập trước khi chạm viên bi mục tiêu thứ hai (carom).
  final int minCushionsBeforeCarom;

  /// Số băng tối đa bi chủ được phép đập trước khi chạm viên bi mục tiêu thứ hai (carom).
  /// Ví dụ: 0 cho các cú trô lùi thẳng trực tiếp (retrait direct / rappel de base) nghiêm cấm chạm băng.
  final int? maxCushionsBeforeCarom;

  /// Chuỗi thành băng bi chủ dự kiến chạm trước khi carom (nếu có yêu cầu nghiêm ngặt).
  final List<CushionId>? expectedCueCushionSequence;

  /// Số băng chính xác bi mục tiêu 1 (vàng) phải chạm trong suốt cú đánh (nếu có yêu cầu bài học).
  final int? expectedYellowCushionBounces;

  /// Danh sách thành băng bi mục tiêu 1 (vàng) phải chạm (nếu có yêu cầu).
  final List<CushionId>? expectedYellowCushionSequence;

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
    this.expectedCuePostImpactMotion,
    this.minCueBallPostImpactDisplacementMeters,
    this.maxCueBallPostImpactDisplacementMeters,
    this.minCueCushionsBeforeFirstBall = 0,
    this.minCushionsBeforeCarom = 0,
    this.maxCushionsBeforeCarom,
    this.expectedCueCushionSequence,
    this.expectedYellowCushionBounces,
    this.expectedYellowCushionSequence,
    this.expectCarom = true,
    this.expectTargetZoneGather = true,
    this.notes = '',
  });

  /// Kiểm chứng kết quả mô phỏng `SimulationResult` theo đầy đủ tiêu chí khắt khe của Fixture.
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
    // Quy tắc P1: Expected có bật mà actual null thì PHẢI FAIL (missing measurement)
    if (expectedLateralSign != null) {
      if (eval.firstObject1LateralSign == null) {
        failures.add(
          'Thiếu số đo má chạm (actual là null) khi bài học yêu cầu má $expectedLateralSign',
        );
      } else if ((eval.firstObject1LateralSign! - expectedLateralSign!).abs() > 0.1) {
        failures.add(
          'Má chạm sai: kì vọng $expectedLateralSign, thực tế ${eval.firstObject1LateralSign}',
        );
      }
    }

    // 3. Độ dày tiếp xúc thực tế vs Taught Fraction
    // Quy tắc P1: Expected có bật mà actual null thì PHẢI FAIL
    if (eval.firstObject1ContactFraction == null) {
      failures.add(
        'Thiếu số đo độ dày chạm (actual là null) khi bài học yêu cầu fraction $expectedContactFraction',
      );
    } else {
      final diff = (eval.firstObject1ContactFraction! - expectedContactFraction).abs();
      if (diff > contactFractionTolerance) {
        failures.add(
          'Sai lệch độ dày chạm quá dung sai ($contactFractionTolerance): '
          'kì vọng $expectedContactFraction, thực tế ${eval.firstObject1ContactFraction!.toStringAsFixed(3)} (lệch ${diff.toStringAsFixed(3)})',
        );
      }
    }

    // 4. Số băng bi chủ trước khi chạm bi mục tiêu 1 (dành cho cú Bricole)
    final firstHit1 = sim.firstHitObject1Event;
    int cueCushionsBeforeHit1 = 0;
    final cueCushionsBeforeCaromList = <CushionId>[];
    final allCueCushionsList = <CushionId>[];
    final allYellowCushionsList = <CushionId>[];

    final hitObj2 = sim.firstHitObject2Event;
    final caromTime = (firstHit1 != null && hitObj2 != null)
        ? math.max(firstHit1.timestamp, hitObj2.timestamp)
        : double.infinity;

    for (final ev in sim.collisionEvents) {
      if (ev.type == CollisionType.ballCushion && ev.cushion != null) {
        if (ev.primaryBall == BallId.cue) {
          allCueCushionsList.add(ev.cushion!);
          if (firstHit1 == null || ev.timestamp < firstHit1.timestamp) {
            cueCushionsBeforeHit1++;
          }
          if (ev.timestamp < caromTime) {
            cueCushionsBeforeCaromList.add(ev.cushion!);
          }
        } else if (ev.primaryBall == BallId.object1) {
          allYellowCushionsList.add(ev.cushion!);
        }
      }
    }

    if (cueCushionsBeforeHit1 < minCueCushionsBeforeFirstBall) {
      failures.add(
        'Số băng bi chủ trước khi chạm bi 1 thiếu: yêu cầu >= $minCueCushionsBeforeFirstBall, thực tế $cueCushionsBeforeHit1',
      );
    }

    // 5. Số băng trước Carom
    if (eval.cushionCountBeforeCarom < minCushionsBeforeCarom) {
      failures.add(
        'Số băng trước carom thiếu: yêu cầu >= $minCushionsBeforeCarom, thực tế ${eval.cushionCountBeforeCarom}',
      );
    }
    if (maxCushionsBeforeCarom != null && eval.cushionCountBeforeCarom > maxCushionsBeforeCarom!) {
      failures.add(
        'Số băng bi chủ trước carom vượt quá giới hạn cho phép: yêu cầu <= $maxCushionsBeforeCarom, '
        'thực tế ${eval.cushionCountBeforeCarom} (chuỗi băng chạm: $cueCushionsBeforeCaromList)',
      );
    }

    // 6. Chuỗi thành băng bi chủ chạm trước Carom
    if (expectedCueCushionSequence != null && expectedCueCushionSequence!.isNotEmpty) {
      bool sequenceMatched = false;
      if (cueCushionsBeforeCaromList.length >= expectedCueCushionSequence!.length) {
        sequenceMatched = true;
        for (int i = 0; i < expectedCueCushionSequence!.length; i++) {
          if (cueCushionsBeforeCaromList[i] != expectedCueCushionSequence![i]) {
            sequenceMatched = false;
            break;
          }
        }
      }
      if (!sequenceMatched) {
        failures.add(
          'Chuỗi băng bi chủ trước carom sai: kì vọng $expectedCueCushionSequence, thực tế $cueCushionsBeforeCaromList',
        );
      }
    }

    // 7. Số băng của Bi 1 (Vàng)
    if (expectedYellowCushionBounces != null) {
      if (eval.objectBall1CushionCount != expectedYellowCushionBounces) {
        failures.add(
          'Số băng bi vàng sai: kì vọng $expectedYellowCushionBounces, thực tế ${eval.objectBall1CushionCount}',
        );
      }
    }

    // 8. Chuỗi thành băng bi vàng (nếu có yêu cầu)
    if (expectedYellowCushionSequence != null && expectedYellowCushionSequence!.isNotEmpty) {
      bool yellowSeqMatched = false;
      if (allYellowCushionsList.length >= expectedYellowCushionSequence!.length) {
        yellowSeqMatched = true;
        for (int i = 0; i < expectedYellowCushionSequence!.length; i++) {
          if (allYellowCushionsList[i] != expectedYellowCushionSequence![i]) {
            yellowSeqMatched = false;
            break;
          }
        }
      }
      if (!yellowSeqMatched) {
        failures.add(
          'Chuỗi băng bi vàng sai: kì vọng $expectedYellowCushionSequence, thực tế $allYellowCushionsList',
        );
      }
    }

    // 9. Phép đo động lực học có dấu sau va chạm Bi 1 (Post-Impact Motion Analysis)
    // Quy tắc P1: Đo chính xác sau va chạm, phân biệt kéo lùi (drawBack) vs đẩy tới (pushForward)
    if (expectedCuePostImpactMotion != null ||
        minCueBallPostImpactDisplacementMeters != null ||
        maxCueBallPostImpactDisplacementMeters != null) {
      if (firstHit1 == null) {
        failures.add('Không thể đo chuyển động sau va chạm vì bi chủ chưa chạm bi mục tiêu 1');
      } else {
        final tHit = firstHit1.timestamp;
        final pHit = firstHit1.primaryBallPositionAtCollision ?? sim.sampleAtTime(tHit).cueBall.position;

        // Vận tốc tới của bi chủ ngay trước va chạm (lấy từ CollisionEvent nếu có, hoặc suy từ snapshot)
        final vIn = firstHit1.primaryBallVelocityBefore ??
            sim.sampleAtTime(math.max(0.0, tHit - 0.002)).cueBall.velocity;
        Vec2 uIn;
        if (vIn.length > 1e-5) {
          uIn = vIn / vIn.length;
        } else {
          final diff = pHit - sim.initialSnapshot.cueBall.position;
          uIn = diff.length > 1e-5 ? diff / diff.length : Vec2.unitX;
        }

        // Điểm kết thúc đoạn kỹ thuật đang đo: khi chạm bi 2 hoặc khi dừng hẳn
        double tEnd = sim.durationSeconds;
        if (hitObj2 != null && hitObj2.timestamp > tHit) {
          tEnd = hitObj2.timestamp;
        }
        final pEnd = sim.sampleAtTime(tEnd).cueBall.position;
        final deltaPost = pEnd - pHit;
        final postDisplacement = deltaPost.length;

        // Độ dời có dấu dọc theo hướng tới (s_par < 0 là lùi, s_par > 0 là tiến)
        final sParallel = deltaPost.x * uIn.x + deltaPost.y * uIn.y;

        // Kiểm tra hướng chuyển động sau va chạm
        const epsilonMotion = 0.005; // Ngưỡng tối thiểu 5mm để xác định rõ chiều chuyển động
        if (expectedCuePostImpactMotion == CuePostImpactMotionType.drawBack) {
          // Bắt buộc bi chủ phải giật lùi ngược hướng tới rõ rệt (s_par < -5mm)
          if (sParallel > -epsilonMotion) {
            failures.add(
              'Bi chủ không kéo lùi (Rétro) sau va chạm Bi 1: yêu cầu s_par < -${(epsilonMotion * 100).toStringAsFixed(1)}cm, '
              'thực tế s_par = ${(sParallel * 100).toStringAsFixed(1)}cm',
            );
          }
        } else if (expectedCuePostImpactMotion == CuePostImpactMotionType.pushForward) {
          // Bắt buộc bi chủ phải tịnh tiến tới cùng chiều hướng tới rõ rệt (s_par > +5mm)
          if (sParallel < epsilonMotion) {
            failures.add(
              'Bi chủ không đẩy tới (Coulé) sau va chạm Bi 1: yêu cầu s_par > +${(epsilonMotion * 100).toStringAsFixed(1)}cm, '
              'thực tế s_par = ${(sParallel * 100).toStringAsFixed(1)}cm',
            );
          }
        }

        // Kiểm tra cự ly di chuyển sau va chạm
        if (minCueBallPostImpactDisplacementMeters != null &&
            postDisplacement < minCueBallPostImpactDisplacementMeters!) {
          failures.add(
            'Bi chủ di chuyển sau va chạm quá ngắn: tối thiểu ${(minCueBallPostImpactDisplacementMeters! * 100).toStringAsFixed(1)}cm, '
            'thực tế ${(postDisplacement * 100).toStringAsFixed(1)}cm',
          );
        }
        if (maxCueBallPostImpactDisplacementMeters != null &&
            postDisplacement > maxCueBallPostImpactDisplacementMeters!) {
          failures.add(
            'Bi chủ di chuyển sau va chạm quá dài: tối đa ${(maxCueBallPostImpactDisplacementMeters! * 100).toStringAsFixed(1)}cm, '
            'thực tế ${(postDisplacement * 100).toStringAsFixed(1)}cm',
          );
        }
      }
    }

    // 10. Ghi điểm Carom
    if (expectCarom && !eval.hitsSecondBall) {
      failures.add('Không trúng bi thứ 2 (hụt Carom)');
    }

    // 11. Gom bi vào target zone (P1: Bắt buộc gathersInZone == true, thiếu số đo/null là FAIL)
    if (expectTargetZoneGather) {
      if (eval.gathersInZone != true) {
        failures.add(
          'Các bi không tụ đủ trong vùng gom mục tiêu (kì vọng gathersInZone == true, thực tế ${eval.gathersInZone})',
        );
      }
    }

    return (isPass: failures.isEmpty, failures: failures);
  }

  /// Danh mục Fixture chuẩn cho tất cả 15 bài học mẫu trong LibreBilliard.
  static final Map<String, LessonPhysicsVerificationFixture> fixtures = {
    // =========================================================================
    // KĨ THUẬT (TECHNIQUE: KT-01 .. KT-04)
    // =========================================================================

    // KT-01: Rétro ngắn kéo lùi sau chạm Bi 1, bi vàng 1 băng ngắn, má trái 3/4
    'KT-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.75,
      contactFractionTolerance: 0.05,
      expectedCuePostImpactMotion: CuePostImpactMotionType.drawBack,
      minCueBallPostImpactDisplacementMeters: 0.03,
      maxCueBallPostImpactDisplacementMeters: 0.12,
      expectedYellowCushionBounces: 1,
      expectedYellowCushionSequence: [CushionId.shortNear],
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Rétro ngắn gom góc: bi chủ lùi sau chạm Bi 1, bi vàng 1 băng ngắn tụ về góc.',
    ),

    // KT-02: Coulé đẩy mượt tịnh tiến tới 2-10cm sau chạm Bi 1, má phải 1/2
    'KT-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      expectedCuePostImpactMotion: CuePostImpactMotionType.pushForward,
      minCueBallPostImpactDisplacementMeters: 0.02,
      maxCueBallPostImpactDisplacementMeters: 0.10,
      expectedYellowCushionBounces: 0,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Poussé tịnh tiến mượt dọc băng giữ cặp bi song song.',
    ),

    // KT-03: Amorti phanh bi (Mô tả sư phạm yêu cầu vàng 2 băng; mô hình 2.5D tiêu tán lực hãm chưa đưa bi vàng đủ 2 băng)
    'KT-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 2.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 2,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Amorti phanh bi: mô tả sư phạm yêu cầu bi vàng 2 băng góc; mô hình tiêu tán hiện tại bi vàng dừng trước khi tới băng; chưa đủ điều kiện verified.',
    ),

    // KT-04: Piqué 40 độ nghiêng cơ (chưa đóng nhãn verified)
    'KT-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'KT-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Piqué 40°: độ cong pha trượt làm lệch fraction (0.36 vs 0.25); chưa đóng verified.',
    ),

    // =========================================================================
    // HÌNH GOM BI (GATHERING: GB-01 .. GB-04)
    // =========================================================================

    // GB-01: Gom bi 1 băng dài (Mô tả yêu cầu vàng 1 băng dài)
    'GB-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 1,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Gom bi 1 băng dài: bi vàng cần chạm 1 băng dài; lực cơ hiện tại 0.9m/s làm bi vàng dừng trước băng; chưa đóng verified.',
    ),

    // GB-02: Gom bi Chữ thập 2 băng (Mô tả yêu cầu vàng 2 băng góc)
    'GB-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 2,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Gom bi chữ thập: yêu cầu bi vàng 2 băng góc; hiện tại mới chạm 1 băng; chưa đóng verified.',
    ),

    // GB-03: Đòn Lật bi gom về vùng Amery (Vàng 1 băng ngắn tụ về góc)
    'GB-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 1,
      expectedYellowCushionSequence: [CushionId.shortNear],
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Lật bi gom vùng Amery: bi vàng 1 băng ngắn quay lại tụ cùng bi đỏ.',
    ),

    // GB-04: Gom bi Dọc băng ngắn (Khứ hồi / Rappel 2 băng ngắn)
    'GB-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'GB-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.875,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 2,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Rappel khứ hồi 2 băng ngắn: mô hình hiện tại bi vàng chưa đủ lực chạm 2 băng; chưa đóng verified.',
    ),

    // =========================================================================
    // HỆ THỐNG BỘ SỐ (SYSTEMS: BS-01 .. BS-04)
    // =========================================================================

    // BS-01: Bộ số 50 (3 băng bi chủ: ngắn xa - dài trái - dài phải)
    'BS-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 3,
      expectedCueCushionSequence: [
        CushionId.shortFar,
        CushionId.longLeft,
        CushionId.longRight,
      ],
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Hệ thống 3 băng bộ số 50: chuẩn 3 băng ngắn-dài-dài trước khi carom.',
    ),

    // BS-02: Plus 2 System (Ngắn - Dài - Dài)
    'BS-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 3,
      expectedCueCushionSequence: [
        CushionId.shortFar,
        CushionId.longLeft,
        CushionId.longRight,
      ],
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Plus 2 ngắn-dài-dài: hiện tại bi chủ chạm 2 băng dài; chưa chạm băng ngắn trước carom; chưa đóng verified.',
    ),

    // BS-03: Bộ số Tia 1 băng chia đôi (Bricole 1 băng dài trái trước khi chạm bi 1)
    'BS-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.516,
      contactFractionTolerance: 0.05,
      minCueCushionsBeforeFirstBall: 1,
      minCushionsBeforeCarom: 1,
      expectedCueCushionSequence: [CushionId.longLeft],
      expectCarom: true,
      expectTargetZoneGather: false,
      notes: 'Bricole 1 băng: bi chủ chạm băng dài trước khi chạm bi 1 và ghi điểm carom.',
    ),

    // BS-04: Hệ thống Tia Góc 2 Băng
    'BS-04': const LessonPhysicsVerificationFixture(
      lessonCode: 'BS-04',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      minCushionsBeforeCarom: 2,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Tia 2 băng góc: hiện tại bi chủ chạm trực tiếp bi 1 trước khi đập băng; chưa đóng verified.',
    ),

    // =========================================================================
    // SERI & XỬ LÝ KHU VỰC CẤM (SERIES: SR-01 .. SR-03)
    // =========================================================================

    // SR-01: Thế bi Mắt kính dọc băng
    'SR-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.25,
      contactFractionTolerance: 0.05,
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Duy trì mắt kính dọc băng dài, gom 3 bi vào cự ly hẹp.',
    ),

    // SR-02: Xoay sở qua vạch Ô cấm góc (Bi vàng 1 băng dài trái thoát ô cấm)
    'SR-02': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-02',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: 1.0,
      expectedContactFraction: 0.50,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 1,
      expectedYellowCushionSequence: [CushionId.longLeft],
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Đưa bi ra khỏi vạch ô cấm đúng luật: bi vàng chạm 1 băng dài trái thoát góc.',
    ),

    // SR-03: Nhịp Bắc cầu qua vạch Amery (Bi vàng 1 băng dài trái vượt vạch Amery)
    'SR-03': const LessonPhysicsVerificationFixture(
      lessonCode: 'SR-03',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0,
      expectedContactFraction: 1.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectedYellowCushionBounces: 1,
      expectedYellowCushionSequence: [CushionId.longLeft],
      expectCarom: true,
      expectTargetZoneGather: true,
      notes: 'Bắc cầu qua vạch Amery: bi vàng 1 băng dài trái tái lập cự ly gom.',
    ),

    // =========================================================================
    // KỸ THUẬT KÉO VỀ (RAPPEL: RP-01)
    // =========================================================================

    // RP-01: Trô kéo về cơ bản 2/3 bi (Rappel de base 2/3 de bille)
    'RP-01': const LessonPhysicsVerificationFixture(
      lessonCode: 'RP-01',
      expectedFirstBallHit: BallId.object1,
      expectedLateralSign: -1.0, // Má phải chuẩn theo hình vẽ gốc
      expectedContactFraction: 2.0 / 3.0,
      contactFractionTolerance: 0.05,
      expectedCuePostImpactMotion: CuePostImpactMotionType.drawBack,
      minCueBallPostImpactDisplacementMeters: 0.20,
      maxCueBallPostImpactDisplacementMeters: 0.85,
      minCushionsBeforeCarom: 0,
      maxCushionsBeforeCarom: 0, // Nghiêm cấm bi chủ chạm băng trước carom (lùi thẳng trực tiếp về bi 3)
      expectedYellowCushionSequence: [CushionId.shortNear],
      expectCarom: true,
      expectTargetZoneGather: true,
      notes:
          'Trô kéo về cơ bản 2/3 bi (Rappel de base): Bi 2 chạy ~1.7L (gần 2 chiều dài bàn), Bi 1 trô lùi thẳng trực tiếp về gom sát Bi 3 không chạm băng.',
    ),
  };
}
