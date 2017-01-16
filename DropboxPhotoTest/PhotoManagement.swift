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
    let firebaseImageDownloadURLBeginning = "https://firebasestorage.googleapis.com/v0/b/firebase-scouting-2016.appspot.com/o/"
    let firebaseImageDownloadURLEnd = "?alt=media"
    let teamsList = Shared.dataCache
    let imageQueueCache = Shared.imageCache
    let firebaseStorageRef = FIRStorage.storage().reference(forURL: "gs://firebase-scouting-2016.appspot.com")
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
        self.getSharedURLsForTeam(teamNumber) { [unowned self] (urls) -> () in
            if let oldURLs = urls {
                let i : Int
                if oldURLs.count == 3 {
                    i = 0
                } else if oldURLs.count < 3 {
                    i = oldURLs.count //If there are currently two images, we want i to be 2, because that will be the index of the third image
                } else {
                    print("This should not happen")
                    i = 0
                }
                let url = self.makeURLForTeamNumAndImageIndex(teamNumber, imageIndex: i)
                if oldURLs.count - 1 == i {
                    oldURLs[i] = url
                } else if oldURLs.count == i {
                    oldURLs.add(url)
                } else {
                    oldURLs[i] = url
                } //Old URLs is actually new urls at this point
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
        let currentURLs = teamFirebase.child("otherImageUrls")
        currentURLs.observeSingleEvent(of: .value, with: { (snap) -> Void in
            if snap.childrenCount >= 3 {
                currentURLs.child((snap.children.allObjects.first as! FIRDataSnapshot).key).removeValue()
            }
            currentURLs.childByAutoId().setValue(link)

            if(selectedImage) {
                teamFirebase.child("selectedImageUrl").setValue(link)
            }
        })
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
                        let teams = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! [[String: [String]]]
                        var keysToKill = [String]()
                        for i in teams{
                            for (team, dates) in i {
                                for date in dates{
                                    self.imageQueueCache.fetch(key: date).onSuccess({ (image) in
                                        self.storeOnFirebase(number: number, image: image, done: {
                                            keysToKill.append(date)
                                        })
                                        sleep(60)
                                    })
                                }
                                self.teamsList.set(value: (dates.filter { !keysToKill.contains($0) }).asData(), key: "teams")
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
            // dictionary is in array because NSKeyedUnarchiver does not work with dictionaries. Keys is an array that has team number: [date keys: images]
            var keys = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! [[String: [String]]]
            // array is the list of date keys under a certain team number
            var array = [String]()
            array = keys[0][String(number)]!
            array.append(key)
            // if keys is empty and has no values
            if keys.count == 0 {
                // create new team number
                keys.append([String(number):array])
                let data = NSKeyedArchiver.archivedData(withRootObject:keys)
                self.teamsList.set(value: data, key: "teams")
            } else {
                var dict = keys[0] as! [String: [String]]
                // if the team number already exists in the queue
                if Array(dict.keys.map { String($0) }).contains(where: {$0 == String(number)}) {
                    
                } else {
                    
                }
                keys.append([String(number):array])
                let data = NSKeyedArchiver.archivedData(withRootObject:keys)
                self.teamsList.set(value:  data, key: "teams")
            }
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
                    
                    print("UPLOADED: \(downloadURL)")
                    done()
                }
            }
          
        })
        
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
