import '../actions/actions_OLD.dart';
import 'helix.dart';

class SideViewSelection {
  List<Helix> helices = [];
}

class SideViewUIModel {
  SideViewSelection selection = SideViewSelection();
//  SideViewMousePositionStore side_view_mouse_position_store = SideViewMousePositionStore();
}

//class SideViewMousePositionStore extends Store {
//  Point<num> pos = null;
//
//  SideViewMousePositionStore() {
//    //FIXME: implement these
//    this.triggerOnActionV2(Actions.update_side_view_mouse_position, (point) {
//      this.pos = point;
//    });
//    this.triggerOnActionV2(Actions.remove_side_view_mouse_position, (_) {
//      this.pos = null;
//    });
//  }
//}