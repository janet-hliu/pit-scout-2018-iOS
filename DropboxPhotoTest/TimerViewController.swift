//
//  TimerViewController.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 2/3/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit

class TimerViewController: UIViewController {

    @IBOutlet weak var TimeLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var submitButton: UIButton!
    
    var timer = Timer()
    var count = 00.00
    var green = UIColor(red: 119/255, green: 218/255, blue: 72/255, alpha: 1.0)
    var red = UIColor(red: 244/255, green: 142/255, blue: 124/255, alpha: 1.0)
   
    override func viewDidLoad() {
        super.viewDidLoad()
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        startButton.layer.cornerRadius = 5
        startButton.backgroundColor = green
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
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
        timer.invalidate()
        startButton.setTitle("Start", for: UIControlState.normal)
        startButton.backgroundColor = green
        count = 0
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    @objc func result() {
        count += 1
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    func convertSeconds(totalSeconds: Int) -> (m: Int, s: Int, ds: Int) {
        let seconds = (totalSeconds / 100) % 60
        let minutes = ((totalSeconds / 100) / 60)
        let deciseconds = totalSeconds % 100
        return (minutes, seconds, deciseconds)
    }
    
    func timeToString(m: Int, s: Int, ds: Int) -> String {
        let m = String(format: "%02d", m)
        let s = String(format: "%02d", s)
        let ds = String(format: "%02d", ds)
        return "\(m):\(s):\(ds)"
    }
    
   @IBAction func submitButton(_ sender: AnyObject) {
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
