import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/analyst_decision.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/mitre_attack_reference.dart';
import '../../domain/validation/investigation_reference_validator.dart';
import '../../domain/validation/hypothesis_status_transition_policy.dart';
import '../datasources/in_memory_investigation_data_source.dart';
import '../exceptions/investigation_repository_exception.dart';
import 'analyst_decision_repository.dart';
import 'evidence_repository.dart';
import 'hypothesis_repository.dart';
import 'hypothesis_assessment_repository.dart';
import 'investigation_repository.dart';

class _RepositorySnapshotValidator {
  _RepositorySnapshotValidator(this._dataSource);

  final InMemoryInvestigationDataSource _dataSource;

  List<Evidence> evidenceFor(String investigationId) =>
      _dataSource.evidence.values
          .where((item) => item.investigationId == investigationId)
          .toList(growable: false);

  List<Hypothesis> hypothesesFor(String investigationId) =>
      _dataSource.hypotheses.values
          .where((item) => item.investigationId == investigationId)
          .toList(growable: false);

  void validateStored(Investigation investigation) {
    try {
      validate(
        investigation,
        evidence: evidenceFor(investigation.id),
        hypotheses: hypothesesFor(investigation.id),
      );
    } on InvalidRelationshipException catch (error) {
      throw InconsistentRepositoryStateException(
        'Stored investigation "${investigation.id}" is inconsistent: '
        '${error.message}',
      );
    }
  }

  void validate(
    Investigation investigation, {
    required Iterable<Evidence> evidence,
    required Iterable<Hypothesis> hypotheses,
  }) {
    try {
      InvestigationReferenceValidator.validateSnapshot(
        investigation: investigation,
        availableEntityIds: _dataSource.availableEntityIds,
        availableConnectionIds: _dataSource.availableConnectionIds,
        evidence: evidence,
        hypotheses: hypotheses,
      );
    } on ArgumentError catch (error) {
      throw InvalidRelationshipException(error.message.toString());
    }
  }
}

class InMemoryInvestigationRepository implements InvestigationRepository {
  InMemoryInvestigationRepository(this._dataSource)
      : _snapshotValidator = _RepositorySnapshotValidator(_dataSource);

  final InMemoryInvestigationDataSource _dataSource;
  final _RepositorySnapshotValidator _snapshotValidator;

  @override
  Future<void> create(Investigation investigation) async {
    if (_dataSource.investigations.containsKey(investigation.id)) {
      throw DuplicateRecordException(
        recordType: 'Investigation',
        recordId: investigation.id,
      );
    }
    _snapshotValidator.validate(
      investigation,
      evidence: _snapshotValidator.evidenceFor(investigation.id),
      hypotheses: _snapshotValidator.hypothesesFor(investigation.id),
    );
    _dataSource.commitInvestigation(investigation);
  }

  @override
  Future<Investigation> getById(String id) async {
    final recordId = _requestedId(id, 'investigation');
    final investigation = _dataSource.investigations[recordId];
    if (investigation == null) {
      throw RecordNotFoundException(
        recordType: 'Investigation',
        recordId: recordId,
      );
    }
    return investigation;
  }

  @override
  Future<List<Investigation>> getAll() async =>
      List<Investigation>.unmodifiable(_dataSource.investigations.values);

  @override
  Future<List<Investigation>> getByStatus(InvestigationStatus status) async =>
      List<Investigation>.unmodifiable(
        _dataSource.investigations.values
            .where((item) => item.status == status),
      );

  @override
  Future<List<Investigation>> getByPriority(
    InvestigationPriority priority,
  ) async =>
      List<Investigation>.unmodifiable(_dataSource.investigations.values.where(
        (item) => item.priority == priority,
      ));

  @override
  Future<Investigation> update(Investigation investigation) async {
    final current = _dataSource.investigations[investigation.id];
    if (current == null) {
      throw RecordNotFoundException(
        recordType: 'Investigation',
        recordId: investigation.id,
      );
    }
    _snapshotValidator.validateStored(current);
    _validateUpdate(current, investigation);
    try {
      _snapshotValidator.validate(
        investigation,
        evidence: _snapshotValidator.evidenceFor(investigation.id),
        hypotheses: _snapshotValidator.hypothesesFor(investigation.id),
      );
    } on InvalidRelationshipException catch (error) {
      throw InvalidUpdateException(error.message);
    }
    _dataSource.commitInvestigation(investigation);
    return investigation;
  }

  @override
  Future<void> deleteById(String id) async {
    final recordId = _requestedId(id, 'investigation');
    final investigation = _dataSource.investigations[recordId];
    if (investigation == null) {
      throw RecordNotFoundException(
        recordType: 'Investigation',
        recordId: recordId,
      );
    }
    _snapshotValidator.validateStored(investigation);
    final hasEvidence = _dataSource.evidence.values
        .any((item) => item.investigationId == recordId);
    final hasHypotheses = _dataSource.hypotheses.values
        .any((item) => item.investigationId == recordId);
    final hasDecisions = _dataSource.decisions.values
        .any((item) => item.investigationId == recordId);
    if (hasEvidence || hasHypotheses || hasDecisions) {
      throw UnsafeDeletionException(
        'Investigation "$recordId" has related evidence, hypotheses, or '
        'decisions; no records were deleted.',
      );
    }
    _dataSource.deleteInvestigation(recordId);
  }

  void _validateUpdate(Investigation current, Investigation updated) {
    if (current.id != updated.id) {
      throw const InvalidUpdateException(
        'An investigation ID cannot be changed.',
      );
    }
    if (!current.createdAt.isAtSameMomentAs(updated.createdAt)) {
      throw const InvalidUpdateException('createdAt cannot be changed.');
    }
    if (updated.updatedAt.isBefore(current.updatedAt)) {
      throw const InvalidUpdateException('updatedAt cannot move backwards.');
    }
    _requireRetained(
      current.relatedEntityIds,
      updated.relatedEntityIds,
      'Related entity references cannot be removed.',
    );
    _requireRetained(
      current.relatedConnectionIds,
      updated.relatedConnectionIds,
      'Related connection references cannot be removed.',
    );
    _requireRetained(
      current.evidenceIds,
      updated.evidenceIds,
      'Evidence references cannot be removed.',
    );
    _requireRetained(
      current.hypothesisIds,
      updated.hypothesisIds,
      'Hypothesis references cannot be removed.',
    );
    if (updated.analystNotes.length < current.analystNotes.length) {
      throw const InvalidUpdateException(
        'Existing analyst notes cannot be removed.',
      );
    }
    for (var index = 0; index < current.analystNotes.length; index++) {
      if (!_sameNote(
          current.analystNotes[index], updated.analystNotes[index])) {
        throw const InvalidUpdateException(
          'Existing analyst notes cannot be changed or reordered.',
        );
      }
    }
  }

  void _requireRetained(
    List<String> existing,
    List<String> updated,
    String message,
  ) {
    if (!updated.toSet().containsAll(existing)) {
      throw InvalidUpdateException(message);
    }
  }

  bool _sameNote(AnalystNote first, AnalystNote second) =>
      first.id == second.id &&
      first.authorId == second.authorId &&
      first.text == second.text &&
      first.timestamp.isAtSameMomentAs(second.timestamp);
}

class InMemoryEvidenceRepository implements EvidenceRepository {
  InMemoryEvidenceRepository(this._dataSource)
      : _snapshotValidator = _RepositorySnapshotValidator(_dataSource);

  final InMemoryInvestigationDataSource _dataSource;
  final _RepositorySnapshotValidator _snapshotValidator;

  @override
  Future<void> add(Evidence evidence) async {
    if (_dataSource.evidence.containsKey(evidence.id)) {
      throw DuplicateRecordException(
        recordType: 'Evidence',
        recordId: evidence.id,
      );
    }
    final investigation = _dataSource.investigations[evidence.investigationId];
    if (investigation == null) {
      throw InvalidRelationshipException(
        'Evidence "${evidence.id}" references nonexistent investigation '
        '"${evidence.investigationId}".',
      );
    }

    _snapshotValidator.validateStored(investigation);
    final updatedInvestigation = _withEvidenceLink(
      investigation,
      evidence.id,
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    final prospectiveEvidence = [
      ..._snapshotValidator.evidenceFor(evidence.investigationId),
      evidence,
    ];
    _snapshotValidator.validate(
      updatedInvestigation,
      evidence: prospectiveEvidence,
      hypotheses: _snapshotValidator.hypothesesFor(evidence.investigationId),
    );
    _dataSource.commitEvidence(
      investigation: updatedInvestigation,
      evidence: evidence,
    );
  }

  @override
  Future<Evidence> getById(String id) async {
    final recordId = _requestedId(id, 'evidence');
    final evidence = _dataSource.evidence[recordId];
    if (evidence == null) {
      throw RecordNotFoundException(recordType: 'Evidence', recordId: recordId);
    }
    return evidence;
  }

  @override
  Future<List<Evidence>> getByInvestigationId(String investigationId) async {
    final id = _requestedId(investigationId, 'investigation');
    if (!_dataSource.investigations.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Investigation', recordId: id);
    }
    return List<Evidence>.unmodifiable(_snapshotValidator.evidenceFor(id));
  }

  @override
  Future<List<Evidence>> getAllForInvestigation(
    String investigationId,
  ) =>
      getByInvestigationId(investigationId);
}

class InMemoryHypothesisRepository implements HypothesisRepository {
  InMemoryHypothesisRepository(this._dataSource)
      : _snapshotValidator = _RepositorySnapshotValidator(_dataSource);

  final InMemoryInvestigationDataSource _dataSource;
  final _RepositorySnapshotValidator _snapshotValidator;

  @override
  Future<void> add(Hypothesis hypothesis) => addAll([hypothesis]);

  @override
  Future<void> addAll(Iterable<Hypothesis> hypotheses) async {
    final batch = List<Hypothesis>.of(hypotheses);
    if (batch.isEmpty) return;

    final investigationId = batch.first.investigationId;
    final batchIds = <String>{};
    for (final hypothesis in batch) {
      if (hypothesis.investigationId != investigationId) {
        throw const InvalidRelationshipException(
          'A hypothesis batch must belong to one investigation.',
        );
      }
      if (hypothesis.mitreAttackReferences.isNotEmpty) {
        throw const InvalidRelationshipException(
          'ATT&CK references must be associated through the analyst workflow.',
        );
      }
      if (!batchIds.add(hypothesis.id) ||
          _dataSource.hypotheses.containsKey(hypothesis.id)) {
        throw DuplicateRecordException(
          recordType: 'Hypothesis',
          recordId: hypothesis.id,
        );
      }
    }
    final investigation = _dataSource.investigations[investigationId];
    if (investigation == null) {
      throw InvalidRelationshipException(
        'Hypothesis batch references nonexistent investigation '
        '"$investigationId".',
      );
    }
    _snapshotValidator.validateStored(investigation);

    final updatedInvestigation = _withHypothesisLinks(
      investigation,
      batch.map((item) => item.id),
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    final prospectiveHypotheses = [
      ..._snapshotValidator.hypothesesFor(investigationId),
      ...batch,
    ];
    _snapshotValidator.validate(
      updatedInvestigation,
      evidence: _snapshotValidator.evidenceFor(investigationId),
      hypotheses: prospectiveHypotheses,
    );
    _dataSource.commitHypotheses(
      investigation: updatedInvestigation,
      hypotheses: batch,
    );
  }

  @override
  Future<Hypothesis> getById(String id) async {
    final recordId = _requestedId(id, 'hypothesis');
    final hypothesis = _dataSource.hypotheses[recordId];
    if (hypothesis == null) {
      throw RecordNotFoundException(
        recordType: 'Hypothesis',
        recordId: recordId,
      );
    }
    return hypothesis;
  }

  @override
  Future<List<Hypothesis>> getByInvestigationId(
    String investigationId,
  ) async {
    final id = _requestedId(investigationId, 'investigation');
    if (!_dataSource.investigations.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Investigation', recordId: id);
    }
    return List<Hypothesis>.unmodifiable(_snapshotValidator.hypothesesFor(id));
  }

  @override
  Future<Hypothesis> updateReviewStatus({
    required String hypothesisId,
    required HypothesisStatus status,
    required DateTime reviewedAt,
  }) async {
    final id = _requestedId(hypothesisId, 'hypothesis');
    final current = _dataSource.hypotheses[id];
    if (current == null) {
      throw RecordNotFoundException(recordType: 'Hypothesis', recordId: id);
    }
    final investigation = _dataSource.investigations[current.investigationId];
    if (investigation == null) {
      throw InconsistentRepositoryStateException(
        'Hypothesis "$id" references a missing investigation.',
      );
    }
    _snapshotValidator.validateStored(investigation);
    if (!HypothesisStatusTransitionPolicy.allows(current.status, status)) {
      throw InvalidUpdateException(
        'Hypothesis status cannot transition from ${current.status.name} '
        'to ${status.name}.',
      );
    }
    final utcReviewedAt = reviewedAt.toUtc();
    if (utcReviewedAt.isBefore(current.generatedAt) ||
        (current.reviewedAt != null &&
            utcReviewedAt.isBefore(current.reviewedAt!))) {
      throw const InvalidUpdateException(
        'reviewedAt cannot precede generation or the previous review.',
      );
    }

    final updated = _withReviewStatus(current, status, utcReviewedAt);
    final prospectiveHypotheses = _snapshotValidator
        .hypothesesFor(current.investigationId)
        .map((item) => item.id == id ? updated : item)
        .toList(growable: false);
    _snapshotValidator.validate(
      investigation,
      evidence: _snapshotValidator.evidenceFor(current.investigationId),
      hypotheses: prospectiveHypotheses,
    );
    final updatedInvestigation = _withUpdatedAt(
      investigation,
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    _dataSource.commitHypothesis(
      investigation: updatedInvestigation,
      hypothesis: updated,
    );
    return updated;
  }

  @override
  Future<Hypothesis> addMitreAttackReference({
    required String hypothesisId,
    required MitreAttackReference reference,
  }) async {
    final current = await _getForReferenceUpdate(hypothesisId);
    if (reference.verificationMetadata != null) {
      throw const InvalidUpdateException(
        'A reference must be proposed before verification metadata is added.',
      );
    }
    if (!reference.isProposed) {
      throw const InvalidUpdateException(
        'A proposed reference must identify its analyst and proposal time.',
      );
    }
    if (current.mitreAttackReferences
        .any((item) => item.techniqueId == reference.techniqueId)) {
      throw DuplicateRecordException(
        recordType: 'MITRE ATT&CK reference',
        recordId: reference.techniqueId,
      );
    }
    return _saveMitreReferences(
      current,
      [...current.mitreAttackReferences, reference],
    );
  }

  @override
  Future<Hypothesis> removeProposedMitreAttackReference({
    required String hypothesisId,
    required String techniqueId,
  }) async {
    final current = await _getForReferenceUpdate(hypothesisId);
    final matching = current.mitreAttackReferences
        .where((item) => item.techniqueId == techniqueId);
    if (matching.isEmpty) {
      throw RecordNotFoundException(
        recordType: 'MITRE ATT&CK reference',
        recordId: techniqueId,
      );
    }
    if (!matching.first.isProposed) {
      throw InvalidUpdateException(
        'Only proposed, unverified reference "$techniqueId" may be removed.',
      );
    }
    return _saveMitreReferences(
      current,
      current.mitreAttackReferences
          .where((item) => item.techniqueId != techniqueId),
    );
  }

  @override
  Future<Hypothesis> applyVerifiedMitreAttackReference({
    required String hypothesisId,
    required MitreAttackReference reference,
  }) async {
    final current = await _getForReferenceUpdate(hypothesisId);
    final matching = current.mitreAttackReferences
        .where((item) => item.techniqueId == reference.techniqueId);
    if (matching.isEmpty) {
      throw RecordNotFoundException(
        recordType: 'MITRE ATT&CK reference',
        recordId: reference.techniqueId,
      );
    }
    final existing = matching.first;
    final metadata = reference.verificationMetadata;
    if (!existing.isProposed ||
        metadata == null ||
        metadata.sourceUrl == null ||
        !_isOfficialAttackUrl(metadata.sourceUrl!) ||
        !_isOfficialAttackUrl(reference.referenceUrl) ||
        (metadata.catalogVersion != null &&
            reference.catalogVersion != null &&
            metadata.catalogVersion != reference.catalogVersion) ||
        !_sameMitreReferenceExceptCatalogAndVerification(
          existing,
          reference,
        )) {
      throw const InvalidUpdateException(
        'Verification must preserve the proposed reference identity and '
        'must supply verification metadata.',
      );
    }
    return _saveMitreReferences(
      current,
      current.mitreAttackReferences.map(
        (item) => item.techniqueId == reference.techniqueId ? reference : item,
      ),
    );
  }

  Future<Hypothesis> _getForReferenceUpdate(String hypothesisId) async {
    final id = _requestedId(hypothesisId, 'hypothesis');
    final current = _dataSource.hypotheses[id];
    if (current == null) {
      throw RecordNotFoundException(recordType: 'Hypothesis', recordId: id);
    }
    final investigation = _dataSource.investigations[current.investigationId];
    if (investigation == null) {
      throw InconsistentRepositoryStateException(
        'Hypothesis "$id" references a missing investigation.',
      );
    }
    _snapshotValidator.validateStored(investigation);
    return current;
  }

  Future<Hypothesis> _saveMitreReferences(
    Hypothesis current,
    Iterable<MitreAttackReference> references,
  ) async {
    final investigation = _dataSource.investigations[current.investigationId];
    if (investigation == null) {
      throw InconsistentRepositoryStateException(
        'Hypothesis "${current.id}" references a missing investigation.',
      );
    }
    final updated = _withMitreAttackReferences(current, references);
    final prospectiveHypotheses = _snapshotValidator
        .hypothesesFor(current.investigationId)
        .map((item) => item.id == current.id ? updated : item)
        .toList(growable: false);
    _snapshotValidator.validate(
      investigation,
      evidence: _snapshotValidator.evidenceFor(current.investigationId),
      hypotheses: prospectiveHypotheses,
    );
    final updatedInvestigation = _withUpdatedAt(
      investigation,
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    _dataSource.commitHypothesis(
      investigation: updatedInvestigation,
      hypothesis: updated,
    );
    return updated;
  }
}

class InMemoryAnalystDecisionRepository implements AnalystDecisionRepository {
  InMemoryAnalystDecisionRepository(this._dataSource)
      : _snapshotValidator = _RepositorySnapshotValidator(_dataSource);

  final InMemoryInvestigationDataSource _dataSource;
  final _RepositorySnapshotValidator _snapshotValidator;

  @override
  Future<void> append(AnalystDecision decision) async {
    if (_dataSource.decisions.containsKey(decision.id)) {
      throw DuplicateRecordException(
        recordType: 'Analyst decision',
        recordId: decision.id,
      );
    }
    final investigation = _dataSource.investigations[decision.investigationId];
    if (investigation == null) {
      throw InvalidRelationshipException(
        'Decision "${decision.id}" references nonexistent investigation '
        '"${decision.investigationId}".',
      );
    }
    final hypothesis = _dataSource.hypotheses[decision.hypothesisId];
    if (hypothesis == null) {
      throw InvalidRelationshipException(
        'Decision "${decision.id}" references nonexistent hypothesis '
        '"${decision.hypothesisId}".',
      );
    }
    _snapshotValidator.validateStored(investigation);
    try {
      InvestigationReferenceValidator.validateDecision(
        investigation: investigation,
        hypothesis: hypothesis,
        decision: decision,
      );
    } on ArgumentError catch (error) {
      throw InvalidRelationshipException(error.message.toString());
    }

    final updatedInvestigation = _withUpdatedAt(
      investigation,
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    _dataSource.commitDecision(
      investigation: updatedInvestigation,
      decision: decision,
    );
  }

  @override
  Future<void> appendReview({
    required AnalystDecision decision,
    required Hypothesis updatedHypothesis,
  }) async {
    if (_dataSource.decisions.containsKey(decision.id)) {
      throw DuplicateRecordException(
        recordType: 'Analyst decision',
        recordId: decision.id,
      );
    }
    final investigation = _dataSource.investigations[decision.investigationId];
    if (investigation == null) {
      throw InvalidRelationshipException(
        'Decision "${decision.id}" references nonexistent investigation '
        '"${decision.investigationId}".',
      );
    }
    final currentHypothesis = _dataSource.hypotheses[decision.hypothesisId];
    if (currentHypothesis == null) {
      throw InvalidRelationshipException(
        'Decision "${decision.id}" references nonexistent hypothesis '
        '"${decision.hypothesisId}".',
      );
    }
    _snapshotValidator.validateStored(investigation);

    if (updatedHypothesis.id != currentHypothesis.id ||
        updatedHypothesis.investigationId != investigation.id ||
        decision.hypothesisId != updatedHypothesis.id ||
        decision.investigationId != updatedHypothesis.investigationId) {
      throw const InvalidRelationshipException(
        'Review decision and updated hypothesis must reference the same '
        'investigation and hypothesis.',
      );
    }
    if (!_sameHypothesisExceptReview(currentHypothesis, updatedHypothesis)) {
      throw const InvalidUpdateException(
        'A review transaction may only change hypothesis status and review '
        'time.',
      );
    }
    if (!HypothesisStatusTransitionPolicy.allows(
      currentHypothesis.status,
      updatedHypothesis.status,
    )) {
      throw InvalidUpdateException(
        'Hypothesis status cannot transition from '
        '${currentHypothesis.status.name} to '
        '${updatedHypothesis.status.name}.',
      );
    }
    final reviewedAt = updatedHypothesis.reviewedAt;
    if (reviewedAt == null ||
        reviewedAt.isBefore(currentHypothesis.generatedAt) ||
        (currentHypothesis.reviewedAt != null &&
            reviewedAt.isBefore(currentHypothesis.reviewedAt!)) ||
        !reviewedAt.isAtSameMomentAs(decision.decidedAt)) {
      throw const InvalidUpdateException(
        'Decision time must match a valid, non-regressing hypothesis review '
        'time.',
      );
    }
    if (HypothesisStatusTransitionPolicy.statusForDecision(decision.decision) !=
        updatedHypothesis.status) {
      throw const InvalidRelationshipException(
        'The updated hypothesis status does not match the analyst decision.',
      );
    }

    try {
      InvestigationReferenceValidator.validateDecision(
        investigation: investigation,
        hypothesis: updatedHypothesis,
        decision: decision,
      );
    } on ArgumentError catch (error) {
      throw InvalidRelationshipException(error.message.toString());
    }
    final prospectiveHypotheses = _snapshotValidator
        .hypothesesFor(investigation.id)
        .map((item) =>
            item.id == updatedHypothesis.id ? updatedHypothesis : item)
        .toList(growable: false);
    _snapshotValidator.validate(
      investigation,
      evidence: _snapshotValidator.evidenceFor(investigation.id),
      hypotheses: prospectiveHypotheses,
    );

    final updatedInvestigation = _withUpdatedAt(
      investigation,
      _dataSource.nextUpdatedAt(investigation.updatedAt),
    );
    _dataSource.commitHypothesisReview(
      investigation: updatedInvestigation,
      hypothesis: updatedHypothesis,
      decision: decision,
    );
  }

  @override
  Future<List<AnalystDecision>> getHistoryForHypothesis(
    String hypothesisId,
  ) async {
    final id = _requestedId(hypothesisId, 'hypothesis');
    if (!_dataSource.hypotheses.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Hypothesis', recordId: id);
    }
    return List<AnalystDecision>.unmodifiable(
      _dataSource.decisions.values.where((item) => item.hypothesisId == id),
    );
  }

  @override
  Future<List<AnalystDecision>> getHistoryForInvestigation(
    String investigationId,
  ) async {
    final id = _requestedId(investigationId, 'investigation');
    if (!_dataSource.investigations.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Investigation', recordId: id);
    }
    return List<AnalystDecision>.unmodifiable(
      _dataSource.decisions.values.where((item) => item.investigationId == id),
    );
  }

  @override
  Future<AnalystDecision?> getLatestForHypothesis(
    String hypothesisId,
  ) async {
    final history = await getHistoryForHypothesis(hypothesisId);
    return history.isEmpty ? null : history.last;
  }
}

class InMemoryAnalystAssessmentRepository
    implements AnalystAssessmentRepository {
  InMemoryAnalystAssessmentRepository(this._dataSource);

  final InMemoryInvestigationDataSource _dataSource;

  @override
  Future<void> append(AnalystAssessment assessment) async {
    if (_dataSource.assessments.containsKey(assessment.id)) {
      throw DuplicateRecordException(
        recordType: 'Hypothesis assessment',
        recordId: assessment.id,
      );
    }
    if (!_dataSource.investigations.containsKey(assessment.investigationId)) {
      throw InvalidRelationshipException(
        'Assessment "${assessment.id}" references nonexistent investigation '
        '"${assessment.investigationId}".',
      );
    }
    final hypothesis = _dataSource.hypotheses[assessment.hypothesisId];
    if (hypothesis == null ||
        hypothesis.investigationId != assessment.investigationId) {
      throw InvalidRelationshipException(
        'Assessment "${assessment.id}" must reference a hypothesis in the '
        'same investigation.',
      );
    }
    final evidenceIds = {
      ...assessment.evidenceReviewedIds,
      ...assessment.supportingEvidenceIds,
      ...assessment.contradictingEvidenceIds,
    };
    for (final evidenceId in evidenceIds) {
      final evidence = _dataSource.evidence[evidenceId];
      if (evidence == null ||
          evidence.investigationId != assessment.investigationId) {
        throw InvalidRelationshipException(
          'Assessment "${assessment.id}" references missing or '
          'cross-investigation evidence "$evidenceId".',
        );
      }
    }
    _dataSource.commitAssessment(assessment);
  }

  @override
  Future<AnalystAssessment> getById(String id) async {
    final recordId = _requestedId(id, 'hypothesis assessment');
    final assessment = _dataSource.assessments[recordId];
    if (assessment == null) {
      throw RecordNotFoundException(
        recordType: 'Hypothesis assessment',
        recordId: recordId,
      );
    }
    return assessment;
  }

  @override
  Future<List<AnalystAssessment>> getByHypothesisId(
    String hypothesisId,
  ) async {
    final id = _requestedId(hypothesisId, 'hypothesis');
    if (!_dataSource.hypotheses.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Hypothesis', recordId: id);
    }
    return _assessmentHistory(
      _dataSource.assessments.values.where((item) => item.hypothesisId == id),
    );
  }

  @override
  Future<List<AnalystAssessment>> getByInvestigationId(
    String investigationId,
  ) async {
    final id = _requestedId(investigationId, 'investigation');
    if (!_dataSource.investigations.containsKey(id)) {
      throw RecordNotFoundException(recordType: 'Investigation', recordId: id);
    }
    return _assessmentHistory(
      _dataSource.assessments.values
          .where((item) => item.investigationId == id),
    );
  }

  List<AnalystAssessment> _assessmentHistory(
    Iterable<AnalystAssessment> assessments,
  ) {
    final result = assessments.toList()
      ..sort((first, second) {
        final byTime = first.assessedAt.compareTo(second.assessedAt);
        return byTime != 0 ? byTime : first.id.compareTo(second.id);
      });
    return List<AnalystAssessment>.unmodifiable(result);
  }
}

typedef InMemoryHypothesisAssessmentRepository
    = InMemoryAnalystAssessmentRepository;

bool _sameHypothesisExceptReview(Hypothesis first, Hypothesis second) =>
    first.id == second.id &&
    first.investigationId == second.investigationId &&
    first.title == second.title &&
    first.explanation == second.explanation &&
    _sameStrings(first.supportingEvidenceIds, second.supportingEvidenceIds) &&
    _sameStrings(
      first.contradictingEvidenceIds,
      second.contradictingEvidenceIds,
    ) &&
    _sameStrings(first.relatedEntityIds, second.relatedEntityIds) &&
    _sameStrings(first.relatedConnectionIds, second.relatedConnectionIds) &&
    first.confidence == second.confidence &&
    first.confidenceExplanation == second.confidenceExplanation &&
    first.generatedAt.isAtSameMomentAs(second.generatedAt) &&
    _sameStrings(
        first.alternativeExplanations, second.alternativeExplanations) &&
    _sameEvidenceGaps(first.evidenceGaps, second.evidenceGaps) &&
    _sameMitreReferences(
      first.mitreAttackReferences,
      second.mitreAttackReferences,
    ) &&
    _sameGenerationMetadata(
      first.generationMetadata,
      second.generationMetadata,
    ) &&
    _sameProvenance(first.provenance, second.provenance);

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _sameEvidenceGaps(List<EvidenceGap> first, List<EvidenceGap> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final a = first[index];
    final b = second[index];
    if (a.description != b.description ||
        a.reason != b.reason ||
        a.suggestedSource != b.suggestedSource) {
      return false;
    }
  }
  return true;
}

bool _sameMitreReferences(
  List<MitreAttackReference> first,
  List<MitreAttackReference> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final a = first[index];
    final b = second[index];
    if (a.techniqueId != b.techniqueId ||
        a.techniqueName != b.techniqueName ||
        a.tactic != b.tactic ||
        a.description != b.description ||
        a.referenceUrl != b.referenceUrl ||
        a.catalogVersion != b.catalogVersion ||
        a.proposedBy != b.proposedBy ||
        a.proposedAt != b.proposedAt ||
        !_sameMitreVerification(
            a.verificationMetadata, b.verificationMetadata)) {
      return false;
    }
  }
  return true;
}

bool _sameMitreVerification(
  MitreVerificationMetadata? first,
  MitreVerificationMetadata? second,
) =>
    first == null
        ? second == null
        : second != null &&
            first.verifiedBy == second.verifiedBy &&
            first.verifiedAt.isAtSameMomentAs(second.verifiedAt) &&
            first.catalogVersion == second.catalogVersion &&
            first.sourceUrl == second.sourceUrl;

bool _sameMitreReferenceExceptCatalogAndVerification(
  MitreAttackReference first,
  MitreAttackReference second,
) =>
    first.techniqueId == second.techniqueId &&
    first.techniqueName == second.techniqueName &&
    first.proposedBy == second.proposedBy &&
    first.proposedAt != null &&
    second.proposedAt != null &&
    first.proposedAt!.isAtSameMomentAs(second.proposedAt!);

bool _isOfficialAttackUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme.toLowerCase() == 'https' &&
      uri.host.toLowerCase() == 'attack.mitre.org';
}

bool _sameGenerationMetadata(
  GenerationMetadata? first,
  GenerationMetadata? second,
) =>
    first == null
        ? second == null
        : second != null &&
            first.method == second.method &&
            first.ruleSetVersion == second.ruleSetVersion;

bool _sameProvenance(DataProvenance first, DataProvenance second) =>
    first.origin == second.origin &&
    first.source.description == second.source.description &&
    first.source.identifier == second.source.identifier &&
    first.authorId == second.authorId &&
    first.recordedAt.isAtSameMomentAs(second.recordedAt) &&
    first.generatorName == second.generatorName &&
    first.generatorVersion == second.generatorVersion;

Investigation _withEvidenceLink(
  Investigation investigation,
  String evidenceId,
  DateTime updatedAt,
) =>
    Investigation(
      id: investigation.id,
      title: investigation.title,
      description: investigation.description,
      status: investigation.status,
      priority: investigation.priority,
      createdAt: investigation.createdAt,
      updatedAt: updatedAt,
      assignedAnalystId: investigation.assignedAnalystId,
      relatedEntityIds: investigation.relatedEntityIds,
      relatedConnectionIds: investigation.relatedConnectionIds,
      evidenceIds: [...investigation.evidenceIds, evidenceId],
      hypothesisIds: investigation.hypothesisIds,
      analystNotes: investigation.analystNotes,
    );

Investigation _withHypothesisLinks(
  Investigation investigation,
  Iterable<String> hypothesisIds,
  DateTime updatedAt,
) =>
    Investigation(
      id: investigation.id,
      title: investigation.title,
      description: investigation.description,
      status: investigation.status,
      priority: investigation.priority,
      createdAt: investigation.createdAt,
      updatedAt: updatedAt,
      assignedAnalystId: investigation.assignedAnalystId,
      relatedEntityIds: investigation.relatedEntityIds,
      relatedConnectionIds: investigation.relatedConnectionIds,
      evidenceIds: investigation.evidenceIds,
      hypothesisIds: [...investigation.hypothesisIds, ...hypothesisIds],
      analystNotes: investigation.analystNotes,
    );

Investigation _withUpdatedAt(
  Investigation investigation,
  DateTime updatedAt,
) =>
    Investigation(
      id: investigation.id,
      title: investigation.title,
      description: investigation.description,
      status: investigation.status,
      priority: investigation.priority,
      createdAt: investigation.createdAt,
      updatedAt: updatedAt,
      assignedAnalystId: investigation.assignedAnalystId,
      relatedEntityIds: investigation.relatedEntityIds,
      relatedConnectionIds: investigation.relatedConnectionIds,
      evidenceIds: investigation.evidenceIds,
      hypothesisIds: investigation.hypothesisIds,
      analystNotes: investigation.analystNotes,
    );

Hypothesis _withReviewStatus(
  Hypothesis hypothesis,
  HypothesisStatus status,
  DateTime reviewedAt,
) =>
    Hypothesis(
      id: hypothesis.id,
      investigationId: hypothesis.investigationId,
      title: hypothesis.title,
      explanation: hypothesis.explanation,
      supportingEvidenceIds: hypothesis.supportingEvidenceIds,
      contradictingEvidenceIds: hypothesis.contradictingEvidenceIds,
      relatedEntityIds: hypothesis.relatedEntityIds,
      relatedConnectionIds: hypothesis.relatedConnectionIds,
      confidence: hypothesis.confidence,
      confidenceExplanation: hypothesis.confidenceExplanation,
      status: status,
      generatedAt: hypothesis.generatedAt,
      reviewedAt: reviewedAt,
      alternativeExplanations: hypothesis.alternativeExplanations,
      evidenceGaps: hypothesis.evidenceGaps,
      mitreAttackReferences: hypothesis.mitreAttackReferences,
      generationMetadata: hypothesis.generationMetadata,
      provenance: hypothesis.provenance,
    );

Hypothesis _withMitreAttackReferences(
  Hypothesis hypothesis,
  Iterable<MitreAttackReference> references,
) =>
    Hypothesis(
      id: hypothesis.id,
      investigationId: hypothesis.investigationId,
      title: hypothesis.title,
      explanation: hypothesis.explanation,
      supportingEvidenceIds: hypothesis.supportingEvidenceIds,
      contradictingEvidenceIds: hypothesis.contradictingEvidenceIds,
      relatedEntityIds: hypothesis.relatedEntityIds,
      relatedConnectionIds: hypothesis.relatedConnectionIds,
      confidence: hypothesis.confidence,
      confidenceExplanation: hypothesis.confidenceExplanation,
      status: hypothesis.status,
      generatedAt: hypothesis.generatedAt,
      reviewedAt: hypothesis.reviewedAt,
      alternativeExplanations: hypothesis.alternativeExplanations,
      evidenceGaps: hypothesis.evidenceGaps,
      mitreAttackReferences: references,
      generationMetadata: hypothesis.generationMetadata,
      provenance: hypothesis.provenance,
    );

String _requestedId(String id, String recordType) {
  final normalized = id.trim();
  if (normalized.isEmpty) {
    throw InvalidRelationshipException('$recordType ID must not be empty.');
  }
  return normalized;
}
