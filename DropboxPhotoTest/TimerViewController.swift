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
    
    @IBOutlet weak var StartStopButton: UIButton!
        
    var timer = Timer()
    var count = 00.00
 
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
        timer.invalidate()
        StartStopButton.setTitle("Start", for: UIControlState.normal)
         StartStopButton.backgroundColor = UIColor.green
        count = 0
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    
    @objc func result(){
        count += 1
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        
        TimeLabel.text = timeToString(m: m, s: s, ds: ds)
    }
    func convertSeconds(totalSeconds: Int) -> (m:Int, s:Int, ds:Int){
        let seconds = (totalSeconds / 100) % 60
        let minutes = ((totalSeconds / 100) / 60)
        let deciseconds = totalSeconds % 100
        return (minutes, seconds, deciseconds)
    }
    func timeToString(m:Int, s:Int, ds:Int) -> String {
        
        var m = String(format: "%02d", m)
        var s = String(format: "%02d", s)
        var ds = String(format: "%02d", ds)
        return "\(m):\(s):\(ds)"
    }
    
   @IBAction func SubmitButton(_ sender: AnyObject) {
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        let (m, s, ds) = convertSeconds(totalSeconds: Int(count))
        
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
