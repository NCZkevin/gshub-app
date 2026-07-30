import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'machine_availability_provider.dart';

class MachineAvailabilityPill extends StatelessWidget {
  final MachineAvailabilityState availability;

  const MachineAvailabilityPill({super.key, required this.availability});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(availability.status);
    return StatusPill(
      label: presentation.label,
      color: presentation.color,
      icon: presentation.icon,
    );
  }
}

({String label, Color color, IconData icon}) _presentation(
  MachineAvailabilityStatus status,
) {
  return switch (status) {
    MachineAvailabilityStatus.noMachine => (
      label: '未选择',
      color: AppTheme.slate500,
      icon: Icons.devices_other_outlined,
    ),
    MachineAvailabilityStatus.checking => (
      label: '检测中',
      color: AppTheme.warning,
      icon: Icons.sync_rounded,
    ),
    MachineAvailabilityStatus.online => (
      label: '在线',
      color: AppTheme.success,
      icon: Icons.cloud_done_outlined,
    ),
    MachineAvailabilityStatus.reconnecting => (
      label: '重连中',
      color: AppTheme.warning,
      icon: Icons.cloud_sync_outlined,
    ),
    MachineAvailabilityStatus.offline => (
      label: '离线',
      color: AppTheme.danger,
      icon: Icons.cloud_off_outlined,
    ),
    MachineAvailabilityStatus.authorizationRequired => (
      label: '需授权',
      color: AppTheme.warning,
      icon: Icons.key_off_outlined,
    ),
    MachineAvailabilityStatus.identityMismatch => (
      label: '地址异常',
      color: AppTheme.danger,
      icon: Icons.wrong_location_outlined,
    ),
  };
}
