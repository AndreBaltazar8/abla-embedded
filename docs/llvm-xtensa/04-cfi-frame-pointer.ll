target triple = "xtensa-esp-unknown-elf"

declare void @g(ptr)

define void @f(i32 %n) "frame-pointer"="all" {
  %p = alloca i32, i32 %n
  call void @g(ptr %p)
  ret void
}
