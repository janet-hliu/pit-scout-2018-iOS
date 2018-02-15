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
import FirebaseStorage
import Haneke
import MWPhotoBrowser

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UIScrollViewDelegate, MWPhotoBrowserDelegate, UITextViewDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var addImageButton: UIButton!
    @IBOutlet weak var viewImageButton: UIButton!
    @IBOutlet weak var deleteImageButton: UIButton!
    @IBOutlet weak var availableWeightTextField: UITextField! { didSet { availableWeightTextField.delegate = self } }
    @IBOutlet weak var selectedImageTextField: UITextField! { didSet { selectedImageTextField.delegate = self } }
    @IBOutlet weak var maxHeightTextField: UITextField! { didSet { maxHeightTextField.delegate = self } }
    @IBOutlet weak var programmingLanguageSegControl: UISegmentedControl!
    @IBOutlet weak var driveTrainSegControl: UISegmentedControl!
    @IBOutlet weak var climberTypeSegControl: UISegmentedControl!
    @IBOutlet weak var driveTimerButton: UIButton!
    @IBOutlet weak var rampTimerButton: UIButton!
    @IBOutlet weak var canCheesecakeSwitch: UISwitch!
    @IBOutlet weak var SEALsNotesTextView: UITextView!{ didSet { SEALsNotesTextView.delegate = self } }
    var timerArray: [Float] = []
    @IBAction func AutoTimerSegue(_ sender: UIButton) {
    }
    
    var photoManager : PhotoManager!
    var number : Int!
    var firebase = Database.database().reference()
    var firebaseStorageRef : StorageReference!
    var ourTeam : DatabaseReference!
    var photos = [MWPhoto]()
    var canViewPhotos : Bool = true //This is for that little time in between when the photo is taken and when it has been passed over to the uploader controller.
    var numberOfImagesOnFirebase = -1
    var notActuallyLeavingViewController = false
    let selectedImageName = PSUITextInputViewController()
    let teamsList = Shared.dataCache
    var deleteImagePhotoBrowser : Bool = false
    let dataKeys: [[String: NeededType]] = [["pitSelectedImage": .String], ["pitAvailableWeight": .Int], ["pitDriveTrain": .String], ["pitCanCheesecake": .Bool], ["pitSEALsNotes": .String], ["pitProgrammingLanguage": .String], ["pitClimberType": .String], ["pitMaxHeight": .Float], ["pitAutoRunTime": .Float]/*, ["pitMoveAbility": .String]*/]
    var didEnterTextView : Bool?
    var didLeaveTextView : Bool?
    var red: UIColor =  UIColor(red: 244/255, green: 142/255, blue: 124/255, alpha: 1)
    var white: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    
    var activeField : UITextField? {
        didSet {
            scrollPositionBeforeScrollingToTextField = scrollView.contentOffset.y
            print(scrollPositionBeforeScrollingToTextField)
            self.scrollView.scrollRectToVisible((activeField?.frame)!, animated: true)
        }
    }
    var scrollPositionBeforeScrollingToTextField : CGFloat = 0
    
    var activeView : UITextView? {
        didSet {
            scrollPositionBeforeScrollingToTextView = scrollView.contentOffset.y
            print(scrollPositionBeforeScrollingToTextView)
            self.scrollView.scrollRectToVisible((activeView?.frame)!, animated: true)
            }
        }
    var scrollPositionBeforeScrollingToTextView : CGFloat = 0
    
    
    //MARK: Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dismisses keyboard when tapping outside of keyboard
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        // To recognize different types of taps on addImageButton
        let normalTapGestureAddImage = UITapGestureRecognizer(target: self, action: #selector(ViewController.didNormalTapAddImage(_:)))
        let longGestureAddImage = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.didLongTap(_:)))
        addImageButton.addGestureRecognizer(normalTapGestureAddImage)
        addImageButton.addGestureRecognizer(longGestureAddImage)
        addImageButton.layer.cornerRadius = 5
        
        // To set up image browser on viewImageButton
        let normalTapGestureViewImage = UITapGestureRecognizer(target: self, action: #selector(ViewController.didNormalTapViewImage(_:)))
        viewImageButton.addGestureRecognizer(normalTapGestureViewImage)
        viewImageButton.layer.cornerRadius = 5
        
        // To set up image browser on deleteImageButton
        let normalTapGestureDeleteImage = UITapGestureRecognizer(target: self, action: #selector(ViewController.didNormalTapDeleteImage(_:)))
        deleteImageButton.addGestureRecognizer(normalTapGestureDeleteImage)
        deleteImageButton.layer.cornerRadius = 5
        driveTimerButton.layer.cornerRadius = 5
        rampTimerButton.layer.cornerRadius = 5
        
        // Setting up all the other UI elements
        self.setUpTextField(elementName: availableWeightTextField, dataKey: "pitAvailableWeight", dataKeyIndex: 1, neededType: NeededType.Int)
        
        self.setUpTextField(elementName: selectedImageTextField, dataKey: "pitSelectedImage", dataKeyIndex: 0, neededType: NeededType.String)
        
        self.setUpTextField(elementName: maxHeightTextField, dataKey: "pitMaxHeight", dataKeyIndex: 7, neededType: NeededType.Float)
        
        self.setUpSegmentedControl(elementName: programmingLanguageSegControl, dataKey: "pitProgrammingLanguage", dataKeyIndex: 5)
        
        self.setUpSegmentedControl(elementName: driveTrainSegControl, dataKey: "pitDriveTrain", dataKeyIndex: 2)
        
      //  self.setUpSegmentedControl(elementName: moveAbilitySegControl, dataKey: "pitMoveAbility", dataKeyIndex: 9)
        
        self.setUpSegmentedControl(elementName: climberTypeSegControl, dataKey: "pitClimberType", dataKeyIndex: 6)
    
        self.setUpSwitch(elementName: canCheesecakeSwitch, dataKey: "pitCanCheesecake", dataKeyIndex: 3)
        
        self.setUpTextView(elementName: SEALsNotesTextView, dataKey: "pitSEALsNotes", dataKeyIndex: 4, placeHolder: "Miscellaneous Notes: climber notes, possible autos, etc")
        SEALsNotesTextView.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        teamsList.fetch(key: "teams").onSuccess({ (keysData) in
            let keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as? [String]
            if keysArray == nil {
                // teamsList is the cache of keys to be placed on firebase. It is an array of strings [teamNum_date]
                self.teamsList.set(value: [String]().asData(), key: "teams")
            }
        })
        
        ourTeam.observeSingleEvent(of: .value) { (snapshot) in
            for i in snapshot.childSnapshot(forPath: "pitDriveTimes").children {
                if let unwrapped = (i as! DataSnapshot).value as? Float {
                    self.timerArray.append(unwrapped)
                }
            }
        }
    }
    
    enum NeededType {
        case Int
        case Float
        case Bool
        case String
    }
    
    // This function gets a UI element's current value in Firebase. It is a function that prevents initialValue from being returned, until the asynchronous Firebase observation is completed.
    func getInitialValue(dataKey: String, neededType: NeededType, done: @escaping (_ initialValue : Any?) ->()) {
        var initialValue: Any?
        self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
            
            switch neededType {
                
            case .Int:
                initialValue = snap.childSnapshot(forPath: dataKey).value as? Int ?? "No current value"
            case .Float:
                initialValue = snap.childSnapshot(forPath: dataKey).value as? Float ?? "No current value"
            case .Bool:
                initialValue = snap.childSnapshot(forPath: dataKey).value as? Bool ?? "No current value"
            case .String:
                if let a = snap.childSnapshot(forPath: dataKey).value as? String, snap.childSnapshot(forPath: dataKey).value as? String != "" {
                    initialValue = a
                } else {
                    initialValue = "No current value"
                }
            }
            done(initialValue)
        })
    }
    
    func setUpTextField(elementName: UITextField, dataKey: String, dataKeyIndex: Int, neededType: NeededType) {
        self.getInitialValue(dataKey: dataKey, neededType: neededType, done: { initialValue in
            self.setInitialText(textField: elementName, initialValue: initialValue!)
        })
        elementName.tag = dataKeyIndex
        elementName.addTarget(self, action: #selector(textFieldValueChanged(_:)), for: UIControlEvents.editingChanged)
    }
    
    func setUpTextView(elementName: UITextView, dataKey: String, dataKeyIndex: Int, placeHolder: String) {
        self.getInitialValue(dataKey: dataKey, neededType: .String, done: { initialValue in
            if initialValue as! String != "No current value" {
                elementName.text = String(describing: initialValue!)
            } else {
                elementName.textColor = self.white
                elementName.backgroundColor = self.red         
                elementName.text = String(describing: placeHolder)
            }
        })
        
    }
    
    func setUpSegmentedControl(elementName: UISegmentedControl, dataKey: String, dataKeyIndex: Int) {
        self.getInitialValue(dataKey: dataKey, neededType: .String, done: { initialValue in
            self.setSelectedSegment(segControl: elementName, initialValue: initialValue as! String)
        })
        elementName.tag = dataKeyIndex
        elementName.addTarget(self, action: #selector(ViewController.segmentedControlValueChanged(_:)), for: .valueChanged)
    }
    
    func setUpSwitch(elementName: UISwitch, dataKey: String, dataKeyIndex: Int) {
        self.getInitialValue(dataKey: dataKey, neededType: .Bool, done: { initialValue in
            if initialValue as? Bool == true {
                elementName.setOn(true, animated: false)
            } else if initialValue as? String == "No current value" {
                elementName.setOn(true, animated: false)
                elementName.tintColor = self.red
                elementName.onTintColor = self.red
            } else {
                elementName.setOn(false, animated: false)
            }
        })
        elementName.tag = dataKeyIndex
        elementName.addTarget(self, action: #selector(switchValueChanged(_:)), for: UIControlEvents.valueChanged)
    }
    
    // Abstracted code to set values of UI elements. Sets background to red if there is no current value.
    func setInitialText(textField: UITextField, initialValue: Any) {
        if initialValue as? String != "No current value"{
            textField.text = String(describing: initialValue)
        } else {
            textField.textColor = white
            textField.backgroundColor = red
            textField.text = String(describing: initialValue)
        }
    }
    
    func setSelectedSegment(segControl: UISegmentedControl, initialValue: String) {
        if initialValue != "No current value"{
            for i in 0..<segControl.numberOfSegments {
                let rawSegmentTitle: String! = segControl.titleForSegment(at: i)
                if rawSegmentTitle! == (initialValue) {
                    segControl.selectedSegmentIndex = i
                    return
                }
            }
        } else {
            segControl.tintColor = red
            segControl.layer.cornerRadius = 5
        }
    }
    
    // Setting up viewImageButton
    @objc func didNormalTapViewImage(_ sender: UIGestureRecognizer) {
        self.deleteImagePhotoBrowser = false
        setUpPhotoBrowser()
    }
    
    //Setting up deleteImageButton
    @objc func didNormalTapDeleteImage(_ sender: UIGestureRecognizer) {
        self.deleteImagePhotoBrowser = true
        setUpPhotoBrowser()
    }
    
    @objc func textFieldValueChanged(_ textField: UITextField) {
        let dataKeyArray: [String: NeededType] = dataKeys[textField.tag]
        var dataKey: String!
        var neededType: NeededType!
        for (key, value) in dataKeyArray{
            dataKey = key
            neededType = value
        }
        var userInput = textField.text!
        if userInput == "" {
            userInput = "0"
        }
        
        switch neededType {
            
        case .Int:
            self.ourTeam.child(dataKey).setValue(Int(userInput)!)
        case .Float:
            self.ourTeam.child(dataKey).setValue(Float(userInput)!)
        case .Bool:
           self.ourTeam.child(dataKey).setValue(Bool(userInput)!)
        case .String:
            self.ourTeam.child(dataKey).setValue(userInput)
        case .none:
            print("This should never happen. Switch has case .none")
        case .some(_):
            print("This should never happen. Switch has case .some")
        }
    }
    
    @objc func segmentedControlValueChanged(_ segmentedControl: UISegmentedControl) {
        let dataKeyArray: [String: NeededType] = dataKeys[segmentedControl.tag]
        var dataKey: String!
        for (key, _) in dataKeyArray{
            dataKey = key
        }
        let userInput: String = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)!
        self.ourTeam.child(dataKey).setValue(userInput)
    }
    
    @objc func switchValueChanged(_ switchElement: UISwitch) {
        let dataKeyArray: [String: NeededType] = dataKeys[switchElement.tag]
        var dataKey: String!
        for (key, _) in dataKeyArray{
            dataKey = key
        }
        var userInput: Bool
        if switchElement.isOn{
            userInput = true
        } else {
            userInput = false
        }
        self.ourTeam.child(dataKey).setValue(userInput)
    }
    
    //THIS CODE NEEDS TO BE ABSTRACTED
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Miscellaneous Notes: climber notes, possible autos, etc" {
            textView.text = ""
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == SEALsNotesTextView {
            self.ourTeam.child("pitSEALsNotes").setValue(textView.text)
        }
    }
    
    //MARK: Photo Browser
    
    /**
     This function makes a new photo browser for viewing photos.
     */
    // Formatting a new photo browser for viewing photos
    func makeNewBrowser (done: @escaping(_ browser: MWPhotoBrowser) -> ()) {
        var browser = MWPhotoBrowser()
        browser = MWPhotoBrowser.init(delegate: self)
        
        // browser options
        browser.displayActionButton = false; // Show action button to allow sharing, copying, etc (defaults to YES)
        browser.displayNavArrows = true; // Whether to display left and right nav arrows on toolbar (defaults to NO)
        browser.displaySelectionButtons = true; // Whether selection buttons are shown on each image (defaults to NO)
        browser.enableGrid = false; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
        browser.autoPlayOnAppear = false; // Auto-play first video
        done(browser)
    }
    
    /** This function allows access to the camera if button is tapped once
     */
    // Normal single tap to access camera
    @objc func didNormalTapAddImage(_ sender: UIGestureRecognizer) {
        self.notActuallyLeavingViewController = true
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
    //Setting up photo browser
    func setUpPhotoBrowser() {
        self.makeNewBrowser(done: { browser in
            let imageURLs = self.ourTeam.child("pitImageKeys")
            imageURLs.observeSingleEvent(of: .value, with: { (snap) -> Void in
                if snap.childrenCount == 0 {
                    // If no photos in firebase for team
                    let noImageAlert = UIAlertController(title: "No Images", message: "No photos have been taken for this team.", preferredStyle: UIAlertControllerStyle.alert)
                    noImageAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    self.present(noImageAlert, animated: true, completion: nil)
                } else {
                    self.notActuallyLeavingViewController = true
                    // Displaying photos in photo browser
                    self.updateMyPhotos { [unowned self] in
                        let nav = UINavigationController(rootViewController: browser)
                        nav.delegate = self
                        self.present(nav, animated: true, completion: {
                            browser.reloadData()
                        })
                    }
                }
            })
        })
    }
    /**
     This function allows access to the photo library if button is long pressed.
     */
    // Long press to access photo library, not camera
    @objc func didLongTap(_ sender: UIGestureRecognizer) {
        notActuallyLeavingViewController = true
        if sender.state == .ended {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        }
    }
    
    /**
     This function displays the photos, pulling from the cache and Firebase.
     */
    func updateMyPhotos(_ callback: @escaping ()->()) {
        ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
            // Pulling images from cache and firebase
            self.photos.removeAll()
            let imageKeysArray = snap.childSnapshot(forPath: "pitImageKeys").value as? NSDictionary
            if imageKeysArray != nil {
                for imageKey in imageKeysArray!.allValues {
                    // Use imageKey to find corresponding image in imageCache
                    self.photoManager.imageCache.fetch(key: String(describing: imageKey)).onSuccess ({ (image) in
                        let captionedImage = MWPhoto(image: image)
                        captionedImage!.caption = "\(String(describing: imageKey))"
                        self.photos.append(captionedImage!)
                    }).onFailure({ Void in
                        // If photo doesn't exist in cache, pull from firebase
                        let imageURLs = snap.childSnapshot(forPath: "pitAllImageURLs").value as? NSDictionary
                        if imageURLs != nil {
                            // Comparing to see if the cached image key matches the firebase URL of one of the image URLs
                            for url in imageURLs!.allValues {
                                let urlArray = (url as! String).replacingOccurrences(of: "https://firebasestorage.googleapis.com/v0/b/scouting-2018-temp.appspot.com/o/", with: "")
                                let componentArray: [String] = urlArray.components(separatedBy: ".png?")
                                let key = componentArray[0]
                                // This is the image key extracted from the image url, which will be modified to follow the format of
                                let modifiedKey = key.replacingOccurrences(of: "%20", with: " ").replacingOccurrences(of: "%2B", with: "+")
                                if modifiedKey == imageKey as! String {
                                    // Adding the firebase image to the local cache
                                    let captionedImage = MWPhoto(url: URL(string: url as! String))
                                    captionedImage!.caption = "\(modifiedKey)"
                                    self.photos.append(captionedImage!)
                                }
                            }
                        }
                    })
                }
            }
        })
        callback()
    }
    
    // This function is a mandatory requirement for the MWPhotoBrowser class. Removing it will cause the code to fail build.
    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(self.photos.count)
    }
    
    /**
     This function sets up the photo browser, and allows photo selection or deletion. Everytime a photo is selected in the photo browser, this function will run.
     */
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt, selectedChanged selected: Bool) {
        if selected {
            if self.deleteImagePhotoBrowser == false {
                // Since deleteImagePhotoBrowser is false, the user must be in the photo browser to view images - they want to set the selected image
                self.dismiss(animated: true, completion: nil)
                ourTeam.child("pitImageKeys").observeSingleEvent(of: .value, with: { (snap) -> Void in
                    let imageKeysDict = snap.value as! NSDictionary
                    for key in imageKeysDict.allValues {
                        //MAY FIX
                        if photoBrowser.photo(at: index).caption?() != nil {
                            if key as! String == photoBrowser.photo(at: index).caption!() {
                                self.selectedImageName.set(key as! String)
                                self.ourTeam.child("pitSelectedImage").setValue(key as! String)
                            }
                        }
                    }
                })
            } else {
                self.dismiss(animated: true, completion: nil)
                // Deleting images from firebase database, but not from firebase storage
                ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    let imageKeysDict = snap.childSnapshot(forPath: "pitImageKeys").value as! NSDictionary
                    let caption = photoBrowser.photo(at: index).caption!()
                    for (key, date) in imageKeysDict {
                        if date as? String == caption {
                            // Removing photo from image cache
                            self.photoManager.imageCache.remove(key: date as! String)
                            self.ourTeam.child("pitImageKeys").child(key as! String).removeValue()
                            let currentSelectedImageName = snap.childSnapshot(forPath: "pitSelectedImage").value as? String
                            // If deleted image is also selected image, delete key value on firebase
                            if currentSelectedImageName == date as? String {
                                self.ourTeam.child("pitSelectedImage").removeValue()
                            }
                            // Deletes image URL from pitAllImageURLs
                            let imageURLDictionary = snap.childSnapshot(forPath: "pitAllImageURLs").value as? [String: String]
                            if imageURLDictionary != nil {
                                for (key, url) in imageURLDictionary! {
                                    let modifiedURL: String = url.replacingOccurrences(of: "%20", with: " ").replacingOccurrences(of: "%2B", with: "+")
                                    if modifiedURL.contains(caption!) {
                                        self.ourTeam.child("pitAllImageURLs").child(key).removeValue()
                                    }
                                }
                            }
                            self.teamsList.fetch(key: "teams").onSuccess({ (keysData) in
                                // Deleting from the keys cache
                                self.photoManager.backgroundQueue.async {
                                    var keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as! NSArray as! [String]
                                    //If there's anything in the cache, check to see if the image key exists. If it does, remove the image key from the cache
                                    if keysArray.count != 0{
                                        for i in 0..<keysArray.count-1 {
                                            if keysArray[i] == caption {
                                                keysArray.remove(at: i)
                                            }
                                        }
                                    }
                                let keysData = NSKeyedArchiver.archivedData(withRootObject: keysArray)
                                self.teamsList.set(value: keysData, key: "teams")
                                }
                            })
                        }
                    }
                })
            }
        }
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        return self.photos[Int(index)]
    }
    
    
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        notActuallyLeavingViewController = true
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
    
    func textViewShouldReturn(_ textView: UITextView) -> Bool { // So that the scroll view can scroll so you can see the text view you are editing
        textView.resignFirstResponder()
        return true
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) {
        activeView = textView
        didEnterTextView = true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) {
        didLeaveTextView = true
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if didEnterTextView == true {
            if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0{
                    self.view.frame.origin.y -= (keyboardSize.height * 1.1)
                        didEnterTextView = false
                    }
                }
            }
        }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if didLeaveTextView == true {
            if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y != 0 {
                    self.view.frame.origin.y = 0
                        didLeaveTextView = false
                    }
                }
            }
        }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*func isNull(_ object: AnyObject?) -> Bool {
        if object_getClass(object) == object_getClass(NSNull()) {
            return true
        }
        return false
    }*/
    
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
    
    override func viewWillDisappear(_ animated: Bool) {
        /*
        //If you are leaving the view controller, and only have one image, make that the selected one.
        super.viewWillDisappear(animated)
        self.photoManager.getSharedURLsForTeam(self.number) { (urls) -> () in
            if urls?.count == 1 {
                self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
                    let imageKeys = snap.childSnapshot(forPath: "imageKeys").value as! NSDictionary
                    for value in imageKeys.allValues {
                        var modifiedURL = urls![0] as! String
                        modifiedURL = modifiedURL.replacingOccurrences(of: "%20", with: " ").replacingOccurrences(of: "%2B", with: "+")
                        if modifiedURL.contains(value as! String) {
                            self.selectedImageName.set(value as AnyObject)
                        }
                    }
                })
            }
        } */
        
        self.ourTeam.observeSingleEvent(of: .value, with: { (snap) -> Void in
            // If cheescake not selected, automatically make it false
            if snap.childSnapshot(forPath: "pitCanCheesecake").value as? Bool == nil {
                self.ourTeam.child("pitCanCheesecake").setValue(false)
            }
            // If selected image doesn't exist, make the first image taken the selected image
            let imageKeys = snap.childSnapshot(forPath: "imageKeys").value as? [String]
            if imageKeys != nil {
                if imageKeys!.count == 1 {
                    self.ourTeam.child("pitSelectedImage").setValue(imageKeys![0])
                }
            }
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "timerSegue" {
            if let dest = segue.destination as? TimerViewController {
                dest.ourTeam = self.ourTeam
                dest.timerArray = self.timerArray
            }
        }
    }
    
    @objc func dismissKeyboard() {
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
