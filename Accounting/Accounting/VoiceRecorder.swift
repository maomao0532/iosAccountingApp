//
//  VoiceRecorder.swift
//  Accounting
//

import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var authorizationMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                switch status {
                case .authorized:
                    self.authorizationMessage = nil
                case .denied:
                    self.authorizationMessage = "语音识别权限未开启"
                case .restricted:
                    self.authorizationMessage = "当前设备无法使用语音识别"
                case .notDetermined:
                    self.authorizationMessage = "语音识别权限尚未确认"
                @unknown default:
                    self.authorizationMessage = "语音识别状态未知"
                }
            }
        }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.authorizationMessage = "麦克风权限未开启"
                }
            }
        }
    }

    func start() {
        guard !isRecording else { return }
        transcript = ""
        authorizationMessage = nil

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            authorizationMessage = "请先在系统设置中开启语音识别权限"
            requestPermission()
            return
        }

        guard speechRecognizer?.isAvailable == true else {
            authorizationMessage = "当前语音识别服务不可用，请稍后重试或先用手动输入"
            return
        }

        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            authorizationMessage = "无法启动录音：\(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0 else {
            authorizationMessage = "没有检测到可用麦克风。若使用模拟器，请在 Mac 的系统设置和模拟器音频输入中允许麦克风"
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            authorizationMessage = "录音启动失败：\(error.localizedDescription)"
            return
        }

        isRecording = true
        task = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
    }
}
