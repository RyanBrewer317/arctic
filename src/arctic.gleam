import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/order.{type Order}
import lustre/element.{type Element}
import snag.{type Result}

pub type Collection {
  Collection(
    directory: String,
    parse: fn(String) -> Result(Page),
    index: Option(fn(List(Page)) -> Element(Nil)),
    rss: Option(fn(List(Page)) -> String),
    ordering: fn(Page, Page) -> Order,
    render: fn(Page) -> Element(Nil),
    raw_pages: List(RawPage),
  )
}

pub type Page {
  Page(
    id: String,
    body: List(Element(Nil)),
    metadata: Dict(String, String),
    title: String,
    blerb: String,
    tags: List(String),
    date: Option(Time),
  )
}

pub type ProcessedCollection {
  ProcessedCollection(collection: Collection, pages: List(Page))
}

pub type RawPage {
  RawPage(id: String, html: Element(Nil))
}

pub type Config {
  Config(
    render_home: fn(List(ProcessedCollection)) -> Element(Nil),
    main_pages: List(RawPage),
    collections: List(Collection),
  )
}
