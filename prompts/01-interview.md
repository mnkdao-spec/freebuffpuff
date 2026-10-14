# 01 — Interview (use before anything ambiguous)

In the Freebuff TUI, `/interview <rough idea>` makes the agent ask you questions. Use it when the
request could mean two different things and the difference is expensive.

Paste this to steer it:

```
Interview me about <the goal>, then stop. Constraints:
- Ask about MY setup specifically: paths, service names, ports, what already works.
- Maximum 8 questions, batched in one message. No question I could answer by reading the repo.
- For each question, give your recommended default so I can just say "yes".
- Do not plan, do not write code, do not touch files in this turn.
- End with: the one thing that, if I get it wrong, makes the rest of the work pointless.
```

Save the answers into `.agents/ops/decisions.md` before moving on.
