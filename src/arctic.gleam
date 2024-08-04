import gleam/option.{type Option}
import gleam/order.{type Order}
import lustre/element.{type Element}
import snag.{type Result}
import gleam/dict.{type Dict}
import birl.{type Time}

pub type Collection {
  Collection(
    directory: String,
    parse: fn(String) -> Result(Page),
    index: Option(fn(List(Page)) -> Element(Nil)),
    rss: Option(fn(List(Page)) -> String),
  )
}

pub type Page {
  Page(
    id: String,
    above: fn(Page) -> Order,
    html: Element(Nil),
    metadata: Dict(String, String),
    date: Option(Time)
  )
}

pub type ProcessedCollection {
  ProcessedCollection(collection: Collection, pages: List(Page))
}

pub type MainPage {
  MainPage(id: String, html: Element(Nil))
}

pub type Config {
  Config(
    render_home: fn(List(ProcessedCollection)) -> Element(Nil),
    main_pages: List(MainPage),
  )
}
