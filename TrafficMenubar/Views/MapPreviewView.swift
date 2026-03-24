import SwiftUI
import MapKit

struct MapPreviewView: NSViewRepresentable {
    let routes: [Route]
    let primaryRouteIndex: Int
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsZoomControls = false
        mapView.showsCompass = false
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
            let coordinates = primary.polylineCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let polyline = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.isPrimary = true
            mapView.addOverlay(polyline)

            mapView.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                animated: false
            )
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? TaggedPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.isPrimary {
                    renderer.strokeColor = NSColor(red: 0.29, green: 0.68, blue: 0.50, alpha: 0.9)
                    renderer.lineWidth = 4
                } else {
                    renderer.strokeColor = NSColor.white.withAlphaComponent(0.15)
                    renderer.lineWidth = 3
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
