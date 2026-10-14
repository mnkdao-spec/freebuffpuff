# 01 — Interview (use before anything ambiguous)

In the Freebuff TUI, `/interview <rough idea>` makes the agent ask questions. Use when the
request could mean two things and the difference is expensive.

```
Interview me about <the goal>, then stop. Constraints:
- Ask about MY setup: paths, service names, ports, what already works.
- Maximum 8 questions, batched in one message. No question answerable by reading the repo.
- For each, give your recommended default so I can just say "yes".
- Do not plan, write code, or touch files this turn.
- End with: the one thing that, if I get it wrong, makes the rest pointless.
```

Save answers into `.agents/ops/decisions.md` before moving on.
