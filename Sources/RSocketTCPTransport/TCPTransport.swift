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

import NIO
import NIOExtras
import RSocketCore

public struct TCPTransport {
    public init() { }
}

extension TCPTransport: TransportChannelHandler {
    public func addChannelHandler(
        channel: Channel,
        host: String,
        port: Int,
        upgradeComplete: @escaping () -> EventLoopFuture<Void>
    ) -> EventLoopFuture<Void> {
        channel.pipeline.addHandlers([
            ByteToMessageHandler(LengthFieldBasedFrameDecoder(lengthFieldBitLength: .threeBytes)),
            LengthFieldPrepender(lengthFieldBitLength: .threeBytes),
        ]).flatMap(upgradeComplete)
    }
}
