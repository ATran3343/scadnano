@JS()
library app;

import 'dart:html';

import 'package:js/js.dart';
import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:platform_detect/platform_detect.dart';
import 'package:redux/redux.dart';
import 'package:path/path.dart' as p;
import 'package:redux_dev_tools/redux_dev_tools.dart';
import 'package:scadnano/src/middleware/all_middleware.dart';
import 'package:over_react/over_react.dart' as react;

import 'package:scadnano/src/middleware/throttle.dart';
import 'package:scadnano/src/state/dna_ends_move.dart';
import 'package:scadnano/src/state/potential_crossover.dart';
import 'package:scadnano/src/view/menu.dart';
import 'actions/actions.dart';
import 'reducers/dna_ends_move_reducer.dart';
import 'reducers/potential_crossover_reducer.dart';
import 'state/app_state.dart';
import 'state/selection_box.dart';
import 'state/undo_redo.dart';
import 'reducers/selection_reducer.dart';
import 'view/design.dart';
import 'view/view.dart';
import 'reducers/app_state_reducer.dart';
import 'middleware/local_storage.dart';
import 'middleware/all_middleware.dart';
import 'util.dart' as util;
import 'actions/actions.dart' as actions;
import 'constants.dart' as constants;
import 'dna_sequence_constants.dart';

//import 'test.dart';
//import 'constants.dart' as constants;

// global variable for whole program
App app = App();

//const USE_REDUX_DEV_TOOLS = false;
const USE_REDUX_DEV_TOOLS = true;

const RUN_TEST_CODE_INSTEAD_OF_APP = false;
//const RUN_TEST_CODE_INSTEAD_OF_APP = true;

//const DEBUG_SELECT = true;
const DEBUG_SELECT = false;

test_stuff() async {
  print("m13p7249 unrotated: ${DNASequencePredefined.dna_sequence_by_name('M13p7249', 0)}");
  print("m13p7249 rotated 5587: ${DNASequencePredefined.dna_sequence_by_name('M13p7249')}");
}

/// One instance of this class contains the global variables needed by all parts of the app.
class App {
  AppState get state => store.state;
  View view;

  Store store;

  // for optimization; too slow to store in Model since it's updated 60 times/sec
  Store store_selection_box;
  var context_selection_box = createContext();
  Store store_potential_crossover;
  var context_potential_crossover = createContext();
  Store store_dna_ends_move;
  var context_dna_ends_move = createContext();

  // for optimization; don't want to dispatch Actions changing model on every keypress
  // This is updated in view/design.dart; consider moving it higher-level.
  final Set<int> keys_pressed = {};

  // when user-interacting dialog is open, disable keyboard shortcuts
  bool keyboard_shortcuts_enabled = true;

  /// Undo/Redo stacks
  UndoRedo undo_redo = UndoRedo();

  start() async {
    if (RUN_TEST_CODE_INSTEAD_OF_APP) {
      await test_stuff();
    } else {
      warn_wrong_browser();
      react.setClientConfiguration();
      await initialize_model();
      setup_undo_redo_keyboard_listeners();
      setup_save_open_dna_file_keyboard_listeners();
//    util.save_editor_content_to_js_context(state.editor_content);
      restore_all_local_storage();
      this.setup_warning_before_unload();
      make_dart_functions_available_to_js(state);
      DivElement app_root_element = querySelector('#top-container');
      setup_file_drag_and_drop_listener(app_root_element);
      this.view = View(app_root_element);
      this.view.render(state);
    }
  }

  initialize_model() async {
    AppState state;
    String error_message = constants.NO_DNA_DESIGN_MESSAGE;

    state = (DEFAULT_AppStateBuilder
          ..error_message = error_message
          ..editor_content = '')
        .build();

    if (USE_REDUX_DEV_TOOLS) {
      var middleware_plus = all_middleware + [overReactReduxDevToolsMiddleware];
      store = DevToolsStore<AppState>(app_state_reducer, initialState: state, middleware: middleware_plus);
    } else {
      store = Store<AppState>(app_state_reducer, initialState: state, middleware: all_middleware);
    }

    store_selection_box = Store<SelectionBox>(optimized_selection_box_reducer,
        initialState: null, middleware: [throttle_middleware]);

    store_potential_crossover = Store<PotentialCrossover>(optimized_potential_crossover_reducer,
        initialState: null, middleware: [throttle_middleware]);

    store_dna_ends_move = Store<DNAEndsMove>(optimized_dna_ends_move_reducer,
        initialState: null, middleware: [throttle_middleware]);
  }

  Future<T> disable_keyboard_shortcuts_while<T>(Future<T> f()) async {
    keyboard_shortcuts_enabled = false;
    T return_value = await f();
    keyboard_shortcuts_enabled = true;
    return return_value;
  }

  dispatch(Action action) {
    // dispatch most to normal store, but fast-repeated actions only go to optimized stores
    if (!(action is FastAction)) {
      store.dispatch(action);
    }

    // optimization since these actions happen too fast to update whole model without jank
    var underlying_action = action is ThrottledActionFast ? action.action : action;
    if (underlying_action is actions.SelectionBoxCreate ||
        underlying_action is actions.SelectionBoxSizeChange ||
        underlying_action is actions.SelectionBoxRemove) {
      store_selection_box.dispatch(action);
    }
    if (underlying_action is actions.PotentialCrossoverCreate ||
        underlying_action is actions.PotentialCrossoverMove ||
        underlying_action is actions.PotentialCrossoverRemove) {
      store_potential_crossover.dispatch(action);
    }
    if (underlying_action is actions.DNAEndsMoveSetSelectedEnds ||
        underlying_action is actions.DNAEndsMoveAdjustOffset ||
        underlying_action is actions.DNAEndsMoveStop) {
      store_dna_ends_move.dispatch(action);
    }
  }

  setup_warning_before_unload() {
    window.onBeforeUnload.listen((Event event) {
      if (this.undo_redo.undo_stack.isNotEmpty) {
        BeforeUnloadEvent e = event;
        e.returnValue = 'You have unsaved work. Are you sure you want to leave?';
      }
    });
  }

  make_dart_functions_available_to_js(AppState state) {
    util.make_dart_function_available_to_js('dart_main_view_pointer_up', main_view_pointer_up);
  }
}

warn_wrong_browser() {
  if (!(browser.isChrome || browser.isFirefox)) {
    var msg = 'You appear to be using ${browser.name}. '
        'scadnano does not currently support this browser. '
        'Please use Chrome or Firefox instead.';
    window.alert(msg);
  }
  print('current browser: ${browser.name}');
}

/// Return null if browser is fine.
String error_message_wrong_browser() {
  String error_message = null;
  if (browser.isSafari) {
    error_message = 'You appear to be using the Safari browser. '
        'scadnano does not currently support Safari. '
        'Please use Chrome or Firefox instead.';
    print(error_message);
  }
  return error_message;
}

setup_undo_redo_keyboard_listeners() {
  // below doesn't work with onKeyPress
  // previous solution with onKeyPress used event.code == 'KeyZ' and worked inconsistently
  document.body.onKeyDown.listen((KeyboardEvent event) {
    int key = event.which;
//    print('*' * 100);
//    print('charCode: ${event.charCode}');
//    print(' keyCode: ${event.keyCode}');
//    print('    code: ${event.code}');
//    print('     key: ${event.key}');
//    print('   which: ${event.which}');
//    print("Control: ${event.getModifierState('control')}"); // modifiers.control);
//    print("KeyCode: ${event.key.codeUnitAt(0)}");

    // ctrl+Z to undo
    if ((event.ctrlKey || event.metaKey) && !event.shiftKey && key == KeyCode.Z && !event.altKey) {
      if (app.state.undo_redo.undo_stack.isNotEmpty) {
        app.dispatch(actions.Undo());
      }
    }
    // shift+ctrl+Z to redo
    if ((event.ctrlKey || event.metaKey) && event.shiftKey && key == KeyCode.Z && !event.altKey) {
      if (app.state.undo_redo.redo_stack.isNotEmpty) {
        app.dispatch(actions.Redo());
      }
    }
  });
}

setup_save_open_dna_file_keyboard_listeners() {
  document.body.onKeyDown.listen((KeyboardEvent event) {
    int key = event.which;
    // ctrl+S to save
    if ((event.ctrlKey || event.metaKey) && !event.shiftKey && key == KeyCode.S && !event.altKey) {
      event.preventDefault();
      app.dispatch(actions.SaveDNAFile());
    }
    // ctrl+O to load
    if ((event.ctrlKey || event.metaKey) && !event.shiftKey && key == KeyCode.O && !event.altKey) {
      event.preventDefault();
      // TODO(benlee12): maybe this is slightly hacky.
      document.getElementById('open-form-file').click();
    }
  });
}

setup_file_drag_and_drop_listener(Element drop_zone) {
  drop_zone.onDragOver.listen((event) {
    event.stopPropagation();
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
  });

  drop_zone.onDrop.listen((event) {
    event.stopPropagation();
    event.preventDefault();
    var files = event.dataTransfer.files;

    if (files.length > 1) {
      window.alert('More than one file dropped! Please drop only one .dna file.');
      return;
    }

    var file = files.first;
    var filename = file.name;
    var ext = p.extension(filename);
    if (ext == '.dna') {
      var confirm = app.state.has_error() || window.confirm('Are you sure you want to replace the current design?');

      if (confirm) {
        FileReader file_reader = new FileReader();
        //XXX: Technically to be clean Flux (or Elm architecture), this should be an Action,
        // and what is done in file_loaded should be another Action.
        file_reader.onLoad.listen((_) => scadnano_file_loaded(file_reader, filename));
        var err_msg = "error reading file: ${file_reader.error.toString()}";
        file_reader.onError.listen((_) => window.alert(err_msg));
        file_reader.readAsText(file);
      }
    } else {
      window.alert('scadnano does not support "${ext}" type files. Please drop a .dna file.');
    }
  });
}
