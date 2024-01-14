import 'package:example_basic/models/user.dart';
import 'package:flutter/material.dart';
import 'package:use_case/use_case.dart';

class ExampleViewModel {
  ValueNotifier<List<User>> users = ValueNotifier([]);
  ValueNotifier<List<UseCaseState>> useCaseStates = ValueNotifier([]);

  getUser(int index) => users.value[index];
}
