//
//  ViewController.swift
//  GoogleMapsExp
//
//  Created by Venugopal Reddy Devarapally on 03/02/17.
//  Copyright © 2017 Venugopal Reddy Devarapally. All rights reserved.
//

import UIKit
import GoogleMaps

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var directionsBtn: UIButton!
    @IBOutlet weak var mapTypeBtn: UIButton!
    var locationManager = CLLocationManager()
    var didFindMyLocation = false
    var mapAccessory = MapAccessory()
    var locationMarker: GMSMarker!
    var myLocation = CLLocation()
    
    // Direction Implementation
    var originMarker: GMSMarker!
    
    var destinationMarker: GMSMarker!
    
    var routePolyline: GMSPolyline!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var image = UIImage(named: "directions")?.withRenderingMode(.alwaysTemplate)
        directionsBtn.setImage(image, for: .normal)
        
        image = UIImage(named: "map")?.withRenderingMode(.alwaysTemplate)
        mapTypeBtn.setImage(image, for: .normal)
        
        // Do any additional setup after loading the view, typically from a nib.
        let camera = GMSCameraPosition.camera(withLatitude: 48.857165, longitude: 2.354613, zoom: 10.0)
        mapView.camera = camera
        
        // Night Mode Map Styling
        do {
            // Set the map style by passing the URL of the local file.
            let styleURL = Bundle.main.url(forResource: "style", withExtension: "json")
            if  styleURL != nil {
                mapView.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL!)
            } else {
                NSLog("Unable to find style.json")
            }
        } catch {
            NSLog("One or more of the map styles failed to load. \(error)")
        }
        
        //LocationManager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        mapView.addObserver(self, forKeyPath: "myLocation", options: NSKeyValueObservingOptions.new, context: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus){
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            mapView.isMyLocationEnabled = true
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if !didFindMyLocation {
            myLocation = change?[.newKey] as! CLLocation
            mapView.camera = GMSCameraPosition.camera(withTarget: myLocation.coordinate, zoom: 10.0)
            mapView.settings.myLocationButton = true
            
            didFindMyLocation = true
        }
    }
    
    @IBAction func changeMapType(_ sender: Any) {
        let actionSheet = UIAlertController(title: "Map Types", message: "Select map type:", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let normalMapTypeAction = UIAlertAction(title: "Normal", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.mapView.mapType = .normal
        }
        
        let terrainMapTypeAction = UIAlertAction(title: "Terrain", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.mapView.mapType = .terrain
        }
        
        let hybridMapTypeAction = UIAlertAction(title: "Hybrid", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.mapView.mapType = .hybrid
        }
        
        let cancelAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(normalMapTypeAction)
        actionSheet.addAction(terrainMapTypeAction)
        actionSheet.addAction(hybridMapTypeAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func createRoute(_ sender: Any) {
        let addressAlert = UIAlertController(title: "Destination", message: "Get route from current location to your destination", preferredStyle: UIAlertControllerStyle.alert)
        
        addressAlert.addTextField { (textField) -> Void in
            textField.placeholder = "Type Destination?"
        }
        
        
        let createRouteAction = UIAlertAction(title: "Search", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            let origin =  self.myLocation.coordinate.latitude.description + "," + self.myLocation.coordinate.longitude.description//(addressAlert.textFields![0] as UITextField).text! as String
            let destination = (addressAlert.textFields![0] as UITextField).text! as String
            
            self.mapAccessory.getDirections(origin: origin, destination: destination, waypoints: nil, travelMode: nil, completionHandler: { (status, success) -> Void in
                if success {
                    self.configureMapAndMarkersForRoute()
                    self.drawRoute()
                    self.displayRouteInfo()
                }
                else {
                    if(status == "NETWORK_ISSUE"){
                        self.showAlert(title: "No Network!", message: "Please check you internet connection.")
                    }else{
                        self.showAlert(title: "Not found!", message: "Could not find the location you requested.")
                    }
                    print(status)
                }
            })
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        addressAlert.addAction(createRouteAction)
        addressAlert.addAction(closeAction)
        
        present(addressAlert, animated: true, completion: nil)
    }
    
    func showAlert(title: String, message: String) -> Void{
        let addressAlert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let closeAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        addressAlert.addAction(closeAction)
        present(addressAlert, animated: true, completion: nil)
    }
    
    func configureMapAndMarkersForRoute() {
        if originMarker != nil {
            originMarker.map = nil
        }
        if destinationMarker != nil {
            destinationMarker.map = nil
        }
        
        let bounds: GMSCoordinateBounds = GMSCoordinateBounds.init(coordinate: mapAccessory.originCoordinate, coordinate: mapAccessory.destinationCoordinate)
        let update = GMSCameraUpdate.fit(bounds)
        mapView.moveCamera(update)
        originMarker = GMSMarker(position: self.mapAccessory.originCoordinate)
        originMarker.map = self.mapView
        originMarker.icon = GMSMarker.markerImage(with: UIColor.green)
        originMarker.title = self.mapAccessory.originAddress
        
        destinationMarker = GMSMarker(position: self.mapAccessory.destinationCoordinate)
        destinationMarker.map = self.mapView
        destinationMarker.icon = GMSMarker.markerImage(with: UIColor.red)
        destinationMarker.title = self.mapAccessory.destinationAddress
    }
    
    func drawRoute() {
        let route = (mapAccessory.overviewPolyline as NSDictionary)["points"] as! String
        
        let path: GMSPath = GMSPath(fromEncodedPath: route)!
        if routePolyline != nil {
            routePolyline.map = nil
            routePolyline = nil
        }
        routePolyline = GMSPolyline(path: path)
        routePolyline.map = mapView
    }
    
    func displayRouteInfo() {
        lblInfo.text = mapAccessory.totalDistance + "\n" + mapAccessory.expectedArrival
    }
}
