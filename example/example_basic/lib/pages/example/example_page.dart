
import 'package:example_basic/models/user.dart';
import 'package:example_basic/pages/example/example_bloc.dart';
import 'package:example_basic/pages/example/example_view_model.dart';
import 'package:flutter/material.dart';

class ExamplePage extends StatefulWidget {

  final ExampleViewModel viewModel;
  final ExampleBloc bloc;

  const ExamplePage({ required this.title, required this.viewModel, required this.bloc, super.key });

  final String title;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(

        children: [

          ValueListenableBuilder(
            valueListenable: widget.viewModel.useCaseStates,
            builder: ( ctx, val, _) {

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text( 'States:' ),
                  ),
                  ListView.builder(
                    itemCount: widget.viewModel.useCaseStates.value.length,
                    shrinkWrap: true,
                    itemBuilder: ( ctx, idx ) {

                      return Center(
                        child: Text( widget.viewModel.useCaseStates.value[ idx ].toString() ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox( height: 16.0, ),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: widget.viewModel.users,
              builder: ( ctx, val, _) => ListView.builder(
                itemCount: widget.viewModel.users.value.length,
                itemBuilder: ( ctx, idx ) {

                  User user = widget.viewModel.getUser( idx );

                  return Center(
                    child: Text( '${user.lastName}, ${user.firstName}' ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.bloc.fetchUsers(),
        tooltip: 'Fetch Users',
        child: const Icon(Icons.sync),
      ),
    );
  }
}
