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
///
/// Đặc tính kỹ thuật:
/// - Kiểm tra nghiêm ngặt đầu vào `input.validate(config)` với dung sai số học `1e-6 m`
///   (ném `ShotInputValidationException` nếu bi chồng lấp hoặc vượt biên thay vì âm thầm dịch chuyển thế bi).
/// - Mỗi bước con `[0, subDt]` được giới hạn bởi thời điểm chuyển pha sớm nhất `timeToNextPhaseTransition`
///   của cả 3 bi, đảm bảo gia tốc `a_i` của mỗi bi là hằng số trên toàn đoạn `[0, subDt]`.
/// - Bộ tìm thời điểm va chạm CCD (`CollisionPhysics.findBallBallImpactTime` & `findBallCushionImpactTime`)
///   và bộ tiến trạng thái (`advanceBallOnCloth`) dùng chung phương trình quỹ đạo bậc hai chính xác
///   `p_i(t) = p_i0 + v_i0 * t + 0.5 * a_i * t^2`, đạt khoảng cách tiếp xúc `||p_i(t*) - p_j(t*)|| = 2R`
///   với sai số `< 1e-12 m` mà không cần đẩy vị trí nhân tạo.
class CaromPhysicsEngine {
  final TableConfig config;

  /// Bước thời gian tích phân vật lý cơ sở (1 ms = 1000 Hz) kết hợp chia nhỏ bước tại chuyển pha & va chạm (CCD).
  final double timeStepSeconds;

  /// Chu kỳ ghi nhận Snapshot cho bộ phát lại quỹ đạo (mặc định 1/60 s ~ 16.67 ms).
  final double snapshotIntervalSeconds;

  /// Thời gian mô phỏng tối đa (s) để tránh vòng lặp vô tận khi thông số ma sát bằng 0.
  final double maxSimulationSeconds;

  /// Bộ đếm số lần `simulate` được thực thi (phục vụ kiểm thử xác minh cache và tách biệt render/physics).
  static int debugSimulationRunCount = 0;

  const CaromPhysicsEngine({
    this.config = TableConfig.standardCarom,
    this.timeStepSeconds = 0.001,
    this.snapshotIntervalSeconds = 1.0 / 60.0,
    this.maxSimulationSeconds = 14.0,
  });

  /// Chạy mô phỏng đầy đủ cho một cú đánh `input` và trả về `SimulationResult`.
  /// Ném `ShotInputValidationException` nếu `input` không hợp lệ (chồng lấp hoặc ngoài biên bàn quá `1e-6 m`).
  SimulationResult simulate(ShotInput input) {
    debugSimulationRunCount++;

    final validation = input.validate(config);
    if (!validation.isValid) {
      throw ShotInputValidationException(validation);
    }

    // Chỉ khử sai số làm tròn dấu phẩy động dưới ngưỡng 1e-6 m tại biên bàn
    final cleanInput = input.copyWith(
      cueBallPosition: config.clampBallPositionMeters(input.cueBallPosition),
      objectBall1Position:
          config.clampBallPositionMeters(input.objectBall1Position),
      objectBall2Position:
          config.clampBallPositionMeters(input.objectBall2Position),
    );

    BallState cue = CueStrikePhysics.computePostStrikeCueBallState(
      input: cleanInput,
      config: config,
    );
    BallState obj1 = BallState(
      id: BallId.object1,
      position: cleanInput.objectBall1Position,
    );
    BallState obj2 = BallState(
      id: BallId.object2,
      position: cleanInput.objectBall2Position,
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

    while (currentTime < maxSimulationSeconds - 1e-12) {
      if (cue.isCompletelyAtRest &&
          obj1.isCompletelyAtRest &&
          obj2.isCompletelyAtRest) {
        reason = SimulationTerminationReason.allBallsStopped;
        break;
      }

      double remainingDt =
          math.min(timeStepSeconds, maxSimulationSeconds - currentTime);
      int subStepGuard = 0;

      while (remainingDt > 1e-12 && subStepGuard < 24) {
        subStepGuard++;

        // Giới hạn bước con theo thời điểm chuyển pha sớm nhất (Trượt -> Lăn hoặc Lăn -> Dừng)
        // để trên đoạn [0, phaseBoundedDt], gia tốc của cả 3 bi đều hoàn toàn không đổi.
        double phaseBoundedDt = remainingDt;
        for (final b in [cue, obj1, obj2]) {
          final tPhase = b.timeToNextPhaseTransition(config);
          if (tPhase > 1e-9 && tPhase < phaseBoundedDt) {
            phaseBoundedDt = tPhase;
          }
        }

        // Tìm sự kiện va chạm sớm nhất (CCD) trên quỹ đạo bậc hai trong khoảng [0, phaseBoundedDt]
        final earliest = _findEarliestCollision(
          cue: cue,
          obj1: obj1,
          obj2: obj2,
          maxDt: phaseBoundedDt,
        );

        if (earliest != null) {
          final tau = earliest.time;
          if (tau > 1e-12) {
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

          // Ghi snapshot ngay tại thời điểm va chạm để quỹ đạo và nội suy giữa các snapshot chính xác
          if (snapshots.last.timestamp < currentTime - 1e-7) {
            snapshots.add(
              SimulationSnapshot(
                timestamp: currentTime,
                cueBall: cue,
                objectBall1: obj1,
                objectBall2: obj2,
              ),
            );
          }

          // Nếu sự kiện xảy ra ngay tại tau == 0, tiến một vi bước để thoát khỏi mặt tiếp xúc vừa giải
          if (tau <= 1e-12) {
            final tinyDt = math.min(remainingDt, 1e-6);
            if (tinyDt > 0.0) {
              cue = advanceBallOnCloth(cue, config, tinyDt);
              obj1 = advanceBallOnCloth(obj1, config, tinyDt);
              obj2 = advanceBallOnCloth(obj2, config, tinyDt);
              currentTime += tinyDt;
              remainingDt -= tinyDt;
            }
          }
        } else {
          cue = advanceBallOnCloth(cue, config, phaseBoundedDt);
          obj1 = advanceBallOnCloth(obj1, config, phaseBoundedDt);
          obj2 = advanceBallOnCloth(obj2, config, phaseBoundedDt);
          currentTime += phaseBoundedDt;
          remainingDt -= phaseBoundedDt;
        }
      }

      if (currentTime >= nextSnapshotTime - 1e-9) {
        if (snapshots.last.timestamp < currentTime - 1e-7) {
          snapshots.add(
            SimulationSnapshot(
              timestamp: currentTime,
              cueBall: cue,
              objectBall1: obj1,
              objectBall2: obj2,
            ),
          );
        }
        nextSnapshotTime = currentTime + snapshotIntervalSeconds;
      }
    }

    if (cue.isCompletelyAtRest &&
        obj1.isCompletelyAtRest &&
        obj2.isCompletelyAtRest) {
      reason = SimulationTerminationReason.allBallsStopped;
    }

    if (snapshots.last.timestamp < currentTime - 1e-7 ||
        snapshots.length == 1) {
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
      input: cleanInput,
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

    final r = config.ballRadius;
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
    final slip = Vec2(vel.x - r * omega.y, vel.y + r * omega.x);
    final slipSpeed = slip.length;

    if (slipSpeed > 1e-5) {
      if (muS > 0.0) {
        final uHat = slip / slipSpeed;
        // Tốc độ suy giảm vận tốc trượt: du/dt = -(7/2) * mu_s * g
        final slipDecayRate = 3.5 * muS * g;
        final timeToPureRoll = slipSpeed / slipDecayRate;

        final slideDt = math.min(rem, timeToPureRoll);
        final linAccel = -uHat * (muS * g);
        final angAccelX = -(2.5 * muS * g / r) * uHat.y;
        final angAccelY = (2.5 * muS * g / r) * uHat.x;

        final nextPos =
            pos + vel * slideDt + linAccel * (0.5 * slideDt * slideDt);
        final nextVel = vel + linAccel * slideDt;
        final nextWz = decayWz(omega.z, slideDt);

        Vec3 nextOmega;
        if (slideDt >= timeToPureRoll - 1e-9) {
          // Chuyển chính xác sang lăn thuần túy (u = 0): wx = -vy/R, wy = vx/R
          nextOmega = Vec3(-nextVel.y / r, nextVel.x / r, nextWz);
        } else {
          nextOmega = Vec3(
            omega.x + angAccelX * slideDt,
            omega.y + angAccelY * slideDt,
            nextWz,
          );
        }

        final avgOmega = Vec3.lerp(omega, nextOmega, 0.5);
        orient = orient.integrateAngularVelocity(avgOmega, slideDt);
        pos = nextPos;
        vel = nextVel;
        omega = nextOmega;
        rem -= slideDt;
      } else {
        // Không có ma sát trượt (mu_s == 0): giữ nguyên vận tốc thẳng và vận tốc góc ngang
        final nextPos = pos + vel * rem;
        final nextWz = decayWz(omega.z, rem);
        final nextOmega = Vec3(omega.x, omega.y, nextWz);
        orient = orient.integrateAngularVelocity(nextOmega, rem);
        pos = nextPos;
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
          final nextOmega = Vec3(-nextVel.y / r, nextVel.x / r, nextWz);

          final avgOmega = Vec3.lerp(omega, nextOmega, 0.5);
          orient = orient.integrateAngularVelocity(avgOmega, rem);
          pos = nextPos;
          vel = nextVel;
          omega = nextOmega;
        } else {
          final nextPos = pos + vel * rem;
          final nextWz = decayWz(omega.z, rem);
          final nextOmega = Vec3(-vel.y / r, vel.x / r, nextWz);
          orient = orient.integrateAngularVelocity(nextOmega, rem);
          pos = nextPos;
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
      ballRadius: r,
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
    final r = config.ballRadius;
    _CandidateCollision? best;

    void consider(_CandidateCollision candidate) {
      if (best == null || candidate.time < best!.time) {
        best = candidate;
      }
    }

    final tC1 = CollisionPhysics.findBallBallImpactTime(
      ballA: cue,
      ballB: obj1,
      ballRadius: r,
      maxDt: maxDt,
      config: config,
    );
    if (tC1 != null) {
      consider(_CandidateCollision.ballBall(tC1, BallId.cue, BallId.object1));
    }

    final tC2 = CollisionPhysics.findBallBallImpactTime(
      ballA: cue,
      ballB: obj2,
      ballRadius: r,
      maxDt: maxDt,
      config: config,
    );
    if (tC2 != null) {
      consider(_CandidateCollision.ballBall(tC2, BallId.cue, BallId.object2));
    }

    final t12 = CollisionPhysics.findBallBallImpactTime(
      ballA: obj1,
      ballB: obj2,
      ballRadius: r,
      maxDt: maxDt,
      config: config,
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
