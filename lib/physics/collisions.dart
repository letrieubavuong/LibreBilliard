import 'dart:math' as math;
import 'ball_state.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Loại sự kiện va chạm vật lý được ghi nhận trong quá trình mô phỏng.
enum CollisionType {
  ballBall,
  ballCushion,
}

/// Sự kiện va chạm thực tế (chỉ được sinh ra khi hai vật thể thực sự tiếp xúc vật lý).
class CollisionEvent {
  /// Thời điểm xảy ra va chạm tính từ lúc đầu cơ chạm bi chủ (s).
  final double timestamp;

  /// Loại va chạm: bi-bi hoặc bi-băng.
  final CollisionType type;

  /// Viên bi thứ nhất tham gia va chạm.
  final BallId primaryBall;

  /// Viên bi thứ hai (nếu `type == CollisionType.ballBall`).
  final BallId? secondaryBall;

  /// Thành băng va chạm (nếu `type == CollisionType.ballCushion`).
  final CushionId? cushion;

  /// Tọa độ điểm tiếp xúc trên mặt bàn (m).
  final Vec2 contactPointMeters;

  /// Độ lớn xung lượng pháp tuyến `J_n` (N*s).
  final double normalImpulse;

  /// Độ lớn xung lượng tiếp tuyến `J_t` (N*s).
  final double tangentialImpulse;

  const CollisionEvent({
    required this.timestamp,
    required this.type,
    required this.primaryBall,
    this.secondaryBall,
    this.cushion,
    required this.contactPointMeters,
    required this.normalImpulse,
    required this.tangentialImpulse,
  });

  bool involvesBall(BallId id) => primaryBall == id || secondaryBall == id;

  bool isBetweenBalls(BallId a, BallId b) =>
      type == CollisionType.ballBall &&
      ((primaryBall == a && secondaryBall == b) ||
          (primaryBall == b && secondaryBall == a));
}

/// Bộ giải Phát hiện Va chạm Liên tục (Continuous Collision Detection - CCD)
/// và Giải Xung lượng Va chạm Vật rắn 3D (Bi-Bi & Bi-Băng).
class CollisionPhysics {
  /// Tìm thời điểm va chạm sớm nhất `tau` trong khoảng `[0, maxDt]` giữa hai bi chuyển động thẳng đều trong bước nhỏ.
  /// Trả về `null` nếu hai bi không va chạm trong bước này.
  static double? findBallBallImpactTime({
    required BallState ballA,
    required BallState ballB,
    required double ballRadius,
    required double maxDt,
  }) {
    final dp = ballB.position - ballA.position;
    final dv = ballB.velocity - ballA.velocity;

    // Điều kiện hai tâm bi đang tiến lại gần nhau: dp . dv < 0
    final b = dp.dot(dv);
    if (b >= -1e-11) return null;

    final twoR = 2.0 * ballRadius;
    final c = dp.lengthSquared - twoR * twoR;

    // Nếu hai bi đã chạm sát bề mặt (do sai số dấu phẩy động) và đang lao vào nhau
    if (c <= 0.0) {
      return 0.0;
    }

    final a = dv.lengthSquared;
    if (a <= 1e-14) return null;

    final disc = b * b - a * c;
    if (disc < 0.0) return null;

    final tau = (-b - math.sqrt(disc)) / a;
    if (tau >= -1e-9 && tau <= maxDt) {
      return tau.clamp(0.0, maxDt);
    }
    return null;
  }

  /// Tìm thời điểm va chạm sớm nhất `tau` trong khoảng `[0, maxDt]` giữa một viên bi và 4 thành băng.
  static ({double time, CushionId cushion})? findBallCushionImpactTime({
    required BallState ball,
    required TableConfig config,
    required double maxDt,
  }) {
    final R = config.ballRadius;
    final L = config.lengthMeters;
    final W = config.widthMeters;
    final pos = ball.position;
    final vel = ball.velocity;

    double? bestTime;
    CushionId? bestCushion;

    void checkCandidate(double t, CushionId c) {
      if (t >= -1e-9 && t <= maxDt) {
        final clampedT = t.clamp(0.0, maxDt);
        if (bestTime == null || clampedT < bestTime!) {
          bestTime = clampedT;
          bestCushion = c;
        }
      }
    }

    if (vel.x < -1e-9) {
      final t = pos.x <= R ? 0.0 : (R - pos.x) / vel.x;
      checkCandidate(t, CushionId.shortNear);
    } else if (vel.x > 1e-9) {
      final t = pos.x >= L - R ? 0.0 : ((L - R) - pos.x) / vel.x;
      checkCandidate(t, CushionId.shortFar);
    }

    if (vel.y < -1e-9) {
      final t = pos.y <= R ? 0.0 : (R - pos.y) / vel.y;
      checkCandidate(t, CushionId.longLeft);
    } else if (vel.y > 1e-9) {
      final t = pos.y >= W - R ? 0.0 : ((W - R) - pos.y) / vel.y;
      checkCandidate(t, CushionId.longRight);
    }

    if (bestTime != null && bestCushion != null) {
      return (time: bestTime!, cushion: bestCushion!);
    }
    return null;
  }

  /// Giải va chạm đàn hồi + ma sát tiếp tuyến Coulomb giữa hai viên bi `ball1` và `ball2`.
  /// Bảo toàn động lượng tuyến tính tuyệt đối và truyền xoáy ngang (throw + spin transfer).
  static ({
    BallState ball1,
    BallState ball2,
    CollisionEvent event,
  }) resolveBallBallCollision({
    required BallState ball1,
    required BallState ball2,
    required TableConfig config,
    required double timestamp,
  }) {
    final R = config.ballRadius;
    final m = config.ballMass;
    final e = config.restitutionBallBall;
    final muBb = config.ballBallFriction;

    final delta = ball2.position - ball1.position;
    final dist = delta.length;
    final n = dist > 1e-12 ? delta / dist : Vec2.unitX;
    final t = n.perpCCW; // (-n.y, n.x)

    // Đảm bảo hai tâm bi cách nhau đúng >= 2R (khử sai số số học nếu có)
    Vec2 p1 = ball1.position;
    Vec2 p2 = ball2.position;
    final twoR = 2.0 * R;
    if (dist < twoR) {
      final corr = (twoR - dist + 1e-7) * 0.5;
      p1 = p1 - n * corr;
      p2 = p2 + n * corr;
    }

    // Vận tốc tiếp cận theo phương pháp tuyến n (từ bi 1 sang bi 2)
    final relVel = ball1.velocity - ball2.velocity;
    final approachingSpeed = relVel.dot(n);

    if (approachingSpeed <= 0.0) {
      return (
        ball1: ball1.copyWith(position: p1),
        ball2: ball2.copyWith(position: p2),
        event: CollisionEvent(
          timestamp: timestamp,
          type: CollisionType.ballBall,
          primaryBall: ball1.id,
          secondaryBall: ball2.id,
          contactPointMeters: Vec2.lerp(p1, p2, 0.5),
          normalImpulse: 0.0,
          tangentialImpulse: 0.0,
        ),
      );
    }

    // Xung lượng pháp tuyến: J_n = (1 + e) * s / (1/m1 + 1/m2) = 0.5 * m * (1 + e) * s
    final jNormal = 0.5 * m * (1.0 + e) * approachingSpeed;

    // Vận tốc trượt tiếp tuyến tương đối tại điểm tiếp xúc:
    // Điểm chạm là +R*n trên bi 1 và -R*n trên bi 2 => thành phần do wz là R*(w1z + w2z)*t
    final vTangentRel =
        relVel.dot(t) + R * (ball1.angularVelocity.z + ball2.angularVelocity.z);

    double jTangent = 0.0;
    if (muBb > 0.0 && vTangentRel.abs() > 1e-9) {
      final maxGripImpulse = (m / 7.0) * vTangentRel.abs();
      final coulombLimit = muBb * jNormal;
      final mag = math.min(coulombLimit, maxGripImpulse);
      jTangent = vTangentRel > 0.0 ? mag : -mag;
    }

    final impulseVec = n * jNormal + t * jTangent;
    final newV1 = ball1.velocity - impulseVec / m;
    final newV2 = ball2.velocity + impulseVec / m;

    // Cập nhật vận tốc góc wz do xung lượng tiếp tuyến jTangent:
    // Mô-men xoắn trên cả 2 bi tại điểm chạm (+R*n và -R*n) đều bằng -R * jTangent * k
    final deltaWz = -(2.5 * jTangent) / (m * R);
    final newOmega1 = Vec3(
      ball1.angularVelocity.x,
      ball1.angularVelocity.y,
      ball1.angularVelocity.z + deltaWz,
    );
    final newOmega2 = Vec3(
      ball2.angularVelocity.x,
      ball2.angularVelocity.y,
      ball2.angularVelocity.z + deltaWz,
    );

    final nextBall1 = ball1.copyWith(
      position: p1,
      velocity: newV1,
      angularVelocity: newOmega1,
      phase: BallState.classifyPhase(
        velocity: newV1,
        angularVelocity: newOmega1,
        ballRadius: R,
      ),
    );
    final nextBall2 = ball2.copyWith(
      position: p2,
      velocity: newV2,
      angularVelocity: newOmega2,
      phase: BallState.classifyPhase(
        velocity: newV2,
        angularVelocity: newOmega2,
        ballRadius: R,
      ),
    );

    return (
      ball1: nextBall1,
      ball2: nextBall2,
      event: CollisionEvent(
        timestamp: timestamp,
        type: CollisionType.ballBall,
        primaryBall: ball1.id,
        secondaryBall: ball2.id,
        contactPointMeters: Vec2.lerp(p1, p2, 0.5),
        normalImpulse: jNormal,
        tangentialImpulse: jTangent.abs(),
      ),
    );
  }

  /// Giải va chạm giữa viên bi và thành băng cao su (`cushion`) với đàn hồi pháp tuyến `e_bc`
  /// và ma sát tiếp tuyến Coulomb `mu_bc` phụ thuộc vào vận tốc tới và ép-phê ngang `omega_z`.
  static ({
    BallState ball,
    CollisionEvent event,
  }) resolveBallCushionCollision({
    required BallState ball,
    required CushionId cushion,
    required TableConfig config,
    required double timestamp,
  }) {
    final R = config.ballRadius;
    final m = config.ballMass;
    final eBc = config.restitutionBallCushion;
    final muBc = config.ballCushionFriction;

    final n = cushion.inwardNormal; // Pháp tuyến hướng vào lòng bàn
    final t = cushion.tangent; // Tiếp tuyến dọc băng sao cho n x t = +k

    final pos = config.clampBallPositionMeters(ball.position);
    final vIn = ball.velocity;

    // Tốc độ lao vào băng (dương khi đi ngược chiều inwardNormal)
    final vNormalIn = -vIn.dot(n);
    if (vNormalIn <= 0.0) {
      return (
        ball: ball.copyWith(position: pos),
        event: CollisionEvent(
          timestamp: timestamp,
          type: CollisionType.ballCushion,
          primaryBall: ball.id,
          cushion: cushion,
          contactPointMeters: pos - n * R,
          normalImpulse: 0.0,
          tangentialImpulse: 0.0,
        ),
      );
    }

    final vTangentIn = vIn.dot(t);
    final jNormal = m * (1.0 + eBc) * vNormalIn;

    // Vận tốc trượt tiếp tuyến của bề mặt bi tại mũi băng (-R * n):
    // v_slip_t = v_t - R * omega_z
    final wz = ball.angularVelocity.z;
    final vSlipTangent = vTangentIn - R * wz;

    double jTangent = 0.0;
    if (muBc > 0.0 && vSlipTangent.abs() > 1e-9) {
      final maxGripImpulse = (2.0 / 7.0) * m * vSlipTangent.abs();
      final coulombLimit = muBc * jNormal;
      final mag = math.min(coulombLimit, maxGripImpulse);
      jTangent = vSlipTangent > 0.0 ? -mag : mag;
    }

    // Thành phần cu-lê / trô vuông góc mặt băng (topspin/backspin into cushion):
    // Trục lăn thuận hướng vào băng là k x (-n) = -t
    final incomingNormalRoll =
        -(ball.angularVelocity.x * t.x + ball.angularVelocity.y * t.y);
    final normalRollBoost =
        (incomingNormalRoll * R * 0.12).clamp(-0.35 * vNormalIn, 0.35 * vNormalIn);

    final vNormalOut = math.max(0.02 * vNormalIn, eBc * vNormalIn + normalRollBoost);
    final vTangentOut = vTangentIn + (jTangent / m);
    final newVel = n * vNormalOut + t * vTangentOut;

    // Cập nhật wz sau khi ăn băng
    final newWz = wz - (2.5 * jTangent) / (m * R);

    // Cập nhật vận tốc góc ngang sau khi dội băng (chuyển một phần sang lăn theo hướng bật ra)
    final naturalOutRollAxis = Vec3(-newVel.y, newVel.x, 0.0);
    final dampedHorizontalOmega = Vec3(
      ball.angularVelocity.x * 0.35 + naturalOutRollAxis.x / R * 0.65,
      ball.angularVelocity.y * 0.35 + naturalOutRollAxis.y / R * 0.65,
      newWz,
    );

    final nextBall = ball.copyWith(
      position: pos,
      velocity: newVel,
      angularVelocity: dampedHorizontalOmega,
      phase: BallState.classifyPhase(
        velocity: newVel,
        angularVelocity: dampedHorizontalOmega,
        ballRadius: R,
      ),
    );

    return (
      ball: nextBall,
      event: CollisionEvent(
        timestamp: timestamp,
        type: CollisionType.ballCushion,
        primaryBall: ball.id,
        cushion: cushion,
        contactPointMeters: pos - n * R,
        normalImpulse: jNormal,
        tangentialImpulse: jTangent.abs(),
      ),
    );
  }
}

