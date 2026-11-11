import 'dart:math' as math;
import 'ball_state.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Mã lỗi kiểm tra tính hợp lệ của `ShotInput` trước khi đưa vào `CaromPhysicsEngine`.
enum ShotInputValidationErrorCode {
  nonFiniteValue,
  ballOutOfBounds,
  ballsOverlapping,
  invalidCueSpeed,
}

/// Chi tiết một lỗi kiểm tra đầu vào vật lý.
class ShotInputValidationIssue {
  final ShotInputValidationErrorCode code;
  final String message;
  final BallId? primaryBall;
  final BallId? secondaryBall;

  const ShotInputValidationIssue({
    required this.code,
    required this.message,
    this.primaryBall,
    this.secondaryBall,
  });

  @override
  String toString() => message;
}

/// Kết quả kiểm tra tính hợp lệ của `ShotInput`.
class ShotInputValidationResult {
  final List<ShotInputValidationIssue> issues;

  const ShotInputValidationResult(this.issues);

  bool get isValid => issues.isEmpty;
}

/// Ngoại lệ ném ra khi `ShotInput` vi phạm biên bàn hoặc chồng lấp vượt quá dung sai số học `positionValidationToleranceMeters`.
class ShotInputValidationException implements Exception {
  final ShotInputValidationResult validation;

  const ShotInputValidationException(this.validation);

  @override
  String toString() =>
      'ShotInputValidationException: ${validation.issues.map((e) => e.message).join('; ')}';
}

/// Đầu vào vật lý đầy đủ và tường minh của một cú đánh Billiard Carom.
/// Hoàn toàn độc lập với UI (không phụ thuộc Widget/Canvas).
class ShotInput {
  /// Dung sai số học dấu phẩy động tối đa cho phép khi kiểm tra biên và khoảng cách tâm 2R (1 micromet = 1e-6 m).
  /// Mọi sai lệch lớn hơn ngưỡng này đều bị từ chối rõ ràng thay vì tự ý dịch chuyển thế bi.
  static const double positionValidationToleranceMeters = 1e-6;

  /// Vị trí ban đầu của Bi chủ (Trắng) tính bằng mét.
  final Vec2 cueBallPosition;

  /// Vị trí ban đầu của Bi mục tiêu 1 (Vàng) tính bằng mét.
  final Vec2 objectBall1Position;

  /// Vị trí ban đầu của Bi mục tiêu 2 (Đỏ) tính bằng mét.
  final Vec2 objectBall2Position;

  /// Hướng ngắm đơn vị trên mặt bàn (cos(psi), sin(psi)).
  final Vec2 aimDirection;

  /// Tốc độ ngọn cơ lúc chạm bi chủ `v_cue` (m/s).
  final double cueSpeed;

  /// Điểm chạm đầu cơ chuẩn hóa theo bán kính bi R:
  /// - `tipOffsetRatio.x` thuộc [-maxTipOffsetRatio, +maxTipOffsetRatio]:
  ///   âm là Ép-phê Trái, dương là Ép-phê Phải.
  /// - `tipOffsetRatio.y` thuộc [-maxTipOffsetRatio, +maxTipOffsetRatio]:
  ///   dương là Cao cơ / Cu-lê (12h), âm là Thấp cơ / Trô (6h).
  /// Luôn được đảm bảo nằm trong miền tròn hợp lệ `length <= maxTipOffsetRatio`.
  final Vec2 tipOffsetRatio;

  /// Góc nâng chuôi cơ (radian) cho các cú đánh Piqué / Massé (0 = cơ phẳng song song mặt bàn).
  final double cueElevationRadians;

  /// Tâm vùng gom bi mục tiêu (nếu có) tính bằng mét.
  final Vec2? targetZoneCenterMeters;

  /// Bán kính vùng gom bi mục tiêu (nếu có) tính bằng mét.
  final double? targetZoneRadiusMeters;

  ShotInput({
    required this.cueBallPosition,
    required this.objectBall1Position,
    required this.objectBall2Position,
    required Vec2 aimDirection,
    required this.cueSpeed,
    Vec2 tipOffsetRatio = Vec2.zero,
    this.cueElevationRadians = 0.0,
    this.targetZoneCenterMeters,
    this.targetZoneRadiusMeters,
    double maxTipOffsetRatio = 0.80,
  })  : aimDirection =
            aimDirection.length > 1e-9 ? aimDirection.normalized : Vec2.unitX,
        tipOffsetRatio = clampTipOffsetToDisk(
          tipOffsetRatio,
          maxRadius: maxTipOffsetRatio,
        );

  /// Quy đổi chuẩn từ mức lực `speedLevel` (1..5) trên UI sang vận tốc ngọn cơ `v_cue` (m/s).
  /// Hàm đơn điệu tăng nghiêm ngặt:
  /// - Level 1: 0.90 m/s (Chạm êm / Seri dọc băng)
  /// - Level 2: 1.65 m/s (Kiểm soát / Amorti / Gom bi ngắn)
  /// - Level 3: 2.55 m/s (Trung bình chuẩn / Gom 2 băng / Bộ số)
  /// - Level 4: 3.60 m/s (Mạnh / Khứ hồi dọc bàn / 3 băng)
  /// - Level 5: 4.80 m/s (Tối đa)
  static double cueSpeedFromLevel(int speedLevel, {double fineScale = 1.0}) {
    final clamped = speedLevel.clamp(1, 5);
    const speeds = <double>[0.90, 1.65, 2.55, 3.60, 4.80];
    return speeds[clamped - 1] * fineScale;
  }

  /// Quy đổi đơn điệu từ `speedLevel` (1..5) có xét vận tốc tham chiếu `referenceCueSpeed` tại `referenceSpeedLevel`.
  /// Đảm bảo với mọi bài học: tăng `speedLevel` từ 1 -> 5 luôn làm tăng nghiêm ngặt vận tốc đầu cơ `v_cue`.
  static double calibratedCueSpeedForLevel({
    required int activeSpeedLevel,
    required int referenceSpeedLevel,
    double? referenceCueSpeed,
  }) {
    if (referenceCueSpeed == null || referenceCueSpeed <= 0.0) {
      return cueSpeedFromLevel(activeSpeedLevel);
    }
    final baseAtRef = cueSpeedFromLevel(referenceSpeedLevel);
    final scale = referenceCueSpeed / baseAtRef;
    return cueSpeedFromLevel(activeSpeedLevel, fineScale: scale);
  }

  /// Chiếu điểm chạm đầu cơ `(dx, dy)` vào hình tròn hợp lệ bán kính `maxRadius` (circular valid domain).
  static Vec2 clampTipOffsetToDisk(
    Vec2 rawOffset, {
    double maxRadius = 0.80,
  }) {
    final r = rawOffset.length;
    if (r <= maxRadius || r <= 1e-12) {
      return rawOffset;
    }
    return rawOffset * (maxRadius / r);
  }

  /// Quy đổi từ số mũi cơ `horizontalTips` (-4..+4) và `verticalTips` (-4..+4)
  /// sang tỉ lệ bán kính vật lý `tipOffsetRatio` trong hình tròn bán kính `maxTipOffsetRatio`.
  static Vec2 tipOffsetRatioFromTips({
    required double horizontalTips,
    required double verticalTips,
    double maxTips = 4.0,
    double maxTipOffsetRatio = 0.80,
  }) {
    final raw = Vec2(
      (horizontalTips / maxTips) * maxTipOffsetRatio,
      (verticalTips / maxTips) * maxTipOffsetRatio,
    );
    return clampTipOffsetToDisk(raw, maxRadius: maxTipOffsetRatio);
  }

  /// Quy đổi điểm chạm đầu cơ sang đơn vị mét thực tế trên mặt cầu bi chủ `(x_tip, z_tip)`.
  Vec2 tipOffsetMeters(TableConfig config) {
    final clamped = clampTipOffsetToDisk(
      tipOffsetRatio,
      maxRadius: config.maxTipOffsetRatio,
    );
    return clamped * config.ballRadius;
  }

  /// Kiểm tra tính hợp lệ hình học & vật lý của `ShotInput` với dung sai số học `toleranceMeters`.
  /// Không tự ý dịch chuyển vị trí các bi.
  ShotInputValidationResult validate(
    TableConfig config, {
    double toleranceMeters = positionValidationToleranceMeters,
  }) {
    final issues = <ShotInputValidationIssue>[];
    final r = config.ballRadius;
    final l = config.lengthMeters;
    final w = config.widthMeters;

    bool isFiniteVec(Vec2 v) => v.x.isFinite && v.y.isFinite;

    if (!isFiniteVec(cueBallPosition) ||
        !isFiniteVec(objectBall1Position) ||
        !isFiniteVec(objectBall2Position) ||
        !isFiniteVec(aimDirection) ||
        !cueSpeed.isFinite) {
      issues.add(
        const ShotInputValidationIssue(
          code: ShotInputValidationErrorCode.nonFiniteValue,
          message: 'Tọa độ bi hoặc vận tốc đầu cơ chứa giá trị không hữu hạn (NaN/Infinity).',
        ),
      );
      return ShotInputValidationResult(issues);
    }

    if (cueSpeed < 0.0) {
      issues.add(
        ShotInputValidationIssue(
          code: ShotInputValidationErrorCode.invalidCueSpeed,
          message: 'Vận tốc đầu cơ không được âm (cueSpeed = $cueSpeed m/s).',
        ),
      );
    }

    void checkBounds(BallId id, Vec2 pos) {
      if (pos.x < r - toleranceMeters ||
          pos.x > l - r + toleranceMeters ||
          pos.y < r - toleranceMeters ||
          pos.y > w - r + toleranceMeters) {
        issues.add(
          ShotInputValidationIssue(
            code: ShotInputValidationErrorCode.ballOutOfBounds,
            primaryBall: id,
            message:
                'Viên bi $id tại (${pos.x.toStringAsFixed(4)}, ${pos.y.toStringAsFixed(4)}) m nằm ngoài biên lòng bàn [${r.toStringAsFixed(4)}, ${(l - r).toStringAsFixed(4)}] x [${r.toStringAsFixed(4)}, ${(w - r).toStringAsFixed(4)}] m.',
          ),
        );
      }
    }

    checkBounds(BallId.cue, cueBallPosition);
    checkBounds(BallId.object1, objectBall1Position);
    checkBounds(BallId.object2, objectBall2Position);

    final twoR = 2.0 * r;
    void checkPair(BallId idA, Vec2 posA, BallId idB, Vec2 posB) {
      final dist = posA.distanceTo(posB);
      if (dist < twoR - toleranceMeters) {
        issues.add(
          ShotInputValidationIssue(
            code: ShotInputValidationErrorCode.ballsOverlapping,
            primaryBall: idA,
            secondaryBall: idB,
            message:
                'Hai viên bi $idA và $idB chồng lấp lên nhau: khoảng cách tâm = ${dist.toStringAsFixed(5)} m < 2R = ${twoR.toStringAsFixed(5)} m.',
          ),
        );
      }
    }

    checkPair(BallId.cue, cueBallPosition, BallId.object1, objectBall1Position);
    checkPair(BallId.cue, cueBallPosition, BallId.object2, objectBall2Position);
    checkPair(
      BallId.object1,
      objectBall1Position,
      BallId.object2,
      objectBall2Position,
    );

    return ShotInputValidationResult(issues);
  }

  double get aimAngleRadians => math.atan2(aimDirection.y, aimDirection.x);

  ShotInput copyWith({
    Vec2? cueBallPosition,
    Vec2? objectBall1Position,
    Vec2? objectBall2Position,
    Vec2? aimDirection,
    double? cueSpeed,
    Vec2? tipOffsetRatio,
    double? cueElevationRadians,
    Vec2? targetZoneCenterMeters,
    double? targetZoneRadiusMeters,
  }) {
    return ShotInput(
      cueBallPosition: cueBallPosition ?? this.cueBallPosition,
      objectBall1Position: objectBall1Position ?? this.objectBall1Position,
      objectBall2Position: objectBall2Position ?? this.objectBall2Position,
      aimDirection: aimDirection ?? this.aimDirection,
      cueSpeed: cueSpeed ?? this.cueSpeed,
      tipOffsetRatio: tipOffsetRatio ?? this.tipOffsetRatio,
      cueElevationRadians: cueElevationRadians ?? this.cueElevationRadians,
      targetZoneCenterMeters:
          targetZoneCenterMeters ?? this.targetZoneCenterMeters,
      targetZoneRadiusMeters:
          targetZoneRadiusMeters ?? this.targetZoneRadiusMeters,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotInput &&
          cueBallPosition == other.cueBallPosition &&
          objectBall1Position == other.objectBall1Position &&
          objectBall2Position == other.objectBall2Position &&
          aimDirection == other.aimDirection &&
          cueSpeed == other.cueSpeed &&
          tipOffsetRatio == other.tipOffsetRatio &&
          cueElevationRadians == other.cueElevationRadians &&
          targetZoneCenterMeters == other.targetZoneCenterMeters &&
          targetZoneRadiusMeters == other.targetZoneRadiusMeters);

  @override
  int get hashCode => Object.hash(
        cueBallPosition,
        objectBall1Position,
        objectBall2Position,
        aimDirection,
        cueSpeed,
        tipOffsetRatio,
        cueElevationRadians,
        targetZoneCenterMeters,
        targetZoneRadiusMeters,
      );
}
