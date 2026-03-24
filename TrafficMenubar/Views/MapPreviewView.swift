import SwiftUI
import MapKit

struct MapPreviewView: NSViewRepresentable {
    let routePolyline: [Coordinate]
    let originCoordinate: Coordinate
    let destinationCoordinate: Coordinate
    let incidents: [TrafficIncident]

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsZoomControls = false
        mapView.showsCompass = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard !routePolyline.isEmpty else { return }

        let coordinates = routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        let originAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude),
            annotationType: .origin
        )
        let destAnnotation = RouteAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude),
            annotationType: .destination
        )
        mapView.addAnnotations([originAnnotation, destAnnotation])

        for incident in incidents {
            let annotation = RouteAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: incident.location.latitude, longitude: incident.location.longitude),
                annotationType: .incident
            )
            mapView.addAnnotation(annotation)
        }

        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else { return nil }

            let identifier = "RoutePin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation

            let size: CGFloat = 12
            let circle = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let color: NSColor
                switch routeAnnotation.annotationType {
                case .origin: color = .systemGreen
                case .destination: color = .systemRed
                case .incident: color = .systemOrange
                }
                color.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                return true
            }
            view.image = circle
            view.frame.size = NSSize(width: size, height: size)

            return view
        }
    }
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
