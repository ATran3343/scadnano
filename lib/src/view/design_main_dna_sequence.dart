import 'dart:html';
import 'dart:math';

import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:built_collection/built_collection.dart';
import 'package:platform_detect/platform_detect.dart';
import 'package:tuple/tuple.dart';

import '../state/app_state.dart';
import '../app.dart';
import '../state/strand.dart';
import '../state/bound_substrand.dart';
import '../state/loopout.dart';
import '../constants.dart' as constants;
import '../util.dart' as util;
import 'pure_component.dart';

part 'design_main_dna_sequence.over_react.g.dart';

//UiFactory<_$DesignMainDNASequenceProps> ConnectedDesignMainDNASequence =
//    connect<AppState, DesignMainDNASequenceProps>(
//  mapStateToProps: (state) =>
//      (DesignMainDNASequence()..side_selected_helix_idxs = state.ui_state.side_selected_helix_idxs),
//)(DesignMainDNASequence);

@Factory()
UiFactory<DesignMainDNASequenceProps> DesignMainDNASequence = _$DesignMainDNASequence;

@Props()
class _$DesignMainDNASequenceProps extends UiProps {
  Strand strand;
  BuiltSet<int> side_selected_helix_idxs;
}

bool should_draw_bound_ss(BoundSubstrand ss, BuiltSet<int> side_selected_helix_idxs) =>
    side_selected_helix_idxs.isEmpty || side_selected_helix_idxs.contains(ss.helix);

@Component2()
class DesignMainDNASequenceComponent extends UiComponent2<DesignMainDNASequenceProps> with PureComponent {

  @override
  render() {
    BuiltSet<int> side_selected_helix_idxs = props.side_selected_helix_idxs;

    List<ReactElement> dna_sequence_elts = [];
    for (int i = 0; i < this.props.strand.substrands.length; i++) {
      var substrand = this.props.strand.substrands[i];
      if (substrand.is_bound_substrand()) {
        if (should_draw_bound_ss(substrand, side_selected_helix_idxs)) {
          var bound_ss = substrand as BoundSubstrand;
          dna_sequence_elts.add(this._dna_sequence_on_bound_substrand(bound_ss));
          for (var insertion in bound_ss.insertions) {
            int offset = insertion.offset;
            int length = insertion.length;
            dna_sequence_elts.add(this._dna_sequence_on_insertion(bound_ss, offset, length));
          }
        }
      } else {
        assert(0 < i);
        assert(i < this.props.strand.substrands.length - 1);
        var loopout = substrand as Loopout;
        BoundSubstrand prev_ss = this.props.strand.substrands[i - 1];
        BoundSubstrand next_ss = this.props.strand.substrands[i + 1];
        if (should_draw_bound_ss(prev_ss, side_selected_helix_idxs) &&
            should_draw_bound_ss(next_ss, side_selected_helix_idxs)) {
          dna_sequence_elts.add(this._dna_sequence_on_loopout(loopout, prev_ss, next_ss));
        }
      }
    }
    return (Dom.g()..className = 'strand-dna-sequence')(dna_sequence_elts);
  }

  static const classname_dna_sequence = 'dna-seq';

  ReactElement _dna_sequence_on_bound_substrand(BoundSubstrand substrand) {
    var seq_to_draw = substrand.dna_sequence_deletions_insertions_to_spaces();

    var rotate_degrees = 0;
    int offset = substrand.offset_5p;
    var helix = app.state.dna_design.helices[substrand.helix];
    Point<num> pos = helix.svg_base_pos(offset, substrand.forward);
    var rotate_x = pos.x;
    var rotate_y = pos.y;

    // this is needed to make complementary DNA bases line up more nicely (still not perfect)
    var x_adjust = -constants.BASE_WIDTH_SVG * 0.32;
    if (!substrand.forward) {
      rotate_degrees = 180;
    }
    var dy = -constants.BASE_HEIGHT_SVG * 0.25;
    var text_length = constants.BASE_WIDTH_SVG * (substrand.visual_length - 0.342);
    var id = 'dna-bound-substrand-H${substrand.helix}-S${substrand.start}-E${substrand.end}-'
        '${substrand.forward ? 'forward' : 'reverse'}';

    return (Dom.text()
//      ..onMouseLeave = ((_) => mouse_leave_update_mouseover())
//      ..onMouseMove = ((event) => update_mouseover(event, helix))
      ..key = id
      ..id = id
      ..className = classname_dna_sequence
      ..x = '${pos.x + x_adjust}'
      ..y = '${pos.y}'
      ..textLength = '$text_length'
      ..transform = 'rotate(${rotate_degrees} ${rotate_x} ${rotate_y})'
      ..dy = '$dy')(seq_to_draw);
  }

  ReactElement _dna_sequence_on_insertion(BoundSubstrand substrand, int offset, int length) {
    var subseq = substrand.dna_sequence_in(offset, offset);
    //XXX: path_length appears to return different results depending on the computer (probably resolution??)
    // don't rely on it. This caused Firefox for example to render different on the same version.
//    num path_length = insertion_path_elt.getTotalLength();

    var start_offset = '50%';
    var dy = '${0.1 * constants.BASE_WIDTH_SVG}';

    Tuple2<num, num> ls_fs = _calculate_letter_spacing_and_font_size_insertion(length);
    num letter_spacing = ls_fs.item1;
    num font_size = ls_fs.item2;

    Map<String, dynamic> style_map;
    if (letter_spacing != null) {
      style_map = {'letterSpacing': '${letter_spacing}em', 'fontSize': '${font_size}px'};
    } else {
      style_map = {'fontSize': '${font_size}px'};
    }

    SvgProps text_path_props = (Dom.textPath()
      ..className = classname_dna_sequence + '-insertion'
      ..href = '#${util.id_insertion(substrand, offset)}'
      ..startOffset = start_offset
      ..style = style_map);
    return (Dom.text()
      ..key = 'textelt-${util.id_insertion(substrand, offset)}'
      ..dy = dy)(text_path_props(subseq));
  }

  ReactElement _dna_sequence_on_loopout(Loopout loopout, BoundSubstrand prev_ss, BoundSubstrand next_ss) {
    var subseq = loopout.dna_sequence;
    var length = subseq.length;

    var start_offset = '50%';
    var dy = '${0.1 * constants.BASE_WIDTH_SVG}';

    Tuple2<num, num> ls_fs;
    if (util.is_hairpin(prev_ss, next_ss)) {
      ls_fs = _calculate_letter_spacing_and_font_size_hairpin(length);
    } else {
      ls_fs = _calculate_letter_spacing_and_font_size_loopout(length);
    }
    num letter_spacing = ls_fs.item1;
    num font_size = ls_fs.item2;

    Map<String, dynamic> style_map;
    if (letter_spacing != null) {
      style_map = {'letterSpacing': '${letter_spacing}em', 'fontSize': '${font_size}px'};
    } else {
      style_map = {'fontSize': '${font_size}px'};
    }

    SvgProps text_path_props = (Dom.textPath()
      ..className = classname_dna_sequence + '-loopout'
      ..href = '#${loopout.id()}'
      ..startOffset = start_offset
      ..style = style_map);
    return (Dom.text()
      ..key = 'loopout-text-'
          'H${prev_ss.helix},${prev_ss.offset_3p}-'
          'H${next_ss.helix},${next_ss.offset_5p}'
      ..dy = dy)(text_path_props(subseq));
  }
}

Tuple2<num, num> _calculate_letter_spacing_and_font_size_loopout(int len) {
  num letter_spacing = 0;
  num font_size = 12;
  return Tuple2<num, num>(letter_spacing, font_size);
}

Tuple2<num, num> _calculate_letter_spacing_and_font_size_hairpin(int len) {
  num letter_spacing;
  num font_size = max(6, 12 - max(0, len - 6));
  if (browser.isChrome) {
    if (len == 1) {
      letter_spacing = 0;
    } else if (len == 2) {
      letter_spacing = -0.1;
    } else if (len == 3) {
      letter_spacing = -0.1;
    } else if (len == 4) {
      letter_spacing = -0.1;
    } else if (len == 5) {
      letter_spacing = -0.15;
    } else if (len == 6) {
      letter_spacing = -0.18;
    } else {
      letter_spacing = null;
    }
  }
  if (browser.isFirefox) {
    // Firefox ignores the "letter-spacing" property so we only have font-size to play with
    font_size = max(6, 12 - (len - 1));
    if (len > 3 && font_size > 6) {
      font_size -= 1;
    }
    letter_spacing = null;
  }
  return Tuple2<num, num>(letter_spacing, font_size);
}

Tuple2<num, num> _calculate_letter_spacing_and_font_size_insertion(int num_insertions) {
  // UGGG
  num letter_spacing;
  num font_size = max(6, 12 - (num_insertions - 1));
  if (browser.isChrome) {
    if (num_insertions == 1) {
      letter_spacing = 0;
    } else if (num_insertions == 2) {
      letter_spacing = -0.1;
    } else if (num_insertions == 3) {
      letter_spacing = -0.1;
    } else if (num_insertions == 4) {
      letter_spacing = -0.1;
    } else if (num_insertions == 5) {
      letter_spacing = -0.15;
    } else if (num_insertions == 6) {
      letter_spacing = -0.18;
    } else {
      letter_spacing = null;
    }
  }
  if (browser.isFirefox) {
    // Firefox ignores the "letter-spacing" property so we only have font-size to play with
    font_size = max(6, 12 - (num_insertions - 1));
    if (num_insertions > 3 && font_size > 6) {
      font_size -= 1;
    }
    letter_spacing = null;
  }
  return Tuple2<num, num>(letter_spacing, font_size);
}

// keep this around in case this is how we want to export to an SVG file and it doesn't do textLength well
//  draw_dna_sequence_old(Substrand substrand) {
//    var seq_group = svg.GElement();
//    seq_group.attributes = {'class': 'dna-subsequence'};
//    element.children.add(seq_group);
//    String dna_sequence = substrand.dna_sequence();
//    for (int i = 0; i < substrand.dna_length && i < dna_sequence.length; i++) {
//      String base = dna_sequence[i];
//      var base_elt = svg.TextElement();
//      base_elt.innerHtml = base;
//      var offset_from_start = i;
//      var rotate_degrees = 0;
//      if (substrand.direction == Direction.left) {
//        offset_from_start = -i;
//      }
//      int offset = substrand.offset_5p + offset_from_start;
//      Point<num> pos = Helix.svg_base_pos(substrand.helix_idx, offset, substrand.direction);
//      var rotate_x = pos.x;
//      var rotate_y = pos.y;
//      if (substrand.direction == Direction.left) {
//        rotate_degrees = 180;
//      }
//      var dy = '0.75px';
//      if (browser.isFirefox) {
//        dy = '0px';
//      }
//      base_elt.attributes = {
//        'class': 'dna-base',
//        'x': '${pos.x}',
//        'y': '${pos.y}',
//        'transform': 'rotate(${rotate_degrees} ${rotate_x} ${rotate_y})',
//        'dy': dy,
//      };
//      seq_group.children.add(base_elt);
//    }
//  }
