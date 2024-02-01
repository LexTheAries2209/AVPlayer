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

    var body: some View {
        HStack {
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
            } else {
                Text("No videos available")
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
            .frame(width: 200)
            
            // 添加视频按钮
            Button("Add Video") {
                openVideoFile()
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
            // 这里不需要 weak self，因为 ContentView 是一个结构体
            for key in keys {
                var error: NSError?
                let status = asset.statusOfValue(forKey: key, error: &error)
                if status == .failed {
                    // Handle the error appropriately
                    print("Error loading \(key): \(String(describing: error))")
                    return
                }
            }

            // 检查所有需要的属性是否加载成功
            if asset.statusOfValue(forKey: "duration", error: nil) == .loaded,
               asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                // 时长和轨道都已经加载，可以继续处理
                DispatchQueue.main.async { // 确保在主线程更新 UI
                    self.loadVideoTracks(for: asset, player: player, videoURL: url)
                }
            }
        }
    }


    func loadVideoTracks(for asset: AVAsset, player: AVPlayer, videoURL: URL) {
        // 这里不再需要检查轨道的状态，因为我们已经在上面的方法中检查过了
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





