//
//  TableViewController.swift
//  DropboxPhotoTest
//
//  Created by Bryton Moeller on 1/18/16.
//  Copyright © 2016 citruscircuits. All rights reserved.
//
import UIKit
import Foundation
import Firebase
import Haneke

let firebaseKeys = ["pitNumberOfWheels",  "pitSelectedImageName"]

class TableViewController: UITableViewController, UIPopoverPresentationControllerDelegate {
    
    let cellReuseId = "teamCell"
    var firebase : FIRDatabaseReference?
    var teams : NSMutableArray = []
    var scoutedTeamInfo : [[String: Int]] = []   // ["num": 254, "hasBeenScouted": 0]
    
    var teamNums = [Int]()
    var timer = Timer()
    var photoManager : PhotoManager?
    var urlsDict : [Int : NSMutableArray] = [Int: NSMutableArray]()
    var dontNeedNotification = true
    let cache = Shared.dataCache
    var refHandle = FIRDatabaseHandle()
    var firebaseStorageRef : FIRStorageReference?
    
    @IBOutlet weak var uploadPhotos: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsSelection = false //You can select once we are done setting up the photo uploader object
        firebaseStorageRef = FIRStorage.storage().reference()
        
        // Get a reference to the storage service, using the default Firebase App
        // Create a storage reference from our storage service
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(TableViewController.didLongPress(_:)))
        self.tableView.addGestureRecognizer(longPress)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        self.firebase = FIRDatabase.database().reference()
        
        self.firebase!.observe(.value, with: { (snapshot) in
            self.setup(snapshot.childSnapshot(forPath: "Teams"))
        })
        
        setupphotoManager()
        
        NotificationCenter.default.addObserver(self, selector: #selector(TableViewController.updateTitle(_:)), name: NSNotification.Name(rawValue: "titleUpdated"), object: nil)
    }
    
    func updateTitle(_ note : Notification) {
        DispatchQueue.main.async { () -> Void in
            self.title = note.object as? String
        }
    }
    
    func setup(_ snap: FIRDataSnapshot) {
        self.teams = NSMutableArray()
        self.scoutedTeamInfo = []
        self.teamNums = []
        let teamsDatabase: NSDictionary = snap.value as! NSDictionary
        for (_, info) in teamsDatabase {
            // teamInfo is the information for the team at certain number
            var allPhotosUploaded = 0
            let teamInfo = info as! [String: AnyObject]
            let imageURLs = teamInfo["pitAllImageURLs"] as? NSDictionary
            let imageKeys = teamInfo["imageKeys"] as? NSDictionary
            if imageURLs != nil && imageKeys != nil {
                if imageURLs!.count == imageKeys!.count {
                    allPhotosUploaded = 1
                    self.tableView.reloadData()
                }
            }

            self.teams.add(teamInfo)
            if let teamNum = teamInfo["number"] as? Int {
                let scoutedTeamInfoDict = ["num": teamNum, "hasBeenScouted": 0, "allPhotosUploaded": allPhotosUploaded]
                self.scoutedTeamInfo.append(scoutedTeamInfoDict)
                self.teamNums.append(teamNum)
                if let urlsForTeam = teamInfo["pitAllImageURLs"] as? NSMutableDictionary {
                    let urlsArr = NSMutableArray()
                    for (_, value) in urlsForTeam {
                        urlsArr.add(value)
                    }
                    urlsDict[teamNum] = urlsArr
                } else {
                    urlsDict[teamNum] = NSMutableArray()
                }
            } else {
                print("No Num")
            }
        }

        self.scoutedTeamInfo.sort { (team1, team2) -> Bool in
            if team1["num"]! < team2["num"]! {
                return true
            }
            return false
        }
        self.tableView.reloadData()
        self.cache.fetch(key: "scoutedTeamInfo").onSuccess({ [unowned self] (data) -> () in
            let cacheScoutedTeamInfo = NSKeyedUnarchiver.unarchiveObject(with: data) as! [[String: Int]]
            var cacheTeams: [Int] = []
            var firebaseTeams: [Int] = []
            for i in 0..<cacheScoutedTeamInfo.count {
                let teamInfo = cacheScoutedTeamInfo[i]
                cacheTeams.append(teamInfo["num"]!)
            }
            for i in 0..<self.scoutedTeamInfo.count {
                let teamInfo = self.scoutedTeamInfo[i]
                firebaseTeams.append(teamInfo["num"]!)
            }
            // If the teams in the cache are the same as the teams on Firebase, use the information inside the cache to update the table view
            if Set(cacheTeams) == Set(firebaseTeams) {
                self.scoutedTeamInfo = cacheScoutedTeamInfo
            } else {
                // Some or all teams have changed on Firebase, but if there are any identical teams, we want to keep the data on that team
                let commonTeamSet = Set(cacheTeams).intersection(Set(firebaseTeams))
                var commonTeams = Array(commonTeamSet)
                firebaseTeams = firebaseTeams.filter { !commonTeams.contains($0) }
                // Appending the cached information about the common teams
                self.scoutedTeamInfo = self.scoutedTeamInfo.filter { !commonTeams.contains($0["num"]!) }
                for i in 0..<commonTeams.count {
                    // Add cached info to cacheScoutedTeamInfo
                    let teamDictionary = cacheScoutedTeamInfo.filter { $0["num"] == commonTeams[i] }
                    self.scoutedTeamInfo.append(teamDictionary[0])
                }
            }
            // Sorts the scouted teams into numerical order
            self.scoutedTeamInfo.sort {
                $0["num"]! < $1["num"]!
            }
            self.tableView.reloadData()
        })
    }
    
    func setupphotoManager() {
        
        if self.photoManager == nil {
            self.photoManager = PhotoManager(teamsFirebase: (self.firebase?.child("Teams"))!, teamNumbers: self.teamNums)
            photoManager?.getNext(done: { (nextImage, nextKey, nextNumber, nextDate) in
                self.photoManager?.startUploadingImageQueue(photo: nextImage, key: nextKey, teamNum: nextNumber, date: nextDate)
            })
        }
        self.tableView.allowsSelection = true
    }
    
    func teamHasBeenPitScouted(_ snap: [String: AnyObject]) -> Bool { //For some reason it wasn't working other ways
        for key in firebaseKeys {
            if let _ = (snap[key]) as? NSString {
            } else {
                if let _ = (snap[key]) as? NSNumber {
                } else {
                    return false
                }
            }
        }
        return true
    }
    
    
    // MARK:  UITextFieldDelegate Methods
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2 //One section is for checked cells, the other unchecked
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            var numUnscouted = 0
            for teamN in self.scoutedTeamInfo {
                if teamN["hasBeenScouted"] == 0 {
                    numUnscouted += 1
                }
            }
            return numUnscouted
        } else if section == 1 {
            var numScouted = 0
            for teamN in self.scoutedTeamInfo {
                if teamN["hasBeenScouted"] == 1 {
                    numScouted += 1
                }
            }
            return numScouted
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as UITableViewCell
        cell.textLabel?.text = "Please Wait..."
        if self.scoutedTeamInfo.count == 0 { return cell }

        var text = "shouldntBeThis"
        if (indexPath as NSIndexPath).section == 1 {
            let scoutedTeamNums = NSMutableArray()
            for team in self.scoutedTeamInfo {
                if team["hasBeenScouted"] == 1 {
                    scoutedTeamNums.add(team["num"]!)
                }
            }
            text = "\(scoutedTeamNums[(indexPath as NSIndexPath).row])"
        } else if (indexPath as NSIndexPath).section == 0 {
            let notScoutedTeamNums = NSMutableArray()
            for team in self.scoutedTeamInfo {
                if team["hasBeenScouted"] == 0 {
                    notScoutedTeamNums.add(team["num"]!)
                }
            }
            text = "\(notScoutedTeamNums[(indexPath as NSIndexPath).row])"
        }

        cell.textLabel?.text = "\(text)"
        for i in 0 ..< scoutedTeamInfo.count {
            let teamData = scoutedTeamInfo[i]
            if teamData["num"] == Int(text) {
                if teamData["allPhotosUploaded"] == 1 {
                    cell.backgroundColor = UIColor(red: 0, green: 200, blue: 0, alpha: 0.1)
                }
            }
        }
        if((indexPath as NSIndexPath).section == 1) {
            cell.accessoryType = UITableViewCellAccessoryType.checkmark
        } else {
            cell.accessoryType = UITableViewCellAccessoryType.none
        }
        return cell
    }
    
    func didLongPress(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.ended {
            let longPressLocation = recognizer.location(in: self.tableView)
            if let longPressedIndexPath = tableView.indexPathForRow(at: longPressLocation) {
                if let longPressedCell = self.tableView.cellForRow(at: longPressedIndexPath) {
                    // If cell is becoming unchecked
                    if longPressedCell.accessoryType == UITableViewCellAccessoryType.checkmark {
                        longPressedCell.accessoryType = UITableViewCellAccessoryType.none
                        let scoutedTeamInfoIndex = self.scoutedTeamInfo.index { $0["num"]! == Int((longPressedCell.textLabel?.text)!) }
                        scoutedTeamInfo[scoutedTeamInfoIndex!]["hasBeenScouted"] = 0
                    } else { // Cell is becoming checked
                        longPressedCell.accessoryType = UITableViewCellAccessoryType.checkmark
                        let scoutedTeamInfoIndex = self.scoutedTeamInfo.index { $0["num"]! == Int((longPressedCell.textLabel?.text)!) }
                        scoutedTeamInfo[scoutedTeamInfoIndex!]["hasBeenScouted"] = 1
                    }
                    self.cache.set(value: NSKeyedArchiver.archivedData(withRootObject: scoutedTeamInfo), key: "scoutedTeamInfo")
                    
                    self.tableView.reloadData()
                }
            }
        }
    }
        
    // MARK:  UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Team View Segue" {
            var number = -1
            let indexPath = self.tableView.indexPath(for: sender as! UITableViewCell)
            if (indexPath! as NSIndexPath).section == 1 {
                let scoutedTeamNums = NSMutableArray()
                for team in self.scoutedTeamInfo {
                    if team["hasBeenScouted"] == 1 {
                        scoutedTeamNums.add(team["num"]!)
                    }
                }
                number = scoutedTeamNums[((indexPath as NSIndexPath?)?.row)!] as! Int
            } else if (indexPath! as NSIndexPath).section == 0 {
                
                let notScoutedTeamNums = NSMutableArray()
                for team in self.scoutedTeamInfo {
                    if team["hasBeenScouted"] == 0 {
                        notScoutedTeamNums.add(team["num"]!)
                    }
                }
                number = notScoutedTeamNums[((indexPath as NSIndexPath?)?.row)!] as! Int
            }
            let teamViewController = segue.destination as! ViewController
            
            let teamFB = self.firebase!.child("Teams").child("\(number)")
            teamViewController.ourTeam = teamFB
            teamViewController.firebase = self.firebase!
            teamViewController.number = number
            teamViewController.title = "\(number)"
            teamViewController.photoManager = self.photoManager
            teamViewController.firebaseStorageRef = self.firebaseStorageRef
        } else if segue.identifier == "popoverSegue" {
            let popoverViewController = segue.destination
            popoverViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            popoverViewController.popoverPresentationController!.delegate = self
            if let missingDataViewController = segue.destination as? MissingDataViewController {
                self.firebase!.child("Teams").observeSingleEvent(of: .value, with: { (snap) -> Void in
                    missingDataViewController.snap = snap
                })
            }
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if self.photoManager != nil {
            self.photoManager?.currentlyNotifyingTeamNumber = 0
        }
    }
    
    @IBAction func myShareButton(sender: UIBarButtonItem) {
        self.firebase?.observeSingleEvent(of: FIRDataEventType.value, with: { (snap) -> Void in
            do {
                let theJSONData = try JSONSerialization.data(
                    withJSONObject: self.teams ,
                    options: JSONSerialization.WritingOptions())
                let theJSONText = NSString(data: theJSONData,
                                           encoding: String.Encoding.ascii.rawValue)
                let activityViewController = UIActivityViewController(activityItems: [theJSONText ?? ""], applicationActivities: nil)
                self.present(activityViewController, animated: true, completion: {})
            } catch {
                print(error.localizedDescription)
            }
        })
        
    }}
