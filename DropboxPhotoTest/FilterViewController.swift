//
//  FilterViewController.swift
//  DropboxPhotoTest
//
//  Created by Janet Liu on 3/11/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import Foundation
import Firebase
import UIKit
import DropDown

class FilterViewController: UIViewController, UITableViewDelegate {
    @IBOutlet weak var dataPointButton: UIButton!
    @IBOutlet weak var dataPointValueButton: UIButton!
    @IBOutlet weak var dataPointLabel: UILabel!
    @IBOutlet weak var dataPointValueLabel: UILabel!
    
    let dataPointDropDown = DropDown()
    let dataPointValueDropDown = DropDown()
    // Array of all the data points in pit scout, not including ramp time/outcome, drive time/outcome, SEALs notes
    var pitDataPoints: [String] = ["All", "pitSelectedImage", "pitAvailableWeight", "pitDriveTrain", "pitCanCheesecake", "pitHasCamera", "pitProgrammingLanguage", "pitClimberType", "pitWheelDiameter"]
    // Array of all the values under a certain data point in pit scout. Will change when the data point selected changes
    var pitDataPointValues: [String] = ["nil"]
    var dataPointIndex: Int = 0
    var firebase : DatabaseReference?

    override func viewDidLoad() {
        self.firebase = Database.database().reference()
        setUpDataPointDropDown(anchorButton: dataPointButton, dataArray: pitDataPoints)
        setUpDataPointValueDropDown(anchorButton: dataPointValueButton, dataArray: pitDataPointValues)
    }
    
    func setUpDataPointDropDown(anchorButton: UIButton, dataArray: [String]) {
        dataPointDropDown.anchorView = anchorButton
        dataPointDropDown.bottomOffset = CGPoint(x: 0, y: anchorButton.bounds.height)
        dataPointDropDown.dataSource = dataArray
        dataPointDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            self!.dataPointIndex = index
            self!.dataPointLabel.text = item
            self!.pitDataPointValues = ["nil"]
            self!.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
                let teamsDictionary = snap.value as! NSDictionary
                let dataPoint = self!.pitDataPoints[index]
                // Iterating through the data of all the teams to find all the different values for a given data point
                for (_, data) in teamsDictionary {
                    let dataDictionary = data as! NSDictionary
                    let value = dataDictionary.object(forKey: dataPoint)
                    if value != nil {
                        let valueAsString = String(describing: value!)
                        if !self!.pitDataPointValues.contains(valueAsString) {
                            self!.pitDataPointValues.append(valueAsString)
                        }
                    }
                }
                self!.setUpDataPointValueDropDown(anchorButton: self!.dataPointValueButton, dataArray: self!.pitDataPointValues)
            })
        }
    }
    
    func setUpDataPointValueDropDown(anchorButton: UIButton, dataArray: [String]) {
        dataPointValueDropDown.anchorView = anchorButton
        dataPointValueDropDown.bottomOffset = CGPoint(x: 0, y: anchorButton.bounds.height)
        dataPointValueDropDown.dataSource = dataArray
        dataPointValueDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            self!.dataPointValueLabel.text = item
        }
    }
    
    @IBAction func dataPointButtonPressed(_ sender: Any) {
        dataPointDropDown.show()
    }
    
    @IBAction func dataPointValueButtonpressed(_ sender: Any) {
        dataPointValueDropDown.show()
    }
}


