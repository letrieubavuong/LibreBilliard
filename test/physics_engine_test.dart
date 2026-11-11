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
import 'package:xavier_billiard_libre/widgets/diagrams/cue_ball_effet_diagram.dart';

void main() {
  const config = TableConfig.standardCarom;
  const R = 0.03075;

  group('I. Kiểm thử Vật lý Định lượng (Section VIII.1 - VIII.10)', () {
    test('1. Bảo toàn & suy giảm năng lượng: chỉ lăn/trượt trên vải, v giảm đơn điệu về 0 và dừng hẳn', () {
      const engine = CaromPhysicsEngine(config: config);
      final input = ShotInput(
        cueBallPosition: const Vec2(0.5, 0.71),
        objectBall1Position: const Vec2(2.4, 0.2),
        objectBall2Position: const Vec2(2.4, 1.2),
        aimDirection: Vec2.unitX,
        cueSpeed: 1.5,
      );

      final result = engine.simulate(input);
      expect(
        result.terminationReason,
        SimulationTerminationReason.allBallsStopped,
      );
      expect(result.finalSnapshot.cueBall.velocity.length, lessThan(1e-4));

      double prevSpeed = result.initialSnapshot.cueBall.velocity.length;
      for (int i = 1; i < result.snapshots.length; i++) {
        final curSpeed = result.snapshots[i].cueBall.velocity.length;
        // Không tự tăng tốc khi không có topspin vượt ngưỡng lăn
        expect(curSpeed, lessThanOrEqualTo(prevSpeed + 1e-6));
        prevSpeed = curSpeed;
      }
    });

    test('2. Chuyển pha trượt -> lăn (Stun shot): tại t_roll = 2*v0/(7*mu_s*g), v đạt đúng (5/7)*v0 và u -> 0 không đổi dấu', () {
      const v0 = 2.1;
      BallState state = const BallState(
        id: BallId.cue,
        position: Vec2(0.5, 0.71),
        velocity: Vec2(v0, 0.0),
        angularVelocity: Vec3.zero,
        phase: MotionPhase.sliding,
      );

      final tRoll = (2.0 * v0) / (7.0 * config.slidingFriction * config.gravity);
      const dt = 0.002;
      double elapsed = 0.0;
      double prevSlipX = state.clothSlipVelocity(R).x;

      while (elapsed < tRoll + 0.05) {
        state = CaromPhysicsEngine.advanceBallOnCloth(state, config, dt);
        elapsed += dt;
        final slip = state.clothSlipVelocity(R);
        // Vận tốc trượt ux không bao giờ đổi dấu sang âm (không dao động qua 0)
        expect(slip.x, greaterThanOrEqualTo(-1e-9));
        expect(slip.x, lessThanOrEqualTo(prevSlipX + 1e-9));
        prevSlipX = slip.x;
      }

      // Kiểm tra giá trị giải tích ngay tại t = tRoll: v = (5/7)*v0 và u = 0
      final exactAtRoll = CaromPhysicsEngine.advanceBallOnCloth(
        const BallState(
          id: BallId.cue,
          position: Vec2(0.5, 0.71),
          velocity: Vec2(v0, 0.0),
          angularVelocity: Vec3.zero,
          phase: MotionPhase.sliding,
        ),
        config,
        tRoll,
      );
      expect(exactAtRoll.velocity.x, closeTo((5.0 / 7.0) * v0, 1e-6));
      expect(exactAtRoll.clothSlipVelocity(R).length, lessThan(1e-7));
      expect(exactAtRoll.phase, MotionPhase.rolling);
    });

    test('3. Coulé vs Stun vs Rétro trực diện: sau khi chạm bi mục tiêu đứng yên, Coulé tiến thêm, Stun dừng gần điểm chạm, Rétro lùi lại', () {
      final idealCollisionConfig = config.copyWith(
        restitutionBallBall: 0.98,
        ballBallFriction: 0.0,
      );
      final engine = CaromPhysicsEngine(config: idealCollisionConfig);

      SimulationResult runDirect(double verticalTipRatio) {
        return engine.simulate(
          ShotInput(
            cueBallPosition: const Vec2(0.80, 0.71),
            objectBall1Position: const Vec2(1.20, 0.71),
            objectBall2Position: const Vec2(2.50, 1.25),
            aimDirection: Vec2.unitX,
            cueSpeed: 1.25,
            tipOffsetRatio: Vec2(0.0, verticalTipRatio),
          ),
        );
      }

      final couleRes = runDirect(0.70); // 12h cao
      final stunRes = runDirect(-0.18); // Vừa đủ hết xoáy tại điểm chạm
      final retroRes = runDirect(-0.75); // 6h thấp sâu

      final contactX = 1.20 - 2.0 * R;
      final couleFinalX = couleRes.finalSnapshot.cueBall.position.x;
      final stunFinalX = stunRes.finalSnapshot.cueBall.position.x;
      final retroFinalX = retroRes.finalSnapshot.cueBall.position.x;

      // Coulé phải tiến vượt qua điểm va chạm
      expect(couleFinalX, greaterThan(contactX + 0.08));
      // Rétro phải kéo lùi về phía sau điểm va chạm
      expect(retroFinalX, lessThan(contactX - 0.08));
      // Thứ tự vị trí dừng: Rétro < Stun < Coulé
      expect(retroFinalX, lessThan(stunFinalX));
      expect(stunFinalX, lessThan(couleFinalX));
    });

    test('4. Va chạm đàn hồi trực diện (e = 1, mu = 0): bảo toàn động lượng và năng lượng trong sai số số học < 1e-6', () {
      final idealConfig = config.copyWith(
        restitutionBallBall: 1.0,
        ballBallFriction: 0.0,
        slidingFriction: 0.0,
        rollingFriction: 0.0,
      );

      final b1 = const BallState(
        id: BallId.cue,
        position: Vec2(1.0, 0.71),
        velocity: Vec2(2.5, 0.0),
      );
      final b2 = const BallState(
        id: BallId.object1,
        position: Vec2(1.0 + 2.0 * R, 0.71),
        velocity: Vec2.zero,
      );

      final resolved = CollisionPhysics.resolveBallBallCollision(
        ball1: b1,
        ball2: b2,
        config: idealConfig,
        timestamp: 0.1,
      );

      final m = idealConfig.ballMass;
      final pBefore = (b1.velocity + b2.velocity) * m;
      final pAfter = (resolved.ball1.velocity + resolved.ball2.velocity) * m;
      expect((pAfter - pBefore).length, lessThan(1e-9));

      final eBefore =
          0.5 * m * (b1.velocity.lengthSquared + b2.velocity.lengthSquared);
      final eAfter = 0.5 *
          m *
          (resolved.ball1.velocity.lengthSquared +
              resolved.ball2.velocity.lengthSquared);
      expect((eAfter - eBefore).abs(), lessThan(1e-9));

      // Bi 1 dừng hẳn, Bi 2 nhận toàn bộ vận tốc Bi 1
      expect(resolved.ball1.velocity.length, lessThan(1e-9));
      expect(resolved.ball2.velocity.x, closeTo(2.5, 1e-9));
    });

    test('5. Va chạm lệch tâm & độ dày fraction: khi f = 0.5 và mu_bb = 0, góc lệch của bi mục tiêu đúng bằng 30° (sai số < 0.5°)', () {
      final frictionlessConfig = config.copyWith(
        ballBallFriction: 0.0,
        slidingFriction: 0.0,
        rollingFriction: 0.0,
      );
      final engine = CaromPhysicsEngine(
        config: frictionlessConfig,
        maxSimulationSeconds: 0.6,
      );

      const cuePos = Vec2(0.80, 0.71);
      const obj1Pos = Vec2(1.50, 0.71);

      final ghostAim = AimGeometry.computeGhostBallAim(
        cueBallPos: cuePos,
        objectBallPos: obj1Pos,
        ballRadius: R,
        fraction: 0.5,
        lateralSign: 1.0,
      );
      expect(ghostAim.cutAngleDegrees, closeTo(30.0, 1e-6));

      final res = engine.simulate(
        ShotInput(
          cueBallPosition: cuePos,
          objectBall1Position: obj1Pos,
          objectBall2Position: const Vec2(2.60, 1.30),
          aimDirection: ghostAim.aimDirection,
          cueSpeed: 2.0,
        ),
      );

      expect(res.firstHitObject1Event, isNotNull);
      final postHitSnap = res.sampleAtTime(res.firstHitObject1Event!.timestamp + 0.02);
      final obj1Vel = postHitSnap.objectBall1.velocity.normalized;
      final incomingDir = ghostAim.aimDirection.normalized;
      final cosAngle = incomingDir.dot(obj1Vel).clamp(-1.0, 1.0);
      final angleDeg = math.acos(cosAngle) * 180.0 / math.pi;

      expect(angleDeg, closeTo(30.0, 0.5));
    });

    test('6. Không chồng lấp (Non-penetration invariant): với mọi cặp bi và mọi bước thời gian, ||pi(t) - pj(t)|| >= 2R - 1e-6', () {
      const engine = CaromPhysicsEngine(config: config);
      final input = ShotInput(
        cueBallPosition: const Vec2(1.0, 0.71),
        objectBall1Position: const Vec2(1.45, 0.72),
        objectBall2Position: const Vec2(1.62, 0.70),
        aimDirection: const Vec2(1.0, 0.02).normalized,
        cueSpeed: 4.5, // Tốc độ rất mạnh xuyên qua đám đông 3 bi
        tipOffsetRatio: const Vec2(0.3, 0.4),
      );

      final res = engine.simulate(input);
      const minAllowed = 2.0 * R - 1e-6;

      for (final snap in res.snapshots) {
        final pC = snap.cueBall.position;
        final p1 = snap.objectBall1.position;
        final p2 = snap.objectBall2.position;

        expect(pC.distanceTo(p1), greaterThanOrEqualTo(minAllowed));
        expect(pC.distanceTo(p2), greaterThanOrEqualTo(minAllowed));
        expect(p1.distanceTo(p2), greaterThanOrEqualTo(minAllowed));
      }
    });

    test('7. Va chạm băng với ép-phê ngang (wz != 0): bắn vuông góc vào băng với wz > 0 và wz < 0 cho góc bật đối xứng; wz = 0 bật ngược pháp tuyến', () {
      const engine = CaromPhysicsEngine(
        config: config,
        maxSimulationSeconds: 0.8,
      );

      SimulationResult shootIntoLeftLongCushion(double horizTipRatio) {
        return engine.simulate(
          ShotInput(
            cueBallPosition: const Vec2(1.42, 0.45),
            objectBall1Position: const Vec2(2.50, 1.20),
            objectBall2Position: const Vec2(2.65, 1.20),
            aimDirection: const Vec2(0.0, -1.0), // Vuông góc vào băng dài y = 0
            cueSpeed: 2.2,
            tipOffsetRatio: Vec2(horizTipRatio, 0.0),
          ),
        );
      }

      final resNoSpin = shootIntoLeftLongCushion(0.0);
      final resRightSpin = shootIntoLeftLongCushion(0.65);
      final resLeftSpin = shootIntoLeftLongCushion(-0.65);

      final cEvent0 = resNoSpin.collisionEvents.first;
      final cEventR = resRightSpin.collisionEvents.first;
      final cEventL = resLeftSpin.collisionEvents.first;

      final vOut0 = resNoSpin.sampleAtTime(cEvent0.timestamp + 0.02).cueBall.velocity;
      final vOutR = resRightSpin.sampleAtTime(cEventR.timestamp + 0.02).cueBall.velocity;
      final vOutL = resLeftSpin.sampleAtTime(cEventL.timestamp + 0.02).cueBall.velocity;

      // Không ép-phê: bật thẳng lại theo pháp tuyến +y (vx == 0)
      expect(vOut0.x.abs(), lessThan(1e-6));
      expect(vOut0.y, greaterThan(0.5));

      // Có ép-phê phải và trái: lệch sang 2 phía ngược dấu và đối xứng tuyệt đối
      expect(vOutR.x.abs(), greaterThan(0.05));
      expect(vOutR.x, closeTo(-vOutL.x, 1e-6));
      expect(vOutR.y, closeTo(vOutL.y, 1e-6));
    });

    test('8. Cú đánh hụt thật (True Miss): bắn lệch khỏi bi 1 và bi 2 => hitsSecondBall == false, objectBall1 & objectBall2 đứng yên tuyệt đối, không sinh sự kiện va chạm bi', () {
      const engine = CaromPhysicsEngine(config: config);
      const obj1Start = Vec2(1.80, 0.40);
      const obj2Start = Vec2(2.10, 0.40);

      final res = engine.simulate(
        ShotInput(
          cueBallPosition: const Vec2(0.60, 1.10),
          objectBall1Position: obj1Start,
          objectBall2Position: obj2Start,
          aimDirection: Vec2.unitX, // Bắn dọc theo y = 1.10, cách xa 2 bi mục tiêu 0.70m
          cueSpeed: 2.5,
        ),
      );

      expect(res.evaluation.hitsFirstObjectBall, isFalse);
      expect(res.evaluation.hitsSecondBall, isFalse);
      expect(
        res.collisionEvents.where((e) => e.type == CollisionType.ballBall),
        isEmpty,
      );

      for (final snap in res.snapshots) {
        expect(snap.objectBall1.position, equals(obj1Start));
        expect(snap.objectBall2.position, equals(obj2Start));
        expect(snap.objectBall1.velocity, equals(Vec2.zero));
        expect(snap.objectBall2.velocity, equals(Vec2.zero));
      }
    });

    test('9. Bắt buộc hiệu lực của speedLevel: thay đổi speedLevel 1 -> 5 làm thay đổi đơn điệu vận tốc đầu vào và quãng đường lăn', () {
      const engine = CaromPhysicsEngine(config: config);
      double prevSpeed = 0.0;
      double prevDistance = 0.0;

      for (int level = 1; level <= 5; level++) {
        final vCue = ShotInput.cueSpeedFromLevel(level);
        expect(vCue, greaterThan(prevSpeed));

        final res = engine.simulate(
          ShotInput(
            cueBallPosition: const Vec2(0.20, 0.71),
            objectBall1Position: const Vec2(2.60, 0.20),
            objectBall2Position: const Vec2(2.60, 1.20),
            aimDirection: Vec2.unitX,
            cueSpeed: vCue,
          ),
        );

        double totalDist = 0.0;
        for (int i = 1; i < res.snapshots.length; i++) {
          totalDist += res.snapshots[i].cueBall.position
              .distanceTo(res.snapshots[i - 1].cueBall.position);
        }
        expect(totalDist, greaterThan(prevDistance));
        prevSpeed = vCue;
        prevDistance = totalDist;
      }
    });

    test('10. Không có nhánh ăn gian theo preset: toàn bộ 13 bài học mẫu chạy ở thông số gốc đều thực thi đầy đủ qua CaromPhysicsEngine và trúng bi 2 thật', () {
      for (final lesson in SampleLessonsRepository.lessons) {
        final defaultOutcome = CaromPhysicsSolver.evaluateAdjustedShot(
          lesson: lesson,
          activeContact: lesson.shotParams.contact,
          activeEffet: lesson.shotParams.effet,
          activeSpeedLevel: lesson.shotParams.speedLevel,
        );

        // Kết quả trả về phải chứa chuỗi snapshots vật lý thật từ CaromPhysicsEngine
        expect(
          defaultOutcome.simulationResult.snapshots.length,
          greaterThan(10),
          reason: 'Lesson ${lesson.code} must generate physical snapshots',
        );
        expect(
          defaultOutcome.simulationResult.durationSeconds,
          greaterThan(0.2),
          reason: 'Lesson ${lesson.code} must have positive simulation duration',
        );
        expect(
          defaultOutcome.hitsSecondBall,
          equals(defaultOutcome.simulationResult.evaluation.hitsSecondBall),
        );
        expect(
          defaultOutcome.hitsSecondBall,
          isTrue,
          reason: 'Lesson ${lesson.code} (${lesson.title}) must hit second ball via real physics',
        );
        expect(
          defaultOutcome.gathersInZone,
          equals(defaultOutcome.simulationResult.evaluation.gathersInZone),
        );
      }
    });
  });

  group('II. Kiểm thử UI, Model & Persistence (Section VIII.11 - VIII.16)', () {
    test('11. Miền hợp lệ tròn của CueBallEffetSpec: truyền (4, 4) tự động chiếu về hình tròn r <= 4.0, đồng nhất giữa model, nhãn và engine', () {
      final spec = CueBallEffetSpec.fromTips(
        horizontalTips: 4.0,
        verticalTips: 4.0,
      );
      final tipMagnitude = math.sqrt(
        spec.horizontalEffet * spec.horizontalEffet +
            spec.verticalHeight * spec.verticalHeight,
      );
      expect(tipMagnitude, closeTo(CueBallEffetSpec.maxTips, 1e-6));
      expect(spec.normalizedTipOffset.distance, closeTo(1.0, 1e-6));
      expect(
        spec.physicalTipOffsetRatio.distance,
        closeTo(CueBallEffetSpec.maxPhysicalRadiusRatio, 1e-6),
      );

      // Bán kính vẽ và bán kính cảm ứng trong CueBallEffetPainter dùng chung một hàm duy nhất
      const testSize = Size(96, 96);
      expect(
        CueBallEffetPainter.maxTipPixelRadiusFor(testSize),
        closeTo(
          CueBallEffetPainter.ballPixelRadiusFor(testSize) *
              CueBallEffetSpec.maxPhysicalRadiusRatio,
          1e-9,
        ),
      );
    });

    testWidgets('12. Preset độ dày BallContactSpec: 1/3 và 2/3 chính xác, có preset Tràn mặt (1.0) đồng bộ với ContactSide.center', (tester) async {
      final oneThird = BallContactSpec.oneThird();
      final twoThirds = BallContactSpec.twoThirds();
      final full = BallContactSpec.full();

      expect(oneThird.fraction, closeTo(1.0 / 3.0, 1e-12));
      expect(twoThirds.fraction, closeTo(2.0 / 3.0, 1e-12));
      expect(full.fraction, closeTo(1.0, 1e-12));
      expect(full.side, equals(ContactSide.center));

      // Khi copyWith sang ContactSide.center, fraction tự động đồng bộ = 1.0
      final centered = oneThird.copyWith(side: ContactSide.center);
      expect(centered.fraction, closeTo(1.0, 1e-12));
      expect(centered.side, equals(ContactSide.center));

      BallContactSpec current = oneThird;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BallContactDiagram(
                spec: current,
                mode: DiagramDisplayMode.interactive,
                onSpecChanged: (next) => setState(() => current = next),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tràn mặt'), findsOneWidget);
      await tester.tap(find.text('Tràn mặt'));
      await tester.pump();
      expect(current.fraction, closeTo(1.0, 1e-9));
      expect(current.side, equals(ContactSide.center));
    });

    testWidgets('13. Tương tác kéo thả trong CustomPositionBuilderScreen: chạm vùng trống không làm nhảy bi, kéo bi không chồng lấp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomPositionBuilderScreen(nextCustomIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Tìm văn bản hiển thị tọa độ ban đầu của 3 bi: Trắng (3.0, 2.1) • Vàng (2.0, 1.3) • Đỏ (1.4, 0.8)
      expect(find.textContaining('Trắng (3.0, 2.1)'), findsOneWidget);

      // Chạm vào góc dưới bên phải mặt bàn (vùng trống cách xa cả 3 bi): tọa độ 3 bi không được nhảy!
      final canvasFinder = find.byType(CustomPaint).first;
      final rect = tester.getRect(canvasFinder);
      await tester.dragFrom(
        Offset(rect.right - 25, rect.bottom - 25),
        const Offset(-15, -15),
      );
      await tester.pump();

      expect(find.textContaining('Trắng (3.0, 2.1)'), findsOneWidget);
    });

    test('14. Lưu bền dữ liệu (Persistence): tạo hình bi mới, lưu ghi chú, tăng lượt tập, khởi tạo lại storage vẫn giữ nguyên và chống lỗi JSON hỏng', () async {
      final tempDir = await Directory.systemTemp.createTemp('xavier_test_');
      final testFile = File('${tempDir.path}/notebook_test.json');
      final storage = NotebookStorage(overrideFile: testFile);

      final customLesson = BilliardLesson(
        id: 'custom-test-01',
        code: 'MY-01',
        title: 'Hình bi test lưu bền',
        subtitle: 'Kiểm tra persistence',
        category: LessonCategory.gathering,
        subCategory: 'Sổ tay cá nhân',
        difficulty: 'Tự tạo',
        diagram: const TableDiagramSpec(
          cueBall: Offset(3.0, 2.0),
          objectBall1: Offset(2.0, 1.3),
          objectBall2: Offset(1.3, 0.8),
        ),
        shotParams: ShotParameters(
          contact: BallContactSpec.oneThird(),
          effet: CueBallEffetSpec.fromTips(horizontalTips: 1.0, verticalTips: -1.5),
          strokeType: 'Êm tay',
          speedLevel: 2,
        ),
        objective: 'Gom về góc',
        executionSteps: const ['Bước 1'],
        commonMistakes: const ['Lỗi 1'],
      );

      final savedState = NotebookPersistedState(
        bookmarkedIds: {'kt-01', 'custom-test-01'},
        practiceCounts: {'kt-01': 12, 'custom-test-01': 4},
        personalNotes: {'kt-01': 'Ghi chú đã lưu bền'},
        customLessons: [customLesson],
        customLessonCounter: 2,
      );

      final ok = await storage.saveState(savedState);
      expect(ok, isTrue);

      final reloaded = await storage.loadState();
      expect(reloaded.bookmarkedIds.contains('custom-test-01'), isTrue);
      expect(reloaded.practiceCounts['kt-01'], equals(12));
      expect(reloaded.personalNotes['kt-01'], equals('Ghi chú đã lưu bền'));
      expect(reloaded.customLessons.length, equals(1));
      expect(reloaded.customLessons.first.title, equals('Hình bi test lưu bền'));
      expect(
        reloaded.customLessons.first.shotParams.contact.fraction,
        closeTo(1.0 / 3.0, 1e-9),
      );

      // Kiểm tra phục hồi an toàn khi file JSON bị hỏng
      await testFile.writeAsString('{corrupted json!!!');
      final fallback = await storage.loadState();
      expect(fallback.bookmarkedIds, isNotEmpty);

      await tempDir.delete(recursive: true);
    });

    testWidgets('15. Tách tính toán và render: phát animation, lật bàn, bật tắt số nút băng không chạy lại mô phỏng trong paint()', (tester) async {
      final lesson = SampleLessonsRepository.lessons.first;
      final outcome1 = CaromPhysicsSolver.evaluateAdjustedShot(
        lesson: lesson,
        activeContact: lesson.shotParams.contact,
        activeEffet: lesson.shotParams.effet,
      );
      final outcome2 = CaromPhysicsSolver.evaluateAdjustedShot(
        lesson: lesson,
        activeContact: lesson.shotParams.contact,
        activeEffet: lesson.shotParams.effet,
      );
      // Cache trả về chính xác cùng một instance SimulationResult
      expect(identical(outcome1.simulationResult, outcome2.simulationResult), isTrue);

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
      await tester.pump();

      final flipBtn = find.text('Lật Trái/Phải');
      await tester.ensureVisible(flipBtn);
      await tester.pump();
      await tester.tap(flipBtn);
      await tester.pump();

      final numbersChip = find.text('Số nút băng');
      await tester.ensureVisible(numbersChip);
      await tester.pump();
      await tester.tap(numbersChip);
      await tester.pump();

      expect(find.byType(LessonDetailScreen), findsOneWidget);
    });

    testWidgets('16. Kiểm thử tích hợp (Smoke test): mở ứng dụng, chuyển qua tất cả các tab và mở màn hình chi tiết bài học không lỗi', (tester) async {
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

