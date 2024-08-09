import arctic.{
  type Collection, type Config, type ProcessedCollection, Config, RawPage,
}
import lustre/element.{type Element, text}
import lustre/element/html

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

pub fn home_renderer(
  config: Config,
  renderer: fn(List(ProcessedCollection)) -> Element(Nil),
) {
  Config(renderer, config.main_pages, config.collections)
}

pub fn add_main_page(config: Config, id: String, body: Element(Nil)) {
  Config(
    config.render_home,
    [RawPage(id, body), ..config.main_pages],
    config.collections,
  )
}

pub fn add_collection(config: Config, collection: Collection) {
  Config(config.render_home, config.main_pages, [
    collection,
    ..config.collections
  ])
}
