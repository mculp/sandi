# frozen_string_literal: true

require_relative "comments"

module Sandi
  # The comments that come after code on their line, each with the code it is about: the method it is in, or else the
  # smallest statement that holds its line. Each is read on its own, even beside another on the next line. Only
  # StaleComment asks about them: WhatComment's question is worded for a comment above the lines it describes, which a
  # comment after code is not.
  class TrailingComments < Comments
    private

    def paragraphs = inline.select(&:trailing?).map { |comment| [comment] }
    def subject(paragraph) = method_around(paragraph) || holding(paragraph)
  end
end
