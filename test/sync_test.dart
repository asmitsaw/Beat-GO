import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final RealtimeChannel? channel = null;
  channel?.sendBroadcastEvent(
    event: 'test',
    payload: {},
  );
}
