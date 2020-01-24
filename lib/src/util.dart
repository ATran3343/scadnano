@JS()
library util;

import 'dart:convert';
import 'dart:html' hide ImageElement;
import 'dart:js' as js;
import 'dart:math';
import 'dart:async';
import 'dart:svg' hide Point;
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:color/color.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:platform_detect/platform_detect.dart';
import 'package:scadnano/src/state/app_state.dart';
import 'package:scadnano/src/state/app_ui_state.dart';
import 'package:scadnano/src/view/design.dart';

import 'app.dart';
import 'state/crossover.dart';
import 'state/dialog.dart';
import 'state/dna_end.dart';
import 'state/grid.dart';
import 'state/grid_position.dart';
import 'state/helix.dart';
import 'state/loopout.dart';
import 'state/dna_design.dart';
import 'constants.dart' as constants;
import 'state/bound_substrand.dart';
import 'state/position3d.dart';
import 'state/selectable.dart';
import 'state/selection_box.dart';
import 'state/strand.dart';
import 'actions/actions.dart' as actions;

const ASSERTION_ERROR_MESSAGE = 'You have discovered a bug. Please send this entire error message to\n'
    '  ${constants.BUG_REPORT_URL}';

final ColorCycler color_cycler = ColorCycler();

class ColorCycler {
  static List<Color> colors = [
    Color.rgb(204, 0, 0),
    Color.rgb(50, 184, 108),
    Color.rgb(247, 67, 8),
    Color.rgb(87, 187, 0),
    Color.rgb(0, 114, 0),
    Color.rgb(170, 170, 0),
    Color.rgb(3, 182, 162),
    Color.rgb(247, 147, 30),
    // Color.rgb(23, 0, 222), // don't like this because it looks too much like scaffold
    Color.rgb(50, 0, 150), // this one is better contrast with scaffold
    Color.rgb(184, 5, 108),
    Color.rgb(51, 51, 51),
    Color.rgb(115, 0, 222),
    Color.rgb(136, 136, 136),
  ];

  int idx = 0;

  ColorCycler();

  Color next() {
    Color next_color = colors[idx];
    idx = (idx + 1) % colors.length;
    return next_color;
  }

  static final Color scaffold_color = Color.rgb(0, 102, 204);
}

final scaffold_color = ColorCycler.scaffold_color;

make_dart_function_available_to_js(String js_function_name, Function dart_func) {
  setProperty(window, js_function_name, allowInterop(dart_func));
}

@JS()
external void set_allow_pan(bool allow);

/// Should only be called once at the start of the program
Future<DNADesign> dna_design_from_url(String url) async {
  String content = await get_text_file_content(url);
  Map<String, dynamic> parsed_json = jsonDecode(content);
  DNADesign dna_design = DNADesign.from_json(parsed_json);
  return dna_design;
}

Future<String> get_text_file_content(String url) async =>
    await HttpRequest.getString(url).then((content) => content);

///// Go to url specifying a directory, and if directory listing is enabled, parse the names of the
///// files ending in .dna. TODO: implement this, doesn't work now with local server
//Future<List<String>> get_dna_files_in_directory(String url) async {
//  String page = await HttpRequest.getString(url).then((content) => content);
//  print('page=\n$page');
//  var regex = RegExp(r'href="(.*\.dna)"');
//  var matches = regex.allMatches(page);
//  for (var match in matches) {
//    print('match: $match');
//  }
//  return [];
//}

Future<ByteBuffer> get_binary_file_content(String url) async {
  return await HttpRequest.request(url, responseType: 'arraybuffer').then((request) {
    return request.response;
  });
}

/// Pops up dialog to ask user for information and returns responses.
/// Returns null if dialog was canceled.
Future<List<DialogItem>> dialog(Dialog dialog) async {
  if (app.state.ui_state.dialog != null) {
    app.dispatch(actions.DialogHide());
  }
  // https://api.dart.dev/stable/2.7.0/dart-async/Completer-class.html
  Completer<List<DialogItem>> completer = Completer<List<DialogItem>>();
  dialog = dialog.rebuild((b) => b
    ..on_submit = (List<DialogItem> items) {
      completer.complete(items);
    });
  app.dispatch(actions.DialogShow(dialog: dialog));
  return completer.future;
}

/// Gets grid position of mouse cursor in side view.
GridPosition grid_position_of_mouse_in_side_view(Grid grid,
    {Point<num> mouse_pos = null, MouseEvent event = null}) {
  SvgSvgElement side_view_elt = querySelector('#${SIDE_VIEW_SVG_ID}') as SvgSvgElement;
  var svg_pos = transformed_svg_point(side_view_elt, false, mouse_pos: mouse_pos, event: event);
  var grid_pos = side_view_svg_to_grid(grid, svg_pos);
  return grid_pos;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// assign SVG coordinates to helices

List<Helix> helices_assign_svg(List<Helix> helices, Grid grid, [BuiltSet<int> selected_helix_idxs = null]) {
  if (selected_helix_idxs == null || selected_helix_idxs.isEmpty) {
    selected_helix_idxs = [for (int i = 0; i < helices.length; i++) i].toBuiltSet();
  }

  var selected_helices = [for (var helix in helices) if (selected_helix_idxs.contains(helix.idx)) helix];

  List<int> view_order = List<int>(selected_helices.length);
  for (int i = 0; i < selected_helices.length; i++) {
    view_order[i] = selected_helices[i].view_order;
  }

  List<Helix> new_helices = List<Helix>.from(helices);
  num prev_y = null;

  for (int i = 0; i < view_order.length; i++) {
    int i_unsorted = view_order[i];
    Helix helix = helices[i_unsorted];

    num x = 0; //TODO: shift x by grid_position.b or position.z
    num y = 0;
    if (i > 0) {
      int prev_i_unsorted = view_order[i - 1];
      var prev_helix = helices[prev_i_unsorted];
      num delta_y;
      if (grid.is_none()) {
        var prev_pos = prev_helix.position_;
        var pos = helix.position_;
        delta_y = ((pos.distance_xy(prev_pos))) * constants.NM_TO_MAIN_VIEW_SVG_PIXELS;
      } else {
        var prev_grid_position = prev_helix.grid_position;
        var grid_position = helix.grid_position;
        delta_y =
            prev_grid_position.distance_lattice(grid_position, grid) * constants.DISTANCE_BETWEEN_HELICES_SVG;
      }
      y = prev_y + delta_y;
    }
    prev_y = y;
    helix = helix.rebuild((b) => b..svg_position_ = Point<num>(x, y));

    new_helices[i_unsorted] = helix;
  }

  return new_helices;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// transforming of points

/// Return helix where click event occured, or the closest (e.g. if click was on a crossover).
Helix get_closest_helix(MouseEvent event, BuiltList<Helix> helices) {
  var svg_coord = round_point(svg_position_of_mouse_click(event));

  num svg_y = svg_coord.y;
  for (Helix helix in helices) {
    if (helix.svg_position.y <= svg_y && svg_y <= helix.svg_position.y + constants.BASE_HEIGHT_SVG * 2) {
      return helix;
    }
  }

  // didn't find a helix, so we'll find the closest one
  Helix helix_closest = helices.first;
  num min_dist = distance_y_coord_to_closest_helix(helix_closest, svg_y);
  for (Helix helix in helices) {
    if (distance_y_coord_to_closest_helix(helix, svg_y) < min_dist) {
      helix_closest = helix;
      min_dist = distance_y_coord_to_closest_helix(helix, svg_y);
    }
  }
  return helix_closest;
}

num distance_y_coord_to_closest_helix(Helix helix, num y) =>
    (helix.svg_position.y + constants.BASE_HEIGHT_SVG - y).abs();

/// Return (closest) helix, offset and direction where click event occurred.
Address get_closest_address(MouseEvent event, BuiltList<Helix> helices) {
  var svg_coord = round_point(svg_position_of_mouse_click(event));
  Helix helix = get_closest_helix(event, helices);
  int offset = helix.svg_x_to_offset(svg_coord.x);
  bool forward = helix.svg_y_is_forward(svg_coord.y);
  return Address(helix_idx: helix.idx, offset: offset, forward: forward);
}

//XXX: don't know why I need to correct for this here, but not when responding to a selection box mouse event
// might be related to the fact that the mouse coordinates for the selection box are detected outside of React
Point<num> svg_position_of_mouse_click(MouseEvent event) {
  Point<num> offset_in_svg_elt;
  if (browser.isFirefox) {
    offset_in_svg_elt = get_svg_point(event);
  } else {
    offset_in_svg_elt = event.offset;
  }
  return transform_mouse_coord_to_svg_current_panzoom(offset_in_svg_elt, true);
}

Point<num> get_svg_point(MouseEvent event) {
  if (browser.isFirefox) {
    Element svg_elt = svg_ancestor(event.target);
    var rect = svg_elt.getBoundingClientRect().topLeft;
    var offset = event.client - rect;
    return offset;
  } else {
    return event.client;
  }
}

SvgSvgElement svg_ancestor(SvgElement elt) {
  while (!(elt is SvgSvgElement)) {
    elt = elt.parent;
  }
  return elt;
}

Point<num> rect_to_point(Rect rect) => Point<num>(rect.x, rect.y);

Point<int> round_point(Point<num> point) => Point<int>(point.x.round(), point.y.round());

Point<num> transform_mouse_coord_to_svg_current_panzoom_correct_firefox(
    MouseEvent event, bool is_main_view, SvgSvgElement view_svg) {
  Point<num> point;
  if (!browser.isFirefox) {
    point = event.offset;
    point = transform_mouse_coord_to_svg_current_panzoom(point, is_main_view);
  } else {
    point = untransformed_svg_point(view_svg, event: event);
    point = transform_mouse_coord_to_svg_current_panzoom(point, is_main_view);
  }
  return point;
}

/// Gets untransformed coordinates of mouse_pos. If mouse_pos==null, get it from mouse event.client.
/// XXX: Firefox is the only browser to handle this correctly; cross-browser solution taken from
/// https://stackoverflow.com/questions/19713320/svg-viewbox-doesnt-return-correct-mouse-points-with-nested-svg-in-firefox
Point<num> untransformed_svg_point(SvgSvgElement svg_elt,
    {Point<num> mouse_pos = null, MouseEvent event = null}) {
  var svg_point_SVG = svg_elt.createSvgPoint();
  if (mouse_pos == null) {
    assert(event != null);
    mouse_pos = event.client;
  }
  svg_point_SVG.x = mouse_pos.x;
  svg_point_SVG.y = mouse_pos.y;
  //TODO: consider using svg_elt.getCtm(): https://github.com/anvaka/panzoom/commit/49be4a1bd6361598b79f29fe99adc2c125d93678
  var svg_point_SVG_1 = svg_point_SVG.matrixTransform(svg_elt.getScreenCtm().inverse());
  Point<num> svg_point = Point<num>(svg_point_SVG_1.x, svg_point_SVG_1.y);
  return svg_point;
}

/// Gets untransformed coordinates of mouse event in svg_elt.
/// XXX: Firefox is the only browser to handle this correctly; cross-browser solution taken from
/// https://stackoverflow.com/questions/19713320/svg-viewbox-doesnt-return-correct-mouse-points-with-nested-svg-in-firefox
Point<num> transformed_svg_point(SvgSvgElement svg_elt, bool is_main,
    {Point<num> mouse_pos = null, MouseEvent event = null}) {
  var svg_pos_untransformed = untransformed_svg_point(svg_elt, mouse_pos: mouse_pos, event: event);
  var svg_pos = transform_mouse_coord_to_svg_current_panzoom(svg_pos_untransformed, is_main);
  return svg_pos;
}

Point<num> transform_mouse_coord_to_svg_current_panzoom(Point<num> point, bool is_main) {
  return transform_mouse_coord_to_svg(point, current_pan(is_main), current_zoom(is_main));
}

/// Transform point by panning and zooming from mouse coordinates to SVG coordinates.
/// (Actually I needed to do what appears to be the inverse transformation here, not sure why.)
Point<num> transform_mouse_coord_to_svg(Point<num> point, Point<num> pan, num zoom) {
  return (point - pan) * (1.0 / zoom);
}

Point<num> transform_svg_to_mouse_coord(Point<num> point, Point<num> pan, num zoom) {
  // Don't know why but Firefox auto-corrects for the current SVG coordinates whereas Chrome does not
  if (browser.isFirefox || browser.isInternetExplorer) {
    return point;
  } else {
    return point * zoom + pan;
  }
}

transform_rect(
    Point<num> transform(Point<num> p, Point<num> pan, num zoom), Rect rect, Point<num> pan, num zoom) {
  var up_left = Point<num>(rect.x, rect.y);
  var low_right = Point<num>(rect.x + rect.width, rect.y + rect.height);
  var up_left_tran = transform(up_left, pan, zoom);
  var low_right_tran = transform(low_right, pan, zoom);
  rect.x = up_left_tran.x;
  rect.y = up_left_tran.y;
  rect.width = low_right_tran.x - rect.x;
  rect.height = low_right_tran.y - rect.y;
}

///Modifies Rect in place because there doesn't seem to be a constructor:
/// https://api.dartlang.org/stable/2.5.2/dart-svg/Rect-class.html
transform_rect_mouse_coord_to_svg(Rect rect, Point<num> pan, num zoom) {
  transform_rect(transform_mouse_coord_to_svg, rect, pan, zoom);
}

///Modifies Rect in place because there doesn't seem to be a constructor:
/// https://api.dartlang.org/stable/2.5.2/dart-svg/Rect-class.html
transform_rect_svg_to_mouse_coord(Rect rect, Point<num> pan, num zoom) {
  transform_rect(transform_svg_to_mouse_coord, rect, pan, zoom);
}

transform_rect_mouse_coord_to_svg_main_view(Rect rect) {
  transform_rect_mouse_coord_to_svg(rect, current_pan(true), current_zoom(true));
}

transform_rect_svg_to_mouse_coord_main_view(Rect rect) {
  transform_rect_svg_to_mouse_coord(rect, current_pan(true), current_zoom(true));
}

Point<num> side_view_grid_to_svg(GridPosition gp, Grid grid) {
  num radius = constants.SIDE_HELIX_RADIUS;
  Point<num> point;
  if (grid == Grid.square) {
    point = Point<num>(gp.h, gp.v);
  } else if (grid == Grid.hex || grid == Grid.honeycomb) {
    point = hex_grid_position_to_position2d_diameter_1_circles(gp);
  } else {
    throw ArgumentError(
        'cannot convert grid coordinates for grid unless it is one of square, hex, or honeycomb');
  }
  return point * 2 * radius;
}

/// see here for definitions: https://www.redblobgames.com/grids/hexagons/
enum HexGridCoordinateSystem { odd_r, even_r, odd_q, even_q }

/// Converts from hex grid_position to absolute real-number position,
/// assuming each grid circle has diameter 1,
/// and the center of circle at grid_position (0,0) is the origin.
Point<num> hex_grid_position_to_position2d_diameter_1_circles(GridPosition gp,
    [HexGridCoordinateSystem coordinate_system = HexGridCoordinateSystem.odd_q]) {
  num x, y;
  if (coordinate_system == HexGridCoordinateSystem.odd_r) {
    x = gp.h; // x offset from h
    if (gp.v % 2 == 1) {
      x += cos(2 * pi / 6); // x offset from v
    }
    y = sin(2 * pi / 6) * gp.v; // y offset from v
  } else if (coordinate_system == HexGridCoordinateSystem.even_q) {
    y = gp.v;
    if (gp.h % 2 == 1) {
      y -= cos(2 * pi / 6);
    }
    x = sin(2 * pi / 6) * gp.h;
  } else if (coordinate_system == HexGridCoordinateSystem.odd_q) {
    y = gp.v;
    if (gp.h % 2 == 1) {
      y += cos(2 * pi / 6);
    }
    x = sin(2 * pi / 6) * gp.h;
  } else {
    throw UnsupportedError('coordinate system ${coordinate_system} not supported');
  }
  return Point<num>(x, y);
}

/// Translates SVG coordinates in side view to Grid coordinates using the specified grid.
GridPosition side_view_svg_to_grid(Grid grid, Point<num> svg_coord,
    [HexGridCoordinateSystem coordinate_system = HexGridCoordinateSystem.odd_q]) {
  num radius = constants.SIDE_HELIX_RADIUS;
  num x = svg_coord.x / (2 * radius), y = svg_coord.y / (2 * radius);
  int h, v;
  int b = 0;
  if (grid.is_none()) {
    throw ArgumentError('cannot output grid coordinates for grid = Grid.none');
  } else if (grid == Grid.square) {
    h = x.round();
    v = y.round();
  } else if (grid == Grid.honeycomb || grid == Grid.hex) {
    if (coordinate_system == HexGridCoordinateSystem.odd_r) {
      v = (y / sin(2 * pi / 6)).round();
      if (v % 2 == 1) {
        x -= cos(2 * pi / 6);
      }
      h = x.round();
    } else if (coordinate_system == HexGridCoordinateSystem.even_q) {
      h = (x / sin(2 * pi / 6)).round();
      if (h % 2 == 1) {
        y += cos(2 * pi / 6);
      }
      v = y.round();
    } else if (coordinate_system == HexGridCoordinateSystem.odd_q) {
      h = (x / sin(2 * pi / 6)).round();
      if (h % 2 == 1) {
        y -= cos(2 * pi / 6);
      }
      v = y.round();
    } else {
      throw UnsupportedError('coordinate system ${coordinate_system} not supported');
    }
  }
  return GridPosition(h, v, b);
}

GridPosition position3d_to_grid(Position3D position, Grid grid) {
//  Point<num> svg_coord = position3d_to_main_view_svg(position);
  Point<num> svg_coord = position3d_to_side_view_svg(position);
  GridPosition grid_position = side_view_svg_to_grid(grid, svg_coord);
  return grid_position;
}

Position3D grid_to_position3d(GridPosition grid_position, Grid grid) {
//  GridPosition grid_position = side_view_svg_to_grid(grid_position, svg_coord);
  Point<num> svg_coord = side_view_grid_to_svg(grid_position, grid);
  Position3D position3d = svg_side_view_to_position3d(svg_coord);
  return position3d;
}

Point<num> position3d_to_main_view_svg(Position3D position) => Point<num>(
    (position.z / 0.34) * constants.BASE_WIDTH_SVG,
    (position.y / 2.5) * constants.DISTANCE_BETWEEN_HELICES_SVG);

Point<num> position3d_to_side_view_svg(Position3D position) => Point<num>(
    position.x * (constants.SIDE_HELIX_RADIUS * 2) / 2.5,
    position.y * (constants.SIDE_HELIX_RADIUS * 2) / 2.5);

Position3D svg_side_view_to_position3d(Point<num> svg_pos) => Position3D(
    x: svg_pos.x / (constants.SIDE_HELIX_RADIUS * 2) * 2.5,
    y: svg_pos.y / (constants.SIDE_HELIX_RADIUS * 2) * 2.5);

/// This goes into "window", so in JS you can access window.editor_content, and in Brython you can do this:
/// from browser import window
/// print(window['editor_content'])
save_editor_content_to_js_context(String new_content) {
  js.context[constants.editor_content_js_key] = new_content;
}

/// Tries to get value in map associated to key, but raises an exception if the key is not present.
/// Since this is only used for [DNADesign]s, it throws an [IllegalDNADesignError].
dynamic get_value(Map<String, dynamic> map, String key, String name) {
  if (!map.containsKey(key)) {
    throw IllegalDNADesignError('key "${key}" is missing from the description of a ${name}:\n  ${map}');
  } else {
    return map[key];
  }
}

/// Tries to get value in map associated to [key], returning [default_value] if [key] is not present.
/// If transformer is given and the key is found in the map, apply transformer to the associated value and return it.
T get_value_with_default<T, U>(Map<String, dynamic> map, String key, T default_value,
    {T Function(U) transformer = null}) {
  if (!map.containsKey(key)) {
    return default_value;
  } else {
    if (transformer == null) {
      return map[key];
    } else {
      return transformer(map[key]);
    }
  }
}

num sigmoid(num x) {
  return 1.0 / (1.0 + exp(-x));
}

@JS(constants.js_function_name_cache_svg)
external ImageElement cache_svg(String svg_elt_id);

@JS(constants.js_function_name_current_zoom_main)
external num current_zoom_main_js();

@JS(constants.js_function_name_current_zoom_side)
external num current_zoom_side_js();

@JS(constants.js_function_name_current_pan_main)
external List<num> current_pan_main_js();

@JS(constants.js_function_name_current_pan_side)
external List<num> current_pan_side_js();

Point<num> current_pan(bool is_main) {
  var ret = is_main ? current_pan_main_js() : current_pan_side_js();
  return Point<num>(ret[0], ret[1]);
}

num current_zoom(bool is_main) => is_main ? current_zoom_main_js() : current_zoom_side_js();

/// Indicates if loopout between two given strands is a hairpin.
bool is_hairpin(BoundSubstrand prev_ss, BoundSubstrand next_ss) {
  bool is_hairpin = prev_ss.helix == next_ss.helix &&
      prev_ss.forward != next_ss.forward &&
      (prev_ss.offset_3p - next_ss.offset_5p).abs() < 3;
  return is_hairpin;
}

enum BlobType { text, binary, image, excel }

String blob_type_to_string(BlobType blob_type) {
  switch (blob_type) {
    case BlobType.text:
      return 'text/plain;charset=utf-8';
    case BlobType.binary:
      return 'application/octet-stream';
    case BlobType.image:
      return 'data:image/svg+xml;charset=utf-8,';
    case BlobType.excel:
      // https://stackoverflow.com/questions/974079/setting-mime-type-for-excel-document
//      return 'application/vnd.ms-excel';
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  throw AssertionError(ASSERTION_ERROR_MESSAGE);
}

save_file(String default_filename, var content, {BlobType blob_type = BlobType.text}) async {
  try {
    String blob_type_string = blob_type_to_string(blob_type);
    Blob blob = new Blob([content], blob_type_string);
    String url = Url.createObjectUrlFromBlob(blob);
    var link = new AnchorElement()
      ..href = url
      ..download = default_filename;

    if (browser.isFirefox) {
      document.body.children.add(link);
    }
    //TODO: this await is my attempt to block until the user has selected a file, but it doesn't work.
    // The code keeps executing while they pick their file. Figure out how to detect if they picked a file or cancelled
    // If they cancelled then we should act as though nothing happened (in particular the Controller should not
    // send an Action indicating that the file was saved.
    // consider using one of these libraries if possible:
    //  https://github.com/jimmywarting/StreamSaver.js
    //  https://github.com/eligrey/FileSaver.js
    await link.click();

    if (browser.isFirefox) {
      link.remove();
    }

    Url.revokeObjectUrl(url);
  } on Exception catch (e, stackTrace) {
    var msg = e.toString() + '\n\n' + stackTrace.toString();
    app.store.dispatch(actions.ErrorMessageSet(msg));
    app.view.design_view.render(app.store.state);
    return;
  }

  //TODO: create separate textfield for user to enter desired save filename that we use above
  // we cannot pull it from the download dialog due to security:
  //  https://github.com/eligrey/FileSaver.js/issues/75
  //  https://github.com/WICG/native-file-system
}

pprint(Map map) {
  print('{');
  for (var key in map.keys) {
    print('$key: ${map[key]},');
  }
  print('}');
}

String id_insertion(BoundSubstrand substrand, int offset) =>
    'insertion-H${substrand.helix}-O${offset}-${substrand.forward ? 'forward' : 'reverse'}';

String id_deletion(BoundSubstrand substrand, int offset) =>
    'deletion-H${substrand.helix}-O${offset}-${substrand.forward ? 'forward' : 'reverse'}';

Map<Type, List> split_list_selectable_by_type(List<Selectable> selected) {
  Map<Type, List> selected_all = {Crossover: [], Loopout: [], DNAEnd: [], Strand: []};
  for (var selectable in selected) {
    selected_all[selectable.runtimeType].add(selectable);
  }
  return selected_all;
}

num to_degrees(num radians) => radians * 360 / (2 * pi);

num to_radians(num degrees) => degrees * 2 * pi / 360;

num rotation_between_helices(BuiltList<Helix> helices, actions.HelixRotationSetAtOther action) {
  Helix helix = helices[action.helix_idx];
  Helix helix_other = helices[action.helix_other_idx];

  num rotation = helix.angle_to(helix_other);
  if (!action.forward) {
    rotation = (rotation - 150) % 360;
  }

  return rotation;
}

List<int> identity_permutation(int length) => [for (int i = 0; i < length; i++) i];

/// Return offset and direction on helix where click event occurred.
Address get_address_on_helix(MouseEvent event, Helix helix) {
  var svg_coord = svg_position_of_mouse_click(event);
  int offset = helix.svg_x_to_offset(svg_coord.x);
  bool forward = helix.svg_y_is_forward(svg_coord.y);
  return Address(helix_idx: helix.idx, offset: offset, forward: forward);
}

String remove_whitespace_and_uppercase(String string) {
  var string_no_spaces = string.replaceAll(RegExp(r'\s+'), '');
  return string_no_spaces.toUpperCase();
}

/// Return [sequence] modified to have length [length].
/// If [sequence.length] < [length], pad with [constants.DNA_BASE_WILDCARD].
/// If [sequence.length] > [length], remove extra symbols.
String pad_dna(String sequence, int length) {
  if (sequence.length > length) {
    sequence = sequence.substring(0, length);
  } else if (sequence.length < length) {
    sequence += constants.DNA_BASE_WILDCARD * (length - sequence.length);
  }
  return sequence;
}

/// Takes a "union" of two equal-length strings [s1] and [s2].
/// Whenever one has a symbol [wildcard] and the other does not, the result has the non-wildcard symbol.
/// Throws [ArgumentError] if [s1] and [s2] are not the same length or do not agree on non-wildcard
/// symbols at any position.
String merge_wildcards(String s1, String s2, String wildcard) {
  if (s1.length != s2.length) {
    throw ArgumentError('\ns1=${s1} and\ns2=${s2}\nare not the same length.');
  }
  List<String> union_builder = [];
  for (int i = 0; i < s1.length; i++) {
    String c1 = s1[i];
    String c2 = s2[i];
    if (c1 == wildcard) {
      union_builder.add(c2);
    } else if (c2 == wildcard) {
      union_builder.add(c1);
    } else if (c1 != c2) {
      throw ArgumentError('s1=${s1} and s2=${s2} have unequal symbols ${c1} and ${c2} at position ${i}.');
    } else if (c1 == c2) {
      union_builder.add(c1); // doesn't matter which we pick in this case
    } else {
      throw AssertionError('should be unreachable');
    }
  }
  return union_builder.join('');
}

/// Takes a "union" of two equal-length strings [s1] and [s2].
/// Whenever one has a symbol [wildcard] and the other does not, the result has the non-wildcard symbol.
/// Throws [ArgumentError] if [s1] and [s2] are not the same length or do not agree on non-wildcard
/// symbols at any position.
String merge_wildcards_favor_first(String s1, String s2, String wildcard) {
  if (s1.length != s2.length) {
    throw ArgumentError('\ns1=${s1} and\ns2=${s2}\nare not the same length.');
  }
  List<String> union_builder = [];
  for (int i = 0; i < s1.length; i++) {
    String c1 = s1[i];
    String c2 = s2[i];
    if (c1 == wildcard) {
      union_builder.add(c2);
    } else if (c2 == wildcard) {
      union_builder.add(c1);
    } else {
      union_builder.add(c1);
    }
  }
  return union_builder.join('');
}

/// Ensure is a valid DNA sequence.
/// Throw [FormatException] if it contains symbols other than base symbols a c g t A C G T and whitespace,
/// and if it does not have at least one base symbol.
check_dna_sequence(String seq) {
  var seq_no_spaces = seq.replaceAll(RegExp(r'\s+'), '');
  if (seq_no_spaces.isEmpty) {
    throw FormatException('"${seq}" is not a valid DNA sequence; it cannot be empty');
  }
  RegExp regex = RegExp(r'^(a|c|g|t|A|C|G|T)+$');
  if (regex.hasMatch(seq_no_spaces)) {
    return true;
  } else {
    String counter_example;
    for (int i = 0; i < seq_no_spaces.length; i++) {
      counter_example = seq_no_spaces[i];
      if (counter_example != 'A' &&
          counter_example != 'C' &&
          counter_example != 'G' &&
          counter_example != 'T' &&
          counter_example != 'a' &&
          counter_example != 'c' &&
          counter_example != 'g' &&
          counter_example != 't') {
        break;
      }
    }
    String seq_with_newlines = with_newlines(seq, 100);
    throw FormatException(r'<pre>' +
        seq_with_newlines +
        r'</pre>' +
        'is not a valid DNA sequence; it can only contain the symbols a c g t A C G T '
            'but it contains the symbol ${counter_example}');
  }
}

/// Puts newline symbols every [width] offsets into [string].
String with_newlines(String string, int width) {
  List<String> lines = [];
  for (int i = 0; i < string.length; i += width) {
    String line = string.substring(i, min(i + width, string.length));
    lines.add(line);
  }
  return lines.join('\n');
}

/// Return reverse Watson-Crick complement of seq. (leave non-base symbols alone)
String wc(String seq) => seq.split('').reversed.map((base) => wc_base(base)).join('');

String wc_base(String base) {
  switch (base) {
    case 'A':
      return 'T';
    case 'a':
      return 't';
    case 'C':
      return 'G';
    case 'C':
      return 'g';
    case 'G':
      return 'C';
    case 'g':
      return 'c';
    case 'T':
      return 'A';
    case 't':
      return 'a';
  }
  return base;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// intersection geometry

class Box {
  num height;
  num width;
  num x;
  num y;

  factory Box.from(Rect svg_rect) =>
      Box(svg_rect.x, svg_rect.y, width: svg_rect.width, height: svg_rect.height);

  factory Box.from_selection_box(SelectionBox box) => Box(box.x, box.y, width: box.width, height: box.height);

  Box(this.x, this.y, {num height = null, num width = null, num x2 = null, num y2 = null}) {
    if (width == null && x2 == null) {
      throw ArgumentError('at least one of height or x2 must be non-null');
    } else if (x2 == null) {
      this.width = width;
    } else if (width == null) {
      this.width = x2 - x;
    }

    if (height == null && y2 == null) {
      throw ArgumentError('at least one of height or x2 must be non-null');
    } else if (y2 == null) {
      this.height = height;
    } else if (height == null) {
      this.height = y2 - y;
    }
  }

  num get x2 => x + width;

  num get y2 => y + height;

  set x2(num x2new) {
    width = x2new - x;
  }

  set y2(num y2new) {
    height = y2new - y;
  }
}

// gets list of elements associated to Selectables that intersect select_box_bbox
List<E> intersection_list<E>(List<E> elts, List<Box> bboxes, Box select_box) =>
    generalized_intersection_list(elts, bboxes, select_box, intervals_overlap);

// gets list of elements associated to Selectables that intersect select_box_bbox
List<E> enclosure_list<E>(List<E> elts, List<Box> bboxes, Box select_box) =>
    generalized_intersection_list(elts, bboxes, select_box, interval_contained);

// indicates if (l1,h1) intersect (l2,h2) \neq empty
bool intervals_overlap(num l1, num h1, num l2, num h2) {
  return h1 >= l2 && h2 >= l1;
}

// indicates if (l1,h1) \subseteq (l2,h2)
bool interval_contained(num l1, num h1, num l2, num h2) {
  return l1 >= l2 && h1 <= h2;
}

List<E> generalized_intersection_list<E>(
    List<E> elts, List<Box> bboxes, Box select_box, bool overlap(num l1, num h1, num l2, num h2)) {
  if (elts.length != bboxes.length) {
    throw ArgumentError(
        'elts (length ${elts.length}) and bboxes (length ${bboxes.length}) must have same length');
  }
  List<E> elts_intersecting = [];
  for (int i = 0; i < elts.length; i++) {
    Box elt_bbox = bboxes[i];
    E elt = elts[i];
    if (boxes_intersect_generalized(elt_bbox, select_box, overlap)) {
      elts_intersecting.add(elt);
    }
  }
  return elts_intersecting;
}

bool boxes_intersect_generalized(Box elt_bbox, Box select_box, bool overlap(num l1, num h1, num l2, num h2)) {
  num elt_x2 = elt_bbox.x + elt_bbox.width;
  num select_box_x2 = select_box.x + select_box.width;
  num elt_y2 = elt_bbox.y + elt_bbox.height;
  num select_box_y2 = select_box.y + select_box.height;
  return overlap(elt_bbox.x, elt_x2, select_box.x, select_box_x2) &&
      overlap(elt_bbox.y, elt_y2, select_box.y, select_box_y2);
}

// gets list of elements associated to Selectables that intersect select_box_bbox in elements with classname
List<SvgElement> intersection_list_in_elt(String classname, Rect select_box_bbox) {
  return generalized_intersection_list_in_elt(classname, select_box_bbox, intervals_overlap);
}

// gets list of elements associated to Selectables that intersect select_box_bbox in elements with classname
List<SvgElement> enclosure_list_in_elt(String classname, Rect select_box_bbox) {
  return generalized_intersection_list_in_elt(classname, select_box_bbox, interval_contained);
}

generalized_intersection_list_in_elt(
    String classname, Rect select_box_bbox, bool overlap(num l1, num h1, num l2, num h2)) {
  List<SvgElement> elts_intersecting = [];
  List<Element> selectable_elts = querySelectorAll('.selectable');
  for (GraphicsElement elt in selectable_elts) {
    Rect elt_bbox = elt.getBBox();
//    util.transform_rect_svg_to_mouse_coord_main_view(elt_bbox);
    if (bboxes_intersect_generalized(elt_bbox, select_box_bbox, overlap)) {
      elts_intersecting.add(elt);
    }
  }
  return elts_intersecting;
}

bool bboxes_intersect_generalized(
    Rect elt_bbox, Rect select_box_bbox, bool overlap(num l1, num h1, num l2, num h2)) {
  num elt_x2 = elt_bbox.x + elt_bbox.width;
  num select_box_x2 = select_box_bbox.x + select_box_bbox.width;
  num elt_y2 = elt_bbox.y + elt_bbox.height;
  num select_box_y2 = select_box_bbox.y + select_box_bbox.height;
  return overlap(elt_bbox.x, elt_x2, select_box_bbox.x, select_box_x2) &&
      overlap(elt_bbox.y, elt_y2, select_box_bbox.y, select_box_y2);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// unit testing utilities

/// Returns the default state of the app.
AppState default_state() {
  var dna_design = DNADesign();
  var ui_state = AppUIState.from_dna_design(dna_design);
  var state = (DEFAULT_AppStateBuilder
        ..dna_design.replace(dna_design)
        ..ui_state.replace(ui_state)
        ..editor_content = '')
      .build();
  return state;
}
