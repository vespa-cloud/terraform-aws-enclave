# Test fixture: exposes the release of this module package to test runs.
# Test files cannot call functions in a run's variables on all supported
# runtimes, but they can refer to the outputs of an earlier run.

output "release" {
  value = trimspace(file("${path.module}/../../VERSION"))
}
