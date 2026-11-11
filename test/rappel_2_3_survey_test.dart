// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:xavier_billiard_libre/physics/billiard_physics.dart';

void main() {
  test('Khảo sát có hệ thống thế bi Trô kéo về 2/3 (Rappel de base 2/3 de bille) - Má Phải Chuẩn', () {
    const config = TableConfig.standardCarom;
    const engine = CaromPhysicsEngine(config: config);

    // 1. Tọa độ đo đạc chuẩn xác từ lưới pixel và cadre sách gốc (media_1794403626708_8b299f8b.png)
    // Hệ Diamond:
    // Bi 2 (Object 1 - Vàng): X = 6.000, Y = 2.6667
    // Bi 1 (Cue - Trắng): X = 6.490, Y = 2.560
    // Bi 3 (Object 2 - Đỏ): X = 7.710, Y = 3.650
    final cuePosM = config.diamondToMeters(const Vec2(6.490, 2.560));
    final obj1PosM = config.diamondToMeters(const Vec2(6.000, 2.6667));
    final obj2PosM = config.diamondToMeters(const Vec2(7.710, 3.650));

    const fraction = 2.0 / 3.0;
    const lateralSign = -1.0; // Má phải (-1.0) theo chuẩn đối chiếu hình học sách

    final ghostAim = AimGeometry.computeGhostBallAim(
      cueBallPos: cuePosM,
      objectBallPos: obj1PosM,
      ballRadius: config.ballRadius,
      fraction: fraction,
      lateralSign: lateralSign,
    );
    final aimDir = ghostAim.aimDirection;

    // 2. Miền quét thô
    final zListCoarse = [-4.0, -6.0, -8.0, -10.0, -12.0, -14.0, -15.375]; // mm
    final vListCoarse = [1.8, 2.1, 2.4, 2.7, 3.0, 3.3, 3.6]; // m/s

    final surveyRecords = <Map<String, dynamic>>[];

    print('=== BẮT ĐẦU QUÉT THÔ MÁ PHẢI (49 CA) ===');
    for (final zMm in zListCoarse) {
      for (final vCue in vListCoarse) {
        final record = _runSingleSimulation(
          engine: engine,
          config: config,
          cuePosM: cuePosM,
          obj1PosM: obj1PosM,
          obj2PosM: obj2PosM,
          aimDir: aimDir,
          fraction: fraction,
          zMm: zMm,
          vCue: vCue,
        );
        surveyRecords.add(record);
      }
    }

    // Sắp xếp tìm ca tối ưu:
    // 1. Cả 5 tiêu chí allPassed == true
    // 1. AllPassed = true
    // 2. Không chạm băng trước khi tới bi 3 (cueHitsCushionBeforeCarom == false)
    // 3. dMinCueToObj2 nhỏ nhất (tiếp xúc trực diện Bi 3)
    // 4. Độ chênh lệch quãng đường bi 2 s2 so với mục tiêu 1.70L - 1.80L
    surveyRecords.sort((a, b) {
      final aPass = a['allPassed'] as bool;
      final bPass = b['allPassed'] as bool;
      if (aPass != bPass) return aPass ? -1 : 1;

      final aNoCush = !(a['cueHitsCushionBeforeCarom'] as bool);
      final bNoCush = !(b['cueHitsCushionBeforeCarom'] as bool);
      if (aNoCush != bNoCush) return aNoCush ? -1 : 1;

      final aHitsBoth = (a['criteriaA'] as bool) && (a['criteriaB'] as bool);
      final bHitsBoth = (b['criteriaA'] as bool) && (b['criteriaB'] as bool);
      if (aHitsBoth != bHitsBoth) return aHitsBoth ? -1 : 1;

      final aDmin = a['minDistCueToObj2'] as double;
      final bDmin = b['minDistCueToObj2'] as double;
      return aDmin.compareTo(bDmin);
    });

    print('\nTop 5 ca quét thô tốt nhất:');
    for (int i = 0; i < math.min(5, surveyRecords.length); i++) {
      final r = surveyRecords[i];
      print(
        '#$i: z=${r['zMm']}mm, v=${r['vCue']}m/s | '
        'Pass: ${r['allPassed']} | '
        'Hits: 1->2:${r['criteriaA']}, 1->3:${r['criteriaB']} (dMin=${(r['minDistCueToObj2'] as double).toStringAsFixed(4)}m) | '
        'B2 TopCushion:${r['criteriaC']}, s2=${(r['ball2PathLength'] as double).toStringAsFixed(2)}m (${(r['ball2PathLengthOverL'] as double).toStringAsFixed(2)}L) | '
        'Term: ${r['terminationReason']}',
      );
    }

    // 3. Quét tinh quanh ứng viên tốt nhất của quét thô
    final bestCoarse = surveyRecords.first;
    final bestZ = bestCoarse['zMm'] as double;
    final bestV = bestCoarse['vCue'] as double;

    print('\n=== BẮT ĐẦU QUÉT TINH QUANH z=$bestZ mm, v=$bestV m/s ===');
    final zFine = <double>[];
    for (double dz = -2.0; dz <= 2.0; dz += 0.5) {
      final z = (bestZ + dz).clamp(-15.375, -2.0);
      if (!zFine.any((element) => (element - z).abs() < 1e-4)) {
        zFine.add(double.parse(z.toStringAsFixed(3)));
      }
    }

    final vFine = <double>[];
    for (double dv = -0.4; dv <= 0.4; dv += 0.05) {
      final v = (bestV + dv).clamp(1.2, 4.5);
      if (!vFine.any((element) => (element - v).abs() < 1e-4)) {
        vFine.add(double.parse(v.toStringAsFixed(3)));
      }
    }

    final fineRecords = <Map<String, dynamic>>[];
    for (final z in zFine) {
      for (final v in vFine) {
        final record = _runSingleSimulation(
          engine: engine,
          config: config,
          cuePosM: cuePosM,
          obj1PosM: obj1PosM,
          obj2PosM: obj2PosM,
          aimDir: aimDir,
          fraction: fraction,
          zMm: z,
          vCue: v,
        );
        fineRecords.add(record);
      }
    }

    fineRecords.sort((a, b) {
      final aPass = a['allPassed'] as bool;
      final bPass = b['allPassed'] as bool;
      if (aPass != bPass) return aPass ? -1 : 1;

      final aNoCush = !(a['cueHitsCushionBeforeCarom'] as bool);
      final bNoCush = !(b['cueHitsCushionBeforeCarom'] as bool);
      if (aNoCush != bNoCush) return aNoCush ? -1 : 1;

      final aHitsBoth = (a['criteriaA'] as bool) && (a['criteriaB'] as bool);
      final bHitsBoth = (b['criteriaA'] as bool) && (b['criteriaB'] as bool);
      if (aHitsBoth != bHitsBoth) return aHitsBoth ? -1 : 1;

      // Ưu tiên s2 gần 1.70L - 1.80L
      final aS2Diff = ((a['ball2PathLengthOverL'] as double) - 1.75).abs();
      final bS2Diff = ((b['ball2PathLengthOverL'] as double) - 1.75).abs();
      return aS2Diff.compareTo(bS2Diff);
    });

    print('\nTop 5 ca quét tinh tốt nhất:');
    for (int i = 0; i < math.min(5, fineRecords.length); i++) {
      final r = fineRecords[i];
      print(
        '#$i: z=${r['zMm']}mm, v=${r['vCue']}m/s | '
        'AllPassed: ${r['allPassed']} | '
        'Hits: 1->2:${r['criteriaA']}, 1->3:${r['criteriaB']} (dMin=${(r['minDistCueToObj2'] as double).toStringAsFixed(4)}m) | '
        'B2 TopCushion:${r['criteriaC']}, s2=${(r['ball2PathLength'] as double).toStringAsFixed(2)}m (${(r['ball2PathLengthOverL'] as double).toStringAsFixed(2)}L) | '
        'Term: ${r['terminationReason']}',
      );
    }

    final fullReport = {
      'metadata': {
        'lessonName': 'Trô kéo về cơ bản 2/3 bi (Rappel de base 2/3 de bille)',
        'tableConfig': {
          'lengthMeters': config.lengthMeters,
          'widthMeters': config.widthMeters,
          'ballRadiusMeters': config.ballRadius,
          'ballMassKg': config.ballMass,
          'cueMassKg': config.cueMass,
        },
        'initialPositions': {
          'cueBall': {'x': cuePosM.x, 'y': cuePosM.y, 'diamond': [6.567, 2.493]},
          'objectBall1': {'x': obj1PosM.x, 'y': obj1PosM.y, 'diamond': [6.000, 2.6667]},
          'objectBall2': {'x': obj2PosM.x, 'y': obj2PosM.y, 'diamond': [7.710, 3.644]},
        },
        'contact': {
          'fraction': fraction,
          'side': 'right',
          'lateralSign': lateralSign,
          'cutAngleDegrees': ghostAim.cutAngleDegrees,
          'aimDirection': {'x': aimDir.x, 'y': aimDir.y},
        },
      },
      'coarseCount': surveyRecords.length,
      'fineCount': fineRecords.length,
      'bestCoarse': bestCoarse,
      'bestFine': fineRecords.first,
      'allCoarse': surveyRecords,
      'allFine': fineRecords,
    };

    final outDir = Directory(r'C:\Users\Admin\.gemini\antigravity\brain\1c741af9-b8e7-420f-86d8-333a73342e63');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final outFile = File('${outDir.path}/survey_results_rappel_2_3.json');
    outFile.writeAsStringSync(jsonEncode(fullReport));
    print('Đã lưu toàn bộ kết quả khảo sát ra: ${outFile.path}');

    // Xuất snapshots của ứng viên tối ưu nhất ra file JSON
    final bestInput = ShotInput(
      cueBallPosition: cuePosM,
      objectBall1Position: obj1PosM,
      objectBall2Position: obj2PosM,
      aimDirection: ghostAim.aimDirection,
      cueSpeed: 2.85,
      tipOffsetRatio: Vec2(0.0, -14.5 / (config.ballRadius * 1000.0)),
      cueElevationRadians: 0.0,
      maxTipOffsetRatio: config.maxTipOffsetRatio,
    );
    final bestSim = engine.simulate(bestInput);
    final snapList = bestSim.snapshots.map((s) => {
      't': s.timestamp,
      'b1': {'x': s.cueBall.position.x, 'y': s.cueBall.position.y},
      'b2': {'x': s.objectBall1.position.x, 'y': s.objectBall1.position.y},
      'b3': {'x': s.objectBall2.position.x, 'y': s.objectBall2.position.y},
    }).toList();

    final snapsFile = File('${outDir.path}/snapshots_best_candidate.json');
    snapsFile.writeAsStringSync(jsonEncode(snapList));
    print('Đã lưu ${snapList.length} snapshots ra: ${snapsFile.path}');
  });
}

Map<String, dynamic> _runSingleSimulation({
  required CaromPhysicsEngine engine,
  required TableConfig config,
  required Vec2 cuePosM,
  required Vec2 obj1PosM,
  required Vec2 obj2PosM,
  required Vec2 aimDir,
  required double fraction,
  required double zMm,
  required double vCue,
}) {
  final zRatio = zMm / (config.ballRadius * 1000.0);
  final tipOffsetRatio = Vec2(0.0, zRatio);

  final shotInput = ShotInput(
    cueBallPosition: cuePosM,
    objectBall1Position: obj1PosM,
    objectBall2Position: obj2PosM,
    aimDirection: aimDir,
    cueSpeed: vCue,
    tipOffsetRatio: tipOffsetRatio,
    cueElevationRadians: 0.0,
    maxTipOffsetRatio: config.maxTipOffsetRatio,
  );

  final result = engine.simulate(shotInput);

  bool hitsCueToObj1 = false;
  bool hitsCueToObj2 = false;
  bool cueHitsCushionBeforeCarom = false;
  bool ball2HitsTopCushion = false;
  final collisionChain = <String>[];

  double? vCuePre1;
  double? actualFractionObj1;

  for (final ev in result.collisionEvents) {
    if (ev.type == CollisionType.ballBall) {
      final pair = '${ev.primaryBall.name}-${ev.secondaryBall?.name}';
      collisionChain.add(pair);

      if ((ev.primaryBall == BallId.cue && ev.secondaryBall == BallId.object1) ||
          (ev.primaryBall == BallId.object1 && ev.secondaryBall == BallId.cue)) {
        if (!hitsCueToObj1) {
          hitsCueToObj1 = true;
          actualFractionObj1 = ev.effectiveContactFraction;
          vCuePre1 = ev.primaryBallVelocityBefore?.length;
        }
      } else if ((ev.primaryBall == BallId.cue && ev.secondaryBall == BallId.object2) ||
          (ev.primaryBall == BallId.object2 && ev.secondaryBall == BallId.cue)) {
        if (hitsCueToObj1 && !hitsCueToObj2) {
          hitsCueToObj2 = true;
        }
      }
    } else if (ev.type == CollisionType.ballCushion) {
      final seg = '${ev.primaryBall.name}-${ev.cushion?.name}';
      collisionChain.add(seg);
      if (ev.primaryBall == BallId.cue && !hitsCueToObj2) {
        cueHitsCushionBeforeCarom = true;
      }
      if (ev.primaryBall == BallId.object1 && ev.cushion == CushionId.shortNear) {
        ball2HitsTopCushion = true;
      }
    }
  }

  double ball2PathLength = 0.0;
  for (int i = 1; i < result.snapshots.length; i++) {
    final prev = result.snapshots[i - 1].objectBall1.position;
    final curr = result.snapshots[i].objectBall1.position;
    ball2PathLength += (curr - prev).length;
  }

  double minDistCueToObj2 = double.infinity;
  bool afterObj1Hit = false;
  for (final snap in result.snapshots) {
    if (!afterObj1Hit) {
      if ((snap.cueBall.position - snap.objectBall1.position).length <=
          2 * config.ballRadius + 0.005) {
        afterObj1Hit = true;
      }
    }
    if (afterObj1Hit) {
      final d = (snap.cueBall.position - snap.objectBall2.position).length;
      if (d < minDistCueToObj2) {
        minDistCueToObj2 = d;
      }
    }
  }

  final finalSnap = result.finalSnapshot;
  final finalPosCue = finalSnap.cueBall.position;
  final finalPosObj1 = finalSnap.objectBall1.position;
  final finalPosObj2 = finalSnap.objectBall2.position;

  final critA = hitsCueToObj1;
  final critB = hitsCueToObj2 || minDistCueToObj2 <= 2 * config.ballRadius + 0.001;
  final critC = ball2HitsTopCushion;
  final s2Ratio = ball2PathLength / config.lengthMeters;
  final critD = s2Ratio >= 1.4 && s2Ratio <= 2.2;
  // Bi 1 trô lùi xuống và sang phải về phía Bi 3 (vùng x > obj1.x, y > obj1.y) và không chạm băng trước carom
  final cueDisplacementAfter = finalPosCue - obj1PosM;
  final critE = cueDisplacementAfter.x > 0.05 && cueDisplacementAfter.y > 0.05 && !cueHitsCushionBeforeCarom;

  return {
    'zMm': zMm,
    'zRatio': zRatio,
    'vCue': vCue,
    'terminationReason': result.terminationReason.name,
    'durationSeconds': result.durationSeconds,
    'actualFraction': actualFractionObj1 ?? fraction,
    'hitsCueToObj1': hitsCueToObj1,
    'hitsCueToObj2': hitsCueToObj2,
    'cueHitsCushionBeforeCarom': cueHitsCushionBeforeCarom,
    'ball2HitsTopCushion': ball2HitsTopCushion,
    'minDistCueToObj2': minDistCueToObj2,
    'ball2PathLength': ball2PathLength,
    'ball2PathLengthOverL': s2Ratio,
    'vCuePre1': vCuePre1,
    'finalCue': [finalPosCue.x, finalPosCue.y],
    'finalObj1': [finalPosObj1.x, finalPosObj1.y],
    'finalObj2': [finalPosObj2.x, finalPosObj2.y],
    'collisionChain': collisionChain,
    'criteriaA': critA,
    'criteriaB': critB,
    'criteriaC': critC,
    'criteriaD': critD,
    'criteriaE': critE,
    'allPassed': critA && critB && critC && critD && critE,
  };
}
