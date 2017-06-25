#!/usr/bin/env ruby

require "nokogiri"
require "open-uri"

SPEECH_CLASSES = %w(Speech SubsQuestion SubsAnswer SupQuestion SupAnswer Interjection)

# A comment/speech from a single speaker
# Speaker may be speaking to or on behalf of someone
# May cross sections if the speaker talks a lot
class Speech
  attr_reader :sections, :speaker, :reason, :other

  def initialize(source)
    @class = source[:class]
    @sections = []
    @speaker = nil
    @other = nil
    @reason = nil
    strong = nil
    source.children.each do |child|
      case child.name
      when "a";      # metadata tag containing timestamp... ignore this for now
      when "strong"  # Someone's name. May be split across multiple tags, so we combine them
        if strong.nil?
          strong = child.text.strip
        else
          strong += " " + child.text.strip
        end
      else
        # If the speech has a target or is on behalf of someone,
        # this will be described in non-bold between their names:
        #   Speaker [to/behalf] Other Person
        # To avoid confusion we only accept one non-bold tag before aborting
        if strong.nil?
          @reason = nil
          break
        elsif @speaker.nil?
          @speaker = strong
          @reason = child.text.strip
        elsif @other.nil?
          @other = strong
          break
        end
        strong = nil
      end
    end
  end

  def to_s
    if @other.nil?
      "  #{@class}: #{@speaker}"
    else
      "  #{@class}: #{@speaker} #{@reason} #{@other}"
    end
  end
end

# A topic that was discussed
# Contains one or more speeches, crossing one or more sections from the session
class Topic
  attr_reader :title, :sections, :speech

  def initialize(title)
    @title = title
    @sections = []
    @speech = []
  end

  def parse
    puts self
    @sections.each do |section|
      section.children.each do |child|
        # TODO: This will fail if the element has multiple classes
        if SPEECH_CLASSES.include? child[:class]
          @speech << Speech.new(child)
        elsif child[:class] == "a" and not @speech.empty?
          @speech.last.sections << child
        end
      end
    end
    @speech.each { |speech| puts speech }
  end

  def to_s
    "#{@title} [#{@sections.count} sections]"
  end
end

# The transcript of a single session.
# Contains one or more topics
class Transcript
  attr_reader :topics

  def initialize(url)
    @topics = []
    page = Nokogiri::HTML(open(url))
    p url
    page.css(".hansard__level li div .section").each do |section|
      topic_title = section.at_css(".QSubjectHeading, .QSubjectheadingalone, .Debate, .BillDebate")&.text
      if @topics.empty?
        # The opening section can have no title, so we give it a fake one
        topic_title ||= "OPENING"
      end
      unless topic_title.nil?
        @topics << Topic.new(topic_title)
      end
      @topics.last.sections << section
    end
    @topics.each(&:parse)
  end
end

def parse_index
  url = "https://www.parliament.nz/en/pb/hansard-debates/rhr/"
  transcripts = []

  while url
    page = Nokogiri::HTML(open(url))

    page.css(".hansard__list-item .hansard__content .hansard__body .hansard__heading a").each do |transcript|
      url = "https://www.parliament.nz" + transcript[:href]
      transcripts << Transcript.new(url)
      break # testing
    end

    url = page.at_css(".list-controls .pagination .pagination__next a")[:href]
    break # testing
  end
end

parse_index
