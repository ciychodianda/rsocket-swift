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

/// A single one-way message
internal struct RequestFireAndForgetFrameBody: Hashable {
    /// Identification of the service being requested along with parameters for the request
    internal let payload: Payload
}

extension RequestFireAndForgetFrameBody: FrameBodyBoundToStream {
    func body() -> FrameBody { .requestFnf(self) }
    func header(withStreamId streamId: StreamID, additionalFlags: FrameFlags) -> FrameHeader {
        var flags = additionalFlags
        if payload.metadata != nil {
            flags.insert(.metadata)
        }
        return FrameHeader(streamId: streamId, type: .requestFnf, flags: flags)
    }
}
