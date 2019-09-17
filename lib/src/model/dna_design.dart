import 'dart:math';

import 'package:color/color.dart';
import 'package:meta/meta.dart';
import 'package:scadnano/src/json_serializable.dart';

import 'strand.dart';
import 'helix.dart';
import '../constants.dart' as constants;

//TODO: support editing an existing DNADesign so that user can modify strands, etc.

//TODO: add support for PotentialHelix (modify existing view code to query them)

//TODO: add a mixin that lets me specify for each class that when it is created using from_json,
//  it should store all the fields that are not used by scadnano,
//  and write them back out on serialization using to_json

//TODO: import/export cadnano files

//TODO: export IDT files

//TODO: export SVG

/// Represents parts of the Model to serialize
class DNADesign extends JSONSerializable {
  String version = constants.CURRENT_VERSION;

  Grid grid;

  int major_tick_distance;

  /// all helices in model
  List<Helix> helices = [];

  /// all strands in model
  List<Strand> strands = [];

  List<PotentialHelix> potential_helices = [];

  Map<BoundSubstrand, List<Mismatch>> _substrand_mismatches_map = {};

  DNADesign();

  //"private" constructor; meta package will warn if it is used outside testing
  @visibleForTesting
  DNADesign.internal();

  DNADesign.default_design({int num_helices_x = 10, int num_helices_y = 10}) {
    this.grid = Grid.square;
    this.major_tick_distance = 8;
    this.build_default_potential_helices(num_helices_x, num_helices_y);
    this.strands = [];
    this.helices = [];
  }

  build_default_potential_helices(int num_helices_x, int num_helices_y) {
    this.potential_helices = [];
    for (int gx = 0; gx < num_helices_x; gx++) {
      for (int gy = 0; gy < num_helices_y; gy++) {
        var grid_pos = GridPosition(gx, gy);
        this.potential_helices.add(PotentialHelix(grid_pos));
      }
    }
  }

  /// max number of bases allowed on any Helix in the Model
  int max_bases() {
    int ret = 0;
    for (var helix in this.helices) {
      if (ret < helix.max_bases) {
        ret = helix.max_bases;
      }
    }
    return ret;
  }

  /// This exact method name is required for Dart to know how to encode as JSON.
  Map<String, dynamic> to_json_serializable() {
    Map<String, dynamic> json_map = {constants.version_key: this.version};
    if (this.grid != constants.default_grid) {
      json_map[constants.grid_key] = grid_to_json(this.grid);
    }
    if (this.major_tick_distance != default_major_tick_distance(this.grid)) {
      json_map[constants.major_tick_distance_key] = this.major_tick_distance;
    }

    json_map[constants.helices_key] = [for (var helix in this.helices) helix.to_json_serializable()];

    if (this.potential_helices.isNotEmpty) {
      json_map[constants.potential_helices_key] = [
        for (var ph in this.potential_helices) ph.to_json_serializable()
      ];
    }

    json_map[constants.strands_key] = [for (var strand in this.strands) strand.to_json_serializable()];

    return json_map;
  }

  DNADesign.from_json(Map<String, dynamic> json_map) {
//    this.menu_view_ui_model.loaded_filename = filename;

    //TODO: add test for illegally overlapping substrands on Helix (copy algorithm from Python repo)

    this.version = json_map.containsKey(constants.version_key)
        ? json_map[constants.version_key]
        : constants.INITIAL_VERSION;

    this.grid =
        json_map.containsKey(constants.grid_key) ? grid_from_string(json_map[constants.grid_key]) : Grid.none;

    if (json_map.containsKey(constants.major_tick_distance_key)) {
      this.major_tick_distance = json_map[constants.major_tick_distance_key];
    } else if (json_map.containsKey(constants.grid_key)) {
      if (this.grid == Grid.hex || this.grid == Grid.honeycomb) {
        this.major_tick_distance = 7;
      } else {
        this.major_tick_distance = 8;
      }
    }

    this.helices = [];
    List<dynamic> deserialized_helices_list = json_map[constants.helices_key];
    int idx = 0;
    for (var helix_json in deserialized_helices_list) {
      Helix helix = Helix.from_json(helix_json);
      helix.set_idx_no_change_notification(idx);
      idx++;
      this.helices.add(helix);
    }

    this.potential_helices = [];
    if (json_map.containsKey(constants.potential_helices_key)) {
      List<dynamic> deserialized_potential_helices_list = json_map[constants.potential_helices_key];
      for (var potential_helix_json in deserialized_potential_helices_list) {
        PotentialHelix potential_helix = PotentialHelix.from_json(potential_helix_json);
        this.potential_helices.add(potential_helix);
      }
    }

    this.strands = [];
    List<dynamic> deserialized_strand_list = json_map[constants.strands_key];
    for (var strand_json in deserialized_strand_list) {
      Strand strand = Strand.from_json(strand_json);
      this.strands.add(strand);
    }

    //XXX: order of these is important because each uses the data calculated from the previous
    this._set_helices_idxs();
    this._set_helices_grid_and_svg_positions();
    this._build_helix_idx_substrands_map();
    this._set_helices_max_bases(update: false);
    this._build_substrand_mismatches_map();
    this._check_legal_design();
  }

  static int default_major_tick_distance(Grid grid) {
    return grid == Grid.hex || grid == Grid.honeycomb ? 7 : 8;
  }

  _set_helices_idxs() {
    for (int idx = 0; idx < this.helices.length; idx++) {
      var helix = this.helices[idx];
      helix.set_idx_no_change_notification(idx);
    }
  }

  _set_helices_grid_and_svg_positions() {
    for (int idx = 0; idx < this.helices.length; idx++) {
      var helix = this.helices[idx];
      if (helix.grid_position == null) {
        helix.set_default_grid_position();
      }
      if (helix.svg_position == null) {
        helix.set_default_svg_position();
      }
    }
  }

  _set_helices_max_bases({bool update = true}) {
    for (var helix in this.helices) {
      if (update || helix.max_bases < 0) {
        var max_bases = -1;
        for (var substrand in helix.bound_substrands()) {
          max_bases = max(max_bases, substrand.end);
        }
        helix.set_max_bases_directly(max_bases);
      }
    }
  }

  _check_legal_design() {
    //TODO: implement this and give reasonable error messages
  }

  String toString() => """DNADesign(grid=$grid, major_tick_distance=$major_tick_distance, 
  helices=$helices, 
  strands=$strands)""";

  _build_helix_idx_substrands_map() {
    for (Strand strand in this.strands) {
      for (Substrand substrand in strand.substrands) {
        if (substrand.is_bound_substrand()) {
          var bound_ss = substrand as BoundSubstrand;
          this.helices[bound_ss.helix].bound_substrands().add(bound_ss);
        }
      }
    }
  }

  _build_substrand_mismatches_map() {
    this._substrand_mismatches_map = {};
    for (Strand strand in this.strands) {
      if (strand.dna_sequence != null) {
        for (Substrand substrand in strand.substrands) {
          if (substrand.is_bound_substrand()) {
            var bound_ss = substrand as BoundSubstrand;
            this._substrand_mismatches_map[bound_ss] = this._find_mismatches_on_substrand(bound_ss);
          }
        }
      }
    }
  }

  List<Mismatch> _find_mismatches_on_substrand(BoundSubstrand substrand) {
    List<Mismatch> mismatches = [];

    for (int offset = substrand.start; offset < substrand.end; offset++) {
      if (substrand.deletions.contains(offset)) {
        continue;
      }

      var other_ss = this.other_substrand_at_offset(substrand, offset);
      if (other_ss == null || other_ss.dna_sequence() == null) {
        continue;
      }

      this._ensure_other_substrand_same_deletion_or_insertion(substrand, other_ss, offset);

      var seq = substrand.dna_sequence_in(offset, offset);
      var other_seq = other_ss.dna_sequence_in(offset, offset);
      assert(other_seq.length == seq.length);

      for (int idx = 0, idx_other = seq.length - 1; idx < seq.length; idx++, idx_other--) {
        if (seq.codeUnitAt(idx) != _wc(other_seq.codeUnitAt(idx_other))) {
          int dna_idx = substrand.offset_to_strand_dna_idx(offset, substrand.forward) + idx;
          int within_insertion = seq.length == 1 ? -1 : idx;
          var mismatch = Mismatch(dna_idx, offset, within_insertion: within_insertion);
          mismatches.add(mismatch);
        }
      }
    }
    return mismatches;
  }

  /// Return other substrand at `offset` on `substrand.helix_idx`, or null if there isn't one.
  BoundSubstrand other_substrand_at_offset(BoundSubstrand substrand, int offset) {
    List<BoundSubstrand> other_substrands = this._other_substrands_overlapping(substrand);
    for (var other_ss in other_substrands) {
      if (other_ss.contains_offset(offset)) {
        assert(substrand.forward != other_ss.forward);
        return other_ss;
      }
    }
    return null;
  }

  void _ensure_other_substrand_same_deletion_or_insertion(
      BoundSubstrand substrand, BoundSubstrand other_ss, int offset) {
    if (substrand.deletions.contains(offset) && !other_ss.deletions.contains(offset)) {
      throw UnsupportedError('cannot yet handle one strand having deletion at an offset but the overlapping '
          'strand does not\nThis was found between the substrands on helix ${substrand.helix} '
          'occupying offset intervals\n'
          '(${substrand.start}, ${substrand.end}) and\n'
          '(${other_ss.start}, ${other_ss.end})');
    }
    if (substrand.contains_insertion_at(offset) && !other_ss.contains_insertion_at(offset)) {
      throw UnsupportedError('cannot yet handle one strand having insertion at an offset but the overlapping '
          'strand does not\nThis was found between the substrands on helix ${substrand.helix} '
          'occupying offset intervals\n'
          '(${substrand.start}, ${substrand.end}) and\n'
          '(${other_ss.start}, ${other_ss.end})');
    }
  }

  /// Return list of mismatches in substrand where the base is mismatched with the overlapping substrand.
  /// If a mismatch occurs outside an insertion, within_insertion = -1).
  /// If a mismatch occurs in an insertion, within_insertion = relative position within insertion (0,1,...)).
  List<Mismatch> mismatches_on_substrand(BoundSubstrand substrand) {
    var ret = this._substrand_mismatches_map[substrand];
    if (ret == null) {
      ret = List<Mismatch>();
    }
    return ret;
  }

  /// Return list of substrands on the Helix with the given index.
  substrands_on_helix(int helix_idx) {
    return this.helices[helix_idx].bound_substrands();
  }

  /// Return list of Substrands overlapping `substrand`.
  List<BoundSubstrand> _other_substrands_overlapping(BoundSubstrand substrand) {
    List<BoundSubstrand> ret = [];
    var helix = this.helices[substrand.helix];
    for (var other_ss in helix.bound_substrands()) {
      if (substrand.overlaps(other_ss)) {
        ret.add(other_ss);
      }
    }
    return ret;
  }

//  /// Add new Helix.
//  /// If idx > 0, idx must be < current number of helices.
//  /// Inserted into middle of used helices if idx is intermediate, and other helces idx's are incremented.
//  add_helix(Helix helix) {
//    if (helix.idx >= 0) {
//      var new_idx = this.idx;
//      this.helix.idx = new_idx;
//      design.used_helices.insert(new_idx, this.helix);
//      for (var helix_after_idx_used in design.used_helices.sublist(new_idx + 1)) {
//        helix_after_idx_used.idx++;
//        app.controller.notifier_helix_change_used.add(helix_after_idx_used);
//      }
//    } else {
//      design.used_helices.removeAt(old_idx);
//      this.helix.idx = -1;
//      app.controller.notifier_helix_change_used.add(this.helix);
//      for (var helix_after_idx_unused in design.used_helices.sublist(old_idx)) {
//        helix_after_idx_unused.idx--;
//        app.controller.notifier_helix_change_used.add(helix_after_idx_unused);
//      }
//    }
//  }

//  /// Set helix used status to true. idx is new idx to use.
//  set_helix_used(Helix helix, int new_idx) {
//    helix.idx = new_idx;
//    this.used_helices.insert(new_idx, helix);
//    for (var helix_after_idx_used in this.used_helices.sublist(new_idx + 1)) {
//      helix_after_idx_used.idx++;
//      app.controller.notifier_helix_change_used.add(helix_after_idx_used);
//    }
//  }
//
//  /// Set helix used status to false.
//  set_helix_unused(Helix helix) {
//    int old_idx = helix.idx;
//    this.used_helices.removeAt(old_idx);
//    helix.idx = -1;
//    app.controller.notifier_helix_change_used.add(helix);
//    for (var helix_after_idx_unused in this.used_helices.sublist(old_idx)) {
//      helix_after_idx_unused.idx--;
//      app.controller.notifier_helix_change_used.add(helix_after_idx_unused);
//    }
//  }
}

class Mismatch {
  final int dna_idx;
  final int offset;
  final int within_insertion;

  Mismatch(this.dna_idx, this.offset, {this.within_insertion = -1});

  String toString() =>
      'Mismatch(dna_idx=${this.dna_idx}, offset=${this.offset}' +
      (this.within_insertion < 0 ? ')' : ', within_insertion=${this.within_insertion})');
}

final Map<int, int> _wc_table = {
  'A'.codeUnitAt(0): 'T'.codeUnitAt(0),
  'T'.codeUnitAt(0): 'A'.codeUnitAt(0),
  'G'.codeUnitAt(0): 'C'.codeUnitAt(0),
  'C'.codeUnitAt(0): 'G'.codeUnitAt(0),
  'a'.codeUnitAt(0): 't'.codeUnitAt(0),
  't'.codeUnitAt(0): 'a'.codeUnitAt(0),
  'g'.codeUnitAt(0): 'c'.codeUnitAt(0),
  'c'.codeUnitAt(0): 'g'.codeUnitAt(0),
};

int _wc(int code_unit) {
  if (_wc_table.containsKey(code_unit)) {
    return _wc_table[code_unit];
  } else {
    return code_unit;
  }
}

class IllegalDNADesignError implements Exception {
  String cause;

  IllegalDNADesignError(String the_cause) {
    this.cause = '**********************\n'
            '* illegal DNA design *\n'
            '**********************\n\n' +
        the_cause;
  }
}

class StrandError extends IllegalDNADesignError {
  StrandError(Strand strand, String the_cause) : super(the_cause) {
    var first_substrand = strand.first_bound_substrand();
    var last_substrand = strand.last_bound_substrand();

    var msg = '\n'
        'strand length        =  ${strand.dna_length}\n'
        'DNA length           =  ${strand.dna_sequence.length}\n'
        'DNA sequence         =  ${strand.dna_sequence}'
        "strand 5' helix      =  ${first_substrand.helix}\n"
        "strand 5' end offset =  ${first_substrand.offset_5p}\n"
        "strand 3' helix      =  ${last_substrand.helix}\n"
        "strand 3' end offset =  ${last_substrand.offset_3p}\n";

    this.cause += msg;
  }
}

Color parse_json_color(Map json_map) {
  int r = json_map['r'];
  int g = json_map['g'];
  int b = json_map['b'];
  return RgbColor(r, g, b);
}
