from pathlib import Path

Import("env")

project = Path(env["PROJECT_DIR"])
object_path = (project / env.GetProjectOption("custom_abla_object")).resolve()
if not object_path.is_file():
    raise RuntimeError(
        f"missing Abla object: {object_path}; build the example's build.ab first"
    )

# A relocatable Abla object is an ordinary PlatformIO build input. It supplies
# Arduino's setup/loop symbols directly, so no generated or handwritten C/C++
# glue exists. PIOBUILDFILES also tells PlatformIO this intentionally has no
# C-family source file; adding the path to LINKFLAGS alone triggers its
# "Nothing to build" guard.
env.AppendUnique(PIOBUILDFILES=[env.File(str(object_path))])
