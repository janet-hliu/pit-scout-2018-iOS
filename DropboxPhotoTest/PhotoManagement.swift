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
    // cache of urls used to set up images to view or delete
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
    // teamsList is used to upload images to firebase, imageKeys on firebase is used to find selectedImage via imageCache (even if device is offline)
    var teamsList = Shared.dataCache
    let imageCache = Shared.imageCache
    let firebaseStorageRef = FIRStorage.storage().reference(forURL: "gs://scouting-2017-5f51c.appspot.com")
    var teamKeys : [String]?
    var keyIndex : Int = 0
    
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
            teamsFirebase.child("\(num)").child("pitAllImageURLs").observeSingleEvent(of: .value , with: { (updateURL) in
                if let urlsDict = updateURL.value as? NSDictionary {
                    fetched((urlsDict.allValues as NSArray).mutableCopy() as? NSMutableArray)
                } else {
                    fetched(nil)
                }
            })
        }
    }
    
    func putPhotoLinkToFirebase(_ link: String, teamNumber: Int) {
        let teamFirebase = self.teamsFirebase.child("\(teamNumber)")
        let currentURLs = teamFirebase.child("pitAllImageURLs")
        teamFirebase.observeSingleEvent(of: .value, with: { (snap) -> Void in
            currentURLs.childByAutoId().setValue(link)
            var photoIndex = snap.childSnapshot(forPath: "photoIndex").value as? Int ?? 0
            photoIndex = photoIndex + 1
            teamFirebase.child("photoIndex").setValue(photoIndex)
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
    
    func getNext (done: @escaping (_ nextPhoto: UIImage, _ nextKey: String, _ nextNumber: Int)->()) {
        self.teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                // Choose key in index 0 of cache and find the corresponding image
                var teamNum : Int
                var nextPhoto = UIImage()
                let keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
                if keysArray.count != 0 {
                    if keysArray.count > self.keyIndex {
                        let nextKey = String(keysArray[self.keyIndex])
                        let nextKeyArray = nextKey!.components(separatedBy: "_")
                        teamNum = Int(nextKeyArray[0])!
                        self.imageCache.fetch(key: nextKey!).onSuccess({ (image) in
                            nextPhoto = image
                            done(nextPhoto, nextKey!, teamNum)
                        })
                        self.keyIndex += 1
                        // Gives time for the cache fetch to occur
                        sleep(1)
                    } else {
                        self.keyIndex = 0
                        self.getNext(done: { (image, key, number) in
                            done(image, key, number)
                        })
                    }
                } else {
                    self.keyIndex = 0
                    // Retry again in a minute
                    sleep(60)
                    self.getNext(done: { (image, key, number) in
                        done(image, key, number)
                    })
                }
            }
        })
    }

    func removeFromCache(key: String, done: @escaping ()->()) {
        // Removes key from dataCache
        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            var keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
            for var i in 0 ..< keysArray.count {
                if String(keysArray[i]) != key {
                    i += 1
                } else {
                    keysArray.remove(at: i)
                    break
                }
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: keysArray)
            self.teamsList.set(value: data, key: "teams")
            done()
        })
    }
    
    func startUploadingImageQueue(photo: UIImage, key: String, teamNum: Int) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            self.storeOnFirebase(number: teamNum, image: photo, done: { didSucceed, photoIndex in
                if didSucceed {
                    //self.updateUrl(teamNumber: teamNum, photoIndex: photoIndex)
                    self.removeFromCache(key: key, done: {
                        self.getNext(done: { nextPhoto, nextKey, nextNumber in
                            self.startUploadingImageQueue(photo: nextPhoto, key: nextKey, teamNum: nextNumber)
                        })
                    })
                } else {
                    sleep(60)
                    self.getNext(done: { (image, key, number) in
                        self.startUploadingImageQueue(photo: image, key: key, teamNum: number)
                    })
                }
            })
        }
    }
    
    func storeOnFirebase(number: Int, image: UIImage, done: @escaping (_ didSucceed : Bool, _ photoIndex: Int)->()) {
        self.teamsFirebase.observeSingleEvent(of: .value, with: { (snap) -> Void in
            let photoIndex = (snap.childSnapshot(forPath: "photoIndex").value as? Int ?? 0)
            //self.teamsFirebase.child("\(number)").child("photoIndex").setValue(0)
            let name = self.makeFilenameForTeamNumAndIndex(number, imageIndex: photoIndex)
            var e: Bool = false
            self.firebaseStorageRef.child(name).put(UIImagePNGRepresentation(image)!, metadata: nil) { [done] metadata, error in
                
                if (error != nil) {
                    print("ERROR: \(error.debugDescription)")
                } else {
                    // Metadata contains file metadata such as size, content-type, and download URL.
                    let downloadURL = metadata!.downloadURL()?.absoluteString
                    self.putPhotoLinkToFirebase(downloadURL!, teamNumber: number)
                    e = true
                    print("UPLOADED: \(downloadURL!)")
                }
                done(e, photoIndex)
            }
        })
    }
 
    // Photo storage stuff - work on waiting till wifi
    func addImageKey(key : String, number: Int) {
        // Adding to teamsList cache to upload photos
        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            var keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
            keysArray.append(key)
            let data = NSKeyedArchiver.archivedData(withRootObject: keysArray)
            self.teamsList.set(value: data, key: "teams")
        })
        let currentImageKeys = teamsFirebase.child("\(number)").child("imageKeys")
        teamsFirebase.child("\(number)").observeSingleEvent(of: .value, with: { (snap) -> Void in
            currentImageKeys.childByAutoId().setValue(key)
        })
    }
    
    func addToFirebaseStorageQueue(image: UIImage, number: Int) {
        let date = String(describing: Date())
        // Format of keys will be teamNumber_date. Will use _ to distinguish between number and date
        let key = "\(number)_\(date)"
        addImageKey(key: key, number: number)
        imageCache.set(value: image, key: key)
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
