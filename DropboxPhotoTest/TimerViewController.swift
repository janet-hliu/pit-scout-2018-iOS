//
//  TimerViewController.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 2/3/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit

class TimerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var submitButton: UIButton!
    
    var timer = Timer()
    var count = 00.00
    var green = UIColor(red: 119/255, green: 218/255, blue: 72/255, alpha: 1.0)
    var red = UIColor(red: 244/255, green: 142/255, blue: 124/255, alpha: 1.0)
    var driveTime = 00.00
    var firebase = Database.database().reference()
    var firebaseStorageRef : StorageReference!
    var ourTeam : DatabaseReference!
    var timerArray : [Float]?
    var didSucceed: Bool? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.table.register(UINib(nibName: "TimerTableViewCell", bundle: nil), forCellReuseIdentifier: "TimerCell")
        self.table.delegate = self
        self.table.dataSource = self
        self.table.reloadData()
        let (m, s, ds) = convertSeconds(totalDeciSeconds: Int(count))
        startButton.layer.cornerRadius = 5
        startButton.backgroundColor = green
        timeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var cells = 0
        cells = (self.timerArray?.count) ?? 0
        //CODE TO FIND HOW MANY CELLS YOU NEED
        return cells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TimerCell", for: indexPath) as! TimerTableViewCell
        cell.value.text = "\(String(describing: self.timerArray![indexPath.row])) sec"
        cell.dataPoint.text = "Data Point \(String(describing: indexPath.row + 1))"
        cell.didSucceed.text = String(describing: didSucceed)
        return cell
    }
    @IBAction func startButton(_ sender: AnyObject) {
        if timer.isValid {
            timer.invalidate()
            startButton.setTitle("Start", for: UIControlState.normal)
            startButton.backgroundColor = green

        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(TimerViewController.result), userInfo: nil, repeats: true)
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
    
    func didSucceedAlert() {
        let successAlert = UIAlertController(title: "Was it Successful?", message: "", preferredStyle: .alert)
        let affirmative = UIAlertAction(title: "Yes", style: .default) { (_) in
            self.didSucceed = true
        }
        let negative = UIAlertAction(title: "No", style: .default) { (_) in
            self.didSucceed = false
        }
        successAlert.addAction(affirmative)
        successAlert.addAction(negative)
        self.present(successAlert, animated: true, completion: nil)
    }
    
   @IBAction func submitButton(_ sender: AnyObject) {
        if startButton.currentTitle as String! == "Start" && Float(count) != 0 {
            let driveTime = Float(count) / 100
            print("number of total seconds is \(driveTime)")
            //FIX THIS  timerArray should be initially called as []
            if timerArray == nil {
                timerArray = []
            }
            timerArray?.append(driveTime)
            writeToFirebase(dataKey: "pitDriveTimes", value: driveTime)
            clearTimer()
            self.viewDidLoad()
            didSucceedAlert()
        } else {
            //FIX THIS: Make it so an alert pops up here
        }
    }
    
    //FIX THIS: abstract like we did in view controller, with an enum
    func writeToFirebase(dataKey: String, value: Float) {
        ourTeam.child(dataKey).setValue(value)
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
