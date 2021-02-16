//
//  ContentView.swift
//  Shared
//
//  Created by James Keith on 2/8/21.
//

import SwiftUI
import AVFoundation

extension Data {
     func append(fileURL: URL) throws {
         if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
             defer {
                 fileHandle.closeFile()
             }
             fileHandle.seekToEndOfFile()
             fileHandle.write(self)
         }
         else {
             try write(to: fileURL, options: .atomic)
         }
     }
 }

struct ContentView: View {
    @State private var statusString = "Initalized"
    
    var audioEngine: AVAudioEngine = AVAudioEngine()
    var audioFilePlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    
    var body: some View {
        Text(statusString)
            .padding()
        Button(action: doThing, label: {
            Text("Perform Action")
        })
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func doThing() {
        let messageHolder = UnsafeMutablePointer<Int8>.allocate(capacity: 64)
        
        if let path = Bundle.main.path(forResource: "knulla-kuk.mod", ofType: nil) {
            
            if let nsdata = NSData(contentsOfFile: path) {
                statusString = "data loaded"
                
                var data = nsdata as Data
                let dataCount = data.count
                data.withUnsafeMutableBytes ({ (ptr: UnsafeMutableRawBufferPointer) -> Void in
                    var moduleData = moddata()
                    moduleData.buffer = ptr.baseAddress?.assumingMemoryBound(to: Int8.self)
                    moduleData.length = Int32(dataCount)
                    statusString = "Data loaded: Count " + String(dataCount)
                    
                    let mod: UnsafeMutablePointer<module> = module_load(&moduleData, messageHolder)
                    statusString = "Mod loaded"
                    
                    let replayData: UnsafeMutablePointer<replay> = new_replay(mod, 44100, 1)
                    
                    let replayDuration = replay_calculate_duration(replayData)
                    
                    statusString = "Mod duration in samples: " + String(replayDuration)
                    print("Mod duration in samples: " + String(replayDuration))
                    
                    var currentReplayPosition = replay_get_sequence_pos(replayData)
                    
                    statusString = "Mod replay position: " + String(currentReplayPosition)
                    
                    let mixBufLength = calculate_mix_buf_len(44100)
                    
                    statusString = "Mix buf length should be: " + String(mixBufLength)
                    print("Mix buf length should be: " + String(mixBufLength))
                    
                    let mixBuf = UnsafeMutablePointer<Int32>.allocate(capacity: Int(mixBufLength))
                    let mixBufBuffer = UnsafeBufferPointer(start: mixBuf, count: Int(mixBufLength))
                    
                    let filename = getDocumentsDirectory().appendingPathComponent("test.pcm")
                    
                    print(filename);
                    
                    var samplesLeftToWrite = replayDuration;
                    
                    while samplesLeftToWrite > 0 {
                        let samplesWritten = replay_get_audio(replayData, mixBuf, 0)
                        samplesLeftToWrite -= samplesWritten
                        
                        var mixBufArray = Array(mixBufBuffer)
                        
                        for index in 0 ... Int(samplesWritten) * 2 {
                            var value = mixBufArray[index]
                            
                            if(value > 32767) {
                                value = 32767
                            } else if (value < -32768) {
                                value = -32768
                            }
                            mixBufArray[index] = value * 65536
                        }
                        
                        let dataToWrite = Data(bytes: mixBufArray, count: Int(samplesWritten) * 4 * 2)
                        try! dataToWrite.append(fileURL: filename)
                    }

                    //statusString = "Wrote this number of samples to mixbuf: " + String(samplesWritten)
                    statusString = "Wrote all samples to file?"
                    currentReplayPosition = replay_get_row(replayData)
                    statusString = "Mod replay row position: " + String(currentReplayPosition)
                })
            }
            
        } else {
            statusString = "Failed to locate mod"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
