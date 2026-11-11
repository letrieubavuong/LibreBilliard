import 'dart:math' as math;
import 'ball_state.dart';
import 'shot_input.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Kết quả chi tiết của va chạm Đầu cơ – Bi chủ (phục vụ kiểm chứng bảo toàn năng lượng & xung lượng).
class CueStrikeMechanicsResult {
  final BallState cueBall;
  final double impulseMagnitude;
  final double postStrikeCueSpeed;
  final double initialCueKineticEnergy;
  final double postStrikeCueKineticEnergy;
  final double postStrikeBallKineticEnergy;

  const CueStrikeMechanicsResult({
    required this.cueBall,
    required this.impulseMagnitude,
    required this.postStrikeCueSpeed,
    required this.initialCueKineticEnergy,
    required this.postStrikeCueKineticEnergy,
    required this.postStrikeBallKineticEnergy,
  });

  double get postStrikeTotalKineticEnergy =>
      postStrikeCueKineticEnergy + postStrikeBallKineticEnergy;
}

/// Mô hình vật lý va chạm Đầu cơ - Bi chủ (Cue-to-Ball Strike Mechanics):
///
/// Từ phương trình xung lượng - mô-men động lượng của quả cầu đặc bán kính `R`, khối lượng `m`,
/// mô-men quán tính `I = (2/5) m R^2` và khối lượng hiệu dụng của cây cơ `M_c`:
/// - Xung lực truyền từ đầu cơ có vận tốc `v_cue` tại điểm chạm lệch tâm `b = sqrt(x_tip^2 + z_tip^2)`:
///   `J = (M_c * m * (1 + e_tip) * v_cue) / (m + M_c * (1 + (5 / (2 R^2)) * (x_tip^2 + z_tip^2)))`
/// - Khối lượng hiệu dụng của bi tại điểm tiếp xúc:
///   `m_eff = m / (1 + (5 / (2 R^2)) * (x_tip^2 + z_tip^2))`
/// - Vận tốc dài ban đầu của bi chủ chiếu trên mặt bàn:
///   `v_0 = (J / m) * cos(theta_elev) * d_hat`
/// - Vận tốc góc ban đầu của bi chủ `Delta_omega = I^-1 * (r_c x J)`:
///   + Thành phần cu-lê (topspin) / trô (backspin) quanh trục ngang `e_2 = k x d_hat`:
///     `omega_roll = (5 * z_tip / (2 * R^2)) * |v_0| * (k x d_hat)`
///   + Thành phần ép-phê ngang quanh trục đứng `+z`:
///     `omega_z = (5 * x_tip / (2 * R^2)) * |v_0|`
///   + Khi nâng chuôi cơ góc `theta_elev > 0` (Piqué / Massé) kèm lệch tâm ngang `x_tip != 0`,
///     thành phần xung lực hướng xuống tạo mô-men xoáy dọc trục tiến `d_hat`:
///     `omega_masse = (5 * x_tip / (2 * R^2)) * (J / m) * sin(theta_elev) * d_hat`
///
/// Bảo toàn / tiêu hao năng lượng:
/// Với mọi `0 <= e_tip <= 1`, mọi `(x_tip, z_tip)` và mọi `theta_elev`:
/// `E_ball_after + E_cue_after <= E_cue_before = 1/2 * M_c * v_cue^2`
/// (đẳng thức đạt chính xác tới sai số máy khi `e_tip == 1` và `theta_elev == 0`).
class CueStrikePhysics {
  static const double defaultTipRestitution = 0.72;

  /// Tính đầy đủ trạng thái bi chủ, xung lượng `J`, vận tốc cơ sau va chạm và năng lượng cơ–bi.
  static CueStrikeMechanicsResult computeStrikeMechanics({
    required ShotInput input,
    required TableConfig config,
    double tipRestitution = defaultTipRestitution,
  }) {
    final r = config.ballRadius;
    final m = config.ballMass;
    final mc = config.cueMass;
    final eTip = tipRestitution.clamp(0.0, 1.0);

    final dir = input.aimDirection.normalized;
    final tipMeters = input.tipOffsetMeters(config);
    final xTip = tipMeters.x; // Lệch ngang (+: Phải, -: Trái)
    final zTip = tipMeters.y; // Lệch dọc (+: 12h Cu-lê, -: 6h Trô)

    // Hệ số quán tính quay chính xác từ I = (2/5) m R^2 => r_perp^2 / I = (5 / (2 R^2)) / m = 2.5 / (m R^2)
    final rPerpSq = xTip * xTip + zTip * zTip;
    final inertiaFactor = 1.0 + (2.5 * rPerpSq) / (r * r);

    final impulseMag = (mc * m * (1.0 + eTip) * input.cueSpeed) /
        (m + mc * inertiaFactor);

    final postStrikeCueSpeed = input.cueSpeed - (impulseMag / mc);

    final elev = input.cueElevationRadians.clamp(0.0, math.pi * 0.45);
    final cosElev = math.cos(elev);
    final sinElev = math.sin(elev);

    // Vận tốc tịnh tiến ban đầu trên mặt phẳng bàn
    final v0Mag = (impulseMag / m) * cosElev;
    final velocity = dir * v0Mag;

    // Trục xoay lăn tự nhiên k x dir = (-dir.y, dir.x, 0)
    final rollAxis = Vec3(-dir.y, dir.x, 0.0);

    // Thành phần vận tốc góc ngang do độ cao đầu cơ zTip (Cu-lê > 0 / Trô < 0):
    // Khi zTip = +(2/5)R = 0.4R, omegaRollMag = v0Mag / R => u = 0 (lăn thuần túy ngay từ đầu).
    final omegaRollMag = (2.5 * zTip / (r * r)) * v0Mag;
    Vec3 omega = rollAxis * omegaRollMag;

    // Thành phần vận tốc góc quanh trục đứng wz do ép-phê ngang xTip
    final omegaZ = (2.5 * xTip / (r * r)) * v0Mag;
    omega = Vec3(omega.x, omega.y, omegaZ);

    // Thành phần Massé / Piqué khi nâng chuôi cơ (elev > 0) và đặt ép-phê ngang xTip != 0
    if (sinElev > 1e-4 && xTip.abs() > 1e-6) {
      final vDown = (impulseMag / m) * sinElev;
      final omegaMasseMag = (2.5 * xTip / (r * r)) * vDown;
      omega = omega + Vec3(dir.x * omegaMasseMag, dir.y * omegaMasseMag, 0.0);
    }

    final phase = BallState.classifyPhase(
      velocity: velocity,
      angularVelocity: omega,
      ballRadius: r,
    );

    final cueBall = BallState(
      id: BallId.cue,
      position: input.cueBallPosition,
      velocity: velocity,
      angularVelocity: omega,
      orientation: Quat.identity,
      phase: phase,
    );

    final initialCueKE = 0.5 * mc * input.cueSpeed * input.cueSpeed;
    final postCueKE = 0.5 * mc * postStrikeCueSpeed * postStrikeCueSpeed;
    final postBallKE = cueBall.kineticEnergy(config);

    return CueStrikeMechanicsResult(
      cueBall: cueBall,
      impulseMagnitude: impulseMag,
      postStrikeCueSpeed: postStrikeCueSpeed,
      initialCueKineticEnergy: initialCueKE,
      postStrikeCueKineticEnergy: postCueKE,
      postStrikeBallKineticEnergy: postBallKE,
    );
  }

  /// Tính trạng thái tức thời của Bi chủ ngay sau khi đầu cơ chạm bi (t = 0+).
  static BallState computePostStrikeCueBallState({
    required ShotInput input,
    required TableConfig config,
    double tipRestitution = defaultTipRestitution,
  }) {
    return computeStrikeMechanics(
      input: input,
      config: config,
      tipRestitution: tipRestitution,
    ).cueBall;
  }
}
