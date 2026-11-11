import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import 'base_billiard_diagram.dart';

/// Painter vẽ mặt đồng hồ Bi chủ (2R = 61.5mm) & Điểm chạm Đầu cơ (11.5–12.0mm, Thang 4 mức)
/// Kế thừa từ [BaseBilliardPainter<CueBallEffetSpec>] để đồng bộ phong cách vẽ 3D.
///
/// Quy chuẩn P2 Review Lần 5:
/// - Thể hiện 4 vòng định vị đồng tâm cho 4 mức/tầng (0.125R = 3.84mm mỗi mức, Mức 4 = 0.50R = 15.38mm).
/// - Vòng biên an toàn tham khảo: 0.50R = 15.375 mm (Dr. Dave Cue Tip Limit).
/// - Mốc tham khảo Natural Roll tại z = +0.40R = +12.30 mm trong mô hình cơ ngang lí tưởng.
/// - Vòng tròn đầu cơ tỉ lệ thực 11.5–12.0 mm (mặc định 12.0 mm) đóng vai trò hình tham chiếu kích thước.
/// - Chấm đỏ nhỏ là điểm tiếp xúc thực tế trên mặt cầu để phân biệt rạch ròi tâm đầu cơ và điểm tiếp xúc.
class CueBallEffetPainter extends BaseBilliardPainter<CueBallEffetSpec> {
  const CueBallEffetPainter({
    required super.spec,
    super.mode,
  });

  /// Công thức bán kính bi duy nhất trên Canvas:
  static double ballPixelRadiusFor(Size size) =>
      (size.shortestSide * 0.42).clamp(16.0, 48.0);

  /// Bán kính miền tham khảo an toàn tránh tạch cơ (0.50 * R).
  static double referenceSafetyPixelRadiusFor(Size size) =>
      ballPixelRadiusFor(size) * CueBallEffetSpec.referenceMaxRatio;

  /// Bán kính miền hợp lệ tối đa mở rộng (0.80 * R).
  static double extendedMaxPixelRadiusFor(Size size) =>
      ballPixelRadiusFor(size) * CueBallEffetSpec.maxPhysicalRadiusRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ballRadius = ballPixelRadiusFor(size);

    // 1. Vẽ thân bi chủ 3D (Đường kính 61.5mm)
    drawSphereBall(
      canvas,
      center,
      ballRadius,
      BilliardPalette.cueBallWhite,
    );

    // 2. Vẽ 4 vòng định vị đồng tâm mờ ứng với 4 mức quy ước:
    // Mức 1: 0.125R (3.84mm)
    // Mức 2: 0.250R (7.69mm)
    // Mức 3: 0.375R (11.53mm)
    // Mức 4: 0.500R (15.38mm) - Biên an toàn tham khảo
    final tierPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int t = 1; t <= 3; t++) {
      canvas.drawCircle(center, ballRadius * (t * 0.125), tierPaint);
    }

    // Vòng biên tham khảo an toàn 0.50R (Mức 4) nét nổi bật nhẹ
    final safetyRingPaint = Paint()
      ..color = BilliardPalette.diamondGold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, ballRadius * CueBallEffetSpec.referenceMaxRatio, safetyRingPaint);

    // Nếu điểm chạm hiện tại vượt ra ngoài miền tham khảo (> 0.50R - Chế độ nghiên cứu/legacy),
    // vẽ thêm vòng giới hạn cực đại 0.80R nét đứt
    if (spec.isOutsideReferenceSafetyZone) {
      final extPaint = Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, ballRadius * CueBallEffetSpec.extendedMaxRatio, extPaint);
    }

    // 3. Vẽ mốc tham khảo Natural Roll tại z = +0.40R = +12.30mm (mô hình cơ ngang lí tưởng)
    final rollY = center.dy - ballRadius * CueBallEffetSpec.naturalRollZRatio;
    // Bán độ rộng của vạch ngang tại z = 0.4R: x_max = sqrt(1 - 0.4^2) * R ≈ 0.9165 R
    final rollHalfWidth = ballRadius * math.sqrt(math.max(0.0, 1.0 - 0.40 * 0.40));
    final rollPaint = Paint()
      ..color = BilliardPalette.cueTrajectory.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    drawDashedLine(
      canvas,
      Offset(center.dx - rollHalfWidth * 0.85, rollY),
      Offset(center.dx + rollHalfWidth * 0.85, rollY),
      rollPaint,
      dashWidth: 3,
      dashSpace: 2,
    );

    // Trục ngang (Ép-phê Trái - Phải) & Trục dọc (12h Cu-lê - 6h Trô)
    canvas.drawLine(
      Offset(center.dx - ballRadius * 0.85, center.dy),
      Offset(center.dx + ballRadius * 0.85, center.dy),
      tierPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - ballRadius * 0.85),
      Offset(center.dx, center.dy + ballRadius * 0.85),
      tierPaint,
    );

    // 4. Nhãn định vị 12h / 6h / T / P và mốc Natural roll
    if (mode != DiagramDisplayMode.thumbnail) {
      _drawClockLabel(canvas, '12h', Offset(center.dx, center.dy - ballRadius - 8));
      _drawClockLabel(canvas, '6h', Offset(center.dx, center.dy + ballRadius + 8));
      _drawClockLabel(canvas, 'T', Offset(center.dx - ballRadius - 9, center.dy));
      _drawClockLabel(canvas, 'P', Offset(center.dx + ballRadius + 9, center.dy));
    }

    // 5. Tọa độ điểm chạm thực tế trên Canvas
    final physRatio = spec.physicalTipOffsetRatio;
    final contactPoint = Offset(
      center.dx + physRatio.dx * ballRadius,
      center.dy - physRatio.dy * ballRadius,
    );

    // Đường nối từ tâm bi ra điểm tiếp xúc
    canvas.drawLine(
      center,
      contactPoint,
      Paint()
        ..color = BilliardPalette.chalkTipRed.withValues(alpha: 0.50)
        ..strokeWidth = 1.2,
    );

    // 6. Vẽ vòng tròn đầu cơ đúng tỉ lệ (11.5–12.0 mm trên bi 61.5 mm, chiếm ~19.5% đường kính bi)
    // Làm hình tham chiếu kích thước, KHÔNG đồng nhất tâm vòng tròn là điểm tiếp xúc
    final tipPixelRadius = ballRadius * (spec.tipDiameterMm / CueBallEffetSpec.ballDiameterMm);
    final tipRefPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(contactPoint, tipPixelRadius, tipRefPaint);

    final tipBorderPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(contactPoint, tipPixelRadius, tipBorderPaint);

    // 7. Vẽ chấm đỏ điểm tiếp xúc thực tế trên mặt cầu (lơ đỏ rõ nét)
    canvas.drawCircle(
      contactPoint,
      3.2,
      Paint()..color = BilliardPalette.chalkTipRed,
    );
    canvas.drawCircle(
      contactPoint,
      3.2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
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
        oldDelegate.spec.tipDiameterMm != spec.tipDiameterMm ||
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
  String get diagramCategoryLabel => 'TÂM BI & ÉP-PHÊ (MM / 4 MỨC)';

  @override
  IconData get diagramIcon => Icons.gps_fixed;

  void _handleLocalTouch(Offset localPosition, Size canvasSize) {
    if (onSpecChanged == null) return;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final ballRadius = CueBallEffetPainter.ballPixelRadiusFor(canvasSize);
    if (ballRadius <= 0) return;

    final pixelDx = localPosition.dx - center.dx;
    final pixelDy = localPosition.dy - center.dy;

    // Quy đổi từ pixel sang tọa độ mm thực trên mặt cầu bi 61.5mm
    final xMm = (pixelDx / ballRadius) * CueBallEffetSpec.ballRadiusMm;
    final zMm = (-pixelDy / ballRadius) * CueBallEffetSpec.ballRadiusMm;

    final allowExt = spec.isOutsideReferenceSafetyZone;
    onSpecChanged!(
      CueBallEffetSpec.fromMm(
        xMm: xMm,
        zMm: zMm,
        tipDiameterMm: spec.tipDiameterMm,
        allowExtendedRange: allowExt,
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
    return CueBallEffetInteractiveControls(
      spec: spec,
      onSpecChanged: onSpecChanged!,
    );
  }
}

/// BẢNG ĐIỀU KHIỂN TƯƠNG TÁC ĐIỂM MŨI CƠ (MM & 4 MỨC QUY ƯỚC)
class CueBallEffetInteractiveControls extends StatelessWidget {
  final CueBallEffetSpec spec;
  final ValueChanged<CueBallEffetSpec> onSpecChanged;

  const CueBallEffetInteractiveControls({
    super.key,
    required this.spec,
    required this.onSpecChanged,
  });

  @override
  Widget build(BuildContext context) {
    final xMm = spec.contactOffsetXMm;
    final zMm = spec.contactOffsetZMm;
    final rMm = spec.contactRadiusMm;
    final isOutside = spec.isOutsideReferenceSafetyZone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Thẻ hiển thị số đo vật lý thực tế theo mm
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOutside ? Colors.orangeAccent.withValues(alpha: 0.6) : BilliardPalette.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Text(
                'X: ${xMm >= 0 ? '+' : ''}${xMm.toStringAsFixed(1)} mm  •  Z: ${zMm >= 0 ? '+' : ''}${zMm.toStringAsFixed(1)} mm',
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bán kính r = ${rMm.toStringAsFixed(1)} mm / 15.4 mm (0.5R) • Đầu cơ ${spec.tipDiameterMm.toStringAsFixed(1)} mm',
                style: TextStyle(
                  fontSize: 10.0,
                  color: isOutside ? Colors.orangeAccent : BilliardPalette.diamondGold,
                ),
              ),
              if (isOutside)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '⚠️ Ngoài vùng tham khảo an toàn (> 15.4mm) — Nguy cơ tạch cơ',
                    style: TextStyle(fontSize: 9.5, color: Colors.orangeAccent),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. Tùy chọn đường kính đầu cơ (11.5, 11.75, 12.0 mm)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Đầu cơ:',
                style: TextStyle(fontSize: 10.0, color: Colors.white70)),
            for (final d in CueBallEffetSpec.supportedTipDiametersMm)
              ChoiceChip(
                label: Text(
                  d == 12.0
                      ? '12mm'
                      : (d == 11.5 ? '11.5mm' : '11.75mm'),
                  style: const TextStyle(fontSize: 9.5),
                ),
                selected: (spec.tipDiameterMm - d).abs() < 1e-4,
                visualDensity: VisualDensity.compact,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                padding: EdgeInsets.zero,
                onSelected: (_) {
                  // Đổi tipDiameter không tự đổi spin khi contactOffset thực giữ nguyên (Quy chuẩn IV.7)
                  onSpecChanged(spec.copyWith(tipDiameterMm: d));
                },
              ),
          ],
        ),
        const SizedBox(height: 6),

        // 3. Các nút preset nhanh (Tâm, Natural roll, Cu-lê, Trô, Ép-phê 4 mức)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            ActionChip(
              label: const Text('Tâm bi (0,0)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromTiers(
                  horizontalTier: 0,
                  verticalTier: 0,
                  tipDiameterMm: spec.tipDiameterMm,
                ),
              ),
            ),
            ActionChip(
              label: const Text('Roll (+12.3mm)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromMm(
                  xMm: 0.0,
                  zMm: CueBallEffetSpec.naturalRollZMm,
                  tipDiameterMm: spec.tipDiameterMm,
                  customLabel: 'Roll (+12.3mm)',
                ),
              ),
            ),
            ActionChip(
              label: const Text('Cu-lê (+7.7mm)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromTiers(
                  horizontalTier: 0,
                  verticalTier: 2,
                  tipDiameterMm: spec.tipDiameterMm,
                ),
              ),
            ),
            ActionChip(
              label: const Text('Trô (-7.7mm)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromTiers(
                  horizontalTier: 0,
                  verticalTier: -2,
                  tipDiameterMm: spec.tipDiameterMm,
                ),
              ),
            ),
            ActionChip(
              label: const Text('2 Phải (+7.7mm)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromTiers(
                  horizontalTier: 2,
                  verticalTier: 0,
                  tipDiameterMm: spec.tipDiameterMm,
                ),
              ),
            ),
            ActionChip(
              label: const Text('2 Trái (-7.7mm)', style: TextStyle(fontSize: 9.5)),
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              onPressed: () => onSpecChanged(
                CueBallEffetSpec.fromTiers(
                  horizontalTier: -2,
                  verticalTier: 0,
                  tipDiameterMm: spec.tipDiameterMm,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
