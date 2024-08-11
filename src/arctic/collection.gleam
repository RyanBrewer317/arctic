import arctic.{type Collection, type Page, Collection, RawPage}
import arctic/page
import arctic/parse
import birl
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order.{type Order, Eq}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html
import snag.{type Result}

pub fn new(dir: String) -> Collection {
  Collection(
    directory: dir,
    parse: default_parser(),
    index: None,
    rss: None,
    ordering: fn(_, _) { Eq },
    render: fn(_) {
      html.html([], [
        html.head([], []),
        html.body([], [
          text("No renderer set up for collection \"" <> dir <> "\"."),
        ]),
      ])
    },
    raw_pages: [],
  )
}

pub fn with_parser(
  c: Collection,
  parser: fn(String) -> Result(Page),
) -> Collection {
  Collection(
    c.directory,
    parser,
    c.index,
    c.rss,
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

pub fn default_parser() -> fn(String) -> Result(Page) {
  fn(src) {
    // TODO: rule/registration functions should get parser position info!!
    use tokenized <- result.try(parse.tokenize_page(
      [parse.InlineRule("*", "*", fn(el) { Ok(html.i([], [el])) })],
      [parse.PrefixRule("#", fn(el) { Ok(html.h1([], [el])) })],
      [
        parse.StaticRegistration("image", fn(args, label) {
          case args {
            [url] -> Ok(html.img([attribute.src(url), attribute.alt(label)]))
            [url, width] -> {
              let assert Ok(w) = int.base_parse(width, 10)
              html.img([
                attribute.src(url),
                attribute.width(w),
                attribute.alt(label),
              ])
              |> Ok
            }
            [url, width, height] -> {
              let assert Ok(w) = int.base_parse(width, 10)
              let assert Ok(h) = int.base_parse(height, 10)
              html.img([
                attribute.src(url),
                attribute.width(w),
                attribute.height(h),
                attribute.alt(label),
              ])
              |> Ok
            }
            _ -> snag.error("bad @image arguments `" <> string.join(args, ", ") <> "`")
          }
        }),
      ],
      src,
    ))
    case tokenized.errors {
      [first_e, ..rest] ->
        snag.error(
          "parse errors in `___` ("
          <> list.fold(
            rest,
            "unexpected "
              <> first_e.unexpected
              <> " at "
              <> int.to_string(first_e.line)
              <> ":"
              <> int.to_string(first_e.column),
            fn(s, e) {
              s
              <> ", unexpected "
              <> e.unexpected
              <> " at "
              <> int.to_string(e.line)
              <> ":"
              <> int.to_string(e.column)
            },
          )
          <> ")",
        )
      [] -> {
        use id <- result.try(
          dict.get(tokenized.val.metadata, "id")
          |> result.map_error(fn(_) { snag.new("no `id` field present") }),
        )
        use date <- result.try(case dict.get(tokenized.val.metadata, "date") {
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
          dict.get(tokenized.val.metadata, "blerb"),
          "",
        ))
        |> page.with_tags(
          result.unwrap(
            result.map(dict.get(tokenized.val.metadata, "tags"), string.split(
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
          dict.get(tokenized.val.metadata, "title"),
          "",
        ))
        |> page.with_body(
          list.map(tokenized.val.body, fn(token) {
            case token {
              parse.Markup(el) -> el
              parse.Component(f, _args, _body) ->
                panic as { "unknown component `" <> f <> "`" }
              parse.DidntParse -> panic as "DidntParse but no errors"
            }
          }),
        )
        |> Ok
      }
    }
  }
}

pub fn with_index(
  c: Collection,
  index: fn(List(Page)) -> Element(Nil),
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    Some(index),
    c.rss,
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

pub fn with_rss(c: Collection, rss: fn(List(Page)) -> String) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    Some(rss),
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

pub fn with_ordering(
  c: Collection,
  ordering: fn(Page, Page) -> Order,
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    c.rss,
    ordering,
    c.render,
    c.raw_pages,
  )
}

pub fn with_renderer(
  c: Collection,
  renderer: fn(Page) -> Element(Nil),
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    c.rss,
    c.ordering,
    renderer,
    c.raw_pages,
  )
}

pub fn with_raw_page(
  c: Collection,
  id: String,
  body: Element(Nil),
) -> Collection {
  Collection(c.directory, c.parse, c.index, c.rss, c.ordering, c.render, [
    RawPage(id, body),
    ..c.raw_pages
  ])
}
