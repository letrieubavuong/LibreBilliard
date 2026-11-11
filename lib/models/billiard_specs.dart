import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../physics/aim_geometry.dart';

/// Chế độ hiển thị chung cho tất cả các sơ đồ Billiard (dùng lại ở Danh sách, Chi tiết, Máy tính, Flashcard)
enum DiagramDisplayMode {
  /// Nhỏ gọn (hiển thị trên Card danh sách bài học hoặc Badge)
  thumbnail,

  /// Tiêu chuẩn (hiển thị trong bài viết hoặc bảng tóm tắt)
  standard,

  /// Tương tác đầy đủ (cho phép chạm chỉnh thông số, chạy mô phỏng, lật bàn)
  interactive,
}

/// Lớp cơ sở (Base Class) cho mọi thông số/sơ đồ trực quan trong Billiard Libre.
/// Đảm bảo tính kế thừa đồng nhất về nhãn, mô tả ngắn và khả năng xuất tóm tắt.
abstract class BilliardVisualSpec {
  final String label;
  final String? description;

  const BilliardVisualSpec({
    required this.label,
    this.description,
  });

  /// Tóm tắt ngắn gọn để hiển thị trên chip/badge
  String get shortSummary => label;
}

/// Hướng ngắm chạm vào bi mục tiêu 1 (bên phải hay bên trái tâm bi mục tiêu)
enum ContactSide {
  left('Chạm má Trái'),
  center('Trực diện'),
  right('Chạm má Phải');

  final String title;
  const ContactSide(this.title);
}

/// 1. Thông số CHẠM TRÁI (Độ dày chạm bi mục tiêu - Ball Contact / Thickness)
/// Kế thừa từ [BilliardVisualSpec] và cung cấp sẵn các preset chuẩn Libre (1/8, 1/4, 1/3, 1/2, 2/3, 3/4, Tràn mặt).
///
/// Quy ước vật lý thống nhất với `AimGeometry`:
/// - `fraction` f thuộc (0, 1] là tỉ lệ che phủ đường kính vuông góc hướng ngắm:
///   + Khoảng lệch tâm `b = 2 * R * (1 - f)`
///   + Góc cắt `theta = arcsin(1 - f)` (f = 1/2 => theta = 30°, f = 1.0 => theta = 0°)
/// - Khi `side == ContactSide.center` hoặc `fraction == 1.0`, hai thuộc tính này luôn đồng bộ (`fraction = 1.0`, `side = ContactSide.center`).
class BallContactSpec extends BilliardVisualSpec {
  /// Tỉ lệ che phủ mặt bi mục tiêu: (0.0 .. 1.0]
  final double fraction;

  /// Chạm má phải, má trái hoặc trực diện tâm bi mục tiêu 1
  final ContactSide side;

  const BallContactSpec._({
    required super.label,
    required this.fraction,
    required this.side,
    super.description,
  });

  factory BallContactSpec({
    String? label,
    required double fraction,
    ContactSide side = ContactSide.right,
    String? description,
  }) {
    final normalized = _normalizeFractionAndSide(fraction, side);
    return BallContactSpec._(
      label: label ?? formatFractionLabel(normalized.fraction),
      fraction: normalized.fraction,
      side: normalized.side,
      description: description,
    );
  }

  static ({double fraction, ContactSide side}) _normalizeFractionAndSide(
    double rawFraction,
    ContactSide rawSide,
  ) {
    final clamped = rawFraction.clamp(0.05, 1.0);
    if (rawSide == ContactSide.center || clamped >= 0.999) {
      return (fraction: 1.0, side: ContactSide.center);
    }
    return (fraction: clamped, side: rawSide);
  }

  /// Preset: Chạm rất mỏng (1/8 trái = 0.125)
  factory BallContactSpec.oneEighth({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/8 trái',
        fraction: 1.0 / 8.0,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Chạm rất mỏng ngoài rìa bi mục tiêu',
      );

  /// Preset: Chạm 1/4 trái (0.25)
  factory BallContactSpec.oneQuarter({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/4 trái',
        fraction: 1.0 / 4.0,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Ngắm rìa bi chủ vào 1/4 bi mục tiêu',
      );

  /// Preset: Chạm 1/3 trái (chính xác 1.0 / 3.0)
  factory BallContactSpec.oneThird({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/3 trái',
        fraction: 1.0 / 3.0,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Độ dày tiêu chuẩn cho các đòn dẫn bi',
      );

  /// Preset: Chạm nửa trái (1/2 = 0.50, góc cắt chuẩn 30°)
  factory BallContactSpec.half({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/2 trái',
        fraction: 0.50,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Tâm bi chủ ngắm thẳng vào rìa bi mục tiêu (góc cắt 30°)',
      );

  /// Preset: Chạm 2/3 trái (chính xác 2.0 / 3.0)
  factory BallContactSpec.twoThirds({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '2/3 trái',
        fraction: 2.0 / 3.0,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Chạm dày để truyền lực cho bi số 1 đi xa',
      );

  /// Preset: Chạm 3/4 trái (0.75)
  factory BallContactSpec.threeQuarters({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '3/4 trái',
        fraction: 0.75,
        side: side == ContactSide.center ? ContactSide.right : side,
        description: description ?? 'Chạm dày cho đòn Cu-lê đẩy hoặc Trô kéo',
      );

  /// Preset: Tràn mặt (1.0 - Trực diện tâm đối tâm, góc cắt 0°)
  factory BallContactSpec.full({
    String? description,
  }) =>
      BallContactSpec._(
        label: 'Tràn mặt',
        fraction: 1.0,
        side: ContactSide.center,
        description: description ?? 'Ngắm thẳng tâm bi chủ vào tâm bi mục tiêu (truyền 100% lực trực diện)',
      );

  /// Preset phân số phần tám: k in 1..8 (k=8 là Tràn mặt)
  factory BallContactSpec.eighths(
    int k, {
    ContactSide side = ContactSide.right,
    String? description,
  }) {
    final clampedK = k.clamp(1, 8);
    if (clampedK == 8) {
      return BallContactSpec.full(description: description);
    }
    return BallContactSpec(
      fraction: clampedK / 8.0,
      side: side == ContactSide.center ? ContactSide.right : side,
      description: description,
    );
  }

  /// Nấc phần tám (k = 1..8) nếu độ dày trùng khớp lưới 1/8 .. 8/8 (dung sai 0.02).
  /// Trả về null nếu là phân số khác (ví dụ 1/3, 2/3) hoặc số đo liên tục từ ngắm tự do.
  int? get eighthsStep {
    if (fraction >= 0.98) return 8;
    for (int k = 1; k <= 7; k++) {
      if ((fraction - (k / 8.0)).abs() < 0.02) return k;
    }
    return null;
  }

  /// Góc cắt lí tưởng theta = arcsin(1 - f) tính bằng độ (AimGeometry).
  double get cutAngleDegrees =>
      AimGeometry.cutAngleRadians(fraction) * 180.0 / math.pi;

  BallContactSpec copyWith({
    String? label,
    double? fraction,
    ContactSide? side,
    String? description,
  }) {
    double targetFraction = fraction ?? this.fraction;
    ContactSide targetSide = side ?? this.side;

    if (side == ContactSide.center && fraction == null) {
      targetFraction = 1.0;
    } else if (fraction != null && fraction < 0.999 && targetSide == ContactSide.center) {
      targetSide = this.side == ContactSide.center ? ContactSide.right : this.side;
    } else if (side != null &&
        side != ContactSide.center &&
        fraction == null &&
        this.fraction >= 0.999) {
      // Khi đang ở Tràn mặt mà người dùng bấm chọn Má Trái/Phải, chuyển về độ dày 6/8 (3/4) mặc định
      targetFraction = 0.75;
    }

    final normalized = _normalizeFractionAndSide(targetFraction, targetSide);
    return BallContactSpec._(
      label: label ?? formatFractionLabel(normalized.fraction),
      fraction: normalized.fraction,
      side: normalized.side,
      description: description ?? this.description,
    );
  }

  static String formatFractionLabel(double f) {
    if (f >= 0.98) return 'Tràn mặt';
    if ((f - 0.125).abs() < 0.02) return '1/8 trái';
    if ((f - 0.25).abs() < 0.02) return '2/8 (1/4) trái';
    if ((f - (1.0 / 3.0)).abs() < 0.02) return '1/3 trái';
    if ((f - 0.375).abs() < 0.02) return '3/8 trái';
    if ((f - 0.50).abs() < 0.02) return '4/8 (1/2) trái';
    if ((f - 0.625).abs() < 0.02) return '5/8 trái';
    if ((f - (2.0 / 3.0)).abs() < 0.02) return '2/3 trái';
    if ((f - 0.75).abs() < 0.02) return '6/8 (3/4) trái';
    if ((f - 0.875).abs() < 0.02) return '7/8 trái';
    return '${(f * 100).round()}% trái';
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'fraction': fraction,
        'side': side.name,
        'description': description,
      };

  factory BallContactSpec.fromJson(Map<String, dynamic> json) {
    final sideName = json['side'] as String? ?? 'right';
    final side = ContactSide.values.firstWhere(
      (s) => s.name == sideName,
      orElse: () => ContactSide.right,
    );
    return BallContactSpec(
      label: json['label'] as String?,
      fraction: (json['fraction'] as num?)?.toDouble() ?? 0.5,
      side: side,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BallContactSpec &&
          (fraction - other.fraction).abs() < 1e-9 &&
          side == other.side &&
          label == other.label);

  @override
  int get hashCode => Object.hash(fraction.toStringAsFixed(6), side, label);
}

/// 2. Thông số ÉP-PHÊ & TÂM BI CHỦ (Cue Ball Spin / Effet)
/// Kế thừa từ [BilliardVisualSpec], biểu diễn điểm đầu cơ chạm vào bi chủ theo:
/// - Ngang (`horizontalEffet`): từ -4 (4 ép-phê trái) đến +4 (4 ép-phê phải)
/// - Dọc (`verticalHeight`): từ -4 (6h tối đa - Rétro sâu) đến +4 (12h tối đa - Coulé cao)
///
/// Thang đo kép chuẩn xác (SI & Quy ước 4 mức):
/// - Đường kính bi Carom chuẩn: `2R = 61.5 mm` (bán kính `R = 30.75 mm`).
/// - Đường kính đầu cơ: tùy chọn 11.5, 11.75, 12.0 mm (mặc định 12.0 mm).
/// - Giới hạn tham khảo an toàn tránh tạch cơ: `r <= 0.50 * R = 15.375 mm`.
/// - Thang 4 mức quy ước: mỗi mức ứng với `0.125 * R = 3.84375 mm`.
/// - Mốc tham khảo Natural Roll (lăn tự nhiên khi cơ ngang): `z = +0.40 * R = +12.30 mm`.
/// - Ràng buộc đĩa tròn tiếp xúc: `x^2 + z^2 <= r_limit^2`.
class CueBallEffetSpec extends BilliardVisualSpec {
  static const double maxTips = 4.0;
  static const double maxPhysicalRadiusRatio = 0.80;

  /// Đường kính viên bi Carom tiêu chuẩn: 61.5 mm
  static const double ballDiameterMm = 61.5;

  /// Bán kính viên bi Carom tiêu chuẩn: R = 30.75 mm
  static const double ballRadiusMm = 30.75;

  /// Đường kính đầu cơ mặc định: 12.0 mm (chiếm ~19.51% đường kính viên bi)
  static const double defaultTipDiameterMm = 12.0;

  /// Các kích thước đầu cơ Carom phổ biến: 11.5, 11.75, 12.0 mm
  static const List<double> supportedTipDiametersMm = [11.5, 11.75, 12.0];

  /// Giới hạn tham khảo an toàn tránh tạch cơ (Dr. Dave Cue Tip / Miscuing Limit): 0.50 * R = 15.375 mm
  static const double referenceMaxRatio = 0.50;

  /// Giới hạn vật lý cực đại mở rộng (chế độ nghiên cứu / tương thích legacy): 0.80 * R = 24.60 mm
  static const double extendedMaxRatio = 0.80;

  /// Bước dịch chuyển mỗi tầng / mức theo quy ước 4 mức: 0.125 * R = 3.84375 mm
  static const double tierStepMm = 3.84375;

  /// Mốc tham khảo Natural Roll (lăn tự nhiên trong mô hình cơ ngang lí tưởng): z = +0.40 * R = +12.30 mm
  static const double naturalRollZMm = 12.30;
  static const double naturalRollZRatio = 0.40;

  /// Mức ép-phê ngang: âm là Trái, dương là Phải (nằm trong đĩa tròn bán kính 4.0).
  final double horizontalEffet;

  /// Độ cao đầu cơ: dương là Cao/Cu-lê (12h), âm là Thấp/Trô (6h) (nằm trong đĩa tròn bán kính 4.0).
  final double verticalHeight;

  /// Đường kính đầu cơ (mm)
  final double tipDiameterMm;

  const CueBallEffetSpec._({
    required super.label,
    required this.horizontalEffet,
    required this.verticalHeight,
    this.tipDiameterMm = defaultTipDiameterMm,
    super.description,
  });

  factory CueBallEffetSpec({
    String? label,
    required double horizontalEffet,
    required double verticalHeight,
    double tipDiameterMm = defaultTipDiameterMm,
    String? description,
  }) {
    final clamped = clampTipsToCircle(horizontalEffet, verticalHeight);
    return CueBallEffetSpec._(
      label: label ?? _buildAutoLabel(clamped.h, clamped.v),
      horizontalEffet: clamped.h,
      verticalHeight: clamped.v,
      tipDiameterMm: tipDiameterMm,
      description: description,
    );
  }

  /// Chiếu cặp `(h, v)` về hình tròn bán kính `maxTips = 4.0`.
  static ({double h, double v}) clampTipsToCircle(
    double rawH,
    double rawV, {
    double maxRadiusTips = maxTips,
  }) {
    final dist = math.sqrt(rawH * rawH + rawV * rawV);
    if (dist <= maxRadiusTips || dist <= 1e-12) {
      return (h: rawH, v: rawV);
    }
    final scale = maxRadiusTips / dist;
    return (h: rawH * scale, v: rawV * scale);
  }

  /// Tọa độ chuẩn hóa trong đĩa đơn vị `length <= 1.0` để vẽ trên mặt bi chủ.
  /// Trên Canvas: trục Y hướng xuống nên `verticalHeight` dương (12h) có `dy` âm.
  Offset get normalizedTipOffset => Offset(
        horizontalEffet / maxTips,
        -verticalHeight / maxTips,
      );

  /// Tỉ lệ điểm chạm vật lý `(x_tip / R, z_tip / R)` trong đĩa tròn bán kính `maxPhysicalRadiusRatio (0.80)`.
  Offset get physicalTipOffsetRatio => Offset(
        (horizontalEffet / maxTips) * maxPhysicalRadiusRatio,
        (verticalHeight / maxTips) * maxPhysicalRadiusRatio,
      );

  /// Tọa độ tiếp xúc vật lý X (mm) từ tâm bi (-R .. +R). Âm là Trái, Dương là Phải.
  double get contactOffsetXMm => physicalTipOffsetRatio.dx * ballRadiusMm;

  /// Tọa độ tiếp xúc vật lý Z (mm) từ tâm bi (-R .. +R). Dương là Cao (12h), Âm là Thấp (6h).
  double get contactOffsetZMm => physicalTipOffsetRatio.dy * ballRadiusMm;

  /// Khoảng cách từ tâm bi tới điểm tiếp xúc r = sqrt(x^2 + z^2) tính bằng mm.
  double get contactRadiusMm => math.sqrt(
        contactOffsetXMm * contactOffsetXMm +
            contactOffsetZMm * contactOffsetZMm,
      );

  /// Tỷ lệ bán kính tiếp xúc so với bán kính bi: r / R.
  double get contactRadiusRatio => contactRadiusMm / ballRadiusMm;

  /// Nấc / tầng ngang gần nhất theo thang 4 mức quy ước (-4..+4, tâm 0).
  int get nearestHorizontalTier =>
      (contactOffsetXMm / tierStepMm).round().clamp(-4, 4);

  /// Nấc / tầng dọc gần nhất theo thang 4 mức quy ước (-4..+4, tâm 0).
  int get nearestVerticalTier =>
      (contactOffsetZMm / tierStepMm).round().clamp(-4, 4);

  /// Điểm chạm có nằm ngoài miền tham khảo an toàn (r > 0.50 * R = 15.375 mm) hay không.
  bool get isOutsideReferenceSafetyZone =>
      contactRadiusMm > (referenceMaxRatio * ballRadiusMm + 0.05);

  /// Khởi tạo từ mức Cao/Thấp và số mũi Ép-phê (tự động chiếu vào miền tròn hợp lệ).
  factory CueBallEffetSpec.fromTips({
    required double horizontalTips,
    required double verticalTips,
    double tipDiameterMm = defaultTipDiameterMm,
    String? customLabel,
    String? description,
  }) {
    final clamped = clampTipsToCircle(horizontalTips, verticalTips);
    return CueBallEffetSpec._(
      label: customLabel ?? _buildAutoLabel(clamped.h, clamped.v),
      horizontalEffet: clamped.h,
      verticalHeight: clamped.v,
      tipDiameterMm: tipDiameterMm,
      description: description,
    );
  }

  /// Khởi tạo từ 4 tầng / mức quy ước:
  /// - `horizontalTier`: -4..+4 (mỗi mức 3.84375 mm = 0.125 R)
  /// - `verticalTier`: -4..+4 (mỗi mức 3.84375 mm = 0.125 R)
  /// Ràng buộc đĩa tròn an toàn r <= 0.50 * R (15.375 mm).
  factory CueBallEffetSpec.fromTiers({
    required int horizontalTier,
    required int verticalTier,
    double tipDiameterMm = defaultTipDiameterMm,
    String? customLabel,
    String? description,
  }) {
    final rawXMm = horizontalTier.clamp(-4, 4) * tierStepMm;
    final rawZMm = verticalTier.clamp(-4, 4) * tierStepMm;
    return CueBallEffetSpec.fromMm(
      xMm: rawXMm,
      zMm: rawZMm,
      tipDiameterMm: tipDiameterMm,
      customLabel: customLabel,
      description: description,
    );
  }

  /// Khởi tạo trực tiếp từ tọa độ mm tiếp xúc vật lý trên mặt cầu:
  /// - `xMm`: trục ngang (-15.375 .. +15.375 mm trong chuẩn an toàn)
  /// - `zMm`: trục đứng (-15.375 .. +15.375 mm trong chuẩn an toàn)
  /// Ràng buộc đĩa tròn x^2 + z^2 <= (r_limit)^2.
  factory CueBallEffetSpec.fromMm({
    required double xMm,
    required double zMm,
    double tipDiameterMm = defaultTipDiameterMm,
    bool allowExtendedRange = false,
    String? customLabel,
    String? description,
  }) {
    final maxAllowedR =
        (allowExtendedRange ? extendedMaxRatio : referenceMaxRatio) * ballRadiusMm;
    final dist = math.sqrt(xMm * xMm + zMm * zMm);
    double clampedX = xMm;
    double clampedZ = zMm;
    if (dist > maxAllowedR && dist > 1e-9) {
      final scale = maxAllowedR / dist;
      clampedX = xMm * scale;
      clampedZ = zMm * scale;
    }

    final h = (clampedX / (ballRadiusMm * maxPhysicalRadiusRatio)) * maxTips;
    final v = (clampedZ / (ballRadiusMm * maxPhysicalRadiusRatio)) * maxTips;

    return CueBallEffetSpec._(
      label: customLabel ?? _buildMmLabel(clampedX, clampedZ),
      horizontalEffet: h,
      verticalHeight: v,
      tipDiameterMm: tipDiameterMm,
      description: description,
    );
  }

  CueBallEffetSpec copyWith({
    double? horizontalEffet,
    double? verticalHeight,
    double? tipDiameterMm,
    String? label,
    String? description,
  }) {
    final clamped = clampTipsToCircle(
      horizontalEffet ?? this.horizontalEffet,
      verticalHeight ?? this.verticalHeight,
    );
    return CueBallEffetSpec._(
      label: label ?? _buildAutoLabel(clamped.h, clamped.v),
      horizontalEffet: clamped.h,
      verticalHeight: clamped.v,
      tipDiameterMm: tipDiameterMm ?? this.tipDiameterMm,
      description: description ?? this.description,
    );
  }

  static String _buildMmLabel(double xMm, double zMm) {
    String vPart;
    if (zMm >= 6.0) {
      vPart = 'Cu-lê (+${zMm.toStringAsFixed(1)}mm)';
    } else if (zMm >= 1.5) {
      vPart = 'Trên tâm (+${zMm.toStringAsFixed(1)}mm)';
    } else if (zMm <= -6.0) {
      vPart = 'Trô sâu (${zMm.toStringAsFixed(1)}mm)';
    } else if (zMm <= -1.5) {
      vPart = 'Dưới tâm (${zMm.toStringAsFixed(1)}mm)';
    } else {
      vPart = 'Tâm bi (0mm)';
    }

    if (xMm.abs() < 0.8) {
      return '$vPart • Không ép-phê';
    }
    final side = xMm > 0 ? 'Phải' : 'Trái';
    return '$vPart • ${xMm.abs().toStringAsFixed(1)}mm $side';
  }

  static String _buildAutoLabel(double h, double v) {
    String vPart;
    if (v >= 1.5) {
      vPart = 'Cu-lê (12h)';
    } else if (v >= 0.4) {
      vPart = 'Trên tâm nhẹ';
    } else if (v <= -1.5) {
      vPart = 'Trô sâu (6h)';
    } else if (v <= -0.4) {
      vPart = 'Dưới tâm nhẹ';
    } else {
      vPart = 'Tâm bi';
    }

    if (h.abs() < 0.25) {
      return '$vPart • Không ép-phê';
    }
    final side = h > 0 ? 'Phải' : 'Trái';
    final rounded = (h.abs() * 2).round() / 2.0;
    final tips = rounded.toStringAsFixed(rounded % 1 == 0 ? 0 : 1);
    return '$vPart • $tips Ép-phê $side';
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'horizontalEffet': horizontalEffet,
        'verticalHeight': verticalHeight,
        'tipDiameterMm': tipDiameterMm,
        'description': description,
      };

  factory CueBallEffetSpec.fromJson(Map<String, dynamic> json) {
    return CueBallEffetSpec(
      label: json['label'] as String?,
      horizontalEffet: (json['horizontalEffet'] as num?)?.toDouble() ?? 0.0,
      verticalHeight: (json['verticalHeight'] as num?)?.toDouble() ?? 0.0,
      tipDiameterMm: (json['tipDiameterMm'] as num?)?.toDouble() ?? defaultTipDiameterMm,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CueBallEffetSpec &&
          (horizontalEffet - other.horizontalEffet).abs() < 1e-9 &&
          (verticalHeight - other.verticalHeight).abs() < 1e-9 &&
          (tipDiameterMm - other.tipDiameterMm).abs() < 1e-6 &&
          label == other.label);

  @override
  int get hashCode => Object.hash(
        horizontalEffet.toStringAsFixed(6),
        verticalHeight.toStringAsFixed(6),
        tipDiameterMm.toStringAsFixed(2),
        label,
      );
}

/// 3. Thông số SƠ ĐỒ HÌNH BI TRÊN BÀN (Carom Table Diagram Spec)
/// Kế thừa từ [BilliardVisualSpec], dùng lại cho cả bài học Kĩ thuật, Gom bi, Bộ số và Seri.
/// Tọa độ chuẩn hóa theo 8 nút băng dài (X: 0.0..8.0) x 4 nút băng ngắn (Y: 0.0..4.0).
///
/// Lưu ý kiến trúc vật lý:
/// - `cueBallPath`, `objectBall1Path`, `objectBall2Path` chỉ đóng vai trò là
///   **Sơ đồ hướng dẫn tĩnh (Static Guideline Layer)** minh họa ý đồ chiến thuật trong sách,
///   tuyệt đối KHÔNG được dùng để giả lập hay ép kết quả va chạm vật lý.
class TableDiagramSpec extends BilliardVisualSpec {
  final Offset cueBall; // Bi chủ (Trắng)
  final Offset objectBall1; // Bi mục tiêu 1 (Vàng)
  final Offset objectBall2; // Bi mục tiêu 2 (Đỏ)

  /// Các đường hướng dẫn chiến thuật tĩnh (Static Guideline Layer) của bài học.
  final List<Offset> cueBallPath;
  final List<Offset> objectBall1Path;
  final List<Offset> objectBall2Path;

  final Offset? targetZoneCenter; // Vùng gom bi mục tiêu
  final double targetZoneRadius;
  final bool showDiamondNumbers; // Hiển thị bộ số trên băng (hữu ích cho tab Bộ số)
  final bool showCornerZones; // Hiển thị ô cấm góc Libre (71x35.5cm)

  const TableDiagramSpec({
    super.label = 'Sơ đồ bàn Carom',
    super.description,
    required this.cueBall,
    required this.objectBall1,
    required this.objectBall2,
    this.cueBallPath = const [],
    this.objectBall1Path = const [],
    this.objectBall2Path = const [],
    this.targetZoneCenter,
    this.targetZoneRadius = 0.65,
    this.showDiamondNumbers = false,
    this.showCornerZones = true,
  });

  /// Tạo bản sao đã lật ngang / lật dọc bàn (giúp người tập xem hình bi ở cả 4 góc bàn)
  TableDiagramSpec flipped({
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    if (!flipHorizontal && !flipVertical) return this;
    Offset transform(Offset p) => Offset(
          flipHorizontal ? 8.0 - p.dx : p.dx,
          flipVertical ? 4.0 - p.dy : p.dy,
        );

    return TableDiagramSpec(
      label: label,
      description: description,
      cueBall: transform(cueBall),
      objectBall1: transform(objectBall1),
      objectBall2: transform(objectBall2),
      cueBallPath: cueBallPath.map(transform).toList(),
      objectBall1Path: objectBall1Path.map(transform).toList(),
      objectBall2Path: objectBall2Path.map(transform).toList(),
      targetZoneCenter:
          targetZoneCenter != null ? transform(targetZoneCenter!) : null,
      targetZoneRadius: targetZoneRadius,
      showDiamondNumbers: showDiamondNumbers,
      showCornerZones: showCornerZones,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'description': description,
        'cueBall': [cueBall.dx, cueBall.dy],
        'objectBall1': [objectBall1.dx, objectBall1.dy],
        'objectBall2': [objectBall2.dx, objectBall2.dy],
        'cueBallPath': cueBallPath.map((p) => [p.dx, p.dy]).toList(),
        'objectBall1Path': objectBall1Path.map((p) => [p.dx, p.dy]).toList(),
        'objectBall2Path': objectBall2Path.map((p) => [p.dx, p.dy]).toList(),
        'targetZoneCenter': targetZoneCenter != null
            ? [targetZoneCenter!.dx, targetZoneCenter!.dy]
            : null,
        'targetZoneRadius': targetZoneRadius,
        'showDiamondNumbers': showDiamondNumbers,
        'showCornerZones': showCornerZones,
      };

  factory TableDiagramSpec.fromJson(Map<String, dynamic> json) {
    Offset parseOffset(dynamic raw, Offset fallback) {
      if (raw is List && raw.length >= 2) {
        return Offset(
          (raw[0] as num).toDouble(),
          (raw[1] as num).toDouble(),
        );
      }
      return fallback;
    }

    List<Offset> parsePath(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => parseOffset(e, Offset.zero))
            .toList(growable: false);
      }
      return const [];
    }

    return TableDiagramSpec(
      label: json['label'] as String? ?? 'Sơ đồ bàn Carom',
      description: json['description'] as String?,
      cueBall: parseOffset(json['cueBall'], const Offset(3.0, 2.0)),
      objectBall1: parseOffset(json['objectBall1'], const Offset(2.0, 1.3)),
      objectBall2: parseOffset(json['objectBall2'], const Offset(1.3, 0.8)),
      cueBallPath: parsePath(json['cueBallPath']),
      objectBall1Path: parsePath(json['objectBall1Path']),
      objectBall2Path: parsePath(json['objectBall2Path']),
      targetZoneCenter: json['targetZoneCenter'] != null
          ? parseOffset(json['targetZoneCenter'], Offset.zero)
          : null,
      targetZoneRadius: (json['targetZoneRadius'] as num?)?.toDouble() ?? 0.65,
      showDiamondNumbers: json['showDiamondNumbers'] as bool? ?? false,
      showCornerZones: json['showCornerZones'] as bool? ?? true,
    );
  }
}
