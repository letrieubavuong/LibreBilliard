# AGENTS.md: Quy Chuẩn Phát Triển & Kiểm Chứng Hệ Thống LibreBilliard

Tài liệu này định nghĩa các quy tắc bất biến dành cho các AI Agent khi làm việc trên kho mã nguồn `LibreBilliard`.

## 1. Engine Vật Lý Carom (`lib/physics/`)
- Mọi đơn vị tính trong Engine là chuẩn SI: mét ($\text{m}$), giây ($\text{s}$), kilôgam ($\text{kg}$), radian ($\text{rad}$).
- Không bao giờ thêm các hệ số nhân tạo phá vỡ định luật bảo toàn cơ học ($E_{\text{after}} \le E_{\text{before}}$).
- Va chạm CCD giải trên quỹ đạo bậc hai $\vec{p}(t) = \vec{p}_0 + \vec{v}_0 t + \frac{1}{2}\vec{a} t^2$ và đồng bộ chặt chẽ với thời điểm chuyển pha (`timeToNextPhaseTransition`).
- Đầu vào không hợp lệ (chồng lấp hoặc ra ngoài biên bàn) phải bị từ chối bằng `ShotInputValidationException` và `validation.isValid == false`. Tuyệt đối không tự ý dịch chuyển tọa độ bi của người dùng.

## 2. Giao Diện & Bàn Carom (`lib/widgets/diagrams/`, `lib/screens/`)
- Tỉ lệ khung nhìn của bàn bida phải sử dụng duy nhất một đại lượng `pixelsPerMeter` cho cả hai trục để giữ bóng tròn hoàn hảo và tiếp xúc đúng ở mọi góc.
- Tốc độ phát lại `1.0×` phải đồng bộ với thời gian vật lý thực tế `durationSeconds` (cộng thời gian ra ngọn cơ).
- Các thao tác chuyển đổi góc nhìn UI (lật bàn, bật tắt số nút băng, kéo thanh timeline) chỉ thay đổi trạng thái hiển thị của Painter, không được chạy lại `CaromPhysicsEngine.simulate()`.

## 3. Lưu Trữ Bền Vững (`lib/data/notebook_storage.dart`)
- Dữ liệu người dùng (Sổ tay cá nhân, hình bi tự tạo) phải được lưu vào thư mục ứng dụng hệ thống, không dùng thư mục tạm (`systemTemp`).
- Phải tạo bản sao `.corrupted.bak` khi gặp file JSON lỗi và bảo lưu file khi gặp `schemaVersion` tương lai.
- Trạng thái lưu trữ phải được thông báo trung thực lên UI qua `Future<bool>`.

