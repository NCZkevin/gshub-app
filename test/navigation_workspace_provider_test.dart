import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/navigation/presentation/navigation_provider.dart';
import 'package:sysapp/features/navigation/presentation/navigation_workspace_provider.dart';
import 'package:sysapp/shared/widgets/occupancy_map.dart';

void main() {
  test('path and record drafts remain independent across mode changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = container.read(navigationDraftProvider.notifier);
    final workspace = container.read(navigationWorkspaceProvider.notifier);

    workspace.setMode(NavMode.path);
    draft.addPathWaypoint(const MapSelection(x: 1, y: 2));
    workspace.setMode(NavMode.record);
    draft.addRecordWaypoint(const MapSelection(x: 8, y: 9));
    workspace.setMode(NavMode.path);

    final state = container.read(navigationDraftProvider);
    expect(state.pathWaypoints, hasLength(1));
    expect(state.pathWaypoints.single.x, 1);
    expect(state.recordWaypoints, hasLength(1));
    expect(state.recordWaypoints.single.x, 8);
  });

  test(
    'map interaction must be explicitly entered and mission collapse exits it',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final workspace = container.read(navigationWorkspaceProvider.notifier);

      expect(
        container.read(navigationWorkspaceProvider).interactionMode,
        MapInteractionMode.browse,
      );

      workspace.setMode(NavMode.relocalize);
      workspace.beginMapInteraction();
      expect(
        container.read(navigationWorkspaceProvider).interactionMode,
        MapInteractionMode.pickRelocalization,
      );

      workspace.collapseForMission();
      final collapsed = container.read(navigationWorkspaceProvider);
      expect(collapsed.interactionMode, MapInteractionMode.browse);
      expect(collapsed.sheetLevel, NavigationSheetLevel.summary);
      expect(collapsed.sheetExtent, 0.16);
    },
  );

  test('clearing one draft does not clear other task drafts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = container.read(navigationDraftProvider.notifier);

    draft.setSingleGoal(const MapSelection(x: 2, y: 3));
    draft.addPathWaypoint(const MapSelection(x: 4, y: 5));
    draft.addRecordWaypoint(const MapSelection(x: 6, y: 7));
    draft.clearPath();

    final state = container.read(navigationDraftProvider);
    expect(state.singleGoal, isNotNull);
    expect(state.pathWaypoints, isEmpty);
    expect(state.recordWaypoints, hasLength(1));
  });
}
