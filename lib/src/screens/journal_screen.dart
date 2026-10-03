part of '../../main.dart';

// ── Entry-type styling ──────────────────────────────────────────────────────
String _entryIcon(String type) => switch (type) {
  'dream' => 'dream',
  'idea' => 'idea',
  _ => 'feather',
};
String _entryLabel(String type) => switch (type) {
  'dream' => 'Dream',
  'idea' => 'Idea',
  _ => 'Reflection',
};

const _journalTypes = ['dream', 'reflection', 'idea'];

String _newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';

String _timeLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

// ── Antara journal ───────────────────────────────────────────────────────────

/// Kinds in the timeline: the three word-kinds plus meals, each with the
/// colour that lands on the type eyebrow only.
Color journalKindInk(VyanaColors t, String type) => switch (type) {
  'dream' => t.jDream,
  'idea' => t.jIdea,
  'meal' => t.jMeal,
  _ => t.jReflection,
};

/// One item in the single reverse-chronological timeline — an entry or a meal.
class _TimelineItem {
  const _TimelineItem.entry(this.entry) : meal = null;
  const _TimelineItem.meal(this.meal) : entry = null;
  final JournalEntryRow? entry;
  final MealRow? meal;
  DateTime get at => entry?.createdAt ?? meal!.createdAt;
  String get kind => entry?.type ?? 'meal';
}

enum JournalScope { month, quarter, year, all }

extension on JournalScope {
  String get label => switch (this) {
    JournalScope.month => 'This month',
    JournalScope.quarter => 'Last 3 months',
    JournalScope.year => 'This year',
    JournalScope.all => 'All time',
  };
  DateTime? get since {
    final now = DateTime.now();
    return switch (this) {
      JournalScope.month => DateTime(now.year, now.month, 1),
      JournalScope.quarter => now.subtract(const Duration(days: 90)),
      JournalScope.year => DateTime(now.year, 1, 1),
      JournalScope.all => null,
    };
  }
}

/// The search sheet's three inputs — one question ("water in July"), combined
/// with AND.
class JournalQuery {
  const JournalQuery({this.text = '', this.tag, this.scope = JournalScope.all});

  final String text;
  final String? tag;
  final JournalScope scope;

  bool get isEmpty =>
      text.trim().isEmpty && tag == null && scope == JournalScope.all;

  JournalQuery copyWith({
    String? text,
    String? tag,
    bool clearTag = false,
    JournalScope? scope,
  }) => JournalQuery(
    text: text ?? this.text,
    tag: clearTag ? null : (tag ?? this.tag),
    scope: scope ?? this.scope,
  );
}

/// Journal answers "what did I notice" — the only screen holding nothing
/// measured, just the user's own words. Wake capture leads; then one
/// day-grouped timeline of entries and meals running back through real dates.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  String _typeFilter = 'all';
  JournalQuery _query = const JournalQuery();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  void _recompute() {
    if (!mounted) return;
    final ring = ref.read(ringControllerProvider);
    unawaited(ref.read(patternEngineProvider).recompute(history: ring.history));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final db = ref.watch(databaseProvider);
    final armed = ref.watch(lucidArmedProvider);
    final armedNow = ref.read(lucidArmedProvider.notifier).isArmed;
    final patterns = ref.watch(patternsProvider).valueOrNull ?? const [];
    final pattern = currentPatternFor(patterns, 'journal');

    return StreamBuilder<List<JournalEntryRow>>(
      stream: db.watchEntries(),
      builder: (context, entrySnap) {
        final entries = entrySnap.data ?? const <JournalEntryRow>[];
        return StreamBuilder<List<MealRow>>(
          stream: db.watchMeals(),
          builder: (context, mealSnap) {
            final meals = mealSnap.data ?? const <MealRow>[];
            final all = [
              for (final e in entries) _TimelineItem.entry(e),
              for (final m in meals) _TimelineItem.meal(m),
            ]..sort((a, b) => b.at.compareTo(a.at));
            final shown = _apply(all);
            final days = _groupByDay(shown);
            final tags = <String>{
              for (final e in entries) ...splitTags(e.tags),
            }.toList()..sort();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 176),
              children: [
                VAppBar(
                  title: 'Journal',
                  actions: [
                    IconBtn(
                      icon: 'search',
                      active: !_query.isEmpty,
                      onTap: () => _openSearch(context, tags),
                    ),
                    IconBtn(
                      icon: 'download',
                      onTap: () => openExports(context, ref, section: ExportSection.journal),
                    ),
                  ],
                ),
                _WakeCapture(armedAt: armedNow ? armed : null),
                const SizedBox(height: 10),
                // IntrinsicHeight, not stretch: a stretched Row in a ListView
                // has no height to stretch to.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: HairlineCard(
                          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                          onTap: () => openNewEntry(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  VyanaIcon(
                                    'feather',
                                    size: 17,
                                    color: t.mutedInk,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'New entry',
                                    style: VyanaType.label.copyWith(
                                      color: t.text,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              MonoEyebrow(
                                'DREAM · REFLECTION · IDEA',
                                size: 10.5,
                                spacing: 0.7,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 118,
                        child: HairlineCard(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                          onTap: () => openMealLog(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VyanaIcon('bowl', size: 17, color: t.jMeal),
                              const SizedBox(height: 6),
                              Text(
                                'Log a meal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VyanaType.caption.copyWith(
                                  color: t.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pattern != null)
                  PatternCard(
                    pattern: pattern,
                    tint: t.jDream,
                    glyph: 'drop',
                    margin: const EdgeInsets.only(top: 22),
                  ),
                const SizedBox(height: 20),
                _FilterRow(
                  typeFilter: _typeFilter,
                  query: _query,
                  count: shown.length,
                  onType: (id) => setState(() => _typeFilter = id),
                  onClear: () => setState(() => _query = const JournalQuery()),
                ),
                if (days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(
                      all.isEmpty
                          ? 'Nothing here yet. Catch a dream, a reflection, an idea — or what nourished you.'
                          : 'Nothing matches. Clear the filter to see everything.',
                      textAlign: TextAlign.center,
                      style: VyanaType.caption.copyWith(
                        color: t.textSec,
                        height: 1.5,
                      ),
                    ),
                  ),
                for (var i = 0; i < days.length; i++) ...[
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 18 : 22, bottom: 10),
                    child: Row(
                      children: [
                        MonoEyebrow(
                          days[i].label,
                          size: 11,
                          spacing: 0.9,
                          color: t.heading,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Container(height: 1, color: t.hairline),
                        ),
                        const SizedBox(width: 9),
                        MonoEyebrow(
                          '${days[i].items.length} ${days[i].items.length == 1 ? 'ENTRY' : 'ENTRIES'}',
                          size: 10.5,
                          spacing: 0.6,
                        ),
                      ],
                    ),
                  ),
                  for (final item in days[i].items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: item.entry != null
                          ? _EntryCard(
                              entry: item.entry!,
                              activeTag: _query.tag,
                              onTag: (tag) => setState(
                                () => _query = _query.copyWith(tag: tag),
                              ),
                            )
                          : _MealCard(meal: item.meal!),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  List<_TimelineItem> _apply(List<_TimelineItem> all) {
    final q = _query;
    final text = q.text.trim().toLowerCase();
    final since = q.scope.since;
    return all.where((item) {
      if (since != null && item.at.isBefore(since)) return false;
      // Tag mode replaces the type chips; the two are mutually exclusive.
      if (q.tag != null) {
        final e = item.entry;
        if (e == null) return false;
        if (!splitTags(
          e.tags,
        ).map((x) => x.toLowerCase()).contains(q.tag!.toLowerCase())) {
          return false;
        }
      } else if (_typeFilter != 'all' && item.kind != _typeFilter) {
        return false;
      }
      if (text.isNotEmpty) {
        final hay = item.entry != null
            ? '${item.entry!.title} ${item.entry!.body}'.toLowerCase()
            : '${item.meal!.label} ${item.meal!.note ?? ''}'.toLowerCase();
        if (!hay.contains(text)) return false;
      }
      return true;
    }).toList();
  }

  static List<({String label, List<_TimelineItem> items})> _groupByDay(
    List<_TimelineItem> items,
  ) {
    final out = <({String label, List<_TimelineItem> items})>[];
    DateTime? current;
    for (final item in items) {
      final day = DateTime(item.at.year, item.at.month, item.at.day);
      if (current == null || day != current) {
        current = day;
        out.add((label: _dayLabel(item.at), items: []));
      }
      out.last.items.add(item);
    }
    return out;
  }

  Future<void> _openSearch(BuildContext context, List<String> tags) async {
    final result = await showModalBottomSheet<JournalQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(initial: _query, tags: tags),
    );
    if (result != null && mounted) setState(() => _query = result);
  }
}

/// Wake capture: first, largest, dream violet, with a filled mic — the only
/// filled control on the screen. Armed by last night's Lucid Dreaming.
class _WakeCapture extends StatelessWidget {
  const _WakeCapture({required this.armedAt});
  final DateTime? armedAt;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final armed = armedAt != null;
    final ink = t.jDream;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openWakeCapture(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: t.isDark ? 0.14 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ink.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: VyanaIcon(
                    armed ? 'dream' : 'moon',
                    size: 21,
                    color: t.isDark ? const Color(0xFFB9BAE8) : ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (armed) ...[
                      MonoEyebrow(
                        'LUCID ATTEMPT · ${_timeShort(armedAt!)}',
                        size: 10.5,
                        spacing: 0.7,
                        color: t.isDark ? const Color(0xFFB9BAE8) : ink,
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      armed ? 'Did you catch it?' : 'Wake capture',
                      style: VyanaType.label.copyWith(
                        color: t.text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      armed
                          ? 'Anything at all — a fragment counts'
                          : 'Speak your dream before it fades',
                      style: VyanaType.caption.copyWith(
                        color: t.textSec,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.isDark ? const Color(0xFFB9BAE8) : ink,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: VyanaIcon(
                    'mic',
                    size: 19,
                    color: t.isDark ? const Color(0xFF0B0D1C) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Type chips (All / Dreams / Reflections / Ideas / Meals), or — in tag or
/// search mode — one removable chip with a count. Never both.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.typeFilter,
    required this.query,
    required this.count,
    required this.onType,
    required this.onClear,
  });

  final String typeFilter;
  final JournalQuery query;
  final int count;
  final ValueChanged<String> onType;
  final VoidCallback onClear;

  static const _filters = [
    ('all', 'All'),
    ('dream', 'Dreams'),
    ('reflection', 'Reflections'),
    ('idea', 'Ideas'),
    ('meal', 'Meals'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    if (!query.isEmpty) {
      final parts = <String>[
        if (query.tag != null) '#${query.tag}',
        if (query.text.trim().isNotEmpty) '“${query.text.trim()}”',
        if (query.scope != JournalScope.all) query.scope.label.toLowerCase(),
      ];
      return Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 7),
                decoration: BoxDecoration(
                  color: t.heading,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      parts.join(' · '),
                      style: VyanaType.caption.copyWith(
                        color: t.isDark
                            ? const Color(0xFF071211)
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    VyanaIcon(
                      'x',
                      size: 14,
                      color: t.isDark ? const Color(0xFF071211) : Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            count == 1 ? '1 entry' : '$count entries',
            style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 13),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (id, label) in _filters) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onType(id),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
                  decoration: BoxDecoration(
                    color: id == typeFilter
                        ? t.heading
                        : t.mutedInk.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: id == typeFilter ? Colors.transparent : t.hairline,
                    ),
                  ),
                  child: Text(
                    label,
                    style: VyanaType.caption.copyWith(
                      color: id == typeFilter
                          ? (t.isDark ? const Color(0xFF071211) : Colors.white)
                          : t.textSec,
                      fontWeight: id == typeFilter
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// One sheet, three inputs: text matching title and body, the user's existing
/// tags as chips, and a date scope. Combined with AND.
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.initial, required this.tags});
  final JournalQuery initial;
  final List<String> tags;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial.text,
  );
  late JournalQuery _q = widget.initial;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: Panel(
        pad: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search entries',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: t.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: TextField(
                controller: _text,
                autofocus: true,
                onChanged: (v) => setState(() => _q = _q.copyWith(text: v)),
                style: VyanaType.bodySm.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Titles and bodies…',
                  hintStyle: VyanaType.bodySm.copyWith(color: t.textMuted),
                ),
              ),
            ),
            if (widget.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              MonoEyebrow('YOUR TAGS', size: 10.5),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in widget.tags)
                    _TagChip(
                      label: '#$tag',
                      active: _q.tag == tag,
                      onTap: () => setState(
                        () => _q = _q.tag == tag
                            ? _q.copyWith(clearTag: true)
                            : _q.copyWith(tag: tag),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            MonoEyebrow('WHEN', size: 10.5),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in JournalScope.values)
                  Pill(
                    label: s.label,
                    active: _q.scope == s,
                    accent: t.heading,
                    onTap: () => setState(() => _q = _q.copyWith(scope: s)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Cta(
                    label: 'Clear',
                    solid: false,
                    onTap: () =>
                        Navigator.of(context).pop(const JournalQuery()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Cta(
                    label: 'Show entries',
                    icon: 'search',
                    onTap: () => Navigator.of(context).pop(_q),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Type eyebrow + time, title, body, tags as tappable mono chips; refined
/// entries show Nova's reflection inset behind a hairline.
class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.entry,
    required this.activeTag,
    required this.onTag,
  });

  final JournalEntryRow entry;
  final String? activeTag;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ink = journalKindInk(t, entry.type);
    final tags = splitTags(entry.tags);
    final reflection = entry.reflection;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      onTap: () => showJournalEntrySheet(context, ref, entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VyanaIcon(_entryIcon(entry.type), size: 14, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: MonoEyebrow(
                  _entryLabel(entry.type),
                  size: 11,
                  spacing: 0.9,
                  weight: FontWeight.w700,
                  color: ink,
                ),
              ),
              MonoEyebrow(_timeShort(entry.createdAt), size: 10.5),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            entry.title,
            style: VyanaType.caption.copyWith(
              color: t.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          if (entry.body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: VyanaType.caption.copyWith(
                color: t.textSec,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
          if (entry.refined &&
              reflection != null &&
              reflection.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoEyebrow('NOVA', size: 10.5, spacing: 0.8),
                  const SizedBox(height: 3),
                  Text(
                    reflection,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 13.5,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final tag in tags)
                  _TagChip(
                    label: tag,
                    active: tag == activeTag,
                    onTap: () => onTag(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal});
  final MealRow meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ink = t.jMeal;
    final photoPath = meal.photoPath;
    final hasPhoto =
        photoPath != null &&
        photoPath.isNotEmpty &&
        File(photoPath).existsSync();

    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      onTap: () => _showMealSheet(context, ref, meal),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    VyanaIcon(
                      mealTypeIcon(meal.mealType),
                      size: 14,
                      color: ink,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MonoEyebrow(
                        'MEAL · ${meal.mealType}',
                        size: 11,
                        spacing: 0.9,
                        weight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    MonoEyebrow(_timeShort(meal.createdAt), size: 10.5),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  meal.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.caption.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (meal.note != null && meal.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meal.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(photoPath),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet with the full meal — large photo (tap to zoom), note, and
/// delete. Keeps the journal list itself quiet.
Future<void> _showMealSheet(BuildContext context, WidgetRef ref, MealRow meal) {
  final t = context.vyana;
  final photoPath = meal.photoPath;
  final hasPhoto =
      photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Panel(
        pad: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => MealPhotoViewer(path: photoPath),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.file(
                        File(photoPath),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Tap to zoom',
                            style: VyanaType.mono10.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                VyanaIcon(
                  mealTypeIcon(meal.mealType),
                  size: 16,
                  color: t.jMeal,
                ),
                const SizedBox(width: 7),
                Text(
                  '${meal.mealType.toUpperCase()} · ${_timeLabel(meal.createdAt)}',
                  style: VyanaType.mono10.copyWith(color: t.textSec),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              meal.label,
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
            ),
            if (meal.note != null && meal.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                meal.note!,
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
              ),
            ],
            const SizedBox(height: 18),
            Cta(
              label: 'Edit meal',
              icon: 'edit',
              onTap: () async {
                final navigator = Navigator.of(sheetContext);
                navigator.pop();
                await navigator.push<void>(
                  MaterialPageRoute(
                    builder: (_) => MealLogScreen(existing: meal),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Cta(
              label: 'Remove this meal',
              icon: 'x',
              solid: false,
              onTap: () async {
                final confirmed = await showVyanaConfirmDialog<bool>(
                  context: sheetContext,
                  title: 'Remove meal?',
                  message:
                      'This removes "${meal.label}" and its photo from your journal.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
                if (confirmed != true) return;
                await ref.read(databaseProvider).deleteMeal(meal.id);
                if (hasPhoto) {
                  try {
                    await File(photoPath).delete();
                  } catch (_) {
                    // Photo file already gone — nothing to clean up.
                  }
                }
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet with the full journal entry text, Nova's reflection, tags,
/// and delete.
Future<void> showJournalEntrySheet(
  BuildContext context,
  WidgetRef ref,
  JournalEntryRow entry,
) {
  final t = context.vyana;
  final ac = journalKindInk(t, entry.type);
  final tags = splitTags(entry.tags);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: Panel(
          pad: 18,
          accent: ac,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VyanaIcon(_entryIcon(entry.type), size: 15, color: ac),
                  const SizedBox(width: 7),
                  Text(
                    '${_entryLabel(entry.type).toUpperCase()} · ${_timeLabel(entry.createdAt)}',
                    style: VyanaType.mono10.copyWith(color: ac),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                style: VyanaType.titleSerif.copyWith(
                  color: t.text,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.body,
                        style: VyanaType.body.copyWith(
                          color: t.textSec,
                          height: 1.55,
                        ),
                      ),
                      if (entry.reflection != null &&
                          entry.reflection!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: t.hairline)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoEyebrow('NOVA', size: 10.5, spacing: 0.8),
                              const SizedBox(height: 4),
                              Text(
                                entry.reflection!,
                                style: VyanaType.bodySm.copyWith(
                                  color: t.textSec,
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tag in tags) _TagChip(label: '#$tag')],
                ),
              ],
              const SizedBox(height: 18),
              // Bug 8: a mistranscription was permanent without this — the
              // only remedy was deleting and re-dictating, which loses the
              // original timestamp the pattern engine joins on.
              Cta(
                label: 'Edit entry',
                icon: 'edit',
                onTap: () async {
                  final navigator = Navigator.of(sheetContext);
                  navigator.pop();
                  await navigator.push<void>(
                    MaterialPageRoute(
                      builder: (_) => NewEntryScreen(existing: entry),
                    ),
                  );
                },
              ),
              if (entry.reflection != null &&
                  entry.reflection!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                // Nova wrote about the old text, so re-asking is offered
                // rather than done silently.
                Cta(
                  label: 'Ask Nova again',
                  icon: 'sparkles',
                  solid: false,
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    navigator.pop();
                    await addNovaReflection(context, ref, entry);
                  },
                ),
              ],
              const SizedBox(height: 8),
              Cta(
                label: 'Remove this entry',
                icon: 'x',
                solid: false,
                onTap: () async {
                  final confirmed = await showVyanaConfirmDialog<bool>(
                    context: sheetContext,
                    title: 'Remove entry?',
                    message: 'This removes "${entry.title}" from your journal.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (confirmed != true) return;
                  await ref.read(databaseProvider).deleteJournalEntry(entry.id);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Full-screen, pinch-zoomable meal photo.
class MealPhotoViewer extends StatelessWidget {
  const MealPhotoViewer({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.file(File(path))),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconBtn(
                icon: 'x',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.active = false, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 7, 4),
      decoration: BoxDecoration(
        color: active ? t.heading : t.mutedInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: VyanaType.mono,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: active
              ? (t.isDark ? const Color(0xFF071211) : Colors.white)
              : t.mutedInk,
        ),
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: chip,
      ),
    );
  }
}
