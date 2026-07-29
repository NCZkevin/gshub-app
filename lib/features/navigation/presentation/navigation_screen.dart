import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'navigation_provider.dart';
import 'navigation_workspace.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navAsync = ref.watch(navigationProvider);

    return navAsync.when(
      loading: () => const ConsoleScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ConsoleScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('加载失败: $error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(navigationProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (state) => switch (state.viewState) {
        NavViewState.checking => const ConsoleScaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        NavViewState.setup => _NavigationSetup(state: state),
        NavViewState.active => NavigationWorkspace(navState: state),
      },
    );
  }
}

class _NavigationSetup extends ConsumerWidget {
  final NavigationState state;

  const _NavigationSetup({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(navigationProvider.notifier);

    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(
          title: '导航配置',
          subtitle: 'map selection',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConsoleCard(
            title: '启动导航',
            icon: Icons.route_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.error != null) ...[
                  _MessageBanner(message: state.error!, color: AppTheme.danger),
                  const SizedBox(height: 16),
                ],
                Text('选择地图', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(state.selectedMap),
                  isExpanded: true,
                  initialValue: state.selectedMap,
                  hint: const Text('请选择地图'),
                  items: state.maps
                      .map(
                        (map) => DropdownMenuItem(
                          value: map.name,
                          child: Text(map.name),
                        ),
                      )
                      .toList(),
                  onChanged: state.loading
                      ? null
                      : (name) {
                          if (name != null) notifier.selectMap(name);
                        },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('setup-relocalization'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('重定位模式'),
                  subtitle: const Text('作为启动容器参数，用于恢复已有地图坐标'),
                  value: state.useRelocalizationOnStart,
                  onChanged: state.loading
                      ? null
                      : notifier.setUseRelocalizationOnStart,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: state.loading || state.selectedMap == null
                      ? null
                      : notifier.startNavContainer,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: state.loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('启动导航'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdvancedParameters(state: state),
        ],
      ),
    );
  }
}

class _AdvancedParameters extends ConsumerWidget {
  final NavigationState state;

  const _AdvancedParameters({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(navigationProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.tune_outlined),
        title: Row(
          children: [
            const Expanded(child: Text('高级导航参数')),
            if (state.navParamsDirty)
              const StatusPill(label: '未应用', color: AppTheme.warning),
          ],
        ),
        subtitle: const Text('通常无需修改'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (state.navParamsDirty) ...[
            const _MessageBanner(
              message: '参数有未应用修改，启动导航不会自动保存这些参数',
              color: AppTheme.warning,
            ),
            const SizedBox(height: 10),
          ],
          if (state.navParamsMessage != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                state.navParamsMessage!,
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '本体'),
                    Tab(text: '绕障'),
                    Tab(text: '停障'),
                  ],
                ),
                SizedBox(
                  height: 340,
                  child: TabBarView(
                    children: [
                      _ParameterList(
                        params: state.navParams,
                        specs: _robotSpecs,
                      ),
                      _ParameterList(
                        params: state.navParams,
                        specs: _freeSpecs,
                      ),
                      ListView(
                        padding: const EdgeInsets.only(top: 12),
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('全向控制'),
                            value: state.navParams.holonomic,
                            onChanged: notifier.setHolonomic,
                          ),
                          _ParameterList(
                            params: state.navParams,
                            specs: _fixedSpecs,
                            shrinkWrap: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.loading
                      ? null
                      : notifier.reloadSavedNavParams,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('加载已保存'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.loading ? null : notifier.applyNavParams,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('应用参数'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParameterList extends ConsumerWidget {
  final NavParamForm params;
  final List<_ParamSpec> specs;
  final bool shrinkWrap;

  const _ParameterList({
    required this.params,
    required this.specs,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.only(top: 12),
      children: specs
          .map(
            (spec) => _ParamNumberField(
              label: spec.label,
              unit: spec.unit,
              value: params.valueOf(spec.field),
              onChanged: (value) => ref
                  .read(navigationProvider.notifier)
                  .updateNavParam(spec.field, value),
            ),
          )
          .toList(),
    );
  }
}

class _ParamNumberField extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;

  const _ParamNumberField({
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ParamNumberField> createState() => _ParamNumberFieldState();
}

class _ParamNumberFieldState extends State<_ParamNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ParamNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _format(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.unit,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          final value = double.tryParse(text);
          if (value != null) widget.onChanged(value);
        },
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final Color color;

  const _MessageBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _ParamSpec {
  final NavParamField field;
  final String label;
  final String unit;

  const _ParamSpec(this.field, this.label, this.unit);
}

const _robotSpecs = [
  _ParamSpec(NavParamField.lidarHeight, '雷达高度', 'm'),
  _ParamSpec(NavParamField.robotLength, '本体长度', 'm'),
  _ParamSpec(NavParamField.robotWidth, '本体宽度', 'm'),
  _ParamSpec(NavParamField.deviceFrontDistance, '设备前向距离', 'm'),
  _ParamSpec(NavParamField.deviceLeftDistance, '设备左向距离', 'm'),
];

const _freeSpecs = [
  _ParamSpec(NavParamField.freeMinObstacleHeight, '最低障碍高度', 'm'),
  _ParamSpec(NavParamField.freeMaxObstacleHeight, '最高障碍高度', 'm'),
  _ParamSpec(NavParamField.freeLinearSpeed, '最大线速度', 'm/s'),
  _ParamSpec(NavParamField.freeAngularSpeed, '最大角速度', 'rad/s'),
  _ParamSpec(NavParamField.freeXyGoalTolerance, '到点距离', 'm'),
  _ParamSpec(NavParamField.freeYawGoalTolerance, '到点角度', 'rad'),
  _ParamSpec(NavParamField.freeSafetyDistance, '安全距离', 'm'),
];

const _fixedSpecs = [
  _ParamSpec(NavParamField.fixedMaxLinearSpeed, '最大线速度', 'm/s'),
  _ParamSpec(NavParamField.fixedMaxAngularSpeed, '最大角速度', 'rad/s'),
  _ParamSpec(NavParamField.fixedXyGoalTolerance, '到点距离', 'm'),
  _ParamSpec(NavParamField.fixedYawGoalTolerance, '到点角度', 'rad'),
  _ParamSpec(NavParamField.fixedLateralSafetyDistance, '侧向安全距', 'm'),
  _ParamSpec(NavParamField.fixedForwardSafetyDistance, '前向停车距', 'm'),
];
