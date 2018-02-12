//
//  TimerViewController.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 2/3/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit
import Firebase
import FirebaseStorage

class TimerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var cells = 0
        cells = (self.TimerArray?.count)!
        //CODE TO FIND HOW MANY CELLS YOU NEED
        return cells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TimerCell", for: indexPath) as! TimerTableViewCell
        cell.value.text = "\(String(describing: self.TimerArray![indexPath.row])) sec"
        cell.dataPoint.text = "Data Point \(String(describing: indexPath.row + 1))"
        return cell
    }
    
    @IBOutlet weak var table: UITableView!
    
    @IBOutlet weak var TimeLabel: UILabel!
    
    @IBOutlet weak var StartStopButton: UIButton!
        
    var timer = Timer()
    var count = 00.00
    var AutoRunTime = 00.00
    var firebase = Database.database().reference()
    var firebaseStorageRef : StorageReference!
    var ourTeam : DatabaseReference!
    var TimerArray : [Float]?
    
    @IBAction func StartButton(_ sender: AnyObject) {
        if timer.isValid {
            timer.invalidate()
            StartStopButton.setTitle("Start", for: UIControlState.normal)
            StartStopButton.backgroundColor = UIColor.green

        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(TimerViewController.result), userInfo: nil, repeats: true)
            StartStopButton.setTitle("Stop", for: UIControlState.normal)
            StartStopButton.backgroundColor = UIColor.red
        }
    }
    
    @IBAction func ClearButton(_ sender: AnyObject) {
        clearTimer()
    }
    
    func clearTimer() {
        timer.invalidate()
        StartStopButton.setTitle("Start", for: UIControlState.normal)
        StartStopButton.backgroundColor = UIColor.green
        count = 0
        let (m, s, ds) = convertSeconds(totalDeciseconds: Int(count))
        
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
        
    
    @objc func result(){
        count += 1
        let (m, s, ds) = convertSeconds(totalDeciseconds: Int(count))
        
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    func convertSeconds(totalDeciseconds: Int) -> (m:Int, s:Int, ds:Int){
        let seconds = (totalDeciseconds / 100) % 60
        let minutes = ((totalDeciseconds / 100) / 60)
        let deciseconds = totalDeciseconds % 100
        return (minutes, seconds, deciseconds)
    }
    func timeToString(m:Int, s:Int, ds:Int) -> String {
        
        let m = String(format: "%02d", m)
        let s = String(format: "%02d", s)
        let ds = String(format: "%02d", ds)
        return "\(m):\(s):\(ds)"
    }
    
    
    
   @IBAction func SubmitButton(_ sender: AnyObject) {
        if StartStopButton.currentTitle as String! == "Start" && Float(count) != 0 {
            let AutoRunTime = Float(count) / 100
            print("number of total seconds is \(AutoRunTime)")
            TimerArray?.append(AutoRunTime)
            ourTeam.child("pitDriveTimes").setValue(TimerArray)
            clearTimer()
            self.viewDidLoad()
        }else{
            print("Don't do that.")
    }
    }
    
    func writeToFirebase(dataKey: String, AutoTime: Float) {
       ourTeam.child(dataKey).setValue(AutoTime)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.table.register(UINib(nibName: "TimerTableViewCell", bundle: nil), forCellReuseIdentifier: "TimerCell")
        self.table.delegate = self
        self.table.dataSource = self
        self.table.reloadData()
        let (m, s, ds) = convertSeconds(totalDeciseconds: Int(count))
        
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
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
