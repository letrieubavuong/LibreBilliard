import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';

/// Bảng màu chuẩn cho tất cả các sơ đồ Billiard Libre
class BilliardPalette {
  static const Color clothDark = Color(0xFF0E4D34);
  static const Color clothLight = Color(0xFF156947);
  static const Color railWood = Color(0xFF3E2415);
  static const Color railCushion = Color(0xFF0A3A27);
  static const Color diamondGold = Color(0xFFE6C15A);
  static const Color cardBackground = Color(0xFF141E19);
  static const Color cardBorder = Color(0xFF263B31);

  static const Color cueBallWhite = Color(0xFFF7F9F8);
  static const Color objectBallYellow = Color(0xFFFFCA28);
  static const Color objectBallRed = Color(0xFFE53935);
  static const Color chalkTipRed = Color(0xFFFF5252);
  static const Color cueTrajectory = Color(0xFF80DEEA);
}

/// LỚP CƠ SỞ (ABSTRACT BASE PAINTER) CHO MỌI SƠ ĐỒ BILLIARD
/// Cung cấp các hàm vẽ dùng chung: vẽ bi 3D đổ bóng, vẽ đường đứt nét, vẽ mũi tên hướng chạy.
abstract class BaseBilliardPainter<T extends BilliardVisualSpec>
    extends CustomPainter {
  final T spec;
  final DiagramDisplayMode mode;

  const BaseBilliardPainter({
    required this.spec,
    this.mode = DiagramDisplayMode.standard,
  });

  /// Vẽ một viên bi có hiệu ứng ánh sáng 3D và đổ bóng xuống mặt vải
  void drawSphereBall(
    Canvas canvas,
    Offset center,
    double radius,
    Color baseColor, {
    bool isGhost = false,
    Color? spotColor,
  }) {
    if (isGhost) {
      final ghostPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.32)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, ghostPaint);

      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, borderPaint);
      return;
    }

    // Đổ bóng dưới mặt bàn
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + Offset(radius * 0.18, radius * 0.22), radius, shadowPaint);

    // Thân bi chuyển sắc 3D
    final gradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.95,
      colors: [
        Color.lerp(baseColor, Colors.white, 0.45)!,
        baseColor,
        Color.lerp(baseColor, Colors.black, 0.35)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final ballPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, ballPaint);

    // Viền mảnh để tách biệt trên nền vải xanh
    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, outlinePaint);

    // Chấm đỏ tâm bi (nếu có)
    if (spotColor != null) {
      canvas.drawCircle(
        center,
        radius * 0.14,
        Paint()..color = spotColor,
      );
    }
  }

  /// Vẽ đường đứt nét (dùng cho đường đi của bi mục tiêu 1 & 2 hoặc tia ngắm)
  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5.0,
    double dashSpace = 4.0,
  }) {
    final totalDistance = (end - start).distance;
    if (totalDistance <= 0.1) return;
    final direction = (end - start) / totalDistance;
    double distance = 0.0;
    while (distance < totalDistance) {
      final segEnd = math.min(distance + dashWidth, totalDistance);
      canvas.drawLine(
        start + direction * distance,
        start + direction * segEnd,
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  /// Vẽ đầu mũi tên chỉ hướng di chuyển của bi
  void drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    double size = 7.0,
  }) {
    final delta = to - from;
    if (delta.distance < 1.0) return;
    final angle = math.atan2(delta.dy, delta.dx);
    final arrowAngle = 0.52; // ~30 độ

    final p1 = Offset(
      to.dx - size * math.cos(angle - arrowAngle),
      to.dy - size * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - size * math.cos(angle + arrowAngle),
      to.dy - size * math.sin(angle + arrowAngle),
    );

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }
}

/// LỚP CƠ SỞ (ABSTRACT BASE WIDGET) CHO CÁC SƠ ĐỒ BILLIARD CÓ THỂ TÁI SỬ DỤNG NHIỀU NƠI
/// Các lớp con ([CaromTableDiagram], [BallContactDiagram], [CueBallEffetDiagram]) kế thừa lớp này
/// để tự động tương thích với 3 chế độ: Thumbnail (nhỏ), Standard (trong bài viết) và Interactive (tương tác).
abstract class BaseBilliardDiagramWidget<T extends BilliardVisualSpec>
    extends StatelessWidget {
  final T spec;
  final DiagramDisplayMode mode;
  final String? titleOverride;
  final VoidCallback? onTap;

  const BaseBilliardDiagramWidget({
    super.key,
    required this.spec,
    this.mode = DiagramDisplayMode.standard,
    this.titleOverride,
    this.onTap,
  });

  /// Nhãn tiêu đề loại sơ đồ (VD: "CHẠM TRÁI", "TÂM BI & ÉP-PHÊ", "SƠ ĐỒ HÌNH BI")
  String get diagramCategoryLabel;

  /// Icon đại diện cho loại sơ đồ
  IconData get diagramIcon;

  /// Lớp con định nghĩa phần vẽ Canvas chính
  Widget buildDiagramCanvas(BuildContext context);

  /// Lớp con có thể cung cấp thêm thanh công cụ điều khiển khi ở chế độ Interactive
  Widget? buildInteractiveControls(BuildContext context) => null;

  @override
  Widget build(BuildContext context) {
    if (mode == DiagramDisplayMode.thumbnail) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: BilliardPalette.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BilliardPalette.cardBorder),
          ),
          padding: const EdgeInsets.all(6),
          child: buildDiagramCanvas(context),
        ),
      );
    }

    final controls =
        mode == DiagramDisplayMode.interactive ? buildInteractiveControls(context) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: BilliardPalette.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BilliardPalette.cardBorder, width: 1.2),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(diagramIcon, size: 15, color: BilliardPalette.diamondGold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titleOverride ?? diagramCategoryLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: BilliardPalette.diamondGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(child: buildDiagramCanvas(context)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                spec.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (spec.description != null && mode != DiagramDisplayMode.thumbnail) ...[
              const SizedBox(height: 3),
              Center(
                child: Text(
                  spec.description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ],
            if (controls != null) ...[
              const SizedBox(height: 10),
              controls,
            ],
          ],
        ),
      ),
    );
  }
}

