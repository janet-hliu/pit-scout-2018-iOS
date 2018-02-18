//
//  TimerViewController.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 2/3/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit
import Firebase

class TimerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var timerValue: UILabel!
    
    var timer = Timer()
    var count = 00.00
    var green = UIColor(red: 119/255, green: 218/255, blue: 72/255, alpha: 1.0)
    var red = UIColor(red: 244/255, green: 142/255, blue: 124/255, alpha: 1.0)
    var driveTime = 00.00
    var firebase = Database.database().reference()
    var ourTeam: DatabaseReference!
    var timeArray: [Float] = []
    var outcomeArray: [Bool] = []
    var didSucceed: Bool? = nil
    var timeDataKey: String?
    var outcomeDataKey: String?
    var timeLabelText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.timerValue.text = self.timeLabelText
        self.table.register(UINib(nibName: "CellTimerTableViewCell", bundle: nil), forCellReuseIdentifier: "timerCell")
        self.table.delegate = self
        self.table.dataSource = self
        self.table.reloadData()
        let (m, s, ds) = convertSeconds(totalDeciSeconds: Int(count))
        startButton.layer.cornerRadius = 5
        startButton.backgroundColor = green
        timeLabel.text = timeToString(m: m, s: s, ds: ds)
        outcomeDataKey = self.timeDataKey! + "Outcome"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var cells = 0
        cells = (self.timeArray.count) ?? 0
        return cells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "timerCell", for: indexPath) as! CellTimerTableViewCell
        cell.trialNumber.text = "\(String(describing: indexPath.row + 1))"
        cell.timerValue.text = "\(String(describing: self.timeArray[indexPath.row])) sec"
        cell.didSucceed.text = String(describing: self.outcomeArray[indexPath.row])
        return cell
    }
    
    @IBAction func startButton(_ sender: AnyObject) {
        if timer.isValid {
            timer.invalidate()
            startButton.setTitle("Start", for: UIControlState.normal)
            startButton.backgroundColor = green
        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(TimerViewController.result), userInfo: nil, repeats: true)
            RunLoop.current.add(self.timer, forMode: RunLoopMode.commonModes)
            startButton.setTitle("Stop", for: UIControlState.normal)
            startButton.backgroundColor = red
        }
    }
    
    @IBAction func clearButton(_ sender: AnyObject) {
        clearTimer()
    }
    
    func clearTimer() {
        timer.invalidate()
        startButton.setTitle("Start", for: UIControlState.normal)
        startButton.backgroundColor = green
        count = 0
        let (m, s, ds) = convertSeconds(totalDeciSeconds: Int(count))
        timeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    @objc func result() {
        count += 1
        let (m, s, ds) = convertSeconds(totalDeciSeconds: Int(count))
        timeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    func convertSeconds(totalDeciSeconds: Int) -> (m: Int, s: Int, ds: Int) {
        let seconds = (totalDeciSeconds / 100) % 60
        let minutes = ((totalDeciSeconds / 100) / 60)
        let deciseconds = totalDeciSeconds % 100
        return (minutes, seconds, deciseconds)
    }
    
    func timeToString(m: Int, s: Int, ds: Int) -> String {
        let m = String(format: "%02d", m)
        let s = String(format: "%02d", s)
        let ds = String(format: "%02d", ds)
        return "\(m):\(s):\(ds)"
    }
    
    func didSucceedAlert(dataKey: String) {
        let successAlert = UIAlertController(title: "Was it Successful?", message: "", preferredStyle: .alert)
        let affirmative = UIAlertAction(title: "Yes", style: .default) { (_) in
            self.didSucceed = true
            self.outcomeArray.append(true)
            self.writeToFirebase(dataKey: dataKey, neededType: NeededType.Bool, value: self.didSucceed!)
            self.viewDidLoad()
        }
        let negative = UIAlertAction(title: "No", style: .default) { (_) in
            self.didSucceed = false
            self.outcomeArray.append(false)
            self.writeToFirebase(dataKey: dataKey, neededType: NeededType.Bool, value: self.didSucceed!)
            self.viewDidLoad()
        }
        successAlert.addAction(affirmative)
        successAlert.addAction(negative)
        self.present(successAlert, animated: true, completion: nil)
    }
    
   @IBAction func submitButton(_ sender: AnyObject) {
        if startButton.currentTitle as String! == "Start" && Float(count) != 0 {
            let driveTime = Float(count) / 100
            print("number of total seconds is \(driveTime)")
            timeArray.append(driveTime)
            writeToFirebase(dataKey: self.timeDataKey!, neededType: NeededType.Float, value: driveTime)
            clearTimer()
            didSucceedAlert(dataKey: self.outcomeDataKey!)
        } else if count == 00.00 {
             let inputAlert = UIAlertController(title: "User Input?", message: "Please time something before submitting", preferredStyle: .alert)
            inputAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            present(inputAlert, animated: true, completion: nil)
        } else {
            self.startButton(self.startButton)
            let inputConfirmationAlert = UIAlertController(title: "Confirmation", message: "Please confirm this time before submitting to Firebase", preferredStyle: .alert)
            let affirmative = UIAlertAction(title: "Correct", style: .default) { (_) in
                self.submitButton(self.submitButton)
            }
            let negative = UIAlertAction(title: "Back", style: .default)
            inputConfirmationAlert.addAction(affirmative)
            inputConfirmationAlert.addAction(negative)
            present(inputConfirmationAlert, animated: true, completion: nil)
        }
    }
    
    func writeToFirebase(dataKey: String, neededType: NeededType, value: Any) {
        let currentData = ourTeam.child(dataKey)
        switch neededType {
            case .Float:
                currentData.childByAutoId().setValue(value as! Float)
            case .Bool:
                currentData.childByAutoId().setValue(value as! Bool)
        }
    }
    
    enum NeededType {
        case Float
        case Bool
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    // Do any additional setup after loading the view.
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
