import 'dart:html';

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../serializers.dart';
import '../app.dart';
import '../actions/actions.dart' as actions;
import 'crossover.dart';
import 'dna_end.dart';
import 'select_mode.dart';
import 'strand.dart';

part 'selectable.g.dart';

final DEFAULT_SelectablesStoreBuilder = SelectablesStoreBuilder()..selected_items.replace([]);

abstract class SelectablesStore
    with BuiltJsonSerializable
    implements Built<SelectablesStore, SelectablesStoreBuilder> {
  SelectablesStore._();

  factory SelectablesStore([void Function(SelectablesStoreBuilder) updates]) = _$SelectablesStore;

  static Serializer<SelectablesStore> get serializer => _$selectablesStoreSerializer;

  /************************ end BuiltValue boilerplate ************************/

  BuiltSet<Selectable> get selected_items;

  @memoized
  BuiltSet<Strand> get selected_strands => BuiltSet<Strand>.from(selected_items.where((s) => s is Strand));

  @memoized
  BuiltSet<Crossover> get selected_crossovers =>
      BuiltSet<Crossover>.from(selected_items.where((s) => s is Crossover));

  @memoized
  BuiltSet<DNAEnd> get selected_dna_ends => BuiltSet<DNAEnd>.from(selected_items.where((s) => s is DNAEnd));

  bool get isEmpty => selected_items.isEmpty;

  bool get isNotEmpty => selected_items.isNotEmpty;

  bool selected(Selectable selectable) => selected_items.contains(selectable);

  @memoized
  int get hashCode;

  /// adds [selectable] to selected items. If only=true, deselects all other items.
  SelectablesStore select(Selectable selectable, {bool only = false}) {
    var selected_items_builder = selected_items.toBuilder();
    if (only) {
      selected_items_builder.clear();
    }
    selected_items_builder.add(selectable);
    return rebuild((s) => s..selected_items = selected_items_builder);
  }

  /// removes [selectable] from selected items.
  SelectablesStore unselect(Selectable selectable) {
    var selected_items_builder = selected_items.toBuilder();
    selected_items_builder.remove(selectable);
    return rebuild((s) => s..selected_items = selected_items_builder);
  }

  /// removes all selectables from store
  SelectablesStore clear() {
    return rebuild((s) => s..selected_items = SetBuilder<Selectable>());
  }

  // methods below here defined in terms of select and unselect
  SelectablesStore select_all(Iterable<Selectable> selectables, {bool only = false}) {
    var selected_items_builder = selected_items.toBuilder();
    if (only) {
      selected_items_builder.clear();
    }
    selected_items_builder.addAll(selectables);
    return rebuild((s) => s..selected_items = selected_items_builder);
  }

  SelectablesStore toggle(Selectable selectable) {
    if (selected(selectable)) {
      return unselect(selectable);
    } else {
      return select(selectable);
    }
  }

  SelectablesStore toggle_all(Iterable<Selectable> selectables) {
    var selected_items_builder = selected_items.toBuilder();
    for (var selectable in selectables) {
      if (selected_items.contains(selectable)) {
        selected_items_builder.remove(selectable);
      } else {
        selected_items_builder.add(selectable);
      }
    }
    return rebuild((s) => s..selected_items = selected_items_builder);
  }
}

/// Represents a part of the Model that represents a part of the View that is Selectable.
mixin Selectable {
  /// Subclasses must define this to be used to associate view element to state object through CSS selector.
  String id();

  /// Subclasses must define this to be able to be selectively selected.
  SelectModeChoice select_mode();

  //XXX: Previously the type of event was SyntheticMouseEvent, but now we have a pointer event since
  // the Dart dnd library intercepts and prevent mouse events. Luckily that event has the
  // ctrlKey, metaKey, and shiftKey properties we need to check for.
//  handle_selection(react.SyntheticPointerEvent event) {
  handle_selection_mouse_down(MouseEvent event) {
    if (event.ctrlKey || event.metaKey) {
      app.dispatch(actions.Select(this, toggle: true));
    } else {
      // add to selection on mouse down
      app.dispatch(actions.Select(this, toggle: false));
    }
//    if (event.ctrlKey || event.metaKey) {
//      app.dispatch(actions.Select(this, toggle: true, only: false));
//    } else if (event.shiftKey) {
//      // add to selection on mouse down
//      app.dispatch(actions.Select(this, toggle: false, only: false));
//    } else {
//      app.dispatch(actions.Select(this, toggle: false, only: true));
//    }
  }

  // We choose to use the mouse up event to deselect other selections. Otherwise it is difficult to select
  // multiple items and then move them, because the click that attempts to move them is done without the
  // Shift or Ctrl key, so if we deselected whenever the user clicks without those keys, we would not be
  // able to move multiple items.
  handle_selection_mouse_up(MouseEvent event) {
    if (!(event.ctrlKey || event.metaKey || event.shiftKey)) {
      app.dispatch(actions.Select(this, toggle: false, only: true));
    }
  }
}
