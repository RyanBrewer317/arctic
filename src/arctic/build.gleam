import arctic.{
  type Collection, type Config, type Page, type ProcessedCollection,
  type RawPage, ProcessedCollection,
}
import gleam/list
import gleam/option.{type Option, None, Some}
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

fn process(collections: List(Collection)) -> Result(List(ProcessedCollection)) {
  use rest, collection <- list.try_fold(over: collections, from: [])
  use pages_unsorted <- result.try(read_collection(collection))
  let pages = list.sort(pages_unsorted, collection.ordering)
  Ok([ProcessedCollection(collection:, pages:), ..rest])
}

pub fn build(config: Config) -> Result(Nil) {
  use processed_collections <- result.try(process(config.collections))
  use ssg_config <- make_ssg_config(processed_collections, config)
  use <- ssg_build(ssg_config)
  use <- add_public()
  use <- add_feed(processed_collections)
  use <- add_vite_config(config, processed_collections)
  Ok(Nil)
}

fn make_ssg_config(
  processed_collections: List(ProcessedCollection),
  config: Config,
  k: fn(ssg.Config(ssg.HasStaticRoutes, ssg.NoStaticDir, ssg.UseIndexRoutes)) ->
    Result(Nil),
) -> Result(Nil) {
  use ssg_config <- result.try(
    ssg.new("arctic_build")
    |> ssg.use_index_routes()
    |> ssg.add_static_route("/", config.render_home(processed_collections))
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
        let ssg_config3 =
          list.fold(
            over: processed.collection.raw_pages,
            from: ssg_config2,
            with: fn(s, rp: RawPage) {
              ssg.add_static_route(
                s,
                "/" <> processed.collection.directory <> "/" <> rp.id,
                rp.html,
              )
            },
          )
        list.fold(
          over: processed.pages,
          from: ssg_config3,
          with: fn(s, p: Page) {
            ssg.add_static_route(
              s,
              "/" <> processed.collection.directory <> "/" <> p.id,
              processed.collection.render(p),
            )
          },
        )
        |> Ok
      },
    ),
  )
  k(ssg_config)
}

fn ssg_build(ssg_config, k: fn() -> Result(Nil)) -> Result(Nil) {
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
  k()
}

fn add_public(k: fn() -> Result(Nil)) -> Result(Nil) {
  use _ <- result.try(
    simplifile.create_directory("arctic_build/public")
    |> map_error(fn(err) {
      snag.new(
        "couldn't create directory `arctic_build/public` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  use _ <- result.try(
    simplifile.copy_directory(at: "public", to: "arctic_build/public")
    |> map_error(fn(err) {
      snag.new(
        "couldn't copy `public` to `arctic_build/public` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  k()
}

fn option_to_result_nil(opt: Option(a), f: fn(a) -> Result(Nil)) -> Result(Nil) {
  case opt {
    Some(a) -> f(a)
    None -> Ok(Nil)
  }
}

fn add_feed(
  processed_collections: List(ProcessedCollection),
  k: fn() -> Result(Nil),
) -> Result(Nil) {
  use _ <- result.try({
    simplifile.create_file("arctic_build/public/feed.rss")
    |> map_error(fn(err) {
      snag.new(
        "couldn't create file `arctic_build/public/feed.rss` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    })
  })
  use _ <- result.try({
    list.try_each(over: processed_collections, with: fn(processed) {
      option_to_result_nil(processed.collection.rss, fn(render) {
        simplifile.write(
          contents: render(processed.pages),
          to: "arctic_build/public/feed.rss",
        )
        |> map_error(fn(err) {
          snag.new(
            "couldn't write to `arctic_build/public/feed.rss` ("
            <> simplifile.describe_error(err)
            <> ")",
          )
        })
      })
    })
  })
  k()
}

fn add_vite_config(
  config: Config,
  processed_collections: List(ProcessedCollection),
  k: fn() -> Result(Nil),
) -> Result(Nil) {
  let home_page = "\"main\": \"arctic_build/index.html\""
  let main_pages =
    list.fold(over: config.main_pages, from: "", with: fn(js, page) {
      js
      <> "\""
      <> page.id
      <> "\": \"arctic_build/"
      <> page.id
      <> "/index.html\", "
    })
  let collected_pages =
    list.fold(over: processed_collections, from: "", with: fn(js, processed) {
      list.fold(over: processed.pages, from: js, with: fn(js, page) {
        js
        <> "\""
        <> processed.collection.directory
        <> "/"
        <> page.id
        <> "\": \"arctic_build/"
        <> processed.collection.directory
        <> "/"
        <> page.id
        <> "/index.html\", "
      })
    })
  use _ <- result.try(
    simplifile.write(to: "arctic_vite_config.js", contents: "
  // NOTE: AUTO-GENERATED! DO NOT EDIT!
  export default {" <> main_pages <> collected_pages <> home_page <> "};")
    |> map_error(fn(err) {
      snag.new(
        "couldn't create `arctic_vite_config.js` ("
        <> simplifile.describe_error(err)
        <> ")",
      )
    }),
  )
  k()
}
