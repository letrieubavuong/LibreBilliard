import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/billiard_specs.dart';
import 'base_billiard_diagram.dart';

/// Loại bi đang được kéo trong chế độ Tự xếp hình bi (Editor Mode)
enum DraggableTableElement {
  cueBall,
  objectBall1,
  objectBall2,
  targetZone,
}

/// Một khung hình trong chuỗi 120 bước thời gian vật lý đã được khử hoàn toàn va chạm chồng lấp (PBD Non-Penetration)
class _PhysicsStepState {
  final Offset cuePos;
  final Offset obj1Pos;
  final Offset obj2Pos;
  final double cueSpin;
  final double obj1Spin;
  final double obj2Spin;

  const _PhysicsStepState({
    required this.cuePos,
    required this.obj1Pos,
    required this.obj2Pos,
    required this.cueSpin,
    required this.obj1Spin,
    required this.obj2Spin,
  });
}

/// Toàn bộ chuỗi thời gian (Timeline) của một cú đánh sau khi giải vật lý vật rắn 2D
class _SolvedTimeline {
  final List<_PhysicsStepState> frames; // 121 frames (0..120)
  final int hit1FrameIndex;
  final Offset hit1ContactPoint;
  final int hit2FrameIndex;
  final Offset hit2ContactPoint;
  final Offset initialAimDirection;

  const _SolvedTimeline({
    required this.frames,
    required this.hit1FrameIndex,
    required this.hit1ContactPoint,
    required this.hit2FrameIndex,
    required this.hit2ContactPoint,
    required this.initialAimDirection,
  });
}

/// Painter vẽ Bàn Carom DỌC THEO MÀN HÌNH kèm Engine Vật Rắn Không Chồng Lấp (PBD Rigid-Body Solver):
/// - Đảm bảo tuyệt đối tại MỌI thời điểm (ban đầu, lúc va chạm, đang lăn và khi dừng lại):
///   khoảng cách tâm giữa bất kỳ 2 viên bi nào luôn >= 2.04 * ballRadius (KHÔNG BAO GIỜ chồng lên nhau).
/// - Khi Bi chủ chạm vào Bi Đỏ (kể cả khi bài học không khai báo đường đi của Bi Đỏ),
///   Bi Đỏ tự động nhận xung lực va chạm thực tế và lăn nhẹ ra theo hướng va chạm.
class CaromTablePainter extends BaseBilliardPainter<TableDiagramSpec> {
  final double animationProgress; // 0.0 (ban đầu) -> 1.0 (kết thúc)
  final bool hideTrajectories;
  final bool halfTableCloseup;

  const CaromTablePainter({
    required super.spec,
    super.mode,
    this.animationProgress = 0.0,
    this.hideTrajectories = false,
    this.halfTableCloseup = false,
  });

  static double railThicknessFor(DiagramDisplayMode mode) =>
      mode == DiagramDisplayMode.thumbnail ? 7.0 : 20.0;

  static bool canUseHalfTable(TableDiagramSpec s) {
    final allX = <double>[
      s.cueBall.dx,
      s.objectBall1.dx,
      s.objectBall2.dx,
      ...s.cueBallPath.map((p) => p.dx),
      ...s.objectBall1Path.map((p) => p.dx),
      ...s.objectBall2Path.map((p) => p.dx),
    ];
    final maxX = allX.reduce(math.max);
    return maxX <= 4.45;
  }

  @override
  void paint(Canvas canvas, Size size) {
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
            Offset(x, playRect.top), Offset(x, playRect.bottom), gridPaint);
      }
      final maxGridY = halfTableCloseup ? 4 : 7;
      for (int i = 1; i <= maxGridY; i++) {
        final y = playRect.top + (i / maxLongUnits) * playRect.height;
        canvas.drawLine(
            Offset(playRect.left, y), Offset(playRect.right, y), gridPaint);
      }
    }

    // Viền cao su băng có bóng đổ tạo chiều sâu 3D
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

    Offset toCanvas(Offset diamondCoord) {
      return Offset(
        playRect.left + (diamondCoord.dy / 4.0) * playRect.width,
        playRect.top + (diamondCoord.dx / maxLongUnits) * playRect.height,
      );
    }

    // 3. Vẽ vạch kẻ Ô CẤM GÓC LIBRE (71cm × 35.5cm)
    if (spec.showCornerZones) {
      final zonePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;

      const double longRailZone = 1.92;
      const double shortRailZone = 0.96;

      canvas.drawLine(
        toCanvas(const Offset(longRailZone, 0)),
        toCanvas(const Offset(0, shortRailZone)),
        zonePaint,
      );
      canvas.drawLine(
        toCanvas(const Offset(longRailZone, 4)),
        toCanvas(const Offset(0, 4 - shortRailZone)),
        zonePaint,
      );

      if (!halfTableCloseup) {
        canvas.drawLine(
          toCanvas(const Offset(8 - longRailZone, 0)),
          toCanvas(const Offset(8, shortRailZone)),
          zonePaint,
        );
        canvas.drawLine(
          toCanvas(const Offset(8 - longRailZone, 4)),
          toCanvas(const Offset(8, 4 - shortRailZone)),
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

    final ballRadius = (playRect.width * 0.038).clamp(4.2, 13.5);

    // 5. Giải toàn bộ chuỗi thời gian 120 bước với ràng buộc vật rắn KHÔNG CHỒNG LẤP (distance >= 2.05 * R)
    final cueRaw = [spec.cueBall, ...spec.cueBallPath].map(toCanvas).toList();
    final obj1Raw =
        [spec.objectBall1, ...spec.objectBall1Path].map(toCanvas).toList();
    final obj2Raw =
        [spec.objectBall2, ...spec.objectBall2Path].map(toCanvas).toList();

    final timeline = _solveCollisionFreeTimeline(
      cueRaw: cueRaw,
      obj1Raw: obj1Raw,
      obj2Raw: obj2Raw,
      playRect: playRect,
      ballRadius: ballRadius,
    );

    canvas.save();
    canvas.clipRect(playRect);

    final effectiveProgress = hideTrajectories ? 0.0 : animationProgress;
    final isSimulating = effectiveProgress > 0.001;

    // 6. Vẽ vùng gom bi & đường hướng dẫn (lấy trực tiếp từ quỹ đạo đã khử chồng lấp của timeline)
    if (!hideTrajectories) {
      if (spec.targetZoneCenter != null) {
        final zoneCenter = toCanvas(spec.targetZoneCenter!);
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

      final guideAlpha = isSimulating ? 0.22 : 0.88;
      final solvedCueTrack = timeline.frames.map((f) => f.cuePos).toList();
      final solvedObj1Track = timeline.frames.map((f) => f.obj1Pos).toList();
      final solvedObj2Track = timeline.frames.map((f) => f.obj2Pos).toList();

      _drawTrackGuide(
        canvas,
        solvedObj2Track,
        BilliardPalette.objectBallRed.withValues(alpha: guideAlpha),
        isDashed: true,
      );
      _drawTrackGuide(
        canvas,
        solvedObj1Track,
        BilliardPalette.objectBallYellow.withValues(alpha: guideAlpha),
        isDashed: true,
      );
      _drawTrackGuide(
        canvas,
        solvedCueTrack,
        BilliardPalette.cueTrajectory.withValues(alpha: isSimulating ? 0.26 : 0.94),
        isDashed: false,
      );
    }

    // 7. Nội suy trạng thái tại thời điểm effectiveProgress (0.0 -> 1.0)
    // - 12% đầu (0.00 .. 0.12): Cây cơ nhấp & lao tới chạm Bi chủ (3 bi đứng tại frame 0).
    // - 88% sau (0.12 .. 1.00): Phát chuỗi 120 bước vật lý của 3 bi.
    const double strikePhaseEnd = 0.12;
    double cueStickStrikeProgress = -1.0;
    double frameFloatIndex = 0.0;

    if (effectiveProgress <= 0.0001) {
      cueStickStrikeProgress = 0.0;
      frameFloatIndex = 0.0;
    } else if (effectiveProgress < strikePhaseEnd) {
      cueStickStrikeProgress = (effectiveProgress / strikePhaseEnd).clamp(0.0, 1.0);
      frameFloatIndex = 0.0;
    } else {
      final moveT =
          ((effectiveProgress - strikePhaseEnd) / (1.0 - strikePhaseEnd))
              .clamp(0.0, 1.0);
      // Áp dụng đường cong giảm tốc ma sát vải bàn bida
      final easedMoveT = 1.0 - math.pow(1.0 - moveT, 2.15).toDouble();
      frameFloatIndex = easedMoveT * (timeline.frames.length - 1);
      if (moveT < 0.07) {
        cueStickStrikeProgress = 1.0 + (moveT / 0.07) * 0.5;
      }
    }

    final idx0 = frameFloatIndex.floor().clamp(0, timeline.frames.length - 1);
    final idx1 = (idx0 + 1).clamp(0, timeline.frames.length - 1);
    final subT = frameFloatIndex - idx0;

    final f0 = timeline.frames[idx0];
    final f1 = timeline.frames[idx1];

    final currentCuePos = Offset.lerp(f0.cuePos, f1.cuePos, subT)!;
    final currentObj1Pos = Offset.lerp(f0.obj1Pos, f1.obj1Pos, subT)!;
    final currentObj2Pos = Offset.lerp(f0.obj2Pos, f1.obj2Pos, subT)!;

    final currentCueSpin = f0.cueSpin + (f1.cueSpin - f0.cueSpin) * subT;
    final currentObj1Spin = f0.obj1Spin + (f1.obj1Spin - f0.obj1Spin) * subT;
    final currentObj2Spin = f0.obj2Spin + (f1.obj2Spin - f0.obj2Spin) * subT;

    // 8. Khi đang mô phỏng, vẽ vệt sáng của đường đi thực tế tính tới frame idx0
    if (isSimulating && idx0 > 0) {
      _drawGlowingTrail(
        canvas,
        timeline.frames
            .take(idx0 + 1)
            .map((f) => f.obj2Pos)
            .toList(),
        BilliardPalette.objectBallRed,
      );
      _drawGlowingTrail(
        canvas,
        timeline.frames
            .take(idx0 + 1)
            .map((f) => f.obj1Pos)
            .toList(),
        BilliardPalette.objectBallYellow,
      );
      _drawGlowingTrail(
        canvas,
        timeline.frames
            .take(idx0 + 1)
            .map((f) => f.cuePos)
            .toList(),
        BilliardPalette.cueTrajectory,
      );
    }

    // 9. Vẽ vòng sóng xung kích va chạm (Impact Ripple) tại khoảnh khắc chạm Bi 1 và Bi 2
    if (isSimulating) {
      final dHit1 = frameFloatIndex - timeline.hit1FrameIndex;
      if (dHit1 >= 0 && dHit1 <= 18) {
        _drawImpactRipple(
          canvas,
          timeline.hit1ContactPoint,
          ballRadius,
          dHit1 / 18.0,
          BilliardPalette.objectBallYellow,
        );
      }

      final dHit2 = frameFloatIndex - timeline.hit2FrameIndex;
      if (dHit2 >= 0 && dHit2 <= 18) {
        _drawImpactRipple(
          canvas,
          timeline.hit2ContactPoint,
          ballRadius,
          dHit2 / 18.0,
          BilliardPalette.objectBallRed,
        );
      }
    }

    // 10. Vẽ 3 viên bi vật rắn (đã được đảm bảo không bao giờ chồng lấp ở mọi frame)
    _drawRealisticRollingBall(
      canvas,
      center: currentObj2Pos,
      radius: ballRadius,
      baseColor: BilliardPalette.objectBallRed,
      spinPhase: currentObj2Spin,
      isMeaslesCueBall: false,
    );
    _drawRealisticRollingBall(
      canvas,
      center: currentObj1Pos,
      radius: ballRadius,
      baseColor: BilliardPalette.objectBallYellow,
      spinPhase: currentObj1Spin,
      isMeaslesCueBall: false,
    );
    _drawRealisticRollingBall(
      canvas,
      center: currentCuePos,
      radius: ballRadius,
      baseColor: BilliardPalette.cueBallWhite,
      spinPhase: currentCueSpin,
      isMeaslesCueBall: true,
    );

    // 11. Vẽ Cây cơ Bida lúc chuẩn bị đánh và khi ra ngọn cơ
    if (!hideTrajectories &&
        mode != DiagramDisplayMode.thumbnail &&
        cueStickStrikeProgress >= 0.0) {
      _drawCueStick(
        canvas,
        cueBallCenter: timeline.frames.first.cuePos,
        shotDirection: timeline.initialAimDirection,
        ballRadius: ballRadius,
        strikeProgress: cueStickStrikeProgress,
      );
    }

    canvas.restore();
  }

  /// BỘ GIẢI VẬT LÝ VẬT RẮN 120 BƯỚC (POSITION-BASED DYNAMICS NON-PENETRATION SOLVER):
  /// Giải bài toán chuyển động của 3 bi sao cho:
  /// 1. Điểm chạm vào Bi 1 và Bi 2 luôn dừng ở bề mặt ngoài (cách tâm đúng 2.06 * ballRadius).
  /// 2. Bi 1 chỉ bắt đầu chạy sau khi Bi chủ thực sự chạm tới bề mặt Bi 1.
  /// 3. Bi 2 chỉ bắt đầu chạy sau khi Bi chủ (hoặc Bi 1) thực sự chạm tới bề mặt Bi 2.
  ///    Nếu bài học để `objectBall2Path` rỗng mà Bi chủ chạm vào Bi 2, Bi 2 tự động lăn nhẹ ra theo hướng va chạm!
  /// 4. Tại MỌI bước thời gian `k = 0..120`, bộ giải PBD kiểm tra cả 3 cặp bi `(Trắng-Vàng, Trắng-Đỏ, Vàng-Đỏ)`
  ///    và đẩy tách mặt cầu để khoảng cách tâm luôn >= `2.05 * ballRadius` (tuyệt đối không chồng lên nhau).
  _SolvedTimeline _solveCollisionFreeTimeline({
    required List<Offset> cueRaw,
    required List<Offset> obj1Raw,
    required List<Offset> obj2Raw,
    required Rect playRect,
    required double ballRadius,
  }) {
    const int totalSteps = 120;
    final minSep = ballRadius * 2.06; // Khoảng cách tâm tối thiểu giữa 2 bi (2R + khe hở 3%)

    Offset clampToTable(Offset p) {
      return Offset(
        p.dx.clamp(playRect.left + ballRadius, playRect.right - ballRadius),
        p.dy.clamp(playRect.top + ballRadius, playRect.bottom - ballRadius),
      );
    }

    // Bước A: Tách vị trí khởi đầu (Frame 0) nếu tọa độ mẫu đặt 2 bi quá sát nhau
    Offset cue0 = clampToTable(cueRaw.first);
    Offset obj1_0 = clampToTable(obj1Raw.first);
    Offset obj2_0 = clampToTable(obj2Raw.first);

    ({Offset a, Offset b}) separatePair(
      Offset a,
      Offset b, {
      required double weightA,
      required double weightB,
    }) {
      final delta = a - b;
      final dist = delta.distance;
      if (dist >= minSep) return (a: a, b: b);
      final normal = dist > 0.001
          ? delta / dist
          : const Offset(0.7071, -0.7071);
      final overlap = minSep - dist;
      final totalW = weightA + weightB;
      if (totalW <= 0.0001) return (a: a, b: b);
      final newA = clampToTable(a + normal * (overlap * (weightA / totalW)));
      final newB = clampToTable(b - normal * (overlap * (weightB / totalW)));
      return (a: newA, b: newB);
    }

    for (int iter = 0; iter < 4; iter++) {
      final s12 = separatePair(obj1_0, obj2_0, weightA: 0.5, weightB: 0.5);
      obj1_0 = s12.a;
      obj2_0 = s12.b;
      final sC1 = separatePair(cue0, obj1_0, weightA: 1.0, weightB: 0.0);
      cue0 = sC1.a;
      final sC2 = separatePair(cue0, obj2_0, weightA: 1.0, weightB: 0.0);
      cue0 = sC2.a;
    }

    // Bước B: Hiệu chỉnh các đỉnh đường đi của Bi chủ sao cho không đi xuyên qua tâm Bi 1 và Bi 2
    final adjustedCueWaypoints = <Offset>[cue0];
    for (int i = 1; i < cueRaw.length; i++) {
      Offset pt = clampToTable(cueRaw[i]);
      final prev = adjustedCueWaypoints.last;

      // Nếu đỉnh này nhắm vào tâm Bi 1 -> Lùi về điểm tiếp xúc ngoài mặt cầu (Ghost Ball)
      if ((pt - obj1_0).distance < minSep) {
        final dir = pt - prev;
        final unit =
            dir.distance > 0.01 ? dir / dir.distance : const Offset(0, -1);
        // Nếu còn điểm tiếp theo sau Bi 1, lệch nhẹ tâm Ghost Ball về phía hướng tách để đường đi vòng qua má bi
        Offset lateralBias = Offset.zero;
        if (i + 1 < cueRaw.length) {
          final nextPt = cueRaw[i + 1];
          final outDir = nextPt - obj1_0;
          if (outDir.distance > 0.1) {
            final perp = Offset(-unit.dy, unit.dx);
            final sideSign =
                (outDir.dx * perp.dx + outDir.dy * perp.dy) >= 0 ? 1.0 : -1.0;
            lateralBias = perp * (sideSign * ballRadius * 0.45);
          }
        }
        final contactVec = (pt + lateralBias) - obj1_0;
        final contactUnit = contactVec.distance > 0.01
            ? contactVec / contactVec.distance
            : -unit;
        pt = clampToTable(obj1_0 + contactUnit * minSep);
      }

      // Nếu đỉnh cuối (hoặc đỉnh trung gian) nhắm vào tâm Bi 2 -> Dừng ở mép ngoài Bi 2 (cách tâm minSep)
      if ((pt - obj2_0).distance < minSep) {
        final dir = pt - prev;
        final unit =
            dir.distance > 0.01 ? dir / dir.distance : const Offset(0, -1);
        pt = clampToTable(obj2_0 - unit * minSep);
      }

      adjustedCueWaypoints.add(pt);
    }

    // Nếu bài học không khai báo đường đi cho Bi Đỏ (obj2Raw chỉ có 1 điểm),
    // tạo hiệu ứng Bi Đỏ lăn nhẹ ra 1.35 * ballRadius khi được Bi chủ chạm tới!
    final adjustedObj2Waypoints = <Offset>[obj2_0];
    if (obj2Raw.length > 1) {
      for (int i = 1; i < obj2Raw.length; i++) {
        adjustedObj2Waypoints.add(clampToTable(obj2Raw[i]));
      }
    } else if (adjustedCueWaypoints.length >= 2) {
      final lastCue = adjustedCueWaypoints.last;
      final prevCue = adjustedCueWaypoints[adjustedCueWaypoints.length - 2];
      final impactDir = obj2_0 - lastCue;
      final fallbackDir = lastCue - prevCue;
      final pushUnit = impactDir.distance > 0.01
          ? impactDir / impactDir.distance
          : (fallbackDir.distance > 0.01
              ? fallbackDir / fallbackDir.distance
              : const Offset(0, -1));
      adjustedObj2Waypoints.add(
        clampToTable(obj2_0 + pushUnit * (ballRadius * 1.35)),
      );
    }

    final adjustedObj1Waypoints = <Offset>[
      obj1_0,
      ...obj1Raw.skip(1).map(clampToTable),
    ];

    // Lấy mẫu đường cong mượt cho Bi chủ, Bi 1 và Bi 2
    final cueDense = _sampleSmoothCurvePath(
      adjustedCueWaypoints,
      obj1Pos: obj1_0,
      ballRadius: ballRadius,
    );
    final obj1Dense = _samplePolyline(adjustedObj1Waypoints, samplesPerSegment: 20);
    final obj2Dense = _samplePolyline(adjustedObj2Waypoints, samplesPerSegment: 16);

    final cueCumLen = _cumulativeLengths(cueDense);
    final obj1CumLen = _cumulativeLengths(obj1Dense);
    final obj2CumLen = _cumulativeLengths(obj2Dense);

    // Xác định bước thời gian `hit1Step` khi Bi chủ tiếp cận Bi 1
    int hit1Step = 18;
    double bestDist1 = double.infinity;
    for (int k = 1; k <= totalSteps; k++) {
      final posC = _pointAtFraction(cueDense, cueCumLen, k / totalSteps);
      final d = (posC - obj1_0).distance;
      if (d < bestDist1) {
        bestDist1 = d;
        hit1Step = k;
      }
      if (d <= minSep * 1.08) {
        hit1Step = k;
        break;
      }
    }
    hit1Step = hit1Step.clamp(4, totalSteps - 25);

    // Xác định bước thời gian `hit2Step` khi Bi chủ tiếp cận Bi 2 (sau hit1Step)
    int hit2Step = (hit1Step + 40).clamp(25, totalSteps - 10);
    double bestDist2 = double.infinity;
    for (int k = hit1Step + 4; k <= totalSteps; k++) {
      final posC = _pointAtFraction(cueDense, cueCumLen, k / totalSteps);
      final d = (posC - obj2_0).distance;
      if (d < bestDist2) {
        bestDist2 = d;
        hit2Step = k;
      }
      if (d <= minSep * 1.12) {
        hit2Step = k;
        break;
      }
    }

    // Bước C: Mô phỏng 120 bước và giải ràng buộc KHÔNG CHỒNG LẤP (PBD Non-Penetration) ở từng bước
    final frames = <_PhysicsStepState>[];
    double cueSpinAcc = 0.0;
    double obj1SpinAcc = 0.0;
    double obj2SpinAcc = 0.0;

    Offset prevC = cue0;
    Offset prev1 = obj1_0;
    Offset prev2 = obj2_0;

    for (int k = 0; k <= totalSteps; k++) {
      final fracC = k / totalSteps;
      Offset posC = _pointAtFraction(cueDense, cueCumLen, fracC);

      // Bi 1 đứng yên trước hit1Step; sau hit1Step bắt đầu chạy nhanh hơn Bi chủ một chút để tách mặt bi
      double frac1 = 0.0;
      if (k > hit1Step) {
        final raw1 = (k - hit1Step) / (totalSteps - hit1Step);
        frac1 = math.pow(raw1.clamp(0.0, 1.0), 0.78).toDouble();
      }
      Offset pos1 = _pointAtFraction(obj1Dense, obj1CumLen, frac1);

      // Bi 2 đứng yên trước hit2Step; sau hit2Step bắt đầu lăn
      double frac2 = 0.0;
      if (k > hit2Step) {
        final raw2 = (k - hit2Step) / (totalSteps - hit2Step);
        frac2 = math.pow(raw2.clamp(0.0, 1.0), 0.82).toDouble();
      }
      Offset pos2 = _pointAtFraction(obj2Dense, obj2CumLen, frac2);

      // GIẢI RÀNG BUỘC KHÔNG CHỒNG LẤP (5 vòng lặp PBD mỗi bước thời gian)
      for (int iter = 0; iter < 5; iter++) {
        // 1. Giữa Bi chủ (posC) và Bi 1 (pos1):
        if ((posC - pos1).distance < minSep) {
          if (k <= hit1Step) {
            // Trước hoặc ngay lúc chạm Bi 1: Bi 1 còn đứng yên, giữ Bi chủ ở ngoài mặt cầu Bi 1
            final s = separatePair(posC, pos1, weightA: 1.0, weightB: 0.0);
            posC = s.a;
          } else {
            // Sau khi chạm: đẩy cả 2 tách nhau để không bao giờ cắt xuyên qua bụng nhau
            final s = separatePair(posC, pos1, weightA: 0.55, weightB: 0.45);
            posC = s.a;
            pos1 = s.b;
          }
        }

        // 2. Giữa Bi chủ (posC) và Bi 2 (pos2):
        if ((posC - pos2).distance < minSep) {
          if (k <= hit2Step) {
            final s = separatePair(posC, pos2, weightA: 1.0, weightB: 0.0);
            posC = s.a;
          } else {
            final s = separatePair(posC, pos2, weightA: 0.45, weightB: 0.55);
            posC = s.a;
            pos2 = s.b;
          }
        }

        // 3. Giữa Bi 1 (pos1) và Bi 2 (pos2):
        if ((pos1 - pos2).distance < minSep) {
          final w1 = k > hit1Step ? 0.65 : 0.5;
          final w2 = k > hit2Step ? 0.35 : 0.5;
          final s = separatePair(pos1, pos2, weightA: w1, weightB: w2);
          pos1 = s.a;
          pos2 = s.b;
        }
      }

      cueSpinAcc += (posC - prevC).distance / (ballRadius * 0.85);
      obj1SpinAcc += (pos1 - prev1).distance / (ballRadius * 0.85);
      obj2SpinAcc += (pos2 - prev2).distance / (ballRadius * 0.85);

      prevC = posC;
      prev1 = pos1;
      prev2 = pos2;

      frames.add(
        _PhysicsStepState(
          cuePos: posC,
          obj1Pos: pos1,
          obj2Pos: pos2,
          cueSpin: cueSpinAcc,
          obj1Spin: obj1SpinAcc,
          obj2Spin: obj2SpinAcc,
        ),
      );
    }

    final rawAim = adjustedCueWaypoints.length > 1
        ? (adjustedCueWaypoints[1] - cue0)
        : const Offset(0, -1);
    final initialAimDir =
        rawAim.distance > 0.01 ? rawAim / rawAim.distance : const Offset(0, -1);

    final hit1Contact = Offset.lerp(
      frames[hit1Step].cuePos,
      frames[hit1Step].obj1Pos,
      0.5,
    )!;
    final hit2Contact = Offset.lerp(
      frames[hit2Step].cuePos,
      frames[hit2Step].obj2Pos,
      0.5,
    )!;

    return _SolvedTimeline(
      frames: frames,
      hit1FrameIndex: hit1Step,
      hit1ContactPoint: hit1Contact,
      hit2FrameIndex: hit2Step,
      hit2ContactPoint: hit2Contact,
      initialAimDirection: initialAimDir,
    );
  }

  Offset _pointAtFraction(
    List<Offset> pts,
    List<double> cumLengths,
    double fraction,
  ) {
    if (pts.isEmpty) return Offset.zero;
    if (pts.length == 1 || fraction <= 0.0 || cumLengths.last <= 0.001) {
      return pts.first;
    }
    if (fraction >= 1.0) return pts.last;

    final targetDist = cumLengths.last * fraction;
    for (int i = 0; i < cumLengths.length - 1; i++) {
      final d0 = cumLengths[i];
      final d1 = cumLengths[i + 1];
      if (targetDist <= d1) {
        final segLen = d1 - d0;
        final localT = segLen <= 0.0001 ? 0.0 : (targetDist - d0) / segLen;
        return Offset.lerp(pts[i], pts[i + 1], localT)!;
      }
    }
    return pts.last;
  }

  List<Offset> _sampleSmoothCurvePath(
    List<Offset> waypoints, {
    required Offset obj1Pos,
    required double ballRadius,
  }) {
    if (waypoints.length < 2) return waypoints;
    if (waypoints.length == 2) {
      return _samplePolyline(waypoints, samplesPerSegment: 24);
    }

    final samples = <Offset>[];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p0 = waypoints[i];
      final p1 = waypoints[i + 1];

      if (i == 1 &&
          waypoints.length >= 3 &&
          (p0 - obj1Pos).distance <= ballRadius * 2.8) {
        final incomingDir = (p0 - waypoints[0]);
        final outVec = (p1 - p0);
        if (incomingDir.distance > 1.0 && outVec.distance > 6.0) {
          final inUnit = incomingDir / incomingDir.distance;
          final controlPt =
              Offset.lerp(p0, p1, 0.30)! + inUnit * (outVec.distance * 0.14);
          const steps = 28;
          for (int s = 0; s <= steps; s++) {
            final t = s / steps;
            final oneMinusT = 1.0 - t;
            final bezier = p0 * (oneMinusT * oneMinusT) +
                controlPt * (2.0 * oneMinusT * t) +
                p1 * (t * t);
            if (samples.isEmpty || (bezier - samples.last).distance > 0.5) {
              samples.add(bezier);
            }
          }
          continue;
        }
      }

      const segSteps = 22;
      for (int s = 0; s <= segSteps; s++) {
        final pt = Offset.lerp(p0, p1, s / segSteps)!;
        if (samples.isEmpty || (pt - samples.last).distance > 0.5) {
          samples.add(pt);
        }
      }
    }
    return samples;
  }

  List<Offset> _samplePolyline(List<Offset> pts, {int samplesPerSegment = 16}) {
    if (pts.length < 2) return pts;
    final out = <Offset>[pts.first];
    for (int i = 0; i < pts.length - 1; i++) {
      for (int s = 1; s <= samplesPerSegment; s++) {
        out.add(Offset.lerp(pts[i], pts[i + 1], s / samplesPerSegment)!);
      }
    }
    return out;
  }

  List<double> _cumulativeLengths(List<Offset> pts) {
    if (pts.isEmpty) return const [];
    final lengths = <double>[0.0];
    double sum = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += (pts[i + 1] - pts[i]).distance;
      lengths.add(sum);
    }
    return lengths;
  }

  void _drawTrackGuide(
    Canvas canvas,
    List<Offset> track,
    Color color, {
    required bool isDashed,
  }) {
    if (track.length < 2) return;
    // Lọc bớt các điểm đứng yên trùng nhau
    final filtered = <Offset>[track.first];
    for (int i = 1; i < track.length; i++) {
      if ((track[i] - filtered.last).distance >= 2.5) {
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
      final midIdx = (filtered.length * 0.65).floor().clamp(1, filtered.length - 1);
      drawArrowHead(
        canvas,
        filtered[midIdx - 1],
        filtered[midIdx],
        color,
        size: 6.5,
      );
    }
  }

  /// Vẽ viên bi Carom 3D kèm các chấm đỏ Aramith Pro-Cup xoay theo quãng đường lăn
  void _drawRealisticRollingBall(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color baseColor,
    required double spinPhase,
    required bool isMeaslesCueBall,
  }) {
    drawSphereBall(canvas, center, radius, baseColor);

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.94)),
    );

    if (isMeaslesCueBall) {
      final dotColor = BilliardPalette.chalkTipRed.withValues(alpha: 0.90);
      final dotRadius = (radius * 0.145).clamp(1.2, 2.6);

      final angles = <double>[
        spinPhase,
        spinPhase + math.pi * 0.5,
        spinPhase + math.pi,
        spinPhase + math.pi * 1.5,
      ];
      for (final a in angles) {
        final projX = math.sin(a) * radius * 0.58;
        final projY = math.cos(a * 0.7) * radius * 0.42;
        final depthScale = (0.65 + 0.35 * math.cos(a)).clamp(0.4, 1.0);
        canvas.drawCircle(
          center + Offset(projX, projY),
          dotRadius * depthScale,
          Paint()..color = dotColor,
        );
      }
    } else {
      final spotAngle = spinPhase + 0.6;
      final spotOffset = Offset(
        math.sin(spotAngle) * radius * 0.48,
        math.cos(spotAngle * 0.8) * radius * 0.48,
      );
      canvas.drawCircle(
        center + spotOffset,
        (radius * 0.13).clamp(1.0, 2.2),
        Paint()..color = Colors.white.withValues(alpha: 0.70),
      );
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
        _drawTinyNumber(canvas, '${i * 10}', Offset(leftX, y));
        _drawTinyNumber(canvas, '${i * 10}', Offset(rightX, y));
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
        _drawTinyNumber(canvas, '${j * 10}', Offset(x, topY));
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
        oldDelegate.mode != mode ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.hideTrajectories != hideTrajectories ||
        oldDelegate.halfTableCloseup != halfTableCloseup;
  }
}

/// WIDGET SƠ ĐỒ BÀN CAROM DỌC KÈM ENGINE MÔ PHỎNG VẬT LÝ VẬT RẮN KHÔNG CHỒNG LẤP
class CaromTableDiagram extends BaseBilliardDiagramWidget<TableDiagramSpec> {
  final bool hideTrajectories;
  final void Function(DraggableTableElement element, Offset newDiamondCoord)?
      onElementDragged;

  const CaromTableDiagram({
    super.key,
    required super.spec,
    super.mode = DiagramDisplayMode.standard,
    super.titleOverride,
    super.onTap,
    this.hideTrajectories = false,
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
        hideTrajectories: hideTrajectories,
      );
    }

    if (onElementDragged != null) {
      return _EditableCaromTableCanvas(
        spec: spec,
        onElementDragged: onElementDragged!,
      );
    }

    final useHalf = CaromTablePainter.canUseHalfTable(spec);
    return AspectRatio(
      aspectRatio: useHalf ? 0.82 : 0.52,
      child: CustomPaint(
        painter: CaromTablePainter(
          spec: spec,
          mode: mode,
          hideTrajectories: hideTrajectories,
          halfTableCloseup: useHalf,
        ),
      ),
    );
  }
}

/// Canvas cho phép người dùng kéo trực tiếp 3 bi & vùng gom trên mặt bàn dọc (Position Builder)
class _EditableCaromTableCanvas extends StatefulWidget {
  final TableDiagramSpec spec;
  final void Function(DraggableTableElement element, Offset newDiamondCoord)
      onElementDragged;

  const _EditableCaromTableCanvas({
    required this.spec,
    required this.onElementDragged,
  });

  @override
  State<_EditableCaromTableCanvas> createState() =>
      _EditableCaromTableCanvasState();
}

class _EditableCaromTableCanvasState extends State<_EditableCaromTableCanvas> {
  DraggableTableElement? _activeElement;

  Offset _pixelToDiamond(Offset localPos, Size size) {
    final rail =
        CaromTablePainter.railThicknessFor(DiagramDisplayMode.interactive);
    final playW = (size.width - rail * 2).clamp(1.0, double.infinity);
    final playH = (size.height - rail * 2).clamp(1.0, double.infinity);
    final shortRailDy =
        (((localPos.dx - rail) / playW) * 4.0).clamp(0.18, 3.82);
    final longRailDx = (((localPos.dy - rail) / playH) * 8.0).clamp(0.18, 7.82);
    return Offset(longRailDx, shortRailDy);
  }

  DraggableTableElement _pickNearestElement(Offset diamondPos) {
    final candidates = <DraggableTableElement, double>{
      DraggableTableElement.cueBall:
          (diamondPos - widget.spec.cueBall).distance,
      DraggableTableElement.objectBall1:
          (diamondPos - widget.spec.objectBall1).distance,
      DraggableTableElement.objectBall2:
          (diamondPos - widget.spec.objectBall2).distance,
      if (widget.spec.targetZoneCenter != null)
        DraggableTableElement.targetZone:
            (diamondPos - widget.spec.targetZoneCenter!).distance,
    };
    final sorted = candidates.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first.key;
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
            final dPos = _pixelToDiamond(details.localPosition, size);
            _activeElement = _pickNearestElement(dPos);
            widget.onElementDragged(_activeElement!, dPos);
          },
          onPanUpdate: (details) {
            if (_activeElement == null) return;
            final dPos = _pixelToDiamond(details.localPosition, size);
            widget.onElementDragged(_activeElement!, dPos);
          },
          onPanEnd: (_) => _activeElement = null,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: CaromTablePainter(
                spec: widget.spec,
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
  final bool hideTrajectories;

  const _InteractiveCaromTableBody({
    required this.initialSpec,
    this.hideTrajectories = false,
  });

  @override
  State<_InteractiveCaromTableBody> createState() =>
      _InteractiveCaromTableBodyState();
}

class _InteractiveCaromTableBodyState extends State<_InteractiveCaromTableBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _flipLongRail = false;
  bool _flipShortRail = false;
  bool _slowMotion = false;
  late bool _showNumbers;
  late bool _halfTableCloseup;

  @override
  void initState() {
    super.initState();
    _showNumbers = widget.initialSpec.showDiamondNumbers;
    _halfTableCloseup = CaromTablePainter.canUseHalfTable(widget.initialSpec);
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
    if (oldWidget.initialSpec != widget.initialSpec) {
      _controller.reset();
      _flipLongRail = false;
      _flipShortRail = false;
      _showNumbers = widget.initialSpec.showDiamondNumbers;
      _halfTableCloseup = CaromTablePainter.canUseHalfTable(widget.initialSpec);
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
      _controller.duration =
          Duration(milliseconds: _slowMotion ? 5200 : 2600);
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

  void _openZoomableModal(TableDiagramSpec activeSpec, bool useHalf) {
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
                      mode: DiagramDisplayMode.interactive,
                      halfTableCloseup: useHalf,
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
    final activeSpec = widget.initialSpec
        .flipped(
          flipHorizontal: _flipLongRail,
          flipVertical: _flipShortRail,
        )
        .copyWithFlags(showDiamondNumbers: _showNumbers);

    final effectiveHalf =
        _halfTableCloseup && CaromTablePainter.canUseHalfTable(activeSpec);

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
                mode: DiagramDisplayMode.interactive,
                hideTrajectories: widget.hideTrajectories,
                halfTableCloseup: effectiveHalf,
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
                  tooltip: _controller.isAnimating ? 'Tạm dừng' : 'Chạy mô phỏng',
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
          children: const [
            _LegendDot(
                color: BilliardPalette.cueTrajectory, label: 'Bi chủ (Trắng)'),
            _LegendDot(
                color: BilliardPalette.objectBallYellow,
                label: 'Bi đích 1 (Vàng)'),
            _LegendDot(
                color: BilliardPalette.objectBallRed, label: 'Bi đích 2 (Đỏ)'),
            _LegendDot(
                color: BilliardPalette.diamondGold, label: 'Vùng gom bi'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (CaromTablePainter.canUseHalfTable(activeSpec))
              FilterChip(
                avatar: const Icon(Icons.zoom_in, size: 16),
                label: Text(
                  effectiveHalf ? 'Cận cảnh 1/2 bàn' : 'Xem cả bàn dọc',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: effectiveHalf,
                onSelected: (v) => setState(() => _halfTableCloseup = v),
              ),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _flipShortRail = !_flipShortRail),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Lật Trái/Phải', style: TextStyle(fontSize: 12)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _flipLongRail = !_flipLongRail;
                  if (_flipLongRail) _halfTableCloseup = false;
                });
              },
              icon: const Icon(Icons.swap_vert, size: 16),
              label: const Text('Lật Trên/Dưới', style: TextStyle(fontSize: 12)),
            ),
            FilterChip(
              label: const Text('Số nút băng', style: TextStyle(fontSize: 12)),
              selected: _showNumbers,
              onSelected: (v) => setState(() => _showNumbers = v),
            ),
            IconButton.outlined(
              tooltip: 'Phóng to toàn màn hình (Zoom 4x)',
              onPressed: () => _openZoomableModal(activeSpec, effectiveHalf),
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
