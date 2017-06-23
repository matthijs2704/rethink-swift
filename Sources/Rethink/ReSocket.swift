/**  Rethink.swift
 Copyright (c) 2016 Pixelspark
 Author: Tommy van der Vorst (tommy@pixelspark.nl)
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE. **/
import Foundation
import Sockets
import Dispatch

internal enum ReSocketState {
    case unconnected
    case connecting
    case connected
}

internal class ReSocket: NSObject {
    typealias WriteCallback = (String?) -> ()
    typealias ReadCallback = (Data?) -> ()
    
    var socket: TCPInternetSocket? = nil
    internal var state: ReSocketState = .unconnected
    var num = 0
    private var privSocketQueues: [String: DispatchQueue] = [:]
    
    private func socketQueue(with tag: String) -> DispatchQueue {
        if self.privSocketQueues[tag] == nil {
            self.privSocketQueues[tag] = DispatchQueue.init(label: "SocketQueue-\(tag)")
        }
        print (tag)
        return self.privSocketQueues[tag]!
    }
//    {
//        num += 1
//        return
//    }
    
    internal var delegateQueue: DispatchQueue
    
    private var onConnect: ((String?) -> ())?
    private var writeCallbacks: [Int: WriteCallback] = [:]
    private var readCallbacks: [Int: ReadCallback] = [:]
    
    init(queue: DispatchQueue) {
        self.delegateQueue = queue
        super.init()
    }
    
    func connect(_ url: URL, withTimeout timeout: TimeInterval = 5.0, callback: @escaping (String?) -> ()) {
        assert(self.state == .unconnected, "Already connected or connecting")
        self.onConnect = callback
        self.state = .connecting
        
        guard let scheme = url.scheme else { return callback("Invalid scheme") }
        guard let host = url.host else { return callback("Invalid URL") }
        let port = url.port ?? 28015
        
        self.socketQueue(with: "Connect").async {
            do {
                self.socket = try TCPInternetSocket.init(scheme: scheme, hostname: host, port: Port(port))
                try self.socket!.connect()
                self.socket(self.socket!, didConnectToHost: host, port: Port(port))
            }
            catch let e {
                return callback(e.localizedDescription)
            }
        }
    }
    
    internal func socket(_ sock: TCPInternetSocket, didConnectToHost host: String, port: UInt16) {
        self.state = .connected
        self.onConnect?(nil)
    }
    
    internal func socketDidDisconnect(_ sock: TCPInternetSocket, withError err: Error?) {
        self.state = .unconnected
    }
    
    func read(_ length: Int, callback: @escaping ReadCallback)  {
        assert(length > 0, "Length cannot be zero or less")
        
        if self.state != .connected {
            return callback(nil)
        }
        
        guard let tcpSock = self.socket else {
            return callback(nil)
        }
        
        self.delegateQueue.async {
            let tag = (self.readCallbacks.count + 1)
            self.readCallbacks[tag] = callback
            self.socketQueue(with: "Read\(Int(arc4random_uniform(20) + 100))").async {
                do {
                    _ = try tcpSock.waitForReadableData(timeout: nil)
                    var bytes: Bytes = []
                    while let dataRead = try tcpSock.readByte() {
                        bytes.append(dataRead)
                        if bytes.count == length {
                            break
                        }
                    }
                    self.socket(tcpSock, didRead: Data.init(bytes: bytes), withTag: tag)
                } catch {
                    return callback(nil)
                }
            }
        }
    }
    
    func readZeroTerminatedASCII(_ callback: @escaping (String?) -> ()) {
        if self.state != .connected {
            return callback(nil)
        }
        
        guard let tcpSock = self.socket else {
            return callback(nil)
        }
        
        self.delegateQueue.async {
            let tag = (self.readCallbacks.count + 1)
            self.readCallbacks[tag] = { data in
                if let d = data {
                    if let s = String(data: d.subdata(in: 0..<(d.count-1)), encoding: String.Encoding.ascii) {
                        callback(s)
                    }
                    else {
                        callback(nil)
                    }
                }
                else {
                    callback(nil)
                }
            }
            self.socketQueue(with: "Read\(Int(arc4random_uniform(20) + 100))").async {
                do {
                    _ = try! tcpSock.waitForReadableData(timeout: nil)
                    var bytes: Bytes = []
                    while let dataRead = try tcpSock.readByte() {
                        bytes.append(dataRead)
                        if dataRead == UInt8(0) {
                            break
                        }
                    }
                    self.socket(tcpSock, didRead: Data.init(bytes: bytes), withTag: tag)
//                    print ("ascii \(Thread.current)")
                } catch {
                    return callback(nil)
                }
            }
        }
    }
    
    func write(_ data: Data, callback: @escaping WriteCallback) {
        if self.state != .connected {
            return callback("socket is not connected!")
        }
        
        guard let tcpSock = self.socket else {
            return callback("socket is nil!")
        }
        
        self.delegateQueue.async {
            let tag = (self.writeCallbacks.count + 1)
            self.writeCallbacks[tag] = callback
            let bytes = data.makeBytes()
            self.socketQueue(with: "\(tag)").async {
                _ = try! tcpSock.write(bytes)
                try! tcpSock.flush()
                self.socket(tcpSock, didWriteDataWithTag: tag)
            }
        }
    }
    
    internal func socket(_ sock: TCPInternetSocket, didWriteDataWithTag tag: Int) {
        self.delegateQueue.async {
            if let cb = self.writeCallbacks[tag] {
                cb(nil)
                self.writeCallbacks.removeValue(forKey: tag)
            }
        }
    }
    
    internal func socket(_ sock: TCPInternetSocket, didRead data: Data, withTag tag: Int) {
        self.delegateQueue.async {
            if let cb = self.readCallbacks[tag] {
                cb(data)
                self.readCallbacks.removeValue(forKey: tag)
            }
        }
    }
    
    func disconnect() {
        try? self.socket?.close()
        self.state = .unconnected
    }
    
    deinit {
        try? self.socket?.close()
    }
}

/** A pthread-based recursive mutex lock. */
internal class Mutex {
    private var mutex: pthread_mutex_t = pthread_mutex_t()
    
    public init() {
        var attr: pthread_mutexattr_t = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        #if os(Linux)
            pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_RECURSIVE))
        #else
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        #endif
        
        let err = pthread_mutex_init(&self.mutex, &attr)
        pthread_mutexattr_destroy(&attr)
        
        switch err {
        case 0:
            // Success
            break
            
        default:
            fatalError("Could not create mutex, error \(err)")
        }
    }
    
    private final func lock() {
        let ret = pthread_mutex_lock(&self.mutex)
        switch ret {
        case 0:
            // Success
            break
            
        default:
            fatalError("Could not lock mutex: error \(ret)")
        }
    }
    
    private final func unlock() {
        let ret = pthread_mutex_unlock(&self.mutex)
        switch ret {
        case 0:
            // Success
            break
        default:
            fatalError("Could not unlock mutex: error \(ret)")
        }
    }
    
    deinit {
        assert(pthread_mutex_trylock(&self.mutex) == 0 && pthread_mutex_unlock(&self.mutex) == 0, "deinitialization of a locked mutex results in undefined behavior!")
        pthread_mutex_destroy(&self.mutex)
    }
    
    @discardableResult public final func locked<T>(_ file: StaticString = #file, line: UInt = #line, block: () -> (T)) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        let ret: T = block()
        return ret
    }
}
