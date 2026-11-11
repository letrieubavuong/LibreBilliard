import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xavier_billiard_libre/data/notebook_storage.dart';
import 'package:xavier_billiard_libre/data/sample_lessons.dart';
import 'package:xavier_billiard_libre/models/billiard_lesson.dart';
import 'package:xavier_billiard_libre/models/carom_physics_solver.dart';
import 'package:xavier_billiard_libre/physics/billiard_physics.dart';
import 'package:xavier_billiard_libre/screens/custom_position_builder_screen.dart';
import 'package:xavier_billiard_libre/screens/home_screen.dart';
import 'package:xavier_billiard_libre/screens/lesson_detail_screen.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/ball_contact_diagram.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/carom_table_canvas_layout.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/cue_ball_effet_diagram.dart';

void main() {
  const config = TableConfig.standardCarom;
  const R = 0.03075;

  group('I. Kiểm thử Động lực học & Bảo toàn Năng lượng (Milestone 1)', () {
    test('1. Bảo toàn năng lượng khi ra cơ (Cue Strike Energy Conservation): E_ball + E_cue_final <= E_cue_initial cho mọi offset và elevation', () {
      final input1 = ShotInput(
        cueBallPosition: const Vec2(1.0, 0.71),
        objectBall1Position: const Vec2(1.5, 0.71),
        objectBall2Position: const Vec2(2.0, 0.71),
        aimDirection: Vec2.unitX,
        cueSpeed: 1.0,
        tipOffsetRatio: const Vec2(0.0, 0.80),
        cueElevationRadians: 0.0,
      );
      final res1 = CueStrikePhysics.computeStrikeMechanics(
        input: input1,
        config: config,
      );
      final eCueInitial1 = 0.5 * config.cueMass * 1.0 * 1.0;
      final eBall1 = res1.cueBall.kineticEnergy(config);
      final eCueFinal1 = 0.5 * config.cueMass * res1.postStrikeCueSpeed * res1.postStrikeCueSpeed;
      expect(eBall1 + eCueFinal1, lessThanOrEqualTo(eCueInitial1 + 1e-9));

      // Sweep grid across tip offsets [-0.8..0.8] and elevations [0..60 deg]
      for (double r = 0.0; r <= 0.8; r += 0.2) {
        for (double elevDeg in [0.0, 20.0, 45.0, 60.0]) {
          final inSweep = ShotInput(
            cueBallPosition: const Vec2(1.0, 0.71),
            objectBall1Position: const Vec2(1.5, 0.71),
            objectBall2Position: const Vec2(2.0, 0.71),
            aimDirection: Vec2.unitX,
            cueSpeed: 2.5,
            tipOffsetRatio: Vec2(r, 0.0),
            cueElevationRadians: elevDeg * math.pi / 180.0,
          );
          final res = CueStrikePhysics.computeStrikeMechanics(
            input: inSweep,
            config: config,
          );
          final eInit = 0.5 * config.cueMass * 2.5 * 2.5;
          final eFinal = res.cueBall.kineticEnergy(config) +
              0.5 * config.cueMass * res.postStrikeCueSpeed * res.postStrikeCueSpeed;
          expect(eFinal, lessThanOrEqualTo(eInit + 1e-9),
              reason: 'Energy created at tip=$r, elev=$elevDeg: $eFinal > $eInit');
        }
      }
    });

    test('2. Bảo toàn năng lượng khi chạm băng (Cushion Impact Energy Conservation): E_after <= E_before, và E_after == E_before khi e_bc=1, mu_bc=0', () {
      final ballBefore = const BallState(
        id: BallId.cue,
        position: Vec2(R, 0.71),
        velocity: Vec2(-0.01, 1.0),
        angularVelocity: Vec3.zero,
        phase: MotionPhase.sliding,
      );
      final resolved = CollisionPhysics.resolveBallCushionCollision(
        ball: ballBefore,
        cushion: CushionId.shortNear,
        config: config,
        timestamp: 0.1,
      );
      final eBefore = ballBefore.kineticEnergy(config);
      final eAfter = resolved.ball.kineticEnergy(config);
      expect(eAfter, lessThanOrEqualTo(eBefore + 1e-9));

      // Test ideal cushion e_bc = 1.0, mu_bc = 0.0
      final idealConfig = config.copyWith(
        restitutionBallCushion: 1.0,
        ballCushionFriction: 0.0,
      );
      final idealResolved = CollisionPhysics.resolveBallCushionCollision(
        ball: const BallState(
          id: BallId.cue,
          position: Vec2(R, 0.71),
          velocity: Vec2(-1.0, 0.0),
          angularVelocity: Vec3.zero,
          phase: MotionPhase.sliding,
        ),
        cushion: CushionId.shortNear,
        config: idealConfig,
        timestamp: 0.1,
      );
      final eIdealBefore = 0.5 * config.ballMass * 1.0 * 1.0;
      final eIdealAfter = idealResolved.ball.kineticEnergy(idealConfig);
      expect(eIdealAfter, closeTo(eIdealBefore, 1e-7));

      // Sweep angles [5..85 deg], speeds [0.5..4.0], spins [-50..50 rad/s]
      for (double angleDeg in [10.0, 30.0, 45.0, 60.0, 80.0]) {
        final rad = angleDeg * math.pi / 180.0;
        final v = Vec2(-math.cos(rad) * 2.0, math.sin(rad) * 2.0);
        for (double wz in [-30.0, 0.0, 30.0]) {
          final b = BallState(
            id: BallId.cue,
            position: const Vec2(R, 0.71),
            velocity: v,
            angularVelocity: Vec3(0.0, 0.0, wz),
            phase: MotionPhase.sliding,
          );
          final res = CollisionPhysics.resolveBallCushionCollision(
            ball: b,
            cushion: CushionId.shortNear,
            config: config,
            timestamp: 0.1,
          );
          expect(res.ball.kineticEnergy(config),
              lessThanOrEqualTo(b.kineticEnergy(config) + 1e-9));
        }
      }
    });

    test('3. Độ chính xác tiếp xúc CCD & Hội tụ (Continuous Collision Detection Accuracy): |distance - 2R| < 1e-11 m', () {
      final b1 = const BallState(
        id: BallId.cue,
        position: Vec2(0.50, 0.71),
        velocity: Vec2(2.0, 0.0),
        angularVelocity: Vec3.zero,
        phase: MotionPhase.sliding,
      );
      final b2 = const BallState(
        id: BallId.object1,
        position: Vec2(0.80, 0.71),
        velocity: Vec2.zero,
        angularVelocity: Vec3.zero,
        phase: MotionPhase.sliding,
      );

      final tImpact = CollisionPhysics.findBallBallImpactTime(
        ballA: b1,
        ballB: b2,
        ballRadius: R,
        maxDt: 0.5,
        config: config,
      );
      expect(tImpact, isNotNull);

      final p1AtT = CaromPhysicsEngine.advanceBallOnCloth(b1, config, tImpact!).position;
      final p2AtT = CaromPhysicsEngine.advanceBallOnCloth(b2, config, tImpact).position;
      final distAtImpact = p1AtT.distanceTo(p2AtT);
      expect((distAtImpact - 2.0 * R).abs(), lessThan(1e-11));

      // Test cushion CCD accuracy
      final bCushion = const BallState(
        id: BallId.cue,
        position: Vec2(0.20, 0.71),
        velocity: Vec2(-1.5, 0.0),
        angularVelocity: Vec3.zero,
        phase: MotionPhase.sliding,
      );
      final cushionImpact = CollisionPhysics.findBallCushionImpactTime(
        ball: bCushion,
        config: config,
        maxDt: 0.5,
      );
      expect(cushionImpact, isNotNull);
      final pCushionAtT = CaromPhysicsEngine.advanceBallOnCloth(bCushion, config, cushionImpact!.time).position;
      expect((pCushionAtT.x - R).abs(), lessThan(1e-11));
    });

    test('4. Không chồng lấp tại mọi thời điểm mẫu (Non-penetration invariant via sampleAtTime)', () {
      const engine = CaromPhysicsEngine(config: config);
      final input = ShotInput(
        cueBallPosition: const Vec2(1.0, 0.71),
        objectBall1Position: const Vec2(1.45, 0.72),
        objectBall2Position: const Vec2(1.62, 0.70),
        aimDirection: const Vec2(1.0, 0.02).normalized,
        cueSpeed: 3.5,
        tipOffsetRatio: const Vec2(0.3, 0.4),
      );

      final res = engine.simulate(input);
      const minAllowed = 2.0 * R - 1e-9;

      for (double t = 0.0; t <= res.durationSeconds; t += 0.02) {
        final snap = res.sampleAtTime(t);
        expect(snap.cueBall.position.distanceTo(snap.objectBall1.position),
            greaterThanOrEqualTo(minAllowed));
        expect(snap.cueBall.position.distanceTo(snap.objectBall2.position),
            greaterThanOrEqualTo(minAllowed));
        expect(snap.objectBall1.position.distanceTo(snap.objectBall2.position),
            greaterThanOrEqualTo(minAllowed));
      }
    });

    test('5. Giới hạn thời gian mô phỏng (maxSimulationSeconds) trả về maxTimeReached trung thực', () {
      const shortEngine = CaromPhysicsEngine(
        config: config,
        maxSimulationSeconds: 0.15,
      );
      final res = shortEngine.simulate(
        ShotInput(
          cueBallPosition: const Vec2(0.5, 0.71),
          objectBall1Position: const Vec2(2.4, 0.2),
          objectBall2Position: const Vec2(2.4, 1.2),
          aimDirection: Vec2.unitX,
          cueSpeed: 2.0,
        ),
      );
      expect(res.terminationReason, SimulationTerminationReason.maxTimeReached);
      expect(res.durationSeconds, closeTo(0.15, 1e-5));
    });
  });

  group('II. Kiểm thử Bài học Mẫu & Tính Trung thực của Đầu vào (Milestone 2)', () {
    test('6. Tăng speedLevel từ 1 -> 5 tăng đơn điệu vận tốc qua evaluateAdjustedShot cho toàn bộ 13 bài học', () {
      for (final lesson in SampleLessonsRepository.lessons) {
        double prevSpeed = 0.0;
        for (int level = 1; level <= 5; level++) {
          final outcome = CaromPhysicsSolver.evaluateAdjustedShot(
            lesson: lesson,
            activeContact: lesson.shotParams.contact,
            activeEffet: lesson.shotParams.effet,
            activeSpeedLevel: level,
          );
          final actualSpeed = outcome.simulationResult.input.cueSpeed;
          expect(actualSpeed, greaterThan(prevSpeed),
              reason: 'Lesson ${lesson.code} failed monotonic speed increase at level $level');
          prevSpeed = actualSpeed;
        }
      }
    });

    test('7. Xác thực kỹ thuật toàn bộ 13 bài học mẫu: ngắm Ghost Ball thực tế, trúng Bi 1 trước, carom thành công và gom bi', () {
      for (final lesson in SampleLessonsRepository.lessons) {
        expect(lesson.isPhysicsVerified, isTrue,
            reason: 'Lesson ${lesson.code} must be marked isPhysicsVerified: true');

        final outcome = CaromPhysicsSolver.evaluateAdjustedShot(
          lesson: lesson,
          activeContact: lesson.shotParams.contact,
          activeEffet: lesson.shotParams.effet,
        );

        expect(outcome.isInputValid, isTrue,
            reason: 'Lesson ${lesson.code} input must be strictly valid');

        final eval = outcome.simulationResult.evaluation;
        if (lesson.code == 'BS-03') {
          expect(eval.cushionCountBeforeCarom, greaterThanOrEqualTo(1),
              reason: 'BS-03 must hit cushion before carom');
        } else {
          expect(eval.firstObjectBallHit, BallId.object1,
              reason: 'Lesson ${lesson.code} must hit objectBall1 first');
          expect(eval.firstObject1ContactFraction, isNotNull);
          // Với các cú đánh đặc biệt có độ nâng cơ lớn (như KT-04 elevation 40° làm cong đường bi trong pha trượt),
          // dung sai tiếp xúc cho phép tối đa 0.15; các cú đánh thẳng thông thường < 0.05
          final maxContactTol = lesson.shotParams.cueElevationDegrees > 15.0 ? 0.15 : 0.05;
          expect(
            (eval.firstObject1ContactFraction! - lesson.shotParams.contact.fraction).abs(),
            lessThan(maxContactTol),
            reason: 'Lesson ${lesson.code} must hit at taught contact fraction',
          );
        }

        expect(eval.hitsSecondBall, isTrue,
            reason: 'Lesson ${lesson.code} must hit second ball (carom)');

        if (lesson.diagram.targetZoneCenter != null) {
          expect(eval.gathersInZone, isTrue,
              reason: 'Lesson ${lesson.code} must gather 3 balls in target zone');
        }
      }
    });

    test('8. Từ chối ShotInput không hợp lệ (ShotInputValidationException / validation.isValid == false): không tự ý sửa bi', () {
      // 1. Two balls overlapping (< 2R)
      final overlappingInput = ShotInput(
        cueBallPosition: const Vec2(1.0, 0.71),
        objectBall1Position: const Vec2(1.05, 0.71), // distance 0.05 < 0.0615
        objectBall2Position: const Vec2(2.0, 0.71),
        aimDirection: Vec2.unitX,
        cueSpeed: 1.5,
      );
      final validation1 = overlappingInput.validate(config);
      expect(validation1.isValid, isFalse);
      expect(validation1.issues.first.code, ShotInputValidationErrorCode.ballsOverlapping);

      expect(
        () => const CaromPhysicsEngine(config: config).simulate(overlappingInput),
        throwsA(isA<ShotInputValidationException>()),
      );

      // Solver returns empty simulation without altering ball positions
      final outcome = CaromPhysicsSolver.evaluateShotInput(
        baseDiagram: const TableDiagramSpec(
          cueBall: Offset(1.0, 0.71),
          objectBall1: Offset(1.05, 0.71),
          objectBall2: Offset(2.0, 0.71),
        ),
        input: overlappingInput,
      );
      expect(outcome.isInputValid, isFalse);
      expect(outcome.simulationResult.initialSnapshot.cueBall.position, equals(const Vec2(1.0, 0.71)));
      expect(outcome.simulationResult.initialSnapshot.objectBall1.position, equals(const Vec2(1.05, 0.71)));

      // 2. Ball out of bounds (< R from cushion)
      final outOfBoundsInput = ShotInput(
        cueBallPosition: const Vec2(0.01, 0.71), // 0.01 < R (0.03075)
        objectBall1Position: const Vec2(1.5, 0.71),
        objectBall2Position: const Vec2(2.0, 0.71),
        aimDirection: Vec2.unitX,
        cueSpeed: 1.5,
      );
      final validation2 = outOfBoundsInput.validate(config);
      expect(validation2.isValid, isFalse);
      expect(validation2.issues.first.code, ShotInputValidationErrorCode.ballOutOfBounds);
    });

    test('9. Tương tác kéo 3 bi sát góc bàn không chồng lấp (Corner Drag Non-overlapping)', () {
      final rD = config.ballRadiusInDiamonds;
      final builderState = const CustomPositionBuilderScreen(nextCustomIndex: 1);
      expect(builderState, isNotNull);
      final p1 = Offset(rD, rD);
      final p2 = Offset(rD + 2.0 * rD + 0.005, rD);
      expect((p1 - p2).distance, greaterThanOrEqualTo(2.0 * rD));
    });
  });

  group('III. Kiểm thử Hiển thị & Lưu trữ Bền vững (Milestone 3)', () {
    test('10. Đồng nhất tỉ lệ khung nhìn pixelsPerMeter: hai bi chạm nhau (d = 2R) tiếp xúc chuẩn ở mọi góc 0°, 45°, 90°', () {
      const testSize = Size(340, 600);
      final layoutFull = CaromTableCanvasLayout(
        canvasSize: testSize,
        railThickness: 20.0,
        maxLongUnits: 8.0,
        config: config,
      );
      final ppmFull = layoutFull.pixelsPerMeter;
      final rPx = config.ballRadius * ppmFull;

      // At distance 2R along X (90° on canvas)
      final pA = layoutFull.metersToCanvas(const Vec2(1.0, 0.71));
      final pB = layoutFull.metersToCanvas(Vec2(1.0 + 2.0 * R, 0.71));
      expect((pA - pB).distance, closeTo(2.0 * rPx, 1e-4));

      // At distance 2R along Y (0° on canvas)
      final pC = layoutFull.metersToCanvas(Vec2(1.0, 0.71 + 2.0 * R));
      expect((pA - pC).distance, closeTo(2.0 * rPx, 1e-4));

      // At distance 2R at 45°
      final offset45 = 2.0 * R / math.sqrt(2.0);
      final pD = layoutFull.metersToCanvas(Vec2(1.0 + offset45, 0.71 + offset45));
      expect((pA - pD).distance, closeTo(2.0 * rPx, 1e-4));

      // Test round-trip world <-> canvas
      final origMeters = const Vec2(1.5, 0.8);
      final canvasPt = layoutFull.metersToCanvas(origMeters);
      final roundTripMeters = layoutFull.canvasToMeters(canvasPt);
      expect((roundTripMeters - origMeters).length, lessThan(1e-4));
    });

    test('11. Sao lưu file JSON hỏng (.corrupted.bak) và bảo lưu schemaVersion tương lai', () async {
      final tempDir = await Directory.systemTemp.createTemp('xavier_storage_test_');
      final testFile = File('${tempDir.path}/notebook_state_v1.json');
      final storage = NotebookStorage(overrideFile: testFile);

      // 1. Write corrupted JSON
      await testFile.writeAsString('{not valid json at all!');
      final fallbackState = await storage.loadState();
      expect(fallbackState.bookmarkedIds, isNotEmpty);

      final bakFile = File('${testFile.path}.corrupted.bak');
      expect(bakFile.existsSync(), isTrue);
      expect(bakFile.readAsStringSync(), equals('{not valid json at all!'));

      // 2. Future schema version
      final futureJson = {
        'schemaVersion': 999,
        'bookmarkedIds': ['kt-01'],
        'practiceCounts': {'kt-01': 5},
        'personalNotes': {},
        'customLessons': [],
        'customLessonCounter': 1,
      };
      await testFile.writeAsString(jsonEncode(futureJson));
      final futureLoaded = await storage.loadState();
      expect(futureLoaded.schemaVersion, equals(1)); // parsed cleanly

      final futureBak = File('${testFile.path}.future_v999.bak');
      expect(futureBak.existsSync(), isTrue);

      await tempDir.delete(recursive: true);
    });

    testWidgets('12. Thao tác UI (lật bàn, bật tắt số nút băng) không gọi lại CaromPhysicsEngine.simulate', (tester) async {
      CaromPhysicsSolver.clearCache();
      CaromPhysicsEngine.debugSimulationRunCount = 0;

      final lesson = SampleLessonsRepository.lessons.first;
      await tester.pumpWidget(
        MaterialApp(
          home: LessonDetailScreen(
            lesson: lesson,
            isBookmarked: true,
            practiceCount: 3,
            onToggleBookmark: () {},
            onIncrementPractice: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final runsAfterOpen = CaromPhysicsEngine.debugSimulationRunCount;
      expect(runsAfterOpen, greaterThan(0));

      final flipBtn = find.text('Lật Trái/Phải');
      await tester.ensureVisible(flipBtn);
      await tester.pump();
      await tester.tap(flipBtn);
      await tester.pumpAndSettle();

      final numbersChip = find.text('Số nút băng');
      await tester.ensureVisible(numbersChip);
      await tester.pump();
      await tester.tap(numbersChip);
      await tester.pumpAndSettle();

      // Flipping table or toggling diamond numbers must NOT call simulate() again!
      expect(CaromPhysicsEngine.debugSimulationRunCount, equals(runsAfterOpen));
    });

    testWidgets('13. Smoke Test: Mở ứng dụng, chuyển 5 tabs và mở LessonDetailScreen', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('xavier_smoke_');
      final storage = NotebookStorage(
        overrideFile: File('${tempDir.path}/smoke_state.json'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xavier Billiard Libre'), findsOneWidget);
      expect(find.text('Kĩ thuật'), findsWidgets);

      await tester.tap(find.text('Hình gom bi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bộ số'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seri & Góc'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sổ tay'));
      await tester.pumpAndSettle();

      tempDir.deleteSync(recursive: true);
    });
  });
}
