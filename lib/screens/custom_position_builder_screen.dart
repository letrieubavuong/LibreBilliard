import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';
import '../widgets/diagrams/base_billiard_diagram.dart';
import '../widgets/diagrams/carom_table_diagram.dart';
import '../widgets/diagrams/shot_parameters_panel.dart';

/// Màn hình Tự Xếp Hình Bi & Lưu Ghi Chú Cá Nhân (Custom Position Builder):
/// Tái sử dụng [CaromTableDiagram] (chế độ kéo thả trực tiếp 3 bi trên bàn),
/// kết hợp [BallContactDiagram] và [CueBallEffetDiagram] (chế độ Interactive).
class CustomPositionBuilderScreen extends StatefulWidget {
  final int nextCustomIndex;

  const CustomPositionBuilderScreen({
    super.key,
    required this.nextCustomIndex,
  });

  @override
  State<CustomPositionBuilderScreen> createState() =>
      _CustomPositionBuilderScreenState();
}

class _CustomPositionBuilderScreenState
    extends State<CustomPositionBuilderScreen> {
  final _titleController = TextEditingController(
    text: 'Hình gom bi tự ghi chú tại CLB',
  );
  final _noteController = TextEditingController(
    text: 'Chú ý vào cơ êm tay, giữ bi số 1 quay về sát vạch ô cấm.',
  );

  LessonCategory _selectedCategory = LessonCategory.gathering;
  int _speedLevel = 2;

  Offset _cueBall = const Offset(3.0, 2.1);
  Offset _objectBall1 = const Offset(2.0, 1.3);
  Offset _objectBall2 = const Offset(1.35, 0.85);
  Offset _targetZone = const Offset(1.25, 0.78);

  BallContactSpec _contact = BallContactSpec.oneThird();
  CueBallEffetSpec _effet =
      CueBallEffetSpec.fromTips(horizontalTips: 1.0, verticalTips: -1.5);

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TableDiagramSpec _buildCurrentDiagramSpec() {
    // Tự động tính đường đi minh họa từ Bi chủ -> Bi 1 -> Bi 2 -> Vùng gom
    // và Bi 1 chạm băng gần nhất quay về Vùng gom
    final railBounce = Offset(_objectBall1.dx * 0.7, 0.0);
    return TableDiagramSpec(
      label: 'Kéo thả trực tiếp 3 bi hoặc vùng gom vàng trên mặt bàn',
      description:
          'Trắng (${_cueBall.dx.toStringAsFixed(1)}, ${_cueBall.dy.toStringAsFixed(1)}) • Vàng (${_objectBall1.dx.toStringAsFixed(1)}, ${_objectBall1.dy.toStringAsFixed(1)}) • Đỏ (${_objectBall2.dx.toStringAsFixed(1)}, ${_objectBall2.dy.toStringAsFixed(1)})',
      cueBall: _cueBall,
      objectBall1: _objectBall1,
      objectBall2: _objectBall2,
      cueBallPath: [_objectBall1, _objectBall2, _targetZone],
      objectBall1Path: [railBounce, _targetZone],
      objectBall2Path: [_targetZone],
      targetZoneCenter: _targetZone,
      targetZoneRadius: 0.52,
      showDiamondNumbers: true,
      showCornerZones: true,
    );
  }

  void _onElementDragged(DraggableTableElement element, Offset newCoord) {
    setState(() {
      switch (element) {
        case DraggableTableElement.cueBall:
          _cueBall = newCoord;
          break;
        case DraggableTableElement.objectBall1:
          _objectBall1 = newCoord;
          break;
        case DraggableTableElement.objectBall2:
          _objectBall2 = newCoord;
          break;
        case DraggableTableElement.targetZone:
          _targetZone = newCoord;
          break;
      }
    });
  }

  void _savePosition() {
    final code = 'MY-${widget.nextCustomIndex.toString().padLeft(2, '0')}';
    final title = _titleController.text.trim().isEmpty
        ? 'Hình bi cá nhân $code'
        : _titleController.text.trim();
    final note = _noteController.text.trim().isEmpty
        ? 'Thực hiện đúng độ dày chạm trái và điểm chạm đầu cơ đã thiết lập.'
        : _noteController.text.trim();

    final newLesson = BilliardLesson(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      title: title,
      subtitle: 'Hình bi tự thiết kế • ${_contact.label} • ${_effet.label}',
      category: _selectedCategory,
      subCategory: 'Sổ tay cá nhân',
      difficulty: 'Tự tạo',
      diagram: _buildCurrentDiagramSpec(),
      shotParams: ShotParameters(
        contact: _contact,
        effet: _effet,
        strokeType: 'Theo cảm giác tay cá nhân',
        speedLevel: _speedLevel,
      ),
      objective: note,
      executionSteps: [
        'Đặt vị trí 3 bi theo sơ đồ tọa độ trên bàn.',
        'Ngắm độ dày ${_contact.label} (${_contact.side.title}) vào bi Vàng.',
        'Đặt mũi cơ tại ${_effet.label} với mức lực $_speedLevel/5.',
      ],
      commonMistakes: [
        'Lưu ý điều chỉnh lực theo độ trơn thực tế của vải bàn tại CLB.',
      ],
    );

    Navigator.of(context).pop(newLesson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tạo Hình Bi Mới',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: _savePosition,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Lưu vào Sổ tay'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 1. Sơ đồ bàn Kéo-Thả trực tiếp
          CaromTableDiagram(
            spec: _buildCurrentDiagramSpec(),
            mode: DiagramDisplayMode.interactive,
            titleOverride: 'CHẠM & KÉO 3 BI TRỰC TIẾP TRÊN MẶT BÀN',
            onElementDragged: _onElementDragged,
          ),
          const SizedBox(height: 16),

          // 2. Chọn thông số Chạm trái & Ép-phê (tái sử dụng Widget kế thừa)
          const Text(
            'CHỌN ĐỘ DÀY CHẠM TRÁI & ĐIỂM CHẠM BI CHỦ:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: BilliardPalette.diamondGold,
            ),
          ),
          const SizedBox(height: 8),
          ShotParametersDetailPanel(
            params: ShotParameters(
              contact: _contact,
              effet: _effet,
              strokeType: 'Kéo thanh trượt bên dưới để chọn lực đánh',
              speedLevel: _speedLevel,
            ),
            mode: DiagramDisplayMode.interactive,
            onContactChanged: (c) => setState(() => _contact = c),
            onEffetChanged: (e) => setState(() => _effet = e),
          ),
          const SizedBox(height: 12),

          // 3. Chọn mức lực & Chuyên mục
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BilliardPalette.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BilliardPalette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mức lực đánh:',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Slider(
                        value: _speedLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: 'Lực $_speedLevel/5',
                        onChanged: (v) =>
                            setState(() => _speedLevel = v.round()),
                      ),
                    ),
                    Text(
                      '$_speedLevel/5',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BilliardPalette.diamondGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<LessonCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Phân vào chuyên mục Bottom Bar',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: LessonCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.title),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tên hình bi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú kinh nghiệm / Điểm cần lưu ý',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

