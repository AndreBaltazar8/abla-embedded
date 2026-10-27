import pathlib
import runpy

inspect = runpy.run_path(str(pathlib.Path(__file__).parents[1] / 'tools/check-target-reachability'))['inspect']
ir = '''define i64 @entry(i64 %x) #0 {
  %r = call i64 @middle(i64 %x)
  ret i64 %r
}
define internal i64 @middle(i64 %x) #1 {
  %r = call i64 @hardware(i64 %x)
  ret i64 %r
}
define internal i64 @hardware(i64 %x) #2 {
  ret i64 %x
}
define internal i64 @unreachable(i64 %x) #3 {
  ret i64 %x
}
attributes #0 = { "abla.source"="main" }
attributes #1 = { "abla.source"="driver" }
attributes #2 = { "abla.source"="transfer" }
attributes #3 = { "abla.source"="dead" }
'''
assert inspect(ir, 'entry', ['transfer']) == ['main -> driver -> transfer']
assert inspect('@public = alias i64 (i64), ptr @entry\n' + ir, 'public', ['transfer']) == ['public -> main -> driver -> transfer']
for entry, target in [('missing', 'transfer'), ('entry', 'dead'), ('entry', 'absent')]:
    try:
        inspect(ir, entry, [target])
    except ValueError:
        pass
    else:
        raise AssertionError((entry, target))
print('PASS: retained-path checker rejects missing and unreachable boundaries')
