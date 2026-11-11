import 'dart:math' as math;
import 'ball_state.dart';
import 'shot_input.dart';
import 'table_config.dart';
import 'vector_math.dart';

/// Mô hình vật lý va chạm Đầu cơ - Bi chủ (Cue-to-Ball Strike Mechanics):
///
/// Từ phương trình xung lượng - mô-men động lượng của quả cầu đặc bán kính R, khối lượng m,
/// mô-men quán tính `I = (2/5) m R^2` và khối lượng hiệu dụng của cây cơ `M_c`:
/// - Xung lực truyền từ đầu cơ có vận tốc `v_cue`:
///   `J = (M_c * m * (1 + e_tip) * v_cue) / (m + M_c * (1 + (5 / (2 R^2)) * (x_tip^2 + z_tip^2)))`
/// - Vận tốc dài ban đầu của bi chủ:
///   `v_0 = (J / m) * cos(theta_elev) * d_hat`
/// - Vận tốc góc ban đầu của bi chủ `Delta_omega = I^-1 * (r x J)`:
///   + Thành phần cu-lê (topspin) / trô (backspin) quanh trục ngang vuông góc hướng bắn `k x d_hat`:
///     `omega_roll = (5 * z_tip / (2 * R^2)) * |v_0| * (k x d_hat)`
///   + Thành phần ép-phê ngang quanh trục đứng `+z`:
///     `omega_z = (5 * x_tip / (2 * R^2)) * |v_0|`
///   + Khi nâng chuôi cơ góc `theta_elev > 0` (Piqué / Massé) kèm lệch tâm ngang `x_tip != 0`,
///     thành phần xung lực hướng xuống tạo thêm mô-men xoáy ngang dọc theo trục tiến `d_hat`,
///     gây ra vận tốc trượt ngang trên mặt vải khiến quỹ đạo bi chủ uốn cong (swerve / massé).
class CueStrikePhysics {
  static const double tipRestitution = 0.72;

  /// Tính trạng thái tức thời của Bi chủ ngay sau khi đầu cơ chạm bi (t = 0+).
  static BallState computePostStrikeCueBallState({
    required ShotInput input,
    required TableConfig config,
  }) {
    final r = config.ballRadius;
    final m = config.ballMass;
    final mc = config.cueMass;

    final dir = input.aimDirection.normalized;
    final tipMeters = input.tipOffsetMeters(config);
    final xTip = tipMeters.x; // Lệch ngang (+: Phải, -: Trái)
    final zTip = tipMeters.y; // Lệch dọc (+: 12h Cu-lê, -: 6h Trô)

    final rPerpSq = xTip * xTip + zTip * zTip;
    final inertiaFactor = 1.0 + (2.5 * rPerpSq) / (r * r);

    // Xung lượng J từ va chạm cơ - bi chủ
    final impulseMag = (mc * m * (1.0 + tipRestitution) * input.cueSpeed) /
        (m + mc * inertiaFactor);

    final elev = input.cueElevationRadians.clamp(0.0, math.pi * 0.45);
    final cosElev = math.cos(elev);
    final sinElev = math.sin(elev);

    // Vận tốc tịnh tiến ban đầu trên mặt phẳng bàn
    final v0Mag = (impulseMag / m) * cosElev;
    final velocity = dir * v0Mag;

    // Trục xoay lăn tự nhiên k x dir = (-dir.y, dir.x, 0)
    final rollAxis = Vec3(-dir.y, dir.x, 0.0);

    // Thành phần vận tốc góc ngang do độ cao đầu cơ zTip (Cu-lê > 0 / Trô < 0):
    // Lưu ý: khi zTip = +(2/5)R = 0.4R, omegaRollMag = v0Mag / R => u = 0 (lăn thuần túy ngay từ đầu).
    final omegaRollMag = (2.5 * zTip / (r * r)) * v0Mag;
    Vec3 omega = rollAxis * omegaRollMag;

    // Thành phần vận tốc góc quanh trục đứng wz do ép-phê ngang xTip
    final omegaZ = (2.5 * xTip / (r * r)) * v0Mag;
    omega = Vec3(omega.x, omega.y, omegaZ);

    // Thành phần Massé / Piqué khi nâng chuôi cơ (elev > 0) và đặt ép-phê ngang xTip != 0:
    // Xung lực hướng xuống J_z = -J * sin(elev) tại cánh tay đòn ngang xTip tạo mô-men xoáy dọc theo hướng bắn `dir`,
    // làm điểm tiếp xúc đáy bi trượt ngang và uốn cong quỹ đạo bi chủ!
    if (sinElev > 1e-4 && xTip.abs() > 1e-6) {
      final vDown = (impulseMag / m) * sinElev;
      final omegaMasseMag = (2.5 * xTip / (r * r)) * vDown;
      // Với k x (dir * omegaMasseMag) hướng về phía lệch tâm để ma sát vải đẩy cong bi
      omega = omega + Vec3(dir.x * omegaMasseMag, dir.y * omegaMasseMag, 0.0);
    }

    final phase = BallState.classifyPhase(
      velocity: velocity,
      angularVelocity: omega,
      ballRadius: r,
    );

    return BallState(
      id: BallId.cue,
      position: input.cueBallPosition,
      velocity: velocity,
      angularVelocity: omega,
      orientation: Quat.identity,
      phase: phase,
    );
  }
}
