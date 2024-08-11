import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/element.{type Element}
import lustre/element/html
import party.{type Parser}
import snag.{type Result}

// I managed to make this without exposing anything from Party, so that's good!
// It definitely could use some optimization.
// There's even a lot of room for concurrency!

pub type Token {
  Markup(Element(Nil))
  Component(func: String, args: List(String), body: String)
  DidntParse
}

pub type TokenizedPage {
  TokenizedPage(metadata: Dict(String, String), body: List(Token))
}

pub type TokenizeResult(a) {
  TokenizeResult(val: a, errors: List(ParseError))
}

pub type ParseError {
  ParseError(line: Int, column: Int, unexpected: String)
}

type Tokenizer {
  Tokenizer(tokenize: fn(String, party.Position) -> TokenizeResult(Token))
}

pub type InlineRule {
  InlineRule(
    left: String,
    right: String,
    action: fn(Element(Nil)) -> Result(Element(Nil)),
  )
}

pub type PrefixRule {
  PrefixRule(prefix: String, action: fn(Element(Nil)) -> Result(Element(Nil)))
}

pub type Component

pub type Registration {
  StaticRegistration(
    name: String,
    action: fn(List(String), String) -> Result(Element(Nil)),
  )
  DynamicRegistration(name: String)
}

fn tokenize_metadata(
  start_dict: Dict(String, String),
) -> Parser(Dict(String, String), Nil) {
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
      tokenize_metadata(d)
    }
    Error(Nil) -> {
      party.return(start_dict)
    }
  }
}

fn tokenize_prefix() -> Parser(String, Nil) {
  party.many_concat(
    party.satisfy(string.contains(
      does: "~`!#$%^&*-_=+{[|;:<>,./?]}",
      contain: _,
    )),
  )
}

fn escaped_char() -> Parser(String, Nil) {
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
            does: "1234567890abcdefgABCDEFG",
            contain: _,
          )),
        ),
      )
      use _ <- party.do(party.whitespace())
      use _ <- party.do(party.char("}"))
      let assert Ok(code) = int.base_parse(code_str, 16)
      case string.utf_codepoint(code) {
        Ok(codepoint) -> party.return(string.from_utf_codepoints([codepoint]))

        // TODO: make sure this is actually failing at the right parser position, instead of just after
        Error(_) -> party.fail()
      }
    }
    _ -> party.return(c)
  }
}

fn tokenize_markup(
  inline_rules: List(InlineRule),
  until terminator: String,
) -> Parser(Element(Nil), Nil) {
  party.choice(
    list.map(inline_rules, fn(rule) {
      use _ <- party.do(party.string(rule.left))
      use middle <- party.do(
        party.lazy(fn() { tokenize_markup(inline_rules, until: rule.right) }),
      )
      case rule.action(middle) {
        Ok(el) -> party.return(el)
        Error(_snag) -> party.fail()
      }
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

fn tokenize_text(
  inline_rules: List(InlineRule),
  prefix_rules: List(PrefixRule),
) -> Tokenizer {
  Tokenizer(fn(src, pos) {
    let res =
      party.go(
        {
          use prefix <- party.do(tokenize_prefix())
          use _ <- party.do(
            party.many(party.either(party.char(" "), party.char("\t"))),
          )
          use rest <- party.do(tokenize_markup(inline_rules, until: "\n\n"))
          use el <- party.do(case
            list.find(prefix_rules, fn(rule) { rule.prefix == prefix })
          {
            Ok(rule) ->
              case rule.action(rest) {
                Ok(el) -> party.return(el)
                Error(_snag) -> party.fail()
              }
            Error(Nil) ->
              party.return(html.div([], [element.text(prefix), rest]))
          })
          party.return(Markup(el))
        },
        src,
      )
    case res {
      Ok(t) -> TokenizeResult(val: t, errors: [])
      Error(err) -> {
        let assert party.Unexpected(party_pos, s) = err
        TokenizeResult(val: DidntParse, errors: [
          ParseError(
            line: party_pos.row + pos.row,
            column: party_pos.col + pos.col,
            unexpected: s,
          ),
        ])
      }
    }
  })
}

fn tokenize_component(registry: List(Registration)) -> Tokenizer {
  Tokenizer(fn(src, pos) {
    let res =
      party.go(
        {
          use _ <- party.do(party.char("@"))
          party.choice(
            list.map(registry, fn(registration) {
              use _ <- party.do(party.string(registration.name))
              use _ <- party.do(party.whitespace())
              use res <- party.do(party.perhaps(party.char("(")))
              use args <- party.do(case res {
                Ok(_) -> {
                  use _ <- party.do(party.whitespace())
                  use a <- party.do(party.sep(
                    party.many1_concat(party.satisfy(fn(c) { c != "," })),
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
              case registration {
                StaticRegistration(_, action:) ->
                  case action(args, string.concat(body)) {
                    Ok(el) -> party.return(Markup(el))
                    Error(_snag) -> party.fail()
                  }
                DynamicRegistration(_) ->
                  party.return(Component(
                    registration.name,
                    args,
                    string.concat(body),
                  ))
              }
            }),
          )
        },
        src,
      )
    case res {
      Ok(t) -> TokenizeResult(val: t, errors: [])
      Error(err) -> {
        let assert party.Unexpected(party_pos, s) = err
        TokenizeResult(val: DidntParse, errors: [
          ParseError(
            line: pos.row + party_pos.row,
            column: pos.col + party_pos.col,
            unexpected: s,
          ),
        ])
      }
    }
  })
}

pub fn tokenize_page(
  inline_rules: List(InlineRule),
  prefix_rules: List(PrefixRule),
  registry: List(Registration),
  src: String,
) -> Result(TokenizeResult(TokenizedPage)) {
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
  // fourth pass: section list to token list 
  use #(#(_, meta_sec), body) <- result.try(case sections {
    [] -> snag.error("empty page")
    [h, ..t] -> Ok(#(h, t))
  })
  let meta_res = party.go(tokenize_metadata(dict.new()), meta_sec)
  let body_res =
    list.map(body, fn(sec) {
      let #(line, str) = sec
      case string.starts_with(str, "@") {
        True ->
          tokenize_component(registry).tokenize(str, party.Position(line, 0))
        False ->
          tokenize_text(inline_rules, prefix_rules).tokenize(
            str,
            party.Position(line, 0),
          )
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
    Ok(sec) -> TokenizeResult(val: sec, errors: [])
    Error(err) -> {
      let assert party.Unexpected(pos, s) = err
      TokenizeResult(val: dict.new(), errors: [
        ParseError(line: pos.row, column: pos.col, unexpected: s),
      ])
    }
  }
  Ok(TokenizeResult(
    val: TokenizedPage(metadata.val, list.reverse(body_ast_rev)),
    errors: list.append(metadata.errors, list.reverse(body_errors_rev)),
  ))
}
