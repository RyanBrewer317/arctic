import arctic.{type Collection, type Page, Collection, RawPage}
import gleam/option.{None, Some}
import gleam/order.{type Order, Eq}
import lustre/element.{type Element, text}
import lustre/element/html
import snag.{type Result}

pub fn new(dir: String) -> Collection {
  Collection(
    directory: dir,
    parse: fn(_) {
      snag.error("No parser set up for collection \"" <> dir <> "\".")
    },
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
