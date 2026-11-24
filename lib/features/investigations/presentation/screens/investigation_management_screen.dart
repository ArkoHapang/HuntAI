import 'package:flutter/material.dart';

import '../../application/models/investigation_summary.dart';
import '../../domain/enums/investigation_enums.dart';
import '../controllers/investigation_ui_controller.dart';
import 'investigation_workspace_screen.dart';

class InvestigationManagementScreen extends StatefulWidget {
  const InvestigationManagementScreen({
    required this.controller,
    required this.selectedInvestigationId,
    required this.onSelectedInvestigationChanged,
    required this.onOpenGraphSelection,
    super.key,
  });

  final InvestigationUiController controller;
  final String? selectedInvestigationId;
  final ValueChanged<String?> onSelectedInvestigationChanged;
  final ValueChanged<String> onOpenGraphSelection;

  @override
  State<InvestigationManagementScreen> createState() =>
      _InvestigationManagementScreenState();
}

class _InvestigationManagementScreenState
    extends State<InvestigationManagementScreen> {
  final _searchController = TextEditingController();
  InvestigationStatus? _statusFilter;
  InvestigationPriority? _priorityFilter;

  @override
  void initState() {
    super.initState();
    widget.controller.loadInvestigations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final selectedId = widget.selectedInvestigationId;
        if (selectedId != null) {
          return InvestigationWorkspaceScreen(
            controller: widget.controller,
            investigationId: selectedId,
            onBack: () => widget.onSelectedInvestigationChanged(null),
            onOpenGraphSelection: widget.onOpenGraphSelection,
          );
        }
        return _buildList(context);
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final controller = widget.controller;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = controller.summaries.where((summary) {
      final investigation = summary.investigation;
      return (_statusFilter == null || investigation.status == _statusFilter) &&
          (_priorityFilter == null ||
              investigation.priority == _priorityFilter) &&
          (query.isEmpty ||
              investigation.title.toLowerCase().contains(query) ||
              investigation.id.toLowerCase().contains(query));
    }).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return ListView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Investigations',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('create-investigation'),
                  onPressed: controller.isSubmitting ? null : _create,
                  icon: const Icon(Icons.add),
                  label: Text(compact ? 'Create' : 'New investigation'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Analyst-managed cases, evidence, hypotheses, and review history.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _DemoNotice(compact: compact),
            if (controller.errorMessage != null)
              _ErrorBanner(
                message: controller.errorMessage!,
                onDismiss: controller.clearError,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 340,
                  child: TextField(
                    controller: _searchController,
                    key: const ValueKey('investigation-search'),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search title or ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _FilterDropdown<InvestigationStatus>(
                  label: 'Status',
                  value: _statusFilter,
                  values: InvestigationStatus.values,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
                _FilterDropdown<InvestigationPriority>(
                  label: 'Priority',
                  value: _priorityFilter,
                  values: InvestigationPriority.values,
                  onChanged: (value) => setState(() => _priorityFilter = value),
                ),
                if (_statusFilter != null || _priorityFilter != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _statusFilter = null;
                      _priorityFilter = null;
                    }),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.isLoadingList)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filtered.isEmpty)
              _EmptyInvestigations(
                hasInvestigations: controller.summaries.isNotEmpty,
                onCreate: _create,
              )
            else
              ...filtered.map(
                (summary) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InvestigationListCard(
                    summary: summary,
                    onTap: () {
                      widget.onSelectedInvestigationChanged(
                        summary.investigation.id,
                      );
                      widget.controller
                          .openInvestigation(summary.investigation.id);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _create() async {
    final draft = await showDialog<_InvestigationDraft>(
      context: context,
      builder: (context) => const _CreateInvestigationDialog(),
    );
    if (draft == null || !mounted) return;
    final id = 'INV-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await widget.controller.createInvestigation(
      id: id,
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Investigation records are kept only in memory and disappear '
                  'when this process ends. No example cases are preloaded. '
                  'Graph links use synthetic demo fixtures and are not evidence.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          title: Text(message),
          trailing: IconButton(
            tooltip: 'Dismiss error',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ),
      );
}

class _EmptyInvestigations extends StatelessWidget {
  const _EmptyInvestigations({
    required this.hasInvestigations,
    required this.onCreate,
  });

  final bool hasInvestigations;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                hasInvestigations ? Icons.search_off : Icons.folder_open,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                hasInvestigations
                    ? 'No investigations match these filters.'
                    : 'No investigations yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                hasInvestigations
                    ? 'Change or clear the current search and filters.'
                    : 'Create a case to start recording analyst findings.',
                textAlign: TextAlign.center,
              ),
              if (!hasInvestigations) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create investigation'),
                ),
              ],
            ],
          ),
        ),
      );
}

class _InvestigationListCard extends StatelessWidget {
  const _InvestigationListCard({
    required this.summary,
    required this.onTap,
  });

  final InvestigationSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final investigation = summary.investigation;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    investigation.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _LabelChip(label: _humanize(investigation.status.name)),
                  _LabelChip(label: _humanize(investigation.priority.name)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${investigation.id} · Updated ${_formatDate(investigation.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (investigation.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  investigation.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _CountLabel(
                    icon: Icons.hub_outlined,
                    label: '${summary.associatedEntityCount} graph entities',
                  ),
                  _CountLabel(
                    icon: Icons.link,
                    label: '${summary.associatedConnectionCount} connections',
                  ),
                  _CountLabel(
                    icon: Icons.receipt_long_outlined,
                    label: '${summary.evidenceCount} evidence',
                  ),
                  _CountLabel(
                    icon: Icons.lightbulb_outline,
                    label: '${summary.hypothesisCount} hypotheses',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown<T extends Enum> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text('All $label'.toLowerCase()),
            ),
            ...values.map(
              (item) => DropdownMenuItem<T?>(
                value: item,
                child: Text(_humanize(item.name)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      );
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text(label),
      );
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _InvestigationDraft {
  const _InvestigationDraft({
    required this.title,
    required this.description,
    required this.priority,
  });

  final String title;
  final String description;
  final InvestigationPriority priority;
}

class _CreateInvestigationDialog extends StatefulWidget {
  const _CreateInvestigationDialog();

  @override
  State<_CreateInvestigationDialog> createState() =>
      _CreateInvestigationDialogState();
}

class _CreateInvestigationDialogState
    extends State<_CreateInvestigationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  InvestigationPriority _priority = InvestigationPriority.medium;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create investigation'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('new-investigation-title'),
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InvestigationPriority>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: InvestigationPriority.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_humanize(value.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _InvestigationDraft(
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  priority: _priority,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      );
}

String _humanize(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
