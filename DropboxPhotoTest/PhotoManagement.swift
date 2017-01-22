//
//  PhotoUploader.swift
//  DropboxPhotoTest
//
//  Created by Bryton Moeller on 2/8/16.
//  Copyright © 2016 citruscircuits. All rights reserved.
//

import Foundation
//import SwiftyDropbox
import Firebase
import Haneke

class PhotoManager : NSObject {
    let cache = Shared.dataCache
    var teamNumbers : [Int]
    var mayKeepWorking = true {
        didSet {
            print("mayKeepWorking: \(mayKeepWorking)")
        }
    }
    
    
    var timer : Timer = Timer()
    var teamsFirebase : FIRDatabaseReference
    var numberOfPhotosForTeam = [Int: Int]()
    var callbackForPhotoCasheUpdated = { }
    var currentlyNotifyingTeamNumber = 0
    let photoSaver = CustomPhotoAlbum()
    var activeImages = [[String: AnyObject]]()
    let firebaseImageDownloadURLBeginning = "https://firebasestorage.googleapis.com/v0/b/firebase-scouting-2017-5f51c.appspot.com/o/"
    let firebaseImageDownloadURLEnd = "?alt=media"
    var teamsList = Shared.dataCache
    let imageQueueCache = Shared.imageCache
    let firebaseStorageRef = FIRStorage.storage().reference(forURL: "gs://scouting-2017-5f51c.appspot.com")
    var teamKeys : [String]?
    
    
    init(teamsFirebase : FIRDatabaseReference, teamNumbers : [Int]) {
        
        self.teamNumbers = teamNumbers
        self.teamsFirebase = teamsFirebase
        for number in teamNumbers {
            self.numberOfPhotosForTeam[number] = 0
        }
        super.init()
    }
    
    func getSharedURLsForTeam(_ num: Int, fetched: @escaping (NSMutableArray?)->()) {
        if self.mayKeepWorking {
            self.cache.fetch(key: "sharedURLs\(num)").onSuccess { (data) -> () in
                if let urls = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableArray {
                    fetched(urls)
                } else {
                    fetched(nil)
                }
                }.onFailure { (E) -> () in
                    print("Failed to fetch URLS for team \(num)")
            }
        }
    }
    
    func updateUrl(_ teamNumber: Int, callback: @escaping (_ i: Int)->()) {
        // Firebase key of photoIndex
        self.getSharedURLsForTeam(teamNumber) { [unowned self] (urls) -> () in
            
            if let oldURLs = urls {
                let i : Int = oldURLs.count
                // var photoList: [String]
                let url = self.makeURLForTeamNumAndImageIndex(teamNumber, imageIndex: i)
                oldURLs.add(url)
                //Old URLs is actually new urls at this point
                self.cache.set(value: NSKeyedArchiver.archivedData(withRootObject: oldURLs), key: "sharedURLs\(teamNumber)", success: { _ in
                    callback(i)
                })
                
            } else {
                print("Could not fetch shared urls for \(teamNumber)")
            }
        }
    }
    
    func putPhotoLinkToFirebase(_ link: String, teamNumber: Int, selectedImage: Bool) {
        let teamFirebase = self.teamsFirebase.child("\(teamNumber)")
        let currentURLs = teamFirebase.child("pitAllImageURLs")
        currentURLs.observeSingleEvent(of: .value, with: { (snap) -> Void in
            currentURLs.childByAutoId().setValue(link)
            let myTeamFirebaseRef = self.teamsFirebase.child(String(teamNumber))
            var photoIndex = snap.value as? Int ?? -1
            photoIndex = photoIndex + 1
            myTeamFirebaseRef.child("photoIndex").setValue(photoIndex)
        })
        
        if(selectedImage) {
            teamFirebase.child("pitSelectedImageURL").setValue(link)
        }
    }
    
    func makeURLForTeamNumAndImageIndex(_ teamNum: Int, imageIndex: Int) -> String {
        return self.firebaseImageDownloadURLBeginning + self.makeFilenameForTeamNumAndIndex(teamNum, imageIndex: imageIndex) + self.firebaseImageDownloadURLEnd
    }
    
    func makeFilenameForTeamNumAndIndex(_ teamNum: Int, imageIndex: Int) -> String {
        return String(teamNum) + "_" + String(imageIndex) + ".png"
    }
    
    func makeURLForFileName(_ fileName: String) -> String {
        return self.firebaseImageDownloadURLBeginning + String(fileName)
    }
    
    func startUploadingImageQueue(number: Int) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: {
            while true {
                if Reachability.isConnectedToNetwork() {
                    self.teamsList.fetch(key: "teams").onSuccess({ (keysData) in
                        let teams = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSDictionary as! [[String: [String]]]
                        self.teamsList.set
                        var selfkeysToKill = [String]()
                        if teams.count != 0 {
                            let dict = teams[0]
                            for (team, dates) in dict {
                                for date in dates{
                                    self.imageQueueCache.fetch(key: date).onSuccess({ (image) in
                                        self.storeOnFirebase(number: Int(team)!, image: image, done: {
                                            selfkeysToKill.append(date)
                                        })
                                        sleep(60)
                                    })
                                }
                                self.teamsList.set(value: (dates.filter { !selfkeysToKill.contains($0) }).asData(), key: "teams")
                                self.teamsList = self.teamsList as! Dictionary
                            }
                            
                        }
                        
                    })
                }
                sleep(30)
            }
        })
        
    }
    // Photo storage stuff - work on waiting till wifi
    func addImageKey(key : String, number: Int) {
        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            // keys is in an array because NSKeyedUnarchiver does not work with dictionaries. Keys is an array that has the dictionary [team number: [date keys]]. It has only one index (the first dictionary, which then contains all other information
            var keys = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! [[String: [String]]]
            // Array is the list of date keys under a certain team number
            var dateArray = [String]()
            // If keys is empty and has no values
            if keys.count == 0 {
                // A team will not have any previous date keys if keys has nothing in it, so append the date key to the array without worrying about previous information
                dateArray.append(key)
                // Create new team number and make keys into data format to cache
                keys.append([String(number) : dateArray])
            } else {
                var dict = keys[0] as [String: [String]]
                // If the team number already exists in the queue
                if Array(dict.keys.map { String($0) }).contains(where: {$0 == String(number)}) {
                    // Get previous dates and add new date
                    dateArray = dict[String(number)]!
                    dateArray.append(key)
                    dict[String(number)] = dateArray
                    // Updates keys to include new date
                    keys[0] = dict
                } else { // Create the team number
                    dateArray.append(key)
                    
                    dict.updateValue(dateArray, forKey: String(number))
                    keys[0] = dict
                }
            }
            let data = NSKeyedArchiver.archivedData(withRootObject:keys)
            self.teamsList.set(value: data, key: "teams")
        })
    }
    
    func addToFirebaseStorageQueue(image: UIImage, number: Int) {
        let key = String(describing: Date())
        addImageKey(key: key, number: number)
        imageQueueCache.set(value: image, key: key)
    }
    
    func storeOnFirebase(number: Int, image: UIImage, done: @escaping ()->()) {
        self.updateUrl(number, callback: { [unowned self] i in
            let name = self.makeFilenameForTeamNumAndIndex(number, imageIndex: i)
            
            self.firebaseStorageRef.child(name).put(UIImagePNGRepresentation(image)!, metadata: nil) { metadata, error in
                
                if (error != nil) {
                    print("ERROR: \(error.debugDescription)")
                } else {
                    // Metadata contains file metadata such as size, content-type, and download URL.
                    let downloadURL = metadata!.downloadURL()?.absoluteString
                    self.putPhotoLinkToFirebase(downloadURL!, teamNumber: number, selectedImage: false)
                    
                    print("UPLOADED:\(downloadURL!)")
                    done()
                }
            }
            
        })
        
    }
    func deleteImageFromFirebase() {
        
    }
}

extension UIImage {
    public func imageRotatedByDegrees(_ degrees: CGFloat, flip: Bool) -> UIImage {
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat(M_PI)
        }
        
        // calculate the size of the rotated view's containing box for our drawing spaaace
        let rotatedViewBox = UIView(frame: CGRect(origin: CGPoint.zero, size: size))
        let t = CGAffineTransform(rotationAngle: degreesToRadians(degrees));
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap?.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0);
        
        //   // Rotate the image context
        bitmap?.rotate(by: degreesToRadians(degrees));
        
        // Now, draw the rotated/scaled image into the context
        var yFlip: CGFloat
        
        if(flip){
            yFlip = CGFloat(-1.0)
        } else {
            yFlip = CGFloat(1.0)
        }
        
        bitmap?.scaleBy(x: yFlip, y: -1.0)
        bitmap?.draw(cgImage!, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
