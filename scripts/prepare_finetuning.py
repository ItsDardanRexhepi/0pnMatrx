#!/usr/bin/env python3
"""Prepare fine-tuning datasets from collected conversation examples.

Reads rated examples from the 0pnMatrx SQLite database, filters to
high-quality entries, splits into train/validation sets, and exports
as JSONL files ready for the Anthropic fine-tuning API.

Usage:
    python scripts/prepare_finetuning.py --agent trinity --min-rating 4
    python scripts/prepare_finetuning.py --all --min-rating 3 --output-dir data/finetuning
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sqlite3
import sys
from pathlib import Path


def get_examples(db_path: str, agent: str | None, min_rating: int) -> list[dict]:
    """Read qualifying examples from the database."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    if agent:
        rows = conn.execute(
            """
            SELECT agent, user_message, agent_response, tool_calls
            FROM finetuning_examples
            WHERE agent = ? AND rating >= ?
            ORDER BY rating DESC, created_at DESC
            """,
            (agent, min_rating),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT agent, user_message, agent_response, tool_calls
            FROM finetuning_examples
            WHERE rating >= ?
            ORDER BY agent, rating DESC, created_at DESC
            """,
            (min_rating,),
        ).fetchall()

    conn.close()
    return [dict(r) for r in rows]


def format_as_jsonl(examples: list[dict]) -> list[str]:
    """Format examples as JSONL lines for fine-tuning."""
    lines = []
    for ex in examples:
        record = {
            "messages": [
                {
                    "role": "system",
                    "content": (
                        f"You are {ex['agent']}, an AI agent on the "
                        "0pnMatrx platform."
                    ),
                },
                {"role": "user", "content": ex["user_message"]},
                {"role": "assistant", "content": ex["agent_response"]},
            ],
        }
        lines.append(json.dumps(record, ensure_ascii=False))
    return lines


def estimate_tokens(lines: list[str]) -> int:
    """Rough token estimate (4 chars per token)."""
    return sum(len(line) for line in lines) // 4


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare 0pnMatrx fine-tuning data")
    parser.add_argument("--agent", type=str, default=None, help="Agent name (trinity, neo, morpheus)")
    parser.add_argument("--all", action="store_true", help="Export all agents")
    parser.add_argument("--min-rating", type=int, default=4, help="Minimum quality rating (1-5)")
    parser.add_argument("--output-dir", type=str, default="data/finetuning", help="Output directory")
    parser.add_argument("--db", type=str, default="data/0pnmatrx.db", help="Database path")
    parser.add_argument("--split", type=float, default=0.9, help="Train/val split ratio")
    args = parser.parse_args()

    if not args.agent and not args.all:
        parser.error("Specify --agent NAME or --all")

    if not Path(args.db).exists():
        print(f"Database not found: {args.db}")
        sys.exit(1)

    examples = get_examples(args.db, args.agent if not args.all else None, args.min_rating)

    if not examples:
        print(f"No examples found with rating >= {args.min_rating}")
        sys.exit(0)

    print(f"Found {len(examples)} qualifying examples")

    # Group by agent
    by_agent: dict[str, list[dict]] = {}
    for ex in examples:
        by_agent.setdefault(ex["agent"], []).append(ex)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for agent_name, agent_examples in by_agent.items():
        lines = format_as_jsonl(agent_examples)

        # Shuffle and split
        random.shuffle(lines)
        split_idx = int(len(lines) * args.split)
        train_lines = lines[:split_idx]
        val_lines = lines[split_idx:]

        train_path = output_dir / f"{agent_name}_train.jsonl"
        val_path = output_dir / f"{agent_name}_val.jsonl"

        train_path.write_text("\n".join(train_lines) + "\n", encoding="utf-8")
        val_path.write_text("\n".join(val_lines) + "\n", encoding="utf-8")

        train_tokens = estimate_tokens(train_lines)
        val_tokens = estimate_tokens(val_lines)

        print(f"\n{'='*50}")
        print(f"Agent: {agent_name}")
        print(f"  Train: {len(train_lines)} examples ({train_tokens:,} est. tokens) -> {train_path}")
        print(f"  Val:   {len(val_lines)} examples ({val_tokens:,} est. tokens) -> {val_path}")
        print(f"  Total: {len(lines)} examples")

        if len(train_lines) < 100:
            print(f"  WARNING: Need at least 100 training examples. Currently have {len(train_lines)}.")
        else:
            print(f"  READY for fine-tuning submission.")

    print(f"\nNext steps:")
    print(f"  1. Review exported files in {output_dir}/")
    print(f"  2. Submit via Anthropic fine-tuning API: https://docs.anthropic.com/en/docs/build-with-claude/fine-tuning")
    print(f"  3. Evaluate fine-tuned model against base model on held-out validation set")


if __name__ == "__main__":
    main()
