import 'package:flutter_webrtc/flutter_webrtc.dart';

final Map<String, dynamic> rtcConfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ],
};

final Map<String, dynamic> dataChannelConfig = {
  'ordered': true,
};
