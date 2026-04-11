"""
    forward_request(client::HTTP2Client, req::ServerRequest) → ServerResponse

Forward a server request to an upstream HTTP/2 server via the client,
and return the upstream response as a ServerResponse.
Useful for building HTTP/2 proxies.
"""
function forward_request(client::HTTP2Client, req::ServerRequest)
    # Forward the request
    resp = request(client, req.method, req.path;
                   headers=req.headers, body=req.body)

    # Convert client Response to ServerResponse
    return ServerResponse(resp.status, resp.headers, resp.body)
end
