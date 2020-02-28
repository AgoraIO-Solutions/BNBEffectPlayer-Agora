
import Foundation
import BanubaEffectPlayer

public protocol VoiceChangeable {
    
    var queue: DispatchQueue { get set }
    var volume: Float { get set }
    
    var isConfigured: Bool { get }
    
    func process(file url: URL, completion: ((Bool, Error?)->Void)?)
    func process(file url: URL) throws
}

public enum VoiceChangerError: Error {
    case cantCreateAssetExportSession
    case exportSessionCantExportAudio
}

class VoiceChanger {

    enum FileType {
        case audio
        case video
        
        var fileType: AVFileType {
            switch self {
            case .audio:
                return .m4a
            case .video:
                return .mp4
            }
        }
        
        var presetName: String {
            switch self {
            case .audio:
                return AVAssetExportPresetAppleM4A
            case .video:
                return AVAssetExportPresetHighestQuality
            }
        }
        
    }
    
    fileprivate struct Defaults {
        
        static let volume: Float = 0.2
        
        static let audioFileName =  "extractedAudio.m4a"
        static let audioFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(audioFileName)
        
        static let processedAudioFileName =  "processedAudio.wav"
        static let processedAudioFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(processedAudioFileName)
        
        static let resultFileName =  "result.mp4"
        static let resultFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(resultFileName)
    }
    
    internal var volume: Float = Defaults.volume
    internal var queue: DispatchQueue
    fileprivate let effectPlayer: BNBEffectPlayer
    
    var isConfigured: Bool {
        return effectPlayer.isVoiceChangerConfigured()
    }
    
    init(effectPlayer: BNBEffectPlayer, queue: DispatchQueue = DispatchQueue.global(qos: .utility)) {
        self.queue = queue
        self.effectPlayer = effectPlayer
    }
    
    private func extractAudio(from asset: AVAsset, to url: URL) throws {
        let composition = AVMutableComposition()
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        for track in audioTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionTrack?.insertTimeRange(track.timeRange, of: track, at: track.timeRange.start)
        }
        try write(asset: composition, to: url, fileType: .audio)
    }
    
    private func write(asset: AVAsset, to url: URL, fileType: FileType) throws {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: fileType.presetName) else {
            throw VoiceChangerError.cantCreateAssetExportSession
        }
        
        exportSession.outputFileType = fileType.fileType
        exportSession.outputURL = url
        
        var success = false
        
        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            success = exportSession.status == .completed
            semaphore.signal()
        }
        semaphore.wait()
        
        guard success else {
            throw VoiceChangerError.exportSessionCantExportAudio
        }
    }
    
    private func merge(audio audioFile: URL, video videoFile: URL, to resultFile: URL) throws {
        let videoAsset = AVAsset(url: videoFile)
        let audioAsset = AVAsset(url: audioFile)
        let composition = AVMutableComposition()
        
        let audioTracks = audioAsset.tracks(withMediaType: .audio)
        for track in audioTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionTrack?.insertTimeRange(track.timeRange, of: track, at: track.timeRange.start)
        }
        
        let videoTracks = videoAsset.tracks(withMediaType: .video)
        for track in videoTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionTrack?.insertTimeRange(track.timeRange, of: track, at: track.timeRange.start)
        }
        
        try write(asset: composition, to: resultFile, fileType: .video)
    }
    
    private func replaceFile(at fileUrl: URL, with otherFileUrl: URL) throws {
       _ = try FileManager.default.replaceItemAt(fileUrl, withItemAt: otherFileUrl)
    }
    
    private func removeTemporaryFiles() {
        removeFiles([Defaults.processedAudioFileUrl, Defaults.audioFileUrl, Defaults.resultFileUrl])
    }
    
    private func removeFiles(_ urls: [URL]) {
        let fileManager = FileManager.default
        for url in urls {
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(atPath: url.path)
            }
        }
    }
    
}

extension VoiceChanger: VoiceChangeable {
    
    func process(file url: URL) throws {
        defer {
            removeTemporaryFiles()
        }
        let asset = AVAsset(url: url)
        try extractAudio(from: asset, to: Defaults.audioFileUrl)
        effectPlayer.processRecordedAudio(
            Defaults.audioFileUrl.path,
            outFilename: Defaults.processedAudioFileUrl.path,
            mixVolume: volume
        )
        try merge(audio: Defaults.processedAudioFileUrl, video: url, to: Defaults.resultFileUrl)
        try replaceFile(at: url, with: Defaults.resultFileUrl)
    }
    
    func process(file url: URL, completion: ((Bool, Error?)->Void)?) {
        queue.async { [weak self] in
            guard let self = self else {
                completion?(false, nil)
                return
            }
            do {
                try self.process(file: url)
                completion?(true, nil)
            } catch {
                completion?(false, error)
            }
        }
    }
    
}
