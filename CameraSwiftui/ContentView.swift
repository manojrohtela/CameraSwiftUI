import SwiftUI
import AVFoundation
import PhotosUI

struct ContentView: View {
    var body: some View {
        CameraView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct CameraView: View {
    @State private var isRecording = false
    @State private var isTakingPhoto = false
    @State private var session: AVCaptureSession?
    @State private var latestVideoThumbnail: UIImage? // To store the latest video thumbnail
    private var videoRecorder = VideoRecorder()
    private var photoCapture = PhotoCapture()
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showImagePicker:Bool = false
    
    
    
    var body: some View {
        ZStack {
            // Display camera preview layer
            CameraViewController(session: $session)

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        isRecording = false
                        videoRecorder.stopRecording()
                        isTakingPhoto = true
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 30)

                    Button(action: {
                        isTakingPhoto = false
                        isRecording.toggle()
                        if isRecording {
                            videoRecorder.checkPermissionsAndStartRecording()
                        } else {
                            videoRecorder.stopRecording()
                        }
                    }) {
                        
                        Image(systemName: isRecording ? "stop.circle" : "circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 30)

                    PhotosPicker(selection: $avatarItem) {
                        if let latestVideoThumbnail = latestVideoThumbnail {
                                                    Image(uiImage: latestVideoThumbnail)
                                                        .resizable()
                                                        .frame(width: 80, height: 80)
                                                        .cornerRadius(10)
                                                } else {
                                                    Image(systemName: "photo.fill.on.rectangle.fill")
                                                        .font(.system(size: 80))
                                                        .foregroundColor(.green)
                                                }
                      
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            setUpCamera()
            getLatestThumbnail()
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: isTakingPhoto) { newValue in
            if newValue {
                photoCapture.takePhoto()
            }
        }
        .onChange(of: avatarItem) { _ in
                    Task {
                        if let data = try? await avatarItem?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                avatarImage = Image(uiImage: uiImage)
                                return
                            }
                        }

                        print("Failed")
                    }
                }
        .sheet(isPresented: $showImagePicker) {
            VStack {
                        //PhotosPicker("Select avatar", selection: $avatarItem, matching: .videos)

                        if let avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 300)

                        }
                    }
        }
    }
    
    private func getLatestThumbnail() {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)

            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            if let latestVideo = fetchResult.firstObject {
                let requestOptions = PHImageRequestOptions()
                requestOptions.isSynchronous = true
                requestOptions.deliveryMode = .opportunistic
                PHImageManager.default().requestImage(for: latestVideo, targetSize: CGSize(width: 80, height: 80), contentMode: .aspectFill, options: requestOptions) { image, _ in
                    DispatchQueue.main.async {
                        latestVideoThumbnail = image
                    }
                }
            }
        }
    
    
    

    private func setUpCamera() {
        let session = AVCaptureSession()
        self.session = session

        DispatchQueue.global(qos: .userInitiated).async {
            guard let device = AVCaptureDevice.default(for: .video) else {
                print("Failed to access video device.")
                return
            }
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                print("Failed to access audio device.")
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: device)
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)

                session.beginConfiguration()

                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }

                if session.canAddOutput(videoRecorder.videoOutput) {
                    session.addOutput(videoRecorder.videoOutput)
                }
                if session.canAddOutput(videoRecorder.audioOutput) {
                    session.addOutput(videoRecorder.audioOutput)
                }

                if session.canAddOutput(photoCapture.photoOutput) {
                    session.addOutput(photoCapture.photoOutput)
                }

                session.commitConfiguration()

                session.sessionPreset = .high // Set session preset to high quality

                DispatchQueue.main.async {
                    session.startRunning()
                }
            } catch {
                print("Error setting up camera: \(error.localizedDescription)")
            }
        }
    }
}

struct CameraViewController: UIViewControllerRepresentable {
    typealias UIViewControllerType = CameraPreviewController

    @Binding var session: AVCaptureSession?

    func makeUIViewController(context: Context) -> CameraPreviewController {
        let controller = CameraPreviewController()
        controller.session = session
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPreviewController, context: Context) {
        uiViewController.session = session
    }
}

class CameraPreviewController: UIViewController {
    var session: AVCaptureSession? {
        didSet {
            if let session = session {
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black // Set background color to black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = view.bounds
        }
    }
}

class VideoRecorder: NSObject {
    internal var videoOutput: AVCaptureMovieFileOutput // Change 'private' to 'internal'
    internal var audioOutput: AVCaptureAudioDataOutput // Change 'private' to 'internal'
    private var outputFileURL: URL?

    override init() {
         videoOutput = AVCaptureMovieFileOutput()
         audioOutput = AVCaptureAudioDataOutput()
     }

     func checkPermissionsAndStartRecording() {
         switch AVCaptureDevice.authorizationStatus(for: .video) {
         case .authorized, .notDetermined:
             AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                 switch AVCaptureDevice.authorizationStatus(for: .audio) {
                 case .authorized, .notDetermined:
                     AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                         if videoGranted, audioGranted {
                             DispatchQueue.main.async {
                                 self.startRecording()
                             }
                         } else {
                             print("Video or audio recording permission denied.")
                         }
                     }
                 default:
                     print("Audio recording permission denied.")
                 }
             }
         default:
             print("Video recording permission denied.")
         }
     }

     func startRecording() {
         guard let connection = videoOutput.connection(with: .video) else {
             print("Cannot access video connection.")
             return
         }
         guard connection.isVideoOrientationSupported else {
             print("Video orientation is not supported.")
             return
         }

         connection.videoOrientation = .portrait

         let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("video").appendingPathExtension("mov")
         videoOutput.startRecording(to: videoURL, recordingDelegate: self)
         outputFileURL = videoURL
     }

     func stopRecording() {
         videoOutput.stopRecording()
     }
 }

 extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
     func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
         print("Started Recording")
     }

     func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
         if let error = error {
             print("Video recording error: \(error.localizedDescription)")
         } else {
             PHPhotoLibrary.shared().performChanges({
                 PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
             }) { success, error in
                 if success {
                     print("Video saved to gallery.")
                 } else if let error = error {
                     print("Error saving video to gallery: \(error.localizedDescription)")
                 }
             }
         }
     }
 }

class PhotoCapture: NSObject {
    internal var photoOutput: AVCapturePhotoOutput // Change 'private' to 'internal'
    private var photoSettings: AVCapturePhotoSettings?

    override init() {
        photoOutput = AVCapturePhotoOutput()
    }

    func takePhoto() {
        guard let connection = photoOutput.connection(with: .video) else {
            print("Cannot access video connection.")
            return
        }
        guard connection.isVideoOrientationSupported else {
            print("Video orientation is not supported.")
            return
        }

        connection.videoOrientation = .portrait

        let photoSettings = AVCapturePhotoSettings()
        self.photoSettings = photoSettings

        DispatchQueue.main.async {
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

extension PhotoCapture: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
        } else {
            guard let imageData = photo.fileDataRepresentation() else {
                print("Failed to convert photo to data.")
                return
            }

            // Save the captured photo to the photo library
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }) { success, error in
                if success {
                    print("Photo saved to gallery.")
                } else if let error = error {
                    print("Error saving photo to gallery: \(error.localizedDescription)")
                }
            }
        }
    }
}
