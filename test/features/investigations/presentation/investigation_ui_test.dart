import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/mitre_attack_reference.dart';
import 'package:huntai/features/investigations/presentation/investigation_feature_dependencies.dart';
import 'package:huntai/features/investigations/presentation/screens/investigation_management_screen.dart';

void main() {
  group('Investigation UI controller', () {
    late InvestigationFeatureDependencies dependencies;

    setUp(() {
      dependencies = InvestigationFeatureDependencies.inMemoryDemo(
        clock: () => DateTime.utc(2025, 1, 2, 3, 4),
      );
    });

    tearDown(() => dependencies.dispose());

    test('starts empty and exposes created case summaries', () async {
      final controller = dependencies.controller;
      await controller.loadInvestigations();
      expect(controller.summaries, isEmpty);

      final created = await controller.createInvestigation(
        id: 'INV-UI-1',
        title: 'Review login pattern',
        description: 'Analyst-created case.',
        priority: InvestigationPriority.high,
      );

      expect(created, isNotNull);
      expect(controller.summaries, hasLength(1));
      expect(controller.summaries.single.investigation.id, 'INV-UI-1');
      expect(controller.summaries.single.evidenceCount, 0);
    });

    test('surfaces invalid writes and leaves summaries unchanged', () async {
      final controller = dependencies.controller;
      await controller.loadInvestigations();

      final result = await controller.createInvestigation(
        id: ' ',
        title: ' ',
        description: '',
        priority: InvestigationPriority.medium,
      );

      expect(result, isNull);
      expect(controller.errorMessage, isNotNull);
      expect(controller.summaries, isEmpty);
      expect(controller.isSubmitting, isFalse);
    });

    test('metadata edits preserve notes and lifecycle errors are visible',
        () async {
      final controller = dependencies.controller;
      final created = await controller.createInvestigation(
        id: 'INV-UI-2',
        title: 'Initial title',
        description: 'Initial description',
        priority: InvestigationPriority.medium,
      );
      await controller.openInvestigation(created!.id);
      final note = await controller.appendNote(
        investigationId: created.id,
        noteId: 'NOTE-1',
        authorId: 'analyst-1',
        content: 'Preserve this analyst context.',
      );
      expect(note, isNotNull);

      await controller.updateMetadata(
        investigationId: created.id,
        title: 'Updated title',
      );
      expect(controller.summary!.investigation.title, 'Updated title');
      expect(
        controller.summary!.investigation.analystNotes.single.text,
        'Preserve this analyst context.',
      );

      await controller.changeStatus(
        investigationId: created.id,
        status: InvestigationStatus.active,
      );
      await controller.changeStatus(
        investigationId: created.id,
        status: InvestigationStatus.closed,
      );
      final update = await controller.changePriority(
        investigationId: created.id,
        priority: InvestigationPriority.critical,
      );

      expect(update, isNull);
      expect(controller.errorMessage, contains('closed'));
      expect(
        controller.summary!.investigation.priority,
        InvestigationPriority.medium,
      );
    });

    test('rejects unknown graph IDs without changing case associations',
        () async {
      final controller = dependencies.controller;
      final created = await controller.createInvestigation(
        id: 'INV-UI-3',
        title: 'Graph association validation',
        description: '',
        priority: InvestigationPriority.low,
      );
      await controller.openInvestigation(created!.id);

      final result = await controller.associateGraphEntity(
        investigationId: created.id,
        entityId: 'not-in-the-graph-catalog',
      );

      expect(result, isNull);
      expect(controller.errorMessage, isNotNull);
      expect(controller.summary!.associatedEntityCount, 0);
    });
  });

  testWidgets('creates and opens a case through the investigation list',
      (tester) async {
    final dependencies = InvestigationFeatureDependencies.inMemoryDemo(
      clock: () => DateTime.utc(2025, 2, 3, 4, 5),
    );
    addTearDown(dependencies.dispose);
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: InvestigationManagementScreen(
              controller: dependencies.controller,
              selectedInvestigationId: selectedId,
              onSelectedInvestigationChanged: (id) =>
                  setState(() => selectedId = id),
              onOpenGraphSelection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No investigations yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-investigation')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-investigation-title')),
      'UI-created investigation',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('UI-created investigation'), findsOneWidget);

    await tester.tap(find.text('UI-created investigation'));
    await tester.pumpAndSettle();
    expect(find.text('Case metadata'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('investigation-tab-Evidence')));
    await tester.pumpAndSettle();
    expect(find.text('No evidence recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evidence form preserves provenance and notes append',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    final dependencies = InvestigationFeatureDependencies.inMemoryDemo(
      clock: () => DateTime.utc(2025, 2, 4, 5, 6),
    );
    addTearDown(dependencies.dispose);
    final investigation = await dependencies.controller.createInvestigation(
      id: 'INV-EVIDENCE-UI',
      title: 'Evidence workflow',
      description: '',
      priority: InvestigationPriority.medium,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationManagementScreen(
            controller: dependencies.controller,
            selectedInvestigationId: investigation!.id,
            onSelectedInvestigationChanged: (_) {},
            onOpenGraphSelection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('investigation-tab-Evidence')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-investigation-evidence')));
    await tester.pumpAndSettle();

    final provenanceField = find.byType(DropdownButtonFormField<DataOrigin>);
    await tester.tap(provenanceField);
    await tester.pumpAndSettle();
    final provenanceDropdown = tester.widget<DropdownButton<DataOrigin>>(
      find.byType(DropdownButton<DataOrigin>),
    );
    expect(
      provenanceDropdown.items!.map((item) => item.value),
      isNot(contains(DataOrigin.aiGenerated)),
    );
    await tester.tap(find.text('Synthetic demo').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('evidence-title')),
      'Synthetic sample record',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Test details');
    await tester.enterText(find.byType(TextFormField).at(2), 'Sample source');
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Fixture reliability only.',
    );
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Add evidence').last);
    await tester.tap(find.widgetWithText(FilledButton, 'Add evidence').last);
    await tester.pumpAndSettle();

    expect(dependencies.controller.evidence, hasLength(1));
    expect(
      dependencies.controller.evidence.single.provenance.origin,
      DataOrigin.syntheticDemo,
    );
    expect(
      dependencies.controller.evidence.single.reliabilityRationale,
      'Fixture reliability only.',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('investigation-tab-Activity')),
    );
    await tester.tap(find.byKey(const ValueKey('investigation-tab-Activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Append note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Retain analyst context.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Append'));
    await tester.pumpAndSettle();
    expect(dependencies.controller.errorMessage, isNull);
    expect(
      dependencies.controller.summary!.investigation.analystNotes,
      hasLength(1),
    );
    expect(
      dependencies.controller.summary!.investigation.analystNotes.single.text,
      'Retain analyst context.',
    );
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('hypothesis decisions append and assessments remain separate',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1000);
    final dependencies = InvestigationFeatureDependencies.inMemoryDemo(
      clock: () => DateTime.utc(2025, 4, 5, 6, 7),
    );
    addTearDown(dependencies.dispose);
    final investigation = await dependencies.controller.createInvestigation(
      id: 'INV-REVIEW-UI',
      title: 'Review workflow',
      description: '',
      priority: InvestigationPriority.high,
    );
    await dependencies.controller.associateGraphEntity(
      investigationId: investigation!.id,
      entityId: 'demo-ip',
    );
    final now = DateTime.utc(2025, 4, 5, 6, 7);
    await dependencies.controller.addEvidence(
      Evidence(
        id: 'EVD-REVIEW-1',
        investigationId: investigation.id,
        title: 'Analyst supplied evidence',
        description: 'Evidence associated with a demo graph anchor.',
        evidenceType: EvidenceType.alert,
        provenance: DataProvenance(
          origin: DataOrigin.analystCreated,
          source: EvidenceSource(description: 'Unit test fixture'),
          recordedAt: now,
          authorId: 'analyst-1',
        ),
        collectedAt: now,
        reliability: EvidenceReliability.medium,
        reliabilityRationale: 'Recorded for the UI test.',
        dataClassification: DataClassification.internal,
        relatedEntityIds: const ['demo-ip'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationManagementScreen(
            controller: dependencies.controller,
            selectedInvestigationId: investigation.id,
            onSelectedInvestigationChanged: (_) {},
            onOpenGraphSelection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('investigation-tab-Hypotheses')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('generation-cue-EVD-REVIEW-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supporting').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('generate-hypotheses')));
    await tester.pumpAndSettle();
    expect(dependencies.controller.hypotheses, hasLength(1));

    final startReview = find.text('Start hypothesis review');
    await tester.ensureVisible(startReview);
    await tester.pumpAndSettle();
    await tester.tap(startReview);
    await tester.pumpAndSettle();
    final accept = find.text('Accept for continued investigation');
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Continue validating the observed pattern.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Append decision'));
    await tester.pumpAndSettle();
    expect(
      dependencies.controller.hypotheses.single.status,
      HypothesisStatus.acceptedForInvestigation,
    );
    expect(
      dependencies.controller.decisionsByHypothesis.values.single,
      hasLength(1),
    );

    await tester.tap(
      find.byKey(const ValueKey('investigation-tab-Assessments')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add assessment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'The selected evidence partially supports this lead.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save assessment'));
    await tester.pumpAndSettle();
    expect(
      dependencies.controller.assessmentsByHypothesis.values.single,
      hasLength(1),
    );
    expect(
      dependencies.controller.hypotheses.single.status,
      HypothesisStatus.acceptedForInvestigation,
    );
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('closed investigations cannot verify ATT&CK references',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    final dependencies = InvestigationFeatureDependencies.inMemoryDemo(
      clock: () => DateTime.utc(2025, 5, 6, 7, 8),
    );
    addTearDown(dependencies.dispose);
    final investigation =
        await dependencies.workflowService.createInvestigation(
      id: 'INV-CLOSED-ATTACK',
      title: 'Closed mapping case',
      description: '',
    );
    final timestamp = DateTime.utc(2025, 5, 6, 7, 8);
    await dependencies.workflowService.addHypotheses(
      investigationId: investigation.id,
      hypotheses: [
        Hypothesis(
          id: 'HYP-ATTACK-UI',
          investigationId: investigation.id,
          title: 'Candidate mapping',
          explanation: 'A test candidate, not a finding.',
          confidence: .5,
          confidenceExplanation: 'Uncalibrated test heuristic.',
          status: HypothesisStatus.candidate,
          generatedAt: timestamp,
          provenance: DataProvenance(
            origin: DataOrigin.analystCreated,
            source: EvidenceSource(description: 'UI test input'),
            authorId: 'analyst-1',
            recordedAt: timestamp,
          ),
        ),
      ],
    );
    await dependencies.workflowService.addProposedMitreReference(
      hypothesisId: 'HYP-ATTACK-UI',
      analystId: 'analyst-1',
      reference: MitreAttackReference(
        techniqueId: 'T1059',
        techniqueName: 'Test-only technique name',
        tactic: 'Test-only tactic',
        description: 'Test reference; not evidence of technique use.',
        referenceUrl: 'https://example.test/technique',
      ),
    );
    await dependencies.workflowService.changeStatus(
      investigationId: investigation.id,
      status: InvestigationStatus.active,
    );
    await dependencies.workflowService.closeInvestigation(investigation.id);
    await dependencies.controller.openInvestigation(investigation.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationManagementScreen(
            controller: dependencies.controller,
            selectedInvestigationId: investigation.id,
            onSelectedInvestigationChanged: (_) {},
            onOpenGraphSelection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('investigation-tab-ATT&CK')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T1059 · Test-only technique name'));
    await tester.pumpAndSettle();

    final verifyButton = tester.widget<OutlinedButton>(find.widgetWithText(
      OutlinedButton,
      'Verify reference',
    ));
    expect(verifyButton.onPressed, isNull);
    expect(find.text('Remove proposal'), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('investigation workspace fits required responsive widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    final dependencies = InvestigationFeatureDependencies.inMemoryDemo(
      clock: () => DateTime.utc(2025, 3, 4, 5, 6),
    );
    addTearDown(dependencies.dispose);
    final created = await dependencies.controller.createInvestigation(
      id: 'INV-RESPONSIVE',
      title: 'Responsive investigation',
      description: 'Workspace layout test.',
      priority: InvestigationPriority.medium,
    );

    for (final width in [390.0, 768.0, 1199.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationManagementScreen(
              controller: dependencies.controller,
              selectedInvestigationId: created!.id,
              onSelectedInvestigationChanged: (_) {},
              onOpenGraphSelection: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Responsive investigation'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
      final activityTab =
          find.byKey(const ValueKey('investigation-tab-Activity'));
      await tester.ensureVisible(activityTab);
      await tester.tap(activityTab);
      await tester.pumpAndSettle();
      expect(find.text('Analyst activity'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'activity width $width');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
