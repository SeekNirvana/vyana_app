part of '../../main.dart';

Future<void> openNewEntry(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const NewEntryScreen()));

Future<void> openWakeCapture(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const WakeCaptureScreen()));

Future<void> openMealLog(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const MealLogScreen()));

Future<void> openPastJournal(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const PastJournalScreen()));

/// Shared editor chrome: back affordance, serif title, scrolling body, and a
/// sticky CTA at the bottom.
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.sub,
    required this.children,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.onSave,
    this.canSave = true,
  });

  final String title;
  final String sub;
  final List<Widget> children;
  final String ctaLabel;
  final String ctaIcon;
  final VoidCallback onSave;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.toUpperCase(),
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        Text(title,
                            style: VyanaType.appBarSerif.copyWith(color: t.text)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: children,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Cta(
                    label: ctaLabel,
                    icon: ctaIcon,
                    disabled: !canSave,
                    onTap: onSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

// ── New entry (dream / reflection / idea) ────────────────────────────────────
class NewEntryScreen extends ConsumerStatefulWidget {
  const NewEntryScreen({super.key});

  @override
  ConsumerState<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends ConsumerState<NewEntryScreen> {
  String _type = 'reflection';
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tagInput = TextEditingController();
  final List<String> _tags = [];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag() {
    final raw = _tagInput.text.trim().replaceAll('#', '');
    if (raw.isEmpty) return;
    setState(() {
      if (!_tags.contains(raw)) _tags.add(raw);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.addJournalEntry(
      id: _newId('j'),
      type: _type,
      title: _title.text.trim().isEmpty ? _entryLabel(_type) : _title.text.trim(),
      body: _body.text.trim(),
      tags: _tags,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit(_entryAccent(_type));
    return _EditorScaffold(
      title: 'New entry',
      sub: 'Antara',
      ctaLabel: 'Save entry',
      ctaIcon: 'check',
      canSave: _body.text.trim().isNotEmpty || _title.text.trim().isNotEmpty,
      onSave: _save,
      children: [
        Row(
          children: [
            for (final type in _journalTypes)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: type == _journalTypes.last ? 0 : 8),
                  child: _TypeChip(
                    type: type,
                    active: _type == type,
                    onTap: () => setState(() => _type = type),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldBox(
          child: TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Title',
              hintStyle: VyanaType.titleSerif.copyWith(color: t.textMuted, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FieldBox(
          child: TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            maxLines: 7,
            style: VyanaType.body.copyWith(color: t.text, height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'What happened, what you noticed, what arrived…',
              hintStyle: VyanaType.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FieldBox(
                child: TextField(
                  controller: _tagInput,
                  onSubmitted: (_) => _addTag(),
                  style: VyanaType.bodySm.copyWith(color: t.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add a tag',
                    hintStyle: VyanaType.bodySm.copyWith(color: t.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconBtn(icon: 'plus', active: true, onTap: _addTag),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                GestureDetector(
                  onTap: () => setState(() => _tags.remove(tag)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: ac.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$tag',
                            style: VyanaType.caption.copyWith(color: ac)),
                        const SizedBox(width: 5),
                        VyanaIcon('x', size: 12, color: ac),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.active, required this.onTap});
  final String type;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit(_entryAccent(type));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? ac.withValues(alpha: t.isDark ? 0.18 : 0.12) : t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? ac : t.border),
        ),
        child: Column(
          children: [
            VyanaIcon(_entryIcon(type), size: 20, color: active ? ac : t.textSec),
            const SizedBox(height: 6),
            Text(_entryLabel(type),
                style: VyanaType.caption.copyWith(
                    color: active ? ac : t.textSec, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Wake capture (dream) ─────────────────────────────────────────────────────
class WakeCaptureScreen extends ConsumerStatefulWidget {
  const WakeCaptureScreen({super.key});

  @override
  ConsumerState<WakeCaptureScreen> createState() => _WakeCaptureScreenState();
}

class _WakeCaptureScreenState extends ConsumerState<WakeCaptureScreen> {
  final _body = TextEditingController();
  String? _reflection;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _appendDreamText(String transcript) {
    final existing = _body.text.trim();
    final next = existing.isEmpty
        ? transcript
        : '$existing\n\n$transcript';
    _body
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    setState(() {});
  }

  void _showVoiceSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleVoiceCapture() async {
    final voice = ref.read(guideVoiceServiceProvider);
    if (voice.isTranscribing) return;

    try {
      if (voice.isRecording) {
        final transcript = await voice.stopRecordingAndTranscribe();
        if (transcript.trim().isNotEmpty) {
          _appendDreamText(transcript.trim());
        }
      } else {
        if (!voice.whisperModelReady) {
          if (voice.isPreparingWhisperModel) {
            _showVoiceSnack('Downloading Vani Voice… try again shortly.');
            return;
          }
          unawaited(voice.preloadWhisperModel());
        }
        await voice.startRecording();
      }
    } catch (e) {
      _showVoiceSnack(voice.lastError ?? 'Voice error: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _exploreWithGuide() {
    // On-device guide reflection lands in M9; this is a gentle canned prompt.
    setState(() {
      _reflection =
          'Notice the feeling the dream left behind, not just the events. '
          'What in waking life carries that same texture right now?';
    });
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final text = _body.text.trim();
    await db.addJournalEntry(
      id: _newId('j'),
      type: 'dream',
      title: text.isEmpty
          ? 'Dream'
          : (text.length > 40 ? '${text.substring(0, 40)}…' : text),
      body: text,
      refined: _reflection != null,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit('luna');
    final voice = ref.watch(guideVoiceServiceProvider);
    final voiceLabel = voice.isTranscribing
        ? 'Transcribing…'
        : voice.isRecording
            ? 'Tap to stop'
            : 'Tap to speak';
    return _EditorScaffold(
      title: 'Wake capture',
      sub: 'Antara · dream',
      ctaLabel: 'Save dream',
      ctaIcon: 'moon',
      canSave: _body.text.trim().isNotEmpty,
      onSave: _save,
      children: [
        _FieldBox(
          child: TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            autofocus: true,
            maxLines: 8,
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20, height: 1.4),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'I was…',
              hintStyle: VyanaType.titleSerif.copyWith(color: t.textMuted, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (voice.isRecording || voice.isTranscribing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                VyanaIcon(
                  voice.isRecording ? 'waveform' : 'refresh',
                  size: 15,
                  color: t.vit('hr'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    voice.isRecording
                        ? 'Listening… tap again when you\'re done'
                        : 'Transcribing your dream…',
                    style: VyanaType.mono10.copyWith(color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Cta(
              label: voiceLabel,
              icon: voice.isTranscribing
                  ? 'refresh'
                  : (voice.isRecording ? 'stop' : 'mic'),
              solid: voice.isRecording,
              disabled: voice.isTranscribing,
              onTap: voice.isTranscribing ? null : () => _toggleVoiceCapture(),
            ),
            const SizedBox(height: 10),
            Cta(
              label: 'Ask Ravi',
              icon: 'sparkles',
              solid: false,
              onTap: _exploreWithGuide,
            ),
          ],
        ),
        if (_reflection != null) ...[
          const SizedBox(height: 14),
          Panel(
            pad: 16,
            accent: ac,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VyanaIcon('sparkles', size: 14, color: ac),
                    const SizedBox(width: 7),
                    Text('RAVI', style: VyanaType.mono10.copyWith(color: ac)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_reflection!,
                    style: VyanaType.body.copyWith(color: t.textSec, height: 1.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Meal log ─────────────────────────────────────────────────────────────────
const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Hydration'];

/// Icon per meal type — used by the editor pills and the journal meal cards.
String mealTypeIcon(String type) => switch (type) {
      'Breakfast' => 'sunDim',
      'Lunch' => 'sun',
      'Dinner' => 'moon',
      'Hydration' => 'drop',
      _ => 'leaf', // snack
    };

class MealLogScreen extends ConsumerStatefulWidget {
  const MealLogScreen({super.key});

  @override
  ConsumerState<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends ConsumerState<MealLogScreen> {
  final _label = TextEditingController();
  final _note = TextEditingController();
  final _mealPhotos = MealPhotoService();
  String _mealType = 'Breakfast';
  String? _photoPath;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final t = context.vyana;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MEAL PHOTO',
                    style: VyanaType.eyebrow.copyWith(color: t.gold)),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: VyanaIcon('camera', size: 20, color: t.text),
                  title: Text('Take photo',
                      style: VyanaType.label.copyWith(color: t.text)),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: VyanaIcon('image', size: 20, color: t.text),
                  title: Text('Choose from library',
                      style: VyanaType.label.copyWith(color: t.text)),
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
                if (_photoPath != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: VyanaIcon('x', size: 20, color: t.vit('hr')),
                    title: Text('Remove photo',
                        style: VyanaType.label.copyWith(color: t.vit('hr'))),
                    onTap: () => Navigator.pop(sheetContext, 'remove'),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    if (action == 'remove') {
      setState(() => _photoPath = null);
      return;
    }

    try {
      final source =
          action == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final path = await _mealPhotos.pickAndPersist(source: source);
      if (!mounted) return;
      if (path != null) {
        setState(() => _photoPath = path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $e')),
      );
    }
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.addMeal(
      id: _newId('m'),
      label: _label.text.trim(),
      mealType: _mealType,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return _EditorScaffold(
      title: 'Log a meal',
      sub: 'Antara · nourishment',
      ctaLabel: 'Save meal',
      ctaIcon: 'bowl',
      canSave: _label.text.trim().isNotEmpty,
      onSave: _save,
      children: [
        GestureDetector(
          onTap: _choosePhoto,
          child: Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.border),
              boxShadow: t.shadowSoft,
            ),
            clipBehavior: Clip.antiAlias,
            child: _photoPath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_photoPath!),
                        fit: BoxFit.cover,
                      ),
                      // Soft gradient so the overlay chips stay readable.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.4],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Row(
                          children: [
                            _PhotoChip(
                              label: 'Change',
                              icon: 'camera',
                              onTap: _choosePhoto,
                            ),
                            const SizedBox(width: 8),
                            _PhotoChip(
                              label: 'Remove',
                              icon: 'x',
                              onTap: () => setState(() => _photoPath = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : CustomPaint(
                    painter: _StripePainter(t.border, t.surface),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.vit('steps')
                                  .withValues(alpha: t.isDark ? 0.18 : 0.12),
                              border: Border.all(
                                  color:
                                      t.vit('steps').withValues(alpha: 0.4)),
                            ),
                            child: Center(
                              child: VyanaIcon('camera',
                                  size: 24, color: t.vit('steps')),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Add a photo of your plate',
                              style: VyanaType.label.copyWith(color: t.text)),
                          const SizedBox(height: 3),
                          Text('Camera or library',
                              style:
                                  VyanaType.caption.copyWith(color: t.textMuted)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldBox(
          child: TextField(
            controller: _label,
            onChanged: (_) => setState(() {}),
            style: VyanaType.bodyLg.copyWith(color: t.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'What did you eat?',
              hintStyle: VyanaType.bodyLg.copyWith(color: t.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FieldBox(
          child: TextField(
            controller: _note,
            maxLines: 3,
            style: VyanaType.bodySm.copyWith(color: t.text, height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'How did it make you feel?',
              hintStyle: VyanaType.bodySm.copyWith(color: t.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('WHEN', style: VyanaType.eyebrow.copyWith(color: t.gold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _mealTypes)
              Pill(
                label: type,
                icon: mealTypeIcon(type),
                active: _mealType == type,
                accent: t.vit('steps'),
                onTap: () => setState(() => _mealType = type),
              ),
          ],
        ),
      ],
    );
  }
}

/// Small frosted action chip overlaid on the meal photo.
class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.label, required this.icon, this.onTap});
  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.bg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VyanaIcon(icon, size: 13, color: t.text),
            const SizedBox(width: 5),
            Text(label, style: VyanaType.mono10.copyWith(color: t.text)),
          ],
        ),
      ),
    );
  }
}

// ── Past journal ─────────────────────────────────────────────────────────────
class PastJournalScreen extends ConsumerWidget {
  const PastJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: StreamBuilder<List<JournalEntryRow>>(
            stream: db.watchEntries(),
            builder: (context, entrySnap) {
              return StreamBuilder<List<MealRow>>(
                stream: db.watchMeals(),
                builder: (context, mealSnap) {
                  final entries = entrySnap.data ?? const <JournalEntryRow>[];
                  final meals = mealSnap.data ?? const <MealRow>[];
                  final days = _groupByDay(entries, meals);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    children: [
                      Row(
                        children: [
                          IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                          const SizedBox(width: 11),
                          Text('Past',
                              style: VyanaType.appBarSerif.copyWith(color: t.text)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (days.isEmpty)
                        const EmptyState(
                          icon: Icons.history_edu,
                          text: 'Your journal history will gather here.',
                        )
                      else
                        for (final day in days)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _PastDayCard(day: day),
                          ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<_PastDay> _groupByDay(
      List<JournalEntryRow> entries, List<MealRow> meals) {
    final map = <String, _PastDay>{};
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
    String key(DateTime d) => dayKey(d).toIso8601String();

    for (final e in entries) {
      final k = key(e.createdAt);
      final d = map.putIfAbsent(k, () => _PastDay(dayKey(e.createdAt)));
      d.entries++;
      if (e.type == 'dream') d.dreams++;
    }
    for (final m in meals) {
      final k = key(m.createdAt);
      final d = map.putIfAbsent(k, () => _PastDay(dayKey(m.createdAt)));
      d.meals++;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return list;
  }
}

class _PastDay {
  _PastDay(this.day);
  final DateTime day;
  int entries = 0;
  int dreams = 0;
  int meals = 0;
}

class _PastDayCard extends StatelessWidget {
  const _PastDayCard({required this.day});
  final _PastDay day;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final date = day.day;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : '${date.day}/${date.month}';
    return Panel(
      pad: 16,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 18)),
          ),
          _Count(icon: 'feather', value: day.entries, color: t.vit('nova')),
          const SizedBox(width: 12),
          _Count(icon: 'dream', value: day.dreams, color: t.vit('luna')),
          const SizedBox(width: 12),
          _Count(icon: 'bowl', value: day.meals, color: t.vit('steps')),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.color});
  final String icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VyanaIcon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$value', style: VyanaType.caption.copyWith(color: t.textSec)),
      ],
    );
  }
}
