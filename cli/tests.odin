package temple_cli

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:testing"

// ─── Lexer Tests ─────────────────────────────────────────────────────────────

@(test)
lexer_test_plain_text :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "hello world")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, "hello world")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.EOF)
}

@(test)
lexer_test_output_expression :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "{{ this.name }}")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Output_Open)
	testing.expect_value(t, tok.value, "{{")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, " this.name ")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Output_Close)
	testing.expect_value(t, tok.value, "}}")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.EOF)
}

@(test)
lexer_test_process_block :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "{% if this.x %}text{% end %}")

	// Process open
	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	// "if" keyword (recognized because prev_token == Process_Open)
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.If)
	testing.expect_value(t, tok.value, "if")

	// expression after "if "
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)

	// Process close
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	// body text
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, "text")

	// {% end %}
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.End)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.EOF)
}

@(test)
lexer_test_for_loop :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "{% for x in this.items %}{% end %}")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.For)
	testing.expect_value(t, tok.value, "for")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, " x in this.items ")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.End)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)
}

@(test)
lexer_test_else_elseif :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "{% if a %}{% elseif b %}{% else %}{% end %}")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.If)

	tok = lexer_next(&l) // " a "
	testing.expect_value(t, tok.type, Token_Type.Text)

	tok = lexer_next(&l) // %}
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	// {% elseif b %}
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.ElseIf)
	testing.expect_value(t, tok.value, "elseif")

	// {% else %}
	tok = lexer_next(&l) // " b "
	testing.expect_value(t, tok.type, Token_Type.Text)

	tok = lexer_next(&l) // %}
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	tok = lexer_next(&l) // {%
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Else)

	tok = lexer_next(&l) // %}
	testing.expect_value(t, tok.type, Token_Type.Process_Close)

	// {% end %}
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.End)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)
}

@(test)
lexer_test_embed :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, `{% embed "header.twig" %}`)

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Embed)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Embed_Path)
	testing.expect_value(t, tok.value, `"header.twig"`)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)
}

@(test)
lexer_test_embed_with :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, `{% embed "header.twig" with this.header %}`)

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Embed)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Embed_Path)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Embed_With)
	testing.expect_value(t, tok.value, "with")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, " this.header ")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Close)
}

@(test)
lexer_test_mixed_text_and_output :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "Hello {{ this.name }}, welcome!")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, "Hello ")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Output_Open)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, " this.name ")

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Output_Close)

	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, ", welcome!")
}

@(test)
lexer_test_empty_input :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.EOF)
}

@(test)
lexer_test_pos_tracking :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "ab\ncd")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Text)
	testing.expect_value(t, tok.value, "ab\ncd")
	testing.expect_value(t, tok.pos.line, 0)
	testing.expect_value(t, tok.pos.col, 0)
}

@(test)
lexer_test_illegal_process :: proc(t: ^testing.T) {
	l: Lexer
	lexer_init(&l, "{% bad_keyword %}")

	tok := lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Process_Open)

	// "bad_keyword" is not a known keyword after Process_Open -> Illegal
	tok = lexer_next(&l)
	testing.expect_value(t, tok.type, Token_Type.Illegal)
}

// ─── Parser Tests ────────────────────────────────────────────────────────────

@(test)
parser_test_text_only :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "just text", context.temp_allocator)
	templ := parse(&p)

	testing.expect_value(t, len(templ.content), 1)
	testing.expect(t, templ.err == nil, "expected no parse errors")

	text_node := templ.content[0].derived.(^Node_Text)
	testing.expect_value(t, text_node.text.value, "just text")
	testing.expect_value(t, text_node.text.type, Token_Type.Text)
}

@(test)
parser_test_output :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{{ this.name }}", context.temp_allocator)
	templ := parse(&p)

	testing.expect_value(t, len(templ.content), 1)
	testing.expect(t, templ.err == nil, "expected no parse errors")

	out := templ.content[0].derived.(^Node_Output)
	testing.expect_value(t, out.expression.type, Token_Type.Text)
	testing.expect_value(t, out.expression.value, " this.name ")
}

@(test)
parser_test_if_end :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if this.show %}hello{% end %}", context.temp_allocator)
	templ := parse(&p)

	testing.expect_value(t, len(templ.content), 1)
	testing.expect(t, templ.err == nil, "expected no parse errors")

	if_node := templ.content[0].derived.(^Node_If)
	testing.expect_value(t, if_node._if.start.type.type, Token_Type.If)
	testing.expect_value(t, if_node._if.start.expr.?.value, " this.show ")
	testing.expect_value(t, len(if_node._if.body), 1)
	testing.expect_value(t, len(if_node.elseifs), 0)
	testing.expect(t, if_node._else == nil, "expected no else branch")
}

@(test)
parser_test_if_else :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if this.a %}yes{% else %}no{% end %}", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	if_node := templ.content[0].derived.(^Node_If)
	testing.expect_value(t, len(if_node._if.body), 1)
	testing.expect(t, if_node._else != nil, "expected else branch")
	testing.expect_value(t, len(if_node._else.?.body), 1)
}

@(test)
parser_test_if_elseif :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if a %}1{% elseif b %}2{% else %}3{% end %}", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	if_node := templ.content[0].derived.(^Node_If)
	testing.expect_value(t, len(if_node.elseifs), 1)
	testing.expect(t, if_node._else != nil, "expected else branch")
}

@(test)
parser_test_for_loop :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% for x in this.items %}{{ x }}{% end %}", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	for_node := templ.content[0].derived.(^Node_For)
	testing.expect_value(t, for_node.start.expression.value, " x in this.items ")
	testing.expect_value(t, len(for_node.body), 1)

	body_out := for_node.body[0].derived.(^Node_Output)
	testing.expect_value(t, body_out.expression.value, " x ")
}

@(test)
parser_test_nested_if :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if a %}{% if b %}inner{% end %}{% end %}", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	outer := templ.content[0].derived.(^Node_If)
	testing.expect_value(t, len(outer._if.body), 1)

	inner := outer._if.body[0].derived.(^Node_If)
	testing.expect_value(t, len(inner._if.body), 1)

	inner_text := inner._if.body[0].derived.(^Node_Text)
	testing.expect_value(t, inner_text.text.value, "inner")
}

@(test)
parser_test_embed :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, `{% embed "partial.twig" %}`, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	embed := templ.content[0].derived.(^Node_Embed)
	testing.expect_value(t, embed.path.type, Token_Type.Embed_Path)
	testing.expect_value(t, embed.path.value, `"partial.twig"`)
	testing.expect(t, embed.with == nil, "expected no with clause")
}

@(test)
parser_test_embed_with :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, `{% embed "partial.twig" with this.data %}`, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	embed := templ.content[0].derived.(^Node_Embed)
	testing.expect(t, embed.with != nil, "expected with clause")
	testing.expect_value(t, embed.with.?.expr.value, " this.data ")
}

@(test)
parser_test_unclosed_output :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{{ this.x ", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err != nil, "expected parse error for unclosed output")
}

@(test)
parser_test_missing_end :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if this.x %}text", context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err != nil, "expected parse error for missing end")
}

@(test)
parser_test_complex_template :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	source := `<ul>
{% for item in this.items %}
<li>{{ item.name }}</li>
{% end %}
</ul>`

	p: Parser
	parser_init(&p, source, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	// text + for loop + text
	testing.expect_value(t, len(templ.content), 3)

	// First: text node "<ul>\n"
	testing.expect_value(t, templ.content[0].derived.(^Node_Text).text.type, Token_Type.Text)

	// Second: for loop
	for_node := templ.content[1].derived.(^Node_For)
	testing.expect_value(t, for_node.start.expression.type, Token_Type.Text)

	// Inside the for: text + output + text + text (whitespace handling)
	testing.expect(t, len(for_node.body) > 0, "expected body content")

	// Third: text node "\n</ul>"
	testing.expect_value(t, templ.content[2].derived.(^Node_Text).text.type, Token_Type.Text)
}

// ─── Transpiler Tests ────────────────────────────────────────────────────────
// The transpiler writes Odin source code to an io.Writer.
// We capture output in a strings.Builder and check key patterns.

@(test)
transpile_test_text_only :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "hello", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, `write_string`), "expected write_string call in output")
	testing.expect(t, strings.contains(output, "hello"), "expected text content in output")
	testing.expect(t, strings.contains(output, `when path == "test"`), "expected path match guard")
}

@(test)
transpile_test_output_expression :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{{ this.name }}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "__temple_write_escaped_string"), "expected escaped string write")
	testing.expect(t, strings.contains(output, "this.name"), "expected expression in output")
}

@(test)
transpile_test_output_int_cast :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{{ int(this.count) }}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "write_int"), "expected write_int for int() cast")
	testing.expect(t, strings.contains(output, "int(this.count)"), "expected cast expression")
}

@(test)
transpile_test_if_statement :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if this.show %}visible{% end %}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "if this.show"), "expected if statement")
	testing.expect(t, strings.contains(output, "visible"), "expected body content")
}

@(test)
transpile_test_for_loop :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% for i in 0..<5 %}{{ int(i) }}{% end %}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "for i in 0..<5"), "expected for loop")
	testing.expect(t, strings.contains(output, "write_int"), "expected write_int for int() cast")
}

@(test)
transpile_test_approx_bytes :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "hello world", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "approx_bytes"), "expected approx_bytes field")
	testing.expect(t, strings.contains(output, "11"), "expected approx_bytes to be 11 (length of 'hello world')")
}

@(test)
transpile_test_if_else_branches :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{% if this.a %}A{% else %}B{% end %}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "if this.a"), "expected if condition")
	testing.expect(t, strings.contains(output, " else "), "expected else branch")
	testing.expect(t, strings.contains(output, "write_string"), "expected write_string calls")
}

@(test)
transpile_test_output_raw_cast :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	p: Parser
	parser_init(&p, "{{ raw(this.html) }}", context.temp_allocator)
	templ := parse(&p)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "write_string"), "expected write_string for raw() cast")
	testing.expect(t, !strings.contains(output, "__temple_write_escaped_string"), "raw() should NOT use escaped write")
	testing.expect(t, strings.contains(output, "this.html"), "expected inner expression in output")
	testing.expect(t, !strings.contains(output, "raw("), "raw() wrapper should be stripped from output")
}

// ─── Integration: Lexer → Parser → Transpiler ──────────────────────────────

@(test)
integration_test_full_pipeline :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	source := `Hello {{ this.name }}!
{% if this.vip %}Welcome back!{% end %}
{% for i in 0..<3 %}{{ int(i) }} {% end %}`

	p: Parser
	parser_init(&p, source, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, fmt.aprintf("unexpected parse error: %v", templ.err, allocator = context.temp_allocator))
	// Node count varies based on whitespace stripping logic.
	// Just verify no errors and key transpilation patterns.
	testing.expect_value(t, len(templ.content), 6)

	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	w := strings.to_writer(&b)

	transpile(w, "integration_test", templ, nil_embed_parser, nil)

	output := strings.to_string(b)
	testing.expect(t, strings.contains(output, "when path == \"integration_test\""), "expected path guard")
	testing.expect(t, strings.contains(output, "__temple_write_escaped_string"), "expected escaped output")
	testing.expect(t, strings.contains(output, "write_int"), "expected int write")
	testing.expect(t, strings.contains(output, "if this.vip"), "expected if statement")
	testing.expect(t, strings.contains(output, "for i in 0..<3"), "expected for loop")
}

@(test)
integration_test_whitespace_stripping :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	// Process tags on their own line should strip trailing whitespace from the
	// preceding text node.
	source := "{% if true %}\nhello\n{% end %}"

	p: Parser
	parser_init(&p, source, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")

	// No text before {% if %}, so no stripping there. But the body text
	// before {% end %} has its trailing whitespace stripped (the newline
	// before {% end %} which is on its own line).
	if_node := templ.content[0].derived.(^Node_If)
	testing.expect_value(t, len(if_node._if.body), 1)

	body_text := if_node._if.body[0].derived.(^Node_Text)
	// parser_maybe_remove_whitespace strips the trailing \n before {% end %}.
	testing.expect_value(t, body_text.text.value, "\nhello")
}

@(test)
integration_test_multiple_outputs :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)

	source := "{{ a }} and {{ b }} and {{ c }}"

	p: Parser
	parser_init(&p, source, context.temp_allocator)
	templ := parse(&p)

	testing.expect(t, templ.err == nil, "expected no parse errors")
	testing.expect_value(t, len(templ.content), 5) // out + text + out + text + out
}

// nil_embed_parser is a stub that always returns empty (no embedded templates).
nil_embed_parser :: proc(node: ^Node_Embed, data: rawptr) -> (Template, bool) {
	return {}, false
}
