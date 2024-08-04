import arctic.{type Page, Page}
import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import birl.{type Time}
import lustre/element.{type Element}
import lustre/element/html

pub fn new(id: String) -> Page {
  Page(
    id: id,
    html: html.html([], [html.head([], []), html.body([], [])]),
    metadata: dict.new(),
    title: "",
    blerb: "",
    tags: [],
    date: None,
  )
}

pub fn with_html(p: Page, html: Element(Nil)) -> Page {
  Page(p.id, html, p.metadata, p.title, p.blerb, p.tags, p.date)
}

pub fn with_metadata(p: Page, key: String, val: String) -> Page {
  Page(
    p.id,
    p.html,
    dict.insert(p.metadata, key, val),
    p.title,
    p.blerb,
    p.tags,
    p.date,
  )
}

pub fn replace_metadata(p: Page, metadata: Dict(String, String)) -> Page {
  Page(
    p.id,
    p.html,
    metadata,
    p.title,
    p.blerb,
    p.tags,
    p.date,
  )
}

pub fn with_title(p: Page, title: String) -> Page {
  Page(p.id, p.html, p.metadata, title, p.blerb, p.tags, p.date)
}

pub fn with_blerb(p: Page, blerb: String) -> Page {
  Page(p.id, p.html, p.metadata, p.title, blerb, p.tags, p.date)
}

pub fn with_tags(p: Page, tags: List(String)) -> Page {
  Page(p.id, p.html, p.metadata, p.title, p.blerb, tags, p.date)
}

pub fn with_date(p: Page, date: Time) -> Page {
  Page(p.id, p.html, p.metadata, p.title, p.blerb, p.tags, Some(date))
}
