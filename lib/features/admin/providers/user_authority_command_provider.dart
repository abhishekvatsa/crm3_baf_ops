import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_authority_command_service.dart';

final userAuthorityCommandServiceProvider =
    Provider<UserAuthorityCommandService>((ref) {
      return UserAuthorityCommandService();
    });
