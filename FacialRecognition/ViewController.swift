import UIKit
import AVFoundation
import Vision
import CoreML

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private var vnModel: VNCoreMLModel?
    private let faceLayer = CAShapeLayer()
    private var isProcessing = false
    private var isRegisterMode = true

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white; l.textAlignment = .center; l.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        l.layer.cornerRadius = 12; l.clipsToBounds = true; l.text = "Loading..."; l.numberOfLines = 0
        return l
    }()

    private let modeBtn: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = .systemBlue; b.setTitle("Mode: Registration", for: .normal)
        b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 15
        return b
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadModel()
        setupCamera()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly // Best for custom converted FaceNet
            let modelWrapper = try FaceNet(configuration: config)
            self.vnModel = try VNCoreMLModel(for: modelWrapper.model)
            statusLabel.text = "Blink to Scan 😉"
            
            
            // Add to setupUI()
            let historyBtn = UIButton(type: .system)
            historyBtn.setTitle("📋 View History", for: .normal)
            historyBtn.frame = CGRect(x: 20, y: 140, width: 120, height: 40)
            historyBtn.backgroundColor = .darkGray
            historyBtn.setTitleColor(.white, for: .normal)
            historyBtn.layer.cornerRadius = 8
            historyBtn.addTarget(self, action: #selector(showHistory), for: .touchUpInside)
            view.addSubview(historyBtn)

            // Add the action
           
            
        } catch { statusLabel.text = "Model Error" }
    }

    
    @objc func showHistory() {
        let nav = UINavigationController(rootViewController: HistoryViewController())
        present(nav, animated: true)
    }
    
    private func setupUI() {
        faceLayer.strokeColor = UIColor.cyan.cgColor; faceLayer.lineWidth = 3; faceLayer.fillColor = UIColor.clear.cgColor
//        view.layer.addSublayer(faceLayer)
        statusLabel.frame = CGRect(x: 20, y: 60, width: view.frame.width - 40, height: 70); view.addSubview(statusLabel)
        modeBtn.frame = CGRect(x: 40, y: view.frame.height - 100, width: view.frame.width - 80, height: 55)
        modeBtn.addTarget(self, action: #selector(toggleMode), for: .touchUpInside); view.addSubview(modeBtn)
    }

    @objc func toggleMode() {
        isRegisterMode.toggle()
        modeBtn.setTitle(isRegisterMode ? "Mode: Registration" : "Mode: Attendance", for: .normal)
        modeBtn.backgroundColor = isRegisterMode ? .systemBlue : .systemGreen
    }

    private func setupCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device) else { return }
                self.session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "vQueue"))
                self.session.addOutput(output)
                let preview = AVCaptureVideoPreviewLayer(session: self.session)
                preview.frame = self.view.bounds; preview.videoGravity = .resizeAspectFill
                self.view.layer.insertSublayer(preview, at: 0)
                DispatchQueue.global().async { self.session.startRunning() }
            }
        }
    }

    func captureOutput(_ o: AVCaptureOutput, didOutput b: CMSampleBuffer, from c: AVCaptureConnection) {
        guard !isProcessing, let buffer = CMSampleBufferGetImageBuffer(b) else { return }
        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self = self, let face = (req.results as? [VNFaceObservation])?.first else {
                DispatchQueue.main.async { self?.faceLayer.path = nil }; return
            }
            self.updateOverlay(face: face)
            if self.isBlinking(face: face) { self.runRecognition(buffer: buffer) }
        }
        try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored).perform([request])
    }

    private func isBlinking(face: VNFaceObservation) -> Bool {
        guard let l = face.landmarks?.leftEye?.normalizedPoints, l.count >= 6,
              let r = face.landmarks?.rightEye?.normalizedPoints, r.count >= 6 else { return false }
        let ear = (calculateEAR(p: l) + calculateEAR(p: r)) / 2.0
        return ear < 0.20 // Adjust threshold if needed
    }

    private func calculateEAR(p: [CGPoint]) -> CGFloat {
        // v1: dist(p1, p5), v2: dist(p2, p4), h: dist(p0, p3)
        let v1 = hypot(p[1].x - p[5].x, p[1].y - p[5].y)
        let v2 = hypot(p[2].x - p[4].x, p[2].y - p[4].y)
        let h = hypot(p[0].x - p[3].x, p[0].y - p[3].y)
        return (v1 + v2) / (2.0 * h)
    }

    private func runRecognition(buffer: CVPixelBuffer) {
        guard let model = vnModel else { return }
        isProcessing = true
        
        let request = VNCoreMLRequest(model: model) { [weak self] req, _ in
            guard let self = self,
                  let results = req.results as? [VNCoreMLFeatureValueObservation],
                  let emb = results.first?.featureValue.multiArrayValue else {
                self?.isProcessing = false; return
            }
            
            let vector = (0..<emb.count).map { Float(truncating: emb[$0]) }
            
            // Step 1: Always check if the face is already registered
            let matchedName = AttendanceDB.shared.findMatch(newVector: vector)
            
            if self.isRegisterMode {
                // REGISTRATION MODE
                if let name = matchedName {
                    // Face already exists!
                    self.showFeedback(msg: "⚠️ Already Registered\nUser: \(name)")
                } else {
                    // New Face -> Proceed to Register
                    DispatchQueue.main.async { self.promptForRegistration(vector: vector) }
                }
            } else {
                // ATTENDANCE MODE
                if let name = matchedName {
                    let status = AttendanceDB.shared.logAttendance(name: name)
                    self.showFeedback(msg: "\(name)\n\(status)")
                } else {
                    self.showFeedback(msg: "Unknown Face ❌\nPlease Register First")
                }
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop
        try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored).perform([request])
    }

    private func promptForRegistration(vector: [Float]) {
        let alert = UIAlertController(title: "Register New User", message: "Face not found. Please enter name.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Full Name" }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                AttendanceDB.shared.registerUser(name: name, vector: vector)
                self.showFeedback(msg: "Registration Successful! ✨\nWelcome \(name)")
            } else {
                self.isProcessing = false
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.isProcessing = false
        })
        
        self.present(alert, animated: true)
    }


    private func updateOverlay(face: VNFaceObservation) {
        DispatchQueue.main.async {
            let b = face.boundingBox; let s = self.view.bounds.size
            let r = CGRect(x: b.origin.x * s.width, y: (1 - b.origin.y - b.height) * s.height, width: b.width * s.width, height: b.height * s.height)
            self.faceLayer.path = UIBezierPath(roundedRect: r, cornerRadius: 12).cgPath
        }
    }

    private func showFeedback(msg: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = msg
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.isProcessing = false }
        }
    }
}
