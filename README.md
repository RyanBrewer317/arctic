# Arctic

[![Package Version](https://img.shields.io/hexpm/v/arctic)](https://hex.pm/packages/arctic)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/arctic/)

Arctic is a declarative web framework for building fast sites in the way you want. You specify what sorts of elements a markup file can have and how you notate those elements, and Arctic cranks out an optimized site that can be hosted on a static CDN and supported by servers or serverless functions. This maximizes page startup times.

Arctic doesn't take away your range of expression, it merely tries to act as shorthand. To do so, Arctic uses a modular process that lets you describe each part of each page in the way you want. A page can be mostly written in customized markup, and then in the middle you can write latex, HTML, gleam, or your own thing!

Arctic is still very much a work in progress. Packages for common languages like those mentioned above should be added. We need better comments and documentation. Pages aren't well optimized yet. The rendering part is still pretty DIY. If you're interested in this project, please chip in! Anyone is welcome to contribute. Also consider sponsoring me, so I have more time to work on this!

Arctic is very frontend-oriented. I think it would be paired very well with the sort of work coming out of the Pevensie project, which is generally on the server side. In the more immediate future, Wisp/Mist is a great Gleam backend that's available right now! More generally, you should be able to pair an Arctic codebase with servers written in any language, or serverless functions, or just serve the Arctic site statically from a CDN!

## Quickstart

A proper quickstart guide can be found [here](https://arctic-framework.org/guides/quickstart). But the code block below gives a good sense of how the library works:

```sh
gleam add arctic
```
```gleam
import arctic/build
import arctic/collection
import arctic/config
import arctic/parse
import app
import lustre/element/html
import snag

pub fn main() {
  let post_parser = parse.new()
    |> parse.add_inline_rule("_", "_", parse.wrap(html.i))
  let posts = collection.new("posts")
    |> collection.with_parser(post_parser)
    |> collection.with_index(app.post_index)
    |> collection.with_renderer(app.post_renderer)
  let config = config.new()
    |> config.home_renderer(app.render_homepage)
    |> config.add_collection(posts)
    |> config.add_main_page("404", app.unknown_page_html)
  let res = build.build(config)
  case res {
    Ok(Nil) -> io.println("Success!")
    Error(err) -> io.println(snag.pretty_print(err))
  }
}
```

Further documentation can be found at <https://hexdocs.pm/arctic>.

## Development
Some features mentioned here can be separate libraries on Hex, called `arctic_rss` or whatever and allowing imports like `arctic/rss`. That'd be cool. Maybe `arctic_plugin_` is a better prefix, with `arctic/plugin/rss` for example, to ensure safer namespacing. Obviously anyone could develop these packages, and a bigger ecosystem is better!

Here's a list of things I want to accomplish. They generally aren't hard. For some of the components I imagined just `shellout`ing to other tools and `simplifile`ing the result back into memory, or into an assets folder, or whatever. I already do this with latex on my personal site. However, the list is long, and contributions from others would help a lot in getting it done. Note that there are other important things Arctic needs to be able to do; me not including them here just means that Arctic is already doing them :)

(Note from the future: As I complete these, I mark them instead of deleting them, just for fun. So some of these are already done!)

 - [x] Threaded state of page parsing, such as for generating unique IDs and filenames.
 - [x] Caching of whole processed pages when they haven't changed.
 - [ ] Caching of the output of components when we know that they haven't changed since last process. We can optimize a lot by only building the paragraphs that have changed, at the cost of hard-disk space. See comments on memory usage below. Assets generated by components, like images or whatever, wouldn't get rerendered if the component isn't rerun, so they get that caching for free. Notice that with Lustre Dev Tools watching for file changes, every rebuild would instantly put the rendered stuff on the page in real time. If we wanted to go real crazy we could file-watch the arctic markup files too, so you could edit in your DSL and watch the results appear in real time!
 - [x] Right now pages are just thrown in a directory and served statically. We could instead generate a collection of SSR'd SPA `index.html` files, that route with `modem` and query for pages from a separate static collection, injecting the HTML a little like HTMX. This would be part of the optimization Arctic hopes to offer. It's reminiscent of the way AstroJS works, from what I understand. We could always offer a `Config` setting, or a different `build` function, to use the normal process instead. Note that we'll need to restructure a little for this, because the stuff that an SPA keeps around (nav bar, side panels, footer, etc.) isn't represented in any usable way, it's just produced by render functions. We can use the global event bus to tell them to rerender and how, if they need to. The SPA approach shouldn't be less expressive.
 - [ ] There isn't a great way to use a whole-page Lustre application that is partially written with Arctic markup. We should be able to inject Arctic-rendered HTML into normal gleam applications, to be used in, say, a Lustre `view` function.
 - [ ] It would be good to integrate with `nakai`, due to its use in the community, but I'm really not sure how that would work. I need to think about it more.
 - [ ] A `sketch` integration would be cool. I've talked to the author about it but that's all so far. I'm not sure exactly what we'd do differently from `sketch/lustre`, maybe just routing the styles in an optimal way into parts of the produced site.
 - [ ] Main pages are always rendered as a directory with an `index.html` file right now. It'd be good to change that so you can do that if you want or you can add something like a `404.html`.
 - [ ] On the BEAM target, we should be able to trivially parallelize a ton of Arctic's work.
 - [ ] Generate a `sitemap.xml` for improved performance and SEO.
 - [ ] Better rendering convenience/modularity. It should be like how parsing is now.
 - [ ] Better metadata validation.
 - [ ] Better Lustre component (custom element) support. They're a big pain to use right now and it'd be great if you could write the model type and the three functions as a block in the page and have that get copy-pasted into a gleam file to produce the custom component. This is super doable and can give correct error message file positions. Ideally this can even import from your other gleam files, we just have to make sure the file paths line up the right way.
 - [ ] RSS feed renderer
 - [ ] HTML component
 - [ ] Common inline rules: bold, links, strikethrough, underline, code, latex, footnote, etc.
 - [ ] Common prefix rules: lists, headers, horizontal rule, image, code block with language, footnote, table, block quote, etc.
 - [ ] A better default parser, with all the expected markdown features.
 - [ ] Latex component (builds on your own system with your packages)
 - [ ] Gleam component (imports and correct error message positions should be possible, with some pre- and post-processing)

Something that is a pain point for me is scale: handing around the entirety of all pages in all collections, in memory via pointer-chasing, could never scale to the number of pages of a large corporation. That limits one's growth when using Arctic. I think a streaming version (as well as one that doesn't need the posts to be sitting in a directory on each developer's machine!) can be implemented, but the API would need to change a bit to enable that. Servers searching through pages should also not have to re-process the markup files; we could build a database during processing. Ideally much of this should be as incremental as possible, which can be done well with caching. There's much figuring out to do.
