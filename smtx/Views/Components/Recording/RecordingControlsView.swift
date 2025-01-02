import SwiftUI
import AVFoundation

struct RecordingControlsView: View {
    enum Mode {
        case recording
        case preview
    }
    
    let mode: Mode
    let isRecording: Bool
    let isPlaying: Bool
    let onRecordTap: () -> Void
    let onPlayTap: () -> Void
    let onBackward: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 24) {
            // 删除按钮（仅在预览模式下显示）
            if mode == .preview {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            } else {
                // 占位视图，保持布局对称
                Color.clear
                    .frame(width: 24, height: 24)
            }
            
            Spacer()
            
            Group {
                if mode == .preview {
                    // 预览模式按钮组
                    HStack(spacing: 24) {
                        // 后退15秒
                        Button(action: onBackward) {
                            Image(systemName: "gobackward.15")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        // 播放/暂停
                        Button(action: onPlayTap) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.primary)
                        }
                        
                        // 前进15秒
                        Button(action: onForward) {
                            Image(systemName: "goforward.15")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                        removal: .scale(scale: 0.3)
                            .combined(with: .opacity)
                            .animation(.easeOut(duration: 0.2))
                    ))
                } else {
                    // 录音按钮
                    Button(action: onRecordTap) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(isRecording ? .primary : .red)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                        removal: .scale(scale: 0.3)
                            .combined(with: .opacity)
                            .animation(.easeOut(duration: 0.2))
                    ))
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8),
                value: mode
            )
            
            Spacer()
            
            // 完成按钮（仅在预览模式下显示）
            if mode == .preview {
                Button(action: onDismiss) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            } else {
                // 占位视图，保持布局对称
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal)
    }
} 