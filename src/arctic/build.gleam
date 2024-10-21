import arctic.{
  type CacheablePage, type Collection, type Config, type Page,
  type ProcessedCollection, type RawPage, CachedPage, NewPage,
  ProcessedCollection,
}
import birl
import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result.{map_error}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/ssg
import party
import simplifile
import snag.{type Result}

type Cache =
  Dict(String, #(BitArray, Dict(String, String)))

fn lift_ordering(
  ordering: fn(Page, Page) -> Order,
) -> fn(CacheablePage, CacheablePage) -> Order {
  fn(a, b) { ordering(arctic.to_dummy_page(a), arctic.to_dummy_page(b)) }
}

fn get_id(p: CacheablePage) -> String {
  case p {
    CachedPage(_, metadata) -> {
      let assert Ok(id) = dict.get(metadata, "id")
      id
    }
    NewPage(page) -> page.id
  }
}

fn to_metadata(csv: List(String)) -> Result(Dict(String, String)) {
  case csv {
    [] -> Ok(dict.new())
    [pair_str, ..rest] ->
      case string.split(pair_str, ":") {
        [] -> snag.error("malformed cache (metadata item with no colon)")
        [key, ..vals] -> {
          use rest2 <- result.try(to_metadata(rest))
          Ok(dict.insert(rest2, key, string.join(vals, ":")))
        }
      }
  }
}

fn to_cache(csv: List(List(String))) -> Result(Cache) {
  case csv {
    [] -> Ok(dict.new())
    [[id, hash, ..metadata], ..rest] -> {
      use rest2 <- result.try(to_cache(rest))
      use metadata2 <- result.try(to_metadata(metadata))
      use hash_str <- result.try(
        bit_array.base64_decode(hash)
        |> map_error(fn(_) {
          snag.new(
            "malformed cache (`" <> hash <> "` is not a valid base-64 hash)",
          )
        }),
      )
      Ok(dict.insert(rest2, id, #(hash_str, metadata2)))
    }
    [malformed_row, ..] ->
      snag.error(
        "malformed cache (row `" <> string.join(malformed_row, ", ") <> "`)",
      )
  }
}

fn parse_csv(csv: String) -> Result(List(List(String))) {
  let res =
    party.go(
      {
        use _ <- party.do(party.char("\""))
        use val <- party.do(
          party.many_concat(party.either(
            party.map(party.string("\"\""), fn(_) { "\"" }),
            party.satisfy(fn(c) { c != "\"" }),
          )),
        )
        use _ <- party.do(party.char("\""))
        party.return(val)
      }
        |> party.sep(by: party.char(","))
        |> fn(p) {
          party.do(p, fn(row) { party.seq(party.char("\n"), party.return(row)) })
        }
        |> party.many(),
      csv,
    )
  map_error(res, fn(e) {
    case e {
      party.Unexpected(p, s) ->
        snag.new(
          s <> " at " <> int.to_string(p.row) <> ":" <> int.to_string(p.col),
        )
      party.UserError(p, Nil) ->
        snag.new(
          "internal Arctic error at "
          <> int.to_string(p.row)
          <> ":"
          <> int.to_string(p.col),
        )
    }
  })
}

fn read_collection(
  collection: Collection,
  cache: Cache,
) -> Result(List(CacheablePage)) {
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
    let new_hash = crypto.hash(crypto.Sha256, bit_array.from_string(content))
    case dict.get(cache, path) {
      Ok(#(current_hash, metadata)) if current_hash == new_hash ->
        Ok([CachedPage(path, metadata), ..so_far])
      _ -> {
        // something changed or the page is new
        use p <- result.try(collection.parse(path, content))
        use _ <- result.try(
          simplifile.append(
            ".arctic_cache.csv",
            "\""
              <> string.replace(path, each: "\"", with: "\"\"")
              <> "\",\""
              <> bit_array.base64_encode(new_hash, False)
              <> "\",\"id:"
              <> string.replace(p.id, each: "\"", with: "\"\"")
              <> "\",\"title:"
              <> string.replace(p.title, each: "\"", with: "\"\"")
              <> "\""
              <> option.unwrap(
              option.map(p.date, fn(d) {
                ",\"date:" <> birl.to_naive_date_string(d) <> "\""
              }),
              "",
            )
              <> ",\"tags:"
              <> string.join(
              list.map(p.tags, string.replace(_, "\"", "\"\"")),
              ",",
            )
              <> "\",\"blerb:"
              <> string.replace(p.blerb, "\"", "\"\"")
              <> "\""
              <> dict.fold(over: p.metadata, from: "", with: fn(b, k, v) {
              b
              <> ",\""
              <> string.replace(k, "\"", "\"\"")
              <> ":"
              <> string.replace(v, "\"", "\"\"")
              <> "\""
            })
              <> "\n",
          )
          |> map_error(fn(err) {
            snag.new(
              "couldn't write to cache ("
              <> simplifile.describe_error(err)
              <> ")",
            )
          }),
        )
        Ok([NewPage(p), ..so_far])
      }
    }
  })
  |> result.map(list.reverse)
}

fn process(
  collections: List(Collection),
  cache: Cache,
) -> Result(List(ProcessedCollection)) {
  use rest, collection <- list.try_fold(over: collections, from: [])
  use pages_unsorted <- result.try(read_collection(collection, cache))
  let pages = list.sort(pages_unsorted, lift_ordering(collection.ordering))
  Ok([ProcessedCollection(collection:, pages:), ..rest])
}

/// Fill out an `arctic_build` directory from an Arctic configuration.
pub fn build(config: Config) -> Result(Nil) {
  // create the cache if it doesn't exist, ignore Error thrown if it does
  let _ = simplifile.create_file(".arctic_cache.csv")
  use content <- result.try(
    simplifile.read(".arctic_cache.csv")
    |> map_error(fn(err) {
      snag.new("couldn't read cache (" <> simplifile.describe_error(err) <> ")")
    }),
  )
  use csv <- result.try(case content {
    "" -> Ok([])
    _ ->
      parse_csv(content)
      |> snag.context("couldn't parse cache")
  })
  // the reverse is so that later entries override earlier ones
  // In the future we should also clean up the cache file, at least periodically.
  use cache <- result.try(to_cache(list.reverse(csv)))
  use processed_collections <- result.try(process(config.collections, cache))
  use ssg_config <- make_ssg_config(processed_collections, config)
  use <- ssg_build(ssg_config)
  use <- add_public()
  use <- add_feed(processed_collections)
  use <- add_vite_config(config, processed_collections)
  Ok(Nil)
}

fn spa(
  frame: fn(Element(Nil)) -> Element(Nil),
  home: Element(Nil),
) -> Element(Nil) {
  frame(
    html.div([], [
      html.div([attribute.id("arctic-app")], [home]),
      html.script(
        [],
        "
if (window.location.pathname !== '/') {
  go_to(new URL(window.location.href));
}
// SPA algorithm stolen from Hayleigh Thompson's wonderful Modem library
async function go_to(url, no_loader) {
  const $app = document.getElementById('arctic-app');
  if (!no_loader) $app.innerHTML = '<div id=\"arctic-loader\"></div>';
  window.history.pushState({}, '', url.href);
  window.requestAnimationFrame(() => {
    // scroll in #-link elements, as the browser would if we didn't preventDefault
    if (url.hash) {
      document.getElementById(url.hash.slice(1))?.scrollIntoView();
    }
  });
  // handle new path
  console.log(url.pathname);
  const response = await fetch('/__pages/' + url.pathname + '/index.html');
  if (!response.ok) response = await fetch('/__pages/404.html');
  if (!response.ok) return;
  const html = await response.text();
  $app.innerHTML = html;
}
document.addEventListener('click', async function(e) {
  const a = find_a(e.target);
  if (!a) return;
  try {
    const url = new URL(a.href);
    const is_external = url.host !== window.location.host;
    if (is_external) return;
    event.preventDefault();
    go_to(url);
  } catch {
    return;
  }
});
window.addEventListener('popstate', (e) => {
  e.preventDefault();
  const url = new URL(window.location.href);
  go_to(url);
});
function find_a(target) {
  if (!target || target.tagName === 'BODY') return null;
  if (target.tagName === 'A') return target;
  return find_a(target.parentElement);
}
  ",
      ),
    ]),
  )
}

fn make_ssg_config(
  processed_collections: List(ProcessedCollection),
  config: Config,
  k: fn(ssg.Config(ssg.HasStaticRoutes, ssg.NoStaticDir, ssg.UseIndexRoutes)) ->
    Result(Nil),
) -> Result(Nil) {
  let home = config.render_home(processed_collections)
  let dir = case config.render_spa {
    Some(_) -> "/__pages/"
    None -> "/"
  }
  use ssg_config <- result.try(
    ssg.new("arctic_build")
    |> ssg.use_index_routes()
    |> ssg.add_static_route(dir, home)
    |> fn(ssg_config) {
      case config.render_spa {
        Some(frame) -> ssg.add_static_route(ssg_config, "/", spa(frame, home))
        None -> ssg_config
      }
    }
    |> list.fold(over: config.main_pages, with: fn(ssg_config, page) {
      ssg.add_static_route(ssg_config, dir <> page.id, page.html)
    })
    |> list.try_fold(
      over: processed_collections,
      with: fn(ssg_config, processed) {
        let ssg_config2 = case processed.collection.index {
          Some(render) ->
            ssg.add_static_route(
              ssg_config,
              dir <> processed.collection.directory,
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
                dir <> processed.collection.directory <> "/" <> rp.id,
                rp.html,
              )
            },
          )
        list.fold(over: processed.pages, from: ssg_config3, with: fn(s, p) {
          case p {
            NewPage(new_page) ->
              ssg.add_static_route(
                s,
                dir
                  <> processed.collection.directory
                  <> "/"
                  <> new_page.id,
                processed.collection.render(new_page),
              )
            CachedPage(path, _) -> {
              let assert [start, ..] = string.split(path, ".txt")
              let cached_path = "arctic_build" <> dir <> start <> "/index.html"
              let res = simplifile.read(cached_path)
              let content = case res {
                Ok(c) -> c
                Error(_) -> panic as cached_path
              }
              ssg.add_static_asset(
                s,
                dir <> start <> "/index.html",
                content,
              )
            }
          }
        })
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
      option_to_result_nil(processed.collection.feed, fn(feed) {
        simplifile.write(
          contents: feed.1(processed.pages),
          to: "arctic_build/public/" <> feed.0,
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
  let dir = case config.render_spa {
    Some(_) -> "/__pages/"
    None -> "/"
  }
  let main_pages =
    list.fold(over: config.main_pages, from: "", with: fn(js, page) {
      js
      <> "\""
      <> page.id
      <> "\": \"arctic_build"
      <> dir
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
        <> get_id(page)
        <> "\": \"arctic_build"
        <> dir
        <> processed.collection.directory
        <> "/"
        <> get_id(page)
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
