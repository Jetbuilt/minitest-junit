require 'minitest/autorun'
require 'stringio'
require 'time'
require 'nokogiri'

require 'ox'
require 'rexml/document'
require 'minitest/junit'
require 'minitest/junit/xml_ox'
require 'minitest/junit/xml_nokogiri'
require 'minitest/junit/xml_rexml'

class FakeTestName; end

module FirstModule
  module SecondModule
    class TestClass; end
  end
end

module TestCaseFormatterTests
  def test_all_tests_generate_testcase_tag
    test = create_test_result
    reporter = create_reporter
    reporter.record test
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    node = parsed.at_xpath("//testcase")
    assert_equal test.name, node['name']
  end

  def test_skipped_tests_generates_skipped_tag
    test = create_test_result
    test.failures << create_error(Minitest::Skip)
    reporter = create_reporter
    reporter.record test
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    skipped = parsed.at_xpath("//testcase/skipped")
    assert skipped, "Expected skipped tag"
    assert skipped['message']
  end

  def test_failing_tests_creates_failure_tag
    test = create_test_result
    test.failures << create_error(Minitest::Assertion)
    reporter = create_reporter
    reporter.record test
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    assert parsed.at_xpath("//testcase/failure")
  end

  def test_other_errors_generates_error_tag
    test = create_test_result
    test.failures << Minitest::UnexpectedError.new(create_error(Exception))
    reporter = create_reporter
    reporter.record test
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    assert parsed.at_xpath("//testcase/error")
  end

  def test_jenkins_sanitizer_uses_modules_as_packages
    test = create_test_result FirstModule::SecondModule::TestClass
    reporter = create_reporter junit_jenkins: true
    reporter.record test
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    node = parsed.at_xpath("//testcase")
    assert_equal 'FirstModule::SecondModule.TestClass', node['classname']
  end

  private

  def document_class
    self.class::DOCUMENT_CLASS
  end

  def create_error(klass)
    fail klass, "A #{klass} failure"
  rescue klass => e
    e
  end

  def create_test_result(name = FakeTestName)
    test = Class.new Minitest::Test do
      define_method 'class' do
        name
      end
    end.new 'test_method_name'
    test.time = a_number
    test.assertions = a_number
    Minitest::Result.from test
  end

  def a_number
    rand(100)
  end

  def create_reporter(options = {})
    io = StringIO.new
    reporter = Minitest::Junit::Reporter.new io, options.merge(document_class: document_class)
    def reporter.output
      @io.string
    end
    reporter.start
    reporter
  end
end

class TestCaseFormatterOx < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::OxDocument
  include TestCaseFormatterTests
end

class TestCaseFormatterNokogiri < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::NokogiriDocument
  include TestCaseFormatterTests
end

class TestCaseFormatterRexml < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::RexmlDocument
  include TestCaseFormatterTests
end
