"""
    websocket_connect(client, path; headers=NVPair[]) → Int32

Initiate a WebSocket connection over HTTP/2 (RFC 8441) by sending
a CONNECT request with the `:protocol` pseudo-header set to `websocket`.

Returns the stream ID for the WebSocket tunnel.

Note: Requires server support for RFC 8441 (Extended CONNECT).
"""
function websocket_connect(client::HTTP2Client, path::AbstractString;
                           headers::Vector{NVPair}=NVPair[])
    _check_open(client, "HTTP2Client")

    # Build CONNECT request with :protocol pseudo-header
    all_headers = NVPair[
        NVPair(":method", "CONNECT"),
        NVPair(":path", String(path)),
        NVPair(":scheme", "https"),
        NVPair(":authority", client.host),
        NVPair(":protocol", "websocket"),
    ]
    append!(all_headers, headers)

    nva = [to_nghttp2_nv(nv) for nv in all_headers]

    stream_id = GC.@preserve all_headers nva begin
        nghttp2_submit_request2(client.session_ptr, C_NULL,
                                 pointer(nva), length(nva),
                                 C_NULL, C_NULL)
    end

    if stream_id < 0
        check_error(stream_id)
    end

    # Flush
    outdata = _session_send_all(client.session_ptr)
    if !isempty(outdata)
        write(client.tls_stream, outdata)
    end

    return stream_id
end
