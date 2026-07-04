import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Isolates the exact Riverpod AsyncNotifier hazard that VideoStudioController
// .setInput's `await future;` guards against (see the comment on setInput in
// video_studio_controller.dart). VideoStudioController can't be used directly
// here: its build() calls FontRegistry.ensureLoaded(), whose real duration
// depends on platform asset/font IO that a test harness can't reliably slow
// down or speed up — so a test built on it would pass or fail by timing
// accident rather than by the guard actually being present. This harness
// gates build() with a Completer under direct test control instead, so the
// race and its fix are deterministic.

class _RaceState {
  const _RaceState(this.value);
  final String value;
}

class _UnguardedNotifier extends AsyncNotifier<_RaceState> {
  static const _default = _RaceState('default');
  static Completer<void>? buildGate;

  @override
  Future<_RaceState> build() async {
    await buildGate?.future;
    return _default;
  }

  void setValue(String v) {
    state = AsyncData(_RaceState(v));
  }
}

class _GuardedNotifier extends AsyncNotifier<_RaceState> {
  static const _default = _RaceState('default');
  static Completer<void>? buildGate;

  @override
  Future<_RaceState> build() async {
    await buildGate?.future;
    return _default;
  }

  // Mirrors VideoStudioController.setInput's fix: wait for the initial
  // build() to have already landed before mutating state, so a build() that
  // resolves later can never unconditionally overwrite this call's result.
  Future<void> setValue(String v) async {
    await future;
    state = AsyncData(_RaceState(v));
  }
}

void main() {
  final unguarded =
      AsyncNotifierProvider<_UnguardedNotifier, _RaceState>(_UnguardedNotifier.new);
  final guarded =
      AsyncNotifierProvider<_GuardedNotifier, _RaceState>(_GuardedNotifier.new);

  test(
      'without the future-await guard, a build() that resolves late clobbers '
      'a value set while it was pending', () async {
    _UnguardedNotifier.buildGate = Completer<void>();
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // Starts build() (pending on buildGate) without waiting for it — mirrors
    // VideoStudioScreen reading the provider and calling setInput() the very
    // next frame.
    final notifier = c.read(unguarded.notifier);
    notifier.setValue('user-loaded-file');
    expect(c.read(unguarded).valueOrNull?.value, equals('user-loaded-file'));

    // build() finally resolves — its stale default return value overwrites
    // the value set above, reproducing the "loads, flashes, then reverts"
    // symptom.
    _UnguardedNotifier.buildGate!.complete();
    await c.read(unguarded.future);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(unguarded).valueOrNull?.value, equals('default'));
  });

  test('with the future-await guard, a late-resolving build() cannot clobber '
      'a value set after the guard', () async {
    _GuardedNotifier.buildGate = Completer<void>();
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final notifier = c.read(guarded.notifier);
    // Fire-and-forget, same as the real caller: setValue awaits `future`
    // internally before assigning, so at this point it's still parked —
    // state is whatever build() left it as (loading, since the gate isn't
    // complete yet), not yet the new value.
    unawaited(notifier.setValue('user-loaded-file'));
    expect(c.read(guarded).isLoading, isTrue);

    _GuardedNotifier.buildGate!.complete();
    await c.read(guarded.future);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(guarded).valueOrNull?.value, equals('user-loaded-file'));
  });
}
