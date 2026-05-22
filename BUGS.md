# Known Bugs

## 1. `parser_maybe_remove_whitespace` drops non-whitespace content

**Severity:** High — silent data loss in template output.  
**File:** `cli/parser.odin` — `parser_maybe_remove_whitespace`

**Reproduction:**

```
Hello World
Name: {% if show %}{{ name }}{% end %}
```

Expected text node: `"Hello World\nName: "`  
Actual text node: `"Hello World\nName"` — `": "` silently eaten.

**Root cause (two compounding issues):**

1. **Wrong line check.** Compares `last_txt.text.pos.line` (text *start* line) against `token.pos.line`. For multi-line text nodes, the start line is wrong — content may exist on the same line as the tag.
2. **Off-by-one slice.** `value[0:new_end]` excludes the character at `new_end`. When the first non-space/tab from the end is a content char, it gets sliced off.

**Fix direction:** Only strip when the portion between the last `\n` in the text node and the tag offset is whitespace-only. Check actual content adjacency, not start-line vs tag-line.

---

## 2. `lexer_skip_spaces` ignores tabs

**Severity:** Medium — breaks templates with tab indentation after `{%`.  
**File:** `cli/lexer.odin` — `lexer_skip_spaces`

**Reproduction:**

```
{%	if true %}hello{% end %}
```

Lexer produces `.Illegal` token after `{%` because `\t` isn't skipped, so keyword detection fails.

**Root cause:** Skip loop only checks `l.ch != ' '`. Tabs are not skipped.

**Fix:**

```odin
if l.ch != ' ' && l.ch != '\t' do return
```

---

## Non-bugs (reviewed, dismissed)

- `transpile_if` approx_bytes max-of-branches tracking — correct.
- `embed_parser` redundant `templ.err == nil` check after early return — harmless.
- `transpile_output` prefix matching (`"byte("`, `"int("`, etc.) — `(` in prefix prevents false positives.
- `__temple_write_escaped_string` per-char writes — slow but correct.
- `collect_compile_calls` allocator split (temp for parse, explicit for results) — correct.

## Deferred (not bugs, but worth noting)

- **No circular embed detection.** Cross-referencing `{% embed "a" %}` / `{% embed "b" %}` → stack overflow.
- **`else`/`elseif` keyword detection** only peeks fixed char counts. `elseifx` matches as `elseif`. Harmless (parser errors on garbage expression), but fragile.
