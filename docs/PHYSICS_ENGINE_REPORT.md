# Báo Cáo Kỹ Thuật: Tái Thiết Kế Engine Vật Lý & Sơ Đồ Mô Phỏng Carom Billiard (`fix/physics-engine-v1`)

## 1. Kết Luận Khảo Sát Hiện Trạng & Các Hàm Giả Vật Lý Đã Thay Thế

Qua khảo sát toàn diện tại commit `7a8fe98939619f89da1dea893403edecab297ffe`, các bất cập gốc rễ của bộ giải và giao diện cũ đã được nhận diện và loại bỏ hoàn toàn:

| Nhóm lỗi hiện trạng | Vị trí cũ | Cơ chế giả / lỗi cũ | Cơ chế vật lý thật thay thế |
| :--- | :--- | :--- | :--- |
| **1. Nhánh trả kết quả ăn gian (Preset Bypass)** | `CaromPhysicsSolver.evaluateAdjustedShot` (`lib/models/carom_physics_solver.dart`) | Khi `deltaFraction.abs() < 0.03 && deltaEffetH.abs() < 0.35 && deltaEffetV.abs() < 0.35`, hàm trả thẳng `lesson.diagram` kèm `hitsSecondBall: true`, `gathersInZone: true` mà không mô phỏng. | Xóa bỏ hoàn toàn nhánh kiểm tra ngưỡng sai lệch. Mọi cú đánh (kể cả thông số gốc của 13 bài học) đều đi qua `CaromPhysicsEngine.simulate(ShotInput)` và đánh giá va chạm thật từ `SimulationResult.collisionEvents`. |
| **2. Dịch chuyển điểm mốc Heuristic** | `CaromPhysicsSolver.evaluateAdjustedShot` & `SystemCalculatorCard` | Cộng trừ trực tiếp các hệ số ma thuật (`0.55`, `0.38`, `0.16`, `0.11`, `0.65`) vào danh sách `Offset` có sẵn; `speedLevel` hoàn toàn không được truyền vào hàm giải. | Thay bằng tích phân động lực học thời gian thực ($\Delta t \le 1\,\text{ms}$) với vận tốc đầu cơ $v_{\text{cue}}(\text{speedLevel})$ đơn điệu tăng từ mức 1 đến mức 5. |
| **3. Tách chồng lấp giả tạo trên đường cong nội suy** | `_CaromTableDiagramState._solveCollisionFreeTimeline` (`lib/widgets/diagrams/carom_table_diagram.dart`) | Lấy mẫu 140 bước trên polyline gấp khúc kết hợp `math.pow(t, 0.80)`, dùng `hit1Step` / `hit2Step` đoán thời điểm va chạm, và khi bi 1 chưa từng chạm bi 2 vẫn tự động đẩy bi 2 đi `1.35 * ballRadius`. | Xóa bỏ hoàn toàn `_solveCollisionFreeTimeline`, `hit1Step`, `hit2Step` và hàm mũ easing. Hoạt ảnh nội suy trực tiếp theo thời gian vật lý $t \in [0, T_{\text{end}}]$ từ `SimulationResult.sampleAtTime(t)`. Nếu hụt thật, bi 2 đứng yên tuyệt đối ($\vec{v} = \vec{0}$). |
| **4. Lệch chuẩn hình học & miền hợp lệ Model** | `BallContactSpec`, `CueBallEffetSpec` (`lib/models/billiard_specs.dart`), `CueBallEffetDiagram` | `oneThird = 0.33`, `twoThirds = 0.66`, thiếu preset Tràn mặt (`1.0`); `CueBallEffetSpec` cho phép hình vuông $[-4, 4]^2$ đạt $\approx 5.66$ mũi ở góc chéo; bán kính vẽ (`0.38`) và bán kính chạm (`0.40`) lệch nhau. | Chuẩn hóa `1.0 / 3.0`, `2.0 / 3.0`, bổ sung `BallContactSpec.full()` đồng bộ hai chiều với `ContactSide.center`; chiếu miền ép-phê về hình tròn $\sqrt{h^2 + v^2} \le 4.0$ (tương ứng $r \le 0.75 R$); thống nhất một hàm bán kính duy nhất. |
| **5. Kéo thả nhảy vị trí & mất dữ liệu Sổ tay** | `_EditableCaromTableCanvas` (`lib/screens/custom_position_builder_screen.dart`), `HomeScreen` | Chạm vào vùng trống vẫn kéo viên bi gần nhất nhảy tới ngón tay; toàn bộ trạng thái Sổ tay chỉ nằm trong RAM. | Giới hạn ngưỡng bắt chạm `0.48` nút băng, giữ nguyên `_dragGrabOffset`, kẹp biên $[R, L-R] \times [R, W-R]$ và chống chồng lấp $2R$; lưu bền JSON nguyên tử có `schemaVersion` qua `NotebookStorage`. |

---

## 2. Hệ Phương Trình Vật Lý, Tham Số Chuẩn SI & Phương Pháp Tích Phân Số

### 2.1. Hằng số vật lý chuẩn SI (`TableConfig.standardCarom`)

- **Kích thước mặt bàn trong lòng băng:** $L = 2.84\,\text{m}$ (8 nút băng dài, $1\,\text{nút} = 0.355\,\text{m}$), $W = 1.42\,\text{m}$ (4 nút băng ngắn).
- **Bi Carom chuẩn UMB:** Bán kính $R = 0.03075\,\text{m}$ ($d = 61.5\,\text{mm}$), khối lượng $m = 0.210\,\text{kg}$, mô-men quán tính cầu đặc $I = \frac{2}{5}mR^2$, khối lượng hiệu dụng cây cơ $M_c = 0.520\,\text{kg}$.
- **Hệ số đàn hồi & ma sát:**
  - Đàn hồi bi–bi: $e_{bb} = 0.94$; ma sát tiếp tuyến bi–bi: $\mu_{bb} = 0.055$.
  - Đàn hồi bi–băng: $e_{bc} = 0.80$; ma sát tiếp tuyến bi–băng: $\mu_{bc} = 0.18$.
  - Ma sát trượt vải bàn: $\mu_s = 0.20$; ma sát lăn vải bàn: $\mu_r = 0.014$; suy giảm xoáy đứng: $\alpha_z = 10.5\,\text{rad/s}^2$; gia tốc trọng trường: $g = 9.81\,\text{m/s}^2$.

### 2.2. Ánh xạ hệ tọa độ (Vật lý $\leftrightarrow$ Nút băng $\leftrightarrow$ Màn hình)

1. **Vật lý (SI) $\leftrightarrow$ Nút băng (`Diamond`):**
   - $x \in [0, L]$ dọc theo băng dài tương ứng $d_x = x / 0.355 \in [0, 8]$.
   - $y \in [0, W]$ dọc theo băng ngắn tương ứng $d_y = y / 0.355 \in [0, 4]$.
2. **Nút băng $\leftrightarrow$ Canvas màn hình bàn dọc (`CaromTablePainter`):**
   - Trục ngang màn hình $X_{\text{screen}}$ biểu diễn chiều rộng bàn $d_y \in [0, 4]$ (hoặc $4 - d_y$ khi bật `flipHorizontal`).
   - Trục dọc màn hình $Y_{\text{screen}}$ biểu diễn chiều dài bàn $d_x \in [0, 8]$ (hoặc $8 - d_x$ khi bật `flipVertical`).
   - Tỉ lệ bán kính vẽ viên bi khớp chính xác kích thước vật lý: $r_{\text{px}} = R \cdot \frac{\text{playRect.width}}{W}$.

### 2.3. Các phương trình động lực học cốt lõi

1. **Xung lượng đầu cơ – bi chủ (`CueStrikePhysics`):**
   - Điểm chạm đầu cơ lệch tâm $(x_{\text{tip}}, z_{\text{tip}})$ thỏa $\sqrt{x_{\text{tip}}^2 + z_{\text{tip}}^2} \le 0.75 R$.
   - Vận tốc tịnh tiến ban đầu: $\vec{v}_0 = \frac{J}{m}\cos\theta_{\text{elev}}\,\hat{d}$.
   - Vận tốc góc ban đầu:
     $$\omega_{\text{roll}} = \frac{5 z_{\text{tip}}}{2 R^2} |\vec{v}_0|, \quad \omega_z = \frac{5 x_{\text{tip}}}{2 R^2} |\vec{v}_0|$$
     Khi nâng cơ $\theta_{\text{elev}} > 0$ kèm $x_{\text{tip}} \ne 0$, thành phần xung lực đứng tạo thêm $\omega_{\text{masse}} = \frac{5 x_{\text{tip}}}{2 R^2}\frac{J}{m}\sin\theta_{\text{elev}}$ dọc theo $\hat{d}$ làm uốn cong quỹ đạo (Piqué / Massé).

2. **Chuyển pha Trượt (Sliding) $\to$ Lăn (Rolling) giải tích (`CaromPhysicsEngine`):**
   - Vận tốc trượt tại đáy bi: $\vec{u} = \vec{v} + R(\hat{k} \times \vec{\omega}_{xy}) = (v_x - R\omega_y,\; v_y + R\omega_x)$.
   - Khi $|\vec{u}| > \varepsilon_u$, lực ma sát trượt cho:
     $$\frac{d\vec{v}}{dt} = -\mu_s g \hat{u}, \quad \frac{d\vec{\omega}_{xy}}{dt} = -\frac{5\mu_s g}{2R}(\hat{k}\times\hat{u}) \implies \frac{d\vec{u}}{dt} = -\frac{7}{2}\mu_s g \hat{u}$$
   - Thời gian chính xác đạt trạng thái lăn thuần túy ($\vec{u} = \vec{0}$):
     $$t_{\text{roll}} = \frac{2|\vec{u}_0|}{7\mu_s g}$$
     Nếu $t_{\text{roll}} \le \Delta t$, bước tích phân được tách đôi tại đúng $t_{\text{roll}}$ để triệt tiêu hoàn toàn hiện tượng dao động đổi dấu của $\vec{u}$.

3. **Hình học ngắm Ghost Ball (`AimGeometry`):**
   - Với độ dày chạm $f \in (0, 1]$, tham số va chạm $b = 2R(1-f)$, góc lệch lý thuyết bi mục tiêu $\theta = \arcsin(1-f)$.
   - Góc ngắm $\beta$ tại khoảng cách $D = \|\vec{p}_2 - \vec{p}_1\|$ được giải chính xác từ $\sin\beta = \frac{b}{D}$.

4. **Phát hiện va chạm liên tục (CCD) & Giải va chạm (`CollisionPhysics`):**
   - Giải nghiệm dương nhỏ nhất $t^* \in [0, \Delta t]$ của $\|\Delta\vec{p}_0 + \Delta\vec{v}\,t\|^2 = (2R)^2$ (bi–bi) và thời điểm tâm bi chạm biên $[R, L-R] \times [R, W-R]$ (bi–băng).
   - Va chạm bi–bi và bi–băng giải đồng thời xung lượng pháp tuyến $J_n$ và xung lượng tiếp tuyến giới hạn Coulomb $|J_t| \le \mu J_n$, bảo toàn động lượng và truyền hiệu ứng ném tiếp tuyến (throw) cũng như xoáy $\omega_z$.

---

## 3. Bảng Kết Quả Kiểm Thử Định Lượng & Tích Hợp (16/16 Tiêu Chí)

| STT | Tiêu chí kiểm thử (Mục VIII) | File test | Trạng thái |
| :---: | :--- | :--- | :---: |
| 1 | Bảo toàn & suy giảm năng lượng đơn điệu về $0$ | `test/physics_engine_test.dart` | **PASS** |
| 2 | Chuyển pha trượt $\to$ lăn tại $t_{\text{roll}} = \frac{2v_0}{7\mu_s g}$, đạt $v = \frac{5}{7}v_0$ | `test/physics_engine_test.dart` | **PASS** |
| 3 | Coulé vs Stun vs Rétro trực diện ($x_{\text{Rétro}} < x_{\text{Stun}} < x_{\text{Coulé}}$) | `test/physics_engine_test.dart` | **PASS** |
| 4 | Va chạm đàn hồi trực diện ($e=1, \mu=0$) sai số $< 10^{-6}$ | `test/physics_engine_test.dart` | **PASS** |
| 5 | Va chạm lệch tâm $f = 0.5, \mu_{bb} = 0$ cho góc lệch đúng $30^\circ$ ($< 0.5^\circ$) | `test/physics_engine_test.dart` | **PASS** |
| 6 | Bất biến không chồng lấp $\|\vec{p}_i(t) - \vec{p}_j(t)\| \ge 2R - 10^{-6}\,\text{m}$ | `test/physics_engine_test.dart` | **PASS** |
| 7 | Va chạm băng với ép-phê ngang ($\omega_z > 0$, $\omega_z < 0$, $\omega_z = 0$) đối xứng | `test/physics_engine_test.dart` | **PASS** |
| 8 | Cú đánh hụt thật (True Miss): `hitsSecondBall == false`, bi 2 đứng yên tuyệt đối | `test/physics_engine_test.dart` | **PASS** |
| 9 | Hiệu lực đơn điệu của `speedLevel` từ $1 \to 5$ | `test/physics_engine_test.dart` | **PASS** |
| 10 | Không có nhánh ăn gian theo preset trên toàn bộ 13 bài học mẫu | `test/physics_engine_test.dart` | **PASS** |
| 11 | Miền hợp lệ tròn của `CueBallEffetSpec` ($r \le 4.0$) và đồng nhất bán kính | `test/physics_engine_test.dart` | **PASS** |
| 12 | Preset độ dày `1/3`, `2/3`, `Tràn mặt (1.0)` và đồng bộ `ContactSide.center` | `test/physics_engine_test.dart` | **PASS** |
| 13 | Tương tác kéo thả `CustomPositionBuilderScreen` không nhảy bi, không chồng lấp | `test/physics_engine_test.dart` | **PASS** |
| 14 | Lưu bền dữ liệu (`NotebookStorage`) & tự phục hồi khi JSON hỏng | `test/physics_engine_test.dart` | **PASS** |
| 15 | Tách tính toán và render (`SimulationResult` cache, lật bàn không chạy lại engine) | `test/physics_engine_test.dart` | **PASS** |
| 16 | Kiểm thử tích hợp (Smoke test) toàn bộ các tab và màn hình chi tiết | `test/physics_engine_test.dart` & `test/widget_test.dart` | **PASS** |
