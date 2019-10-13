import 'dart:async';
import 'dart:math';

import 'package:over_react/over_react.dart';
import 'package:w_flux/w_flux.dart';

import '../app.dart';
import '../dispatcher/actions.dart';

/// Represents a part of the Model that represents a part of the View that is Selectable.
mixin Selectable implements Store {
  /// Subclasses must define this to be used to associate view element to model object through CSS selector.
  String id();

  handle_selection(SyntheticMouseEvent event) {
    if (event.ctrlKey) {
      Actions.toggle(this);
    } else if (event.shiftKey) {
      Actions.select(this);
    }
  }

  bool selected() => app.model.dna_design.selectable_store.selected(this);

  String toString() => id();
}

class SelectableStore extends Store {
  final selectables_by_id = Map<String, Selectable>();

  final Set<Selectable> Function() selected_items_factory;

  Set<Selectable> get selected_items => selected_items_factory();

  SelectableStore(this.selected_items_factory);

  /// Registers unique ID of this Selectable so it can be reconciled with View component with same HTML id.
  register(Selectable selectable) {
    String id = selectable.id();
    selectables_by_id[id] = selectable;
  }

  bool selected(Selectable selectable) => selected_items.contains(selectable);

  select(Selectable selectable) {
    bool added = selected_items.add(selectable);
    if (added) {
      selectable.trigger();
    }
  }

  select_all(Iterable<Selectable> selectables) {
    for (var selectable in selectables) {
      select(selectable);
    }
  }

  unselect(Selectable selectable) {
    bool removed = selected_items.remove(selectable);
    if (removed) {
      selectable.trigger();
    }
  }

  toggle(Selectable selectable) {
    if (selected(selectable)) {
      unselect(selectable);
    } else {
      select(selectable);
    }
  }

  toggle_all(Iterable<Selectable> selectables) {
    for (var selectable in selectables) {
      toggle(selectable);
    }
  }

  clear() {
    List<Selectable> old_selected_items = selected_items.toList();
    selected_items.clear();
    for (var selectable in old_selected_items) {
      selectable.trigger();
    }
  }

  /// Set up selectable
  handle_actions() {
    triggerOnActionV2(Actions.select, (obj) => select(obj));
    triggerOnActionV2(Actions.select_all, (objs) => select_all(objs));
    triggerOnActionV2(Actions.unselect, (obj) => unselect(obj));
    triggerOnActionV2(Actions.toggle, (obj) => toggle(obj));
    triggerOnActionV2(Actions.toggle_all, (objs) => toggle_all(objs));
    triggerOnActionV2(Actions.remove_all_selections, (_) => clear());
  }
}
