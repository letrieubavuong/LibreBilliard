import 'dart:math' as math;

/// Vector 2D bất biến dùng trong hệ tọa độ vật lý mặt bàn (đơn vị SI: mét, m/s).
/// Tuyệt đối không phụ thuộc vào `dart:ui` hay `package:flutter`.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0.0, 0.0);
  static const Vec2 unitX = Vec2(1.0, 0.0);
  static const Vec2 unitY = Vec2(0.0, 1.0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator -() => Vec2(-x, -y);
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Tích có hướng 2D (thành phần z của tích có hướng 3D): x1*y2 - y1*x2
  double cross(Vec2 other) => x * other.y - y * other.x;

  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  double distanceTo(Vec2 other) => (this - other).length;
  double distanceSquaredTo(Vec2 other) => (this - other).lengthSquared;

  Vec2 get normalized {
    final len = length;
    if (len <= 1e-12) return Vec2.zero;
    return Vec2(x / len, y / len);
  }

  /// Pháp tuyến vuông góc ngược chiều kim đồng hồ trong hệ (x, y): (-y, x)
  Vec2 get perpCCW => Vec2(-y, x);

  /// Pháp tuyến vuông góc cùng chiều kim đồng hồ trong hệ (x, y): (y, -x)
  Vec2 get perpCW => Vec2(y, -x);

  Vec2 rotated(double angleRadians) {
    final c = math.cos(angleRadians);
    final s = math.sin(angleRadians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  static Vec2 lerp(Vec2 a, Vec2 b, double t) =>
      Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vec2 && x == other.x && y == other.y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}

/// Vector 3D bất biến dùng cho vận tốc góc 3 thành phần (wx, wy, wz) và xung lực 3D.
/// Hệ trục tọa độ thuận tay phải: +z hướng thẳng đứng từ mặt bàn lên trên.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0.0, 0.0, 0.0);
  static const Vec3 unitX = Vec3(1.0, 0.0, 0.0);
  static const Vec3 unitY = Vec3(0.0, 1.0, 0.0);
  static const Vec3 unitZ = Vec3(0.0, 0.0, 1.0);

  factory Vec3.fromXY(Vec2 v, [double z = 0.0]) => Vec3(v.x, v.y, z);

  Vec2 get xy => Vec2(x, y);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator -() => Vec3(-x, -y, -z);
  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);
  Vec3 operator /(double scalar) => Vec3(x / scalar, y / scalar, z / scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vec3 get normalized {
    final len = length;
    if (len <= 1e-12) return Vec3.zero;
    return Vec3(x / len, y / len, z / len);
  }

  static Vec3 lerp(Vec3 a, Vec3 b, double t) => Vec3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vec3 && x == other.x && y == other.y && z == other.z);

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';
}

/// Quaternion đơn vị biểu diễn hướng xoay 3D thực tế của viên bi.
/// Được tích phân trực tiếp từ vận tốc góc `omega = (wx, wy, wz)`.
class Quat {
  final double w;
  final double x;
  final double y;
  final double z;

  const Quat(this.w, this.x, this.y, this.z);

  static const Quat identity = Quat(1.0, 0.0, 0.0, 0.0);

  factory Quat.fromAxisAngle(Vec3 axis, double angleRad) {
    final len = axis.length;
    if (len <= 1e-12 || angleRad.abs() <= 1e-12) {
      return Quat.identity;
    }
    final half = angleRad * 0.5;
    final s = math.sin(half) / len;
    return Quat(math.cos(half), axis.x * s, axis.y * s, axis.z * s).normalized;
  }

  Quat get normalized {
    final norm = math.sqrt(w * w + x * x + y * y + z * z);
    if (norm <= 1e-12) return Quat.identity;
    return Quat(w / norm, x / norm, y / norm, z / norm);
  }

  Quat operator *(Quat b) => Quat(
        w * b.w - x * b.x - y * b.y - z * b.z,
        w * b.x + x * b.w + y * b.z - z * b.y,
        w * b.y - x * b.z + y * b.w + z * b.x,
        w * b.z + x * b.y - y * b.x + z * b.w,
      );

  /// Tích phân hướng xoay của bi theo vận tốc góc thế giới `omega` trong khoảng thời gian `dt`.
  Quat integrateAngularVelocity(Vec3 omega, double dt) {
    final speed = omega.length;
    if (speed <= 1e-12 || dt <= 0.0) return this;
    final dq = Quat.fromAxisAngle(omega, speed * dt);
    return (dq * this).normalized;
  }

  /// Xoay một điểm trên mặt cầu đơn vị của viên bi sang hệ tọa độ thế giới.
  Vec3 rotate(Vec3 v) {
    final qv = Vec3(x, y, z);
    final uv = qv.cross(v);
    final uuv = qv.cross(uv);
    return v + ((uv * w) + uuv) * 2.0;
  }

  static Quat slerp(Quat a, Quat b, double t) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;

    double cosHalfTheta = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;
    Quat end = b;
    if (cosHalfTheta < 0.0) {
      end = Quat(-b.w, -b.x, -b.y, -b.z);
      cosHalfTheta = -cosHalfTheta;
    }
    if (cosHalfTheta >= 0.9995) {
      return Quat(
        a.w + t * (end.w - a.w),
        a.x + t * (end.x - a.x),
        a.y + t * (end.y - a.y),
        a.z + t * (end.z - a.z),
      ).normalized;
    }

    final halfTheta = math.acos(cosHalfTheta.clamp(-1.0, 1.0));
    final sinHalfTheta = math.sqrt(1.0 - cosHalfTheta * cosHalfTheta);
    final ratioA = math.sin((1.0 - t) * halfTheta) / sinHalfTheta;
    final ratioB = math.sin(t * halfTheta) / sinHalfTheta;

    return Quat(
      a.w * ratioA + end.w * ratioB,
      a.x * ratioA + end.x * ratioB,
      a.y * ratioA + end.y * ratioB,
      a.z * ratioA + end.z * ratioB,
    ).normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quat &&
          w == other.w &&
          x == other.x &&
          y == other.y &&
          z == other.z);

  @override
  int get hashCode => Object.hash(w, x, y, z);
}

