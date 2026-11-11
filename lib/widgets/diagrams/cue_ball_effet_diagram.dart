import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import 'base_billiard_diagram.dart';

/// Painter vẽ mặt đồng hồ Bi chủ & Điểm chạm Đầu cơ (Ép-phê / Cao thấp)
/// Kế thừa từ [BaseBilliardPainter<CueBallEffetSpec>] để đồng bộ phong cách vẽ 3D.
class CueBallEffetPainter extends BaseBilliardPainter<CueBallEffetSpec> {
  const CueBallEffetPainter({
    required super.spec,
    super.mode,
  });

  /// Công thức bán kính bi duy nhất trên Canvas, dùng chung cho cả hàm vẽ và xử lý cảm ứng chạm/kéo.
  static double ballPixelRadiusFor(Size size) =>
      (size.shortestSide * 0.42).clamp(16.0, 48.0);

  /// Bán kính miền hợp lệ tối đa của đầu cơ trên Canvas (`0.80 * R`).
  static double maxTipPixelRadiusFor(Size size) =>
      ballPixelRadiusFor(size) * CueBallEffetSpec.maxPhysicalRadiusRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = ballPixelRadiusFor(size);
    final maxTipRadius = maxTipPixelRadiusFor(size);

    // 1. Vẽ thân bi chủ 3D
    drawSphereBall(
      canvas,
      center,
      radius,
      BilliardPalette.cueBallWhite,
    );

    // 2. Vẽ các vòng chia mức ép-phê (2 mũi và biên tối đa 4 mũi = 0.80R) và trục chữ thập
    final ringPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxTipRadius * 0.5, ringPaint);
    canvas.drawCircle(center, maxTipRadius, ringPaint);

    // Trục ngang (Ép-phê Trái - Phải) & Trục dọc (12h Cu-lê - 6h Trô)
    canvas.drawLine(
      Offset(center.dx - radius * 0.85, center.dy),
      Offset(center.dx + radius * 0.85, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.85),
      Offset(center.dx, center.dy + radius * 0.85),
      ringPaint,
    );

    // 3. Vẽ nhãn 12h / 6h / T / P nếu không phải chế độ Thumbnail
    if (mode != DiagramDisplayMode.thumbnail) {
      _drawClockLabel(canvas, '12h', Offset(center.dx, center.dy - radius - 8));
      _drawClockLabel(canvas, '6h', Offset(center.dx, center.dy + radius + 8));
      _drawClockLabel(canvas, 'T', Offset(center.dx - radius - 9, center.dy));
      _drawClockLabel(canvas, 'P', Offset(center.dx + radius + 9, center.dy));
    }

    // 4. Vẽ điểm đầu cơ chạm bi chủ (Chấm lơ đỏ + vòng sáng)
    // normalizedTipOffset đã nằm trong đĩa tròn đơn vị <= 1.0 ngay từ model CueBallEffetSpec
    final normalized = spec.normalizedTipOffset;
    final tipPoint = Offset(
      center.dx + normalized.dx * maxTipRadius,
      center.dy + normalized.dy * maxTipRadius,
    );

    // Đường nối từ tâm ra điểm chạm để dễ nhìn độ lệch
    canvas.drawLine(
      center,
      tipPoint,
      Paint()
        ..color = BilliardPalette.chalkTipRed.withValues(alpha: 0.55)
        ..strokeWidth = 1.5,
    );

    final tipRadius = (radius * 0.19).clamp(3.5, 8.5);
    canvas.drawCircle(
      tipPoint,
      tipRadius + 2.5,
      Paint()..color = BilliardPalette.chalkTipRed.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      tipPoint,
      tipRadius,
      Paint()..color = BilliardPalette.chalkTipRed,
    );
    canvas.drawCircle(
      tipPoint,
      tipRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawClockLabel(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CueBallEffetPainter oldDelegate) {
    return oldDelegate.spec.horizontalEffet != spec.horizontalEffet ||
        oldDelegate.spec.verticalHeight != spec.verticalHeight ||
        oldDelegate.mode != mode;
  }
}

/// WIDGET SƠ ĐỒ TÂM BI & ÉP-PHÊ KẾ THỪA TỪ [BaseBilliardDiagramWidget]
/// Hỗ trợ tái sử dụng ở cả 3 chế độ: Thumbnail, Standard và Interactive (chạm/kéo chọn mũi cơ).
class CueBallEffetDiagram extends BaseBilliardDiagramWidget<CueBallEffetSpec> {
  final ValueChanged<CueBallEffetSpec>? onSpecChanged;

  const CueBallEffetDiagram({
    super.key,
    required super.spec,
    super.mode = DiagramDisplayMode.standard,
    super.titleOverride,
    super.onTap,
    this.onSpecChanged,
  });

  @override
  String get diagramCategoryLabel => 'TÂM BI & ÉP-PHÊ';

  @override
  IconData get diagramIcon => Icons.gps_fixed;

  void _handleLocalTouch(Offset localPosition, Size canvasSize) {
    if (onSpecChanged == null) return;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final maxTipRadius = CueBallEffetPainter.maxTipPixelRadiusFor(canvasSize);
    if (maxTipRadius <= 0) return;

    final rawDx = (localPosition.dx - center.dx) / maxTipRadius;
    final rawDy = (localPosition.dy - center.dy) / maxTipRadius;

    // Quy đổi sang số mũi cơ và làm tròn bước 0.25 mũi, sau đó CueBallEffetSpec.fromTips
    // sẽ chiếu (project) chính xác về đĩa tròn hợp lệ sqrt(h^2 + v^2) <= 4.0.
    final rawHTips = (rawDx * CueBallEffetSpec.maxTips * 4).round() / 4.0;
    final rawVTips = (-rawDy * CueBallEffetSpec.maxTips * 4).round() / 4.0;

    onSpecChanged!(
      CueBallEffetSpec.fromTips(
        horizontalTips: rawHTips,
        verticalTips: rawVTips,
        description: spec.description,
      ),
    );
  }

  @override
  Widget buildDiagramCanvas(BuildContext context) {
    final dimension = mode == DiagramDisplayMode.thumbnail ? 48.0 : 96.0;
    final canvasSize = Size.square(dimension);

    Widget painterBox = SizedBox(
      width: dimension,
      height: dimension,
      child: CustomPaint(
        painter: CueBallEffetPainter(spec: spec, mode: mode),
      ),
    );

    if (mode == DiagramDisplayMode.interactive && onSpecChanged != null) {
      painterBox = GestureDetector(
        onPanDown: (d) => _handleLocalTouch(d.localPosition, canvasSize),
        onPanUpdate: (d) => _handleLocalTouch(d.localPosition, canvasSize),
        child: painterBox,
      );
    }

    return painterBox;
  }

  @override
  Widget? buildInteractiveControls(BuildContext context) {
    if (onSpecChanged == null) return null;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        ActionChip(
          label: const Text('Tâm bi', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSpecChanged!(
            CueBallEffetSpec.fromTips(horizontalTips: 0, verticalTips: 0),
          ),
        ),
        ActionChip(
          label: const Text('12h + 2 Phải', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSpecChanged!(
            CueBallEffetSpec.fromTips(horizontalTips: 2, verticalTips: 2.5),
          ),
        ),
        ActionChip(
          label: const Text('6h Trô + 2 Trái', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSpecChanged!(
            CueBallEffetSpec.fromTips(horizontalTips: -2, verticalTips: -2.5),
          ),
        ),
      ],
    );
  }
}
