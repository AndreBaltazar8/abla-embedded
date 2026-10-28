target triple = "xtensa-esp-unknown-elf"

@sym = global [16 x i8] zeroinitializer

define i32 @f() {
  %r = call i32 asm "movi $0, sym+5", "=r"()
  ret i32 %r
}
