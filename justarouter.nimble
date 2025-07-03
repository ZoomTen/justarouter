version = "0.1.0"
author = "Zumi"
license = "MIT"
skipDirs = @["bench", "tests"]
installFiles = @["justarouter.nim"]

requires "nim >= 2.0.0"
requires "regex == 0.26.1"

task bench, "perform a benchmark":
  selfExec("r -d:danger bench/bench.nim")
