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
  final ShotInputValidationResult validation;
  final bool hitsFirstObjectBall;
  final bool hitsSecondBall;

  /// `null` nếu bài học không có `targetZoneCenter`;
  /// `true` khi và chỉ khi cả 3 bi dừng hẳn và tâm cả 3 bi nằm trong `targetZoneRadius`.
  final bool? gathersInZone;

  /// Độ dày chạm thực tế suy ra từ tia ngắm hoặc lần va chạm đầu tiên với Bi 1
  /// (`null` nếu tia ngắm không hướng vào Bi 1, ví dụ cú đánh A-băng Bricole).
  final BallContactSpec? effectiveContact;

  final String feedbackMessage;

  const SolvedShotOutcome({
    required this.updatedDiagram,
    required this.simulationResult,
    this.validation = const ShotInputValidationResult(<ShotInputValidationIssue>[]),
    required this.hitsFirstObjectBall,
    required this.hitsSecondBall,
    required this.gathersInZone,
    this.effectiveContact,
    required this.feedbackMessage,
  });

  bool get isInputValid => validation.isValid;

  /// Trả về `true` nếu đầu vào hợp lệ và cú đánh đạt tất cả mục tiêu của bài học (ghi điểm Carom, và gom bi nếu có vùng gom).
  bool get isSuccessfulShot =>
      isInputValid &&
      hitsSecondBall &&
      (gathersInZone == null || gathersInZone == true);
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

  /// Xóa bộ nhớ đệm (dùng trong kiểm thử để đo chính xác số lần gọi `CaromPhysicsEngine.simulate`).
  static void clearCache() => _resultCache.clear();

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

  /// Quy đổi ngược từ dấu lệch bên `lateralSign` sang `ContactSide`.
  static ContactSide contactSideFromLateralSign(double lateralSign) {
    if (lateralSign.abs() <= 1e-4) return ContactSide.center;
    return lateralSign > 0.0 ? ContactSide.left : ContactSide.right;
  }

  /// Tính `BallContactSpec` thực tế từ hướng ngắm `aimDirection` (hoặc trả về `null` nếu tia ngắm trượt qua ngoài mặt cầu `2R` của Bi 1).
  static BallContactSpec? inferEffectiveContact({
    required TableDiagramSpec diagram,
    required Vec2 aimDirection,
    TableConfig config = defaultConfig,
  }) {
    final cuePosM = config.diamondToMeters(
      Vec2(diagram.cueBall.dx, diagram.cueBall.dy),
    );
    final obj1PosM = config.diamondToMeters(
      Vec2(diagram.objectBall1.dx, diagram.objectBall1.dy),
    );
    final inferred = AimGeometry.inferContactFromAimDirection(
      cueBallPos: cuePosM,
      objectBallPos: obj1PosM,
      ballRadius: config.ballRadius,
      aimDirection: aimDirection,
    );
    if (inferred == null) return null;

    final side = contactSideFromLateralSign(inferred.lateralSign);
    final pct = (inferred.fraction * 100).round();
    return BallContactSpec(
      label: side == ContactSide.center
          ? 'Tràn mặt (~100%)'
          : 'Độ dày thực ~$pct% trái',
      fraction: inferred.fraction,
      side: side,
      description:
          'Độ dày chạm thực tế suy ra từ tia ngắm tự do (f = ${inferred.fraction.toStringAsFixed(2)})',
    );
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

  /// Chạy (hoặc lấy từ bộ nhớ đệm) kết quả `SimulationResult` cho một `ShotInput` hợp lệ.
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
  /// - Tốc độ đầu cơ được tính qua `baseParams.effectiveCueSpeedForLevel(effectiveSpeedLevel)`,
  ///   đảm bảo tăng `speedLevel` từ 1 -> 5 luôn làm tăng nghiêm ngặt vận tốc đầu cơ cho mọi bài học.
  /// - Không có bất kỳ nhánh trả kết quả giả nào.
  static SolvedShotOutcome evaluateAdjustedShot({
    required BilliardLesson lesson,
    required BallContactSpec activeContact,
    required CueBallEffetSpec activeEffet,
    int? activeSpeedLevel,
    double? activeCustomCueSpeed,
    Offset? activeAimTargetDiamond,
    double? activeExplicitAimAngleRadians,
  }) {
    final baseParams = lesson.shotParams;
    final isDefaultContact =
        (activeContact.fraction - baseParams.contact.fraction).abs() < 1e-4 &&
            activeContact.side == baseParams.contact.side;

    final effectiveSpeedLevel = activeSpeedLevel ?? baseParams.speedLevel;
    final calibratedCueSpeed = activeCustomCueSpeed ??
        baseParams.effectiveCueSpeedForLevel(effectiveSpeedLevel);

    // Nếu bài học có điểm ngắm tường minh (ví dụ đánh A-băng Bricole),
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
      customCueSpeed: calibratedCueSpeed,
      cueElevationDegrees: baseParams.cueElevationDegrees,
      aimTargetDiamond: aimTarget,
      explicitAimAngleRadians: aimAngle,
    );

    return evaluateShotInput(
      baseDiagram: lesson.diagram,
      input: shotInput,
      fallbackContact: (aimTarget == null && aimAngle == null)
          ? activeContact
          : null,
    );
  }

  /// Giải trực tiếp từ `TableDiagramSpec` và `ShotInput` (dùng chung cho Bài học, Máy tính Bộ số, và Position Builder).
  /// Nếu `input` không hợp lệ (bi chồng lấp hoặc ngoài biên bàn), trả về `SolvedShotOutcome` với `validation.isValid == false`
  /// mà không tự ý sửa thế bi.
  static SolvedShotOutcome evaluateShotInput({
    required TableDiagramSpec baseDiagram,
    required ShotInput input,
    BallContactSpec? fallbackContact,
  }) {
    final validation = input.validate(defaultConfig);
    if (!validation.isValid) {
      final initialSnap = SimulationSnapshot(
        timestamp: 0.0,
        cueBall: BallState(id: BallId.cue, position: input.cueBallPosition),
        objectBall1:
            BallState(id: BallId.object1, position: input.objectBall1Position),
        objectBall2:
            BallState(id: BallId.object2, position: input.objectBall2Position),
      );
      final emptyResult = SimulationResult(
        config: defaultConfig,
        input: input,
        snapshots: [initialSnap],
        collisionEvents: const [],
        durationSeconds: 0.0,
        terminationReason: SimulationTerminationReason.allBallsStopped,
      );
      return SolvedShotOutcome(
        updatedDiagram: baseDiagram,
        simulationResult: emptyResult,
        validation: validation,
        hitsFirstObjectBall: false,
        hitsSecondBall: false,
        gathersInZone: input.targetZoneCenterMeters != null ? false : null,
        effectiveContact: null,
        feedbackMessage:
            'Thế bi không hợp lệ: ${validation.issues.map((e) => e.message).join(' ')}',
      );
    }

    final simResult = runCachedSimulation(input);
    final eval = simResult.evaluation;

    BallContactSpec? effectiveContact = fallbackContact;
    if (effectiveContact == null) {
      if (eval.firstObjectBallHit == BallId.object1 &&
          eval.firstObject1ContactFraction != null) {
        final f = eval.firstObject1ContactFraction!;
        final side = contactSideFromLateralSign(
          eval.firstObject1LateralSign ?? 0.0,
        );
        effectiveContact = BallContactSpec(
          label: side == ContactSide.center
              ? 'Tràn mặt (~100%)'
              : 'Độ dày thực ~${(f * 100).round()}% trái',
          fraction: f,
          side: side,
          description:
              'Độ dày va chạm thực tế tại thời điểm chạm Bi 1 (f = ${f.toStringAsFixed(2)})',
        );
      } else {
        effectiveContact = inferEffectiveContact(
          diagram: baseDiagram,
          aimDirection: input.aimDirection,
        );
      }
    }

    return SolvedShotOutcome(
      updatedDiagram: baseDiagram,
      simulationResult: simResult,
      validation: validation,
      hitsFirstObjectBall: eval.hitsFirstObjectBall,
      hitsSecondBall: eval.hitsSecondBall,
      gathersInZone: eval.gathersInZone,
      effectiveContact: effectiveContact,
      feedbackMessage: eval.feedbackMessage,
    );
  }
}
