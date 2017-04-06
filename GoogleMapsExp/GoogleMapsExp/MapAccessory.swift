//
//  MapAccessory.swift
//  GoogleMapsExp
//
//  Created by Venugopal Reddy Devarapally on 04/02/17.
//  Copyright © 2017 Venugopal Reddy Devarapally. All rights reserved.
//

import UIKit
import CoreLocation

class MapAccessory: NSObject {
    // Identify Location Implementation
    let baseURLGeocode = "https://maps.googleapis.com/maps/api/geocode/json?"
    
    var lookupAddressResults: Dictionary<NSObject, AnyObject>!
    
    var fetchedFormattedAddress: String!
    
    var fetchedAddressLongitude: Double!
    
    var fetchedAddressLatitude: Double!
    
    //DIRECTION IMPLEMENTATION
    let baseURLDirections = "https://maps.googleapis.com/maps/api/directions/json?"
    
    var selectedRoute: Dictionary<NSObject, AnyObject>!
    
    var overviewPolyline: Dictionary<NSObject, AnyObject>!
    
    var originCoordinate: CLLocationCoordinate2D!
    
    var destinationCoordinate: CLLocationCoordinate2D!
    
    var originAddress: String!
    
    var destinationAddress: String!
    
    //Calculate Time and Distance
    
    var totalDistanceInMeters: UInt = 0
    
    var totalDistance: String!
    
    var totalDurationInSeconds: UInt = 0
    
    var totalDuration: String!
    
    var expectedArrival: String!
    
    override init() {
        super.init()
    }
    
    func geocodeAddress(address: String!, withCompletionHandler completionHandler: @escaping ((_ status: String, _ success: Bool) -> Void)) {
        if let lookupAddress = address {
            var geocodeURLString = baseURLGeocode + "address=" + lookupAddress
            geocodeURLString = geocodeURLString.addingPercentEncoding(withAllowedCharacters: (NSCharacterSet.urlQueryAllowed))!
            let geocodeURL = NSURL(string: geocodeURLString)
            
            DispatchQueue.main.async(execute: { () -> Void in
                let geocodingResultsData = NSData(contentsOf: geocodeURL! as URL)
                
                // if an error occurs, print it and re-enable the UI
                func displayError(_ error: String) {
                    print(error)
                    print("URL at time of error: \(geocodeURLString)")
                }
                
                // parse the data
                let parsedResult: Dictionary<NSObject, AnyObject>!
                do {
                    parsedResult = try JSONSerialization.jsonObject(with: geocodingResultsData as! Data, options: .mutableContainers) as! Dictionary<NSObject, AnyObject>
                } catch {
                    displayError("Could not parse the data as JSON: '\(geocodingResultsData)'")
                    return
                }
                
                // Get the response status.
                let status = (parsedResult as NSDictionary)["status"] as! String//parsedResult["status"] as String
                
                if status == "OK" {
                    let allResults = (parsedResult as NSDictionary)["results"] as! Array<Dictionary<NSObject, AnyObject>>
                    self.lookupAddressResults = allResults[0]
                    
                    // Keep the most important values.
                    self.fetchedFormattedAddress = (self.lookupAddressResults as NSDictionary)["formatted_address"] as! String
                    let geometry = (self.lookupAddressResults as NSDictionary)["geometry"] as! Dictionary<NSObject, AnyObject>
                    self.fetchedAddressLongitude = (((geometry as NSDictionary)["location"] as! NSDictionary)["lng"] as! NSNumber).doubleValue
                    self.fetchedAddressLatitude = (((geometry as NSDictionary)["location"] as! NSDictionary)["lat"] as! NSNumber).doubleValue
                    
                    completionHandler(status, true)
                }
                else {
                    completionHandler(status, false)
                }
            })
        }
        else {
            completionHandler("No valid address.", false)
        }
    }
    
    
    func getDirections(origin: String!, destination: String!, waypoints: Array<String>!, travelMode: AnyObject!, completionHandler: @escaping ((_ status: String, _ success: Bool) -> Void)) {
        if let originLocation = origin {
            if let destinationLocation = destination {
                var directionsURLString = baseURLDirections + "origin=" + originLocation + "&destination=" + destinationLocation
                
                directionsURLString = directionsURLString.addingPercentEncoding(withAllowedCharacters: (NSCharacterSet.urlQueryAllowed))!
                let directionsURL = NSURL(string: directionsURLString)
                
                DispatchQueue.main.async(execute: { () -> Void in
                    let directionsData = NSData(contentsOf: directionsURL! as URL)
                    
                    // if an error occurs, print it and re-enable the UI
                    func displayError(_ error: String) {
                        print(error)
                        print("URL at time of error: \(directionsURLString)")
                    }
                    
                    // parse the data
                    let parsedResult: Dictionary<NSObject, AnyObject>!
                    guard directionsData != nil else{
                        completionHandler("NETWORK_ISSUE", false)
                        return
                    }
                    do {
                        parsedResult = try JSONSerialization.jsonObject(with: directionsData as! Data, options: .mutableContainers) as! Dictionary<NSObject, AnyObject>
                    } catch {
                        displayError("Could not parse the data as JSON: '\(directionsData)'")
                        return
                    }
                    let status = (parsedResult as NSDictionary)["status"] as! String
                    
                    if status == "OK" {
                        self.selectedRoute = self.getFastestRoute(routes: ((parsedResult as NSDictionary)["routes"] as! Array<Dictionary<NSObject, AnyObject>>))
                        self.overviewPolyline = (self.selectedRoute as NSDictionary)["overview_polyline"] as! Dictionary<NSObject, AnyObject>
                        
                        let legs = (self.selectedRoute as NSDictionary)["legs"] as! Array<Dictionary<NSObject, AnyObject>>
                        
                        let startLocationDictionary = ((legs as NSArray)[0] as! NSDictionary)["start_location"] as! Dictionary<NSObject, AnyObject>
                        self.originCoordinate = CLLocationCoordinate2DMake((startLocationDictionary as NSDictionary)["lat"] as! Double, (startLocationDictionary as NSDictionary)["lng"] as! Double)
                        
                        let endLocationDictionary = ((legs as NSArray)[legs.count - 1] as! NSDictionary)["end_location"] as! Dictionary<NSObject, AnyObject>
                        self.destinationCoordinate = CLLocationCoordinate2DMake((endLocationDictionary as NSDictionary)["lat"] as! Double, (endLocationDictionary as NSDictionary)["lng"] as! Double)
                        
                        self.originAddress = ((legs as NSArray)[0] as! NSDictionary)["start_address"] as! String
                        self.destinationAddress = ((legs as NSArray)[legs.count - 1] as! NSDictionary)["end_address"] as! String
                        
                        self.calculateTotalDistanceAndETA()
                        
                        completionHandler(status, true)
                    }
                    else {
                        completionHandler(status, false)
                    }
                })
            }
            else {
                completionHandler("Destination is nil.", false)
            }
        }
        else {
            completionHandler("Origin is nil", false)
        }
    }
    
    func getFastestRoute(routes: Array<Dictionary<NSObject, AnyObject>>) -> Dictionary<NSObject, AnyObject> {
        var fastestRoute = Dictionary<NSObject, AnyObject>()
        var duration: UInt = getTotalDurationInSecondsFor(route: routes[0])
        for route in routes {
            if (duration >= getTotalDurationInSecondsFor(route: route)) {
                duration = getTotalDurationInSecondsFor(route: route)
                fastestRoute = route
            }
        }
        return fastestRoute
    }
    
    func getTotalDurationInSecondsFor(route: Dictionary<NSObject, AnyObject>) ->  UInt{
        let legs = (route as NSDictionary)["legs"] as! Array<Dictionary<NSObject, AnyObject>>
        
        totalDistanceInMeters = 0
        totalDurationInSeconds = 0
        
        for leg in legs {
            totalDurationInSeconds += (((leg as NSDictionary)["duration"] as! Dictionary<NSObject, AnyObject>) as NSDictionary)["value"] as! UInt
        }
        return totalDurationInSeconds
    }
    
    func calculateTotalDistanceAndETA() {
        let legs = (self.selectedRoute as NSDictionary)["legs"] as! Array<Dictionary<NSObject, AnyObject>>
        
        totalDistanceInMeters = 0
        totalDurationInSeconds = 0
        
        for leg in legs {
            totalDistanceInMeters += (((leg as NSDictionary)["distance"] as! Dictionary<NSObject, AnyObject>) as NSDictionary)["value"] as! UInt
            totalDurationInSeconds += (((leg as NSDictionary)["duration"] as! Dictionary<NSObject, AnyObject>) as NSDictionary)["value"] as! UInt
        }
        
        //Distance
        let distanceInKilometers: Double = Double(totalDistanceInMeters / 1000)
        
        //ETA
        let calendar = Calendar.current
        let startDate = Date()
        let systemDate = startDate.addingTimeInterval(TimeInterval(totalDurationInSeconds))
        let dateFormate = DateFormatter()
        dateFormate.dateFormat = "MMM d, H:mm a"
        if calendar.component(.day, from: startDate) == calendar.component(.day, from: systemDate) {
            dateFormate.dateFormat = "H:mm a"
        }
        
        let stringOfDate = dateFormate.string(from: systemDate)
        expectedArrival = "Expected Arrival: \(stringOfDate)"
        
        
        //Duration
        let mins = totalDurationInSeconds / 60
        let hours = mins / 60
        let days = hours / 24
        let remainingHours = hours % 24
        let remainingMins = mins % 60
        let remainingSecs = totalDurationInSeconds % 60
        totalDuration = ""
        if days > 0 {
            totalDuration = totalDuration +  String(days) + " d "
        }
        if remainingHours > 0 {
            totalDuration = totalDuration +  String(remainingHours) + " h "
        }
        if remainingMins > 0 {
            totalDuration = totalDuration +  String(remainingMins) + " mins "
        }
        if remainingSecs > 0 {
            totalDuration = totalDuration +  String(remainingSecs) + " secs "
        }
        
        totalDistance = "\(distanceInKilometers) Km, \(totalDuration.description)"
    }
}
