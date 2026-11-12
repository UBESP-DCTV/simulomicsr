You are a careful technical editor. Work only from two files; do not read, search or open anything else, and do not use the web.

- `full-prompt.md`: an instruction text ("the prompt") that a language model receives before it reads a gene-expression study and writes a JSON "factor table".
- `pairs.md`: 11 pairs, C01 to C11. In each pair, ORIGINAL is one sentence of the prompt and REWRITTEN is a proposed replacement for that sentence. Everything else in the prompt stays identical.

For each pair decide whether the REWRITTEN sentence, read in its place in the prompt, has EXACTLY the same meaning as the ORIGINAL: the same instructions, conditions, exceptions, quantifiers, modal strength, scope and examples, nothing added and nothing removed. A change of word order, of voice (active/passive) or of a function word is acceptable only if a careful reader would follow exactly the same instruction in every case. Also flag a rewrite that is ungrammatical, or that is ambiguous in a way the original is not.

Judge each pair on its own. Any number of the pairs, from none to all, may be meaning-preserving. Do not try to balance your answers.

Answer with one line per pair, in order, in this exact format, and nothing else after the list:

C01 | SAME or CHANGED | one sentence: what differs in meaning or scope (or "nothing") | confidence 1-5
