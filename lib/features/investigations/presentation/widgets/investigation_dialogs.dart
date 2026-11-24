import 'package:flutter/material.dart';

import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/mitre_attack_reference.dart';

class InvestigationMetadataDraft {
  const InvestigationMetadataDraft({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class EvidenceDraft {
  const EvidenceDraft({
    required this.evidence,
  });

  final Evidence evidence;
}

class AssessmentDraft {
  const AssessmentDraft({
    required this.rationale,
    required this.outcome,
    required this.evidenceReviewedIds,
    required this.supportingEvidenceIds,
    required this.contradictingEvidenceIds,
    required this.alternativeExplanations,
    required this.evidenceGaps,
  });

  final String rationale;
  final AnalystAssessmentOutcome outcome;
  final List<String> evidenceReviewedIds;
  final List<String> supportingEvidenceIds;
  final List<String> contradictingEvidenceIds;
  final List<String> alternativeExplanations;
  final List<EvidenceGap> evidenceGaps;
}

Future<InvestigationMetadataDraft?> showInvestigationMetadataDialog(
  BuildContext context,
  Investigation investigation,
) =>
    showDialog<InvestigationMetadataDraft>(
      context: context,
      builder: (context) => _MetadataDialog(investigation: investigation),
    );

Future<String?> showAnalystNoteDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _AnalystNoteDialog(),
    );

Future<Evidence?> showEvidenceDialog(
  BuildContext context, {
  required Investigation investigation,
}) =>
    showDialog<Evidence>(
      context: context,
      builder: (context) => _EvidenceDialog(investigation: investigation),
    );

Future<String?> showDecisionRationaleDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _RationaleDialog(
        title: title,
        actionLabel: actionLabel,
        minimumLength: 8,
      ),
    );

Future<AssessmentDraft?> showAssessmentDialog(
  BuildContext context, {
  required List<Evidence> evidence,
}) =>
    showDialog<AssessmentDraft>(
      context: context,
      builder: (context) => _AssessmentDialog(evidence: evidence),
    );

Future<MitreAttackReference?> showProposedMitreReferenceDialog(
  BuildContext context,
) =>
    showDialog<MitreAttackReference>(
      context: context,
      builder: (context) => const _MitreReferenceDialog(),
    );

class _MetadataDialog extends StatefulWidget {
  const _MetadataDialog({required this.investigation});

  final Investigation investigation;

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.investigation.title);
  late final _description =
      TextEditingController(text: widget.investigation.description);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit investigation metadata'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
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
                InvestigationMetadataDraft(
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _AnalystNoteDialog extends StatefulWidget {
  const _AnalystNoteDialog();

  @override
  State<_AnalystNoteDialog> createState() => _AnalystNoteDialogState();
}

class _AnalystNoteDialogState extends State<_AnalystNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Append analyst note'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_controller.text.trim().isEmpty) return;
              Navigator.pop(context, _controller.text.trim());
            },
            child: const Text('Append'),
          ),
        ],
      );
}

class _RationaleDialog extends StatefulWidget {
  const _RationaleDialog({
    required this.title,
    required this.actionLabel,
    required this.minimumLength,
  });

  final String title;
  final String actionLabel;
  final int minimumLength;

  @override
  State<_RationaleDialog> createState() => _RationaleDialogState();
}

class _RationaleDialogState extends State<_RationaleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Rationale',
            helperText: 'Provide at least ${widget.minimumLength} characters.',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final rationale = _controller.text.trim();
              if (rationale.length < widget.minimumLength) return;
              Navigator.pop(context, rationale);
            },
            child: Text(widget.actionLabel),
          ),
        ],
      );
}

class _EvidenceDialog extends StatefulWidget {
  const _EvidenceDialog({required this.investigation});

  final Investigation investigation;

  @override
  State<_EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<_EvidenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _source = TextEditingController();
  final _sourceId = TextEditingController();
  final _reliabilityRationale = TextEditingController();
  EvidenceType _type = EvidenceType.other;
  DataOrigin _origin = DataOrigin.analystCreated;
  EvidenceReliability _reliability = EvidenceReliability.unassessed;
  DataClassification _classification = DataClassification.internal;
  final Set<String> _entities = {};
  final Set<String> _connections = {};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _source.dispose();
    _sourceId.dispose();
    _reliabilityRationale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add evidence'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('evidence-title'),
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 4,
                    validator: _required,
                  ),
                  DropdownButtonFormField<EvidenceType>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Evidence type'),
                    items: EvidenceType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_humanize(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                  DropdownButtonFormField<DataOrigin>(
                    initialValue: _origin,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Data provenance'),
                    items: DataOrigin.values
                        .where((origin) => origin != DataOrigin.aiGenerated)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_originLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _origin = value);
                    },
                  ),
                  TextFormField(
                    controller: _source,
                    decoration: const InputDecoration(
                      labelText: 'Source description',
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _sourceId,
                    decoration: InputDecoration(
                      labelText: _origin == DataOrigin.observedTelemetry
                          ? 'Source identifier (required for telemetry)'
                          : 'Source identifier (optional)',
                    ),
                    validator: (value) {
                      if (_origin == DataOrigin.observedTelemetry &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Observed telemetry requires a source ID.';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<EvidenceReliability>(
                    initialValue: _reliability,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Reliability'),
                    items: EvidenceReliability.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_humanize(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _reliability = value);
                    },
                  ),
                  TextFormField(
                    controller: _reliabilityRationale,
                    decoration: const InputDecoration(
                      labelText: 'Reliability rationale',
                    ),
                    validator: _required,
                  ),
                  DropdownButtonFormField<DataClassification>(
                    initialValue: _classification,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Classification'),
                    items: DataClassification.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_humanize(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _classification = value);
                      }
                    },
                  ),
                  if (widget.investigation.relatedEntityIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Related synthetic graph entities'),
                    ),
                    ...widget.investigation.relatedEntityIds.map(
                      (id) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(id),
                        value: _entities.contains(id),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _entities.add(id);
                          } else {
                            _entities.remove(id);
                          }
                        }),
                      ),
                    ),
                  ],
                  if (widget.investigation.relatedConnectionIds.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Related synthetic graph connections'),
                    ),
                    ...widget.investigation.relatedConnectionIds.map(
                      (id) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(id),
                        value: _connections.contains(id),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _connections.add(id);
                          } else {
                            _connections.remove(id);
                          }
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Add evidence'),
          ),
        ],
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toUtc();
    final evidence = Evidence(
      id: 'EVD-${now.microsecondsSinceEpoch}',
      investigationId: widget.investigation.id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      evidenceType: _type,
      provenance: DataProvenance(
        origin: _origin,
        source: EvidenceSource(
          description: _source.text.trim(),
          identifier:
              _sourceId.text.trim().isEmpty ? null : _sourceId.text.trim(),
        ),
        recordedAt: now,
        authorId: _origin == DataOrigin.analystCreated ? 'demo-analyst' : null,
      ),
      collectedAt: now,
      observedAt: _origin == DataOrigin.observedTelemetry ? now : null,
      reliability: _reliability,
      reliabilityRationale: _reliabilityRationale.text.trim(),
      dataClassification: _classification,
      relatedEntityIds: _entities,
      relatedConnectionIds: _connections,
    );
    Navigator.pop(context, evidence);
  }
}

class _AssessmentDialog extends StatefulWidget {
  const _AssessmentDialog({required this.evidence});

  final List<Evidence> evidence;

  @override
  State<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends State<_AssessmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rationale = TextEditingController();
  final _alternatives = TextEditingController();
  final _gapDescription = TextEditingController();
  final _gapReason = TextEditingController();
  final Map<String, String> _evidenceCues = {};
  AnalystAssessmentOutcome _outcome = AnalystAssessmentOutcome.inconclusive;

  @override
  void dispose() {
    _rationale.dispose();
    _alternatives.dispose();
    _gapDescription.dispose();
    _gapReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assess hypothesis'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AnalystAssessmentOutcome>(
                    initialValue: _outcome,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Outcome'),
                    items: AnalystAssessmentOutcome.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_humanize(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _outcome = value);
                    },
                  ),
                  TextFormField(
                    controller: _rationale,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Assessment rationale',
                      helperText: 'At least 8 characters.',
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 8
                            ? 'Provide a meaningful rationale.'
                            : null,
                  ),
                  TextFormField(
                    controller: _alternatives,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Alternative explanations (one per line)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Evidence reviewed and its relationship'),
                  ),
                  for (final item in widget.evidence)
                    DropdownButtonFormField<String>(
                      initialValue: _evidenceCues[item.id] ?? 'notReviewed',
                      isExpanded: true,
                      decoration: InputDecoration(labelText: item.title),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'notReviewed',
                          child: Text('Not reviewed'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'neutral',
                          child: Text('Reviewed; no polarity assigned'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'supporting',
                          child: Text('Supporting'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'contradicting',
                          child: Text('Contradicting'),
                        ),
                      ],
                      onChanged: (value) => setState(() =>
                          _evidenceCues[item.id] = value ?? 'notReviewed'),
                    ),
                  TextFormField(
                    controller: _gapDescription,
                    decoration: const InputDecoration(
                      labelText: 'Evidence gap (optional)',
                    ),
                  ),
                  TextFormField(
                    controller: _gapReason,
                    decoration: const InputDecoration(
                      labelText: 'Why this evidence is missing (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Save assessment'),
          ),
        ],
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cues = _evidenceCues.entries
        .where((entry) => entry.value != 'notReviewed')
        .toList(growable: false);
    final gapDescription = _gapDescription.text.trim();
    final gapReason = _gapReason.text.trim();
    if (gapDescription.isNotEmpty != gapReason.isNotEmpty) return;
    Navigator.pop(
      context,
      AssessmentDraft(
        rationale: _rationale.text.trim(),
        outcome: _outcome,
        evidenceReviewedIds: cues.map((entry) => entry.key).toList(),
        supportingEvidenceIds: [
          for (final entry in cues)
            if (entry.value == 'supporting') entry.key,
        ],
        contradictingEvidenceIds: [
          for (final entry in cues)
            if (entry.value == 'contradicting') entry.key,
        ],
        alternativeExplanations: _alternatives.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        evidenceGaps: gapDescription.isEmpty
            ? const []
            : [
                EvidenceGap(
                  description: gapDescription,
                  reason: gapReason,
                ),
              ],
      ),
    );
  }
}

class _MitreReferenceDialog extends StatefulWidget {
  const _MitreReferenceDialog();

  @override
  State<_MitreReferenceDialog> createState() => _MitreReferenceDialogState();
}

class _MitreReferenceDialogState extends State<_MitreReferenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _techniqueId = TextEditingController();
  final _name = TextEditingController();
  final _tactic = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _techniqueId.dispose();
    _name.dispose();
    _tactic.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Propose ATT&CK reference'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _techniqueId,
                  decoration: const InputDecoration(labelText: 'Technique ID'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Technique name'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _tactic,
                  decoration: const InputDecoration(labelText: 'Tactic'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                  validator: _required,
                ),
                TextFormField(
                  controller: _url,
                  decoration:
                      const InputDecoration(labelText: 'HTTPS reference URL'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a reference URL.';
                    }
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null ||
                        uri.scheme != 'https' ||
                        uri.host.isEmpty) {
                      return 'Use a valid HTTPS URL.';
                    }
                    return null;
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
                MitreAttackReference(
                  techniqueId: _techniqueId.text.trim(),
                  techniqueName: _name.text.trim(),
                  tactic: _tactic.text.trim(),
                  description: _description.text.trim(),
                  referenceUrl: _url.text.trim(),
                  catalogVersion: null,
                  proposedBy: 'demo-analyst',
                  proposedAt: DateTime.now().toUtc(),
                ),
              );
            },
            child: const Text('Propose'),
          ),
        ],
      );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

String _humanize(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _originLabel(DataOrigin value) => switch (value) {
      DataOrigin.observedTelemetry => 'Observed telemetry',
      DataOrigin.syntheticDemo => 'Synthetic demo',
      DataOrigin.analystCreated => 'Analyst-created',
      DataOrigin.aiGenerated => 'AI-generated (not accepted as evidence)',
      DataOrigin.imported => 'Imported',
    };
