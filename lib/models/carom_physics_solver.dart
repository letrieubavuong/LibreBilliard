import 'package:flutter/material.dart';
import 'billiard_lesson.dart';

/// Kết quả tính toán quỹ đạo vật lý khi người học thay đổi Độ dày (Chạm trái) hoặc Tâm bi (Ép-phê)
class SolvedShotOutcome {
  final TableDiagramSpec updatedDiagram;
  final bool hitsSecondBall;
  final bool gathersInZone;
  final String feedbackMessage;

  const SolvedShotOutcome({
    required this.updatedDiagram,
    required this.hitsSecondBall,
    required this.gathersInZone,
    required this.feedbackMessage,
  });
}

/// Bộ giải Vật lý Carom (Carom Physics Solver):
/// Tính toán sự biến thiên đường đi của Bi chủ và Bi mục tiêu 1 khi người dùng
/// thử thay đổi Độ dày Chạm trái ([BallContactSpec]) hoặc Điểm chạm Đầu cơ ([CueBallEffetSpec])
/// so với thông số chuẩn của bài học.
class CaromPhysicsSolver {
  static SolvedShotOutcome evaluateAdjustedShot({
    required BilliardLesson lesson,
    required BallContactSpec activeContact,
    required CueBallEffetSpec activeEffet,
  }) {
    final baseDiagram = lesson.diagram;
    final baseContact = lesson.shotParams.contact;
    final baseEffet = lesson.shotParams.effet;

    // Sai số độ dày chạm trái (-0.75 .. +0.75)
    final deltaFraction = activeContact.fraction - baseContact.fraction;
    final sameSide = activeContact.side == baseContact.side ||
        baseContact.side == ContactSide.center;
    final sideMultiplier = sameSide ? 1.0 : -1.0;

    // Sai số chiều cao đầu cơ (Cu-lê 12h vs Trô 6h: -8.0 .. +8.0)
    final deltaVertical = activeEffet.verticalHeight - baseEffet.verticalHeight;
    // Sai số ép-phê ngang (-8.0 .. +8.0)
    final deltaHorizontal =
        activeEffet.horizontalEffet - baseEffet.horizontalEffet;

    // Nếu thông số gần như trùng khớp với chuẩn gốc của bài học
    if (deltaFraction.abs() < 0.03 &&
        sameSide &&
        deltaVertical.abs() < 0.25 &&
        deltaHorizontal.abs() < 0.25) {
      return SolvedShotOutcome(
        updatedDiagram: baseDiagram,
        hitsSecondBall: true,
        gathersInZone: true,
        feedbackMessage: 'Thông số chuẩn: 3 bi hội tụ chính xác tại vùng gom.',
      );
    }

    // Vector từ Bi chủ đến Bi mục tiêu 1
    final toObj1 = baseDiagram.objectBall1 - baseDiagram.cueBall;
    final distToObj1 = toObj1.distance.clamp(0.2, 8.0);
    final forwardUnit = toObj1 / distToObj1;
    // Vector pháp tuyến ngang (vuông góc với hướng ngắm)
    final lateralUnit = Offset(-forwardUnit.dy, forwardUnit.dx);

    // 1. Tính quỹ đạo mới của Bi chủ sau khi thay đổi Độ dày / Cao thấp / Ép-phê:
    // - Tăng verticalHeight (đánh cao cơ hơn chuẩn) đẩy đường bi chủ tiến về phía trước (forwardUnit)
    // - Tăng độ dày (deltaFraction > 0) làm giảm tốc độ văng ngang và tăng tác dụng của Cu-lê/Trô
    // - Thay đổi ép-phê ngang làm lệch tia sau khi chạm băng (~0.12 nút mỗi mũi ép-phê)
    final newCuePath = <Offset>[];
    for (int i = 0; i < baseDiagram.cueBallPath.length; i++) {
      final pt = baseDiagram.cueBallPath[i];
      if (i == 0 && (pt - baseDiagram.objectBall1).distance < 0.35) {
        // Điểm chạm bi 1 giữ nguyên hoặc lệch nhẹ theo má chạm
        newCuePath.add(pt);
        continue;
      }

      final stepWeight = ((i + 1) / baseDiagram.cueBallPath.length);
      final followShift = forwardUnit * (deltaVertical * 0.22 * stepWeight);
      final thicknessShift =
          lateralUnit * (-deltaFraction * 0.65 * sideMultiplier * stepWeight);
      final spinShift = lateralUnit * (deltaHorizontal * 0.14 * stepWeight);

      final shifted = pt + followShift + thicknessShift + spinShift;
      newCuePath.add(
        Offset(
          shifted.dx.clamp(0.0, 8.0),
          shifted.dy.clamp(0.0, 4.0),
        ),
      );
    }

    // 2. Tính quỹ đạo mới của Bi mục tiêu 1 (Vàng):
    // - Vào dày hơn (deltaFraction > 0) làm Bi Vàng đi mạnh hơn (xa hơn) và lệch góc ít hơn
    // - Vào mỏng hơn (deltaFraction < 0) làm Bi Vàng thiếu lực (ngắn hơn) và mở góc ngang rộng hơn
    final newObj1Path = <Offset>[];
    for (int i = 0; i < baseDiagram.objectBall1Path.length; i++) {
      final pt = baseDiagram.objectBall1Path[i];
      final isCushionPoint =
          pt.dx <= 0.05 || pt.dx >= 7.95 || pt.dy <= 0.05 || pt.dy >= 3.95;

      if (isCushionPoint) {
        final angleShift = lateralUnit * (-deltaFraction * 0.45 * sideMultiplier);
        final shifted = pt + angleShift;
        newObj1Path.add(
          Offset(
            pt.dx <= 0.05 || pt.dx >= 7.95
                ? pt.dx
                : shifted.dx.clamp(0.0, 8.0),
            pt.dy <= 0.05 || pt.dy >= 3.95
                ? pt.dy
                : shifted.dy.clamp(0.0, 4.0),
          ),
        );
      } else {
        // Điểm dừng cuối của Bi Vàng phụ thuộc mạnh vào lực truyền (độ dày chạm trái)
        final speedScale = 1.0 + deltaFraction * 0.85;
        final vecFromStart = pt - baseDiagram.objectBall1;
        final scaledEnd = baseDiagram.objectBall1 +
            vecFromStart * speedScale +
            lateralUnit * (-deltaFraction * 0.35 * sideMultiplier);
        newObj1Path.add(
          Offset(
            scaledEnd.dx.clamp(0.15, 7.85),
            scaledEnd.dy.clamp(0.15, 3.85),
          ),
        );
      }
    }

    // Kiểm tra xem đường đi mới của Bi chủ có còn chạm được vào Bi Đỏ (objectBall2) hay không
    double minDistanceToRed = double.infinity;
    final fullCue = [baseDiagram.cueBall, ...newCuePath];
    for (int i = 0; i < fullCue.length - 1; i++) {
      final d = _distancePointToSegment(
        baseDiagram.objectBall2,
        fullCue[i],
        fullCue[i + 1],
      );
      if (d < minDistanceToRed) minDistanceToRed = d;
    }

    final hitsSecondBall = minDistanceToRed <= 0.38;

    // Kiểm tra xem điểm cuối của Bi Vàng và Bi chủ có nằm trong vùng gom không
    bool gathersInZone = true;
    if (baseDiagram.targetZoneCenter != null) {
      final zone = baseDiagram.targetZoneCenter!;
      final radius = baseDiagram.targetZoneRadius * 1.15;
      final cueEnd = newCuePath.isEmpty ? baseDiagram.cueBall : newCuePath.last;
      final obj1End =
          newObj1Path.isEmpty ? baseDiagram.objectBall1 : newObj1Path.last;
      gathersInZone =
          (cueEnd - zone).distance <= radius && (obj1End - zone).distance <= radius;
    }

    // Tạo thông báo phân tích vật lý trực quan cho người tập
    String feedback;
    if (!sameSide) {
      feedback =
          'Ngắm nhầm sang ${activeContact.side.title}: Bi chủ văng ngược hướng, không thể trúng bi Đỏ!';
    } else if (!hitsSecondBall) {
      if (deltaVertical > 0.8) {
        feedback =
            'Đầu cơ quá cao (dư Cu-lê): Bi chủ lao vọt qua phía trước mặt bi Đỏ.';
      } else if (deltaVertical < -0.8) {
        feedback =
            'Đầu cơ quá thấp (dư Trô): Bi chủ bị kéo giật lùi quá sâu, trượt dưới bi Đỏ.';
      } else if (deltaFraction > 0.12) {
        feedback =
            'Vào quá dày (${activeContact.label}): Bi chủ bị hãm góc, lệch tia vào bi Đỏ.';
      } else {
        feedback =
            'Vào quá mỏng (${activeContact.label}) hoặc lệch ép-phê: Tia bi chủ trượt qua bi Đỏ.';
      }
    } else if (!gathersInZone) {
      if (deltaFraction > 0.1) {
        feedback =
            'Trúng Carom nhưng vào hơi dày (${activeContact.label}) làm bi Vàng chạy lố qua vùng gom!';
      } else {
        feedback =
            'Trúng Carom nhưng vào hơi mỏng (${activeContact.label}) làm bi Vàng thiếu lực về vùng gom!';
      }
    } else {
      feedback =
          'Đạt yêu cầu: Quỹ đạo vẫn ghi điểm Carom và giữ 3 bi trong vùng kiểm soát.';
    }

    return SolvedShotOutcome(
      updatedDiagram: baseDiagram.copyWithTrajectories(
        cueBallPath: newCuePath,
        objectBall1Path: newObj1Path,
        objectBall2Path: hitsSecondBall ? baseDiagram.objectBall2Path : const [],
      ),
      hitsSecondBall: hitsSecondBall,
      gathersInZone: gathersInZone,
      feedbackMessage: feedback,
    );
  }

  static double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq <= 0.00001) return (p - a).distance;
    final t =
        (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(0.0, 1.0);
    final projection = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - projection).distance;
  }
}

extension _TableDiagramTrajectoryCopy on TableDiagramSpec {
  TableDiagramSpec copyWithTrajectories({
    required List<Offset> cueBallPath,
    required List<Offset> objectBall1Path,
    required List<Offset> objectBall2Path,
  }) {
    return TableDiagramSpec(
      label: label,
      description: description,
      cueBall: cueBall,
      objectBall1: objectBall1,
      objectBall2: objectBall2,
      cueBallPath: cueBallPath,
      objectBall1Path: objectBall1Path,
      objectBall2Path: objectBall2Path,
      targetZoneCenter: targetZoneCenter,
      targetZoneRadius: targetZoneRadius,
      showDiamondNumbers: showDiamondNumbers,
      showCornerZones: showCornerZones,
    );
  }
}
