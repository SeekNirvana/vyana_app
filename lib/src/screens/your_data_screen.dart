part of '../../main.dart';

/// Item 53 — Your data: back up, restore, and say where history lives.
///
/// The screen exists because of a sentence nobody had been told: everything
/// Vyana holds is on this phone, so deleting the app deletes it, and
/// neither Android nor iOS gives an app any warning at uninstall. There is
/// no moment at which to ask. So it has to be said in advance, somewhere a
/// person will pass, and it has to come with the thing that answers it.
Future<void> openYourData(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const YourDataScreen()),
  );
}

/// Asks for a passphrase, and says the one thing that must be said.
///
/// Returns null if the person backed out.
Future<String?> askForBackupPassphrase(
  BuildContext context, {
  required bool creating,
}) {
  final controller = TextEditingController();
  var hidden = true;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final t = sheetContext.vyana;
      return StatefulBuilder(
        builder: (builderContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(builderContext).viewInsets.bottom,
          ),
          child: Panel(
            pad: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creating ? 'Choose a passphrase' : 'Enter the passphrase',
                  style: VyanaType.titleSerif.copyWith(color: t.text),
                ),
                const SizedBox(height: 10),
                Text(
                  creating
                      // Said once, plainly, before it can matter. There is
                      // no reset, no recovery and no copy held anywhere —
                      // which is the point, and is useless as a surprise.
                      ? 'This locks the backup. Without this passphrase the '
                          'backup cannot be opened — not by anyone, and not '
                          'by us.'
                      : 'The passphrase this backup was made with.',
                  style: VyanaType.bodySm
                      .copyWith(color: t.textSec, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: hidden,
                  autofocus: true,
                  style: VyanaType.body.copyWith(color: t.text),
                  decoration: InputDecoration(
                    hintText: 'Passphrase',
                    suffixIcon: IconButton(
                      icon: VyanaIcon(hidden ? 'eye' : 'eyeOff',
                          size: 18, color: t.textSec),
                      onPressed: () => setSheetState(() => hidden = !hidden),
                    ),
                  ),
                  onSubmitted: (value) =>
                      Navigator.of(sheetContext).pop(value.trim()),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Cta(
                        label: 'Cancel',
                        solid: false,
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Cta(
                        label: creating ? 'Back up' : 'Restore',
                        onTap: () => Navigator.of(sheetContext)
                            .pop(controller.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class YourDataScreen extends ConsumerStatefulWidget {
  const YourDataScreen({super.key});

  @override
  ConsumerState<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends ConsumerState<YourDataScreen> {
  DateTime? _lastBackup;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    unawaited(_readLastBackup());
  }

  Future<void> _readLastBackup() async {
    final at = await ref.read(backupServiceProvider).lastBackupAt();
    if (mounted) setState(() => _lastBackup = at);
  }

  Future<void> _backUp() async {
    final passphrase =
        await askForBackupPassphrase(context, creating: true);
    if (passphrase == null || !mounted) return;
    if (passphrase.isEmpty) {
      setState(() => _note = 'A backup needs a passphrase.');
      return;
    }

    setState(() {
      _busy = true;
      _note = null;
    });

    final info = await PackageInfo.fromPlatform();
    final attempt = await ref.read(backupServiceProvider).backUpNow(
          passphrase: passphrase,
          appVersion: info.version,
        );
    if (!mounted) return;

    setState(() => _busy = false);
    switch (attempt.outcome) {
      case BackupOutcome.saved:
        await _readLastBackup();
        if (!mounted) return;
        showVyanaSnackBar(
          context,
          message: 'Backup saved. Keep the passphrase somewhere safe.',
          icon: 'check',
        );
      case BackupOutcome.dismissed:
        // Not an error, and not a backup either — so the date is not
        // recorded and the row keeps telling the truth.
        setState(() => _note = 'Nothing was saved.');
      case BackupOutcome.failed:
        setState(() => _note = attempt.message);
    }
  }

  Future<void> _restore() async {
    final service = ref.read(backupServiceProvider);
    final file = await service.chooseBackup();
    if (file == null || !mounted) return;

    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Replace everything on this phone?',
      message: 'Restoring puts the backup back as it was. Anything recorded '
          'since then — readings, entries, meals — is replaced by what the '
          'backup holds.',
      confirmLabel: 'Restore',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final passphrase =
        await askForBackupPassphrase(context, creating: false);
    if (passphrase == null || passphrase.isEmpty || !mounted) return;

    setState(() {
      _busy = true;
      _note = null;
    });

    try {
      final report =
          await service.restoreFrom(file: file, passphrase: passphrase);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = null;
      });
      showVyanaSnackBar(context, message: report.summary, icon: 'check');
    } on BackupException catch (error) {
      // The four reasons read differently on purpose; flattening them to
      // "restore failed" sends people to the wrong place.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = 'The backup could not be restored. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            VAppBar(
              title: 'Your data',
              sub: lastBackupLine(_lastBackup),
              leading: IconBtn(
                icon: 'chevL',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              pad: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your history lives only on this phone.',
                    style: VyanaType.titleSerif.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleting Vyana deletes it. Neither Android nor iPhone '
                    'warns an app that it is being removed, so there is no '
                    'moment at which we could ask — which is why this says '
                    'so now.',
                    style: VyanaType.bodySm
                        .copyWith(color: t.textSec, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Cta(
                    label: _busy ? 'Working…' : 'Back up now',
                    icon: 'download',
                    onTap: _busy ? null : _backUp,
                  ),
                ],
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _note!,
                  style: VyanaType.caption
                      .copyWith(color: t.gold, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const MonoEyebrow('RESTORE', size: 11, spacing: 0.9),
            const SizedBox(height: 8),
            SettingsGroup(
              rows: [
                SettingsRow(
                  icon: 'db',
                  iconColor: t.heading,
                  label: 'Restore from a backup',
                  subtitle: 'Replaces everything on this phone',
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const MonoEyebrow('EXPORTS', size: 11, spacing: 0.9),
            const SizedBox(height: 8),
            SettingsGroup(
              rows: [
                SettingsRow(
                  icon: 'download',
                  iconColor: t.heading,
                  label: 'Export health data',
                  subtitle: 'Summary, every reading, sleep nights, ECG',
                  onTap: () =>
                      openExports(context, ref, section: ExportSection.health),
                ),
                SettingsRow(
                  icon: 'download',
                  iconColor: t.heading,
                  label: 'Export your journal',
                  subtitle: 'Entries, dreams, reflections, ideas, meals',
                  onTap: () =>
                      openExports(context, ref, section: ExportSection.journal),
                ),
                SettingsRow(
                  icon: 'db',
                  iconColor: t.heading,
                  label: 'Export everything',
                  subtitle: 'Machine-readable archive',
                  onTap: () =>
                      openExports(context, ref, section: ExportSection.archive),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'An export is for reading elsewhere — a spreadsheet, another '
                'app. A backup is the one that comes back.',
                style: VyanaType.caption
                    .copyWith(color: t.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
