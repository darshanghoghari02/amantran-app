import 'dart:async';
import 'package:flutter/material.dart';
import '../models/guest_model.dart';
import '../repositories/guest_repository.dart';
import '../services/firestore_service.dart';

class GuestProvider extends ChangeNotifier {
  final GuestRepository _guestRepository = GuestRepository();
  final List<GuestModel> _guests = [];

  StreamSubscription? _guestsSubscription;
  StreamSubscription? _authSubscription;

  List<GuestModel> get guests => List.unmodifiable(_guests);

  int get totalCount => _guests.length;
  int get pendingCount => _guests.where((g) => g.rsvpStatus == RsvpStatus.pending).length;
  int get sentCount => _guests.where((g) => g.rsvpStatus == RsvpStatus.sent).length;
  int get viewedCount => _guests.where((g) => g.rsvpStatus == RsvpStatus.viewed).length;

  GuestProvider() {
    _init();
  }

  void _init() {
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) {
      if (uid != null) {
        _subscribeToStreams();
      } else {
        _unsubscribeFromStreams();
        _guests.clear();
        notifyListeners();
      }
    });

    final initialUid = FirestoreService().resolvedUid;
    if (initialUid != null) {
      _subscribeToStreams();
    }
  }

  void _subscribeToStreams() {
    _unsubscribeFromStreams();

    _guestsSubscription = _guestRepository.watchGuests().listen((rawList) {
      _guests.clear();
      for (var item in rawList) {
        try {
          _guests.add(GuestModel.fromJson(item));
        } catch (e) {
          debugPrint("Failed to parse guest from Firestore: $e");
        }
      }
      notifyListeners();
    });
  }

  void _unsubscribeFromStreams() {
    _guestsSubscription?.cancel();
  }

  Future<void> addGuest(GuestModel guest) async {
    try {
      // Optimistic update
      _guests.add(guest);
      notifyListeners();

      await _guestRepository.saveGuest(guest.id, guest.toJson());
    } catch (e) {
      debugPrint("Failed to add guest: $e");
      _guests.removeWhere((g) => g.id == guest.id);
      notifyListeners();
    }
  }

  Future<void> addGuests(List<GuestModel> newGuests) async {
    try {
      final List<GuestModel> added = [];
      for (var guest in newGuests) {
        if (!_guests.any((g) => g.phone == guest.phone)) {
          _guests.add(guest);
          added.add(guest);
          await _guestRepository.saveGuest(guest.id, guest.toJson());
        }
      }
      if (added.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to add multiple guests: $e");
    }
  }

  Future<void> updateGuest(
    String id, {
    String? name,
    String? phone,
    String? note,
    RsvpStatus? rsvpStatus,
  }) async {
    final index = _guests.indexWhere((g) => g.id == id);
    if (index != -1) {
      final original = _guests[index];
      final updated = original.copyWith(
        name: name,
        phone: phone,
        note: note,
        rsvpStatus: rsvpStatus,
      );

      try {
        // Optimistic update
        _guests[index] = updated;
        notifyListeners();

        await _guestRepository.saveGuest(id, updated.toJson());
      } catch (e) {
        debugPrint("Failed to update guest: $e");
        _guests[index] = original;
        notifyListeners();
      }
    }
  }

  Future<void> deleteGuest(String id) async {
    final index = _guests.indexWhere((g) => g.id == id);
    if (index != -1) {
      final original = _guests[index];
      try {
        // Optimistic update
        _guests.removeAt(index);
        notifyListeners();

        await _guestRepository.deleteGuest(id);
      } catch (e) {
        debugPrint("Failed to delete guest: $e");
        _guests.insert(index, original);
        notifyListeners();
      }
    }
  }

  List<GuestModel> search(String query) {
    if (query.isEmpty) return _guests;
    final q = query.toLowerCase();
    return _guests.where((g) =>
      g.name.toLowerCase().contains(q) ||
      g.phone.contains(q)
    ).toList();
  }

  List<GuestModel> filterByStatus(RsvpStatus? status) {
    if (status == null) return _guests;
    return _guests.where((g) => g.rsvpStatus == status).toList();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromStreams();
    super.dispose();
  }
}
