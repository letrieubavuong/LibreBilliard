import 'package:flutter/material.dart';
import '../models/billiard_specs.dart';
import 'diagrams/base_billiard_diagram.dart';
import 'diagrams/carom_table_diagram.dart';
import 'diagrams/cue_ball_effet_diagram.dart';
import 'diagrams/ball_contact_diagram.dart';

enum CaromSystemType {
  system50('Bộ 50 (3 Băng)'),
  plusTwo('Cộng 2 (Ngắn-Dài)'),
  oneCushion('Tia 1 Băng');

  final String label;
  const CaromSystemType(this.label);
}

/// Máy tính Bộ số Đa năng (Bộ 50, Bộ Cộng 2, Tia 1 Băng + Ép-phê)
/// Tái sử dụng [CaromTableDiagram] từ kiến trúc kế thừa để vẽ đường tia theo thời gian thực.
class DiamondSystemCalculatorCard extends StatefulWidget {
  const DiamondSystemCalculatorCard({super.key});

  @override
  State<DiamondSystemCalculatorCard> createState() =>
      _DiamondSystemCalculatorCardState();
}

class _DiamondSystemCalculatorCardState
    extends State<DiamondSystemCalculatorCard> {
  CaromSystemType _systemType = CaromSystemType.system50;
  bool _expanded = true;

  // Tham số cho Bộ 50
  double _cuePosition50 = 50; // 30..70
  double _targetThirdRail50 = 30; // 10..50

  // Tham số cho Bộ Cộng 2 (Ngắn - Dài - Dài)
  double _shortRailStart = 10; // 5..25 (nút băng ngắn)
  double _effetTipsPlus2 = 2.5; // 1..4 mũi

  // Tham số cho Tia 1 Băng (Bricole)
  double _oneRailCueX = 20; // 10..70
  double _oneRailTargetX = 60; // 10..70
  double _oneRailEffet = 2.0; // -3..+3 mũi

  TableDiagramSpec _buildDiagramForActiveSystem() {
    switch (_systemType) {
      case CaromSystemType.system50:
        final firstRailAim =
            (_cuePosition50 - _targetThirdRail50).clamp(5.0, 50.0);
        return TableDiagramSpec(
          label:
              'Bộ 50: Đứng ${_cuePosition50.round()} − Trúng ${_targetThirdRail50.round()} ⇒ Ngắm Băng 1 tại ${firstRailAim.round()}',
          description: 'Chuẩn 3 mũi ép-phê thuận • Ra cơ xuyên suốt',
          cueBall: Offset((_cuePosition50 / 10.0).clamp(1.0, 7.5), 3.65),
          objectBall1:
              Offset((_targetThirdRail50 / 10.0).clamp(0.8, 7.2), 3.45),
          objectBall2:
              Offset((_targetThirdRail50 / 10.0 + 0.35).clamp(1.0, 7.5), 3.3),
          cueBallPath: [
            Offset((firstRailAim / 10.0).clamp(0.5, 6.5), 0.0),
            const Offset(0.0, 1.85),
            Offset((_targetThirdRail50 / 10.0).clamp(0.5, 7.5), 4.0),
            Offset((_targetThirdRail50 / 10.0 + 0.2).clamp(0.8, 7.5), 3.4),
          ],
          objectBall1Path: const [],
          objectBall2Path: const [],
          showDiamondNumbers: true,
          showCornerZones: false,
        );

      case CaromSystemType.plusTwo:
        final aimLongRail =
            (_shortRailStart + 20.0 + (_effetTipsPlus2 - 2.5) * 3.0)
                .clamp(15.0, 65.0);
        final landingCornerX =
            (7.5 - (_shortRailStart - 10) * 0.08).clamp(5.2, 7.7);
        return TableDiagramSpec(
          label:
              'Cộng 2: Xuất phát ${_shortRailStart.round()} + 20 ⇒ Ngắm nút ${aimLongRail.round()} băng dài',
          description:
              'Áp dụng khi bi chủ đứng gần băng ngắn đánh sang góc bên kia bàn',
          cueBall: Offset(0.45, (_shortRailStart / 10.0).clamp(0.4, 3.2)),
          objectBall1: Offset(1.3, (_shortRailStart / 10.0 * 0.7).clamp(0.4, 2.8)),
          objectBall2: Offset(landingCornerX - 0.5, 0.65),
          cueBallPath: [
            Offset((aimLongRail / 10.0).clamp(1.0, 7.0), 0.0),
            Offset(landingCornerX, 4.0),
            Offset(landingCornerX - 0.5, 0.65),
          ],
          objectBall1Path: const [],
          objectBall2Path: const [],
          showDiamondNumbers: true,
          showCornerZones: true,
        );

      case CaromSystemType.oneCushion:
        final midPoint = (_oneRailCueX + _oneRailTargetX) / 2.0;
        // Mỗi mũi ép-phê thuận làm mở góc ~0.5 nút (5 đơn vị) nên cần lùi điểm ngắm về phía bi chủ
        final compensatedAim = (midPoint - _oneRailEffet * 5.0).clamp(5.0, 75.0);
        return TableDiagramSpec(
          label:
              'Tia 1 Băng: Trung điểm ${midPoint.round()} − (${_oneRailEffet.toStringAsFixed(1)} ép-phê × 5) ⇒ Ngắm nút ${compensatedAim.round()}',
          description:
              'Mỗi 1 mũi ép-phê dịch chuyển điểm rơi khoảng 0.5 nút băng (5 đơn vị)',
          cueBall: Offset((_oneRailCueX / 10.0).clamp(0.5, 7.5), 3.35),
          objectBall1: Offset((_oneRailTargetX / 10.0).clamp(0.5, 7.5), 3.15),
          objectBall2:
              Offset((_oneRailTargetX / 10.0 + 0.35).clamp(0.7, 7.7), 2.95),
          cueBallPath: [
            Offset((compensatedAim / 10.0).clamp(0.4, 7.6), 0.0),
            Offset((_oneRailTargetX / 10.0).clamp(0.5, 7.5), 3.15),
            Offset((_oneRailTargetX / 10.0 + 0.35).clamp(0.7, 7.7), 2.95),
          ],
          objectBall1Path: const [],
          objectBall2Path: const [],
          showDiamondNumbers: true,
          showCornerZones: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamicSpec = _buildDiagramForActiveSystem();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17261F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BilliardPalette.diamondGold.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: BilliardPalette.diamondGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MÁY TÍNH BỘ SỐ TƯƠNG TÁC (3 HỆ THỐNG)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: BilliardPalette.diamondGold,
                        ),
                      ),
                      Text(
                        dynamicSpec.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: BilliardPalette.diamondGold,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<CaromSystemType>(
                segments: CaromSystemType.values
                    .map(
                      (t) => ButtonSegment(
                        value: t,
                        label: Text(
                          t.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
                selected: {_systemType},
                onSelectionChanged: (s) =>
                    setState(() => _systemType = s.first),
              ),
            ),
            const SizedBox(height: 10),
            ..._buildSlidersForActiveSystem(),
            const SizedBox(height: 6),
            // Tái sử dụng CaromTableDiagram từ hệ thống kế thừa
            CaromTableDiagram(
              spec: dynamicSpec,
              mode: DiagramDisplayMode.interactive,
              titleOverride: 'SƠ ĐỒ TIA BỘ SỐ TRÊN BÀN (CÓ THỂ CHẠY MÔ PHỎNG)',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSlidersForActiveSystem() {
    switch (_systemType) {
      case CaromSystemType.system50:
        return [
          _SliderRow(
            label: 'Điểm Đứng (Cơ):',
            value: _cuePosition50,
            min: 30,
            max: 70,
            divisions: 8,
            displayValue: '${_cuePosition50.round()}',
            onChanged: (v) => setState(() => _cuePosition50 = v),
          ),
          _SliderRow(
            label: 'Điểm Trúng (B3):',
            value: _targetThirdRail50,
            min: 10,
            max: 50,
            divisions: 8,
            displayValue: '${_targetThirdRail50.round()}',
            onChanged: (v) => setState(() => _targetThirdRail50 = v),
          ),
        ];

      case CaromSystemType.plusTwo:
        return [
          _SliderRow(
            label: 'Nút Băng ngắn:',
            value: _shortRailStart,
            min: 5,
            max: 25,
            divisions: 4,
            displayValue: '${_shortRailStart.round()}',
            onChanged: (v) => setState(() => _shortRailStart = v),
          ),
          _SliderRow(
            label: 'Số mũi Ép-phê:',
            value: _effetTipsPlus2,
            min: 1.0,
            max: 4.0,
            divisions: 6,
            displayValue: '${_effetTipsPlus2.toStringAsFixed(1)} mũi',
            onChanged: (v) => setState(() => _effetTipsPlus2 = v),
          ),
        ];

      case CaromSystemType.oneCushion:
        return [
          _SliderRow(
            label: 'Vị trí Bi chủ:',
            value: _oneRailCueX,
            min: 10,
            max: 45,
            divisions: 7,
            displayValue: '${_oneRailCueX.round()}',
            onChanged: (v) => setState(() => _oneRailCueX = v),
          ),
          _SliderRow(
            label: 'Vị trí Bi đích:',
            value: _oneRailTargetX,
            min: 35,
            max: 75,
            divisions: 8,
            displayValue: '${_oneRailTargetX.round()}',
            onChanged: (v) => setState(() => _oneRailTargetX = v),
          ),
          _SliderRow(
            label: 'Ép-phê hiệu chỉnh:',
            value: _oneRailEffet,
            min: -2.0,
            max: 3.0,
            divisions: 10,
            displayValue: '${_oneRailEffet.toStringAsFixed(1)} mũi',
            onChanged: (v) => setState(() => _oneRailEffet = v),
          ),
        ];
    }
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Phòng Lab Thử nghiệm Chạm trái & Ép-phê (Đặt trong tab Sổ tay để người tập tự tra cứu/mô phỏng)
class ShotSandboxCard extends StatefulWidget {
  const ShotSandboxCard({super.key});

  @override
  State<ShotSandboxCard> createState() => _ShotSandboxCardState();
}

class _ShotSandboxCardState extends State<ShotSandboxCard> {
  BallContactSpec _contact = BallContactSpec.half();
  CueBallEffetSpec _effet =
      CueBallEffetSpec.fromTips(horizontalTips: 1.5, verticalTips: -2.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BilliardPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BilliardPalette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 18, color: BilliardPalette.diamondGold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BÀN THỬ NGHIỆM CHẠM TRÁI & ÉP-PHÊ (TƯƠNG TÁC)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BilliardPalette.diamondGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chạm hoặc kéo trực tiếp lên mặt bi chủ / chọn độ dày để luyện cảm giác ngắm tại bàn:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BallContactDiagram(
                  spec: _contact,
                  mode: DiagramDisplayMode.interactive,
                  onSpecChanged: (v) => setState(() => _contact = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CueBallEffetDiagram(
                  spec: _effet,
                  mode: DiagramDisplayMode.interactive,
                  onSpecChanged: (v) => setState(() => _effet = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
