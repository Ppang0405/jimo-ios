//
//  CreatePostVM.swift
//  Jimo
//
//  Created by Gautam Mekkat on 1/10/21.
//

import SwiftUI
import Combine
import MapKit

enum CreatePostActiveSheet: String, Identifiable {
    case placeSearch, locationSelection, imagePicker
    
    var id: String {
        self.rawValue
    }
}

class CreatePostVM: ObservableObject {
    var cancellable: Cancellable?
    
    var mapRegion: MKCoordinateRegion {
        let location = useCustomLocation ? customLocation : selectedLocation?.placemark
        if let place = location {
            return MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))
        } else {
            return MapViewModel.defaultRegion
        }
    }

    @Published var useCustomLocation = false
    
    @Published var activeSheet: CreatePostActiveSheet?
    
    /// Used for navigation links
    @Published var placeSearchActive = false
    @Published var locationSearchActive = false
    
    /// Photo selection
    @Published var showImagePicker = false
    @Published var image: UIImage?
    
    // Sent to server
    @Published var name: String?
    
    /// Set when user searches and selects a location
    @Published var selectedLocation: MKMapItem?
    
    /// Set when user selects a custom location
    @Published var customLocation: MKPlacemark?
    
    var locationString: String? {
        return useCustomLocation ? "Custom location (View on map)" : selectedPlaceAddress
    }
    
    var selectedPlaceAddress: String? {
        /// For whatever reason, the default placemark title is "United States"
        /// Example: Mount Everest Base Camp has placemark title "United States"
        /// WTF Apple
        if selectedLocation?.placemark.title == "United States" {
            return "View on map"
        }
        return selectedLocation?.placemark.title
    }
    
    var maybeCreatePlaceRequest: MaybeCreatePlaceRequest? {
        guard let name = name, let location = selectedLocation else {
            return nil
        }
        var region: Region? = nil
        if let area = location.placemark.region as? CLCircularRegion {
            region = Region(coord: location.placemark.coordinate, radius: area.radius.magnitude)
        }
        return MaybeCreatePlaceRequest(
            name: name,
            location: Location(coord: location.placemark.coordinate),
            region: region,
            additionalData: AdditionalPlaceDataRequest(location)
        )
    }
    
    func selectPlace(placeSelection: MKMapItem) {
        useCustomLocation = false
        selectedLocation = placeSelection
        name = placeSelection.name
    }
    
    func selectLocation(selectionRegion: MKCoordinateRegion) {
        customLocation = MKPlacemark(coordinate: selectionRegion.center)
        useCustomLocation = true
    }
    
    func resetName() {
        name = nil
    }
    
    func resetLocation() {
        if useCustomLocation {
            useCustomLocation = false
            customLocation = nil
        } else {
            // Either there is no searched location or we are already on it
            // In that case clear the location and the search
            selectedLocation = nil
        }
    }
}
