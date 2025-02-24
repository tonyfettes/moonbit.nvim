pub fn hello() -> String {
  "Hello, world!"
}

test "a" {
  inspect!(hello());
}
