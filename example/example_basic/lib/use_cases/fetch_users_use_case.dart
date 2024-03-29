import 'dart:async';
import 'package:example_basic/services/user_service.dart';
import 'package:use_case/use_case.dart';
import '../main.dart';
import '../models/user.dart';

class FetchUsersUseCase extends UseCase<Map<String, dynamic>, List<User>> {
  static String fetchUsersUseCaseID = 'FetchUsersUseCase';

  @override
  FutureOr<List<User>> execute(Map<String, dynamic>? args) {
    int limit = _getLimit(args);

    return injector.get<UserService>().fetchUsers(limit);
  }

  int _getLimit(Map<String, dynamic>? args) {
    args ??= {};

    if (args.containsKey('limit')) {
      return args['limit'];
    }

    return 5;
  }
}
