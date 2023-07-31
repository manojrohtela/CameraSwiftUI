import SwiftUI
import AVFoundation
import Photos
import PhotosUI

enum MediaType {
    case camera, video
}

enum FlashStates {
    case auto
    case on
    case off
}

struct ContentView: View {
    @State private var isCameraOpen: Bool = false
    @State var mediaType: MediaType = .camera
    var body: some View {
        VStack{
            Menu {
                Button {
                    mediaType = .camera
                    isCameraOpen.toggle()
                    
                } label: {
                    Image(systemName: "camera")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    mediaType = .video
                    isCameraOpen.toggle()
                }) {
                    Image(systemName: "video")
                        .foregroundColor(.red)
                }

            } label: {
                Text("Add Image")
            }

        }
        .sheet(isPresented: $isCameraOpen) {
            RecordingView(mediaType: $mediaType)
        }
    }
}

struct RecordingView: View {
    
    @Binding var mediaType: MediaType
    
    @State private var isRecording = false
    @State private var isTakingPhoto = false
    @State private var session: AVCaptureSession?
    @State private var latestVideoThumbnail: UIImage? // To store the latest video thumbnail
    var videoRecorder = VideoRecorder()
    var photoCapture = PhotoCapture()
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showImagePicker:Bool = false
    @State private var isFlashOn:Bool = false
    @State private var isFlashMenuOpen = false
    @State private var flashCurrentState:FlashStates = .auto
    @State private var currentCameraPosition: AVCaptureDevice.Position = .back
    
    
    var body: some View {
        ZStack {
            // Display camera preview layer
            CameraViewController(session: $session)
            VStack {
                Spacer()
                HStack {
                    if mediaType == .camera {
                        Button {
                            isRecording = false
                            videoRecorder.stopRecording()
                            isTakingPhoto.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 62, height: 62)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 50, height: 50)
                            }
                        }
                    }else{
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
                    }
                    
                    Button {
                        switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40))
                    }
                    .padding(.horizontal, 30)
                    
                    VStack {
                        // Your camera view or other content here

                        // Button to show/hide the flash menu
                        Button(action: {
                            withAnimation {
                                isFlashMenuOpen.toggle()
                            }
                        }) {
                            switch flashCurrentState {
                            case .auto:
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            case .on:
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                            case .off:
                                Image(systemName: "bolt.slash.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }                    }
                    .flashMenu(isVisible: $isFlashMenuOpen,selectedOption: $flashCurrentState)
                    .padding(20)
                    .onChange(of: flashCurrentState) { _ in
                        flashModeToggle()
                    }
                    
                    PhotoPickerView(photoPickerItem: $avatarItem) {
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
                   // .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                setUpCamera()
            }
            
            getLatestThumbnail()
            videoRecorder.closureVideoSave = { _ in
                getLatestThumbnail()
            }
            photoCapture.closurePhotoSave = { _ in
                getLatestThumbnail()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: isTakingPhoto) { newValue in
            if newValue {
                photoCapture.takePhoto(flashMode: flashCurrentState)
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
        .onChange(of: isFlashOn, perform: { newValue in
            flashModeToggle()
        })
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
        if mediaType == .camera {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }else{
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        }
            

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
    
    
    private func flashModeToggle(){
        settingDevice()
        session?.commitConfiguration()
    }
        
    
    private func settingDevice(){
        if let sessionTemp = session?.inputs{
            for input in sessionTemp {
                session?.removeInput(input)
            }
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        guard let device = discoverySession.devices.first(where: { $0.position == currentCameraPosition }) else {
            print("Failed to access the specified camera.")
            return
        }
        
        
        
        if device.hasTorch && device.isTorchModeSupported(.on) {
            do {
                try device.lockForConfiguration()
            switch flashCurrentState {
            case .auto:
                device.torchMode = .auto
            case .on:
                device.torchMode = .on
            case .off:
                device.torchMode = .off
            }
            device.unlockForConfiguration()
                
            }catch{
                
            }
                
            }
        
        
        
        
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Failed to access audio device.")
            return
        }
      
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)

            session?.beginConfiguration()

            if ((session?.canAddInput(videoInput)) != nil) {
                session?.addInput(videoInput)
            }
            if ((session?.canAddInput(audioInput)) != nil) {
                session?.addInput(audioInput)
            }
        } catch {
            print("werrr")
        }
        
        
        
    }
    
    
    private func switchCamera() {
            // Determine the current camera position
            let cameraPosition = session?.inputs.first { input in
                if let input = input as? AVCaptureDeviceInput {
                    return input.device.position == .back || input.device.position == .front
                }
                return false
            } as? AVCaptureDeviceInput

            // Get the opposite camera position
        currentCameraPosition = (cameraPosition?.device.position == .back) ? .front : .back
        settingDevice()
        session?.commitConfiguration()
        }
    
    

    
    func stopSession() {
        if ((session?.isRunning) != nil) {
            DispatchQueue.global().async {
                self.session?.stopRunning()
            }
        }
    }

    private func setUpCamera() {
        let session = AVCaptureSession()
        self.session = session

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                settingDevice()
                if session.canAddOutput(videoRecorder.videoOutput) {
                    session.addOutput(videoRecorder.videoOutput)
                }
                if session.canAddOutput(videoRecorder.audioOutput) {
                    session.addOutput(videoRecorder.audioOutput)
                }

                if session.canAddOutput(photoCapture.photoOutput) {
                    session.addOutput(photoCapture.photoOutput)
                }
                session.sessionPreset = .high // Set session preset to high quality

                DispatchQueue.global().async {
                    session.startRunning()
                }
                session.commitConfiguration()
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
                //self.view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Set background color to black
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
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

    var closureVideoSave:((Bool)->())?
    
    
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
                     if let closureVideoSave = self.closureVideoSave{
                         closureVideoSave(true)
                     }
                     print("Video saved to gallery.")
                 } else if let error = error {
                     if let closureVideoSave = self.closureVideoSave{
                         closureVideoSave(false)
                     }
                     print("Error saving video to gallery: \(error.localizedDescription)")
                 }
             }
         }
     }
 }

class PhotoCapture: NSObject {
    internal var photoOutput: AVCapturePhotoOutput // Change 'private' to 'internal'
    private var photoSettings: AVCapturePhotoSettings?
    var closurePhotoSave:((Bool)->())?

    override init() {
        photoOutput = AVCapturePhotoOutput()
    }

    func takePhoto(flashMode:FlashStates = .auto) {
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
        switch flashMode {
        case .auto:
            photoSettings.flashMode = .auto
        case .on:
            photoSettings.flashMode = .on
        case .off:
            photoSettings.flashMode = .off
        }

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
                    if let closurePhotoSave = self.closurePhotoSave{
                        closurePhotoSave(true)
                    }
                    print("Photo saved to gallery.")
                } else if let error = error {
                    if let closurePhotoSave = self.closurePhotoSave{
                        closurePhotoSave(false)
                    }
                    print("Error saving photo to gallery: \(error.localizedDescription)")
                }
            }
        }
    }
}


struct FlashMenuModifier: ViewModifier {
    @Binding var isVisible: Bool
    @Binding var selectedOption: FlashStates

    func body(content: Content) -> some View {
        ZStack {
            content

            if isVisible {
                VStack(spacing: 10) {
                    Button("Auto") {
                        // Handle the flash mode change to Auto
                        withAnimation {
                            selectedOption = .auto
                            isVisible.toggle()
                        }
                    }
                    Button("On") {
                        // Handle the flash mode change to On
                        withAnimation {
                            selectedOption = .on
                            isVisible.toggle()
                        }
                    }
                    Button("Off") {
                        // Handle the flash mode change to Off
                        withAnimation {
                            selectedOption = .off
                            isVisible.toggle()
                        }
                    }
                }
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 5)
                .transition(.scale) // Apply scale animation to menu expansion
            }
        }
    }
}

extension View {
    func flashMenu(isVisible: Binding<Bool>,selectedOption: Binding<FlashStates>) -> some View {
        self.modifier(FlashMenuModifier(isVisible: isVisible, selectedOption: selectedOption))
    }
}


struct PhotoPickerView: View {
    @Binding var photoPickerItem: PhotosPickerItem
    let completion: () -> ()
    var body: some View {
        PhotosPicker(selection: $photoPickerItem, matching: mediaType == .camera ? .images : .videos) {
            completion()
        }
    }
}
