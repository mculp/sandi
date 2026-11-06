# sandi

A ratchet on [Sandi Metz's four rules](https://thoughtbot.com/blog/sandi-metz-rules-for-developers), and on her
guidelines if you ask for them.

**Rules** are what a parser can count, so sandi counts them exactly, with RuboCop and Prism:

1. A class is at most 100 lines.
2. A method is at most 5 lines.
3. A method takes at most 4 parameters.
4. An entry point builds one object, counted here as the distinct constants a script calls methods on outside any
   `def`.

**Guidelines** are the rest of what she says about code: judgment calls no parser can make, such as whether a comment
says what the code does rather than why. sandi puts each one as a yes/no question to
[Jev](https://docs.typesafe.ai/concepts/system-one), TypeSafe's decision model, through OpenRouter. Guidelines are off
unless a project turns them on. See [Guidelines](#guidelines).

Most code doesn't meet them yet. `sandi` records each file's counts in `.sandi-baseline.json` and exits 1 when a
count rises or a file the baseline lacks has an offense. Counts can fall and never rise. Its first line is the
progress to quote in a PR, and it names the files that improved.

## Install

```ruby
# Gemfile
gem "sandi", git: "https://github.com/mculp/sandi"
gem "rubocop", "1.87.0" # the baseline's counts are one version's, so pin it
```

RuboCop counts rules 1-3 and Prism reads the scripts for rule 4. Point RuboCop at Sandi's limits and say what to
measure in `.rubocop.yml`:

```yaml
inherit_gem:
  sandi: config/sandi.yml

AllCops:
  TargetRubyVersion: 3.4
  Include:
    - bin/*
    - lib/**/*.rb
```

`config/sandi.yml` turns every other cop off. Code that isn't under `Include` isn't measured. A file under `Include`
whose first line is a Ruby shebang is an entry point.

## Use

Run it from the project's root:

```sh
bundle exec sandi                                # 0: no count rose, 1: one did, 2: couldn't count or misused
bundle exec sandi --update                       # write today's counts as the baseline; refuses to raise one
bundle exec sandi --update --allow-increase      # write them even if a count rose
```

A PR doesn't have to touch the baseline, which keeps parallel PRs from conflicting. Tighten it after merges with
`sandi --update`.

## Guidelines

Turn guidelines on by name in `.sandi.yml`:

```yaml
guidelines:
  - WhatComment   # a comment inside a method that only says what the lines after it do
  - StaleComment  # a comment that the code under it contradicts
```

Each is asked about every comment written for a reader: a comment just above a `class`, `module` or `def`, and a
comment on its own lines inside a method, each sent with the code it is about. Shebangs, magic comments, `rubocop:`
directives and comments after code on the same line are skipped, though a directive between a comment and the
definition under it doesn't separate them. The questions are in `config/guidelines.yml`, and
[GUIDELINES.md](GUIDELINES.md) says how they were calibrated against Jev and lists the guidelines still to come.

Jev answers with the probability that the answer is yes. A yes of 0.7 or more counts against the comment's file, in
the same baseline and ratchet as the rules. When a count rises, sandi names the comments behind it, and it says what
asking cost:

```text
guidelines: 2 (StaleComment 1, WhatComment 1) in 1 of 1 files
  lib/cart.rb:5 StaleComment 0.81
  lib/cart.rb:7 WhatComment 0.93
asked Jev (typesafe/jev-1.14) through OpenRouter 6 of 6 questions in 0.4s: 360 input tokens, about $0.00002
```

Asking needs an OpenRouter key in `OPENROUTER_API_KEY`. Jev's answers go in `.sandi-judgments.json`, which you commit
beside the baseline. A model asked the same borderline question twice can answer differently, so sandi asks about a
comment once and reuses the answer until the comment, its code, the question or the model changes. A rerun on the same
tree asks nothing and counts the same, and CI can check guidelines without a key once every answer is recorded.

Without a key, and with some answer not yet recorded, sandi says so and leaves the baseline's guideline counts as they
are. It doesn't fail the run, and it doesn't count what it didn't judge. A key that OpenRouter refuses, an answer
sandi can't read, or a file it can't write is exit 2. `sandi --update` also drops recorded answers the tree no longer
uses.

Jev is pinned to a version, `typesafe/jev-1.14`, rather than the `jev-latest` alias, so a new Jev can't change the
counts under a baseline. Moving to a new version asks every question again.

## Develop

```sh
bundle install
bundle exec rake test
bundle exec exe/sandi    # sandi holds itself to its own rules
```

The tests run against a fake `rubocop` on the `PATH` and a fake Jev on localhost, which `SANDI_JEV_URL` points sandi
at, so they need no network, no key and no real RuboCop.

sandi holds its own comments to its guidelines too, from the answers committed in `.sandi-judgments.json`, so
`bundle exec exe/sandi` needs no key. After changing a comment, or the code it is about, run
`bundle exec exe/sandi --update` with `OPENROUTER_API_KEY` set to record the answers that change needs, and commit them.
