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

  /// Khoảng cách tâm thực tế giữa hai bi tại thời điểm sự kiện CCD (m) (đối với `ballBall`).
  final double? centerDistanceMeters;

  /// Độ dày chạm thực tế `f = 1 - sin(theta)` thuộc `[0, 1]` tại thời điểm va chạm `ballBall`.
  final double? effectiveContactFraction;

  /// Dấu lệch bên thực tế tại thời điểm va chạm `ballBall`:
  /// `+1` tương ứng má trái (`ContactSide.left`), `-1` tương ứng má phải (`ContactSide.right`), `0` trực diện.
  final double? effectiveLateralSign;

  const CollisionEvent({
    required this.timestamp,
    required this.type,
    required this.primaryBall,
    this.secondaryBall,
    this.cushion,
    required this.contactPointMeters,
    required this.normalImpulse,
    required this.tangentialImpulse,
    this.centerDistanceMeters,
    this.effectiveContactFraction,
    this.effectiveLateralSign,
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
  /// Tìm thời điểm va chạm sớm nhất `tau` trong khoảng `[0, maxDt]` giữa hai bi chuyển động
  /// có gia tốc không đổi `a_A`, `a_B` trong cùng một pha chuyển động:
  /// `p_i(t) = p_i0 + v_i0 * t + 0.5 * a_i * t^2`.
  /// Khớp chính xác 100% phương trình tích phân quỹ đạo của `CaromPhysicsEngine.advanceBallOnCloth`.
  static double? findBallBallImpactTime({
    required BallState ballA,
    required BallState ballB,
    required double ballRadius,
    required double maxDt,
    TableConfig? config,
  }) {
    if (maxDt <= 0.0) return null;

    final dp0 = ballB.position - ballA.position;
    final dv0 = ballB.velocity - ballA.velocity;
    final da = config != null
        ? (ballB.linearAccelerationOnCloth(config) -
            ballA.linearAccelerationOnCloth(config))
        : Vec2.zero;

    final twoR = 2.0 * ballRadius;
    final targetDistSq = twoR * twoR;

    Vec2 relPos(double t) => dp0 + dv0 * t + da * (0.5 * t * t);
    Vec2 relVel(double t) => dv0 + da * t;
    double f(double t) => relPos(t).lengthSquared - targetDistSq;
    double df(double t) => 2.0 * relPos(t).dot(relVel(t));

    final f0 = f(0.0);
    final df0 = df(0.0);

    // Nếu hai bi đã chạm sát bề mặt (trong dung sai số học) và đang lao vào nhau (df(0) < 0)
    if (f0 <= 1e-12 && df0 < -1e-11) {
      return 0.0;
    }

    // Kiểm tra nhanh khi gia tốc tương đối bằng 0 (chuyển động thẳng đều)
    if (da.lengthSquared <= 1e-16) {
      if (df0 >= -1e-11) return null;
      final a = dv0.lengthSquared;
      if (a <= 1e-14) return null;
      final b = dp0.dot(dv0);
      final disc = b * b - a * f0;
      if (disc < 0.0) return null;
      final tau = (-b - math.sqrt(disc)) / a;
      if (tau >= -1e-12 && tau <= maxDt) {
        return tau.clamp(0.0, maxDt);
      }
      return null;
    }

    // Với quỹ đạo bậc hai có gia tốc không đổi trên bước nhỏ [0, maxDt]:
    // Chia [0, maxDt] thành N đoạn nhỏ + điểm cực trị gần đúng t_min = -dp0.dot(dv0) / dv0.lengthSquared
    // để định vị chính xác khoảng đổi dấu đầu tiên [tL, tR] có f(tL) > 0 và f(tR) <= 0.
    final sampleTimes = <double>[0.0];
    if (dv0.lengthSquared > 1e-14) {
      final tLinMin = (-dp0.dot(dv0) / dv0.lengthSquared).clamp(0.0, maxDt);
      if (tLinMin > 1e-12 && tLinMin < maxDt - 1e-12) {
        sampleTimes.add(tLinMin);
      }
      final b = dp0.dot(dv0);
      final a = dv0.lengthSquared;
      final disc = b * b - a * f0;
      if (disc >= 0.0) {
        final tLinRoot = ((-b - math.sqrt(disc)) / a).clamp(0.0, maxDt);
        if (tLinRoot > 1e-12 && tLinRoot < maxDt - 1e-12) {
          sampleTimes.add(tLinRoot);
        }
      }
    }
    const int subdivisions = 8;
    for (int i = 1; i <= subdivisions; i++) {
      sampleTimes.add(maxDt * (i / subdivisions));
    }
    sampleTimes.sort();

    double? bracketL;
    double? bracketR;
    double prevT = 0.0;
    double prevF = f0;

    for (int i = 1; i < sampleTimes.length; i++) {
      final currT = sampleTimes[i];
      if (currT <= prevT + 1e-15) continue;
      final currF = f(currT);
      if (prevF > 0.0 && currF <= 0.0) {
        bracketL = prevT;
        bracketR = currT;
        break;
      }
      prevT = currT;
      prevF = currF;
    }

    if (bracketL == null || bracketR == null) {
      return null;
    }

    // Tinh chỉnh nghiệm t* trên [bracketL, bracketR] bằng thuật toán lai Newton-Raphson & Chia đôi (10 bước)
    double lo = bracketL;
    double hi = bracketR;
    double tStar = 0.5 * (lo + hi);

    for (int iter = 0; iter < 10; iter++) {
      final val = f(tStar);
      if (val.abs() <= 1e-15) break;
      if (val > 0.0) {
        lo = tStar;
      } else {
        hi = tStar;
      }
      final deriv = df(tStar);
      if (deriv < -1e-12) {
        final newton = tStar - val / deriv;
        if (newton > lo && newton < hi) {
          tStar = newton;
          continue;
        }
      }
      tStar = 0.5 * (lo + hi);
    }

    if (df(tStar) < -1e-11) {
      return tStar.clamp(0.0, maxDt);
    }
    return null;
  }

  /// Tìm thời điểm va chạm sớm nhất `tau` trong khoảng `[0, maxDt]` giữa một viên bi chuyển động
  /// có gia tốc không đổi `a = ball.linearAccelerationOnCloth(config)` và 4 thành băng.
  static ({double time, CushionId cushion})? findBallCushionImpactTime({
    required BallState ball,
    required TableConfig config,
    required double maxDt,
  }) {
    if (maxDt <= 0.0) return null;

    final r = config.ballRadius;
    final l = config.lengthMeters;
    final w = config.widthMeters;
    final pos = ball.position;
    final vel = ball.velocity;
    final acc = ball.linearAccelerationOnCloth(config);

    double? bestTime;
    CushionId? bestCushion;

    void checkBoundary1D({
      required double p0,
      required double v0,
      required double a,
      required double targetBound,
      required double outwardSign, // -1 cho biên dưới (R), +1 cho biên trên (L-R hoặc W-R)
      required CushionId cushion,
    }) {
      // Nếu đã ở sát biên và vận tốc đang hướng ra ngoài lòng bàn (vào băng)
      if ((p0 - targetBound) * outwardSign >= -1e-12 &&
          v0 * outwardSign > 1e-9) {
        if (bestTime == null || 0.0 < bestTime!) {
          bestTime = 0.0;
          bestCushion = cushion;
        }
        return;
      }

      // Giải phương trình bậc hai: 0.5 * a * t^2 + v0 * t + (p0 - targetBound) = 0
      final c = p0 - targetBound;
      if (a.abs() <= 1e-12) {
        if (v0 * outwardSign <= 1e-9) return;
        final t = -c / v0;
        if (t >= -1e-12 && t <= maxDt) {
          final clamped = t.clamp(0.0, maxDt);
          if (bestTime == null || clamped < bestTime!) {
            bestTime = clamped;
            bestCushion = cushion;
          }
        }
        return;
      }

      final halfA = 0.5 * a;
      final disc = v0 * v0 - 4.0 * halfA * c;
      if (disc < 0.0) return;
      final sqrtDisc = math.sqrt(disc);
      final roots = <double>[
        (-v0 - sqrtDisc) / (2.0 * halfA),
        (-v0 + sqrtDisc) / (2.0 * halfA),
      ]..sort();

      for (final root in roots) {
        if (root >= -1e-12 && root <= maxDt) {
          final vAtRoot = v0 + a * root;
          if (vAtRoot * outwardSign > 1e-9) {
            final clamped = root.clamp(0.0, maxDt);
            if (bestTime == null || clamped < bestTime!) {
              bestTime = clamped;
              bestCushion = cushion;
            }
            break;
          }
        }
      }
    }

    checkBoundary1D(
      p0: pos.x,
      v0: vel.x,
      a: acc.x,
      targetBound: r,
      outwardSign: -1.0,
      cushion: CushionId.shortNear,
    );
    checkBoundary1D(
      p0: pos.x,
      v0: vel.x,
      a: acc.x,
      targetBound: l - r,
      outwardSign: 1.0,
      cushion: CushionId.shortFar,
    );
    checkBoundary1D(
      p0: pos.y,
      v0: vel.y,
      a: acc.y,
      targetBound: r,
      outwardSign: -1.0,
      cushion: CushionId.longLeft,
    );
    checkBoundary1D(
      p0: pos.y,
      v0: vel.y,
      a: acc.y,
      targetBound: w - r,
      outwardSign: 1.0,
      cushion: CushionId.longRight,
    );

    if (bestTime != null && bestCushion != null) {
      return (time: bestTime!, cushion: bestCushion!);
    }
    return null;
  }

  /// Giải va chạm đàn hồi + ma sát tiếp tuyến Coulomb giữa hai viên bi `ball1` và `ball2`.
  /// Bảo toàn động lượng tuyến tính tuyệt đối, không tự sinh năng lượng (`E_after <= E_before`),
  /// và truyền xoáy ngang (throw + spin transfer).
  ///
  /// Giới hạn mô hình: Tiếp xúc bi–bi xét xung lượng tiếp tuyến trong mặt phẳng ngang và trục đứng `omega_z`
  /// (mô hình chuẩn cho các cú đánh phẳng và Piqué/Massé vừa phải).
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
    final r = config.ballRadius;
    final m = config.ballMass;
    final e = config.restitutionBallBall.clamp(0.0, 1.0);
    final muBb = math.max(0.0, config.ballBallFriction);

    final delta = ball2.position - ball1.position;
    final dist = delta.length;
    final n = dist > 1e-12 ? delta / dist : Vec2.unitX;
    final t = n.perpCCW; // (-n.y, n.x)

    final p1 = ball1.position;
    final p2 = ball2.position;

    // Vận tốc tiếp cận theo phương pháp tuyến n (từ bi 1 sang bi 2)
    final relVel = ball1.velocity - ball2.velocity;
    final approachingSpeed = relVel.dot(n);

    // Tính độ dày chạm thực tế f = 1 - sin(theta) và dấu lệch bên tại điểm chạm
    double? effectiveFraction;
    double? effectiveLateralSign;
    final relSpeed = relVel.length;
    if (relSpeed > 1e-9 && approachingSpeed > 0.0) {
      final relDir = relVel / relSpeed;
      final cosTheta = relDir.dot(n).clamp(0.0, 1.0);
      final sinTheta = math.sqrt(math.max(0.0, 1.0 - cosTheta * cosTheta));
      effectiveFraction = (1.0 - sinTheta).clamp(0.0, 1.0);
      // Nếu bi 1 va vào bi 2 đứng yên, tâm bi 1 tại va chạm lệch khỏi tâm bi 2 theo hướng -n.
      // Trong hệ quy chiếu nhìn từ bi 1 sang bi 2 (xấp xỉ hướng relDir):
      // (-n) . relDir.perpCCW > 0 tương ứng chạm má trái (lateralSign = +1), < 0 tương ứng má phải (-1).
      final latProj = (-n).dot(relDir.perpCCW);
      effectiveLateralSign =
          latProj.abs() <= 1e-4 ? 0.0 : (latProj > 0.0 ? 1.0 : -1.0);
    }

    if (approachingSpeed <= 0.0) {
      return (
        ball1: ball1,
        ball2: ball2,
        event: CollisionEvent(
          timestamp: timestamp,
          type: CollisionType.ballBall,
          primaryBall: ball1.id,
          secondaryBall: ball2.id,
          contactPointMeters: Vec2.lerp(p1, p2, 0.5),
          normalImpulse: 0.0,
          tangentialImpulse: 0.0,
          centerDistanceMeters: dist,
          effectiveContactFraction: effectiveFraction,
          effectiveLateralSign: effectiveLateralSign,
        ),
      );
    }

    // Xung lượng pháp tuyến: J_n = (1 + e) * s / (1/m1 + 1/m2) = 0.5 * m * (1 + e) * s
    final jNormal = 0.5 * m * (1.0 + e) * approachingSpeed;

    // Vận tốc trượt tiếp tuyến tương đối tại điểm tiếp xúc:
    // Điểm chạm là +R*n trên bi 1 và -R*n trên bi 2 => thành phần do wz là R*(w1z + w2z)*t
    final vTangentRel =
        relVel.dot(t) + r * (ball1.angularVelocity.z + ball2.angularVelocity.z);

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
    final deltaWz = -(2.5 * jTangent) / (m * r);
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
        ballRadius: r,
      ),
    );
    final nextBall2 = ball2.copyWith(
      position: p2,
      velocity: newV2,
      angularVelocity: newOmega2,
      phase: BallState.classifyPhase(
        velocity: newV2,
        angularVelocity: newOmega2,
        ballRadius: r,
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
        centerDistanceMeters: dist,
        effectiveContactFraction: effectiveFraction,
        effectiveLateralSign: effectiveLateralSign,
      ),
    );
  }

  /// Giải va chạm giữa viên bi và thành băng cao su (`cushion`) từ xung lượng 3D nhất quán:
  /// - Xung lượng pháp tuyến `J_n = m * (1 + e_bc) * v_n_in` cho `v_n_out = e_bc * v_n_in`.
  /// - Xung lượng ma sát tiếp tuyến ngang `J_t` giới hạn bởi Coulomb `|J_t| <= mu_bc * J_n` và ngưỡng không đảo chiều trượt `|J_t| <= (2/7) * m * |v_t - R * wz|`,
  ///   cập nhật đồng thời `v_t_out = v_t_in + J_t / m` và `wz_out = wz - (5 / (2 m R)) * J_t`.
  /// - Ma sát mặt mũi băng ở độ cao `cushionContactHeightRatio` cản trở thành phần xoáy ngang dọc trục băng `omega_t = omega_xy . t`
  ///   với xung lượng `|J_k| <= mu_bc * (1 + noseHeightOffsetRatio) * J_n`, làm giảm `|omega_t|` về 0 mà không bao giờ tự sinh spin khi `omega_xy == 0` hoặc `mu_bc == 0`.
  ///
  /// Định lý bảo toàn / tiêu hao năng lượng:
  /// Với mọi `0 <= e_bc <= 1`, mọi `mu_bc >= 0`, mọi vận tốc tới `v` và mọi spin 3D `omega`:
  /// `E_after <= E_before` (đẳng thức đạt chính xác khi `e_bc == 1` và `mu_bc == 0`).
  static ({
    BallState ball,
    CollisionEvent event,
  }) resolveBallCushionCollision({
    required BallState ball,
    required CushionId cushion,
    required TableConfig config,
    required double timestamp,
  }) {
    final r = config.ballRadius;
    final m = config.ballMass;
    final eBc = config.restitutionBallCushion.clamp(0.0, 1.0);
    final muBc = math.max(0.0, config.ballCushionFriction);

    final n = cushion.inwardNormal; // Pháp tuyến hướng vào lòng bàn
    final t = cushion.tangent; // Tiếp tuyến dọc băng sao cho n x t = +k

    final pos = ball.position;
    final vIn = ball.velocity;

    // Tốc độ lao vào băng (dương khi đi ngược chiều inwardNormal)
    final vNormalIn = -vIn.dot(n);
    if (vNormalIn <= 0.0) {
      return (
        ball: ball,
        event: CollisionEvent(
          timestamp: timestamp,
          type: CollisionType.ballCushion,
          primaryBall: ball.id,
          cushion: cushion,
          contactPointMeters: pos - n * r,
          normalImpulse: 0.0,
          tangentialImpulse: 0.0,
        ),
      );
    }

    final vTangentIn = vIn.dot(t);
    final jNormal = m * (1.0 + eBc) * vNormalIn;

    // 1. Thành phần trượt tiếp tuyến ngang tại điểm tiếp xúc (-R * n): u_t = v_t - R * wz
    final wz = ball.angularVelocity.z;
    final vSlipTangent = vTangentIn - r * wz;

    double jTangent = 0.0;
    if (muBc > 0.0 && vSlipTangent.abs() > 1e-9) {
      final maxGripImpulse = (2.0 / 7.0) * m * vSlipTangent.abs();
      final coulombLimit = muBc * jNormal;
      final mag = math.min(coulombLimit, maxGripImpulse);
      jTangent = vSlipTangent > 0.0 ? -mag : mag;
    }

    final vNormalOut = eBc * vNormalIn;
    final vTangentOut = vTangentIn + (jTangent / m);
    final newVel = n * vNormalOut + t * vTangentOut;
    final newWz = wz - (2.5 * jTangent) / (m * r);

    // 2. Thành phần vận tốc góc ngang omega_xy = omega_n * n + omega_t * t:
    // - omega_n (quanh trục pháp tuyến n) bảo toàn vì mô-men tại (-R * n) vuông góc với n.
    // - omega_t (xoáy cu-lê / trô vuông góc với mặt băng) chịu mô-men cản ma sát tại mũi băng
    //   có độ cao chuẩn hóa `cushionContactHeightRatio` (lệch tâm đứng beta = max(0, 2*h_ratio - 1)).
    final omegaXY = Vec2(ball.angularVelocity.x, ball.angularVelocity.y);
    final omegaN = omegaXY.dot(n);
    final omegaT = omegaXY.dot(t);

    double newOmegaT = omegaT;
    if (muBc > 0.0 && omegaT.abs() > 1e-9) {
      final noseHeightOffsetRatio =
          math.max(0.0, 2.0 * config.cushionContactHeightRatio - 1.0);
      final maxSpinDrop =
          (2.5 * muBc * (1.0 + noseHeightOffsetRatio) * jNormal) / (m * r);
      if (omegaT.abs() <= maxSpinDrop) {
        newOmegaT = 0.0;
      } else {
        newOmegaT = omegaT > 0.0 ? omegaT - maxSpinDrop : omegaT + maxSpinDrop;
      }
    }

    final newOmegaXY = n * omegaN + t * newOmegaT;
    final newOmega = Vec3(newOmegaXY.x, newOmegaXY.y, newWz);

    final nextBall = ball.copyWith(
      position: pos,
      velocity: newVel,
      angularVelocity: newOmega,
      phase: BallState.classifyPhase(
        velocity: newVel,
        angularVelocity: newOmega,
        ballRadius: r,
      ),
    );

    return (
      ball: nextBall,
      event: CollisionEvent(
        timestamp: timestamp,
        type: CollisionType.ballCushion,
        primaryBall: ball.id,
        cushion: cushion,
        contactPointMeters: pos - n * r,
        normalImpulse: jNormal,
        tangentialImpulse: jTangent.abs(),
      ),
    );
  }
}
