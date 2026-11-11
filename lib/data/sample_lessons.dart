import 'package:flutter/material.dart';
import '../models/billiard_lesson.dart';

class SampleLessonsRepository {
  static final List<BilliardLesson> lessons = [
    // =========================================================================
    // TAB 1: KĨ THUẬT (TECHNIQUE)
    // =========================================================================
    BilliardLesson(
      id: 'kt-01',
      code: 'KT-01',
      title: 'Kĩ thuật Trô ngắn giữ bi (Rétro Amorti)',
      subtitle:
          'Kéo bi chủ lùi 4–8cm sau va chạm Bi 1 (tổng dịch chuyển 15–25cm) gom góc',
      category: LessonCategory.technique,
      subCategory: 'Cú đánh nền tảng',
      difficulty: 'Cơ bản',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Rétro ngắn gom vào góc',
        description:
            'Bi chủ trô lùi 5.7cm chạm bi đỏ, bi vàng đi 1 băng ngắn quay lại',
        cueBall: Offset(1.65, 1.45),
        objectBall1: Offset(0.92, 1.12),
        objectBall2: Offset(1.40, 1.10),
        targetZoneCenter: Offset(1.05, 1.00),
        targetZoneRadius: 0.58,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.threeQuarters(
          side: ContactSide.left,
          description: 'Vào dày 3/4 má trái bi vàng để hãm tốc độ bi chủ',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 0.5,
          verticalTips: -3.0,
          customLabel: '6h Trô sâu • 0.5 Ép-phê Phải',
          description: 'Hạ thấp cầu tay, điểm chạm 6h cách mép dưới 3mm',
        ),
        strokeType: 'Ra cơ gọn, miết nhẹ đầu cơ (4–5cm)',
        speedLevel: 2,
        customCueSpeed: 1.60,
      ),
      objective:
          'Làm chủ cú Rétro ngắn để bi mục tiêu 1 (Vàng) chạm 1 băng ngắn rồi quay về đúng vị trí bi Đỏ, tạo thành hình mắt kính sát góc.',
      executionSteps: [
        'Đặt cầu tay mở hoặc đóng thấp sát mặt bàn, khoảng cách từ cầu tay đến bi chủ chỉ 10–12cm.',
        'Ngắm dày 3/4 vào má trái của bi Vàng để truyền lực cho bi Vàng vào băng ngắn.',
        'Chạm mũi cơ ở hướng 6h thấp, cổ tay thả lỏng, rút ngọn cơ dứt khoát nhưng dừng ngay sau khi qua bi chủ 4cm.',
      ],
      commonMistakes: [
        'Cầu tay quá xa (trên 18cm) khiến đầu cơ bị ngóc lên lúc chạm bi, biến Rétro thành cú đánh trượt hoặc nhảy bi.',
        'Vào quá mỏng (1/2 trái) làm bi chủ văng ngang quá nhanh và bi Vàng thiếu lực quay về.',
      ],
    ),

    BilliardLesson(
      id: 'kt-02',
      code: 'KT-02',
      title: 'Kĩ thuật Đẩy mượt (Poussé / Coulé ngắn)',
      subtitle:
          'Đẩy bi chủ tịnh tiến 3–6cm sau chạm Bi 1 (tổng dịch chuyển 12–18cm)',
      category: LessonCategory.technique,
      subCategory: 'Cú đánh nền tảng',
      difficulty: 'Trung cấp',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Poussé giữ nhịp dọc băng',
        description: 'Đẩy tịnh tiến mượt cả 2 bi dọc theo băng dài giữ cặp bi song song',
        cueBall: Offset(3.05, 0.58),
        objectBall1: Offset(3.52, 0.36),
        objectBall2: Offset(3.40, 0.12),
        targetZoneCenter: Offset(3.73, 0.22),
        targetZoneRadius: 0.75,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.half(
          side: ContactSide.right,
          description: 'Chạm đúng 1/2 má phải để tách góc 30–40 độ tự nhiên',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -1.0,
          verticalTips: 2.5,
          customLabel: '12h Cu-lê • 1 Ép-phê Trái',
          description: 'Đầu cơ cao 12h giúp bi chủ lăn tới ngay từ lúc chạm',
        ),
        strokeType: 'Đẩy mượt tăng tốc đều (Không giật cơ)',
        speedLevel: 1,
        customCueSpeed: 0.55,
      ),
      objective:
          'Di chuyển cả 3 bi tịnh tiến dọc theo băng dài từng nhịp 10–15cm mà không làm 2 bi mục tiêu tách xa nhau (nền tảng của Seri dọc băng).',
      executionSteps: [
        'Nâng nhẹ cầu tay để thân cơ song song mặt bàn khi ngắm vào điểm 12h của bi chủ.',
        'Nhịp nhấp cơ chậm, khi ra cơ giữ tốc độ ngọn cơ đều đặn đi xuyên qua vị trí bi chủ khoảng 6–8cm.',
        'Kiểm soát lực mức 1 để bi Vàng và bi Đỏ chỉ lăn thêm đúng một khoảng bằng 2 thân bi.',
      ],
      commonMistakes: [
        'Giật ngọn cơ lại ngay khi chạm bi (biến thành cú đánh chết bi làm bi chủ đứng yên, hỏng thế dẫn bi).',
        'Đứng hai bi quá sát (< 1cm) mà đẩy thẳng mặt dễ phạm lỗi dính cơ (Double hit / Push shot).',
      ],
    ),

    BilliardLesson(
      id: 'kt-03',
      code: 'KT-03',
      title: 'Cú đánh Phanh bi (Amorti / Drop Shot)',
      subtitle:
          'Bắt chết tốc độ bi chủ ngay khi chạm vào bi mục tiêu ở cự ly trung bình',
      category: LessonCategory.technique,
      subCategory: 'Kiểm soát lực',
      difficulty: 'Trung cấp',
      isPhysicsVerified: false,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Amorti giữ bi chủ ở lại vùng gom',
        description:
            'Bi chủ lăn nhẹ đến chạm mỏng bi đỏ, trong khi bi vàng chạy 2 băng quay về',
        cueBall: Offset(3.0, 2.0),
        objectBall1: Offset(1.35, 1.18),
        objectBall2: Offset(1.30, 0.90),
        targetZoneCenter: Offset(1.02, 0.95),
        targetZoneRadius: 0.85,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.twoThirds(
          side: ContactSide.left,
          description: 'Chạm 2/3 trái để truyền 70% động lượng sang bi Vàng',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 1.5,
          verticalTips: -1.5,
          customLabel: 'Dưới tâm (6h nhẹ) • 1.5 Ép-phê Phải',
          description: 'Độ xoáy ngược vừa đủ triệt tiêu đà lăn tới của bi chủ',
        ),
        strokeType: 'Đánh mềm cổ tay (Lực 2/5)',
        speedLevel: 2,
        customCueSpeed: 1.20,
      ),
      objective:
          'Khi bi chủ ở xa còn 2 bi mục tiêu đã ở gần góc: dùng đòn Amorti để bi chủ dừng lại ngay cạnh bi số 2, đồng thời đưa bi số 1 đi 2 băng góc quay lại chụm 3 bi.',
      executionSteps: [
        'Ước lượng khoảng cách từ bi chủ đến bi Vàng để chọn độ thấp đầu cơ: càng xa thì càng cần chạm thấp hơn một chút để giữ xoáy.',
        'Ngắm 2/3 trái bi Vàng, cho thêm 1.5 ép-phê thuận để bi Vàng sau khi chạm 2 băng góc sẽ mở rộng ra đúng vị trí bi Đỏ.',
        'Ra cơ êm như đặt bi chủ vào vị trí bi Vàng.',
      ],
      commonMistakes: [
        'Đánh quá mạnh làm bi chủ bị giật lùi (Rétro) thay vì lăn nhẹ từ từ vào bi Đỏ.',
        'Đánh cao đầu cơ khiến bi chủ lao thẳng vào băng ngắn và làm bung bi Đỏ ra xa.',
      ],
    ),

    BilliardLesson(
      id: 'kt-04',
      code: 'KT-04',
      title: 'Kĩ thuật Piqué / Massé nhỏ (Petit Massé)',
      subtitle: 'Nghiêng cơ 35–45 độ để bẻ cong quỹ đạo bi chủ trong phạm vi hẹp',
      category: LessonCategory.technique,
      subCategory: 'Cú đánh đặc biệt',
      difficulty: 'Nâng cao',
      isPhysicsVerified: false,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Piqué xử lý thế 3 bi thẳng hàng sát băng',
        description:
            'Bi chủ lách nhẹ qua má bi vàng rồi vòng cong chạm mặt bi đỏ mà không đẩy bi đi xa',
        cueBall: Offset(2.02, 0.46),
        objectBall1: Offset(2.48, 0.36),
        objectBall2: Offset(2.50, 0.60),
        targetZoneCenter: Offset(2.50, 0.47),
        targetZoneRadius: 0.45,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneQuarter(
          side: ContactSide.right,
          description: 'Chạm mỏng 1/4 má phải bi Vàng rồi uốn cong vào bi Đỏ',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -2.5,
          verticalTips: -2.5,
          customLabel: 'Nghiêng cơ 40° • 2.5 Ép-phê Trái (7h)',
          description:
              'Đặt đầu cơ ở góc 7h–8h, dựng chuôi cơ nghiêng khoảng 40 độ',
        ),
        strokeType: 'Thả rơi ngọn cơ nhẹ bằng cổ tay (Lực 1/5)',
        speedLevel: 1,
        cueElevationDegrees: 40.0,
        customCueSpeed: 1.00,
      ),
      objective:
          'Giải quyết thế bi "chết góc" (khi góc chạm thẳng thông thường quá hẹp không thể Rétro ngang được) mà vẫn giữ nguyên 3 bi trong diện tích 15cm.',
      executionSteps: [
        'Dựng cầu tay cao vững chắc, nâng chuôi cơ lên góc 35–45 độ so với mặt bàn.',
        'Ngắm 1/4 má phải bi Vàng, mũi cơ đặt tại hướng 7h30 trên bi chủ.',
        'Dùng lực cổ tay thả nhẹ đầu cơ đi xuống xuyên qua bi chủ 2cm, tuyệt đối không thúc mạnh bằng vai.',
      ],
      commonMistakes: [
        'Thúc cơ quá mạnh làm bi chủ nảy tưng lên hoặc làm rách vải bàn, đồng thời làm bi Vàng văng xa.',
      ],
    ),

    // =========================================================================
    // TAB 2: HÌNH GOM BI (GATHERING / RAPPEL)
    // =========================================================================
    BilliardLesson(
      id: 'gb-01',
      code: 'GB-01',
      title: 'Gom bi 1 băng dọc (Rappel 1 Bande Longue)',
      subtitle:
          'Đưa bi mục tiêu 1 đập 1 băng dài quay về chụm với bi mục tiêu 2 ở góc',
      category: LessonCategory.gathering,
      subCategory: 'Gom bi 1 băng',
      difficulty: 'Cơ bản',
      isPhysicsVerified: false,
      diagram: const TableDiagramSpec(
        label: 'Hình gom 1 băng dài kinh điển (Xavier Gretillat)',
        description:
            'Bi vàng đập băng dài rồi tụ về khu vực đầu ô cấm góc trái',
        cueBall: Offset(3.4, 1.65),
        objectBall1: Offset(2.3, 1.05),
        objectBall2: Offset(2.0, 1.30),
        targetZoneCenter: Offset(1.80, 0.95),
        targetZoneRadius: 0.90,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneThird(
          side: ContactSide.right,
          description:
              'Chạm 1/3 má phải bi Vàng để bi Vàng vào băng dài góc 60 độ',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 0.0,
          verticalTips: -1.0,
          customLabel: 'Dưới tâm nhẹ • Không ép-phê',
          description: 'Giữ đường đi tự nhiên của bi chủ sang chạm nhẹ bi Đỏ',
        ),
        strokeType: 'Đánh êm, kiểm soát tốc độ bi chủ',
        speedLevel: 2,
        customCueSpeed: 0.90,
      ),
      objective:
          'Thu hồi bi Vàng đang nằm lơ lửng ngoài trung tâm về sát mép ô cấm góc cùng với bi Đỏ để bắt đầu vào seri góc.',
      executionSteps: [
        'Xác định điểm rơi mong muốn của bi Vàng là ngay phía trên bi Đỏ (ngoài vạch ô cấm góc 5cm).',
        'Từ điểm đó kẻ đường đối xứng qua băng dài để tìm điểm chạm băng của bi Vàng.',
        'Ngắm 1/3 trái vào má phải bi Vàng, đầu cơ dưới tâm nửa mũi để bi chủ lăn chậm sang chạm mỏng bi Đỏ rồi dừng lại.',
      ],
      commonMistakes: [
        'Vào dày hơn 1/2 làm bi Vàng đập băng quá mạnh, nảy vọt xuống băng dài đối diện.',
        'Cho dư ép-phê làm bi chủ sau khi chạm bi Vàng bị lệch tia, trượt qua mặt bi Đỏ.',
      ],
    ),

    BilliardLesson(
      id: 'gb-02',
      code: 'GB-02',
      title: 'Gom bi Chữ thập 2 băng (Croisé Rappel)',
      subtitle: 'Xử lý thế 2 bi mục tiêu nằm lệch nhau bằng đường bi cắt chéo',
      category: LessonCategory.gathering,
      subCategory: 'Gom bi 2 băng',
      difficulty: 'Trung cấp',
      isPhysicsVerified: false,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Gom bi Chữ thập (Croisé)',
        description:
            'Bi vàng đi 2 băng góc (dài - ngắn) vòng về đón đầu bi chủ và bi đỏ',
        cueBall: Offset(2.8, 2.3),
        objectBall1: Offset(2.1, 1.5),
        objectBall2: Offset(2.4, 1.3),
        targetZoneCenter: Offset(1.81, 0.87),
        targetZoneRadius: 1.60,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.half(
          side: ContactSide.left,
          description:
              'Chạm 1/2 má trái để đẩy bi Vàng đi 2 băng góc trái trên',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -1.5,
          verticalTips: -2.0,
          customLabel: '6h Trô • 1.5 Ép-phê Trái',
          description:
              'Kéo nhẹ bi chủ sang ngang để chạm mỏng mặt trên bi Đỏ',
        ),
        strokeType: 'Đánh chắc tay (Lực 2.5/5)',
        speedLevel: 3,
        customCueSpeed: 1.70,
      ),
      objective:
          'Biến thế bi rời rạc giữa bàn thành thế 3 bi chụm sát nhau ở khu vực đầu ô cấm bằng cách mượn 2 băng góc cho bi số 1.',
      executionSteps: [
        'Ngắm 1/2 má trái bi Vàng sao cho bi Vàng đi vào nút băng số 12 trên băng dài rồi sang băng ngắn.',
        'Đặt đầu cơ ở 6h kèm 1.5 ép-phê trái để sau khi chạm bi Vàng, bi chủ bẻ ngang xuống chạm vào phần trên của bi Đỏ.',
        'Va chạm vào mặt trên của bi Đỏ sẽ vừa phanh bi chủ lại vừa đẩy nhẹ bi Đỏ về điểm hẹn với bi Vàng.',
      ],
      commonMistakes: [
        'Chạm vào mặt dưới của bi Đỏ khiến bi Đỏ bị đẩy lùi xuống góc dưới, làm 2 bi mục tiêu xa nhau hơn.',
        'Thiếu lực khiến bi Vàng chết ở băng ngắn mà chưa kịp ra tới điểm gom.',
      ],
    ),

    BilliardLesson(
      id: 'gb-03',
      code: 'GB-03',
      title: 'Đòn Lật bi gom về vùng Amery (Bricole / Renversé)',
      subtitle:
          'Dùng bi chủ đi 1 băng sau khi chạm bi 1 để gom cả 2 bi về điểm hẹn',
      category: LessonCategory.gathering,
      subCategory: 'Gom về góc Amery',
      difficulty: 'Nâng cao',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Gom bi về vùng Amery trước ô cấm',
        description:
            'Bi vàng chạy 1 băng lên trên, bi chủ đập băng lật về chạm bi đỏ',
        cueBall: Offset(1.6, 2.6),
        objectBall1: Offset(0.95, 2.1),
        objectBall2: Offset(1.10, 1.90),
        targetZoneCenter: Offset(0.64, 1.38),
        targetZoneRadius: 1.25,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneQuarter(
          side: ContactSide.left,
          description: 'Chạm mỏng 1/4 má trái để bi chủ đi vào băng ngắn',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 2.5,
          verticalTips: 1.5,
          customLabel: 'Trên tâm • 2.5 Ép-phê Phải',
          description:
              'Ép-phê thuận giúp bi chủ mở góc sau khi chạm băng ngắn',
        ),
        strokeType: 'Ra cơ mượt, đi hết ngọn cơ',
        speedLevel: 2,
        customCueSpeed: 1.10,
      ),
      objective:
          'Đưa toàn bộ 3 bi từ nửa bàn dưới tập kết về đúng "Điểm vàng Amery" (giao điểm vạch ô cấm với băng dài) để đánh seri lớn.',
      executionSteps: [
        'Ngắm 1/4 má trái bi Vàng: lực vừa đủ để bi Vàng chạy dọc lên băng dài rồi thả xuống điểm Amery.',
        'Cho 2.5 ép-phê phải trên bi chủ để sau khi chạm băng ngắn, bi chủ mở rộng góc đi lên chạm nhẹ vào má dưới bi Đỏ.',
      ],
      commonMistakes: [
        'Vào quá dày vào bi Vàng làm bi Vàng đập băng dài quá mạnh còn bi chủ không đủ đà tới bi Đỏ.',
      ],
    ),

    BilliardLesson(
      id: 'gb-04',
      code: 'GB-04',
      title: 'Gom bi Dọc băng ngắn (Rappel Bande Courte)',
      subtitle:
          'Thu hồi bi mục tiêu 1 đi hết chiều dài bàn (2 băng ngắn) về lại vùng góc',
      category: LessonCategory.gathering,
      subCategory: 'Gom bi 2 băng',
      difficulty: 'Trung cấp',
      isPhysicsVerified: false,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Gom bi Dọc bàn (Khứ hồi băng ngắn)',
        description:
            'Khi góc chạm quá thẳng không thể gạt ngang, cho bi vàng đi thẳng xuống băng ngắn đối diện quay về',
        cueBall: Offset(1.2, 1.3),
        objectBall1: Offset(2.3, 1.35),
        objectBall2: Offset(0.9, 1.1),
        targetZoneCenter: Offset(3.07, 1.35),
        targetZoneRadius: 4.60,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec(
          label: '7/8 trái (Gần tràn mặt)',
          fraction: 0.875,
          side: ContactSide.right,
          description:
              'Chạm thật dày để truyền lực cho bi Vàng đi hết chiều dài bàn rồi quay lại',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -1.0,
          verticalTips: -3.5,
          customLabel: '6h Trô sâu • 1 Ép-phê Trái',
          description:
              'Kéo bi chủ lùi xéo về chạm nhẹ vào bi Đỏ đang chờ ở góc',
        ),
        strokeType: 'Trô dứt khoát (Lực 4/5)',
        speedLevel: 4,
        customCueSpeed: 2.40,
      ),
      objective:
          'Giải quyết tình huống bi số 1 nằm thẳng hàng hướng ra giữa bàn: thay vì cố đánh mỏng làm hỏng bi, ta đánh dày Rétro cho bi 1 đi khứ hồi băng ngắn đối diện quay về góc.',
      executionSteps: [
        'Ngắm 7/8 trái (gần thẳng mặt) vào má phải của bi Vàng để bi Vàng chạy thẳng sang băng ngắn đối diện.',
        'Đặt mũi cơ thật thấp ở 6h kèm 1 ép-phê trái để kéo bi chủ lùi xéo lên trên chạm nhẹ vào bi Đỏ.',
        'Định lượng lực mức 4 sao cho bi Vàng sau khi bật băng ngắn đối diện sẽ lăn về dừng ngay trước vạch ô cấm.',
      ],
      commonMistakes: [
        'Sợ hụt nên vào quá mỏng (2/3 trái) làm bi Vàng chạm vào băng dài thay vì đi thẳng tới băng ngắn.',
      ],
    ),

    // =========================================================================
    // TAB 3: BỘ SỐ (DIAMOND SYSTEMS)
    // =========================================================================
    BilliardLesson(
      id: 'bs-01',
      code: 'BS-01',
      title: 'Hệ thống Bộ số 50 (Cơ bản 3 băng & Cứu bi)',
      subtitle:
          'Công thức kinh điển: Điểm Đứng (Cơ) - Điểm Ngắm (Băng 1) = Điểm Trúng (Băng 3)',
      category: LessonCategory.system,
      subCategory: 'Hệ thống 3 băng',
      difficulty: 'Cơ bản',
      isPhysicsVerified: true,
      systemFormula:
          'Điểm Băng 1 = Điểm Đứng (Chân cơ) − Điểm Trúng (Băng 3)',
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Hệ thống Bộ 50 (50 - 20 = 30)',
        description:
            'Đứng ở nút 50, muốn về nút 30 băng 3 -> Ngắm vào nút 20 trên băng đầu',
        cueBall: Offset(5.0, 3.6),
        objectBall1: Offset(5.8, 2.2),
        objectBall2: Offset(0.35, 3.72),
        showDiamondNumbers: true,
        showCornerZones: false,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneQuarter(
          side: ContactSide.left,
          description:
              'Chạm mỏng để bi chủ đi đúng tia ngắm về nút 20 băng dài',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 3.0,
          verticalTips: 1.0,
          customLabel: 'Trên tâm nhẹ • 3 Ép-phê Thuận',
          description:
              'Chuẩn bộ 50 yêu cầu 3 mũi ép-phê thuận (xoáy theo chiều băng)',
        ),
        strokeType: 'Ra cơ xuyên suốt, không bẻ cổ tay',
        speedLevel: 3,
        customCueSpeed: 2.80,
      ),
      objective:
          'Giải cứu những hình bi xa hoặc bị che mặt bi trong Libre bằng cách tính chính xác đường đi 3 băng về vùng có 2 bi mục tiêu.',
      executionSteps: [
        'Xác định Điểm Trúng trên băng dài thứ 3 (mỗi nút băng tương ứng 10 đơn vị: 10, 20, 30, 40...).',
        'Kéo tia từ Điểm Đứng của bi chủ qua điểm ngắm trên Băng 1 theo công thức: Băng 1 = Điểm Đứng - Điểm Trúng.',
        'Đặt đúng 3 mũi ép-phê thuận và đánh xuyên ngọn cơ để quỹ đạo không bị ngắn băng.',
      ],
      commonMistakes: [
        'Ngắm vào mép băng gỗ thay vì ngắm vào điểm nút băng (trên hệ thống Bộ 50 cần ngắm xuyên qua nút gỗ trên thành băng).',
        'Đánh quá mạnh hoặc rút cơ đột ngột làm đường bi từ băng 2 sang băng 3 bị trượt dài (dư điểm).',
      ],
    ),

    BilliardLesson(
      id: 'bs-02',
      code: 'BS-02',
      title: 'Bộ số Cộng 2 (Plus 2 System - Ngắn Dài Dài)',
      subtitle: 'Áp dụng khi bi chủ xuất phát từ băng ngắn đánh vào băng dài',
      category: LessonCategory.system,
      subCategory: 'Hệ thống Ngắn - Dài',
      difficulty: 'Trung cấp',
      isPhysicsVerified: false,
      systemFormula:
          'Điểm Ngắm (Băng dài 1) = Điểm Xuất phát (Băng ngắn) + 2 nút',
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Hệ thống Plus 2 (Ngắn - Dài - Dài)',
        description:
            'Xuất phát nút 10 băng ngắn + 20 = Ngắm nút 30 băng dài',
        cueBall: Offset(0.5, 1.0),
        objectBall1: Offset(1.4, 0.7),
        objectBall2: Offset(4.70, 3.75),
        showDiamondNumbers: true,
        showCornerZones: true,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneThird(
          side: ContactSide.right,
          description:
              'Mượn má bi Vàng để hướng bi chủ vào đúng nút 30 băng dài',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 2.5,
          verticalTips: 1.0,
          customLabel: 'Trên tâm • 2.5 Ép-phê Thuận',
          description:
              'Ép-phê thuận giúp bi chủ giữ độ bám khi qua băng thứ 2',
        ),
        strokeType: 'Đánh lăn tự nhiên (Lực 3/5)',
        speedLevel: 3,
        customCueSpeed: 2.30,
      ),
      objective:
          'Tính nhanh đường bi từ băng ngắn đi 2 băng dài về góc đối diện khi 2 bi mục tiêu nằm ở hai đầu bàn.',
      executionSteps: [
        'Đọc tọa độ xuất phát của bi chủ trên băng ngắn (1 nút = 10, 2 nút = 20).',
        'Cộng thêm 20 (tức 2 nút băng) để ra điểm cần ngắm trên băng dài đầu tiên.',
        'Sử dụng 2.5 ép-phê thuận và lực lăn đều.',
      ],
      commonMistakes: [
        'Đánh bi chủ bị nhảy hoặc trô nhẹ lúc đầu khiến góc phản xạ ở băng dài thứ nhất bị hẹp lại.',
      ],
    ),

    BilliardLesson(
      id: 'bs-03',
      code: 'BS-03',
      title: 'Bộ số Tia 1 băng chia đôi & Hiệu chỉnh Ép-phê',
      subtitle:
          'Cách tính góc tới - góc phản xạ kèm mỗi mũi ép-phê dịch chuyển 1/2 nút băng',
      category: LessonCategory.system,
      subCategory: 'Hệ thống 1 băng',
      difficulty: 'Cơ bản',
      isPhysicsVerified: true,
      systemFormula:
          'Điểm Băng = Trung bình cộng (Bi chủ + Bi đích) ± (0.5 nút × Số mũi Ép-phê)',
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Tia 1 băng có hiệu chỉnh Ép-phê',
        description:
            'Thêm 2 ép-phê phải giúp mở rộng góc ra thêm đúng 1 nút băng',
        cueBall: Offset(2.0, 3.2),
        objectBall1: Offset(3.15, 0.90),
        objectBall2: Offset(2.85, 1.21),
        showDiamondNumbers: true,
        showCornerZones: false,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.full(
          description:
              'Ngắm trực tiếp vào băng dài rồi mới trúng 2 bi mục tiêu (Bricole)',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 2.0,
          verticalTips: 0.5,
          customLabel: 'Tâm bi • 2 Ép-phê Phải',
          description:
              'Mỗi mũi ép-phê dịch điểm rơi trên băng đối diện khoảng 0.5 nút',
        ),
        strokeType: 'Đánh êm để ép-phê kịp ăn vào băng',
        speedLevel: 2,
        aimTargetDiamond: Offset(3.0, 0.0),
        customCueSpeed: 1.60,
      ),
      objective:
          'Xử lý các cú đánh A-băng (Bricole 1 băng) chính xác để vừa ghi điểm vừa không làm xáo trộn thế 2 bi mục tiêu đang đứng gần nhau.',
      executionSteps: [
        'Tìm trung điểm hình học giữa vị trí bi chủ và vị trí 2 bi đích.',
        'Nếu cần mở góc rộng hơn (để vào mặt đúng của bi đích), lùi điểm ngắm trên băng về gần mình 0.5 nút cho mỗi 1 mũi ép-phê thuận.',
        'Đánh lực 2/5 để cao su băng bắt hết độ xoáy ngang của bi chủ.',
      ],
      commonMistakes: [
        'Đánh quá mạnh làm bi chủ dội băng ra sớm trước khi ép-phê kịp phát huy tác dụng.',
      ],
    ),

    BilliardLesson(
      id: 'bs-04',
      code: 'BS-04',
      title: 'Hệ thống Tia Góc 2 Băng (Système du Coin)',
      subtitle:
          'Mượn 2 băng góc (Dài - Ngắn) để vòng sau lưng 2 bi đích đang dính nhau',
      category: LessonCategory.system,
      subCategory: 'Hệ thống 2 băng',
      difficulty: 'Trung cấp',
      isPhysicsVerified: false,
      systemFormula:
          'Ngắm nút 10–15 băng dài với 2 Ép-phê thuận → Ra đúng mép vạch ô cấm góc',
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Tia 2 băng góc vòng sau lưng bi',
        description:
            'Bi chủ chạm mỏng bi vàng, ăn 2 băng góc rồi vòng ra chạm bi đỏ từ phía sau',
        cueBall: Offset(3.1, 1.3),
        objectBall1: Offset(2.0, 0.8),
        objectBall2: Offset(1.8, 1.0),
        targetZoneCenter: Offset(1.03, 0.99),
        targetZoneRadius: 0.95,
        showDiamondNumbers: true,
        showCornerZones: true,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneQuarter(
          side: ContactSide.right,
          description:
              'Chạm 1/4 má phải để bi Vàng chỉ nhích nhẹ về phía bi Đỏ',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -2.0,
          verticalTips: 1.0,
          customLabel: 'Trên tâm • 2 Ép-phê Trái (Thuận)',
          description: '2 mũi ép-phê trái giúp bi chủ ôm gọn 2 băng góc quay ra',
        ),
        strokeType: 'Đánh mềm tay (Lực 2/5)',
        speedLevel: 2,
        customCueSpeed: 1.30,
      ),
      objective:
          'Khi 2 bi đích đã ở gần nhau nhưng góc trực tiếp sẽ đẩy bi số 1 đi mất: mượn 2 băng góc cho bi chủ để giữ cả 3 bi lại đầu vạch ô cấm.',
      executionSteps: [
        'Ngắm 1/4 má phải của bi Vàng để hướng bi chủ vào khoảng nút 11 trên băng dài.',
        'Cho 2 mũi ép-phê thuận (trái) để sau khi qua băng ngắn, bi chủ lăn êm về chạm vào mặt sau của bi Đỏ.',
      ],
      commonMistakes: [
        'Cho quá nhiều ép-phê (4 mũi) làm bi chủ mở góc quá rộng, trượt qua phía dưới bi Đỏ.',
      ],
    ),

    // =========================================================================
    // TAB 4: SERI & DẪN BI (SERIE & RAIL CONTROL)
    // =========================================================================
    BilliardLesson(
      id: 'sr-01',
      code: 'SR-01',
      title: 'Thế bi Mắt kính dọc băng (Les Lunettes)',
      subtitle:
          'Cách duy trì và tái tạo thế 2 bi đứng song song cách băng 5–8cm',
      category: LessonCategory.serie,
      subCategory: 'Seri dọc băng',
      difficulty: 'Cơ bản',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Thế bi Mắt kính (Lunettes) dọc băng dài',
        description:
            'Chạm mỏng bi ngoài, mượn băng dài chạm nhẹ bi trong để lặp lại mắt kính',
        cueBall: Offset(2.55, 0.52),
        objectBall1: Offset(3.20, 0.68),
        objectBall2: Offset(3.30, 1.10),
        targetZoneCenter: Offset(3.72, 1.11),
        targetZoneRadius: 1.00,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneQuarter(
          side: ContactSide.left,
          description:
              'Chạm 1/4 má ngoài bi Vàng rồi mượn nhẹ băng dài chạm bi Đỏ',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: -1.5,
          verticalTips: 0.5,
          customLabel: 'Tâm bi • 1.5 Ép-phê Nghịch',
          description:
              'Ép-phê nghịch giúp hãm bi chủ đứng lại ngay sau hai bi mục tiêu',
        ),
        strokeType: 'Chạm nhẹ cảm giác đầu cơ (Lực 1/5)',
        speedLevel: 1,
        customCueSpeed: 0.75,
      ),
      objective:
          'Giữ 2 bi mục tiêu luôn đi song song như gọng mắt kính dọc theo băng dài, mỗi lần đánh chỉ nhích lên 4–6cm.',
      executionSteps: [
        'Luôn ưu tiên chạm vào viên bi nằm phía ngoài (xa băng hơn) trước để đưa nó tiến lên 5cm.',
        'Cho 1.5 ép-phê nghịch để sau khi bi chủ chạm băng dài sẽ hãm tốc, chạm rất nhẹ vào viên bi sát băng rồi dừng lại phía sau.',
        'Kết quả sau cú đánh: 2 bi đích lại tạo thành cặp mắt kính mới chỉ nhích lên vài cm.',
      ],
      commonMistakes: [
        'Không dùng ép-phê nghịch khiến bi chủ vọt lên phía trước hai bi mục tiêu (mất thế đứng sau lưng bi).',
      ],
    ),

    BilliardLesson(
      id: 'sr-02',
      code: 'SR-02',
      title: 'Xoay sở qua vạch Ô cấm góc (Passage du Coin)',
      subtitle:
          'Cách bước ra và bước vào ô cấm góc đúng luật (Tối đa 2 điểm trong ô)',
      category: LessonCategory.serie,
      subCategory: 'Seri trong góc',
      difficulty: 'Trung cấp',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Đưa bi số 1 ra khỏi vạch ô cấm (Sortie de Zone)',
        description:
            'Ở điểm thứ 2 trong ô cấm, bắt buộc đẩy ít nhất 1 bi đích vượt qua vạch trắng',
        cueBall: Offset(0.95, 0.52),
        objectBall1: Offset(1.55, 0.32),
        objectBall2: Offset(1.70, 0.50),
        targetZoneCenter: Offset(1.82, 0.42),
        targetZoneRadius: 0.52,
        showCornerZones: true,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.half(
          side: ContactSide.left,
          description:
              'Chạm 1/2 má trái để đẩy bi Vàng bước qua vạch ô cấm 3–5cm',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 0.0,
          verticalTips: -1.5,
          customLabel: '6h nhẹ • Không ép-phê',
          description: 'Kéo nhẹ sang chạm bi Đỏ và giữ bi chủ ngay sát mép vạch',
        ),
        strokeType: 'Kiểm soát chính xác độ lăn của bi Vàng',
        speedLevel: 1,
        customCueSpeed: 0.80,
      ),
      objective:
          'Tuân thủ luật vùng giới hạn góc Libre (71×35.5cm): ở cú đánh thứ 2 khi cả 2 bi đích nằm trong ô, phải đưa ít nhất 1 bi đích bước qua vạch rồi kéo trở lại ở nhịp sau.',
      executionSteps: [
        'Quan sát vị trí vạch phấn ô cấm (cách góc 71cm trên băng dài và 35.5cm trên băng ngắn).',
        'Khi thực hiện điểm thứ 2 trong ô (Entrée -> Dedans), chạm 1/2 vào bi Vàng nằm gần vạch hơn để nó lăn qua vạch khoảng 3–5cm.',
        'Ở cú đánh tiếp theo, mượn băng dài đưa bi Vàng quay ngược lại vào đầu vạch để lặp lại chu kỳ vô hạn.',
      ],
      commonMistakes: [
        'Đẩy bi Vàng quá nhẹ khiến bi dừng ngay trên vạch nhưng chưa vượt qua vạch (trọng tài tính phạm lỗi).',
        'Đẩy quá mạnh làm bi Vàng trôi xa hơn 25cm, phải tốn thêm một nhịp gom bi.',
      ],
    ),

    BilliardLesson(
      id: 'sr-03',
      code: 'SR-03',
      title: 'Nhịp Bắc cầu qua vạch Amery (Le Chevalet)',
      subtitle:
          'Giữ 1 bi trong ô cấm, 1 bi ngoài ô cấm để đánh liên hoàn không bị giới hạn',
      category: LessonCategory.serie,
      subCategory: 'Seri trong góc',
      difficulty: 'Nâng cao',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Thế bi Bắc cầu (Chevalet) trên vạch ô cấm',
        description:
            'Bi đỏ nằm trong vạch, bi vàng nằm ngoài vạch: mượn băng dài cho bi vàng nhảy qua lại vạch',
        cueBall: Offset(2.38, 0.56),
        objectBall1: Offset(1.98, 0.28),
        objectBall2: Offset(1.60, 0.50),
        targetZoneCenter: Offset(1.14, 0.55),
        targetZoneRadius: 0.95,
        showCornerZones: true,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec.oneThird(
          side: ContactSide.right,
          description:
              'Chạm 1/3 má phải để bi Vàng chạm nhẹ băng dài rồi nảy ra',
        ),
        effet: CueBallEffetSpec.fromTips(
          horizontalTips: 0.5,
          verticalTips: 0.5,
          customLabel: 'Tâm bi • 0.5 Ép-phê Phải',
          description: 'Giữ tốc độ bi chủ cực êm để dừng ngay cạnh bi Đỏ',
        ),
        strokeType: 'Đánh chạm nhẹ bằng ngón tay cầm cơ (Lực 1/5)',
        speedLevel: 1,
        customCueSpeed: 0.80,
      ),
      objective:
          'Bí quyết của các cơ thủ Libre chuyên nghiệp (Xavier Gretillat): giữ 2 bi đích "cưỡi" hai bên vạch ô cấm góc để ghi hàng trăm điểm tại một góc bàn.',
      executionSteps: [
        'Đặt góc ngắm sao cho bi Vàng đập nhẹ vào băng dài ngay tại giao điểm vạch ô cấm (cách góc 71cm).',
        'Lực chạm thật mềm để bi Vàng chỉ nảy ra cách băng 4–5cm, trong khi bi Đỏ chỉ nhích 1cm.',
        'Luân phiên đưa 1 bi qua vạch ở mỗi 1–2 nhịp để không bao giờ vi phạm luật ô cấm.',
      ],
      commonMistakes: [
        'Đánh quá mạnh làm cả 2 bi chui sâu vào góc bàn, khó kéo ngược trở ra vạch.',
      ],
    ),

    BilliardLesson(
      id: 'rp-01',
      code: 'RP-01',
      title: 'Trô Kéo Về Cơ Bản 2/3 Bi (Rappel de base 2/3 de bille)',
      subtitle:
          'Chạm 2/3 bi má phải, hạ thấp đầu cơ dưới tâm -9.5mm, bi 2 chạy 2 chiều dài bàn hồi về góc',
      category: LessonCategory.gathering,
      subCategory: 'Kéo về (Rappel cơ bản)',
      difficulty: 'Dễ (Facile)',
      isPhysicsVerified: true,
      diagram: const TableDiagramSpec(
        label: 'Sơ đồ Rappel de base 2/3 bi hồi về góc bàn',
        description:
            'Bi chủ trô lùi giật xuống góc phải chạm bi 3, bi 2 chạy lên băng ngắn trên và hồi về vùng gom bi quanh bi 3',
        cueBall: Offset(6.567, 2.493),
        objectBall1: Offset(6.000, 2.6667),
        objectBall2: Offset(7.710, 3.644),
        targetZoneCenter: Offset(7.710, 3.644),
        targetZoneRadius: 0.95,
      ),
      shotParams: ShotParameters(
        contact: BallContactSpec(
          label: '2/3 trái',
          fraction: 2.0 / 3.0,
          side: ContactSide.right,
          description:
              'Chạm 2/3 má phải theo đúng tài liệu gốc (Quantité de bille: 2/3 de bille)',
        ),
        effet: CueBallEffetSpec.fromMm(
          xMm: 0.0,
          zMm: -9.5,
          customLabel: 'Dưới tâm -9.5mm (Hauteur basse)',
          description:
              'Không ép-phê ngang (Effet: aucun), hạ mũi cơ thấp dưới tâm để tạo lực trô lùi mạnh',
        ),
        strokeType: 'Đâm xuyên êm mượt (Énergie: fort - vitesse normale)',
        speedLevel: 3,
        customCueSpeed: 2.70,
      ),
      objective:
          'Bài học nền tảng số 1 về kỹ thuật kéo về (Rappel de base): Bi 2 chạy quãng đường gần 2 lần chiều dài bàn (~1.8L) rồi hồi về tụ bi sát góc cùng Bi 3.',
      executionSteps: [
        'Cầu tay đặt cách bi chủ 12–15cm, mũi cơ hạ thấp -9.5mm so với tâm (vùng an toàn Dr. Dave).',
        'Ngắm ngọn cơ vào má phải bi 2 sao cho độ dày che phủ đạt chính xác 2/3 trái.',
        'Tuyệt đối không để ép-phê ngang (Effet: aucun).',
        'Ra cơ với tốc độ bình thường (vitesse normale) nhưng đâm xuyên sâu, tạo lực cấp 3 để bi 2 đủ đà chạy 2 chiều dài bàn.',
      ],
      commonMistakes: [
        'Để vô tình ép-phê ngang làm bi 2 lệch hướng không lên đúng đỉnh băng ngắn trên.',
        'Đánh quá mỏng (1/2 trái) khiến bi 2 thiếu lực chạy không đủ 2 chiều dài bàn.',
        'Đầu cơ không đủ thấp khiến bi chủ không giật lùi về được bi 3.',
      ],
    ),
  ];

  static List<BilliardLesson> byCategory(LessonCategory category) {
    return lessons.where((l) => l.category == category).toList();
  }
}
