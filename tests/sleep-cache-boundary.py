import runpy
from pathlib import Path

validate = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/check-sleep-cache-boundary'))['validate']
source = '''define internal i64 @boundary(i64 %x) #0 section ".iram1.abla.s3LightSleepSuspended" {
  %y = call i64 @helper(i64 %x)
  ret i64 %y
}
define internal i64 @helper(i64 %x) #1 section ".iram1.abla.helper" {
  ret i64 %x
}
define i64 @ordinary(i64 %x) #1 {
  %y = call i64 @boundary(i64 %x)
  ret i64 %y
}
attributes #0 = { noinline minsize }
attributes #1 = { minsize }
'''
assert validate(source) == 2
for broken in (
    source.replace('noinline ', ''),
    source.replace('.iram1.abla.s3LightSleepSuspended', '.text.boundary'),
    source.replace('.iram1.abla.helper', '.text.helper'),
):
    try:
        validate(broken)
    except ValueError:
        pass
    else:
        raise AssertionError('unsafe placement accepted')
print('PASS: sleep boundary retention, inlining and helper placement regressions')
