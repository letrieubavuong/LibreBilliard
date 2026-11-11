import 'package:flutter/material.dart';
import '../../models/billiard_lesson.dart';
import 'base_billiard_diagram.dart';
import 'ball_contact_diagram.dart';
import 'cue_ball_effet_diagram.dart';

/// Thanh tóm tắt nhanh (Compact Strip) tái sử dụng trên các Card danh sách bài học,
/// kết hợp các sơ đồ con ở chế độ [DiagramDisplayMode.thumbnail].
class ShotParametersSummaryBar extends StatelessWidget {
  final ShotParameters params;

  const ShotParametersSummaryBar({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BilliardPalette.cardBorder),
      ),
      child: Row(
        children: [
          BallContactDiagram(
            spec: params.contact,
            mode: DiagramDisplayMode.thumbnail,
          ),
          const SizedBox(width: 8),
          CueBallEffetDiagram(
            spec: params.effet,
            mode: DiagramDisplayMode.thumbnail,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.adjust,
                      size: 13,
                      color: BilliardPalette.diamondGold,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Chạm: ${params.contact.label} (${params.contact.side.title})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 13,
                      color: BilliardPalette.chalkTipRed,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        params.effet.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.speed,
                      size: 13,
                      color: BilliardPalette.cueTrajectory,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${params.strokeType} • Lực ${params.speedLevel}/5',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng chi tiết thông số cú đánh (tái sử dụng trong Màn hình Chi tiết bài học & Phòng Lab thử nghiệm)
class ShotParametersDetailPanel extends StatelessWidget {
  final ShotParameters params;
  final DiagramDisplayMode mode;
  final ValueChanged<BallContactSpec>? onContactChanged;
  final ValueChanged<CueBallEffetSpec>? onEffetChanged;
  final ValueChanged<int>? onSpeedLevelChanged;

  const ShotParametersDetailPanel({
    super.key,
    required this.params,
    this.mode = DiagramDisplayMode.standard,
    this.onContactChanged,
    this.onEffetChanged,
    this.onSpeedLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BallContactDiagram(
                spec: params.contact,
                mode: mode,
                onSpecChanged: onContactChanged,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: CueBallEffetDiagram(
                spec: params.effet,
                mode: mode,
                onSpecChanged: onEffetChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: BilliardPalette.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BilliardPalette.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    size: 18,
                    color: BilliardPalette.cueTrajectory,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KIỂU RA CƠ & ĐỊNH LƯỢNG LỰC',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: BilliardPalette.diamondGold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          params.strokeType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SpeedBar(
                    level: params.speedLevel,
                    actualSpeed: params.effectiveCueSpeed,
                  ),
                ],
              ),
              if (mode == DiagramDisplayMode.interactive &&
                  onSpeedLevelChanged != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Điều chỉnh Lực:',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                    Expanded(
                      child: Slider(
                        value: params.speedLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: 'Lực ${params.speedLevel}/5',
                        onChanged: (v) => onSpeedLevelChanged!(v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final int level; // 1..5
  final double? actualSpeed;

  const _SpeedBar({required this.level, this.actualSpeed});

  @override
  Widget build(BuildContext context) {
    final speedText = actualSpeed != null
        ? '${actualSpeed!.toStringAsFixed(2)} m/s (Lực $level/5)'
        : 'Lực $level/5';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          speedText,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 6),
        ...List.generate(5, (index) {
          final active = index < level;
          return Container(
            width: 7,
            height: 16,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: active
                  ? (index >= 3
                      ? BilliardPalette.objectBallRed
                      : BilliardPalette.diamondGold)
                  : Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ],
    );
  }
}
