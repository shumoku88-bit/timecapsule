#!/usr/bin/env python3
import re
import sys
from pathlib import Path

NODE_RE = re.compile(
    r'^\s*(?P<id>"[^"]+"|[^\s\[]+)\s+\[(?P<attrs>.*)\]\s*;?\s*$'
)
EDGE_RE = re.compile(
    r'^\s*(?P<src>"[^"]+"|[^\s]+)\s*->\s*(?P<dst>"[^"]+"|[^\s\[]+)\s+\[(?P<attrs>.*)\]\s*;?\s*$'
)
LABEL_RE = re.compile(r'\blabel="(?P<label>(?:\\.|[^"])*)"')
PHASE_RE = re.compile(r'\bphase\s*=\s*(?P<phase>[A-Za-z_][A-Za-z0-9_]*)')
DEADLINE_RE = re.compile(r'\bdeadline\s*=\s*(?P<deadline>-?[0-9]+)')
RELEASED_AT_RE = re.compile(r'\breleasedAt\s*=\s*(?P<released_at>-?[0-9]+)')
ACTION_RE = re.compile(r'<?\s*(?P<action>Seal|Release)\b')


def unquote_id(value: str) -> str:
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def unescape_dot_label(value: str) -> str:
    return value.replace(r'\"', '"').replace(r'\n', '\n')


def label_from_attrs(attrs: str) -> str | None:
    match = LABEL_RE.search(attrs)
    if match is None:
        return None
    return unescape_dot_label(match.group("label"))


def parse_state(label: str) -> tuple[str, int, int] | None:
    phase = PHASE_RE.search(label)
    deadline = DEADLINE_RE.search(label)
    released_at = RELEASED_AT_RE.search(label)
    if phase is None or deadline is None or released_at is None:
        return None
    return (
        phase.group("phase"),
        int(deadline.group("deadline")),
        int(released_at.group("released_at")),
    )


def render_state(state: tuple[str, int, int]) -> str:
    phase, deadline, released_at = state
    if phase == "Unsealed":
        return "unsealed"
    if phase == "Waiting":
        return f"waiting:{deadline}"
    if phase == "Released":
        return f"released:{deadline}:{released_at}"
    raise SystemExit(f"unknown phase in TLC graph: {phase!r}")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: normalize_tlc_dot.py STATE_GRAPH.dot", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    nodes: dict[str, tuple[str, int, int]] = {}
    edges: list[tuple[str, str, str]] = []

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        edge_match = EDGE_RE.match(raw_line)
        if edge_match is not None:
            label = label_from_attrs(edge_match.group("attrs"))
            if label is None:
                continue
            action_match = ACTION_RE.search(label.strip())
            if action_match is None:
                continue
            edges.append(
                (
                    unquote_id(edge_match.group("src")),
                    action_match.group("action"),
                    unquote_id(edge_match.group("dst")),
                )
            )
            continue

        node_match = NODE_RE.match(raw_line)
        if node_match is None:
            continue
        label = label_from_attrs(node_match.group("attrs"))
        if label is None:
            continue
        state = parse_state(label)
        if state is not None:
            nodes[unquote_id(node_match.group("id"))] = state

    normalized: set[tuple[str, str, str]] = set()

    for src, action, dst in edges:
        if src not in nodes or dst not in nodes:
            raise SystemExit(
                f"edge references an unparsed state node: {src!r} -> {dst!r}"
            )

        before_state = nodes[src]
        after_state = nodes[dst]
        before = render_state(before_state)
        after = render_state(after_state)

        if action == "Seal":
            phase, deadline, _ = after_state
            if phase != "Waiting":
                raise SystemExit(f"Seal did not enter Waiting: {after_state!r}")
            command = f"seal:{deadline}"
        elif action == "Release":
            phase, _, released_at = after_state
            if phase != "Released":
                raise SystemExit(f"Release did not enter Released: {after_state!r}")
            command = f"release:{released_at}"
        else:
            continue

        normalized.add((before, command, after))

    if not normalized:
        raise SystemExit("no TimeCapsule transitions found in TLC DOT state graph")

    for before, command, after in sorted(normalized):
        print(f"{before}\t{command}\t{after}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
