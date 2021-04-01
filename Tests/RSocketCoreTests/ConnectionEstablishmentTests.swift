/*
 * Copyright 2015-present the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import NIO
@testable import RSocketCore

extension StreamID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int32) {
        self.init(rawValue: value)
    }
}

final class ConnectionEstablishmentTests: XCTestCase {
    func testSuccessfulEstablishment() throws {
        let initializeConnection = self.expectation(description: "should initialize connection")
        initializeConnection.assertForOverFulfill = true
        
        let shouldAcceptSetup = self.expectation(description: "shouldAcceptSetup should be called")
        shouldAcceptSetup.assertForOverFulfill = true
        
        
        let channel = EmbeddedChannel(
            handler: ConnectionEstablishmentHandler(initializeConnection: { (info, channel) in
                initializeConnection.fulfill()
                return channel.eventLoop.makeSucceededFuture(())
            }, shouldAcceptClient: { (info) -> ClientAcceptorResult in
                shouldAcceptSetup.fulfill()
                return .accept
            }))
        
        try channel.writeInbound(SetupFrameBody(
            honorsLease: false,
            version: .v1_0,
            timeBetweenKeepaliveFrames: 500,
            maxLifetime: 10000,
            resumeIdentificationToken: nil,
            metadataEncodingMimeType: "utf8",
            dataEncodingMimeType: "utf8",
            payload: .empty
        ).asFrame())
        
        XCTAssertThrowsError(
            try channel.pipeline.handler(type: ConnectionEstablishmentHandler.self).wait(),
            "handler should be removed"
        )
        
        self.wait(for: [initializeConnection, shouldAcceptSetup], timeout: 0.1)
    }
    
    func testKeepAliveRespondBack() throws {
        let channel = EmbeddedChannel(handler: ConnectionStreamHandler(timeBetweenKeepaliveFrames: 1, maxLifetime: 2, connectionSide: ConnectionRole.server))

        let frame = KeepAliveFrameBody(respondWithKeepalive: true, lastReceivedPosition: 0, data: Data()).asFrame()
        try channel.writeInbound(frame)

        var keepAliveFrame: RSocketCore.Frame?
        keepAliveFrame = try channel.readOutbound()
        if let testFrame = keepAliveFrame {
            XCTAssertEqual(testFrame.header.type, FrameType.keepalive)
        } else {
            XCTFail("Should have received KeepAliveFrame in response")
        }
        _ = try channel.finish()
    }

    func testKeepAliveNoResponseBack() throws {
        let channel = EmbeddedChannel(handler: ConnectionStreamHandler(timeBetweenKeepaliveFrames: 1, maxLifetime: 2, connectionSide: ConnectionRole.client))

        let frame = KeepAliveFrameBody(respondWithKeepalive: false, lastReceivedPosition: 0, data: Data()).asFrame()
        try channel.writeInbound(frame)

        var keepAliveFrame: RSocketCore.Frame?
        keepAliveFrame = try channel.readOutbound()
        if keepAliveFrame != nil {
            XCTFail("Shouldn't have received a KeepAliveFrame in response")
        } else {
            XCTAssertNil(keepAliveFrame)
        }
        _ = try channel.finish()
    }
    
//    func testKeepAliveTimeout() throws {
//        let loop = EmbeddedEventLoop()
//        let channel = EmbeddedChannel(handler: ConnectionStreamHandler(timeBetweenKeepaliveFrames: 1, maxLifetime: 2, connectionSide: ConnectionRole.client, now: { () -> TimeInterval in
//                                       return ProcessInfo.processInfo.systemUptime - 10
//        }), loop: loop)
//        try channel.connect(to: SocketAddress.init(ipAddress: "127.0.0.1", port: 0)).wait()
//
//        var errorFrame: RSocketCore.Frame?
//        errorFrame = try channel.readOutbound()
//        switch errorFrame?.body {
//        case .error(_):
//            print("Done")
//        default:
//            XCTFail("Shouldn't have received a KeepAliveFrame in response")
//        }
//        _ = try channel.finish()
//    }

    func testDeliveryOfExtraMessagesDuringSetup() throws {
        let loop = EmbeddedEventLoop()
        let connectionInitialization = loop.makePromise(of: Void.self)
        
        let channel = EmbeddedChannel(
            handler: ConnectionEstablishmentHandler(initializeConnection: { _, _ in
                connectionInitialization.futureResult
            }), loop: loop)
        
        try channel.writeInbound(SetupFrameBody(
            honorsLease: false,
            version: .v1_0,
            timeBetweenKeepaliveFrames: 500,
            maxLifetime: 10000,
            resumeIdentificationToken: nil,
            metadataEncodingMimeType: "utf8",
            dataEncodingMimeType: "utf8",
            payload: .empty
        ).asFrame())
        
        let frame = RequestResponseFrameBody(payload: .empty)
            .asFrame(withStreamId: 3)
        try channel.writeInbound(frame)
        
        connectionInitialization.completeWith(.success(()))
        
        XCTAssertEqual(try channel.readInbound(as: Frame.self), frame)
    }
}
