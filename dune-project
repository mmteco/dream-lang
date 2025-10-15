(lang dune 3.0)
(name dream)
(version 0.1.0)

(using menhir 2.1)

(generate_opam_files true)

(package
 (name dream)
 (synopsis "Dream programming language compiler")
 (description "A modern compiled language for AI applications with Python-style syntax and TypeScript-style type system")
 (depends
  (ocaml (>= 4.14))
  dune
  menhir))
