import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';
import '../models/carom_physics_solver.dart';
import '../physics/billiard_physics.dart';
import '../widgets/diagrams/base_billiard_diagram.dart';
import '../widgets/diagrams/carom_table_diagram.dart';
import '../widgets/diagrams/shot_parameters_panel.dart';

/// Màn hình Tự Xếp Hình Bi & Lưu Ghi Chú Cá Nhân (Custom Position Builder):
/// - Chạy trực tiếp Engine Vật lý (`CaromPhysicsSolver` / `CaromPhysicsEngine`) theo thời gian thực khi người dùng
///   kéo thả 3 bi, vùng gom, điểm ngắm hoặc điều chỉnh Độ dày, Ép-phê, Lực.
/// - Tuyệt đối không nối thẳng các đoạn thẳng giả định tới `_targetZone`.
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
  bool _previewPlayMode = false;
  bool _useFreeAimHandle = false;

  Offset _cueBall = const Offset(3.0, 2.1);
  Offset _objectBall1 = const Offset(2.0, 1.3);
  Offset _objectBall2 = const Offset(1.35, 0.85);
  Offset _targetZone = const Offset(1.25, 0.78);
  Offset _freeAimTarget = const Offset(1.9, 1.2);

  BallContactSpec _contact = BallContactSpec.oneThird();
  CueBallEffetSpec _effet =
      CueBallEffetSpec.fromTips(horizontalTips: 1.0, verticalTips: -1.5);

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TableDiagramSpec _buildBaseDiagramSpec({
    List<Offset> cueGuide = const [],
    List<Offset> obj1Guide = const [],
    List<Offset> obj2Guide = const [],
  }) {
    return TableDiagramSpec(
      label: _previewPlayMode
          ? 'Chế độ Mô phỏng Vật lý: Bấm Play để chạy thử hình bi'
          : 'Chạm & kéo trực tiếp 3 bi hoặc vùng gom trên mặt bàn',
      description:
          'Trắng (${_cueBall.dx.toStringAsFixed(1)}, ${_cueBall.dy.toStringAsFixed(1)}) • Vàng (${_objectBall1.dx.toStringAsFixed(1)}, ${_objectBall1.dy.toStringAsFixed(1)}) • Đỏ (${_objectBall2.dx.toStringAsFixed(1)}, ${_objectBall2.dy.toStringAsFixed(1)})',
      cueBall: _cueBall,
      objectBall1: _objectBall1,
      objectBall2: _objectBall2,
      cueBallPath: cueGuide,
      objectBall1Path: obj1Guide,
      objectBall2Path: obj2Guide,
      targetZoneCenter: _targetZone,
      targetZoneRadius: 0.56,
      showDiamondNumbers: true,
      showCornerZones: true,
    );
  }

  SolvedShotOutcome _solveCurrentPosition() {
    final baseDiagram = _buildBaseDiagramSpec();
    final input = CaromPhysicsSolver.buildShotInput(
      diagram: baseDiagram,
      contact: _contact,
      effet: _effet,
      speedLevel: _speedLevel,
      aimTargetDiamond: _useFreeAimHandle ? _freeAimTarget : null,
    );
    return CaromPhysicsSolver.evaluateShotInput(
      baseDiagram: baseDiagram,
      input: input,
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
        case DraggableTableElement.aimHandle:
          _freeAimTarget = newCoord;
          break;
      }
    });
  }

  List<Offset> _compressTrajectoryToGuide(List<Offset> dense) {
    if (dense.length <= 1) return const [];
    final out = <Offset>[];
    Offset last = dense.first;
    for (int i = 1; i < dense.length - 1; i++) {
      if ((dense[i] - last).distance >= 0.35) {
        out.add(dense[i]);
        last = dense[i];
      }
    }
    if ((dense.last - dense.first).distance >= 0.08) {
      out.add(dense.last);
    }
    return out;
  }

  void _savePosition() {
    final solved = _solveCurrentPosition();
    final sim = solved.simulationResult;
    final cueDiamonds = sim
        .trajectoryDiamondsOf(BallId.cue)
        .map((v) => Offset(v.x, v.y))
        .toList();
    final obj1Diamonds = sim
        .trajectoryDiamondsOf(BallId.object1)
        .map((v) => Offset(v.x, v.y))
        .toList();
    final obj2Diamonds = sim
        .trajectoryDiamondsOf(BallId.object2)
        .map((v) => Offset(v.x, v.y))
        .toList();

    final code = 'MY-${widget.nextCustomIndex.toString().padLeft(2, '0')}';
    final title = _titleController.text.trim().isEmpty
        ? 'Hình bi cá nhân $code'
        : _titleController.text.trim();
    final note = _noteController.text.trim().isEmpty
        ? 'Thực hiện đúng độ dày chạm trái và điểm chạm đầu cơ đã thiết lập.'
        : _noteController.text.trim();

    final savedDiagram = _buildBaseDiagramSpec(
      cueGuide: _compressTrajectoryToGuide(cueDiamonds),
      obj1Guide: _compressTrajectoryToGuide(obj1Diamonds),
      obj2Guide: _compressTrajectoryToGuide(obj2Diamonds),
    );

    final newLesson = BilliardLesson(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      title: title,
      subtitle: 'Hình bi tự thiết kế • ${_contact.label} • ${_effet.label}',
      category: _selectedCategory,
      subCategory: 'Sổ tay cá nhân',
      difficulty: 'Tự tạo',
      diagram: savedDiagram,
      shotParams: ShotParameters(
        contact: _contact,
        effet: _effet,
        strokeType: 'Theo cảm giác tay cá nhân',
        speedLevel: _speedLevel,
        aimTargetDiamond: _useFreeAimHandle ? _freeAimTarget : null,
      ),
      objective: note,
      executionSteps: [
        'Đặt vị trí 3 bi theo sơ đồ tọa độ trên bàn.',
        _useFreeAimHandle
            ? 'Ngắm theo tia hướng dẫn tới tọa độ (${_freeAimTarget.dx.toStringAsFixed(1)}, ${_freeAimTarget.dy.toStringAsFixed(1)}).'
            : 'Ngắm độ dày ${_contact.label} (${_contact.side.title}) vào bi Vàng.',
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
    final solved = _solveCurrentPosition();
    final isSuccess = solved.isSuccessfulShot;

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
          // Thanh chuyển nhanh chế độ Kéo Bi <-> Chạy thử Mô phỏng và kiểu Ngắm
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.open_with, size: 16),
                label: const Text('Kéo xếp 3 bi', style: TextStyle(fontSize: 12)),
                selected: !_previewPlayMode,
                onSelected: (_) => setState(() => _previewPlayMode = false),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text(
                  'Chạy thử mô phỏng',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _previewPlayMode,
                onSelected: (_) => setState(() => _previewPlayMode = true),
              ),
              FilterChip(
                avatar: const Icon(Icons.explore_outlined, size: 16),
                label: Text(
                  _useFreeAimHandle ? 'Ngắm tự do 360°' : 'Ngắm theo Bi 1',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _useFreeAimHandle,
                onSelected: (v) {
                  setState(() {
                    _useFreeAimHandle = v;
                    if (_useFreeAimHandle) {
                      _freeAimTarget = _objectBall1;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Sơ đồ bàn Kéo-Thả trực tiếp hoặc Chạy thử mô phỏng
          CaromTableDiagram(
            spec: solved.updatedDiagram,
            simulationResult: solved.simulationResult,
            mode: DiagramDisplayMode.interactive,
            titleOverride: _previewPlayMode
                ? 'CHẠY THỬ MÔ PHỎNG VẬT LÝ TRÊN HÌNH BI VỪA XẾP'
                : 'CHẠM ĐÚNG BI ĐỂ KÉO (GIỮ KHOẢNG CÁCH KHÔNG CHỒNG LẤP)',
            aimHandleDiamond:
                (!_previewPlayMode && _useFreeAimHandle) ? _freeAimTarget : null,
            onElementDragged: _previewPlayMode ? null : _onElementDragged,
          ),
          const SizedBox(height: 10),

          // Kết quả phân tích vật lý thời gian thực
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
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: isSuccess
                      ? BilliardPalette.diamondGold
                      : BilliardPalette.chalkTipRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solved.feedbackMessage,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Chọn thông số Chạm trái & Ép-phê
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
              contact: (_useFreeAimHandle && solved.effectiveContact != null)
                  ? solved.effectiveContact!
                  : (_useFreeAimHandle
                      ? BallContactSpec.full(description: 'Ngắm tự do (A-băng / Không chạm trực tiếp Bi 1)')
                      : _contact),
              effet: _effet,
              strokeType: 'Kéo thanh trượt để chọn lực đánh thực tế',
              speedLevel: _speedLevel,
            ),
            mode: DiagramDisplayMode.interactive,
            onContactChanged: (c) => setState(() {
              _contact = c;
              _useFreeAimHandle = false;
            }),
            onEffetChanged: (e) => setState(() => _effet = e),
            onSpeedLevelChanged: (s) => setState(() => _speedLevel = s),
          ),
          const SizedBox(height: 12),

          // 3. Chọn Chuyên mục & Ghi chú
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
