//
//  ContentView.swift
//  AVPlayer
//
//  Created by 吴坤城 on 1/31/24.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreMedia


struct ContentView: View {
    
    //变量定义
    @State private var players: [AVPlayer] = []
    @State private var selectedPlayerIndex: Int = 0
    @State private var videoAspectRatios: [CGSize] = []
    @State private var videoNames: [String] = []
    @State private var playbackSpeedIndex: Int = 0
    @State private var lastKeyPress: String? = nil
    @State private var playbackMode: PlaybackMode = .sequential
    @State private var showMetadataPanel: Bool = false
    @State private var videoMetadata: [VideoMetadata] = []
    
    // 定义播放速度的数组
    let playbackSpeeds: [Float] = [1, 2, 4, 8, 16, 32, 64]
    
    //枚举播放模式
    enum PlaybackMode: String, CaseIterable {
        case sequential = "顺序播放"
        case loopSingle = "单次循环"
        case single = "单次播放"
        case random = "随机播放"
    }
    
    //元数据变量定义
    struct VideoMetadata {
        var audioCodec: String = ""
        var videoCodec: String = ""
        var videoBitRate: Int = 0
        var videoFrameRate: Float = 0.0
        var audioBitRate: Int = 0
        var fileSize: Int64 = 0
        var audioSampleRate: Double = 0.0
        var videoFormat: String = ""
        var colorSpace: String = ""
        var bitDepth: Int = 0
        var aspectRatio: String = "Unknown"
    }
    
    var body: some View {
        ZStack {
            
            HStack {
                
                Spacer()
                
                VStack {
                    
                    // 视频播放器部分
                    if !players.isEmpty {
                        VideoPlayer(player: players[selectedPlayerIndex])
                            .aspectRatio(videoAspectRatios[selectedPlayerIndex], contentMode: .fit)
                            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: players[selectedPlayerIndex].currentItem)) { _ in
                                self.playerDidFinishPlaying()
                            }
                    } else {
                        Text("列表中无视频")
                    }
                }
                Spacer()
                
                //操作按钮
                VStack (spacing: 10){
                    
                    // 添加视频按钮
                    Button("添加视频") {
                        openVideoFile()
                    }
                    
                    // 切换播放模式按钮
                    Button(action: togglePlaybackMode) {
                        Text("播放模式: \(playbackMode.rawValue)")
                    }
                    
                    // 视频播放列表部分
                    List {
                        ForEach(Array(zip(players.indices, videoNames)), id: \.0) { index, name in
                            Button(action: {
                                self.selectVideo(at: index)
                            }) {
                                HStack {
                                    Text(name)
                                    Spacer()
                                    if selectedPlayerIndex == index {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            // 视频列表二级菜单
                            .contextMenu {
                                Button("删除视频") {
                                    self.removeVideoPlayer(at: index)
                                }
                            }
                        }
                    }
                    .frame(width: 225)
                    .cornerRadius(10)
                }
                .padding(10)
                
                // 按键提示
                KeyPressHandlingView(onKeyPress: handleKeyPress)
                    .frame(width: 0, height: 0)
                    .focusable(true)
            }
            .padding([.top,.bottom],5)
            .frame(minWidth: 1100, minHeight: 480)
            .onAppear {
                DispatchQueue.main.async {
                    NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView?.subviews.last { $0 is KeyPressHandlingNSView })
                }
            }
            
            HStack {
                
                // 元数据视图
                if showMetadataPanel && selectedPlayerIndex < players.count {
                    MetadataView(
                        videoName: videoNames[selectedPlayerIndex],
                        aspectRatio: videoAspectRatios[selectedPlayerIndex],
                        duration: players[selectedPlayerIndex].currentItem?.duration ?? CMTime.zero,
                        metadata: videoMetadata[selectedPlayerIndex] // 传递元数据
                    )
                    .transition(.slide)
                }
                Spacer()
            }
            
            HStack {
                
                VStack {
                    
                    //显示元数据按钮
                    Button(action: {
                        self.showMetadataPanel.toggle()
                    }) {
                        Image(systemName: showMetadataPanel ? "info.circle.fill" : "info.circle")
                            .padding()
                            .accessibilityLabel("Show/Hide Metadata Panel")
                    }
                    
                    Spacer()
                }
                .padding([.top,.leading],10)
                
                VStack {
                    
                    //显示当前播放速度
                    Text("Speed: \(Int(playbackSpeeds[playbackSpeedIndex]))x")
                        .padding(1)
                        .padding([.leading,.trailing],3)
                        .cornerRadius(5)
                    Spacer()
                }
                .padding(.top,10)
                
                Spacer()
            }
            .padding([.leading,.top],3)
        }
    }
    
    
    // 文件选择器
    func openVideoFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                addVideoPlayer(for: url)
            }
        }
    }
    
    // 为选定的视频URL创建AVPlayer并获取视频宽高比
    func addVideoPlayer(for url: URL) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        // 异步加载视频属性
        let keys = ["duration", "tracks"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            var allKeysLoaded = true
            
            for key in keys {
                var error: NSError?
                let status = asset.statusOfValue(forKey: key, error: &error)
                if status == .failed {
                    // Handle the error appropriately
                    allKeysLoaded = false
                    return
                }
            }
            
            // 检查所有需要的属性是否加载成功
            if allKeysLoaded {
                // 确保在主线程更新 UI
                DispatchQueue.main.async {
                    self.loadVideoTracks(for: asset, player: player, videoURL: url)
                    
                    // 创建一个新的VideoMetadata实例
                    var metadata = VideoMetadata()
                    
                    // 获取视频轨道信息
                    if let videoTrack = asset.tracks(withMediaType: .video).first {
                        if let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription],
                           let formatDescription = formatDescriptions.first {
                            
                            // 使用CMFormatDescriptionGetMediaSubType方法获取视频编码类型
                            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
                            
                            //获取视频编码
                            metadata.videoCodec = FourCharCodeToString(mediaSubType)
                            
                            //获取视频码率
                            metadata.videoBitRate = Int(videoTrack.estimatedDataRate)
                            
                            //获取视频帧率
                            metadata.videoFrameRate = videoTrack.nominalFrameRate
                            
                            //获取视频封装格式（最后没有显示在元数据列表中，因为观察后缀名就能直观看出。）
                            metadata.videoFormat = url.pathExtension.uppercased()
                            
                            // 计算和设置画面比例
                            let aspectRatioValue = videoTrack.naturalSize.width / videoTrack.naturalSize.height
                            let aspectRatioFormatted = String(format: "%.2f:1", aspectRatioValue)
                            switch aspectRatioValue {
                            case 1:
                                metadata.aspectRatio = "1:1"
                            case 4.0/3.0:
                                metadata.aspectRatio = "4:3"
                            case 16.0/9.0:
                                metadata.aspectRatio = "16:9"
                            case 2048/1080:
                                metadata.aspectRatio = "17:9"
                            case 2048/858:
                                metadata.aspectRatio = "2.39:1"
                            default:
                                metadata.aspectRatio = aspectRatioFormatted
                            }
                            
                            // 获取色彩空间和位深
                            if let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription],
                               let formatDescription = formatDescriptions.first {
                                
                                // 获取色彩空间
                                if let colorAttachments = CMFormatDescriptionGetExtensions(formatDescription) as? [String: AnyObject],
                                   let colorSpaceProperty = colorAttachments[kCVImageBufferColorPrimariesKey as String] {
                                    metadata.colorSpace = "\(colorSpaceProperty)"
                                }
                                
                                // 获取视频位深
                                if let depthAttachments = CMFormatDescriptionGetExtensions(formatDescription) as? [String: AnyObject],
                                   let bitDepthProperty = depthAttachments["BitsPerComponent"] as? Int {
                                    metadata.bitDepth = bitDepthProperty
                                }
                            }
                        }
                        //对于无法识别到的都获取为8bit
                        if metadata.bitDepth != 10 && metadata.bitDepth != 12 {
                            metadata.bitDepth = 8
                        }
                    }
                    
                    
                    // 获取音频轨道信息
                    if let audioTrack = asset.tracks(withMediaType: .audio).first {
                        if let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription],
                           let formatDescription = formatDescriptions.first {
                            // 使用CMAudioFormatDescriptionGetStreamBasicDescription方法获取音频流基本描述
                            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                                // 从streamBasicDescription中获取音频格式信息
                                metadata.audioBitRate = Int(streamBasicDescription.pointee.mBytesPerPacket * streamBasicDescription.pointee.mFramesPerPacket * 8)
                            }
                            
                            // 使用CMFormatDescriptionGetMediaSubType方法获取音频编码类型
                            let audioCodecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                            metadata.audioCodec = FourCharCodeToString(audioCodecType)
                        }
                        
                        // 获取音频编码格式和采样率
                        if let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription],
                           let formatDescription = formatDescriptions.first,
                           let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
                            
                            //获取音频编码
                            metadata.audioCodec = FourCharCodeToString(CMFormatDescriptionGetMediaSubType(formatDescription))
                            
                            //获取音频码率
                            metadata.audioSampleRate = streamBasicDescription.mSampleRate
                            
                            // 计算音频码率，确保转换为相同的类型后再进行乘法操作
                            let bitsPerChannel = Int(streamBasicDescription.mBitsPerChannel)
                            let sampleRate = Int(streamBasicDescription.mSampleRate)
                            let channelsPerFrame = Int(streamBasicDescription.mChannelsPerFrame)
                            //音频比特率计算
                            metadata.audioBitRate = bitsPerChannel * sampleRate * channelsPerFrame
                        }
                    }
                    
                    // 获取文件大小
                    if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        metadata.fileSize = Int64(fileSize)
                    }
                    self.videoMetadata.append(metadata)
                }
            }
        }
    }
    
    //视频加载
    func loadVideoTracks(for asset: AVAsset, player: AVPlayer, videoURL: URL) {
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let naturalSize = track.naturalSize
        let preferredTransform = track.preferredTransform
        let trackSize = naturalSize.applying(preferredTransform)
        let size = CGSize(width: abs(trackSize.width), height: abs(trackSize.height))
        
        DispatchQueue.main.async {
            self.videoAspectRatios.append(size)
            self.players.append(player)
            self.videoNames.append(videoURL.lastPathComponent)
        }
    }
}

//contentview的方法
extension ContentView {
    
    // 空格、J、K、L控制播放
    func handleKeyPress(event: NSEvent) {
        guard let characters = event.characters else { return }
        for char in characters {
            switch char {
            case " ":
                togglePlayPause()
            case "k":
                togglePlayPause()
            case "j":
                if lastKeyPress == "j" {
                    incrementPlaybackRate(reverse: true)
                } else {
                    setPlaybackRateToOneAndPlay(reverse: true)
                }
            case "l":
                if lastKeyPress == "l" {
                    incrementPlaybackRate(reverse: false)
                } else {
                    setPlaybackRateToOneAndPlay(reverse: false)
                }
            default:
                break
            }
            lastKeyPress = String(char)
        }
    }
    
    //播放速度控制
    func incrementPlaybackRate(reverse: Bool) {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            // 根据当前速度找出下一个速度
            playbackSpeedIndex = (playbackSpeedIndex + 1) % playbackSpeeds.count
            currentPlayer.rate = reverse ? -playbackSpeeds[playbackSpeedIndex] : playbackSpeeds[playbackSpeedIndex]
            if currentPlayer.timeControlStatus != .playing {
                currentPlayer.play() // 如果当前状态不是播放，则开始播放
            }
        }
    }
    
    //重置播放速度
    func setPlaybackRateToOneAndPlay(reverse: Bool) {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            // 重置播放速度索引为一倍速
            playbackSpeedIndex = playbackSpeeds.firstIndex(of: 1) ?? 0
            currentPlayer.rate = reverse ? -playbackSpeeds[playbackSpeedIndex] : playbackSpeeds[playbackSpeedIndex]
            if currentPlayer.timeControlStatus != .playing {
                currentPlayer.play() // 如果当前状态是暂停，则开始播放
            }
        }
    }
    
    //暂停逻辑
    func togglePlayPause() {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            if currentPlayer.rate == 0 {
                currentPlayer.play()
            } else {
                currentPlayer.pause()
            }
        }
    }
    
    //加减速循环
    func changePlaybackRate(decrement: Bool) {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            if decrement {
                // 倒退播放
                playbackSpeedIndex -= 1
                if playbackSpeedIndex < 0 {
                    playbackSpeedIndex = playbackSpeeds.count - 1 // 循环到最大的倒退速度
                }
                currentPlayer.rate = -playbackSpeeds[playbackSpeedIndex]
            } else {
                // 正向播放
                playbackSpeedIndex += 1
                if playbackSpeedIndex >= playbackSpeeds.count {
                    playbackSpeedIndex = 0 // 循环回到1倍速
                }
                currentPlayer.rate = playbackSpeeds[playbackSpeedIndex]
            }
        }
    }
    
    //二级菜单选择视频
    func selectVideo(at index: Int) {
        players[selectedPlayerIndex].pause()
        selectedPlayerIndex = index
        // 选择新视频时重置最后一个按键
        lastKeyPress = nil
    }
    
    //删除视频
    func removeVideoPlayer(at index: Int) {
        players[index].pause() // 暂停当前播放器
        players.remove(at: index) // 从数组中删除播放器
        videoAspectRatios.remove(at: index) // 删除对应的视频宽高比
        videoNames.remove(at: index) // 删除视频名称
        lastKeyPress = nil // 重置最后一个按键
        
        // 如果删除了当前选中的视频，需要更新selectedPlayerIndex
        if selectedPlayerIndex >= players.count {
            selectedPlayerIndex = players.indices.last ?? 0
        }
        
        // 如果列表中还有其他视频，播放下一个视频
        if !players.isEmpty {
            players[selectedPlayerIndex].play()
        }
    }
    
    //播放方式选择
    func togglePlaybackMode() {
        switch playbackMode {
        case .sequential:
            playbackMode = .loopSingle
        case .loopSingle:
            playbackMode = .single
        case .single:
            playbackMode = .random
        case .random:
            playbackMode = .sequential
        }
    }
    
    //播放方式定义
    func playerDidFinishPlaying() {
        switch playbackMode {
        case .sequential:
            // 如果当前视频是列表中的最后一个，则暂停播放
            if selectedPlayerIndex == players.count - 1 {
                players[selectedPlayerIndex].pause()
            } else {
                // 否则，切换到下一个视频
                selectedPlayerIndex = (selectedPlayerIndex + 1) % players.count
                players[selectedPlayerIndex].play()
            }
        case .loopSingle:
            // 重新播放当前视频
            players[selectedPlayerIndex].seek(to: CMTime.zero) { _ in
                self.players[self.selectedPlayerIndex].play()
            }
        case .single:
            // 不做任何事情，已经播放完毕
            break
        case .random:
            // 随机选择一个视频播放
            selectedPlayerIndex = Int.random(in: 0..<players.count)
            players[selectedPlayerIndex].play()
        }
    }
    
    //将获取的编码定义按照文档转换为编解码器ID
    func FourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xff),
            CChar((code >> 16) & 0xff),
            CChar((code >> 8) & 0xff),
            CChar(code & 0xff),
            0
        ]
        return String(cString: bytes)
    }
}

// 承载按键逻辑
struct KeyPressHandlingView: NSViewRepresentable {
    var onKeyPress: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyPressHandlingNSView()
        view.onKeyPress = onKeyPress
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// 确保按键按下时相应
class KeyPressHandlingNSView: NSView {
    var onKeyPress: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyPress?(event)
    }
    override func becomeFirstResponder() -> Bool {
        true
    }
}

//元数据视图
struct MetadataView: View {
    
    let videoName: String
    let aspectRatio: CGSize
    let duration: CMTime
    let metadata: ContentView.VideoMetadata
    
    // 将CMTime转换为小时、分钟、秒的格式
    func formatDuration(_ duration: CMTime) -> String {
        let totalSeconds = Int(duration.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let hoursString = hours > 0 ? String(format: "%02d小时 ", hours) : ""
        let minutesString = String(format: "%02d分 ", minutes)
        let secondsString = String(format: "%02d秒", seconds)
        return hoursString + minutesString + secondsString
    }
    
    // 将视频比特率从bps转换为Mbps并格式化输出
    func formatBitRate(_ bitRate: Int) -> String {
        let bitRateMbps = Double(bitRate) / 1_000_000
        return String(format: "%.2f Mbps", bitRateMbps)
    }
    
    // 将视频文件大小从字节转换为MB并格式化输出
    func formatFileSize(_ fileSize: Int64) -> String {
        let fileSizeMB = Double(fileSize) / 1_000_000
        return String(format: "%.2f MB", fileSizeMB)
    }
    
    // 将比特率从bps转换为kbps并格式化输出
    func audioformatBitRate(_ bitRate: Int) -> String {
        let bitRateKbps = Double(bitRate) / 1_000 // 从bps转换为kbps
        return String(format: "%.0f kbps", bitRateKbps)
    }
    
    var body: some View {
        
        //显示元数据文本
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("视频名称: \(videoName)")
                Text("视频时长: \(formatDuration(duration))")
                Text("文件大小: \(formatFileSize(metadata.fileSize))")
                Text("")
                Text("视频分辨率: \(Int(aspectRatio.width))* \(Int(aspectRatio.height))")
                Text("画面比例: \(metadata.aspectRatio)")
                Text("视频帧率: \(String(format: "%.3f fps", metadata.videoFrameRate))")
                Text("视频码率: \(formatBitRate(metadata.videoBitRate))")
                Text("视频编码: \(metadata.videoCodec.uppercased())")
                Text("视频位深: \(metadata.bitDepth) bits")
                Text("色彩空间: \(metadata.colorSpace)")
                Text("")
                Text("音频编码: \(metadata.audioCodec.uppercased())")
                Text("音频采样率: \(String(format: "%.0f Hz", metadata.audioSampleRate))")
                Text("音频码率: \(audioformatBitRate(metadata.audioBitRate))")
                
                Spacer()
            }
            .padding(.leading,5)
            .padding(.top,75)
        }
        .frame(width: 200)
        .background(Color.gray.opacity(0.6))
        .navigationTitle("\(videoName)_Metadata")
    }
}

//版本V1.1.5 作者吴坤城
