### Exact Parity with BizTalk FILE Adapter
- Input masking: identical wildcard support (`*` and `?`) via regex.
- Output macros: **100% identical** list implemented (see MacroReplacer.cs).
- Behavior: poll → read → write with new name → delete (same as BizTalk).