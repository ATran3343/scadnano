import 'dart:html_common';

import 'package:scadnano/src/dispatcher/actions.dart';
import 'package:scadnano/src/model/dna_design.dart';
import 'package:scadnano/src/model/model.dart';
import 'package:scadnano/src/model/strand_ui_model.dart';
import 'package:w_flux/w_flux.dart';

import 'strand.dart';
import 'model_ui.dart';

/// These are stores that reference other stores, notifying their listeners when any of those Stores update.
/// They have no Actions that mutate them directly, and only serve as "funnels" for notification.
/// Useful for parts of the view that listen to parts of the Model that are disparate in the Model tree.
_subscribe_to_stores(Store composite_store, Iterable<Store> stores) {
  for (var store in stores) {
    store.listen((_) => composite_store.trigger());
  }
  convertNativePromiseToDartFuture;
}

class DNASequencesStore extends Store {
  final StrandsStore strands_store;
  final ShowDNAStore show_dna_store;

  DNASequencesStore(this.strands_store, this.show_dna_store) {
    _subscribe_to_stores(this, [this.strands_store, this.show_dna_store]);
  }
}

class MismatchesStore extends Store {
  final StrandsStore strands_store;
  final ShowMismatchesStore show_mismatches_store;

  MismatchesStore(this.strands_store, this.show_mismatches_store) {
    _subscribe_to_stores(this, [this.strands_store, this.show_mismatches_store]);
  }
}

/// Contains data about whether to show various things in Main view (DNA, mismatches, editor)
class ShowStore extends Store {
  final ShowDNAStore show_dna_store;
  final ShowMismatchesStore show_mismatches_store;
  final ShowEditorStore show_editor_store;

  ShowStore(this.show_dna_store, this.show_mismatches_store, this.show_editor_store) {
    _subscribe_to_stores(this, [this.show_dna_store, this.show_mismatches_store, this.show_editor_store]);
  }
}

// Fires when either Design or ErrorMessage updates so Design view knows to redraw.
class DesignOrErrorStore extends Store {
  DNADesign dna_design;
  ErrorMessageStore error_message_store;

  DesignOrErrorStore(this.dna_design, this.error_message_store) {
    _subscribe_to_stores(this, [this.dna_design, this.error_message_store]);
  }
}


// Crossover components listen to this on the BoundSubstrands on either end of them.
class TwoBoundSubstrandsStore extends Store {
  BoundSubstrand prev_substrand;
  BoundSubstrand next_substrand;
  CrossoverUIModel crossover_ui_model;

  TwoBoundSubstrandsStore(this.prev_substrand, this.next_substrand, this.crossover_ui_model) {
    _subscribe_to_stores(this, [this.prev_substrand, this.next_substrand]);
    Actions.crossover_select_toggle.listen((pair) {
      if (identical(pair.item1, prev_substrand) && identical(pair.item2, next_substrand)) {
        crossover_ui_model.selected = !crossover_ui_model.selected;
        this.trigger();
      }
    });
  }
}


