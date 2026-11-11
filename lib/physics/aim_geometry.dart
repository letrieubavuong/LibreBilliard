import 'dart:math' as math;
import 'vector_math.dart';

/// Kết quả tính toán hình học ngắm Ghost Ball từ độ dày chạm trái `fraction`.
class GhostBallAimResult {
  /// Độ dày chạm trái f thuộc (0, 1].
  final double fraction;

  /// Khoảng lệch tâm (impact parameter) b = 2R * (1 - f) tính bằng mét.
  final double impactParameterMeters;

  /// Góc cắt (cut angle) theta = arcsin(1 - f) tính bằng radian (giữa hướng bi chủ tới và pháp tuyến va chạm).
  final double cutAngleRadians;

  /// Tâm của Ghost Ball tại thời điểm tiếp xúc ngoại tiếp với bi mục tiêu (cách tâm bi mục tiêu đúng 2R).
  final Vec2 ghostBallCenter;

  /// Điểm tiếp xúc trên bề mặt hai viên bi (nằm chính giữa tâm Ghost Ball và tâm bi mục tiêu).
  final Vec2 contactPoint;

  /// Vector đơn vị hướng ngắm từ vị trí bi chủ ban đầu tới tâm Ghost Ball.
  final Vec2 aimDirection;

  /// Pháp tuyến đơn vị từ tâm Ghost Ball sang tâm bi mục tiêu tại điểm chạm.
  final Vec2 collisionNormal;

  const GhostBallAimResult({
    required this.fraction,
    required this.impactParameterMeters,
    required this.cutAngleRadians,
    required this.ghostBallCenter,
    required this.contactPoint,
    required this.aimDirection,
    required this.collisionNormal,
  });

  double get cutAngleDegrees => cutAngleRadians * 180.0 / math.pi;
}

/// Hình học ngắm chạm trái (Thickness / Fraction) chuẩn vật lý Billiard Carom:
/// - Độ dày che phủ `fraction` f in (0, 1] được định nghĩa dọc theo đường kính vuông góc với hướng ngắm:
///   + Khoảng lệch tâm (impact parameter): `b = 2 * R * (1 - f)`
///   + Góc cắt (cut angle): `sin(theta) = b / (2 * R) = 1 - f` => `theta = arcsin(1 - f)`
///   + Kiểm tra chuẩn:
///     * f = 1.0 (Tràn mặt) => b = 0, theta = 0 deg
///     * f = 0.5 (1/2 trái) => b = R, theta = 30 deg
///     * f = 0.25 (1/4 trái) => b = 1.5 R, theta = arcsin(0.75) ~ 48.59 deg
///     * f = 0.75 (3/4 trái) => b = 0.5 R, theta = arcsin(0.25) ~ 14.48 deg
class AimGeometry {
  /// Tính khoảng lệch tâm `b = 2R(1 - f)` từ độ dày `fraction` và bán kính `ballRadius`.
  static double impactParameter({
    required double fraction,
    required double ballRadius,
  }) {
    final f = fraction.clamp(0.0, 1.0);
    return 2.0 * ballRadius * (1.0 - f);
  }

  /// Tính góc cắt lý thuyết `theta = arcsin(1 - f)` (radian).
  static double cutAngleRadians(double fraction) {
    final sinTheta = (1.0 - fraction.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    return math.asin(sinTheta);
  }

  /// Tính tâm Ghost Ball và hướng ngắm chính xác sao cho tại thời điểm bi chủ (đi thẳng từ `cueBallPos`)
  /// chạm vào bi mục tiêu đứng yên tại `objectBallPos`, khoảng lệch tâm vuông góc với tia ngắm đúng bằng `b = 2R(1 - f)`.
  ///
  /// Tham số `lateralSign`:
  /// - `0.0`: ngắm trực diện (tràn mặt, `f = 1.0`).
  /// - `+1.0`: lệch sang phía pháp tuyến `perpCCW = (-e_y, e_x)` của đường nối tâm.
  /// - `-1.0`: lệch sang phía pháp tuyến `perpCW = (e_y, -e_x)` của đường nối tâm.
  static GhostBallAimResult computeGhostBallAim({
    required Vec2 cueBallPos,
    required Vec2 objectBallPos,
    required double ballRadius,
    required double fraction,
    required double lateralSign,
  }) {
    final effectiveFraction =
        lateralSign.abs() <= 1e-9 ? 1.0 : fraction.clamp(1e-4, 1.0);
    final sign = lateralSign.abs() <= 1e-9 ? 0.0 : (lateralSign >= 0 ? 1.0 : -1.0);

    final b = impactParameter(
      fraction: effectiveFraction,
      ballRadius: ballRadius,
    );
    final theta = cutAngleRadians(effectiveFraction);

    final toObj = objectBallPos - cueBallPos;
    final dist = toObj.length;
    final e = dist > 1e-9 ? toObj / dist : Vec2.unitX;
    final nPerp = e.perpCCW; // (-e.y, e.x)

    final twoR = 2.0 * ballRadius;
    if (dist <= twoR + 1e-9) {
      final ghost = objectBallPos - e * twoR;
      return GhostBallAimResult(
        fraction: effectiveFraction,
        impactParameterMeters: b,
        cutAngleRadians: theta,
        ghostBallCenter: ghost,
        contactPoint: Vec2.lerp(ghost, objectBallPos, 0.5),
        aimDirection: e,
        collisionNormal: e,
      );
    }

    // Góc lệch beta giữa đường nối tâm (cue -> obj) và tia ngắm (cue -> ghost)
    // thỏa mãn: D * sin(beta) = b
    final sinBeta = (b / dist).clamp(0.0, 0.999999);
    final cosBeta = math.sqrt(1.0 - sinBeta * sinBeta);

    final aimDir = (e * cosBeta + nPerp * (sign * sinBeta)).normalized;

    // Khoảng cách từ bi chủ tới tâm Ghost Ball dọc theo tia aimDir:
    // t_hit = D * cos(beta) - sqrt((2R)^2 - b^2)
    final normalAdvance = math.sqrt(math.max(0.0, twoR * twoR - b * b));
    final tHit = math.max(0.0, dist * cosBeta - normalAdvance);

    final ghostCenter = cueBallPos + aimDir * tHit;
    final collisionNormal = (objectBallPos - ghostCenter).normalized;
    final contactPt = Vec2.lerp(ghostCenter, objectBallPos, 0.5);

    return GhostBallAimResult(
      fraction: effectiveFraction,
      impactParameterMeters: b,
      cutAngleRadians: theta,
      ghostBallCenter: ghostCenter,
      contactPoint: contactPt,
      aimDirection: aimDir,
      collisionNormal: collisionNormal,
    );
  }

  /// Suy ngược độ dày chạm thực tế `fraction` thuộc `[0, 1]` và dấu lệch bên `lateralSign`
  /// từ một hướng ngắm tự do `aimDirection`. Trả về `null` nếu tia ngắm thẳng không giao với mặt cầu `2R` của bi mục tiêu.
  static ({
    double fraction,
    double lateralSign,
    double impactParameterMeters,
  })? inferContactFromAimDirection({
    required Vec2 cueBallPos,
    required Vec2 objectBallPos,
    required double ballRadius,
    required Vec2 aimDirection,
  }) {
    if (aimDirection.lengthSquared <= 1e-12) return null;
    final dir = aimDirection.normalized;
    final toObj = objectBallPos - cueBallPos;
    final forwardProj = toObj.dot(dir);
    if (forwardProj <= 0.0) return null;

    final twoR = 2.0 * ballRadius;
    // Độ lệch có dấu của tâm Ghost Ball so với đường nối tâm along dir.perpCCW:
    // dir = cos(beta)*e + lateralSign*sin(beta)*e.perpCCW => toObj . dir.perpCCW = -lateralSign * b
    final signedPerp = -toObj.dot(dir.perpCCW);
    final b = signedPerp.abs();
    if (b >= twoR) return null;

    final fraction = (1.0 - (b / twoR)).clamp(0.0, 1.0);
    final lateralSign =
        b <= 1e-5 ? 0.0 : (signedPerp >= 0.0 ? 1.0 : -1.0);

    return (
      fraction: fraction,
      lateralSign: lateralSign,
      impactParameterMeters: b,
    );
  }
}

