import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';
import '../models/carom_physics_solver.dart';
import '../widgets/diagrams/base_billiard_diagram.dart';
import '../widgets/diagrams/carom_table_diagram.dart';
import '../widgets/diagrams/shot_parameters_panel.dart';

class LessonDetailScreen extends StatefulWidget {
  final BilliardLesson lesson;
  final bool isBookmarked;
  final int practiceCount;
  final String? personalNote;
  final VoidCallback onToggleBookmark;
  final VoidCallback onIncrementPractice;
  final Future<bool> Function(String)? onSavePersonalNote;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    required this.isBookmarked,
    required this.practiceCount,
    this.personalNote,
    required this.onToggleBookmark,
    required this.onIncrementPractice,
    this.onSavePersonalNote,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  late bool _bookmarked;
  late int _count;
  late BallContactSpec _activeContact;
  late CueBallEffetSpec _activeEffet;
  late int _activeSpeedLevel;
  late TextEditingController _noteController;
  bool _customizeMode = false;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;
    _count = widget.practiceCount;
    _activeContact = widget.lesson.shotParams.contact;
    _activeEffet = widget.lesson.shotParams.effet;
    _activeSpeedLevel = widget.lesson.shotParams.speedLevel;
    _noteController = TextEditingController(text: widget.personalNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final solvedOutcome = CaromPhysicsSolver.evaluateAdjustedShot(
      lesson: lesson,
      activeContact: _activeContact,
      activeEffet: _activeEffet,
      activeSpeedLevel: _activeSpeedLevel,
    );
    final isSuccess = solvedOutcome.isSuccessfulShot;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BilliardPalette.diamondGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BilliardPalette.diamondGold),
              ),
              child: Text(
                lesson.code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: BilliardPalette.diamondGold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lesson.title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _bookmarked ? 'Bỏ lưu sổ tay' : 'Lưu vào sổ tay',
            onPressed: () {
              setState(() => _bookmarked = !_bookmarked);
              widget.onToggleBookmark();
            },
            icon: Icon(
              _bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _bookmarked ? BilliardPalette.diamondGold : Colors.white,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 28),
        children: [
          // 1. Tiêu đề & Nhãn phân loại
          Text(
            lesson.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lesson.subtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _BadgeChip(
                icon: lesson.category.icon,
                label: '${lesson.category.title} • ${lesson.subCategory}',
              ),
              _BadgeChip(
                icon: Icons.signal_cellular_alt,
                label: 'Độ khó: ${lesson.difficulty}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. SƠ ĐỒ BÀN TƯƠNG TÁC (Nhận trực tiếp SimulationResult từ CaromPhysicsEngine)
          CaromTableDiagram(
            spec: solvedOutcome.updatedDiagram,
            simulationResult: solvedOutcome.simulationResult,
            mode: DiagramDisplayMode.interactive,
            titleOverride: 'SƠ ĐỒ BÀN & MÔ PHỎNG VẬT LÝ SI (CHÍNH XÁC)',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSuccess
                  ? const Color(0xFF153826)
                  : const Color(0xFF3A1D1D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSuccess
                    ? BilliardPalette.diamondGold
                    : BilliardPalette.chalkTipRed,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: isSuccess
                      ? BilliardPalette.diamondGold
                      : BilliardPalette.chalkTipRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solvedOutcome.feedbackMessage,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. CÔNG THỨC BỘ SỐ (nếu thuộc mục Bộ số)
          if (lesson.systemFormula != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2B1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BilliardPalette.diamondGold),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.functions,
                    color: BilliardPalette.diamondGold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CÔNG THỨC BỘ SỐ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: BilliardPalette.diamondGold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lesson.systemFormula!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. BỘ THÔNG SỐ KĨ THUẬT (Kế thừa từ BallContactDiagram & CueBallEffetDiagram)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'THÔNG SỐ CÚ ĐÁNH (CHẠM TRÁI, ÉP-PHÊ & LỰC)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: BilliardPalette.diamondGold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _customizeMode = !_customizeMode;
                    if (!_customizeMode) {
                      _activeContact = lesson.shotParams.contact;
                      _activeEffet = lesson.shotParams.effet;
                      _activeSpeedLevel = lesson.shotParams.speedLevel;
                    }
                  });
                },
                icon: Icon(
                  _customizeMode ? Icons.restart_alt : Icons.tune,
                  size: 16,
                ),
                label: Text(
                  _customizeMode ? 'Về chuẩn gốc' : 'Thử chỉnh',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          ShotParametersDetailPanel(
            params: ShotParameters(
              contact: _activeContact,
              effet: _activeEffet,
              strokeType: lesson.shotParams.strokeType,
              speedLevel: _activeSpeedLevel,
            ),
            mode: _customizeMode
                ? DiagramDisplayMode.interactive
                : DiagramDisplayMode.standard,
            onContactChanged: (newContact) =>
                setState(() => _activeContact = newContact),
            onEffetChanged: (newEffet) =>
                setState(() => _activeEffet = newEffet),
            onSpeedLevelChanged: (newSpeed) =>
                setState(() => _activeSpeedLevel = newSpeed),
          ),
          const SizedBox(height: 18),

          // 5. MỤC TIÊU HÌNH BI & TƯ DUY GOM BI
          _SectionCard(
            title: 'MỤC TIÊU & HÌNH BI TIẾP THEO',
            icon: Icons.flag_outlined,
            accentColor: BilliardPalette.cueTrajectory,
            child: Text(
              lesson.objective,
              style: const TextStyle(fontSize: 14, height: 1.48),
            ),
          ),
          const SizedBox(height: 14),

          // 6. CÁC BƯỚC THỰC HIỆN CHI TIẾT
          _SectionCard(
            title: 'CÁC BƯỚC THỰC HIỆN TẠI BÀN',
            icon: Icons.format_list_numbered,
            accentColor: BilliardPalette.diamondGold,
            child: Column(
              children: List.generate(lesson.executionSteps.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor:
                            BilliardPalette.diamondGold.withValues(alpha: 0.2),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: BilliardPalette.diamondGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lesson.executionSteps[i],
                          style: const TextStyle(fontSize: 13.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // 7. LỖI THƯỜNG GẶP & CÁCH KHẮC PHỤC
          _SectionCard(
            title: 'LỖI THƯỜNG GẶP (CẦN TRÁNH)',
            icon: Icons.warning_amber_rounded,
            accentColor: BilliardPalette.chalkTipRed,
            child: Column(
              children: lesson.commonMistakes.map((err) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: BilliardPalette.chalkTipRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          err,
                          style: const TextStyle(fontSize: 13.5, height: 1.42),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 8. GHI CHÚ CÁ NHÂN TẠI CLB
          _SectionCard(
            title: 'GHI CHÚ CÁ NHÂN TẠI BÀN TẬP',
            icon: Icons.edit_note,
            accentColor: BilliardPalette.diamondGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText:
                        'VD: Bàn CLB vải mới trơn, giảm 0.5 mũi ép-phê và đánh nhẹ tay hơn...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: BilliardPalette.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    final scaffold = ScaffoldMessenger.of(context);
                    final saveFuture = widget.onSavePersonalNote?.call(_noteController.text.trim());
                    final ok = saveFuture != null ? await saveFuture : true;
                    if (!mounted) return;
                    if (ok) {
                      scaffold.showSnackBar(
                        const SnackBar(
                          content:
                              Text('Đã lưu ghi chú cá nhân cho hình bi này!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      scaffold.showSnackBar(
                        const SnackBar(
                          content:
                              Text('Lỗi: Không thể lưu ghi chú vào bộ nhớ!'),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label:
                      const Text('Lưu ghi chú', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 9. BỘ ĐẾM LUYỆN TẬP TẠI BÀN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BilliardPalette.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BilliardPalette.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: BilliardPalette.diamondGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theo dõi lượt tập hình bi này',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Đã hoàn thành: $_count lượt tập (Mục tiêu: 10 lượt/buổi)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _count++);
                    widget.onIncrementPractice();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+1 Lượt tập'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BilliardPalette.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BilliardPalette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BilliardPalette.diamondGold),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: BilliardPalette.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BilliardPalette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
