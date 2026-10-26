/// The other person of a match. Only what the backend decides to share (never the phone number).
class MatchPartner {
  const MatchPartner({required this.id, required this.name, required this.age, required this.city});

  final String id;
  final String name;
  final int age;
  final String city;
}

/// Everything needed to join the voice channel of one match, as sent by the backend's `match_found`.
class MatchInfo {
  const MatchInfo({
    required this.matchId,
    required this.channelId,
    required this.agoraToken,
    required this.agoraUid,
    required this.agoraAppId,
    required this.partner,
  });

  final String matchId;
  final String channelId;
  final String agoraToken;
  final int agoraUid;
  final String agoraAppId;
  final MatchPartner partner;

  /// Returns null when the server sent something unusable, so the app shows an error instead of crashing.
  static MatchInfo? tryParse(dynamic data) {
    if (data is! Map) return null;
    final partner = data['matchedUser'];
    final uid = data['agoraUid'];
    final matchId = data['matchId'];
    final channelId = data['channelId'];
    final token = data['agoraToken'];
    if (partner is! Map ||
        uid is! num ||
        matchId is! String ||
        matchId.isEmpty ||
        channelId is! String ||
        channelId.isEmpty ||
        token is! String ||
        token.isEmpty) {
      return null;
    }
    final partnerId = partner['id'];
    final partnerName = partner['name'];
    if (partnerId is! String || partnerId.isEmpty || partnerName is! String) return null;

    final age = partner['age'];
    final city = partner['city'];
    return MatchInfo(
      matchId: matchId,
      channelId: channelId,
      agoraToken: token,
      agoraUid: uid.toInt(),
      agoraAppId: data['agoraAppId'] is String ? data['agoraAppId'] as String : '',
      partner: MatchPartner(
        id: partnerId,
        name: partnerName,
        age: age is num ? age.toInt() : 0,
        city: city is String ? city : '',
      ),
    );
  }
}

enum CallPhase {
  /// Nothing going on.
  idle,

  /// In the queue, waiting for someone.
  searching,

  /// Match found, joining the voice channel and waiting for the other person.
  connecting,

  /// Both people are in the channel.
  inCall,

  /// Call over, showing the summary (rate / report).
  ended,
}

enum CallEndReason { youEnded, partnerLeft, noShow, connectionLost, timeLimit, failed }

/// Why starting a search did not work, or that it did.
enum StartResult { started, busy, notConnected, micDenied, micPermanentlyDenied }

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.match,
    this.muted = false,
    this.speakerOn = true,
    this.reconnecting = false,
    this.partnerPresent = false,
    this.searchSeconds = 0,
    this.elapsedSeconds = 0,
    this.endReason,
    this.notice,
  });

  final CallPhase phase;
  final MatchInfo? match;
  final bool muted;
  final bool speakerOn;

  /// Voice connection dropped and is being re-established.
  final bool reconnecting;
  final bool partnerPresent;
  final int searchSeconds;

  /// Length of the call so far; after the call, the final length.
  final int elapsedSeconds;
  final CallEndReason? endReason;

  /// A message for the Match tab to show once the call screen closes (for example "No one is available").
  final String? notice;

  CallState copyWith({
    CallPhase? phase,
    MatchInfo? match,
    bool? muted,
    bool? speakerOn,
    bool? reconnecting,
    bool? partnerPresent,
    int? searchSeconds,
    int? elapsedSeconds,
    CallEndReason? endReason,
    String? notice,
    bool clearNotice = false,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        match: match ?? this.match,
        muted: muted ?? this.muted,
        speakerOn: speakerOn ?? this.speakerOn,
        reconnecting: reconnecting ?? this.reconnecting,
        partnerPresent: partnerPresent ?? this.partnerPresent,
        searchSeconds: searchSeconds ?? this.searchSeconds,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        endReason: endReason ?? this.endReason,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// 125 -> "02:05"
String formatDuration(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Reasons the backend accepts for a report, with the text shown to the user.
const reportReasons = <String, String>{
  'abuse': 'Abusive language',
  'harassment': 'Harassment',
  'inappropriate_content': 'Inappropriate content',
  'fake_profile': 'Fake profile',
  'spam': 'Spam',
  'underage': 'Seems under 18',
  'other': 'Something else',
};
