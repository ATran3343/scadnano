import 'dart:math';

import 'package:platform_detect/platform_detect.dart';
import 'package:quiver/core.dart' as quiver;
import 'package:scadnano/src/json_serializable.dart';
import 'package:tuple/tuple.dart';
import 'package:w_flux/w_flux.dart';

import 'strand.dart';
import 'model.dart';
import '../app.dart';
import '../actions.dart';
import '../constants.dart' as constants;


/// If use=true, converting the given PotentialHelix to a Helix; otherwise converting the other way.
class UseHelixActionParameters extends ReversibleActionParameters {
  final bool use;
  final GridPosition grid_position;
  final int idx;

  UseHelixActionParameters(this.use, this.grid_position, this.idx);

  @override
  UseHelixActionParameters reverse() => UseHelixActionParameters(!this.use, this.grid_position, this.idx);
}

//class HelicesActions {
//  /// converts potential helix to actual helix, or the other way
//  static final use_helix_global = Action<UseHelixActionParameters>();
//
//  Action<UseHelixActionParameters> get use_helix => use_helix_global;
//
//  static final set_helices_global = Action<List<Helix>>();
//
//  Action<List<Helix>> get set_helices => set_helices_global;
//
//  static final set_potential_helices_global = Action<List<PotentialHelix>>();
//
//  Action<List<PotentialHelix>> get set_potential_helices => set_potential_helices_global;
//
//  static final set_all_helices_global = Action<Tuple2<List<Helix>, List<PotentialHelix>>>();
//
//  Action<Tuple2<List<Helix>, List<PotentialHelix>>> get set_all_helices => set_all_helices_global;
//}

class HelicesStore extends Store {
  static final use_helix_global = Action<UseHelixActionParameters>();

  Action<UseHelixActionParameters> get use_helix => use_helix_global;

  static final set_helices_global = Action<List<Helix>>();

  Action<List<Helix>> get set_helices => set_helices_global;

  static final set_potential_helices_global = Action<List<PotentialHelix>>();

  Action<List<PotentialHelix>> get set_potential_helices => set_potential_helices_global;

  static final set_all_helices_global = Action<Tuple2<List<Helix>, List<PotentialHelix>>>();

  Action<Tuple2<List<Helix>, List<PotentialHelix>>> get set_all_helices => set_all_helices_global;

//  HelicesActions _actions = HelicesActions();
//
//  get use_helix => this._actions.use_helix;
//
//  get set_helices => this._actions.set_helices;
//
//  get set_potential_helices => this._actions.set_potential_helices;
//
//  get set_all_helices => this._actions.set_all_helices;

  List<Helix> _helices;
  List<PotentialHelix> _potential_helices;

  List<Helix> get helices => this._helices;

  List<PotentialHelix> get potential_helices => this._potential_helices;

  set helices(List<Helix> new_helices) {
    this._helices = new_helices;
    this._build_helices_map();
  }

  set potential_helices(List<PotentialHelix> new_potential_helices) {
    this._potential_helices = new_potential_helices;
    this._build_helices_map();
  }

  Map<GridPosition, dynamic> _gp_to_helix;

  HelicesStore() {
    this._helices = [];
    this._potential_helices = [];
    this._build_helices_map();

    this._handle_actions();
  }

  _handle_actions() {
    triggerOnActionV2<UseHelixActionParameters>(this.use_helix, (params) {
      params.use ? this._convert_potential_to_helix(params) : this._convert_helix_to_potential(params);
    });

    triggerOnActionV2<List<Helix>>(this.set_helices, (new_helices) {
      this.helices = new_helices;
    });

    triggerOnActionV2<List<PotentialHelix>>(this.set_potential_helices, (new_potential_helices) {
      this.potential_helices = new_potential_helices;
    });

    triggerOnActionV2<Tuple2<List<Helix>, List<PotentialHelix>>>(this.set_all_helices, (all_helices) {
      this._helices = all_helices.item1;
      this._potential_helices = all_helices.item2;
      this._build_helices_map();
    });
  }

  void _convert_helix_to_potential(UseHelixActionParameters params) {
    Helix old_helix = this._gp_to_helix[params.grid_position];
    int old_idx = old_helix.idx();
    assert(old_idx == params.idx);
    PotentialHelix potential_helix = PotentialHelix(params.grid_position);

    this.helices.removeAt(old_idx);
    this.potential_helices.add(potential_helix);
    this._gp_to_helix[params.grid_position] = potential_helix;

    for (Helix helix_after_idx_unused in this.helices.sublist(old_idx)) {
      int prev_idx = helix_after_idx_unused.idx();
      helix_after_idx_unused.set_idx(prev_idx - 1);
    }
  }

  void _convert_potential_to_helix(UseHelixActionParameters params) {
    Helix helix = Helix(grid_position: params.grid_position, max_bases: constants.default_max_bases);
    helix.set_idx(params.idx);

    this.helices.insert(params.idx, helix);
    PotentialHelix old_pot_helix = this._gp_to_helix[params.grid_position];
    this.potential_helices.remove(old_pot_helix);
    this._gp_to_helix[params.grid_position] = helix;

    for (Helix helix_after_idx_used in this.helices.sublist(params.idx + 1)) {
      int prev_idx = helix_after_idx_used.idx();
      helix_after_idx_used.set_idx(prev_idx + 1);
    }
  }

  void _build_helices_map() {
    this._gp_to_helix = {};
    for (var h in this.helices) {
      this._gp_to_helix[h.grid_position()] = h;
    }
    for (var ph in this.potential_helices) {
      this._gp_to_helix[ph.grid_position()] = ph;
    }
  }
}

enum Grid { square, hex, honeycomb, none }

String grid_to_json(Grid grid) {
  switch (grid) {
    case Grid.square:
      return 'square';
    case Grid.hex:
      return 'hex';
    case Grid.honeycomb:
      return 'honeycomb';
    case Grid.none:
      return 'none';
    default:
      throw UnimplementedError('unrecognized grid: $grid');
  }
}

Grid grid_from_string(String string) {
  switch (string) {
    case 'square':
      return Grid.square;
    case 'hex':
      return Grid.hex;
    case 'honeycomb':
      return Grid.honeycomb;
    case 'none':
      return Grid.none;
    default:
      throw new UnimplementedError('unrecognized grid: $string');
  }
}

/// TODO: document GridPosition class
class GridPosition {
  final int h;
  final int v;
  final int b;

  const GridPosition(this.h, this.v, [this.b]);

  const GridPosition.origin() : this(0, 0, 0);

  const GridPosition.none() : this(-1, -1, -1);

  static const ORIGIN = GridPosition.origin(); //Point<int>(0, 0);
  static const NONE = GridPosition.origin(); //Point<int>(0, 0);

  GridPosition.from_list(List<dynamic> json_list)
      : this(json_list[0], json_list[1], json_list.length == 3 ? json_list[2] : 0);

  List<int> toJson() {
    var list = [
      this.h,
      this.v,
    ];
    if (this.b != 0) {
      list.add(this.b);
    }
    return list;
  }

  @override
//  int get hashCode => quiver.hash3(this.h, this.v, this.b);
  int get hashCode {
    int h = quiver.hash3(this.h, this.v, this.b);
    return h;
  }

  @override
  bool operator ==(other) {
    return this.h == other.h && this.v == other.v && this.b == other.b;
  }

  @override
  String toString() => '(${this.h}, ${this.v}, ${this.b})';
}

/// Represents a potential position for a Helix (the circles drawn in the side
/// view initially, which are unused helices). It has a grid position but nothing else.
class PotentialHelix extends JSONSerializable with ChangeNotifier {
  /// position within square/hex/honeycomb integer grid (side view)
  GridPosition _grid_position;

  GridPosition grid_position() => this._grid_position;

  PotentialHelix(this._grid_position) {
    this._set_change_notifier();
  }

  PotentialHelix.from_json(Map<String, dynamic> json_map) {
    this._set_change_notifier();

    if (json_map.containsKey(constants.grid_position_key)) {
      List<dynamic> gp_list = json_map[constants.grid_position_key];
      if (!(gp_list.length == 2 || gp_list.length == 3)) {
        throw ArgumentError(
            "list of grid_position coordinates must be length 2 or 3 but this is the list: ${gp_list}");
      }
      this._grid_position = GridPosition.from_list(gp_list);
    }
  }

  Map<String, dynamic> to_json_serializable() {
    Map<String, dynamic> json_map = {constants.grid_position_key: this._grid_position};
    return json_map;
  }

  num get gh => this._grid_position.h;

  num get gv => this._grid_position.v;

  num get gb => this._grid_position.b;

  _set_change_notifier() {
    this.notifier = app.controller.notifier_potential_helix_change;
  }
}

//TODO: rename Helix.max_bases to max_offset, add Helix.min_offset, and allow offsets to be negative

/// Represents a helix (as opposed to the circles drawn in the side
/// view initially, which are unused helices). However, a helix doesn't
/// have to have any strands on it.
class Helix extends JSONSerializable {
  /// unique identifier of used helix; also index indicating order to show
  /// in main view from top to bottom (unused helices not shown in main view)
  /// by default. This default positioning can be overridden by setting the position field.
  int _idx = -1;

  /// position within square/hex/honeycomb integer grid (side view)
  GridPosition _grid_position = null;

  /// SVG position of upper-left corner (main view). This is only 2D.
  /// There is a position object that can be stored in the JSON, but this is used only for 3D visualization,
  /// which is currently unsupported in scadnano. If we want to support it in the future, we can store that
  /// position in Helix as well, but svg_position will always be 2D.
  Point<num> _svg_position = null;

  /// Maximum length (in bases) of Substrand that can be drawn on this Helix.
  int _max_bases = -1;

  int _major_tick_distance = -1;

  List<int> _major_ticks = null;

  int get major_tick_distance => this._major_tick_distance;

  List<int> get major_ticks => this._major_ticks;

  bool has_major_tick_distance() => this._major_tick_distance >= 0;

  bool has_major_ticks() => this._major_ticks != null;

  set major_tick_distance(int new_dist) {
    this._major_tick_distance = new_dist;
  }

  set major_ticks(List<int> new_ticks) {
    this._major_ticks = new_ticks;
  }

  num get gh => this._grid_position.h;

  num get gv => this._grid_position.v;

  num get gb => this._grid_position.b;

  GridPosition grid_position() => this._grid_position;

  Point<num> svg_position() => this._svg_position;

  int get max_bases => this._max_bases;

  List<BoundSubstrand> _substrands = [];

  List<BoundSubstrand> bound_substrands() => this._substrands;

  Helix({grid_position, max_bases}) {
    this._grid_position = grid_position;
    this._max_bases = max_bases;
  }

  dynamic to_json_serializable() {
    Map<String, dynamic> json_map = {};

    if (this.has_grid_position()) {
      json_map[constants.grid_position_key] = this._grid_position;
    }

    if (this.has_nondefault_svg_position()) {
      json_map[constants.svg_position_key] = [this._svg_position.x, this._svg_position.y];
    }

    if (this.has_nondefault_max_bases()) {
      json_map[constants.max_bases_key] = this.max_bases;
    }

    return NoIndent(json_map);
  }

  /// Gets "center of base" (middle of square representing base) given helix idx and offset,
  /// depending on whether strand is going forward or not.
  Point<num> svg_base_pos(int offset, bool forward) {
    num x = constants.BASE_WIDTH_SVG / 2 + offset * constants.BASE_WIDTH_SVG + this._svg_position.x;
    num y = constants.BASE_HEIGHT_SVG / 2 + this._svg_position.y;
    if (!forward) {
      y += 10;
    }
    return Point<num>(x, y);
  }

  // Don't know why but Firefox knows about the SVG translation already so no need to correct for it.
  int svg_x_to_offset(num x) {
    var offset;
    if (browser.isFirefox) {
      offset = (x / constants.BASE_WIDTH_SVG).floor();
    } else {
      offset = ((x - this._svg_position.x) / constants.BASE_WIDTH_SVG).floor();
    }
    return offset;
  }

  // Don't know why but Firefox knows about the SVG translation already so no need to correct for it.
  bool svg_y_is_forward(num y) {
    var relative_y;
    if (browser.isFirefox) {
      relative_y = y;
    } else {
      relative_y = (y - this._svg_position.y);
    }
    return relative_y < 10;
  }

  GridPosition default_grid_position() {
    return GridPosition(0, this._idx);
  }

  Point<num> default_svg_position() {
    return Point<num>(0, constants.DISTANCE_BETWEEN_HELICES_SVG * this._idx);
  }

  int idx() => this._idx;

  set_idx(int new_idx) {
    this._idx = new_idx;
    this._svg_position = this.default_svg_position();
//    this.notify_changed();
  }

//  /// Sets idx without changing svg position or notifying listeners.
//  /// Intended only for specialized use within library.
//  set_idx_no_change_notification(int new_idx) {
//    this._idx = new_idx;
//    this._svg_position = this.default_svg_position();
//  }

  int get hashCode =>
      quiver.hash4(this._idx, this._grid_position.h, this._grid_position.v, this._grid_position.b);

  operator ==(other) {
    if (other is Helix) {
      var other_helix = other;
      return this._idx == other_helix._idx && this._grid_position == other_helix._grid_position;
    } else {
      return false;
    }
  }

  String toString() => "Helix(idx=$_idx, gh=$gh, gv=$gv, gb=$gb, max_bases=$max_bases})";

  bool has_substrands() => this._substrands.isNotEmpty;

  bool has_grid_position() => this._grid_position != null;

  bool has_svg_position() => this._svg_position != null;

  bool has_nondefault_svg_position() {
    num eps = 0.00000001;
    num default_x = this
        .default_svg_position()
        .x;
    num default_y = this
        .default_svg_position()
        .y;
    num this_x = this._svg_position.x;
    num this_y = this._svg_position.y;
    num diff_x = (this_x - default_x).abs();
    num diff_y = (this_y - default_y).abs();
    return diff_x > eps && diff_y > eps;
  }

  bool has_max_bases() => this._max_bases != null;

  bool has_nondefault_max_bases() {
    int max_ss_offset = -1;
    for (var ss in this._substrands) {
      if (max_ss_offset < ss.end) {
        max_ss_offset = ss.end;
      }
    }
    return this.max_bases != max_ss_offset;
  }

  Helix.from_json(Map<String, dynamic> json_map) {
    if (json_map.containsKey(constants.major_tick_distance_key)) {
      this._major_tick_distance = json_map[constants.major_tick_distance_key];
    }

    if (json_map.containsKey(constants.major_ticks_key)) {
      this._major_ticks = List<int>.from(json_map[constants.major_ticks_key]);
    }

    if (json_map.containsKey(constants.grid_position_key)) {
      List<dynamic> gp_list = json_map[constants.grid_position_key];
      if (!(gp_list.length == 2 || gp_list.length == 3)) {
        throw ArgumentError(
            "list of grid_position coordinates must be length 2 or 3 but this is the list: ${gp_list}");
      }
      this._grid_position = GridPosition.from_list(gp_list);
    }

    if (json_map.containsKey(constants.svg_position_key)) {
      List<dynamic> svg_position_list = json_map[constants.svg_position_key];
      if (svg_position_list.length != 2) {
        throw ArgumentError(
            "svg_position must have exactly two integers but instead it has ${svg_position_list
                .length}: ${svg_position_list}");
      }
      this._svg_position = Point<num>(svg_position_list[0], svg_position_list[1]);
    }

    if (json_map.containsKey(constants.max_bases_key)) {
      this._max_bases = json_map[constants.max_bases_key];
    }
  }

  set_default_grid_position() {
    this._grid_position = this.default_grid_position();
  }

  set_default_svg_position() {
    this._svg_position = this.default_svg_position();
  }

  set_max_bases_directly(int max_bases) {
    this._max_bases = max_bases;
  }

  /// Transform to apply to an SVG element so that it will appear in the correct position relative to this
  /// Helix.
  transform() => 'translate(${this
      .svg_position()
      .x} ${this
      .svg_position()
      .y})';

  num svg_width() => constants.BASE_WIDTH_SVG * this.max_bases;

  num svg_height() => 2 * constants.BASE_HEIGHT_SVG;

//  Helix.from_js_object(JsObject js_obj) {
//    this._idx = js_obj[constants.idx_key];
//
//    if (js_obj.hasProperty(constants.grid_position_key)) {
//      List<dynamic> gp_list = js_obj[constants.grid_position_key];
//      if (!(gp_list.length == 2 || gp_list.length == 3)) {
//        throw ArgumentError(
//            "list of grid_position coordinates must be length 2 or 3 but this is the list: ${gp_list}");
//      }
//      this._grid_position = GridPosition.from_list(gp_list);
//    }
//
//    if (js_obj.hasProperty(constants.svg_position_key)) {
//      List<dynamic> svg_position_list = js_obj[constants.svg_position_key];
//      if (svg_position_list.length != 2) {
//        throw ArgumentError(
//            "svg_position must have exactly two integers but instead it has ${svg_position_list.length}: ${svg_position_list}");
//      }
//      this._svg_position = Point<int>(svg_position_list[0], svg_position_list[1]);
//    } else {
//      this._svg_position = this.default_svg_position();
//    }
//
//    this._max_bases = js_obj[constants.max_bases_key];
//  }
}
