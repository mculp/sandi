# frozen_string_literal: true

require "rbconfig"

# What the tests of autocorrect share: a `rubocop` that counts what is in the files, so that a rewrite changes its
# report, a project test command that can fail, and a project of one file to rewrite.
module AutocorrectHelper
  # A MethodLength offense for each line that says LONG, and a ClassLength one for each that says BIG.
  RUBOCOP = <<~'RUBY'
    require "json"
    COPS = {"LONG" => ["MethodLength", "Method has too many lines. [9/5]"],
            "BIG" => ["ClassLength", "Class has too many lines. [120/100]"]}
    def offenses_in(path)
      File.readlines(path).each_with_index.flat_map do |text, index|
        COPS.select { |word, _| text.include?(word) }.map do |_, (cop, message)|
          {"cop_name" => "Metrics/#{cop}", "message" => message, "location" => {"start_line" => index + 1}}
        end
      end
    end
    files = (Dir["lib/**/*.rb"] + Dir["exe/*"]).sort.map { |path| {"path" => path, "offenses" => offenses_in(path)} }
    puts JSON.generate("metadata" => {"rubocop_version" => "1.87.0"}, "files" => files)
    exit(files.all? { |file| file["offenses"].empty? } ? 0 : 1)
  RUBY

  # The project's tests fail when a file in lib says BROKEN.
  TESTS = <<~'RUBY'
    broken = Dir["lib/**/*.rb"].select { |path| File.read(path).include?("BROKEN") }
    puts "BROKEN found in #{broken.join(", ")}" unless broken.empty?
    exit(broken.empty? ? 0 : 1)
  RUBY

  SLOW = "def total\n  LONG\n  1\nend\n"
  TWICE = "def total\n  LONG\n  LONG\n  1\nend\n"
  FIVE = "def total\n#{"  LONG\n" * 5}  1\nend\n"
  QUICK = "def total = 1\n"
  BROKEN = "def total = 1 # BROKEN\n"
  TESTED = "autocorrect:\n  test: project-tests\n"
  # What a guided project starts from: its one comment, `add one`, is the one Jev says yes to.
  NARRATED = "def total\n  # add one\n  1\nend\n"
  # The same with an offense beside it.
  BOTH = "def total\n  # add one\n  LONG\n  1\nend\n"
  # The same with the line changed.
  CHANGED = "def total\n  # add one\n  2\nend\n"
  # A second file with another such comment.
  OTHER = "def other\n  # add two\n  2\nend\n"
  # A method with two.
  TWO_NARRATED = "def total\n  # add one\n  1\n  # add two\n  2\nend\n"
  # The settings that ask about such comments.
  GUIDED = "guidelines:\n  - WhatComment\n#{TESTED}"

  def fenced(code) = "```ruby\n#{code}```"

  # A model's whole reply when the key is the project's own provider key: OpenRouter charges nothing, and what the
  # provider charged is in the cost details.
  def own_key_reply(charged)
    usage = {"prompt_tokens" => 1000, "completion_tokens" => 500, "cost" => 0, "is_byok" => true,
             "cost_details" => {"upstream_inference_cost" => charged}}
    {"choices" => [{"message" => {"content" => fenced(QUICK)}}], "usage" => usage}
  end
  def read(path) = File.read(File.join(@root, path))

  # What was sent to the model, one string for each request.
  def asked = @model.requests.map { |request| request.body["messages"].map { |message| message["content"] }.join("\n") }

  # What the model is told before it is sent the file, which is the same in every request.
  def told = @model.requests.first.body["messages"].first["content"]

  # The reply for the request being answered: the first of these for the first request, the second for the rest.
  def first_then(first, rest) = fenced(@model.requests.size == 1 ? first : rest)

  # The file in a request with one LONG line less: the reply of a model that fixes one offense at a time.
  def one_less(body)
    source = body["messages"].last["content"][/```ruby\n(.*)```/m, 1]
    fenced(source.sub("  LONG\n", ""))
  end

  # lib/a.rb as `source`, a `.sandi.yml` that says how to autocorrect, and the fake tools that count and test it.
  def project(source = SLOW, sandi_yml = TESTED)
    write("lib/a.rb", source)
    write(".sandi.yml", sandi_yml)
    install("rubocop", RUBOCOP, shell: RbConfig.ruby)
    install("project-tests", TESTS, shell: RbConfig.ruby)
  end

  # A project, a model that answers as the block says, and `sandi --autocorrect` run on them: its exit status.
  def autocorrect(source = SLOW, sandi_yml: TESTED, &reply)
    project(source, sandi_yml)
    model(&reply)
    sandi("--autocorrect")
  end

  # A project with WhatComment on, a Jev that says yes to the comment "add one" and to no other, and a model that
  # answers as the block says.
  def guided_project(source = NARRATED, &reply)
    jev_says_yes_to("add one")
    project(source, GUIDED)
    model(&reply)
  end

  # `sandi --autocorrect` run on a guided project: its exit status.
  def guided(source = NARRATED, &reply)
    guided_project(source, &reply)
    sandi("--autocorrect")
  end
end
