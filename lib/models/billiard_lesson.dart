import 'package:flutter/material.dart';
import 'billiard_specs.dart';

export 'billiard_specs.dart';

enum LessonCategory {
  technique(
    id: 'technique',
    title: 'Kĩ thuật',
    subtitle: 'Nền tảng cơ học, cảm giác tay & cú đánh cơ bản',
    icon: Icons.sports_handball,
  ),
  gathering(
    id: 'gathering',
    title: 'Hình gom bi',
    subtitle: 'Đưa bi từ thế rời rạc về khu vực góc & dọc băng',
    icon: Icons.hub_outlined,
  ),
  system(
    id: 'system',
    title: 'Bộ số',
    subtitle: 'Công thức tính nút băng 1 băng, 2 băng, 3 băng',
    icon: Icons.calculate_outlined,
  ),
  serie(
    id: 'serie',
    title: 'Seri & Dẫn bi',
    subtitle: 'Giữ nhịp seri dọc băng và xoay sở quanh ô cấm góc',
    icon: Icons.all_inclusive,
  );

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const LessonCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  static LessonCategory fromId(String? id) {
    return LessonCategory.values.firstWhere(
      (c) => c.id == id || c.name == id,
      orElse: () => LessonCategory.gathering,
    );
  }
}

/// Tổ hợp các thông số kĩ thuật và đầu vào vật lý của một cú đánh:
/// Kết hợp kế thừa từ [BallContactSpec] (Chạm trái) và [CueBallEffetSpec] (Ép-phê/Tâm bi),
/// cùng mức lực, góc nâng cơ (Massé/Piqué) và điểm ngắm băng (nếu đánh A-băng / Bricole).
class ShotParameters {
  final BallContactSpec contact; // Độ dày chạm trái (1/8, 1/4, 1/3, 1/2, 2/3, 3/4, Tràn mặt)
  final CueBallEffetSpec effet; // Điểm chạm bi chủ (12h/6h + Ép-phê Trái/Phải)
  final String strokeType; // Kiểu ra cơ: Đẩy mượt (Poussé), Giữ ngọn (Rétro), Phanh (Amorti)
  final int speedLevel; // Mức lực: 1..5

  /// Tốc độ ngọn cơ tinh chỉnh (m/s) nếu bài học cần vận tốc cụ thể ngoài 5 bậc mặc định.
  final double? customCueSpeed;

  /// Góc nâng chuôi cơ (độ) cho các đòn Piqué / Massé (mặc định 0°).
  final double cueElevationDegrees;

  /// Điểm ngắm trên bàn (theo đơn vị nút băng 0..8 x 0..4) dùng cho các cú đánh chạm băng trước (Bricole / A-băng)
  /// hoặc khi người dùng tự xoay hướng ngắm tự do trong Position Builder.
  final Offset? aimTargetDiamond;

  /// Góc ngắm tường minh (radian) trong hệ tọa độ bàn (nếu được chỉ định trực tiếp).
  final double? explicitAimAngleRadians;

  const ShotParameters({
    required this.contact,
    required this.effet,
    required this.strokeType,
    required this.speedLevel,
    this.customCueSpeed,
    this.cueElevationDegrees = 0.0,
    this.aimTargetDiamond,
    this.explicitAimAngleRadians,
  });

  ShotParameters copyWith({
    BallContactSpec? contact,
    CueBallEffetSpec? effet,
    String? strokeType,
    int? speedLevel,
    double? customCueSpeed,
    double? cueElevationDegrees,
    Offset? aimTargetDiamond,
    bool clearAimTarget = false,
    double? explicitAimAngleRadians,
    bool clearExplicitAimAngle = false,
  }) {
    return ShotParameters(
      contact: contact ?? this.contact,
      effet: effet ?? this.effet,
      strokeType: strokeType ?? this.strokeType,
      speedLevel: (speedLevel ?? this.speedLevel).clamp(1, 5),
      customCueSpeed: customCueSpeed ?? this.customCueSpeed,
      cueElevationDegrees: cueElevationDegrees ?? this.cueElevationDegrees,
      aimTargetDiamond:
          clearAimTarget ? null : (aimTargetDiamond ?? this.aimTargetDiamond),
      explicitAimAngleRadians: clearExplicitAimAngle
          ? null
          : (explicitAimAngleRadians ?? this.explicitAimAngleRadians),
    );
  }

  Map<String, dynamic> toJson() => {
        'contact': contact.toJson(),
        'effet': effet.toJson(),
        'strokeType': strokeType,
        'speedLevel': speedLevel,
        'customCueSpeed': customCueSpeed,
        'cueElevationDegrees': cueElevationDegrees,
        'aimTargetDiamond': aimTargetDiamond != null
            ? [aimTargetDiamond!.dx, aimTargetDiamond!.dy]
            : null,
        'explicitAimAngleRadians': explicitAimAngleRadians,
      };

  factory ShotParameters.fromJson(Map<String, dynamic> json) {
    Offset? aimTarget;
    final rawTarget = json['aimTargetDiamond'];
    if (rawTarget is List && rawTarget.length >= 2) {
      aimTarget = Offset(
        (rawTarget[0] as num).toDouble(),
        (rawTarget[1] as num).toDouble(),
      );
    }

    return ShotParameters(
      contact: json['contact'] is Map<String, dynamic>
          ? BallContactSpec.fromJson(json['contact'] as Map<String, dynamic>)
          : BallContactSpec.half(),
      effet: json['effet'] is Map<String, dynamic>
          ? CueBallEffetSpec.fromJson(json['effet'] as Map<String, dynamic>)
          : CueBallEffetSpec.fromTips(horizontalTips: 0, verticalTips: 0),
      strokeType: json['strokeType'] as String? ?? 'Tiêu chuẩn',
      speedLevel: ((json['speedLevel'] as num?)?.toInt() ?? 2).clamp(1, 5),
      customCueSpeed: (json['customCueSpeed'] as num?)?.toDouble(),
      cueElevationDegrees:
          (json['cueElevationDegrees'] as num?)?.toDouble() ?? 0.0,
      aimTargetDiamond: aimTarget,
      explicitAimAngleRadians:
          (json['explicitAimAngleRadians'] as num?)?.toDouble(),
    );
  }
}

class BilliardLesson {
  final String id;
  final String code; // Mã hình bi (VD: "KT-01", "GB-01", "BS-01", "SR-01")
  final String title;
  final String subtitle;
  final LessonCategory category;
  final String subCategory;
  final String difficulty; // Cơ bản, Trung cấp, Nâng cao
  final TableDiagramSpec diagram;
  final ShotParameters shotParams;
  final String objective;
  final List<String> executionSteps;
  final List<String> commonMistakes;
  final String? systemFormula;

  const BilliardLesson({
    required this.id,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.subCategory,
    required this.difficulty,
    required this.diagram,
    required this.shotParams,
    required this.objective,
    required this.executionSteps,
    required this.commonMistakes,
    this.systemFormula,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'subtitle': subtitle,
        'category': category.id,
        'subCategory': subCategory,
        'difficulty': difficulty,
        'diagram': diagram.toJson(),
        'shotParams': shotParams.toJson(),
        'objective': objective,
        'executionSteps': executionSteps,
        'commonMistakes': commonMistakes,
        'systemFormula': systemFormula,
      };

  factory BilliardLesson.fromJson(Map<String, dynamic> json) {
    return BilliardLesson(
      id: json['id'] as String? ??
          'custom-${DateTime.now().millisecondsSinceEpoch}',
      code: json['code'] as String? ?? 'MY-01',
      title: json['title'] as String? ?? 'Hình bi cá nhân',
      subtitle: json['subtitle'] as String? ?? '',
      category: LessonCategory.fromId(json['category'] as String?),
      subCategory: json['subCategory'] as String? ?? 'Sổ tay cá nhân',
      difficulty: json['difficulty'] as String? ?? 'Tự tạo',
      diagram: json['diagram'] is Map<String, dynamic>
          ? TableDiagramSpec.fromJson(json['diagram'] as Map<String, dynamic>)
          : const TableDiagramSpec(
              cueBall: Offset(3.0, 2.0),
              objectBall1: Offset(2.0, 1.3),
              objectBall2: Offset(1.3, 0.8),
            ),
      shotParams: json['shotParams'] is Map<String, dynamic>
          ? ShotParameters.fromJson(json['shotParams'] as Map<String, dynamic>)
          : ShotParameters(
              contact: BallContactSpec.half(),
              effet: CueBallEffetSpec.fromTips(
                horizontalTips: 0,
                verticalTips: 0,
              ),
              strokeType: 'Tiêu chuẩn',
              speedLevel: 2,
            ),
      objective: json['objective'] as String? ?? '',
      executionSteps: (json['executionSteps'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      commonMistakes: (json['commonMistakes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      systemFormula: json['systemFormula'] as String?,
    );
  }
}
