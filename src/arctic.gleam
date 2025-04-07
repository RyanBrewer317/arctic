import gleam/time/timestamp.{type Timestamp}
import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import lustre/element.{type Element}
import snag.{type Result}

/// A particular organization of pages, 
/// written either in custom markup or raw HTML.
/// A collection might be a set of products, or blog posts, or wiki entries.
/// A dedicated page can be generated to show off the pages in a collection,
/// and RSS feeds and whatnot can also be generated from the set of pages.
/// The pages are pulled from a particular directory,
/// and parsed and rendered a particular way,
/// that might be different from other collections.
/// See `arctic/collection` for more.
pub type Collection {
  Collection(
    directory: String,
    parse: fn(String, String) -> Result(Page),
    index: Option(fn(List(CacheablePage)) -> Element(Nil)),
    feed: Option(#(String, fn(List(CacheablePage)) -> String)),
    ordering: fn(Page, Page) -> Order,
    render: fn(Page) -> Element(Nil),
    raw_pages: List(RawPage),
  )
}

/// A single page in a collection.
/// These must have an ID to distinguish from other pages in the collection,
/// and a body of HTML elements.
/// Any other metadata can be added (stringly typed), 
/// and there are a variety of privileged metadata fields
/// like `.title` and `.date` that are actual typed properties.
/// However, these fields are optional.
/// See `arctic/page` for more.
pub type Page {
  Page(
    id: String,
    body: List(Element(Nil)),
    metadata: Dict(String, String),
    title: String,
    blerb: String,
    tags: List(String),
    date: Option(Timestamp),
  )
}

pub type CacheablePage {
  CachedPage(path: String, metadata: Dict(String, String))
  NewPage(Page)
}

pub fn to_dummy_page(c: CacheablePage) -> Page {
  case c {
    CachedPage(_, metadata) -> {
      let title = metadata |> dict.get("title") |> result.unwrap("")
      let blerb = metadata |> dict.get("blerb") |> result.unwrap("")
      let tags =
        metadata
        |> dict.get("tags")
        |> result.map(string.split(_, on: ","))
        |> result.unwrap([])
      let date =
        metadata
        |> dict.get("date")
        |> result.try(timestamp.parse_rfc3339)
        |> option.from_result
      Page(get_id(c), [], metadata:, title:, blerb:, tags:, date:)
    }
    NewPage(p) -> p
  }
}

pub fn get_id(p: CacheablePage) -> String {
  case p {
    CachedPage(_, metadata) -> {
      let assert Ok(id) = dict.get(metadata, "id")
      id
    }
    NewPage(page) -> page.id
  }
}

pub fn output_path(input_path: String) -> String {
  let assert [start, ""] = string.split(input_path, ".txt")
  "arctic_build/" <> start <> "/index.html"
}

/// A collection whose pages have been processed from the files.
pub type ProcessedCollection {
  ProcessedCollection(collection: Collection, pages: List(CacheablePage))
}

/// A page that is just HTML produced by hand.
pub type RawPage {
  RawPage(id: String, html: Element(Nil))
}

/// An Arctic configuration, describing all the collections, pages, parsing rules, etc.
pub type Config {
  Config(
    render_home: fn(List(ProcessedCollection)) -> Element(Nil),
    main_pages: List(RawPage),
    collections: List(Collection),
    render_spa: Option(fn(Element(Nil)) -> Element(Nil)),
  )
}
