part of '../../main.dart';

// ── Entry-type styling ──────────────────────────────────────────────────────
String _entryAccent(String type) => switch (type) {
      'dream' => 'luna',
      'idea' => 'gold',
      _ => 'nova', // reflection
    };
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

String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

String _timeLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

// ── Antara journal ───────────────────────────────────────────────────────────
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<JournalEntryRow>>(
      stream: db.watchEntries(),
      builder: (context, entrySnap) {
        final entries = entrySnap.data ?? const <JournalEntryRow>[];
        return StreamBuilder<List<MealRow>>(
          stream: db.watchMeals(),
          builder: (context, mealSnap) {
            final meals = mealSnap.data ?? const <MealRow>[];
            final todayEntries =
                entries.where((e) => _isToday(e.createdAt)).toList();
            final todayMeals = meals.where((m) => _isToday(m.createdAt)).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              children: [
                VAppBar(
                  title: 'Antara',
                  sub: 'inner journal',
                  actions: [
                    IconBtn(
                      icon: 'calendar',
                      onTap: () => openPastJournal(context),
                    ),
                  ],
                ),
                // Wake capture hero
                Panel(
                  grad: true,
                  pad: 20,
                  onTap: () => openWakeCapture(context),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.vit('luna').withValues(alpha: t.isDark ? 0.2 : 0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                            child: VyanaIcon('dream', size: 24, color: t.vit('luna'))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Wake capture',
                                style: VyanaType.titleSerif.copyWith(
                                    color: t.text, fontSize: 20)),
                            Text('Catch the dream before it fades',
                                style: VyanaType.caption.copyWith(color: t.textSec)),
                          ],
                        ),
                      ),
                      VyanaIcon('chevR', size: 18, color: t.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Cta(
                        label: 'New entry',
                        icon: 'feather',
                        solid: false,
                        onTap: () => openNewEntry(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Cta(
                        label: 'Log a meal',
                        icon: 'bowl',
                        solid: false,
                        onTap: () => openMealLog(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SectionHead(
                  eyebrow: 'Today',
                  title: todayEntries.isEmpty && todayMeals.isEmpty
                      ? 'Nothing yet'
                      : 'Your day',
                ),
                if (todayEntries.isEmpty && todayMeals.isEmpty)
                  const EmptyState(
                    icon: Icons.auto_stories,
                    text: 'Capture a dream, a reflection, an idea — or what nourished you.',
                  ),
                for (final e in todayEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EntryCard(entry: e),
                  ),
                if (todayMeals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionHead(eyebrow: 'Nourishment', title: 'Meals'),
                  for (final m in todayMeals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MealCard(meal: m),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});
  final JournalEntryRow entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ac = t.vit(_entryAccent(entry.type));
    final tags = splitTags(entry.tags);
    return Panel(
      pad: 16,
      accent: ac,
      onTap: () => _showEntrySheet(context, ref, entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VyanaIcon(_entryIcon(entry.type), size: 15, color: ac),
              const SizedBox(width: 7),
              Text(_entryLabel(entry.type).toUpperCase(),
                  style: VyanaType.mono10.copyWith(color: ac)),
              const Spacer(),
              Text(_timeLabel(entry.createdAt),
                  style: VyanaType.mono10.copyWith(color: t.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(entry.title,
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 18)),
          const SizedBox(height: 4),
          Text(entry.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5)),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in tags) _TagChip(label: '#$tag')],
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
    final ac = t.vit('steps');
    final photoPath = meal.photoPath;
    final hasPhoto =
        photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();

    final info = Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: VyanaIcon(mealTypeIcon(meal.mealType),
                  size: 17, color: ac),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(meal.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.label.copyWith(color: t.text)),
                Text(
                  '${meal.mealType} · ${_timeLabel(meal.createdAt)}'
                  '${meal.note == null ? '' : ' · ${meal.note}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ],
            ),
          ),
          VyanaIcon('chevR', size: 16, color: t.textMuted),
        ],
      ),
    );

    return Panel(
      pad: 0,
      onTap: () => _showMealSheet(context, ref, meal),
      child: hasPhoto
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.file(
                  File(photoPath),
                  height: 132,
                  fit: BoxFit.cover,
                ),
                info,
              ],
            )
          : info,
    );
  }
}

/// Bottom sheet with the full meal — large photo (tap to zoom), note, and
/// delete. Keeps the journal list itself quiet.
Future<void> _showMealSheet(
    BuildContext context, WidgetRef ref, MealRow meal) {
  final t = context.vyana;
  final photoPath = meal.photoPath;
  final hasPhoto = photoPath != null &&
      photoPath.isNotEmpty &&
      File(photoPath).existsSync();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom),
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
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('Tap to zoom',
                              style: VyanaType.mono10
                                  .copyWith(color: Colors.white)),
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
                VyanaIcon(mealTypeIcon(meal.mealType),
                    size: 16, color: t.vit('steps')),
                const SizedBox(width: 7),
                Text('${meal.mealType.toUpperCase()} · ${_timeLabel(meal.createdAt)}',
                    style: VyanaType.mono10.copyWith(color: t.textSec)),
              ],
            ),
            const SizedBox(height: 8),
            Text(meal.label,
                style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22)),
            if (meal.note != null && meal.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(meal.note!,
                  style: VyanaType.bodySm
                      .copyWith(color: t.textSec, height: 1.5)),
            ],
            const SizedBox(height: 18),
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

/// Bottom sheet with the full journal entry text, tags, and delete.
Future<void> _showEntrySheet(
    BuildContext context, WidgetRef ref, JournalEntryRow entry) {
  final t = context.vyana;
  final ac = t.vit(_entryAccent(entry.type));
  final tags = splitTags(entry.tags);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom),
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
                      style: VyanaType.mono10.copyWith(color: ac)),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry.title,
                  style:
                      VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(entry.body,
                      style: VyanaType.body
                          .copyWith(color: t.textSec, height: 1.55)),
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
                  await ref
                      .read(databaseProvider)
                      .deleteJournalEntry(entry.id);
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
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.borderSoft),
      ),
      child: Text(label, style: VyanaType.mono10.copyWith(color: t.textSec)),
    );
  }
}
