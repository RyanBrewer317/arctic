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
  )
}

pub type Page {
  Page(id: String, above: fn(Page) -> Order, html: Element(Nil))
}

pub type MainPage {
  MainPage(id: String, html: Element(Nil))
}

pub type Config {
  Config(
    render_home: fn(List(Collection)) -> Element(Nil),
    main_pages: List(MainPage),
  )
}
