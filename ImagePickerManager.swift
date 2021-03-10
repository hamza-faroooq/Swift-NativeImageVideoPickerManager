import UIKit
import Photos
import MobileCoreServices

// MARK: - This class is used to make native image and video picker in a single use -

protocol imagePickerSelectedProtocol {
    
    func imagePickerSelectedFunction(selectedImage: UIImage?)
    
}

protocol videoPickerSelectedProtocol {
    
    func videoPickerSelectedFunction(selectedVideo: NSURL?)
    
}

class ImagePickerManager: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    static let sharedInstance = ImagePickerManager()
    
    var presentingController = UIViewController()
    var imagePickerSelectedDelegate: imagePickerSelectedProtocol?
    var videoPickerSelectedDelegate: videoPickerSelectedProtocol?
    
    var cameraImage: Bool = false
    var cameraVideo: Bool = false
    var galleryVideo: Bool = false
    
    class func callGenericImagePickerActionSheet(presentingController: UIViewController, title: String, message: String, buttonTitlesArray: [String], isVideo: Bool = false) {
        
        self.sharedInstance.presentingController = presentingController
        
        ActionSheetManager.actionSheetDynamic(title: title, message: message, buttonTitlesArray: buttonTitlesArray, successCallBack: { (callBackText) in
            
            self.sharedInstance.cameraImage = false
            self.sharedInstance.cameraVideo = false
            self.sharedInstance.galleryVideo = false
            
            if callBackText == buttonTitlesArray.first { // make this for camera always
                
                if isVideo {
                    
                    self.sharedInstance.cameraVideo = true
                    
                } else {
                    
                    self.sharedInstance.cameraImage = true
                    
                }
                
            } else {
                
                if isVideo {
                    
                    self.sharedInstance.galleryVideo = true
                    
                }
                
            }
            
            self.genericPickerMethod()
            
        }) {
            
            print("nothing")
            
        }
        
    }
    
    private class func genericPickerMethod() {

        let photos = PHPhotoLibrary.authorizationStatus()

        if photos == .notDetermined || photos == .authorized {

            PHPhotoLibrary.requestAuthorization({ status in

                if status == .authorized {

                    print("access granted")

                    DispatchQueue.main.async {

                        let imagePicker = UIImagePickerController()
                        imagePicker.delegate = sharedInstance.self
                        imagePicker.allowsEditing = true

                        if self.sharedInstance.cameraImage || self.sharedInstance.cameraVideo {

                            imagePicker.sourceType = .camera

                        }

                        if self.sharedInstance.galleryVideo || self.sharedInstance.cameraVideo {

                            imagePicker.videoMaximumDuration = 30.0
                            imagePicker.mediaTypes = [(kUTTypeMovie as String)]

                        }

                        sharedInstance.presentingController.present(imagePicker, animated: true, completion: nil)

                    }

                } else {

                    print("access denied")

                }

            })

        } else {

            AlertManager.customAlertView(messageString: "App is not able to access Photos, give permission to continue")

        }

    }

    func compressVideo(inputURL: URL, outputURL: URL, handler: @escaping (_ exportSession: AVAssetExportSession?) -> Void) {

        let urlAsset = AVURLAsset(url: inputURL, options: nil)

        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetMediumQuality) else {

            handler(nil)
            return

        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously { () -> Void in
            handler(exportSession)
        }

    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        print(info)
        
        if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {

            print(videoURL)

            let compressedURL = NSURL.fileURL(withPath: NSTemporaryDirectory() + NSUUID().uuidString + ".mp4")

            print(compressedURL)

            self.compressVideo(inputURL: videoURL as URL, outputURL: compressedURL) { (exportSession) in

                guard let session = exportSession else {
                    return
                }

                switch session.status {

                case .unknown:

                    print("Unknown Stage")
                    break

                case .waiting:

                    print("Working On file")
                    break

                case .exporting:

                    print("File is exporting")
                    break

                case .completed:

                    guard let compressedData = NSData(contentsOf: compressedURL) else {
                        return
                    }

                    let imageSize = Double(compressedData.length / 1048576)

                    print("File size after compression: \(imageSize) mb")
                    
                    if imageSize > 10 {

                        AlertManager.customAlertView(messageString: "Video should be less than 10MB")

                    } else {

                        DispatchQueue.main.async {

                            print(compressedURL)

                            let videoURL = compressedURL as NSURL

                            ImagePickerManager.sharedInstance.presentingController.dismiss(animated: true, completion: nil)
                                      
                            self.videoPickerSelectedDelegate?.videoPickerSelectedFunction(selectedVideo: videoURL)
                            
                        }

                    }

                case .failed:

                    print("Failed to compress Url")
                    break

                case .cancelled:

                    print("Cancelled  compress Url")
                    break

                @unknown default:
                    fatalError()
                }

            }

        } else {
        
            var selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
                    
            if selectedImage == nil {
            
                selectedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
                        
            }
            
            ImagePickerManager.sharedInstance.presentingController.dismiss(animated: true, completion: nil)
                      
            imagePickerSelectedDelegate?.imagePickerSelectedFunction(selectedImage: selectedImage)
        
        }
        
    }
    
}
