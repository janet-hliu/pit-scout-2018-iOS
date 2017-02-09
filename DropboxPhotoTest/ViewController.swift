//
//  ViewController.swift
//  DropboxPhotoTest
//
//  Created by Bryton Moeller on 12/30/15.
//  Copyright © 2015 citruscircuits. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase
//import SwiftyDropbox
//import SwiftPhotoGallery
import Haneke
import MWPhotoBrowser

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UIScrollViewDelegate, MWPhotoBrowserDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var bottomScrollViewConstraint: NSLayoutConstraint!
    
    var browser = MWPhotoBrowser()
    var photoManager : PhotoManager!
    var number : Int!
    var firebase = FIRDatabase.database().reference()
    var firebaseStorageRef : FIRStorageReference!
    var ourTeam : FIRDatabaseReference!
    var photos = [MWPhoto]()
    var canViewPhotos : Bool = true //This is for that little time in between when the photo is taken and when it has been passed over to the uploader controller.
    var numberOfImagesOnFirebase = -1
    var notActuallyLeavingViewController = false
    let selectedImageName = PSUITextInputViewController()
    let teamsList = Shared.dataCache
    var deleteImagePhotoBrowser : Bool = false
    
    var activeField : UITextField? {
        didSet {
            scrollPositionBeforeScrollingToTextField = scrollView.contentOffset.y
            print(scrollPositionBeforeScrollingToTextField)
            self.scrollView.scrollRectToVisible((activeField?.frame)!, animated: true)
        }
    }
    var scrollPositionBeforeScrollingToTextField : CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Dismisses keyboard when tapping outside of keyboard
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in //Updating UI
            
            //Adding the PSUI Elements
            //Buttons
            let screenWidth = Int(self.view.frame.width)
            let addImageButton = PSUIButton(title: "Add Image", width: screenWidth, y: 0, buttonPressed: { (sender) -> () in
                self.notActuallyLeavingViewController = true
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)!
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
            })
            
            var verticalPlacement : CGFloat = addImageButton.frame.origin.y + addImageButton.frame.height
            
            let longPressImageButton = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.didLongPressImageButton(_:)))
            addImageButton.addGestureRecognizer(longPressImageButton)
            
            self.scrollView.addSubview(addImageButton)
            
            let viewImagesButton = PSUIButton(title: "View Images", width: screenWidth, y: Int(verticalPlacement), buttonPressed: { (sender) -> () in
                let imageURLs = self.ourTeam.child("imageKeys")
                imageURLs.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    if snap.childrenCount == 0 {
                        let noImageAlert = UIAlertController(title: "No Images", message: "Firebase has no image URLs for this team.", preferredStyle: UIAlertControllerStyle.alert)
                        noImageAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                        self.present(noImageAlert, animated: true, completion: nil)
                    } else {
                        self.deleteImagePhotoBrowser = false
                        self.notActuallyLeavingViewController = true
                        self.updateMyPhotos { [unowned self] in
                            let nav = UINavigationController(rootViewController: self.browser)
                            nav.delegate = self
                            self.present(nav, animated: true, completion: {
                                self.browser.reloadData()
                            })
                        }
                    }
                })
            })
            
            verticalPlacement = viewImagesButton.frame.origin.y + viewImagesButton.frame.height
            
            self.scrollView.addSubview(viewImagesButton)
            
            let deleteImagesButton = PSUIButton(title: "Delete Images", width: screenWidth, y: Int(verticalPlacement), buttonPressed: { (sender) -> () in
                let imageURLs = self.ourTeam.child("imageKeys")
                imageURLs.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    if snap.childrenCount == 0 {
                        let noImageAlert = UIAlertController(title: "No Images", message: "Firebase has no images for this team.", preferredStyle: UIAlertControllerStyle.alert)
                        noImageAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                        self.present(noImageAlert, animated: true, completion: nil)
                    } else {
                        self.deleteImagePhotoBrowser = true
                        self.notActuallyLeavingViewController = true
                        self.updateMyPhotos { [unowned self] in
                            let nav = UINavigationController(rootViewController: self.browser)
                            nav.delegate = self
                            self.present(nav, animated: true, completion: {
                                self.browser.reloadData()
                            })
                        }
                    }
                })
            })
            
            verticalPlacement = deleteImagesButton.frame.origin.y + deleteImagesButton.frame.height
            
            self.scrollView.addSubview(deleteImagesButton)
            
            /* Text Input
             let numberOfWheels = PSUITextInputViewController()
             numberOfWheels.setup("Num. Wheels", firebaseRef: self.ourTeam.child("pitNumberOfWheels"), initialValue: snap.childSnapshot(forPath: "pitNumberOfWheels").value)
             numberOfWheels.neededType = .int */
            
            self.selectedImageName.setup("Selected Image:", firebaseRef: self.ourTeam.child("pitSelectedImageName"), initialValue: snap.childSnapshot(forPath: "pitSelectedImageName").value)
            self.selectedImageName.neededType = .string
            
            //Segmented Control
            let programmingLanguage = PSUISegmentedViewController()
            programmingLanguage.setup("Programming Language:", firebaseRef: self.ourTeam.child("pitProgrammingLanguage"), initialValue: snap.childSnapshot(forPath: "pitProgrammingLanguage").value)
            programmingLanguage.segments = ["Java", "C++", "Labview", "Other"]
            programmingLanguage.neededType = .string
            
            //Switch
            let tankDrive = PSUISwitchViewController()
            tankDrive.setup("Has Tank Tread:", firebaseRef: self.ourTeam.child("pitDidUseStandardTankDrive"), initialValue: snap.childSnapshot(forPath: "pitDidUseStandardTankDrive").value)
            
            // Segmented Control
            let pitOrganization = PSUISegmentedViewController()
            pitOrganization.setup("Pit Organization:", firebaseRef: self.ourTeam.child("pitOrganization"), initialValue: snap.childSnapshot(forPath: "pitOrganization").value)
            pitOrganization.segments = ["Terrible", "Bad", "Okay", "Good", "Great"]
            pitOrganization.neededType = .string
            
            // Text Field
            let availableWeight = PSUITextInputViewController()
            availableWeight.setup("Available Weight:", firebaseRef: self.ourTeam.child("pitAvailableWeight"), initialValue: snap.childSnapshot(forPath: "pitAvailableWeight").value)
            availableWeight.neededType = .int
            
            
            // Switch
            let willCheesecake = PSUISwitchViewController()
            willCheesecake.setup("Will Cheesecake", firebaseRef: self.ourTeam.child("pitDidDemonstrateCheesecakePotential"), initialValue: snap.childSnapshot(forPath: "pitDidDemonstrateCheesecakePotential").value)
            
            // self.addChildViewController(numberOfWheels)
            self.addChildViewController(self.selectedImageName)
            self.addChildViewController(programmingLanguage)
            self.addChildViewController(tankDrive)
            self.addChildViewController(pitOrganization)
            self.addChildViewController(availableWeight)
            self.addChildViewController(willCheesecake)
            
            for childViewController in self.childViewControllers {
                self.scrollView.addSubview(childViewController.view)
                childViewController.view.frame.origin.y = verticalPlacement
                
                let width = NSLayoutConstraint(item: childViewController.view, attribute: NSLayoutAttribute.width, relatedBy: .equal, toItem: self.scrollView, attribute: .width, multiplier: 1.0, constant: 0)
                let center = NSLayoutConstraint(item: childViewController.view, attribute: NSLayoutAttribute.centerX, relatedBy: .equal, toItem: self.scrollView, attribute: .centerX, multiplier: 1.0, constant: 0)
                
                self.scrollView.addConstraints([width, center])
                print(verticalPlacement)
                verticalPlacement = childViewController.view.frame.origin.y + childViewController.view.frame.height
            }
        })
        
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: scrollPositionBeforeScrollingToTextField), animated: true)
        
        self.ourTeam.child("pitAllImageURLs").observe(.value, with: { (snap) -> Void in
            if self.numberOfImagesOnFirebase == -1 { //This is the first time that the firebase event gets called, it gets called once no matter what when you first get here in code.
                self.numberOfImagesOnFirebase = Int(snap.childrenCount)
                self.updateMyPhotos({})
            } else {
                self.numberOfImagesOnFirebase = Int(snap.childrenCount)
                self.updateMyPhotos({})
            }
        })
        
        browser = MWPhotoBrowser.init(delegate: self)
        
        // browser options
        browser.displayActionButton = false; // Show action button to allow sharing, copying, etc (defaults to YES)
        browser.displayNavArrows = true; // Whether to display left and right nav arrows on toolbar (defaults to NO)
        browser.displaySelectionButtons = true; // Whether selection buttons are shown on each image (defaults to NO)
        browser.enableGrid = false; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
        browser.autoPlayOnAppear = false; // Auto-play first video
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide(_:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil);
        teamsList.set(value: [[String: [String]]]().asData(), key: "teams")
    }
    
    func didLongPressImageButton(_ recognizer: UIGestureRecognizer) {
        notActuallyLeavingViewController = true
        if recognizer.state == UIGestureRecognizerState.ended {
            let picker = UIImagePickerController()
            
            picker.sourceType = .photoLibrary
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        }
    }
    
    func updateMyPhotos(_ callback: @escaping ()->()) {
        let imageKeys = ourTeam.child("imageKeys")
        imageKeys.observeSingleEvent(of: .value, with: { (snap) -> Void in
            self.photos.removeAll()
            let imageKeysArray = snap.value as? NSDictionary
            if imageKeysArray != nil {
                for imageKey in imageKeysArray!.allValues {
                    // use imageKey to find corresponding image in imageCache
                    self.photoManager.imageCache.fetch(key: String(describing: imageKey)).onSuccess ({ (image) in
                        let captionedImage = MWPhoto(image: image)
                        captionedImage!.caption = "\(String(describing: imageKey))"
                        self.photos.append(captionedImage!)
                    })
                }
            }
        })
        callback()
    }
    
    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(self.photos.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt, selectedChanged selected: Bool) {
        if selected {
            if self.deleteImagePhotoBrowser == false {
                // Setting selected image
                self.dismiss(animated: true, completion: nil)
                let imageKeys = ourTeam.child("imageKeys")
                imageKeys.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    let imageKeysDict = snap.value as! NSDictionary
                    for key in imageKeysDict.allValues {
                        if key as! String == photoBrowser.photo(at: index).caption!() {
                            self.selectedImageName.set(key)
                            self.ourTeam.child("pitSelectedImageName").setValue(key)
                            break
                        }
                    }
                })
            } else {
                // Deleting images from firebase database but not from firebase storage
                ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    let imageKeysDict = snap.childSnapshot(forPath: "imageKeys").value as! NSDictionary
                    for key in imageKeysDict.allValues {
                        if key as! String == photoBrowser.photo(at: index).caption!() {
                            self.photoManager.imageCache.remove(key: key as! String)
                            self.ourTeam.child("imageKeys").child(key as! String).removeValue()
                            break
                        }
                        
                    }
                
                    // Deletes image URL from pitAllImageURLs
                    var imageURLDictionary = snap.childSnapshot(forPath: "pitAllImageURLs").value as? [String: String]
                    self.photoManager.getSharedURLsForTeam(self.number) { (urls) -> () in
                        for (key, url) in imageURLDictionary! {
                            if url == String(describing: urls![Int(index)]) {
                                imageURLDictionary?.removeValue(forKey: key)
                                self.ourTeam.child("pitAllImageURLs").child(key).removeValue()
                                
                                if imageURLDictionary!.count == 0 {
<<<<<<< HEAD
                                    self.ourTeam.child("pitSelectedImageURL").removeValue()
                                    
=======
                                    self.ourTeam.child("pitSelectedImageName").removeValue()
>>>>>>> 8a35a2456ba5dc347ecb84d8f986846813213eb0
                                }
                                break
                            }
                        }
                    }
                })
            }
        }
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        return self.photos[Int(index)]
    }
    
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        notActuallyLeavingViewController = false
        canViewPhotos = false
        picker.dismiss(animated: true, completion: nil)
        self.photos.append(MWPhoto(image: image))
        photoManager.photoSaver.saveImage(image)
        photoManager.addToFirebaseStorageQueue(image: image, number: number)
    }
    //You shold only have to call this once each time the app wakes up
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { // So that the scroll view can scroll so you can see the text field you are editing
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        activeField = textField
    }
    
    func keyboardWillHide(_ notification:Notification){
        // scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: scrollPositionBeforeScrollingToTextField), animated: true)
        print(self.view.frame.midY)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func isNull(_ object: AnyObject?) -> Bool {
        if object_getClass(object) == object_getClass(NSNull()) {
            return true
        }
        return false
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        notActuallyLeavingViewController = false
    }
    
    override func viewWillDisappear(_ animated: Bool) { //If you are leaving the view controller, and only have one image, make that the selected one.
        super.viewWillDisappear(animated)
        self.photoManager.getSharedURLsForTeam(self.number) { (urls) -> () in
                if urls?.count == 1 {
                    self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
                        // Should only have one image key because there is only one url
                        let imageKey = snap.childSnapshot(forPath: "imageKeys").value as! NSDictionary
                        for value in imageKey.allValues {
                            self.selectedImageName.set(value as AnyObject)
                        }
                    })
                }
        }
        
        self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
            if snap.childSnapshot(forPath: "pitDidUseStandardTankDrive").value as? Bool == nil {
                self.ourTeam.child("pitDidUseStandardTankDrive").setValue(false)
            }
            if snap.childSnapshot(forPath: "pitDidDemonstrateCheesecakePotential").value as? Bool == nil {
                self.ourTeam.child("pitDidDemonstrateCheesecakePotential").setValue(false)
            }
            let imageKeys = snap.childSnapshot(forPath: "imageKeys").value as? [String]
            if imageKeys != nil {
                if imageKeys!.count == 1 {
                    self.ourTeam.child("pitSelectedImageName").setValue(imageKeys![0])
                }
            }
        })
    }
    
    func dismissKeyboard () {
        view.endEditing(true)
    }
    
}



extension Dictionary {
    var vals : [AnyObject] {
        var v = [AnyObject]()
        for (_, value) in self {
            v.append(value as AnyObject)
        }
        return v
    }
    var keys : [AnyObject] {
        var k = [AnyObject]()
        for (key, _) in self {
            k.append(key as AnyObject)
        }
        return k
    }
    var FIRJSONString : String {
        //if self.keys[0] as? String != nil && self.vals[0] as? String != nil {
        var JSONString = "{\n"
        for i in 0..<self.keys.count {
            JSONString.append(keys[i] as! String)
            JSONString.append(" : ")
            JSONString.append(String(describing: vals[i]))
            JSONString.append("\n")
        }
        JSONString.append("}")
        return JSONString
        /*} else {
         return "Not of Type [String: String], so cannot use FIRJSONString."
         }*/
    }
}

extension Array : DataConvertible, DataRepresentable {
    
    public typealias Result = Array
    
    public static func convertFromData(_ data:Data) -> Result? {
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? Array
    }
    
    public func asData() -> Data! {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
}

