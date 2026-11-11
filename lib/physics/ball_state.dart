import 'vector_math.dart';

/// Định danh 3 viên bi trong Billiard Carom.
enum BallId {
  /// Bi chủ (Trắng / Chấm đỏ Aramith)
  cue,

  /// Bi mục tiêu 1 (Vàng)
  object1,

  /// Bi mục tiêu 2 (Đỏ)
  object2,
}

/// Pha chuyển động tức thời của viên bi trên mặt vải.
enum MotionPhase {
  /// Đứng yên hoàn toàn (v = 0, omega = 0).
  stationary,

  /// Đang trượt trên vải (vận tốc trượt tại điểm tiếp xúc u = v + omega x (-R k) != 0).
  sliding,

  /// Đang lăn thuần túy không trượt (u = 0, v = R * (omega x k)).
  rolling,

  /// Tâm bi đứng yên nhưng còn tự xoay quanh trục đứng (v = 0, wz != 0).
  spinning,
}

/// Trạng thái vật lý đầy đủ của một viên bi tại một thời điểm t.
class BallState {
  final BallId id;

  /// Vị trí tâm bi trên mặt bàn (m): (x, y) với z = R.
  final Vec2 position;

  /// Vận tốc tịnh tiến trên mặt bàn (m/s): (vx, vy).
  final Vec2 velocity;

  /// Vận tốc góc 3D (rad/s): (wx, wy, wz) trong hệ trục thuận tay phải (+z hướng lên).
  /// - wx, wy: thành phần lăn / cu-lê (topspin) / trô (backspin) / massé ngang.
  /// - wz: thành phần ép-phê ngang quanh trục thẳng đứng (sidespin / English).
  final Vec3 angularVelocity;

  /// Hướng xoay 3D tích lũy của viên bi (dùng để vẽ chính xác các chấm đỏ Aramith).
  final Quat orientation;

  /// Pha chuyển động hiện tại.
  final MotionPhase phase;

  const BallState({
    required this.id,
    required this.position,
    this.velocity = Vec2.zero,
    this.angularVelocity = Vec3.zero,
    this.orientation = Quat.identity,
    this.phase = MotionPhase.stationary,
  });

  /// Vận tốc trượt tại điểm tiếp xúc đáy bi (0, 0, -R) với mặt vải bàn:
  /// `u = v + omega x (-R * k) = (vx - R * wy, vy + R * wx)`
  Vec2 clothSlipVelocity(double ballRadius) => Vec2(
        velocity.x - ballRadius * angularVelocity.y,
        velocity.y + ballRadius * angularVelocity.x,
      );

  bool get isMovingLinear => velocity.lengthSquared > 1e-8;

  bool get isSpinning => angularVelocity.lengthSquared > 1e-6;

  bool get isCompletelyAtRest => !isMovingLinear && !isSpinning;

  static MotionPhase classifyPhase({
    required Vec2 velocity,
    required Vec3 angularVelocity,
    required double ballRadius,
    double linearEps = 1e-4,
    double slipEps = 2e-4,
    double spinEps = 1e-3,
  }) {
    final vLen = velocity.length;
    final slip = Vec2(
      velocity.x - ballRadius * angularVelocity.y,
      velocity.y + ballRadius * angularVelocity.x,
    ).length;

    if (vLen <= linearEps && slip <= slipEps) {
      if (angularVelocity.z.abs() > spinEps) {
        return MotionPhase.spinning;
      }
      return MotionPhase.stationary;
    }
    if (slip > slipEps) {
      return MotionPhase.sliding;
    }
    return MotionPhase.rolling;
  }

  BallState copyWith({
    Vec2? position,
    Vec2? velocity,
    Vec3? angularVelocity,
    Quat? orientation,
    MotionPhase? phase,
  }) {
    return BallState(
      id: id,
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      angularVelocity: angularVelocity ?? this.angularVelocity,
      orientation: orientation ?? this.orientation,
      phase: phase ?? this.phase,
    );
  }

  static BallState interpolate(BallState a, BallState b, double t) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    return BallState(
      id: a.id,
      position: Vec2.lerp(a.position, b.position, t),
      velocity: Vec2.lerp(a.velocity, b.velocity, t),
      angularVelocity: Vec3.lerp(a.angularVelocity, b.angularVelocity, t),
      orientation: Quat.slerp(a.orientation, b.orientation, t),
      phase: t < 0.5 ? a.phase : b.phase,
    );
  }
}

