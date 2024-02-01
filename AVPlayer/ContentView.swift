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
    @State private var playbackSpeedIndex: Int = 0 // 新的属性来跟踪播放速度状态
    let playbackSpeeds: [Float] = [1, 2, 4, 8, 16, 32, 64] // 定义播放速度的数组
    
    var body: some View {
        HStack {
            Spacer()
            // 视频播放器部分
            if !players.isEmpty {
                VideoPlayer(player: players[selectedPlayerIndex])
                    .aspectRatio(videoAspectRatios[selectedPlayerIndex], contentMode: .fit)
                    .onAppear {
                        players[selectedPlayerIndex].play()
                    }
                    .onDisappear {
                        players[selectedPlayerIndex].pause()
                    }
                Text("Speed: \(Int(playbackSpeeds[playbackSpeedIndex]))x")
                    .padding(.top, 5)
            } else {
                Text("列表中无视频")
            }
            Spacer()
            VStack (spacing:10){
                // 添加视频按钮
                Button("添加视频") {
                    openVideoFile()
                }
                
                // 视频播放列表部分
                List {
                    ForEach(Array(zip(players.indices, videoNames)), id: \.0) { index, name in
                        Button(action: {
                            players[selectedPlayerIndex].pause()
                            selectedPlayerIndex = index
                            players[selectedPlayerIndex].play()
                        }) {
                            HStack {
                                Text(name)
                                Spacer()
                                if selectedPlayerIndex == index {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .frame(width: 225)
                .cornerRadius(10)
            }
            .padding(10)
            
            // 添加 KeyPressHandlingView
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
    
    // 使用NSOpenPanel打开文件选择器
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
                    player.rate = playbackSpeeds[playbackSpeedIndex]
                }
            }
        }
    }
    
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
    
    // 处理键盘事件的方法
    func handleKeyPress(event: NSEvent) {
        guard let characters = event.characters else { return }
        for char in characters {
            switch char {
            case " ":
                togglePlayPause()
            case "j":
                changePlaybackRate(decrement: true) // 减慢播放速度
            case "k":
                togglePlayPause()
            case "l":
                changePlaybackRate(decrement: false) // 加快播放速度
            default:
                break
            }
        }
    }
    
    func togglePlayPause() {
        // 检查 selectedPlayerIndex 是否在 players 数组的范围内
        if selectedPlayerIndex < players.count {
            let currentPlayer = players[selectedPlayerIndex]
            if currentPlayer.rate != 0 {
                currentPlayer.pause()
            } else {
                currentPlayer.play()
            }
        } else {
            // 如果 selectedPlayerIndex 超出了 players 的范围，您需要处理这种情况
            print("Error: selectedPlayerIndex is out of range for players array.")
        }
    }
    
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



