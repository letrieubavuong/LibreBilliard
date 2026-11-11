import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';
import 'diagrams/base_billiard_diagram.dart';
import 'diagrams/carom_table_diagram.dart';
import 'diagrams/shot_parameters_panel.dart';

/// Card hiển thị bài học trong danh sách:
/// Tái sử dụng cả 3 sơ đồ kế thừa ([CaromTableDiagram] dọc 1:2, [BallContactDiagram], [CueBallEffetDiagram])
/// ở chế độ [DiagramDisplayMode.thumbnail] để người tập nhìn lướt qua là thấy ngay Hình bi - Độ dày - Ép-phê.
class LessonCard extends StatelessWidget {
  final BilliardLesson lesson;
  final bool isBookmarked;
  final int practiceCount;
  final String? personalNote;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.isBookmarked,
    required this.practiceCount,
    this.personalNote,
    required this.onTap,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: BilliardPalette.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BilliardPalette.cardBorder, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng trên: Mã bài học, Chuyên mục con, Độ khó & Bookmark
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          BilliardPalette.diamondGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: BilliardPalette.diamondGold
                              .withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      lesson.code,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: BilliardPalette.diamondGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${lesson.subCategory} • ${lesson.difficulty}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (practiceCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          'Đã tập $practiceCount×',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleBookmark,
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: isBookmarked
                          ? BilliardPalette.diamondGold
                          : Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Hàng giữa: Tiêu đề + Mục tiêu tóm tắt bên trái, Sơ đồ Bàn Carom DỌC bên phải
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.38,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lesson.objective,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.56),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sơ đồ bàn Carom dọc thu nhỏ (tỉ lệ 1:2 dọc theo màn hình)
                  SizedBox(
                    width: 92,
                    child: CaromTableDiagram(
                      spec: lesson.diagram,
                      mode: DiagramDisplayMode.thumbnail,
                    ),
                  ),
                ],
              ),
              if (personalNote != null && personalNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: BilliardPalette.diamondGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          BilliardPalette.diamondGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note,
                        size: 16,
                        color: BilliardPalette.diamondGold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ghi chú: $personalNote',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Hàng dưới: Thanh tóm tắt Chạm trái + Tâm bi Ép-phê (tái sử dụng thumbnail)
              ShotParametersSummaryBar(params: lesson.shotParams),
            ],
          ),
        ),
      ),
    );
  }
}
