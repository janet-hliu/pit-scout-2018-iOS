//
//  MissingDataTableViewController.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 3/28/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class MissingDataTableViewController: UITableViewController {
    
    var pitDataPoints: [String] = ["pitSelectedImage", "pitAvailableWeight", "pitDriveTrain", "pitCanCheesecake", "pitHasCamera", "pitProgrammingLanguage", "pitClimberType", "pitWheelDiameter"]
    var firebase: DatabaseReference?
    var teamsDictionary: NSDictionary = [:]
    // Holds firebase data from "Teams"
    var missingData: [(Int,String)] = [(Int,String)]()
    // Holds team and missing dataPoints ex. [(118, pitClimberType), (100, pitHasCamera)]
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UINib(nibName: "MissingDataTableViewCell", bundle: nil), forCellReuseIdentifier: "missingDataCell")
        self.firebase = Database.database().reference()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.firebase!.child("Teams").observe(.value) { (snap) in
            self.teamsDictionary = snap.value as! NSDictionary
            self.getNils()
        }
    }
    
    func getNils() {
        var missingDataForTeam: [String] = []
        for (_, teamData) in self.teamsDictionary {
            missingDataForTeam = []
            let dataDictionary = teamData as! NSDictionary
            var num: Int? = dataDictionary.object(forKey: "number") as? Int
            // get teamNum
            if num != nil {
                for i in pitDataPoints {
                    let value = dataDictionary.object(forKey: i)
                    if value == nil {
                        missingDataForTeam.append(i)
                    }
                }
                let dataPointsAsString = missingDataForTeam.joined(separator: ", ")
                missingData.append((num!, dataPointsAsString))
            } else {
                print("This should never happen. There is a team without a number?!?")
            }
        }
        missingData.sort {$0.0 < $1.0}
        print("\(missingData)")
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cells = missingData.count
        return cells
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "missingDataCell", for: indexPath) as! MissingDataTableViewCell
        cell.missingDataPoints.text = "\(missingData[indexPath.row].1)"
        cell.teamNum.text = "\(missingData[indexPath.row].0)"
        return cell
    }
}
