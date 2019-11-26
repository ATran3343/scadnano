@JS()
library actions2;

import 'dart:math';

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:js/js.dart';
import 'package:w_flux/w_flux.dart';
import 'package:built_collection/built_collection.dart';

import '../serializers.dart';
import '../model/dna_design.dart';
import '../model/substrand.dart';
import '../model/model.dart';
import '../model/dna_design_action_packs.dart';
import '../model/select_mode.dart';
import '../model/select_mode_state.dart';
import '../model/edit_mode.dart';
import '../model/helix.dart';
import '../model/grid_position.dart';
import '../model/mouseover_data.dart';
import '../model/strand.dart';
import '../model/bound_substrand.dart';
import '../model/loopout.dart';
import '../middleware/local_storage.dart';

part 'actions.g.dart';

//TODO: put name of loaded file in browser tab

/// [Action]s don't have to implement BuiltValue, but if they do, and they use the serialization mechanism,
/// this this toJson method will work automatically.
abstract class Action2 {
  dynamic toJson();
}

/// [Action] that can be undone via the undo stack. (typically changes to the [DNADesign])
//@BuiltValue(instantiable: false)
//abstract class UndoableAction implements Action2 {
//  @override
//  @nullable
//  bool get skip_undo;
//
//  UndoableAction rebuild(void Function(UndoableActionBuilder) updates);
//  UndoableActionBuilder toBuilder();
//}

abstract class UndoableAction extends Action2 {}

// Wrap an UndoableAction in a SkipUndo in order to apply it, but skip its effect on the undo/redo stacks.
abstract class SkipUndo with BuiltJsonSerializable implements Action2, Built<SkipUndo, SkipUndoBuilder> {
  UndoableAction get undoable_action;

  /************************ begin BuiltValue boilerplate ************************/
  factory SkipUndo(UndoableAction undoable_action) =>
      SkipUndo.from((b) => b..undoable_action = undoable_action);

  factory SkipUndo.from([void Function(SkipUndoBuilder) updates]) = _$SkipUndo;

  SkipUndo._();

  static Serializer<SkipUndo> get serializer => _$skipUndoSerializer;
}

/// [Action] that should trigger storing of certain [Storable]s to localStorage.
abstract class StorableAction extends Action2 {
  Iterable<Storable> storables();
}

/// [Action] intended for applying >= 2 other [UndoableAction]s at once,
/// which can be undone/redone in a single step by [UndoRedo].
abstract class BatchAction
    with BuiltJsonSerializable
    implements UndoableAction, Built<BatchAction, BatchActionBuilder> {
  BuiltList<UndoableAction> get actions;

  /************************ begin BuiltValue boilerplate ************************/
  factory BatchAction(Iterable<UndoableAction> actions) =>
      BatchAction.from((b) => b..actions.replace(BuiltList<UndoableAction>(actions)));

  factory BatchAction.from([void Function(BatchActionBuilder) updates]) = _$BatchAction;

  BatchAction._();

  static Serializer<BatchAction> get serializer => _$batchActionSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Select modes

abstract class ToggleSelectMode
    with BuiltJsonSerializable
    implements StorableAction, Built<ToggleSelectMode, ToggleSelectModeBuilder> {
  SelectModeChoice get select_mode_choice;

  Iterable<Storable> storables() => [Storable.select_modes];

  /************************ begin BuiltValue boilerplate ************************/
  factory ToggleSelectMode(SelectModeChoice select_mode_choice) =>
      ToggleSelectMode.from((b) => b..select_mode_choice = select_mode_choice);

  factory ToggleSelectMode.from([void Function(ToggleSelectModeBuilder) updates]) = _$ToggleSelectMode;

  ToggleSelectMode._();

  static Serializer<ToggleSelectMode> get serializer => _$toggleSelectModeSerializer;
}

abstract class SetSelectModes
    with BuiltJsonSerializable
    implements Action2, Built<SetSelectModes, SetSelectModesBuilder> {
  BuiltSet<SelectModeChoice> get select_mode_choices;

  /************************ begin BuiltValue boilerplate ************************/
  factory SetSelectModes(SetBuilder<SelectModeChoice> select_mode_choices) =>
      SetSelectModes.from((b) => b..select_mode_choices = select_mode_choices);

  factory SetSelectModes.from([void Function(SetSelectModesBuilder) updates]) = _$SetSelectModes;

  SetSelectModes._();

  static Serializer<SetSelectModes> get serializer => _$setSelectModesSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Show/hide DNA/mismatches/editor

abstract class SetShowDNA
    with BuiltJsonSerializable
    implements StorableAction, Built<SetShowDNA, SetShowDNABuilder> {
  bool get show;

  Iterable<Storable> storables() => [Storable.show_dna];

  factory SetShowDNA(bool show) => SetShowDNA.from((b) => b..show = show);

  /************************ begin BuiltValue boilerplate ************************/
  factory SetShowDNA.from([void Function(SetShowDNABuilder) updates]) = _$SetShowDNA;

  SetShowDNA._();

  static Serializer<SetShowDNA> get serializer => _$setShowDNASerializer;
}

abstract class SetShowMismatches
    with BuiltJsonSerializable
    implements StorableAction, Built<SetShowMismatches, SetShowMismatchesBuilder> {
  bool get show;

  Iterable<Storable> storables() => [Storable.show_mismatches];

  factory SetShowMismatches(bool show) => SetShowMismatches.from((b) => b..show = show);

  /************************ begin BuiltValue boilerplate ************************/
  factory SetShowMismatches.from([void Function(SetShowMismatchesBuilder) updates]) = _$SetShowMismatches;

  SetShowMismatches._();

  static Serializer<SetShowMismatches> get serializer => _$setShowMismatchesSerializer;
}

abstract class SetShowEditor
    with BuiltJsonSerializable
    implements StorableAction, Built<SetShowEditor, SetShowEditorBuilder> {
  bool get show;

  Iterable<Storable> storables() => [Storable.show_editor];

  factory SetShowEditor(bool show) => SetShowEditor.from((b) => b..show = show);

  /************************ begin BuiltValue boilerplate ************************/
  factory SetShowEditor.from([void Function(SetShowEditorBuilder) updates]) = _$SetShowEditor;

  SetShowEditor._();

  static Serializer<SetShowEditor> get serializer => _$setShowEditorSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Save/load files

abstract class SaveDNAFile
    with BuiltJsonSerializable
    implements Action2, Built<SaveDNAFile, SaveDNAFileBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SaveDNAFile([void Function(SaveDNAFileBuilder) updates]) = _$SaveDNAFile;

  SaveDNAFile._();

  static Serializer<SaveDNAFile> get serializer => _$saveDNAFileSerializer;
}

abstract class LoadDNAFile
    with BuiltJsonSerializable
    implements Action2, Built<LoadDNAFile, LoadDNAFileBuilder> {
  String get content;

  String get filename;

  /************************ begin BuiltValue boilerplate ************************/
  factory LoadDNAFile(String content, String filename) => LoadDNAFile.from((b) => b
    ..content = content
    ..filename = filename);

  factory LoadDNAFile.from([void Function(LoadDNAFileBuilder) updates]) = _$LoadDNAFile;

  LoadDNAFile._();

  static Serializer<LoadDNAFile> get serializer => _$loadDNAFileSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Mouseover data (main view)

abstract class MouseoverDataClear
    with BuiltJsonSerializable
    implements Action2, Built<MouseoverDataClear, MouseoverDataClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory MouseoverDataClear([void Function(MouseoverDataClearBuilder) updates]) = _$MouseoverDataClear;

  MouseoverDataClear._();

  static Serializer<MouseoverDataClear> get serializer => _$mouseoverDataClearSerializer;
}

abstract class MouseoverDataUpdate
    with BuiltJsonSerializable
    implements Action2, Built<MouseoverDataUpdate, MouseoverDataUpdateBuilder> {
  BuiltList<MouseoverData> get mouseover_datas;

  factory MouseoverDataUpdate(DNADesign dna_design, Iterable<MouseoverParams> params) {
    ListBuilder<MouseoverData> mouseover_datas_builder = MouseoverData.from_params(dna_design, params);
    return MouseoverDataUpdate.from((b) => b..mouseover_datas = mouseover_datas_builder);
  }

  /************************ begin BuiltValue boilerplate ************************/
  factory MouseoverDataUpdate.from([void Function(MouseoverDataUpdateBuilder) updates]) =
      _$MouseoverDataUpdate;

  MouseoverDataUpdate._();

  static Serializer<MouseoverDataUpdate> get serializer => _$mouseoverDataUpdateSerializer;
}

abstract class HelixRotationSet
    with BuiltJsonSerializable
    implements UndoableAction, Built<HelixRotationSet, HelixRotationSetBuilder> {
  int get helix_idx;

  double get rotation;

  int get anchor;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixRotationSet(int helix_idx, double rotation, int anchor) => HelixRotationSet.from((b) => b
    ..helix_idx = helix_idx
    ..rotation = rotation
    ..anchor = anchor);

  factory HelixRotationSet.from([void Function(HelixRotationSetBuilder) updates]) = _$HelixRotationSet;

  HelixRotationSet._();

  static Serializer<HelixRotationSet> get serializer => _$helixRotationSetSerializer;
}

// set helix rotation at anchor to point at helix_other
abstract class HelixRotationSetAtOther
    with BuiltJsonSerializable
    implements UndoableAction, Built<HelixRotationSetAtOther, HelixRotationSetAtOtherBuilder> {
  int get helix_idx;

  int get helix_other_idx;

  bool get forward;

  int get anchor;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixRotationSetAtOther(int helix_idx, int helix_other_idx, bool forward, int anchor) =>
      HelixRotationSetAtOther.from((b) => b
        ..helix_idx = helix_idx
        ..helix_other_idx = helix_other_idx
        ..forward = forward
        ..anchor = anchor);

  factory HelixRotationSetAtOther.from([void Function(HelixRotationSetAtOtherBuilder) updates]) =
      _$HelixRotationSetAtOther;

  HelixRotationSetAtOther._();

  static Serializer<HelixRotationSetAtOther> get serializer => _$helixRotationSetAtOtherSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Error message

abstract class ErrorMessageSet
    with BuiltJsonSerializable
    implements Action2, Built<ErrorMessageSet, ErrorMessageSetBuilder> {
  String get error_message;

  /************************ begin BuiltValue boilerplate ************************/
  factory ErrorMessageSet(String error_message) =>
      ErrorMessageSet.from((b) => b..error_message = error_message);

  factory ErrorMessageSet.from([void Function(ErrorMessageSetBuilder) updates]) = _$ErrorMessageSet;

  ErrorMessageSet._();

  static Serializer<ErrorMessageSet> get serializer => _$errorMessageSetSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Selection box (side view)

abstract class SideViewSelectionBoxCreateToggling
    with BuiltJsonSerializable
    implements Action2, Built<SideViewSelectionBoxCreateToggling, SideViewSelectionBoxCreateTogglingBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewSelectionBoxCreateToggling(Point<num> point) =>
      SideViewSelectionBoxCreateToggling.from((b) => b..point = point);

  factory SideViewSelectionBoxCreateToggling.from(
          [void Function(SideViewSelectionBoxCreateTogglingBuilder) updates]) =
      _$SideViewSelectionBoxCreateToggling;

  SideViewSelectionBoxCreateToggling._();

  static Serializer<SideViewSelectionBoxCreateToggling> get serializer =>
      _$sideViewSelectionBoxCreateTogglingSerializer;
}

abstract class SideViewSelectionBoxCreateSelecting
    with BuiltJsonSerializable
    implements
        Action2,
        Built<SideViewSelectionBoxCreateSelecting, SideViewSelectionBoxCreateSelectingBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewSelectionBoxCreateSelecting(Point<num> point) =>
      SideViewSelectionBoxCreateSelecting.from((b) => b..point = point);

  factory SideViewSelectionBoxCreateSelecting.from(
          [void Function(SideViewSelectionBoxCreateSelectingBuilder) updates]) =
      _$SideViewSelectionBoxCreateSelecting;

  SideViewSelectionBoxCreateSelecting._();

  static Serializer<SideViewSelectionBoxCreateSelecting> get serializer =>
      _$sideViewSelectionBoxCreateSelectingSerializer;
}

abstract class SideViewSelectionBoxSizeChanged
    with BuiltJsonSerializable
    implements Action2, Built<SideViewSelectionBoxSizeChanged, SideViewSelectionBoxSizeChangedBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewSelectionBoxSizeChanged(Point<num> point) =>
      SideViewSelectionBoxSizeChanged.from((b) => b..point = point);

  factory SideViewSelectionBoxSizeChanged.from(
      [void Function(SideViewSelectionBoxSizeChangedBuilder) updates]) = _$SideViewSelectionBoxSizeChanged;

  SideViewSelectionBoxSizeChanged._();

  static Serializer<SideViewSelectionBoxSizeChanged> get serializer =>
      _$sideViewSelectionBoxSizeChangedSerializer;
}

abstract class SideViewSelectionBoxRemove
    with BuiltJsonSerializable
    implements Action2, Built<SideViewSelectionBoxRemove, SideViewSelectionBoxRemoveBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewSelectionBoxRemove() => SideViewSelectionBoxRemove.from((b) => b);

  factory SideViewSelectionBoxRemove.from([void Function(SideViewSelectionBoxRemoveBuilder) updates]) =
      _$SideViewSelectionBoxRemove;

  SideViewSelectionBoxRemove._();

  static Serializer<SideViewSelectionBoxRemove> get serializer => _$sideViewSelectionBoxRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Selection box (main view)

abstract class MainViewSelectionBoxCreateToggling
    with BuiltJsonSerializable
    implements Action2, Built<MainViewSelectionBoxCreateToggling, MainViewSelectionBoxCreateTogglingBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory MainViewSelectionBoxCreateToggling(Point<num> point) =>
      MainViewSelectionBoxCreateToggling.from((b) => b..point = point);

  factory MainViewSelectionBoxCreateToggling.from(
          [void Function(MainViewSelectionBoxCreateTogglingBuilder) updates]) =
      _$MainViewSelectionBoxCreateToggling;

  MainViewSelectionBoxCreateToggling._();

  static Serializer<MainViewSelectionBoxCreateToggling> get serializer =>
      _$mainViewSelectionBoxCreateTogglingSerializer;
}

abstract class MainViewSelectionBoxCreateSelecting
    with BuiltJsonSerializable
    implements
        Action2,
        Built<MainViewSelectionBoxCreateSelecting, MainViewSelectionBoxCreateSelectingBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory MainViewSelectionBoxCreateSelecting(Point<num> point) =>
      MainViewSelectionBoxCreateSelecting.from((b) => b..point = point);

  factory MainViewSelectionBoxCreateSelecting.from(
          [void Function(MainViewSelectionBoxCreateSelectingBuilder) updates]) =
      _$MainViewSelectionBoxCreateSelecting;

  MainViewSelectionBoxCreateSelecting._();

  static Serializer<MainViewSelectionBoxCreateSelecting> get serializer =>
      _$mainViewSelectionBoxCreateSelectingSerializer;
}

abstract class MainViewSelectionBoxSizeChanged
    with BuiltJsonSerializable
    implements Action2, Built<MainViewSelectionBoxSizeChanged, MainViewSelectionBoxSizeChangedBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory MainViewSelectionBoxSizeChanged(Point<num> point) =>
      MainViewSelectionBoxSizeChanged.from((b) => b..point = point);

  factory MainViewSelectionBoxSizeChanged.from(
      [void Function(MainViewSelectionBoxSizeChangedBuilder) updates]) = _$MainViewSelectionBoxSizeChanged;

  MainViewSelectionBoxSizeChanged._();

  static Serializer<MainViewSelectionBoxSizeChanged> get serializer =>
      _$mainViewSelectionBoxSizeChangedSerializer;
}

abstract class MainViewSelectionBoxRemove
    with BuiltJsonSerializable
    implements Action2, Built<MainViewSelectionBoxRemove, MainViewSelectionBoxRemoveBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory MainViewSelectionBoxRemove() => MainViewSelectionBoxRemove.from((b) => b);

  factory MainViewSelectionBoxRemove.from([void Function(MainViewSelectionBoxRemoveBuilder) updates]) =
      _$MainViewSelectionBoxRemove;

  MainViewSelectionBoxRemove._();

  static Serializer<MainViewSelectionBoxRemove> get serializer => _$mainViewSelectionBoxRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Mouse position (side view)

abstract class SideViewMousePositionUpdate
    with BuiltJsonSerializable
    implements Action2, Built<SideViewMousePositionUpdate, SideViewMousePositionUpdateBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewMousePositionUpdate(Point<num> point) =>
      SideViewMousePositionUpdate.from((b) => b..point = point);

  factory SideViewMousePositionUpdate.from([void Function(SideViewMousePositionUpdateBuilder) updates]) =
      _$SideViewMousePositionUpdate;

  SideViewMousePositionUpdate._();

  static Serializer<SideViewMousePositionUpdate> get serializer => _$sideViewMousePositionUpdateSerializer;
}

abstract class SideViewMousePositionRemove
    with BuiltJsonSerializable
    implements Action2, Built<SideViewMousePositionRemove, SideViewMousePositionRemoveBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SideViewMousePositionRemove() => SideViewMousePositionRemove.from((b) => b);

  factory SideViewMousePositionRemove.from([void Function(SideViewMousePositionRemoveBuilder) updates]) =
      _$SideViewMousePositionRemove;

  SideViewMousePositionRemove._();

  static Serializer<SideViewMousePositionRemove> get serializer => _$sideViewMousePositionRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helix select (side view)

abstract class HelixSelect
    with BuiltJsonSerializable
    implements Action2, Built<HelixSelect, HelixSelectBuilder> {
  int get helix_idx;

  bool get toggle;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixSelect(int helix_idx, bool toggle) => HelixSelect.from((b) => b
    ..helix_idx = helix_idx
    ..toggle = toggle);

  factory HelixSelect.from([void Function(HelixSelectBuilder) updates]) = _$HelixSelect;

  HelixSelect._();

  static Serializer<HelixSelect> get serializer => _$helixSelectSerializer;
}

abstract class HelicesSelectedClear
    with BuiltJsonSerializable
    implements Action2, Built<HelicesSelectedClear, HelicesSelectedClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory HelicesSelectedClear() => HelicesSelectedClear.from((b) => b);

  factory HelicesSelectedClear.from([void Function(HelicesSelectedClearBuilder) updates]) =
      _$HelicesSelectedClear;

  HelicesSelectedClear._();

  static Serializer<HelicesSelectedClear> get serializer => _$helicesSelectedClearSerializer;
}

abstract class HelixSelectionsAdjust
    with BuiltJsonSerializable
    implements Action2, Built<HelixSelectionsAdjust, HelixSelectionsAdjustBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory HelixSelectionsAdjust() => HelixSelectionsAdjust.from((b) => b);

  factory HelixSelectionsAdjust.from([void Function(HelixSelectionsAdjustBuilder) updates]) =
      _$HelixSelectionsAdjust;

  HelixSelectionsAdjust._();

  static Serializer<HelixSelectionsAdjust> get serializer => _$helixSelectionsAdjustSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Mouse position (side view)

abstract class SetShowMouseoverRect
    with BuiltJsonSerializable
    implements Action2, Built<SetShowMouseoverRect, SetShowMouseoverRectBuilder> {
  bool get show;

  /************************ begin BuiltValue boilerplate ************************/
  factory SetShowMouseoverRect(bool show) => SetShowMouseoverRect.from((b) => b..show = show);

  factory SetShowMouseoverRect.from([void Function(SetShowMouseoverRectBuilder) updates]) =
      _$SetShowMouseoverRect;

  SetShowMouseoverRect._();

  static Serializer<SetShowMouseoverRect> get serializer => _$setShowMouseoverRectSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Export SVG

abstract class ExportSvgMain
    with BuiltJsonSerializable
    implements Action2, Built<ExportSvgMain, ExportSvgMainBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ExportSvgMain() => ExportSvgMain.from((b) => b);

  factory ExportSvgMain.from([void Function(ExportSvgMainBuilder) updates]) = _$ExportSvgMain;

  ExportSvgMain._();

  static Serializer<ExportSvgMain> get serializer => _$exportSvgMainSerializer;
}

abstract class ExportSvgSide
    with BuiltJsonSerializable
    implements Action2, Built<ExportSvgSide, ExportSvgSideBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ExportSvgSide() => ExportSvgSide.from((b) => b);

  factory ExportSvgSide.from([void Function(ExportSvgSideBuilder) updates]) = _$ExportSvgSide;

  ExportSvgSide._();

  static Serializer<ExportSvgSide> get serializer => _$exportSvgSideSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Undo/Redo

abstract class Undo with BuiltJsonSerializable implements Action2, Built<Undo, UndoBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory Undo() => Undo.from((b) => b);

  factory Undo.from([void Function(UndoBuilder) updates]) = _$Undo;

  Undo._();

  static Serializer<Undo> get serializer => _$undoSerializer;
}

abstract class Redo with BuiltJsonSerializable implements Action2, Built<Redo, RedoBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory Redo() => Redo.from((b) => b);

  factory Redo.from([void Function(RedoBuilder) updates]) = _$Redo;

  Redo._();

  static Serializer<Redo> get serializer => _$redoSerializer;
}

abstract class UndoRedoClear
    with BuiltJsonSerializable
    implements Action2, Built<UndoRedoClear, UndoRedoClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory UndoRedoClear() => UndoRedoClear.from((b) => b);

  factory UndoRedoClear.from([void Function(UndoRedoClearBuilder) updates]) = _$UndoRedoClear;

  UndoRedoClear._();

  static Serializer<UndoRedoClear> get serializer => _$undoRedoClearSerializer;
}

//class Actions {
//  // Save .dna file
//  *save_dna_file = Action<Null>();
//
//  // Load .dna file
//  *load_dna_file = Action<LoadDNAFileParameters>();
//
//  // Mouseover data (main view)
//  *update_mouseover_data = Action<MouseoverParameters>();
//  *remove_mouseover_data = Action<Null>();
//
//  // Side view position
//  *update_side_view_mouse_position = Action<Point<num>>();
//  *remove_side_view_mouse_position = Action<Null>();
//
//  // Helix
//  helix_use = Action<HelixUseActionParameters>();
//  set_helices = Action<List<Helix>>();
//  *set_helix_rotation = Action<SetHelixRotationActionParameters>();
//
//  // Strand
//  strand_remove = Action<Strand>();
//  strand_add = Action<Strand>();
//  strands_remove = Action<Iterable<Strand>>();
//  strands_add = Action<Iterable<Strand>>();
//
//  // Strand UI model
//  strand_select_toggle = Action<Strand>();
//  five_prime_select_toggle = Action<BoundSubstrand>();
//  three_prime_select_toggle = Action<BoundSubstrand>();
//  loopout_select_toggle = Action<Loopout>();
//  crossover_select_toggle = Action<Tuple2<BoundSubstrand, BoundSubstrand>>();
//
//  unselect_all = Action<Null>();
//  select = Action<Selectable>();
//  select_all = Action<List<Selectable>>();
//  unselect = Action<Selectable>();
//  toggle = Action<Selectable>();
//  toggle_all = Action<List<Selectable>>();
//
//  delete_all = Action<DeleteAllParameters>();
//
//  // Selection box
//  *create_selection_box_toggling = Action<Point<num>>();
//  *create_selection_box_selecting = Action<Point<num>>();
//  *selection_box_size_changed = Action<Point<num>>();
//  *remove_selection_box = Action<Null>();
//
//  // Errors (so there's no DNADesign to display, e.g., parsing error reading JSON file)
//  *set_error_message = Action<String>();
//
//  // Edit mode
//  set_edit_mode = Action<EditModeChoice>();
//
//  // Menu
//  *set_show_dna = Action<bool>();
//  *set_show_mismatches = Action<bool>();
//  *set_show_editor = Action<bool>();
//
//  // Select modes
//  *toggle_select_mode = Action<SelectModeChoice>();
//  *set_select_modes = Action<List<SelectModeChoice>>();
//
//  // all reversible dispatcher go through this Action
//  reversible_action = Action<ReversibleActionPack>();
//
//}
