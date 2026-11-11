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
}

/// Tổ hợp các thông số kĩ thuật của một cú đánh:
/// Kết hợp kế thừa từ [BallContactSpec] (Chạm trái) và [CueBallEffetSpec] (Ép-phê/Tâm bi)
class ShotParameters {
  final BallContactSpec contact; // Độ dày chạm trái (1/8, 1/4, 1/2, 3/4...)
  final CueBallEffetSpec effet; // Điểm chạm bi chủ (12h/6h + Ép-phê Trái/Phải)
  final String strokeType; // Kiểu ra cơ: Đẩy mượt (Poussé), Giữ ngọn (Rétro), Phanh (Amorti)
  final int speedLevel; // Mức lực: 1..5

  const ShotParameters({
    required this.contact,
    required this.effet,
    required this.strokeType,
    required this.speedLevel,
  });
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
}
