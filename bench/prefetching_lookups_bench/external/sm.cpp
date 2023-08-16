/*Copyright (c) 2018 Gor Nishanov All rights reserved.

This code is licensed under the MIT License (MIT).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

From https://github.com/GorNishanov/await
*/
#include <vector>
#include <xmmintrin.h>
#include "runner.hpp"

// Handcrafted state machine's frame.
struct Frame {
  enum State { KEEP_GOING, FOUND, NOT_FOUND, EMPTY };

  int const* first;
  int const* last;
  int const* middle;
  size_t len;
  size_t half;
  int val;
  State state = EMPTY;

  template <typename T>
  static void prefetch(T const& x) {
    _mm_prefetch(reinterpret_cast<const char*>(&x), _MM_HINT_NTA);
  }

  void init(int const* first, int const* last, int key)
  {
    this->val = key;
    this->first = first;
    this->last = last;

    this->len = last - first;

    if (len == 0) {
      state = NOT_FOUND;
      return;
    }

    half = len / 2;
    middle = first + half;
    this->state = KEEP_GOING;
    prefetch(*middle);
  }

  bool run() {
    auto x = *middle;
    if (x < val) {
      first = middle;
      ++first;
      len = len - half - 1;
    } else
      len = half;

    if (x == val) {
      state = FOUND;
      return true;
    }

    if (len > 0) {
      half = len / 2;
      middle = first + half;
      prefetch(*middle);
      return false;
    }

    state = NOT_FOUND;
    return true;
  }
};

bool sm_binary_search(int const* first, int const* last, int key) {
  Frame f;
  f.init(first, last, key);
  while (f.state == 0)
    f.run();
  return f.state == 1;
}

// Multi lookup with prefetching using hand-crafted state machine.
long SmMultiLookup(
  std::vector<int> const& v, std::vector<int> const& lookups, int streams) {
  std::vector<Frame> f(streams);
  size_t N = streams - 1;
  size_t i = N;
  long result = 0;

  auto beg = &v[0];
  auto end = beg + v.size();

  for (auto key: lookups) {
    auto *fr = &f[i];
    if (fr->state != Frame::State::KEEP_GOING) {
      fr->init(beg, end, key);
      if (i == 0) i = N; else --i;
    } else {
      for (;;) {
        if (fr->run()) {
          // run to completion
          if (fr->state == Frame::State::FOUND)
            ++result;
          fr->init(beg, end, key);
          if (i == 0) i = N; else --i;
          break;
        }
        if (i == 0) i = N; else --i; fr = &f[i];
      }
    }
  }

  bool moreWork = false;
  do {
    moreWork = false;
    for (auto& fr: f)
      if (fr.state == 0) {
        moreWork = true;
        if (fr.run() && fr.state == Frame::State::FOUND)
          ++result;
      }
  } while (moreWork);

  return result;
}

long testSm(State &s) {
  return SmMultiLookup(s.v, s.lookups, s.streams);
}

int main(int argc, const char** argv) {
    int streams = 9;

    if (argc == 2){
      streams = atoi(argv[1]);
    }

  return runner(testSm, Case::big, streams, "sm");
}
