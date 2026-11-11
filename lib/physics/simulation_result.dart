import 'ball_state.dart';
import 'collisions.dart';
import 'shot_input.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Lý do kết thúc mô phỏng vật lý.
enum SimulationTerminationReason {
  /// Tất cả 3 bi đã dừng hẳn tịnh tiến và xoáy.
  allBallsStopped,

  /// Đạt giới hạn thời gian tối đa của bộ giải.
  maxTimeReached,
}

/// Trạng thái chụp nhanh (Snapshot) của cả 3 viên bi tại thời điểm `timestamp` (s).
class SimulationSnapshot {
  final double timestamp;
  final BallState cueBall;
  final BallState objectBall1;
  final BallState objectBall2;

  const SimulationSnapshot({
    required this.timestamp,
    required this.cueBall,
    required this.objectBall1,
    required this.objectBall2,
  });

  BallState stateOf(BallId id) {
    switch (id) {
      case BallId.cue:
        return cueBall;
      case BallId.object1:
        return objectBall1;
      case BallId.object2:
        return objectBall2;
    }
  }

  /// Tổng động năng cơ học (tịnh tiến + quay 3D) của cả 3 bi trên bàn tại thời điểm `timestamp` (J).
  double totalKineticEnergy(TableConfig config) =>
      cueBall.kineticEnergy(config) +
      objectBall1.kineticEnergy(config) +
      objectBall2.kineticEnergy(config);

  static SimulationSnapshot interpolate(
    SimulationSnapshot a,
    SimulationSnapshot b,
    double t,
  ) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    return SimulationSnapshot(
      timestamp: a.timestamp + (b.timestamp - a.timestamp) * t,
      cueBall: BallState.interpolate(a.cueBall, b.cueBall, t),
      objectBall1: BallState.interpolate(a.objectBall1, b.objectBall1, t),
      objectBall2: BallState.interpolate(a.objectBall2, b.objectBall2, t),
    );
  }
}

/// Kết quả chấm điểm cú đánh Carom & Gom bi được suy ra thuần túy từ `SimulationResult`.
class ShotEvaluation {
  /// Bi chủ có chạm vào ít nhất 1 bi mục tiêu hay không.
  final bool hitsFirstObjectBall;

  /// Bi chủ có thực sự chạm cả 2 bi mục tiêu (Vàng & Đỏ) để ghi điểm Carom hợp lệ hay không.
  final bool hitsSecondBall;

  /// Viên bi mục tiêu đầu tiên mà Bi chủ chạm phải (`BallId.object1` hoặc `BallId.object2`).
  final BallId? firstObjectBallHit;

  /// Độ dày chạm thực tế `f = 1 - sin(theta)` thuộc `[0, 1]` tại lần chạm đầu tiên giữa Bi chủ và Bi mục tiêu 1.
  final double? firstObject1ContactFraction;

  /// Dấu lệch bên thực tế tại lần chạm đầu tiên giữa Bi chủ và Bi mục tiêu 1 (`+1` má trái, `-1` má phải, `0` trực diện).
  final double? firstObject1LateralSign;

  /// Số băng Bi chủ đã chạm trước khi chạm viên bi mục tiêu thứ hai (dùng cho 1 băng / 3 băng).
  final int cushionCountBeforeCarom;

  /// Tổng số lần Bi mục tiêu 1 (Vàng) chạm băng trong suốt cú đánh.
  final int objectBall1CushionCount;

  /// Tổng số lần Bi chủ (Trắng) chạm băng trong suốt cú đánh.
  final int cueBallCushionCount;

  /// Kết quả gom 3 bi vào vùng mục tiêu:
  /// - `null`: Bài học / hình bi không quy định `targetZoneCenter`.
  /// - `true`: Cả 3 bi đã dừng hẳn (`allBallsStopped`) VÀ tâm cả 3 bi đều nằm trong `targetZoneRadius`.
  /// - `false`: Có ít nhất 1 bi dừng ngoài `targetZoneRadius` hoặc chưa dừng hẳn.
  final bool? gathersInZone;

  /// Thông điệp phân tích vật lý trung thực từ kết quả mô phỏng.
  final String feedbackMessage;

  const ShotEvaluation({
    required this.hitsFirstObjectBall,
    required this.hitsSecondBall,
    this.firstObjectBallHit,
    this.firstObject1ContactFraction,
    this.firstObject1LateralSign,
    required this.cushionCountBeforeCarom,
    this.objectBall1CushionCount = 0,
    this.cueBallCushionCount = 0,
    required this.gathersInZone,
    required this.feedbackMessage,
  });
}

/// Kết quả toàn diện của một lần chạy mô phỏng vật lý Carom.
class SimulationResult {
  final TableConfig config;
  final ShotInput input;
  final List<SimulationSnapshot> snapshots;
  final List<CollisionEvent> collisionEvents;
  final double durationSeconds;
  final SimulationTerminationReason terminationReason;
  late final ShotEvaluation evaluation = _computeEvaluation();

  SimulationResult({
    required this.config,
    required this.input,
    required this.snapshots,
    required this.collisionEvents,
    required this.durationSeconds,
    required this.terminationReason,
  });

  SimulationSnapshot get initialSnapshot => snapshots.first;
  SimulationSnapshot get finalSnapshot => snapshots.last;

  /// Tìm sự kiện va chạm đầu tiên giữa Bi chủ và Bi mục tiêu 1 (Vàng).
  CollisionEvent? get firstHitObject1Event {
    for (final e in collisionEvents) {
      if (e.isBetweenBalls(BallId.cue, BallId.object1)) return e;
    }
    return null;
  }

  /// Tìm sự kiện va chạm đầu tiên giữa Bi chủ và Bi mục tiêu 2 (Đỏ).
  CollisionEvent? get firstHitObject2Event {
    for (final e in collisionEvents) {
      if (e.isBetweenBalls(BallId.cue, BallId.object2)) return e;
    }
    return null;
  }

  /// Nội suy trạng thái 3 bi tại thời điểm vật lý `timeSeconds` thuộc `[0, durationSeconds]`.
  SimulationSnapshot sampleAtTime(double timeSeconds) {
    if (snapshots.isEmpty) {
      throw StateError('SimulationResult contains no snapshots.');
    }
    if (snapshots.length == 1 || timeSeconds <= 0.0) {
      return snapshots.first;
    }
    if (timeSeconds >= durationSeconds) {
      return snapshots.last;
    }

    // Tìm nhị phân (binary search) khoảng snapshot chứa timeSeconds
    int low = 0;
    int high = snapshots.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final midTime = snapshots[mid].timestamp;
      if (midTime < timeSeconds) {
        low = mid + 1;
      } else if (midTime > timeSeconds) {
        high = mid - 1;
      } else {
        return snapshots[mid];
      }
    }

    final idx0 = high.clamp(0, snapshots.length - 2);
    final idx1 = idx0 + 1;
    final s0 = snapshots[idx0];
    final s1 = snapshots[idx1];
    final span = s1.timestamp - s0.timestamp;
    final localT = span <= 1e-9 ? 0.0 : (timeSeconds - s0.timestamp) / span;
    return SimulationSnapshot.interpolate(s0, s1, localT);
  }

  /// Nội suy trạng thái 3 bi theo tiến độ chuẩn hóa `progress` thuộc `[0.0, 1.0]`.
  SimulationSnapshot sampleAtProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return sampleAtTime(clamped * durationSeconds);
  }

  /// Trích xuất danh sách tọa độ quỹ đạo (m) của một viên bi từ chuỗi snapshots.
  List<Vec2> trajectoryMetersOf(BallId id) =>
      snapshots.map((s) => s.stateOf(id).position).toList();

  /// Trích xuất danh sách tọa độ quỹ đạo theo đơn vị nút băng (0..8, 0..4) của một viên bi.
  List<Vec2> trajectoryDiamondsOf(BallId id) => snapshots
      .map((s) => config.metersToDiamond(s.stateOf(id).position))
      .toList();

  ShotEvaluation _computeEvaluation() {
    final hitObj1 = firstHitObject1Event;
    final hitObj2 = firstHitObject2Event;

    final hitsFirst = hitObj1 != null || hitObj2 != null;
    final hitsSecond = hitObj1 != null && hitObj2 != null;

    BallId? firstObjectHit;
    if (hitObj1 != null && hitObj2 != null) {
      firstObjectHit = hitObj1.timestamp <= hitObj2.timestamp
          ? BallId.object1
          : BallId.object2;
    } else if (hitObj1 != null) {
      firstObjectHit = BallId.object1;
    } else if (hitObj2 != null) {
      firstObjectHit = BallId.object2;
    }

    int cushionsBeforeCarom = 0;
    if (hitsSecond) {
      final secondHitTime = hitObj1.timestamp > hitObj2.timestamp
          ? hitObj1.timestamp
          : hitObj2.timestamp;
      for (final e in collisionEvents) {
        if (e.type == CollisionType.ballCushion &&
            e.primaryBall == BallId.cue &&
            e.timestamp <= secondHitTime + 1e-6) {
          cushionsBeforeCarom++;
        }
      }
    }

    int obj1Cushions = 0;
    int cueCushions = 0;
    for (final e in collisionEvents) {
      if (e.type == CollisionType.ballCushion) {
        if (e.primaryBall == BallId.object1) obj1Cushions++;
        if (e.primaryBall == BallId.cue) cueCushions++;
      }
    }

    bool? gathers;
    if (input.targetZoneCenterMeters != null &&
        input.targetZoneRadiusMeters != null &&
        input.targetZoneRadiusMeters! > 0.0) {
      final zoneCenter = input.targetZoneCenterMeters!;
      final zoneRadius = input.targetZoneRadiusMeters!;
      if (terminationReason != SimulationTerminationReason.allBallsStopped) {
        gathers = false;
      } else {
        final end = finalSnapshot;
        final dCue = end.cueBall.position.distanceTo(zoneCenter);
        final dObj1 = end.objectBall1.position.distanceTo(zoneCenter);
        final dObj2 = end.objectBall2.position.distanceTo(zoneCenter);
        gathers =
            dCue <= zoneRadius && dObj1 <= zoneRadius && dObj2 <= zoneRadius;
      }
    }

    String feedback;
    if (!hitsFirst) {
      feedback =
          'Bi chủ đi trượt hoàn toàn, chưa chạm được vào bi mục tiêu nào.';
    } else if (!hitsSecond) {
      final missedName = hitObj1 == null ? 'bi Vàng (Bi 1)' : 'bi Đỏ (Bi 2)';
      feedback =
          'Chưa ghi điểm Carom: Bi chủ mới chạm 1 bi đích, đường bi lệch khỏi $missedName.';
    } else if (gathers == false) {
      feedback =
          'Trúng điểm Carom hợp lệ nhưng 3 bi dừng cuối cùng chưa tụ hết trong bán kính vùng gom.';
    } else if (gathers == true) {
      feedback =
          'Đạt chuẩn Carom & Gom bi: Bi chủ chạm đủ 2 bi đích và cả 3 bi dừng gọn trong vùng gom!';
    } else {
      feedback = cushionsBeforeCarom > 0
          ? 'Ghi điểm Carom hợp lệ (chạm $cushionsBeforeCarom băng trước khi trúng bi đích thứ 2).'
          : 'Ghi điểm Carom hợp lệ: Bi chủ chạm chính xác cả 2 bi mục tiêu.';
    }

    return ShotEvaluation(
      hitsFirstObjectBall: hitsFirst,
      hitsSecondBall: hitsSecond,
      firstObjectBallHit: firstObjectHit,
      firstObject1ContactFraction: hitObj1?.effectiveContactFraction,
      firstObject1LateralSign: hitObj1?.effectiveLateralSign,
      cushionCountBeforeCarom: cushionsBeforeCarom,
      objectBall1CushionCount: obj1Cushions,
      cueBallCushionCount: cueCushions,
      gathersInZone: gathers,
      feedbackMessage: feedback,
    );
  }
}
