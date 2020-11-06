# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [rule: 5, fetch: 3],
  export: [
    locals_without_parens: [rule: 5, fetch: 3]
  ]
]
