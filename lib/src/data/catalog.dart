part of '../../main.dart';

/// Content source of truth, ported from the handoff's `app/data.js`. These are
/// the static catalog/seed values (activities, guide store, weekly insights,
/// journal seed, home dashboard seed). Live physiology comes from
/// [RingController]; sessions/journal will move to the local DB (drift) in later
/// milestones, seeded from here.

/// A practice in the Sadhana catalog.
class Activity {
  const Activity({
    required this.id,
    required this.cat,
    required this.name,
    required this.ring,
    required this.kind,
    required this.gps,
    required this.icon,
    required this.accent,
    required this.dur,
    required this.guidance,
    required this.blurb,
    required this.track,
    required this.coaching,
    required this.how,
  });

  /// `sport` | `mind` | `wellness`
  final String cat;

  /// `gps` | `indoor` | `strength` | `breath` | `audio` | `sequence` | `recovery`
  final String kind;

  /// `none` | `light` | `structured`
  final String guidance;

  final String id;
  final String name;

  /// Ring SDK sport mode name.
  final String ring;
  final bool gps;
  final String icon;

  /// Per-vital accent key (see [VyanaColors.vit]).
  final String accent;

  /// Default duration in minutes.
  final int dur;
  final String blurb;
  final List<String> track;
  final String coaching;
  final List<String> how;

  /// Whether a chosen length is a promise the session must keep (§5 Length):
  /// guided audio, breath pacers and guided sequences count down and end on a
  /// bell. Movement is open-ended and stays counting up.
  bool get isTimed =>
      kind == 'breath' || kind == 'audio' || kind == 'sequence';
}

/// Category metadata for the Practice library's segmented switch.
class ActivityCategory {
  const ActivityCategory(this.id, this.label, this.eyebrow, this.icon);
  final String id;
  final String label;
  final String eyebrow;
  final String icon;
}

// Movement first and default: it is the largest group and the one people
// open the Practice screen to start.
const kActivityCategories = <ActivityCategory>[
  ActivityCategory('sport', 'Movement', 'Move with intent', 'run'),
  ActivityCategory('mind', 'Mindfulness', 'Steady the mind', 'meditate'),
  ActivityCategory('wellness', 'Wellness', 'Restore the body', 'leaf'),
];

/// The one practice that does not end when the session ends: finishing it
/// arms the next morning's wake capture in the Journal.
const kLucidDreamingId = 'lucidDreaming';

List<Activity> activitiesByCat(String cat) =>
    kActivities.where((a) => a.cat == cat).toList(growable: false);

/// Sports the user added themselves (§5), merged into the catalogue so every
/// lookup, pin, history and pattern treats them like any other practice.
/// Registered by [registerUserActivities] when the table changes.
List<Activity> _userActivities = const [];

List<Activity> get userActivities => _userActivities;

/// Builds an [Activity] from a user-added sport. It gets no guidance and no
/// coaching, because nobody wrote any — it is start/end, like every named
/// sport in §5.
Activity userActivityToActivity({
  required String id,
  required String name,
  required String kind,
  required String icon,
}) {
  final gps = kind == 'gps';
  return Activity(
    id: id,
    cat: 'sport',
    name: name,
    // The SDK has no mode for an arbitrary sport; GPS-driven ones ride the
    // walk profile, the rest use free mode.
    ring: gps ? 'walk' : 'freeMode',
    kind: kind,
    gps: gps,
    icon: icon,
    accent: 'hr',
    dur: 40,
    guidance: 'none',
    blurb: gps
        ? 'Your own sport, outdoors: time, heart rate and route.'
        : 'Your own sport: time and heart rate.',
    track: gps
        ? const ['HR', 'Time', 'Route']
        : const ['HR', 'Time'],
    coaching: 'None.',
    how: const [
      'Tap Start when you begin.',
      'Vyana records heart rate and time until you end it.',
    ],
  );
}

void registerUserActivities(List<Activity> activities) {
  _userActivities = List.unmodifiable(activities);
}

/// Everything in [cat], the user's own sports included.
List<Activity> allActivitiesByCat(String cat) => [
      ...activitiesByCat(cat),
      for (final a in _userActivities)
        if (a.cat == cat) a,
    ];

Activity? activityById(String id) {
  for (final a in kActivities) {
    if (a.id == id) return a;
  }
  for (final a in _userActivities) {
    if (a.id == id) return a;
  }
  return null;
}

/// Name match across all three categories, including the user's own sports
/// (§5 "Catalogue search"). Movement grows past thirty rows, so the list
/// needs a way in other than scrolling.
List<Activity> searchActivities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final a in [...kActivities, ..._userActivities])
      if (a.name.toLowerCase().contains(q)) a,
  ];
}

String guidanceLabel(String guidance) => switch (guidance) {
      'structured' => 'Guided',
      'light' => 'Light cues',
      _ => 'No cues',
    };

/// Maps a catalog `ring` mode name to the ring SDK's [DeviceSportType] code.
/// Meditation/etc. fall back to `freeMode` (per the SDK constraint that
/// meditation is not a native sport type).
int sportTypeCodeForRing(String ring) {
  switch (ring) {
    case 'outdoorRunning':
      return DeviceSportType.outdoorRunning;
    case 'run':
      return DeviceSportType.run;
    case 'walk':
      return DeviceSportType.walk;
    case 'onfoot':
      return DeviceSportType.onfoot;
    case 'outdoorWalking':
      return DeviceSportType.outdoorWalking;
    case 'riding':
      return DeviceSportType.riding;
    case 'indoorRiding':
      return DeviceSportType.indoorRiding;
    case 'indoorRunning':
      return DeviceSportType.indoorRunning;
    case 'rowingMachine':
      return DeviceSportType.rowingMachine;
    case 'ellipticalMachine':
      return DeviceSportType.ellipticalMachine;
    case 'weightTraining':
      return DeviceSportType.weightTraining;
    case 'fitness':
      return DeviceSportType.fitness;
    case 'ropeskipping':
      return DeviceSportType.ropeskipping;
    case 'dance':
      return DeviceSportType.dance;
    case 'playball':
      return DeviceSportType.playball;
    case 'football':
      return DeviceSportType.football;
    case 'badminton':
      return DeviceSportType.badminton;
    case 'tennis':
      return DeviceSportType.tennis;
    case 'golf':
      return DeviceSportType.golf;
    case 'swimming':
      return DeviceSportType.swimming;
    case 'rockClimbing':
      return DeviceSportType.rockClimbing;
    // §5/§15: the SDK has no winter or water-sport modes, but it does have
    // these — checked against vyana_sdk rather than defaulting to freeMode.
    case 'pingPang':
      return DeviceSportType.pingPang;
    case 'volleyball':
      return DeviceSportType.volleyball;
    case 'kayak':
      return DeviceSportType.kayak;
    case 'rollerSkating':
      return DeviceSportType.rollerSkating;
    case 'mountaineering':
      return DeviceSportType.mountaineering;
    case 'otherSports':
      return DeviceSportType.otherSports;
    case 'realTimeMonitoring':
      return DeviceSportType.realTimeMonitoring;
    case 'yoga':
      return DeviceSportType.yoga;
    case 'freeMode':
    default:
      return DeviceSportType.freeMode;
  }
}

const kActivities = <Activity>[
  // ── SPORT / MOVEMENT ───────────────────────────────────────────────────
  Activity(
    id: 'outdoorRun', cat: 'sport', name: 'Outdoor Run', ring: 'outdoorRunning',
    kind: 'gps', gps: true, icon: 'run', accent: 'hr', dur: 40, guidance: 'light',
    blurb: 'GPS pace, route and elevation, paired with live heart rate and effort.',
    track: ['Pace & distance', 'HR zones', 'Elevation gain', 'Recovery HR'],
    coaching: 'Spoken split every 10 min — time, pace, heart rate, elevation gain.',
    how: [
      'Wear the PRANA ring snug on your index finger.',
      'Step outside and let GPS lock — Vyana confirms with a soft chime.',
      'Tap Start and ease into a conversational effort.',
      'Vyana speaks your splits every 10 minutes; keep your eyes up.',
      'Tap End to bank the run — zones, gain and recovery are computed for you.',
    ],
  ),
  Activity(
    id: 'trailRun', cat: 'sport', name: 'Trail Run', ring: 'run', kind: 'gps',
    gps: true, icon: 'mountain', accent: 'hr', dur: 50, guidance: 'light',
    blurb: 'Climb rate, grade and descent watched alongside heart-rate load.',
    track: ['HR zones', 'Climb & descent rate', 'Grade', 'Elevation gain'],
    coaching: 'Cues on steep climbs and a gentle descent-care reminder.',
    how: [
      'Pick a marked trail and let GPS settle.',
      'Tap Start at the trailhead.',
      'Vyana flags hard climbs and reminds you to control descents.',
    ],
  ),
  Activity(
    id: 'walk', cat: 'sport', name: 'Walk', ring: 'walk', kind: 'gps', gps: true,
    icon: 'walk', accent: 'steps', dur: 25, guidance: 'none',
    blurb: 'A gentle GPS-tracked walk with steps, distance and easy heart rate.',
    track: ['Steps & distance', 'HR', 'Calm minutes'],
    coaching: 'Quiet by default — just a soft start chime.',
    how: [
      'Tap Start and walk at a comfortable pace.',
      'Vyana tracks distance and steps in the background.',
    ],
  ),
  Activity(
    id: 'hike', cat: 'sport', name: 'Hike / Trek', ring: 'onfoot', kind: 'gps',
    gps: true, icon: 'mountain', accent: 'steps', dur: 90, guidance: 'light',
    blurb: 'Altitude gain and HR load over the route, with hydration reminders.',
    track: ['Elevation gain', 'HR load', 'Distance', 'Hydration'],
    coaching: 'Hydration nudge every 30 minutes; altitude-gain callouts.',
    how: [
      'Let GPS lock at the trailhead.',
      'Tap Start and set your pace.',
      'Vyana reminds you to sip water and tracks total climb.',
    ],
  ),
  Activity(
    id: 'cycling', cat: 'sport', name: 'Cycling', ring: 'riding', kind: 'gps',
    gps: true, icon: 'bike', accent: 'cal', dur: 60, guidance: 'light',
    blurb: 'Speed, elevation and route with continuous heart rate.',
    track: ['Speed', 'HR zones', 'Climb', 'Distance'],
    coaching: 'Safety prompt at start; climb and HR callouts.',
    how: [
      'Mount your phone and let GPS lock.',
      'Tap Start — Vyana gives a quick safety prompt.',
      'Ride; speed, climb and HR are logged the whole way.',
    ],
  ),
  Activity(
    id: 'indoorCycling', cat: 'sport', name: 'Indoor Cycling', ring: 'indoorRiding',
    kind: 'indoor', gps: false, icon: 'bike', accent: 'cal', dur: 45, guidance: 'none',
    blurb: 'No GPS — HR, duration and estimated load for the spin.',
    track: ['HR zones', 'Duration', 'Estimated load'],
    coaching: 'Optional interval prompts.',
    how: ['Tap Start on the bike.', 'Follow your effort; Vyana tracks HR and load.'],
  ),
  Activity(
    // Name only: the id and ring mode stay put so existing history carries
    // over. Walkers were being told to run.
    id: 'treadmill', cat: 'sport', name: 'Treadmill Walk / Run',
    ring: 'indoorRunning',
    kind: 'indoor', gps: false, icon: 'run', accent: 'hr', dur: 35, guidance: 'none',
    blurb: 'Indoor walk or run with HR, cadence proxy and time — optional '
        'manual distance.',
    track: ['HR zones', 'Time', 'Cadence proxy'],
    coaching: 'Quiet; optional HR-zone alerts.',
    how: ['Set your treadmill speed.', 'Tap Start and walk or run.', 'Add manual distance afterward if you like.'],
  ),
  Activity(
    id: 'rowing', cat: 'sport', name: 'Rowing Machine', ring: 'rowingMachine',
    kind: 'indoor', gps: false, icon: 'dumbbell', accent: 'hr', dur: 30, guidance: 'none',
    blurb: 'HR, duration and intensity for the erg.',
    track: ['HR', 'Duration', 'Intensity'],
    coaching: 'Optional stroke-pacing cue.',
    how: ['Strap in and tap Start.', 'Row steady; Vyana logs HR and intensity.'],
  ),
  Activity(
    id: 'elliptical', cat: 'sport', name: 'Elliptical', ring: 'ellipticalMachine',
    kind: 'indoor', gps: false, icon: 'activity', accent: 'cal', dur: 35, guidance: 'none',
    blurb: 'HR zones, calories and consistency.',
    track: ['HR zones', 'Calories', 'Consistency'],
    coaching: 'Quiet session.',
    how: ['Tap Start.', 'Hold a steady cadence; Vyana tracks zones and calories.'],
  ),
  Activity(
    id: 'strength', cat: 'sport', name: 'Gym', ring: 'weightTraining',
    kind: 'strength', gps: false, icon: 'dumbbell', accent: 'hr', dur: 50, guidance: 'structured',
    blurb: 'Set and rest timers with heart-rate recovery between efforts.',
    track: ['Set & rest timers', 'HR recovery', 'Session load'],
    coaching: '"Rest complete. HR 118. Start your next set."',
    how: [
      'Build or pick your exercise list.',
      'Tap Start; log a set, then hit Rest.',
      'Vyana counts your rest and watches HR drop.',
      'When recovered, it cues your next set.',
      'End to see HR recovery and total load.',
    ],
  ),
  Activity(
    id: 'functional', cat: 'sport', name: 'Functional Fitness', ring: 'fitness',
    kind: 'strength', gps: false, icon: 'dumbbell', accent: 'cal', dur: 40, guidance: 'structured',
    blurb: 'Intervals, HR zones and recovery for mixed-modal work.',
    track: ['Intervals', 'HR zones', 'Recovery'],
    coaching: 'Work / rest prompts.',
    how: ['Set your circuit.', 'Tap Start and move through stations.', 'Vyana paces work and rest.'],
  ),
  Activity(
    id: 'hiit', cat: 'sport', name: 'HIIT', ring: 'fitness', kind: 'strength',
    gps: false, icon: 'bolt', accent: 'hr', dur: 25, guidance: 'structured',
    blurb: 'Work/rest prompts with peak HR and recovery HR.',
    track: ['Work/rest', 'Peak HR', 'Recovery HR'],
    coaching: 'Sharp work and rest calls.',
    how: ['Choose your work/rest ratio.', 'Tap Start and go hard on each work block.', 'Vyana calls the intervals and tracks peak HR.'],
  ),
  Activity(
    id: 'jumpRope', cat: 'sport', name: 'Jump Rope', ring: 'ropeskipping',
    kind: 'strength', gps: false, icon: 'repeat', accent: 'cal', dur: 20, guidance: 'structured',
    blurb: 'Rounds, HR and calories.',
    track: ['Rounds', 'HR', 'Calories'],
    coaching: 'Round timer and rest calls.',
    how: ['Tap Start.', 'Skip in rounds; Vyana times each and your rest.'],
  ),
  Activity(
    id: 'dance', cat: 'sport', name: 'Dance', ring: 'dance', kind: 'indoor',
    gps: false, icon: 'sparkles', accent: 'nova', dur: 40, guidance: 'none',
    blurb: 'HR, duration and calories — move how you like.',
    track: ['HR', 'Duration', 'Calories'],
    coaching: 'Quiet; pure flow.',
    how: ['Put on a track.', 'Tap Start and dance.'],
  ),
  Activity(
    id: 'basketball', cat: 'sport', name: 'Basketball', ring: 'playball',
    kind: 'indoor', gps: false, icon: 'target', accent: 'hr', dur: 60, guidance: 'none',
    blurb: 'HR and duration across the game.',
    track: ['HR', 'Active time'],
    coaching: 'None.',
    how: ['Tap Start before tip-off.', 'Play; Vyana logs HR and active time.'],
  ),
  Activity(
    id: 'football', cat: 'sport', name: 'Football', ring: 'football', kind: 'gps',
    gps: true, icon: 'target', accent: 'steps', dur: 75, guidance: 'none',
    blurb: 'Distance, sprint bursts and HR if outdoors.',
    track: ['Distance', 'Bursts', 'HR'],
    coaching: 'None.',
    how: ['Let GPS lock outdoors.', 'Tap Start and play.'],
  ),
  Activity(
    id: 'badminton', cat: 'sport', name: 'Badminton', ring: 'badminton',
    kind: 'indoor', gps: false, icon: 'activity', accent: 'hr', dur: 45, guidance: 'none',
    blurb: 'HR and duration on court.',
    track: ['HR', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start.', 'Play your match.'],
  ),
  Activity(
    id: 'tennis', cat: 'sport', name: 'Tennis', ring: 'tennis', kind: 'indoor',
    gps: false, icon: 'activity', accent: 'hr', dur: 60, guidance: 'none',
    blurb: 'HR and active time across sets.',
    track: ['HR', 'Active time'],
    coaching: 'None.',
    how: ['Tap Start.', 'Play; Vyana logs HR and active time.'],
  ),
  Activity(
    id: 'golf', cat: 'sport', name: 'Golf', ring: 'golf', kind: 'gps', gps: true,
    icon: 'target', accent: 'steps', dur: 120, guidance: 'none',
    blurb: 'Walking distance, HR and duration over the round.',
    track: ['Walking distance', 'HR', 'Duration'],
    coaching: 'None.',
    how: ['Let GPS lock.', 'Tap Start at the first tee.'],
  ),
  Activity(
    id: 'swimming', cat: 'sport', name: 'Swimming', ring: 'swimming',
    kind: 'indoor', gps: false, icon: 'swim', accent: 'spo2', dur: 35, guidance: 'none',
    blurb: 'Duration and HR where the ring reads reliably.',
    track: ['Duration', 'HR'],
    coaching: 'None.',
    how: ['Tap Start poolside.', 'Swim; Vyana logs duration and HR.'],
  ),
  // §5 "More named sports": every sport keeps its own name; the grouping is
  // internal, via `kind`, which already decides what is tracked. All
  // start/end — none has a length to choose.
  Activity(
    id: 'downhillSki', cat: 'sport', name: 'Downhill Skiing', ring: 'freeMode',
    kind: 'gps', gps: true, icon: 'ski', accent: 'hr', dur: 120,
    guidance: 'none',
    blurb: 'Runs, descent and heart rate through the day on the mountain.',
    track: ['HR', 'Time', 'Descent'],
    coaching: 'None.',
    how: ['Tap Start at the first lift.', 'Ski; Vyana logs HR and the route.'],
  ),
  Activity(
    id: 'crossCountrySki', cat: 'sport', name: 'Cross-country Skiing',
    ring: 'freeMode',
    kind: 'gps', gps: true, icon: 'ski', accent: 'hr', dur: 70,
    guidance: 'light',
    blurb: 'Distance, pace and heart rate on the track.',
    track: ['Distance', 'Pace', 'HR zones'],
    coaching: 'Splits every 10 minutes.',
    how: ['Tap Start at the trailhead.', 'Ski; Vyana tracks distance and HR.'],
  ),
  Activity(
    id: 'snowboarding', cat: 'sport', name: 'Snowboarding', ring: 'freeMode',
    kind: 'gps', gps: true, icon: 'snowboard', accent: 'hr', dur: 120,
    guidance: 'none',
    blurb: 'Runs, descent and heart rate through the day.',
    track: ['HR', 'Time', 'Descent'],
    coaching: 'None.',
    how: ['Tap Start at the first lift.', 'Ride; Vyana logs HR and the route.'],
  ),
  Activity(
    id: 'iceSkating', cat: 'sport', name: 'Ice Skating',
    ring: 'rollerSkating',
    kind: 'indoor', gps: false, icon: 'skate', accent: 'hr', dur: 45,
    guidance: 'none',
    blurb: 'Time and heart rate on the ice.',
    track: ['HR', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start as you step on.', 'Skate; Vyana logs HR and duration.'],
  ),
  Activity(
    id: 'iceHockey', cat: 'sport', name: 'Ice Hockey', ring: 'freeMode',
    kind: 'indoor', gps: false, icon: 'hockey', accent: 'hr', dur: 70,
    guidance: 'none',
    blurb: 'Shift intensity and heart-rate recovery across the game.',
    track: ['HR zones', 'Recovery between shifts', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start before the first shift.', 'Play; Vyana logs HR and recovery.'],
  ),
  Activity(
    id: 'padel', cat: 'sport', name: 'Padel', ring: 'tennis',
    kind: 'indoor', gps: false, icon: 'racket', accent: 'hr', dur: 60,
    guidance: 'none',
    blurb: 'HR zones and duration across the match.',
    track: ['HR zones', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start at the first serve.', 'Play; Vyana logs HR and duration.'],
  ),
  Activity(
    id: 'squash', cat: 'sport', name: 'Squash', ring: 'tennis',
    kind: 'indoor', gps: false, icon: 'racket', accent: 'hr', dur: 45,
    guidance: 'none',
    blurb: 'A hard interval sport, read through heart-rate zones.',
    track: ['HR zones', 'Duration', 'Recovery'],
    coaching: 'None.',
    how: ['Tap Start on court.', 'Play; Vyana logs HR and recovery.'],
  ),
  Activity(
    id: 'tableTennis', cat: 'sport', name: 'Table Tennis', ring: 'pingPang',
    kind: 'indoor', gps: false, icon: 'tableTennis', accent: 'hr', dur: 45,
    guidance: 'none',
    blurb: 'Duration and heart rate across the session.',
    track: ['HR', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start at the table.', 'Play; Vyana logs HR and duration.'],
  ),
  Activity(
    id: 'volleyball', cat: 'sport', name: 'Volleyball', ring: 'volleyball',
    kind: 'indoor', gps: false, icon: 'volleyball', accent: 'hr', dur: 70,
    guidance: 'none',
    blurb: 'HR zones and duration across the match.',
    track: ['HR zones', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start before the first point.', 'Play; Vyana logs HR.'],
  ),
  Activity(
    id: 'hockey', cat: 'sport', name: 'Hockey', ring: 'freeMode',
    kind: 'indoor', gps: false, icon: 'hockey', accent: 'hr', dur: 70,
    guidance: 'none',
    blurb: 'HR zones and duration across the match.',
    track: ['HR zones', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start before kick-off.', 'Play; Vyana logs HR.'],
  ),
  Activity(
    id: 'boxing', cat: 'sport', name: 'Boxing / Martial Arts', ring: 'fitness',
    kind: 'indoor', gps: false, icon: 'boxing', accent: 'hr', dur: 60,
    guidance: 'none',
    blurb: 'Round intensity and heart-rate recovery between them.',
    track: ['HR zones', 'Recovery', 'Duration'],
    coaching: 'None.',
    how: ['Tap Start before the first round.', 'Train; Vyana logs HR and recovery.'],
  ),
  Activity(
    id: 'surfing', cat: 'sport', name: 'Surfing', ring: 'freeMode',
    kind: 'gps', gps: true, icon: 'surf', accent: 'hr', dur: 90,
    guidance: 'none',
    blurb: 'Time in the water with heart rate and the paddle-out effort.',
    track: ['HR', 'Time', 'Route'],
    coaching: 'None.',
    how: ['Tap Start on the beach.', 'Surf; Vyana logs HR and time in the water.'],
  ),
  Activity(
    id: 'kayaking', cat: 'sport', name: 'Kayaking / SUP', ring: 'kayak',
    kind: 'gps', gps: true, icon: 'kayak', accent: 'hr', dur: 70,
    guidance: 'light',
    blurb: 'Distance, pace and heart rate on the water.',
    track: ['Distance', 'Pace', 'HR'],
    coaching: 'Splits every 10 minutes.',
    how: ['Tap Start at the put-in.', 'Paddle; Vyana tracks distance and HR.'],
  ),
  Activity(
    id: 'climbing', cat: 'sport', name: 'Climbing', ring: 'rockClimbing',
    kind: 'indoor', gps: false, icon: 'mountain', accent: 'hr', dur: 50, guidance: 'none',
    blurb: 'HR, duration and recovery between routes.',
    track: ['HR', 'Duration', 'Recovery'],
    coaching: 'None.',
    how: ['Tap Start at the wall.', 'Climb; rest and recovery are tracked.'],
  ),
  Activity(
    id: 'freeWorkout', cat: 'sport', name: 'Free Workout', ring: 'freeMode',
    kind: 'indoor', gps: false, icon: 'activity', accent: 'steps', dur: 30, guidance: 'none',
    blurb: 'A generic session — HR and load, configure as you go.',
    track: ['HR', 'Session load'],
    coaching: 'None.',
    how: ['Tap Start.', 'Move; Vyana logs HR and load.'],
  ),

  // ── MINDFULNESS ─────────────────────────────────────────────────────────
  Activity(
    id: 'meditation', cat: 'mind', name: 'Meditation', ring: 'realTimeMonitoring',
    kind: 'audio', gps: false, icon: 'meditate', accent: 'luna', dur: 10, guidance: 'structured',
    blurb: 'Timer and gentle attention cues with a calming HR trend.',
    track: ['HR calm trend', 'Calm score', 'Stillness'],
    coaching: 'Soft breath and attention guidance.',
    how: ['Find a quiet seat.', 'Choose a length and tap Begin.', 'Follow the gentle cues; watch your HR settle.'],
  ),
  Activity(
    id: 'breathwork', cat: 'mind', name: 'Breathwork', ring: 'freeMode',
    kind: 'breath', gps: false, icon: 'wind', accent: 'hrv', dur: 8, guidance: 'structured',
    blurb: 'A visual breath pacer with inhale–hold–exhale cues and HRV response.',
    track: ['Breath compliance', 'HRV response', 'Coherence'],
    coaching: 'Expanding orb with inhale, hold and exhale prompts.',
    how: [
      'Sit tall and relax your shoulders.',
      'Choose a pattern and tap Begin.',
      'Breathe with the orb — in as it grows, out as it shrinks.',
      'Watch your coherence rise as breath and heart sync.',
      'Finish to see your HRV response.',
    ],
  ),
  Activity(
    id: 'pranayama', cat: 'mind', name: 'Pranayama', ring: 'freeMode',
    kind: 'breath', gps: false, icon: 'wind', accent: 'hrv', dur: 10, guidance: 'structured',
    blurb: 'Guided ratio breathing in the classical pranayama tradition.',
    track: ['Breath ratio', 'HRV', 'Coherence'],
    coaching: 'Ratio breathing with a visual pacer.',
    how: ['Sit comfortably with a straight spine.', 'Pick a ratio and tap Begin.', 'Follow the orb through each measured phase.'],
  ),
  Activity(
    id: 'yogaNidra', cat: 'mind', name: 'Yoga Nidra', ring: 'yoga', kind: 'audio',
    gps: false, icon: 'moon', accent: 'luna', dur: 25, guidance: 'structured',
    blurb: 'A guided body-scan journey — deep rest, no performance cues.',
    track: ['HR drop', 'Stress release', 'Rest depth'],
    coaching: 'Full audio script. Body scan, no interruptions.',
    how: [
      'Lie down somewhere warm and dim.',
      'Tap Begin and close your eyes.',
      'Let the voice guide your attention through the body.',
      'There is nothing to achieve — only to rest.',
      'We measure how deeply you settled, gently.',
    ],
  ),
  Activity(
    id: kLucidDreamingId, cat: 'mind', name: 'Lucid Dreaming', ring: 'freeMode',
    kind: 'audio', gps: false, icon: 'dream', accent: 'luna', dur: 14, guidance: 'structured',
    blurb: 'A pre-sleep audio that primes tonight and is recalled at dawn.',
    track: ['Wake capture armed', 'Recall'],
    coaching: 'Spoken intention-setting, then silence. Finishing arms tomorrow\'s wake capture.',
    how: [
      'Do this in bed, lights off, within the hour before sleep.',
      'Tap Begin and follow the voice through the intention.',
      'Repeat the intention as you drift off — nothing else to do.',
      'When you wake, the Journal asks "Did you catch it?" — a fragment counts.',
    ],
  ),
  Activity(
    id: 'bodyScan', cat: 'mind', name: 'Body Scan', ring: 'freeMode', kind: 'audio',
    gps: false, icon: 'leaf', accent: 'luna', dur: 15, guidance: 'structured',
    blurb: 'A relaxation progression from head to toe.',
    track: ['Relaxation', 'HR drop'],
    coaching: 'Slow audio progression.',
    how: ['Lie down and settle.', 'Tap Begin and follow the voice through each region.'],
  ),
  Activity(
    id: 'mantra', cat: 'mind', name: 'Mantra Meditation', ring: 'freeMode',
    kind: 'audio', gps: false, icon: 'speaker', accent: 'nova', dur: 12, guidance: 'light',
    blurb: 'Repetition with a soft bell and minimal vitals.',
    track: ['Stillness', 'HR calm'],
    coaching: 'Repetition bell.',
    how: ['Choose your mantra.', 'Tap Begin; repeat with each soft bell.'],
  ),
  Activity(
    id: 'walkingMed', cat: 'mind', name: 'Walking Meditation', ring: 'outdoorWalking',
    kind: 'gps', gps: true, icon: 'walk', accent: 'steps', dur: 20, guidance: 'structured',
    blurb: 'Slow, mindful pace with calm cues and an easy heart rate.',
    track: ['Pace', 'HR calm', 'Mindful cues'],
    coaching: 'Slow-down and attention prompts.',
    how: ['Step outside to a quiet path.', 'Tap Begin and walk slowly.', 'Match each step to your breath.'],
  ),
  Activity(
    id: 'soundBath', cat: 'mind', name: 'Sound Bath', ring: 'freeMode', kind: 'audio',
    gps: false, icon: 'speaker', accent: 'spo2', dur: 20, guidance: 'light',
    blurb: 'A passive session bracketed by before/after vitals.',
    track: ['Before/after vitals', 'HR drop'],
    coaching: 'Passive — just receive.',
    how: ['Lie back and rest your hands.', 'Tap Begin and let the sound carry you.'],
  ),
  Activity(
    id: 'hrvBreathing', cat: 'mind', name: 'HRV Breathing', ring: 'realTimeMonitoring',
    kind: 'breath', gps: false, icon: 'pulse', accent: 'hrv', dur: 6, guidance: 'structured',
    blurb: 'A breath pacer tuned to maximise coherence between breath and heart.',
    track: ['Coherence score', 'HRV trend'],
    coaching: 'Resonance-frequency pacer.',
    how: ['Sit quietly.', 'Tap Begin and breathe with the pacer at ~6 breaths a minute.', 'Aim to keep the coherence line high.'],
  ),

  // ── WELLNESS / RECOVERY ───────────────────────────────────────────────────
  Activity(
    id: 'sunSalutation', cat: 'wellness', name: 'Sun Salutation', ring: 'yoga',
    kind: 'sequence', gps: false, icon: 'sun', accent: 'gold', dur: 12, guidance: 'structured',
    blurb: 'A guided Surya Namaskar — pose sequence with a round counter.',
    track: ['Round count', 'HR response', 'Flow rhythm'],
    coaching: 'Pose-by-pose sequence, round counter, optional bell.',
    how: [
      'Stand at the top of your mat in Pranamasana.',
      'Tap Begin; Vyana guides each of the twelve poses.',
      'Move with your breath — one pose per inhale or exhale.',
      'A soft bell closes each round and counts it.',
      'Finish to see rounds and your HR response.',
    ],
  ),
  Activity(
    id: 'yogaFlow', cat: 'wellness', name: 'Yoga Flow', ring: 'yoga',
    kind: 'sequence', gps: false, icon: 'lotus', accent: 'nova', dur: 30, guidance: 'structured',
    blurb: 'A flowing sequence timed pose to pose, with HR and recovery.',
    track: ['Duration', 'HR', 'Recovery'],
    coaching: 'Sequence timer with breath cues.',
    how: ['Roll out your mat.', 'Tap Begin and follow the flow.', 'Let breath lead each transition.'],
  ),
  Activity(
    id: 'stretching', cat: 'wellness', name: 'Stretching', ring: 'freeMode',
    kind: 'sequence', gps: false, icon: 'leaf', accent: 'hrv', dur: 12, guidance: 'structured',
    blurb: 'Held poses on a calm-HR timer to build the flexibility habit.',
    track: ['Pose timer', 'Calm HR'],
    coaching: 'Hold timers per stretch.',
    how: ['Find space to move.', 'Tap Begin and hold each stretch with the timer.'],
  ),
  Activity(
    id: 'mobility', cat: 'wellness', name: 'Mobility', ring: 'fitness',
    kind: 'sequence', gps: false, icon: 'activity', accent: 'readiness', dur: 15, guidance: 'structured',
    blurb: 'A range-of-motion session for consistency.',
    track: ['Consistency', 'Range'],
    coaching: 'Movement timers.',
    how: ['Tap Begin.', 'Work each joint through its range with the timers.'],
  ),
  Activity(
    id: 'pilates', cat: 'wellness', name: 'Pilates', ring: 'fitness',
    kind: 'sequence', gps: false, icon: 'lotus', accent: 'nova', dur: 25, guidance: 'structured',
    blurb: 'Controlled work with HR and duration.',
    track: ['HR', 'Duration'],
    coaching: 'Exercise timers.',
    how: ['Set your mat.', 'Tap Begin and follow the timed exercises.'],
  ),
  Activity(
    id: 'warmup', cat: 'wellness', name: 'Warm-up', ring: 'freeMode',
    kind: 'sequence', gps: false, icon: 'flame', accent: 'temp', dur: 8, guidance: 'structured',
    blurb: 'Prime the body and check readiness before a workout.',
    track: ['Readiness', 'HR rise'],
    coaching: 'Short movement timers.',
    how: ['Tap Begin before your main session.', 'Move through the prep drills.'],
  ),
  Activity(
    id: 'cooldown', cat: 'wellness', name: 'Cool-down', ring: 'freeMode',
    kind: 'sequence', gps: false, icon: 'snow', accent: 'spo2', dur: 8, guidance: 'structured',
    blurb: 'Bring the heart rate down and track the recovery slope.',
    track: ['HR recovery slope'],
    coaching: 'Slow breathing and easy holds.',
    how: ['Tap Begin after training.', 'Breathe slow and hold the gentle stretches.'],
  ),
  Activity(
    id: 'sauna', cat: 'wellness', name: 'Sauna', ring: 'realTimeMonitoring',
    kind: 'recovery', gps: false, icon: 'flame', accent: 'temp', dur: 18, guidance: 'structured',
    blurb: 'Heat exposure with an HR and temperature watch, plus a safety timer.',
    track: ['HR & temp trend', 'Safety timer', 'Before/after vitals'],
    coaching: 'Safety timer and HR-warning stop prompt.',
    how: [
      'Take a baseline reading before you enter.',
      'Tap Begin as you sit down in the heat.',
      'Vyana watches HR and temperature and runs a safety timer.',
      'If your heart rate climbs too high, it prompts you to step out.',
      'Read again after to see how you recovered.',
    ],
  ),
  Activity(
    id: 'coldPlunge', cat: 'wellness', name: 'Cold Plunge', ring: 'realTimeMonitoring',
    kind: 'recovery', gps: false, icon: 'snow', accent: 'spo2', dur: 4, guidance: 'structured',
    blurb: 'A timed plunge with the HR response and recovery captured.',
    track: ['HR response', 'Recovery', 'Before/after vitals'],
    coaching: 'Countdown timer with breathe-slow cue.',
    how: [
      'Take a baseline reading.',
      'Tap Begin as you enter the water.',
      'Breathe slow and steady; watch the timer.',
      'Read again after to see your rebound.',
    ],
  ),
  Activity(
    id: 'saunaCold', cat: 'wellness', name: 'Sauna & Cold Plunge',
    ring: 'realTimeMonitoring',
    kind: 'recovery', gps: false, icon: 'flame', accent: 'temp', dur: 30,
    guidance: 'none',
    blurb: 'Heat and cold in one session, with the HR swing through every '
        'round.',
    track: ['HR through each round', 'Total time', 'Before/after vitals'],
    coaching: 'HR-too-high prompt only; no timer.',
    how: [
      'Take a baseline reading before you start.',
      'Tap Start once — rounds need no taps in between.',
      'Vyana follows your heart rate through the heat and the cold.',
      'If your heart rate climbs too high, it prompts you to step out.',
      'Tap End when you are finished, however many rounds that took.',
    ],
  ),
  Activity(
    id: 'saunaSwim', cat: 'wellness', name: 'Sauna & Swim',
    ring: 'realTimeMonitoring',
    kind: 'recovery', gps: false, icon: 'flame', accent: 'temp', dur: 30,
    guidance: 'none',
    blurb: 'Sauna rounds with a swim between, tracked as one session.',
    track: ['HR through each round', 'Total time', 'Before/after vitals'],
    coaching: 'HR-too-high prompt only; no timer.',
    how: [
      'Take a baseline reading before you start.',
      'Tap Start once — rounds need no taps in between.',
      'Vyana follows your heart rate through the heat and the water.',
      'If your heart rate climbs too high, it prompts you to step out.',
      'Tap End when you are finished.',
    ],
  ),
  Activity(
    id: 'recovery', cat: 'wellness', name: 'Recovery Session', ring: 'realTimeMonitoring',
    kind: 'recovery', gps: false, icon: 'heart', accent: 'readiness', dur: 15, guidance: 'structured',
    blurb: 'A guided down-regulation measuring HRV and stress before and after.',
    track: ['HRV change', 'Stress before/after', 'Readiness impact'],
    coaching: 'Calm guidance, before/after capture.',
    how: [
      'Take a baseline reading.',
      'Tap Begin and rest in a comfortable position.',
      'Let the body down-regulate; read again after.',
    ],
  ),
  Activity(
    id: 'nap', cat: 'wellness', name: 'Nap / NSDR', ring: 'freeMode', kind: 'audio',
    gps: false, icon: 'moon', accent: 'luna', dur: 20, guidance: 'light',
    blurb: 'Non-sleep deep rest — an audio guide and the HR drop.',
    track: ['HR drop', 'Rest depth'],
    coaching: 'Soft NSDR script.',
    how: ['Lie down somewhere you won\'t be disturbed.', 'Tap Begin and let go.'],
  ),
  Activity(
    id: 'physio', cat: 'wellness', name: 'Physiotherapy', ring: 'freeMode',
    kind: 'strength', gps: false, icon: 'activity', accent: 'readiness', dur: 20, guidance: 'structured',
    blurb: 'Run your exercise checklist with adherence and gentle HR monitoring.',
    track: ['Adherence', 'Gentle HR'],
    coaching: 'Exercise checklist.',
    how: [
      'Open your prescribed checklist.',
      'Tap Begin and complete each exercise.',
      'Vyana tracks adherence over time.',
    ],
  ),
];

// ── Guide personas (on-device LLM) ──────────────────────────────────────────
class GuidePersona {
  const GuidePersona({
    required this.id,
    required this.name,
    required this.role,
    required this.accent,
    required this.tagline,
    required this.model,
    required this.icon,
    this.size,
    this.installed = false,
  });

  final String id;
  final String name;
  final String role;
  final String accent;
  final String tagline;
  final String model;
  final String icon;
  final String? size;
  final bool installed;
}

/// The one guide. Nova covers everything the earlier personas split between
/// them — sleep and recovery, dreams and reflective journaling, mindfulness
/// and breath, movement, nutrition — from a single on-device model, so there
/// is one assistant, one model and one row in You.
const kActiveGuides = <GuidePersona>[
  GuidePersona(id: 'nova', name: 'Nova', role: 'Your private guide', accent: 'nova', tagline: 'Sleep, mind, movement, nourishment', model: 'Gemma E2B · on-device', icon: 'brain'),
];

/// No downloadable personas: the single-assistant decision means the store
/// only ever installs Nova's model.
const kGuideStore = <GuidePersona>[];

GuidePersona? guideById(String id) {
  for (final g in [...kActiveGuides, ...kGuideStore]) {
    if (g.id == id) return g;
  }
  return null;
}

// ── Home dashboard seed (until the readiness/correlation engine lands) ───────
class ReadinessDriver {
  const ReadinessDriver(this.label, this.value, {this.good = true});
  final String label;
  final String value;
  final bool good;
}

class HomeInsight {
  const HomeInsight(this.guide, this.tag, this.text, this.accent);
  final String guide;
  final String tag;
  final String text;
  final String accent;
}

/// Weekly insights seed (the north-star correlation engine lands in M9; until
/// then this drives the Weekly screen's layout). Ported from data.js `weekly`.
class WeeklyInsight {
  const WeeklyInsight(this.tag, this.text, this.accent);
  final String tag;
  final String text;
  final String accent;
}

class WeeklySeed {
  WeeklySeed._();
  static const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const load = [38, 62, 20, 74, 30, 88, 26];
  static const calmMin = [22, 14, 35, 9, 28, 12, 40];
  static const hrvTrend = [48, 46, 52, 50, 55, 53, 58];
  static const activeDays = 6;
  static const strainLabel = 'Balanced';
  static const strainValue = 'Moderate';
  static const strainDetail = 'Two hard days well spaced by recovery.';
  static const northStar =
      'Easy Zone-2 runs the morning after 7h+ sleep lifted your HRV about two '
      'days later — by roughly 8%. The same run on short sleep did the opposite.';
  static const cards = <WeeklyInsight>[
    WeeklyInsight('Sleep → effort',
        'Your best sessions followed nights above 7 hours. Protect sleep before hard days.',
        'sleep'),
    WeeklyInsight('Calm',
        '126 calm minutes this week, up 18%. Pranayama is doing the heavy lifting.',
        'hrv'),
    WeeklyInsight('Recovery',
        'HRV trended up all week. A good window to add one more intensity day.',
        'readiness'),
  ];
}

class HomeSeed {
  HomeSeed._();
  static const userName = 'Aarav';
  static const streak = 14;
  static const readinessScore = 82;
  static const readinessLabel = 'Primed';
  static const readinessDelta = 6;
  static const drivers = <ReadinessDriver>[
    ReadinessDriver('HRV balance', 'Good'),
    ReadinessDriver('Resting HR', 'Optimal'),
    ReadinessDriver('Sleep', 'Fair', good: false),
    ReadinessDriver('Recovery', 'High'),
  ];
  static const quickPractices = ['breathwork', 'walk', 'sunSalutation'];
  static const insights = <HomeInsight>[
    HomeInsight('nova', 'Sleep', 'Your deep sleep dropped 18% on nights you trained after 7pm. Try winding down by 9:30.', 'luna'),
    HomeInsight('nova', 'Recovery', 'HRV climbed steadily this week — your recovery is trending up. A good window to push intensity.', 'nova'),
    HomeInsight('nova', 'Activity', "You're 660 steps from a 14-day streak. A short evening walk closes it.", 'steps'),
  ];
}

/// Keeps [registerUserActivities] in step with the table, so the catalogue
/// and every `activityById` lookup see the user's own sports.
final userActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  return ref.watch(databaseProvider).watchUserActivities().map((rows) {
    final activities = [
      for (final r in rows)
        userActivityToActivity(
          id: r.id,
          name: r.name,
          kind: r.kind,
          icon: r.icon,
        ),
    ];
    registerUserActivities(activities);
    return activities;
  });
});
