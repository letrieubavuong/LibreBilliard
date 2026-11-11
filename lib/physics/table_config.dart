import 'vector_math.dart';

/// Bốn thành băng của mặt bàn Carom trong hệ trục (x: băng dài 0..L, y: băng ngắn 0..W).
enum CushionId {
  /// Băng ngắn trên / đầu bàn (x = 0, pháp tuyến hướng vào trong bàn: +x)
  shortNear(Vec2(1.0, 0.0)),

  /// Băng ngắn dưới / cuối bàn (x = L, pháp tuyến hướng vào trong bàn: -x)
  shortFar(Vec2(-1.0, 0.0)),

  /// Băng dài trái (y = 0, pháp tuyến hướng vào trong bàn: +y)
  longLeft(Vec2(0.0, 1.0)),

  /// Băng dài phải (y = W, pháp tuyến hướng vào trong bàn: -y)
  longRight(Vec2(0.0, -1.0));

  /// Pháp tuyến đơn vị hướng vào phía trong mặt bàn.
  final Vec2 inwardNormal;
  const CushionId(this.inwardNormal);

  /// Tiếp tuyến đơn vị dọc theo mặt băng sao cho `inwardNormal x tangent = +z`:
  /// tức là `tangent = (-n_y, n_x)`.
  Vec2 get tangent => Vec2(-inwardNormal.y, inwardNormal.x);
}

/// Cấu hình vật lý chuẩn của bàn Carom Libre / 3-Cushion trong hệ đơn vị SI (mét, giây, kg, rad).
///
/// Nguồn tham khảo thông số vật lý:
/// - UMB / CEB Carom Table & Ball Equipment Rules:
///   + Kích thước lọt lòng bàn lớn (Match table): 2.84 m x 1.42 m (tỉ lệ 2:1, 8 x 4 nút băng).
///   + Đường kính bi Carom Aramith Pro-Cup: 61.5 mm (bán kính R = 0.03075 m), khối lượng m = 0.210 kg.
///   + Ô cấm góc Libre chuẩn: 71 cm (2 nút băng dài) x 35.5 cm (1 nút băng ngắn).
/// - Marlow (1994), *The Physics of Pocket Billiards* & Alciatore (*The Illustrated Principles of Pool and Billiards*):
///   + Hệ số đàn hồi bi-bi (phenolic resin): e_bb = 0.94.
///   + Hệ số đàn hồi bi-băng cao su Kleber: e_bc = 0.80.
///   + Hệ số ma sát trượt vải bàn Simonis 300 Rapide: mu_s = 0.20.
///   + Hệ số ma sát lăn vải bàn: mu_r = 0.014.
///   + Hệ số ma sát tiếp tuyến bi-bi (gây hiệu ứng throw & truyền ép-phê): mu_bb = 0.055.
///   + Hệ số ma sát tiếp tuyến bi-băng (gây hiệu ứng mở/khép góc ép-phê): mu_bc = 0.18.
class TableConfig {
  /// Chiều dài lọt lòng mặt bàn dọc theo băng dài (m) - tương ứng 8 nút băng.
  final double lengthMeters;

  /// Chiều rộng lọt lòng mặt bàn dọc theo băng ngắn (m) - tương ứng 4 nút băng.
  final double widthMeters;

  /// Bán kính bi Carom (m) - chuẩn 61.5 mm đường kính => R = 0.03075 m.
  final double ballRadius;

  /// Khối lượng một viên bi Carom (kg) - chuẩn 210 g = 0.210 kg.
  final double ballMass;

  /// Khối lượng hiệu dụng của cây cơ (kg) - chuẩn cơ Libre/Carom 500-530 g.
  final double cueMass;

  /// Gia tốc trọng trường (m/s^2).
  final double gravity;

  /// Giới hạn bán kính điểm chạm đầu cơ chuẩn hóa trên mặt bi (r_max / R) trước khi tạch cơ (miscue).
  final double maxTipOffsetRatio;

  /// Hệ số đàn hồi pháp tuyến khi va chạm bi - bi (0 < e_bb <= 1).
  final double restitutionBallBall;

  /// Hệ số đàn hồi pháp tuyến khi va chạm bi - băng (0 < e_bc <= 1).
  final double restitutionBallCushion;

  /// Hệ số ma sát trượt giữa bi và vải bàn (mu_s).
  final double slidingFriction;

  /// Hệ số ma sát lăn giữa bi và vải bàn (mu_r).
  final double rollingFriction;

  /// Gia tốc tắt dần vận tốc góc trục đứng wz do ma sát xoáy tại điểm tiếp xúc vải bàn (rad/s^2).
  final double spinDecelerationRate;

  /// Hệ số ma sát tiếp tuyến giữa hai mặt bi khi va chạm (mu_bb).
  final double ballBallFriction;

  /// Hệ số ma sát tiếp tuyến giữa bi và cao su băng (mu_bc).
  final double ballCushionFriction;

  /// Tỉ lệ chiều cao mũi băng cao su so với bán kính bi (h_cushion / R ~ 1.24, tức ~62% đường kính bi).
  final double cushionContactHeightRatio;

  const TableConfig({
    this.lengthMeters = 2.84,
    this.widthMeters = 1.42,
    this.ballRadius = 0.03075,
    this.ballMass = 0.210,
    this.cueMass = 0.520,
    this.gravity = 9.81,
    this.maxTipOffsetRatio = 0.80,
    this.restitutionBallBall = 0.94,
    this.restitutionBallCushion = 0.80,
    this.slidingFriction = 0.20,
    this.rollingFriction = 0.014,
    this.spinDecelerationRate = 10.5,
    this.ballBallFriction = 0.055,
    this.ballCushionFriction = 0.18,
    this.cushionContactHeightRatio = 1.24,
  });

  /// Cấu hình bàn Carom tiêu chuẩn.
  static const TableConfig standardCarom = TableConfig();

  /// Mô-men quán tính của quả cầu đặc đồng chất: I = (2/5) * m * R^2.
  double get ballMomentOfInertia => 0.4 * ballMass * ballRadius * ballRadius;

  /// Khoảng cách 1 nút băng (1 diamond unit) tính bằng mét (2.84 / 8 = 0.355 m).
  double get metersPerDiamondX => lengthMeters / 8.0;
  double get metersPerDiamondY => widthMeters / 4.0;

  /// Bán kính bi quy đổi sang đơn vị nút băng (diamond units).
  double get ballRadiusInDiamonds => ballRadius / metersPerDiamondX;

  /// Chuyển đổi tọa độ từ hệ nút băng (X: 0..8, Y: 0..4) sang hệ mét vật lý (m).
  Vec2 diamondToMeters(Vec2 diamond) => Vec2(
        diamond.x * metersPerDiamondX,
        diamond.y * metersPerDiamondY,
      );

  /// Chuyển đổi tọa độ từ hệ mét vật lý (m) sang hệ nút băng (X: 0..8, Y: 0..4).
  Vec2 metersToDiamond(Vec2 meters) => Vec2(
        meters.x / metersPerDiamondX,
        meters.y / metersPerDiamondY,
      );

  double diamondDistanceToMeters(double diamondDist) =>
      diamondDist * metersPerDiamondX;

  double metersToDiamondDistance(double metersDist) =>
      metersDist / metersPerDiamondX;

  /// Giới hạn tâm bi nằm trong lòng bàn hợp lệ [R, L - R] x [R, W - R].
  Vec2 clampBallPositionMeters(Vec2 pos) => Vec2(
        pos.x.clamp(ballRadius, lengthMeters - ballRadius),
        pos.y.clamp(ballRadius, widthMeters - ballRadius),
      );

  /// Giới hạn tâm bi trong hệ đơn vị nút băng [R_d, 8 - R_d] x [R_d, 4 - R_d].
  Vec2 clampBallPositionDiamonds(Vec2 diamondPos) {
    final rx = ballRadius / metersPerDiamondX;
    final ry = ballRadius / metersPerDiamondY;
    return Vec2(
      diamondPos.x.clamp(rx, 8.0 - rx),
      diamondPos.y.clamp(ry, 4.0 - ry),
    );
  }

  TableConfig copyWith({
    double? lengthMeters,
    double? widthMeters,
    double? ballRadius,
    double? ballMass,
    double? cueMass,
    double? gravity,
    double? maxTipOffsetRatio,
    double? restitutionBallBall,
    double? restitutionBallCushion,
    double? slidingFriction,
    double? rollingFriction,
    double? spinDecelerationRate,
    double? ballBallFriction,
    double? ballCushionFriction,
    double? cushionContactHeightRatio,
  }) {
    return TableConfig(
      lengthMeters: lengthMeters ?? this.lengthMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      ballRadius: ballRadius ?? this.ballRadius,
      ballMass: ballMass ?? this.ballMass,
      cueMass: cueMass ?? this.cueMass,
      gravity: gravity ?? this.gravity,
      maxTipOffsetRatio: maxTipOffsetRatio ?? this.maxTipOffsetRatio,
      restitutionBallBall: restitutionBallBall ?? this.restitutionBallBall,
      restitutionBallCushion:
          restitutionBallCushion ?? this.restitutionBallCushion,
      slidingFriction: slidingFriction ?? this.slidingFriction,
      rollingFriction: rollingFriction ?? this.rollingFriction,
      spinDecelerationRate: spinDecelerationRate ?? this.spinDecelerationRate,
      ballBallFriction: ballBallFriction ?? this.ballBallFriction,
      ballCushionFriction: ballCushionFriction ?? this.ballCushionFriction,
      cushionContactHeightRatio:
          cushionContactHeightRatio ?? this.cushionContactHeightRatio,
    );
  }
}

