target triple = "xtensa-esp-unknown-elf"

define i32 @f(i32 %a, i32 %b) {
  %s = shl i32 %b, 3
  %r = add i32 %s, 8192
  ret i32 %r
}
