import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_encryption_service.dart';

final mediaEncryptionServiceProvider = Provider<MediaEncryptionService>((ref) {
  return MediaEncryptionService();
});
