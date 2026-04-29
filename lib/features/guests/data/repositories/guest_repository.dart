import 'package:hive_flutter/hive_flutter.dart';
import '../models/guest_model.dart';

class GuestRepository {
  static const String _boxName = "guests";

  Box<GuestModel>? _box;

  // ------------------------------------------------------------
  // 🔓 GET BOX (SAFE OPEN)
  // ------------------------------------------------------------
  Future<Box<GuestModel>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<GuestModel>(_boxName);
    return _box!;
  }

  // ------------------------------------------------------------
  // 📥 GET ALL
  // ------------------------------------------------------------
  Future<List<GuestModel>> getAll() async {
    final box = await _getBox();
    return box.values.toList();
  }

  // ------------------------------------------------------------
  // 🔄 WATCH (REAL-TIME UI UPDATE)
  // ------------------------------------------------------------
  Stream<List<GuestModel>> watchGuests() async* {
    final box = await _getBox();

    // initial data
    yield box.values.toList();

    // listen for changes
    await for (final _ in box.watch()) {
      yield box.values.toList();
    }
  }

  // ------------------------------------------------------------
  // ➕ ADD SINGLE
  // ------------------------------------------------------------
  Future<bool> add(GuestModel guest) async {
    final box = await _getBox();

    // ❗ Prevent duplicate phone
    final exists = box.values.any((g) => g.phone == guest.phone);
    if (exists) return false;

    await box.put(guest.id, guest);
    return true;
  }

  // ------------------------------------------------------------
  // ➕ ADD BULK (IMPORT)
  // ------------------------------------------------------------
  Future<List<GuestModel>> addAll(List<GuestModel> guests) async {
    final box = await _getBox();

    final List<GuestModel> duplicates = [];

    for (var guest in guests) {
      final exists = box.values.any((g) => g.phone == guest.phone);

      if (exists) {
        duplicates.add(guest); // collect duplicates
      } else {
        await box.put(guest.id, guest);
      }
    }

    return duplicates; // UI can show warning
  }

  // ------------------------------------------------------------
  // ✏️ UPDATE
  // ------------------------------------------------------------
  Future<void> update(GuestModel guest) async {
    final box = await _getBox();
    await box.put(guest.id, guest);
  }

  // ------------------------------------------------------------
  // ❌ DELETE SINGLE
  // ------------------------------------------------------------
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  // ------------------------------------------------------------
  // ❌ DELETE MULTIPLE
  // ------------------------------------------------------------
  Future<void> deleteMany(List<String> ids) async {
    final box = await _getBox();
    await box.deleteAll(ids);
  }

  // ------------------------------------------------------------
  // 🔍 SEARCH (Name / Phone)
  // ------------------------------------------------------------
  Future<List<GuestModel>> search(String query) async {
    final box = await _getBox();
    final q = query.toLowerCase();

    return box.values.where((g) {
      return g.name.toLowerCase().contains(q) || g.phone.contains(q);
    }).toList();
  }

  // ------------------------------------------------------------
  // 🎯 FILTER
  // ------------------------------------------------------------
  Future<List<GuestModel>> filter({
    FamilySide? side,
    RsvpStatus? rsvp,
  }) async {
    final box = await _getBox();

    return box.values.where((g) {
      final matchSide = side == null || g.familySide == side;
      final matchRsvp = rsvp == null || g.rsvpStatus == rsvp;

      return matchSide && matchRsvp;
    }).toList();
  }

  // ------------------------------------------------------------
  // 📊 COUNT
  // ------------------------------------------------------------
  Future<int> count() async {
    final box = await _getBox();
    return box.length;
  }

  // ------------------------------------------------------------
  // 🧹 CLEAR ALL
  // ------------------------------------------------------------
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
  }
}
