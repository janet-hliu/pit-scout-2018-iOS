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

class FilterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    @IBOutlet weak var dataTable: UITableView!
    @IBOutlet weak var dataPointButton: UIButton!
    @IBOutlet weak var dataPointValueButton: UIButton!
    @IBOutlet weak var dataPointLabel: UILabel!
    @IBOutlet weak var dataPointValueLabel: UILabel!
    
    let dataPointDropDown = DropDown()
    let dataPointValueDropDown = DropDown()
    // Array of all the data points in pit scout, not including ramp time/outcome, drive time/outcome, SEALs notes
    var pitDataPoints: [String] = ["pitSelectedImage", "pitAvailableWeight", "pitDriveTrain", "pitCanCheesecake", "pitHasCamera", "pitProgrammingLanguage", "pitClimberType", "pitWheelDiameter"]
    // Array of all the values under a certain data point in pit scout. Will change when the data point selected changes
    var pitDataPointValues: [String] = ["nil", "All"]
    var dataPointIndex: Int = 0
    var firebase : DatabaseReference?
    var teamDataPoints: [(Int,String)] = [(Int,String)]()
    var teamsForDataValue : [Int] = [Int]()
    var filterDatapoint : String = ""
    var filterByValue : String = ""
    var teamsDictionary : NSDictionary = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataTable.register(UINib(nibName: "CellFilterTableViewCell", bundle: nil), forCellReuseIdentifier: "filterCell")
        self.firebase = Database.database().reference()
        setUpDataPointDropDown(anchorButton: dataPointButton, dataArray: pitDataPoints)
        setUpDataPointValueDropDown(anchorButton: dataPointValueButton, dataArray: pitDataPointValues)
        self.dataTable.delegate = self
        self.dataTable.dataSource = self
        self.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
            self.teamsDictionary = snap.value as! NSDictionary
        })
    }
    
    func setUpDataPointDropDown(anchorButton: UIButton, dataArray: [String]) {
        dataPointDropDown.anchorView = anchorButton
        dataPointDropDown.bottomOffset = CGPoint(x: 0, y: anchorButton.bounds.height)
        dataPointDropDown.dataSource = dataArray
        dataPointDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            self!.dataPointIndex = index
            self!.dataPointLabel.text = item
            self!.pitDataPointValues = ["nil", "All"]
            let dataPoint = self!.pitDataPoints[index]
            // Iterating through the data of all the teams to find all the different values for a given data point
 //           self!.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
 //               self!.teamsDictionary = snap.value as! NSDictionary
                for (_, data) in (self!.teamsDictionary) {
                    let dataDictionary = data as! NSDictionary
                    let value = dataDictionary.object(forKey: dataPoint)
                    if value != nil {
                        let valueAsString = String(describing: value!)
                        if !self!.pitDataPointValues.contains(valueAsString) {
                            self!.pitDataPointValues.append(valueAsString)
                        }
                    }
                }
 //           })
            self!.setUpDataPointValueDropDown(anchorButton: self!.dataPointValueButton, dataArray: self!.pitDataPointValues)
            self!.filterDatapoint = item
            self!.dataPointValueLabel.text = "All"
            self!.filterByValue = ""
            self!.filterForData(dataPoint: (self!.filterDatapoint))
        }
    }
    
    func setUpDataPointValueDropDown(anchorButton: UIButton, dataArray: [String]) {
        dataPointValueDropDown.anchorView = anchorButton
        dataPointValueDropDown.bottomOffset = CGPoint(x: 0, y: anchorButton.bounds.height)
        dataPointValueDropDown.dataSource = dataArray
        dataPointValueDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            self!.dataPointValueLabel.text = item
            self!.filterByValue = item
            if self!.filterByValue == "All" {
                self!.filterByValue = ""
            }
            self!.filterForData(dataPoint: self!.filterDatapoint)
        }
    }
    
    @IBAction func dataPointButtonPressed(_ sender: Any) {
        dataPointDropDown.show()
    }
    
    @IBAction func dataPointValueButtonpressed(_ sender: Any) {
        dataPointValueDropDown.show()
    }
    
    func filterForData(dataPoint: String) {
        teamsForDataValue = []
        teamDataPoints = []
        self.teamDataPoints = [(Int, String)]()
        for (_, teamData) in self.teamsDictionary {
            let dataDictionary = teamData as! NSDictionary
            let value = dataDictionary.object(forKey: dataPoint)
            var num : Int?
            num = dataDictionary.object(forKey: "number") as? Int
            if value != nil && num != nil {
                let valueAsString = String(describing: value!)
                teamDataPoints.append((num!, valueAsString))
            } else if num != nil{
                teamDataPoints.append((num!, "nil"))
            } else if num == nil{
                print("there is a team without a number?!?")
            }
        }
        if filterByValue != "" {
            for (teamNum, value) in self.teamDataPoints {
                if value == filterByValue {
                    teamsForDataValue.append(teamNum)
                }
            }
        }
        teamDataPoints.sort {$0.0 < $1.0}
        teamsForDataValue.sort {$0 < $1}
        print(teamDataPoints)
        print(teamsForDataValue)
        dataTable.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var cells = 0
        if filterByValue != "" {
            cells = teamsForDataValue.count
        }else{
            cells = teamDataPoints.count
        }
        return cells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "filterCell", for: indexPath) as! CellFilterTableViewCell
        if filterByValue != "" {
            cell.teamNum.text = "\(teamsForDataValue[indexPath.row])"
            cell.dataPoint.text = "\(filterDatapoint)"
            cell.dataValue.text = "\(filterByValue)"
        }else {
            cell.teamNum.text = "\(teamDataPoints[indexPath.row].0)"
            cell.dataPoint.text = "\(filterDatapoint)"
            cell.dataValue.text = "\(teamDataPoints[indexPath.row].1)"
        }
        return cell
    }
}





