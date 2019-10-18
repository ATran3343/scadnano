import 'package:scadnano/src/model/bound_substrand.dart';
import 'package:scadnano/src/model/select_mode.dart';

import '../app.dart';
import 'strand.dart';
import 'selectable.dart';
import '../constants.dart' as constants;
import '../util.dart' as util;

class Loopout extends Substrand with Selectable {
  int loopout_length;

  Loopout(this.loopout_length) {
//    this.handle_actions();
  }

//  handle_actions() {
////    register_selectable(() => app.model.main_view_ui_model.selection.loopouts);
//  }

  register_selectables(SelectablesStore store) {
    store.register(this);
  }

//  trigger() {
//    print('calling Loopout.trigger() on ${id()}');
//    super.trigger();
//  }

  SelectModeChoice select_mode() => SelectModeChoice.loopout;

  String id() => 'loopout-${order()}-${strand.id()}';

  String toString() => 'Loopout(${this.loopout_length})';

  bool is_loopout() => true;

  int dna_length() => this.loopout_length;

  String dna_sequence() {
    String strand_seq = this.strand.dna_sequence;
    if (strand_seq == null) {
      return null;
    }

    int str_idx_left = this.get_seq_start_idx();
    int str_idx_right = str_idx_left + this.loopout_length; // EXCLUSIVE (unlike similar code for Substrand)
    String subseq = strand_seq.substring(str_idx_left, str_idx_right);
    return subseq;
  }

  /// Starting DNA subsequence index for first base of this :any:`Loopout` on its Parent
  /// :any:`Strand`'s DNA sequence.
  int get_seq_start_idx() {
    List<Substrand> substrands = this.strand.substrands;
    // index of self in parent strand's list of substrands
    int self_substrand_idx = substrands.indexOf(this);
    // index of self's position within the DNA sequence of parent strand
    int self_seq_idx_start = 0;
    for (Substrand prev_substrand in substrands.sublist(0, self_substrand_idx)) {
      self_seq_idx_start += prev_substrand.dna_length();
    }
    return self_seq_idx_start;
  }

  Loopout.from_json(Map<String, dynamic> json_map) {
    var name = 'Loopout';
    this.loopout_length = util.get_value(json_map, constants.loopout_key, name);
  }

  Map<String, dynamic> to_json_serializable() {
    var json_map = {
      constants.loopout_key: this.loopout_length,
    };
    return json_map;
  }

  int order() => strand.substrands.indexOf(this);

  BoundSubstrand prev_substrand() {
    int i = order();
    return i > 0 ? strand.substrands[i - 1] : null;
  }

  BoundSubstrand next_substrand() {
    int i = order();
    return i < strand.substrands.length - 1 ? strand.substrands[i + 1] : null;
  }
}
