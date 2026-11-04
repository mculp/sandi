# sandi

A ratchet on [Sandi Metz's four rules](https://thoughtbot.com/blog/sandi-metz-rules-for-developers):

1. A class is at most 100 lines.
2. A method is at most 5 lines.
3. A method takes at most 4 parameters.
4. An entry point builds one object, counted here as the distinct constants a script calls methods on outside any
   `def`.

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

## Develop

```sh
bundle install
bundle exec rake test
bundle exec exe/sandi    # sandi holds itself to its own rules
```

The tests run against a fake `rubocop` on the `PATH`, so they need no network and no real RuboCop.
