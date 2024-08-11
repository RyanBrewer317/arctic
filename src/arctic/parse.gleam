import arctic.{type Page}
import arctic/page
import birl
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import party.{type Parser}
import snag.{type Result}

// I managed to make this without exposing anything from Party, so that's good!
// It definitely could use some optimization.
// There's even a lot of room for concurrency!

type ParsedPage {
  ParsedPage(metadata: Dict(String, String), body: List(Option(Element(Nil))))
}

type ParseResult(a) {
  ParseResult(val: a, errors: List(ParseError))
}

type ParseError {
  ParseError(pos: Position, unexpected: String)
}

type ArcticParser {
  ArcticParser(parse: fn(String, Position) -> ParseResult(Option(Element(Nil))))
}

/// A place in an Arctic markup file
pub type Position {
  Position(line: Int, column: Int)
}

type InlineRule {
  InlineRule(
    left: String,
    right: String,
    action: fn(Element(Nil), List(String), Position) -> Result(Element(Nil)),
  )
}

type PrefixRule {
  PrefixRule(
    prefix: String,
    action: fn(Element(Nil), Position) -> Result(Element(Nil)),
  )
}

type Component {
  StaticComponent(
    name: String,
    action: fn(List(String), String, Position) -> Result(Element(Nil)),
  )
  DynamicComponent(name: String)
}

/// An under-construction parser that you can add rules to.
/// For example,
/// ```
/// my_parser
///   |> add_inline_rule("_", "_", wrap_inline(html.i))
/// ```
pub opaque type ParserBuilder {
  ParserBuilder(
    inline_rules: List(InlineRule),
    prefix_rules: List(PrefixRule),
    components: List(Component),
  )
}

/// Create a new parser builder, with no rules or components.
pub fn new() -> ParserBuilder {
  ParserBuilder(inline_rules: [], prefix_rules: [], components: [])
}

/// Add an "inline rule" to a parser.
/// An inline rule rewrites parts of text paragraphs.
/// For example, `add_inline_rule("**", "**", wrap_inline(html.strong))` 
/// replaces anything wrapped in double-asterisks with a bolded version of the same text.
/// Note that the rule may fail with a `snag` error, halting the parsing of that paragraph,
/// and that the position in the file is given, so you can produce better `snag` error messages.
/// The rewrite might also be given parameters, allowing for something like
/// `[here](https://example.com) is a link`
pub fn add_inline_rule(
  p: ParserBuilder,
  left: String,
  right: String,
  action: fn(Element(Nil), List(String), Position) -> Result(Element(Nil)),
) -> ParserBuilder {
  ParserBuilder(
    [InlineRule(left, right, action), ..p.inline_rules],
    p.prefix_rules,
    p.components,
  )
}

/// Add a "prefix rule" to a parser.
/// A prefix rule rewrites a whole paragraph based on symbols at the beginning.
/// For example, `add_prefix_rule("#", wrap_prefix(html.h1))` 
/// replaces anything that starts with a hashtag with a header of the same text.
/// Note that the rule may fail with a `snag` error, halting the parsing of that paragraph,
/// and that the position in the file is given, so you can produce better `snag` error messages.
pub fn add_prefix_rule(
  p: ParserBuilder,
  prefix: String,
  action: fn(Element(Nil), Position) -> Result(Element(Nil)),
) -> ParserBuilder {
  ParserBuilder(
    p.inline_rules,
    [PrefixRule(prefix, action), ..p.prefix_rules],
    p.components,
  )
}

/// Add a "static component" to a parser.
/// A static component is a component (imagine a DSL) that doesn't need MVC interactivity.
/// You just specify how it gets turned into HTML,
/// and Arctic turns it into HTML.
/// In your Arctic markup file, you write 
/// ```
/// @component_name(an arg, another arg)
/// A bunch
/// of content
/// ```
/// Arctic will parse the body until the first blank line, then apply your given action to the parameters and body.
/// This allows you to embed languages in Arctic markup files, like latex or HTML.
/// Note that the component may fail with a `snag` error, halting the parsing of that paragraph,
/// and that the position in the file is given, so you can produce better `snag` error messages.
pub fn add_static_component(
  p: ParserBuilder,
  name: String,
  action: fn(List(String), String, Position) -> Result(Element(Nil)),
) -> ParserBuilder {
  ParserBuilder(p.inline_rules, p.prefix_rules, [
    StaticComponent(name, action),
    ..p.components
  ])
}

/// Add a "dynamic component" to a parser.
/// A dynamic component is a component (imagine a DSL) that needs MVC interactivity.
/// You will need to separately register a Lustre component of the same name;
/// this is just the way that you put it into your site from an Arctic markup file.
/// In your Arctic markup file, you would write
/// ```
/// @component_name(an arg, another arg)
/// A bunch
/// of content
/// ```
/// Arctic will parse the body until the first blank line.
/// Then the produced HTML is
/// ```
/// <component_name data-parameters="an arg,another arg" data-body="A bunch\nof content">
/// </component_name>
/// ```
pub fn add_dynamic_component(p: ParserBuilder, name: String) -> ParserBuilder {
  ParserBuilder(p.inline_rules, p.prefix_rules, [
    DynamicComponent(name),
    ..p.components
  ])
}

/// Apply a given parser to a given string.
pub fn parse(p: ParserBuilder, src: String) -> Result(Page) {
  use parsed <- result.try(parse_page(
    p.inline_rules,
    p.prefix_rules,
    p.components,
    src,
  ))
  case parsed.errors {
    [first_e, ..rest] ->
      snag.error(
        "parse errors in `___` ("
        <> list.fold(
          rest,
          "unexpected "
            <> first_e.unexpected
            <> " at "
            <> int.to_string(first_e.pos.line)
            <> ":"
            <> int.to_string(first_e.pos.column),
          fn(s, e) {
            s
            <> ", unexpected "
            <> e.unexpected
            <> " at "
            <> int.to_string(e.pos.line)
            <> ":"
            <> int.to_string(e.pos.column)
          },
        )
        <> ")",
      )
    [] -> {
      use id <- result.try(
        dict.get(parsed.val.metadata, "id")
        |> result.map_error(fn(_) { snag.new("no `id` field present") }),
      )
      use date <- result.try(case dict.get(parsed.val.metadata, "date") {
        Ok(s) -> {
          use d <- result.try(
            birl.parse(s)
            |> result.map_error(fn(_) {
              snag.new("couldn't parse date `" <> s <> "`")
            }),
          )
          Ok(Some(d))
        }
        Error(Nil) -> {
          Ok(None)
        }
      })
      page.new(id)
      |> page.with_blerb(result.unwrap(
        dict.get(parsed.val.metadata, "blerb"),
        "",
      ))
      |> page.with_tags(
        result.unwrap(
          result.map(dict.get(parsed.val.metadata, "tags"), string.split(
            _,
            on: ",",
          )),
          [],
        ),
      )
      |> fn(p) {
        case date {
          Some(d) -> page.with_date(p, d)
          None -> p
        }
      }
      |> page.with_title(result.unwrap(
        dict.get(parsed.val.metadata, "title"),
        "",
      ))
      |> page.with_body(
        list.map(parsed.val.body, fn(section) {
          case section {
            Some(el) -> el
            None -> html.div([attribute.class("arctic-failed-parse")], [])
          }
        }),
      )
      |> Ok
    }
  }
}

/// A convenience function for inline rules that just put content in an element.
/// For example, `wrap_inline(html.i)` italicizes.
pub fn wrap_inline(
  w: fn(List(Attribute(a)), List(Element(Nil))) -> Element(Nil),
) {
  fn(el, _args, _pos) { Ok(w([], [el])) }
}

/// A convenience function for inline rules that just put content in an element 
/// and give the element some parameters.
/// For example, `wrap_inline(html.a, [attribute.src("https://arctic-framework.org")])`
/// makes something a link to arctic-framework.org.
pub fn wrap_inline_with_attributes(
  w: fn(List(Attribute(a)), List(Element(Nil))) -> Element(Nil),
  attrs: List(Attribute(a)),
) {
  fn(el, _args, _pos) { Ok(w(attrs, [el])) }
}

/// A convenience function for prefix rules that just put content in an element
/// For example, `wrap_prefix(html.h1)` makes a paragraph a header.
pub fn wrap_prefix(
  w: fn(List(Attribute(a)), List(Element(Nil))) -> Element(Nil),
) {
  fn(el, _pos) { Ok(w([], [el])) }
}

/// A convenience function for prefix rules that just put content in an element 
/// and give the element some parameters.
/// For example, `wrap_prefix(html.a, [attribute.src("https://arctic-framework.org")])`
/// makes a paragraph a link to arctic-framework.org.
pub fn wrap_prefix_with_attributes(
  w: fn(List(Attribute(a)), List(Element(Nil))) -> Element(Nil),
  attrs: List(Attribute(a)),
) {
  fn(el, _pos) { Ok(w(attrs, [el])) }
}

fn parse_metadata(
  start_dict: Dict(String, String),
) -> Parser(Dict(String, String), snag.Snag) {
  use res <- party.do(party.perhaps(party.satisfy(fn(c) { c != "\n" })))
  case res {
    Ok(key_first) -> {
      use key_rest <- party.do(party.until(
        do: party.satisfy(fn(_) { True }),
        until: party.seq(party.whitespace(), party.char(":")),
      ))
      use _ <- party.do(party.whitespace())
      use val <- party.do(party.until(
        do: party.satisfy(fn(_) { True }),
        until: party.char("\n"),
      ))
      let key_str = string.concat([key_first, ..key_rest])
      let val_str = string.concat(val)
      let d = dict.insert(start_dict, key_str, val_str)
      parse_metadata(d)
    }
    Error(Nil) -> {
      party.return(start_dict)
    }
  }
}

fn parse_prefix() -> Parser(String, snag.Snag) {
  party.many_concat(
    party.satisfy(string.contains(
      does: "~`!#$%^&*-_=+{[|;:<>,./?]}",
      contain: _,
    )),
  )
}

fn escaped_char() -> Parser(String, snag.Snag) {
  use _ <- party.do(party.char("\\"))
  use c <- party.do(party.satisfy(fn(_) { True }))
  case c {
    "n" -> party.return("\n")
    "t" -> party.return("\t")
    "f" -> party.return("\f")
    "r" -> party.return("\r")
    "u" -> {
      use _ <- party.do(party.char("{"))
      use _ <- party.do(party.whitespace())
      use code_str <- party.do(
        party.many1_concat(
          party.satisfy(string.contains(
            does: "1234567890abcdefABCDEF",
            contain: _,
          )),
        ),
      )
      use _ <- party.do(party.whitespace())
      use _ <- party.do(party.char("}"))
      // this assert should never fail because we only parse characters in "1234567890abcdefABCDEF"
      let assert Ok(code) = int.base_parse(code_str, 16)
      use codepoint <- party.do(
        party.try(party.return(Nil), fn(_) {
          string.utf_codepoint(code)
          |> result.map_error(fn(_) {
            snag.new("unknown unicode codepoint `\\u{" <> code_str <> "}")
          })
        }),
      )
      party.return(string.from_utf_codepoints([codepoint]))
    }
    _ -> party.return(c)
  }
}

fn parse_markup(
  inline_rules: List(InlineRule),
  until terminator: String,
  at pos: Position,
) -> Parser(Element(Nil), snag.Snag) {
  party.choice(
    list.map(inline_rules, fn(rule) {
      use _ <- party.do(party.string(rule.left))
      use party_pos <- party.do(party.pos())
      let pos2 =
        Position(
          line: pos.line + party_pos.row,
          column: pos.column + party_pos.col,
        )
      use middle <- party.do(
        party.lazy(fn() {
          parse_markup(inline_rules, until: rule.right, at: pos2)
        }),
      )
      use res <- party.do(party.perhaps(party.char("(")))
      use args <- party.do(case res {
        Ok(_) -> {
          use args <- party.do(party.sep(
            party.many_concat(party.satisfy(fn(c) { c != "," && c != ")" })),
            by: party.char(","),
          ))
          use _ <- party.do(party.char(")"))
          party.return(args)
        }
        Error(Nil) -> party.return([])
      })
      party.try(party.return(Nil), fn(_) { rule.action(middle, args, pos2) })
    })
    |> list.append([
      party.until(
        do: party.either(escaped_char(), party.satisfy(fn(_) { True })),
        until: party.string(terminator),
      )
      |> party.map(fn(chars) {
        html.span(
          [],
          string.concat(chars)
            |> string.split("\n")
            |> list.map(element.text)
            |> list.intersperse(html.br([])),
        )
      }),
    ]),
  )
}

fn parse_text(
  inline_rules: List(InlineRule),
  prefix_rules: List(PrefixRule),
) -> ArcticParser {
  ArcticParser(fn(src, pos) {
    let res =
      party.go(
        {
          use prefix <- party.do(parse_prefix())
          use _ <- party.do(
            party.many(party.either(party.char(" "), party.char("\t"))),
          )
          use party_pos <- party.do(party.pos())
          let pos2 =
            Position(
              line: pos.line + party_pos.row,
              column: pos.column + party_pos.col,
            )
          use rest <- party.do(parse_markup(
            inline_rules,
            until: "\n\n",
            at: pos2,
          ))
          use el <- party.do(case
            list.find(prefix_rules, fn(rule) { rule.prefix == prefix })
          {
            Ok(rule) -> {
              use party_pos <- party.do(party.pos())
              let pos3 =
                Position(
                  line: pos.line + party_pos.row,
                  column: pos.column + party_pos.col,
                )
              use el <- party.do(
                party.try(party.return(Nil), fn(_) { rule.action(rest, pos3) }),
              )
              party.return(el)
            }
            Error(Nil) ->
              party.return(html.div([], [element.text(prefix), rest]))
          })
          party.return(Some(el))
        },
        src,
      )
    case res {
      Ok(t) -> ParseResult(val: t, errors: [])
      Error(err) -> {
        case err {
          party.Unexpected(party_pos, s) ->
            ParseResult(val: None, errors: [
              ParseError(
                pos: Position(
                  line: party_pos.row + pos.line,
                  column: party_pos.col + pos.column,
                ),
                unexpected: s,
              ),
            ])
          party.UserError(party_pos, err) ->
            ParseResult(val: None, errors: [
              ParseError(
                pos: Position(
                  line: party_pos.row + pos.line,
                  column: party_pos.col + pos.column,
                ),
                unexpected: err.issue,
              ),
            ])
        }
      }
    }
  })
}

fn parse_component(components: List(Component)) -> ArcticParser {
  ArcticParser(fn(src, pos) {
    let res =
      party.go(
        {
          use _ <- party.do(party.char("@"))
          party.choice(
            list.map(components, fn(component) {
              use _ <- party.do(party.string(component.name))
              use _ <- party.do(party.whitespace())
              use res <- party.do(party.perhaps(party.char("(")))
              use args <- party.do(case res {
                Ok(_) -> {
                  use _ <- party.do(party.whitespace())
                  use a <- party.do(party.sep(
                    party.many1_concat(
                      party.satisfy(fn(c) { c != "," && c != ")" }),
                    ),
                    by: party.all([
                      party.whitespace(),
                      party.char(","),
                      party.whitespace(),
                    ]),
                  ))
                  use _ <- party.do(party.whitespace())
                  use _ <- party.do(party.char(")"))
                  party.return(a)
                }
                Error(Nil) -> party.return([])
              })
              use _ <- party.do(
                party.many(party.either(party.char(" "), party.char("\t"))),
              )
              use _ <- party.do(party.char("\n"))
              use body <- party.do(party.until(
                do: party.satisfy(fn(_) { True }),
                until: party.string("\n\n"),
              ))
              case component {
                StaticComponent(_, action:) -> {
                  use party_pos <- party.do(party.pos())
                  let pos2 =
                    Position(
                      line: pos.line + party_pos.row,
                      column: pos.column + party_pos.col,
                    )
                  use el <- party.do(
                    party.try(party.return(Nil), fn(_) {
                      action(args, string.concat(body), pos2)
                    }),
                  )
                  party.return(Some(el))
                }
                DynamicComponent(_) ->
                  party.return(
                    Some(
                      element.element(
                        component.name,
                        [
                          attribute.attribute(
                            "data-parameters",
                            string.join(args, ","),
                          ),
                          attribute.attribute("data-body", string.concat(body)),
                        ],
                        [],
                      ),
                    ),
                  )
              }
            }),
          )
        },
        src,
      )
    case res {
      Ok(t) -> ParseResult(val: t, errors: [])
      Error(err) -> {
        case err {
          party.Unexpected(party_pos, s) ->
            ParseResult(val: None, errors: [
              ParseError(
                pos: Position(
                  line: pos.line + party_pos.row,
                  column: pos.column + party_pos.col,
                ),
                unexpected: s,
              ),
            ])
          party.UserError(party_pos, err) ->
            ParseResult(val: None, errors: [
              ParseError(
                pos: Position(
                  line: pos.line + party_pos.row,
                  column: pos.column + party_pos.col,
                ),
                unexpected: err.issue,
                // TODO: should I show err.cause too? Since I have it?
              ),
            ])
        }
      }
    }
  })
}

fn parse_page(
  inline_rules: List(InlineRule),
  prefix_rules: List(PrefixRule),
  components: List(Component),
  src: String,
) -> Result(ParseResult(ParsedPage)) {
  // first pass: string to char list
  let graphemes = string.to_graphemes(src)
  // second pass: char list to section list with line numbers
  let #(last_sec, sections_rev, last_sec_line, _, _) =
    list.fold(
      over: graphemes,
      from: #("", [], 0, 0, False),
      with: fn(so_far, c) {
        let #(sec, secs, sec_line, curr_line, was_newline) = so_far
        case c {
          "\n" if was_newline -> #(
            "",
            [#(sec_line, sec), ..secs],
            curr_line + 1,
            curr_line + 1,
            True,
          )
          "\n" -> #(sec <> "\n", secs, sec_line, curr_line + 1, True)
          _ -> #(sec <> c, secs, sec_line, curr_line, False)
        }
      },
    )
  // third pass: append last section
  let sections = case last_sec {
    "" -> list.reverse(sections_rev)
    _ -> list.reverse([#(last_sec_line, last_sec), ..sections_rev])
  }
  // fourth pass: section list to parsed list 
  use #(#(_, meta_sec), body) <- result.try(case sections {
    [] -> snag.error("empty page")
    [h, ..t] -> Ok(#(h, t))
  })
  let meta_res = party.go(parse_metadata(dict.new()), meta_sec)
  let body_res =
    list.map(body, fn(sec) {
      let #(line, str) = sec
      case string.starts_with(str, "@") {
        True -> parse_component(components).parse(str, Position(line, 0))
        False ->
          parse_text(inline_rules, prefix_rules).parse(str, Position(line, 0))
      }
    })
  // fourth pass: collect ast and errors
  let #(body_ast_rev, body_errors_rev) =
    list.fold(over: body_res, from: #([], []), with: fn(so_far, res) {
      let #(ast_so_far, errors_so_far) = so_far
      #([res.val, ..ast_so_far], list.append(res.errors, errors_so_far))
    })
  // fifth pass: reverse ast and errors
  let metadata = case meta_res {
    Ok(sec) -> ParseResult(val: sec, errors: [])
    Error(err) -> {
      case err {
        party.Unexpected(pos, s) ->
          ParseResult(val: dict.new(), errors: [
            ParseError(
              pos: Position(line: pos.row, column: pos.col),
              unexpected: s,
            ),
          ])
        party.UserError(pos, err) ->
          ParseResult(val: dict.new(), errors: [
            ParseError(
              pos: Position(line: pos.row, column: pos.col),
              unexpected: err.issue,
            ),
          ])
      }
    }
  }
  Ok(ParseResult(
    val: ParsedPage(metadata.val, list.reverse(body_ast_rev)),
    errors: list.append(metadata.errors, list.reverse(body_errors_rev)),
  ))
}
