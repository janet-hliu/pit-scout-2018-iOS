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
    
    
    @IBOutlet weak var dataTable: UITableView!
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
    var teamsForDataValue: [String:[Int]] = [String:[Int]]()
    var teamsForDataNil: [Int:[String]] = [Int:[String]]()
    var filterByPoint : String = ""
    var filterByValue : String = ""
    var numOfCells : Int = 0
    
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
            self!.filterByPoint = item
        }
    }
    
    func setUpDataPointValueDropDown(anchorButton: UIButton, dataArray: [String]) {
        dataPointValueDropDown.anchorView = anchorButton
        dataPointValueDropDown.bottomOffset = CGPoint(x: 0, y: anchorButton.bounds.height)
        dataPointValueDropDown.dataSource = dataArray
        dataPointValueDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            self!.dataPointValueLabel.text = item
            self!.filterByValue = item
        }
    }
    
    @IBAction func dataPointButtonPressed(_ sender: Any) {
        dataPointDropDown.show()
    }
    
    @IBAction func dataPointValueButtonpressed(_ sender: Any) {
        dataPointValueDropDown.show()
    }
    
    func filterForNils() {
        self.teamsForDataNil = [:]
        numOfCells = 0
        self.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
            let teamsDictionary = snap.value as! NSDictionary
            for (_, teamData) in teamsDictionary {
                let dataDictionary = teamData as! NSDictionary
                let num = dataDictionary.object(forKey: "number") as! Int
                for key in self.pitDataPoints {
                    let value = dataDictionary.object(forKey: key)
                    if value == nil {
                        var teamArrayForNilArray = self.teamsForDataNil[num] ?? []
                        teamArrayForNilArray.append(key)
                        self.teamsForDataNil[num] = teamArrayForNilArray
                        self.numOfCells += 1
                    }
                }
            }
        })
    }
    
    func filterForData(dataPoint: String) {
        self.teamsForDataValue = [:]
        numOfCells = 0
        self.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
            let teamsDictionary = snap.value as! NSDictionary
            for (_, teamData) in teamsDictionary {
                let dataDictionary = teamData as! NSDictionary
                let value = dataDictionary.object(forKey: dataPoint)
                let num = dataDictionary.object(forKey: "number") as! Int
                if value != nil {
                    let valueAsString = String(describing: value!)
                    var teamArrayForDataArray = self.teamsForDataValue[valueAsString] ?? []
                    teamArrayForDataArray.append(num)
                    self.teamsForDataValue[valueAsString] = teamArrayForDataArray
                    self.numOfCells += 1
                } else {
                    var teamArrayForDataNilArray = self.teamsForDataValue["nil"] ?? []
                    teamArrayForDataNilArray.append(num)
                    self.teamsForDataValue["nil"] = teamArrayForDataNilArray
                }
            }
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var cells = 0
        cells = numOfCells
        return cells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "filterCell", for: indexPath) as! CellFilterTableViewCell
        if self.filterByPoint != "" && self.filterByValue = "" {
            filterForData(dataPoint: filterByPoint)
            for (key, value) in teamsForDataValue {
                for i in 0...value.count {
                    cell.teamNum.text = "\(value[i])"
                    cell.dataPoint.text = "\(filterByPoint)"
                    cell.dataValue.text = "\(key)"
                    return cell
                }
            }
        }else if self.filterByPoint != "" && self.filterByValue != "" {
            filterForData(dataPoint: filterByPoint)
            for value in teamsForDataValue[filterByValue] {
                for i in 0...value.count {
                    cell.teamNum.text = "\(value[i])"
                    cell.dataPoint.text = "\(filterByPoint)"
                    cell.dataValue.text = "\(filterByValue)"
                    return cell
                }
            }
        }else if self.filterbyPoint = "" && self.filterByValue = "" {
            for (key, value) in teamsForDataNil {
                for i in 0...value.count {
                    cell.teamNum.text = "\(key)"
                    cell.dataPoint.text = "\(i)"
                    cell.dataValue.text = "nil"
                }
            }
        }
    }
}


