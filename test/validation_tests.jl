@testitem "check_header_name" begin
    using Nghttp2Wrapper
    @test nghttp2_check_header_name("content-type") == true
    @test nghttp2_check_header_name(":method") == true
    @test nghttp2_check_header_name("Content-Type") == false  # uppercase not allowed in HTTP/2
    @test nghttp2_check_header_name("") == false
end

@testitem "check_header_value" begin
    using Nghttp2Wrapper
    @test nghttp2_check_header_value("text/html") == true
    @test nghttp2_check_header_value("GET") == true
    @test nghttp2_check_header_value("") == true  # empty value is valid
end

@testitem "check_authority_path_method" begin
    using Nghttp2Wrapper
    @test nghttp2_check_authority("example.com") == true
    @test nghttp2_check_authority("example.com:443") == true
    @test nghttp2_check_path("/index.html") == true
    @test nghttp2_check_path("/") == true
    @test nghttp2_check_method("GET") == true
    @test nghttp2_check_method("POST") == true
end
