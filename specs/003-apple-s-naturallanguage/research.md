# Research: NaturalLanguage Framework Text Classifier

**Feature**: 003-apple-s-naturallanguage
**Date**: 2025-10-05

## Research Areas

### 1. NaturalLanguage Framework & CreateML Integration

**Decision**: Use CreateML for model training, CoreML for inference via NaturalLanguage framework

**Rationale**:
- CreateML provides native text classification training with minimal code
- NaturalLanguage framework offers NLModel for loading custom CoreML text classifiers
- Tight integration ensures optimal performance and memory efficiency
- No external dependencies required (all built into macOS SDK)
- Apple's official recommendation for on-device text classification

**Alternatives Considered**:
- **TensorFlow Lite**: Rejected - requires external dependency, larger model size, no native Swift integration
- **ONNX Runtime**: Rejected - additional dependency, not Apple-optimized
- **Custom bag-of-words implementation**: Rejected - lower accuracy, more complex to maintain

**Implementation Details**:
- Training: Use CreateML's MLTextClassifier with labeled training data
- Model format: Export as .mlmodel for CoreML deployment
- Inference: NLModel(contentsOf: modelURL) for loading, predict(text:) for classification
- Expected model size: 2-5MB for 6-category classifier with moderate vocabulary

### 2. Feature Extraction Strategy

**Decision**: Use NaturalLanguage framework's built-in tokenization + custom feature extractors

**Rationale**:
- NLTokenizer provides efficient, locale-aware tokenization
- NLTagger can extract linguistic features (lexical class, named entities)
- Custom extractors needed for domain-specific features (formality, punctuation density)
- Hybrid approach balances accuracy with implementation complexity

**Feature Set**:
1. **Sentence structure**: NLTokenizer for sentence/word boundaries, fragment detection
2. **Formality indicators**: Custom dictionary matching for greetings ("Dear", "Hey"), signatures, professional terms
3. **Technical terms**: NLTagger lexical class analysis + code syntax pattern matching
4. **Length patterns**: Character/word count, average sentence length
5. **Punctuation density**: Ratio of punctuation to total characters, specific punctuation patterns (e.g., multiple "!" for social)

**Alternatives Considered**:
- **Pure ML approach (bag-of-words only)**: Rejected - misses structural features critical for distinguishing categories
- **Rule-based only**: Rejected - insufficient accuracy, brittle to edge cases
- **Deep learning embeddings**: Rejected - model size/inference time constraints

### 3. Training Data Strategy

**Decision**: Curated labeled dataset with ~500-1000 examples per category (3000-6000 total)

**Rationale**:
- CreateML text classifier performs well with moderate dataset sizes
- 500+ examples per category sufficient for 80% accuracy baseline
- Quality over quantity: hand-labeled examples ensure clean training
- Categories need balanced representation to avoid bias

**Data Sources**:
1. **Email**: Professional correspondence templates, job applications, newsletters
2. **Message**: iMessage/Slack conversations (anonymized), casual text examples
3. **Document (formal)**: Technical documentation, reports, academic writing
4. **Social**: Twitter/LinkedIn posts, status updates, announcements
5. **Code**: Programming snippets across languages (Swift, Python, JS, etc.)
6. **Search**: Web search queries, command lookups, short factual questions

**Validation Split**: 80% training, 20% validation (stratified by category)

**Alternatives Considered**:
- **Few-shot learning**: Rejected - accuracy below 80% threshold
- **Synthetic data generation**: Rejected - poor generalization to real usage
- **Unsupervised clustering**: Rejected - requires labeled data anyway for validation

### 4. Classification Logging & Storage

**Decision**: SQLite via GRDB.swift with lightweight schema

**Rationale**:
- GRDB already integrated in BetterVoice codebase (zero new dependencies)
- Efficient for append-only logging pattern
- Supports future querying for model retraining analysis
- Type-safe Swift interface reduces bugs
- Minimal performance overhead (<1ms per log entry)

**Schema**:
```
ClassificationLog:
- id: UUID (primary key)
- text: String (original transcribed text)
- category: String (email/message/document/social/code/search)
- timestamp: Date
- textLength: Int
- extractedFeatures: JSON (optional: for future analysis)
```

**Alternatives Considered**:
- **CoreData**: Rejected - overhead unnecessary for simple append-only logs
- **Plain file logging**: Rejected - no structured querying, inefficient
- **UserDefaults**: Rejected - not designed for large datasets

### 5. Dominant Characteristic Analysis (Mixed Signals)

**Decision**: Frequency-based voting across feature categories

**Rationale**:
- Clarification answer: classify by dominant characteristics
- Simple, interpretable algorithm: count features per category, pick winner
- Handles mixed signals gracefully (e.g., "Hey [casual] + detailed explanation [formal]")
- Aligns with 80% accuracy target without overengineering

**Algorithm**:
1. Extract all features from text
2. Map each feature to likely category (e.g., "Dear" → email/document)
3. Accumulate scores per category
4. Return category with highest score
5. Tiebreaker: defer to ML model prediction

**Alternatives Considered**:
- **First N words only**: Rejected - misses context in longer texts
- **Last N words only**: Rejected - ignores opening formality cues
- **Weighted features**: Rejected - adds complexity, unclear benefit for MVP

### 6. Performance Optimization

**Decision**: Lazy model loading, in-memory caching, async inference

**Rationale**:
- CoreML model loading is one-time ~50ms cost → cache after first use
- Inference on background thread prevents UI blocking
- Feature extraction can be parallelized for long texts
- Target <10ms achievable with optimized CoreML model

**Optimization Strategy**:
- Load NLModel singleton on app launch or first classification
- Use DispatchQueue.global(qos: .userInitiated) for inference
- Cache NLTokenizer/NLTagger instances
- Batch feature extraction for efficiency

**Benchmarking Plan**:
- Measure end-to-end latency (text input → category output)
- Test on representative text lengths (10 words, 100 words, 500 words)
- Profile on target hardware (MacBook Air M1 minimum spec)
- Ensure <10ms p95 latency

### 7. Integration Points with Existing Codebase

**Decision**: Extend DocumentTypeContext, inject into TextEnhancementService

**Rationale**:
- DocumentTypeContext already represents document type state
- TextEnhancementService is the consumer of classification results
- Minimal coupling: classification service has single public API
- Testable: services can be mocked/stubbed

**Integration Flow**:
1. Transcription completes → text available
2. TextClassificationService.classify(text) → returns category
3. Update DocumentTypeContext.currentType
4. TextEnhancementService applies category-specific formatting
5. ClassificationLogger.log() async in background

**Existing Code to Modify**:
- DocumentTypeContext: Add auto-detection flag, classification source tracking
- TextEnhancementService: Add classification service dependency
- AppState: Wire up classification service lifecycle

## Open Questions (Deferred to Implementation)

1. **Multi-language support**: Spec deferred this as low-impact for MVP. For future: NLLanguageRecognizer can detect language, train separate models per language.

2. **Model retraining workflow**: Outside current scope. Future: periodic batch retraining using accumulated logs, A/B testing new models.

3. **Category confidence visualization**: Per clarification, not showing confidence scores to user. Internal metrics only for debugging.

## Research Complete ✅

All NEEDS CLARIFICATION items from Technical Context resolved. Ready for Phase 1: Design & Contracts.
