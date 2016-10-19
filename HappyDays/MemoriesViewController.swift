//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by Patrick Bellot on 10/11/16.
//  Copyright © 2016 Bell OS, LLC. All rights reserved.
//

import AVFoundation
import Photos
import Speech
import UIKit
import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVAudioRecorderDelegate {
  
  var memories = [URL]()
  var activeMemory: URL!
  var audioRecorder: AVAudioRecorder?
  var recordingURL: URL!
  var audioPlayer: AVAudioPlayer?

  override func viewDidLoad() {
    super.viewDidLoad()
    loadMemories()
    
    recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self,
      action: #selector(addTapped))
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkPermissions()
  }
  
  func addTapped() {
    let vc = UIImagePickerController()
    vc.modalPresentationStyle = .formSheet
    vc.delegate = self
    navigationController?.present(vc, animated: true)
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    dismiss(animated: true)
    
    if let possibleImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
      saveNewMemory(image: possibleImage)
      loadMemories()
    }
  }
  
  func saveNewMemory(image: UIImage) {
    
    // create a unique name for this memory
    let memoryName = "memory- \(Date().timeIntervalSince1970)"
    
    // use the unique name to create filenames for the full-size image and the thumbnail
    let imageName = memoryName + ".jpg"
    let thumbnailName = memoryName + ".thumb"
    
    do {
      // create a URL where we can write the JPEG to
      let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
      
      //convert the UIImage into at JPEG data object
      if let jpegData = UIImageJPEGRepresentation(image, 80) {
        
        // write that data to the URL we created
        try jpegData.write(to: imagePath, options: [.atomicWrite])
      }
      
      // create thumnail here
      if let thumbnail = resize(image: image, to: 200) {
        let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
          if let jpegData = UIImageJPEGRepresentation(thumbnail, 80) {
            try jpegData.write(to: imagePath, options: [.atomicWrite])
        }
      }
    } catch {
      print("Failed to save to disk.")
    }
  }
  
  func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
  }
  
  func loadMemories() {
    memories.removeAll()
    
    // attempt to load all the memories in our documents directory
    guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil,
      options: [])
        else { return }
    
    // loop over every file found
    for file in files {
      let filename = file.lastPathComponent
      
      // check it ends with ".thumb" so we don't count each memory more than once
      if filename.hasSuffix(".thumb") {
        
        //get the root name of the memory (i.e., without its path extension)
        let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
        
        //create a full path from the memory
        let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
        
        // add it to our array
        memories.append(memoryPath)
      }
    }
    
    collectionView?.reloadSections(IndexSet(integer: 1))
  }
  
  func resize(image: UIImage, to width: CGFloat) -> UIImage? {
    
    // calculate how much we need to bring the width down to match our target size
    let scale = width / image.size.width
    
    // bring the height down by the same amount so that the aspect ratio is preserved
    let height = image.size.height * scale
    
    // create a new image context we can draw into
    UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
    
    // draw the original image into the context
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // pull out the resized version
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    
    // end the context so UIKit can clean up
    UIGraphicsEndImageContext()
    
    // send it back to the caller
    return newImage
  }
  
  func checkPermissions() {
    // check status for all three permissions
    let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
    let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission() == .granted
    let transcribedAutorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    
    // make a single boolean out of all three
    let authorized = photosAuthorized && recordingAuthorized && transcribedAutorized
    
    // if we're missing one, show the first run screen
    if authorized == false {
      if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
        navigationController?.present(vc, animated: true)
      }
    }
  }
  
  // MARK: Helper Methods
  
  func imageURL(for memory: URL) -> URL {
    return memory.appendingPathExtension("jpg")
  }
  
  func thumbnailURL(for memory: URL) -> URL {
    return memory.appendingPathExtension("thumb")
  }
  
  func audioURL(for memory: URL) -> URL {
    return memory.appendingPathExtension("m4a")
  }
  
  func transcriptionURL(for memory: URL) -> URL {
    return memory.appendingPathExtension("txt")
  }
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 2
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if section == 0 {
      return 0
    } else {
      return memories.count
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell
    let memory = memories[indexPath.row]
    let imageName = thumbnailURL(for: memory).path
    let image = UIImage(contentsOfFile: imageName)
    cell.imageView.image = image
    
    if cell.gestureRecognizers == nil {
      let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
      recognizer.minimumPressDuration = 0.25
      
      cell.addGestureRecognizer(recognizer)
      cell.layer.borderColor = UIColor.white.cgColor
      cell.layer.borderWidth = 3
      cell.layer.cornerRadius = 10
    }
    
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let memory = memories[indexPath.row]
    let fm = FileManager.default
    
    do {
      let audioName = audioURL(for: memory)
      let transcriptionName = transcriptionURL(for: memory)
      
      if fm.fileExists(atPath: audioName.path) {
        audioPlayer = try AVAudioPlayer(contentsOf: audioName)
        audioPlayer?.play()
      }
      
      if fm.fileExists(atPath: transcriptionName.path) {
        let contents = try String(contentsOf: transcriptionName)
          print(contents)
      }
    } catch {
        print("Error loading audio")
    }
  }
  
  func memoryLongPress(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let cell = sender.view as! MemoryCell
      
        if let index = collectionView?.indexPath(for: cell) {
          activeMemory = memories[index.row]
          recordMemory()
        }
      } else if sender.state == .ended {
          finishRecording(success: true)
      }
  }
  
  func recordMemory() {
    audioPlayer?.stop()
    collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
    
    let recordingSession = AVAudioSession.sharedInstance()
    
    do {
      try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
      try recordingSession.setActive(true)
      
      let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
      
      audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
      audioRecorder?.delegate = self
      audioRecorder?.record()
    } catch let error {
        print("Failed to record: \(error)")
        finishRecording(success: false)
    }
  }
  
  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    if !flag {
      finishRecording(success: false)
    }
  }
  
  func finishRecording(success: Bool) {
    collectionView?.backgroundColor = UIColor.darkGray
    
    audioRecorder?.stop()
    
    if success {
      do {
        let memoryAudioURL = activeMemory.appendingPathComponent("m4a")
        let fm = FileManager.default
        
        if fm.fileExists(atPath: memoryAudioURL.path) {
          try fm.removeItem(at: memoryAudioURL)
        }
        try fm.moveItem(at: recordingURL, to: memoryAudioURL)
        transcribeAudio(memory: activeMemory)
      } catch let error {
          print("Failure finishing recording: \(error)")
      }
    }
  }
  
  func transcribeAudio(memory: URL) {
    
    // get the paths to where the audio is, and where the transcription should be
    let audio = audioURL(for: memory)
    let transcription = transcriptionURL(for: memory)
    
    // create a new recognizer and point it at our audio
    let recognizer = SFSpeechRecognizer()
    let request = SFSpeechURLRecognitionRequest(url: audio)
    
    // start recognition!
    recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
      
      // abort if we didn't get any transcription back
      guard let result = result else {
        print("There was an error: \(error!)")
        return
      }
      
      // if we got the final transcription back, we need to write it to disk
      if result.isFinal {
        
        // pull out the best transcription
        let text = result.bestTranscription.formattedString
        
        // ...and write it to disk at the correct filename for this memory
        do {
          try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
          self.indexMemory(memory: memory, text: text)
        } catch {
          print("Failed to save transcription.")
        }
      }
    }
  }
  
  func indexMemory(memory: URL, text: String) {
    
    //create a basic attribute set
    let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
    attributeSet.title = "Happy Days Memory"
    attributeSet.contentDescription = text
    attributeSet.thumbnailURL = thumbnailURL(for: memory)
    
    // wrap it in a searchable item, using the memory's full path as its unique identifier
    let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "com.hackingwithswift", attributeSet: attributeSet)
    
    // make it never expire
    item.expirationDate = Date.distantFuture
    
    // ask Spotlight to index the item
    CSSearchableIndex.default().indexSearchableItems([item]) { error in
      if let error = error {
        print("Indexing error: \(error.localizedDescription)")
      } else {
        print("Search item successfully indexed: \(text)")
      }
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath) -> UICollectionReusableView {
      return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    referenceSizeForHeaderInSection section: Int) -> CGSize {
      if section == 1 {
        return CGSize.zero
      } else {
        return CGSize(width: 0, height: 50)
      }
  }
  
  
  
  
  
  
  
  
  
  
} // End of class
