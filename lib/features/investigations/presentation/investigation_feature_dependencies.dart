import '../application/services/investigation_workflow_service.dart';
import '../data/datasources/in_memory_investigation_data_source.dart';
import '../data/repositories/in_memory_investigation_repositories.dart';
import '../generation/providers/deterministic_mock_hypothesis_generator.dart';
import '../generation/services/hypothesis_generation_service.dart';
import '../../visualizations/services/visualization_data_service.dart';
import 'controllers/investigation_ui_controller.dart';

class InvestigationFeatureDependencies {
  InvestigationFeatureDependencies({
    required this.dataSource,
    required this.workflowService,
    required this.generationService,
    required this.controller,
  });

  factory InvestigationFeatureDependencies.inMemoryDemo({
    DateTime Function()? clock,
  }) {
    final dataSource = InMemoryInvestigationDataSource(
      availableEntityIds:
          VisualizationDataService.entities.map((entity) => entity.id),
      availableConnectionIds:
          VisualizationDataService.connections.map((item) => item.id),
      clock: clock,
    );
    final investigations = InMemoryInvestigationRepository(dataSource);
    final evidence = InMemoryEvidenceRepository(dataSource);
    final hypotheses = InMemoryHypothesisRepository(dataSource);
    final decisions = InMemoryAnalystDecisionRepository(dataSource);
    final assessments = InMemoryAnalystAssessmentRepository(dataSource);
    final workflow = InvestigationWorkflowService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      analystDecisionRepository: decisions,
      assessmentRepository: assessments,
      graphCatalog: dataSource,
      clock: clock,
    );
    final generation = HypothesisGenerationService(
      workflowService: workflow,
      generator: DeterministicMockHypothesisGenerator(clock: clock),
    );
    return InvestigationFeatureDependencies(
      dataSource: dataSource,
      workflowService: workflow,
      generationService: generation,
      controller: InvestigationUiController(
        workflowService: workflow,
        generationService: generation,
      ),
    );
  }

  final InMemoryInvestigationDataSource dataSource;
  final InvestigationWorkflowService workflowService;
  final HypothesisGenerationService generationService;
  final InvestigationUiController controller;

  void dispose() => controller.dispose();
}
