# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Upcoming

### Added

 - `arctic/collection` and `arctic/config` provide a builder-pattern interface for constructing a site.
 - `arctic_vite_config.js` is now generated, giving an object that can be exported into a vite config file.

### Changed

 - Collections can have raw pages that you can just add (not all pages must be parsed from a collection directory).
 - `MainPage` -> `RawPage`, to make this concept usable in other parts of Arctic.
 - Configurations now hold the list of collections, instead of that being a separate argument to `build.build`.

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
