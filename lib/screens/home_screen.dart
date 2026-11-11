import 'package:flutter/material.dart';
import '../data/notebook_storage.dart';
import '../data/sample_lessons.dart';
import '../models/billiard_lesson.dart';
import '../widgets/diagrams/base_billiard_diagram.dart';
import '../widgets/lesson_card.dart';
import '../widgets/system_calculator_card.dart';
import 'custom_position_builder_screen.dart';
import 'flashcard_drill_screen.dart';
import 'lesson_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final NotebookStorage storage;

  const HomeScreen({
    super.key,
    this.storage = const NotebookStorage(),
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  String _searchQuery = '';
  String? _selectedSubCategory;

  final List<BilliardLesson> _customLessons = [];
  int _customLessonCounter = 1;

  // Lưu trạng thái Bookmark, Số lượt tập luyện và Ghi chú cá nhân
  final Set<String> _bookmarkedIds = {'kt-01', 'gb-01', 'sr-01'};
  final Map<String, int> _practiceCounts = {
    'kt-01': 5,
    'gb-01': 3,
    'sr-01': 8,
  };
  final Map<String, String> _personalNotes = {
    'kt-01': 'Cầu tay đặt sát 10cm, dừng ngọn cơ ngay sau khi chạm bi chủ.',
  };

  List<BilliardLesson> get _allLessons => [
        ..._customLessons,
        ...SampleLessonsRepository.lessons,
      ];

  @override
  void initState() {
    super.initState();
    _loadPersistedNotebookState();
  }

  Future<void> _loadPersistedNotebookState() async {
    final loaded = await widget.storage.loadState();
    if (!mounted) return;
    setState(() {
      _bookmarkedIds
        ..clear()
        ..addAll(loaded.bookmarkedIds);
      _practiceCounts
        ..clear()
        ..addAll(loaded.practiceCounts);
      _personalNotes
        ..clear()
        ..addAll(loaded.personalNotes);
      _customLessons
        ..clear()
        ..addAll(loaded.customLessons);
      _customLessonCounter = loaded.customLessonCounter;
    });
  }

  Future<bool> _persistCurrentNotebookState() async {
    final snapshot = NotebookPersistedState(
      bookmarkedIds: Set<String>.from(_bookmarkedIds),
      practiceCounts: Map<String, int>.from(_practiceCounts),
      personalNotes: Map<String, String>.from(_personalNotes),
      customLessons: List<BilliardLesson>.from(_customLessons),
      customLessonCounter: _customLessonCounter,
    );
    final ok = await widget.storage.saveState(snapshot);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Không thể lưu dữ liệu sổ tay vào bộ nhớ thiết bị!'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return ok;
  }

  void _toggleBookmark(String id) {
    setState(() {
      if (_bookmarkedIds.contains(id)) {
        _bookmarkedIds.remove(id);
      } else {
        _bookmarkedIds.add(id);
      }
    });
    _persistCurrentNotebookState();
  }

  void _incrementPractice(String id) {
    setState(() {
      _practiceCounts[id] = (_practiceCounts[id] ?? 0) + 1;
    });
    _persistCurrentNotebookState();
  }

  void _savePersonalNote(String id, String note) {
    setState(() {
      if (note.isEmpty) {
        _personalNotes.remove(id);
      } else {
        _personalNotes[id] = note;
      }
    });
    _persistCurrentNotebookState();
  }

  void _openLessonDetail(BilliardLesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          lesson: lesson,
          isBookmarked: _bookmarkedIds.contains(lesson.id),
          practiceCount: _practiceCounts[lesson.id] ?? 0,
          personalNote: _personalNotes[lesson.id],
          onToggleBookmark: () => _toggleBookmark(lesson.id),
          onIncrementPractice: () => _incrementPractice(lesson.id),
          onSavePersonalNote: (note) async {
            _savePersonalNote(lesson.id, note);
            return await _persistCurrentNotebookState();
          },
        ),
      ),
    );
  }

  void _openFlashcardDrills(List<BilliardLesson> pool) {
    if (pool.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardDrillScreen(
          lessons: pool,
          onMarkPracticed: _incrementPractice,
        ),
      ),
    );
  }

  Future<void> _openCustomPositionBuilder() async {
    final created = await Navigator.of(context).push<BilliardLesson>(
      MaterialPageRoute(
        builder: (_) => CustomPositionBuilderScreen(
          nextCustomIndex: _customLessonCounter,
        ),
      ),
    );
    if (created != null) {
      setState(() {
        _customLessons.insert(0, created);
        _bookmarkedIds.add(created.id);
        _customLessonCounter++;
      });
      final ok = await _persistCurrentNotebookState();
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã lưu "${created.title}" vào Sổ tay & ${created.category.title}!',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNotebookTab = _currentTabIndex == 4;
    final currentCategory =
        isNotebookTab ? null : LessonCategory.values[_currentTabIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xavier Billiard Libre',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              isNotebookTab
                  ? 'Sổ tay lưu trữ, Đố hình bi & Bàn thử nghiệm'
                  : currentCategory!.subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đố hình bi (Flashcard Quiz)',
            onPressed: () => _openFlashcardDrills(_allLessons),
            icon: const Icon(
              Icons.quiz_outlined,
              color: BilliardPalette.diamondGold,
            ),
          ),
        ],
      ),
      floatingActionButton: isNotebookTab
          ? FloatingActionButton.extended(
              onPressed: _openCustomPositionBuilder,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Tạo hình bi riêng'),
            )
          : null,
      body: isNotebookTab
          ? _buildNotebookTab()
          : _buildCategoryTab(currentCategory!),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
            _selectedSubCategory = null;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_handball_outlined),
            selectedIcon: Icon(Icons.sports_handball),
            label: 'Kĩ thuật',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Hình gom bi',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Bộ số',
          ),
          NavigationDestination(
            icon: Icon(Icons.all_inclusive_outlined),
            selectedIcon: Icon(Icons.all_inclusive),
            label: 'Seri & Góc',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Sổ tay',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(LessonCategory category) {
    final allInCategory =
        _allLessons.where((l) => l.category == category).toList();
    final subCategories =
        allInCategory.map((e) => e.subCategory).toSet().toList();

    final filtered = allInCategory.where((lesson) {
      final matchesSub = _selectedSubCategory == null ||
          lesson.subCategory == _selectedSubCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          lesson.title.toLowerCase().contains(q) ||
          lesson.subtitle.toLowerCase().contains(q) ||
          lesson.code.toLowerCase().contains(q);
      return matchesSub && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText:
                'Tìm trong ${category.title} (VD: Rétro, Amery, Bộ 50...)',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: BilliardPalette.cardBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BilliardPalette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BilliardPalette.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Tất cả (${allInCategory.length})'),
                  selected: _selectedSubCategory == null,
                  onSelected: (_) =>
                      setState(() => _selectedSubCategory = null),
                ),
              ),
              ...subCategories.map((sub) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(sub),
                    selected: _selectedSubCategory == sub,
                    onSelected: (_) =>
                        setState(() => _selectedSubCategory = sub),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (category == LessonCategory.system)
          const DiamondSystemCalculatorCard(),
        ...filtered.map((lesson) {
          return LessonCard(
            lesson: lesson,
            isBookmarked: _bookmarkedIds.contains(lesson.id),
            practiceCount: _practiceCounts[lesson.id] ?? 0,
            personalNote: _personalNotes[lesson.id],
            onTap: () => _openLessonDetail(lesson),
            onToggleBookmark: () => _toggleBookmark(lesson.id),
          );
        }),
      ],
    );
  }

  Widget _buildNotebookTab() {
    final bookmarkedLessons =
        _allLessons.where((l) => _bookmarkedIds.contains(l.id)).toList();
    final totalPractice =
        _practiceCounts.values.fold<int>(0, (sum, item) => sum + item);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BilliardPalette.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BilliardPalette.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                    value: '${bookmarkedLessons.length}',
                    label: 'Hình bi đã lưu',
                    icon: Icons.bookmark,
                  ),
                  _StatColumn(
                    value: '$totalPractice',
                    label: 'Tổng lượt tập',
                    icon: Icons.sports_score,
                  ),
                  _StatColumn(
                    value: '${_allLessons.length}',
                    label: 'Tổng bài học',
                    icon: Icons.library_books,
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openFlashcardDrills(_allLessons),
                      icon: const Icon(Icons.quiz_outlined, size: 18),
                      label: const Text(
                        'Đố hình bi (Quiz)',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCustomPositionBuilder,
                      icon: const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        'Tự xếp hình bi',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const ShotSandboxCard(),
        const SizedBox(height: 18),
        const Text(
          'HÌNH BI ĐÃ LƯU TRONG SỔ TAY',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: BilliardPalette.diamondGold,
          ),
        ),
        const SizedBox(height: 10),
        if (bookmarkedLessons.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BilliardPalette.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BilliardPalette.cardBorder),
            ),
            child: const Text(
              'Chưa có hình bi nào được đánh dấu.\nBấm biểu tượng Bookmark trên mỗi bài học để lưu vào đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          ...bookmarkedLessons.map((lesson) {
            return LessonCard(
              lesson: lesson,
              isBookmarked: true,
              practiceCount: _practiceCounts[lesson.id] ?? 0,
              personalNote: _personalNotes[lesson.id],
              onTap: () => _openLessonDetail(lesson),
              onToggleBookmark: () => _toggleBookmark(lesson.id),
            );
          }),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: BilliardPalette.diamondGold, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}
