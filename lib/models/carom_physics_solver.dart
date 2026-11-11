import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../physics/billiard_physics.dart';
import 'billiard_lesson.dart';

/// Kết quả tính toán quỹ đạo từ Engine Vật lý Carom (`CaromPhysicsEngine`).
/// Hoàn toàn dựa trên tích phân động lực học SI (không dùng heuristic dịch điểm hay ép kết quả).
class SolvedShotOutcome {
  final TableDiagramSpec updatedDiagram;
  final SimulationResult simulationResult;
  final bool hitsFirstObjectBall;
  final bool hitsSecondBall;

  /// `null` nếu bài học không có `targetZoneCenter`;
  /// `true` khi và chỉ khi cả 3 bi dừng hẳn và tâm cả 3 bi nằm trong `targetZoneRadius`.
  final bool? gathersInZone;

  final String feedbackMessage;

  const SolvedShotOutcome({
    required this.updatedDiagram,
    required this.simulationResult,
    required this.hitsFirstObjectBall,
    required this.hitsSecondBall,
    required this.gathersInZone,
    required this.feedbackMessage,
  });

  /// Trả về `true` nếu cú đánh đạt tất cả mục tiêu của bài học (ghi điểm Carom, và gom bi nếu có vùng gom).
  bool get isSuccessfulShot =>
      hitsSecondBall && (gathersInZone == null || gathersInZone == true);
}

/// Bộ chuyển đổi (Adapter) và Cache kết nối giữa Model UI (`TableDiagramSpec`, `ShotParameters`)
/// và Engine Vật lý độc lập (`CaromPhysicsEngine` trong `lib/physics/`).
class CaromPhysicsSolver {
  static const TableConfig defaultConfig = TableConfig.standardCarom;
  static const CaromPhysicsEngine _engine = CaromPhysicsEngine(
    config: defaultConfig,
  );

  static final LinkedHashMap<ShotInput, SimulationResult> _resultCache =
      LinkedHashMap<ShotInput, SimulationResult>();
  static const int _maxCacheEntries = 48;

  /// Quy đổi `ContactSide` trên sơ đồ bàn dọc sang dấu pháp tuyến `lateralSign` của `AimGeometry`:
  /// - Trên sơ đồ bàn dọc (`X_screen = y`, `Y_screen = x`), khi nhìn từ Bi chủ sang Bi mục tiêu 1:
  ///   + `ContactSide.left` (chạm má trái): Ghost Ball lệch về phía `+perpCCW` (`lateralSign = +1.0`).
  ///   + `ContactSide.right` (chạm má phải): Ghost Ball lệch về phía `-perpCCW` (`lateralSign = -1.0`).
  ///   + `ContactSide.center` (trực diện / tràn mặt): `lateralSign = 0.0`.
  static double lateralSignForContactSide(ContactSide side) {
    switch (side) {
      case ContactSide.left:
        return 1.0;
      case ContactSide.right:
        return -1.0;
      case ContactSide.center:
        return 0.0;
    }
  }

  /// Xây dựng `ShotInput` chuẩn SI (mét, m/s, rad) từ thông số hình bi và thông số cú đánh.
  static ShotInput buildShotInput({
    required TableDiagramSpec diagram,
    required BallContactSpec contact,
    required CueBallEffetSpec effet,
    required int speedLevel,
    double? customCueSpeed,
    double cueElevationDegrees = 0.0,
    Offset? aimTargetDiamond,
    double? explicitAimAngleRadians,
    TableConfig config = defaultConfig,
  }) {
    final cuePosM = config.diamondToMeters(
      Vec2(diagram.cueBall.dx, diagram.cueBall.dy),
    );
    final obj1PosM = config.diamondToMeters(
      Vec2(diagram.objectBall1.dx, diagram.objectBall1.dy),
    );
    final obj2PosM = config.diamondToMeters(
      Vec2(diagram.objectBall2.dx, diagram.objectBall2.dy),
    );

    Vec2 aimDir;
    if (explicitAimAngleRadians != null) {
      aimDir = Vec2(
        math.cos(explicitAimAngleRadians),
        math.sin(explicitAimAngleRadians),
      );
    } else if (aimTargetDiamond != null) {
      final targetM = config.diamondToMeters(
        Vec2(aimTargetDiamond.dx, aimTargetDiamond.dy),
      );
      final delta = targetM - cuePosM;
      aimDir = delta.length > 1e-9 ? delta.normalized : Vec2.unitX;
    } else {
      final ghostAim = AimGeometry.computeGhostBallAim(
        cueBallPos: cuePosM,
        objectBallPos: obj1PosM,
        ballRadius: config.ballRadius,
        fraction: contact.fraction,
        lateralSign: lateralSignForContactSide(contact.side),
      );
      aimDir = ghostAim.aimDirection;
    }

    final cueSpeed =
        customCueSpeed ?? ShotInput.cueSpeedFromLevel(speedLevel);
    final physTip = effet.physicalTipOffsetRatio;
    final tipOffsetRatio = Vec2(physTip.dx, physTip.dy);

    final zoneCenterM = diagram.targetZoneCenter != null
        ? config.diamondToMeters(
            Vec2(
              diagram.targetZoneCenter!.dx,
              diagram.targetZoneCenter!.dy,
            ),
          )
        : null;
    final zoneRadiusM = diagram.targetZoneCenter != null
        ? config.diamondDistanceToMeters(diagram.targetZoneRadius)
        : null;

    return ShotInput(
      cueBallPosition: cuePosM,
      objectBall1Position: obj1PosM,
      objectBall2Position: obj2PosM,
      aimDirection: aimDir,
      cueSpeed: cueSpeed,
      tipOffsetRatio: tipOffsetRatio,
      cueElevationRadians: cueElevationDegrees * math.pi / 180.0,
      targetZoneCenterMeters: zoneCenterM,
      targetZoneRadiusMeters: zoneRadiusM,
      maxTipOffsetRatio: config.maxTipOffsetRatio,
    );
  }

  /// Chạy (hoặc lấy từ bộ nhớ đệm) kết quả `SimulationResult` cho một `ShotInput`.
  static SimulationResult runCachedSimulation(ShotInput input) {
    final cached = _resultCache.remove(input);
    if (cached != null) {
      _resultCache[input] = cached;
      return cached;
    }
    final result = _engine.simulate(input);
    if (_resultCache.length >= _maxCacheEntries) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[input] = result;
    return result;
  }

  /// Giải vật lý thật cho cú đánh của một bài học (hoặc khi người học điều chỉnh Độ dày, Ép-phê, Lực).
  /// Không có bất kỳ nhánh trả kết quả giả nào.
  static SolvedShotOutcome evaluateAdjustedShot({
    required BilliardLesson lesson,
    required BallContactSpec activeContact,
    required CueBallEffetSpec activeEffet,
    int? activeSpeedLevel,
    Offset? activeAimTargetDiamond,
    double? activeExplicitAimAngleRadians,
  }) {
    final baseParams = lesson.shotParams;
    final isDefaultContact =
        (activeContact.fraction - baseParams.contact.fraction).abs() < 1e-4 &&
            activeContact.side == baseParams.contact.side;

    final effectiveSpeedLevel = activeSpeedLevel ?? baseParams.speedLevel;
    final customSpeed =
        (effectiveSpeedLevel == baseParams.speedLevel) ? baseParams.customCueSpeed : null;

    // Nếu bài học có điểm ngắm tường minh (ví dụ đánh A-băng Bricole hoặc góc tinh chỉnh),
    // chỉ dùng điểm ngắm đó khi người dùng giữ nguyên độ dày & má chạm chuẩn;
    // khi người dùng đổi độ dày chạm trái, tính lại tia ngắm Ghost Ball từ activeContact.
    final Offset? aimTarget = activeAimTargetDiamond ??
        (isDefaultContact ? baseParams.aimTargetDiamond : null);
    final double? aimAngle = activeExplicitAimAngleRadians ??
        (isDefaultContact ? baseParams.explicitAimAngleRadians : null);

    final shotInput = buildShotInput(
      diagram: lesson.diagram,
      contact: activeContact,
      effet: activeEffet,
      speedLevel: effectiveSpeedLevel,
      customCueSpeed: customSpeed,
      cueElevationDegrees: baseParams.cueElevationDegrees,
      aimTargetDiamond: aimTarget,
      explicitAimAngleRadians: aimAngle,
    );

    return evaluateShotInput(
      baseDiagram: lesson.diagram,
      input: shotInput,
    );
  }

  /// Giải trực tiếp từ `TableDiagramSpec` và `ShotInput` (dùng chung cho Bài học, Máy tính Bộ số, và Position Builder).
  static SolvedShotOutcome evaluateShotInput({
    required TableDiagramSpec baseDiagram,
    required ShotInput input,
  }) {
    final simResult = runCachedSimulation(input);
    final eval = simResult.evaluation;

    return SolvedShotOutcome(
      updatedDiagram: baseDiagram,
      simulationResult: simResult,
      hitsFirstObjectBall: eval.hitsFirstObjectBall,
      hitsSecondBall: eval.hitsSecondBall,
      gathersInZone: eval.gathersInZone,
      feedbackMessage: eval.feedbackMessage,
    );
  }
}
