import 'package:over_react/over_react.dart';
import 'package:built_collection/built_collection.dart';

import 'design_main_mouseover_rect_helix.dart';
import '../state/helix.dart';

part 'design_main_mouseover_rect_helices.over_react.g.dart';

const _ID = 'mouseover-rectangle-main-view';
const _CLASS = 'mouseover-rectangle-main-view';

@Factory()
UiFactory<DesignMainMouseoverRectHelicesProps> DesignMainMouseoverRectHelices =
    _$DesignMainMouseoverRectHelices;

@Props()
class _$DesignMainMouseoverRectHelicesProps extends UiProps { // FluxUiProps<HelicesStore, HelicesStore> {
  BuiltMap<int, Helix> helices;
}

@Component2()
class DesignMainMouseoverRectHelicesComponent extends UiComponent2<DesignMainMouseoverRectHelicesProps> { // FluxUiComponent<DesignMainMouseoverRectHelicesProps> {

  @override
  render() {
    return (Dom.g()
      ..id = _ID
      ..className = _CLASS)([
      for (Helix helix in props.helices.values)
//        (DesignMainMouseoverRectHelix()
        (ConnectedDesignMainMouseoverRectHelix()
          ..helix_idx = helix.idx
          ..key = helix.idx)()
    ]);
  }
}


