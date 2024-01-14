import 'package:example_basic/pages/example/example_bloc.dart';
import 'package:example_basic/pages/example/example_page.dart';
import 'package:example_basic/pages/example/example_view_model.dart';
import 'package:example_basic/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:use_case/use_case.dart';

import 'use_cases/fetch_users_use_case.dart';

final injector = GetIt.instance;

void main() {
  configureDependencies();

  runApp(const MyApp());
}

void configureDependencies() {
  injector.registerSingleton(UseCaseManager());
  injector.registerSingleton(UserService());

  injector
      .get<UseCaseManager>()
      .register<FetchUsersUseCase>(() => FetchUsersUseCase());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UseCase Demo',
      home: Builder(
        builder: (c) {
          ExampleViewModel vm = ExampleViewModel();
          ExampleBloc bloc = ExampleBloc(vm);
          return ExamplePage(
              title: 'UseCase Example', viewModel: vm, bloc: bloc);
        },
      ),
    );
  }
}
