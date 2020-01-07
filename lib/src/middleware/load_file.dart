import 'dart:html';

import 'package:redux/redux.dart';

import '../actions/actions.dart' as actions;
import '../app.dart';
import '../state/app_state.dart';

load_file_middleware(Store<AppState> store, action, NextDispatcher next) {
  next(action);
  if (action is actions.LoadDNAFile) {
    document.title = action.filename;
    app?.view?.design_view?.render(store.state);
  }
}