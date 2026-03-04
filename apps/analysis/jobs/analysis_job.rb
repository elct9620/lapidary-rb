# frozen_string_literal: true

module Analysis
  module Jobs
    # Assembles the analysis pipeline and delegates to ProcessJob.
    # Outer-layer job class that wires container dependencies into inner-layer use cases.
    class AnalysisJob < Lapidary::Analysis::BaseJob
      include Lapidary::Dependency[
        'analysis.repositories.job_repository',
        'analysis.repositories.analysis_record_repository',
        'analysis.repositories.graph_repository',
        'database',
        'llm',
        'logger'
      ]

      def perform(job)
        use_case.call(job)
      end

      private

      def use_case
        @use_case ||= ::Analysis::UseCases::ProcessJob.new(
          job_repository: job_repository,
          analysis_record_repository: analysis_record_repository,
          pipeline: build_pipeline,
          logger: logger
        )
      end

      def build_pipeline
        ::Analysis::UseCases::TripletPipeline.new(
          extractor: build_extractor,
          validator: ::Analysis::Ontology::Validator.new,
          normalizer: ::Analysis::Ontology::Normalizer.new,
          graph_repository: graph_repository,
          logger: logger
        )
      end

      def build_extractor
        ::Analysis::Extractors::LlmExtractor.new(
          llm: llm,
          logger: logger,
          tools: build_tools
        )
      end

      def build_tools
        [
          ::Analysis::Extractors::Tools::SearchNodeTool.new(database),
          ::Analysis::Extractors::Tools::ValidateModuleTool.new,
          ::Analysis::Extractors::Tools::SearchEdgeTool.new(database)
        ]
      end
    end
  end
end
