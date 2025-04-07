import gleam/time/timestamp.{type Timestamp}
import arctic.{type Page, Page}
import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import lustre/element.{type Element}

/// Construct a new page, with the given ID and default-everything.
pub fn new(id: String) -> Page {
  Page(
    id: id,
    body: [],
    metadata: dict.new(),
    title: "",
    blerb: "",
    tags: [],
    date: None,
  )
}

/// Add a "body" to a page. 
/// A body is the list of elements that will appear when the page is loaded.
pub fn with_body(p: Page, body: List(Element(Nil))) -> Page {
  Page(..p, body:)
}

/// Add some metadata to a page.
/// This is any string key and value, that you can look up during parsing later.
/// Sorry for the lack of type safety! 
/// Processing mismatches are handled with `snag` results,
/// which is like compile-time errors since the run-time is at build-time.
/// Also, note that some metadata gets privileged fields store in a different way, 
/// like `.date`. This adds type safety and convenience, and is opt-in.
pub fn with_metadata(p: Page, key: String, val: String) -> Page {
  Page(..p, metadata: dict.insert(p.metadata, key, val))
}

/// Swap out the entirety of the metadata for a page with a new dictionary,
/// except for the privileged metadata like `.title` and `.date`.
/// This is useful for if you're building a metadata dictionary programmatically.
pub fn replace_metadata(p: Page, metadata: Dict(String, String)) -> Page {
  Page(..p, metadata:)
}

/// Add a title to a page.
pub fn with_title(p: Page, title: String) -> Page {
  Page(..p, title:)
}

/// Add a blerb (description, whatever) to a page.
/// This is useful for nice thumbnails.
pub fn with_blerb(p: Page, blerb: String) -> Page {
  Page(..p, blerb:)
}

/// Add tags to a page.
/// This is useful for implementing a helpful search.
pub fn with_tags(p: Page, tags: List(String)) -> Page {
  Page(..p, tags:)
}

/// Add a date to a page.
/// This is useful for sorting pages by date in a list,
/// like in a blog.
pub fn with_date(p: Page, date: Timestamp) -> Page {
  Page(..p, date: Some(date))
}
