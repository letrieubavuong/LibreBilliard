import 'dart:math' as math;
import 'ball_state.dart';
import 'collisions.dart';
import 'cue_strike.dart';
import 'shot_input.dart';
import 'simulation_result.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Engine Mô phỏng Vật lý Billiard Carom 3 Bi (Đơn vị SI: m, s, kg, rad).
/// Hoàn toàn độc lập với giao diện Flutter/Canvas.
class CaromPhysicsEngine {
  final TableConfig config;

  /// Bước thời gian tích phân vật lý cơ sở (1 ms = 1000 Hz) kết hợp chia nhỏ bước tại thời điểm va chạm (CCD).
  final double timeStepSeconds;

  /// Chu kỳ ghi nhận Snapshot cho bộ phát lại quỹ đạo (mặc định 1/60 s ~ 16.67 ms).
  final double snapshotIntervalSeconds;

  /// Thời gian mô phỏng tối đa (s) để tránh vòng lặp vô tận khi thông số ma sát bằng 0.
  final double maxSimulationSeconds;

  const CaromPhysicsEngine({
    this.config = TableConfig.standardCarom,
    this.timeStepSeconds = 0.001,
    this.snapshotIntervalSeconds = 1.0 / 60.0,
    this.maxSimulationSeconds = 14.0,
  });

  /// Chạy mô phỏng đầy đủ cho một cú đánh `input` và trả về `SimulationResult`.
  SimulationResult simulate(ShotInput input) {
    final R = config.ballRadius;

    // 1. Khởi tạo 3 viên bi (đảm bảo nằm trong lòng bàn và không chồng lấp ở t = 0)
    final initialPositions = _sanitizeInitialPositions(
      cue: input.cueBallPosition,
      obj1: input.objectBall1Position,
      obj2: input.objectBall2Position,
    );

    final sanitizedInput = input.copyWith(
      cueBallPosition: initialPositions.cue,
      objectBall1Position: initialPositions.obj1,
      objectBall2Position: initialPositions.obj2,
    );

    BallState cue = CueStrikePhysics.computePostStrikeCueBallState(
      input: sanitizedInput,
      config: config,
    );
    BallState obj1 = BallState(
      id: BallId.object1,
      position: initialPositions.obj1,
    );
    BallState obj2 = BallState(
      id: BallId.object2,
      position: initialPositions.obj2,
    );

    final snapshots = <SimulationSnapshot>[
      SimulationSnapshot(
        timestamp: 0.0,
        cueBall: cue,
        objectBall1: obj1,
        objectBall2: obj2,
      ),
    ];
    final collisionEvents = <CollisionEvent>[];

    double currentTime = 0.0;
    double nextSnapshotTime = snapshotIntervalSeconds;
    SimulationTerminationReason reason =
        SimulationTerminationReason.maxTimeReached;

    while (currentTime < maxSimulationSeconds) {
      if (cue.isCompletelyAtRest &&
          obj1.isCompletelyAtRest &&
          obj2.isCompletelyAtRest) {
        reason = SimulationTerminationReason.allBallsStopped;
        break;
      }

      double remainingDt =
          math.min(timeStepSeconds, maxSimulationSeconds - currentTime);
      int subStepGuard = 0;

      while (remainingDt > 1e-9 && subStepGuard < 16) {
        subStepGuard++;

        // Tìm sự kiện va chạm sớm nhất (CCD) trong khoảng [0, remainingDt]
        final earliest = _findEarliestCollision(
          cue: cue,
          obj1: obj1,
          obj2: obj2,
          maxDt: remainingDt,
        );

        if (earliest != null) {
          final tau = earliest.time;
          if (tau > 1e-9) {
            cue = advanceBallOnCloth(cue, config, tau);
            obj1 = advanceBallOnCloth(obj1, config, tau);
            obj2 = advanceBallOnCloth(obj2, config, tau);
            currentTime += tau;
            remainingDt -= tau;
          }

          // Giải xung lượng va chạm tại đúng thời điểm currentTime
          if (earliest.isBallBall) {
            final pair = _getBallPair(
              cue: cue,
              obj1: obj1,
              obj2: obj2,
              idA: earliest.ballA,
              idB: earliest.ballB!,
            );
            final resolved = CollisionPhysics.resolveBallBallCollision(
              ball1: pair.a,
              ball2: pair.b,
              config: config,
              timestamp: currentTime,
            );
            if (resolved.event.normalImpulse > 1e-9) {
              collisionEvents.add(resolved.event);
            }
            final updated = _setBallPair(
              cue: cue,
              obj1: obj1,
              obj2: obj2,
              newA: resolved.ball1,
              newB: resolved.ball2,
            );
            cue = updated.cue;
            obj1 = updated.obj1;
            obj2 = updated.obj2;
          } else {
            final target = _getBallById(
              cue: cue,
              obj1: obj1,
              obj2: obj2,
              id: earliest.ballA,
            );
            final resolved = CollisionPhysics.resolveBallCushionCollision(
              ball: target,
              cushion: earliest.cushion!,
              config: config,
              timestamp: currentTime,
            );
            if (resolved.event.normalImpulse > 1e-9) {
              collisionEvents.add(resolved.event);
            }
            final updated = _setSingleBall(
              cue: cue,
              obj1: obj1,
              obj2: obj2,
              newBall: resolved.ball,
            );
            cue = updated.cue;
            obj1 = updated.obj1;
            obj2 = updated.obj2;
          }

          // Ghi snapshot ngay tại thời điểm va chạm để quỹ đạo gãy khúc sắc nét tại điểm chạm
          if (snapshots.last.timestamp < currentTime - 1e-6) {
            snapshots.add(
              SimulationSnapshot(
                timestamp: currentTime,
                cueBall: cue,
                objectBall1: obj1,
                objectBall2: obj2,
              ),
            );
          }

          // Nếu tau == 0, nhích nhẹ thời gian còn lại để tránh lặp cùng một sự kiện
          if (tau <= 1e-9) {
            final tinyDt = math.min(remainingDt, 1e-5);
            cue = advanceBallOnCloth(cue, config, tinyDt);
            obj1 = advanceBallOnCloth(obj1, config, tinyDt);
            obj2 = advanceBallOnCloth(obj2, config, tinyDt);
            currentTime += tinyDt;
            remainingDt -= tinyDt;
          }
        } else {
          cue = advanceBallOnCloth(cue, config, remainingDt);
          obj1 = advanceBallOnCloth(obj1, config, remainingDt);
          obj2 = advanceBallOnCloth(obj2, config, remainingDt);
          currentTime += remainingDt;
          remainingDt = 0.0;
        }

        // Bảo hiểm chống chồng lấp hình học do sai số làm tròn dấu phẩy động
        final separated = _enforceMinimumSeparation(
          cue: cue,
          obj1: obj1,
          obj2: obj2,
          ballRadius: R,
        );
        cue = separated.cue;
        obj1 = separated.obj1;
        obj2 = separated.obj2;
      }

      if (currentTime >= nextSnapshotTime) {
        snapshots.add(
          SimulationSnapshot(
            timestamp: currentTime,
            cueBall: cue,
            objectBall1: obj1,
            objectBall2: obj2,
          ),
        );
        nextSnapshotTime = currentTime + snapshotIntervalSeconds;
      }
    }

    if (cue.isCompletelyAtRest &&
        obj1.isCompletelyAtRest &&
        obj2.isCompletelyAtRest) {
      reason = SimulationTerminationReason.allBallsStopped;
    }

    if (snapshots.last.timestamp < currentTime - 1e-7 || snapshots.length == 1) {
      snapshots.add(
        SimulationSnapshot(
          timestamp: currentTime,
          cueBall: cue,
          objectBall1: obj1,
          objectBall2: obj2,
        ),
      );
    }

    return SimulationResult(
      config: config,
      input: sanitizedInput,
      snapshots: snapshots,
      collisionEvents: collisionEvents,
      durationSeconds: currentTime,
      terminationReason: reason,
    );
  }

  /// Tích phân trạng thái của một viên bi trên mặt vải bàn trong khoảng `dt` (s).
  /// Xử lý chính xác sự chuyển pha từ Trượt (Sliding) -> Lăn thuần túy (Rolling) -> Dừng hẳn (Stationary)
  /// mà không bao giờ gây dao động đổi dấu vận tốc trượt `u`.
  static BallState advanceBallOnCloth(
    BallState ball,
    TableConfig config,
    double dt,
  ) {
    if (dt <= 0.0 || ball.isCompletelyAtRest) return ball;

    final R = config.ballRadius;
    final g = config.gravity;
    final muS = config.slidingFriction;
    final muR = config.rollingFriction;
    final alphaZ = config.spinDecelerationRate;

    double decayWz(double wz, double tau) {
      if (wz.abs() <= 1e-9 || alphaZ <= 0.0) return wz;
      final drop = alphaZ * tau;
      if (wz.abs() <= drop) return 0.0;
      return wz > 0.0 ? wz - drop : wz + drop;
    }

    Vec2 pos = ball.position;
    Vec2 vel = ball.velocity;
    Vec3 omega = ball.angularVelocity;
    Quat orient = ball.orientation;
    double rem = dt;

    // 1. Pha Trượt (Sliding Phase): u = (vx - R*wy, vy + R*wx) != 0
    final slip = Vec2(vel.x - R * omega.y, vel.y + R * omega.x);
    final slipSpeed = slip.length;

    if (slipSpeed > 1e-5) {
      if (muS > 0.0) {
        final uHat = slip / slipSpeed;
        // Tốc độ suy giảm vận tốc trượt: du/dt = -(7/2) * mu_s * g
        final slipDecayRate = 3.5 * muS * g;
        final timeToPureRoll = slipSpeed / slipDecayRate;

        final slideDt = math.min(rem, timeToPureRoll);
        final linAccel = -uHat * (muS * g);
        final angAccelX = -(2.5 * muS * g / R) * uHat.y;
        final angAccelY = (2.5 * muS * g / R) * uHat.x;

        final nextPos = pos + vel * slideDt + linAccel * (0.5 * slideDt * slideDt);
        final nextVel = vel + linAccel * slideDt;
        final nextWz = decayWz(omega.z, slideDt);

        Vec3 nextOmega;
        if (slideDt >= timeToPureRoll - 1e-9) {
          // Chuyển chính xác sang lăn thuần túy (u = 0): wx = -vy/R, wy = vx/R
          nextOmega = Vec3(-nextVel.y / R, nextVel.x / R, nextWz);
        } else {
          nextOmega = Vec3(
            omega.x + angAccelX * slideDt,
            omega.y + angAccelY * slideDt,
            nextWz,
          );
        }

        final avgOmega = Vec3.lerp(omega, nextOmega, 0.5);
        orient = orient.integrateAngularVelocity(avgOmega, slideDt);
        pos = config.clampBallPositionMeters(nextPos);
        vel = nextVel;
        omega = nextOmega;
        rem -= slideDt;
      } else {
        // Không có ma sát trượt (mu_s == 0): giữ nguyên vận tốc thẳng và vận tốc góc ngang
        final nextPos = pos + vel * rem;
        final nextWz = decayWz(omega.z, rem);
        final nextOmega = Vec3(omega.x, omega.y, nextWz);
        orient = orient.integrateAngularVelocity(nextOmega, rem);
        pos = config.clampBallPositionMeters(nextPos);
        omega = nextOmega;
        rem = 0.0;
      }
    }

    // 2. Pha Lăn thuần túy (Pure Rolling Phase): u == 0
    if (rem > 1e-9) {
      final speed = vel.length;
      if (speed > 1e-5) {
        if (muR > 0.0) {
          final rollDecel = muR * g;
          final timeToStop = speed / rollDecel;
          final rollDt = math.min(rem, timeToStop);
          final vHat = vel / speed;
          final linAccel = -vHat * rollDecel;

          final nextPos =
              pos + vel * rollDt + linAccel * (0.5 * rollDt * rollDt);
          final Vec2 nextVel =
              rollDt >= timeToStop - 1e-9 ? Vec2.zero : vel + linAccel * rollDt;
          final nextWz = decayWz(omega.z, rem);
          final nextOmega = Vec3(-nextVel.y / R, nextVel.x / R, nextWz);

          final avgOmega = Vec3.lerp(omega, nextOmega, 0.5);
          orient = orient.integrateAngularVelocity(avgOmega, rem);
          pos = config.clampBallPositionMeters(nextPos);
          vel = nextVel;
          omega = nextOmega;
        } else {
          final nextPos = pos + vel * rem;
          final nextWz = decayWz(omega.z, rem);
          final nextOmega = Vec3(-vel.y / R, vel.x / R, nextWz);
          orient = orient.integrateAngularVelocity(nextOmega, rem);
          pos = config.clampBallPositionMeters(nextPos);
          omega = nextOmega;
        }
      } else {
        // Đứng yên tịnh tiến, chỉ còn tắt dần wz (nếu có)
        vel = Vec2.zero;
        final nextWz = decayWz(omega.z, rem);
        final nextOmega = Vec3(0.0, 0.0, nextWz);
        final avgOmega = Vec3(0.0, 0.0, 0.5 * (omega.z + nextWz));
        orient = orient.integrateAngularVelocity(avgOmega, rem);
        omega = nextOmega;
      }
    }

    final phase = BallState.classifyPhase(
      velocity: vel,
      angularVelocity: omega,
      ballRadius: R,
    );

    return ball.copyWith(
      position: pos,
      velocity: vel,
      angularVelocity: omega,
      orientation: orient,
      phase: phase,
    );
  }

  _CandidateCollision? _findEarliestCollision({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required double maxDt,
  }) {
    final R = config.ballRadius;
    _CandidateCollision? best;

    void consider(_CandidateCollision candidate) {
      if (best == null || candidate.time < best!.time) {
        best = candidate;
      }
    }

    final tC1 = CollisionPhysics.findBallBallImpactTime(
      ballA: cue,
      ballB: obj1,
      ballRadius: R,
      maxDt: maxDt,
    );
    if (tC1 != null) {
      consider(_CandidateCollision.ballBall(tC1, BallId.cue, BallId.object1));
    }

    final tC2 = CollisionPhysics.findBallBallImpactTime(
      ballA: cue,
      ballB: obj2,
      ballRadius: R,
      maxDt: maxDt,
    );
    if (tC2 != null) {
      consider(_CandidateCollision.ballBall(tC2, BallId.cue, BallId.object2));
    }

    final t12 = CollisionPhysics.findBallBallImpactTime(
      ballA: obj1,
      ballB: obj2,
      ballRadius: R,
      maxDt: maxDt,
    );
    if (t12 != null) {
      consider(
          _CandidateCollision.ballBall(t12, BallId.object1, BallId.object2));
    }

    for (final b in [cue, obj1, obj2]) {
      final hitCushion = CollisionPhysics.findBallCushionImpactTime(
        ball: b,
        config: config,
        maxDt: maxDt,
      );
      if (hitCushion != null) {
        consider(
          _CandidateCollision.ballCushion(
            hitCushion.time,
            b.id,
            hitCushion.cushion,
          ),
        );
      }
    }

    return best;
  }

  ({Vec2 cue, Vec2 obj1, Vec2 obj2}) _sanitizeInitialPositions({
    required Vec2 cue,
    required Vec2 obj1,
    required Vec2 obj2,
  }) {
    final minSep = 2.0 * config.ballRadius + 1e-5;
    Vec2 c = config.clampBallPositionMeters(cue);
    Vec2 o1 = config.clampBallPositionMeters(obj1);
    Vec2 o2 = config.clampBallPositionMeters(obj2);

    ({Vec2 a, Vec2 b}) sep(Vec2 a, Vec2 b, double wA, double wB) {
      final d = b - a;
      final len = d.length;
      if (len >= minSep) return (a: a, b: b);
      final n = len > 1e-9 ? d / len : const Vec2(0.70710678, 0.70710678);
      final overlap = minSep - len;
      return (
        a: config.clampBallPositionMeters(a - n * (overlap * wA)),
        b: config.clampBallPositionMeters(b + n * (overlap * wB)),
      );
    }

    for (int i = 0; i < 4; i++) {
      final s12 = sep(o1, o2, 0.5, 0.5);
      o1 = s12.a;
      o2 = s12.b;
      final sC1 = sep(c, o1, 1.0, 0.0);
      c = sC1.a;
      final sC2 = sep(c, o2, 1.0, 0.0);
      c = sC2.a;
    }

    return (cue: c, obj1: o1, obj2: o2);
  }

  ({BallState cue, BallState obj1, BallState obj2}) _enforceMinimumSeparation({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required double ballRadius,
  }) {
    final minDist = 2.0 * ballRadius;
    BallState c = cue;
    BallState o1 = obj1;
    BallState o2 = obj2;

    ({BallState a, BallState b}) checkPair(BallState a, BallState b) {
      final delta = b.position - a.position;
      final dist = delta.length;
      if (dist >= minDist - 1e-7) return (a: a, b: b);
      final n = dist > 1e-9 ? delta / dist : Vec2.unitX;
      final corr = (minDist - dist + 1e-7) * 0.5;
      return (
        a: a.copyWith(
          position: config.clampBallPositionMeters(a.position - n * corr),
        ),
        b: b.copyWith(
          position: config.clampBallPositionMeters(b.position + n * corr),
        ),
      );
    }

    final p1 = checkPair(c, o1);
    c = p1.a;
    o1 = p1.b;
    final p2 = checkPair(c, o2);
    c = p2.a;
    o2 = p2.b;
    final p3 = checkPair(o1, o2);
    o1 = p3.a;
    o2 = p3.b;

    return (cue: c, obj1: o1, obj2: o2);
  }

  BallState _getBallById({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required BallId id,
  }) {
    switch (id) {
      case BallId.cue:
        return cue;
      case BallId.object1:
        return obj1;
      case BallId.object2:
        return obj2;
    }
  }

  ({BallState a, BallState b}) _getBallPair({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required BallId idA,
    required BallId idB,
  }) {
    return (
      a: _getBallById(cue: cue, obj1: obj1, obj2: obj2, id: idA),
      b: _getBallById(cue: cue, obj1: obj1, obj2: obj2, id: idB),
    );
  }

  ({BallState cue, BallState obj1, BallState obj2}) _setSingleBall({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required BallState newBall,
  }) {
    switch (newBall.id) {
      case BallId.cue:
        return (cue: newBall, obj1: obj1, obj2: obj2);
      case BallId.object1:
        return (cue: cue, obj1: newBall, obj2: obj2);
      case BallId.object2:
        return (cue: cue, obj1: obj1, obj2: newBall);
    }
  }

  ({BallState cue, BallState obj1, BallState obj2}) _setBallPair({
    required BallState cue,
    required BallState obj1,
    required BallState obj2,
    required BallState newA,
    required BallState newB,
  }) {
    final step1 = _setSingleBall(
      cue: cue,
      obj1: obj1,
      obj2: obj2,
      newBall: newA,
    );
    return _setSingleBall(
      cue: step1.cue,
      obj1: step1.obj1,
      obj2: step1.obj2,
      newBall: newB,
    );
  }
}

class _CandidateCollision {
  final double time;
  final bool isBallBall;
  final BallId ballA;
  final BallId? ballB;
  final CushionId? cushion;

  const _CandidateCollision.ballBall(this.time, this.ballA, this.ballB)
      : isBallBall = true,
        cushion = null;

  const _CandidateCollision.ballCushion(this.time, this.ballA, this.cushion)
      : isBallBall = false,
        ballB = null;
}

