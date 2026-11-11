import 'dart:math' as math;
import 'table_config.dart';
import 'vector_math.dart';

/// Đầu vào vật lý đầy đủ và tường minh của một cú đánh Billiard Carom.
/// Hoàn toàn độc lập với UI (không phụ thuộc Widget/Canvas).
class ShotInput {
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
