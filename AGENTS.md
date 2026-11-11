# AGENTS.md: Quy Chuẩn Phát Triển & Kiểm Chứng Hệ Thống LibreBilliard

Tài liệu này định nghĩa các quy tắc bất biến dành cho các AI Agent khi làm việc trên kho mã nguồn `LibreBilliard`.

## 1. Engine Vật Lý Carom (`lib/physics/`)
- Mọi đơn vị tính trong Engine là chuẩn SI: mét ($\text{m}$), giây ($\text{s}$), kilôgam ($\text{kg}$), radian ($\text{rad}$).
- Không bao giờ thêm các hệ số nhân tạo phá vỡ định luật bảo toàn cơ học ($E_{\text{after}} \le E_{\text{before}}$).
- **Mô hình Băng:** Công bố trung thực là Mô hình Băng Rút Gọn 2.5D Tiêu Tán Năng Lượng (Planar Dissipative Cushion Model) với ma sát Coulomb và suy giảm xoáy mặt băng (spin damping). Tuyệt đối không tuyên bố là mô hình vật rắn 3D toàn phần khi chưa giải động học nâng nảy trục Z.
- **Va chạm CCD:** Giải trên quỹ đạo bậc hai $\vec{p}(t) = \vec{p}_0 + \vec{v}_0 t + \frac{1}{2}\vec{a} t^2$, tích hợp **Cô lập Cực trị Giải tích** giải nghiệm thực của $f'(t) = 0$ (Cardano & lượng giác) để chia khoảng đơn điệu, bắt trọn 100% các ca va chạm sượt (grazing collisions) với sai số tiếp xúc $|d - 2R| < 10^{-11}\,\text{m}$.
- Đầu vào không hợp lệ (chồng lấp $< 2R$ hoặc ra ngoài biên bàn) phải bị từ chối bằng `ShotInputValidationException` và `validation.isValid == false`. Tuyệt đối không tự ý dịch chuyển tọa độ bi của người dùng.

## 2. Bài Học Sư Phạm & Fixture Kỹ Thuật (`lib/data/sample_lessons.dart`, `lib/models/lesson_verification_fixture.dart`)
- Mọi bài học mẫu phải được nghiệm thu qua `LessonPhysicsVerificationFixture` độc lập (thứ tự chạm, má, fraction thực $\pm 0.05$, số băng trước carom, số băng bi vàng, khoảng kéo/tiến cm và gom bi).
- Tuyệt đối không được nới rộng bán kính vùng gom (`targetZoneRadius`) hay nới lỏng dung sai để gượng ép làm xanh bài test.
- Bài học nào phụ thuộc vào hiệu ứng cơ học chưa có dữ liệu đo đạc thực nghiệm (như Piqué nâng cơ 40° làm cong quỹ đạo trượt) phải đánh nhãn trung thực `isPhysicsVerified: false`.

## 3. Giao Diện & Bàn Carom (`lib/widgets/diagrams/`, `lib/screens/`)
- Tỉ lệ khung nhìn của bàn bida phải sử dụng duy nhất một đại lượng `pixelsPerMeter` cho cả hai trục để giữ bóng tròn hoàn hảo và tiếp xúc đúng ở mọi góc.
- **Thời lượng phát lại:** Tốc độ `1.0×` phải ánh xạ chính xác: $0.28\text{s}$ vung cơ và đúng $T_{\text{sim}}$ giây chuyển động bi trong thời gian thực.
- Kéo thả bi trên bàn phải sử dụng thuật toán chiếu xen kẽ 16 chu kỳ kết hợp binary search fallback (`CaromTableCanvasLayout.constrainBallPosition`) để không bao giờ bị vượt biên hay chồng lấn kể cả khi bị kéo đè vào góc bàn.
- Thao tác chuyển đổi góc nhìn UI (lật bàn, bật tắt số nút băng) chỉ thay đổi trạng thái hiển thị của Painter, không được chạy lại `CaromPhysicsEngine.simulate()`.

## 4. Lưu Trữ Bền Vững (`lib/data/notebook_storage.dart`)
- Dữ liệu người dùng (Sổ tay cá nhân, hình bi tự tạo) phải được lưu vào thư mục ứng dụng hệ thống chuẩn (`path_provider`), không dùng thư mục tạm (`systemTemp`).
- Phải tạo bản sao `.corrupted.bak` khi gặp file JSON lỗi.
- **Write Guard Schema tương lai:** Khi gặp file có `schemaVersion > currentSchemaVersion`, ứng dụng phải tạo bản sao `.future_v{version}.bak` và chuyển sang chế độ Read-Only. Hàm `saveState` phải kiểm tra và từ chối ghi đè lên file trên đĩa để bảo toàn 100% bytes dữ liệu gốc.
- Callback lưu ghi chú trên UI phải thực hiện cập nhật duy nhất một lần và await kết quả lưu, không gọi lặp ghi đôi.
