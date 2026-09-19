#include <ranges>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <chrono>
int main(int argc, char**) {
    size_t n = 10000000 + (size_t)argc;
    std::vector<size_t> data(n - 1);
    for (size_t i = 0; i + 1 < n; i++) data[i] = i + 1;
    double best = 1e30; int64_t c = 0;
    for (int r = 0; r < 7; r++) {
        auto t = std::chrono::steady_clock::now();
        auto v = data | std::views::filter([](size_t i){ return i % 2 == 0; })
                      | std::views::transform([](size_t i){ return (int64_t)i * 3; });
        c = 0; for (auto x : v) c += x;
        best = std::min(best, std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count());
    }
    std::printf("RESULT %lld %.6f\n", (long long)c, best);
}
