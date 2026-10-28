target triple = "xtensa-esp-unknown-elf"

define i32 @f(i32 %x) {
  %r = call i32 asm "mov $0, $1", "=a,a"(i32 %x)
  ret i32 %r
}
