import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/billiard_lesson.dart';

/// Snapshot dữ liệu Sổ tay cá nhân được lưu bền cục bộ (kèm kiểm soát `schemaVersion`).
class NotebookPersistedState {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Set<String> bookmarkedIds;
  final Map<String, int> practiceCounts;
  final Map<String, String> personalNotes;
  final List<BilliardLesson> customLessons;
  final int customLessonCounter;
  final bool isReadOnly;
  final String? readOnlyReason;

  const NotebookPersistedState({
    this.schemaVersion = currentSchemaVersion,
    required this.bookmarkedIds,
    required this.practiceCounts,
    required this.personalNotes,
    required this.customLessons,
    required this.customLessonCounter,
    this.isReadOnly = false,
    this.readOnlyReason,
  });

  factory NotebookPersistedState.initialDefaults() {
    return const NotebookPersistedState(
      schemaVersion: currentSchemaVersion,
      bookmarkedIds: {'kt-01', 'gb-01', 'sr-01'},
      practiceCounts: {
        'kt-01': 5,
        'gb-01': 3,
        'sr-01': 8,
      },
      personalNotes: {
        'kt-01':
            'Cầu tay đặt sát 10cm, dừng ngọn cơ ngay sau khi chạm bi chủ.',
      },
      customLessons: [],
      customLessonCounter: 1,
      isReadOnly: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'bookmarkedIds': bookmarkedIds.toList(),
        'practiceCounts': practiceCounts,
        'personalNotes': personalNotes,
        'customLessons': customLessons.map((l) => l.toJson()).toList(),
        'customLessonCounter': customLessonCounter,
      };

  factory NotebookPersistedState.fromJson(
    Map<String, dynamic> json, {
    bool isReadOnly = false,
    String? readOnlyReason,
  }) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version < 1) {
      return NotebookPersistedState.initialDefaults();
    }

    final rawBookmarks = json['bookmarkedIds'];
    final bookmarks = rawBookmarks is List
        ? rawBookmarks.map((e) => e.toString()).toSet()
        : <String>{'kt-01', 'gb-01', 'sr-01'};

    final rawCounts = json['practiceCounts'];
    final counts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final v = entry.value;
        if (v is num) {
          counts[entry.key.toString()] = v.toInt();
        }
      }
    }

    final rawNotes = json['personalNotes'];
    final notes = <String, String>{};
    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        final v = entry.value?.toString() ?? '';
        if (v.isNotEmpty) {
          notes[entry.key.toString()] = v;
        }
      }
    }

    final rawCustom = json['customLessons'];
    final customList = <BilliardLesson>[];
    if (rawCustom is List) {
      for (final item in rawCustom) {
        if (item is Map<String, dynamic>) {
          customList.add(BilliardLesson.fromJson(item));
        } else if (item is Map) {
          customList.add(
            BilliardLesson.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final counter = ((json['customLessonCounter'] as num?)?.toInt() ??
            (customList.length + 1))
        .clamp(1, 99999);

    return NotebookPersistedState(
      schemaVersion: currentSchemaVersion,
      bookmarkedIds: bookmarks,
      practiceCounts: counts,
      personalNotes: notes,
      customLessons: customList,
      customLessonCounter: counter,
      isReadOnly: isReadOnly,
      readOnlyReason: readOnlyReason,
    );
  }
}

/// Quản lý đọc/ghi bền vững dữ liệu Sổ tay (Bookmark, Lượt tập, Ghi chú, Hình bi tự tạo)
/// với kiểm tra schema/version và xử lý an toàn khi file hỏng hoặc lỗi I/O.
class NotebookStorage {
  final File? overrideFile;

  const NotebookStorage({this.overrideFile});

  /// Lấy file lưu trữ theo thư mục ứng dụng chính thức của nền tảng (asynchronous),
  /// có fallback tự động đồng bộ khi chạy trong môi trường test/CLI.
  Future<File> resolveStorageFile() async {
    if (overrideFile != null) return overrideFile!;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return File('${appDir.path}${Platform.pathSeparator}notebook_state_v1.json');
    } catch (_) {
      return _resolveStorageFileSync();
    }
  }

  File _resolveStorageFileSync() {
    if (overrideFile != null) return overrideFile!;

    if (Platform.isAndroid) {
      const androidAppDir = '/data/data/com.example.xavier_billiard_libre/files';
      try {
        final dir = Directory(androidAppDir);
        if (dir.existsSync() ||
            Directory('/data/data/com.example.xavier_billiard_libre')
                .existsSync()) {
          dir.createSync(recursive: true);
          return File('$androidAppDir/notebook_state_v1.json');
        }
      } catch (_) {}
    }

    // Windows: %LOCALAPPDATA% or %APPDATA%
    final localAppData = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final appDir = Directory(
        '$localAppData${Platform.pathSeparator}XavierBilliardLibre',
      );
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }
      return File('${appDir.path}${Platform.pathSeparator}notebook_state_v1.json');
    }

    // macOS/Linux: HOME/.local/share or Library
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final baseDir = Platform.isMacOS
          ? '$home/Library/Application Support/XavierBilliardLibre'
          : '$home/.local/share/xavier_billiard_libre';
      final appDir = Directory(baseDir);
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }
      return File('${appDir.path}${Platform.pathSeparator}notebook_state_v1.json');
    }

    // Fallback: working directory data/
    final fallbackDir = Directory('data');
    if (!fallbackDir.existsSync()) {
      fallbackDir.createSync(recursive: true);
    }
    return File('data/notebook_state_v1.json');
  }

  /// Đọc dữ liệu Sổ tay đã lưu; nếu file hỏng (JSON parse error) thì backup thành `.corrupted.bak`
  /// trước khi trả về mặc định; nếu file có schemaVersion tương lai thì không ghi đè và chuyển chế độ Read-Only.
  Future<NotebookPersistedState> loadState() async {
    try {
      final file = await resolveStorageFile();
      if (!file.existsSync()) {
        return NotebookPersistedState.initialDefaults();
      }
      final rawContent = file.readAsStringSync();
      if (rawContent.trim().isEmpty) {
        return NotebookPersistedState.initialDefaults();
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(rawContent);
      } catch (parseError) {
        // Sao lưu file hỏng thành .corrupted.bak để người dùng không mất dữ liệu thô
        try {
          final bakFile = File('${file.path}.corrupted.bak');
          bakFile.writeAsStringSync(rawContent, flush: true);
        } catch (_) {}
        return NotebookPersistedState.initialDefaults();
      }

      if (decoded is Map<String, dynamic> || decoded is Map) {
        final map = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);

        final version = (map['schemaVersion'] as num?)?.toInt() ?? 1;
        if (version > NotebookPersistedState.currentSchemaVersion) {
          // Phiên bản dữ liệu mới hơn ứng dụng hiện tại -> bảo lưu file, tạo bản sao backup và chuyển Read-Only
          try {
            final futureBak = File('${file.path}.future_v$version.bak');
            futureBak.writeAsStringSync(rawContent, flush: true);
          } catch (_) {}
          return NotebookPersistedState.fromJson(
            map,
            isReadOnly: true,
            readOnlyReason:
                'Dữ liệu được tạo bởi phiên bản LibreBilliard mới hơn (schema v$version). '
                'Ứng dụng đang ở chế độ chỉ đọc để tránh làm mất các trường dữ liệu mới.',
          );
        }

        return NotebookPersistedState.fromJson(map);
      }

      return NotebookPersistedState.initialDefaults();
    } catch (_) {
      return NotebookPersistedState.initialDefaults();
    }
  }

  /// Lưu dữ liệu Sổ tay xuống bộ nhớ cục bộ một cách nguyên tử (atomic temp write).
  /// Có Write Guard chặn tuyệt đối ghi đè hạ cấp file có schemaVersion tương lai.
  Future<bool> saveState(NotebookPersistedState state) async {
    try {
      // Write Guard 1: Trạng thái hiện tại đang ở chế độ Read-Only do schema tương lai
      if (state.isReadOnly) {
        return false;
      }

      final file = await resolveStorageFile();

      // Write Guard 2: Kiểm tra file hiện có trên đĩa; nếu có schemaVersion tương lai thì từ chối ghi đè
      if (file.existsSync()) {
        try {
          final diskRaw = file.readAsStringSync();
          if (diskRaw.trim().isNotEmpty) {
            final diskDecoded = jsonDecode(diskRaw);
            if (diskDecoded is Map) {
              final diskVersion =
                  (diskDecoded['schemaVersion'] as num?)?.toInt() ?? 1;
              if (diskVersion > NotebookPersistedState.currentSchemaVersion) {
                // Từ chối ghi đè hạ cấp, giữ nguyên byte file chính
                return false;
              }
            }
          }
        } catch (_) {}
      }

      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final encoded = const JsonEncoder.withIndent('  ').convert(state.toJson());
      final tempFile = File('${file.path}.tmp');
      tempFile.writeAsStringSync(encoded, flush: true);
      tempFile.renameSync(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
