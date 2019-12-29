import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:redux/redux.dart';
import 'package:scadnano/src/state/app_state.dart';
import 'package:scadnano/src/state/bound_substrand.dart';
import 'package:scadnano/src/state/dna_end.dart';
import 'package:scadnano/src/state/dna_end_move.dart';
import 'package:scadnano/src/state/substrand.dart';

import '../state/strand.dart';
import '../actions/actions.dart' as actions;
import 'assign_dna_reducer.dart';
import 'change_loopout_length.dart';
import 'delete_reducer.dart';
import 'insertion_deletion_reducer.dart';
import 'nick_join_reducers.dart';
import 'util_reducer.dart';

Reducer<BuiltList<Strand>> strands_local_reducer = combineReducers([
  TypedReducer<BuiltList<Strand>, actions.DNAEndsMoveCommit>(strands_dna_ends_move_stop_reducer),
  TypedReducer<BuiltList<Strand>, actions.AssignDNA>(assign_dna_reducer),
]);

GlobalReducer<BuiltList<Strand>, AppState> strands_global_reducer = combineGlobalReducers([
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.StrandPartAction>(strands_part_reducer),
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.StrandCreate>(strand_create),
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.DeleteAllSelected>(delete_all_reducer),
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.Nick>(nick_reducer),
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.Ligate>(ligate_reducer),
  TypedGlobalReducer<BuiltList<Strand>, AppState, actions.JoinStrandsByCrossover>(
      join_strands_by_crossover_reducer),
]);

// takes a part of a strand and looks up the strand it's in by strand_id, then applies reducer to strand
BuiltList<Strand> strands_part_reducer(
    BuiltList<Strand> strands, AppState state, actions.StrandPartAction action) {
  Strand strand = state.dna_design.strands_by_id[action.strand_part.strand_id];
  int strand_idx = strands.indexOf(strand);

  strand = strand_part_reducer(strand, action);
  //FIXME: is initialize still needed here after adjusting Strand._finalizeBuilder? also below
  strand = strand.initialize();

  var strands_builder = strands.toBuilder();
  strands_builder[strand_idx] = strand;
  return strands_builder.build();
}

Reducer<Strand> strand_part_reducer = combineReducers([
  TypedReducer<Strand, actions.ConvertCrossoverToLoopout>(convert_crossover_to_loopout_reducer),
  TypedReducer<Strand, actions.LoopoutLengthChange>(loopout_length_change_reducer),
  TypedReducer<Strand, actions.InsertionOrDeletionAction>(insertion_deletion_reducer),
]);

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// move DNA ends

BuiltList<Strand> strands_dna_ends_move_stop_reducer(
    BuiltList<Strand> strands, actions.DNAEndsMoveCommit action) {
  DNAEndsMove move = action.dna_ends_move;
  if (move.current_offset == move.original_offset) {
    return strands;
  }
  var strands_builder = strands.toBuilder();
  for (var strand in action.dna_ends_move.strands_affected) {
    int strand_idx = strands.indexOf(strand);
    strand = single_strand_dna_ends_move_stop_reducer(strand, move);
    strand = strand.initialize();
    strands_builder[strand_idx] = strand;
  }
  return strands_builder.build();
}

Strand single_strand_dna_ends_move_stop_reducer(Strand strand, DNAEndsMove all_move) {
//  int delta = all_move.current_offset - all_move.original_offset;
  List<Substrand> substrands = strand.substrands.toList();
  for (int i = 0; i < substrands.length; i++) {
    Substrand substrand = substrands[i];
    Substrand new_substrand = substrand;
    if (substrand is BoundSubstrand) {
      BoundSubstrand bound_ss = substrand;
      for (var dnaend in [substrand.dnaend_start, substrand.dnaend_end]) {
        DNAEndMove move = find_move(all_move.moves, dnaend);
        if (move != null) {
          int new_offset = all_move.current_capped_offset_of(dnaend);
//          int new_offset = adjust_offset(dnaend, move, delta);
          bound_ss = bound_ss.rebuild(
              (b) => dnaend == substrand.dnaend_start ? (b..start = new_offset) : (b..end = new_offset + 1));
          List<int> remaining_deletions = get_remaining_deletions(substrand, new_offset, dnaend);
          List<Insertion> remaining_insertions = get_remaining_insertions(substrand, new_offset, dnaend);
          bound_ss = bound_ss.rebuild(
              (b) => b..deletions.replace(remaining_deletions)..insertions.replace(remaining_insertions));
        }
      }
      new_substrand = bound_ss;
    }
    substrands[i] = new_substrand;
  }
  return strand.rebuild((b) => b..substrands.replace(substrands));
}

List<int> get_remaining_deletions(BoundSubstrand substrand, int new_offset, DNAEnd dnaend) =>
    substrand.deletions
        .where((d) => (substrand.dnaend_start == dnaend ? new_offset <= d : new_offset >= d))
        .toList();

List<Insertion> get_remaining_insertions(BoundSubstrand substrand, int new_offset, DNAEnd dnaend) =>
    substrand.insertions
        .where((i) => (substrand.dnaend_start == dnaend ? new_offset <= i.offset : new_offset >= i.offset))
        .toList();

int adjust_offset(DNAEnd end, DNAEndMove move, int delta) {
  int new_offset = end.offset_inclusive + delta;
  if (move.highest_offset != null && delta > 0) {
    new_offset = min(move.highest_offset, new_offset);
  } else if (move.lowest_offset != null && delta < 0) {
    new_offset = max(move.lowest_offset, new_offset);
  }
  return new_offset;
}

DNAEndMove find_move(BuiltList<DNAEndMove> moves, DNAEnd end) {
  for (DNAEndMove move in moves) {
    if (end == move.dna_end) {
      return move;
    }
  }
  return null;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// create Strand

BuiltList<Strand> strand_create(BuiltList<Strand> strands, AppState state, actions.StrandCreate action) {
  int helix_idx = action.helix_idx;
  int start = action.start;
  int end = action.end;
  bool forward = action.forward;

  // skip creating Strand if one is already there
  var existing_substrands_start = state.dna_design.substrands_on_helix_at(helix_idx, start);
  var existing_substrands_end = state.dna_design.substrands_on_helix_at(helix_idx, end - 1);
  for (var ss in existing_substrands_start.union(existing_substrands_end)) {
    if (ss.forward == forward) {
      return strands;
    }
  }

  BoundSubstrand substrand = BoundSubstrand(
      helix: helix_idx, forward: forward, start: start, end: end, is_first: true, is_last: true);
  Strand strand = Strand([substrand]);
  var new_strands = strands.rebuild((s) => s..add(strand));

  return new_strands;
}
