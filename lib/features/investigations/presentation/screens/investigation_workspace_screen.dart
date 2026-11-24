import 'package:flutter/material.dart';

import '../../application/models/investigation_summary.dart';
import '../../application/models/mitre_reference_verification_result.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/analyst_decision.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/mitre_attack_reference.dart';
import '../../generation/models/hypothesis_generation_configuration.dart';
import '../../generation/models/hypothesis_generation_result.dart';
import '../../../visualizations/models/attack_connection.dart';
import '../../../visualizations/services/visualization_data_service.dart';
import '../controllers/investigation_ui_controller.dart';
import '../widgets/investigation_dialogs.dart';
import '../../generation/models/hypothesis_generation_run.dart';

class InvestigationWorkspaceScreen extends StatefulWidget {
  const InvestigationWorkspaceScreen({
    required this.controller,
    required this.investigationId,
    required this.onBack,
    required this.onOpenGraphSelection,
    super.key,
  });

  final InvestigationUiController controller;
  final String investigationId;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenGraphSelection;

  @override
  State<InvestigationWorkspaceScreen> createState() =>
      _InvestigationWorkspaceScreenState();
}

class _InvestigationWorkspaceScreenState
    extends State<InvestigationWorkspaceScreen> {
  static const _sections = [
    'Overview',
    'Evidence',
    'Hypotheses',
    'Assessments',
    'ATT&CK',
    'Activity',
  ];

  int _section = 0;

  @override
  void initState() {
    super.initState();
    _scheduleLoad(widget.investigationId);
  }

  @override
  void didUpdateWidget(covariant InvestigationWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.investigationId != oldWidget.investigationId) {
      _scheduleLoad(widget.investigationId);
    }
  }

  void _scheduleLoad(String investigationId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller.activeInvestigationId == investigationId) {
        return;
      }
      widget.controller.openInvestigation(investigationId);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final summary = widget.controller.summary;
          if (widget.controller.isLoadingWorkspace ||
              (summary == null && widget.controller.errorMessage == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (summary == null) {
            return _WorkspaceLoadError(
              message: widget.controller.errorMessage ??
                  'The requested investigation could not be loaded.',
              onBack: widget.onBack,
            );
          }
          return _buildWorkspace(context, summary);
        },
      );

  Widget _buildWorkspace(
    BuildContext context,
    InvestigationSummary summary,
  ) {
    final controller = widget.controller;
    final investigation = summary.investigation;
    final closed = investigation.status == InvestigationStatus.closed;
    final sections = [
      _OverviewSection(
        summary: summary,
        onOpenGraphSelection: () =>
            widget.onOpenGraphSelection(investigation.id),
        onEditMetadata: () => _editMetadata(investigation),
        onChangeStatus: (value) => controller.changeStatus(
          investigationId: investigation.id,
          status: value,
        ),
        onChangePriority: (value) => controller.changePriority(
          investigationId: investigation.id,
          priority: value,
        ),
      ),
      _EvidenceSection(
        controller: controller,
        investigation: investigation,
        evidence: controller.evidence,
        readOnly: closed,
      ),
      _HypothesesSection(
        controller: controller,
        investigation: investigation,
        evidence: controller.evidence,
        hypotheses: controller.hypotheses,
        assessments: controller.assessmentsByHypothesis,
        decisions: controller.decisionsByHypothesis,
        readOnly: closed,
      ),
      _AssessmentsSection(
        controller: controller,
        investigation: investigation,
        evidence: controller.evidence,
        hypotheses: controller.hypotheses,
        histories: controller.assessmentsByHypothesis,
        readOnly: closed,
      ),
      _MitreSection(
        controller: controller,
        investigationId: investigation.id,
        hypotheses: controller.hypotheses,
        readOnly: closed,
      ),
      _ActivitySection(
        controller: controller,
        investigation: investigation,
        decisions: controller.decisionsByHypothesis,
        readOnly: closed,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to investigations',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investigation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${investigation.id} · ${_humanize(investigation.status.name)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!closed)
                IconButton(
                  tooltip: 'Select links from attack graph',
                  onPressed: () =>
                      widget.onOpenGraphSelection(investigation.id),
                  icon: const Icon(Icons.hub_outlined),
                ),
            ],
          ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WorkspaceError(
              message: controller.errorMessage!,
              onDismiss: controller.clearError,
            ),
          ),
        if (closed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _ReadOnlyNotice(),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var index = 0; index < _sections.length; index++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('investigation-tab-${_sections[index]}'),
                    label: Text(_sections[index]),
                    selected: _section == index,
                    onSelected: (_) => setState(() => _section = index),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              for (final section in sections) KeyedSubtree(child: section),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editMetadata(Investigation investigation) async {
    final draft = await showInvestigationMetadataDialog(context, investigation);
    if (draft == null || !mounted) return;
    await widget.controller.updateMetadata(
      investigationId: investigation.id,
      title: draft.title,
      description: draft.description,
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.summary,
    required this.onOpenGraphSelection,
    required this.onEditMetadata,
    required this.onChangeStatus,
    required this.onChangePriority,
  });

  final InvestigationSummary summary;
  final VoidCallback onOpenGraphSelection;
  final VoidCallback onEditMetadata;
  final ValueChanged<InvestigationStatus> onChangeStatus;
  final ValueChanged<InvestigationPriority> onChangePriority;

  @override
  Widget build(BuildContext context) {
    final investigation = summary.investigation;
    final closed = investigation.status == InvestigationStatus.closed;
    final entityById = {
      for (final entity in VisualizationDataService.entities) entity.id: entity,
    };
    final connectionById = {
      for (final connection in VisualizationDataService.connections)
        connection.id: connection,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: 'Evidence', value: '${summary.evidenceCount}'),
            _MetricCard(
              label: 'Hypotheses',
              value: '${summary.hypothesisCount}',
            ),
            _MetricCard(
              label: 'Graph entities',
              value: '${summary.associatedEntityCount}',
            ),
            _MetricCard(
              label: 'Graph connections',
              value: '${summary.associatedConnectionCount}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Case metadata',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!closed)
                      OutlinedButton.icon(
                        onPressed: onEditMetadata,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit metadata'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  investigation.description.isEmpty
                      ? 'No description supplied.'
                      : investigation.description,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _MetadataValue(
                      label: 'Status',
                      value: _humanize(investigation.status.name),
                    ),
                    _MetadataValue(
                      label: 'Priority',
                      value: _humanize(investigation.priority.name),
                    ),
                    _MetadataValue(
                      label: 'Created',
                      value: _formatDate(investigation.createdAt),
                    ),
                    _MetadataValue(
                      label: 'Updated',
                      value: _formatDate(investigation.updatedAt),
                    ),
                    _MetadataValue(
                      label: 'Assigned analyst',
                      value: investigation.assignedAnalystId ?? 'Unassigned',
                    ),
                  ],
                ),
                if (!closed) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _EnumSelector<InvestigationStatus>(
                        label: 'Change status',
                        value: investigation.status,
                        values: [
                          investigation.status,
                          ..._allowedStatusTransitions(investigation.status),
                        ],
                        onChanged: onChangeStatus,
                      ),
                      _EnumSelector<InvestigationPriority>(
                        label: 'Priority',
                        value: investigation.priority,
                        values: InvestigationPriority.values,
                        onChanged: onChangePriority,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Graph associations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (!closed)
                      OutlinedButton.icon(
                        onPressed: onOpenGraphSelection,
                        icon: const Icon(Icons.hub_outlined),
                        label: const Text('Select from graph'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Graph associations are synthetic demo references, not '
                  'evidence or confirmation of malicious activity.',
                ),
                const SizedBox(height: 10),
                if (investigation.relatedEntityIds.isEmpty &&
                    investigation.relatedConnectionIds.isEmpty)
                  const Text('No graph items associated.')
                else ...[
                  for (final id in investigation.relatedEntityIds)
                    _AssociationTile(
                      icon: Icons.circle_outlined,
                      title: entityById[id]?.name ?? id,
                      id: id,
                      type: 'Synthetic graph entity',
                    ),
                  for (final id in investigation.relatedConnectionIds)
                    _AssociationTile(
                      icon: Icons.link,
                      title: _connectionLabel(connectionById[id], id),
                      id: id,
                      type: 'Synthetic graph connection',
                    ),
                ],
              ],
            ),
          ),
        ),
        if (summary.latestDecision != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Latest analyst decision'),
              subtitle: Text(
                '${_humanize(summary.latestDecision!.decision.name)} · '
                '${summary.latestDecision!.rationale}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.controller,
    required this.investigation,
    required this.evidence,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final Investigation investigation;
  final List<Evidence> evidence;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Evidence · ${evidence.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!readOnly)
                FilledButton.icon(
                  key: const ValueKey('add-investigation-evidence'),
                  onPressed:
                      controller.isSubmitting ? null : () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add evidence'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const _SemanticNotice(
            text: 'Hypotheses and AI-generated content cannot be stored as '
                'evidence. Adding evidence does not confirm an attack.',
          ),
          if (evidence.isEmpty)
            const _SectionEmpty(
              icon: Icons.receipt_long_outlined,
              title: 'No evidence recorded',
              detail: 'Add a source-backed item with reliability rationale.',
            )
          else
            ...evidence.map(
              (item) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(item.title),
                  subtitle: Text(
                    '${_humanize(item.evidenceType.name)} · '
                    '${_humanize(item.provenance.origin.name)} · '
                    'Reliability ${_humanize(item.reliability.name)}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _DetailLine(label: 'Description', value: item.description),
                    _DetailLine(
                      label: 'Source',
                      value: item.provenance.source.description,
                    ),
                    _DetailLine(
                      label: 'Source ID',
                      value: item.provenance.source.identifier ?? 'Not set',
                    ),
                    _DetailLine(
                      label: 'Reliability rationale',
                      value: item.reliabilityRationale,
                    ),
                    _DetailLine(
                      label: 'Collected',
                      value: _formatDate(item.collectedAt),
                    ),
                    _DetailLine(
                      label: 'Evidence ID',
                      value: item.id,
                    ),
                    if (item.relatedEntityIds.isNotEmpty)
                      _DetailLine(
                        label: 'Related graph entity IDs',
                        value: item.relatedEntityIds.join(', '),
                      ),
                    if (item.relatedConnectionIds.isNotEmpty)
                      _DetailLine(
                        label: 'Related graph connection IDs',
                        value: item.relatedConnectionIds.join(', '),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );

  Future<void> _add(BuildContext context) async {
    final item = await showEvidenceDialog(
      context,
      investigation: investigation,
    );
    if (item == null || !context.mounted) return;
    await controller.addEvidence(item);
  }
}

class _HypothesesSection extends StatefulWidget {
  const _HypothesesSection({
    required this.controller,
    required this.investigation,
    required this.evidence,
    required this.hypotheses,
    required this.assessments,
    required this.decisions,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final Investigation investigation;
  final List<Evidence> evidence;
  final List<Hypothesis> hypotheses;
  final Map<String, List<AnalystAssessment>> assessments;
  final Map<String, List<AnalystDecision>> decisions;
  final bool readOnly;

  @override
  State<_HypothesesSection> createState() => _HypothesesSectionState();
}

class _HypothesesSectionState extends State<_HypothesesSection> {
  final Map<String, String> _cuePolarity = {};
  String? _selectedHypothesisId;

  @override
  void didUpdateWidget(covariant _HypothesesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.investigation.id != widget.investigation.id) {
      _cuePolarity.clear();
      _selectedHypothesisId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _findHypothesis();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hypotheses', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _SemanticNotice(
          text:
              'A generated hypothesis is a heuristic for review, not evidence '
              'or a confirmed incident. Cue polarity below is supplied by the '
              'analyst; the mock generator does not interpret evidence text.',
        ),
        if (widget.evidence.isEmpty)
          const _SectionEmpty(
            icon: Icons.lightbulb_outline,
            title: 'Evidence is required before generation',
            detail: 'Record evidence before requesting mock hypotheses.',
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyst-supplied generation cues',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final item in widget.evidence)
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 210,
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownButton<String>(
                          key: ValueKey('generation-cue-${item.id}'),
                          value: _cuePolarity[item.id] ?? 'none',
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('No cue'),
                            ),
                            DropdownMenuItem(
                              value: 'supporting',
                              child: Text('Supporting'),
                            ),
                            DropdownMenuItem(
                              value: 'contradicting',
                              child: Text('Contradicting'),
                            ),
                          ],
                          onChanged: widget.readOnly
                              ? null
                              : (value) => setState(
                                    () =>
                                        _cuePolarity[item.id] = value ?? 'none',
                                  ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('generate-hypotheses'),
                    onPressed: widget.readOnly || widget.controller.isSubmitting
                        ? null
                        : _generate,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Generate mock hypotheses'),
                  ),
                  if (widget.controller.generationRun != null) ...[
                    const SizedBox(height: 12),
                    _GenerationOutcome(
                      run: widget.controller.generationRun!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.hypotheses.isEmpty)
          const _SectionEmpty(
            icon: Icons.lightbulb_outline,
            title: 'No hypotheses recorded',
            detail: 'Generation only runs when evidence cues are supplied.',
          )
        else ...[
          _HypothesisPicker(
            hypotheses: widget.hypotheses,
            selectedId: selected?.id,
            onChanged: (id) => setState(() => _selectedHypothesisId = id),
          ),
          if (selected != null) ...[
            _HypothesisCard(
              hypothesis: selected,
              evidence: widget.evidence,
              assessments: widget.assessments[selected.id] ?? const [],
              decisions: widget.decisions[selected.id] ?? const [],
            ),
            _DecisionControls(
              controller: widget.controller,
              investigationId: widget.investigation.id,
              hypothesis: selected,
              readOnly: widget.readOnly,
            ),
          ],
        ],
      ],
    );
  }

  Hypothesis? _findHypothesis() {
    for (final hypothesis in widget.hypotheses) {
      if (hypothesis.id == _selectedHypothesisId) return hypothesis;
    }
    return widget.hypotheses.isEmpty ? null : widget.hypotheses.first;
  }

  Future<void> _generate() async {
    final cues = <EvidenceGenerationCue>[];
    for (final entry in _cuePolarity.entries) {
      final polarity = switch (entry.value) {
        'supporting' => EvidenceCuePolarity.supporting,
        'contradicting' => EvidenceCuePolarity.contradicting,
        _ => null,
      };
      if (polarity != null) {
        cues.add(EvidenceGenerationCue(
          evidenceId: entry.key,
          polarity: polarity,
        ));
      }
    }
    await widget.controller.generateHypotheses(
      investigationId: widget.investigation.id,
      configuration: HypothesisGenerationConfiguration(
        evidenceCues: cues,
      ),
    );
  }
}

class _GenerationOutcome extends StatelessWidget {
  const _GenerationOutcome({required this.run});

  final HypothesisGenerationRun run;

  @override
  Widget build(BuildContext context) {
    final result = run.result;
    final text = switch (result) {
      HypothesesGeneratedResult() =>
        'Generated ${result.hypotheses.length} hypothesis candidate(s). '
            '${run.newlyPersisted.length} new; '
            '${run.alreadyPresent.length} already present.',
      InsufficientEvidenceResult() =>
        'Insufficient evidence: ${result.message}',
      NoApplicableGenerationRulesResult() =>
        'No applicable generation rules: ${result.message}',
      InvalidGenerationContextResult() =>
        'Invalid generation context: ${result.message}',
      InvalidEvidenceReferencesResult() =>
        'Invalid evidence references: ${result.message}',
      InvalidGeneratedHypothesesResult() =>
        'Generated hypotheses were rejected: ${result.message}',
      GenerationFailureResult() => 'Generation failed: ${result.message}',
    };
    final successful = result is HypothesesGeneratedResult;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: successful
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text),
      ),
    );
  }
}

class _HypothesisCard extends StatelessWidget {
  const _HypothesisCard({
    required this.hypothesis,
    required this.evidence,
    required this.assessments,
    required this.decisions,
  });

  final Hypothesis hypothesis;
  final List<Evidence> evidence;
  final List<AnalystAssessment> assessments;
  final List<AnalystDecision> decisions;

  @override
  Widget build(BuildContext context) {
    final evidenceById = {for (final item in evidence) item.id: item};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hypothesis.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${_humanize(hypothesis.status.name)} · '
              'Heuristic confidence indicator '
              '${hypothesis.confidence.toStringAsFixed(2)} (uncalibrated)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(hypothesis.explanation),
            const SizedBox(height: 8),
            Text('Confidence rationale: ${hypothesis.confidenceExplanation}'),
            const SizedBox(height: 8),
            _IdList(
              label: 'Supporting evidence',
              ids: hypothesis.supportingEvidenceIds,
              evidenceById: evidenceById,
            ),
            _IdList(
              label: 'Contradicting evidence',
              ids: hypothesis.contradictingEvidenceIds,
              evidenceById: evidenceById,
            ),
            if (hypothesis.evidenceGaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Evidence gaps: ${hypothesis.evidenceGaps.map((gap) => gap.description).join('; ')}',
              ),
            ],
            if (hypothesis.alternativeExplanations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Alternatives: ${hypothesis.alternativeExplanations.join('; ')}',
              ),
            ],
            const Divider(height: 24),
            Text(
              'Assessment history: ${assessments.length} · '
              'Decision history: ${decisions.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Generated ${_formatDate(hypothesis.generatedAt)} · '
              'Provenance ${_humanize(hypothesis.provenance.origin.name)}'
              '${hypothesis.generationMetadata == null ? '' : ' · ${hypothesis.generationMetadata!.method} v${hypothesis.generationMetadata!.ruleSetVersion}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionControls extends StatelessWidget {
  const _DecisionControls({
    required this.controller,
    required this.investigationId,
    required this.hypothesis,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final String investigationId;
  final Hypothesis hypothesis;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final inReview = hypothesis.status == HypothesisStatus.underReview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analyst review',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'Accept means continue investigating; it does not prove the '
              'hypothesis or confirm an incident.',
            ),
            const SizedBox(height: 12),
            if (!inReview && hypothesis.status != HypothesisStatus.superseded)
              OutlinedButton(
                onPressed: readOnly || controller.isSubmitting
                    ? null
                    : () => controller.startHypothesisReview(
                          investigationId: investigationId,
                          hypothesisId: hypothesis.id,
                        ),
                child: const Text('Start hypothesis review'),
              ),
            if (inReview)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final decision in AnalystDecisionType.values)
                    OutlinedButton(
                      onPressed: readOnly || controller.isSubmitting
                          ? null
                          : () => _record(context, decision),
                      child: Text(_decisionLabel(decision)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(
    BuildContext context,
    AnalystDecisionType decision,
  ) async {
    final rationale = await showDecisionRationaleDialog(
      context,
      title: '${_decisionLabel(decision)} hypothesis',
      actionLabel: 'Append decision',
    );
    if (rationale == null || !context.mounted) return;
    await controller.recordDecision(
      investigationId: investigationId,
      hypothesisId: hypothesis.id,
      decisionId: 'DEC-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      analystId: 'demo-analyst',
      rationale: rationale,
      decision: decision,
    );
  }
}

class _AssessmentsSection extends StatefulWidget {
  const _AssessmentsSection({
    required this.controller,
    required this.investigation,
    required this.evidence,
    required this.hypotheses,
    required this.histories,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final Investigation investigation;
  final List<Evidence> evidence;
  final List<Hypothesis> hypotheses;
  final Map<String, List<AnalystAssessment>> histories;
  final bool readOnly;

  @override
  State<_AssessmentsSection> createState() => _AssessmentsSectionState();
}

class _AssessmentsSectionState extends State<_AssessmentsSection> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedHypothesis();
    if (selected == null) {
      return const _SectionEmpty(
        icon: Icons.fact_check_outlined,
        title: 'No hypotheses to assess',
        detail: 'Add or generate a hypothesis candidate first.',
      );
    }
    final history = widget.histories[selected.id] ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HypothesisPicker(
          hypotheses: widget.hypotheses,
          selectedId: selected.id,
          onChanged: (id) => setState(() => _selectedId = id),
        ),
        Card(
          child: ListTile(
            title: const Text('Assessment semantics'),
            subtitle: const Text(
              'Assessments preserve the evidence reviewed and rationale. '
              'They do not change hypothesis status or confirm an incident.',
            ),
            leading: const Icon(Icons.info_outline),
            trailing: widget.readOnly
                ? null
                : FilledButton(
                    onPressed: widget.controller.isSubmitting
                        ? null
                        : () => _add(context, selected),
                    child: const Text('Add assessment'),
                  ),
            isThreeLine: true,
          ),
        ),
        if (history.isEmpty)
          const _SectionEmpty(
            icon: Icons.history,
            title: 'No assessments yet',
            detail: 'Assessment events are kept as a separate history.',
          )
        else
          for (final assessment in history.reversed)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(_humanize(assessment.outcome.name)),
                subtitle: Text(
                  '${assessment.rationale}\n'
                  '${assessment.evidenceReviewedIds.length} evidence item(s) '
                  'reviewed · ${_formatDate(assessment.assessedAt)}',
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }

  Hypothesis? _selectedHypothesis() {
    for (final hypothesis in widget.hypotheses) {
      if (hypothesis.id == _selectedId) return hypothesis;
    }
    return widget.hypotheses.isEmpty ? null : widget.hypotheses.first;
  }

  Future<void> _add(BuildContext context, Hypothesis hypothesis) async {
    final draft = await showAssessmentDialog(
      context,
      evidence: widget.evidence,
    );
    if (draft == null || !context.mounted) return;
    await widget.controller.addAssessment(
      id: 'ASM-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      investigationId: widget.investigation.id,
      hypothesisId: hypothesis.id,
      analystId: 'demo-analyst',
      rationale: draft.rationale,
      outcome: draft.outcome,
      evidenceReviewedIds: draft.evidenceReviewedIds,
      supportingEvidenceIds: draft.supportingEvidenceIds,
      contradictingEvidenceIds: draft.contradictingEvidenceIds,
      alternativeExplanations: draft.alternativeExplanations,
      evidenceGaps: draft.evidenceGaps,
    );
  }
}

class _MitreSection extends StatefulWidget {
  const _MitreSection({
    required this.controller,
    required this.investigationId,
    required this.hypotheses,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final String investigationId;
  final List<Hypothesis> hypotheses;
  final bool readOnly;

  @override
  State<_MitreSection> createState() => _MitreSectionState();
}

class _MitreSectionState extends State<_MitreSection> {
  String? _selectedId;
  String? _verificationMessage;

  @override
  void didUpdateWidget(covariant _MitreSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.investigationId != widget.investigationId) {
      _selectedId = null;
      _verificationMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedHypothesis();
    if (selected == null) {
      return const _SectionEmpty(
        icon: Icons.account_tree_outlined,
        title: 'No hypotheses to map',
        detail: 'ATT&CK references are attached to a hypothesis.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HypothesisPicker(
          hypotheses: widget.hypotheses,
          selectedId: selected.id,
          onChanged: (id) => setState(() {
            _selectedId = id;
            _verificationMessage = null;
          }),
        ),
        const _SemanticNotice(
          text: 'References are analyst-proposed. The default verifier is '
              'unavailable; no catalog lookup or network request is performed.',
        ),
        if (!widget.readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: widget.controller.isSubmitting
                  ? null
                  : () => _addReference(context, selected),
              icon: const Icon(Icons.add),
              label: const Text('Propose reference'),
            ),
          ),
        if (_verificationMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_verificationMessage!),
            ),
          ),
        if (selected.mitreAttackReferences.isEmpty)
          const _SectionEmpty(
            icon: Icons.account_tree_outlined,
            title: 'No ATT&CK references',
            detail: 'No technique identifiers are fabricated or preloaded.',
          )
        else
          for (final reference in selected.mitreAttackReferences)
            _MitreReferenceCard(
              reference: reference,
              readOnly: widget.readOnly,
              isBusy: widget.controller.isSubmitting,
              onVerify: () => _verify(selected.id, reference),
              onRemove: () => widget.controller.removeProposedMitreReference(
                hypothesisId: selected.id,
                analystId: 'demo-analyst',
                techniqueId: reference.techniqueId,
              ),
            ),
      ],
    );
  }

  Hypothesis? _selectedHypothesis() {
    for (final hypothesis in widget.hypotheses) {
      if (hypothesis.id == _selectedId) return hypothesis;
    }
    return widget.hypotheses.isEmpty ? null : widget.hypotheses.first;
  }

  Future<void> _addReference(
    BuildContext context,
    Hypothesis hypothesis,
  ) async {
    final reference = await showProposedMitreReferenceDialog(context);
    if (reference == null || !context.mounted) return;
    await widget.controller.addProposedMitreReference(
      hypothesisId: hypothesis.id,
      analystId: 'demo-analyst',
      reference: reference,
    );
  }

  Future<void> _verify(
    String hypothesisId,
    MitreAttackReference reference,
  ) async {
    final result = await widget.controller.verifyMitreReference(
      hypothesisId: hypothesisId,
      analystId: 'demo-analyst',
      techniqueId: reference.techniqueId,
    );
    if (!mounted || result == null) return;
    setState(() => _verificationMessage = _verificationText(result));
  }

  String _verificationText(MitreReferenceVerificationResult result) =>
      switch (result) {
        MitreReferenceVerifiedResult() =>
          'Reference ${result.reference.techniqueId} was verified.',
        MitreReferenceNotFoundResult() =>
          'Reference not found: ${result.message}',
        MitreReferenceMismatchResult() =>
          'Reference mismatch: ${result.message}',
        MitreReferenceDeprecatedResult() =>
          'Reference is deprecated: ${result.message}',
        MitreReferenceUnverifiedResult() =>
          'Reference remains unverified: ${result.message}',
        MitreReferenceVerificationUnavailableResult() =>
          'Verification unavailable: ${result.message}',
      };
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.controller,
    required this.investigation,
    required this.decisions,
    required this.readOnly,
  });

  final InvestigationUiController controller;
  final Investigation investigation;
  final Map<String, List<AnalystDecision>> decisions;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final history = [
      for (final items in decisions.values) ...items,
    ]..sort((a, b) => b.decidedAt.compareTo(a.decidedAt));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Analyst activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!readOnly)
              FilledButton.icon(
                onPressed:
                    controller.isSubmitting ? null : () => _addNote(context),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Append note'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const _SemanticNotice(
          text: 'Notes and decisions are appended. Earlier history is not '
              'rewritten by metadata edits.',
        ),
        if (investigation.analystNotes.isEmpty)
          const _SectionEmpty(
            icon: Icons.notes,
            title: 'No analyst notes',
            detail: 'Add a note to preserve analyst context.',
          )
        else
          for (final note in investigation.analystNotes.reversed)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes),
                title: Text(note.text),
                subtitle: Text(
                  '${note.authorId} · ${_formatDate(note.timestamp)} · ${note.id}',
                ),
                isThreeLine: true,
              ),
            ),
        const SizedBox(height: 12),
        Text('Hypothesis decisions',
            style: Theme.of(context).textTheme.titleSmall),
        if (history.isEmpty)
          const _SectionEmpty(
            icon: Icons.history,
            title: 'No decisions recorded',
            detail: 'Decision history is appended per hypothesis.',
          )
        else
          for (final decision in history)
            Card(
              child: ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: Text(
                  '${_humanize(decision.decision.name)} · '
                  '${decision.hypothesisId}',
                ),
                subtitle: Text(
                  '${decision.rationale}\n'
                  '${decision.analystId} · ${_formatDate(decision.decidedAt)}',
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }

  Future<void> _addNote(BuildContext context) async {
    final text = await showAnalystNoteDialog(context);
    if (text == null || !context.mounted) return;
    await controller.appendNote(
      investigationId: investigation.id,
      noteId: 'NOTE-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      authorId: 'demo-analyst',
      content: text,
    );
  }
}

class _HypothesisPicker extends StatelessWidget {
  const _HypothesisPicker({
    required this.hypotheses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Hypothesis> hypotheses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: selectedId ?? hypotheses.first.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Hypothesis',
            border: OutlineInputBorder(),
          ),
          items: hypotheses
              .map(
                (hypothesis) => DropdownMenuItem(
                  value: hypothesis.id,
                  child: Text(
                    hypothesis.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      );
}

class _MitreReferenceCard extends StatelessWidget {
  const _MitreReferenceCard({
    required this.reference,
    required this.readOnly,
    required this.isBusy,
    required this.onVerify,
    required this.onRemove,
  });

  final MitreAttackReference reference;
  final bool readOnly;
  final bool isBusy;
  final VoidCallback onVerify;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: Text('${reference.techniqueId} · ${reference.techniqueName}'),
          subtitle: Text(
            '${reference.tactic} · '
            '${reference.isVerified ? 'Verified' : 'Proposed / unverified'}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _DetailLine(label: 'Description', value: reference.description),
            _DetailLine(label: 'Reference URL', value: reference.referenceUrl),
            _DetailLine(
              label: 'Catalog version',
              value: reference.catalogVersion ?? 'Not supplied',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: isBusy || readOnly || !reference.isProposed
                      ? null
                      : onVerify,
                  child: const Text('Verify reference'),
                ),
                if (!readOnly && reference.isProposed)
                  TextButton(
                    onPressed: isBusy ? null : onRemove,
                    child: const Text('Remove proposal'),
                  ),
              ],
            ),
          ],
        ),
      );
}

class _IdList extends StatelessWidget {
  const _IdList({
    required this.label,
    required this.ids,
    required this.evidenceById,
  });

  final String label;
  final List<String> ids;
  final Map<String, Evidence> evidenceById;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '$label: ${ids.isEmpty ? 'None recorded' : ids.map((id) => evidenceById[id]?.title ?? id).join(', ')}',
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _MetadataValue extends StatelessWidget {
  const _MetadataValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value),
          ],
        ),
      );
}

class _EnumSelector<T extends Enum> extends StatelessWidget {
  const _EnumSelector({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: values
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(_humanize(item.name)),
                ),
              )
              .toList(),
          onChanged: (item) {
            if (item != null && item != value) onChanged(item);
          },
        ),
      );
}

class _AssociationTile extends StatelessWidget {
  const _AssociationTile({
    required this.icon,
    required this.title,
    required this.id,
    required this.type,
  });

  final IconData icon;
  final String title;
  final String id;
  final String type;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$type · $id'),
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label: $value'),
        ),
      );
}

class _SemanticNotice extends StatelessWidget {
  const _SemanticNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'This investigation is closed. Its records remain available for '
            'review; workflow edits are disabled.',
          ),
        ),
      );
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(message),
          trailing: IconButton(
            tooltip: 'Dismiss error',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ),
      );
}

class _WorkspaceLoadError extends StatelessWidget {
  const _WorkspaceLoadError({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Back to investigations'),
              ),
            ],
          ),
        ),
      );
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(detail, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

String _connectionLabel(AttackConnection? connection, String id) {
  if (connection == null) return id;
  final entities = {
    for (final entity in VisualizationDataService.entities) entity.id: entity,
  };
  final source =
      entities[connection.sourceEntityId]?.name ?? connection.sourceEntityId;
  final target =
      entities[connection.targetEntityId]?.name ?? connection.targetEntityId;
  return '$source → $target';
}

List<InvestigationStatus> _allowedStatusTransitions(
  InvestigationStatus status,
) =>
    switch (status) {
      InvestigationStatus.draft => const [InvestigationStatus.active],
      InvestigationStatus.active => const [
          InvestigationStatus.onHold,
          InvestigationStatus.closed,
        ],
      InvestigationStatus.onHold => const [
          InvestigationStatus.active,
          InvestigationStatus.closed,
        ],
      InvestigationStatus.closed => const [],
    };

String _decisionLabel(AnalystDecisionType decision) => switch (decision) {
      AnalystDecisionType.accept => 'Accept for continued investigation',
      AnalystDecisionType.reject => 'Reject',
      AnalystDecisionType.defer => 'Defer',
      AnalystDecisionType.inconclusive => 'Mark inconclusive',
    };

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
