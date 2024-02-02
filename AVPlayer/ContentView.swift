//
//  ContentView.swift
//  AVPlayer
//
//  Created by 吴坤城 on 1/31/24.
//

import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var players: [AVPlayer] = []
    @State private var selectedPlayerIndex: Int = 0
    @State private var videoAspectRatios: [CGSize] = []
    @State private var videoNames: [String] = []
    @State private var playbackSpeedIndex: Int = 0
    @State private var lastKeyPress: String? = nil
    // 定义播放速度的数组
    let playbackSpeeds: [Float] = [1, 2, 4, 8, 16, 32, 64]

    
    var body: some View {
        HStack {
            
            Spacer()
            
            // 视频播放器部分
            if !players.isEmpty {
                VideoPlayer(player: players[selectedPlayerIndex])
                    .aspectRatio(videoAspectRatios[selectedPlayerIndex], contentMode: .fit)
                
                //移除添加视频后立刻播放的按钮以修复删除视频后可能的错误
//                    .onAppear {
//                        players[selectedPlayerIndex].play()
//                    }
                    .onDisappear {
                        players[selectedPlayerIndex].pause()
                    }
                Text("Speed: \(Int(playbackSpeeds[playbackSpeedIndex]))x")
                    .padding(.top, 5)
            } else {
                Text("列表中无视频")
            }
            
            Spacer()
            
            //操作按钮
            VStack (spacing:10){
                // 添加视频按钮
                Button("添加视频") {
                    openVideoFile()
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
                            Button("查看元数据") {
                                self.showMetadata(for: index)
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
        .padding([.top,.bottom],8)
        .frame(minWidth: 1100, minHeight: 500)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView?.subviews.last { $0 is KeyPressHandlingNSView })
            }
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
                    print("Error loading \(key): \(String(describing: error))")
                    allKeysLoaded = false
                    return
                }
            }
            
            // 检查所有需要的属性是否加载成功
            if allKeysLoaded {
                // 时长和轨道都已经加载，可以继续处理
                DispatchQueue.main.async { // 确保在主线程更新 UI
                    self.loadVideoTracks(for: asset, player: player, videoURL: url)
                    // 不自动播放视频
                    // player.rate = playbackSpeeds[playbackSpeedIndex]
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
    
    func incrementPlaybackRate(reverse: Bool) {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
        
            // 根据当前速度找出下一个速度
            playbackSpeedIndex = (playbackSpeedIndex + 1) % playbackSpeeds.count
            currentPlayer.rate = reverse ? -playbackSpeeds[playbackSpeedIndex] : playbackSpeeds[playbackSpeedIndex]
            if currentPlayer.timeControlStatus != .playing {
                currentPlayer.play() // 如果当前状态不是播放，则开始播放
            }
        } else {
            print("Error: selectedPlayerIndex is out of range for players array.")
        }
    }

    func setPlaybackRateToOneAndPlay(reverse: Bool) {
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            // 重置播放速度索引为一倍速
            playbackSpeedIndex = playbackSpeeds.firstIndex(of: 1) ?? 0
            currentPlayer.rate = reverse ? -playbackSpeeds[playbackSpeedIndex] : playbackSpeeds[playbackSpeedIndex]
            if currentPlayer.timeControlStatus != .playing {
                currentPlayer.play() // 如果当前状态是暂停，则开始播放
            }
        } else {
            print("Error: selectedPlayerIndex is out of range for players array.")
        }
    }
    
    //暂停功能
    func togglePlayPause() {
        // 检查 selectedPlayerIndex 是否在 players 数组的范围内
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            if currentPlayer.rate == 0 {
                currentPlayer.play()
            } else {
                currentPlayer.pause()
            }
        } else {
            // 如果 selectedPlayerIndex 超出了 players 的范围，您需要处理这种情况
            print("Error: selectedPlayerIndex is out of range for players array.")
        }
    }
    
    //加减速循环
    func changePlaybackRate(decrement: Bool) {
        // 检查 selectedPlayerIndex 是否在 players 数组的范围内
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
        } else {
            // 如果 selectedPlayerIndex 超出了 players 的范围，您需要处理这种情况
            print("Error: selectedPlayerIndex is out of range for players array.")
        }
    }
    
    //二级菜单选择视频
    func selectVideo(at index: Int) {
        players[selectedPlayerIndex].pause()
        selectedPlayerIndex = index
        // 选择新视频时重置最后一个按键
        lastKeyPress = nil
        //不自动播放新视频
        //players[selectedPlayerIndex].play()
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

    //视频元数据
    func showMetadata(for index: Int) {
        // 这里你可以实现显示元数据的逻辑
        // 例如，你可以创建一个新的视图来展示元数据，并将其推送到导航堆栈中
        // 由于这里没有完整的上下文，我将只打印出视频名称
        print("元数据 for \(videoNames[index])")
    }

}

// NSViewRepresentable to handle key presses
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

// NSView subclass that can become first responder and handle key presses
class KeyPressHandlingNSView: NSView {
    var onKeyPress: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        print("Key pressed: \(event.characters ?? "")")
        onKeyPress?(event)
    }
    
    override func becomeFirstResponder() -> Bool {
        true
    }
}



