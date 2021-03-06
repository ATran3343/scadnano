import 'dart:convert';
import 'dart:html';
import 'package:http/http.dart' as http;

import 'package:path/path.dart' as path;
import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:scadnano/src/state/dialog.dart';
import 'package:scadnano/src/state/edit_mode.dart';
import 'package:scadnano/src/state/example_dna_designs.dart';
import 'package:scadnano/src/state/export_dna_format.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/select_mode.dart';
import 'package:scadnano/src/view/redraw_counter_component_mixin.dart';
import 'package:scadnano/src/view/react_bootstrap.dart';
import 'package:scadnano/src/constants.dart' as constants;
import 'package:smart_dialogs/smart_dialogs.dart';
import 'package:scadnano/src/view/menu_boolean.dart';
import 'package:scadnano/src/view/menu_dropdown_item.dart';
import 'package:scadnano/src/view/menu_form_file.dart';

import '../app.dart';
import '../actions/actions.dart' as actions;
import '../state/app_state.dart';
import '../state/app_ui_state.dart';
import '../util.dart' as util;

part 'menu.over_react.g.dart';

UiFactory<MenuProps> ConnectedMenu = connect<AppState, MenuProps>(
  mapStateToProps: (state) => (Menu()
    ..show_dna = state.ui_state.show_dna
    ..show_modifications = state.ui_state.show_modifications
    ..show_mismatches = state.ui_state.show_mismatches
    ..strand_paste_keep_color = state.ui_state.strand_paste_keep_color
    ..autofit = state.ui_state.autofit
    ..only_display_selected_helices = state.ui_state.only_display_selected_helices
    ..grid = state.dna_design?.grid
    ..example_dna_designs = state.ui_state.example_dna_designs
    ..design_has_insertions_or_deletions = state.dna_design?.has_insertions_or_deletions == true
    ..undo_stack_empty = state.undo_redo.undo_stack.isEmpty
    ..redo_stack_empty = state.undo_redo.redo_stack.isEmpty
    ..enable_copy = (app.state.ui_state.edit_modes.contains(EditModeChoice.select) &&
        app.state.ui_state.select_mode_state.modes.contains(SelectModeChoice.strand) &&
        app.state.ui_state.selectables_store.selected_items.isNotEmpty)
    ..modification_font_size = state.ui_state.modification_font_size
    ..modification_display_connector = state.ui_state.modification_display_connector),
  // Used for component test.
  forwardRef: true,
)(Menu);

UiFactory<MenuProps> Menu = _$Menu;

mixin MenuPropsMixin on UiProps {
  bool show_dna;
  bool show_modifications;
  int modification_font_size;
  bool modification_display_connector;
  bool show_mismatches;
  bool strand_paste_keep_color;
  bool autofit;
  bool only_display_selected_helices;
  Grid grid;
  ExampleDNADesigns example_dna_designs;
  bool design_has_insertions_or_deletions;
  bool undo_stack_empty;
  bool redo_stack_empty;
  bool enable_copy;
}

class MenuProps = UiProps with MenuPropsMixin, ConnectPropsMixin;

class MenuComponent extends UiComponent2<MenuProps> with RedrawCounterMixin {
  @override
  get consumedProps => propsMeta.forMixins({MenuPropsMixin});

  /*
  // this is needed in case the user selects the same filename, to reload the file in case it has changed.
  // If not, then the onChange event won't fire and we won't reload the file.
  var file_chooser = app.view.menu_view.file_chooser;
  file_chooser.onClick.listen((_) {
    file_chooser.value = null;
  });
  file_chooser.onChange.listen((_) {
    request_load_file_from_file_chooser(file_chooser);
  });
   */

  @override
  render() {
    return Navbar(
      {
        'bg': 'light',
        'expand': 'lg',
      },
      NavbarBrand({}, 'scadnano'),
      file_menu(),
      edit_menu(),
      view_menu(),
      grid_menu(),
      export_menu(),
      help_menu(),
      //XXX: I like to keep this button around to simulate random things that require user interaction
      // Button(
      //   {
      //     'variant': 'light',
      //     'onClick': (_) {
      //       window.alert('Dummy!');
      //     }
      //   },
      //   'Dummy',
      // ),
    );
  }

  file_menu() {
    return NavDropdown(
      {
        'title': 'File',
        'id': 'file-nav-dropdown',
      },
      (MenuDropdownItem()
        ..on_click = (_) {
          app.disable_keyboard_shortcuts_while(load_example_dialog);
        }
        ..display = '📄 Load example')(),
      (MenuFormFile()
        ..id = 'open-form-file'
        ..accept = ALLOWED_EXTENSIONS_DESIGN.map((ext) => '.' + ext).join(",")
        ..onChange = (e) {
          request_load_file_from_file_chooser(e.target, scadnano_file_loaded);
        }
        ..display = '📂 Open...'
        ..keyboard_shortcut = 'Ctrl+O'
      )(),
      DropdownDivider({}),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.SaveDNAFile());
        }
        ..display = '💾 Save...'
        ..keyboard_shortcut = 'Ctrl+S')(),
      DropdownDivider({}),
      (MenuFormFile()
        ..id = 'import-cadnano-form-file'
        ..accept = '.json'
        ..onChange = (e) {
          request_load_file_from_file_chooser(e.target, cadnano_file_loaded);
        }
        ..display = 'Import cadnano v2'
      )(),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.ExportCadnanoFile());
        }
        ..display = 'Export cadnano v2')(),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.ExportCodenanoFile());
        }
        ..display = 'Export codenano')(),
    );
  }

  edit_menu() {
    return NavDropdown(
      {
        'title': 'Edit',
        'id': 'edit-nav-dropdown',
      },
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.Undo());
        }
        ..display = 'Undo'
        ..keyboard_shortcut = 'Ctrl+Z'
        ..disabled = props.undo_stack_empty)(),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.Redo());
        }
        ..display = 'Redo'
        ..keyboard_shortcut = 'Ctrl+Shift+Z'
        ..disabled = props.redo_stack_empty)(),
      DropdownDivider({}),
      (MenuDropdownItem()
        ..on_click = (_) {
          if (props.enable_copy) {
            window.dispatchEvent(new KeyEvent('keydown', keyCode: KeyCode.C, ctrlKey: true).wrapped);
          }
        }
        ..display = 'Copy'
        ..keyboard_shortcut = 'Ctrl+C'
        ..disabled = !props.enable_copy)(),
      (MenuDropdownItem()
        ..on_click = (_) {
          window.dispatchEvent(new KeyEvent('keydown', keyCode: KeyCode.V, ctrlKey: true).wrapped);
        }
        ..display = 'Paste'
        ..keyboard_shortcut = 'Ctrl+V')(),
      DropdownDivider({}),
      (MenuBoolean()
        ..value = props.strand_paste_keep_color
        ..display = 'Pasted Strands Keep Original Color'
        ..tooltip = '''If checked, when copying and pasting a strand, the color is preserved.
If unchecked, then a new color is generated.'''
        ..name = 'strand-paste-keep-color'
        ..onChange = (_) {
          props.dispatch(actions.StrandPasteKeepColorSet(keep: !props.strand_paste_keep_color));
        })(),
      DropdownDivider({}),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.InlineInsertionsDeletions());
        }
        ..display = 'Inline Insertions/Deletions'
        ..disabled = !props.design_has_insertions_or_deletions
        ..tooltip = ''
            '''Click this to remove insertions and deletions from the design and replace them with domains
whose lengths correspond to the true strand length. Also moves major tick marks on helices.''')(),
      DropdownDivider({}),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.HelicesPositionsSetBasedOnCrossovers());
        }
        ..display = 'Set helix coordinates based on crossovers'
        ..disabled = props.grid != Grid.none
        ..tooltip = '''The grid must be set to none to enable this.

Select some crossovers and some helices. If no helices are selected, then all helices are processed. At 
most one crossover between pairs of adjacent (in view order) helices can be selected. If a pair of adjacent 
helices has no crossover selected, it is assumed to be the first crossover.  

New grid coordinates are calculated based on the crossovers to ensure that each pair of adjacent helices
has crossover angles that point the backbone angles directly at the adjoining helix.''')(),
    );
  }

  view_menu() {
    return NavDropdown(
      {
        'title': 'View',
        'id': 'view-nav-dropdown',
      },
      (MenuBoolean()
        ..value = props.show_dna
        ..display = 'Show DNA Sequences'
        ..tooltip = '''Check to show DNA sequences that have been assigned to strands.
In a large design, this can slow down the performance of panning and
zooming navigation, so uncheck it to speed up navigation.'''
        ..name = 'show-dna'
        ..onChange = (_) {
          props.dispatch(actions.ShowDNASet(!props.show_dna));
        })(),
      DropdownDivider({}),
      (MenuBoolean()
        ..value = props.show_modifications
        ..display = 'Show Modifications'
        ..tooltip = '''Check to show DNA modifications (e.g., biotins, fluorophores).'''
        ..name = 'show-modifications-span'
        ..onChange = (_) {
          props.dispatch(actions.ShowModificationsSet(!props.show_modifications));
        })(),
      (MenuBoolean()
        ..value = props.modification_display_connector
        ..display = 'Display Modification Connector'
        ..tooltip = '''Check to display DNA modification connectors.'''
        ..name = 'modifications-display-connector-span'
        ..onChange = (_) {
          props.dispatch(actions.SetModificationDisplayConnector(!props.modification_display_connector));
        })(),
      (Dom.span()
        ..title = '''Adjust modification font size.'''
        ..className = 'modifications-font-size-span menu-item'
        ..style = {'display': 'block'})(
        (Dom.label())(
          (Dom.input()
            ..style = {'marginRight': '1em', 'width': '4em'}
            ..type = 'number'
            ..min = '1'
            ..id = 'modifications-font-size-number-input'
            ..defaultValue = props.modification_font_size)(),
          (Dom.input()
            ..type = 'submit'
            ..onClick = (_) {
              InputElement inputElement = document.getElementById('modifications-font-size-number-input');
              int font = int.parse(inputElement.value);
              props.dispatch(actions.SetModificationFontSize(font));
            }
            ..value = 'Set Modification Font')(),
        ),
      ),
      DropdownDivider({}),
      (MenuBoolean()
        ..value = props.show_mismatches
        ..display = 'Show DNA Base Mismatches'
        ..tooltip = '''Check to show mismatches between DNA assigned to one strand
and the strand on the same helix with the opposite orientation.'''
        ..name = 'show-mismatches'
        ..onChange = (_) {
          props.dispatch(actions.ShowMismatchesSet(!props.show_mismatches));
        })(),
      (MenuBoolean()
        ..value = props.autofit
        ..display = 'Auto-fit On Loading New Design'
        ..tooltip = '''Check this so that, when loading a new design, the side and main views will be
translated to show the lowest-index helix in the upper-left. otherwise, after
loading the design, you may not be able to see it because it is translated off
the screen.

You may want to uncheck this when working on a design with the scripting library.
in that case, when repeatedly re-running the script to modify the design and then
re-loading it, it is preferable to keep the design centered at the same location
you had before, in order to be able to see the same part of the design you were
looking at before changing the script.'''
        ..name = 'center-on-load'
        ..onChange = (_) {
          props.dispatch(actions.AutofitSet(autofit: !props.autofit));
        })(),
      (MenuBoolean()
        ..value = props.only_display_selected_helices
        ..display = 'Display only selected helices'
        ..tooltip =
        '''Check this so that, only selected helices in the side view are displayed in the main view.'''
        ..name = 'display-only-selected-helices'
        ..onChange = (_) {
          props.dispatch(actions.SetOnlyDisplaySelectedHelices(!props.only_display_selected_helices));
        })(),
      //XXX: let's keep this commented out until we need it
      // (Dom.span()
      //   ..key = 'show-editor menu-item'
      //   ..className = 'show-editor-span')(
      //   (Dom.label()..key = 'show-editor-label')(
      //     (Dom.input()
      //       ..checked = show_editor
      //       ..onChange = (_) {
      //         app.state.main_view_ui_model.show_editor_store.set_show_editor(!show_editor);
      //       }
      //       ..type = 'checkbox')(),
      //     'show editor',
      //   ),
      // ),
    );
  }

  grid_menu() {
    return NavDropdown(
      {
        'title': 'Grid',
        'id': 'grid-nav-dropdown',
      },
      [
        for (var grid in grid_options)
          DropdownItem(
            {
              'active': grid == props.grid,
              'disabled': grid == props.grid,
              'key': grid.toString(),
              'onClick': (ev) {
                props.dispatch(actions.GridChange(grid: grid));
              },
            },
            grid.toString(),
          )
      ],
    );
  }

  export_menu() {
    return NavDropdown(
      {
        'title': 'Export',
        'id': 'export-nav-dropdown',
      },
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.ExportSvg(type: actions.ExportSvgType.side));
        }
        ..display = 'SVG Side View')(),
      (MenuDropdownItem()
        ..on_click = (_) {
          props.dispatch(actions.ExportSvg(type: actions.ExportSvgType.main));
        }
        ..display = 'SVG Main View')(),
      (MenuDropdownItem()
        ..on_click = (_) {
          app.disable_keyboard_shortcuts_while(export_dna);
        }
        ..display = 'DNA Sequences')(),
    );
  }

  help_menu() {
    return NavDropdown(
      {
        'title': 'Help',
        'id': 'help-nav-dropdown',
      },
      DropdownItem(
        {
          'href': 'https://github.com/UC-Davis-molecular-computing/scadnano/blob/master/README.md',
          'target': '_blank',
        },
        'Web Interface Help',
      ),
      DropdownItem(
        {
          'href':
              'https://github.com/UC-Davis-molecular-computing/scadnano/blob/master/tutorial/tutorial.md',
          'target': '_blank',
        },
        'Web Interface Tutorial',
      ),
      DropdownItem(
        {
          'href':
              'https://github.com/UC-Davis-molecular-computing/scadnano-python-package/blob/master/README.md',
          'target': '_blank',
        },
        'Python Scripting Help',
      ),
      DropdownItem(
        {
          'href':
              'https://github.com/UC-Davis-molecular-computing/scadnano-python-package/blob/master/tutorial/tutorial.md',
          'target': '_blank',
        },
        'Python Scripting Tutorial',
      ),
      DropdownItem(
        {
          'href': 'https://scadnano-python-package.readthedocs.io',
          'target': '_blank',
        },
        'Python Scripting API',
      ),
    );
  }

  final List<Grid> grid_options = [Grid.square, Grid.honeycomb, Grid.hex, Grid.none];

  Future<void> export_dna() async {
    // https://pub.dev/documentation/smart_dialogs/latest/smart_dialogs/Info/get.html
    String buttontype = DiaAttr.CHECKBOX;
    String htmlTitleText = 'export DNA sequences';
    List<String> textLabels = ['include scaffold?', 'output type'];
    List<List<String>> comboInfo = [null, ExportDNAFormat.values.map((v) => v.toString()).toList()];
    List<String> defaultInputTexts = [null, ExportDNAFormat.idt_bulk.toString()];
    List<int> widths = [0, 20];
    List<String> isChecked = ['false', null];
    bool alternateRowColor = false;
    List<String> buttonLabels = ['OK', 'Cancel'];

    UserInput result = await Info.get(buttontype, htmlTitleText, textLabels, comboInfo, defaultInputTexts,
        widths, isChecked, alternateRowColor, buttonLabels);

    if (result.buttonCode != 'DIA_ACT_OK') {
      return;
    }

    bool include_scaffold = result.getCheckedState(0) == 'true';
    String format_str = result.getUserInput(1)[0];
    ExportDNAFormat format = ExportDNAFormat.fromString(format_str);

    props.dispatch(actions.ExportDNA(include_scaffold: include_scaffold, export_dna_format: format));
  }

  Future<void> load_example_dialog() async {
    var dialog = Dialog(title: 'Load example DNA design', items: [
      DialogRadio(
        label: 'designs',
        options: props.example_dna_designs.filenames,
      ),
    ]);
    List<DialogItem> results = await util.dialog(dialog);
    if (results == null) return;

    int selected_idx = (results[0] as DialogRadio).selected_idx;
    props.dispatch(actions.ExampleDNADesignsLoad(selected_idx: selected_idx));
  }
}

request_load_file_from_file_chooser(
    FileUploadInputElement file_chooser, void Function(FileReader, String) onload_callback) {
  List<File> files = file_chooser.files;
  assert(files.isNotEmpty);
  File file = files[0];

//  var basefilename = path.basenameWithoutExtension(file.name);
  var basefilename = path.basename(file.name);

  FileReader file_reader = new FileReader();
  //XXX: Technically to be clean Flux (or Elm architecture), this should be an Action,
  // and what is done in file_loaded should be another Action.
  file_reader.onLoad.listen((_) => onload_callback(file_reader, basefilename));
  var err_msg = "error reading file: ${file_reader.error.toString()}";
  //file_reader.onError.listen((e) => error_message.text = err_msg);
  file_reader.onError.listen((_) => window.alert(err_msg));
  file_reader.readAsText(file);
}

scadnano_file_loaded(FileReader file_reader, String filename) {
  var json_model_text = file_reader.result;
  app.dispatch(actions.LoadDNAFile(content: json_model_text, filename: filename));
}

cadnano_file_loaded(FileReader file_reader, String filename) async {
  var json_cadnano_text = file_reader.result;
  var response = await http.post(
    constants.import_url,
    body: json_cadnano_text,
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode == 200) {
    var json_model_text = response.body;
    filename = path.setExtension(filename, '.dna');
    app.dispatch(actions.LoadDNAFile(content: json_model_text, filename: filename));
  } else {
    Map response_body_json = jsonDecode(response.body);
    window.alert('Error importing file: ${response_body_json['error']}');
  }
}
