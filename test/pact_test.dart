import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/pacts/client.dart';
import 'package:vyana/src/pacts/models.dart';

void main() {
  test('a Pact is secured once the required days are proven', () {
    expect(
      pactStatus(done: 5, required: 5, elapsed: 5, total: 7),
      PactStatus.secured,
    );
    expect(
      pactStatus(done: 5, required: 5, elapsed: 7, total: 7),
      PactStatus.secured,
    );
  });

  test('a Pact with slack left is on track, without slack it is at risk', () {
    expect(
      pactStatus(done: 4, required: 5, elapsed: 5, total: 7),
      PactStatus.onTrack,
    );
    expect(
      pactStatus(done: 3, required: 5, elapsed: 5, total: 7),
      PactStatus.atRisk,
    );
  });

  test('a Pact that cannot catch up is not labelled failed', () {
    expect(
      pactStatus(done: 2, required: 5, elapsed: 5, total: 7),
      PactStatus.missed,
    );
    expect(pactStatusLabel(PactStatus.missed), 'Cannot catch up');
  });

  test('day timeline keeps freeze and restore distinct from done or empty', () {
    final me = PactMe.fromJson({
      'done': 2,
      'required': 3,
      'elapsed': 1,
      'total': 3,
      'status': 'active',
      'currentStreak': 2,
      'freezesRemaining': 0,
      'restoresRemaining': 1,
      'days': [
        {'date': '2026-08-18', 'dayNumber': 1, 'status': 'done'},
        {'date': '2026-08-19', 'dayNumber': 2, 'status': 'freeze'},
        {'date': '2026-08-20', 'dayNumber': 3, 'status': 'today'},
      ],
    });

    expect(me.days.map((d) => d.status).toList(), [
      PactDayStatus.done,
      PactDayStatus.freeze,
      PactDayStatus.today,
    ]);
    expect(me.dayIs('2026-08-19', PactDayStatus.freeze), isTrue);
    expect(me.standing, PactStatus.onTrack);
  });

  test('unlocks keep the full window ladder, XP, and lock copy', () {
    final locked = PactUnlocks.fromJson({
      'completed': 0,
      'cap': 1,
      'slotsUsed': 0,
      'slotsFree': 1,
      'xpBalance': 40,
      'unlocks': {
        'modes': ['just_me'],
        'windowDays': [3],
        'stakes': [],
        'backing': false,
      },
      'windowTiers': [
        {'days': 3, 'unlockAt': 0, 'label': '3 days', 'unlocked': true},
        {'days': 5, 'unlockAt': 5, 'label': '5 days', 'unlocked': false},
        {'days': 7, 'unlockAt': 7, 'label': '1 week', 'unlocked': false},
        {'days': 14, 'unlockAt': 10, 'label': '2 weeks', 'unlocked': false},
        {'days': 30, 'unlockAt': 15, 'label': '1 month', 'unlocked': false},
      ],
    });
    final fiveDone = PactUnlocks.fromJson({
      'completed': 5,
      'cap': 2,
      'slotsUsed': 0,
      'slotsFree': 2,
      'xpBalance': 120,
      'unlocks': {
        'modes': ['just_me', 'challenge'],
        'windowDays': [3, 5],
        'stakes': ['coffee'],
        'backing': true,
      },
    });

    expect(locked.windowDays, [3]);
    expect(locked.xpBalance, 40);
    expect(locked.currentStreak, 0);
    expect(locked.windowTiers.map((t) => t.days).toList(), [3, 5, 7, 14, 30]);
    expect(locked.windowTiers[1].unlocked, isFalse);
    expect(locked.windowTiers[1].lockHint, 'Unlock after 5 successful pacts');
    expect(fiveDone.windowDays, [3, 5]);
    expect(fiveDone.windowTiers.firstWhere((t) => t.days == 5).unlocked, isTrue);
    expect(fiveDone.windowTiers.firstWhere((t) => t.days == 7).unlocked, isFalse);
    expect(locked.justMe, isTrue);
    expect(locked.nextLockedTier?.days, 5);
  });

  test('unlocks treat missing XP as zero and keep create slots', () {
    final parsed = PactUnlocks.fromJson({
      'completed': 0,
      'slotsUsed': 1,
      'slotsFree': 2,
      'unlocks': {
        'modes': ['just_me'],
        'windowDays': [3],
      },
    });
    expect(parsed.xpBalance, 0);
    expect(parsed.cap, 3);
    expect(parsed.canCreate, isTrue);
    expect(parsed.currentStreak, 0);
  });

  test('create payload is Just Me with an allowed window', () {
    final body = const PactCreateInput(
      title: 'Earlier night',
      ruleText: 'In bed before 11:45',
      category: 'sleep',
      windowDays: 3,
      requiredDays: 3,
    ).toJson();

    expect(body['mode'], 'just_me');
    expect(body['windowDays'], 3);
    expect(body.containsKey('stake'), isFalse);
  });

  test('PactClient hits Phase 1 endpoints and sends Bearer + proof body', () async {
    final calls = <PactHttpRequest>[];
    final client = PactClient(
      baseUrl: 'https://seeknirvana.com',
      readAccessToken: () async => 'access-token',
      transport: (request) async {
        calls.add(request);
        final path = request.url.path;
        if (path == '/api/pacts/today') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'pacts': [
                {
                  'id': 'p1',
                  'title': '3-Day Show Up',
                  'ruleText': 'Tick the day',
                  'category': 'mindfulness',
                  'mode': 'just_me',
                  'goalMetric': 'custom',
                  'windowDays': 3,
                  'requiredDays': 3,
                  'startsOn': '2026-08-18',
                  'endsOn': '2026-08-20',
                  'proofMode': 'self',
                  'status': 'active',
                  'today': '2026-08-20',
                  'todayStatus': 'today',
                  'me': {
                    'done': 1,
                    'required': 3,
                    'elapsed': 3,
                    'total': 3,
                    'status': 'active',
                    'currentStreak': 1,
                    'freezesRemaining': 1,
                    'restoresRemaining': 1,
                    'days': [
                      {'date': '2026-08-18', 'dayNumber': 1, 'status': 'done'},
                      {'date': '2026-08-19', 'dayNumber': 2, 'status': 'missed'},
                      {'date': '2026-08-20', 'dayNumber': 3, 'status': 'today'},
                    ],
                  },
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/p1/proof') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'date': '2026-08-20',
              'satisfied': true,
              'xpAwarded': 10,
              'me': {
                'done': 2,
                'required': 3,
                'elapsed': 3,
                'total': 3,
                'status': 'active',
                'days': [],
                'currentStreak': 1,
                'freezesRemaining': 1,
                'restoresRemaining': 1,
              },
            }),
          );
        }
        return const PactHttpResponse(404, '{"error":"not_found"}');
      },
    );

    final today = await client.today();
    expect(today, hasLength(1));
    expect(today.first.pact.windowDays, 3);
    expect(today.first.canProve, isTrue);
    expect(today.first.todayDone, isFalse);

    final me = await client.proof('p1', date: '2026-08-20', satisfied: true);
    expect(me.done, 2);
    expect(calls.last.method, 'PUT');
    expect(calls.last.headers['Authorization'], 'Bearer access-token');
    expect(jsonDecode(calls.last.body!), {
      'date': '2026-08-20',
      'satisfied': true,
      'source': 'manual',
    });
  });

  test('PactClient refreshes once on 401 then retries the original call', () async {
    var unlockHits = 0;
    final client = PactClient(
      baseUrl: 'https://seeknirvana.com',
      readAccessToken: () async => 'stale',
      readRefreshToken: () async => 'refresh-token',
      onTokens: ({required accessToken, refreshToken}) async {},
      transport: (request) async {
        if (request.url.path == '/api/auth/refresh') {
          expect(jsonDecode(request.body!), {'refreshToken': 'refresh-token'});
          return PactHttpResponse(
            200,
            jsonEncode({'ok': true, 'accessToken': 'fresh', 'refreshToken': 'next'}),
          );
        }
        if (request.url.path == '/api/pacts/unlocks') {
          unlockHits++;
          if (unlockHits == 1) {
            return const PactHttpResponse(401, '{"error":"unauthorized"}');
          }
          return PactHttpResponse(
            200,
            jsonEncode({
              'completed': 0,
              'cap': 1,
              'slotsUsed': 0,
              'slotsFree': 1,
              'unlocks': {
                'modes': ['just_me'],
                'windowDays': [3],
                'stakes': [],
                'backing': false,
              },
            }),
          );
        }
        return const PactHttpResponse(500, '{"error":"unexpected"}');
      },
    );

    final unlocks = await client.unlocks();
    expect(unlocks.windowDays, [3]);
    expect(unlockHits, 2);
  });

  test('unlocks expose social modes and stakes with lock copy', () {
    final fresh = PactUnlocks.fromJson({
      'completed': 0,
      'cap': 1,
      'slotsUsed': 0,
      'slotsFree': 1,
      'unlocks': {
        'modes': ['just_me'],
        'windowDays': [3],
        'stakes': [],
        'backing': true,
      },
      'locked': {
        'modes': ['challenge', 'friends'],
        'stakes': ['coffee', 'lunch'],
      },
    });
    final social = PactUnlocks.fromJson({
      'completed': 3,
      'cap': 2,
      'slotsUsed': 0,
      'slotsFree': 2,
      'unlocks': {
        'modes': ['just_me', 'challenge', 'friends'],
        'windowDays': [3],
        'stakes': ['coffee', 'lunch', 'drinks', 'pizza'],
        'backing': true,
      },
    });

    expect(fresh.canChallenge, isFalse);
    expect(fresh.canFriends, isFalse);
    expect(fresh.modeLockHint('challenge'), 'Unlock after 2 successful pacts');
    expect(fresh.modeLockHint('friends'), 'Unlock after 3 successful pacts');
    expect(fresh.stakes, isEmpty);
    expect(social.canChallenge, isTrue);
    expect(social.canFriends, isTrue);
    expect(social.stakes, ['coffee', 'lunch', 'drinks', 'pizza']);
    expect(social.modeLockHint('challenge'), '');
  });

  test('a Versus create payload carries a social stake and friends visibility', () {
    final body = const PactCreateInput(
      title: 'Dawn walk',
      ruleText: 'Walk before 8',
      category: 'movement',
      windowDays: 3,
      requiredDays: 3,
      mode: 'challenge',
      stakeCatalog: 'coffee',
      visibility: 'friends',
      maxParticipants: 2,
    ).toJson();

    expect(body['mode'], 'challenge');
    expect(body['stakeCatalog'], 'coffee');
    expect(body['visibility'], 'friends');
    expect(body['maxParticipants'], 2);
  });

  test('others progress is counts only and never a losing status', () {
    final other = PactOther.fromJson({
      'participantId': 'part-2',
      'profileId': 'p2',
      'displayName': 'Sam',
      'done': 2,
      'required': 3,
      'status': 'ended',
    });

    expect(other.participantId, 'part-2');
    expect(other.done, 2);
    expect(other.required, 3);
    expect(other.status, 'active');
    expect(other.displayName, 'Sam');
  });

  test('settlement copy never lists a loser', () {
    final lost = PactSettlement.fromJson({
      'settled': true,
      'stake': 'Coffee',
      'outcome': 'lost',
      'message': 'Coffee on you',
      'winners': [
        {'profileId': 'p2', 'displayName': 'Sam'},
      ],
    });
    final expired = PactBacking.fromJson({
      'id': 'b1',
      'participantId': 'part-1',
      'item': 'Dinner',
      'message': 'You have this',
      'status': 'expired',
      'mine': true,
    });

    expect(lost.message, 'Coffee on you');
    expect(lost.winners.single.displayName, 'Sam');
    expect(expired.endedCopy, 'This pact ended');
  });

  test('a backing names the backer and stays visible after the pledge', () {
    final backing = PactBacking.fromJson({
      'id': 'b1',
      'participantId': 'part-1',
      'item': 'Dinner',
      'message': 'You have this',
      'status': 'pledged',
      'mine': false,
      'backer': {'profileId': 'f1', 'displayName': 'Sam'},
    });
    final me = PactMe.fromJson({
      'participantId': 'part-1',
      'isCreator': true,
      'done': 1,
      'required': 3,
      'elapsed': 1,
      'total': 3,
      'status': 'active',
      'days': [],
      'currentStreak': 1,
      'freezesRemaining': 1,
      'restoresRemaining': 1,
    });
    final progress = PactProgress.fromJson({
      'today': '2026-08-20',
      'me': {
        'participantId': 'part-1',
        'isCreator': true,
        'done': 1,
        'required': 3,
        'elapsed': 1,
        'total': 3,
        'status': 'active',
        'days': [],
        'currentStreak': 1,
        'freezesRemaining': 1,
        'restoresRemaining': 1,
      },
      'others': [],
      'backings': [
        {
          'id': 'b1',
          'participantId': 'part-1',
          'item': 'Dinner',
          'status': 'pledged',
          'mine': false,
          'backer': {'profileId': 'f1', 'displayName': 'Sam'},
        },
      ],
    });

    expect(backing.backer?.displayName, 'Sam');
    expect(me.isCreator, isTrue);
    expect(me.participantId, 'part-1');
    expect(progress.backings.single.backer?.displayName, 'Sam');
    expect(progress.backingsFor('part-1').single.item, 'Dinner');
  });

  test('PactClient hits friends, join, board, backable and progress others', () async {
    final calls = <PactHttpRequest>[];
    final client = PactClient(
      baseUrl: 'https://seeknirvana.com',
      readAccessToken: () async => 'access-token',
      transport: (request) async {
        calls.add(request);
        final path = request.url.path;
        if (path == '/api/friends') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'friends': [
                {
                  'profileId': 'f1',
                  'displayName': 'Sam',
                  'weeklyPactXp': 40,
                  'pactsCompleted': 2,
                  'currentStreak': 1,
                },
              ],
            }),
          );
        }
        if (path == '/api/friends/requests') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'incoming': [
                {
                  'id': 'req-1',
                  'createdAt': '2026-08-20T00:00:00.000Z',
                  'profile': {'profileId': 'f2', 'displayName': 'Alex'},
                },
              ],
              'outgoing': [],
            }),
          );
        }
        if (path == '/api/pacts/join') {
          return PactHttpResponse(
            201,
            jsonEncode({'pactId': 'p2', 'participantId': 'me', 'requiredDays': 2, 'xpAwarded': 25}),
          );
        }
        if (path == '/api/pacts/p2/invites') {
          return PactHttpResponse(200, jsonEncode({'invited': ['f1'], 'skipped': []}));
        }
        if (path == '/api/pacts/leaderboard') {
          expect(request.url.queryParameters['scope'], 'friends');
          return PactHttpResponse(
            200,
            jsonEncode({
              'scope': 'friends',
              'weekStart': '2026-08-17T00:00:00.000Z',
              'entries': [
                {
                  'profileId': 'me',
                  'displayName': 'You',
                  'weeklyPactXp': 70,
                  'isYou': true,
                  'rank': 1,
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/backable') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'unlocked': true,
              'candidates': [
                {
                  'participantId': 'part-9',
                  'pact': {
                    'id': 'p9',
                    'title': 'Earlier night',
                    'ruleText': 'Bed by 11',
                    'category': 'sleep',
                    'mode': 'friends',
                    'goalMetric': 'custom',
                    'windowDays': 3,
                    'requiredDays': 3,
                    'startsOn': '2026-08-18',
                    'endsOn': '2026-08-20',
                    'proofMode': 'self',
                    'status': 'active',
                  },
                  'person': {
                    'profileId': 'f1',
                    'displayName': 'Sam',
                    'done': 1,
                    'required': 3,
                    'status': 'active',
                  },
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/p9/backings') {
          return PactHttpResponse(
            201,
            jsonEncode({'id': 'b1', 'status': 'pledged', 'xpAwarded': 15}),
          );
        }
        if (path == '/api/pacts/p1/progress') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'today': '2026-08-20',
              'me': {
                'done': 1,
                'required': 3,
                'elapsed': 1,
                'total': 3,
                'status': 'active',
                'days': [],
                'currentStreak': 1,
                'freezesRemaining': 1,
                'restoresRemaining': 1,
              },
              'others': [
                {
                  'participantId': 'part-2',
                  'profileId': 'f1',
                  'displayName': 'Sam',
                  'done': 2,
                  'required': 3,
                  'status': 'ended',
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/p1/encourage') {
          return PactHttpResponse(201, jsonEncode({'sent': true, 'xpAwarded': 5}));
        }
        if (path == '/api/pacts/backing') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'pledges': [
                {
                  'participantId': 'part-9',
                  'pact': {
                    'id': 'p9',
                    'title': 'Earlier night',
                    'ruleText': 'Bed by 11',
                    'category': 'sleep',
                    'mode': 'friends',
                    'goalMetric': 'custom',
                    'windowDays': 3,
                    'requiredDays': 3,
                    'startsOn': '2026-08-18',
                    'endsOn': '2026-08-20',
                    'proofMode': 'self',
                    'status': 'active',
                    'creatorId': 'f1',
                  },
                  'person': {
                    'profileId': 'f1',
                    'displayName': 'Sam',
                    'done': 1,
                    'required': 3,
                    'status': 'active',
                  },
                  'backing': {
                    'id': 'b1',
                    'participantId': 'part-9',
                    'item': 'Dinner',
                    'status': 'pledged',
                    'mine': true,
                  },
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/p1/backings') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'backings': [
                {
                  'id': 'b2',
                  'participantId': 'me',
                  'item': 'Coffee',
                  'status': 'pledged',
                  'mine': false,
                  'backer': {'profileId': 'f1', 'displayName': 'Sam'},
                },
              ],
            }),
          );
        }
        return const PactHttpResponse(404, '{"error":"not_found"}');
      },
    );

    final friends = await client.friends();
    expect(friends.single.displayName, 'Sam');
    expect(friends.single.weeklyPactXp, 40);

    final requests = await client.friendRequests();
    expect(requests.incoming.single.id, 'req-1');

    final joined = await client.join(shareCode: 'ABCD');
    expect(joined.pactId, 'p2');
    expect(jsonDecode(calls.last.body!), {'shareCode': 'ABCD'});

    await client.inviteToPact('p2', ['f1']);
    expect(calls.last.method, 'POST');
    expect(jsonDecode(calls.last.body!), {
      'profileIds': ['f1'],
    });

    final board = await client.leaderboard();
    expect(board.entries.single.isYou, isTrue);
    expect(board.entries.single.rank, 1);

    final backable = await client.backable();
    expect(backable.single.participantId, 'part-9');
    expect(backable.single.person.displayName, 'Sam');

    await client.backPact('p9', participantId: 'part-9', itemLabel: 'Dinner');
    expect(jsonDecode(calls.last.body!), {
      'participantId': 'part-9',
      'pledgeType': 'item',
      'itemLabel': 'Dinner',
      'message': '',
    });

    final progress = await client.progress('p1');
    expect(progress.others.single.status, 'active');
    expect(progress.others.single.participantId, 'part-2');

    await client.encourage('p1', participantId: 'part-2', message: 'Keep going');
    expect(jsonDecode(calls.last.body!), {
      'participantId': 'part-2',
      'message': 'Keep going',
    });

    final mine = await client.myBackings();
    expect(mine.single.person.displayName, 'Sam');
    expect(mine.single.backing?.mine, isTrue);
    expect(mine.single.backing?.item, 'Dinner');

    final onPact = await client.backings('p1');
    expect(onPact.single.backer?.displayName, 'Sam');
    expect(onPact.single.item, 'Coffee');
  });

  test('21-day sits on the window ladder and unlocks after 12 kept pacts', () {
    final twelve = PactUnlocks.fromJson({
      'completed': 12,
      'cap': 3,
      'slotsUsed': 0,
      'slotsFree': 3,
      'unlocks': {
        'modes': ['just_me', 'challenge', 'friends'],
        'windowDays': [3, 5, 7, 14, 21],
        'stakes': ['coffee'],
        'backing': true,
        'maxParticipants': 12,
      },
    });
    final twentyOne = twelve.windowTiers.firstWhere((t) => t.days == 21);

    expect(twelve.windowTiers.map((t) => t.days).toList(), [3, 5, 7, 14, 21, 30]);
    expect(twentyOne.unlocked, isTrue);
    expect(twentyOne.label, '3 weeks');
    expect(twelve.windowTiers.firstWhere((t) => t.days == 30).unlocked, isFalse);
    expect(twelve.canCircles, isTrue);
    expect(twelve.maxParticipants, 12);
  });

  test('circles stay locked until the feature row says otherwise', () {
    final locked = PactUnlocks.fromJson({
      'completed': 3,
      'cap': 2,
      'slotsUsed': 0,
      'slotsFree': 2,
      'unlocks': {
        'modes': ['just_me', 'challenge', 'friends'],
        'windowDays': [3],
      },
      'locked': [
        {
          'key': 'community.circles',
          'category': 'community',
          'unlockAt': 7,
          'completionsAway': 4,
        },
        {
          'key': 'window.21',
          'category': 'window',
          'value': 21,
          'unlockAt': 12,
          'completionsAway': 9,
        },
      ],
    });

    expect(locked.canCircles, isFalse);
    expect(locked.circlesLockHint, 'Unlock after 7 successful pacts');
    expect(locked.canTemplates, isTrue);
    expect(locked.canSuggested, isTrue);
  });

  test('a circle, template, and suggestion parse without inventing failure', () {
    final circle = PactCommunity.fromJson({
      'id': 'c1',
      'kind': 'circle',
      'name': 'Dawn Walkers',
      'description': '',
      'memberCount': 3,
      'maxMembers': 12,
      'currentPactId': null,
      'myRole': 'owner',
      'myStatus': 'active',
    });
    final invite = PactCommunity.fromJson({
      'id': 'c2',
      'kind': 'circle',
      'name': 'Night Owls',
      'memberCount': 2,
      'maxMembers': 12,
      'myRole': 'member',
      'myStatus': 'invited',
    });
    final template = PactTemplate.fromJson({
      'slug': 'earlier-nights',
      'title': 'Earlier nights',
      'description': 'In bed before 11:30',
      'category': 'sleep',
      'author': 'Seek Nirvana',
      'windowDays': 7,
      'requiredDays': 5,
      'goalMetric': 'bedtime_before',
      'goalValue': null,
      'goalUnit': '',
      'proofMode': 'both',
      'joinCount': 12,
      'available': true,
      'unlocksAt': 7,
    });
    final suggestion = PactSuggestion.fromJson({
      'key': 'move-more',
      'title': 'Move a little more',
      'reason': 'You have averaged about 4,200 steps a day.',
      'category': 'movement',
      'goalMetric': 'steps_min',
      'goalValue': 5000,
      'goalUnit': 'steps',
      'windowDays': 7,
      'requiredDays': 5,
    });

    expect(circle.isOwner, isTrue);
    expect(circle.seats, '3/12');
    expect(invite.isInvited, isTrue);
    expect(template.available, isTrue);
    expect(template.toCreate().title, 'Earlier nights');
    expect(template.toCreate().windowDays, 7);
    expect(template.toCreate().templateSlug, 'earlier-nights');
    expect(suggestion.toCreate().goalValue, 5000);
    expect(suggestion.toCreate().mode, 'just_me');
  });

  test('global board is a percentile, circle board is names', () {
    final global = PactLeaderboard.fromJson({
      'scope': 'global',
      'weekStart': '2026-08-17T00:00:00.000Z',
      'weeklyPactXp': 40,
      'population': 200,
      'rank': null,
      'percentile': 62,
      'entries': [],
      'availableScopes': ['friends', 'community', 'global'],
      'myCommunityIds': ['c1'],
    });
    final circle = PactLeaderboard.fromJson({
      'scope': 'community',
      'communityId': 'c1',
      'weekStart': '2026-08-17T00:00:00.000Z',
      'availableScopes': ['friends', 'community', 'global'],
      'myCommunityIds': ['c1'],
      'entries': [
        {
          'profileId': 'me',
          'displayName': 'You',
          'weeklyPactXp': 40,
          'isYou': true,
          'rank': 2,
        },
      ],
    });

    expect(global.isPercentile, isTrue);
    expect(global.percentile, 62);
    expect(global.rank, isNull);
    expect(global.entries, isEmpty);
    expect(global.availableScopes, ['friends', 'community', 'global']);
    expect(circle.isPercentile, isFalse);
    expect(circle.communityId, 'c1');
    expect(circle.entries.single.rank, 2);
  });

  test('PactClient hits circles, templates, suggestions and scoped boards', () async {
    final calls = <PactHttpRequest>[];
    final client = PactClient(
      baseUrl: 'https://seeknirvana.com',
      readAccessToken: () async => 'access-token',
      transport: (request) async {
        calls.add(request);
        final path = request.url.path;
        if (path == '/api/communities') {
          if (request.method == 'POST') {
            expect(jsonDecode(request.body!), {'name': 'Dawn Walkers'});
            return PactHttpResponse(
              201,
              jsonEncode({
                'id': 'c1',
                'kind': 'circle',
                'name': 'Dawn Walkers',
                'memberCount': 1,
                'maxMembers': 12,
                'myRole': 'owner',
                'myStatus': 'active',
                'xpAwarded': 25,
              }),
            );
          }
          return PactHttpResponse(
            200,
            jsonEncode({
              'communities': [
                {
                  'id': 'c1',
                  'kind': 'circle',
                  'name': 'Dawn Walkers',
                  'memberCount': 1,
                  'maxMembers': 12,
                  'myRole': 'owner',
                  'myStatus': 'active',
                },
              ],
            }),
          );
        }
        if (path == '/api/communities/c1') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'id': 'c1',
              'kind': 'circle',
              'name': 'Dawn Walkers',
              'memberCount': 2,
              'maxMembers': 12,
              'myRole': 'owner',
              'myStatus': 'active',
              'members': [
                {
                  'profileId': 'me',
                  'displayName': 'You',
                  'weeklyPactXp': 20,
                  'role': 'owner',
                  'status': 'active',
                  'isYou': true,
                },
              ],
            }),
          );
        }
        if (path == '/api/communities/c1/invites') {
          return PactHttpResponse(
            201,
            jsonEncode({
              'invited': ['f1'],
              'skipped': [],
            }),
          );
        }
        if (path == '/api/communities/c1/join') {
          return PactHttpResponse(200, jsonEncode({'joined': true, 'xpAwarded': 15}));
        }
        if (path == '/api/communities/c1/leave') {
          return PactHttpResponse(200, jsonEncode({'left': true, 'deleted': false}));
        }
        if (path == '/api/communities/c1/pact') {
          return PactHttpResponse(
            201,
            jsonEncode({
              'pact': {
                'id': 'p9',
                'title': 'Dawn walk',
                'ruleText': 'Walk before 8',
                'category': 'movement',
                'mode': 'friends',
                'goalMetric': 'custom',
                'windowDays': 7,
                'requiredDays': 5,
                'startsOn': '2026-08-20',
                'endsOn': '2026-08-26',
                'proofMode': 'self',
                'status': 'active',
                'shareCode': 'WAVE1',
              },
              'shareCode': 'WAVE1',
              'xpAwarded': 25,
            }),
          );
        }
        if (path == '/api/pacts/templates') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'templates': [
                {
                  'slug': 'earlier-nights',
                  'title': 'Earlier nights',
                  'description': 'In bed before 11:30',
                  'category': 'sleep',
                  'author': 'Seek Nirvana',
                  'windowDays': 7,
                  'requiredDays': 5,
                  'available': true,
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/suggested') {
          return PactHttpResponse(
            200,
            jsonEncode({
              'today': '2026-08-20',
              'daysObserved': 10,
              'minDaysNeeded': 5,
              'suggestions': [
                {
                  'key': 'move-more',
                  'title': 'Move a little more',
                  'reason': 'Averaging 4,200 steps.',
                  'category': 'movement',
                  'windowDays': 7,
                  'requiredDays': 5,
                },
              ],
            }),
          );
        }
        if (path == '/api/pacts/leaderboard') {
          final scope = request.url.queryParameters['scope'];
          if (scope == 'global') {
            return PactHttpResponse(
              200,
              jsonEncode({
                'scope': 'global',
                'weeklyPactXp': 40,
                'population': 200,
                'rank': null,
                'percentile': 62,
                'entries': [],
              }),
            );
          }
          expect(scope, 'community');
          expect(request.url.queryParameters['communityId'], 'c1');
          return PactHttpResponse(
            200,
            jsonEncode({
              'scope': 'community',
              'communityId': 'c1',
              'entries': [
                {'profileId': 'me', 'displayName': 'You', 'weeklyPactXp': 40, 'isYou': true, 'rank': 1},
              ],
            }),
          );
        }
        return const PactHttpResponse(404, '{"error":"not_found"}');
      },
    );

    final mine = await client.communities();
    expect(mine.single.name, 'Dawn Walkers');

    final created = await client.createCommunity(name: 'Dawn Walkers');
    expect(created.isOwner, isTrue);

    final detail = await client.community('c1');
    expect(detail.members.single.isYou, isTrue);

    await client.inviteToCommunity('c1', ['f1']);
    expect(jsonDecode(calls.last.body!), {'profileIds': ['f1']});

    await client.joinCommunity('c1');
    await client.leaveCommunity('c1');

    final wave = await client.startCommunityPact(
      'c1',
      const PactCreateInput(
        title: 'Dawn walk',
        ruleText: 'Walk before 8',
        category: 'movement',
        windowDays: 7,
        requiredDays: 5,
      ),
    );
    expect(wave.shareCode, 'WAVE1');

    final templates = await client.templates();
    expect(templates.single.slug, 'earlier-nights');

    final suggested = await client.suggested();
    expect(suggested.single.key, 'move-more');

    final global = await client.leaderboard(scope: 'global');
    expect(global.percentile, 62);

    final circleBoard = await client.leaderboard(scope: 'community', communityId: 'c1');
    expect(circleBoard.entries.single.isYou, isTrue);
  });

  test('phase 3 errors stay human', () {
    expect(pactErrorMessage('circles_locked'), 'Circles unlock after 7 successful pacts.');
    expect(pactErrorMessage('already_owns_circle'), 'You already have a circle.');
    expect(pactErrorMessage('templates_locked'), 'Templates are not open yet.');
    expect(pactErrorMessage('community_full'), 'That circle is full.');
    expect(pactErrorMessage('community_pact_in_flight'), 'This circle already has a pact running.');
  });
}
