target triple = "xtensa-esp-unknown-elf"

define i32 @sum(ptr %p, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %i1, %loop ]
  %a = phi i32 [ 0, %entry ], [ %a1, %loop ]
  %q = getelementptr i32, ptr %p, i32 %i
  %v = load i32, ptr %q
  %a1 = add i32 %a, %v
  %i1 = add i32 %i, 1
  %c = icmp ult i32 %i1, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %a1
}
