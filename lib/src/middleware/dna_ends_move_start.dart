import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:redux/redux.dart';
import 'package:scadnano/src/state/bound_substrand.dart';
import 'package:scadnano/src/state/dna_design.dart';
import 'package:scadnano/src/state/dna_end.dart';
import 'package:scadnano/src/state/dna_end_move.dart';
import 'package:scadnano/src/state/strand.dart';

import '../actions/actions.dart' as actions;
import '../app.dart';
import '../state/app_state.dart';

// This is needed to gather the list of selected ends and package them into an action to start the moving
// of selected ends. It is needed because the click on the DNAEnd that triggers the DNAEndsMoveStart action
// does not have access to the list of all selected ends. It is middleware instead of a reducer because
// it triggers a new action to be dispatched.
dna_ends_move_start_middleware(Store<AppState> store, action, NextDispatcher next) {
  next(action);

  if (action is actions.DNAEndsMoveStart) {
    BuiltSet<DNAEnd> selected_ends = store.state.ui_state.selectables_store.selected_dna_ends;
    List<DNAEndMove> moves = [];
    for (var end in selected_ends) {
      int current_offset = end.offset;
      int lowest_offset = find_allowable_offset(store.state.dna_design, end, selected_ends, false);
      int highest_offset = find_allowable_offset(store.state.dna_design, end, selected_ends, true);

      var move = DNAEndMove(
          dna_end: end,
          lowest_offset: lowest_offset,
          highest_offset: highest_offset,
          current_offset: current_offset);
      moves.add(move);
    }

    DNADesign design = store.state.dna_design;
    Set<Strand> strands_affected = {};
    for (var move in moves) {
      Strand strand = design.end_to_strand(move.dna_end);
      strands_affected.add(strand);
    }

    app.dispatch(actions.DNAEndsMoveSetSelectedEnds(
        original_offset: action.offset,
        moves: moves.toBuiltList(),
        helix: action.helix,
        strands_affected: strands_affected.toBuiltSet()));
  } else if (action is actions.DNAEndsMoveStop) {}
}

/// Finds extreme (highest or lowest depending on [highest]) offset that an end at [offset] could be
/// moved to. This depends on what is the closest end that is not selected, and how many selected ends
/// are in between this end and that one.
int find_allowable_offset(DNADesign dna_design, DNAEnd end, BuiltSet<DNAEnd> selected_ends, bool highest) {
  BoundSubstrand substrand = dna_design.end_to_substrand[end];
  int helix_idx = substrand.helix;
  Set<int> selected_offsets = selected_ends.map((e) => e.offset).toSet();

  // offsets of (selected) ends to right (if highest==true) or left (if highest==false) of end.offset
  List<int> unselected_end_offsets_to_one_side = [];
  List<int> selected_end_offsets_to_one_side = [];
  List<BoundSubstrand> other_substrands_same_dir_same_helix =
      dna_design.substrands_on_helix(helix_idx).where((ss) => ss.forward == substrand.forward).toList();
  for (var ss in other_substrands_same_dir_same_helix) {
    for (int other_offset in [ss.start, ss.end - 1]) {
      if (highest && other_offset > end.offset_inclusive) {
        if (selected_offsets.contains(other_offset)) {
          selected_end_offsets_to_one_side.add(other_offset);
        } else {
          unselected_end_offsets_to_one_side.add(other_offset);
        }
      } else if (!highest && other_offset < end.offset_inclusive) {
        if (selected_offsets.contains(other_offset)) {
          selected_end_offsets_to_one_side.add(other_offset);
        } else {
          unselected_end_offsets_to_one_side.add(other_offset);
        }
      }
    }
  }

  if (unselected_end_offsets_to_one_side.isEmpty) {
    return null;
  }

  int closest_unselected_offset = unselected_end_offsets_to_one_side.reduce(highest ? min : max);
  int num_selected_offsets_between = selected_end_offsets_to_one_side
      .where((o) => highest ? o < closest_unselected_offset : o > closest_unselected_offset)
      .length;
  int adjust_factor = highest ? -1 - num_selected_offsets_between : 1 + num_selected_offsets_between;

  return closest_unselected_offset + adjust_factor;
}
