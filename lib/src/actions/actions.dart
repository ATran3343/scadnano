@JS()
library actions2;

import 'dart:math';

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:color/color.dart';
import 'package:js/js.dart';
import 'package:scadnano/src/state/bound_substrand.dart';
import 'package:scadnano/src/state/context_menu.dart';
import 'package:scadnano/src/state/crossover.dart';
import 'package:scadnano/src/state/dialog.dart';
import 'package:scadnano/src/state/dna_end.dart';
import 'package:scadnano/src/state/dna_ends_move.dart';
import 'package:scadnano/src/state/export_dna_format.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/helix.dart';
import 'package:scadnano/src/state/loopout.dart';
import 'package:scadnano/src/state/position3d.dart';
import 'package:scadnano/src/state/potential_crossover.dart';
import 'package:scadnano/src/state/selectable.dart';
import 'package:scadnano/src/state/selection_box.dart';
import 'package:built_collection/built_collection.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/strand_part.dart';
import 'package:scadnano/src/state/strands_move.dart';

//import '../state/substrand.dart';
//import '../state/app_state.dart';
//import '../state/select_mode_state.dart';
//import '../state/helix.dart';
//import '../state/strand.dart';
//import '../state/bound_substrand.dart';
//import '../state/loopout.dart';
import '../state/edit_mode.dart';
import '../serializers.dart';
import '../state/select_mode.dart';
import '../state/grid_position.dart';
import '../state/mouseover_data.dart';
import '../middleware/local_storage.dart';

part 'actions.g.dart';

/// [Action]s don't have to implement BuiltValue, but if they do, and they use the serialization mechanism,
/// this this toJson method will work automatically.
abstract class Action {
  dynamic toJson();
}

// Actions that affect the DNADesign (i.e., not purely UIAppState-affecting actions such as selecting items).
// Only Undo and Redo implement this directly; all others implement the subtype UndoableAction.
abstract class DNADesignChangingAction implements StorableAction {
  Iterable<Storable> storables() => [Storable.dna_design];
}

/// Undoable actions, which must affect the DNADesign, and can be undone by Ctrl+Z.
abstract class UndoableAction implements DNADesignChangingAction {
  Iterable<Storable> storables() => [Storable.dna_design];
}

/// Fast actions happen rapidly and are not dispatched to normal store for optimization
abstract class FastAction extends Action {}

// Wrap an UndoableAction in a SkipUndo in order to apply it, but skip its effect on the undo/redo stacks.
abstract class SkipUndo with BuiltJsonSerializable implements Action, Built<SkipUndo, SkipUndoBuilder> {
  UndoableAction get undoable_action;

  /************************ begin BuiltValue boilerplate ************************/
  factory SkipUndo(UndoableAction undoable_action) =>
      SkipUndo.from((b) => b..undoable_action = undoable_action);

  factory SkipUndo.from([void Function(SkipUndoBuilder) updates]) = _$SkipUndo;

  SkipUndo._();

  static Serializer<SkipUndo> get serializer => _$skipUndoSerializer;
}

/// [Action] that should trigger storing of certain [Storable]s to localStorage.
abstract class StorableAction extends Action {
  Iterable<Storable> storables();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Undo/Redo

abstract class Undo with BuiltJsonSerializable, DNADesignChangingAction implements Built<Undo, UndoBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory Undo() => Undo.from((b) => b);

  factory Undo.from([void Function(UndoBuilder) updates]) = _$Undo;

  Undo._();

  static Serializer<Undo> get serializer => _$undoSerializer;
}

abstract class Redo with BuiltJsonSerializable, DNADesignChangingAction implements Built<Redo, RedoBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory Redo() => Redo.from((b) => b);

  factory Redo.from([void Function(RedoBuilder) updates]) = _$Redo;

  Redo._();

  static Serializer<Redo> get serializer => _$redoSerializer;
}

abstract class UndoRedoClear
    with BuiltJsonSerializable
    implements Action, Built<UndoRedoClear, UndoRedoClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory UndoRedoClear() => UndoRedoClear.from((b) => b);

  factory UndoRedoClear.from([void Function(UndoRedoClearBuilder) updates]) = _$UndoRedoClear;

  UndoRedoClear._();

  static Serializer<UndoRedoClear> get serializer => _$undoRedoClearSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Batch action

/// [Action] intended for applying >= 2 other [UndoableAction]s at once,
/// which can be undone/redone in a single step by [UndoRedo].
abstract class BatchAction
    with BuiltJsonSerializable, UndoableAction
    implements Built<BatchAction, BatchActionBuilder> {
  BuiltList<UndoableAction> get actions;

  /************************ begin BuiltValue boilerplate ************************/
  factory BatchAction(Iterable<UndoableAction> actions) =>
      BatchAction.from((b) => b..actions.replace(BuiltList<UndoableAction>(actions)));

  factory BatchAction.from([void Function(BatchActionBuilder) updates]) = _$BatchAction;

  BatchAction._();

  static Serializer<BatchAction> get serializer => _$batchActionSerializer;

  @override
  dynamic toJson() => {'actions': actions.toList()};
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Throttle

//XXX: Originally all ThrottledActions were FastActions because anything that would need to be throttled
// (>= 60 fps) was too fast to be handled by the normal React/Redux store updates. Now that we have trimmed
// the rendering time significantly (https://github.com/UC-Davis-molecular-computing/scadnano/issues/87),
// this is no longer the case. But FastAction is still used to avoid
// dispatching actions to the main store. So we need ThrottledActionNonFast to throttle actions that we still
// would like to be dispatched to the main store.
abstract class ThrottledAction implements Action {
  Action get action;

  num get interval_sec;
}

abstract class ThrottledActionFast
    with BuiltJsonSerializable
    implements ThrottledAction, FastAction, Built<ThrottledActionFast, ThrottledActionFastBuilder> {
  Action get action;

  num get interval_sec;

  /************************ begin BuiltValue boilerplate ************************/
  factory ThrottledActionFast(Action action, num interval_sec) => ThrottledActionFast.from((b) => b
    ..action = action
    ..interval_sec = interval_sec);

  factory ThrottledActionFast.from([void Function(ThrottledActionFastBuilder) updates]) =
      _$ThrottledActionFast;

  ThrottledActionFast._();

  static Serializer<ThrottledActionFast> get serializer => _$throttledActionFastSerializer;
}

abstract class ThrottledActionNonFast
    with BuiltJsonSerializable
    implements ThrottledAction, Built<ThrottledActionNonFast, ThrottledActionNonFastBuilder> {
  Action get action;

  num get interval_sec;

  /************************ begin BuiltValue boilerplate ************************/
  factory ThrottledActionNonFast(Action action, num interval_sec) => ThrottledActionNonFast.from((b) => b
    ..action = action
    ..interval_sec = interval_sec);

  factory ThrottledActionNonFast.from([void Function(ThrottledActionNonFastBuilder) updates]) =
      _$ThrottledActionNonFast;

  ThrottledActionNonFast._();

  static Serializer<ThrottledActionNonFast> get serializer => _$throttledActionNonFastSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Edit modes

abstract class EditModeToggle
    with BuiltJsonSerializable
    implements StorableAction, Built<EditModeToggle, EditModeToggleBuilder> {
  EditModeChoice get mode;

  Iterable<Storable> storables() => [Storable.edit_modes];

  /************************ begin BuiltValue boilerplate ************************/
  factory EditModeToggle(EditModeChoice mode) => EditModeToggle.from((b) => b..mode = mode);

  factory EditModeToggle.from([void Function(EditModeToggleBuilder) updates]) = _$EditModeToggle;

  EditModeToggle._();

  static Serializer<EditModeToggle> get serializer => _$editModeToggleSerializer;
}

abstract class EditModesSet
    with BuiltJsonSerializable
    implements Action, Built<EditModesSet, EditModesSetBuilder> {
  BuiltSet<EditModeChoice> get edit_modes;

  /************************ begin BuiltValue boilerplate ************************/
  factory EditModesSet(Iterable<EditModeChoice> edit_modes) =>
      EditModesSet.from((b) => b..edit_modes.replace(edit_modes));

  factory EditModesSet.from([void Function(EditModesSetBuilder) updates]) = _$EditModesSet;

  EditModesSet._();

  static Serializer<EditModesSet> get serializer => _$editModesSetSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Select modes

abstract class SelectModeToggle
    with BuiltJsonSerializable
    implements StorableAction, Built<SelectModeToggle, SelectModeToggleBuilder> {
  SelectModeChoice get select_mode_choice;

  Iterable<Storable> storables() => [Storable.select_modes];

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectModeToggle(SelectModeChoice select_mode_choice) =>
      SelectModeToggle.from((b) => b..select_mode_choice = select_mode_choice);

  factory SelectModeToggle.from([void Function(SelectModeToggleBuilder) updates]) = _$SelectModeToggle;

  SelectModeToggle._();

  static Serializer<SelectModeToggle> get serializer => _$selectModeToggleSerializer;
}

abstract class SelectModesSet
    with BuiltJsonSerializable
    implements Action, Built<SelectModesSet, SelectModesSetBuilder> {
  BuiltSet<SelectModeChoice> get select_mode_choices;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectModesSet(Iterable<SelectModeChoice> select_mode_choices) =>
      SelectModesSet.from((b) => b..select_mode_choices.replace(select_mode_choices));

  factory SelectModesSet.from([void Function(SelectModesSetBuilder) updates]) = _$SelectModesSet;

  SelectModesSet._();

  static Serializer<SelectModesSet> get serializer => _$selectModesSetSerializer;
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
    implements Action, Built<SaveDNAFile, SaveDNAFileBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SaveDNAFile([void Function(SaveDNAFileBuilder) updates]) = _$SaveDNAFile;

  SaveDNAFile._();

  static Serializer<SaveDNAFile> get serializer => _$saveDNAFileSerializer;
}

abstract class LoadDNAFile
    with BuiltJsonSerializable, DNADesignChangingAction
    implements Built<LoadDNAFile, LoadDNAFileBuilder> {
  String get content;

  // set to null when getting file from another source such as localStorage
  @nullable
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
    implements Action, Built<MouseoverDataClear, MouseoverDataClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory MouseoverDataClear([void Function(MouseoverDataClearBuilder) updates]) = _$MouseoverDataClear;

  MouseoverDataClear._();

  static Serializer<MouseoverDataClear> get serializer => _$mouseoverDataClearSerializer;
}

abstract class MouseoverDataUpdate
    with BuiltJsonSerializable
    implements Action, Built<MouseoverDataUpdate, MouseoverDataUpdateBuilder> {
  BuiltList<MouseoverParams> get mouseover_params;

  factory MouseoverDataUpdate({BuiltList<MouseoverParams> mouseover_params}) = _$MouseoverDataUpdate._;

//  => MouseoverDataUpdate.from((b) => b..mouseover_params.replace(params));

  /************************ begin BuiltValue boilerplate ************************/
  factory MouseoverDataUpdate.from([void Function(MouseoverDataUpdateBuilder) updates]) =
      _$MouseoverDataUpdate;

  MouseoverDataUpdate._();

  static Serializer<MouseoverDataUpdate> get serializer => _$mouseoverDataUpdateSerializer;
}

abstract class HelixRotationSet
    with BuiltJsonSerializable, UndoableAction
    implements Built<HelixRotationSet, HelixRotationSetBuilder> {
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
    with BuiltJsonSerializable, UndoableAction
    implements Built<HelixRotationSetAtOther, HelixRotationSetAtOtherBuilder> {
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
    implements Action, Built<ErrorMessageSet, ErrorMessageSetBuilder> {
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

abstract class SelectionBoxCreate
    with BuiltJsonSerializable
    implements Action, Built<SelectionBoxCreate, SelectionBoxCreateBuilder> {
  Point<num> get point;

  bool get toggle;

  bool get is_main;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectionBoxCreate(Point<num> point, bool toggle, bool is_main) => SelectionBoxCreate.from((b) => b
    ..point = point
    ..toggle = toggle
    ..is_main = is_main);

  factory SelectionBoxCreate.from([void Function(SelectionBoxCreateBuilder) updates]) = _$SelectionBoxCreate;

  SelectionBoxCreate._();

  static Serializer<SelectionBoxCreate> get serializer => _$selectionBoxCreateSerializer;
}

abstract class SelectionBoxSizeChange
    with BuiltJsonSerializable
    implements FastAction, Built<SelectionBoxSizeChange, SelectionBoxSizeChangeBuilder> {
  Point<num> get point;

  bool get is_main;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectionBoxSizeChange(Point<num> point, bool is_main) => SelectionBoxSizeChange.from((b) => b
    ..point = point
    ..is_main = is_main);

  factory SelectionBoxSizeChange.from([void Function(SelectionBoxSizeChangeBuilder) updates]) =
      _$SelectionBoxSizeChange;

  SelectionBoxSizeChange._();

  static Serializer<SelectionBoxSizeChange> get serializer => _$selectionBoxSizeChangeSerializer;
}

abstract class SelectionBoxRemove
    with BuiltJsonSerializable
    implements Action, Built<SelectionBoxRemove, SelectionBoxRemoveBuilder> {
  bool get is_main;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectionBoxRemove(bool is_main) => SelectionBoxRemove.from((b) => b..is_main = is_main);

  factory SelectionBoxRemove.from([void Function(SelectionBoxRemoveBuilder) updates]) = _$SelectionBoxRemove;

  SelectionBoxRemove._();

  static Serializer<SelectionBoxRemove> get serializer => _$selectionBoxRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Mouse position/grid position (side view)

abstract class MouseGridPositionSideUpdate
    with BuiltJsonSerializable
    implements Action, Built<MouseGridPositionSideUpdate, MouseGridPositionSideUpdateBuilder> {
  GridPosition get grid_position;

  /************************ begin BuiltValue boilerplate ************************/
  factory MouseGridPositionSideUpdate(GridPosition grid_position) =>
      MouseGridPositionSideUpdate.from((b) => b..grid_position.replace(grid_position));

  factory MouseGridPositionSideUpdate.from([void Function(MouseGridPositionSideUpdateBuilder) updates]) =
      _$MouseGridPositionSideUpdate;

  MouseGridPositionSideUpdate._();

  static Serializer<MouseGridPositionSideUpdate> get serializer => _$mouseGridPositionSideUpdateSerializer;
}

abstract class MouseGridPositionSideClear
    with BuiltJsonSerializable
    implements Action, Built<MouseGridPositionSideClear, MouseGridPositionSideClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory MouseGridPositionSideClear() => MouseGridPositionSideClear.from((b) => b);

  factory MouseGridPositionSideClear.from([void Function(MouseGridPositionSideClearBuilder) updates]) =
      _$MouseGridPositionSideClear;

  MouseGridPositionSideClear._();

  static Serializer<MouseGridPositionSideClear> get serializer => _$mouseGridPositionSideClearSerializer;
}

abstract class MousePositionSideUpdate
    with BuiltJsonSerializable
    implements Action, Built<MousePositionSideUpdate, MousePositionSideUpdateBuilder> {
  Point<num> get svg_pos;

  /************************ begin BuiltValue boilerplate ************************/
  factory MousePositionSideUpdate({Point<num> svg_pos}) = _$MousePositionSideUpdate._;

  MousePositionSideUpdate._();

  static Serializer<MousePositionSideUpdate> get serializer => _$mousePositionSideUpdateSerializer;
}

abstract class MousePositionSideClear
    with BuiltJsonSerializable
    implements Action, Built<MousePositionSideClear, MousePositionSideClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory MousePositionSideClear() = _$MousePositionSideClear;

  MousePositionSideClear._();

  static Serializer<MousePositionSideClear> get serializer => _$mousePositionSideClearSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Selectables

abstract class Select with BuiltJsonSerializable implements Action, Built<Select, SelectBuilder> {
  Selectable get selectable;

  // if true, negate current selection status; otherwise set to be selected irrespective of previous status
  bool get toggle;

  // if true, deselect all other items and select only this object; otherwise leave other selections alone
  bool get only;

  /************************ begin BuiltValue boilerplate ************************/
  factory Select(Selectable selectable, {bool toggle, bool only = false}) => Select.from((b) => b
    ..selectable = selectable
    ..toggle = toggle
    ..only = only);

  factory Select.from([void Function(SelectBuilder) updates]) = _$Select;

  Select._();

  static Serializer<Select> get serializer => _$selectSerializer;
}

abstract class SelectionsClear
    with BuiltJsonSerializable
    implements Action, Built<SelectionsClear, SelectionsClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SelectionsClear() => SelectionsClear.from((b) => b);

  factory SelectionsClear.from([void Function(SelectionsClearBuilder) updates]) = _$SelectionsClear;

  SelectionsClear._();

  static Serializer<SelectionsClear> get serializer => _$selectionsClearSerializer;
}

abstract class SelectionsAdjust
    with BuiltJsonSerializable
    implements Action, Built<SelectionsAdjust, SelectionsAdjustBuilder> {
  bool get toggle;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectionsAdjust(bool toggle) => SelectionsAdjust.from((b) => b..toggle = toggle);

  factory SelectionsAdjust.from([void Function(SelectionsAdjustBuilder) updates]) = _$SelectionsAdjust;

  SelectionsAdjust._();

  static Serializer<SelectionsAdjust> get serializer => _$selectionsAdjustSerializer;
}

// This selects all that are specified in constructor. SelectAllSelectable selects all selectable items
// in the whole design.
abstract class SelectAll with BuiltJsonSerializable implements Action, Built<SelectAll, SelectAllBuilder> {
  BuiltList<Selectable> get selectables;

  // if true, deselect all other items and select only this object; otherwise leave other selections alone
  bool get only;

  /************************ begin BuiltValue boilerplate ************************/
  factory SelectAll({BuiltList<Selectable> selectables, bool only}) = _$SelectAll._;

  SelectAll._();

  static Serializer<SelectAll> get serializer => _$selectAllSerializer;
}

// Selects all selectable items in the whole design.
abstract class SelectAllSelectable
    with BuiltJsonSerializable
    implements Action, Built<SelectAllSelectable, SelectAllSelectableBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory SelectAllSelectable() = _$SelectAllSelectable;

  SelectAllSelectable._();

  static Serializer<SelectAllSelectable> get serializer => _$selectAllSelectableSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Delete selected non-helix items

abstract class DeleteAllSelected
    with BuiltJsonSerializable, UndoableAction
    implements Built<DeleteAllSelected, DeleteAllSelectedBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory DeleteAllSelected() => DeleteAllSelected.from((b) => b);

  factory DeleteAllSelected.from([void Function(DeleteAllSelectedBuilder) updates]) = _$DeleteAllSelected;

  DeleteAllSelected._();

  static Serializer<DeleteAllSelected> get serializer => _$deleteAllSelectedSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helix add/remove

abstract class HelixAdd
    with BuiltJsonSerializable, UndoableAction
    implements Built<HelixAdd, HelixAddBuilder> {
  @nullable
  GridPosition get grid_position;

  @nullable
  Position3D get position;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixAdd({GridPosition grid_position = null, Position3D position = null}) {
    if (grid_position == null && position == null) {
      throw AssertionError('cannot have both grid_position and position null in HelixAdd');
    }
    return HelixAdd.from((b) => b
      ..grid_position = grid_position?.toBuilder()
      ..position = position?.toBuilder());
  }

  factory HelixAdd.from([void Function(HelixAddBuilder) updates]) = _$HelixAdd;

  HelixAdd._();

  static Serializer<HelixAdd> get serializer => _$helixAddSerializer;
}

abstract class HelixRemove
    with BuiltJsonSerializable, UndoableAction
    implements Built<HelixRemove, HelixRemoveBuilder> {
  int get helix_idx;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixRemove(int helix_idx) => HelixRemove.from((b) => b..helix_idx = helix_idx);

  factory HelixRemove.from([void Function(HelixRemoveBuilder) updates]) = _$HelixRemove;

  HelixRemove._();

  static Serializer<HelixRemove> get serializer => _$helixRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helix select (side view)

abstract class HelixSelect
    with BuiltJsonSerializable
    implements Action, Built<HelixSelect, HelixSelectBuilder> {
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

abstract class HelixSelectionsClear
    with BuiltJsonSerializable
    implements Action, Built<HelixSelectionsClear, HelixSelectionsClearBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory HelixSelectionsClear() => HelixSelectionsClear.from((b) => b);

  factory HelixSelectionsClear.from([void Function(HelixSelectionsClearBuilder) updates]) =
      _$HelixSelectionsClear;

  HelixSelectionsClear._();

  static Serializer<HelixSelectionsClear> get serializer => _$helixSelectionsClearSerializer;
}

abstract class HelixSelectionsAdjust
    with BuiltJsonSerializable
    implements Action, Built<HelixSelectionsAdjust, HelixSelectionsAdjustBuilder> {
  bool get toggle;

  SelectionBox get selection_box;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixSelectionsAdjust(bool toggle, SelectionBox selection_box) =>
      HelixSelectionsAdjust.from((b) => b
        ..toggle = toggle
        ..selection_box.replace(selection_box));

  factory HelixSelectionsAdjust.from([void Function(HelixSelectionsAdjustBuilder) updates]) =
      _$HelixSelectionsAdjust;

  HelixSelectionsAdjust._();

  static Serializer<HelixSelectionsAdjust> get serializer => _$helixSelectionsAdjustSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helix change major ticks

abstract class HelixIndividualAction implements Action {
  int get helix_idx;
}

abstract class HelixMajorTickDistanceChange
    with BuiltJsonSerializable, UndoableAction
    implements
        HelixIndividualAction,
        Built<HelixMajorTickDistanceChange, HelixMajorTickDistanceChangeBuilder> {
  int get helix_idx;

  int get major_tick_distance;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixMajorTickDistanceChange({int helix_idx, int major_tick_distance}) =
      _$HelixMajorTickDistanceChange._;

  HelixMajorTickDistanceChange._();

  static Serializer<HelixMajorTickDistanceChange> get serializer => _$helixMajorTickDistanceChangeSerializer;
}

abstract class HelixMajorTickDistanceChangeAll
    with BuiltJsonSerializable, UndoableAction
    implements Action, Built<HelixMajorTickDistanceChangeAll, HelixMajorTickDistanceChangeAllBuilder> {
  int get major_tick_distance;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixMajorTickDistanceChangeAll({int major_tick_distance}) = _$HelixMajorTickDistanceChangeAll._;

  HelixMajorTickDistanceChangeAll._();

  static Serializer<HelixMajorTickDistanceChangeAll> get serializer =>
      _$helixMajorTickDistanceChangeAllSerializer;
}

abstract class HelixMajorTicksChange
    with BuiltJsonSerializable, UndoableAction
    implements HelixIndividualAction, Built<HelixMajorTicksChange, HelixMajorTicksChangeBuilder> {
  int get helix_idx;

  BuiltList<int> get major_ticks;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixMajorTicksChange({int helix_idx, BuiltList<int> major_ticks}) = _$HelixMajorTicksChange._;

  HelixMajorTicksChange._();

  static Serializer<HelixMajorTicksChange> get serializer => _$helixMajorTicksChangeSerializer;
}

abstract class HelixMajorTicksChangeAll
    with BuiltJsonSerializable, UndoableAction
    implements Action, Built<HelixMajorTicksChangeAll, HelixMajorTicksChangeAllBuilder> {
  BuiltList<int> get major_ticks;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixMajorTicksChangeAll({BuiltList<int> major_ticks}) = _$HelixMajorTicksChangeAll._;

  HelixMajorTicksChangeAll._();

  static Serializer<HelixMajorTicksChangeAll> get serializer => _$helixMajorTicksChangeAllSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helix change min/max offsets

abstract class HelixOffsetChange
    with BuiltJsonSerializable, UndoableAction
    implements HelixIndividualAction, Built<HelixOffsetChange, HelixOffsetChangeBuilder> {
  int get helix_idx;

  @nullable
  int get min_offset;

  @nullable
  int get max_offset;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixOffsetChange({int helix_idx, int min_offset, int max_offset}) = _$HelixOffsetChange._;

  HelixOffsetChange._();

  static Serializer<HelixOffsetChange> get serializer => _$helixOffsetChangeSerializer;
}

abstract class HelixOffsetChangeAll
    with BuiltJsonSerializable, UndoableAction
    implements Built<HelixOffsetChangeAll, HelixOffsetChangeAllBuilder> {
  @nullable
  int get min_offset;

  @nullable
  int get max_offset;

  /************************ begin BuiltValue boilerplate ************************/
  factory HelixOffsetChangeAll({int min_offset, int max_offset}) = _$HelixOffsetChangeAll._;

  HelixOffsetChangeAll._();

  static Serializer<HelixOffsetChangeAll> get serializer => _$helixOffsetChangeAllSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Show mouseover box (side view)

abstract class ShowMouseoverRectSet
    with BuiltJsonSerializable
    implements Action, Built<ShowMouseoverRectSet, ShowMouseoverRectSetBuilder> {
  bool get show;

  /************************ begin BuiltValue boilerplate ************************/
  factory ShowMouseoverRectSet(bool show) => ShowMouseoverRectSet.from((b) => b..show = show);

  factory ShowMouseoverRectSet.from([void Function(ShowMouseoverRectSetBuilder) updates]) =
      _$ShowMouseoverRectSet;

  ShowMouseoverRectSet._();

  static Serializer<ShowMouseoverRectSet> get serializer => _$showMouseoverRectSetSerializer;
}

abstract class ShowMouseoverRectToggle
    with BuiltJsonSerializable
    implements Action, Built<ShowMouseoverRectToggle, ShowMouseoverRectToggleBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ShowMouseoverRectToggle() => ShowMouseoverRectToggle.from((b) => b);

  factory ShowMouseoverRectToggle.from([void Function(ShowMouseoverRectToggleBuilder) updates]) =
      _$ShowMouseoverRectToggle;

  ShowMouseoverRectToggle._();

  static Serializer<ShowMouseoverRectToggle> get serializer => _$showMouseoverRectToggleSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Export DNA

abstract class ExportDNA with BuiltJsonSerializable implements Action, Built<ExportDNA, ExportDNABuilder> {
  bool get include_scaffold;

  ExportDNAFormat get export_dna_format;

  /************************ begin BuiltValue boilerplate ************************/
  factory ExportDNA({bool include_scaffold, ExportDNAFormat export_dna_format}) = _$ExportDNA._;

  ExportDNA._();

  static Serializer<ExportDNA> get serializer => _$exportDNASerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Export SVG

abstract class ExportSvgMain
    with BuiltJsonSerializable
    implements Action, Built<ExportSvgMain, ExportSvgMainBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ExportSvgMain() => ExportSvgMain.from((b) => b);

  factory ExportSvgMain.from([void Function(ExportSvgMainBuilder) updates]) = _$ExportSvgMain;

  ExportSvgMain._();

  static Serializer<ExportSvgMain> get serializer => _$exportSvgMainSerializer;
}

abstract class ExportSvgSide
    with BuiltJsonSerializable
    implements Action, Built<ExportSvgSide, ExportSvgSideBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ExportSvgSide() => ExportSvgSide.from((b) => b);

  factory ExportSvgSide.from([void Function(ExportSvgSideBuilder) updates]) = _$ExportSvgSide;

  ExportSvgSide._();

  static Serializer<ExportSvgSide> get serializer => _$exportSvgSideSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Strand part action

abstract class StrandPartAction extends Action {
  StrandPart get strand_part;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// loopout length change

abstract class LoopoutLengthChange
    with BuiltJsonSerializable, UndoableAction
    implements StrandPartAction, Built<LoopoutLengthChange, LoopoutLengthChangeBuilder> {
  Loopout get loopout;

  int get length;

  StrandPart get strand_part => loopout;

  /************************ begin BuiltValue boilerplate ************************/
  factory LoopoutLengthChange(Loopout loopout, int length) => LoopoutLengthChange.from((b) => b
    ..loopout.replace(loopout)
    ..length = length);

  factory LoopoutLengthChange.from([void Function(LoopoutLengthChangeBuilder) updates]) =
      _$LoopoutLengthChange;

  LoopoutLengthChange._();

  static Serializer<LoopoutLengthChange> get serializer => _$loopoutLengthChangeSerializer;
}

abstract class ConvertCrossoverToLoopout
    with BuiltJsonSerializable, UndoableAction
    implements StrandPartAction, Built<ConvertCrossoverToLoopout, ConvertCrossoverToLoopoutBuilder> {
  Crossover get crossover;

  int get length;

  StrandPart get strand_part => crossover;

  /************************ begin BuiltValue boilerplate ************************/
  factory ConvertCrossoverToLoopout(Crossover crossover, int length) =>
      ConvertCrossoverToLoopout.from((b) => b
        ..crossover.replace(crossover)
        ..length = length);

  factory ConvertCrossoverToLoopout.from([void Function(ConvertCrossoverToLoopoutBuilder) updates]) =
      _$ConvertCrossoverToLoopout;

  ConvertCrossoverToLoopout._();

  static Serializer<ConvertCrossoverToLoopout> get serializer => _$convertCrossoverToLoopoutSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// nick/join

abstract class Nick with BuiltJsonSerializable, UndoableAction implements Built<Nick, NickBuilder> {
  BoundSubstrand get bound_substrand;

  int get offset;

  /************************ begin BuiltValue boilerplate ************************/
  factory Nick({BoundSubstrand bound_substrand, int offset}) = _$Nick._;

  Nick._();

  static Serializer<Nick> get serializer => _$nickSerializer;
}

abstract class Ligate with BuiltJsonSerializable, UndoableAction implements Built<Ligate, LigateBuilder> {
  DNAEnd get dna_end;

  /************************ begin BuiltValue boilerplate ************************/
  factory Ligate({DNAEnd dna_end}) = _$Ligate._;

  Ligate._();

  static Serializer<Ligate> get serializer => _$ligateSerializer;
}

abstract class JoinStrandsByCrossover
    with BuiltJsonSerializable, UndoableAction
    implements Built<JoinStrandsByCrossover, JoinStrandsByCrossoverBuilder> {
  DNAEnd get dna_end_first_click;

  DNAEnd get dna_end_second_click;

  /************************ begin BuiltValue boilerplate ************************/
  factory JoinStrandsByCrossover({DNAEnd dna_end_first_click, DNAEnd dna_end_second_click}) =
      _$JoinStrandsByCrossover._;

  JoinStrandsByCrossover._();

  static Serializer<JoinStrandsByCrossover> get serializer => _$joinStrandsByCrossoverSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// create new Strand with a single BoundSubstrand with no deletions or insertions

abstract class StrandCreateStart
    with BuiltJsonSerializable
    implements Action, Built<StrandCreateStart, StrandCreateStartBuilder> {
  Address get address;

  Color get color;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandCreateStart({Address address, Color color}) = _$StrandCreateStart._;

  StrandCreateStart._();

  static Serializer<StrandCreateStart> get serializer => _$strandCreateStartSerializer;
}

abstract class StrandCreateAdjustOffset
    with BuiltJsonSerializable
    implements Action, Built<StrandCreateAdjustOffset, StrandCreateAdjustOffsetBuilder> {
  int get offset;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandCreateAdjustOffset({int offset}) = _$StrandCreateAdjustOffset._;

  StrandCreateAdjustOffset._();

  static Serializer<StrandCreateAdjustOffset> get serializer => _$strandCreateAdjustOffsetSerializer;
}

abstract class StrandCreateStop
    with BuiltJsonSerializable
    implements Action, Built<StrandCreateStop, StrandCreateStopBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory StrandCreateStop() = _$StrandCreateStop;

  StrandCreateStop._();

  static Serializer<StrandCreateStop> get serializer => _$strandCreateStopSerializer;
}

abstract class StrandCreateCommit
    with BuiltJsonSerializable, UndoableAction
    implements Built<StrandCreateCommit, StrandCreateCommitBuilder> {
  int get helix_idx;

  int get start;

  int get end;

  bool get forward;

  Color get color;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandCreateCommit({int helix_idx, bool forward, int start, int end, Color color}) =
      _$StrandCreateCommit._;

  StrandCreateCommit._();

  static Serializer<StrandCreateCommit> get serializer => _$strandCreateCommitSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// potential crossover and linking strands by crossover

abstract class PotentialCrossoverCreate
    with BuiltJsonSerializable
    implements Action, Built<PotentialCrossoverCreate, PotentialCrossoverCreateBuilder> {
  PotentialCrossover get potential_crossover;

  /************************ begin BuiltValue boilerplate ************************/
  factory PotentialCrossoverCreate({PotentialCrossover potential_crossover}) = _$PotentialCrossoverCreate._;

  PotentialCrossoverCreate._();

  static Serializer<PotentialCrossoverCreate> get serializer => _$potentialCrossoverCreateSerializer;
}

abstract class PotentialCrossoverMove
    with BuiltJsonSerializable
    implements FastAction, Built<PotentialCrossoverMove, PotentialCrossoverMoveBuilder> {
  Point<num> get point;

  /************************ begin BuiltValue boilerplate ************************/
  factory PotentialCrossoverMove({Point<num> point}) = _$PotentialCrossoverMove._;

  PotentialCrossoverMove._();

  static Serializer<PotentialCrossoverMove> get serializer => _$potentialCrossoverMoveSerializer;
}

abstract class PotentialCrossoverRemove
    with BuiltJsonSerializable
    implements Action, Built<PotentialCrossoverRemove, PotentialCrossoverRemoveBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory PotentialCrossoverRemove() = _$PotentialCrossoverRemove;

  PotentialCrossoverRemove._();

  static Serializer<PotentialCrossoverRemove> get serializer => _$potentialCrossoverRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// strands move

abstract class StrandsMoveStart
    with BuiltJsonSerializable
    implements Action, Built<StrandsMoveStart, StrandsMoveStartBuilder> {
  BuiltList<Strand> get strands;

  Address get address;

  bool get copy;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandsMoveStart({BuiltList<Strand> strands, Address address, bool copy}) = _$StrandsMoveStart._;

  StrandsMoveStart._();

  static Serializer<StrandsMoveStart> get serializer => _$strandsMoveStartSerializer;
}

abstract class StrandsMoveStartSelectedStrands
    with BuiltJsonSerializable
    implements Action, Built<StrandsMoveStartSelectedStrands, StrandsMoveStartSelectedStrandsBuilder> {
  Address get address;

  bool get copy;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandsMoveStartSelectedStrands({Address address, bool copy}) = _$StrandsMoveStartSelectedStrands._;

  StrandsMoveStartSelectedStrands._();

  static Serializer<StrandsMoveStartSelectedStrands> get serializer =>
      _$strandsMoveStartSelectedStrandsSerializer;
}

abstract class StrandsMoveStop
    with BuiltJsonSerializable
    implements Action, Built<StrandsMoveStop, StrandsMoveStopBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory StrandsMoveStop() = _$StrandsMoveStop;

  StrandsMoveStop._();

  static Serializer<StrandsMoveStop> get serializer => _$strandsMoveStopSerializer;
}

abstract class StrandsMoveAdjustAddress
    with BuiltJsonSerializable
    implements Action, Built<StrandsMoveAdjustAddress, StrandsMoveAdjustAddressBuilder> {
  Address get address;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandsMoveAdjustAddress({Address address}) = _$StrandsMoveAdjustAddress._;

  StrandsMoveAdjustAddress._();

  static Serializer<StrandsMoveAdjustAddress> get serializer => _$strandsMoveAdjustAddressSerializer;
}

abstract class StrandsMoveCommit
    with BuiltJsonSerializable, UndoableAction
    implements Built<StrandsMoveCommit, StrandsMoveCommitBuilder> {
  StrandsMove get strands_move;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandsMoveCommit({StrandsMove strands_move}) = _$StrandsMoveCommit._;

  StrandsMoveCommit._();

  static Serializer<StrandsMoveCommit> get serializer => _$strandsMoveCommitSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// dna ends move

abstract class DNAEndsMoveStart
    with BuiltJsonSerializable
    implements Action, Built<DNAEndsMoveStart, DNAEndsMoveStartBuilder> {
  int get offset;

  Helix get helix;

  /************************ begin BuiltValue boilerplate ************************/
  factory DNAEndsMoveStart({int offset, Helix helix}) = _$DNAEndsMoveStart._;

  DNAEndsMoveStart._();

  static Serializer<DNAEndsMoveStart> get serializer => _$dNAEndsMoveStartSerializer;
}

/// This action is needed because [DNAEndsMoveStart] doesn't have enough information to find the set
/// of selected ends, and because we process the subsequent actions as a [FactAction] with an
/// optimized store, it doesn't have access to the full store either. So middleware on the full store
/// processes the [DNAEndsMoveStart] in order to find the selected ends and put them into the
/// [DNAEndMove]'s of this action.
abstract class DNAEndsMoveSetSelectedEnds
    with BuiltJsonSerializable
    implements Action, Built<DNAEndsMoveSetSelectedEnds, DNAEndsMoveSetSelectedEndsBuilder> {
  BuiltList<DNAEndMove> get moves;

  int get original_offset;

  Helix get helix;

  BuiltSet<Strand> get strands_affected;

  /************************ begin BuiltValue boilerplate ************************/
  factory DNAEndsMoveSetSelectedEnds(
      {BuiltList<DNAEndMove> moves,
      int original_offset,
      Helix helix,
      BuiltSet<Strand> strands_affected}) = _$DNAEndsMoveSetSelectedEnds._;

  DNAEndsMoveSetSelectedEnds._();

  static Serializer<DNAEndsMoveSetSelectedEnds> get serializer => _$dNAEndsMoveSetSelectedEndsSerializer;
}

abstract class DNAEndsMoveAdjustOffset
    with BuiltJsonSerializable
    implements FastAction, Built<DNAEndsMoveAdjustOffset, DNAEndsMoveAdjustOffsetBuilder> {
  int get offset;

  /************************ begin BuiltValue boilerplate ************************/
  factory DNAEndsMoveAdjustOffset({int offset}) = _$DNAEndsMoveAdjustOffset._;

  DNAEndsMoveAdjustOffset._();

  static Serializer<DNAEndsMoveAdjustOffset> get serializer => _$dNAEndsMoveAdjustOffsetSerializer;
}

abstract class DNAEndsMoveStop
    with BuiltJsonSerializable
    implements Action, Built<DNAEndsMoveStop, DNAEndsMoveStopBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory DNAEndsMoveStop() = _$DNAEndsMoveStop._;

  DNAEndsMoveStop._();

  static Serializer<DNAEndsMoveStop> get serializer => _$dNAEndsMoveStopSerializer;
}

abstract class DNAEndsMoveCommit
    with BuiltJsonSerializable, UndoableAction
    implements Built<DNAEndsMoveCommit, DNAEndsMoveCommitBuilder> {
  DNAEndsMove get dna_ends_move;

  /************************ begin BuiltValue boilerplate ************************/
  factory DNAEndsMoveCommit({DNAEndsMove dna_ends_move}) = _$DNAEndsMoveCommit._;

  DNAEndsMoveCommit._();

  static Serializer<DNAEndsMoveCommit> get serializer => _$dNAEndsMoveCommitSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// assign/remove dna

abstract class AssignDNA
    with BuiltJsonSerializable, UndoableAction
    implements Built<AssignDNA, AssignDNABuilder> {
  Strand get strand;

  String get dna_sequence;

  bool get assign_complements;

  /************************ begin BuiltValue boilerplate ************************/
  factory AssignDNA({Strand strand, String dna_sequence, bool assign_complements}) = _$AssignDNA._;

  AssignDNA._();

  static Serializer<AssignDNA> get serializer => _$assignDNASerializer;
}

abstract class RemoveDNA
    with BuiltJsonSerializable, UndoableAction
    implements Built<RemoveDNA, RemoveDNABuilder> {
  Strand get strand;

  bool get remove_complements;

  bool get remove_all;

  /************************ begin BuiltValue boilerplate ************************/
  factory RemoveDNA({Strand strand, bool remove_complements, bool remove_all}) = _$RemoveDNA._;

  RemoveDNA._();

  static Serializer<RemoveDNA> get serializer => _$removeDNASerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// insertion/deletion

abstract class InsertionOrDeletionAction implements UndoableAction, StrandPartAction {
  BoundSubstrand get substrand;

  int get offset;

  StrandPart get strand_part; // => substrand;

  InsertionOrDeletionAction clone_for_adjacent_substrand(BoundSubstrand other_substrand);
}

abstract class InsertionAdd
    with BuiltJsonSerializable, UndoableAction
    implements InsertionOrDeletionAction, Built<InsertionAdd, InsertionAddBuilder> {
  BoundSubstrand get substrand;

  int get offset;

  StrandPart get strand_part => substrand;

  InsertionAdd clone_for_adjacent_substrand(BoundSubstrand other_substrand) =>
      InsertionAdd(substrand: other_substrand, offset: offset);

  /************************ begin BuiltValue boilerplate ************************/
  factory InsertionAdd({BoundSubstrand substrand, int offset}) = _$InsertionAdd._;

  InsertionAdd._();

  static Serializer<InsertionAdd> get serializer => _$insertionAddSerializer;
}

abstract class InsertionLengthChange
    with BuiltJsonSerializable, UndoableAction
    implements InsertionOrDeletionAction, Built<InsertionLengthChange, InsertionLengthChangeBuilder> {
  BoundSubstrand get substrand;

  Insertion get insertion;

  int get length;

  int get offset => insertion.offset;

  StrandPart get strand_part => substrand;

  InsertionLengthChange clone_for_adjacent_substrand(BoundSubstrand other_substrand) => InsertionLengthChange(
        substrand: other_substrand,
        insertion: other_substrand.insertions.firstWhere((i) => i.offset == offset),
        length: length,
      );

  /************************ begin BuiltValue boilerplate ************************/
  factory InsertionLengthChange({BoundSubstrand substrand, Insertion insertion, int length}) =
      _$InsertionLengthChange._;

  InsertionLengthChange._();

  static Serializer<InsertionLengthChange> get serializer => _$insertionLengthChangeSerializer;
}

abstract class DeletionAdd
    with BuiltJsonSerializable, UndoableAction
    implements InsertionOrDeletionAction, Built<DeletionAdd, DeletionAddBuilder> {
  BoundSubstrand get substrand;

  int get offset;

  StrandPart get strand_part => substrand;

  DeletionAdd clone_for_adjacent_substrand(BoundSubstrand other_substrand) =>
      DeletionAdd(substrand: other_substrand, offset: offset);

  /************************ begin BuiltValue boilerplate ************************/
  factory DeletionAdd({BoundSubstrand substrand, int offset}) = _$DeletionAdd._;

  DeletionAdd._();

  static Serializer<DeletionAdd> get serializer => _$deletionAddSerializer;
}

abstract class InsertionRemove
    with BuiltJsonSerializable, UndoableAction
    implements InsertionOrDeletionAction, Built<InsertionRemove, InsertionRemoveBuilder> {
  BoundSubstrand get substrand;

  Insertion get insertion;

  int get offset => insertion.offset;

  StrandPart get strand_part => substrand;

  InsertionRemove clone_for_adjacent_substrand(BoundSubstrand other_substrand) => InsertionRemove(
        substrand: other_substrand,
        insertion: other_substrand.insertions.firstWhere((i) => i.offset == offset),
      );

  /************************ begin BuiltValue boilerplate ************************/
  factory InsertionRemove({BoundSubstrand substrand, Insertion insertion}) = _$InsertionRemove._;

  InsertionRemove._();

  static Serializer<InsertionRemove> get serializer => _$insertionRemoveSerializer;
}

abstract class DeletionRemove
    with BuiltJsonSerializable, UndoableAction
    implements InsertionOrDeletionAction, Built<DeletionRemove, DeletionRemoveBuilder> {
  BoundSubstrand get substrand;

  int get offset;

  StrandPart get strand_part => substrand;

  DeletionRemove clone_for_adjacent_substrand(BoundSubstrand other_substrand) =>
      DeletionRemove(substrand: other_substrand, offset: offset);

  /************************ begin BuiltValue boilerplate ************************/
  factory DeletionRemove({BoundSubstrand substrand, int offset}) = _$DeletionRemove._;

  DeletionRemove._();

  static Serializer<DeletionRemove> get serializer => _$deletionRemoveSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// grid change

abstract class GridChange
    with BuiltJsonSerializable, UndoableAction
    implements Built<GridChange, GridChangeBuilder> {
  Grid get grid;

  /************************ begin BuiltValue boilerplate ************************/
  factory GridChange({Grid grid}) = _$GridChange._;

  GridChange._();

  static Serializer<GridChange> get serializer => _$gridChangeSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// interactive dialog

abstract class DialogShow with BuiltJsonSerializable implements Action, Built<DialogShow, DialogShowBuilder> {
  Dialog get dialog;

  /************************ begin BuiltValue boilerplate ************************/
  factory DialogShow({Dialog dialog}) = _$DialogShow._;

  DialogShow._();

  static Serializer<DialogShow> get serializer => _$dialogShowSerializer;
}

abstract class DialogHide with BuiltJsonSerializable implements Action, Built<DialogHide, DialogHideBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory DialogHide() = _$DialogHide;

  DialogHide._();

  static Serializer<DialogHide> get serializer => _$dialogHideSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// context menu

abstract class ContextMenuShow
    with BuiltJsonSerializable
    implements Action, Built<ContextMenuShow, ContextMenuShowBuilder> {
  ContextMenu get context_menu;

  /************************ begin BuiltValue boilerplate ************************/
  factory ContextMenuShow({ContextMenu context_menu}) = _$ContextMenuShow._;

  ContextMenuShow._();

  static Serializer<ContextMenuShow> get serializer => _$contextMenuShowSerializer;
}

abstract class ContextMenuHide
    with BuiltJsonSerializable
    implements Action, Built<ContextMenuHide, ContextMenuHideBuilder> {
  /************************ begin BuiltValue boilerplate ************************/
  factory ContextMenuHide() = _$ContextMenuHide;

  ContextMenuHide._();

  static Serializer<ContextMenuHide> get serializer => _$contextMenuHideSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// scaffold set/unset

abstract class SingleStrandAction implements Action {
  Strand get strand;
}

abstract class ScaffoldSet
    with BuiltJsonSerializable, UndoableAction
    implements SingleStrandAction, Built<ScaffoldSet, ScaffoldSetBuilder> {
  Strand get strand;

  bool get is_scaffold;

  /************************ begin BuiltValue boilerplate ************************/
  factory ScaffoldSet({Strand strand, bool is_scaffold}) = _$ScaffoldSet._;

  ScaffoldSet._();

  static Serializer<ScaffoldSet> get serializer => _$scaffoldSetSerializer;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Strand color set

abstract class StrandColorSet
    with BuiltJsonSerializable
    implements SingleStrandAction, Built<StrandColorSet, StrandColorSetBuilder> {
  Strand get strand;

  Color get color;

  /************************ begin BuiltValue boilerplate ************************/
  factory StrandColorSet({Strand strand, Color color}) = _$StrandColorSet._;

  StrandColorSet._();

  static Serializer<StrandColorSet> get serializer => _$strandColorSetSerializer;
}
