# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
