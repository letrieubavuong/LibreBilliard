import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xavier_billiard_libre/data/notebook_storage.dart';
import 'package:xavier_billiard_libre/screens/home_screen.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/ball_contact_diagram.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/carom_table_diagram.dart';
import 'package:xavier_billiard_libre/widgets/diagrams/cue_ball_effet_diagram.dart';

void main() {
  testWidgets('Xavier Billiard Libre renders Bottom Bar & reusable diagrams',
      (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('xavier_widget_test_');
    final storage = NotebookStorage(
      overrideFile: File('${tempDir.path}/widget_test_notebook.json'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage),
      ),
    );

    // Kiểm tra các tab trên Bottom Bar
    expect(find.text('Kĩ thuật'), findsWidgets);
    expect(find.text('Hình gom bi'), findsOneWidget);
    expect(find.text('Bộ số'), findsOneWidget);
    expect(find.text('Seri & Góc'), findsOneWidget);
    expect(find.text('Sổ tay'), findsOneWidget);

    // Kiểm tra các sơ đồ kế thừa được tái sử dụng trên danh sách bài học
    expect(find.byType(CaromTableDiagram), findsWidgets);
    expect(find.byType(BallContactDiagram), findsWidgets);
    expect(find.byType(CueBallEffetDiagram), findsWidgets);

    // Chuyển sang tab Hình gom bi
    await tester.tap(find.text('Hình gom bi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gom bi 1 băng dọc'), findsOneWidget);

    // Chuyển sang tab Bộ số
    await tester.tap(find.text('Bộ số'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MÁY TÍNH BỘ SỐ'), findsOneWidget);

    tempDir.deleteSync(recursive: true);
  });
}
