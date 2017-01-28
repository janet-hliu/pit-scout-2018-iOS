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
    var keyIndex : Int = 0
    var keyFetchFailed : Bool = true
    
    
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
    
    func updateUrl(_ teamNumber: Int, done: @escaping (_ i: Int)->()) {
        let teamFirebase = teamsFirebase.child("\(teamNumber)")
        teamFirebase.observeSingleEvent(of: .value, with: { (snap) -> Void in
            var photoIndex = snap.childSnapshot(forPath: "photoIndex").value as? Int
            self.cache.fetch(key: "sharedURLs\(teamNumber)").onSuccess({ (keysData) in
                var url: String
                if photoIndex == nil {
                    url = self.makeURLForTeamNumAndImageIndex(teamNumber, imageIndex: 0)
                    photoIndex = 0
                    teamFirebase.child("photoIndex").setValue(0)
                } else {
                    url = self.makeURLForTeamNumAndImageIndex(teamNumber, imageIndex: photoIndex!)
                }
                let urlList = NSKeyedUnarchiver.unarchiveObject(with: keysData) as?NSMutableArray
                urlList?.add(url)
                let urlData = NSKeyedArchiver.archivedData(withRootObject: urlList)
                self.cache.set(value: urlData, key: "sharedURLs\(teamNumber)")
                done(photoIndex!)
            })
        })
    }
    
    func putPhotoLinkToFirebase(_ link: String, teamNumber: Int, selectedImage: Bool) {
        let teamFirebase = self.teamsFirebase.child("\(teamNumber)")
        let currentURLs = teamFirebase.child("pitAllImageURLs")
        teamFirebase.observeSingleEvent(of: .value, with: { (snap) -> Void in
            currentURLs.childByAutoId().setValue(link)
            var photoIndex = snap.childSnapshot(forPath: "photoIndex").value as? Int ?? 0
            photoIndex = photoIndex + 1
            teamFirebase.child("photoIndex").setValue(photoIndex)
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
    
    func getNext (done: @escaping (_ nextPhoto: UIImage, _ nextKey: String, _ nextNumber: Int)->()) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            while self.keyFetchFailed {
                self.teamsList.fetch(key: "teams").onSuccess({ (keysData) in
                    // Choose key in index 0 of cache and find the corresponding image
                    var teamNum : Int
                    var nextPhoto = UIImage()
                    let keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
                    if keysArray.count > self.keyIndex {
                        if keysArray.count != 0 {
                            let nextKey = String(keysArray[self.keyIndex])
                            let nextKeyArray = nextKey!.components(separatedBy: "_")
                            teamNum = Int(nextKeyArray[0])!
                            self.imageQueueCache.fetch(key: nextKey!).onSuccess({ (image) in
                                nextPhoto = image
                                done(nextPhoto, nextKey!, teamNum)
                                self.keyFetchFailed = false
                            })
                            self.keyIndex += 1
                            // Gives time for the cache fetch to occur
                            sleep(1)
                        } else {
                            // There are no keys in cache- either all the keys have been uploaded or no keys are cached. Either way, reset keyIndex to 0
                            self.keyIndex = 0
                            // No keys or images in cache, retry in 60 seconds
                            sleep(60)
                        }
                    } else {
                        
                    }
                })
            }
        }
    }

    func removeFromCache(photo: UIImage, key: String, done: @escaping ()->()) {
        // Removes image from imageCache
        imageQueueCache.remove(key: key)
        // Removes key from dataCache
        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            var keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
            if keysArray.count >= self.keyIndex {
                // keyIndex is one index higher than successfully uploaded index
                self.keyIndex = 0
            }
            for var i in 0 ..< keysData.count {
                if String(keysData[i]) != key {
                    i += 1
                } else {
                    keysArray.remove(at: i)
                    break
                }
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: keysArray)
            self.teamsList.set(value: data, key: "teams")
        })
    }
    
    func startUploadingImageQueue(photo: UIImage, key: String, teamNum: Int) {
        keyFetchFailed = true
        // If connected to wifi, and if photo stores on firebase, THEN remove the image and key from the caches and get the next photo to upload
        if Reachability.isConnectedToNetwork() {
            self.storeOnFirebase(number: teamNum, image: photo, done: { didSucceed in
                if didSucceed {
                    self.removeFromCache(photo: photo, key: key, done: {
                        self.getNext(done: { nextPhoto, nextKey, nextNumber in
                            self.startUploadingImageQueue(photo: nextPhoto, key: nextKey, teamNum: nextNumber)
                        })
                    })
                }
            })
        }
        sleep(60)
        
    }
    
    func storeOnFirebase(number: Int, image: UIImage, done: @escaping (_ didSucceed : Bool)->()) {
        self.updateUrl(number, done: { [unowned self] i in
            let name = self.makeFilenameForTeamNumAndIndex(number, imageIndex: i)
            var e: Bool = false
            self.firebaseStorageRef.child(name).put(UIImagePNGRepresentation(image)!, metadata: nil) { metadata, error in
                
                if (error != nil) {
                    print("ERROR: \(error.debugDescription)")
                } else {
                    // Metadata contains file metadata such as size, content-type, and download URL.
                    let downloadURL = metadata!.downloadURL()?.absoluteString
                    self.putPhotoLinkToFirebase(downloadURL!, teamNumber: number, selectedImage: false)
                    e = true
                    print("UPLOADED:\(downloadURL!)")
                }
            }
            done(e)
        })
        
    }
 
    // Photo storage stuff - work on waiting till wifi
    func addImageKey(key : String, number: Int) {
        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            var keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
            keysArray.append(key)
            let data = NSKeyedArchiver.archivedData(withRootObject: keysArray)
            self.teamsList.set(value: data, key: "teams")
        })
    }
    
    func addToFirebaseStorageQueue(image: UIImage, number: Int) {
        let date = String(describing: Date())
        // Format of keys will be teamNumber-date. Will use - to distinguish between number and date
        let key = "\(number)_\(date)"
        addImageKey(key: key, number: number)
        imageQueueCache.set(value: image, key: key)
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
