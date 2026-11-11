import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';
import '../widgets/diagrams/base_billiard_diagram.dart';
import '../widgets/diagrams/carom_table_diagram.dart';
import '../widgets/diagrams/shot_parameters_panel.dart';

/// Màn hình Luyện phản xạ / Đố hình bi (Flashcard Drill Mode):
/// Tái sử dụng [CaromTableDiagram] với chế độ ẩn đường chạy lúc đầu (hideTrajectories: true),
/// sau khi người học tự tính Độ dày Chạm trái & Ép-phê mới bấm "Hiện lời giải" để đối chiếu.
class FlashcardDrillScreen extends StatefulWidget {
  final List<BilliardLesson> lessons;
  final void Function(String lessonId) onMarkPracticed;

  const FlashcardDrillScreen({
    super.key,
    required this.lessons,
    required this.onMarkPracticed,
  });

  @override
  State<FlashcardDrillScreen> createState() => _FlashcardDrillScreenState();
}

class _FlashcardDrillScreenState extends State<FlashcardDrillScreen> {
  int _currentIndex = 0;
  bool _revealed = false;
  int _masteredCount = 0;

  // Cho phép người tập chọn thử thông số dự đoán trước khi lật đáp án
  BallContactSpec _guessedContact = BallContactSpec.half();
  CueBallEffetSpec _guessedEffet =
      CueBallEffetSpec.fromTips(horizontalTips: 0, verticalTips: 0);

  void _nextCard({required bool mastered}) {
    final current = widget.lessons[_currentIndex];
    if (mastered) {
      _masteredCount++;
      widget.onMarkPracticed(current.id);
    }
    if (_currentIndex < widget.lessons.length - 1) {
      setState(() {
        _currentIndex++;
        _revealed = false;
        _guessedContact = BallContactSpec.half();
        _guessedEffet =
            CueBallEffetSpec.fromTips(horizontalTips: 0, verticalTips: 0);
      });
    } else {
      _showFinishDialog();
    }
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BilliardPalette.cardBackground,
        title: const Text('Hoàn thành lượt ôn tập!'),
        content: Text(
          'Bạn đã ghi nhớ chính xác $_masteredCount / ${widget.lessons.length} hình bi Libre.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentIndex = 0;
                _revealed = false;
                _masteredCount = 0;
              });
            },
            child: const Text('Luyện lại từ đầu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lessons[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Đố Hình Bi (${_currentIndex + 1}/${widget.lessons.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                'Đã thuộc: $_masteredCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: BilliardPalette.diamondGold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Tiến độ
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.lessons.length,
            backgroundColor: BilliardPalette.cardBorder,
            color: BilliardPalette.diamondGold,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 14),

          // Câu hỏi tình huống
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BilliardPalette.diamondGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lesson.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: BilliardPalette.diamondGold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _revealed
                ? 'ĐÁP ÁN CHUẨN: Đối chiếu đường đi 3 bi và thông số bên dưới.'
                : 'CÂU HỎI: Quan sát vị trí 3 bi (Trắng - Vàng - Đỏ). Hãy chọn Độ dày chạm trái & Điểm chạm đầu cơ trước khi mở đáp án!',
            style: TextStyle(
              fontSize: 13,
              color: _revealed
                  ? BilliardPalette.cueTrajectory
                  : Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),

          // Sơ đồ bàn: Ẩn đường chạy khi chưa lật thẻ, hiện đầy đủ kèm nút chạy mô phỏng khi đã lật
          CaromTableDiagram(
            spec: lesson.diagram,
            mode: DiagramDisplayMode.interactive,
            hideTrajectories: !_revealed,
            titleOverride: _revealed
                ? 'ĐÁP ÁN ĐƯỜNG ĐI 3 BI (BẤM MÔ PHỎNG ĐỂ XEM CHUYỂN ĐỘNG)'
                : 'THẾ BI TRÊN BÀN (ĐÃ ẨN ĐƯỜNG CHẠY)',
          ),
          const SizedBox(height: 16),

          if (!_revealed) ...[
            const Text(
              'DỰ ĐOÁN CỦA BẠN (CHẠM ĐỂ CHỌN THỬ):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BilliardPalette.diamondGold,
              ),
            ),
            const SizedBox(height: 8),
            ShotParametersDetailPanel(
              params: ShotParameters(
                contact: _guessedContact,
                effet: _guessedEffet,
                strokeType: 'Hãy ước lượng kiểu ra cơ & lực đánh',
                speedLevel: 2,
              ),
              mode: DiagramDisplayMode.interactive,
              onContactChanged: (c) => setState(() => _guessedContact = c),
              onEffetChanged: (e) => setState(() => _guessedEffet = e),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.visibility),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'LẬT THẺ XEM ĐÁP ÁN & ĐƯỜNG BI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'THÔNG SỐ KĨ THUẬT CHUẨN:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BilliardPalette.diamondGold,
              ),
            ),
            const SizedBox(height: 8),
            ShotParametersDetailPanel(
              params: lesson.shotParams,
              mode: DiagramDisplayMode.standard,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BilliardPalette.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BilliardPalette.cardBorder),
              ),
              child: Text(
                '• Mục tiêu: ${lesson.objective}\n• Lưu ý: ${lesson.commonMistakes.first}',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _nextCard(mastered: false),
                    icon: const Icon(Icons.refresh),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Cần ôn lại'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _nextCard(mastered: true),
                    icon: const Icon(Icons.check),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Đã thuộc (+1 Lượt)'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

