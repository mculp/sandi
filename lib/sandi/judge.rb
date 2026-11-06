# frozen_string_literal: true

module Sandi
  # Answers each judgment from the record when it can, or else from Jev, recording what Jev says so that the same tree
  # is judged the same way next time. Each state Jev reads, a comment with its code or a method's source, is one request
  # with every question about it, however many places read the same, and a few requests are in flight at once, since
  # each one is a round trip.
  class Judge
    AT_ONCE = 8

    def initialize(jev, judgments)
      @jev, @judgments = jev, judgments
      @asked, @tokens, @seconds = 0, 0, 0.0
    end

    def description = @jev.description

    # True when the record holds every answer or Jev can be asked for the rest.
    def able?(judgments) = @jev.ready? || unrecorded(judgments).empty?

    # Each judgment with its noul. What Jev answered is saved even when a request fails, so a rerun picks up where this
    # one stopped.
    def nouls(judgments)
      timed { unrecorded(judgments).group_by(&:state).each_slice(AT_ONCE) { |states| ask(states) } }
      judgments.to_h { |judgment| [judgment, @judgments.noul(key(judgment))] }
    ensure
      save(judgments, failing: $!)
    end

    # What asking took, the way the rules' counters say what they counted.
    def report(judgments)
      return "asked Jev nothing: all #{judgments.size} answers were recorded" if @asked.zero?
      format("asked %s %d of %d questions in %.1fs: %d input tokens, about $%.5f",
             description, @asked, judgments.size, @seconds, @tokens, @tokens * @jev.price)
    end

    def excuse(judgments)
      "#{unrecorded(judgments).size} of #{judgments.size} questions have no recorded answer and #{@jev.unready}"
    end

    private

    def unrecorded(judgments) = judgments.reject { |judgment| @judgments.noul(key(judgment)) }
    def key(judgment) = keys[judgment] ||= judgment.key(@jev.model)

    # By identity, so that looking one up doesn't hash the comment and its code again.
    def keys = @keys ||= {}.compare_by_identity

    # Every request asked at once is waited for, and what Jev answered is recorded, before the first failure is raised.
    def ask(states)
      threads = states.map { |_state, judgments| Thread.new { quietly { [judgments, ask_about(judgments)] } } }
      failures = threads.filter_map { |thread| failure { record(*thread.value) } }
      raise failures.first if failures.any?
    end

    # The error the block raised, if it raised one.
    def failure
      yield
      nil
    rescue Error => error
      error
    end

    def ask_about(judgments) = @jev.nouls(judgments.first.state, questions(judgments))
    def questions(judgments) = judgments.to_h { |judgment| [judgment.name, judgment.question] }

    def record(judgments, (nouls, tokens))
      judgments.each { |judgment| @judgments.record(key(judgment), nouls.fetch(judgment.name)) }
      @asked += judgments.size
      @tokens += tokens
    end

    # A failure to save is raised, unless asking failed first: raised then, it would replace that failure, the one to
    # report.
    def save(judgments, failing:)
      @judgments.save(judgments.map { |judgment| key(judgment) })
    rescue Error
      raise unless failing
    end

    # A thread's error reaches whoever waits for it, so it needn't be printed as well.
    def quietly
      Thread.current.report_on_exception = false
      yield
    end

    def timed
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      @seconds += Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end
  end
end
