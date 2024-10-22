import arctic.{
  type Collection, type Config, type ProcessedCollection, Config, RawPage,
}
import gleam/option.{None, Some}
import lustre/element.{type Element, text}
import lustre/element/html

/// Produce a new Arctic configuration, with default settings.
/// An Arctic configuration holds all the collections, pages, parsing rules, etc.
pub fn new() -> Config {
  Config(
    render_home: fn(_) {
      html.html([], [
        html.head([], []),
        html.body([], [text("No renderer set up for home page")]),
      ])
    },
    main_pages: [],
    collections: [],
    render_spa: Some(fn(body) { body }),
  )
}

/// Set the renderer for the home page of a site (`/index.html`).
/// Note that a list of all collections, with all of their pages, is provided if you'd like to use it.
pub fn home_renderer(
  config: Config,
  renderer: fn(List(ProcessedCollection)) -> Element(Nil),
) {
  Config(..config, render_home: renderer)
}

/// Add a "main page" to an Arctic configuration.
/// Main pages are pages that aren't a part of any collection, like "Contact" or "About."
/// Note that the home page (`/index.html`) is handled via `home_renderer` instead.
pub fn add_main_page(config: Config, id: String, body: Element(Nil)) {
  Config(..config, main_pages: [RawPage(id, body), ..config.main_pages])
}

/// Add a "collection" to an Arctic configuration.
/// A collection holds a bunch of pages and their processing rules,
/// like a set of products, blog posts, wiki entries, etc.
/// See `arctic/collection` for more.
pub fn add_collection(config: Config, collection: Collection) {
  Config(..config, collections: [collection, ..config.collections])
}

/// Specify code that is on the outside of a page, 
/// and doesn't get re-rendered on page navigation.
/// This can be nav bars, a `head` element, side panels, footer, etc.
pub fn add_spa_frame(config: Config, frame: fn(Element(Nil)) -> Element(Nil)) {
  Config(..config, render_spa: Some(frame))
}

/// Generate the site as a directory of files,
/// instead of as a single-page app with clever routing.
pub fn turn_off_spa(config: Config) {
  Config(..config, render_spa: None)
}
