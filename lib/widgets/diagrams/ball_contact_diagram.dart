import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import 'base_billiard_diagram.dart';

/// Painter vẽ sơ đồ CHẠM TRÁI (Độ dày chạm bi mục tiêu 1)
/// Kế thừa từ [BaseBilliardPainter<BallContactSpec>] để dùng chung hàm vẽ bi 3D và tia ngắm.
class BallContactPainter extends BaseBilliardPainter<BallContactSpec> {
  const BallContactPainter({
    required super.spec,
    super.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ballRadius = (size.shortestSide * 0.30).clamp(12.0, 38.0);

    // Vẽ đường ngắm ngang chuẩn qua tâm bi mục tiêu
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(8, center.dy),
      Offset(size.width - 8, center.dy),
      guidePaint,
    );

    // Tính độ lệch tâm giữa Bi chủ (Ghost) và Bi mục tiêu (Vàng) dựa trên fraction (0..1)
    // Khi fraction = 1.0 (tràn mặt): độ lệch ngang = 0
    // Khi fraction = 0.5 (1/2 trái): tâm bi chủ trùng mép bi mục tiêu -> lệch = 1 * ballRadius
    // Khi fraction -> 0 (mỏng sát mép): lệch tiến sát 2 * ballRadius
    final sign = spec.side == ContactSide.left
        ? -1.0
        : (spec.side == ContactSide.right ? 1.0 : 0.0);
    final horizontalOffset = (1.0 - spec.fraction) * 2.0 * ballRadius * sign;

    final objectBallCenter = Offset(
      center.dx - horizontalOffset * 0.35,
      center.dy - ballRadius * 0.08,
    );
    final cueBallCenter = Offset(
      objectBallCenter.dx + horizontalOffset,
      center.dy + ballRadius * 0.14,
    );

    // 1. Vẽ Bi mục tiêu 1 (Vàng) ở phía sau
    drawSphereBall(
      canvas,
      objectBallCenter,
      ballRadius,
      BilliardPalette.objectBallYellow,
    );

    // 2. Vẽ vùng giao nhau (phần diện tích chạm trái)
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: objectBallCenter, radius: ballRadius)),
    );
    canvas.drawCircle(
      cueBallCenter,
      ballRadius,
      Paint()..color = BilliardPalette.diamondGold.withValues(alpha: 0.40),
    );
    canvas.restore();

    // 3. Vẽ Bi chủ (Trắng trong suốt - Ghost Ball) đè lên trước để thấy rõ tỉ lệ che phủ
    drawSphereBall(
      canvas,
      cueBallCenter,
      ballRadius,
      BilliardPalette.cueBallWhite,
      isGhost: true,
    );

    // 4. Vẽ tâm ngắm của Bi chủ (chấm + đường gióng lên bi mục tiêu)
    final aimPaint = Paint()
      ..color = BilliardPalette.cueTrajectory
      ..strokeWidth = 1.4;
    drawDashedLine(
      canvas,
      Offset(cueBallCenter.dx, size.height - 4),
      Offset(cueBallCenter.dx, objectBallCenter.dy - ballRadius),
      aimPaint,
      dashWidth: 3,
      dashSpace: 3,
    );
    canvas.drawCircle(
      cueBallCenter,
      3.0,
      Paint()..color = BilliardPalette.cueTrajectory,
    );
  }

  @override
  bool shouldRepaint(covariant BallContactPainter oldDelegate) {
    return oldDelegate.spec.fraction != spec.fraction ||
        oldDelegate.spec.side != spec.side ||
        oldDelegate.mode != mode;
  }
}

/// WIDGET SƠ ĐỒ CHẠM TRÁI (ĐỘ DÀY) KẾ THỪA TỪ [BaseBilliardDiagramWidget]
/// Có thể đặt ở bất kỳ đâu: Danh sách bài học (Thumbnail), Chi tiết bài học (Standard), hoặc Bộ công cụ (Interactive).
class BallContactDiagram extends BaseBilliardDiagramWidget<BallContactSpec> {
  final ValueChanged<BallContactSpec>? onSpecChanged;

  const BallContactDiagram({
    super.key,
    required super.spec,
    super.mode = DiagramDisplayMode.standard,
    super.titleOverride,
    super.onTap,
    this.onSpecChanged,
  });

  @override
  String get diagramCategoryLabel => 'ĐỘ DÀY CHẠM TRÁI';

  @override
  IconData get diagramIcon => Icons.adjust;

  @override
  Widget buildDiagramCanvas(BuildContext context) {
    final height = mode == DiagramDisplayMode.thumbnail ? 48.0 : 88.0;
    final width = mode == DiagramDisplayMode.thumbnail ? 74.0 : 140.0;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: BallContactPainter(spec: spec, mode: mode),
      ),
    );
  }

  @override
  Widget? buildInteractiveControls(BuildContext context) {
    if (onSpecChanged == null) return null;
    final presets = <BallContactSpec>[
      BallContactSpec.oneEighth(side: spec.side),
      BallContactSpec.oneQuarter(side: spec.side),
      BallContactSpec.oneThird(side: spec.side),
      BallContactSpec.half(side: spec.side),
      BallContactSpec.twoThirds(side: spec.side),
      BallContactSpec.threeQuarters(side: spec.side),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: presets.map((preset) {
            final selected = (preset.fraction - spec.fraction).abs() < 0.04;
            final shortLabel = preset.label.replaceAll(' trái', '');
            return ChoiceChip(
              label: Text(shortLabel, style: const TextStyle(fontSize: 10.5)),
              selected: selected,
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (_) => onSpecChanged!(preset),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        SegmentedButton<ContactSide>(
          segments: const [
            ButtonSegment(
              value: ContactSide.left,
              label: Text('Má Trái', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: ContactSide.right,
              label: Text('Má Phải', style: TextStyle(fontSize: 11)),
            ),
          ],
          selected: {
            spec.side == ContactSide.center ? ContactSide.right : spec.side
          },
          onSelectionChanged: (selection) {
            onSpecChanged!(spec.copyWith(side: selection.first));
          },
        ),
      ],
    );
  }
}

