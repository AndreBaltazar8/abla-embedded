import runpy
from pathlib import Path

module = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/place-internal-closure'))
plan = module['plan']
sections = [('', 0, 0), ('.iram1.root', 6, 16), ('.text.helper', 6, 20),
            ('.literal.helper', 2, 4), ('.rodata.table', 2, 16),
            ('.text.callback', 6, 24), ('.bss.state', 3, 4), ('.text.unused', 6, 40)]
edges = {1: {2}, 2: {3}, 3: {4}, 4: {5, 6}, 5: {2}}
result = dict(plan(sections, edges))
assert len(result) == 5
assert result['.literal.helper'].startswith('.iram1.')
assert result['.rodata.table'].startswith('.dram1.')
assert result['.bss.state'].startswith('.dram1.')
assert '.text.unused' not in result
for broken in ({1: {0}}, {1: {99}}):
    try:
        plan(sections, broken)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid target accepted')
assert not plan([('', 0, 0), ('.iram1.code', 6, 4), ('.dram1.data', 2, 4)], {1: {2}})
print('PASS: transitive calls/tables/cycles, literal placement, unused pruning, unresolved refusal')

# Minimal ELF with one internal root relocation to an undefined linker name.
# Allowing that exact name must not permit an unrelated undefined symbol.
import struct
def boundary_object(name):
    names=b'\0.iram1.root\0.rela.root\0.symtab\0.strtab\0.shstrtab\0'
    strings=b'\0'+name.encode()+b'\0'
    blobs=[b'',b'\0'*4,struct.pack('<IIi',0,257,0),b'\0'*16+struct.pack('<IIIBBH',1,0,0,16,0,0),strings,names]
    result=bytearray(52);headers=[]
    for i,blob in enumerate(blobs):
        offset=len(result);result.extend(blob)
        label=[b'',b'.iram1.root',b'.rela.root',b'.symtab',b'.strtab',b'.shstrtab'][i]
        headers.append((names.index(label) if i else 0,[0,1,4,2,3,3][i],6 if i==1 else 0,0,offset,len(blob),3 if i==2 else 4 if i==3 else 0,1 if i==2 else 0,4,[0,0,12,16,0,0][i]))
    table=len(result)
    for h in headers: result.extend(struct.pack('<10I',*h))
    result[:6]=b'\x7fELF\x01\x01'
    struct.pack_into('<I',result,32,table)
    struct.pack_into('<HHH',result,46,40,6,5)
    return bytes(result)
inspect=module['inspect']
for name,allowed,success in [('__stack',(),False),('__stack',('__stack',),True),('libc_fn',('__stack',),False)]:
    try: plan(*inspect(boundary_object(name),allowed))
    except ValueError:
        assert not success
    else: assert success
print('PASS: exact linker boundary opt-in; default and unrelated externals rejected')
