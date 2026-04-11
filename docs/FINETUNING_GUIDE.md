# Fine-Tuning Guide

This guide covers collecting training data from real conversations, exporting it, and submitting fine-tuning jobs for the 0pnMatrx agents.

---

## When to Fine-Tune

Fine-tuning makes sense when you have **500+ high-quality examples per agent** (rated 4 or 5 stars). Below that threshold, prompt engineering and few-shot examples give better returns.

Signs you're ready:

- Trinity handles most queries well but misses nuance in specific domains
- Neo's blockchain reasoning is correct but could be faster with fewer reasoning steps
- Morpheus interventions are accurate but could be more concise

---

## Collecting Training Data

### Enable Collection

Set `finetuning.collect: true` in `openmatrix.config.json`:

```json
"finetuning": {
  "collect": true,
  "min_rating_for_export": 4,
  "export_path": "data/finetuning/"
}
```

Every conversation turn is recorded as a potential training example.

### Rating Examples

Rate examples through the admin API:

```bash
curl -X POST http://localhost:18790/admin/rate-example \
  -H "Content-Type: application/json" \
  -d '{"example_id": "abc123", "rating": 5, "flags": ["excellent"]}'
```

Rating scale:

| Rating | Meaning |
|--------|---------|
| 1 | Incorrect or harmful — never use for training |
| 2 | Partially correct but missing key information |
| 3 | Acceptable but not ideal |
| 4 | Good — correct, clear, appropriate tone |
| 5 | Excellent — perfect response, ideal training example |

Quality flags: `excellent`, `perfect_tone`, `incorrect`, `incomplete`, `wrong_tool`, `hallucination`

### What Makes a Good Example

- **Correct**: the response is factually accurate and the right tool was called
- **Complete**: all parts of the user's question are addressed
- **Tone-appropriate**: matches the agent's identity (Trinity is warm, Morpheus is measured, Neo is precise)
- **Proportional**: response length matches the question complexity

---

## Exporting Training Data

Run the export script:

```bash
python scripts/prepare_finetuning.py --agent trinity --min-rating 4
```

Options:

| Flag | Description |
|------|-------------|
| `--agent NAME` | Export for a specific agent |
| `--all` | Export all agents |
| `--min-rating N` | Minimum quality rating (default: 4) |
| `--output-dir PATH` | Output directory (default: `data/finetuning/`) |
| `--split RATIO` | Train/validation split (default: 0.9) |

Output files:

```
data/finetuning/
  trinity_train.jsonl
  trinity_val.jsonl
  neo_train.jsonl
  neo_val.jsonl
  morpheus_train.jsonl
  morpheus_val.jsonl
```

---

## Submitting to the Fine-Tuning API

Follow the Anthropic fine-tuning documentation:
https://docs.anthropic.com/en/docs/build-with-claude/fine-tuning

---

## Evaluating Results

Compare the fine-tuned model against the base model:

1. Hold out 10% of examples as a test set (the export script handles this)
2. Run both models on the test set
3. Compare: response accuracy, tone match, tool call correctness
4. A fine-tuned model should show improvement on domain-specific tasks while maintaining general capability

---

## Expected Improvements by Agent

### Trinity
- Better parameter extraction from natural language
- More consistent financial accessibility language
- Faster convergence to the right intent

### Neo
- More precise tool call arguments
- Better gas estimation reasoning
- Fewer unnecessary intermediate steps

### Morpheus
- More concise intervention messages
- Better calibration of when to intervene vs. when to stay silent
- More specific risk explanations
