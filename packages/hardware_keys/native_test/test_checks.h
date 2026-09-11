#pragma once

#include <stdexcept>

inline void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

template <typename Action>
void RequireFailure(Action action) {
  try {
    action();
  } catch (const std::exception&) {
    return;
  }
  throw std::runtime_error("Expected operation to fail");
}
