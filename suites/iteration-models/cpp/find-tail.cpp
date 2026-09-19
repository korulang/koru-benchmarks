#include <ranges>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <chrono>
int main(int argc, char**) {
    size_t n = 10000000 + (size_t)argc;
    double best = 1e30; int64_t c = 0;
    for (int r = 0; r < 7; r++) {
        auto t = std::chrono::steady_clock::now();
        auto v = std::views::iota(size_t{0}, n);
        auto it = std::ranges::find_if(v, [](size_t i){ return (int64_t)i > 9999997; });
        c = it == v.end() ? -1 : (int64_t)*it;
        best = std::min(best, std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count());
    }
    std::printf("RESULT %lld %.6f\n", (long long)c, best);
}
