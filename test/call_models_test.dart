import 'package:dosti_app/features/call/call_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload() => {
      'status': 'matched',
      'matchId': 'm1',
      'channelId': 'ch1',
      'agoraToken': 'tok',
      'agoraUid': 11,
      'agoraAppId': 'app123',
      'matchedUser': {'id': 'p1', 'name': 'Bhavin', 'age': 26, 'city': 'Rajkot'},
    };

void main() {
  group('MatchInfo.tryParse', () {
    test('reads a valid match_found payload', () {
      final m = MatchInfo.tryParse(_payload())!;
      expect(m.matchId, 'm1');
      expect(m.channelId, 'ch1');
      expect(m.agoraToken, 'tok');
      expect(m.agoraUid, 11);
      expect(m.agoraAppId, 'app123');
      expect(m.partner.id, 'p1');
      expect(m.partner.name, 'Bhavin');
      expect(m.partner.age, 26);
      expect(m.partner.city, 'Rajkot');
    });

    test('a missing app id parses as empty (the controller reports it)', () {
      final p = _payload()..remove('agoraAppId');
      expect(MatchInfo.tryParse(p)!.agoraAppId, '');
    });

    test('missing optional partner fields get defaults', () {
      final p = _payload();
      p['matchedUser'] = {'id': 'p1', 'name': 'Bhavin'};
      final m = MatchInfo.tryParse(p)!;
      expect(m.partner.age, 0);
      expect(m.partner.city, '');
    });

    test('anything unusable gives null instead of throwing', () {
      expect(MatchInfo.tryParse(null), isNull);
      expect(MatchInfo.tryParse('x'), isNull);
      expect(MatchInfo.tryParse(<String, dynamic>{}), isNull);
      for (final key in ['matchId', 'channelId', 'agoraToken', 'agoraUid', 'matchedUser']) {
        expect(MatchInfo.tryParse(_payload()..remove(key)), isNull, reason: key);
      }
      expect(MatchInfo.tryParse(_payload()..['agoraToken'] = ''), isNull);
      expect(MatchInfo.tryParse(_payload()..['matchedUser'] = {'name': 'No id'}), isNull);
      expect(MatchInfo.tryParse(_payload()..['agoraUid'] = 'abc'), isNull);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(0), '00:00');
    expect(formatDuration(5), '00:05');
    expect(formatDuration(125), '02:05');
    expect(formatDuration(3600), '60:00');
  });

  test('every report reason is one the backend accepts', () {
    const backend = {'abuse', 'harassment', 'fake_profile', 'inappropriate_content', 'spam', 'underage', 'other'};
    expect(reportReasons.keys.toSet(), backend);
  });
}
