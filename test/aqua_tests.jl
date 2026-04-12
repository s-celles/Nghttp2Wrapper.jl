@testitem "Aqua quality" begin
    using Aqua
    using Nghttp2Wrapper

    Aqua.test_all(Nghttp2Wrapper)
end
