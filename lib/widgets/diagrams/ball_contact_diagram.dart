import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import '../../physics/aim_geometry.dart';
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

    // Tính độ lệch tâm b = 2 * R * (1 - f) từ công thức chuẩn AimGeometry:
    // - Khi fraction = 1.0 (tràn mặt / ContactSide.center): b = 0 (góc cắt 0°)
    // - Khi fraction = 0.5 (1/2 trái): b = 1.0 * ballRadius (góc cắt 30°)
    // - Khi fraction -> 0 (mỏng sát mép): b -> 2.0 * ballRadius
    final sign = spec.side == ContactSide.left
        ? -1.0
        : (spec.side == ContactSide.right ? 1.0 : 0.0);
    final impactParam = AimGeometry.impactParameter(
      fraction: spec.fraction,
      ballRadius: ballRadius,
    );
    final horizontalOffset = impactParam * sign;

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
      Path()
        ..addOval(
          Rect.fromCircle(center: objectBallCenter, radius: ballRadius),
        ),
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
    return BallContactSliderControls(
      spec: spec,
      onSpecChanged: onSpecChanged!,
    );
  }
}

/// BỘ ĐIỀU KHIỂN THANH TRƯỢT RỜI RẠC 7 NẤC PHẦN TÁM (1/8 .. 7/8 & TRÀN MẶT 8/8)
/// Quy chuẩn P1 Review Lần 5:
/// - Slider 7 nấc rời rạc k=1..7 (divisions=6), nhãn phần tám kết hợp tên rút gọn.
/// - Nút [-] và [+] dịch chuyển đúng 1/8 nấc, không nhảy bước.
/// - Nhãn lớn "Chạm k/8 • Má trái/phải" kèm góc cắt lí tưởng AimGeometry chuẩn.
/// - Điều khiển Má Trái / Má Phải riêng biệt: Đổi độ dày giữ má, đổi má giữ độ dày.
/// - Nút "Tràn mặt 8/8" riêng: Khi bật/tắt sẽ lưu và khôi phục chính xác độ dày và má trước đó.
/// - Bảo toàn bài học cũ (1/3, 2/3): Hiển thị rõ nhãn "Giá trị gốc", không tự làm tròn khi build.
class BallContactSliderControls extends StatefulWidget {
  final BallContactSpec spec;
  final ValueChanged<BallContactSpec> onSpecChanged;

  const BallContactSliderControls({
    super.key,
    required this.spec,
    required this.onSpecChanged,
  });

  @override
  State<BallContactSliderControls> createState() =>
      _BallContactSliderControlsState();
}

class _BallContactSliderControlsState extends State<BallContactSliderControls> {
  static const Map<int, String> _stepShortLabels = {
    1: '1/8',
    2: '2/8\n(1/4)',
    3: '3/8',
    4: '4/8\n(1/2)',
    5: '5/8',
    6: '6/8\n(3/4)',
    7: '7/8',
  };

  static const Map<int, String> _stepFullLabels = {
    1: '1/8',
    2: '2/8 (1/4)',
    3: '3/8',
    4: '4/8 (1/2)',
    5: '5/8',
    6: '6/8 (3/4)',
    7: '7/8',
  };

  late double _savedNonFullFraction;
  late ContactSide _savedNonCenterSide;

  @override
  void initState() {
    super.initState();
    _savedNonFullFraction =
        widget.spec.fraction < 0.99 ? widget.spec.fraction : 0.75;
    _savedNonCenterSide = widget.spec.side == ContactSide.center
        ? ContactSide.right
        : widget.spec.side;
  }

  @override
  void didUpdateWidget(covariant BallContactSliderControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.fraction < 0.99) {
      _savedNonFullFraction = widget.spec.fraction;
    }
    if (widget.spec.side != ContactSide.center) {
      _savedNonCenterSide = widget.spec.side;
    }
  }

  bool get _isFull =>
      widget.spec.fraction >= 0.99 || widget.spec.side == ContactSide.center;

  int get _currentK {
    if (widget.spec.eighthsStep != null) {
      return widget.spec.eighthsStep!.clamp(1, 7);
    }
    return (widget.spec.fraction * 8.0).round().clamp(1, 7);
  }

  bool get _isLegacyOrContinuous => widget.spec.eighthsStep == null;

  void _onSliderChanged(double value) {
    final k = value.round().clamp(1, 7);
    final newFraction = k / 8.0;
    _savedNonFullFraction = newFraction;
    final targetSide = widget.spec.side == ContactSide.center
        ? _savedNonCenterSide
        : widget.spec.side;

    widget.onSpecChanged(
      BallContactSpec.eighths(k, side: targetSide),
    );
  }

  void _stepDelta(int delta) {
    if (_isFull) {
      if (delta < 0) {
        _onSliderChanged(7.0);
      }
      return;
    }
    final targetK = (_currentK + delta).clamp(1, 7);
    if (targetK != _currentK || _isLegacyOrContinuous) {
      _onSliderChanged(targetK.toDouble());
    }
  }

  void _toggleFull() {
    if (_isFull) {
      final restoreK = (_savedNonFullFraction * 8.0).round().clamp(1, 7);
      widget.onSpecChanged(
        BallContactSpec.eighths(restoreK, side: _savedNonCenterSide),
      );
    } else {
      _savedNonFullFraction = widget.spec.fraction;
      _savedNonCenterSide = widget.spec.side == ContactSide.center
          ? ContactSide.right
          : widget.spec.side;
      widget.onSpecChanged(BallContactSpec.full());
    }
  }

  void _selectSpecialFraction(double frac, String label) {
    final targetSide = widget.spec.side == ContactSide.center
        ? _savedNonCenterSide
        : widget.spec.side;
    _savedNonFullFraction = frac;
    widget.onSpecChanged(
      BallContactSpec(
        label: label,
        fraction: frac,
        side: targetSide,
        description: 'Độ dày chính xác $label theo tài liệu cơ bản',
      ),
    );
  }

  void _onSideChanged(ContactSide newSide) {
    _savedNonCenterSide = newSide;
    if (_isFull) {
      final restoreK = (_savedNonFullFraction * 8.0).round().clamp(1, 7);
      widget.onSpecChanged(
        BallContactSpec.eighths(restoreK, side: newSide),
      );
    } else {
      widget.onSpecChanged(widget.spec.copyWith(side: newSide));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFull = _isFull;
    final currentK = _currentK;
    final angle = widget.spec.cutAngleDegrees.toStringAsFixed(1);

    String mainTitle;
    if (isFull) {
      mainTitle = 'Chạm 8/8 • Tràn mặt (Góc cắt 0.0°)';
    } else if (_isLegacyOrContinuous) {
      final pct = (widget.spec.fraction * 100).toStringAsFixed(1);
      final sideName =
          widget.spec.side == ContactSide.left ? 'Má trái' : 'Má phải';
      mainTitle = '${widget.spec.label} (Gốc $pct%) • $sideName ($angle°)';
    } else {
      final sideName =
          widget.spec.side == ContactSide.left ? 'Má trái' : 'Má phải';
      final fracName = _stepFullLabels[currentK] ?? '$currentK/8';
      mainTitle = 'Chạm $fracName • $sideName ($angle°)';
    }

    final canDecrease = !isFull && currentK > 1 || isFull;
    final canIncrease = !isFull && currentK < 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Nhãn lớn và 2 nút [-] / [+]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFull
                  ? BilliardPalette.diamondGold.withValues(alpha: 0.60)
                  : BilliardPalette.cardBorder,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Giảm 1/8 độ dày',
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                color: canDecrease ? BilliardPalette.diamondGold : Colors.white24,
                onPressed: canDecrease ? () => _stepDelta(-1) : null,
              ),
              Expanded(
                child: Text(
                  mainTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isFull ? BilliardPalette.diamondGold : Colors.white,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tăng 1/8 độ dày',
                icon: const Icon(Icons.add_circle_outline, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                color: canIncrease ? BilliardPalette.diamondGold : Colors.white24,
                onPressed: canIncrease ? () => _stepDelta(1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Slider rời rạc 7 nấc
        Opacity(
          opacity: isFull ? 0.45 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Độ dày chạm trái theo phần tám',
                value: isFull
                    ? 'Tràn mặt 8/8'
                    : (_stepFullLabels[currentK] ?? '$currentK/8'),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.0,
                    activeTrackColor: BilliardPalette.diamondGold,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: BilliardPalette.diamondGold,
                    overlayColor:
                        BilliardPalette.diamondGold.withValues(alpha: 0.2),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    tickMarkShape:
                        const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                    activeTickMarkColor: Colors.black54,
                    inactiveTickMarkColor: Colors.white38,
                  ),
                  child: Slider(
                    min: 1.0,
                    max: 7.0,
                    divisions: 6,
                    value: currentK.toDouble(),
                    onChanged: isFull ? null : _onSliderChanged,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final k = index + 1;
                    final isCurrent = !isFull && k == currentK;
                    return InkWell(
                      onTap: () => _onSliderChanged(k.toDouble()),
                      child: Text(
                        _stepShortLabels[k]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? BilliardPalette.diamondGold
                              : Colors.white54,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Hàng điều khiển Má Trái / Má Phải riêng biệt & Nút Tràn mặt 8/8
        SegmentedButton<ContactSide>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment(
              value: ContactSide.left,
              label: Text('Má Trái', style: TextStyle(fontSize: 10)),
            ),
            ButtonSegment(
              value: ContactSide.right,
              label: Text('Má Phải', style: TextStyle(fontSize: 10)),
            ),
          ],
          selected: {
            isFull ? _savedNonCenterSide : widget.spec.side,
          },
          onSelectionChanged: (selection) {
            _onSideChanged(selection.first);
          },
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: isFull
              ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BilliardPalette.diamondGold,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  icon: const Icon(Icons.center_focus_strong, size: 14),
                  label: const Text(
                    'Tràn mặt 8/8 (Đang chọn)',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _toggleFull,
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  icon: const Icon(Icons.center_focus_weak, size: 14),
                  label: const Text('Tràn mặt 8/8',
                      style: TextStyle(fontSize: 10)),
                  onPressed: _toggleFull,
                ),
        ),
        const SizedBox(height: 6),

        // 4. Các nút chọn nhanh độ dày chính xác (1/3, 1/2, 2/3)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _buildSpecialFractionChip(1.0 / 3.0, '1/3 trái (33%)'),
            _buildSpecialFractionChip(0.50, '1/2 trái (50%)'),
            _buildSpecialFractionChip(2.0 / 3.0, '2/3 trái (67%)'),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialFractionChip(double targetFrac, String chipLabel) {
    final isSelected = !_isFull && (widget.spec.fraction - targetFrac).abs() < 0.015;
    return ChoiceChip(
      label: Text(chipLabel, style: const TextStyle(fontSize: 9.5)),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.zero,
      selectedColor: BilliardPalette.diamondGold.withValues(alpha: 0.35),
      onSelected: (_) => _selectSpecialFraction(targetFrac, chipLabel),
    );
  }
}
