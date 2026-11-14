part of '../../main.dart';

Future<void> openProfileEditor(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const ProfileEditorScreen()));

/// Local profile editor — first name, last name, age, gender, height, weight.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  UserGender? _gender;
  bool _initialized = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _seedFrom(UserProfile profile) {
    if (_initialized) return;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    if (profile.age != null) _age.text = '${profile.age}';
    if (profile.heightCm != null) {
      _height.text = '${profile.heightCm!.round()}';
    }
    if (profile.weightKg != null) {
      final w = profile.weightKg!;
      _weight.text =
          w == w.roundToDouble() ? '${w.round()}' : w.toStringAsFixed(1);
    }
    _gender = profile.gender;
    _initialized = true;
  }

  /// The range the height field accepts. Nothing computes from height — it
  /// is shown on the You row and nowhere else — but a row that reads
  /// "17 cm" is a typo the screen agreed to, and it stays there looking like
  /// data until somebody notices.
  static const double _minHeightCm = 50;
  static const double _maxHeightCm = 250;
  static const double _minWeightKg = 20;
  static const double _maxWeightKg = 350;

  /// null when the field is blank, which is allowed; a value only when it is
  /// one a person could have.
  static double? _plausible(String raw, double min, double max) {
    final value = double.tryParse(raw.trim());
    if (value == null) return null;
    return value >= min && value <= max ? value : null;
  }

  static bool _fieldOk(String raw, double min, double max) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return true;
    final value = double.tryParse(trimmed);
    return value != null && value >= min && value <= max;
  }

  bool get _canSave {
    final first = _firstName.text.trim();
    final age = int.tryParse(_age.text.trim());
    return first.isNotEmpty &&
        age != null &&
        age >= 1 &&
        age <= 120 &&
        // Blocked rather than quietly dropped, the way an out-of-range age
        // already is: Save greys out and the caption under the field says
        // what it wants.
        _fieldOk(_height.text, _minHeightCm, _maxHeightCm) &&
        _fieldOk(_weight.text, _minWeightKg, _maxWeightKg);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final age = int.tryParse(_age.text.trim());
    if (first.isEmpty || age == null || age < 1 || age > 120) return;

    final height = _plausible(_height.text, _minHeightCm, _maxHeightCm);
    final weight = _plausible(_weight.text, _minWeightKg, _maxWeightKg);

    final before = ref.read(userProfileProvider).valueOrNull;
    // copyWith, not a fresh UserProfile.
    //
    // This used to build the whole profile from the five fields on screen
    // and carry the rest over by hand, with a comment saying so. It carried
    // the three cycle fields and missed `trainingFrequency`, which was added
    // later — so saving the profile silently wiped the one behaviour answer
    // behind the personal resting-HR band, and the band fell back to the
    // clinical 60–100 with nothing said. Anyone whose gender is female walks
    // straight from this save into the cycle sheet, so that is the path it
    // happened on. Copying from the stored profile means a field added after
    // this screen cannot be dropped by it again.
    await ref.read(userProfileProvider.notifier).save(
          (before ?? const UserProfile()).copyWith(
            firstName: first,
            lastName: last,
            age: age,
            gender: _gender,
            clearGender: _gender == null,
            heightCm: height,
            clearHeightCm: height == null,
            weightKg: weight,
            clearWeightKg: weight == null,
          ),
        );
    if (!mounted) return;

    // Bug 35: this save is the moment the gender became female, so the offer
    // belongs to this screen — but only once it has closed, or the pop below
    // would dismiss the sheet the instant it appeared. Age is deliberately
    // not a condition: the offer used to wait for isWellnessReady, so with an
    // empty age it never appeared at all.
    final offerCycle = _gender == UserGender.female &&
        !(before?.cycleSheetSeen ?? false);
    final navigator = Navigator.of(context);
    final shellContext = navigator.context;
    navigator.pop();
    if (!offerCycle) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shellContext.mounted) {
        unawaited(offerCycleTracking(shellContext, ref));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final profileAsync = ref.watch(userProfileProvider);
    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Could not load profile: $error')),
      ),
      data: (profile) {
        _seedFrom(profile);
        return _EditorScaffold(
          title: 'Your profile',
          sub: 'You',
          ctaLabel: 'Save profile',
          ctaIcon: 'check',
          canSave: _canSave,
          onSave: _save,
          children: [
            Text(
              'Stored only on this device. Age helps baseline heart rate and SpO₂.',
              style: VyanaType.caption.copyWith(color: t.textSec, height: 1.45),
            ),
            const SizedBox(height: 16),
            _profileLabel('First name'),
            _FieldBox(
              child: TextField(
                controller: _firstName,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Required',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _profileLabel('Last name'),
            _FieldBox(
              child: TextField(
                controller: _lastName,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Optional',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _profileLabel('Age'),
            _FieldBox(
              child: TextField(
                controller: _age,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Required · years',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _profileLabel('Gender'),
            Row(
              children: [
                for (final g in UserGender.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: g == UserGender.values.last ? 0 : 8,
                      ),
                      child: Pill(
                        label: g.label,
                        active: _gender == g,
                        onTap: () => setState(() => _gender = g),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _profileLabel('Height (cm)'),
            _FieldBox(
              child: TextField(
                controller: _height,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. 175',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            if (!_fieldOk(_height.text, _minHeightCm, _maxHeightCm))
              _fieldNote('Between ${_minHeightCm.round()} and '
                  '${_maxHeightCm.round()} cm, or leave it blank.'),
            const SizedBox(height: 12),
            _profileLabel('Weight (kg)'),
            _FieldBox(
              child: TextField(
                controller: _weight,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. 68',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            if (!_fieldOk(_weight.text, _minWeightKg, _maxWeightKg))
              _fieldNote('Between ${_minWeightKg.round()} and '
                  '${_maxWeightKg.round()} kg, or leave it blank.'),
          ],
        );
      },
    );
  }

  Widget _fieldNote(String text) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        text,
        style: VyanaType.caption.copyWith(color: t.vit('hr')),
      ),
    );
  }

  Widget _profileLabel(String text) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: VyanaType.label.copyWith(color: t.textSec)),
    );
  }
}