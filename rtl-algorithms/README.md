# RTL algorithms

This package contains `CrossVision.Geometry`, `CrossVision.Geometry.Types`, and `CrossVision.DisjointSet`, with console tests. It also includes the pure Pascal `CrossVision.Image`, `Binarize`, `Morphology`, `Contour`, and `Curve` units needed by the image examples. These algorithms have no direct OpenCV or Leptonica dependency.

On Windows x64, the two console tests passed 541 Geometry checks and 9 DisjointSet checks with Delphi 13.2 and Lazarus 4.8. These programs test Geometry and DisjointSet.

## Run the example

Open `tests/TestGeometry.dproj` or `tests/TestDisjointSet.dproj` in Delphi 13.2. Select Windows 64-bit and either Debug or Release, then build and run the console project. The executables appear in `build/Win64/<configuration>/`.

In Lazarus 4.8, open `tests/TestGeometry.lpi` or `tests/TestDisjointSet.lpi`. Build for Windows x64 and run. The executables appear in `tests/bin/lazarus-win64/`. Both IDEs use the relative `../src` unit path. Each executable prints its passed and failed counts and returns exit code 1 if a check fails.

## Image algorithms

For the graphical image route, open `../examples/marker-lite/MarkerLite.dproj` in Delphi or `../examples/marker-lite/MarkerLite.lpi` in Lazarus and follow its README. Backend adapters are in `../vision`. The full image source closure is Image, Binarize, Morphology, Contour, Curve, Geometry, Geometry.Types, and DisjointSet.

## Geometry conventions and edge cases

The notes below describe the current implementation and its input requirements. See the [Geometry unit](src/CrossVision.Geometry.pas) and [geometry types](src/CrossVision.Geometry.Types.pas) for declarations.

### Angles and transforms

| API or convention | Behavior |
| --- | --- |
| Coordinates and directions | Screen coordinates have Y increasing downwards. `DirectionAngle` and `ToPolar` return radians in `[0, 2 * Pi)`, increasing clockwise on screen. `BuildRadialScanLines` uses mathematical counterclockwise angles instead. |
| `CircularMean` | Pass a nonempty array. Empty input currently returns zero, which cannot distinguish missing data from a real zero direction. Opposite directions have no unique mean; do not depend on one exact angle. Ordinary output is normalized to `[0, 2 * Pi)`. |
| `MinAreaRectAngle` | Returns the long-side direction in `[0, Pi)`. When no direction exists, it returns `-1` and zero dimensions. A square has no unique long-side direction. The size overload returns `Long >= Short`. |
| Transform pivots | `TurnPointsAboutMeanPoint` and `ScalePointsAboutMeanPoint` use the arithmetic mean of vertices, not the polygon centroid. For `ShearPoints`, use one axis at a time if you need to invert the transform by negating the angle. |

### Contours, intersections, and scans

| API | Behavior |
| --- | --- |
| `ClosePolygon` and `ReversePolyline` | Return copies. `ClosePolygon` appends the first point only when needed and keeps empty input empty. `ReversePolyline` leaves its input unchanged. |
| `ClipSegmentByPolygon` | Processes the `N - 1` consecutive edges and does not add a closing edge. Call `ClosePolygon` first when clipping against a closed contour. It classifies pieces by their midpoint and returns each piece as two endpoints. |
| `PointInAnyPolygon` and `PointsOnSegment` | An empty polygon list gives `False` for `PointInAnyPolygon`. An empty point list gives `True` for `PointsOnSegment`. For a degenerate segment, each supplied point must match its endpoint under the existing `PointOnSegment` rule. |
| Circle and line intersections | The circle-circle routine returns zero for coincident or concentric circles and for negative radii. A zero-length segment does not define an infinite line, so the line-circle routine returns zero intersections. `RayLineIntersection` rejects intersections behind the ray origin. |
| `NextDistinctPointOnRay` | Returns the next rounded pixel distinct from `Previous`. If the step limit is exhausted or coordinates become nonfinite, it returns `Previous` without changing `Distance`. |
| `BuildRadialScanLines` | Requires positive image dimensions, a positive finite `Step`, and a center inside the image; these checks return an empty array on failure. Supply finite angle bounds. `MaxAngle` is exclusive. Endpoints stay within `0..Width-1` and `0..Height-1`. |
| `BuildRibbonPolygon` | Requires at least two points on each side. It traverses the left side forward and the right side backward, then closes the contour when needed. The sides may have different lengths. |

### Rectangles and line groups

| API or type | Behavior |
| --- | --- |
| `FitSizePreserveAspect` | `fkContain` fits inside the box; `fkCover` covers it. Nonpositive source or box dimensions, or a result that collapses to zero, return `False` with zero output dimensions. This computes a size; it does not resize pixels. |
| `RectsWithinMargin` | Normalizes both rectangles, applies the X/Y margins to both, and tests strict overlap. A positive gap must be strictly less than twice the corresponding margin. Exact contact at twice the margin is excluded. |
| `RectRelativeAlignment` | Classifies the second rectangle relative to the first using nine alignment values. It normalizes both inputs and uses non-strict edge comparisons, so touching an edge already counts as outside in that direction. |
| `FindBracketTriples` | The first link accepts any sufficiently close endpoint pair. The second link compares the third segment's start with the second segment's end. Output `A` and `C` are parallel; `B` is transverse. `soOther` is excluded. Different segment and orientation counts return an empty result. |
| `BorderAngleValue` and `ArbitrateOppositeBorders` | `Found` distinguishes a missing boundary from a valid zero angle. When both boundaries are found and their slips differ beyond epsilon, arbitration discards the boundary with the larger `Slip`. Equal slips retain both. |
| `RejectSkewOutliers` | With at most two angles, retains all. For larger sets, the rule is `max(0, abs(angle) - StdDev(all angles)) <= MaxDeviation`. It does not measure distance from the mean. Retained angles keep their input order. |
| `CombineSkewAngles` | `spMean` computes an arithmetic mean. `spMaximum` selects the greatest absolute angle and keeps its sign. Insufficient input returns `False` and zero `Skew`. |
| `MergeCollinearLines` | Gap joining compares midpoint separation; overlap absorption compares band separation. Joined endpoints retain the separate source midpoint heights and can form a slanted segment. A join shorter than `MinLength` is rejected. |
| `TLineSpan` | Negative endpoints mean no measurement. `Spare` is a separate flag for keeping a span, so coordinate zero remains a valid measurement. |

## License

Original code uses the [MIT license](LICENSE). `CrossVision.Binarize.pas` and `CrossVision.Curve.pas` use [MPL 1.1](licenses/MPL-1.1.txt); see the [source attribution and changes](licenses/CROSSFPCCOMMON-NOTICE.md).
