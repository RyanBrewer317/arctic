import arctic.{type Collection, type Page, Collection, RawPage}
import arctic/parse
import gleam/int
import gleam/option.{None, Some}
import gleam/order.{type Order, Eq}
import gleam/string
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html
import snag.{type Result}

/// Produce a new collection, with default-everything and the given directory path.
/// You can use the other functions to modify the collection.
/// Or, collections can be produced manually with the `Collection` constructor from `arctic`.
pub fn new(dir: String) -> Collection {
  Collection(
    directory: dir,
    parse: default_parser(),
    index: None,
    feed: None,
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

/// Add a parser to a collection.
/// A parser processed the raw text and 
/// either fails with a message or produces a page.
/// See `arctic/parse` for help constructing these.
pub fn with_parser(
  c: Collection,
  parser: fn(String) -> Result(Page),
) -> Collection {
  Collection(
    c.directory,
    parser,
    c.index,
    c.feed,
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

/// A simple default parser for the sorts of things you'd expect when writing markup.
/// This also serves as a nice example of how to construct parsers.
pub fn default_parser() -> fn(String) -> Result(Page) {
  fn(src) {
    let parser =
      parse.new(Nil)
      |> parse.add_inline_rule("*", "*", parse.wrap_inline(html.i))
      |> parse.add_prefix_rule("#", parse.wrap_prefix(html.h1))
      |> parse.add_static_component("image", fn(args, label, data) {
        case args {
          [url] ->
            Ok(#(html.img([attribute.src(url), attribute.alt(label)]), Nil))
          _ -> {
            let pos = parse.get_pos(data)
            snag.error(
              "bad @image arguments `"
              <> string.join(args, ", ")
              <> "` at "
              <> int.to_string(pos.line)
              <> ":"
              <> int.to_string(pos.column),
            )
          }
        }
      })
    parse.parse(parser, src)
  }
}

/// Add an "index" to the collection.
/// An index is a page that shows off the pages in the collection, 
/// perhaps with a search bar and/or a list of pretty thumbnails.
/// Note that this would need to bring *all* the pages to the client side;
/// Pagination and search-via-server should be done in other ways.
/// Though this doesn't scale well to massive numbers of pages,
/// it's pretty easy to swap it out with something else when the number gets too high.
pub fn with_index(
  c: Collection,
  index: fn(List(Page)) -> Element(Nil),
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    Some(index),
    c.feed,
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

/// Add a "feed" to the collection.
/// A feed is a special text file generated based on the elements of the collection.
/// An RSS feed would be done this way.
pub fn with_feed(
  c: Collection,
  filename: String,
  render: fn(List(Page)) -> String,
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    Some(#(filename, render)),
    c.ordering,
    c.render,
    c.raw_pages,
  )
}

/// Add an ordering to a collection.
/// This specifies the order in which pages are listed 
/// on, say, a collection index.
pub fn with_ordering(
  c: Collection,
  ordering: fn(Page, Page) -> Order,
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    c.feed,
    ordering,
    c.render,
    c.raw_pages,
  )
}

/// Add a "renderer" to a collection.
/// A renderer is any Page->HTML function.
pub fn with_renderer(
  c: Collection,
  renderer: fn(Page) -> Element(Nil),
) -> Collection {
  Collection(
    c.directory,
    c.parse,
    c.index,
    c.feed,
    c.ordering,
    renderer,
    c.raw_pages,
  )
}

/// Add a "raw page" to a collection.
/// A raw page is just HTML, 
/// no parsing or processing will get applied.
pub fn with_raw_page(
  c: Collection,
  id: String,
  body: Element(Nil),
) -> Collection {
  Collection(c.directory, c.parse, c.index, c.feed, c.ordering, c.render, [
    RawPage(id, body),
    ..c.raw_pages
  ])
}
