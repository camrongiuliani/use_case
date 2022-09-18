

import 'package:example_basic/main.dart';
import 'package:example_basic/pages/example/example_view_model.dart';
import 'package:example_basic/services/user_service.dart';
import 'package:example_basic/use_cases/fetch_users_use_case.dart';
import 'package:use_case/use_case.dart';

class ExampleBloc implements UseCaseObserver {

  final ExampleViewModel _viewModel;
  final UseCaseManager ucm;

  ExampleBloc(this._viewModel) : ucm = injector.get<UseCaseManager>();

  void fetchUsers() async {

    _viewModel.useCaseStates.value = [];
    _viewModel.users.value = [];

    await Future.delayed( const Duration( seconds: 1 ) );

    ucm.call( FetchUsersUseCase.fetchUsersUseCaseID, this );
  }

  @override
  void onUseCaseUpdate(UseCaseStatus update) {

    if ( update.id == FetchUsersUseCase.fetchUsersUseCaseID ) {

      _viewModel.useCaseStates.value = [
        ..._viewModel.useCaseStates.value,
        update.state
      ];

      switch ( update.state ) {
        case UseCaseState.done:
          _viewModel.users.value =  update.data ;
          break;
        case UseCaseState.error:
          _viewModel.users.value.clear();
          break;

        default:
      }

    }
  }
}