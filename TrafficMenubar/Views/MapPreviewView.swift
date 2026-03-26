import SwiftUI
import MapKit

struct MapPreviewView: NSViewRepresentable {
    let routes: [Route]
    let primaryRouteIndex: Int
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    var isInteractive: Bool = false
    var recenterTrigger: UUID = UUID()

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = isInteractive
        mapView.isScrollEnabled = isInteractive
        mapView.isRotateEnabled = isInteractive
        mapView.isPitchEnabled = isInteractive
        mapView.showsZoomControls = isInteractive
        mapView.showsCompass = isInteractive
        mapView.delegate = context.coordinator

        // Subtle dark appearance for the map
        if #available(macOS 14.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        }

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Reset region when origin/destination change (e.g. dev address override)
        let newOrigin = CLLocationCoordinate2D(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude)
        let newDest = CLLocationCoordinate2D(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        if let lastOrigin = context.coordinator.lastOrigin, let lastDest = context.coordinator.lastDestination {
            let originMoved = abs(lastOrigin.latitude - newOrigin.latitude) > 0.001 || abs(lastOrigin.longitude - newOrigin.longitude) > 0.001
            let destMoved = abs(lastDest.latitude - newDest.latitude) > 0.001 || abs(lastDest.longitude - newDest.longitude) > 0.001
            if originMoved || destMoved {
                context.coordinator.hasSetInitialRegion = false
            }
        }
        context.coordinator.lastOrigin = newOrigin
        context.coordinator.lastDestination = newDest

        guard !routes.isEmpty else { return }

        // Add alternate routes first (drawn behind)
        for (index, route) in routes.enumerated() where index != primaryRouteIndex {
            let coordinates = route.polylineCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.isPrimary = false
            mapView.addOverlay(polyline)
        }

        // Add primary route on top
        if primaryRouteIndex < routes.count {
            let primary = routes[primaryRouteIndex]

            if let congestion = primary.segmentCongestion, congestion.count > 1 {
                // Draw congestion-colored segments
                let coords = primary.polylineCoordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                let segmentCount = min(congestion.count, coords.count - 1)
                for i in 0..<segmentCount {
                    var segCoords = [coords[i], coords[i + 1]]
                    let polyline = TaggedPolyline(coordinates: &segCoords, count: 2)
                    polyline.isPrimary = true
                    polyline.congestionColor = congestion[i].nsColor
                    mapView.addOverlay(polyline)
                }

                // Fit to full route bounds (skip if interactive and already positioned)
                if !context.coordinator.isInteractive || !context.coordinator.hasSetInitialRegion {
                    let allCoords = coords
                    let fullPolyline = MKPolyline(coordinates: allCoords, count: allCoords.count)
                    let padding: CGFloat = isInteractive ? 40 : 24
                    mapView.setVisibleMapRect(
                        fullPolyline.boundingMapRect,
                        edgePadding: NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
                        animated: false
                    )
                    context.coordinator.hasSetInitialRegion = true
                }
            } else {
                // Fallback: solid green (existing behavior)
                let coordinates = primary.polylineCoordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.isPrimary = true
                mapView.addOverlay(polyline)

                if !context.coordinator.isInteractive || !context.coordinator.hasSetInitialRegion {
                    let padding: CGFloat = isInteractive ? 40 : 24
                    mapView.setVisibleMapRect(
                        polyline.boundingMapRect,
                        edgePadding: NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
                        animated: false
                    )
                    context.coordinator.hasSetInitialRegion = true
                }
            }
        }

        // Origin/destination markers
        let originAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude),
            annotationType: .origin
        )
        let destAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude),
            annotationType: .destination
        )
        mapView.addAnnotations([originAnnotation, destAnnotation])

        // Handle recenter trigger
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            context.coordinator.hasSetInitialRegion = false
            if let primary = routes.indices.contains(primaryRouteIndex) ? routes[primaryRouteIndex] : nil {
                let coords = primary.polylineCoordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                let padding: CGFloat = isInteractive ? 40 : 24
                mapView.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
                    animated: true
                )
                context.coordinator.hasSetInitialRegion = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isInteractive: isInteractive)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let isInteractive: Bool
        var hasSetInitialRegion = false
        var lastRecenterTrigger: UUID?
        var lastOrigin: CLLocationCoordinate2D?
        var lastDestination: CLLocationCoordinate2D?

        init(isInteractive: Bool) {
            self.isInteractive = isInteractive
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? TaggedPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.isPrimary {
                    if let congestionColor = polyline.congestionColor {
                        renderer.strokeColor = congestionColor
                    } else {
                        renderer.strokeColor = NSColor(red: 0.29, green: 0.68, blue: 0.50, alpha: 0.9)
                    }
                    renderer.lineWidth = isInteractive ? 5 : 4
                } else {
                    renderer.strokeColor = NSColor.white.withAlphaComponent(0.15)
                    renderer.lineWidth = isInteractive ? 4 : 3
                    renderer.lineDashPattern = [6, 4]
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else { return nil }

            let identifier = "RoutePin-\(routeAnnotation.annotationType)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation

            let size: CGFloat
            let image: NSImage

            switch routeAnnotation.annotationType {
            case .origin:
                size = 14
                image = makeCircleMarker(size: size, fillColor: .systemGreen, borderColor: .white)
            case .destination:
                size = 14
                image = makeCircleMarker(size: size, fillColor: .systemRed, borderColor: .white)
            case .incident:
                size = 12
                image = makeCircleMarker(size: size, fillColor: .systemOrange, borderColor: .white)
            }

            view.image = image
            view.frame.size = NSSize(width: size, height: size)
            return view
        }

        private func makeCircleMarker(size: CGFloat, fillColor: NSColor, borderColor: NSColor) -> NSImage {
            NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                // White border
                borderColor.setFill()
                NSBezierPath(ovalIn: rect).fill()

                // Colored center
                fillColor.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()

                return true
            }
        }

    }
}

class TaggedPolyline: MKPolyline {
    var isPrimary: Bool = true
    var congestionColor: NSColor?
}

enum RouteAnnotationType {
    case origin
    case destination
    case incident
}

class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let annotationType: RouteAnnotationType

    init(coordinate: CLLocationCoordinate2D, annotationType: RouteAnnotationType) {
        self.coordinate = coordinate
        self.annotationType = annotationType
    }
}
