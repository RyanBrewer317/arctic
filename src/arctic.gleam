import common.{type Collection, type Config, type Page}
import gleam/list
import gleam/option.{None, Some}
import gleam/result.{map_error}
import lustre/ssg
import simplifile
import snag.{type Result}

fn read_collection(collection: Collection) -> Result(List(Page)) {
  use paths <- result.try(
    simplifile.get_files(in: collection.directory)
    |> map_error(fn(err) {
      snag.new(
        "couldn't get files in `"
        <> collection.directory
        <> "` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  list.try_fold(over: paths, from: [], with: fn(so_far, path) {
    use content <- result.try(
      map_error(simplifile.read(path), fn(err) {
        snag.new(
          "could not load file `"
          <> path
          <> "` ("
          <> simplifile.describe_error(err)
          <> ")",
        )
      }),
    )
    use p <- result.try(collection.parse(content))
    Ok([p, ..so_far])
  })
  |> result.map(list.reverse)
}

type ProcessedCollection {
  ProcessedCollection(collection: Collection, pages: List(Page))
}

fn process(collections: List(Collection)) -> Result(List(ProcessedCollection)) {
  use rest, collection <- list.try_fold(over: collections, from: [])
  use pages_unsorted <- result.try(read_collection(collection))
  let pages = list.sort(pages_unsorted, fn(p, q) { p.above(q) })
  Ok([ProcessedCollection(collection:, pages:), ..rest])
}

pub fn build(config: Config, collections: List(Collection)) -> Result(Nil) {
  use processed_collections <- result.try(process(collections))
  use ssg_config <- result.try(
    ssg.new("site")
    |> ssg.use_index_routes()
    |> ssg.add_static_route("/", config.render_home(collections))
    |> list.fold(over: config.main_pages, with: fn(ssg_config, page) {
      ssg.add_static_route(ssg_config, "/" <> page.id, page.html)
    })
    |> list.try_fold(
      over: processed_collections,
      with: fn(ssg_config, processed) {
        let ssg_config2 = case processed.collection.index {
          Some(render) ->
            ssg.add_static_route(
              ssg_config,
              "/" <> processed.collection.directory,
              render(processed.pages),
            )
          None -> ssg_config
        }
        list.fold(
          over: processed.pages,
          from: ssg_config2,
          with: fn(s, p: Page) {
            ssg.add_static_route(
              s,
              "/" <> processed.collection.directory <> "/" <> p.id,
              p.html,
            )
          },
        )
        |> Ok
      },
    ),
  )
  use _ <- result.try(
    ssg.build(ssg_config)
    |> map_error(fn(err) {
      case err {
        ssg.CannotCreateTempDirectory(file_err) ->
          snag.new(
            "couldn't create temp directory ("
            <> simplifile.describe_error(file_err)
            <> ")",
          )
        ssg.CannotWriteStaticAsset(file_err, path) ->
          snag.new(
            "couldn't put asset at `"
            <> path
            <> "` ("
            <> simplifile.describe_error(file_err)
            <> ")",
          )
        ssg.CannotGenerateRoute(file_err, path) ->
          snag.new(
            "couldn't generate `"
            <> path
            <> "` ("
            <> simplifile.describe_error(file_err)
            <> ")",
          )
        ssg.CannotWriteToOutputDir(file_err) ->
          snag.new(
            "couldn't move from temp directory to output directory ("
            <> simplifile.describe_error(file_err)
            <> ")",
          )
        ssg.CannotCleanupTempDir(file_err) ->
          snag.new(
            "couldn't remove temp directory ("
            <> simplifile.describe_error(file_err)
            <> ")",
          )
      }
    }),
  )
  use _ <- result.try(
    simplifile.create_directory("site/public")
    |> map_error(fn(err) {
      snag.new(
        "couldn't create directory `site/public` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  use _ <- result.try(
    simplifile.copy_directory(at: "public", to: "site/public")
    |> map_error(fn(err) {
      snag.new(
        "couldn't copy `public` to `site/public` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  use _ <- result.try(
    simplifile.create_file("site/public/feed.rss")
    |> map_error(fn(err) {
      snag.new(
        "couldn't create file `site/public/feed.rss` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  list.try_each(over: processed_collections, with: fn(processed) {
    case processed.collection.rss {
      Some(render) ->
        simplifile.write(
          contents: render(processed.pages),
          to: "site/public/feed.rss",
        )
        |> map_error(fn(err) {
          snag.new(
            "couldn't write to `site/public/feed.rss` ("
            <> simplifile.describe_error(err)
            <> ")",
          )
        })
      None -> Ok(Nil)
    }
  })
}
