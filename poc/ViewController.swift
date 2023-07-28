//
//  ViewController.swift
//  poc
//
//  Created by Wama on 18/07/23.
//

import UIKit
import WebKit
import Speech
import AVFoundation

class ViewController: UIViewController {
    
    //-----------------
    //MARK: - IBOutlets
    //-----------------
    @IBOutlet private var wkWebViewAI: WKWebView!
    @IBOutlet private var webViewContainerView: UIView!
    @IBOutlet private weak var btnStartSpeech: UIButton!
    @IBOutlet private weak var viewActivityLoader: UIActivityIndicatorView!
    //-----------------
    //MARK: - Variables
    //-----------------
    private var isRecording = false
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-IN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var recordedMessage: String?
    
    //---------------------------------
    //MARK: - View's life cycle methods
    //---------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        DispatchQueue.main.async {
            self.loadInitialConfig()
            self.activityIndicatorSetup()
        }
    }
    
    //----------------------
    //MARK: - WKWebview Configuration and Load the App
    //----------------------
    private func loadInitialConfig() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.suppressesIncrementalRendering = true
        
        // Apply this configurations to the WKWebview
        self.wkWebViewAI = WKWebView(frame: .zero, configuration: configuration)
        wkWebViewAI.navigationDelegate = self
        
        // Add the Webview to container view and set its frame
        if let webView = wkWebViewAI {
            webViewContainerView.addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: webViewContainerView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: webViewContainerView.trailingAnchor),
                webView.topAnchor.constraint(equalTo: webViewContainerView.topAnchor),
                webView.bottomAnchor.constraint(equalTo: webViewContainerView.bottomAnchor)
            ])
        }

        // Finally load the WebApp request in WKWebview
        loadWebView()
    }
    
    private func activityIndicatorSetup() {
        viewActivityLoader.style = UIActivityIndicatorView.Style.large
        viewActivityLoader.color = UIColor.black
        viewActivityLoader.startAnimating()
        view.isUserInteractionEnabled = false
        btnStartSpeech.isHidden = true
    }
    
    private func loadWebView() {
        _print("Loading WebViewURL: \(webURL)")
        if let link = URL(string: webURL) {
            wkWebViewAI.load(URLRequest(url: link))
        }
    }
    
    //MARK: Check Permission
    private func getUserConsent() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.btnStartSpeech.isEnabled = true
                    self.btnStartSpeech.isHidden = false
                case .denied, .restricted, .notDetermined:
                    self.btnStartSpeech.isEnabled = false
                    self.btnStartSpeech.isHidden = true
                @unknown default:
                    return
                }
            }
        }
    }
    
    /// Alert for display error
    private func sendAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    /// Start recording audio
    func startListening() {

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            self.sendAlert(title: "Speech Recognizer Error", message: "Speech recognition request failed to init.")
            _print("Speech recognition request failed to init")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                self.recordedMessage = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
                _print("****** Sppeched whole string ******")
                _print(self.recordedMessage ?? "")
            }
            
            if error != nil || isFinal {
                //self.stopListening()
                _print(error ?? "Getting some error")
            }
        })
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            ///Must include .playAndRecord options with .mixWithOthers to solve the AI freezing issue
            try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers])
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.sendAlert(title: "Audio Session Error", message: "Audio session isn't configured correctly.")
            _print("Audio session isn't configured correctly")
        }
        
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, time) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            self.sendAlert(title: "Speech Recognizer Error", message: "There has been an audio engine error.")
            _print("Audio engine failed to start")
        }
    }
    
    /// Stop recording audio
    private func stopRecordAndRecognizeSpeech() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    //------------------------
    //MARK: - IBAction methods
    //------------------------
    @IBAction private func btnStartSpeechAction(_ sender: UIButton) {
        if isRecording == true {
            stopRecordAndRecognizeSpeech()
            isRecording = false
            DispatchQueue.main.async {
                sender.backgroundColor = UIColor.black
                sender.setTitle("START RECORDING", for: .normal)
            }
            self.passRecordedStringToWebApp(recordedStr: self.recordedMessage ?? "")
        } else {
            startListening()
            isRecording = true
            sender.backgroundColor = UIColor.red
            sender.setTitle("STOP RECORDING", for: .normal)
        }
    }
}

//---------------------------------------------------
//MARK: - WKNavigationDelegate & WKUIDelegate methods
//---------------------------------------------------
extension ViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        _print("Start loading")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        _print("Complete loading")

        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
            self.viewActivityLoader.stopAnimating()
            self.view.isUserInteractionEnabled = true
            self.getUserConsent()
        })
    }
}

//--------------------------------------
//MARK: - Pass speech words to WKWebView
//--------------------------------------
extension ViewController {
    //MARK: Pass the Recorded String to WKWebView app
    fileprivate func passRecordedStringToWebApp(recordedStr: String) {
        let jsonString = """
        {
            "type": "MESSAGE",
            "payload": "\(recordedStr)"
        }
        """
        
        let javascriptString = "window.postMessage(\(jsonString))"
        _print("javascriptString: \(javascriptString)")
        
        wkWebViewAI.evaluateJavaScript(javascriptString) { (result, error) in
            if let error = error {
                _print("Failed to send message to web app: \(error)")
            }
        }
    }
}
