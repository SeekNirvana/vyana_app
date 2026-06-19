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

  bool get _canSave {
    final first = _firstName.text.trim();
    final age = int.tryParse(_age.text.trim());
    return first.isNotEmpty && age != null && age >= 1 && age <= 120;
  }

  Future<void> _save() async {
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final age = int.tryParse(_age.text.trim());
    if (first.isEmpty || age == null || age < 1 || age > 120) return;

    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());

    await ref.read(userProfileProvider.notifier).save(
          UserProfile(
            firstName: first,
            lastName: last,
            age: age,
            gender: _gender,
            heightCm: height != null && height > 0 ? height : null,
            weightKg: weight != null && weight > 0 ? weight : null,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
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
          ],
        );
      },
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