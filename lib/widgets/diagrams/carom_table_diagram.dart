import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import '../../models/carom_physics_solver.dart';
import '../../physics/billiard_physics.dart';
import 'base_billiard_diagram.dart';

/// Phần tử có thể kéo thả trực tiếp trên bàn trong chế độ Tự xếp hình bi (Position Builder)
enum DraggableTableElement {
  cueBall,
  objectBall1,
  objectBall2,
  targetZone,
  aimHandle,
}

/// Painter vẽ Bàn Carom DỌC THEO MÀN HÌNH từ kết quả `SimulationResult` của `CaromPhysicsEngine`:
/// - Tuyệt đối KHÔNG chạy bộ giải vật lý hay nắn đường cong Bézier giả trong `paint()`.
/// - Bán kính vẽ bi `ballRadius` được quy đổi trực tiếp từ bán kính vật lý `config.ballRadius` (0.03075 m)
///   theo đúng tỉ lệ khung nhìn `playRect.width / config.widthMeters` (không clamp độc lập theo pixel).
/// - Hướng xoay 3D của 6 chấm đỏ Aramith trên Bi chủ được lấy trực tiếp từ Quaternion `BallState.orientation`
///   tích phân từ vận tốc góc `omega = (wx, wy, wz)`.
/// - Vòng sóng va chạm (Impact Ripple) chỉ xuất hiện tại đúng thời điểm và tọa độ trong `SimulationResult.collisionEvents`.
class CaromTablePainter extends BaseBilliardPainter<TableDiagramSpec> {
  final SimulationResult? simulationResult;
  final double animationProgress; // 0.0 (ban đầu) -> 1.0 (kết thúc)
  final bool hideTrajectories;
  final bool showGuidelineOverlay;
  final bool halfTableCloseup;
  final bool flipLongRail;
  final bool flipShortRail;
  final Offset? aimHandleDiamond;

  const CaromTablePainter({
    required super.spec,
    super.mode,
    this.simulationResult,
    this.animationProgress = 0.0,
    this.hideTrajectories = false,
    this.showGuidelineOverlay = false,
    this.halfTableCloseup = false,
    this.flipLongRail = false,
    this.flipShortRail = false,
    this.aimHandleDiamond,
  });

  static double railThicknessFor(DiagramDisplayMode mode) =>
      mode == DiagramDisplayMode.thumbnail ? 7.0 : 20.0;

  static bool canUseHalfTable(
    TableDiagramSpec s, {
    SimulationResult? sim,
    bool flipLongRail = false,
  }) {
    double mapX(double x) => flipLongRail ? 8.0 - x : x;
    final allX = <double>[
      mapX(s.cueBall.dx),
      mapX(s.objectBall1.dx),
      mapX(s.objectBall2.dx),
      ...s.cueBallPath.map((p) => mapX(p.dx)),
      ...s.objectBall1Path.map((p) => mapX(p.dx)),
      ...s.objectBall2Path.map((p) => mapX(p.dx)),
    ];
    if (sim != null) {
      for (final snap in sim.snapshots) {
        allX.add(mapX(sim.config.metersToDiamond(snap.cueBall.position).x));
        allX.add(mapX(sim.config.metersToDiamond(snap.objectBall1.position).x));
        allX.add(mapX(sim.config.metersToDiamond(snap.objectBall2.position).x));
      }
    }
    final maxX = allX.reduce(math.max);
    return maxX <= 4.45;
  }

  /// Các điểm chấm đỏ 3D trên mặt cầu đơn vị của Bi chủ Aramith Pro-Cup
  static const List<Vec3> _aramithUnitDots = <Vec3>[
    Vec3(1.0, 0.0, 0.0),
    Vec3(-1.0, 0.0, 0.0),
    Vec3(0.0, 1.0, 0.0),
    Vec3(0.0, -1.0, 0.0),
    Vec3(0.0, 0.0, 1.0),
    Vec3(0.0, 0.0, -1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final config = simulationResult?.config ?? TableConfig.standardCarom;
    final railThickness = railThicknessFor(mode);
    final outerRect = Offset.zero & size;
    final maxLongUnits = halfTableCloseup ? 4.5 : 8.0;

    // 1. Vẽ thành băng gỗ ngoài
    final woodPaint = Paint()..color = BilliardPalette.railWood;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(12)),
      woodPaint,
    );

    // 2. Vùng mặt bàn vải xanh bên trong
    final bottomRail = halfTableCloseup ? railThickness * 0.45 : railThickness;
    final playRect = Rect.fromLTRB(
      railThickness,
      railThickness,
      size.width - railThickness,
      size.height - bottomRail,
    );

    const clothGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        BilliardPalette.clothLight,
        BilliardPalette.clothDark,
      ],
    );
    canvas.drawRect(
      playRect,
      Paint()..shader = clothGradient.createShader(playRect),
    );

    // Lưới mờ chia nút băng
    if (spec.showDiamondNumbers && mode != DiagramDisplayMode.thumbnail) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.8;
      for (int j = 1; j < 4; j++) {
        final x = playRect.left + (j / 4.0) * playRect.width;
        canvas.drawLine(
          Offset(x, playRect.top),
          Offset(x, playRect.bottom),
          gridPaint,
        );
      }
      final maxGridY = halfTableCloseup ? 4 : 7;
      for (int i = 1; i <= maxGridY; i++) {
        final y = playRect.top + (i / maxLongUnits) * playRect.height;
        canvas.drawLine(
          Offset(playRect.left, y),
          Offset(playRect.right, y),
          gridPaint,
        );
      }
    }

    // Viền cao su băng
    canvas.drawRect(
      playRect.deflate(1.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawRect(
      playRect,
      Paint()
        ..color = BilliardPalette.railCushion
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Phép chiếu duy nhất từ tọa độ nút băng (dx: 0..8, dy: 0..4) sang Canvas
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

    // 3. Vẽ vạch kẻ Ô CẤM GÓC LIBRE (71cm × 35.5cm = 2.0 × 1.0 nút băng)
    if (spec.showCornerZones) {
      final zonePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;

      const double longRailZone = 2.0; // 71 cm / 35.5 cm = 2.0 nút băng
      const double shortRailZone = 1.0; // 35.5 cm / 35.5 cm = 1.0 nút băng

      canvas.drawLine(
        diamondToCanvas(const Offset(longRailZone, 0)),
        diamondToCanvas(const Offset(0, shortRailZone)),
        zonePaint,
      );
      canvas.drawLine(
        diamondToCanvas(const Offset(longRailZone, 4)),
        diamondToCanvas(const Offset(0, 4 - shortRailZone)),
        zonePaint,
      );

      if (!halfTableCloseup) {
        canvas.drawLine(
          diamondToCanvas(const Offset(8 - longRailZone, 0)),
          diamondToCanvas(const Offset(8, shortRailZone)),
          zonePaint,
        );
        canvas.drawLine(
          diamondToCanvas(const Offset(8 - longRailZone, 4)),
          diamondToCanvas(const Offset(8, 4 - shortRailZone)),
          zonePaint,
        );
      }
    }

    if (halfTableCloseup) {
      final centerLineY = playRect.top + (4.0 / maxLongUnits) * playRect.height;
      drawDashedLine(
        canvas,
        Offset(playRect.left, centerLineY),
        Offset(playRect.right, centerLineY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.0,
        dashWidth: 6,
        dashSpace: 4,
      );
    }

    // 4. Vẽ các nút băng (Diamonds)
    _drawVerticalDiamonds(canvas, playRect, railThickness, maxLongUnits);

    // 5. Bán kính vẽ bi lấy trực tiếp từ bán kính vật lý R = 0.03075 m nhân với tỉ lệ khung nhìn
    final pixelsPerMeter = playRect.width / config.widthMeters;
    final ballRadius = config.ballRadius * pixelsPerMeter;

    canvas.save();
    canvas.clipRect(playRect);

    final effectiveProgress = hideTrajectories ? 0.0 : animationProgress;
    final isSimulating = effectiveProgress > 0.001;

    // 6. Vẽ vùng gom bi & đường dẫn
    if (!hideTrajectories) {
      if (spec.targetZoneCenter != null) {
        final zoneCenter = diamondToCanvas(spec.targetZoneCenter!);
        final zoneRadius = (spec.targetZoneRadius / 4.0) * playRect.width;

        canvas.drawCircle(
          zoneCenter,
          zoneRadius,
          Paint()..color = BilliardPalette.diamondGold.withValues(alpha: 0.15),
        );
        canvas.drawCircle(
          zoneCenter,
          zoneRadius,
          Paint()
            ..color = BilliardPalette.diamondGold.withValues(alpha: 0.62)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }

      // 6a. Nếu bật lớp Sơ đồ hướng dẫn tĩnh (Static Guideline Layer từ sách), vẽ mờ phía dưới
      if (showGuidelineOverlay) {
        final guideCue =
            [spec.cueBall, ...spec.cueBallPath].map(diamondToCanvas).toList();
        final guideObj1 = [spec.objectBall1, ...spec.objectBall1Path]
            .map(diamondToCanvas)
            .toList();
        final guideObj2 = [spec.objectBall2, ...spec.objectBall2Path]
            .map(diamondToCanvas)
            .toList();

        _drawTrackGuide(
          canvas,
          guideObj2,
          Colors.redAccent.withValues(alpha: 0.30),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          guideObj1,
          Colors.amberAccent.withValues(alpha: 0.30),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          guideCue,
          Colors.white.withValues(alpha: 0.32),
          isDashed: true,
        );
      }

      // 6b. Vẽ quỹ đạo vật lý thực tế từ SimulationResult (nếu có)
      if (simulationResult != null && simulationResult!.snapshots.isNotEmpty) {
        final sim = simulationResult!;
        final guideAlpha = isSimulating ? 0.24 : 0.88;
        final physCueTrack = sim.snapshots
            .map((s) => metersToCanvas(s.cueBall.position))
            .toList();
        final physObj1Track = sim.snapshots
            .map((s) => metersToCanvas(s.objectBall1.position))
            .toList();
        final physObj2Track = sim.snapshots
            .map((s) => metersToCanvas(s.objectBall2.position))
            .toList();

        _drawTrackGuide(
          canvas,
          physObj2Track,
          BilliardPalette.objectBallRed.withValues(alpha: guideAlpha),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          physObj1Track,
          BilliardPalette.objectBallYellow.withValues(alpha: guideAlpha),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          physCueTrack,
          BilliardPalette.cueTrajectory
              .withValues(alpha: isSimulating ? 0.28 : 0.94),
          isDashed: false,
        );
      } else if (!showGuidelineOverlay) {
        // Chế độ Thumbnail nhẹ không truyền simulationResult: vẽ đường hướng dẫn tĩnh
        final rawCue =
            [spec.cueBall, ...spec.cueBallPath].map(diamondToCanvas).toList();
        final rawObj1 = [spec.objectBall1, ...spec.objectBall1Path]
            .map(diamondToCanvas)
            .toList();
        final rawObj2 = [spec.objectBall2, ...spec.objectBall2Path]
            .map(diamondToCanvas)
            .toList();
        _drawTrackGuide(
          canvas,
          rawObj2,
          BilliardPalette.objectBallRed.withValues(alpha: 0.75),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          rawObj1,
          BilliardPalette.objectBallYellow.withValues(alpha: 0.75),
          isDashed: true,
        );
        _drawTrackGuide(
          canvas,
          rawCue,
          BilliardPalette.cueTrajectory.withValues(alpha: 0.85),
          isDashed: false,
        );
      }
    }

    // 7. Nếu đang ở chế độ Position Builder có điểm kéo hướng ngắm (aimHandleDiamond)
    if (aimHandleDiamond != null) {
      final cCanvas = diamondToCanvas(spec.cueBall);
      final hCanvas = diamondToCanvas(aimHandleDiamond!);
      drawDashedLine(
        canvas,
        cCanvas,
        hCanvas,
        Paint()
          ..color = BilliardPalette.diamondGold.withValues(alpha: 0.85)
          ..strokeWidth = 1.6,
        dashWidth: 4,
        dashSpace: 3,
      );
      canvas.drawCircle(
        hCanvas,
        ballRadius * 0.75,
        Paint()..color = BilliardPalette.diamondGold.withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        hCanvas,
        ballRadius * 0.42,
        Paint()..color = BilliardPalette.diamondGold,
      );
    }

    // 8. Lấy trạng thái 3 bi tại thời điểm vật lý tương ứng với animationProgress
    const double strikePhaseEnd = 0.10;
    double cueStickStrikeProgress = -1.0;
    double simTime = 0.0;

    final sim = simulationResult;
    final totalDuration = sim?.durationSeconds ?? 0.0;

    if (effectiveProgress <= 0.0001) {
      cueStickStrikeProgress = 0.0;
      simTime = 0.0;
    } else if (effectiveProgress < strikePhaseEnd) {
      cueStickStrikeProgress =
          (effectiveProgress / strikePhaseEnd).clamp(0.0, 1.0);
      simTime = 0.0;
    } else {
      final moveT =
          ((effectiveProgress - strikePhaseEnd) / (1.0 - strikePhaseEnd))
              .clamp(0.0, 1.0);
      simTime = moveT * totalDuration;
      if (moveT < 0.06) {
        cueStickStrikeProgress = 1.0 + (moveT / 0.06) * 0.5;
      }
    }

    Offset currentCuePos;
    Offset currentObj1Pos;
    Offset currentObj2Pos;
    Quat cueOrientation = Quat.identity;
    Quat obj1Orientation = Quat.identity;
    Quat obj2Orientation = Quat.identity;

    if (sim != null && sim.snapshots.isNotEmpty) {
      final snap = sim.sampleAtTime(simTime);
      currentCuePos = metersToCanvas(snap.cueBall.position);
      currentObj1Pos = metersToCanvas(snap.objectBall1.position);
      currentObj2Pos = metersToCanvas(snap.objectBall2.position);
      cueOrientation = snap.cueBall.orientation;
      obj1Orientation = snap.objectBall1.orientation;
      obj2Orientation = snap.objectBall2.orientation;

      // 8a. Vẽ vệt sáng (Glowing Trail) của quỹ đạo thực tế tính tới thời điểm simTime
      if (isSimulating && simTime > 0.0) {
        final pastCue = <Offset>[];
        final pastObj1 = <Offset>[];
        final pastObj2 = <Offset>[];
        for (final s in sim.snapshots) {
          if (s.timestamp > simTime) break;
          pastCue.add(metersToCanvas(s.cueBall.position));
          pastObj1.add(metersToCanvas(s.objectBall1.position));
          pastObj2.add(metersToCanvas(s.objectBall2.position));
        }
        pastCue.add(currentCuePos);
        pastObj1.add(currentObj1Pos);
        pastObj2.add(currentObj2Pos);

        _drawGlowingTrail(canvas, pastObj2, BilliardPalette.objectBallRed);
        _drawGlowingTrail(canvas, pastObj1, BilliardPalette.objectBallYellow);
        _drawGlowingTrail(canvas, pastCue, BilliardPalette.cueTrajectory);
      }

      // 8b. Vẽ vòng sóng xung kích va chạm (Impact Ripple) CHỈ KHI có sự kiện va chạm thật trong collisionEvents
      if (isSimulating) {
        const double rippleDuration = 0.32;
        for (final ev in sim.collisionEvents) {
          if (ev.type != CollisionType.ballBall) continue;
          final dtEvent = simTime - ev.timestamp;
          if (dtEvent >= 0.0 && dtEvent <= rippleDuration) {
            final rippleColor = ev.involvesBall(BallId.object2)
                ? BilliardPalette.objectBallRed
                : BilliardPalette.objectBallYellow;
            _drawImpactRipple(
              canvas,
              metersToCanvas(ev.contactPointMeters),
              ballRadius,
              dtEvent / rippleDuration,
              rippleColor,
            );
          }
        }
      }
    } else {
      currentCuePos = diamondToCanvas(spec.cueBall);
      currentObj1Pos = diamondToCanvas(spec.objectBall1);
      currentObj2Pos = diamondToCanvas(spec.objectBall2);
    }

    // 9. Vẽ 3 viên bi vật rắn với hướng xoay Quaternion 3D thực tế
    _drawRealisticRollingBall(
      canvas,
      center: currentObj2Pos,
      radius: ballRadius,
      baseColor: BilliardPalette.objectBallRed,
      orientation: obj2Orientation,
      isMeaslesCueBall: false,
    );
    _drawRealisticRollingBall(
      canvas,
      center: currentObj1Pos,
      radius: ballRadius,
      baseColor: BilliardPalette.objectBallYellow,
      orientation: obj1Orientation,
      isMeaslesCueBall: false,
    );
    _drawRealisticRollingBall(
      canvas,
      center: currentCuePos,
      radius: ballRadius,
      baseColor: BilliardPalette.cueBallWhite,
      orientation: cueOrientation,
      isMeaslesCueBall: true,
    );

    // 10. Vẽ Cây cơ Bida lúc chuẩn bị đánh và khi ra ngọn cơ
    if (!hideTrajectories &&
        mode != DiagramDisplayMode.thumbnail &&
        cueStickStrikeProgress >= 0.0) {
      Offset initialCueCanvas;
      Offset aimDirCanvas;
      if (sim != null) {
        initialCueCanvas = metersToCanvas(sim.input.cueBallPosition);
        final nextPt = metersToCanvas(
          sim.input.cueBallPosition + sim.input.aimDirection * 0.25,
        );
        final delta = nextPt - initialCueCanvas;
        aimDirCanvas =
            delta.distance > 1e-4 ? delta / delta.distance : const Offset(0, -1);
      } else {
        initialCueCanvas = diamondToCanvas(spec.cueBall);
        final target = spec.cueBallPath.isNotEmpty
            ? diamondToCanvas(spec.cueBallPath.first)
            : diamondToCanvas(spec.objectBall1);
        final delta = target - initialCueCanvas;
        aimDirCanvas =
            delta.distance > 1e-4 ? delta / delta.distance : const Offset(0, -1);
      }

      _drawCueStick(
        canvas,
        cueBallCenter: initialCueCanvas,
        shotDirection: aimDirCanvas,
        ballRadius: ballRadius,
        strikeProgress: cueStickStrikeProgress,
      );
    }

    canvas.restore();
  }

  void _drawTrackGuide(
    Canvas canvas,
    List<Offset> track,
    Color color, {
    required bool isDashed,
  }) {
    if (track.length < 2) return;
    final filtered = <Offset>[track.first];
    for (int i = 1; i < track.length; i++) {
      if ((track[i] - filtered.last).distance >= 2.0) {
        filtered.add(track[i]);
      }
    }
    if (filtered.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = mode == DiagramDisplayMode.thumbnail ? 1.3 : 2.0
      ..style = PaintingStyle.stroke;

    if (!isDashed) {
      final path = Path()..moveTo(filtered.first.dx, filtered.first.dy);
      for (int i = 1; i < filtered.length; i++) {
        path.lineTo(filtered[i].dx, filtered[i].dy);
      }
      canvas.drawPath(path, paint);
    } else {
      for (int i = 0; i < filtered.length - 1; i++) {
        drawDashedLine(
          canvas,
          filtered[i],
          filtered[i + 1],
          paint,
          dashWidth: 5,
          dashSpace: 4,
        );
      }
    }

    if (mode != DiagramDisplayMode.thumbnail && filtered.length >= 3) {
      final midIdx =
          (filtered.length * 0.65).floor().clamp(1, filtered.length - 1);
      drawArrowHead(
        canvas,
        filtered[midIdx - 1],
        filtered[midIdx],
        color,
        size: 6.5,
      );
    }
  }

  /// Vẽ viên bi Carom 3D kèm 6 chấm đỏ Aramith Pro-Cup xoay theo Quaternion 3D `orientation`.
  void _drawRealisticRollingBall(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color baseColor,
    required Quat orientation,
    required bool isMeaslesCueBall,
  }) {
    drawSphereBall(canvas, center, radius, baseColor);

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.94)),
    );

    final flipSignX = flipShortRail ? -1.0 : 1.0;
    final flipSignY = flipLongRail ? -1.0 : 1.0;

    if (isMeaslesCueBall) {
      final dotColor = BilliardPalette.chalkTipRed.withValues(alpha: 0.90);
      final baseDotRadius = (radius * 0.16).clamp(1.0, 2.8);

      for (final unitDot in _aramithUnitDots) {
        final world = orientation.rotate(unitDot);
        // Chỉ vẽ các chấm nằm ở bán cầu hướng lên mắt người nhìn (z >= -0.1)
        if (world.z < -0.10) continue;
        // Hệ tọa độ bàn dọc: trục y vật lý nằm ngang màn hình, trục x vật lý nằm dọc màn hình
        final projX = world.y * flipSignX * radius * 0.72;
        final projY = world.x * flipSignY * radius * 0.72;
        final depthScale = (0.55 + 0.45 * world.z.clamp(0.0, 1.0));
        canvas.drawCircle(
          center + Offset(projX, projY),
          baseDotRadius * depthScale,
          Paint()..color = dotColor,
        );
      }
    } else {
      final spotWorld = orientation.rotate(const Vec3(0.45, 0.35, 0.82));
      if (spotWorld.z > -0.15) {
        final spotOffset = Offset(
          spotWorld.y * flipSignX * radius * 0.65,
          spotWorld.x * flipSignY * radius * 0.65,
        );
        canvas.drawCircle(
          center + spotOffset,
          (radius * 0.14).clamp(0.9, 2.2),
          Paint()..color = Colors.white.withValues(alpha: 0.68),
        );
      }
    }

    canvas.drawCircle(
      center - Offset(radius * 0.32, radius * 0.32),
      radius * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );
    canvas.restore();
  }

  void _drawCueStick(
    Canvas canvas, {
    required Offset cueBallCenter,
    required Offset shotDirection,
    required double ballRadius,
    required double strikeProgress,
  }) {
    double tipGap;
    double opacity = 1.0;

    if (strikeProgress <= 0.001) {
      tipGap = 7.0;
    } else if (strikeProgress <= 0.62) {
      final backT = Curves.easeOut.transform(strikeProgress / 0.62);
      tipGap = 7.0 + backT * 24.0;
    } else if (strikeProgress <= 1.0) {
      final forwardT =
          Curves.easeInExpo.transform((strikeProgress - 0.62) / 0.38);
      tipGap = 31.0 * (1.0 - forwardT);
    } else {
      final followT = (strikeProgress - 1.0).clamp(0.0, 0.5) / 0.5;
      tipGap = -followT * (ballRadius * 0.8);
      opacity = (1.0 - followT).clamp(0.0, 1.0);
    }

    if (opacity <= 0.05) return;

    final tipPos = cueBallCenter - shotDirection * (ballRadius + tipGap);
    final ferruleEnd = tipPos - shotDirection * 6.0;
    final shaftEnd = ferruleEnd - shotDirection * (ballRadius * 5.2);
    final buttEnd = shaftEnd - shotDirection * (ballRadius * 4.5);

    canvas.drawLine(
      tipPos + const Offset(2, 3),
      buttEnd + const Offset(2, 3),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * opacity)
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      shaftEnd,
      buttEnd,
      Paint()
        ..color = const Color(0xFF4E2A14).withValues(alpha: opacity)
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      ferruleEnd,
      shaftEnd,
      Paint()
        ..color = const Color(0xFFF3DFC1).withValues(alpha: opacity)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.butt,
    );

    canvas.drawLine(
      tipPos,
      ferruleEnd,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = 2.8,
    );
    canvas.drawCircle(
      tipPos,
      1.7,
      Paint()..color = BilliardPalette.chalkTipRed.withValues(alpha: opacity),
    );
  }

  void _drawImpactRipple(
    Canvas canvas,
    Offset center,
    double ballRadius,
    double rippleT,
    Color color,
  ) {
    final radius = ballRadius * (0.9 + rippleT * 1.65);
    final alpha = (1.0 - rippleT).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.65 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * alpha,
    );
    canvas.drawCircle(
      center,
      ballRadius * (0.4 + rippleT * 0.6),
      Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
    );
  }

  void _drawGlowingTrail(Canvas canvas, List<Offset> trail, Color color) {
    if (trail.length < 2) return;
    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (int i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx, trail[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawVerticalDiamonds(
    Canvas canvas,
    Rect playRect,
    double railThickness,
    double maxLongUnits,
  ) {
    final diamondPaint = Paint()..color = BilliardPalette.diamondGold;
    final dotRadius = mode == DiagramDisplayMode.thumbnail ? 1.5 : 2.8;
    final maxIndex = halfTableCloseup ? 4 : 8;

    for (int i = 0; i <= maxIndex; i++) {
      final y = playRect.top + (i / maxLongUnits) * playRect.height;
      final leftX = playRect.left - railThickness / 2;
      final rightX = playRect.right + railThickness / 2;

      canvas.drawCircle(Offset(leftX, y), dotRadius, diamondPaint);
      canvas.drawCircle(Offset(rightX, y), dotRadius, diamondPaint);

      if (spec.showDiamondNumbers && mode != DiagramDisplayMode.thumbnail) {
        final labelNum = (flipLongRail ? (8 - i) : i) * 10;
        _drawTinyNumber(canvas, '$labelNum', Offset(leftX, y));
        _drawTinyNumber(canvas, '$labelNum', Offset(rightX, y));
      }
    }

    for (int j = 1; j <= 3; j++) {
      final x = playRect.left + (j / 4.0) * playRect.width;
      final topY = playRect.top - railThickness / 2;
      canvas.drawCircle(Offset(x, topY), dotRadius, diamondPaint);

      if (!halfTableCloseup) {
        final bottomY = playRect.bottom + railThickness / 2;
        canvas.drawCircle(Offset(x, bottomY), dotRadius, diamondPaint);
      }

      if (spec.showDiamondNumbers && mode != DiagramDisplayMode.thumbnail) {
        final labelNum = (flipShortRail ? (4 - j) : j) * 10;
        _drawTinyNumber(canvas, '$labelNum', Offset(x, topY));
      }
    }
  }

  void _drawTinyNumber(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CaromTablePainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.simulationResult != simulationResult ||
        oldDelegate.mode != mode ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.hideTrajectories != hideTrajectories ||
        oldDelegate.showGuidelineOverlay != showGuidelineOverlay ||
        oldDelegate.halfTableCloseup != halfTableCloseup ||
        oldDelegate.flipLongRail != flipLongRail ||
        oldDelegate.flipShortRail != flipShortRail ||
        oldDelegate.aimHandleDiamond != aimHandleDiamond;
  }
}

/// WIDGET SƠ ĐỒ BÀN CAROM DỌC KÈM ENGINE MÔ PHỎNG VẬT LÝ SI (`SimulationResult`)
class CaromTableDiagram extends BaseBilliardDiagramWidget<TableDiagramSpec> {
  final SimulationResult? simulationResult;
  final bool hideTrajectories;
  final bool initialShowGuidelines;
  final Offset? aimHandleDiamond;
  final void Function(DraggableTableElement element, Offset newDiamondCoord)?
      onElementDragged;

  const CaromTableDiagram({
    super.key,
    required super.spec,
    this.simulationResult,
    super.mode = DiagramDisplayMode.standard,
    super.titleOverride,
    super.onTap,
    this.hideTrajectories = false,
    this.initialShowGuidelines = false,
    this.aimHandleDiamond,
    this.onElementDragged,
  });

  @override
  String get diagramCategoryLabel => 'SƠ ĐỒ BÀN CAROM DỌC';

  @override
  IconData get diagramIcon => Icons.crop_portrait;

  @override
  Widget buildDiagramCanvas(BuildContext context) {
    if (mode == DiagramDisplayMode.interactive && onElementDragged == null) {
      return _InteractiveCaromTableBody(
        initialSpec: spec,
        externalSimulationResult: simulationResult,
        hideTrajectories: hideTrajectories,
        initialShowGuidelines: initialShowGuidelines,
      );
    }

    if (onElementDragged != null) {
      return _EditableCaromTableCanvas(
        spec: spec,
        simulationResult: simulationResult,
        aimHandleDiamond: aimHandleDiamond,
        onElementDragged: onElementDragged!,
      );
    }

    final useHalf = CaromTablePainter.canUseHalfTable(
      spec,
      sim: simulationResult,
    );
    return AspectRatio(
      aspectRatio: useHalf ? 0.82 : 0.52,
      child: CustomPaint(
        painter: CaromTablePainter(
          spec: spec,
          simulationResult: simulationResult,
          mode: mode,
          hideTrajectories: hideTrajectories,
          halfTableCloseup: useHalf,
        ),
      ),
    );
  }
}

/// Canvas cho phép người dùng kéo trực tiếp 3 bi, vùng gom & điểm ngắm trên mặt bàn dọc (Position Builder):
/// - Có kiểm tra bán kính hit-test (`maxHitDistance = 0.45` nút băng) để chạm vào vùng vải trống không làm nhảy bi.
/// - Giữ nguyên độ lệch giữa điểm chạm ngón tay và tâm vật thể (`_dragGrabOffset`) suốt quá trình kéo.
/// - Ràng buộc không chồng lấp (`distance >= 2 * R_d`) và không vượt ra ngoài biên bàn `[R_d, 8 - R_d] x [R_d, 4 - R_d]`.
class _EditableCaromTableCanvas extends StatefulWidget {
  final TableDiagramSpec spec;
  final SimulationResult? simulationResult;
  final Offset? aimHandleDiamond;
  final void Function(DraggableTableElement element, Offset newDiamondCoord)
      onElementDragged;

  const _EditableCaromTableCanvas({
    required this.spec,
    this.simulationResult,
    this.aimHandleDiamond,
    required this.onElementDragged,
  });

  @override
  State<_EditableCaromTableCanvas> createState() =>
      _EditableCaromTableCanvasState();
}

class _EditableCaromTableCanvasState extends State<_EditableCaromTableCanvas> {
  DraggableTableElement? _activeElement;
  Offset _dragGrabOffset = Offset.zero;

  static const TableConfig _config = TableConfig.standardCarom;

  Offset _pixelToDiamond(Offset localPos, Size size) {
    final rail =
        CaromTablePainter.railThicknessFor(DiagramDisplayMode.interactive);
    final playW = (size.width - rail * 2).clamp(1.0, double.infinity);
    final playH = (size.height - rail * 2).clamp(1.0, double.infinity);
    final shortRailDy = ((localPos.dx - rail) / playW) * 4.0;
    final longRailDx = ((localPos.dy - rail) / playH) * 8.0;
    return Offset(longRailDx, shortRailDy);
  }

  Offset _positionOfElement(DraggableTableElement element) {
    switch (element) {
      case DraggableTableElement.cueBall:
        return widget.spec.cueBall;
      case DraggableTableElement.objectBall1:
        return widget.spec.objectBall1;
      case DraggableTableElement.objectBall2:
        return widget.spec.objectBall2;
      case DraggableTableElement.targetZone:
        return widget.spec.targetZoneCenter ?? const Offset(1.2, 0.8);
      case DraggableTableElement.aimHandle:
        return widget.aimHandleDiamond ?? widget.spec.objectBall1;
    }
  }

  /// Chỉ chọn phần tử nếu khoảng cách từ điểm chạm tới tâm phần tử <= ngưỡng hit-test (0.48 nút băng).
  DraggableTableElement? _pickElementWithinThreshold(Offset diamondPos) {
    const double ballHitThreshold = 0.48;
    final candidates = <MapEntry<DraggableTableElement, double>>[
      MapEntry(
        DraggableTableElement.cueBall,
        (diamondPos - widget.spec.cueBall).distance,
      ),
      MapEntry(
        DraggableTableElement.objectBall1,
        (diamondPos - widget.spec.objectBall1).distance,
      ),
      MapEntry(
        DraggableTableElement.objectBall2,
        (diamondPos - widget.spec.objectBall2).distance,
      ),
      if (widget.aimHandleDiamond != null)
        MapEntry(
          DraggableTableElement.aimHandle,
          (diamondPos - widget.aimHandleDiamond!).distance,
        ),
    ];

    candidates.sort((a, b) => a.value.compareTo(b.value));
    if (candidates.isNotEmpty && candidates.first.value <= ballHitThreshold) {
      return candidates.first.key;
    }

    if (widget.spec.targetZoneCenter != null) {
      final zoneDist = (diamondPos - widget.spec.targetZoneCenter!).distance;
      if (zoneDist <= math.max(0.48, widget.spec.targetZoneRadius)) {
        return DraggableTableElement.targetZone;
      }
    }

    return null;
  }

  /// Ràng buộc tọa độ kéo thả: nằm trong lòng bàn [R_d, 8 - R_d] x [R_d, 4 - R_d]
  /// và không chồng lấp lên 2 viên bi còn lại (`distance >= 2 * R_d`).
  Offset _constrainDraggedPosition(
    DraggableTableElement element,
    Offset rawTarget,
  ) {
    final rD = _config.ballRadiusInDiamonds;
    if (element == DraggableTableElement.targetZone) {
      return Offset(
        rawTarget.dx.clamp(0.20, 7.80),
        rawTarget.dy.clamp(0.20, 3.80),
      );
    }
    if (element == DraggableTableElement.aimHandle) {
      return Offset(
        rawTarget.dx.clamp(0.0, 8.0),
        rawTarget.dy.clamp(0.0, 4.0),
      );
    }

    Offset pos = Offset(
      rawTarget.dx.clamp(rD, 8.0 - rD),
      rawTarget.dy.clamp(rD, 4.0 - rD),
    );

    final others = <Offset>[
      if (element != DraggableTableElement.cueBall) widget.spec.cueBall,
      if (element != DraggableTableElement.objectBall1) widget.spec.objectBall1,
      if (element != DraggableTableElement.objectBall2) widget.spec.objectBall2,
    ];

    final minSep = 2.0 * rD + 0.004;
    for (int iter = 0; iter < 3; iter++) {
      for (final other in others) {
        final delta = pos - other;
        final dist = delta.distance;
        if (dist < minSep) {
          final normal =
              dist > 1e-5 ? delta / dist : const Offset(0.7071, -0.7071);
          pos = Offset(
            (other.dx + normal.dx * minSep).clamp(rD, 8.0 - rD),
            (other.dy + normal.dy * minSep).clamp(rD, 4.0 - rD),
          );
        }
      }
    }
    return pos;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(160.0, 340.0);
        final height = width / 0.52;
        final size = Size(width, height);

        return GestureDetector(
          onPanStart: (details) {
            final touchDiamond = _pixelToDiamond(details.localPosition, size);
            final picked = _pickElementWithinThreshold(touchDiamond);
            if (picked == null) {
              _activeElement = null;
              return;
            }
            _activeElement = picked;
            _dragGrabOffset = _positionOfElement(picked) - touchDiamond;
          },
          onPanUpdate: (details) {
            if (_activeElement == null) return;
            final touchDiamond = _pixelToDiamond(details.localPosition, size);
            final constrained = _constrainDraggedPosition(
              _activeElement!,
              touchDiamond + _dragGrabOffset,
            );
            widget.onElementDragged(_activeElement!, constrained);
          },
          onPanEnd: (_) => _activeElement = null,
          onPanCancel: () => _activeElement = null,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: CaromTablePainter(
                spec: widget.spec,
                simulationResult: widget.simulationResult,
                aimHandleDiamond: widget.aimHandleDiamond,
                mode: DiagramDisplayMode.interactive,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveCaromTableBody extends StatefulWidget {
  final TableDiagramSpec initialSpec;
  final SimulationResult? externalSimulationResult;
  final bool hideTrajectories;
  final bool initialShowGuidelines;

  const _InteractiveCaromTableBody({
    required this.initialSpec,
    this.externalSimulationResult,
    this.hideTrajectories = false,
    this.initialShowGuidelines = false,
  });

  @override
  State<_InteractiveCaromTableBody> createState() =>
      _InteractiveCaromTableBodyState();
}

class _InteractiveCaromTableBodyState extends State<_InteractiveCaromTableBody>
     with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  SimulationResult? _cachedFallbackSimulation;
  bool _flipLongRail = false;
  bool _flipShortRail = false;
  bool _slowMotion = false;
  late bool _showNumbers;
  late bool _halfTableCloseup;
  late bool _showGuidelines;

  bool get _hasGuidelinePaths =>
      widget.initialSpec.cueBallPath.isNotEmpty ||
      widget.initialSpec.objectBall1Path.isNotEmpty ||
      widget.initialSpec.objectBall2Path.isNotEmpty;

  SimulationResult _resolveSimulation() {
    if (widget.externalSimulationResult != null) {
      return widget.externalSimulationResult!;
    }
    if (_cachedFallbackSimulation != null) {
      return _cachedFallbackSimulation!;
    }
    // Nếu CaromTableDiagram được gọi độc lập (VD: từ Máy tính Bộ số),
    // tạo ShotInput từ điểm ngắm đầu tiên trong cueBallPath hoặc objectBall1 và cache lại.
    final s = widget.initialSpec;
    final aimTarget =
        s.cueBallPath.isNotEmpty ? s.cueBallPath.first : s.objectBall1;
    final input = CaromPhysicsSolver.buildShotInput(
      diagram: s,
      contact: BallContactSpec.half(),
      effet: CueBallEffetSpec.fromTips(horizontalTips: 2.0, verticalTips: 1.0),
      speedLevel: 3,
      aimTargetDiamond: aimTarget,
    );
    _cachedFallbackSimulation = CaromPhysicsSolver.runCachedSimulation(input);
    return _cachedFallbackSimulation!;
  }

  @override
  void initState() {
    super.initState();
    _showNumbers = widget.initialSpec.showDiamondNumbers;
    _showGuidelines = widget.initialShowGuidelines;
    final sim = _resolveSimulation();
    _halfTableCloseup = CaromTablePainter.canUseHalfTable(
      widget.initialSpec,
      sim: sim,
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant _InteractiveCaromTableBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSpec != widget.initialSpec ||
        oldWidget.externalSimulationResult != widget.externalSimulationResult) {
      _controller.reset();
      _cachedFallbackSimulation = null;
      _showNumbers = widget.initialSpec.showDiamondNumbers;
      final sim = _resolveSimulation();
      _halfTableCloseup = CaromTablePainter.canUseHalfTable(
        widget.initialSpec,
        sim: sim,
        flipLongRail: _flipLongRail,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSpeed(bool slow) {
    setState(() {
      _slowMotion = slow;
      _controller.duration = Duration(milliseconds: _slowMotion ? 5200 : 2600);
    });
    if (_controller.isAnimating) {
      _controller.forward(from: _controller.value);
    }
  }

  void _togglePlay() {
    if (_controller.isAnimating) {
      _controller.stop();
    } else {
      if (_controller.value >= 0.99 || _controller.value <= 0.01) {
        _controller.forward(from: 0.002);
      } else {
        _controller.forward();
      }
    }
  }

  void _resetSimulation() {
    _controller.stop();
    _controller.value = 0.0;
  }

  void _openZoomableModal(
    TableDiagramSpec activeSpec,
    SimulationResult sim,
    bool useHalf,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0A110E),
        child: Scaffold(
          backgroundColor: const Color(0xFF0A110E),
          appBar: AppBar(
            title: Text(activeSpec.label, style: const TextStyle(fontSize: 15)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: useHalf ? 0.85 : 0.52,
                  child: CustomPaint(
                    painter: CaromTablePainter(
                      spec: activeSpec,
                      simulationResult: sim,
                      mode: DiagramDisplayMode.interactive,
                      showGuidelineOverlay: _showGuidelines,
                      halfTableCloseup: useHalf,
                      flipLongRail: _flipLongRail,
                      flipShortRail: _flipShortRail,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lưu ý: Lật bàn (_flipLongRail / _flipShortRail), bật tắt số nút băng, cận cảnh 1/2 bàn
    // hay kéo thanh thời gian chỉ thay đổi góc nhìn Painter, TUYỆT ĐỐI KHÔNG chạy lại bộ giải vật lý!
    final sim = _resolveSimulation();
    final activeSpec =
        widget.initialSpec.copyWithFlags(showDiamondNumbers: _showNumbers);

    final canHalf = CaromTablePainter.canUseHalfTable(
      activeSpec,
      sim: sim,
      flipLongRail: _flipLongRail,
    );
    final effectiveHalf = _halfTableCloseup && canHalf;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 340,
            maxHeight: effectiveHalf ? 410 : 580,
          ),
          child: AspectRatio(
            aspectRatio: effectiveHalf ? 0.85 : 0.52,
            child: CustomPaint(
              painter: CaromTablePainter(
                spec: activeSpec,
                simulationResult: sim,
                mode: DiagramDisplayMode.interactive,
                hideTrajectories: widget.hideTrajectories,
                showGuidelineOverlay: _showGuidelines,
                halfTableCloseup: effectiveHalf,
                flipLongRail: _flipLongRail,
                flipShortRail: _flipShortRail,
                animationProgress: _controller.value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!widget.hideTrajectories)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      _controller.isAnimating ? 'Tạm dừng' : 'Chạy mô phỏng',
                  onPressed: _togglePlay,
                  icon: Icon(
                    _controller.isAnimating
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: BilliardPalette.diamondGold,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6.5,
                      ),
                    ),
                    child: Slider(
                      value: _controller.value,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        _controller.stop();
                        _controller.value = v;
                      },
                    ),
                  ),
                ),
                ChoiceChip(
                  label: Text(
                    _slowMotion ? '0.5× Chậm' : '1.0× Chuẩn',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _slowMotion,
                  visualDensity: VisualDensity.compact,
                  onSelected: _updateSpeed,
                ),
                if (_controller.value > 0.0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Đặt lại vị trí bi ban đầu',
                    onPressed: _resetSimulation,
                    icon: const Icon(Icons.replay, size: 18),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            const _LegendDot(
              color: BilliardPalette.cueTrajectory,
              label: 'Bi chủ (Trắng)',
            ),
            const _LegendDot(
              color: BilliardPalette.objectBallYellow,
              label: 'Bi đích 1 (Vàng)',
            ),
            const _LegendDot(
              color: BilliardPalette.objectBallRed,
              label: 'Bi đích 2 (Đỏ)',
            ),
            const _LegendDot(
              color: BilliardPalette.diamondGold,
              label: 'Vùng gom bi',
            ),
            if (_showGuidelines)
              _LegendDot(
                color: Colors.white.withValues(alpha: 0.45),
                label: 'Sơ đồ hướng dẫn (Sách)',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (canHalf)
              FilterChip(
                avatar: const Icon(Icons.zoom_in, size: 16),
                label: Text(
                  effectiveHalf ? 'Cận cảnh 1/2 bàn' : 'Xem cả bàn dọc',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: effectiveHalf,
                onSelected: (v) => setState(() => _halfTableCloseup = v),
              ),
            if (_hasGuidelinePaths)
              FilterChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 15),
                label: const Text(
                  'Sơ đồ hướng dẫn',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _showGuidelines,
                onSelected: (v) => setState(() => _showGuidelines = v),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _flipShortRail = !_flipShortRail),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label:
                  const Text('Lật Trái/Phải', style: TextStyle(fontSize: 12)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _flipLongRail = !_flipLongRail;
                  if (_flipLongRail) _halfTableCloseup = false;
                });
              },
              icon: const Icon(Icons.swap_vert, size: 16),
              label:
                  const Text('Lật Trên/Dưới', style: TextStyle(fontSize: 12)),
            ),
            FilterChip(
              label: const Text('Số nút băng', style: TextStyle(fontSize: 12)),
              selected: _showNumbers,
              onSelected: (v) => setState(() => _showNumbers = v),
            ),
            IconButton.outlined(
              tooltip: 'Phóng to toàn màn hình (Zoom 4x)',
              onPressed: () =>
                  _openZoomableModal(activeSpec, sim, effectiveHalf),
              icon: const Icon(Icons.zoom_out_map, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

extension TableDiagramSpecCopyExt on TableDiagramSpec {
  TableDiagramSpec copyWithFlags({
    bool? showDiamondNumbers,
    Offset? cueBall,
    Offset? objectBall1,
    Offset? objectBall2,
    Offset? targetZoneCenter,
    List<Offset>? cueBallPath,
    List<Offset>? objectBall1Path,
    List<Offset>? objectBall2Path,
  }) {
    return TableDiagramSpec(
      label: label,
      description: description,
      cueBall: cueBall ?? this.cueBall,
      objectBall1: objectBall1 ?? this.objectBall1,
      objectBall2: objectBall2 ?? this.objectBall2,
      cueBallPath: cueBallPath ?? this.cueBallPath,
      objectBall1Path: objectBall1Path ?? this.objectBall1Path,
      objectBall2Path: objectBall2Path ?? this.objectBall2Path,
      targetZoneCenter: targetZoneCenter ?? this.targetZoneCenter,
      targetZoneRadius: targetZoneRadius,
      showDiamondNumbers: showDiamondNumbers ?? this.showDiamondNumbers,
      showCornerZones: showCornerZones,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}
