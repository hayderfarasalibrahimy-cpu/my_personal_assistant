import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/note.dart';
import '../widgets/task_card.dart';
import '../widgets/note_card.dart';

String _normalizeArabic(String input) {
  var s = input.toLowerCase().trim();
  s = s.replaceAll(
    RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
    '',
  );
  s = s.replaceAll(RegExp(r'\u0640'), '');
  s = s
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ئ', 'ي')
      .replaceAll('ؤ', 'و');
  s = s.replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

int _scoreMatch({required String query, required String candidate}) {
  final q = _normalizeArabic(query);
  final c = _normalizeArabic(candidate);
  if (q.isEmpty || c.isEmpty) return 0;
  if (c == q) return 100;
  if (c.startsWith(q)) return 90;
  if (c.contains(q)) return 80;
  final qWords = q.split(' ').where((w) => w.isNotEmpty).toList();
  final cWords = c.split(' ').where((w) => w.isNotEmpty).toList();
  if (qWords.isEmpty || cWords.isEmpty) return 0;
  var hits = 0;
  for (final w in qWords) {
    if (cWords.any((cw) => cw.contains(w) || w.contains(cw))) {
      hits++;
    }
  }
  return hits;
}

List<String> _generateQueryVariants(String query, {int max = 25}) {
  final variants = <String>[];
  void add(String s) {
    final v = _normalizeArabic(s);
    if (v.isEmpty) return;
    if (!variants.contains(v)) variants.add(v);
  }

  add(query);
  var q = _normalizeArabic(query);
  if (q.startsWith('ال') && q.length > 2) {
    add(q.substring(2));
  }
  q = q.replaceAll('ال ', '');
  add(q);

  final words = q.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length > 1) {
    for (final w in words) {
      add(w);
      if (w.startsWith('ال') && w.length > 2) add(w.substring(2));
    }
    for (var i = 0; i < words.length - 1; i++) {
      add('${words[i]} ${words[i + 1]}');
    }
  }

  final synonyms = <String, List<String>>{
    'انترنت': ['النت', 'الانترنت', 'نت', 'شبكه', 'شبكة'],
    'واي': ['wifi', 'واي فاي', 'وايفاي'],
    'واي فاي': ['wifi', 'وايفاي', 'واي'],
    'شراء': ['تسوق', 'تسوّق', 'مشتريات'],
    'تسوق': ['شراء', 'مشتريات'],
    'دفع': ['سداد', 'تسديد', 'دفعة'],
    'فاتوره': ['فاتورة', 'حساب'],
    'فاتورة': ['فاتوره', 'حساب'],
    'اتصال': ['مكالمة', 'تليفون', 'هاتف'],
    'مكالمة': ['اتصال', 'تليفون', 'هاتف'],
    'دواء': ['علاج', 'حبة', 'حبوب'],
  };

  for (final w in words) {
    final key = _normalizeArabic(w);
    final alKey = key.startsWith('ال') && key.length > 2
        ? key.substring(2)
        : key;
    for (final k in [key, alKey]) {
      final list = synonyms[k];
      if (list != null) {
        for (final s in list) {
          add(s);
        }
      }
    }
  }

  if (variants.length > max) {
    return variants.take(max).toList();
  }
  return variants;
}

// ==================== TASK SEARCH ====================
class TaskSearchDelegate extends SearchDelegate {
  final List<Task> tasks;

  TaskSearchDelegate({required this.tasks});

  @override
  String get searchFieldLabel => 'بحث في المهام...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final variants = _generateQueryVariants(query, max: 25);
    final scores = <String, int>{};
    final byId = <String, Task>{};

    for (final v in variants) {
      for (final task in tasks) {
        final s1 = _scoreMatch(query: v, candidate: task.title);
        final s2 = _scoreMatch(query: v, candidate: task.description);
        final s3 = _scoreMatch(query: v, candidate: task.category);
        var score = s1;
        if (s2 > score) score = s2;
        if (s3 > score) score = s3;
        if (score <= 0) continue;
        final prev = scores[task.id] ?? 0;
        if (score > prev) {
          scores[task.id] = score;
          byId[task.id] = task;
        }
      }
    }

    final ids = byId.keys.toList();
    ids.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    final results = ids.map((id) => byId[id]!).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return TaskCard(task: results[index]);
      },
    );
  }
}

// ==================== NOTE SEARCH ====================
class NoteSearchDelegate extends SearchDelegate {
  final List<Note> notes;

  NoteSearchDelegate({required this.notes});

  @override
  String get searchFieldLabel => 'بحث في الملاحظات...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final variants = _generateQueryVariants(query, max: 25);
    final scores = <String, int>{};
    final byId = <String, Note>{};

    for (final v in variants) {
      for (final note in notes) {
        final s1 = _scoreMatch(query: v, candidate: note.title);
        final s2 = _scoreMatch(query: v, candidate: note.content);
        final score = s1 > s2 ? s1 : s2;
        if (score <= 0) continue;
        final prev = scores[note.id] ?? 0;
        if (score > prev) {
          scores[note.id] = score;
          byId[note.id] = note;
        }
      }
    }

    final ids = byId.keys.toList();
    ids.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    final results = ids.map((id) => byId[id]!).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return NoteCard(note: results[index]);
      },
    );
  }
}

// ==================== GLOBAL SEARCH ====================
class GlobalSearchDelegate extends SearchDelegate {
  final List<Task> tasks;
  final List<Note> notes;

  GlobalSearchDelegate({required this.tasks, required this.notes});

  @override
  String get searchFieldLabel => 'بحث عام...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final variants = _generateQueryVariants(query, max: 25);

    final taskScores = <String, int>{};
    final taskById = <String, Task>{};
    for (final v in variants) {
      for (final task in tasks) {
        final s1 = _scoreMatch(query: v, candidate: task.title);
        final s2 = _scoreMatch(query: v, candidate: task.description);
        final s3 = _scoreMatch(query: v, candidate: task.category);
        var score = s1;
        if (s2 > score) score = s2;
        if (s3 > score) score = s3;
        if (score <= 0) continue;
        final prev = taskScores[task.id] ?? 0;
        if (score > prev) {
          taskScores[task.id] = score;
          taskById[task.id] = task;
        }
      }
    }
    final taskIds = taskById.keys.toList();
    taskIds.sort((a, b) => (taskScores[b] ?? 0).compareTo(taskScores[a] ?? 0));
    final taskResults = taskIds.map((id) => taskById[id]!).toList();

    final noteScores = <String, int>{};
    final noteById = <String, Note>{};
    for (final v in variants) {
      for (final note in notes) {
        final s1 = _scoreMatch(query: v, candidate: note.title);
        final s2 = _scoreMatch(query: v, candidate: note.content);
        final score = s1 > s2 ? s1 : s2;
        if (score <= 0) continue;
        final prev = noteScores[note.id] ?? 0;
        if (score > prev) {
          noteScores[note.id] = score;
          noteById[note.id] = note;
        }
      }
    }
    final noteIds = noteById.keys.toList();
    noteIds.sort((a, b) => (noteScores[b] ?? 0).compareTo(noteScores[a] ?? 0));
    final noteResults = noteIds.map((id) => noteById[id]!).toList();

    if (taskResults.isEmpty && noteResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (taskResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'المهام (${taskResults.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...taskResults.map((task) => TaskCard(task: task)),
        ],
        if (taskResults.isNotEmpty && noteResults.isNotEmpty)
          const Divider(height: 32),
        if (noteResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'الملاحظات (${noteResults.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: noteResults.length,
            itemBuilder: (context, index) {
              return NoteCard(note: noteResults[index]);
            },
          ),
        ],
      ],
    );
  }
}
