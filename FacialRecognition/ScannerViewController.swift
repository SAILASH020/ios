import UIKit
import AVFoundation
import Vision

class ScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var mode: ScannerMode = .attendance
    var registerName: String?
    
    private let session = AVCaptureSession()
    private var model: VNCoreMLModel?
    private var isBusy = false
    
    private let status = UILabel()
    private let faceBox = CAShapeLayer()       // Dynamic box (follows face)
    private let staticTarget = CAShapeLayer() // Fixed center box (alignment guide)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupStaticTarget() // ADDED: The "Box" to check face alignment
        setupCamera()
        loadModel()
    }

    private func setupUI() {
        // Status Label with clearer alignment instructions
        status.frame = CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 80)
        status.textAlignment = .center
        status.textColor = .white
        status.numberOfLines = 0
        status.font = .systemFont(ofSize: 20, weight: .bold)
        status.text = "Initializing..."
        view.addSubview(status)
        
        faceBox.strokeColor = UIColor.cyan.cgColor
        faceBox.lineWidth = 2
        faceBox.fillColor = nil
        view.layer.addSublayer(faceBox)
        
        let close = UIButton(frame: CGRect(x: 20, y: 50, width: 40, height: 40))
        close.setTitle("✕", for: .normal); close.addTarget(self, action: #selector(dismissCam), for: .touchUpInside)
        view.addSubview(close)
    }

    private func setupStaticTarget() {
        let size = view.frame.width * 0.75
        let rect = CGRect(x: (view.frame.width - size)/2, y: (view.frame.height - size)/2, width: size, height: size)
        
        staticTarget.path = UIBezierPath(roundedRect: rect, cornerRadius: 20).cgPath
        staticTarget.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        staticTarget.fillColor = nil
        staticTarget.lineWidth = 4
        staticTarget.lineDashPattern = [10, 5] // Dashed line effect
        
        view.layer.addSublayer(staticTarget)
    }

    func captureOutput(_ o: AVCaptureOutput, didOutput b: CMSampleBuffer, from c: AVCaptureConnection) {
        guard !isBusy, let buf = CMSampleBufferGetImageBuffer(b) else { return }
        
        let req = VNDetectFaceLandmarksRequest { [weak self] r, _ in
            guard let self = self, let f = (r.results as? [VNFaceObservation])?.first else {
                DispatchQueue.main.async {
                    self?.faceBox.path = nil
                    self?.status.text = "No Face Detected"
                    self?.staticTarget.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
                }
                return
            }
            
            self.drawFaceBox(f)
            
            // 1. Distance Logic (0.45 is the "Sweet Spot" for FaceNet)
            let isTooFar = f.boundingBox.width < 0.40
            
            // 2. Alignment Logic (Is the face center near screen center?)
            // Vision coordinates are 0 to 1. Center is 0.5.
            let isCenteredX = (0.45...0.55).contains(f.boundingBox.midX)
            let isCenteredY = (0.45...0.55).contains(f.boundingBox.midY)
            let isAligned = isCenteredX && isCenteredY

            DispatchQueue.main.async {
                if isTooFar {
                    self.updateStatus(msg: "Move Closer 🤳", color: .systemYellow)
                } else if !isAligned {
                    self.updateStatus(msg: "Center Your Face in the Box 🔳", color: .systemOrange)
                } else {
                    self.updateStatus(msg: "Perfect! Now Blink 😉", color: .systemGreen)
                    // Only capture when Distance + Alignment + Blink are met
                    if self.isBlink(f) { self.recognize(buf) }
                }
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: buf, orientation: .leftMirrored).perform([req])
    }

    private func updateStatus(msg: String, color: UIColor) {
        self.status.text = msg
        self.staticTarget.strokeColor = color.cgColor
    }

    private func drawFaceBox(_ f: VNFaceObservation) {
        DispatchQueue.main.async {
            let s = self.view.bounds.size; let b = f.boundingBox
            let rect = CGRect(x: (1-b.origin.x-b.width)*s.width, y: (1-b.origin.y-b.height)*s.height, width: b.width*s.width, height: b.height*s.height)
            self.faceBox.path = UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath
        }
    }

    private func isBlink(_ f: VNFaceObservation) -> Bool {
        guard let l = f.landmarks?.leftEye?.normalizedPoints, let r = f.landmarks?.rightEye?.normalizedPoints else { return false }
        let ear = (calcEAR(l) + calcEAR(r)) / 2.0; return ear < 0.20
    }

    private func calcEAR(_ p: [CGPoint]) -> CGFloat {
        // Vertical dist / horizontal dist
        let v1 = hypot(p[1].x - p[5].x, p[1].y - p[5].y)
        let v2 = hypot(p[2].x - p[4].x, p[2].y - p[4].y)
        let h = hypot(p[0].x - p[3].x, p[0].y - p[3].y)
        return (v1 + v2) / (2.0 * h)
    }

    private func recognize(_ b: CVPixelBuffer) {
        guard let m = model else { return }; isBusy = true
        let req = VNCoreMLRequest(model: m) { [weak self] r, _ in
            guard let self = self, let v = (r.results as? [VNCoreMLFeatureValueObservation])?.first?.featureValue.multiArrayValue else { return }
            let vec = (0..<v.count).map { Float(truncating: v[$0]) }
            let match = AttendanceDB.shared.findMatch(newVector: vec)
            
            DispatchQueue.main.async {
                var msg = ""
                if self.mode == .registration {
                    if let x = match { msg = "Already Registered: \(x)" }
                    else { AttendanceDB.shared.registerUser(name: self.registerName!, vector: vec); msg = "Success: \(self.registerName!)" }
                } else {
                    msg = match != nil ? "\(match!)\n\(AttendanceDB.shared.logAttendance(name: match!))" : "Face Not Recognized"
                }
                self.session.stopRunning(); self.showResult(msg)
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: b, orientation: .leftMirrored).perform([req])
    }

    private func showResult(_ m: String) {
        let a = UIAlertController(title: "Result", message: m, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) }); present(a, animated: true)
    }

    private func loadModel() {
        if let m = try? FaceNet(configuration: .init()).model { model = try? VNCoreMLModel(for: m) }
    }

    private func setupCamera() {
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let inp = try? AVCaptureDeviceInput(device: dev) else { return }
        session.addInput(inp); let out = AVCaptureVideoDataOutput()
        out.setSampleBufferDelegate(self, queue: DispatchQueue(label: "v"))
        session.addOutput(out); let pr = AVCaptureVideoPreviewLayer(session: session)
        pr.frame = view.bounds; pr.videoGravity = .resizeAspectFill; view.layer.insertSublayer(pr, at: 0)
        DispatchQueue.global().async { self.session.startRunning() }
    }
    
    @objc func dismissCam() { dismiss(animated: true) }
}
