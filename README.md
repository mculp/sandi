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
says what the code does rather than why, or whether a method reaches through one object to another. sandi puts each
one as a yes/no question to
[Jev](https://docs.typesafe.ai/concepts/system-one), TypeSafe's decision model, through OpenRouter. Guidelines are off
unless a project turns them on. See [Guidelines](#guidelines).

Most code doesn't meet them yet. `sandi` records each file's counts in `.sandi-baseline.json` and exits 1 when a
count rises or a file the baseline lacks has an offense. Counts can fall and never rise. Its first line is the
progress to quote in a PR, and it names the files that improved.

`sandi --autocorrect` can fix what it counts: it asks a code model to rewrite the files that break a rule or a
guideline, and keeps a rewrite only if it checks out. See [Autocorrect](#autocorrect).

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
bundle exec sandi --autocorrect                  # first rewrite the files that break a rule or guideline, then check
```

A PR doesn't have to touch the baseline, which keeps parallel PRs from conflicting. Tighten it after merges with
`sandi --update`. `--autocorrect` runs first and combines with `--update`: sandi fixes what it can, then checks, or
records, what is left.

## Guidelines

A guideline is one yes/no question about one place in the code, put to Jev and phrased so that yes is the finding. Turn
guidelines on by name in `.sandi.yml`:

```yaml
guidelines:
  - WhatComment       # a comment inside a method that only says what the lines after it do
  - StaleComment      # a comment that the code it is about contradicts
  - AskForWhat        # a method that tells another object how to do a job, step by step
  - Demeter           # a method that reaches through an object to that object's collaborators
  - InjectDependency  # a method that creates an object of a class it could be given instead
  - TypeSwitch        # a method that decides what to do by checking what kind of object it has
  - FlagParameter     # a method with a parameter that chooses which of its behaviors runs
  - NullCheck         # a method that checks for nil where an object standing for nothing could answer
```

### Places

Each guideline reads some kinds of place, and is asked about every place of those kinds:

- **A comment**, for WhatComment and StaleComment: every comment written for people to read, on lines of its own. It is
  sent with the code it is about, which is the first of these that applies:
  1. the `class`, `module` or `def` just under it;
  2. the method it is inside, a `def` or a block given to `define_method`;
  3. the statement just under it, such as a constant, a `require` or an `attr_reader`; or
  4. the smallest statement that holds it, such as the class that a comment between its methods floats in.

  A directive between a comment and the code under it doesn't separate them.
- **A comment after code on its line**, as in `retries = 3 # three tries`, for StaleComment alone. It is sent with the
  method it is inside, or else the smallest statement that holds its line, which for that example is the line itself.
- **A method**, for the other six: every `def` and every `define_method` call given a block, wherever it is defined,
  whether in a class or module, in `class << self`, in a block or at the top of a script. It is sent as its own source,
  from the start of the `def` or the call to its closing `end` or brace, as though it began its line, so nothing else on
  its line goes with it.

Jev judges worse as what it reads grows, so what it is sent is one definition or statement, never the whole file, and
stops at 100 lines: the first 100, or for a comment further into something longer, the 100 around it. Sandi's rules
hold a class to 100 lines and a method to 5, so for code that follows them this cuts nothing, except a statement outside
any class that is longer than that, such as a constant. The questions are in `config/guidelines.yml`, and
[GUIDELINES.md](GUIDELINES.md) says where each comes from and lists the guidelines still to come.

#### What isn't read

The advice behind each guideline is Sandi Metz's, and GUIDELINES.md gives the chapter. Which places to put to Jev is
sandi's own choice, not hers, and it leaves these out:

- **Comments written for tools**: a shebang, a magic comment such as `# frozen_string_literal: true`, and a `rubocop:`
  directive. They speak to a program, so there is nothing in them for a guideline to judge.
- **A comment after code, for WhatComment.** Its question asks whether a comment says what the lines after it do, and it
  was calibrated on comments above the lines they describe, which a comment after code is not. StaleComment's question
  reads the same wherever the comment sits, so only StaleComment is asked about these.
- **A comment that no statement holds or sits above**, such as a note on its own between top-level statements, or a
  license at the top of a file. A guideline is asked about a comment together with the code it is about, and this one is
  about none. A comment on its own inside a class or a block is read, as about the smallest statement that holds it.
- **A comment between `=begin` and `=end`.** This is a limit: no reason for leaving these out was written down.
- **A method made in another way than `def` or a `define_method` block**, such as with `define_singleton_method`. The
  method guidelines read what RuboCop's `MethodLength` counts as a method, so that rule 2 and the guidelines agree on
  what one is, and it counts only those two.

### Answers

Jev answers with the probability that the answer is yes. A yes of 0.7 or more counts against the file the comment or
method is in, in the same baseline and ratchet as the rules. When a count rises, sandi names what's behind it, by the
comment's first line or the method's `def`, and it says what asking cost:

```text
guidelines: 3 (Demeter 1, StaleComment 1, WhatComment 1) in 1 of 1 files
  lib/cart.rb:5 StaleComment 0.81
  lib/cart.rb:7 WhatComment 0.93
  lib/cart.rb:9 Demeter 0.88
asked Jev (typesafe/jev-1.14) through OpenRouter 9 of 9 questions in 0.5s: 600 input tokens, about $0.00003
```

Jev is pinned to a version, `typesafe/jev-1.14`, rather than the `jev-latest` alias, which moves to each release. The
record below is keyed by model, so under the alias its old answers would stay valid while new questions went to a newer
Jev, and one tree would be judged by two. A pin keeps the record one model's. Moving to a new version asks every
question again.

### The record

Every question about one comment or method goes to Jev in one request, and two that read the same, such as one method
in two files, share it. Asking needs an OpenRouter key in `OPENROUTER_API_KEY`. Jev's answers go in
`.sandi-judgments.json`, which you commit beside the baseline. A model asked the same borderline question twice can
answer differently, so sandi asks about a comment or method once and reuses the answer until its text or code, the
question or the model changes. A method that only moves keeps its answer. A rerun on the same tree asks nothing and
counts the same, and CI can check guidelines without a key once every answer is recorded.

The first answer recorded is the one that counts. A comment that scores near 0.7 is reworded, not asked about again
until it passes.

Without a key, and with some answer not yet recorded, sandi says so and leaves the baseline's guideline counts as they
are. It doesn't fail the run, and it doesn't count what it didn't judge. A key that OpenRouter refuses, an answer
sandi can't read, or a file it can't write is exit 2. `sandi --update` also drops recorded answers the tree no longer
uses.

### Calibration

A question's wording decides its answers, so a guideline is calibrated before it counts: asked about labeled examples
on each side of the line and about real code, to check that 0.7 separates them. WhatComment and StaleComment were
calibrated against Jev on labeled examples and on sandi's own comments, as [GUIDELINES.md](GUIDELINES.md) describes. The
comments above a constant or another statement, and the ones after code that StaleComment reads, were checked afterwards
on a smaller set of labeled examples, not calibrated as fully. The six method questions haven't been calibrated yet, so
treat their first counts as a draft.

## Autocorrect

RuboCop can't autocorrect Sandi's rules: shortening a method is a design decision, not a substitution. Nor can it reword
a comment that only repeats the code. So `sandi --autocorrect` asks a code model, through OpenRouter and with the same
key as Jev, to rewrite each file that counts against a rule or a guideline, and then checks what it gets rather than
trusting it.

The model is told the four rules and every guideline the project turns on, each with the question Jev is asked, what a
yes and a no to it mean and, for WhatComment and StaleComment, how to put a yes right. It is then sent the file and a
line for each thing wrong with it: an offense RuboCop reports, or a comment or method Jev said yes to, with its line,
how it begins and the question that was answered yes. A rewrite is kept only if

- the file's count falls, and no kind of count rises, whether an offense or a guideline;
- every method the file defined is still defined, so a failing test can't be fixed by deleting it; and
- the project's tests still pass.

Otherwise the rewrite is thrown away, the model is told why, and it tries again. Each model gets three tries at a file.
What is kept is built on: a rewrite that fixes some of the offenses counts, and the next try starts from it, so a file
that can't be fixed in one step is fixed in several. When the tries are used up, the file is as the last kept rewrite
made it, or as it was.

A rewrite is judged as the ratchet will judge it. Jev is asked about the comments and methods of the file that changed,
and its answers are recorded in `.sandi-judgments.json` like any other, so a rewrite that shortens a method but narrates
it in a comment is thrown away too. It rewrites only code RuboCop measures, so put your tests under `Include` to have
them fixed too.

Say how in `.sandi.yml`:

```yaml
autocorrect:
  test: bundle exec rake test   # required: a rewrite is kept only if this succeeds
  model:                        # one model or a list, asked in turn
    - anthropic/claude-haiku-5.5
    - openai/gpt-6.1-terra
```

Without `test` it won't start, because a rewrite nothing can check isn't worth keeping. Without `model` it asks
`anthropic/claude-haiku-5.5`. With a list, each model gets its three tries at a file, and the next one only the files
the one before couldn't fix, so a cheap model can take the easy files and a stronger one the rest. It says what each try
did and what asking cost:

```text
autocorrect: test/cli_test.rb ClassLength 1, MethodLength 4
  anthropic/claude-haiku-5.5 try 1: rejected: the tests failed
  anthropic/claude-haiku-5.5 try 2: kept: 5 -> 1 offenses
  anthropic/claude-haiku-5.5 try 3: kept: 1 -> 0 offenses
autocorrect: fixed 1 of 1 files
asked anthropic/claude-haiku-5.5 through OpenRouter 3 requests: 14000 input tokens, 11000 output tokens, about $0.0069
```

With guidelines on, the same loop puts comments right. This file had a method of six lines, a comment its code
contradicted, and four that only restated the code. The first try extracted two methods named for what the comments
said, corrected the stale comment, deleted the rest, and left the unflagged class comment alone:

```text
autocorrect: lib/cart.rb MethodLength 1, StaleComment 1, WhatComment 4
  anthropic/claude-haiku-5.5 try 1: kept: 6 -> 0 offenses
autocorrect: fixed 1 of 1 files
asked anthropic/claude-haiku-5.5 through OpenRouter 1 request: 1624 input tokens, 856 output tokens, about $0.0006
asked Jev (typesafe/jev-1.14) through OpenRouter 4 questions in 0.3s: 1275 input tokens, about $0.00005
```

A file that is only partly fixed says so, as `partly fixed: lib/a.rb has 2 left`, and a file nothing could fix says
`not fixed: lib/a.rb is as it was`. Run it on a clean tree, so that `git diff` shows only what it changed, and read that
diff before you commit it: tests can pass while code stops meaning what it did, and a comment worth keeping can be
deleted without any count rising.

## Develop

```sh
bundle install
bundle exec rake test
bundle exec exe/sandi    # sandi holds itself to its own rules
```

sandi measures all of its own Ruby, tests included, and its large test classes were brought under the rules with
`sandi --autocorrect`.

The tests run against a fake `rubocop` on the `PATH`, a fake Jev and a fake code model on localhost, which
`SANDI_JEV_URL` and `SANDI_AUTOCORRECT_URL` point sandi at, so they need no network, no key and no real RuboCop.

sandi holds its own comments to its guidelines too, from the answers committed in `.sandi-judgments.json`, so
`bundle exec exe/sandi` needs no key. After changing a comment, or the code it is about, run
`bundle exec exe/sandi --update` with `OPENROUTER_API_KEY` set to record the answers that change needs, and commit them.
