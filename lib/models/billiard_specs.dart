import 'package:flutter/material.dart';

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
class BallContactSpec extends BilliardVisualSpec {
  /// Tỉ lệ che phủ mặt bi mục tiêu: 0.0 (sượt mỏng) -> 1.0 (tràn mặt bi)
  final double fraction;

  /// Chạm má phải hay má trái của bi mục tiêu 1
  final ContactSide side;

  const BallContactSpec({
    required super.label,
    required this.fraction,
    this.side = ContactSide.right,
    super.description,
  });

  /// Preset: Chạm rất mỏng (1/8 trái)
  factory BallContactSpec.oneEighth({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/8 trái',
        fraction: 0.125,
        side: side,
        description: description ?? 'Chạm rất mỏng ngoài rìa bi mục tiêu',
      );

  /// Preset: Chạm 1/4 trái
  factory BallContactSpec.oneQuarter({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/4 trái',
        fraction: 0.25,
        side: side,
        description: description ?? 'Ngắm rìa bi chủ vào 1/4 bi mục tiêu',
      );

  /// Preset: Chạm 1/3 trái
  factory BallContactSpec.oneThird({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/3 trái',
        fraction: 0.33,
        side: side,
        description: description ?? 'Độ dày tiêu chuẩn cho các đòn dẫn bi',
      );

  /// Preset: Chạm nửa trái (1/2)
  factory BallContactSpec.half({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '1/2 trái',
        fraction: 0.50,
        side: side,
        description: description ?? 'Tâm bi chủ ngắm thẳng vào rìa bi mục tiêu',
      );

  /// Preset: Chạm 2/3 trái
  factory BallContactSpec.twoThirds({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '2/3 trái',
        fraction: 0.66,
        side: side,
        description: description ?? 'Chạm dày để truyền lực cho bi số 2 đi xa',
      );

  /// Preset: Chạm 3/4 trái
  factory BallContactSpec.threeQuarters({
    ContactSide side = ContactSide.right,
    String? description,
  }) =>
      BallContactSpec(
        label: '3/4 trái',
        fraction: 0.75,
        side: side,
        description: description ?? 'Chạm dày cho đòn Cu-lê đẩy hoặc Trô kéo',
      );

  BallContactSpec copyWith({
    String? label,
    double? fraction,
    ContactSide? side,
    String? description,
  }) {
    final newFraction = (fraction ?? this.fraction).clamp(0.05, 1.0);
    return BallContactSpec(
      label: label ?? _formatFractionLabel(newFraction),
      fraction: newFraction,
      side: side ?? this.side,
      description: description ?? this.description,
    );
  }

  static String _formatFractionLabel(double f) {
    if ((f - 0.125).abs() < 0.04) return '1/8 trái';
    if ((f - 0.25).abs() < 0.04) return '1/4 trái';
    if ((f - 0.33).abs() < 0.04) return '1/3 trái';
    if ((f - 0.50).abs() < 0.04) return '1/2 trái';
    if ((f - 0.66).abs() < 0.04) return '2/3 trái';
    if ((f - 0.75).abs() < 0.04) return '3/4 trái';
    if (f >= 0.92) return 'Tràn mặt';
    return '${(f * 100).round()}% trái';
  }
}

/// 2. Thông số ÉP-PHÊ & TÂM BI CHỦ (Cue Ball Spin / Effet)
/// Kế thừa từ [BilliardVisualSpec], biểu diễn điểm đầu cơ chạm vào bi chủ theo:
/// - Ngang (horizontalEffet): từ -4 (4 ép-phê trái) đến +4 (4 ép-phê phải)
/// - Dọc (verticalHeight): từ -4 (6h tối đa - Rétro sâu) đến +4 (12h tối đa - Coulé cao)
class CueBallEffetSpec extends BilliardVisualSpec {
  /// Mức ép-phê ngang: âm là Trái, dương là Phải (-4.0 .. +4.0)
  final double horizontalEffet;

  /// Độ cao đầu cơ: dương là Cao/Cu-lê (12h), âm là Thấp/Trô (6h) (-4.0 .. +4.0)
  final double verticalHeight;

  const CueBallEffetSpec({
    required super.label,
    required this.horizontalEffet,
    required this.verticalHeight,
    super.description,
  });

  /// Chuyển đổi sang tọa độ chuẩn hóa (-1.0 .. +1.0) để vẽ trên mặt bi chủ
  /// Lưu ý trên Canvas: trục Y hướng xuống nên verticalHeight dương (12h) có dy âm.
  Offset get normalizedTipOffset {
    final dx = (horizontalEffet / 4.0).clamp(-1.0, 1.0);
    final dy = (-verticalHeight / 4.0).clamp(-1.0, 1.0);
    final vector = Offset(dx, dy);
    if (vector.distance > 0.88) {
      return vector / vector.distance * 0.88;
    }
    return vector;
  }

  /// Khởi tạo nhanh từ mức Cao/Thấp và số mũi Ép-phê
  factory CueBallEffetSpec.fromTips({
    required double horizontalTips, // -4..+4
    required double verticalTips, // -4..+4 (âm: Trô 6h, dương: Cu-lê 12h)
    String? customLabel,
    String? description,
  }) {
    return CueBallEffetSpec(
      label: customLabel ?? _buildAutoLabel(horizontalTips, verticalTips),
      horizontalEffet: horizontalTips,
      verticalHeight: verticalTips,
      description: description,
    );
  }

  CueBallEffetSpec copyWith({
    double? horizontalEffet,
    double? verticalHeight,
    String? label,
    String? description,
  }) {
    final h = (horizontalEffet ?? this.horizontalEffet).clamp(-4.0, 4.0);
    final v = (verticalHeight ?? this.verticalHeight).clamp(-4.0, 4.0);
    return CueBallEffetSpec(
      label: label ?? _buildAutoLabel(h, v),
      horizontalEffet: h,
      verticalHeight: v,
      description: description ?? this.description,
    );
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

    if (h.abs() < 0.3) {
      return '$vPart • Không ép-phê';
    }
    final side = h > 0 ? 'Phải' : 'Trái';
    final tips = h.abs().toStringAsFixed(h.abs() % 1 == 0 ? 0 : 1);
    return '$vPart • $tips Ép-phê $side';
  }
}

/// 3. Thông số SƠ ĐỒ HÌNH BI TRÊN BÀN (Carom Table Diagram Spec)
/// Kế thừa từ [BilliardVisualSpec], dùng lại cho cả bài học Kĩ thuật, Gom bi, Bộ số và Seri.
/// Tọa độ chuẩn hóa theo 8 nút băng dài (X: 0.0..8.0) x 4 nút băng ngắn (Y: 0.0..4.0).
class TableDiagramSpec extends BilliardVisualSpec {
  final Offset cueBall; // Bi chủ (Trắng)
  final Offset objectBall1; // Bi mục tiêu 1 (Vàng)
  final Offset objectBall2; // Bi mục tiêu 2 (Đỏ)
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
    required this.cueBallPath,
    required this.objectBall1Path,
    required this.objectBall2Path,
    this.targetZoneCenter,
    this.targetZoneRadius = 0.65,
    this.showDiamondNumbers = false,
    this.showCornerZones = true,
  });

  /// Tạo bản sao đã lật ngang / lật dọc bàn (giúp người tập xem hình bi ở cả 4 góc bàn)
  TableDiagramSpec flipped({bool flipHorizontal = false, bool flipVertical = false}) {
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
}

