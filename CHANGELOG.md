# Changelog

All notable changes to this project will be documented in this file

## [0.1.0](https://github.com/carsonhawley/Cicada/releases/tag/0.1.0) (2023-10-11)

Initial release. Cicada emerges.

## [0.2.0](https://github.com/carsonhawley/Cicada/releases/tag/0.2.0) (2025-03-10)

#### Changed
- BREAKING: Use Swift's Result type for capture responses.
- BREAKING: Renamed 'CaptureResult' to 'CaptureObject'.
- BREAKING: Lifted the Mode enum out of the Capture type.
- Refactored how machine objects are processed to be more performant.
- Some internal Capture fields are now public readonly.

#### Fixed
- Removed the time interval check for '.uniqueOnce' mode as this had the potential to drop codes.
- Fixed the scan frame in the demo project.

## [0.2.1](https://github.com/carsonhawley/Cicada/releases/tag/0.2.1) (2025-03-11)

#### Fixed
- insert video preview layer below all other views.
- clear stale video frames on stop().