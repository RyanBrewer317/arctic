import arctic.{
  type Collection, type Config, type ProcessedCollection, Config, RawPage,
}
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
  )
}

/// Set the renderer for the home page of a site (`/index.html`).
/// Note that a list of all collections, with all of their pages, is provided if you'd like to use it.
pub fn home_renderer(
  config: Config,
  renderer: fn(List(ProcessedCollection)) -> Element(Nil),
) {
  Config(renderer, config.main_pages, config.collections)
}

/// Add a "main page" to an Arctic configuration.
/// Main pages are pages that aren't a part of any collection, like "Contact" or "About."
/// Note that the home page (`/index.html`) is handled via `home_renderer` instead.
pub fn add_main_page(config: Config, id: String, body: Element(Nil)) {
  Config(
    config.render_home,
    [RawPage(id, body), ..config.main_pages],
    config.collections,
  )
}

/// Add a "collection" to an Arctic configuration.
/// A collection holds a bunch of pages and their processing rules,
/// like a set of products, blog posts, wiki entries, etc.
/// See `arctic/collection` for more.
pub fn add_collection(config: Config, collection: Collection) {
  Config(config.render_home, config.main_pages, [
    collection,
    ..config.collections
  ])
}
