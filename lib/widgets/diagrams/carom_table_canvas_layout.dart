import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../physics/billiard_physics.dart';

/// Phần tử có thể kéo thả trực tiếp trên bàn trong chế độ Tự xếp hình bi (Position Builder)
enum DraggableTableElement {
  cueBall,
  objectBall1,
  objectBall2,
  targetZone,
  aimHandle,
}

/// Bố cục tỉ lệ khung nhìn đồng nhất (Uniform Scaling Layout) cho bàn Carom DỌC THEO MÀN HÌNH:
/// - Hệ tọa độ nút băng: Dọc bàn `x in [0, maxLongUnits]`, Ngang bàn `y in [0, 4]`.
/// - Hệ SI mét: Dọc bàn `X_m in [0, lengthMeters]`, Ngang bàn `Y_m in [0, widthMeters]`.
/// - Dùng duy nhất một `pixelsPerMeter` cho cả chiều ngang và chiều dọc để quả bóng tròn hoàn hảo,
///   khoảng cách tiếp xúc giữa hai quả bóng chạm nhau ($2R$) là tuyệt đối tiếp xúc ở mọi góc ($0^\circ, 45^\circ, 90^\circ$).
class CaromTableCanvasLayout {
  final Size canvasSize;
  final Rect outerRect;
  final Rect playRect;
  final double railThickness;
  final double maxLongUnits;
  final double pixelsPerMeter;
  final TableConfig config;
  final bool flipLongRail;
  final bool flipShortRail;
  final bool halfTableCloseup;

  CaromTableCanvasLayout({
    required this.canvasSize,
    required this.railThickness,
    required this.maxLongUnits,
    required this.config,
    this.flipLongRail = false,
    this.flipShortRail = false,
    this.halfTableCloseup = false,
  })  : outerRect = Offset.zero & canvasSize,
        pixelsPerMeter = _computePixelsPerMeter(
          canvasSize,
          railThickness,
          maxLongUnits,
          config,
          halfTableCloseup,
        ),
        playRect = _computeCenteredPlayRect(
          canvasSize,
          railThickness,
          maxLongUnits,
          config,
          halfTableCloseup,
          _computePixelsPerMeter(
            canvasSize,
            railThickness,
            maxLongUnits,
            config,
            halfTableCloseup,
          ),
        );

  static double _computePixelsPerMeter(
    Size size,
    double rail,
    double maxLongUnits,
    TableConfig config,
    bool half,
  ) {
    final bottomRail = half ? rail * 0.45 : rail;
    final availW = math.max(10.0, size.width - rail * 2);
    final availH = math.max(10.0, size.height - rail - bottomRail);

    final visWidthM = config.widthMeters; // chiều ngang màn hình = chiều rộng bàn (1.42 m)
    final visLengthM = config.lengthMeters * (maxLongUnits / 8.0); // chiều dọc màn hình

    final scaleX = availW / visWidthM;
    final scaleY = availH / visLengthM;
    return math.min(scaleX, scaleY);
  }

  static Rect _computeCenteredPlayRect(
    Size size,
    double rail,
    double maxLongUnits,
    TableConfig config,
    bool half,
    double ppm,
  ) {
    final visWidthM = config.widthMeters;
    final visLengthM = config.lengthMeters * (maxLongUnits / 8.0);

    final playW = visWidthM * ppm;
    final playH = visLengthM * ppm;

    final bottomRail = half ? rail * 0.45 : rail;
    final availW = size.width - rail * 2;
    final availH = size.height - rail - bottomRail;

    final left = rail + (availW - playW) / 2.0;
    final top = rail + (availH - playH) / 2.0;

    return Rect.fromLTWH(left, top, playW, playH);
  }

  Offset diamondToCanvas(Offset rawDiamond) {
    final dx = flipLongRail ? 8.0 - rawDiamond.dx : rawDiamond.dx;
    final dy = flipShortRail ? 4.0 - rawDiamond.dy : rawDiamond.dy;
    return Offset(
      playRect.left + (dy / 4.0) * playRect.width,
      playRect.top + (dx / maxLongUnits) * playRect.height,
    );
  }

  Offset metersToCanvas(Vec2 metersPos) {
    final d = config.metersToDiamond(metersPos);
    return diamondToCanvas(Offset(d.x, d.y));
  }

  Offset canvasToDiamond(Offset canvasPos) {
    final normY = ((canvasPos.dx - playRect.left) / playRect.width).clamp(0.0, 1.0);
    final normX = ((canvasPos.dy - playRect.top) / playRect.height).clamp(0.0, 1.0);

    double dy = normY * 4.0;
    double dx = normX * maxLongUnits;

    if (flipShortRail) dy = 4.0 - dy;
    if (flipLongRail) dx = 8.0 - dx;

    return Offset(dx, dy);
  }

  Vec2 canvasToMeters(Offset canvasPos) {
    final d = canvasToDiamond(canvasPos);
    return config.diamondToMeters(Vec2(d.dx, d.dy));
  }
}
