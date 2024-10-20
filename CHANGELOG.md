# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [11.0.0alpha] - 2024-10-20

### Changed

 - generated apps now operate as SPAs that pull statically-generated HTML to fill the body.
 - `Config` now has a `render_spa` field to specify the code that doesn't get re-rendered on navigation in the client. This starts as an identity function by default, meaning the whole page is re-rendered on navigation.

## [10.0.1] - 2024-10-11

### Added

 - Inline rule arguments now can use `\` for escaping, including escaping `)` and `,`.

## [10.0.0] - 2024-09-11

### Changed

 - Debug messages have been cleaned up.
 - Dependencies have been updated.
 - `10.0.0-alpha`'s page caching is now out of alpha!

### Fixed

 - A caching bug in 10.0.0-alpha has been fixed.

## [10.0.0-alpha] - 2024-08-28

### Added

 - Caching of pages that haven't changed.

### Fixed

 - Lots of parsing bugs have been fixed.

## [9.0.5] - 2024-08-21

### Added

 - Correctly formatted code
 - Updated dependencies

## [9.0.4] - 2024-08-21

### Fixed

 - inline rule parsing bug

## [9.0.3] - 2024-08-21

### Fixed

 - static component parsing bug

## [9.0.2] - 2024-08-14

### Fixed

 - paragraph/component parsing bug

## [9.0.1] - 2024-08-14

### Changed

 - `arctic/parse.parse` now takes a source name used in errors, and `.parser` in `Collection` does too.

## [9.0.0] - 2024-08-13

### Changed

 - Parsing with the combinators in `arctic/parse` now gives access to a new `ParseData(a)` type, allowing the threading of arbitrary state through the parsing process. It replaces the position parameter, and also gives access to the position and earlier-parsed metadata for the markup file. 
 - For the threading of state, the parse actions now must return a `Result(#(Element(Nil), a))` value, where `a` is the user-provided state type. We could provide convenience functions that just expect `Result(Element(Nil))` instead but I'm worried the API is already seeming overwhelming. 
 - `new` also now takes an argument for the initial state at the beginning of parsing a markup file.

## [8.0.0] - 2024-08-12

### Added

 - `arctic/collection` and `arctic/config` provide a builder-pattern interface for constructing a site.
 - `arctic_vite_config.js` is now generated, giving an object that can be exported into a vite config file.
 - Added `default_parser` to `arctic/collection`.
 - Added `arctic/parse` with all the machinery of parsing markup in the ways you want.
 - Much better documentation. (There's still more to do here though!)

### Changed

 - Collections can have raw pages that you can just add (not all pages must be parsed from a collection directory).
 - `MainPage` -> `RawPage`, to make this concept usable in other parts of Arctic.
 - Configurations now hold the list of collections, instead of that being a separate argument to `build.build`.
 - Rename a collection's `.rss` field to `.feed`, which is now both the render function and the filename.

## [7.0.0] - 2024-08-04

### Changed

 - Collections now have a render function for their pages.
 - Pages now hold a list of body elements, instead of an entire HTML document.

## [6.0.0] - 2024-08-04

### Added

 - `arctic/page` now has a bunch of utility functions for constructing pages, since pages now have a rather large amount of information.

### Changed

 - Pages now have more fields broken out of the metadata dictionary, with the intention that pages that don't need them have easy ways of leaving them blank and not using them during rendering, and pages that do need them get a lot more safety and convenience knowing they are there. It also forces consistent naming, so an ecosystem of pretty components can be constructed that click into an application easily.
 - Ordering is now per-collection instead of per-post.

## [5.0.0] - 2024-08-04

### Changed

 - Pages now have an optional date, so it doesn't have to be a string metadata.
 - Corrected folder names: now you import `arctic` or `arctic/build` as intended

## [4.0.0] - 2024-08-04

### Changed

 - Pages now have a metadata dictionary

## [3.0.0] - 2024-08-04

### Changed

 - Collections for rendering the home page now have a page list (so they must be processed before the home page)

## [2.0.0] - 2024-08-04

### Changed

 - Reorganized modules

## [1.0.1] - 2024-08-04

### Added

 - Exposed the `Collection`, `Page`, and `Config` types.
