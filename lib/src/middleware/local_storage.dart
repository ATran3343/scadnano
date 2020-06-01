import 'dart:convert';
import 'dart:html';

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:redux/redux.dart';
import 'package:scadnano/src/state/edit_mode.dart';

import '../json_serializable.dart';
import '../state/app_state.dart';
import '../state/select_mode.dart';
import '../app.dart';
import '../actions/actions.dart' as actions;

part 'local_storage.g.dart';

/// Aspects of state that can be stored in localStorage. (More like a StorableType; the thing stored is
/// somewhere in the Model, and this is an "ID" associated with it.
class Storable extends EnumClass {
  const Storable._(String name) : super(name);

  static const Storable dna_design = _$dna_design;
  static const Storable show_dna = _$show_dna;
  static const Storable show_modifications = _$show_modifications;
  static const Storable modification_display_connector = _$modification_display_connector;
  static const Storable modification_font_size = _$modification_font_size;
  static const Storable show_mismatches = _$show_mismatches;
  static const Storable autofit = _$autofit;
  static const Storable show_editor = _$show_editor;
  static const Storable edit_modes = _$edit_modes;
  static const Storable editor_mode = _$editor_mode;
  static const Storable select_modes = _$select_modes;
  static const Storable only_display_selected_helices = _$only_display_selected_helices;

  static BuiltSet<Storable> get values => _$values;

  static Storable valueOf(String name) => _$valueOf(name);
}

const String _LOCAL_STORAGE_PREFIX = "scadnano:";

const String _FILENAME_KEY = _LOCAL_STORAGE_PREFIX + 'loaded_filename';

save(AppState state, Storable storable) {
  String storable_key = _LOCAL_STORAGE_PREFIX + storable.name;
  String value_string;

  if (storable == Storable.dna_design) {
    var dna_design = state.dna_design;
    value_string = json_encode(dna_design);
    window.localStorage[_FILENAME_KEY] = state.ui_state.loaded_filename;
  } else if (storable == Storable.show_dna) {
    value_string = state.ui_state.show_dna.toString();
  } else if (storable == Storable.show_modifications) {
    value_string = state.ui_state.show_modifications.toString();
  } else if (storable == Storable.modification_display_connector) {
    value_string = state.ui_state.modification_display_connector.toString();
  } else if (storable == Storable.modification_font_size) {
    value_string = state.ui_state.modification_font_size.toString();
  } else if (storable == Storable.show_mismatches) {
    value_string = state.ui_state.show_mismatches.toString();
  } else if (storable == Storable.autofit) {
    value_string = state.ui_state.autofit.toString();
  } else if (storable == Storable.edit_modes) {
    List<String> edit_modes_list = [for (var mode in state.ui_state.edit_modes) mode.name];
    value_string = jsonEncode(edit_modes_list);
  } else if (storable == Storable.editor_mode) {
    value_string = state.ui_state.show_editor.toString();
  } else if (storable == Storable.select_modes) {
    value_string = state.ui_state.select_mode_state.to_json();
  } else if (storable == Storable.only_display_selected_helices) {
    value_string = state.ui_state.only_display_selected_helices.toString();
  }

  if (value_string != null)
    window.localStorage[storable_key] = value_string;
  else
    window.localStorage.remove(storable_key);
}

String side_pane_width() {
  String key = _LOCAL_STORAGE_PREFIX + 'side_pane_width';
  if (window.localStorage.containsKey(key)) {
    return window.localStorage[key];
  } else {
    return null;
  }
}

restore(Storable storable) {
  try {
    _restore(storable);
  } catch (e, stackTrace) {
    print(
        'ERROR: loading ${storable} from localStorage, encountered this error:\n${e.toString()}\n\nstack trace:\n\n${stackTrace}');
  }
}

_restore(Storable storable) {
  String storable_key = _LOCAL_STORAGE_PREFIX + storable.name;
  if (window.localStorage.containsKey(storable_key)) {
    var value = window.localStorage[storable_key];

    actions.Action action = null;

    if (storable == Storable.dna_design) {
      var filename;
      if (window.localStorage.containsKey(_FILENAME_KEY)) {
        filename = window.localStorage[_FILENAME_KEY];
      } else {
        filename = null;
      }
      action = actions.LoadDNAFile(content: value, filename: filename);
    } else if (storable == Storable.show_dna) {
      action = actions.ShowDNASet(value == 'true');
    } else if (storable == Storable.show_modifications) {
      action = actions.ShowModificationsSet(value == 'true');
    } else if (storable == Storable.modification_display_connector) {
      action = actions.SetModificationDisplayConnector(value == 'true');
    } else if (storable == Storable.modification_font_size) {
      action = actions.SetModificationFontSize(int.parse(value));
    } else if (storable == Storable.show_mismatches) {
      action = actions.ShowMismatchesSet(value == 'true');
    } else if (storable == Storable.autofit) {
      action = actions.AutofitSet(autofit: value == 'true');
    } else if (storable == Storable.show_editor) {
      action = actions.SetShowEditor(value == 'true');
    } else if (storable == Storable.editor_mode) {
//      EditModeChoice mode = EditModeChoice.from_json(value);
      //FIXME: implement this

    } else if (storable == Storable.edit_modes) {
      List<dynamic> mode_names = jsonDecode(value);
      List<EditModeChoice> modes = mode_names.map((name) => EditModeChoice.from_json(name)).toList();
      action = actions.EditModesSet(modes);
    } else if (storable == Storable.select_modes) {
      List<dynamic> mode_names = jsonDecode(value);
      List<SelectModeChoice> modes = mode_names.map((name) => SelectModeChoice.from_json(name)).toList();
      action = actions.SelectModesSet(modes);
    } else if (storable == Storable.only_display_selected_helices) {
      action = actions.SetOnlyDisplaySelectedHelices(value == 'true');
    }

    if (action != null) {
      app.dispatch(action);
    }
  }
}

restore_all_local_storage() {
  for (Storable storable in Storable.values) {
    restore(storable);
  }
}

save_async(AppState state, Iterable<Storable> storables) async {
  for (var storable in storables) {
    save(state, storable);
  }
}

local_storage_middleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  var state_before = store.state;
  next(action);
  if (action is actions.StorableAction) {
    var state_after = store.state;
    save_async(state_after, action.storables());
  }
}
