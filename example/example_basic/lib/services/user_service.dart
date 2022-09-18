import 'dart:math';

import '../models/user.dart';

class UserService {

  // Simulate API call to get users.
  Future<List<User>> fetchUsers([int limit = 1]) {
    return Future.delayed( const Duration( seconds: 2 ), () {

      List<User> result = List.from([
        User( 'Bob', 'Smith' ),
        User( 'Jane', 'Doe' ),
        User( 'Mike', 'Robert' ),
        User( 'Alysia', 'Snell' ),
      ]);

      return result.sublist( 0, min(limit, result.length) );
    });
  }

}