import arctic.{type Page, Page}
import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import lustre/element.{type Element}

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

pub fn with_body(p: Page, body: List(Element(Nil))) -> Page {
  Page(p.id, body, p.metadata, p.title, p.blerb, p.tags, p.date)
}

pub fn with_metadata(p: Page, key: String, val: String) -> Page {
  Page(
    p.id,
    p.body,
    dict.insert(p.metadata, key, val),
    p.title,
    p.blerb,
    p.tags,
    p.date,
  )
}

pub fn replace_metadata(p: Page, metadata: Dict(String, String)) -> Page {
  Page(p.id, p.body, metadata, p.title, p.blerb, p.tags, p.date)
}

pub fn with_title(p: Page, title: String) -> Page {
  Page(p.id, p.body, p.metadata, title, p.blerb, p.tags, p.date)
}

pub fn with_blerb(p: Page, blerb: String) -> Page {
  Page(p.id, p.body, p.metadata, p.title, blerb, p.tags, p.date)
}

pub fn with_tags(p: Page, tags: List(String)) -> Page {
  Page(p.id, p.body, p.metadata, p.title, p.blerb, tags, p.date)
}

pub fn with_date(p: Page, date: Time) -> Page {
  Page(p.id, p.body, p.metadata, p.title, p.blerb, p.tags, Some(date))
}
