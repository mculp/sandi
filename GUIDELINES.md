# Guidelines

sandi holds code to two kinds of advice from Sandi Metz.

**Rules** can be counted. A class is at most 100 lines, a method at most 5, a method takes at most 4 parameters, and
an entry point builds one object. RuboCop and Prism count them the same way every time.

**Guidelines** are the rest of what she says about code: responsibilities, dependencies, messages, names and comments.
Each comes down to a judgment no parser can make, so sandi asks Jev, a decision model that answers a typed question
about a piece of code with a probability. A guideline is one yes/no question about one place in the code, phrased so
that yes is the finding. A yes of 0.7 or more counts against the file in the same ratchet as the rules.

This page lists the guidelines sandi has, how they were calibrated, and the ones identified to build next.

## What makes a guideline work

Jev is built for fast, narrow judgments, the kind a reader makes in a second with the right code in front of them.

- **One judgment per question.** "Does this method do more than one thing?" works. "Is this method well designed?"
  doesn't. A question with "and" in it is two questions.
- **Yes is the finding.** A high answer is what counts against the file, so a question never asks whether code is
  free of something.
- **Criteria draw the line.** Jev reads a question literally. Each question's `true` and `false` criteria say where
  yes ends, with the boundary cases two reviewers would argue about.
- **Nothing a parser can count.** Lengths, counts and arithmetic belong in rules. Jev counts poorly, and RuboCop
  counts exactly.
- **A small state.** Jev's accuracy falls as its state fills with code the question isn't about. Sandi's rules help:
  a 5-line method and a 100-line class are small enough to send whole, so code that keeps the rules gets better
  judgments.
- **Calibrated before it counts.** A question's wording decides its answers. Before a guideline goes into
  `config/guidelines.yml`, ask it about labeled examples on each side of the line and about a real codebase, and
  check that 0.7 separates them. Made-up examples alone miss things: only sandi's own code showed that WhatComment's
  first wording counted doc comments too. Changing the wording later means every recorded answer to that question is
  asked again.

## The guidelines sandi has

Each guideline in `config/guidelines.yml` says what kind of place it reads with `about:`, `comment` by default or
`method`, and is asked only about places of that kind. Every question about one place goes to Jev in one request, and
places that read the same, such as one method in two files, share it.

WhatComment and StaleComment are calibrated against Jev, as [Calibration](#calibration) describes. The six method
guidelines aren't yet: they were written when no OpenRouter key was available to ask Jev about examples, so treat
their counts as a draft until they are.

### Comments

They read a comment written for a reader, sent with the code it is about: the class, module or def it documents, or
the method it sits in. The state is `{"comment": ..., "code": ...}`.

**WhatComment**: *Is the comment a note inside a method that only says what the lines after it do?*
Practical Object-Oriented Design in Ruby (POODR), chapter 2. A comment that narrates a bit of code inside a method is a
method waiting to be extracted. Name the method for what the comment says, and the name can't drift from the code the
way a comment can. Comments that give a reason, a constraint or a decision are things code can't say, and they stay. A
comment above a class or method describes it rather than narrating it, so it doesn't count.

**StaleComment**: *Does the code contradict something the comment says about it?*
POODR, chapter 2. Comments aren't executed, so they decay as code changes around them, and a comment that disagrees
with the code misleads the readers who trust it. A claim about a method defined elsewhere doesn't count, since Jev
can't see that method.

### Methods

They read a method: each `def`, wherever it is defined, sent with its own source from `def` to `end`, as though it
began its line, so nothing else on its line goes with it. The state is `{"method": ...}`. A method within Sandi's
second rule is sent whole, and one over 100 lines is cut off there.

**AskForWhat**: *Does the method tell another object how to do a job step by step, rather than ask for what it wants?*
POODR, chapter 4, on asking for "what" instead of telling "how". A trip that tells a mechanic to clean the bicycle,
pump the tires and check the brakes knows the mechanic's job, and a trip that asks the mechanic to prepare the bicycle
doesn't. A parser can count the messages sent to one object. It can't tell a recipe from separate requests.

**Demeter**: *Does the method reach through an object to send a message to one of that object's collaborators?*
POODR, chapter 4, and 99 Bottles of OOP's programming aesthetic, which treats the urge to break the Law of Demeter as
a sign of a missing abstraction. `customer.bicycle.wheel.rotate` reaches through three objects.
`items.map(&:price).sum` transforms one value and is fine. Counting dots can't tell them apart.

**InjectDependency**: *Does the method create an object of a specific class that it could be given instead?*
POODR, chapter 3, on injecting dependencies and isolating instance creation, and 99 Bottles, on pushing object
creation to the edges. A parser finds `Wheel.new` in a method body. It can't tell a collaborator that should be
injected from a value the method rightly builds, such as a result or an error, or from a factory whose job is
building.

**TypeSwitch**: *Does the method decide what to do by checking what kind of object it has?*
POODR, chapter 5, on hidden ducks: `case` on a class, `kind_of?`, `is_a?` and `respond_to?` are each a duck type
waiting to be named. A parser finds those calls. It can't tell a duck in hiding from a boundary that turns outside
input into its own objects, or from a check on a library's objects that can't learn a new message.

**FlagParameter**: *Does a parameter of the method choose which of several behaviors it runs?*
"The Wrong Abstraction" (2016): a shared method that gains a parameter, and a conditional on it, for each caller that
differs. Her line is that "duplication is far cheaper than the wrong abstraction." A parser can find boolean
parameters, but not a mode passed as a symbol, a string or an options hash.

**NullCheck**: *Does the method branch on nil where an object that stands for nothing could take the message
instead?*
"Nothing is Something" (RailsConf 2015), on the null object. A parser counts `nil?` and `&.`. It can't tell a check on
real input from one that keeps passing a missing role around.

## Calibration

The comment questions were calibrated on November 4, 2026, against `typesafe/jev-1.14`. OpenRouter answered it with the
snapshot `typesafe/jev-1.14-20261014`, the same one `jev-latest` pointed to. Each question was asked three times about
49 labeled examples: comments inside methods that narrate or explain, comments above definitions, and the same code
under a comment that is true of it and one the code contradicts. They were also asked about sandi's own comments.

| | Caught | Missed | Correct no | False yes | Lowest labeled yes | Highest labeled no |
| --- | --- | --- | --- | --- | --- | --- |
| WhatComment | 9 | 0 | 39 | 0 | 0.82 | 0.38 |
| StaleComment | 11 | 2 | 36 | 0 | 0.37 | 0.47 |

What the calibration showed:

- **WhatComment's first wording counted doc comments too.** Its criteria included naming what a method already does,
  and 13 of the 52 comments in sandi's code and tests came back yes, every one of them above a `def` or `class`.
  POODR's advice is about a comment inside a method, so the question now asks about those, and no comment above a
  definition, made up or in sandi, reached 0.6.
- **StaleComment misses what takes more than a glance.** A retry limit that only counting through a recursion can
  check scored 0.37, and a wrong method name that reads as a description, "Calls normalize" above a call to
  `sanitize!`, scored 0.54. Jev counts poorly, as above.
- **StaleComment also counts a comment a reader could misread.** In `lib/sandi/ratchet.rb`, "0 when no count rose
  above the baseline, 1 when one did" sat above a method that prints and returns, and it scored 0.67 to 0.79. Turning
  guidelines on for sandi's own code recorded it at 0.68 in one run and 0.77 in the next, which failed that run. The
  comment now begins "The exit status:", which says what the numbers are, and it scores 0.15.
- **Jev is steady but not fixed.** Asked the same question again, its answer usually moved by a hundredth or two, and
  by 0.22 at most, so a borderline answer can land on either side of 0.7. Recording each answer is what keeps a count
  from moving on its own, and the answer recorded first is the one that counts. A comment that scores near 0.7 is
  reworded, not asked about again until it passes.

sandi runs both guidelines on its own comments, from the answers committed in `.sandi-judgments.json`: 108 questions
about the 54 comments in its `lib/` and `exe/`. The first 78 took 1.9 seconds and about a tenth of a cent to ask. None
counts, and the highest is 0.59, WhatComment on the comment above `counts_against` in `lib/sandi/judgment.rb`. CI
replays the answers and needs no key, so a comment that changes shows as not judged until someone records its answers
with `sandi --update`.

## Guidelines to come

sandi reads comments and methods. The method guidelines below need only their questions. The rest need Jev to read
another place: a class or a test.

### Methods

**HiddenStructure**: *Does the method read an array or hash by a position or key whose meaning has no name?*
POODR, chapter 2, on hiding data structures. A method that knows `cell[0]` is the rim and `cell[1]` the tire depends
on the structure of the data, and a Struct gives those positions names. `ARGV.first` is fine, and only a reader knows
the difference.

**OneJob**: *Does the method do more than one thing?*
POODR, chapter 2: methods, like classes, should have one responsibility. "All the Little Things" (RailsConf 2014)
adds the squint test, in which changes in a method's shape and color show where it does different kinds of work.
Five lines can still hold two jobs.

**ConceptName**: *Does the method's name say how it works or what it's made of, rather than what it means?*
99 Bottles of OOP names a thing one level of abstraction above what it is now, such as `container` rather than
`bottle`. A name's meaning is all judgment.

### Classes

**OneResponsibility**: *Does the class do more than one job, so that describing it would take "and" or "or"?*
POODR, chapter 2: describe the class in one sentence. "And" means more than one responsibility. "Or" means more than
one, and unrelated. Cohesion metrics count shared instance variables, which misses a class whose methods share state
but do unrelated jobs.

**EmbeddedType**: *Do the class's methods branch on an attribute that says what kind of thing the object is?*
POODR, chapter 6: an attribute like `style`, checked to choose between road and mountain behavior, is a subclass
waiting to be made.

**SharingSubclass**: *Is the class a subclass only to reuse its superclass's code, rather than a more specific kind of
it?*
"Nothing is Something" and POODR, chapter 6: inheritance is for specialization, and composition is for sharing
behavior. Jev needs the superclass in the state as well.

**PrimitiveConcept**: *Does the class pass around a string or number that stands for a concept with behavior of its
own?*
99 Bottles of OOP, where the integer bottle number becomes an object once its behavior is spread across conditionals.
That's primitive obsession, a code smell.

### Tests

**TestsHow**: *Does the test check how the object does its work, such as a private method or a query it sends, rather
than what it returns or the commands it sends?*
POODR, chapter 9: test an incoming message by its result or its public side effects, expect an outgoing command, and
leave private methods and outgoing queries alone. Jev needs the class under test as well.

## Advice that is a rule after all

Some of her advice can be counted, and belongs with the rules:

- **Hide instance variables** (POODR, chapter 2): an instance variable read outside its accessor or `initialize`.
  Prism can find these.
- **Remove argument-order dependencies** (POODR, chapter 3): positional parameters where keyword arguments would
  name each argument. Prism can count them.

## What to build next

1. Read the comments above a constant, which sandi skips now: 10 of the 64 in its own code, among them the two above a
   `Data.define`.
2. Calibrate the six method guidelines the way the comment guidelines were, and turn each on for sandi once it is.
3. Add HiddenStructure, OneJob and ConceptName. Methods are read already, so each needs only a calibrated question.
4. Add classes, then tests.
