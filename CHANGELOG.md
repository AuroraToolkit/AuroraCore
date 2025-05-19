# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- CHANGELOG.md
- `.env.example` for API keys configuration.
- SwiftLint configuration and linting.
- GitHub Actions CI workflow for build, test, and lint.

## [0.9.2] - 2025-05-18

### Added
- Added AuroraML module for CoreML and NaturalLanguage workflow task integration. Includes
- - `MLManager` for CoreML/NL service management
- - `MLServiceProtocol` for services
- - `ClassificationService` for classification using a CoreML model
- - `IntentExtractionService` for intent extraction using a CoreML model
- - `TaggingService` for tagging using `NLTagger`
- - `EmbeddingService` for for converting text to embeddings using `NLEmbedding`
- - `SemanticSearchService` for semantic search across a collection of documents
- Added new `Workflow.Task` subclasses based on new ML services
- Added `ModelTrainer` for training CoreML models from `.csv` files

### Key Features
- Fully on-device NLP tasks
- Composable workflow components to integrate ML with LLM tasks
- Train and deploy CoreML models with applications
